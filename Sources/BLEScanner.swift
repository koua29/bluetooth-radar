import Foundation
import CoreBluetooth

/// Scan des appareils Bluetooth Low Energy (non connectés) via CoreBluetooth.
/// macOS n'expose PAS l'adresse MAC en BLE : on obtient un UUID propre à ce Mac.
final class BLEScanner: NSObject, CBCentralManagerDelegate {
    weak var sink: DeviceSink?
    var onState: ((CBManagerState) -> Void)?

    private var central: CBCentralManager!
    private var wantScan = false

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func start() {
        wantScan = true
        if central.state == .poweredOn { beginScan() }
    }

    func stop() {
        wantScan = false
        if central.state == .poweredOn { central.stopScan() }
    }

    private func beginScan() {
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        onState?(c.state)
        if c.state == .poweredOn, wantScan { beginScan() }
    }

    func centralManager(_ c: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData data: [String: Any],
                        rssi RSSI: NSNumber) {
        let now = Date()
        var dev = DiscoveredDevice(
            id: peripheral.identifier.uuidString,
            kind: .ble,
            name: (data[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name,
            address: peripheral.identifier.uuidString,
            rssi: RSSI.intValue == 127 ? nil : RSSI.intValue,
            firstSeen: now,
            lastSeen: now
        )
        dev.isConnectable = (data[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
        dev.txPower = (data[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue

        if let svcs = data[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            dev.serviceUUIDs = svcs.map { $0.uuidString }
        }
        if let md = data[CBAdvertisementDataManufacturerDataKey] as? Data, md.count >= 2 {
            dev.manufacturerData = md.map { String(format: "%02X", $0) }.joined(separator: " ")
            let cid = UInt16(md[0]) | (UInt16(md[1]) << 8)
            dev.manufacturerName = CompanyIDs.name(for: cid)
        }
        sink?.upsert(dev)
    }
}
