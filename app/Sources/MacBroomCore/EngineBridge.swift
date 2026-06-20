import Foundation

/// Thin Swift wrapper around `engine/macbroom-engine.sh`.
///
/// Runs the engine as a subprocess and decodes its JSON / NDJSON protocol.
/// Path resolution order (engine + bundled mole):
///   1. environment override (MACBROOM_ENGINE_PATH / MACBROOM_MOLE_DIR)
///   2. app bundle Resources (production .app)
///   3. repo layout via #filePath (development `swift run` & tests)
public enum EngineError: LocalizedError {
    case engineNotFound
    case nonZeroExit(code: Int32, message: String)
    case decodeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .engineNotFound: return "Temizleme motoru bulunamadı."
        case let .nonZeroExit(code, msg): return "Motor hata verdi (\(code)): \(msg)"
        case let .decodeFailed(s): return "Motor çıktısı çözümlenemedi: \(s)"
        }
    }
}

public struct EngineBridge {
    public let enginePath: String
    public let moleDir: String

    public init(enginePath: String? = nil, moleDir: String? = nil) {
        self.enginePath = enginePath ?? Self.resolveEnginePath()
        self.moleDir = moleDir ?? Self.resolveMoleDir(enginePath: self.enginePath)
    }

    // MARK: - Public API

    public func status() async throws -> SystemStatus {
        let (data, _) = try await runCollecting(["status"])
        return try decodeLast(SystemStatus.self, from: data)
    }

    public func scan(categories: [CleanCategory]) async throws -> ScanResult {
        let arg = "--categories=" + categories.map(\.rawValue).joined(separator: ",")
        let (data, _) = try await runCollecting(["scan", arg])
        return try decodeLast(ScanResult.self, from: data)
    }

    // MARK: App uninstaller

    public func apps() async throws -> [AppInfo] {
        let (data, _) = try await runCollecting(["apps"])
        return try decodeLast(AppsResult.self, from: data).apps
    }

    public func appScan(appPath: String) async throws -> ScanResult {
        let (data, _) = try await runCollecting(["app-scan", "--app=\(appPath)"])
        return try decodeLast(ScanResult.self, from: data)
    }

    public func appClean(approvedPaths: [String]) -> AsyncThrowingStream<EngineEvent, Error> {
        streamingClean(subcommand: "app-clean", extraArgs: [], approvedPaths: approvedPaths)
    }

    /// Delete user-approved paths, streaming progress as it goes.
    public func clean(approvedPaths: [String], categories: [CleanCategory]) -> AsyncThrowingStream<EngineEvent, Error> {
        let arg = "--categories=" + categories.map(\.rawValue).joined(separator: ",")
        return streamingClean(subcommand: "clean", extraArgs: [arg], approvedPaths: approvedPaths)
    }

    /// Shared streaming runner for `clean` / `app-clean`.
    private func streamingClean(subcommand: String, extraArgs: [String], approvedPaths: [String]) -> AsyncThrowingStream<EngineEvent, Error> {
        AsyncThrowingStream { continuation in
            do {
                let tmp = try writeApprovedPathsFile(approvedPaths)
                let proc = try makeProcess([subcommand] + extraArgs + ["--paths-file=\(tmp.path)"])
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = FileHandle.nullDevice

                var buffer = Data()
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    guard !chunk.isEmpty else { return }
                    buffer.append(chunk)
                    while let nl = buffer.firstIndex(of: 0x0A) {
                        let lineData = buffer.subdata(in: buffer.startIndex..<nl)
                        buffer.removeSubrange(buffer.startIndex...nl)
                        if let line = String(data: lineData, encoding: .utf8),
                           let event = EngineEvent(jsonLine: line) {
                            continuation.yield(event)
                        }
                    }
                }
                proc.terminationHandler = { _ in
                    pipe.fileHandleForReading.readabilityHandler = nil
                    try? FileManager.default.removeItem(at: tmp)
                    continuation.finish()
                }
                try proc.run()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    // MARK: - Process plumbing

    private func makeProcess(_ args: [String]) throws -> Process {
        guard FileManager.default.fileExists(atPath: enginePath) else { throw EngineError.engineNotFound }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [enginePath] + args
        var env = ProcessInfo.processInfo.environment
        env["MACBROOM_MOLE_DIR"] = moleDir
        proc.environment = env
        return proc
    }

    /// Run the engine and collect full stdout (for non-streaming subcommands).
    private func runCollecting(_ args: [String]) async throws -> (Data, Int32) {
        let proc = try makeProcess(args)
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw EngineError.nonZeroExit(code: proc.terminationStatus, message: msg)
        }
        return (data, proc.terminationStatus)
    }

    /// Engine emits one JSON object per protocol line; results are on the last
    /// non-empty line. Decode that.
    private func decodeLast<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let text = String(data: data, encoding: .utf8) ?? ""
        let lines = text.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        guard let last = lines.last, let lineData = last.data(using: .utf8) else {
            throw EngineError.decodeFailed("boş çıktı")
        }
        do {
            return try JSONDecoder().decode(T.self, from: lineData)
        } catch {
            throw EngineError.decodeFailed(last)
        }
    }

    private func writeApprovedPathsFile(_ paths: [String]) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("macbroom-approved-\(UUID().uuidString).txt")
        try paths.joined(separator: "\n").write(to: tmp, atomically: true, encoding: .utf8)
        return tmp
    }

    // MARK: - Path resolution

    private static func resolveEnginePath() -> String {
        if let p = ProcessInfo.processInfo.environment["MACBROOM_ENGINE_PATH"] { return p }
        if let p = Bundle.main.path(forResource: "macbroom-engine", ofType: "sh") { return p }
        return repoRoot().appendingPathComponent("engine/macbroom-engine.sh").path
    }

    private static func resolveMoleDir(enginePath: String) -> String {
        if let p = ProcessInfo.processInfo.environment["MACBROOM_MOLE_DIR"] { return p }
        if let p = Bundle.main.resourcePath {
            let bundled = (p as NSString).appendingPathComponent("vendor/mole")
            if FileManager.default.fileExists(atPath: bundled) { return bundled }
        }
        return repoRoot().appendingPathComponent("vendor/mole").path
    }

    /// Repo root derived from this source file's location (dev & tests):
    /// .../app/Sources/MacBroomCore/EngineBridge.swift -> up 4 -> repo root
    private static func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        return url
    }
}
