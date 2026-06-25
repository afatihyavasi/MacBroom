import SwiftUI
import MacBroomCore

/// Observable wrapper around `Localization` so SwiftUI views re-render the
/// instant the user changes language in Settings. Inject via `.environmentObject`
/// and read strings with `loc.t(.someKey)`.
@MainActor
final class LocalizationManager: ObservableObject {
    @Published var language: AppLanguage {
        didSet { Localization.current = language }
    }

    init() {
        // Seed from the persisted selection (defaults to `.system`, which
        // resolves to the OS language, English when unsupported).
        language = Localization.current
    }

    /// Localize `key`, applying `String(format:)` when interpolation args are given.
    func t(_ key: L10n, _ args: CVarArg...) -> String {
        let format = Localization.string(key, language: language)
        return args.isEmpty ? format : String(format: format, arguments: args)
    }

    /// Relative time ("2 min ago") in the app's *selected* language.
    /// `RelativeDateTimeFormatter` follows the OS locale by default, so it would
    /// render Turkish ("2 dk. önce") even with the English UI — set its locale
    /// from our language picker on every call instead.
    func relativeTime(for date: Date, relativeTo reference: Date = Date()) -> String {
        Self.relativeFormatter.locale = language.locale
        return Self.relativeFormatter.localizedString(for: date, relativeTo: reference)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated; return f
    }()
}
