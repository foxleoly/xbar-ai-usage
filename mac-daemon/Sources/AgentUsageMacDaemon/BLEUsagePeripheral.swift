@preconcurrency import CoreBluetooth
import Foundation

public final class BLEUsagePeripheral: NSObject, CBPeripheralManagerDelegate {
    public static let serviceUUIDString = "8B7D2F4E-9678-4A13-A890-A5E89D7D6C01"
    public static let snapshotCharacteristicUUIDString = "0A5B95C6-20B7-4149-8E26-AB0BD034A07C"
    public static var serviceUUID: CBUUID { CBUUID(string: serviceUUIDString) }
    public static var snapshotCharacteristicUUID: CBUUID { CBUUID(string: snapshotCharacteristicUUIDString) }

    private var manager: CBPeripheralManager?
    private var snapshotCharacteristic: CBMutableCharacteristic?
    private var subscribedCentrals: [CBCentral] = []
    private var pendingWireChunks: [Data] = []
    private var lastPayload: Data?
    private var nextMessageID: UInt16 = 1

    public override init() {
        super.init()
    }

    public func start() {
        manager = CBPeripheralManager(delegate: self, queue: nil)
    }

    public func publish(_ payload: Data) {
        lastPayload = payload
        guard let manager, let characteristic = snapshotCharacteristic else {
            return
        }

        let maximum = subscribedCentrals.map(\.maximumUpdateValueLength).min() ?? 128
        let chunker = BLEPayloadChunker(maximumChunkSize: max(16, maximum))

        do {
            pendingWireChunks.append(contentsOf: try chunker.wireChunks(for: payload, messageID: nextMessageID))
            nextMessageID &+= 1
            flushPendingChunks(manager: manager, characteristic: characteristic)
        } catch {
            return
        }
    }

    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            return
        }

        let characteristic = CBMutableCharacteristic(
            type: Self.snapshotCharacteristicUUID,
            properties: [.notify],
            value: nil,
            permissions: []
        )
        snapshotCharacteristic = characteristic

        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [characteristic]
        peripheral.add(service)
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else {
            return
        }
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
            CBAdvertisementDataLocalNameKey: "Agent Usage"
        ])
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        subscribedCentrals.append(central)
        if let lastPayload {
            publish(lastPayload)
        }
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        subscribedCentrals.removeAll { $0.identifier == central.identifier }
    }

    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        guard let characteristic = snapshotCharacteristic else {
            return
        }
        flushPendingChunks(manager: peripheral, characteristic: characteristic)
    }

    private func flushPendingChunks(manager: CBPeripheralManager, characteristic: CBMutableCharacteristic) {
        while let next = pendingWireChunks.first {
            let accepted = manager.updateValue(next, for: characteristic, onSubscribedCentrals: nil)
            if !accepted {
                return
            }
            pendingWireChunks.removeFirst()
        }
    }
}
