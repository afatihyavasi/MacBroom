import Foundation
import MacBroomCore

/// Installs/removes `launchd` user agents so scheduled auto-cleans run even when
/// MacBroom is quit. Each enabled rule becomes one agent that invokes the engine
/// `auto-clean` for its target on the rule's schedule. Only ever touches labels
/// under `LaunchAgent.labelPrefix` — never other agents.
enum LaunchAgentManager {
    private static var dir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    /// Ledger where launchd-triggered cleans record freed bytes, folded into the
    /// app's all-time "reclaimed" stat on next launch.
    static var ledgerURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacBroom/reclaimed", isDirectory: false)
    }

    /// Replace all MacBroom auto-clean agents with ones matching `rules`.
    static func sync(rules: [String: AutoCleanRule], enginePath: String,
                     moleDir: String, deleteMode: String) {
        removeAll()
        let enabled = rules.filter { $0.value.isEnabled }
        guard !enabled.isEmpty else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (id, rule) in enabled {
            let label = LaunchAgent.label(for: id)
            let args = ["/bin/bash", enginePath, "auto-clean", "--targets=\(id)"]
            let env = ["MACBROOM_MOLE_DIR": moleDir,
                       "MACBROOM_DELETE_MODE": deleteMode,
                       "MACBROOM_RECLAIMED_LEDGER": ledgerURL.path]
            guard let data = LaunchAgent.plistData(label: label, programArguments: args,
                                                   environment: env, rule: rule) else { continue }
            let file = dir.appendingPathComponent("\(label).plist")
            do {
                try data.write(to: file)
                load(file)
            } catch { continue }
        }
    }

    /// Remove every MacBroom auto-clean agent (unload + delete the plist).
    static func removeAll() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil) else { return }
        for f in files where f.lastPathComponent.hasPrefix(LaunchAgent.labelPrefix)
            && f.pathExtension == "plist" {
            unload(f)
            try? FileManager.default.removeItem(at: f)
        }
    }

    private static func load(_ file: URL)   { launchctl(["load", "-w", file.path]) }
    private static func unload(_ file: URL) { launchctl(["unload", file.path]) }

    private static func launchctl(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }
}
