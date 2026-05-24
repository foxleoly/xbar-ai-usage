import Foundation

public struct ClaudeCodeUsageCollector {
    private let projectsURL: URL
    private let fileManager: FileManager

    public init(
        projectsURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.projectsURL = projectsURL
        self.fileManager = fileManager
    }

    public func agent(now: Date = Date(), calendar: Calendar = .current) throws -> AgentUsage {
        let samples = try tokenUsageSamples()
        let windows = UsageWindowAggregator(now: now, calendar: calendar).windows(for: samples)
        let status = windows.d30.total > 0 ? "active" : "unavailable"

        return AgentUsage(
            id: "claude_code",
            name: "Claude Code",
            source: "claude_code",
            status: status,
            windows: windows
        )
    }

    private func tokenUsageSamples() throws -> [TimedTokenUsage] {
        guard fileManager.fileExists(atPath: projectsURL.path) else {
            return []
        }

        guard let enumerator = fileManager.enumerator(
            at: projectsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var samples: [TimedTokenUsage] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
            samples.append(contentsOf: try Self.samples(in: fileURL))
        }
        return samples
    }

    private static func samples(in fileURL: URL) throws -> [TimedTokenUsage] {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        var samples: [TimedTokenUsage] = []

        for line in content.split(whereSeparator: \.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["type"] as? String == "assistant",
                  let timestampString = object["timestamp"] as? String,
                  let timestamp = AgentUsageDateParser.date(from: timestampString),
                  let message = object["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any]
            else {
                continue
            }

            let input = UsageValue.int(usage["input_tokens"])
            let output = UsageValue.int(usage["output_tokens"])
            let cache = UsageValue.int(usage["cache_read_input_tokens"])
                + UsageValue.int(usage["cache_creation_input_tokens"])
            samples.append(TimedTokenUsage(
                timestamp: timestamp,
                usage: TokenUsage(
                    total: input + output + cache,
                    input: input,
                    output: output,
                    cache: cache,
                    reasoning: 0
                )
            ))
        }

        return samples
    }
}
