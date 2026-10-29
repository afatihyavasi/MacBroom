import Foundation

/// Keeps an engine run away from macOS privacy-protected (TCC) folders when
/// MacBroom has no Full Disk Access.
///
/// Without FDA, every first touch of ~/Documents, ~/Downloads, another app's
/// container, the Calendar/Contacts stores, … pops its own "MacBroom would like
/// to access …" dialog — a scan walks enough of them to raise a stream of
/// prompts. Instead of patching each mole cleaner, the engine runs under a
/// `sandbox-exec` profile that denies those roots up front: the sandbox refuses
/// the access before TCC is consulted, so no dialog appears, and the cleaners
/// simply see "Operation not permitted" and skip the path.
public enum PrivacySandbox {
    public static let executable = "/usr/bin/sandbox-exec"

    /// Home-relative roots guarded by TCC prompts (or FDA-only stores that a
    /// limited run has no business reading anyway).
    public static let protectedRoots: [String] = [
        "Desktop", "Documents", "Downloads", "Pictures",
        "Library/Mobile Documents",          // iCloud Drive
        "Library/Containers",                // other apps' data
        "Library/Group Containers",
        "Library/Mail", "Library/Messages", "Library/Safari",
        "Library/Calendars", "Library/Reminders",
        "Library/Application Support/AddressBook",
    ]

    /// SBPL profile: allow everything except reads/writes under the roots.
    /// `readable` dirs are re-allowed for reading after the deny (in SBPL the
    /// later rule wins) — the engine and mole must stay loadable even when they
    /// live under a protected root, e.g. a dev build inside ~/Documents.
    /// Paths are symlink-resolved: the sandbox matches real paths, so a profile
    /// written against /var/… would never match /private/var/….
    public static func profile(home: String, readable: [String] = []) -> String {
        let realHome = resolved(home)
        let denies = protectedRoots
            .map { "(subpath \(quoted(realHome + "/" + $0)))" }
            .joined()
        let allows = readable
            .map { "(allow file-read* (subpath \(quoted(resolved($0)))))" }
            .joined()
        return "(version 1)(allow default)(deny file-read* file-write* \(denies))\(allows)"
    }

    /// Wrap a command so it runs inside the profile. Returns the command
    /// unchanged when `sandbox-exec` is missing (better a prompt than no scan).
    public static func wrap(executable: String, arguments: [String],
                            home: String = NSHomeDirectory(),
                            readable: [String] = []) -> (executable: String, arguments: [String]) {
        guard FileManager.default.isExecutableFile(atPath: Self.executable) else {
            return (executable, arguments)
        }
        return (Self.executable, ["-p", profile(home: home, readable: readable), executable] + arguments)
    }

    /// realpath(3), not NSString.resolvingSymlinksInPath — the latter strips a
    /// leading /private on purpose, turning /private/var back into /var.
    /// Nonexistent paths are returned unchanged.
    private static func resolved(_ path: String) -> String {
        guard let real = realpath(path, nil) else { return path }
        defer { free(real) }
        return String(cString: real)
    }

    /// SBPL string literal: backslash and double quote are the only escapes.
    private static func quoted(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
