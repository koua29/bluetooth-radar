import Foundation
import CoreBluetooth
import Combine

/// Cerveau de l'app : possède les deux scanners, fusionne les résultats,
/// gère le cycle de scan (10 s à 5 min) et déclenche les alertes.
final class ScanCoordinator: ObservableObject, DeviceSink {
    @Published var devices: [DiscoveredDevice] = []
    @Published var isScanning = false
    @Published var bluetoothState: String = "Initialisation…"
    @Published var bluetoothReady = false

    /// Fenêtre de fraîcheur en secondes : un appareil non revu depuis
    /// ce délai est retiré de la liste. Réglable de 10 s à 300 s (5 min).
    @Published var scanCycle: Double = 30 {
        didSet { UserDefaults.standard.set(scanCycle, forKey: cycleKey) }
    }

    /// Alerte en cours à afficher (bannière).
    @Published var activeAlert: AlertEvent?

    // --- Mode radar / suivi de proximité ---
    /// Appareil actuellement suivi (nil = pas de radar ouvert).
    @Published var trackedID: String?
    /// Historique récent du RSSI de l'appareil suivi.
    @Published var trackHistory: [RSSISample] = []
    /// Compteur sonore type Geiger (bip d'autant plus rapide qu'on est proche).
    @Published var geigerOn = false
    private var geigerTimer: Timer?

    let alertStore: AlertStore

    private let ble = BLEScanner()
    private let classic = ClassicScanner()
    private var index: [String: DiscoveredDevice] = [:]
    private var lastAlertAt: [String: Date] = [:]
    private var pruneTimer: Timer?
    private let cycleKey = "scan_cycle_v1"
    private let alertDebounce: TimeInterval = 30

    init(alertStore: AlertStore) {
        self.alertStore = alertStore
        if let c = UserDefaults.standard.object(forKey: cycleKey) as? Double, c >= 10 {
            scanCycle = c
        }
        ble.sink = self
        classic.sink = self
        ble.onState = { [weak self] state in
            DispatchQueue.main.async { self?.updateState(state) }
        }
    }

    // MARK: - Contrôle du scan

    func toggleScan() { isScanning ? stop() : start() }

