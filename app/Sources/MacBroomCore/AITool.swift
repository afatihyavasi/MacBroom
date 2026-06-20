import Foundation

/// The AI developer tools MacBroom groups cache candidates under.
public enum AITool: String, CaseIterable, Identifiable {
    case claude
    case codex
    case gemini
    case cursor
    case copilot
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude:  return "Claude"
        case .codex:   return "Codex / ChatGPT"
        case .gemini:  return "Gemini / Antigravity"
        case .cursor:  return "Cursor"
        case .copilot: return "GitHub Copilot"
        case .other:   return "Diğer AI Araçları"
        }
    }

    /// SF Symbol used in the tool's section header.
    public var systemImage: String {
        switch self {
        case .claude:  return "a.circle"
        case .codex:   return "chevron.left.forwardslash.chevron.right"
        case .gemini:  return "sparkle"
        case .cursor:  return "cursorarrow.rays"
        case .copilot: return "chevron.left.slash.chevron.right"
        case .other:   return "cpu"
        }
    }

    /// Classify a scan candidate into a tool group from its path + label.
    /// Order matters: more specific markers are checked first so, e.g., a Claude
    /// path is never swallowed by a generic match.
    public static func classify(path: String, label: String) -> AITool {
        let hay = (path + " " + label).lowercased()

        // Cursor before Claude/Codex: cursor-agent paths can contain neither,
        // but its label mentions "cursor" explicitly.
        if hay.contains("cursor") { return .cursor }
        if hay.contains("copilot") { return .copilot }
        // Gemini/Antigravity share ~/.gemini.
        if hay.contains("gemini") || hay.contains("antigravity") { return .gemini }
        // Codex CLI/Desktop + ChatGPT desktop (com.openai.chat).
        if hay.contains("codex") || hay.contains("openai") || hay.contains("chatgpt") { return .codex }
        if hay.contains("claude") || hay.contains("anthropic") { return .claude }
        return .other
    }
}

/// A tool's grouped candidates with an aggregate size, for sectioned display.
public struct AIToolGroup: Identifiable {
    public let tool: AITool
    public var candidates: [CleanCandidate]

    public var id: String { tool.rawValue }
    public var totalBytes: Int64 { candidates.reduce(0) { $0 + $1.sizeBytes } }
    public var count: Int { candidates.count }

    public init(tool: AITool, candidates: [CleanCandidate]) {
        self.tool = tool
        self.candidates = candidates
    }

    /// Group + sort candidates into tool sections (largest groups first, and
    /// largest items within each group first).
    public static func group(_ candidates: [CleanCandidate]) -> [AIToolGroup] {
        var buckets: [AITool: [CleanCandidate]] = [:]
        for c in candidates {
            buckets[AITool.classify(path: c.path, label: c.label), default: []].append(c)
        }
        return buckets
            .map { AIToolGroup(tool: $0.key, candidates: $0.value.sorted { $0.sizeBytes > $1.sizeBytes }) }
            .sorted { $0.totalBytes > $1.totalBytes }
    }
}
