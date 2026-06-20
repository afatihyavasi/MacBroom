import SwiftUI
import MacBroomCore

/// App uninstaller: pick an app, review what will be removed (the bundle + its
/// leftovers), then remove with explicit confirmation.
struct UninstallView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager
    @State private var confirming = false

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
            case let .uninstalled(freed, failed, permissionBlocked):
                uninstalledResult(freed: freed, failed: failed, permissionBlocked: permissionBlocked)
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
    private func uninstalledResult(freed: Int64, failed: Int, permissionBlocked: Bool) -> some View {
        VStack(spacing: Theme.Space.md) {
            if failed == 0 {
                Image(systemName: "trash.slash").font(.system(size: 30)).foregroundStyle(Theme.success)
                Text(loc.t(.removedFreed, Format.bytes(freed))).font(.shHeadline)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30)).foregroundStyle(Theme.warning)
                Text(loc.t(.removedPartial, Format.bytes(freed), failed))
                    .font(.shHeadline).multilineTextAlignment(.center)
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
                Button { state.backToAppList() } label: {
                    HStack(spacing: 3) { Image(systemName: "chevron.left"); Text(loc.t(.back)) }
                }.buttonStyle(.shGhost(.sm))
                Spacer()
                SHBadge(text: loc.t(.itemsBytes, state.appCandidates.count,
                                    Format.bytes(state.appSelectedBytes)))
            }

            HStack(spacing: Theme.Space.sm) {
                AppIconView(path: app.path)
                Text(app.name).font(.shTitle)
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

            Button(role: .destructive) { confirming = true } label: {
                HStack(spacing: Theme.Space.xs) { Image(systemName: "trash"); Text(loc.t(.remove)) }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.shDestructive(.md))
            .disabled(state.appSelected.isEmpty)
            .confirmationDialog(
                loc.t(.confirmDeleteTitle, app.name, state.appSelected.count),
                isPresented: $confirming, titleVisibility: .visible
            ) {
                Button(loc.t(.deletePermanentTitle), role: .destructive) { Task { await state.uninstall() } }
                Button(loc.t(.cancel), role: .cancel) {}
            } message: {
                Text(loc.t(.confirmDeleteMessage))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
