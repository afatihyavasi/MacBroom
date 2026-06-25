import SwiftUI
import MacBroomCore

/// A compact, dependency-free bar chart of reclaimed space per recent cleanup.
/// Built from the design-system primitives (no Swift Charts) to match the rest
/// of the app. Bars are oldest → newest; height is relative to the largest bar.
struct CleanHistoryChart: View {
    @EnvironmentObject var loc: LocalizationManager
    let records: [CleanRecord]   // newest first (as stored)

    private let maxBars = 14
    private let chartHeight: CGFloat = 56

    var body: some View {
        // Oldest → newest so the timeline reads left → right.
        let bars = Array(records.prefix(maxBars).reversed())
        let peak = max(bars.map(\.freedBytes).max() ?? 0, 1)

        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, rec in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Theme.accent.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeight(rec.freedBytes, peak: peak))
                        .help("\(loc.t(rec.kindKey)) · \(Format.bytes(rec.freedBytes)) · \(loc.relativeTime(for: rec.date))")
                }
            }
            .frame(height: chartHeight, alignment: .bottom)
            .accessibilityElement()
            .accessibilityLabel(loc.t(.historyChartTitle))
        }
    }

    /// Bytes → bar height, with a visible floor so tiny cleanups still register.
    private func barHeight(_ bytes: Int64, peak: Int64) -> CGFloat {
        let ratio = CGFloat(max(bytes, 0)) / CGFloat(peak)
        return max(4, ratio * chartHeight)
    }
}
