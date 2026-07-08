#!/bin/bash
#
# install_extensions - install a curated set of VS Code extensions.
# Run inside an SSH session after VS Code Remote has connected once
# (the 'code' CLI is provided by the VS Code server).
#
set -uo pipefail

extensions=(
  # Python and Data Science
  "ms-python.python"
  "ms-toolsai.jupyter"
  "ms-python.vscode-pylance"
  "ms-toolsai.jupyter-renderers"
  "ms-toolsai.jupyter-keymap"

  # Machine Learning
  "ms-toolsai.vscode-ai"
  "ms-toolsai.vscode-ai-remote"

  # Git integration
  "eamodio.gitlens"
  "mhutchie.git-graph"

  # Utilities
  "esbenp.prettier-vscode"
  "christian-kohler.path-intellisense"
  "streetsidesoftware.code-spell-checker"
  "aaron-bond.better-comments"

  # Theme
  "dracula-theme.theme-dracula"
)

if ! command -v code &>/dev/null; then
  echo "ERROR: 'code' CLI not found."
  echo "Connect once with VS Code Remote-SSH first (it installs the server), then re-run this."
  exit 1
fi

echo "Installing ${#extensions[@]} VS Code extensions..."
failed=()
for extension in "${extensions[@]}"; do
  echo "-> $extension"
  if ! code --install-extension "$extension" --force >/dev/null 2>&1; then
    failed+=("$extension")
    echo "   FAILED"
  fi
done

if [ ${#failed[@]} -gt 0 ]; then
  echo ""
  echo "WARNING: ${#failed[@]} extension(s) failed to install: ${failed[*]}"
  exit 1
fi

echo "All extensions installed successfully."
