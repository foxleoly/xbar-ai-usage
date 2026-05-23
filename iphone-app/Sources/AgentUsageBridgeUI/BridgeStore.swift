import AgentUsageBridgeCore
import Foundation

@MainActor
public final class BridgeStore: ObservableObject {
    @Published public private(set) var state: BridgeState
    @Published public private(set) var logs: [BridgeLogEntry]

    private let persistence: BridgePersistence
    private var bluetoothClient: BLEUsageCentral?
    #if os(iOS) && canImport(WatchConnectivity)
    private let watchSnapshotSender: WatchSnapshotSender?
    #endif

    public init(
        state: BridgeState? = nil,
        persistence: BridgePersistence = BridgePersistence()
    ) {
        self.persistence = persistence
        #if os(iOS) && canImport(WatchConnectivity)
        self.watchSnapshotSender = WatchSnapshotSender()
        #endif
        self.logs = (try? persistence.loadLogs(limit: 50)) ?? []

        if let state {
            self.state = state
        } else {
            #if targetEnvironment(simulator)
            self.state = .connected(snapshot: MockData.codexSnapshot, watchSyncedAt: nil)
            #else
            if let cached = try? persistence.loadLatestSnapshot() {
                self.state = .connected(snapshot: cached, watchSyncedAt: nil)
            } else {
                self.state = .initial
            }
            #endif
        }
    }

    public func startBluetooth() {
        #if targetEnvironment(simulator)
        updateMacStatus(.connected, message: "Simulator is using sample data")
        return
        #endif

        guard bluetoothClient == nil else {
            return
        }

        let client = BLEUsageCentral(
            onStatusChanged: { [weak self] status, message in
                self?.updateMacStatus(status, message: message)
            },
            onSnapshotReceived: { [weak self] snapshot in
                self?.apply(snapshot: snapshot, watchSyncedAt: nil)
            }
        )
        bluetoothClient = client
        client.start()
    }

    public func apply(snapshot: AgentUsageSnapshot, watchSyncedAt: Date?) {
        let resolvedWatchSyncedAt: Date?
        #if os(iOS) && canImport(WatchConnectivity)
        resolvedWatchSyncedAt = watchSyncedAt ?? watchSnapshotSender?.send(snapshot)
        #else
        resolvedWatchSyncedAt = watchSyncedAt
        #endif

        state = .connected(snapshot: snapshot, watchSyncedAt: resolvedWatchSyncedAt)
        try? persistence.saveLatestSnapshot(snapshot)
        try? persistence.appendLog(.snapshotReceived(at: snapshot.updatedAt, agentCount: snapshot.agents.count))
        if let resolvedWatchSyncedAt {
            try? persistence.appendLog(.watchSyncSucceeded(at: resolvedWatchSyncedAt))
        }
        logs = (try? persistence.loadLogs(limit: 50)) ?? logs
    }

    public func updateMacStatus(_ status: ConnectionStatus, message: String?) {
        state.macStatus = status
        if let message {
            try? persistence.appendLog(.bluetoothEvent(at: Date(), message: message))
            logs = (try? persistence.loadLogs(limit: 50)) ?? logs
        }
    }
}
