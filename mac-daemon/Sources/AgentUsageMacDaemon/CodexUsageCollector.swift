import Foundation

public struct ThreadRecord: Equatable, Sendable {
    public var rolloutPath: URL
    public var updatedAt: Date

    public init(rolloutPath: URL, updatedAt: Date) {
        self.rolloutPath = rolloutPath
        self.updatedAt = updatedAt
    }
}

public protocol ThreadIndex {
    func records(updatedSince cutoff: Date) throws -> [ThreadRecord]
}

public struct CodexUsageCollector {
    private let threadIndex: ThreadIndex
    private let fileManager: FileManager

    public init(threadIndex: ThreadIndex, fileManager: FileManager = .default) {
        self.threadIndex = threadIndex
        self.fileManager = fileManager
    }

    public func rollouts(now: Date = Date()) throws -> [RolloutUsage] {
        let cutoff = now.addingTimeInterval(-30 * 24 * 60 * 60)
        let records = try threadIndex.records(updatedSince: cutoff)

        return records.compactMap { record in
            guard fileManager.fileExists(atPath: record.rolloutPath.path) else {
                return nil
            }

            do {
                guard let usage = try Self.lastTokenUsage(in: record.rolloutPath) else {
                    return nil
                }

                return RolloutUsage(agentID: "codex", updatedAt: record.updatedAt, usage: usage)
            } catch {
                return nil
            }
        }
    }

    public func snapshot(now: Date = Date(), calendar: Calendar = .current) throws -> AgentUsageSnapshot {
        let todayStart = calendar.startOfDay(for: now)
        let d30Start = calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        let records = try threadIndex.records(updatedSince: d30Start)
        var deltas: [TimedTokenUsage] = []
        var rateLimitSamples: [TimedRateLimits] = []

        for record in records where fileManager.fileExists(atPath: record.rolloutPath.path) {
            do {
                deltas.append(contentsOf: try Self.tokenUsageDeltas(in: record.rolloutPath))
                rateLimitSamples.append(contentsOf: try Self.rateLimitSamples(in: record.rolloutPath))
            } catch {
                continue
            }
        }

        let h5Start = now.addingTimeInterval(-5 * 60 * 60)
        let d7Start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let windows = UsageWindows(
            h5: Self.aggregate(deltas, since: h5Start, until: now),
            today: Self.aggregate(deltas, since: todayStart, until: now),
            d7: Self.aggregate(deltas, since: d7Start, until: now),
            d30: Self.aggregate(deltas, since: d30Start, until: now)
        )
        let status = windows.d30.total > 0 ? "active" : "unavailable"

        return AgentUsageSnapshot(
            kind: "agent_usage_snapshot",
            version: 1,
            updatedAt: now,
            agents: [
                AgentUsage(
                    id: "codex",
                    name: "Codex",
                    source: "codex",
                    status: status,
                    windows: windows,
                    rateLimits: rateLimitSamples.max { $0.timestamp < $1.timestamp }?.rateLimits
                )
            ]
        )
    }

    static func lastTokenUsage(in rolloutPath: URL) throws -> TokenUsage? {
        try tokenUsageSamples(in: rolloutPath).last?.usage
    }

    static func tokenUsageDeltas(in rolloutPath: URL) throws -> [TimedTokenUsage] {
        let samples = try tokenUsageSamples(in: rolloutPath).sorted { $0.timestamp < $1.timestamp }
        var previous: TokenUsage?
        var deltas: [TimedTokenUsage] = []

        for sample in samples {
            defer { previous = sample.usage }

            guard let previous else {
                deltas.append(sample)
                continue
            }

            let delta = sample.usage.subtractingFloor(at: previous)
            if delta.total > 0 || delta.input > 0 || delta.output > 0 || delta.cache > 0 || delta.reasoning > 0 {
                deltas.append(TimedTokenUsage(timestamp: sample.timestamp, usage: delta))
            }
        }

        return deltas
    }

