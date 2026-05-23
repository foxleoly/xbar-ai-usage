import AgentUsageBridgeCore
import SwiftUI

public struct AgentDetailView: View {
    let agent: AgentSummary
    let updatedAt: Date?

    public init(agent: AgentSummary, updatedAt: Date?) {
        self.agent = agent
        self.updatedAt = updatedAt
    }

    public var body: some View {
        List {
            Section {
                MetricRow(title: "5H", usage: agent.windows.h5)
                MetricRow(title: "Today", usage: agent.windows.today)
                MetricRow(title: "7D", usage: agent.windows.d7)
                MetricRow(title: "30D", usage: agent.windows.d30)
            }

            if let rateLimits = agent.rateLimits {
                Section("Usage Remaining") {
                    if let primary = rateLimits.primary {
                        RateLimitRow(title: "5H Window", window: primary)
                    }
                    if let secondary = rateLimits.secondary {
                        RateLimitRow(title: "7D Window", window: secondary)
                    }
                }
            }

            Section("Today Breakdown") {
                BreakdownRow(title: "Input", value: agent.windows.today.input)
                BreakdownRow(title: "Output", value: agent.windows.today.output)
                BreakdownRow(title: "Cache", value: agent.windows.today.cache)
                BreakdownRow(title: "Reasoning", value: agent.windows.today.reasoning)
            }

            Section {
                HStack {
                    Text("Updated")
                    Spacer()
                    Text(updatedAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? "Waiting")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(agent.name)
    }
}

private struct MetricRow: View {
    let title: String
    let usage: TokenUsage

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(TokenCountFormatter.compact(usage.total))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

private struct RateLimitRow: View {
    let title: String
    let window: AgentRateLimitWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(percentText(window.remainingPercent))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(limitColor)
            }

            ProgressView(value: window.remainingPercent, total: 100)
                .tint(limitColor)

            HStack {
                Text("\(window.windowMinutes / 60)h window")
                Spacer()
                if let resetsAt = window.resetsAt {
                    Text("Resets \(resetsAt.formatted(date: .omitted, time: .shortened))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var limitColor: Color {
        if window.remainingPercent <= 15 {
            return .red
        }
        if window.remainingPercent <= 35 {
            return .orange
        }
        return .teal
    }

    private func percentText(_ value: Double) -> String {
        let rounded = value.rounded()
        if rounded == value {
            return "\(Int(rounded))%"
        }
        return "\(String(format: "%.1f", value))%"
    }
}

private struct BreakdownRow: View {
    let title: String
    let value: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(TokenCountFormatter.compact(value))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
