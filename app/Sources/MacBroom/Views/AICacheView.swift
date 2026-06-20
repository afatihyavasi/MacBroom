import SwiftUI
import MacBroomCore

/// The headline feature: safe, per-tool AI cache cleanup.
/// Candidates are pre-filtered by mole's protection layer to regenerable caches;
/// auth / sessions / memory / history are never listed here.
struct AICacheView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.aiGroups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(state.aiGroups) { group in
                            AIToolSection(group: group)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: .infinity)

                safetyFootnote
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal")
                .font(.largeTitle).foregroundStyle(.green)
            Text(loc.t(.aiEmpty))
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var safetyFootnote: some View {
        Label(loc.t(.aiSafety), systemImage: "lock.shield")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }
}

/// One collapsible tool section (Claude, Codex, Gemini, …).
private struct AIToolSection: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager
    let group: AIToolGroup
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                tristateBox
                AIToolIconView(tool: group.tool, size: 18)
                Text(group.tool.displayName).font(.callout.weight(.medium))
                Spacer()
                Text(loc.t(.groupCountBytes, group.count, Format.bytes(group.totalBytes)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button {
                    withAnimation(.snappy(duration: 0.18)) { expanded.toggle() }
                } label: {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)

            if expanded {
                ForEach(group.candidates) { c in
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
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 26)
                    .help(c.path)
                }
            }
        }
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var tristateBox: some View {
        let stateValue = state.selectionState(for: group)
        let symbol = stateValue == true ? "checkmark.square.fill"
            : (stateValue == nil ? "minus.square.fill" : "square")
        return Button {
            state.toggleGroup(group)
        } label: {
            Image(systemName: symbol)
                .foregroundStyle(stateValue == false ? Color.secondary : Color.accentColor)
        }
        .buttonStyle(.borderless)
    }
}
