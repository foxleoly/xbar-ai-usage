import AgentUsageBridgeCore
import Foundation

#if os(iOS) && canImport(WatchConnectivity)
import WatchConnectivity

final class WatchSnapshotSender: NSObject, WCSessionDelegate {
    private let session: WCSession?
    private let encoder: JSONEncoder

    override init() {
        if WCSession.isSupported() {
            self.session = WCSession.default
        } else {
            self.session = nil
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        super.init()

        session?.delegate = self
        session?.activate()
    }

    func send(_ snapshot: AgentUsageSnapshot) -> Date? {
        guard let session, session.activationState == .activated else {
            return nil
        }

        guard session.isPaired, session.isWatchAppInstalled else {
            return nil
        }

        do {
            let data = try encoder.encode(snapshot)
            try session.updateApplicationContext(["snapshot": data])
            return Date()
        } catch {
            return nil
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
