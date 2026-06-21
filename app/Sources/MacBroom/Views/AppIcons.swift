import SwiftUI
import AppKit
import MacBroomCore

/// In-memory icon cache. Resolving NSImages via `NSWorkspace` is surprisingly
/// expensive to do in a view body on every redraw; memoizing each icon once
/// keeps long, scrolling app lists smooth. Main-actor isolated so the static
/// dictionaries need no extra synchronization.
@MainActor
private enum IconCache {
    static var files: [String: NSImage] = [:]
    /// AI-tool icons (nil = resolved-but-not-installed, still worth caching to
    /// avoid repeated filesystem probes).
    static var aiTools: [AITool: NSImage?] = [:]
}

/// Resolves real macOS icons for apps and AI tools, with SF Symbol fallbacks.
@MainActor
enum Icons {
    /// The Finder icon for a file/app bundle path (cached after first lookup).
    static func file(_ path: String) -> NSImage {
        if let cached = IconCache.files[path] { return cached }
        let img = NSWorkspace.shared.icon(forFile: path)
        IconCache.files[path] = img
        return img
    }

    /// Candidate app bundles per AI tool — first existing one wins.
    private static func appPaths(for tool: AITool) -> [String] {
        switch tool {
        case .claude:  return ["/Applications/Claude.app"]
        case .codex:   return ["/Applications/Codex.app", "/Applications/ChatGPT.app"]
        case .gemini:  return ["/Applications/Antigravity.app"]
        case .cursor:  return ["/Applications/Cursor.app"]
        case .copilot: return ["/Applications/GitHub Copilot.app"]
        case .other:   return []
        }
    }

    /// An installed AI tool's real app icon, if we can find its bundle (cached).
    static func aiToolImage(_ tool: AITool) -> NSImage? {
        if let cached = IconCache.aiTools[tool] { return cached }
        var resolved: NSImage?
        for p in appPaths(for: tool) where FileManager.default.fileExists(atPath: p) {
            resolved = NSWorkspace.shared.icon(forFile: p)
            break
        }
        IconCache.aiTools[tool] = resolved
        return resolved
    }
}

/// Icon for an app bundle path (uninstaller list).
struct AppIconView: View {
    let path: String
    var size: CGFloat = 22
    var body: some View {
        Image(nsImage: Icons.file(path))
            .resizable().frame(width: size, height: size)
    }
}

/// Icon for an AI tool: real app icon if installed, else its SF Symbol.
struct AIToolIconView: View {
    let tool: AITool
    var size: CGFloat = 20
    var body: some View {
        if let img = Icons.aiToolImage(tool) {
            Image(nsImage: img).resizable().frame(width: size, height: size)
        } else {
            Image(systemName: tool.systemImage)
                .frame(width: size, height: size)
                .foregroundStyle(.tint)
        }
    }
}
