import SwiftUI
import MacBroomCore

/// Generic cache cleanup for an arbitrary `CleanCategory`: a reviewable,
/// selectable list of regenerable caches surfaced by the engine (already
/// filtered by its protection layer). Derives entirely from `category`, so a
/// new enum case yields a working results view with no per-category code.
struct CategoryCacheView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager

    let category: CleanCategory

    private var items: [CleanCandidate] {
        state.candidates(in: category).sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// Largest item's size, for per-row relative bars (0 when ≤1 item).
    private var maxBytes: Int64 {
        items.count > 1 ? (items.map(\.sizeBytes).max() ?? 0) : 0
    }

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
            SHSelectAllToggle(state: state.selectionState(in: category),
                              selectTitle: loc.t(.selectAll),
                              deselectTitle: loc.t(.deselectAll)) {
                state.toggleAll(in: category)
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
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Theme.Space.sm) {
                    Text(c.label).font(.shCaption).lineLimit(1)
                    Spacer()
                    Text(Format.bytes(c.sizeBytes)).font(.shMono).foregroundStyle(Theme.mutedForeground)
                }
                if maxBytes > 0 {
                    SHProgressBar(value: Double(c.sizeBytes) / Double(maxBytes),
                                  tint: Theme.mutedForeground.opacity(0.35))
                        .frame(height: 3)
                }
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
