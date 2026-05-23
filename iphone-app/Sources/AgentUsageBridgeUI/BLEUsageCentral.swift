import AgentUsageBridgeCore
@preconcurrency import CoreBluetooth
import Foundation

@MainActor
final class BLEUsageCentral: NSObject, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    private let serviceUUID = CBUUID(string: BLEUsageWire.serviceUUIDString)
    private let snapshotCharacteristicUUID = CBUUID(string: BLEUsageWire.snapshotCharacteristicUUIDString)
    private let decoder = AgentUsageSnapshotDecoder()
    private let onStatusChanged: (ConnectionStatus, String?) -> Void
    private let onSnapshotReceived: (AgentUsageSnapshot) -> Void

    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var reassembler = BLEPayloadReassembler()

    init(
        onStatusChanged: @escaping (ConnectionStatus, String?) -> Void,
        onSnapshotReceived: @escaping (AgentUsageSnapshot) -> Void
    ) {
        self.onStatusChanged = onStatusChanged
        self.onSnapshotReceived = onSnapshotReceived
        super.init()
    }

    func start() {
        guard centralManager == nil else {
            return
        }
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            scan()
        case .poweredOff:
            onStatusChanged(.disconnected, "Bluetooth is powered off")
        case .unauthorized:
            onStatusChanged(.disconnected, "Bluetooth permission is not authorized")
        case .unsupported:
            onStatusChanged(.disconnected, "Bluetooth is not supported on this device")
        case .resetting:
            onStatusChanged(.scanning, "Bluetooth is resetting")
        case .unknown:
            onStatusChanged(.scanning, "Bluetooth state is unknown")
        @unknown default:
            onStatusChanged(.disconnected, "Bluetooth entered an unknown state")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        self.peripheral = peripheral
        peripheral.delegate = self
        central.stopScan()
        central.connect(peripheral)
        onStatusChanged(.scanning, "Connecting to \(peripheral.name ?? "Mac daemon")")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        onStatusChanged(.connected, "Connected to \(peripheral.name ?? "Mac daemon")")
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        onStatusChanged(.disconnected, error?.localizedDescription ?? "Failed to connect to Mac daemon")
        scan()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        reassembler.reset()
        onStatusChanged(.disconnected, error?.localizedDescription ?? "Mac daemon disconnected")
        scan()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            onStatusChanged(.disconnected, error.localizedDescription)
            return
        }

        for service in peripheral.services ?? [] where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([snapshotCharacteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            onStatusChanged(.disconnected, error.localizedDescription)
            return
        }

        for characteristic in service.characteristics ?? [] where characteristic.uuid == snapshotCharacteristicUUID {
            peripheral.setNotifyValue(true, for: characteristic)
            onStatusChanged(.connected, "Subscribed to token usage snapshots")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            onStatusChanged(.connected, "Snapshot update failed: \(error.localizedDescription)")
            return
        }
        guard characteristic.uuid == snapshotCharacteristicUUID, let value = characteristic.value else {
            return
        }

        do {
            guard let payload = try reassembler.receive(value) else {
                return
            }
            let snapshot = try decoder.decode(payload)
            onSnapshotReceived(snapshot)
        } catch {
            onStatusChanged(.connected, "Snapshot decode failed: \(error)")
        }
    }

    private func scan() {
        guard let centralManager, centralManager.state == .poweredOn else {
            return
        }

        reassembler.reset()
        onStatusChanged(.scanning, "Scanning for Agent Usage on Mac")
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }
}