    private static func tokenUsageSamples(in rolloutPath: URL) throws -> [TimedTokenUsage] {
        let content = try String(contentsOf: rolloutPath, encoding: .utf8)
        var samples: [TimedTokenUsage] = []

        for line in content.split(whereSeparator: \.isNewline) {
            guard line.contains("token_count"),
                  let data = String(line).data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let timestampString = object["timestamp"] as? String,
                  let timestamp = Self.date(from: timestampString),
                  object["type"] as? String == "event_msg",
                  let payload = object["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let info = payload["info"] as? [String: Any],
                  let totalUsage = info["total_token_usage"] as? [String: Any]
            else {
                continue
            }

            samples.append(TimedTokenUsage(timestamp: timestamp, usage: TokenUsage(
                total: Self.intValue(totalUsage["total_tokens"]),
                input: Self.intValue(totalUsage["input_tokens"]),
                output: Self.intValue(totalUsage["output_tokens"]),
                cache: Self.intValue(totalUsage["cached_input_tokens"]),
                reasoning: Self.intValue(totalUsage["reasoning_output_tokens"])
            )))
        }

        return samples
    }

    private static func rateLimitSamples(in rolloutPath: URL) throws -> [TimedRateLimits] {
        let content = try String(contentsOf: rolloutPath, encoding: .utf8)
        var samples: [TimedRateLimits] = []

        for line in content.split(whereSeparator: \.isNewline) {
            guard line.contains("token_count"),
                  let data = String(line).data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let timestampString = object["timestamp"] as? String,
                  let timestamp = Self.date(from: timestampString),
                  object["type"] as? String == "event_msg",
                  let payload = object["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let rateLimits = payload["rate_limits"] as? [String: Any]
            else {
                continue
            }

            let primary = Self.rateLimitWindow(from: rateLimits["primary"])
            let secondary = Self.rateLimitWindow(from: rateLimits["secondary"])
            if primary != nil || secondary != nil {
                samples.append(TimedRateLimits(
                    timestamp: timestamp,
                    rateLimits: AgentRateLimits(primary: primary, secondary: secondary)
                ))
            }
        }

        return samples
    }

    private static func rateLimitWindow(from value: Any?) -> AgentRateLimitWindow? {
        guard let object = value as? [String: Any] else {
            return nil
        }

        return AgentRateLimitWindow(
            usedPercent: Self.doubleValue(object["used_percent"]),
            windowMinutes: Self.intValue(object["window_minutes"]),
            resetsAt: Self.dateFromUnixSeconds(object["resets_at"])
        )
    }

    private static func aggregate(_ deltas: [TimedTokenUsage], since start: Date, until end: Date) -> TokenUsage {
        deltas
            .filter { $0.timestamp >= start && $0.timestamp <= end }
            .reduce(into: .zero) { partial, sample in
                partial.add(sample.usage)
            }
    }

    private static func date(from string: String) -> Date? {
        let iso8601WithFractions = ISO8601DateFormatter()
        iso8601WithFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601WithFractions.date(from: string) {
            return date
        }
        let iso8601 = ISO8601DateFormatter()
        return iso8601.date(from: string)
    }

    private static func intValue(_ value: Any?) -> Int {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        return 0
    }

    private static func doubleValue(_ value: Any?) -> Double {
        if let value = value as? Double {
            return value
        }
        if let value = value as? Int {
            return Double(value)
        }
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        return 0
    }

    private static func dateFromUnixSeconds(_ value: Any?) -> Date? {
        if let value = value as? Double {
            return Date(timeIntervalSince1970: value)
        }
        if let value = value as? Int {
            return Date(timeIntervalSince1970: TimeInterval(value))
        }
        if let value = value as? NSNumber {
            return Date(timeIntervalSince1970: value.doubleValue)
        }
        return nil
    }
}

private extension TokenUsage {
    func subtractingFloor(at previous: TokenUsage) -> TokenUsage {
        TokenUsage(
            total: max(0, total - previous.total),
            input: max(0, input - previous.input),
            output: max(0, output - previous.output),
            cache: max(0, cache - previous.cache),
            reasoning: max(0, reasoning - previous.reasoning)
        )
    }
}
