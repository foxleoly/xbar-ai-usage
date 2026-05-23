import Foundation

public final class UsageDaemon: @unchecked Sendable {
    private let collector: CodexUsageCollector
    private let encoder: SnapshotEncoder
    private let peripheral: BLEUsagePeripheral
    private let refreshInterval: TimeInterval
    private var timer: Timer?

    public init(
        collector: CodexUsageCollector,
        encoder: SnapshotEncoder = SnapshotEncoder(),
        peripheral: BLEUsagePeripheral = BLEUsagePeripheral(),
        refreshInterval: TimeInterval = 60
    ) {
        self.collector = collector
        self.encoder = encoder
        self.peripheral = peripheral
        self.refreshInterval = refreshInterval
    }

    public func start() {
        peripheral.start()
        publishOnce()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.publishOnce()
        }
        RunLoop.current.run()
    }

    private func publishOnce() {
        do {
            let snapshot = try collector.snapshot()
            let payload = try encoder.encode(snapshot)
            peripheral.publish(payload)
        } catch {
            return
        }
    }
}
