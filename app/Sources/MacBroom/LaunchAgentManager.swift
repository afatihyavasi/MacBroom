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
    /// Returns the target ids whose agent could NOT be installed (plist write or
    /// `launchctl load` failed) so the caller can tell the user instead of
    /// silently leaving a schedule that will never fire.
    @discardableResult
    static func sync(rules: [String: AutoCleanRule], enginePath: String,
                     moleDir: String, deleteMode: String) -> [String] {
        removeAll()
        let enabled = rules.filter { $0.value.isEnabled }
        guard !enabled.isEmpty else { return [] }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return Array(enabled.keys)   // no LaunchAgents dir → nothing can install
        }
        var failed: [String] = []
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
            } catch {
                failed.append(id); continue
            }
            if !load(file) { failed.append(id) }
        }
        return failed
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

    @discardableResult
    private static func load(_ file: URL) -> Bool { launchctl(["load", "-w", file.path]) }
    private static func unload(_ file: URL)        { launchctl(["unload", file.path]) }

    /// Run launchctl; returns true only if it ran and exited cleanly.
    @discardableResult
    private static func launchctl(_ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
}
