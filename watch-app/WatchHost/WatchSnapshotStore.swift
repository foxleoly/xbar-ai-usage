import AgentUsageBridgeCore
import Foundation
import WatchConnectivity

@MainActor
final class WatchSnapshotStore: NSObject, ObservableObject {
    @Published private(set) var snapshot: AgentUsageSnapshot = MockData.codexSnapshot
    @Published private(set) var lastSyncedAt: Date?

    private let decoder = AgentUsageSnapshotDecoder()

    override init() {
        super.init()

        guard WCSession.isSupported() else {
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        apply(data: session.receivedApplicationContext["snapshot"] as? Data)
    }

    private func apply(data: Data?) {
        guard let data else {
            return
        }

        do {
            snapshot = try decoder.decode(data)
            lastSyncedAt = Date()
        } catch {
            lastSyncedAt = nil
        }
    }
}

extension WatchSnapshotStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        let snapshotData = applicationContext["snapshot"] as? Data
        Task { @MainActor in
            self.apply(data: snapshotData)
        }
    }
}
