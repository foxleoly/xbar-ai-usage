import AgentUsageMacDaemon
import Foundation

@discardableResult
func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
    return true
}

func require<T>(_ value: T?, _ message: String) -> T {
    guard let value else {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
    return value
}

struct StubThreadIndex: ThreadIndex {
    var rows: [ThreadRecord]

    func records(updatedSince cutoff: Date) throws -> [ThreadRecord] {
        rows.filter { $0.updatedAt >= cutoff }
    }
}

func makeTempRollout(_ lines: [String]) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("agent-usage-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("rollout.jsonl")
    try lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
    return file
}

func tokenCountLine(
    timestamp: String,
    total: Int,
    input: Int,
    output: Int,
    cache: Int,
    reasoning: Int,
    primaryUsed: Double? = nil,
    secondaryUsed: Double? = nil
) -> String {
    let rateLimits: String
    if let primaryUsed, let secondaryUsed {
        rateLimits = """
        ,"rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":\(primaryUsed),"window_minutes":300,"resets_at":1779511370},"secondary":{"used_percent":\(secondaryUsed),"window_minutes":10080,"resets_at":1779838670},"credits":{"has_credits":false,"unlimited":false,"balance":null},"plan_type":null,"rate_limit_reached_type":null}
        """
    } else {
        rateLimits = ""
    }

    return """
    {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":\(input),"cached_input_tokens":\(cache),"output_tokens":\(output),"reasoning_output_tokens":\(reasoning),"total_tokens":\(total)},"last_token_usage":{"input_tokens":0,"cached_input_tokens":0,"output_tokens":0,"reasoning_output_tokens":0,"total_tokens":0},"model_context_window":258400}\(rateLimits)}}
    """
}

func testCodexSnapshotUsesTokenCountDeltasInsideWindows() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    let now = require(calendar.date(from: DateComponents(
        timeZone: TimeZone(secondsFromGMT: 0),
        year: 2026,
        month: 5,
        day: 19,
        hour: 17,
        minute: 30
    )), "test date should be constructible")

    let rollout = try makeTempRollout([
        tokenCountLine(timestamp: "2026-05-19T11:00:00.000Z", total: 1_000, input: 800, output: 150, cache: 300, reasoning: 50),
        tokenCountLine(timestamp: "2026-05-19T13:00:00.000Z", total: 1_250, input: 1_000, output: 190, cache: 380, reasoning: 60),
        tokenCountLine(timestamp: "2026-05-19T13:05:00.000Z", total: 1_250, input: 1_000, output: 190, cache: 380, reasoning: 60),
        tokenCountLine(timestamp: "2026-05-19T16:00:00.000Z", total: 1_500, input: 1_200, output: 240, cache: 450, reasoning: 60)
    ])

    let collector = CodexUsageCollector(threadIndex: StubThreadIndex(rows: [
        ThreadRecord(rolloutPath: rollout, updatedAt: now.addingTimeInterval(-60))
    ]))

    let snapshot = try collector.snapshot(now: now, calendar: calendar)
    let agent = require(snapshot.agents.first, "snapshot should contain Codex agent")

    expect(agent.windows.h5.total == 500, "5-hour total should use deltas, not cumulative thread total")
    expect(agent.windows.h5.input == 400, "5-hour input delta")
    expect(agent.windows.h5.output == 90, "5-hour output delta")
    expect(agent.windows.h5.cache == 150, "5-hour cache delta")
    expect(agent.windows.h5.reasoning == 10, "5-hour reasoning delta")
}

func testCodexSnapshotIncludesLatestRateLimits() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    let now = require(calendar.date(from: DateComponents(
        timeZone: TimeZone(secondsFromGMT: 0),
        year: 2026,
        month: 5,
        day: 19,
        hour: 17,
        minute: 30
    )), "test date should be constructible")

    let rollout = try makeTempRollout([
        tokenCountLine(timestamp: "2026-05-19T13:00:00.000Z", total: 1_250, input: 1_000, output: 190, cache: 380, reasoning: 60, primaryUsed: 11, secondaryUsed: 32),
        tokenCountLine(timestamp: "2026-05-19T16:00:00.000Z", total: 1_500, input: 1_200, output: 240, cache: 450, reasoning: 60, primaryUsed: 23, secondaryUsed: 46)
    ])

    let collector = CodexUsageCollector(threadIndex: StubThreadIndex(rows: [
        ThreadRecord(rolloutPath: rollout, updatedAt: now.addingTimeInterval(-60))
    ]))

    let snapshot = try collector.snapshot(now: now, calendar: calendar)
    let limits = require(snapshot.agents.first?.rateLimits, "snapshot should include Codex rate limits")

    expect(limits.primary?.usedPercent == 23, "latest primary used percent")
    expect(limits.primary?.windowMinutes == 300, "primary window minutes")
    expect(limits.primary?.resetsAt == Date(timeIntervalSince1970: 1_779_511_370), "primary reset date")
    expect(limits.secondary?.usedPercent == 46, "latest secondary used percent")
    expect(limits.secondary?.windowMinutes == 10_080, "secondary window minutes")
}

