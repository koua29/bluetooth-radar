import Foundation

/// Correspondances simples ID fabricant BLE -> nom (sous-ensemble courant).
enum CompanyIDs {
    static let map: [UInt16: String] = [
        0x004C: "Apple",
        0x0006: "Microsoft",
        0x0075: "Samsung",
        0x00E0: "Google",
        0x0087: "Garmin",
        0x0157: "Anhui Huami (Amazfit)",
        0x00D8: "Qualcomm",
        0x000F: "Broadcom",
        0x0059: "Nordic Semiconductor",
        0x0499: "Ruuvi",
        0x0171: "Amazon",
        0x038F: "Xiaomi",
        0x0131: "Cypress",
        0x02E5: "Espressif (ESP32)",
        0x0001: "Ericsson",
        0x004F: "APT (Qualcomm aptX)",
        0x00C4: "LG",
        0x0107: "Fitbit",
        0x0180: "Bose",
        0x01D7: "Logitech",
    ]
    static func name(for id: UInt16) -> String {
        map[id] ?? String(format: "ID 0x%04X", id)
    }
}

/// Classe d'appareil Bluetooth classique -> libellé majeur.
enum ClassOfDevice {
    static func major(_ value: UInt32) -> String {
        // Bits 8..12 = major device class
        let major = (value >> 8) & 0x1F
        switch major {
        case 0x00: return "Divers"
        case 0x01: return "Ordinateur"
        case 0x02: return "Téléphone"
        case 0x03: return "Point d'accès réseau"
        case 0x04: return "Audio / Vidéo"
        case 0x05: return "Périphérique (clavier/souris)"
        case 0x06: return "Imagerie (imprimante/caméra)"
        case 0x07: return "Objet connecté (wearable)"
        case 0x08: return "Jouet"
        case 0x09: return "Santé"
        default:   return "Non catégorisé"
        }
    }
}
