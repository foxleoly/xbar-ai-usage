import Foundation

public struct UsageSnapshotBuilder {
    private let now: Date
    private let calendar: Calendar

    public init(now: Date = Date(), calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    public func build(agentID: String, agentName: String, rollouts: [RolloutUsage]) -> AgentUsageSnapshot {
        let filtered = rollouts.filter { $0.agentID == agentID }
        let h5Start = now.addingTimeInterval(-5 * 60 * 60)
        let todayStart = calendar.startOfDay(for: now)
        let d7Start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let d30Start = calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart

        let windows = UsageWindows(
            h5: aggregate(filtered, since: h5Start),
            today: aggregate(filtered, since: todayStart),
            d7: aggregate(filtered, since: d7Start),
            d30: aggregate(filtered, since: d30Start)
        )

        let status = windows.d30.total > 0 ? "active" : "unavailable"
        return AgentUsageSnapshot(
            kind: "agent_usage_snapshot",
            version: 1,
            updatedAt: now,
            agents: [
                AgentUsage(id: agentID, name: agentName, source: agentID, status: status, windows: windows)
            ]
        )
    }

    private func aggregate(_ rollouts: [RolloutUsage], since start: Date) -> TokenUsage {
        rollouts
            .filter { $0.updatedAt >= start && $0.updatedAt <= now }
            .reduce(into: .zero) { partial, rollout in
                partial.add(rollout.usage)
            }
    }
}
