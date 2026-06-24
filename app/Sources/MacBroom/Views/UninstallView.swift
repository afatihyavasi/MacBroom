import SwiftUI
import MacBroomCore

/// App uninstaller: pick an app, review what will be removed (the bundle + its
/// leftovers), then remove with explicit confirmation.
struct UninstallView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager
    @AppStorage("deletionMode") private var deletionMode: String = DeleteMode.permanent.rawValue
    @State private var confirming = false

    /// Confirm-button title reflects the user's deletion policy.
    private var deleteActionTitle: String {
        let mode = DeleteMode(rawValue: deletionMode) ?? .permanent
        return loc.t(mode == .trash ? .deleteTrashTitle : .deletePermanentTitle)
    }

    var body: some View {
        Group {
            switch state.appFlow {
            case .loading:
                centered { ProgressView().controlSize(.small)
                    Text(loc.t(.loading)).font(.shBody).foregroundStyle(Theme.mutedForeground) }
            case let .uninstalling(done, total, freed):
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    SHProgressBar(value: Double(done) / Double(max(total, 1)))
                    Text(freed > 0
                         ? loc.t(.removingProgressBytes, done, total, Format.bytes(freed))
                         : loc.t(.removingProgress, done, total))
                        .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            case let .uninstalled(freed, count, failed, permissionBlocked):
                uninstalledResult(freed: freed, count: count, failed: failed, permissionBlocked: permissionBlocked)
            case let .error(msg):
                centered { Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.destructive)
                    Text(msg).font(.shCaption).foregroundStyle(Theme.destructive) }
            case let .reviewing(app):
                reviewList(app)
            case .browsing:
                appList
            }
        }
        .task { await state.loadApps() }
    }

    private func centered<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: Theme.Space.sm) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: result

    @ViewBuilder
    private func uninstalledResult(freed: Int64, count: Int, failed: Int, permissionBlocked: Bool) -> some View {
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
                    Button(loc.t(.openFDA)) { openFullDiskAccess() }.buttonStyle(.shPrimary(.sm))
                } else {
                    Text(loc.t(.itemsInUse))
                        .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                        .multilineTextAlignment(.center).padding(.horizontal, Theme.Space.sm)
                }
            }
            Button(loc.t(.backToList)) { state.backToAppList() }.buttonStyle(.shGhost(.sm))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openFullDiskAccess() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    // MARK: app list

    private var appList: some View {
        Group {
            if state.apps.isEmpty {
                centered { Text(loc.t(.removableEmpty)).font(.shBody).foregroundStyle(Theme.mutedForeground) }
            } else {
                ScrollView {
                    VStack(spacing: Theme.Space.xs) {
                        ForEach(state.apps) { app in
                            Button { Task { await state.reviewApp(app) } } label: {
                                HStack(spacing: Theme.Space.sm) {
                                    AppIconView(path: app.path)
                                    Text(app.name).font(.shBody).lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10)).foregroundStyle(Theme.mutedForeground)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 6)
                                .padding(.horizontal, Theme.Space.sm)
                            }
                            .buttonStyle(.shGhost(.sm))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: review + remove

    private func reviewList(_ app: AppInfo) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack {
                Button { confirming = false; state.backToAppList() } label: {
                    HStack(spacing: 3) { Image(systemName: "chevron.left"); Text(loc.t(.back)) }
                }.buttonStyle(.shGhost(.sm))
                Spacer()
                SHBadge(text: loc.t(.itemsBytes, state.appCandidates.count,
                                    Format.bytes(state.appSelectedBytes)))
            }

            HStack(spacing: Theme.Space.sm) {
                AppIconView(path: app.path)
                Text(app.name).font(.shTitle)
                Spacer()
                SHSelectAllToggle(state: state.appSelectionState,
                                  selectTitle: loc.t(.selectAll),
                                  deselectTitle: loc.t(.deselectAll)) {
                    state.toggleAllAppItems()
                }
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(state.appCandidates) { c in
                        Toggle(isOn: Binding(
                            get: { state.appSelected.contains(c.path) },
                            set: { _ in state.toggleAppItem(c.path) }
                        )) {
                            HStack(spacing: Theme.Space.sm) {
                                Text(c.label).font(.shCaption).lineLimit(1)
                                Spacer()
                                Text(Format.bytes(c.sizeBytes)).font(.shMono).foregroundStyle(Theme.mutedForeground)
                            }
                        }
                        .toggleStyle(SHCheckboxStyle())
                        .padding(.vertical, 5).padding(.horizontal, Theme.Space.sm)
                        .shRowHover()
                        .help(c.path)
                        if c.id != state.appCandidates.last?.id { SHSeparator().opacity(0.6) }
                    }
                }
                .shCard(padding: Theme.Space.xs)
            }
            .frame(maxHeight: .infinity)

            // Inline confirmation — a system confirmationDialog/sheet would steal
            // key-window focus and dismiss the whole MenuBarExtra panel (which
            // reads as "the app closed"). Keeping it in-panel avoids that.
            if confirming {
                inlineConfirm(app)
            } else {
                Button(role: .destructive) { confirming = true } label: {
                    HStack(spacing: Theme.Space.xs) { Image(systemName: "trash"); Text(loc.t(.remove)) }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.shDestructive(.md))
                .disabled(state.appSelected.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// In-panel destructive confirmation (replaces the focus-stealing dialog).
    private func inlineConfirm(_ app: AppInfo) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(loc.t(.confirmDeleteTitle, app.name, state.appSelected.count))
                .font(.shLabel)
            Text(loc.t(.confirmDeleteMessage))
                .font(.shCaption).foregroundStyle(Theme.mutedForeground)
            HStack(spacing: Theme.Space.sm) {
                Button(loc.t(.cancel)) { confirming = false }
                    .buttonStyle(.shOutline(.sm))
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(deleteActionTitle) {
                    confirming = false
                    Task { await state.uninstall() }
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
}
