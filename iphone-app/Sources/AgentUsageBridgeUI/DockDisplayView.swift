import AgentUsageBridgeCore
import SwiftUI

public struct DockDisplayView: View {
    let state: BridgeState

    @Environment(\.dismiss) private var dismiss
    @State private var selectedWindow: UsageWindow = .today

    public init(state: BridgeState) {
        self.state = state
    }

    public var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            ZStack {
                DockPalette.background.ignoresSafeArea()
                if isLandscape {
                    landscapeLayout
                        .padding(.horizontal, 28)
                        .padding(.vertical, 18)
                } else {
                    portraitLayout
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var portraitLayout: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            windowPicker
            totalPanel
            activityPanel
            agentStack
            Spacer(minLength: 0)
        }
    }

    private var landscapeLayout: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                header
                windowPicker
                totalPanel
                activityPanel
            }
            .frame(maxWidth: 420, alignment: .leading)

            VStack(spacing: 12) {
                ForEach(agentDisplays) { agent in
                    AgentDockCard(agent: agent, compact: true)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TokenDock")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.11), in: Circle())
            }
            .accessibilityLabel("Close Dock Display")
        }
    }

    private var windowPicker: some View {
        HStack(spacing: 8) {
            ForEach(UsageWindow.allCases) { window in
                Button {
                    selectedWindow = window
                } label: {
                    Text(window.title)
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(selectedWindow == window ? DockPalette.background : .white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedWindow == window ? .white : .white.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var totalPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TOTAL TOKENS")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.50))
                Spacer()
                Text(selectedWindow.caption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.54))
            }

            Text(TokenCountFormatter.compact(totalUsage.total))
                .font(.system(size: 72, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            HStack(spacing: 14) {
                DockMiniMetric(label: "Input", value: totalUsage.input)
                DockMiniMetric(label: "Output", value: totalUsage.output)
                DockMiniMetric(label: "Cache", value: totalUsage.cache)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [DockPalette.codex.opacity(0.28), .white.opacity(0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var activityPanel: some View {
        let primary = agentDisplays.first ?? AgentDockDisplay.placeholder
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("ACTIVE TASK")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.50))
                Spacer()
                Text("\(primary.progressPercent)%")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(primary.color)
            }

            Text(primary.taskTitle)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            DockProgressBar(progress: primary.progress, color: primary.color)
                .frame(height: 7)
        }
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var agentStack: some View {
        VStack(spacing: 12) {
            ForEach(agentDisplays) { agent in
                AgentDockCard(agent: agent, compact: false)
            }
        }
    }

    private var statusLine: String {
        let watch = state.watchStatus == .synced ? "Watch synced" : "Watch waiting"
        return "\(state.macStatus.title) · \(watch)"
    }

    private var totalUsage: TokenUsage {
        dockAgents
            .map { selectedWindow.usage(from: $0.windows) }
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

    private var agentDisplays: [AgentDockDisplay] {
        dockAgents.enumerated().map { index, agent in
            let usage = selectedWindow.usage(from: agent.windows)
            let brand = AgentBrand(agentID: agent.id, fallbackIndex: index)
            return AgentDockDisplay(
                id: agent.id,
                name: agent.name,
                usage: usage,
                color: brand.color,
                taskTitle: brand.taskTitle,
                progress: brand.progress
            )
        }
    }

    private var dockAgents: [AgentSummary] {
        var agents = state.agents
        let existingIDs = Set(agents.map(\.id))
        let supplementalAgents = MockData.codexSnapshot.agents
            .filter { ["claude_code", "opencode"].contains($0.id) }
            .filter { !existingIDs.contains($0.id) }
            .map {
                AgentSummary(
                    id: $0.id,
                    name: $0.name,
                    status: $0.status,
                    windows: $0.windows,
                    rateLimits: $0.rateLimits
                )
            }
        agents.append(contentsOf: supplementalAgents)
        return agents
    }
}

private struct DockMiniMetric: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.44))
            Text(TokenCountFormatter.compact(value))
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AgentDockCard: View {
    let agent: AgentDockDisplay
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(agent.color)
                        .frame(width: 9, height: 9)
                    Text(agent.name)
                        .font(.system(compact ? .subheadline : .headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer(minLength: 10)
                Text(TokenCountFormatter.compact(agent.usage.total))
                    .font(.system(compact ? .title3 : .title2, design: .rounded).weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(agent.taskTitle)
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)

            DockProgressBar(progress: agent.progress, color: agent.color, subdued: compact)
                .frame(height: compact ? 4 : 6)

            HStack {
                Text("Progress")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.42))
                Spacer()
                Text("\(agent.progressPercent)%")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(agent.color)
            }
        }
        .padding(compact ? 12 : 14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(agent.color.opacity(0.32), lineWidth: 1)
        )
    }
}

private struct DockProgressBar: View {
    let progress: Double
    let color: Color
    var subdued = false

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(subdued ? DockPalette.progressTrack : .white.opacity(0.18))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                subdued ? DockPalette.progressFillStart : color,
                                subdued ? DockPalette.progressFillEnd : color.opacity(0.86)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * clampedProgress)
            }
        }
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((clampedProgress * 100).rounded())) percent")
    }
}

