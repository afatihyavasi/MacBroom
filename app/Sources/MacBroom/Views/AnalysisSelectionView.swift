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
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(loc.t(.analyzeQuestion)).font(.shHeadline)
                Text(loc.t(.analyzeSubtitle)).font(.shCaption).foregroundStyle(Theme.mutedForeground)
            }

            if items.isEmpty {
                Spacer()
                Text(loc.t(.noTargetsInCategory))
                    .font(.shBody).foregroundStyle(Theme.mutedForeground)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: Theme.Space.xs) {
                        ForEach(items) { row($0) }
                    }
                }
                .frame(maxHeight: .infinity)

                HStack(spacing: Theme.Space.sm) {
                    SHSelectAllToggle(state: state.targetsSelectionState(in: category),
                                      selectTitle: loc.t(.selectAll),
                                      deselectTitle: loc.t(.deselectAll)) {
                        state.toggleAllTargets(in: category)
                    }
                    Spacer()
                    Button {
                        Task { await state.scanSelected(category: category) }
                    } label: {
                        Text(loc.t(.analyzeButton, state.selectedTargetCount(in: category)))
                    }
                    .buttonStyle(.shPrimary(.sm))
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
            HStack(spacing: Theme.Space.sm) {
                icon(for: t)
                Text(label(for: t)).font(.shBody)
                Spacer()
            }
        }
        .toggleStyle(SHCheckboxStyle())
        .padding(.vertical, 6)
        .padding(.horizontal, Theme.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    /// System target labels arrive from the engine in Turkish; localize the
    /// known ones. AI targets keep their (language-neutral) brand labels.
    private func label(for t: AnalysisTarget) -> String {
        switch t.id {
        case "system:app-caches": return loc.t(.targetAppCaches)
        case "system:editors":    return loc.t(.targetEditors)
        case "system:gui-apps":   return loc.t(.targetGuiApps)
        case "system:dev-misc":   return loc.t(.targetDevMisc)
        case "developer:xcode":      return loc.t(.targetXcode)
        case "developer:pkg-caches": return loc.t(.targetPkgCaches)
        default:                  return t.label
        }
    }

    @ViewBuilder
    private func icon(for t: AnalysisTarget) -> some View {
        if category == .ai {
            AIToolIconView(tool: AITool(rawValue: String(t.id.dropFirst(3))) ?? .other, size: 18)
        } else {
            Image(systemName: "internaldrive").frame(width: 18).foregroundStyle(Theme.accent)
        }
    }
}
