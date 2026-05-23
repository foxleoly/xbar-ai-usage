# Testing on iPhone

This repository currently provides the reusable Swift package and a minimal app entrypoint. The local machine used to prepare this code only has Command Line Tools, so the iOS app bundle must be created and run from a Mac with full Xcode installed.

## Current Test Scope

The iPhone app currently validates:

- The bridge UI renders with mock multi-agent data.
- The app can display Codex, Claude Code, and OpenCode rows.
- The Codex detail screen shows 5H, Today, 7D, and 30D windows.
- The latest snapshot is cached locally.
- Bridge events are appended to a JSONL log.
- Recent logs appear on the home screen.

It does not yet validate real Bluetooth reception or WatchConnectivity sync.

## Open the Xcode Host App

First check whether this Mac can build for iPhone:

```bash
./scripts/check-iphone-readiness.sh
```

If it reports that Command Line Tools are selected, install/open Xcode and select it:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

1. Open `AgentUsageBridge.xcodeproj`.
2. Select the `AgentUsageBridge` scheme.
3. Select your iPhone or an iOS simulator.
4. If running on a physical iPhone, choose your development team in Signing & Capabilities.
5. Build and run.

## Run on iPhone

1. Connect your iPhone or choose a simulator.
2. Select the `AgentUsageBridge` scheme.
3. Build and run.
4. Confirm the home screen shows:
   - Mac: Connected
   - Watch: Synced
   - Codex with a non-zero Today total
   - Claude Code and OpenCode as unavailable
   - Recent Logs, after a snapshot is applied
5. Open Codex and confirm the detail screen shows:
   - 5H
   - Today
   - 7D
   - 30D
   - Input
   - Output
   - Cache
   - Reasoning

## Storage to Inspect

The app writes under Application Support:

```text
AgentUsageBridge/
  latest-snapshot.json
  bridge-events.jsonl
```

On a simulator, use Xcode's container browser or `xcrun simctl get_app_container` to inspect these files.
