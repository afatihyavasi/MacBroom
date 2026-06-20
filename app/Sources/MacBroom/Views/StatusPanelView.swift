import SwiftUI
import MacBroomCore

/// Compact live disk + memory usage panel shown under the header.
struct StatusPanelView: View {
    @EnvironmentObject var loc: LocalizationManager
    let status: SystemStatus

    var body: some View {
        HStack(spacing: 14) {
            UsageBar(
                title: loc.t(.disk),
                systemImage: "internaldrive",
                percent: status.disk.usedPercent,
                detail: loc.t(.diskFree, Format.bytes(status.disk.free))
            )
            if let mem = status.memory {
                UsageBar(
                    title: loc.t(.memory),
                    systemImage: "memorychip",
                    percent: mem.usedPercent,
                    detail: loc.t(.memoryTotal, Format.bytes(mem.total))
                )
            }
        }
    }
}

/// A labeled mini usage bar that tints by pressure.
private struct UsageBar: View {
    let title: String
    let systemImage: String
    let percent: Int
    let detail: String

    private var tint: Color {
        switch percent {
        case ..<70: return .green
        case 70..<88: return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.caption2)
                Text(title).font(.caption2.weight(.medium))
                Spacer()
                Text("%\(percent)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule().fill(tint)
                        .frame(width: max(2, geo.size.width * CGFloat(min(max(percent, 0), 100)) / 100))
                }
            }
            .frame(height: 5)
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
