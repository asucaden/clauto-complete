#!/bin/bash
# Clauto-Complete installer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAMMERSPOON_DIR="$HOME/.hammerspoon"

echo "Installing Clauto-Complete..."

# Create Hammerspoon directory if needed
mkdir -p "$HAMMERSPOON_DIR"

# Check for existing init.lua
if [ -f "$HAMMERSPOON_DIR/init.lua" ] && [ ! -L "$HAMMERSPOON_DIR/init.lua" ]; then
    echo "Backing up existing init.lua to init.lua.backup"
    mv "$HAMMERSPOON_DIR/init.lua" "$HAMMERSPOON_DIR/init.lua.backup"
fi

# Create symlink
ln -sf "$SCRIPT_DIR/init.lua" "$HAMMERSPOON_DIR/init.lua"
echo "Symlinked init.lua to $HAMMERSPOON_DIR/"

# Check if Claude CLI is installed and update path
CLAUDE_PATH=$(which claude 2>/dev/null || echo "")
if [ -z "$CLAUDE_PATH" ]; then
    echo ""
    echo "Warning: Claude CLI not found in PATH"
    echo "Install it: https://docs.anthropic.com/en/docs/claude-cli"
    echo "Then update CLAUDE_PATH in ~/.hammerspoon/init.lua"
else
    echo "Found Claude CLI at: $CLAUDE_PATH"
    echo "Updating CLAUDE_PATH in init.lua..."
    # Replace the CLAUDE_PATH line with the detected path
    sed -i '' "s|^local CLAUDE_PATH = .*|local CLAUDE_PATH = \"$CLAUDE_PATH\"|" "$SCRIPT_DIR/init.lua"
fi

# Check if Hammerspoon is installed
if [ -d "/Applications/Hammerspoon.app" ]; then
    echo ""
    echo "Installation complete!"
    echo ""
    echo "Next steps:"
    echo "1. Open Hammerspoon from Applications"
    echo "2. Grant Accessibility permissions when prompted"
    echo "3. Use Ctrl+Space to invoke Claude"
else
    echo ""
    echo "Hammerspoon not found. Install it with:"
    echo "  brew install --cask hammerspoon"
fi
