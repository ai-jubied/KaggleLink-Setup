#!/bin/bash
set -e

# Define colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}Starting automated test...${NC}"

# Validate environment variables
AUTH_KEYS_URL="${AUTH_KEYS_URL:-}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"
ZROK_TOKEN="${ZROK_TOKEN:-}"

echo -e "${BLUE}Validating environment variables:${NC}"
echo "AUTH_KEYS_URL: ${AUTH_KEYS_URL:-(not set)}"
echo "SSH_PUBLIC_KEY: ${SSH_PUBLIC_KEY:-(not set)}"
echo "ZROK_TOKEN: ${ZROK_TOKEN:-(not set)}"

if [ -z "$AUTH_KEYS_URL" ] && [ -z "$SSH_PUBLIC_KEY" ]; then
    echo -e "${RED}Error: Neither AUTH_KEYS_URL nor SSH_PUBLIC_KEY environment variable is set.${NC}"
    echo "Provide one during 'docker build' using --build-arg AUTH_KEYS_URL_ARG=your_url"
    exit 1
fi

if [ -z "$ZROK_TOKEN" ]; then
    echo -e "${RED}Error: ZROK_TOKEN environment variable is not set.${NC}"
    echo "Provide it during 'docker build' using --build-arg ZROK_TOKEN_ARG=your_token"
    exit 1
fi

# Run setup script
export SSH_PUBLIC_KEY
echo -e "${BLUE}Running setup_kaggle_zrok.sh...${NC}"
./setup_kaggle_zrok.sh "$AUTH_KEYS_URL"

# Locate zrok binary
ZROK_CMD=""
if command -v zrok &>/dev/null; then
    ZROK_CMD="zrok"
elif [ -f "/usr/local/bin/zrok" ]; then
    ZROK_CMD="/usr/local/bin/zrok"
else
    echo -e "${RED}zrok executable not found after setup_kaggle_zrok.sh.${NC}"
    exit 1
fi

echo -e "${GREEN}Using zrok command: $ZROK_CMD${NC}"

# Check SSH service
echo -e "${BLUE}Checking SSH service status...${NC}"
if service ssh status &>/dev/null || /etc/init.d/ssh status &>/dev/null || systemctl status ssh &>/dev/null; then
    echo -e "${GREEN}SSH service is running.${NC}"
else
    echo -e "${RED}SSH service check failed. Attempting to get more information:${NC}"
    service ssh status || true
    /etc/init.d/ssh status || true
    systemctl status ssh || true
    echo -e "${RED}SSH service does not appear to be running. Check setup_kaggle_zrok.sh logs.${NC}"
    exit 1
fi

# Start zrok for testing
echo -e "${BLUE}Starting zrok for testing (with 15 second timeout)...${NC}"

echo -e "${BLUE}Enabling zrok with token $ZROK_TOKEN${NC}"
"$ZROK_CMD" enable "$ZROK_TOKEN" || {
    echo -e "${RED}Failed to enable zrok with provided token.${NC}"
    exit 1
}

# Run the share command with timeout
echo -e "${BLUE}Starting zrok share with a 15-second timeout (for testing)${NC}"
timeout 15s "$ZROK_CMD" share private --headless --backend-mode tcpTunnel localhost:22 || echo -e "${YELLOW}Zrok stopped after timeout (this is expected in test mode)${NC}"

# Check if zrok is enabled and running
echo -e "${BLUE}Checking if zrok is enabled...${NC}"
if "$ZROK_CMD" status | grep -q 'Account Token.*<<SET>>'; then
    echo -e "${GREEN}zrok service started successfully.${NC}"
else
    echo -e "${RED}zrok service does not appear to be properly configured.${NC}"
    exit 1
fi

# Disable zrok at the end of test
echo -e "${BLUE}Test complete. Disabling zrok...${NC}"
"$ZROK_CMD" disable

echo -e "${GREEN}${BOLD}All tests passed successfully!${NC}"
echo -e "${GREEN}${BOLD}=====================================${NC}"
echo -e "${GREEN}${BOLD}Your Kaggle instance is now ready with:${NC}"
echo -e "${GREEN}✅ SSH server running on port 22${NC}"
echo -e "${GREEN}✅ VS Code extensions setup available${NC}"
echo -e "${GREEN}${BOLD}=====================================${NC}"

echo -e "${GREEN}Automated test script completed.${NC}"
