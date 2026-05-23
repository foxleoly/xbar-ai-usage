import Foundation

public enum ConnectionStatus: String, Equatable, Sendable {
    case disconnected
    case scanning
    case connected
    case synced

    public var title: String {
        switch self {
        case .disconnected: "Disconnected"
        case .scanning: "Scanning"
        case .connected: "Connected"
        case .synced: "Synced"
        }
    }
}

public struct AgentSummary: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var status: String
    public var windows: UsageWindows
    public var rateLimits: AgentRateLimits?

    public init(id: String, name: String, status: String, windows: UsageWindows, rateLimits: AgentRateLimits? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.windows = windows
        self.rateLimits = rateLimits
    }

    public var todayTotalText: String {
        TokenCountFormatter.compact(windows.today.total)
    }

    public var displayStatus: String {
        status == "active" ? "Active" : "Unavailable"
    }

    public var limitText: String {
        guard let rateLimits else {
            return "No limit"
        }

        let primary = rateLimits.primary.map { Self.percentText($0.remainingPercent) } ?? "--"
        let secondary = rateLimits.secondary.map { Self.percentText($0.remainingPercent) } ?? "--"
        return "\(primary) / \(secondary)"
    }

    private static func percentText(_ value: Double) -> String {
        let rounded = value.rounded()
        if rounded == value {
            return "\(Int(rounded))%"
        }
        return "\(String(format: "%.1f", value))%"
    }
}

public struct BridgeState: Equatable, Sendable {
    public var macStatus: ConnectionStatus
    public var watchStatus: ConnectionStatus
    public var macName: String
    public var updatedAt: Date?
    public var watchSyncedAt: Date?
    public var agents: [AgentSummary]

    public init(
        macStatus: ConnectionStatus,
        watchStatus: ConnectionStatus,
        macName: String,
        updatedAt: Date?,
        watchSyncedAt: Date?,
        agents: [AgentSummary]
    ) {
        self.macStatus = macStatus
        self.watchStatus = watchStatus
        self.macName = macName
        self.updatedAt = updatedAt
        self.watchSyncedAt = watchSyncedAt
        self.agents = agents
    }

    public static var initial: BridgeState {
        BridgeState(
            macStatus: .scanning,
            watchStatus: .disconnected,
            macName: "Mac daemon",
            updatedAt: nil,
            watchSyncedAt: nil,
            agents: []
        )
    }

    public static func connected(snapshot: AgentUsageSnapshot, watchSyncedAt: Date?) -> BridgeState {
        BridgeState(
            macStatus: .connected,
            watchStatus: watchSyncedAt == nil ? .disconnected : .synced,
            macName: "Mac daemon",
            updatedAt: snapshot.updatedAt,
            watchSyncedAt: watchSyncedAt,
            agents: snapshot.agents.map {
                AgentSummary(id: $0.id, name: $0.name, status: $0.status, windows: $0.windows, rateLimits: $0.rateLimits)
            }
        )
    }
}
