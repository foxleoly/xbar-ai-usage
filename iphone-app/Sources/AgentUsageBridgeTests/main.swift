import AgentUsageBridgeCore
import Foundation

@discardableResult
func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
    return true
}

func testFormatsTokenCountsForCompactUI() {
    expect(TokenCountFormatter.compact(999) == "999", "formats sub-thousand count")
    expect(TokenCountFormatter.compact(1_200) == "1.2K", "formats thousand count")
    expect(TokenCountFormatter.compact(8_100_241) == "8.1M", "formats million count")
}

func testBuildsSimpleBridgeStateFromSnapshot() throws {
    let snapshot = AgentUsageSnapshot(
        kind: "agent_usage_snapshot",
        version: 1,
        updatedAt: Date(timeIntervalSince1970: 1_779_190_307),
        agents: [
            AgentUsage(
                id: "codex",
                name: "Codex",
                source: "codex",
                status: "active",
                windows: UsageWindows(
                    h5: TokenUsage(total: 8_100_241, input: 8_049_731, output: 50_510, cache: 7_583_488, reasoning: 13_445),
                    today: TokenUsage(total: 8_100_241, input: 8_049_731, output: 50_510, cache: 7_583_488, reasoning: 13_445),
                    d7: TokenUsage(total: 20_767_375, input: 20_682_736, output: 84_639, cache: 19_344_384, reasoning: 20_767),
                    d30: TokenUsage(total: 77_076_451, input: 76_499_079, output: 250_603, cache: 71_767_424, reasoning: 52_320)
                ),
                rateLimits: AgentRateLimits(
                    primary: AgentRateLimitWindow(usedPercent: 22, windowMinutes: 300, resetsAt: Date(timeIntervalSince1970: 1_779_511_370)),
                    secondary: AgentRateLimitWindow(usedPercent: 46, windowMinutes: 10_080, resetsAt: Date(timeIntervalSince1970: 1_779_838_670))
                )
            )
        ]
    )

    let state = BridgeState.connected(snapshot: snapshot, watchSyncedAt: snapshot.updatedAt.addingTimeInterval(1))

    expect(state.macStatus == .connected, "mac status connected")
    expect(state.watchStatus == .synced, "watch status synced")
    expect(state.agents.count == 1, "agent count")
    expect(state.agents[0].todayTotalText == "8.1M", "agent today total text")
    expect(state.agents[0].limitText == "78% / 54%", "agent remaining limit text")
    expect(state.agents[0].displayStatus == "Active", "agent display status")
}

func testDecodesDaemonPayload() throws {
    let json = """
    {
      "kind": "agent_usage_snapshot",
      "version": 1,
      "updatedAt": "2026-05-19T11:38:27Z",
      "agents": [
        {
          "id": "codex",
          "name": "Codex",
          "source": "codex",
          "status": "active",
          "rateLimits": {
            "primary": { "usedPercent": 22, "windowMinutes": 300, "resetsAt": "2026-05-23T00:42:50Z" },
            "secondary": { "usedPercent": 46, "windowMinutes": 10080, "resetsAt": "2026-05-26T19:57:50Z" }
          },
          "windows": {
            "h5": { "cache": 7583488, "input": 8049731, "output": 50510, "reasoning": 13445, "total": 8100241 },
            "today": { "cache": 7583488, "input": 8049731, "output": 50510, "reasoning": 13445, "total": 8100241 },
            "d7": { "cache": 19344384, "input": 20682736, "output": 84639, "reasoning": 20767, "total": 20767375 },
            "d30": { "cache": 71767424, "input": 76499079, "output": 250603, "reasoning": 52320, "total": 77076451 }
          }
        }
      ]
    }
    """

    let snapshot = try AgentUsageSnapshotDecoder().decode(Data(json.utf8))

    expect(snapshot.kind == "agent_usage_snapshot", "decoded kind")
    expect(snapshot.agents.first?.id == "codex", "decoded agent id")
    expect(snapshot.agents.first?.windows.today.total == 8_100_241, "decoded today total")
    expect(snapshot.agents.first?.rateLimits?.primary?.usedPercent == 22, "decoded primary rate limit")
    expect(snapshot.agents.first?.rateLimits?.primary?.remainingPercent == 78, "decoded primary remaining")
    expect(snapshot.agents.first?.rateLimits?.secondary?.windowMinutes == 10_080, "decoded secondary window")
}

