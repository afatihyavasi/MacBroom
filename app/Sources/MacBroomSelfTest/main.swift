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

// SystemStatus: nested disk + optional memory
if let s = try? EngineDecode.systemStatus(data(#"{"disk":{"total_bytes":100,"used_bytes":60,"free_bytes":40,"used_percent":60},"memory":{"total_bytes":16,"used_bytes":8,"used_percent":50}}"#)) {
    check("SystemStatus disk total", s.disk.total == 100)
    check("SystemStatus disk used_percent", s.disk.usedPercent == 60)
    check("SystemStatus memory present", s.memory?.usedPercent == 50)
} else {
    check("SystemStatus decodes", false)
}
// SystemStatus tolerates missing memory
if let s = try? EngineDecode.systemStatus(data(#"{"disk":{"total_bytes":1,"used_bytes":1,"free_bytes":0,"used_percent":100}}"#)) {
    check("SystemStatus memory optional", s.memory == nil)
} else {
    check("SystemStatus without memory decodes", false)
}

// EngineEvent: progress / done / rejects garbage
check("EngineEvent progress",
      EngineEvent(jsonLine: #"{"event":"progress","path":"/x/y","freed_bytes":2048}"#)
        == .progress(path: "/x/y", freedBytes: 2048))
check("EngineEvent done",
      EngineEvent(jsonLine: #"{"event":"done","freed_bytes":9000,"count":3,"failed":1}"#)
        == .done(freedBytes: 9000, count: 3, failed: 1))
check("EngineEvent done without failed defaults to 0",
      EngineEvent(jsonLine: #"{"event":"done","freed_bytes":9000,"count":3}"#)
        == .done(freedBytes: 9000, count: 3, failed: 0))
check("EngineEvent skipped",
      EngineEvent(jsonLine: #"{"event":"skipped","path":"/x/y","reason":"permission"}"#)
        == .skipped(path: "/x/y", reason: "permission"))
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

// DiscoverResult: target list with installed flags
if let d = try? JSONDecoder().decode(DiscoverResult.self, from: data(#"{"targets":[{"id":"ai:gemini","label":"Gemini / Antigravity","category":"ai","installed":true},{"id":"system:dev-misc","label":"Dev","category":"system","installed":false}]}"#)) {
    check("DiscoverResult count", d.targets.count == 2)
    check("AnalysisTarget id", d.targets.first?.id == "ai:gemini")
    check("AnalysisTarget installed true", d.targets.first?.installed == true)
    check("AnalysisTarget installed false", d.targets.last?.installed == false)
} else {
    check("DiscoverResult decodes", false)
}

// Formatting sanity
check("Format.bytes non-empty", !Format.bytes(1_500_000).isEmpty)

// CleanFrequency scheduling math
check("freq off never due", CleanFrequency.off.isDue(since: Date(timeIntervalSince1970: 0), now: Date(timeIntervalSince1970: 9_999_999)) == false)
check("freq hourly interval", CleanFrequency.hourly.interval == 3600)
check("freq weekly due after 8 days",
      CleanFrequency.weekly.isDue(since: Date(timeIntervalSince1970: 0), now: Date(timeIntervalSince1970: 8 * 86_400)))
check("freq weekly not due after 1 day",
      CleanFrequency.weekly.isDue(since: Date(timeIntervalSince1970: 0), now: Date(timeIntervalSince1970: 86_400)) == false)
check("freq never-run is due now", CleanFrequency.daily.isDue(since: nil, now: Date(timeIntervalSince1970: 100)))

// AutoCleanRule calendar-based due logic (UTC gregorian for determinism)
var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
func dt(_ y: Int, _ mo: Int, _ da: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
    utc.date(from: DateComponents(year: y, month: mo, day: da, hour: h, minute: mi))!
}
let daily3 = AutoCleanRule(frequency: .daily, hour: 3)
check("daily: due when lastRun before today's 03:00",
      daily3.isDue(lastRun: dt(2024,1,1,12), now: dt(2024,1,2,5), calendar: utc))
check("daily: not due when lastRun after today's 03:00",
      daily3.isDue(lastRun: dt(2024,1,2,4), now: dt(2024,1,2,5), calendar: utc) == false)
// 2024-01-01 is a Monday → Calendar weekday 2.
let weeklyMon = AutoCleanRule(frequency: .weekly, hour: 3, weekday: 2)
check("weekly Mon: due (lastRun before Monday's fire)",
      weeklyMon.isDue(lastRun: dt(2023,12,25), now: dt(2024,1,3,12), calendar: utc))
check("weekly Mon: not due (lastRun after Monday's fire)",
      weeklyMon.isDue(lastRun: dt(2024,1,2), now: dt(2024,1,3,12), calendar: utc) == false)
let hourly6 = AutoCleanRule(frequency: .hourly, hourInterval: 6)
check("hourly/6: fire aligns to 12:00 at 13:00",
      hourly6.lastFireDate(onOrBefore: dt(2024,1,1,13), calendar: utc) == dt(2024,1,1,12))
check("hourly/6: due when lastRun before the 12:00 step",
      hourly6.isDue(lastRun: dt(2024,1,1,11), now: dt(2024,1,1,13), calendar: utc))
let monthly15 = AutoCleanRule(frequency: .monthly, hour: 3, dayOfMonth: 15)
check("monthly/15: due after the 15th",
      monthly15.isDue(lastRun: dt(2024,1,1), now: dt(2024,1,20), calendar: utc))
check("monthly/15: not due before the 15th when lastRun is this month",
      monthly15.isDue(lastRun: dt(2024,1,1), now: dt(2024,1,10), calendar: utc) == false)
check("rule off never due", AutoCleanRule.off.isDue(lastRun: nil, now: dt(2024,1,1), calendar: utc) == false)

// launchd schedule mapping
check("hourly/3 → StartInterval 10800", AutoCleanRule(frequency: .hourly, hourInterval: 3).launchdStartInterval == 10800)
check("daily has no StartInterval", AutoCleanRule(frequency: .daily).launchdStartInterval == nil)
check("weekly Mon(2) → launchd Weekday 1",
      AutoCleanRule(frequency: .weekly, weekday: 2).launchdCalendarInterval?["Weekday"] == 1)
check("weekly Sun(1) → launchd Weekday 0",
      AutoCleanRule(frequency: .weekly, weekday: 1).launchdCalendarInterval?["Weekday"] == 0)
check("monthly/15 → Day 15", AutoCleanRule(frequency: .monthly, dayOfMonth: 15).launchdCalendarInterval?["Day"] == 15)
// plist serializes to a valid, re-parseable property list with the schedule key.
if let data = LaunchAgent.plistData(
        label: "com.macbroom.autoclean.ai.gemini",
        programArguments: ["/bin/bash", "/x/engine.sh", "auto-clean", "--targets=ai:gemini"],
        environment: ["MACBROOM_DELETE_MODE": "trash"],
        rule: AutoCleanRule(frequency: .weekly, hour: 3, weekday: 6)),
   let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
    check("plist has Label", (obj["Label"] as? String) == "com.macbroom.autoclean.ai.gemini")
    check("plist has StartCalendarInterval", obj["StartCalendarInterval"] is [String: Int])
    check("plist Weekday is Friday (5)", (obj["StartCalendarInterval"] as? [String: Int])?["Weekday"] == 5)
} else {
    check("plist serializes", false)
}
check("plist nil for disabled rule",
      LaunchAgent.plistData(label: "x", programArguments: [], environment: [:], rule: .off) == nil)

// Localization: every key must be translated in all 4 languages (no fallback
// gaps), and format placeholders must match across languages.
for lang in [AppLanguage.en, .tr, .es, .fr] {
    let missing = L10n.allCases.filter { Localization.string($0, language: lang) == $0.rawValue }
    check("L10n complete: \(lang.rawValue) (\(missing.count) missing)", missing.isEmpty)
}
// Placeholder parity vs English (catches a %d/%@ that drifted between languages).
func specs(_ s: String) -> [Character] {
    var out: [Character] = []; var prev: Character? = nil
    for c in s { if prev == "%", c == "d" || c == "@" { out.append(c) }; prev = c }
    return out
}
for key in L10n.allCases {
    let ref = specs(Localization.string(key, language: .en))
    for lang in [AppLanguage.tr, .es, .fr] {
        check("L10n placeholders match en/\(lang.rawValue): \(key.rawValue)",
              specs(Localization.string(key, language: lang)) == ref)
    }
}
// System resolution falls back to a supported language (English when none match).
check("AppLanguage.system resolves to supported",
      [.en, .tr, .es, .fr].contains(AppLanguage.system.resolved))
check("AppLanguage.tr resolves to itself", AppLanguage.tr.resolved == .tr)

// Integration: the streaming clean must actually report freed bytes. Regression
// for the Pipe/termination race where a fast-exiting engine left the final
// progress/done lines unread → UI showed "0 bytes freed" despite a real delete.
do {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("mbselftest-\(UUID().uuidString)")
    let victim = root.appendingPathComponent("cache-dir")
    try? FileManager.default.createDirectory(at: victim, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: victim.appendingPathComponent("blob").path,
                                   contents: Data(count: 128 * 1024))
    var freed: Int64 = 0
    var sawDone = false
    do {
        for try await ev in EngineBridge().appClean(approvedPaths: [victim.path], deleteMode: .permanent) {
            switch ev {
            case let .progress(_, bytes): freed += bytes
            case let .done(bytes, _, _): sawDone = true; freed = max(freed, bytes)
            case .skipped: break
            }
        }
    } catch { /* surfaced by the assertions below */ }
    check("streaming clean reports freed > 0 (not 0 KB)", freed > 0)
    check("streaming clean emits a done event", sawDone)
    check("streaming clean removed the path", !FileManager.default.fileExists(atPath: victim.path))
    try? FileManager.default.removeItem(at: root)
}

// User whitelist: a protected path must NEVER be deleted, even when it is in the
// approved set. The engine enforces this in its single _mb_handle sink, so this
// is the defense-in-depth guarantee behind the Settings "Protected paths" UI.
// Saves and restores the real list file so running the test is non-destructive.
do {
    let realURL = EngineBridge.userProtectedFileURL
    let saved = try? Data(contentsOf: realURL)
    defer {
        if let saved { try? saved.write(to: realURL) }
        else { try? FileManager.default.removeItem(at: realURL) }
    }

    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("mbselftest-protect-\(UUID().uuidString)")
    let victim = root.appendingPathComponent("keep-me")
    try? FileManager.default.createDirectory(at: victim, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: victim.appendingPathComponent("blob").path,
                                   contents: Data(count: 64 * 1024))
    EngineBridge.writeUserProtectedPaths([victim.path])

    var freed: Int64 = 0
    do {
        for try await ev in EngineBridge().appClean(approvedPaths: [victim.path], deleteMode: .permanent) {
            if case let .progress(_, bytes) = ev { freed += bytes }
        }
    } catch { /* surfaced by the assertions below */ }
    check("user-protected path survives clean", FileManager.default.fileExists(atPath: victim.path))
    check("user-protected path frees 0 bytes", freed == 0)
    try? FileManager.default.removeItem(at: root)
}

// Concurrency: many runCollecting-backed calls at once must ALL complete.
// Regression for the cooperative-pool starvation that hung the UI at "Searching
// targets…" — blocking subprocess I/O on the fixed-width Swift pool deadlocked
// when a launch burst (scheduler auto-clean + status + discover) exhausted it.
// runCollecting now runs off-pool on GCD, so concurrent calls can't starve it.
do {
    let bridge = EngineBridge()
    let n = 40
    let completed = await withTaskGroup(of: Bool.self) { group -> Int in
        for _ in 0..<n { group.addTask { (try? await bridge.status()) != nil } }
        var ok = 0
        for await r in group where r { ok += 1 }
        return ok
    }
    check("concurrent status() x\(n) all completed (no pool starvation)", completed == n)
}

print(failures == 0 ? "\nAll self-tests passed." : "\n\(failures) self-test(s) FAILED.")
exit(failures == 0 ? 0 : 1)
