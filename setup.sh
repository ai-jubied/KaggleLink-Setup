#!/bin/bash

# Enable error handling
set -euo pipefail

# Define colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}${BOLD}=====================================${NC}"
echo -e "${BLUE}${BOLD}    KaggleLink Setup Tool ${NC}"
echo -e "${BLUE}${BOLD}=====================================${NC}"
echo ""

# Defaults (all overridable via flags)
REPO_URL="https://github.com/ai-jubied/KaggleLink-Setup.git"
BRANCH="main"
INSTALL_DIR="/tmp/kagglelink"
WORKING_DIR="/kaggle/working"
PORT="22"
ZROK_VERSION="v1.1.11"   # pin to last v1 release; zrok v2 renamed the binary to zrok2 and removed reserve/share-reserved commands this script relies on
SHARE_NAME="kagglelink"
VERBOSE=false
KEEP_EXISTING=true
FOREGROUND=false
PREFERRED_SHELL="bash"
AUTH_KEYS_URL=""
ZROK_TOKEN=""
CODE_SERVER=false        # opt-in browser VS Code (code-server)
CODE_PORT="8080"
CODE_PASSWORD=""         # blank => auto-generated in setup_code_server.sh

usage() {
    echo -e "${BOLD}Usage:${NC} curl -sS <raw_setup_sh_url> | bash -s -- -k <public_key_url> -t <zrok_token> [options]"
    echo ""
    echo -e "${BOLD}Required:${NC}"
    echo "  -k, --keys-url URL      URL to your authorized_keys file"
    echo "  -t, --token TOKEN       Your zrok account token"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  -r, --repo URL          Repository to clone (default: $REPO_URL)"
    echo "  -b, --branch NAME       Branch to clone (default: main)"
    echo "  -d, --dir PATH          Installation directory (default: /tmp/kagglelink)"
    echo "  -w, --working PATH      Working directory (default: /kaggle/working)"
    echo "  -p, --port PORT         SSH port to use (default: 22)"
    echo "  -z, --zrok-version VER  zrok version to install (default: v1.1.11; v2.x is NOT compatible)"
    echo "  -n, --share-name NAME   Reserved zrok share name (default: kagglelink)"
    echo "  -s, --shell SHELL       Preferred shell (bash, zsh) (default: bash)"
    echo "  -F, --foreground        Run zrok share in the foreground (blocks the cell)"
    echo "  -c, --code-server       Also run browser VS Code (code-server) via a public zrok share"
    echo "      --code-port PORT    Local port for code-server (default: 8080)"
    echo "      --code-password PW  Password for code-server (default: auto-generated)"
    echo "  -v, --verbose           Enable verbose output"
    echo "  -f, --force             Force fresh clone even if install dir exists"
    echo "  -h, --help              Display this help message"
    exit 1
}

log() {
    local level=$1
    local message=$2
    case $level in
        info)     echo -e "[${BLUE}INFO${NC}] $message" ;;
        success)  echo -e "[${GREEN}SUCCESS${NC}] $message" ;;
        warning)  echo -e "[${YELLOW}WARNING${NC}] $message" ;;
        error)    echo -e "[${RED}ERROR${NC}] $message" ;;
        progress) echo -e "${BLUE}>>${NC} $message" ;;
    esac
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        log error "$1 could not be found. Please install it and try again."
        exit 1
    fi
}

handle_error() {
    log error "An error occurred at line $1. Setup failed."
    exit 1
}

trap 'handle_error $LINENO' ERR

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--keys-url)      AUTH_KEYS_URL="$2"; shift 2 ;;
        -t|--token)         ZROK_TOKEN="$2"; shift 2 ;;
        -r|--repo)          REPO_URL="$2"; shift 2 ;;
        -b|--branch)        BRANCH="$2"; shift 2 ;;
        -d|--dir)           INSTALL_DIR="$2"; shift 2 ;;
        -w|--working)       WORKING_DIR="$2"; shift 2 ;;
        -p|--port)          PORT="$2"; shift 2 ;;
        -z|--zrok-version)  ZROK_VERSION="$2"; shift 2 ;;
        -n|--share-name)    SHARE_NAME="$2"; shift 2 ;;
        -s|--shell)         PREFERRED_SHELL="$2"; shift 2 ;;
        -F|--foreground)    FOREGROUND=true; shift ;;
        -c|--code-server)   CODE_SERVER=true; shift ;;
        --code-port)        CODE_PORT="$2"; shift 2 ;;
        --code-password)    CODE_PASSWORD="$2"; shift 2 ;;
        -v|--verbose)       VERBOSE=true; shift ;;
        -f|--force)         KEEP_EXISTING=false; shift ;;
        -h|--help)          usage ;;
        *)                  log error "Unknown option: $1"; usage ;;
    esac
done

if [ "$VERBOSE" = true ]; then
    log info "Configuration:"
    log info "  - Repository: $REPO_URL ($BRANCH)"
    log info "  - Installation directory: $INSTALL_DIR"
    log info "  - Working directory: $WORKING_DIR"
    log info "  - SSH port: $PORT"
    log info "  - zrok version: $ZROK_VERSION"
    log info "  - Reserved share name: $SHARE_NAME"
    log info "  - Preferred shell: $PREFERRED_SHELL"
    log info "  - Force fresh clone: $([ "$KEEP_EXISTING" = false ] && echo "Yes" || echo "No")"