func testReassemblesBLEWireChunksOutOfOrder() throws {
    let payload = Data("hello-from-mac".utf8)
    var reassembler = BLEPayloadReassembler()

    let first = makeWireChunk(messageID: 42, index: 0, count: 2, payload: Data("hello-".utf8))
    let second = makeWireChunk(messageID: 42, index: 1, count: 2, payload: Data("from-mac".utf8))

    let incomplete = try reassembler.receive(second)
    let complete = try reassembler.receive(first)

    expect(incomplete == nil, "second chunk waits for first chunk")
    expect(complete == payload, "chunks reassemble in index order")
}

func testRejectsInvalidBLEWireChunkHeader() throws {
    var reassembler = BLEPayloadReassembler()

    do {
        _ = try reassembler.receive(Data([0x00, 0x55, 0x01, 0, 1, 0, 0, 0, 1]))
        expect(false, "invalid magic should throw")
    } catch BLEPayloadReassemblerError.invalidMagic {
    }

    do {
        _ = try reassembler.receive(Data([0x41, 0x55, 0x01, 0, 1, 0, 2, 0, 2]))
        expect(false, "invalid chunk index should throw")
    } catch BLEPayloadReassemblerError.invalidChunkIndex {
    }
}

func testPersistsLatestSnapshotAndAppendsJSONLLogs() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("agent-usage-bridge-tests-\(UUID().uuidString)", isDirectory: true)
    let persistence = BridgePersistence(rootDirectory: root)
    let snapshot = MockData.codexSnapshot

    try persistence.saveLatestSnapshot(snapshot)
    try persistence.appendLog(.snapshotReceived(at: snapshot.updatedAt, agentCount: snapshot.agents.count))
    try persistence.appendLog(.watchSyncSucceeded(at: snapshot.updatedAt.addingTimeInterval(1)))

    let loaded = try persistence.loadLatestSnapshot()
    let logs = try persistence.loadLogs()

    expect(loaded?.agents.first?.id == "codex", "persisted snapshot agent id")
    expect(logs.count == 2, "persisted log count")
    expect(logs[0].kind == "snapshot_received", "first persisted log kind")
    expect(logs[0].agentCount == 3, "first persisted log agent count")
    expect(logs[1].kind == "watch_sync_succeeded", "second persisted log kind")
}

func testMockDataIncludesSampleUsageForAllAgents() {
    let agents = MockData.codexSnapshot.agents
    let claude = agents.first { $0.id == "claude_code" }
    let opencode = agents.first { $0.id == "opencode" }

    expect(agents.count == 3, "mock data agent count")
    expect(claude?.status == "active", "claude code sample status")
    expect(claude?.windows.today.total == 5_928_640, "claude code sample today total")
    expect(opencode?.status == "active", "opencode sample status")
    expect(opencode?.windows.d30.total == 22_418_760, "opencode sample d30 total")
}

func testInvalidCachedSnapshotReturnsNilAndLeavesLogsReadable() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("agent-usage-bridge-tests-\(UUID().uuidString)", isDirectory: true)
    let persistence = BridgePersistence(rootDirectory: root)

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("not-json".utf8).write(to: root.appendingPathComponent("latest-snapshot.json"))
    try persistence.appendLog(.macDisconnected(at: Date(timeIntervalSince1970: 1_779_190_400), reason: "BLE unavailable"))

    let loaded = try persistence.loadLatestSnapshot()
    let logs = try persistence.loadLogs()

    expect(loaded == nil, "invalid cached snapshot should return nil")
    expect(logs.count == 2, "logs include original event and cache failure event")
    expect(logs[0].kind == "mac_disconnected", "mac disconnected log kind")
    expect(logs[0].message == "BLE unavailable", "mac disconnected log message")
    expect(logs[1].kind == "cache_load_failed", "cache failure log kind")
}

func makeWireChunk(messageID: UInt16, index: UInt16, count: UInt16, payload: Data) -> Data {
    var data = Data(BLEUsageWire.magic)
    data.append(BLEUsageWire.version)
    data.appendUInt16(messageID)
    data.appendUInt16(index)
    data.appendUInt16(count)
    data.append(payload)
    return data
}

extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }
}

do {
    testFormatsTokenCountsForCompactUI()
    try testBuildsSimpleBridgeStateFromSnapshot()
    try testDecodesDaemonPayload()
    try testReassemblesBLEWireChunksOutOfOrder()
    try testRejectsInvalidBLEWireChunkHeader()
    try testPersistsLatestSnapshotAndAppendsJSONLLogs()
    testMockDataIncludesSampleUsageForAllAgents()
    try testInvalidCachedSnapshotReturnsNilAndLeavesLogsReadable()
    print("All agent-usage bridge tests passed")
} catch {
    FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
    exit(1)
}
