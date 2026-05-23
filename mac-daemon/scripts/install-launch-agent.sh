#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$HOME/Library/Application Support/AgentUsageWatchBridge"
PLIST_PATH="$HOME/Library/LaunchAgents/com.foxleoly.agent-usage-daemon.plist"
BUNDLE_PATH="$APP_DIR/TokenDockDaemon.app"
BINARY_PATH="$BUNDLE_PATH/Contents/MacOS/agent-usage-daemon"

cd "$ROOT_DIR"
swift build -c release

mkdir -p "$BUNDLE_PATH/Contents/MacOS" "$BUNDLE_PATH/Contents/Resources"
cp ".build/release/agent-usage-daemon" "$BINARY_PATH"
cp "Sources/AgentUsageDaemon/Info.plist" "$BUNDLE_PATH/Contents/Info.plist"
codesign --force --sign - "$BUNDLE_PATH"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.foxleoly.agent-usage-daemon</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BINARY_PATH</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$APP_DIR/stdout.log</string>
  <key>StandardErrorPath</key>
  <string>$APP_DIR/stderr.log</string>
</dict>
</plist>
PLIST

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo "Installed and loaded $PLIST_PATH"
