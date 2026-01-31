# Clauto-Complete

Invoke Claude from any app via hotkey. Type a prompt, get the response inserted at your cursor.

## Hotkeys

| Hotkey | Description |
|--------|-------------|
| `Ctrl+Space` | Text-only prompt |
| `Ctrl+Shift+Space` | Prompt with screenshot of current screen |
| `Ctrl+Option+Space` | **True autocomplete** - takes screenshot, finds your cursor, and types what you should say next (no prompt needed) |

## Prerequisites

- macOS
- [Hammerspoon](https://www.hammerspoon.org/) - `brew install --cask hammerspoon`
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-cli) - installed and authenticated

## Installation

### Quick Install
```bash
brew install --cask hammerspoon
git clone https://github.com/asucaden/clauto-complete.git
cd clauto-complete
./install.sh
```

The install script will:
- Symlink `init.lua` to `~/.hammerspoon/`
- Auto-detect your Claude CLI path and update the config

### Manual Install

1. **Install Hammerspoon**: `brew install --cask hammerspoon`

2. **Install Claude CLI**: https://docs.anthropic.com/en/docs/claude-cli

3. **Clone and symlink**:
   ```bash
   git clone https://github.com/asucaden/clauto-complete.git
   cd clauto-complete
   ln -sf "$(pwd)/init.lua" ~/.hammerspoon/init.lua
   ```

4. **Update Claude path** in `~/.hammerspoon/init.lua`:
   ```lua
   local CLAUDE_PATH = "/path/to/claude"  -- run: which claude
   ```

5. **Launch Hammerspoon** and grant Accessibility permissions when prompted

6. **Reload config**: Click Hammerspoon menu bar icon > Reload Config

## Usage

1. Place your cursor in any text field (Notes, VS Code, browser, etc.)
2. Press `Ctrl+Space` (or `Ctrl+Shift+Space` for screenshot)
3. Type your prompt in the popup
4. Press Enter
5. Wait for Claude's response to be inserted at your cursor

## Examples

- **Quick edits**: Select text, `Ctrl+Space`, "fix grammar"
- **Code help**: `Ctrl+Space`, "python function to reverse a string"
- **Screenshot context**: `Ctrl+Shift+Space`, "what error is shown?"
- **Writing**: `Ctrl+Space`, "email declining a meeting politely"
- **True autocomplete**: In a chat, with cursor in reply field, press `Ctrl+Option+Space` - Claude sees your screen, reads the conversation, and types a response as you

## Configuration

Edit `~/.hammerspoon/init.lua` to customize:

```lua
local CLAUDE_PATH = "/path/to/claude"     -- Claude CLI location
local SYSTEM_PROMPT = "Be concise..."      -- System prompt for Claude
local TIMEOUT_SECONDS = 60                 -- Request timeout
```

## Troubleshooting

### "Clauto-Complete loaded" doesn't appear
- Make sure Hammerspoon is running (look for icon in menu bar)
- Check Hammerspoon console for errors (click menu bar icon > Console)

### Hotkeys don't work
- Grant Accessibility permissions: System Settings > Privacy & Security > Accessibility > Enable Hammerspoon
- Check for hotkey conflicts with other apps

### Claude errors
- Verify Claude CLI is authenticated: run `claude` in terminal
- Check the path in init.lua matches: `which claude`

### Response not pasting
- Some apps block programmatic paste - try a different app
- Make sure cursor is in an editable text field

## How It Works

1. Hotkey triggers Hammerspoon
2. (Optional) Screenshot captured to temp file
3. Spotlight-like chooser popup appears
4. User types prompt and presses Enter
5. Claude CLI executed asynchronously with prompt + screenshot
6. Response inserted via clipboard + Cmd+V
7. Original clipboard restored after 0.5s

## License

MIT