    func start() {
        guard !isScanning else { return }
        isScanning = true
        ble.start()
        classic.start()
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.prune()
        }
    }

    func stop() {
        isScanning = false
        ble.stop()
        classic.stop()
        pruneTimer?.invalidate()
        pruneTimer = nil
    }

    func clear() {
        index.removeAll()
        lastAlertAt.removeAll()
        publish()
    }

    // MARK: - DeviceSink (appelé sur le thread principal)

    func upsert(_ incoming: DiscoveredDevice) {
        DispatchQueue.main.async { [weak self] in self?.merge(incoming) }
    }

    private func merge(_ incoming: DiscoveredDevice) {
        var dev = incoming
        if let old = index[dev.id] {
            dev.firstSeen = old.firstSeen
            if dev.name == nil { dev.name = old.name }
            if dev.rssi == nil { dev.rssi = old.rssi }
            if dev.manufacturerName == nil { dev.manufacturerName = old.manufacturerName }
            if dev.manufacturerData == nil { dev.manufacturerData = old.manufacturerData }
            if dev.serviceUUIDs.isEmpty { dev.serviceUUIDs = old.serviceUUIDs }
            if dev.classOfDevice == nil { dev.classOfDevice = old.classOfDevice }
            if dev.majorClass == nil { dev.majorClass = old.majorClass }
            if dev.isConnectable == nil { dev.isConnectable = old.isConnectable }
            if dev.txPower == nil { dev.txPower = old.txPower }
        }

        if let crit = alertStore.match(dev) {
            dev.isAlerting = true
            fireAlert(for: dev, criterion: crit)
        }
        index[dev.id] = dev

        if dev.id == trackedID, let r = dev.rssi {
            trackHistory.append(RSSISample(t: Date(), rssi: r))
            if trackHistory.count > 120 {
                trackHistory.removeFirst(trackHistory.count - 120)
            }
        }
        publish()
    }

    private func publish() {
        devices = index.values.sorted {
            ($0.rssi ?? -200) > ($1.rssi ?? -200)
        }
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-scanCycle)
        var changed = false
        for (k, v) in index where v.lastSeen < cutoff {
            index.removeValue(forKey: k)
            changed = true
        }
        if changed { publish() }
    }

    // MARK: - Alertes

    private func fireAlert(for device: DiscoveredDevice, criterion: WatchCriterion) {
        let now = Date()
        if let last = lastAlertAt[device.id], now.timeIntervalSince(last) < alertDebounce {
            return
        }
        lastAlertAt[device.id] = now

        let event = AlertEvent(device: device, criterionLabel: criterion.label, at: now)
        if criterion.visual {
            activeAlert = event
            Feedback.bounceDock()
        }
        if criterion.sound {
            Feedback.playSound(alertStore.soundName)
        }
    }

    func dismissAlert() { activeAlert = nil }

    // MARK: - Radar / suivi de proximité

    var trackedDevice: DiscoveredDevice? {
        trackedID.flatMap { index[$0] }
    }

    /// RSSI lissé (moyenne mobile exponentielle) de l'appareil suivi.
    var smoothedRSSI: Double? {
        guard let first = trackHistory.first else { return nil }
        let a = 0.3
        var ema = Double(first.rssi)
        for s in trackHistory.dropFirst() {
            ema = a * Double(s.rssi) + (1 - a) * ema
        }
        return ema
    }

    /// Tendance de proximité basée sur l'évolution récente du RSSI.
    var proximityTrend: ProximityTrend {
        let vals = trackHistory.suffix(24).map { Double($0.rssi) }
        guard vals.count >= 6 else { return .unknown }
        let half = vals.count / 2
        let older = vals.prefix(half)
        let recent = vals.suffix(vals.count - half)
        let d = (recent.reduce(0, +) / Double(recent.count))
              - (older.reduce(0, +) / Double(older.count))
        if d > 2.5 { return .closer }
        if d < -2.5 { return .farther }
        return .stable
    }

    /// Proximité normalisée 0 (loin) … 1 (très proche), à partir du RSSI lissé.
    var closeness: Double {
        guard let s = smoothedRSSI else { return 0 }
        return max(0, min(1, (s + 100) / 60))   // -100 dBm -> 0, -40 dBm -> 1
    }

    /// Distance approximative en mètres (indicative, très bruitée).
    var approxDistance: Double? {
        guard let s = smoothedRSSI else { return nil }
        let txPower = Double(trackedDevice?.txPower ?? -59)
        let n = 2.5
        return pow(10, (txPower - s) / (10 * n))
    }

    func startTracking(_ id: String) {
        trackedID = id
        trackHistory.removeAll()
        if let r = index[id]?.rssi {
            trackHistory.append(RSSISample(t: Date(), rssi: r))
        }
    }

    func stopTracking() {
        trackedID = nil
        trackHistory.removeAll()
        setGeiger(false)
    }

    func setGeiger(_ on: Bool) {
        geigerOn = on
        geigerTimer?.invalidate()
        geigerTimer = nil
        if on { scheduleGeigerTick() }
    }

    private func scheduleGeigerTick() {
        guard geigerOn else { return }
        let c = closeness
        let interval = 1.2 - c * 1.05          // 1.2 s (loin) … 0.15 s (proche)
        geigerTimer = Timer.scheduledTimer(withTimeInterval: max(0.15, interval),
                                           repeats: false) { [weak self] _ in
            guard let self = self, self.geigerOn else { return }
            Feedback.playSound("Tink")
            self.scheduleGeigerTick()
        }
    }

    private func updateState(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            bluetoothReady = true
            bluetoothState = "Bluetooth actif"
        case .poweredOff:
            bluetoothReady = false
            bluetoothState = "Bluetooth désactivé"
        case .unauthorized:
            bluetoothReady = false
            bluetoothState = "Autorisation Bluetooth refusée"
        case .unsupported:
            bluetoothReady = false
            bluetoothState = "Bluetooth non supporté"
        default:
            bluetoothReady = false
            bluetoothState = "Bluetooth indisponible"
        }
    }
}
