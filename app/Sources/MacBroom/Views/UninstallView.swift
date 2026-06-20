import SwiftUI
import MacBroomCore

/// App uninstaller: pick an app, review what will be removed (the bundle + its
/// leftovers), then remove with explicit confirmation.
struct UninstallView: View {
    @EnvironmentObject var state: AppState
    @State private var confirming = false

    var body: some View {
        Group {
            switch state.appFlow {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Yükleniyor…").font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 16)
            case let .uninstalling(done, total):
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(done), total: Double(max(total, 1)))
                    Text("Kaldırılıyor… \(done)/\(total)").font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            case let .uninstalled(freed):
                VStack(spacing: 8) {
                    Image(systemName: "trash.slash").font(.largeTitle).foregroundStyle(.green)
                    Text("Kaldırıldı · \(Format.bytes(freed)) boşaltıldı").font(.callout.weight(.medium))
                    Button("Listeye dön") { state.backToAppList() }.buttonStyle(.link)
                }.frame(maxWidth: .infinity).padding(.vertical, 14)
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

    // MARK: app list

    private var appList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.apps.isEmpty {
                Text("Kaldırılabilir uygulama bulunamadı.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(state.apps) { app in
                            Button { Task { await state.reviewApp(app) } } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "app.dashed").foregroundStyle(.tint)
                                    Text(app.name).font(.callout).lineLimit(1)
                                    Spacer()
                                    Text(Format.bytes(app.sizeBytes))
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
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
                }.frame(maxHeight: 320)
            }
        }
    }

    // MARK: review + remove

    private func reviewList(_ app: AppInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { state.backToAppList() } label: {
                    Image(systemName: "chevron.left"); Text("Geri")
                }.buttonStyle(.borderless)
                Spacer()
                Text("\(state.appCandidates.count) öğe · \(Format.bytes(state.appSelectedBytes))")
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
                Label("Kaldır", systemImage: "trash").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(state.appSelected.isEmpty)
            .confirmationDialog(
                "\(app.name) ve seçili \(state.appSelected.count) öğe kalıcı olarak silinsin mi?",
                isPresented: $confirming, titleVisibility: .visible
            ) {
                Button("Kalıcı olarak sil", role: .destructive) { Task { await state.uninstall() } }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Bu işlem geri alınamaz. Sistem-kritik bileşenler korunur.")
            }
        }
    }
}
