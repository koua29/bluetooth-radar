import Foundation
import IOBluetooth

/// Scan des appareils Bluetooth « classique » (BR/EDR) via IOBluetooth.
/// C'est ici qu'on obtient la VRAIE adresse MAC, utilisable pour les alertes.
final class ClassicScanner: NSObject, IOBluetoothDeviceInquiryDelegate {
    weak var sink: DeviceSink?

    private var inquiry: IOBluetoothDeviceInquiry?
    private var running = false

    func start() {
        running = true
        beginInquiry()
    }

    func stop() {
        running = false
        inquiry?.stop()
        inquiry = nil
    }

    private func beginInquiry() {
        let inq = IOBluetoothDeviceInquiry(delegate: self)
        inq?.inquiryLength = 8            // secondes par passe
        inq?.updateNewDeviceNames = true // résout les noms
        inquiry = inq
        _ = inq?.start()
    }

    private func emit(_ device: IOBluetoothDevice?) {
        guard let device = device, let raw = device.addressString else { return }
        let mac = raw.replacingOccurrences(of: "-", with: ":").uppercased()
        let now = Date()
        var dev = DiscoveredDevice(
            id: mac,
            kind: .classic,
            name: device.name,
            address: mac,
            rssi: nil,
            firstSeen: now,
            lastSeen: now
        )
        let r = device.rawRSSI()
        if r != 127, r != 0 { dev.rssi = Int(r) }
        let cod = UInt32(bitPattern: Int32(device.classOfDevice))
        dev.classOfDevice = String(format: "0x%06X", cod)
        dev.majorClass = ClassOfDevice.major(cod)
        sink?.upsert(dev)
    }

    // MARK: - IOBluetoothDeviceInquiryDelegate

    func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!,
                                  device: IOBluetoothDevice!) {
        emit(device)
    }

    func deviceInquiryDeviceNameUpdated(_ sender: IOBluetoothDeviceInquiry!,
                                        device: IOBluetoothDevice!,
                                        devicesRemaining: UInt32) {
        emit(device)
    }

    func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!,
                               error: IOReturn,
                               aborted: Bool) {
        guard running else { return }
        // Relance en continu tant que le scan est actif.
        sender?.clearFoundDevices()
        _ = sender?.start()
    }
}
