import SwiftUI
import MacBroomCore

/// The headline feature: safe, per-tool AI cache cleanup.
/// Candidates are pre-filtered by mole's protection layer to regenerable caches;
/// auth / sessions / memory / history are never listed here.
struct AICacheView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            automationBanner
            if state.aiGroups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: Theme.Space.sm) {
                        ForEach(state.aiGroups) { AIToolSection(group: $0) }
                    }
                }
                .frame(maxHeight: .infinity)

                safetyFootnote
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Info + entry point to the automatic-cleaning panel. Tinted brighter when
    /// at least one AI tool already has automation enabled.
    private var automationBanner: some View {
        let active = state.installedTargets(in: .ai).contains { state.rule(for: $0.id).isEnabled }
        return HStack(spacing: Theme.Space.sm) {
            Image(systemName: "clock.arrow.circlepath").foregroundStyle(Theme.accent)
            Text(loc.t(.aiAutomationInfo))
                .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Theme.Space.xs)
            Button(loc.t(.aiAutomationOpen)) {
                AutomationWindowController.shared.show(state: state, loc: loc)
            }
            .buttonStyle(.shOutline(.sm)).fixedSize()
        }
        .padding(Theme.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.accent.opacity(active ? 0.12 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.accent.opacity(active ? 0.4 : 0.2), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "checkmark.seal").font(.system(size: 30)).foregroundStyle(Theme.success)
            Text(loc.t(.aiEmpty)).font(.shBody).foregroundStyle(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var safetyFootnote: some View {
        HStack(alignment: .top, spacing: Theme.Space.xs) {
            Image(systemName: "lock.shield").font(.system(size: 10))
            Text(loc.t(.aiSafety))
        }
        .font(.shCaption)
        .foregroundStyle(Theme.mutedForeground)
    }
}

/// One collapsible tool section (Claude, Codex, Gemini, …).
private struct AIToolSection: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager
    let group: AIToolGroup
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Largest candidate's size in this group, for per-row relative bars
    /// (0 when ≤1 item, which suppresses the bar).
    private var maxBytes: Int64 {
        group.candidates.count > 1 ? (group.candidates.map(\.sizeBytes).max() ?? 0) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if expanded {
                VStack(spacing: 0) {
                    ForEach(group.candidates) { c in
                        SHSeparator().opacity(0.6)
                        candidateRow(c)
                    }
                }
                .padding(.top, 4)
            }
        }
        .shCard(padding: Theme.Space.sm)
    }

    private var header: some View {
        HStack(spacing: Theme.Space.sm) {
            SHTriCheckbox(state: state.selectionState(for: group), label: group.tool.displayName) { state.toggleGroup(group) }
            AIToolIconView(tool: group.tool, size: 18)
            Text(group.tool.displayName).font(.shLabel)
            Spacer()
            SHBadge(text: loc.t(.groupCountBytes, group.count, Format.bytes(group.totalBytes)))
            Button {
                if reduceMotion {
                    expanded.toggle()
                } else {
                    withAnimation(.snappy(duration: 0.18)) { expanded.toggle() }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.mutedForeground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(expanded ? "Collapse" : "Expand"))
        }
    }

    private func candidateRow(_ c: CleanCandidate) -> some View {
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
        .padding(.leading, 24)
        .padding(.vertical, 5)
        .padding(.horizontal, Theme.Space.xs)
        .shRowHover()
        .help(c.path)
    }
}
