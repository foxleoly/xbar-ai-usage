import AgentUsageBridgeCore
import SwiftUI

@main
struct AgentUsageWatchApp: App {
    @StateObject private var store = WatchSnapshotStore()

    var body: some Scene {
        WindowGroup {
            WatchUsagePager(snapshot: store.snapshot)
        }
    }
}

private struct WatchUsagePager: View {
    let snapshot: AgentUsageSnapshot

    var body: some View {
        TabView {
            WatchWindowPage(title: "5H", subtitle: "Rolling", usage: snapshot.totalUsage(\.h5), agents: snapshot.agentRows(\.h5))
            WatchWindowPage(title: "Today", subtitle: "Local day", usage: snapshot.totalUsage(\.today), agents: snapshot.agentRows(\.today))
            WatchWindowPage(title: "7D", subtitle: "Week", usage: snapshot.totalUsage(\.d7), agents: snapshot.agentRows(\.d7))
            WatchWindowPage(title: "30D", subtitle: "Month", usage: snapshot.totalUsage(\.d30), agents: snapshot.agentRows(\.d30))
        }
    }
}

private struct WatchWindowPage: View {
    let title: String
    let subtitle: String
    let usage: TokenUsage
    let agents: [AgentWatchRow]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                totalCard
                breakdown
                agentList
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Spacer()
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("TOTAL")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(TokenCountFormatter.compact(usage.total))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.green.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 5) {
            WatchMetricRow(label: "Input", value: usage.input)
            WatchMetricRow(label: "Output", value: usage.output)
            WatchMetricRow(label: "Cache", value: usage.cache)
            WatchMetricRow(label: "Reason", value: usage.reasoning)
        }
    }

    private var agentList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(agents) { agent in
                HStack {
                    Circle()
                        .fill(agent.color)
                        .frame(width: 7, height: 7)
                    Text(agent.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(TokenCountFormatter.compact(agent.total))
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 2)
    }
}

private struct WatchMetricRow: View {
    let label: String
    let value: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(TokenCountFormatter.compact(value))
                .font(.caption2.monospacedDigit().weight(.semibold))
        }
    }
}

private struct AgentWatchRow: Identifiable {
    let id: String
    let name: String
    let total: Int
    let color: Color
}

private extension AgentUsageSnapshot {
    func totalUsage(_ keyPath: KeyPath<UsageWindows, TokenUsage>) -> TokenUsage {
        agents
            .map { $0.windows[keyPath: keyPath] }
            .reduce(.zero) { partial, usage in
                TokenUsage(
                    total: partial.total + usage.total,
                    input: partial.input + usage.input,
                    output: partial.output + usage.output,
                    cache: partial.cache + usage.cache,
                    reasoning: partial.reasoning + usage.reasoning
                )
            }
    }

    func agentRows(_ keyPath: KeyPath<UsageWindows, TokenUsage>) -> [AgentWatchRow] {
        agents.enumerated().map { index, agent in
            AgentWatchRow(
                id: agent.id,
                name: agent.name,
                total: agent.windows[keyPath: keyPath].total,
                color: [Color.green, Color.cyan, Color.orange][index % 3]
            )
        }
    }
}
