#!/bin/bash
#
# connect.sh - run this on your LOCAL machine to reach the Kaggle instance.
#
# Usage: ./connect.sh [options] [share_token] [local_port] [identity_file]
#
#   share_token    The token printed at the end of the Kaggle setup
#                  (default reserved share name: kagglelink)
#   local_port     Local port to bind the tunnel to (default: 9191)
#   identity_file  SSH private key (default: ~/.ssh/kaggle_rsa)
#
# Options:
#   -t, --tunnel   Keep tunnel open for VS Code Remote-SSH without opening shell
#   -h, --help     Show this help message
#
# Requires zrok installed and enabled locally: zrok enable <your_account_token>
#
set -euo pipefail

usage() {
    cat <<EOF
Usage: ./connect.sh [options] [share_token] [local_port] [identity_file]

Connect to your remote Kaggle instance via zrok tunnel.

Arguments:
  share_token    zrok share token (default: kagglelink)
  local_port     Local port to bind (default: 9191)
  identity_file  SSH private key (default: ~/.ssh/kaggle_rsa)

Options:
  -t, --tunnel   Keep the tunnel open for VS Code Remote-SSH without opening an SSH terminal
  -h, --help     Show this help message

Examples:
  ./connect.sh                 # Connect via SSH in current terminal
  ./connect.sh -t              # Open tunnel on 127.0.0.1:9191 and keep open for VS Code
  ./connect.sh mytoken 9292    # Connect to custom token on port 9292
EOF
    exit 0
}

SHARE_TOKEN="kagglelink"
LOCAL_PORT="9191"
IDENTITY="$HOME/.ssh/kaggle_rsa"
TUNNEL_ONLY=false

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tunnel|--tunnel-only)
            TUNNEL_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [ ${#POSITIONAL[@]} -ge 1 ]; then
    SHARE_TOKEN="${POSITIONAL[0]}"
fi
if [ ${#POSITIONAL[@]} -ge 2 ]; then
    LOCAL_PORT="${POSITIONAL[1]}"
fi
if [ ${#POSITIONAL[@]} -ge 3 ]; then
    IDENTITY="${POSITIONAL[2]}"
fi

if ! command -v zrok &>/dev/null; then
    echo "Error: zrok is not installed. See https://docs.zrok.io/docs/guides/install/"
    exit 1
fi

if ! zrok status 2>/dev/null | grep -q '<<SET>>'; then
    echo "Error: zrok is not enabled on this machine. Run: zrok enable <your_account_token>"
    exit 1
fi

if [ "$TUNNEL_ONLY" = false ] && [ ! -f "$IDENTITY" ]; then
    echo "Error: Identity file $IDENTITY not found."
    echo "Generate one with: ssh-keygen -t ed25519 -C kaggle_remote_ssh -f ~/.ssh/kaggle_rsa"
    exit 1
fi

# Clean up any lingering zrok tunnel on the exact same port
if pgrep -f "zrok access private.*${LOCAL_PORT}" >/dev/null 2>&1; then
    echo "Notice: Stopping previous zrok tunnel process on port ${LOCAL_PORT}..."
    pkill -f "zrok access private.*${LOCAL_PORT}" 2>/dev/null || true
    sleep 1
fi

ACCESS_PID=""
cleanup() {
    if [ -n "$ACCESS_PID" ]; then
        kill "$ACCESS_PID" 2>/dev/null || true
        wait "$ACCESS_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

echo "Opening tunnel to share '$SHARE_TOKEN' on 127.0.0.1:${LOCAL_PORT}..."
zrok access private --bind "127.0.0.1:${LOCAL_PORT}" "$SHARE_TOKEN" --headless &
ACCESS_PID=$!

# Wait for the local listener to come up
READY=false
for _ in $(seq 1 20); do
    if ! kill -0 "$ACCESS_PID" 2>/dev/null; then
        echo "Error: zrok access stopped unexpectedly. Please check your share token ($SHARE_TOKEN)."
        echo "Tip: If you see 'accessUnauthorized (401)', refresh your local zrok identity:"
        echo "     zrok disable && zrok enable <your_token>"
        exit 1
    fi
    if (exec 3<>"/dev/tcp/127.0.0.1/${LOCAL_PORT}") 2>/dev/null; then
        exec 3>&- 3<&-
        READY=true
        break
    fi
    sleep 1
done

if [ "$READY" = false ]; then
    echo "Error: Timed out waiting for tunnel on 127.0.0.1:${LOCAL_PORT}."
    exit 1
fi

if [ "$TUNNEL_ONLY" = true ]; then
    echo ""
    echo "========================================================"
    echo "✅ Tunnel is active on 127.0.0.1:${LOCAL_PORT}!"
    echo "========================================================"
    echo "You can now connect via VS Code Remote - SSH:"
    echo "  Host: kaggle (or root@127.0.0.1:${LOCAL_PORT})"
    echo ""
    echo "Press Ctrl+C to stop the tunnel when done."
    echo "========================================================"
    wait "$ACCESS_PID"
else
    echo "Tunnel established. Connecting via SSH..."
    ssh -o UserKnownHostsFile=/dev/null \
        -o StrictHostKeyChecking=no \
        -o ServerAliveInterval=60 \
        -o ServerAliveCountMax=3 \
        -i "$IDENTITY" \
        -p "$LOCAL_PORT" \
        root@127.0.0.1

    echo "SSH session closed; shutting down tunnel."
fi
