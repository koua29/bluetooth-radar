import SwiftUI

struct DeviceDetailView: View {
    let device: DiscoveredDevice
    @EnvironmentObject var store: AlertStore
    @EnvironmentObject var coord: ScanCoordinator
    @State private var added = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                grid
                if !device.serviceUUIDs.isEmpty {
                    section("Services annoncés") {
                        ForEach(device.serviceUUIDs, id: \.self) { uuid in
                            Text(uuid).font(.caption).monospaced().textSelection(.enabled)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .navigationTitle(device.displayName)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: device.kind == .ble ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right")
                .font(.system(size: 34))
                .foregroundStyle(device.kind == .ble ? .blue : .purple)
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName).font(.title2).bold()
                HStack {
                    KindBadge(kind: device.kind)
                    if device.isAlerting {
                        Label("Surveillé", systemImage: "bell.fill")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
            }
            Spacer()
            VStack(spacing: 8) {
                Button {
                    coord.startTracking(device.id)
                } label: {
                    Label("Radar", systemImage: "scope")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    store.addFromDevice(device)
                    added = true
                } label: {
                    Label(added ? "Alerte ajoutée" : "Créer une alerte", systemImage: "bell.badge.fill")
                }
                .disabled(added)
            }
        }
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(device.kind == .ble ? "Identifiant (UUID)" : "Adresse MAC", device.address, mono: true)
            row("Signal (RSSI)", device.rssi.map { "\($0) dBm" } ?? "N/A")
            if let tx = device.txPower { row("Puissance TX", "\(tx) dBm") }
            if let c = device.isConnectable { row("Connectable", c ? "Oui" : "Non") }
            if let m = device.manufacturerName { row("Fabricant", m) }
            if let d = device.manufacturerData { row("Données fabricant", d, mono: true) }
            if let cod = device.classOfDevice { row("Classe d'appareil", cod, mono: true) }
            if let mj = device.majorClass { row("Catégorie", mj) }
            row("Vu pour la 1re fois", device.firstSeen.formatted(date: .omitted, time: .standard))
            row("Dernière détection", device.lastSeen.formatted(date: .omitted, time: .standard))
        }
    }

    private func row(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary).frame(width: 160, alignment: .leading)
            Text(value)
                .font(mono ? .system(.body, design: .monospaced) : .body)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
        }
    }
}
