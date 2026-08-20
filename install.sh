#!/bin/bash
# install.sh — install tmux-ws
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/config"
BIN_DIR="$SCRIPT_DIR/bin"
CONFIG_DIR="$HOME/.config/tmux-ws"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}!${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; }

# Check dependencies
if ! command -v tmux &>/dev/null; then
    error "tmux is not installed"
    exit 1
fi

# Install config files (only copy missing ones)
if [[ -d "$CONFIG_DIR" ]]; then
    warn "Config directory exists at $CONFIG_DIR — skipping config install"
    warn "To reset: rm -rf $CONFIG_DIR && re-run this script"
else
    mkdir -p "$CONFIG_DIR"
    cp -r "$CONFIG_SRC/_templates" "$CONFIG_DIR/"
    cp -r "$CONFIG_SRC/_examples" "$CONFIG_DIR/"
    info "Config installed to $CONFIG_DIR"
fi

# Add bin/ to PATH
SHELL_RC=""
if [[ -f "$HOME/.bashrc" ]]; then
    SHELL_RC="$HOME/.bashrc"
elif [[ -f "$HOME/.zshrc" ]]; then
    SHELL_RC="$HOME/.zshrc"
fi

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -qF "tmux-ws/bin" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# tmux-ws" >> "$SHELL_RC"
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
        info "Added to PATH in $SHELL_RC"
    else
        warn "PATH already configured in $SHELL_RC"
    fi
else
    warn "No .bashrc or .zshrc found — add $BIN_DIR to your PATH manually"
fi

# Make script executable
chmod +x "$BIN_DIR/tmux-ws"

echo ""
info "Installed! Reload your shell:"
echo "  source ${SHELL_RC:-~/.bashrc}"
echo ""
echo "Then:"
echo "  tmux-ws help          # show commands"
echo "  tmux-ws list          # see available workspaces"
echo "  tmux-ws create _examples  # try the example"
