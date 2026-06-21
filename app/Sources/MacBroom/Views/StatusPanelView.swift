import SwiftUI
import MacBroomCore

/// Compact live disk + memory usage cards shown under the header.
struct StatusPanelView: View {
    @EnvironmentObject var loc: LocalizationManager
    let status: SystemStatus

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            UsageCard(
                title: loc.t(.disk),
                systemImage: "internaldrive",
                percent: status.disk.usedPercent,
                detail: loc.t(.diskFree, Format.bytes(status.disk.free))
            )
            if let mem = status.memory {
                UsageCard(
                    title: loc.t(.memory),
                    systemImage: "memorychip",
                    percent: mem.usedPercent,
                    detail: loc.t(.memoryTotal, Format.bytes(mem.total))
                )
            }
        }
    }
}

/// A labeled mini usage card that tints its bar by pressure.
private struct UsageCard: View {
    let title: String
    let systemImage: String
    let percent: Int
    let detail: String

    private var tint: Color {
        switch percent {
        case ..<70: return Theme.success
        case 70..<88: return Theme.warning
        default: return Theme.destructive
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(spacing: Theme.Space.xs) {
                Image(systemName: systemImage).font(.system(size: 11))
                    .foregroundStyle(Theme.mutedForeground)
                Text(title).font(.shLabel)
                Spacer()
                Text("\(percent)%").font(.shMono).foregroundStyle(Theme.mutedForeground)
            }
            SHProgressBar(value: Double(percent) / 100, tint: tint)
            Text(detail).font(.shCaption).foregroundStyle(Theme.mutedForeground)
        }
        .shCard()
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(percent)% — \(detail)"))
    }
}
