# Claude Code Usage Widget

🌏 **Language**: **English** | [한국어](docs/README.ko.md)

[![macOS](https://img.shields.io/badge/macOS-12+-blue.svg)](https://www.apple.com/macos/)
[![xbar](https://img.shields.io/badge/xbar-compatible-brightgreen.svg)](https://xbarapp.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

An xbar plugin that monitors Claude Code API usage in real-time from your macOS menu bar.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/tesilio/cc-usage-widget.git
cd cc-usage-widget

# Install (dependencies + plugin auto-installation)
./install.sh
```

The install script automatically handles:
- Homebrew installation check (installs if missing)
- jq, bc dependency installation
- xbar installation check (suggests installation if missing)
- Plugin copy and execution permission setup
- Claude Code authentication status check

## Prerequisites

- **macOS** 12 or later
- **Claude Code CLI** logged in (`claude login`)

## Features

| Feature | Description |
|---------|-------------|
| 5-Hour Block Usage | Displays current usage percentage in menu bar |
| Weekly Usage | Shows 7-day cumulative usage |
| Color Indicators | Green (<70%) / Yellow (70-90%) / Red (≥90%) |
| Reset Time | Shows time until usage reset |
| Auto Token Refresh | Automatic OAuth token renewal on expiry |
| Caching | 30-second cache to minimize API calls |

## Menu Bar Display

```
72% (14:00)              ← Menu bar (5-hour block usage, reset time)
---
📊 5-Hour Block
   Usage: 72%
   Reset: 2h 15m (14:00)
---
📅 Weekly Usage
   Usage: 45%
   Reset: 3d 12h (2/2)
---
🔄 Refresh
```

## Troubleshooting

### "Authentication info not found"

```bash
# Log in to Claude Code CLI
claude login
```

### Plugin not visible in menu bar

```bash
# Check plugin execution permission
ls -la ~/Library/Application\ Support/xbar/plugins/claude-usage.30s.sh

# Add permission if missing
chmod +x ~/Library/Application\ Support/xbar/plugins/claude-usage.30s.sh

# Restart xbar
# Menu bar → xbar → Quit, then relaunch
```

### Manual testing

```bash
# Run the script directly
bash ~/Library/Application\ Support/xbar/plugins/claude-usage.30s.sh
```

### Clear cache

```bash
rm ~/.claude/.cache/usage-api.json
```

## Configuration

### Change refresh interval

The number in the filename determines the refresh interval:

| Filename | Interval |
|----------|----------|
| `claude-usage.30s.sh` | 30 seconds (default) |
| `claude-usage.1m.sh` | 1 minute |
| `claude-usage.5m.sh` | 5 minutes |

```bash
# Example: Change to 1-minute interval
cd ~/Library/Application\ Support/xbar/plugins
mv claude-usage.30s.sh claude-usage.1m.sh
```

### Change color thresholds

Modify the 70, 90 values in the `get_color()` function in the script.

## Manual Installation

To install without install.sh:

```bash
# Install dependencies
brew install --cask xbar
brew install jq bc

# Copy plugin
cp claude-usage.30s.sh ~/Library/Application\ Support/xbar/plugins/
chmod +x ~/Library/Application\ Support/xbar/plugins/claude-usage.30s.sh
```

## File Structure

```
cc-usage-widget/
├── claude-usage.30s.sh   # xbar plugin (main script)
├── install.sh            # Auto-install script
├── README.md             # English
├── docs/
│   └── README.ko.md      # Korean
└── LICENSE
```

## Security

- OAuth tokens are encrypted and stored in macOS Keychain
- Cache only stores usage percentage and reset time (no tokens)
- All API communication uses HTTPS

## License

MIT License - See [LICENSE](LICENSE)
