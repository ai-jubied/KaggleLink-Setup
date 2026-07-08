#!/bin/bash
#
# setup_code_server.sh - install and configure code-server (browser VS Code)
# on a Kaggle instance. code-server binds to localhost only; a public zrok
# share (see start_code_server.sh) is the internet-facing edge.
#
# Usage: ./setup_code_server.sh [port] [password] [workspace_dir]
#
set -euo pipefail

CODE_PORT=${1:-8080}
CODE_PASSWORD=${2:-}
WORKSPACE=${3:-/kaggle/working}

BLUE='\033[0;34m'
NC='\033[0m'
log() { echo -e "[${BLUE}code-server${NC}] $*"; }

PWFILE="/root/.kagglelink_code_password"
WSFILE="/root/.kagglelink_code_workspace"
CONFIG_DIR="/root/.config/code-server"

# --- Generate a password if none was supplied ---------------------------
if [ -z "$CODE_PASSWORD" ]; then
    if command -v openssl >/dev/null 2>&1; then
        CODE_PASSWORD=$(openssl rand -hex 12)
    else
        CODE_PASSWORD=$(head -c 32 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 24)
    fi
fi

# --- Install code-server if missing -------------------------------------
if command -v code-server >/dev/null 2>&1; then
    log "already installed: $(code-server --version 2>/dev/null | head -n 1); skipping install"
else
    log "Installing code-server..."
    curl -fsSL https://code-server.dev/install.sh | sh
fi

if ! command -v code-server >/dev/null 2>&1; then
    log "ERROR: code-server installation failed"
    exit 1
fi

# --- Write config (bind to localhost; zrok handles public access) -------
mkdir -p "$CONFIG_DIR" "$WORKSPACE"
cat > "$CONFIG_DIR/config.yaml" <<EOF
bind-addr: 127.0.0.1:${CODE_PORT}
auth: password
password: ${CODE_PASSWORD}
cert: false
EOF
chmod 600 "$CONFIG_DIR/config.yaml"

# --- Persist password + workspace for reporting / status ----------------
umask 077
printf '%s\n' "$CODE_PASSWORD" > "$PWFILE"
printf '%s\n' "$WORKSPACE"     > "$WSFILE"

log "configured on 127.0.0.1:${CODE_PORT} (workspace: $WORKSPACE)"
