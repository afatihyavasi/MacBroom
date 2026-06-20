import SwiftUI
import MacBroomCore

/// Lets the user pick which targets to analyze before the (slower) scan runs.
/// Only installed targets are shown; AI tools are pre-checked.
struct AnalysisSelectionView: View {
    @EnvironmentObject var state: AppState

    private var aiTargets: [AnalysisTarget] { state.installedTargets.filter { $0.category == "ai" } }
    private var systemTargets: [AnalysisTarget] { state.installedTargets.filter { $0.category == "system" } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Neyi analiz edelim?")
                .font(.callout.weight(.medium))
            Text("Sisteminizde bulunan hedefler. Yalnızca seçtikleriniz taranır (daha hızlı).")
                .font(.caption2).foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    group("AI Araçları", aiTargets, icon: "sparkles")
                    group("Sistem", systemTargets, icon: "internaldrive")
                    if state.installedTargets.isEmpty {
                        Text("Analiz edilecek hedef bulunamadı.")
                            .font(.callout).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                }
            }
            .frame(maxHeight: 300)

            HStack {
                Button("Tümünü seç") {
                    state.selectedTargets = Set(state.installedTargets.map(\.id))
                }
                .buttonStyle(.link).font(.caption)
                Button("Temizle") { state.selectedTargets = [] }
                    .buttonStyle(.link).font(.caption)
                Spacer()
                Button {
                    Task { await state.scanSelected() }
                } label: {
                    Text("Analiz Et (\(state.selectedTargets.count))")
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.selectedTargets.isEmpty)
            }
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ items: [AnalysisTarget], icon: String) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(items) { t in
                    Toggle(isOn: Binding(
                        get: { state.selectedTargets.contains(t.id) },
                        set: { _ in state.toggleTarget(t.id) }
                    )) {
                        Text(t.label).font(.callout)
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }
}
