#!/bin/bash
# Install script for xbar AI Token Usage plugin

set -e

PLUGIN_DIR="$HOME/Library/Application Support/xbar/plugins"
PLUGIN_FILE="opencode-usage.1m.py"
REPO_URL="https://raw.githubusercontent.com"

# Detect GitHub username (can be overridden)
USERNAME="${GITHUB_USER:-foxleoly}"
REPO_NAME="xbar-ai-usage"

echo "Installing xbar-ai-usage plugin..."
echo ""

# Check if xbar is installed
if [ ! -d "/Applications/xbar.app" ] && [ ! -d "$HOME/Applications/xbar.app" ]; then
    echo "⚠️  xbar is not installed!"
    echo ""
    echo "Please install xbar first:"
    echo "  brew install --cask xbar"
    echo ""
    echo "Or download from: https://xbarapp.com"
    exit 1
fi

# Check xbar plugins directory
if [ ! -d "$PLUGIN_DIR" ]; then
    echo "Creating xbar plugins directory..."
    mkdir -p "$PLUGIN_DIR"
fi

# Download plugin
echo "Downloading plugin..."
curl -sSL "$REPO_URL/$USERNAME/$REPO_NAME/master/opencode-usage.1m.py" -o "$PLUGIN_DIR/$PLUGIN_FILE"

# Make executable
chmod +x "$PLUGIN_DIR/$PLUGIN_FILE"

echo ""
echo "✅ Plugin installed to: $PLUGIN_DIR/$PLUGIN_FILE"
echo ""
echo "Refresh xbar to see the plugin in action!"
echo "If xbar is running, you can refresh it with: open -a xbar"
