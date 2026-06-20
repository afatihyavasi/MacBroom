import SwiftUI
import MacBroomCore

/// System cache cleanup: a reviewable, selectable list of regenerable system /
/// app caches surfaced by mole (already filtered by its protection layer).
struct SystemCacheView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager

    private var items: [CleanCandidate] { state.systemCandidates }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            if items.isEmpty {
                emptyState
            } else {
                selectAllHeader
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(items) { c in
                            row(c)
                            if c.id != items.last?.id { SHSeparator().opacity(0.6) }
                        }
                    }
                    .shCard(padding: Theme.Space.xs)
                }
                .frame(maxHeight: .infinity)

                HStack(alignment: .top, spacing: Theme.Space.xs) {
                    Image(systemName: "lock.shield").font(.system(size: 10))
                    Text(loc.t(.systemSafety))
                }
                .font(.shCaption).foregroundStyle(Theme.mutedForeground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var selectAllHeader: some View {
        HStack(spacing: Theme.Space.sm) {
            SHSelectAllToggle(state: state.selectionState(in: .system),
                              selectTitle: loc.t(.selectAll),
                              deselectTitle: loc.t(.deselectAll)) {
                state.toggleAll(in: .system)
            }
            Spacer()
            SHBadge(text: loc.t(.itemsBytes, items.count,
                               Format.bytes(items.reduce(0) { $0 + $1.sizeBytes })))
        }
    }

    private func row(_ c: CleanCandidate) -> some View {
        Toggle(isOn: Binding(
            get: { state.isSelected(c.path) },
            set: { _ in state.toggle(c.path) }
        )) {
            HStack(spacing: Theme.Space.sm) {
                Text(c.label).font(.shCaption).lineLimit(1)
                Spacer()
                Text(Format.bytes(c.sizeBytes)).font(.shMono).foregroundStyle(Theme.mutedForeground)
            }
        }
        .toggleStyle(SHCheckboxStyle())
        .padding(.vertical, 6)
        .padding(.horizontal, Theme.Space.sm)
        .shRowHover()
        .help(c.path)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "checkmark.seal").font(.system(size: 30)).foregroundStyle(Theme.success)
            Text(loc.t(.systemEmpty)).font(.shBody).foregroundStyle(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
