#!/bin/bash
#
# kagglelink-status - quick health check for the SSH server and zrok tunnel.
# Installed to /usr/local/bin/kagglelink-status by setup_kaggle_zrok.sh.
#
set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

ZROK_LOG="/var/log/kagglelink/zrok.log"

echo -e "${BOLD}KaggleLink status${NC}"
echo "-----------------"

# SSH service
if pgrep -x sshd >/dev/null; then
    port=$(awk '/^Port /{print $2}' /etc/ssh/sshd_config 2>/dev/null)
    echo -e "SSH server:      ${GREEN}running${NC} (port ${port:-22})"
else
    echo -e "SSH server:      ${RED}NOT running${NC} - try: service ssh restart"
fi

# zrok enablement
if zrok status 2>/dev/null | grep -q '<<SET>>'; then
    echo -e "zrok account:    ${GREEN}enabled${NC}"
else
    echo -e "zrok account:    ${RED}NOT enabled${NC} - run: zrok enable <token>"
fi

# zrok share process
if pgrep -f "zrok share" >/dev/null; then
    echo -e "zrok tunnel:     ${GREEN}running${NC}"
else
    echo -e "zrok tunnel:     ${RED}NOT running${NC} - re-run start_zrok.sh"
fi

# supervisor
if pgrep -f "kagglelink-zrok-run" >/dev/null; then
    echo -e "auto-restart:    ${GREEN}active${NC}"
else
    echo -e "auto-restart:    ${YELLOW}inactive${NC} (tunnel will not recover if it drops)"
fi

# access token hint
if [ -f "$ZROK_LOG" ]; then
    token=$(grep -oE 'zrok access private [[:alnum:]]+' "$ZROK_LOG" 2>/dev/null | tail -n 1 | awk '{print $4}')
    if [ -n "$token" ]; then
        echo ""
        echo -e "Access from your local machine with:"
        echo -e "${BOLD}    zrok access private ${token}${NC}"
    fi
    echo ""
    echo "Recent tunnel log ($ZROK_LOG):"
    tail -n 5 "$ZROK_LOG"
fi
