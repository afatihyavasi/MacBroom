import Foundation
import MacBroomCore

// Framework-free test runner. Verifies the engine JSON/NDJSON protocol decoding
// — the contract between the Swift app and macbroom-engine.sh. Exits non-zero on
// any failure so it can gate CI. Run: `swift run MacBroomSelfTest`.

var failures = 0
func check(_ name: String, _ condition: Bool) {
    if condition {
        print("  ok   \(name)")
    } else {
        print("  FAIL \(name)")
        failures += 1
    }
}

func data(_ s: String) -> Data { s.data(using: .utf8)! }

// ScanResult: snake_case size_bytes mapping
if let r = try? EngineDecode.scanResult(data(#"{"candidates":[{"category":"ai","label":"Gemini CLI temp files","path":"/Users/x/.gemini/tmp/a","size_bytes":4096}],"count":1}"#)) {
    check("ScanResult count", r.count == 1)
    check("ScanResult category", r.candidates.first?.category == "ai")
    check("ScanResult size_bytes mapping", r.candidates.first?.sizeBytes == 4096)
    check("CleanCandidate id == path", r.candidates.first?.id == "/Users/x/.gemini/tmp/a")
} else {
    check("ScanResult decodes", false)
}

// DiskStatus: nested object
if let d = try? EngineDecode.diskStatus(data(#"{"disk":{"total_bytes":100,"used_bytes":60,"free_bytes":40,"used_percent":60}}"#)) {
    check("DiskStatus total", d.total == 100)
    check("DiskStatus used", d.used == 60)
    check("DiskStatus used_percent", d.usedPercent == 60)
} else {
    check("DiskStatus decodes", false)
}

// EngineEvent: progress / done / rejects garbage
check("EngineEvent progress",
      EngineEvent(jsonLine: #"{"event":"progress","path":"/x/y","freed_bytes":2048}"#)
        == .progress(path: "/x/y", freedBytes: 2048))
check("EngineEvent done",
      EngineEvent(jsonLine: #"{"event":"done","freed_bytes":9000,"count":3}"#)
        == .done(freedBytes: 9000, count: 3))
check("EngineEvent ignores unknown", EngineEvent(jsonLine: #"{"event":"chatter"}"#) == nil)
check("EngineEvent ignores garbage", EngineEvent(jsonLine: "not json") == nil)
check("EngineEvent ignores empty", EngineEvent(jsonLine: "") == nil)

// AITool classification
check("classify gemini path",
      AITool.classify(path: "/Users/x/.gemini/tmp/bin", label: "Gemini CLI temp files") == .gemini)
check("classify antigravity -> gemini",
      AITool.classify(path: "/Users/x/.gemini/antigravity-browser-profile/Default/Cache", label: "Antigravity browser cache") == .gemini)
check("classify claude old version",
      AITool.classify(path: "/Users/x/.local/share/claude/versions/2.1", label: "Claude Code old version") == .claude)
check("classify cursor before others",
      AITool.classify(path: "/Users/x/.local/share/cursor-agent/versions/1", label: "Cursor Agent old version") == .cursor)
check("classify openai chatgpt -> codex group",
      AITool.classify(path: "/Users/x/Library/Caches/com.openai.chat/blob", label: "ChatGPT cache") == .codex)
check("classify copilot",
      AITool.classify(path: "/Users/x/.copilot/pkg/universal", label: "GitHub Copilot CLI old version") == .copilot)
check("classify unknown -> other",
      AITool.classify(path: "/Users/x/Library/Caches/something", label: "Misc cache") == .other)

// Grouping: largest group first, largest item first within a group
let groups = AIToolGroup.group([
    CleanCandidate(category: "ai", label: "Gemini CLI temp files", path: "/g/tmp", sizeBytes: 10),
    CleanCandidate(category: "ai", label: "Antigravity browser cache", path: "/g/cache", sizeBytes: 100),
    CleanCandidate(category: "ai", label: "Claude Code old version", path: "/c/v", sizeBytes: 50)
])
check("group: gemini first (largest total)", groups.first?.tool == .gemini)
check("group: gemini sorted desc", groups.first?.candidates.first?.sizeBytes == 100)

// Formatting sanity
check("Format.bytes non-empty", !Format.bytes(1_500_000).isEmpty)

print(failures == 0 ? "\nAll self-tests passed." : "\n\(failures) self-test(s) FAILED.")
exit(failures == 0 ? 0 : 1)
