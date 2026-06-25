import SwiftUI
import MacBroomCore

/// Disk Analysis: a read-only scan for the largest files in the user's home
/// folder, with an explicit, Trash-defaulting delete for the selected files.
///
/// SAFETY: the files listed here are user data (not regenerable caches), so the
/// delete path always goes to the Trash via the protection-gated engine sink and
/// is gated behind an inline confirmation that spells out the irreversibility.
struct DiskAnalysisView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager
    @State private var confirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            header
            SHSeparator()
            content
        }
        .padding(Theme.Space.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        .foregroundStyle(Theme.foreground)
        .task { await state.analyzeDisk() }
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(spacing: Theme.Space.sm) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(loc.t(.diskAnalysisTitle)).font(.shTitle)
                Spacer()
            }
            Text(loc.t(.diskAnalysisDesc))
                .font(.shCaption).foregroundStyle(Theme.mutedForeground)
        }
    }

    // MARK: content

    @ViewBuilder private var content: some View {
        switch state.analyzeFlow {
        case .scanning:
            centered { ProgressView().controlSize(.small)
                Text(loc.t(.analyzing)).font(.shBody).foregroundStyle(Theme.mutedForeground) }
        case let .deleting(done, total, freed):
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                SHProgressBar(value: Double(done) / Double(max(total, 1)))
                Text(freed > 0
                     ? loc.t(.removingProgressBytes, done, total, Format.bytes(freed))
                     : loc.t(.removingProgress, done, total))
                    .font(.shCaption).foregroundStyle(Theme.mutedForeground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case let .finished(freed, count, failed, permissionBlocked):
            result(freed: freed, count: count, failed: failed, permissionBlocked: permissionBlocked)
        case let .error(msg):
            centered { Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.destructive)
                Text(msg).font(.shCaption).foregroundStyle(Theme.destructive).multilineTextAlignment(.center) }
        case .ready:
            list
        }
    }

    private func centered<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: Theme.Space.sm) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: list

    @ViewBuilder private var list: some View {
        if state.largeFiles.isEmpty {
            centered { Text(loc.t(.largeFilesEmpty)).font(.shBody).foregroundStyle(Theme.mutedForeground) }
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack {
                    SHSelectAllToggle(state: state.largeSelectionState,
                                      selectTitle: loc.t(.selectAll),
                                      deselectTitle: loc.t(.deselectAll)) {
                        state.toggleAllLargeFiles()
                    }
                    Spacer()
                    SHBadge(text: Format.bytes(state.largeSelectedBytes))
                }

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(state.largeFiles) { file in
                            row(file)
                            if file.id != state.largeFiles.last?.id { SHSeparator().opacity(0.6) }
                        }
                    }
                    .shCard(padding: Theme.Space.xs)
                }
                .frame(maxHeight: .infinity)

                if confirming {
                    inlineConfirm
                } else {
                    Button(role: .destructive) { confirming = true } label: {
                        HStack(spacing: Theme.Space.xs) {
                            Image(systemName: "trash")
                            Text(loc.t(.deleteFilesButton, state.largeSelected.count))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.shDestructive(.md))
                    .disabled(state.largeSelected.isEmpty)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    /// Largest listed file's size, for per-row relative bars (0 when ≤1 item).
    private var maxBytes: Int64 {
        state.largeFiles.count > 1 ? (state.largeFiles.map(\.sizeBytes).max() ?? 0) : 0
    }

    private func row(_ file: LargeFile) -> some View {
        Toggle(isOn: Binding(
            get: { state.largeSelected.contains(file.path) },
            set: { _ in state.toggleLargeFile(file.path) }
        )) {
            HStack(spacing: Theme.Space.sm) {
                VStack(alignment: .leading, spacing: 1) {
                    Text((file.path as NSString).lastPathComponent)
                        .font(.shBody).lineLimit(1)
                    Text(loc.relativeTime(for: Date(timeIntervalSince1970: file.mtime)))
                        .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                    if maxBytes > 0 {
                        SHProgressBar(value: Double(file.sizeBytes) / Double(maxBytes),
                                      tint: Theme.mutedForeground.opacity(0.35))
                            .frame(height: 3).padding(.top, 2)
                    }
                }
                Spacer()
                SHBadge(text: Format.bytes(file.sizeBytes))
                Button { revealInFinder(file.path) } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 11))
                }
                .buttonStyle(.shGhost(.sm))
                .help(loc.t(.revealInFinder))
            }
        }
        .toggleStyle(SHCheckboxStyle())
        .padding(.vertical, 5).padding(.horizontal, Theme.Space.sm)
        .shRowHover()
        .help(file.path)
    }

    /// In-panel destructive confirmation that spells out the irreversibility.
    private var inlineConfirm: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(loc.t(.deleteFilesButton, state.largeSelected.count)).font(.shLabel)
            Text(loc.t(.largeFilesWarning))
                .font(.shCaption).foregroundStyle(Theme.mutedForeground)
            HStack(spacing: Theme.Space.sm) {
                Button(loc.t(.cancel)) { confirming = false }
                    .buttonStyle(.shOutline(.sm))
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(loc.t(.deleteTrashTitle)) {
                    confirming = false
                    let paths = Array(state.largeSelected)
                    Task { await state.deleteLargeFiles(paths) }
                }
                .buttonStyle(.shDestructive(.sm))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.destructive.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.destructive.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: result

    @ViewBuilder
    private func result(freed: Int64, count: Int, failed: Int, permissionBlocked: Bool) -> some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: failed == 0 ? "trash.slash" : "exclamationmark.triangle.fill")
                .font(.system(size: 30)).foregroundStyle(failed == 0 ? Theme.success : Theme.warning)
            Text(loc.t(.freedItems, count, Format.bytes(freed)))
                .font(.shHeadline).multilineTextAlignment(.center)
            if failed > 0 {
                Text(loc.t(.couldntRemove, failed)).font(.shCaption).foregroundStyle(Theme.warning)
                if permissionBlocked {
                    Text(loc.t(.someProtected))
                        .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                        .multilineTextAlignment(.center).padding(.horizontal, Theme.Space.sm)
                    Button(loc.t(.openFDA)) {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                    }.buttonStyle(.shPrimary(.sm))
                }
            }
            Button(loc.t(.done)) { state.analyzeFlow = .ready }.buttonStyle(.shOutline(.sm))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func revealInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}
