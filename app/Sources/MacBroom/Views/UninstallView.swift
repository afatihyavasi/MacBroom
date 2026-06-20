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
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(loc.t(.loading)).font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 16)
            case let .uninstalling(done, total):
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(done), total: Double(max(total, 1)))
                    Text(loc.t(.removingProgress, done, total)).font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            case let .uninstalled(freed, failed, permissionBlocked):
                uninstalledResult(freed: freed, failed: failed, permissionBlocked: permissionBlocked)
            case let .error(msg):
                Label(msg, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red).padding(.vertical, 8)
            case let .reviewing(app):
                reviewList(app)
            case .browsing:
                appList
            }
        }
        .task { await state.loadApps() }
    }

    // MARK: result

    /// Outcome screen. When every selected item was removed we celebrate; when
    /// some couldn't be deleted we tell the user how many and — if the cause was
    /// a permission wall — offer the Full Disk Access shortcut.
    @ViewBuilder
    private func uninstalledResult(freed: Int64, failed: Int, permissionBlocked: Bool) -> some View {
        VStack(spacing: 8) {
            if failed == 0 {
                Image(systemName: "trash.slash").font(.largeTitle).foregroundStyle(.green)
                Text(loc.t(.removedFreed, Format.bytes(freed))).font(.callout.weight(.medium))
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle).foregroundStyle(.orange)
                Text(loc.t(.removedPartial, Format.bytes(freed), failed))
                    .font(.callout.weight(.medium)).multilineTextAlignment(.center)
                if permissionBlocked {
                    Text(loc.t(.someProtected))
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 8)
                    Button(loc.t(.openFDA)) { openFullDiskAccess() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Text(loc.t(.itemsInUse))
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 8)
                }
            }
            Button(loc.t(.backToList)) { state.backToAppList() }.buttonStyle(.link)
        }.frame(maxWidth: .infinity).padding(.vertical, 14)
    }

    private func openFullDiskAccess() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    // MARK: app list

    private var appList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.apps.isEmpty {
                Text(loc.t(.removableEmpty))
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(state.apps) { app in
                            Button { Task { await state.reviewApp(app) } } label: {
                                HStack(spacing: 8) {
                                    AppIconView(path: app.path)
                                    Text(app.name).font(.callout).lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                            Divider().opacity(0.3)
                        }
                    }
                }.frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: review + remove

    private func reviewList(_ app: AppInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { state.backToAppList() } label: {
                    Image(systemName: "chevron.left"); Text(loc.t(.back))
                }.buttonStyle(.borderless)
                Spacer()
                Text(loc.t(.itemsBytes, state.appCandidates.count, Format.bytes(state.appSelectedBytes)))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }

            Text(app.name).font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(state.appCandidates) { c in
                        HStack(spacing: 8) {
                            Toggle("", isOn: Binding(
                                get: { state.appSelected.contains(c.path) },
                                set: { _ in state.toggleAppItem(c.path) }
                            )).labelsHidden().toggleStyle(.checkbox)
                            Text(c.label).font(.caption).lineLimit(1)
                            Spacer()
                            Text(Format.bytes(c.sizeBytes))
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3).help(c.path)
                    }
                }
            }.frame(maxHeight: 240)

            Button(role: .destructive) {
                confirming = true
            } label: {
                Label(loc.t(.remove), systemImage: "trash").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
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
    }
}
