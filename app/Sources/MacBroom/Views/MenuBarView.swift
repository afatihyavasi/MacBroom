import SwiftUI
import MacBroomCore

/// Minimal menu bar panel for the engine bridge skeleton.
/// The rich, per-tool AI cache UI lands in the AI-cache stage.
struct MenuBarView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            switch state.phase {
            case .idle:
                Text("Temizlenebilir alanı taramak için başlayın.")
                    .font(.callout).foregroundStyle(.secondary)
            case .scanning:
                ProgressView("Taranıyor…").controlSize(.small)
            case .ready, .cleaning, .finished, .error:
                summary
            }

            controls
        }
        .padding(16)
        .task { await state.refreshDisk() }
    }

    private var header: some View {
        HStack {
            Image(systemName: "wand.and.stars.inverse").foregroundStyle(.tint)
            Text("MacBroom").font(.headline)
            Spacer()
            if let d = state.disk {
                Text("Disk %\(d.usedPercent)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var summary: some View {
        switch state.phase {
        case .ready:
            Label("\(state.candidates.count) öğe · \(Format.bytes(state.selectedBytes)) seçili",
                  systemImage: "checkmark.circle")
                .font(.callout)
        case let .cleaning(done, total):
            ProgressView(value: Double(done), total: Double(total)) {
                Text("Temizleniyor… \(done)/\(total)")
            }.controlSize(.small)
        case let .finished(freed):
            Label("\(Format.bytes(freed)) boşaltıldı", systemImage: "sparkles")
                .font(.callout).foregroundStyle(.green)
        case let .error(msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.red)
        default:
            EmptyView()
        }
    }

    private var controls: some View {
        HStack {
            Button("Tara") { Task { await state.scan() } }
                .disabled(state.phase == .scanning)
            if case .ready = state.phase {
                Button("Temizle") { Task { await state.clean() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.selected.isEmpty)
            }
            Spacer()
            Button("Çıkış") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
        }
    }
}