fi

# Check for required parameters
if [ -z "$AUTH_KEYS_URL" ]; then
    log error "Public key URL (-k or --keys-url) is required"
    usage
fi

if [ -z "$ZROK_TOKEN" ]; then
    log error "Zrok token (-t or --token) is required"
    usage
fi

log info "Checking required tools..."
check_command git
check_command curl
check_command wget

# Create or update repository
if [ -d "$INSTALL_DIR/.git" ] && [ "$KEEP_EXISTING" = true ]; then
    log info "Repository already present. Updating it..."
    # Hard-reset to the remote so rewritten/force-pushed history still updates cleanly
    # (a plain 'git pull --ff-only' aborts on divergent history and leaves stale scripts).
    if git -C "$INSTALL_DIR" fetch --depth 1 origin "$BRANCH"; then
        git -C "$INSTALL_DIR" reset --hard "origin/$BRANCH" || log warning "git reset failed; continuing with existing checkout"
    else
        log warning "git fetch failed; continuing with existing checkout"
    fi
else
    [ -d "$INSTALL_DIR" ] && { log warning "Removing existing $INSTALL_DIR..."; rm -rf "$INSTALL_DIR"; }
    log progress "Cloning repository..."
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

log progress "Making scripts executable..."
chmod +x ./*.sh

if [ ! -d "$WORKING_DIR" ]; then
    log warning "Working directory doesn't exist. Creating it..."
    mkdir -p "$WORKING_DIR"
fi

# Configure preferred shell
if [ "$PREFERRED_SHELL" = "zsh" ]; then
    log progress "Setting up Zsh as preferred shell..."
    if ! command -v zsh &>/dev/null; then
        log warning "Zsh not found. Installing it..."
        apt-get update && apt-get install -y zsh
    fi
    chsh -s "$(command -v zsh)"
elif [ "$PREFERRED_SHELL" != "bash" ]; then
    log warning "Unsupported shell: $PREFERRED_SHELL. Defaulting to bash."
fi

log progress "Setting up SSH server and zrok..."
./setup_kaggle_zrok.sh "$AUTH_KEYS_URL" "$PORT" "$ZROK_VERSION"

# With --force, start from a clean zrok environment. A leftover identity from a
# previous or dead session is reused by 'zrok enable' (skipped as "already
# enabled") but rejected by the controller, causing 'INVALID_AUTH / no apiSession'
# when a share tries to bind. Purging ~/.zrok forces a fresh, valid enable.
if [ "$KEEP_EXISTING" = false ]; then
    log progress "Resetting zrok environment for a clean enable..."
    command -v zrok >/dev/null 2>&1 && zrok disable >/dev/null 2>&1 || true
    rm -rf "${HOME:-/root}/.zrok" /root/.zrok
fi

# Optional: browser VS Code (code-server), exposed via a public zrok share.
# Started before the SSH tunnel so it also works in --foreground mode (where
# start_zrok.sh exec's and never returns).
if [ "$CODE_SERVER" = true ]; then
    log progress "Setting up browser VS Code (code-server)..."
    ./setup_code_server.sh "$CODE_PORT" "$CODE_PASSWORD" "$WORKING_DIR"
    ./start_code_server.sh "$ZROK_TOKEN" "$CODE_PORT" "$WORKING_DIR"
fi

log progress "Starting zrok tunnel..."
if [ "$FOREGROUND" = true ]; then
    # Foreground share blocks the cell to hold the Kaggle session open. When it
    # is stopped/terminated it exits non-zero - that's a normal end, not a
    # failure, so don't let it trip the ERR trap.
    log info "Tunnel running in the foreground - stop the cell to end it."
    ./start_zrok.sh "$ZROK_TOKEN" "$PORT" --foreground --share-name "$SHARE_NAME" || true
    log info "Foreground tunnel stopped."
    exit 0
else
    ./start_zrok.sh "$ZROK_TOKEN" "$PORT" --share-name "$SHARE_NAME"
fi

echo ""
echo -e "${GREEN}${BOLD}=====================================${NC}"
echo -e "${GREEN}${BOLD}    KaggleLink Setup Complete    ${NC}"
echo -e "${GREEN}${BOLD}=====================================${NC}"
if [ "$CODE_SERVER" = true ]; then
    CODE_URL=$(cat /root/.kagglelink_code_url 2>/dev/null || echo "")
    CODE_PW=$(cat /root/.kagglelink_code_password 2>/dev/null || echo "")
    echo ""
    log success "Browser VS Code (code-server):"
    if [ -n "$CODE_URL" ]; then
        echo -e "    URL:      ${BOLD}${CODE_URL}${NC}"
    else
        echo -e "    URL:      not detected yet - run 'kagglelink-status' or: tail -f /var/log/kagglelink/zrok-code.log"
    fi
    echo -e "    Password: ${BOLD}${CODE_PW:-<see above>}${NC}"
fi
log success "Run 'kagglelink-status' over SSH to check tunnel health."
