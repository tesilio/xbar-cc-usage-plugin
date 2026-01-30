#!/bin/bash

# Claude Code Usage Widget - Installer
# This script installs the xbar plugin for monitoring Claude Code usage

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SOURCE="$SCRIPT_DIR/claude-usage.30s.sh"
XBAR_PLUGIN_DIR="$HOME/Library/Application Support/xbar/plugins"

# Print with color
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Check if running on macOS
check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        print_error "This script only supports macOS"
        exit 1
    fi
    print_success "Running on macOS"
}

# Check and install Homebrew
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        print_warning "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add to PATH for Apple Silicon
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
    print_success "Homebrew is installed"
}

# Install dependencies
install_dependencies() {
    local missing_deps=()

    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if ! command -v bc &> /dev/null; then
        missing_deps+=("bc")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_info "Installing dependencies: ${missing_deps[*]}"
        brew install "${missing_deps[@]}"
    fi

    print_success "Dependencies installed (jq, bc)"
}

# Check if xbar is installed
check_xbar() {
    if ! [[ -d "/Applications/xbar.app" ]] && ! [[ -d "$HOME/Applications/xbar.app" ]]; then
        print_warning "xbar is not installed"
        echo ""
        echo "Please install xbar first:"
        echo "  brew install --cask xbar"
        echo "  or download from: https://xbarapp.com"
        echo ""
        read -p "Would you like to install xbar via Homebrew? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            brew install --cask xbar
            print_success "xbar installed"
        else
            print_error "xbar is required. Please install it and run this script again."
            exit 1
        fi
    else
        print_success "xbar is installed"
    fi
}

# Create xbar plugin directory if needed
create_plugin_dir() {
    if [[ ! -d "$XBAR_PLUGIN_DIR" ]]; then
        print_info "Creating xbar plugin directory..."
        mkdir -p "$XBAR_PLUGIN_DIR"
    fi
    print_success "Plugin directory exists: $XBAR_PLUGIN_DIR"
}

# Check if source file exists
check_source() {
    if [[ ! -f "$PLUGIN_SOURCE" ]]; then
        print_error "Plugin source not found: $PLUGIN_SOURCE"
        exit 1
    fi
    print_success "Plugin source found"
}

# Install the plugin
install_plugin() {
    local dest="$XBAR_PLUGIN_DIR/claude-usage.30s.sh"

    # Check if already installed
    if [[ -f "$dest" ]] || [[ -L "$dest" ]]; then
        print_warning "Plugin already exists at destination"
        read -p "Overwrite? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled"
            exit 0
        fi
        rm -f "$dest"
    fi

    # Copy the plugin
    cp "$PLUGIN_SOURCE" "$dest"
    chmod +x "$dest"

    print_success "Plugin installed to: $dest"
}

# Check Claude Code credentials
check_credentials() {
    # Check Keychain
    if /usr/bin/security find-generic-password -s "Claude Code-credentials" &> /dev/null; then
        print_success "Claude Code credentials found in Keychain"
        return 0
    fi

    # Check file fallback
    if [[ -f "$HOME/.claude/.credentials.json" ]]; then
        print_success "Claude Code credentials found in file"
        return 0
    fi

    print_warning "Claude Code credentials not found"
    echo "  Please run 'claude' and login first to use this widget"
    return 1
}

# Refresh xbar
refresh_xbar() {
    if pgrep -x "xbar" > /dev/null; then
        print_info "Refreshing xbar..."
        open -g "xbar://app.xbarapp.com/refreshAllPlugins"
        print_success "xbar refreshed"
    else
        print_info "xbar is not running. Please start xbar to see the widget."
    fi
}

# Main installation
main() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║   Claude Code Usage Widget - Installer   ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    check_macos
    check_homebrew
    install_dependencies
    check_xbar
    create_plugin_dir
    check_source
    install_plugin
    check_credentials
    refresh_xbar

    echo ""
    echo "════════════════════════════════════════════"
    print_success "Installation complete!"
    echo ""
    echo "The widget should now appear in your menu bar."
    echo "It shows your Claude Code usage and resets automatically."
    echo ""
}

main "$@"
