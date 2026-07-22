import SwiftUI

struct AlertSettingsView: View {
    @EnvironmentObject var store: AlertStore
    @Environment(\.dismiss) private var dismiss

    @State private var newLabel = ""
    @State private var newPattern = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Alertes surveillées").font(.title3).bold()
                Spacer()
                Button("Fermer") { dismiss() }
            }

            Text("Une alerte se déclenche dès qu'un appareil à portée correspond à une adresse MAC, un UUID, ou un fragment de nom. Actif dès le démarrage de l'app.")
                .font(.caption).foregroundStyle(.secondary)

            // Ajout
            GroupBox {
                VStack(spacing: 8) {
                    TextField("Nom du critère (ex. Montre d'Arnaud)", text: $newLabel)
                    TextField("Adresse MAC / UUID / nom (ex. AA:BB:CC:DD:EE:FF)", text: $newPattern)
                        .font(.system(.body, design: .monospaced))
                    HStack {
                        Spacer()
                        Button {
                            add()
                        } label: { Label("Ajouter", systemImage: "plus") }
                        .disabled(newPattern.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .padding(6)
            }

            // Liste
            if store.criteria.isEmpty {
                Spacer()
                Text("Aucun critère. Ajoute-en un, ou clique « Créer une alerte » depuis un appareil.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Spacer()
            } else {
                List {
                    ForEach($store.criteria) { $c in
                        CriterionRow(criterion: $c) { store.remove(c) }
                    }
                }
                .listStyle(.inset)
            }

            // Son
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                Picker("Son d'alerte", selection: $store.soundName) {
                    ForEach(AlertStore.availableSounds, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 220)
                Button {
                    Feedback.playSound(store.soundName)
                } label: { Image(systemName: "play.circle") }
                Spacer()
            }
        }
        .padding(18)
    }

    private func add() {
        let label = newLabel.trimmingCharacters(in: .whitespaces)
        let pattern = newPattern.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return }
        store.criteria.append(
            WatchCriterion(label: label.isEmpty ? pattern : label, pattern: pattern)
        )
        newLabel = ""
        newPattern = ""
    }
}

struct CriterionRow: View {
    @Binding var criterion: WatchCriterion
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $criterion.enabled).labelsHidden()
            VStack(alignment: .leading, spacing: 2) {
                Text(criterion.label).bold()
                Text(criterion.pattern).font(.caption).monospaced().foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(isOn: $criterion.visual) { Image(systemName: "eye") }
                .toggleStyle(.button).help("Alerte visuelle")
            Toggle(isOn: $criterion.sound) { Image(systemName: "speaker.wave.2") }
                .toggleStyle(.button).help("Alerte sonore")
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }.buttonStyle(.plain).foregroundStyle(.red)
        }
        .padding(.vertical, 3)
    }
}
