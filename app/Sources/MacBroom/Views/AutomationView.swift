import SwiftUI
import MacBroomCore

/// The Automation tab: per-AI-tool automatic-clean scheduling, INSIDE the
/// menu-bar panel. Every control is panel-safe (segmented / DatePicker /
/// Stepper) — never an NSMenu picker, which would steal focus and dismiss the
/// panel. Edits a local DRAFT; nothing applies until "Save" (AppState.applyRules).
struct AutomationView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager
    @State private var draft: [String: AutoCleanRule] = [:]

    private var tools: [AnalysisTarget] { state.installedTargets(in: .ai) }
    private var dirty: Bool { tools.contains { draft[$0.id] != state.rule(for: $0.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(loc.t(.automationDesc)).font(.shCaption).foregroundStyle(Theme.mutedForeground)

            if tools.isEmpty {
                Spacer()
                Text(loc.t(.autoCleanNoTools)).font(.shBody).foregroundStyle(Theme.mutedForeground)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: Theme.Space.sm) {
                        ForEach(tools) { toolCard($0) }
                    }
                }
                .frame(maxHeight: .infinity)

                SHSeparator()
                HStack {
                    Spacer()
                    Button(loc.t(.save)) { state.applyRules(draft) }
                        .buttonStyle(.shPrimary(.sm))
                        .disabled(!dirty)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear(perform: seedDraft)
    }

    private func seedDraft() {
        var d: [String: AutoCleanRule] = [:]
        for t in tools { d[t.id] = state.rule(for: t.id) }
        draft = d
    }

    private func rule(_ id: String) -> Binding<AutoCleanRule> {
        Binding(get: { draft[id] ?? .off }, set: { draft[id] = $0 })
    }

    private func toolCard(_ t: AnalysisTarget) -> some View {
        let r = rule(t.id)
        let enabled = r.wrappedValue.isEnabled
        return VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(spacing: Theme.Space.sm) {
                AIToolIconView(tool: AITool(rawValue: String(t.id.dropFirst(3))) ?? .other, size: 18)
                Text(t.label).font(.shLabel)
                Spacer()
            }
            // Frequency as a full-width segmented control (no NSMenu).
            Picker("", selection: r.frequency) {
                ForEach(CleanFrequency.selectable) { Text(loc.t($0.titleKey)).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()

            conditionalControls(r)

            if enabled, let last = state.lastRun(for: t.id) {
                Text(loc.t(.autoCleanLast, loc.relativeTime(for: last)))
                    .font(.shCaption).foregroundStyle(Theme.mutedForeground)
            }
        }
        .padding(Theme.Space.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Theme.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(enabled ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1)
        )
    }

    @ViewBuilder private func conditionalControls(_ r: Binding<AutoCleanRule>) -> some View {
        switch r.wrappedValue.frequency {
        case .off, .hourly:
            EmptyView()   // hourly is no longer selectable (migrated to .daily)
        case .daily:
            timeRow(r)
        case .weekly:
            // Weekday as a 7-segment control (short localized day names).
            Picker("", selection: r.weekday) {
                ForEach(1...7, id: \.self) { Text(weekdayShort($0)).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            timeRow(r)
        case .monthly:
            labeledRow(loc.t(.monthDayLabel)) {
                HStack(spacing: Theme.Space.xs) {
                    Text("\(r.wrappedValue.dayOfMonth)").font(.shCaption).monospacedDigit()
                    Stepper("", value: r.dayOfMonth, in: 1...28).labelsHidden().fixedSize()
                }
            }
            timeRow(r)
        }
    }

    private func timeRow(_ r: Binding<AutoCleanRule>) -> some View {
        labeledRow(loc.t(.timeLabel)) {
            DatePicker("", selection: timeBinding(r), displayedComponents: .hourAndMinute)
                .labelsHidden().fixedSize()
        }
    }

    private func labeledRow<C: View>(_ label: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack {
            Text(label).font(.shCaption).foregroundStyle(Theme.mutedForeground)
            Spacer()
            control()
        }
    }

    private func timeBinding(_ r: Binding<AutoCleanRule>) -> Binding<Date> {
        Binding(
            get: {
                var c = DateComponents(); c.year = 2000; c.month = 1; c.day = 1
                c.hour = r.wrappedValue.hour; c.minute = r.wrappedValue.minute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                var rule = r.wrappedValue
                rule.hour = c.hour ?? 0
                rule.minute = c.minute ?? 0
                r.wrappedValue = rule
            }
        )
    }

    /// Short localized weekday name for Calendar weekday index (1=Sun … 7=Sat).
    private func weekdayShort(_ weekday: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: loc.language.resolved.rawValue)
        let symbols = cal.shortWeekdaySymbols
        let idx = (weekday - 1) % 7
        return symbols.indices.contains(idx) ? symbols[idx] : "\(weekday)"
    }
}
