import AppKit

/// Retour sonore et visuel (rebond dock) pour les alertes.
enum Feedback {
    static func playSound(_ name: String) {
        if let s = NSSound(named: NSSound.Name(name)) {
            s.stop()
            s.play()
        } else {
            NSSound.beep()
        }
    }

    /// Fait rebondir l'icône du Dock (alerte visuelle même app en arrière-plan).
    static func bounceDock() {
        NSApplication.shared.requestUserAttention(.criticalRequest)
    }
}