func testAggregatesCodexRolloutsIntoFourWindows() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    let now = require(calendar.date(from: DateComponents(
        timeZone: TimeZone(secondsFromGMT: 0),
        year: 2026,
        month: 5,
        day: 19,
        hour: 17,
        minute: 30
    )), "test date should be constructible")

    let recent = RolloutUsage(
        agentID: "codex",
        updatedAt: now.addingTimeInterval(-2 * 60 * 60),
        usage: TokenUsage(total: 100, input: 70, output: 20, cache: 8, reasoning: 2)
    )
    let earlierToday = RolloutUsage(
        agentID: "codex",
        updatedAt: now.addingTimeInterval(-8 * 60 * 60),
        usage: TokenUsage(total: 50, input: 30, output: 10, cache: 9, reasoning: 1)
    )
    let lastWeek = RolloutUsage(
        agentID: "codex",
        updatedAt: now.addingTimeInterval(-3 * 24 * 60 * 60),
        usage: TokenUsage(total: 25, input: 20, output: 3, cache: 2, reasoning: 0)
    )
    let lastMonthWindow = RolloutUsage(
        agentID: "codex",
        updatedAt: now.addingTimeInterval(-20 * 24 * 60 * 60),
        usage: TokenUsage(total: 10, input: 8, output: 1, cache: 1, reasoning: 0)
    )

    let snapshot = UsageSnapshotBuilder(now: now, calendar: calendar)
        .build(agentID: "codex", agentName: "Codex", rollouts: [
            recent,
            earlierToday,
            lastWeek,
            lastMonthWindow
        ])

    let agent = require(snapshot.agents.first, "snapshot should contain Codex agent")
    expect(agent.id == "codex", "agent id")
    expect(agent.name == "Codex", "agent name")
    expect(agent.windows.h5.total == 100, "5-hour total")
    expect(agent.windows.today.total == 150, "today total")
    expect(agent.windows.d7.total == 175, "7-day total")
    expect(agent.windows.d30.total == 185, "30-day total")
    expect(agent.windows.today.input == 100, "today input")
    expect(agent.windows.today.output == 30, "today output")
    expect(agent.windows.today.cache == 17, "today cache")
    expect(agent.windows.today.reasoning == 3, "today reasoning")
}

func testEncodesStableMultiAgentPayloadShape() throws {
    let updatedAt = Date(timeIntervalSince1970: 1_779_190_200)
    let snapshot = AgentUsageSnapshot(
        kind: "agent_usage_snapshot",
        version: 1,
        updatedAt: updatedAt,
        agents: [
            AgentUsage(
                id: "codex",
                name: "Codex",
                source: "codex",
                status: "active",
                windows: UsageWindows(
                    h5: TokenUsage(total: 1, input: 2, output: 3, cache: 4, reasoning: 5),
                    today: .zero,
                    d7: .zero,
                    d30: .zero
                )
            )
        ]
    )

    let encoded = try SnapshotEncoder().encode(snapshot)
    let object = require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any], "encoded snapshot should be JSON object")
    let agents = require(object["agents"] as? [[String: Any]], "encoded snapshot should include agents array")
    let codex = require(agents.first, "encoded snapshot should include first agent")
    let windows = require(codex["windows"] as? [String: Any], "encoded agent should include windows")

    expect(object["kind"] as? String == "agent_usage_snapshot", "payload kind")
    expect(object["version"] as? Int == 1, "payload version")
    expect(codex["id"] as? String == "codex", "agent id in payload")
    expect(windows["h5"] != nil, "payload h5 window")
    expect(windows["today"] != nil, "payload today window")
    expect(windows["d7"] != nil, "payload d7 window")
    expect(windows["d30"] != nil, "payload d30 window")
}

func testSplitsPayloadIntoReassemblableChunks() throws {
    let payload = Data((0..<25).map { UInt8($0) })
    let chunker = BLEPayloadChunker(maximumChunkSize: 8)

    let chunks = try chunker.chunks(for: payload, messageID: 42)

    expect(chunks.count == 4, "chunk count")
    expect(chunks.map(\.messageID) == [42, 42, 42, 42], "message ids")
    expect(chunks.map(\.index) == [0, 1, 2, 3], "chunk indexes")
    expect(chunks.map(\.count) == [4, 4, 4, 4], "chunk counts")
    expect(Data(chunks.flatMap(\.payload)) == payload, "reassembled payload")
}

func testRejectsChunkSizeTooSmallForHeader() throws {
    do {
        _ = try BLEPayloadChunker(maximumChunkSize: 8).wireChunks(for: Data([1]), messageID: 1)
        expect(false, "wire chunker should reject too-small maximum size")
    } catch BLEPayloadChunkerError.maximumChunkSizeTooSmall {
        expect(true, "wire chunker rejected too-small maximum size")
    }
}

func testEncodesWireChunkHeader() throws {
    let payload = Data([0xAA, 0xBB, 0xCC])
    let chunker = BLEPayloadChunker(maximumChunkSize: 16)

    let chunks = try chunker.wireChunks(for: payload, messageID: 7)

    expect(chunks.count == 1, "wire chunk count")
    expect(Array(chunks[0].prefix(2)) == [0x41, 0x55], "wire magic")
    expect(chunks[0][2] == 1, "wire version")
    expect(chunks[0][3] == 0, "message high byte")
    expect(chunks[0][4] == 7, "message low byte")
    expect(chunks[0][5] == 0, "index high byte")
    expect(chunks[0][6] == 0, "index low byte")
    expect(chunks[0][7] == 0, "count high byte")
    expect(chunks[0][8] == 1, "count low byte")
    expect(Data(chunks[0].suffix(3)) == payload, "wire payload")
}

do {
    try testCodexSnapshotUsesTokenCountDeltasInsideWindows()
    try testCodexSnapshotIncludesLatestRateLimits()
    try testAggregatesCodexRolloutsIntoFourWindows()
    try testEncodesStableMultiAgentPayloadShape()
    try testSplitsPayloadIntoReassemblableChunks()
    try testRejectsChunkSizeTooSmallForHeader()
    try testEncodesWireChunkHeader()
    print("All agent-usage tests passed")
} catch {
    FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
    exit(1)
}
