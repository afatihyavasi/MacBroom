import Foundation

/// Builds the `launchd` plist for a scheduled auto-clean job. Pure/Foundation
/// so the schedule mapping is unit-testable; the app layer handles file I/O and
/// `launchctl`.
public enum LaunchAgent {
    /// Label prefix for every MacBroom auto-clean agent (used to find/remove ours).
    public static let labelPrefix = "com.macbroom.autoclean."

    public static func label(for targetId: String) -> String {
        labelPrefix + targetId.replacingOccurrences(of: ":", with: ".")
    }

    /// Serialize a LaunchAgent plist. Returns nil for a disabled rule.
    public static func plistData(label: String, programArguments: [String],
                                 environment: [String: String], rule: AutoCleanRule) -> Data? {
        guard rule.isEnabled else { return nil }
        var dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": programArguments,
            "EnvironmentVariables": environment,
            "RunAtLoad": false,
            "ProcessType": "Background",
        ]
        if let interval = rule.launchdStartInterval {
            dict["StartInterval"] = interval
        } else if let calendar = rule.launchdCalendarInterval {
            dict["StartCalendarInterval"] = calendar
        }
        return try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }
}
