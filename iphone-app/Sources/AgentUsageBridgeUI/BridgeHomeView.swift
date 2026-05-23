import AgentUsageBridgeCore
import SwiftUI

public struct BridgeHomeView: View {
    @ObservedObject private var store: BridgeStore
    @State private var isShowingDockDisplay = false

    public init(store: BridgeStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    StatusRow(title: "Mac", value: store.state.macStatus.title, detail: store.state.macName)
                    StatusRow(title: "Watch", value: store.state.watchStatus.title, detail: store.state.watchSyncedAt.map(Self.timeText) ?? "Waiting")
                }

                Section("Agents") {
                    ForEach(store.state.agents) { agent in
                        NavigationLink {
                            AgentDetailView(agent: agent, updatedAt: store.state.updatedAt)
                        } label: {
                            AgentRow(agent: agent)
                        }
                    }
                }

                Section("Dock Display") {
                    Button {
                        isShowingDockDisplay = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Charging Display")
                                    .font(.headline)
                                Text("Full-screen token usage and active task progress.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "display")
                                .foregroundStyle(.teal)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                if !store.logs.isEmpty {
                    Section("Recent Logs") {
                        ForEach(store.logs.suffix(5).reversed(), id: \.at) { log in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(log.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(log.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
            .navigationTitle("TokenDock")
            .toolbar {
                #if os(macOS)
                ToolbarItem {
                    dockDisplayButton
                }
                #else
                ToolbarItem(placement: .topBarTrailing) {
                    dockDisplayButton
                }
                #endif
            }
            #if os(macOS)
            .sheet(isPresented: $isShowingDockDisplay) {
                DockDisplayView(state: store.state)
            }
            #else
            .fullScreenCover(isPresented: $isShowingDockDisplay) {
                DockDisplayView(state: store.state)
            }
            #endif
        }
    }

    private var dockDisplayButton: some View {
        Button {
            isShowingDockDisplay = true
        } label: {
            Image(systemName: "display")
        }
        .accessibilityLabel("Open Dock Display")
    }

    private static func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

private extension BridgeLogEntry {
    var title: String {
        switch kind {
        case "bluetooth_event": "Bluetooth"
        case "snapshot_received": "Snapshot received"
        case "watch_sync_succeeded": "Watch synced"
        case "mac_disconnected": "Mac disconnected"
        case "cache_load_failed": "Cache load failed"
        default: kind
        }
    }

    var detail: String {
        if let message {
            return message
        }
        if let agentCount {
            return "\(agentCount) agents at \(at.formatted(date: .omitted, time: .shortened))"
        }
        return at.formatted(date: .omitted, time: .shortened)
    }
}

private struct StatusRow: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(value == "Connected" || value == "Synced" ? .green : .secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct AgentRow: View {
    let agent: AgentSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(agent.name)
                    .font(.headline)
                Text(agent.displayStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(agent.todayTotalText)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                if agent.rateLimits != nil {
                    Text(agent.limitText)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.teal)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
