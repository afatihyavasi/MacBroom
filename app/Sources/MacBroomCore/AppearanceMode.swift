import Foundation

/// UI appearance override. `.system` follows the macOS setting.
public enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    public var id: String { rawValue }
    public static let defaultsKey = "appearanceMode"

    public var titleKey: L10n {
        switch self {
        case .system: return .appearanceSystem
        case .light:  return .appearanceLight
        case .dark:   return .appearanceDark
        }
    }

    /// Persisted selection (defaults to `.system`).
    public static var current: AppearanceMode {
        get { AppearanceMode(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }
}
