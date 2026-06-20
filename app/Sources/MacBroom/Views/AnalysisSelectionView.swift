import SwiftUI
import MacBroomCore

/// Per-tab target picker shown before the (slower) scan. Lists only the current
/// category's installed targets; AI tools show their real app icons.
struct AnalysisSelectionView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager
    let category: CleanCategory

    private var items: [AnalysisTarget] { state.installedTargets(in: category) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc.t(.analyzeQuestion))
                .font(.callout.weight(.medium))
            Text(loc.t(.analyzeSubtitle))
                .font(.caption2).foregroundStyle(.secondary)

            if items.isEmpty {
                Spacer()
                Text(loc.t(.noTargetsInCategory))
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(items) { t in
                            row(t)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                HStack {
                    Button(loc.t(.selectAll)) {
                        for t in items { state.selectedTargets.insert(t.id) }
                    }.buttonStyle(.link).font(.caption)
                    Button(loc.t(.clearSelection)) {
                        for t in items { state.selectedTargets.remove(t.id) }
                    }.buttonStyle(.link).font(.caption)
                    Spacer()
                    Button {
                        Task { await state.scanSelected(category: category) }
                    } label: {
                        Text(loc.t(.analyzeButton, state.selectedTargetCount(in: category)))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.selectedTargetCount(in: category) == 0)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func row(_ t: AnalysisTarget) -> some View {
        Toggle(isOn: Binding(
            get: { state.selectedTargets.contains(t.id) },
            set: { _ in state.toggleTarget(t.id) }
        )) {
            HStack(spacing: 8) {
                icon(for: t)
                Text(t.label).font(.callout)
            }
        }
        .toggleStyle(.checkbox)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func icon(for t: AnalysisTarget) -> some View {
        if category == .ai {
            AIToolIconView(tool: AITool(rawValue: String(t.id.dropFirst(3))) ?? .other, size: 18)
        } else {
            Image(systemName: "internaldrive").frame(width: 18).foregroundStyle(.tint)
        }
    }
}
