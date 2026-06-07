import Foundation

public struct AgentUsageCollector {
    private let codexCollector: CodexUsageCollector
    private let claudeCollector: ClaudeCodeUsageCollector
    private let openCodeCollector: OpenCodeUsageCollector

    public init(
        codexCollector: CodexUsageCollector,
        claudeCollector: ClaudeCodeUsageCollector = ClaudeCodeUsageCollector(),
        openCodeCollector: OpenCodeUsageCollector = OpenCodeUsageCollector()
    ) {
        self.codexCollector = codexCollector
        self.claudeCollector = claudeCollector
        self.openCodeCollector = openCodeCollector
    }

    public func snapshot(now: Date = Date(), calendar: Calendar = .current) throws -> AgentUsageSnapshot {
        var agents = try codexCollector.snapshot(now: now, calendar: calendar).agents

        agents.append((try? claudeCollector.agent(now: now, calendar: calendar)) ?? .unavailable(
            id: "claude_code",
            name: "Claude Code",
            source: "claude_code"
        ))
        agents.append((try? openCodeCollector.agent(now: now, calendar: calendar)) ?? .unavailable(
            id: "opencode",
            name: "OpenCode",
            source: "opencode"
        ))

        return AgentUsageSnapshot(
            kind: "agent_usage_snapshot",
            version: 1,
            updatedAt: now,
            agents: agents
        )
    }
}

private extension AgentUsage {
    static func unavailable(id: String, name: String, source: String) -> AgentUsage {
        AgentUsage(
            id: id,
            name: name,
            source: source,
            status: "unavailable",
            windows: UsageWindows(h5: .zero, today: .zero, d7: .zero, d30: .zero)
        )
    }
}
