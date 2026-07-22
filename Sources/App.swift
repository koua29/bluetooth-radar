import SwiftUI

@main
struct BluetoothRadarApp: App {
    @StateObject private var alertStore: AlertStore
    @StateObject private var coordinator: ScanCoordinator

    init() {
        let store = AlertStore()
        _alertStore = StateObject(wrappedValue: store)
        _coordinator = StateObject(wrappedValue: ScanCoordinator(alertStore: store))
    }

    var body: some Scene {
        WindowGroup("Bluetooth Radar") {
            ContentView()
                .environmentObject(coordinator)
                .environmentObject(alertStore)
                .frame(minWidth: 820, minHeight: 520)
                .onAppear {
                    // Démarre le scan au lancement : les critères d'alerte
                    // chargés depuis les réglages sont donc actifs immédiatement.
                    coordinator.start()
                }
        }
        .defaultSize(width: 960, height: 640)
    }
}
