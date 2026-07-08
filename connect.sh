#!/bin/bash
#
# connect.sh - run this on your LOCAL machine to reach the Kaggle instance.
#
# Usage: ./connect.sh <share_token> [local_port] [identity_file]
#
#   share_token    The token printed at the end of the Kaggle setup
#                  (default reserved share name: kagglelink)
#   local_port     Local port to bind the tunnel to (default: 9191)
#   identity_file  SSH private key (default: ~/.ssh/kaggle_rsa)
#
# Requires zrok installed and enabled locally: zrok enable <your_account_token>
#
set -euo pipefail

SHARE_TOKEN=${1:-kagglelink}
LOCAL_PORT=${2:-9191}
IDENTITY=${3:-"$HOME/.ssh/kaggle_rsa"}

if ! command -v zrok &>/dev/null; then
    echo "zrok is not installed. See https://docs.zrok.io/docs/guides/install/"
    exit 1
fi

if ! zrok status 2>/dev/null | grep -q '<<SET>>'; then
    echo "zrok is not enabled on this machine. Run: zrok enable <your_account_token>"
    exit 1
fi

if [ ! -f "$IDENTITY" ]; then
    echo "Identity file $IDENTITY not found."
    echo "Generate one with: ssh-keygen -t ed25519 -C kaggle_remote_ssh -f ~/.ssh/kaggle_rsa"
    exit 1
fi

cleanup() {
    [ -n "${ACCESS_PID:-}" ] && kill "$ACCESS_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "Opening tunnel to share '$SHARE_TOKEN' on 127.0.0.1:${LOCAL_PORT}..."
zrok access private --bind "127.0.0.1:${LOCAL_PORT}" "$SHARE_TOKEN" --headless &
ACCESS_PID=$!

# Wait for the local listener to come up
for _ in $(seq 1 15); do
    if (exec 3<>"/dev/tcp/127.0.0.1/${LOCAL_PORT}") 2>/dev/null; then
        exec 3>&- 3<&-
        break
    fi
    sleep 1
done

echo "Connecting via SSH..."
ssh -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    -i "$IDENTITY" \
    -p "$LOCAL_PORT" \
    root@127.0.0.1

echo "SSH session closed; shutting down tunnel."
