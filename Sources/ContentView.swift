import SwiftUI

struct ContentView: View {
    @EnvironmentObject var coord: ScanCoordinator
    @EnvironmentObject var store: AlertStore

    @State private var selection: String?
    @State private var showAlerts = false

    private var selectedDevice: DiscoveredDevice? {
        coord.devices.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let dev = selectedDevice {
                DeviceDetailView(device: dev)
            } else {
                ContentUnavailablePlaceholder()
            }
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAlerts) {
            AlertSettingsView().frame(width: 560, height: 520)
        }
        .sheet(isPresented: Binding(
            get: { coord.trackedID != nil },
            set: { if !$0 { coord.stopTracking() } }
        )) {
            RadarView().frame(width: 460, height: 660)
        }
        .overlay(alignment: .top) { alertBanner }
    }

    // MARK: - Barre latérale (liste des appareils)

    private var sidebar: some View {
        VStack(spacing: 0) {
            statusBar
            Divider()
            if coord.devices.isEmpty {
                Spacer()
                Text(coord.isScanning ? "Recherche d'appareils…" : "Scan arrêté")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(coord.devices, selection: $selection) { dev in
                    DeviceRow(device: dev).tag(dev.id)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 320)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(coord.bluetoothReady ? Color.green : Color.orange)
                .frame(width: 9, height: 9)
            Text(coord.bluetoothState).font(.caption)
            Spacer()
            Text("\(coord.devices.count) appareil\(coord.devices.count > 1 ? "s" : "")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    // MARK: - Barre d'outils

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                coord.toggleScan()
            } label: {
                Label(coord.isScanning ? "Arrêter" : "Scanner",
                      systemImage: coord.isScanning ? "stop.circle.fill" : "play.circle.fill")
            }
        }
        ToolbarItem(placement: .automatic) {
            Button {
                coord.clear()
            } label: { Label("Vider", systemImage: "trash") }
        }
        ToolbarItem(placement: .automatic) {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Slider(value: $coord.scanCycle, in: 10...300, step: 5)
                    .frame(width: 130)
                Text(cycleLabel).font(.caption).monospacedDigit()
                    .frame(width: 54, alignment: .leading)
            }
            .help("Fenêtre de fraîcheur : un appareil non revu depuis ce délai disparaît de la liste (10 s à 5 min).")
        }
        ToolbarItem(placement: .automatic) {
            Button {
                showAlerts = true
            } label: {
                Label("Alertes (\(store.criteria.count))", systemImage: "bell.badge")
            }
        }
    }

    private var cycleLabel: String {
        let s = Int(coord.scanCycle)
        return s >= 60 ? String(format: "%d min%02d", s / 60, s % 60) : "\(s) s"
    }

    // MARK: - Bannière d'alerte

    @ViewBuilder
    private var alertBanner: some View {
        if let alert = coord.activeAlert {
            HStack(spacing: 12) {
                Image(systemName: "bell.fill").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alerte : \(alert.criterionLabel)").bold()
                    Text("\(alert.device.displayName) — \(alert.device.address)")
                        .font(.caption)
                }
                Spacer()
                Button {
                    selection = alert.device.id
                    coord.dismissAlert()
                } label: { Text("Voir") }
                Button {
                    coord.dismissAlert()
                } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(.red.gradient, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.white)
            .padding()
            .shadow(radius: 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Ligne de la liste

struct DeviceRow: View {
    let device: DiscoveredDevice

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(device.kind == .ble ? .blue : .purple)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .lineLimit(1)
                    .foregroundStyle(device.isAlerting ? Color.red : Color.primary)
                Text(device.address)
                    .font(.caption2).monospaced()
                    .foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            KindBadge(kind: device.kind)
            SignalBars(bars: device.signalBars)
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        if device.isAlerting { return "bell.fill" }
        return device.kind == .ble ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right"
    }
}

struct KindBadge: View {
    let kind: DeviceKind
    var body: some View {
        Text(kind.rawValue)
            .font(.caption2).bold()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background((kind == .ble ? Color.blue : Color.purple).opacity(0.15),
                        in: Capsule())
            .foregroundStyle(kind == .ble ? Color.blue : Color.purple)
    }
}

struct SignalBars: View {
    let bars: Int
    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < bars ? Color.green : Color.gray.opacity(0.25))
                    .frame(width: 3, height: CGFloat(5 + i * 3))
            }
        }
        .frame(height: 14, alignment: .bottom)
    }
}

struct ContentUnavailablePlaceholder: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 40)).foregroundStyle(.secondary)
            Text("Sélectionne un appareil pour voir le détail")
                .foregroundStyle(.secondary)
        }
    }
}
