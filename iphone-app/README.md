# Agent Usage Bridge iPhone App

Simple iPhone companion app source for the Agent Usage Watch Bridge.

This package contains the first-pass UI and core state model. It is intentionally small: the iPhone app is a bridge status surface, not the primary dashboard. The Apple Watch remains the main daily display.

## Screens

- Home: Mac connection status, Watch sync status, and agent list.
- Agent detail: 5H, Today, 7D, 30D totals plus today's input/output/cache/reasoning breakdown.

## Current Scope

- Uses mock data for the UI.
- Decodes the same `agent_usage_snapshot` payload emitted by the Mac daemon.
- Keeps the data model multi-agent from day one.
- Persists the latest snapshot to Application Support.
- Appends bridge events to a JSONL log.
- Does not include the BLE Central receiver yet.
- Does not include WatchConnectivity sync yet.
- Does not include a generated Xcode project yet.

## Local Storage

The app stores bridge state under Application Support:

```text
AgentUsageBridge/
  latest-snapshot.json
  bridge-events.jsonl
```

`latest-snapshot.json` keeps the most recent daemon payload so the app can show data after restart. `bridge-events.jsonl` is an append-only event log for receive, sync, disconnect, and cache-load events.

## Commands

Run the no-dependency test runner:

```bash
swift run agent-usage-bridge-tests
```

Build the package:

```bash
swift build
```

## Xcode Integration

Open `AgentUsageBridge.xcodeproj` in Xcode. The project contains a minimal `AgentUsageBridge` iOS app target that uses `AgentUsageBridgeRoot()` as the root view.

See `TESTING_ON_IPHONE.md` for the full manual iPhone testing flow.

## iPhone Readiness Check

Run:

```bash
./scripts/check-iphone-readiness.sh
```

If full Xcode is selected, open the package with:

```bash
./scripts/open-package-in-xcode.sh
```
