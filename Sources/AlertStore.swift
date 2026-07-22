import Foundation

/// Un critère d'alerte : adresse MAC / UUID / fragment de nom à surveiller.
struct WatchCriterion: Identifiable, Codable, Hashable {
    var id = UUID()
    var label: String
    var pattern: String       // MAC, UUID ou texte de nom
    var sound: Bool = true
    var visual: Bool = true
    var enabled: Bool = true
}

/// Stockage persistant des critères + logique de correspondance.
/// Les critères sont chargés au démarrage (UserDefaults) => actifs dès le lancement.
final class AlertStore: ObservableObject {
    @Published var criteria: [WatchCriterion] = [] { didSet { save() } }
    @Published var soundName: String = "Sosumi" { didSet { UserDefaults.standard.set(soundName, forKey: soundKey) } }

    private let key = "watch_criteria_v1"
    private let soundKey = "watch_sound_v1"

    static let availableSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]

    init() { load() }

    // MARK: - Correspondance

    /// Renvoie le premier critère satisfait par cet appareil, sinon nil.
    func match(_ device: DiscoveredDevice) -> WatchCriterion? {
        let addr = normalize(device.address)
        let name = device.name?.lowercased()
        return criteria.first { c in
            guard c.enabled else { return false }
            let target = normalize(c.pattern)
            if target.isEmpty { return false }
            // Correspondance exacte d'adresse (MAC ou UUID)
            if target == addr { return true }
            // Sinon correspondance par fragment de nom (utile en BLE sans MAC)
            if !isAddressLike(target), let name = name, name.contains(target.lowercased()) {
                return true
            }
            return false
        }
    }

    func normalize(_ s: String) -> String {
        s.uppercased()
            .replacingOccurrences(of: "-", with: ":")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isAddressLike(_ s: String) -> Bool {
        s.contains(":") || s.contains("-") || s.count >= 17
    }

    // MARK: - Édition

    func addFromDevice(_ device: DiscoveredDevice) {
        let c = WatchCriterion(
            label: device.displayName,
            pattern: device.address
        )
        criteria.append(c)
    }

    func remove(_ c: WatchCriterion) {
        criteria.removeAll { $0.id == c.id }
    }

    // MARK: - Persistance

    private func save() {
        if let data = try? JSONEncoder().encode(criteria) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([WatchCriterion].self, from: data) {
            criteria = list
        }
        if let s = UserDefaults.standard.string(forKey: soundKey) { soundName = s }
    }
}
