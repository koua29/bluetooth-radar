import SwiftUI

/// Mode radar : suit le signal d'un appareil et indique si l'on s'en rapproche.
struct RadarView: View {
    @EnvironmentObject var coord: ScanCoordinator
    @State private var sweep = 0.0

    private var device: DiscoveredDevice? { coord.trackedDevice }

    var body: some View {
        VStack(spacing: 16) {
            header
            if let dev = device, dev.kind == .classic && dev.rssi == nil {
                Spacer()
                unavailable
                Spacer()
            } else {
                radar
                trendBanner
                stats
                Sparkline(samples: coord.trackHistory)
                    .frame(height: 60)
                    .padding(.horizontal)
                controls
            }
        }
        .padding(18)
    }

    // MARK: - En-tête

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(device?.displayName ?? "Appareil").font(.title3).bold()
                Text(device?.address ?? "").font(.caption).monospaced().foregroundStyle(.secondary)
            }
            Spacer()
            if let k = device?.kind { KindBadge(kind: k) }
        }
    }

    private var unavailable: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash").font(.system(size: 36)).foregroundStyle(.secondary)
            Text("Signal indisponible")
            Text("macOS ne fournit pas de RSSI fiable pour cet appareil Bluetooth classique.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }.padding()
    }

    // MARK: - Radar

    private var radar: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxR = side / 2 - 6
            let blipR = maxR * (1 - coord.closeness)   // proche => vers le centre

            ZStack {
                // Anneaux de portée
                ForEach(1...4, id: \.self) { i in
                    Circle()
                        .stroke(Color.green.opacity(0.18), lineWidth: 1)
                        .frame(width: maxR * 2 * CGFloat(i) / 4,
                               height: maxR * 2 * CGFloat(i) / 4)
                }
                // Croix
                Path { p in
                    p.move(to: CGPoint(x: c.x - maxR, y: c.y)); p.addLine(to: CGPoint(x: c.x + maxR, y: c.y))
                    p.move(to: CGPoint(x: c.x, y: c.y - maxR)); p.addLine(to: CGPoint(x: c.x, y: c.y + maxR))
                }.stroke(Color.green.opacity(0.12), lineWidth: 1)

                // Balayage animé
                Path { p in
                    p.move(to: c)
                    p.addLine(to: CGPoint(x: c.x, y: c.y - maxR))
                }
                .stroke(Color.green.opacity(0.5), lineWidth: 2)
                .rotationEffect(.degrees(sweep), anchor: .center)

                // Blip de l'appareil (bearing fixe vers le haut, distance = signal)
                Circle()
                    .fill(blipColor)
                    .frame(width: 16, height: 16)
                    .shadow(color: blipColor, radius: 8)
                    .position(x: c.x, y: c.y - blipR)
                    .animation(.easeInOut(duration: 0.4), value: blipR)

                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
                    .position(c)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxHeight: 300)
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                sweep = 360
            }
        }
    }

    private var blipColor: Color {
        switch coord.proximityTrend {
        case .closer:  return .green
        case .farther: return .blue
        default:       return .yellow
        }
    }

    // MARK: - Bandeau de tendance

    private var trendBanner: some View {
        let t = coord.proximityTrend
        return HStack(spacing: 10) {
            Image(systemName: t.symbol).font(.title)
            Text(t.label).font(.title3).bold()
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(trendColor.gradient, in: RoundedRectangle(cornerRadius: 10))
    }

    private var trendColor: Color {
        switch coord.proximityTrend {
        case .closer:  return .green
        case .farther: return .blue
        case .stable:  return .gray
        case .unknown: return .secondary
        }
    }

    // MARK: - Stats

    private var stats: some View {
        HStack(spacing: 24) {
            stat("Signal", coord.trackHistory.last.map { "\($0.rssi) dBm" } ?? "—")
            stat("Lissé", coord.smoothedRSSI.map { String(format: "%.0f dBm", $0) } ?? "—")
            stat("Distance ~", coord.approxDistance.map { String(format: "%.1f m", $0) } ?? "—")
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3).bold().monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Contrôles

    private var controls: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { coord.geigerOn },
                set: { coord.setGeiger($0) }
            )) {
                Label("Bip de proximité", systemImage: "dot.radiowaves.left.and.right")
            }
            .toggleStyle(.switch)
            Spacer()
            Button(role: .cancel) { coord.stopTracking() } label: {
                Label("Arrêter le radar", systemImage: "xmark.circle")
            }
        }
    }
}

/// Petite courbe du RSSI récent.
struct Sparkline: View {
    let samples: [RSSISample]

    var body: some View {
        GeometryReader { geo in
            let vals = samples.map { Double($0.rssi) }
            if vals.count >= 2 {
                let minV = -100.0, maxV = -30.0
                let stepX = geo.size.width / CGFloat(vals.count - 1)
                Path { p in
                    for (i, v) in vals.enumerated() {
                        let x = CGFloat(i) * stepX
                        let norm = (v - minV) / (maxV - minV)
                        let y = geo.size.height * (1 - CGFloat(max(0, min(1, norm))))
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            } else {
                Text("Collecte du signal…")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
