import Foundation

/// Nature de l'appareil détecté.
enum DeviceKind: String, Codable {
    case ble = "BLE"
    case classic = "Classique"
}

/// Un appareil Bluetooth détecté à portée (pas forcément connecté).
struct DiscoveredDevice: Identifiable, Equatable {
    /// Clé stable : UUID (BLE) ou adresse MAC (classique).
    let id: String
    var kind: DeviceKind
    var name: String?
    /// UUID pour le BLE, adresse MAC pour le classique.
    var address: String
    var rssi: Int?
    var firstSeen: Date
    var lastSeen: Date

    // --- Extras BLE ---
    var isConnectable: Bool?
    var txPower: Int?
    var serviceUUIDs: [String] = []
    var manufacturerData: String?
    var manufacturerName: String?

    // --- Extras classique ---
    var classOfDevice: String?
    var majorClass: String?
    var minorClass: String?

    /// Correspond à un critère d'alerte actif.
    var isAlerting: Bool = false

    var displayName: String {
        if let n = name, !n.isEmpty { return n }
        return kind == .ble ? "Appareil BLE inconnu" : "Appareil inconnu"
    }

    /// Nombre de barres de signal 0...4 à partir du RSSI.
    var signalBars: Int {
        guard let r = rssi else { return 0 }
        switch r {
        case ..<(-90): return 1
        case -90 ..< -75: return 2
        case -75 ..< -60: return 3
        default: return 4
        }
    }
}

/// Réception des appareils depuis les scanners (BLE / classique).
protocol DeviceSink: AnyObject {
    func upsert(_ device: DiscoveredDevice)
}

/// Un relevé de signal horodaté (pour le mode radar).
struct RSSISample: Identifiable {
    let id = UUID()
    let t: Date
    let rssi: Int
}

/// Tendance de proximité déduite de l'évolution du signal.
enum ProximityTrend {
    case closer, farther, stable, unknown

    var label: String {
        switch self {
        case .closer:  return "Vous vous rapprochez"
        case .farther: return "Vous vous éloignez"
        case .stable:  return "Signal stable"
        case .unknown: return "Analyse du signal…"
        }
    }
    var symbol: String {
        switch self {
        case .closer:  return "arrow.up.forward.circle.fill"
        case .farther: return "arrow.down.forward.circle.fill"
        case .stable:  return "equal.circle.fill"
        case .unknown: return "hourglass.circle.fill"
        }
    }
}

/// Évènement d'alerte à afficher.
struct AlertEvent: Identifiable, Equatable {
    let id = UUID()
    let device: DiscoveredDevice
    let criterionLabel: String
    let at: Date
}
