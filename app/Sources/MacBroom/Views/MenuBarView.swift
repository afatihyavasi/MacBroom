import SwiftUI
import MacBroomCore

/// Root menu bar panel. Headlines safe AI cache cleanup; system cleanup and the
/// status panel slot in alongside in later stages.
struct MenuBarView: View {
    @EnvironmentObject var state: AppState
    @State private var tab: CleanCategory = .ai

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let status = state.status {
                StatusPanelView(status: status)
            }
            Divider()
            content
            Divider()
            controls
        }
        .padding(14)
        .task {
            await state.refreshStatus()
            if case .idle = state.phase { await state.scan() }
        }
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars.inverse")
                .font(.title3).foregroundStyle(.tint)
            Text("MacBroom").font(.headline)
            Spacer()
            Button {
                Task { await state.scan() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Yeniden tara")
            .disabled(state.phase == .scanning)
        }
    }

    // MARK: content

    @ViewBuilder private var content: some View {
        switch state.phase {
        case .idle, .scanning:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("AI cache'leri taranıyor…").font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
        case let .cleaning(done, total):
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                Text("Temizleniyor… \(done)/\(total)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        case let .finished(freed):
            VStack(spacing: 8) {
                Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(.green)
                Text("\(Format.bytes(freed)) boşaltıldı")
                    .font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        case let .error(msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.red).padding(.vertical, 8)
        case .ready:
            VStack(spacing: 10) {
                Picker("", selection: $tab) {
                    ForEach(CleanCategory.allCases) { cat in
                        Text(tabTitle(cat)).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                switch tab {
                case .ai:     AICacheView()
                case .system: SystemCacheView()
                }
            }
        }
    }

    private func tabTitle(_ cat: CleanCategory) -> String {
        let bytes = state.candidates(in: cat).reduce(0) { $0 + $1.sizeBytes }
        return bytes > 0 ? "\(cat.title) · \(Format.bytes(bytes))" : cat.title
    }

    // MARK: controls

    private var controls: some View {
        HStack {
            if case .ready = state.phase {
                Text("\(Format.bytes(state.selectedBytes)) seçili")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if case .ready = state.phase {
                Button("Temizle") { Task { await state.clean() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.selected.isEmpty)
            }
            Button("Çıkış") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
        }
    }
}
