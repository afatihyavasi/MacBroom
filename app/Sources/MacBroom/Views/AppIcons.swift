import SwiftUI
import AppKit
import MacBroomCore

/// Resolves real macOS icons for apps and AI tools, with SF Symbol fallbacks.
enum Icons {
    /// The Finder icon for a file/app bundle path.
    static func file(_ path: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
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

    /// An installed AI tool's real app icon, if we can find its bundle.
    static func aiToolImage(_ tool: AITool) -> NSImage? {
        for p in appPaths(for: tool) where FileManager.default.fileExists(atPath: p) {
            return NSWorkspace.shared.icon(forFile: p)
        }
        return nil
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
