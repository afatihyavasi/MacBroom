import SwiftUI
import MacBroomCore

/// System cache cleanup: a reviewable, selectable list of regenerable system /
/// app caches surfaced by mole (already filtered by its protection layer).
struct SystemCacheView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager

    private var items: [CleanCandidate] { state.systemCandidates }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                emptyState
            } else {
                selectAllHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { c in
                            row(c)
                            if c.id != items.last?.id { Divider().opacity(0.4) }
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                Label(loc.t(.systemSafety), systemImage: "lock.shield")
                    .font(.caption2).foregroundStyle(.secondary).padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var selectAllHeader: some View {
        let st = state.selectionState(in: .system)
        let symbol = st == true ? "checkmark.square.fill" : (st == nil ? "minus.square.fill" : "square")
        return HStack {
            Button { state.toggleAll(in: .system) } label: {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                        .foregroundStyle(st == false ? Color.secondary : Color.accentColor)
                    Text(loc.t(.selectAll)).font(.caption.weight(.medium))
                }
            }
            .buttonStyle(.borderless)
            Spacer()
            Text(loc.t(.itemsBytes, items.count, Format.bytes(items.reduce(0) { $0 + $1.sizeBytes })))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.bottom, 6)
    }

    private func row(_ c: CleanCandidate) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { state.isSelected(c.path) },
                set: { _ in state.toggle(c.path) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            Text(c.label).font(.caption).lineLimit(1)
            Spacer()
            Text(Format.bytes(c.sizeBytes))
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .help(c.path)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal").font(.largeTitle).foregroundStyle(.green)
            Text(loc.t(.systemEmpty))
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}
