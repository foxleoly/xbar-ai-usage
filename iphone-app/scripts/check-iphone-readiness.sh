#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Agent Usage Bridge iPhone readiness"
echo

if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
  echo "FAIL Package.swift not found at $ROOT_DIR"
  exit 1
fi

echo "OK   Swift package found"

if [[ ! -f "$ROOT_DIR/AppHost/AgentUsageBridgeApp.swift" ]]; then
  echo "FAIL AppHost/AgentUsageBridgeApp.swift not found"
  exit 1
fi

echo "OK   iOS app entrypoint template found"

if command -v xed >/dev/null 2>&1; then
  echo "OK   xed found: $(command -v xed)"
else
  echo "WARN xed not found"
fi

developer_dir="$(xcode-select -p 2>/dev/null || true)"
if [[ -z "$developer_dir" ]]; then
  echo "FAIL xcode-select is not configured"
  exit 1
fi

echo "INFO Developer directory: $developer_dir"

if [[ "$developer_dir" == *"CommandLineTools"* ]]; then
  echo "FAIL Full Xcode is not selected. iPhone install requires Xcode, not Command Line Tools."
  echo "NEXT Install/open Xcode, then run:"
  echo "     sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 2
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "FAIL xcodebuild not found"
  exit 1
fi

echo "OK   xcodebuild found"
xcodebuild -version

echo
echo "READY Open this package/project in Xcode and run it on iPhone."
