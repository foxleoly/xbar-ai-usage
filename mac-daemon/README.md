# Agent Usage Mac Daemon

Mac-side daemon for the Agent Usage Watch Bridge.

The daemon reads local Codex token usage, builds a multi-agent usage snapshot, and advertises the snapshot over Bluetooth LE. The first implementation only enables the Codex adapter, but the payload is shaped for multiple agents.

## Scope

- Reads Codex usage from `~/.codex/state_5.sqlite` and rollout JSONL files.
- Produces four windows: rolling 5 hours, today, last 7 days, and last 30 days.
- Encodes a stable `agent_usage_snapshot` JSON payload.
- Exposes a Core Bluetooth peripheral with a custom GATT service.
- Sends payloads through BLE notify chunks.
- Does not expose HTTP, WebSocket, or cloud transport.

## Commands

Run the no-dependency test runner:

```bash
swift run agent-usage-tests
```

Build the daemon:

```bash
swift build
```

Print one payload without starting Bluetooth:

```bash
swift run agent-usage-daemon --print-once
```

Run the daemon in the foreground:

```bash
swift run agent-usage-daemon
```

## BLE Protocol

Service UUID:

```text
8B7D2F4E-9678-4A13-A890-A5E89D7D6C01
```

Snapshot characteristic UUID:

```text
0A5B95C6-20B7-4149-8E26-AB0BD034A07C
```

Each BLE notify value is a chunk:

```text
byte 0..1   magic: 0x41 0x55
byte 2      chunk protocol version: 1
byte 3..4   message id, big endian
byte 5..6   zero-based chunk index, big endian
byte 7..8   chunk count, big endian
byte 9..n   payload bytes
```

The iPhone receiver should group chunks by `message id`, order them by `chunk index`, concatenate payload bytes, and decode the result as JSON.

## Payload Shape

```json
{
  "kind": "agent_usage_snapshot",
  "version": 1,
  "updatedAt": "2026-05-19T11:35:29Z",
  "agents": [
    {
      "id": "codex",
      "name": "Codex",
      "source": "codex",
      "status": "active",
      "windows": {
        "h5": { "total": 1, "input": 1, "output": 0, "cache": 0, "reasoning": 0 },
        "today": { "total": 1, "input": 1, "output": 0, "cache": 0, "reasoning": 0 },
        "d7": { "total": 1, "input": 1, "output": 0, "cache": 0, "reasoning": 0 },
        "d30": { "total": 1, "input": 1, "output": 0, "cache": 0, "reasoning": 0 }
      }
    }
  ]
}
```