private enum UsageWindow: String, CaseIterable, Identifiable {
    case h5
    case today
    case d7
    case d30

    var id: String { rawValue }

    var title: String {
        switch self {
        case .h5: "5H"
        case .today: "Today"
        case .d7: "7D"
        case .d30: "30D"
        }
    }

    var caption: String {
        switch self {
        case .h5: "Rolling window"
        case .today: "Local day"
        case .d7: "Last 7 days"
        case .d30: "Last 30 days"
        }
    }

    func usage(from windows: UsageWindows) -> TokenUsage {
        switch self {
        case .h5: windows.h5
        case .today: windows.today
        case .d7: windows.d7
        case .d30: windows.d30
        }
    }
}

private struct AgentDockDisplay: Identifiable {
    let id: String
    let name: String
    let usage: TokenUsage
    let color: Color
    let taskTitle: String
    let progress: Double

    var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    static let placeholder = AgentDockDisplay(
        id: "placeholder",
        name: "TokenDock",
        usage: .zero,
        color: DockPalette.codex,
        taskTitle: "Waiting for active task",
        progress: 0
    )
}

private struct AgentBrand {
    let color: Color
    let taskTitle: String
    let progress: Double

    init(agentID: String, fallbackIndex: Int) {
        switch agentID {
        case "codex":
            color = DockPalette.codex
            taskTitle = "Implement BLE usage bridge"
            progress = 0.74
        case "claude_code":
            color = DockPalette.claude
            taskTitle = "Review WatchConnectivity plan"
            progress = 0.58
        case "opencode":
            color = DockPalette.opencode
            taskTitle = "Prototype dock display polish"
            progress = 0.41
        default:
            color = DockPalette.fallbacks[fallbackIndex % DockPalette.fallbacks.count]
            taskTitle = "Active coding session"
            progress = 0.50
        }
    }
}

private enum DockPalette {
    static let background = Color(red: 0.018, green: 0.022, blue: 0.024)
    static let codex = Color(red: 0.00, green: 0.78, blue: 0.58)
    static let claude = Color(red: 0.85, green: 0.42, blue: 0.18)
    static let opencode = Color(red: 0.13, green: 0.77, blue: 0.37)
    static let progressTrack = Color(red: 0.10, green: 0.12, blue: 0.15)
    static let progressFillStart = Color(red: 0.22, green: 0.30, blue: 0.38)
    static let progressFillEnd = Color(red: 0.15, green: 0.21, blue: 0.28)
    static let fallbacks: [Color] = [.cyan, .purple, .yellow]
}
