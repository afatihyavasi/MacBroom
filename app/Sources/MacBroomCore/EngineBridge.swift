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
        case .engineNotFound:
            return Localization.string(.errEngineNotFound)
        case let .nonZeroExit(code, msg):
            return String(format: Localization.string(.errNonZero), code, msg)
        case let .decodeFailed(s):
            return String(format: Localization.string(.errDecode), s)
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

    /// Fast discovery: which targets exist on this machine (no sizing).
    public func discover() async throws -> [AnalysisTarget] {
        let (data, _) = try await runCollecting(["discover"])
        return try decodeLast(DiscoverResult.self, from: data).targets
    }

    public func scan(categories: [CleanCategory]) async throws -> ScanResult {
        let arg = "--categories=" + categories.map(\.rawValue).joined(separator: ",")
        let (data, _) = try await runCollecting(["scan", arg])
        return try decodeLast(ScanResult.self, from: data)
    }

    /// Scan only the selected target ids (the scoped, fast path).
    public func scan(targetIds: [String]) async throws -> ScanResult {
        let arg = "--targets=" + targetIds.joined(separator: ",")
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

    public func appClean(approvedPaths: [String], deleteMode: DeleteMode = .permanent) -> AsyncThrowingStream<EngineEvent, Error> {
        streamingClean(subcommand: "app-clean", extraArgs: [], approvedPaths: approvedPaths, deleteMode: deleteMode)
    }

    /// Delete user-approved paths within the given targets, streaming progress.
    public func clean(approvedPaths: [String], targetIds: [String], deleteMode: DeleteMode = .permanent) -> AsyncThrowingStream<EngineEvent, Error> {
        let arg = "--targets=" + targetIds.joined(separator: ",")
        return streamingClean(subcommand: "clean", extraArgs: [arg], approvedPaths: approvedPaths, deleteMode: deleteMode)
    }

    /// Shared streaming runner for `clean` / `app-clean`.
    private func streamingClean(subcommand: String, extraArgs: [String], approvedPaths: [String], deleteMode: DeleteMode) -> AsyncThrowingStream<EngineEvent, Error> {
        AsyncThrowingStream { continuation in
            let tmp: URL
            do {
                tmp = try writeApprovedPathsFile(approvedPaths)
            } catch {
                continuation.finish(throwing: error); return
            }
            do {
                let proc = try makeProcess([subcommand] + extraArgs + ["--paths-file=\(tmp.path)"],
                                           extraEnv: ["MACBROOM_DELETE_MODE": deleteMode.rawValue])
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = FileHandle.nullDevice
                let readHandle = pipe.fileHandleForReading

                // All buffer access + event parsing happens under this lock, so
                // the readability handler (private queue) and the termination
                // handler (another thread) never race on `buffer`.
                let lock = NSLock()
                var didFinish = false
                var buffer = Data()

                // Parse every complete NDJSON line out of `buffer`. Caller holds `lock`.
                let drain: (Data) -> Void = { newData in
                    buffer.append(newData)
                    while let nl = buffer.firstIndex(of: 0x0A) {
                        let lineData = buffer.subdata(in: buffer.startIndex..<nl)
                        buffer.removeSubrange(buffer.startIndex...nl)
                        if let line = String(data: lineData, encoding: .utf8),
                           let event = EngineEvent(jsonLine: line) {
                            continuation.yield(event)
                        }
                    }
                }

                // One-shot teardown — assumes `lock` is already held. Crucially
                // it drains whatever is still buffered in the pipe before
                // finishing: a fast-exiting engine can leave the final
                // progress/done lines unread when the termination handler wins
                // the race against the readability handler — losing them would
                // report "0 bytes freed" even though the delete succeeded.
                let finishLocked: () -> Void = {
                    guard !didFinish else { return }
                    didFinish = true
                    readHandle.readabilityHandler = nil
                    if let rest = try? readHandle.readToEnd(), !rest.isEmpty { drain(rest) }
                    try? FileManager.default.removeItem(at: tmp)
                    continuation.finish()
                }

                // All pipe reads happen under `lock`, so the readability handler
                // and the teardown's `readToEnd()` can never interleave and drop
                // a chunk. The handler is only scheduled when data is available,
                // so reading under the lock won't block.
                readHandle.readabilityHandler = { handle in
                    lock.lock(); defer { lock.unlock() }
                    guard !didFinish else { return }
                    // Throwing read instead of `availableData`: when the engine
                    // exits and the pipe closes, this surfaces as a Swift error
                    // rather than an uncatchable ObjC `Bad file descriptor`
                    // exception that would crash (SIGABRT) the whole app.
                    let chunk: Data
                    do {
                        chunk = try handle.read(upToCount: 64 * 1024) ?? Data()
                    } catch {
                        finishLocked(); return
                    }
                    if chunk.isEmpty { finishLocked(); return } // EOF
                    drain(chunk)
                }
                proc.terminationHandler = { _ in
                    lock.lock(); finishLocked(); lock.unlock()
                }
                try proc.run()
                // If the consumer cancels (e.g. the view goes away), tear the
                // child process down instead of leaving it running detached.
                continuation.onTermination = { @Sendable _ in
                    if proc.isRunning { proc.terminate() }
                }
            } catch {
                try? FileManager.default.removeItem(at: tmp)
                continuation.finish(throwing: error)
            }
        }
    }

    // MARK: - Process plumbing

    private func makeProcess(_ args: [String], extraEnv: [String: String] = [:]) throws -> Process {
        guard FileManager.default.fileExists(atPath: enginePath) else { throw EngineError.engineNotFound }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [enginePath] + args
        var env = ProcessInfo.processInfo.environment
        env["MACBROOM_MOLE_DIR"] = moleDir
        for (k, v) in extraEnv { env[k] = v }
        proc.environment = env
        return proc
    }

    /// Run the engine and collect full stdout (for non-streaming subcommands).
    private func runCollecting(_ args: [String]) async throws -> (Data, Int32) {
        let proc = try makeProcess(args)
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        try proc.run()
        // Drain stdout (the large stream) fully, then stderr. Safe here because
        // the engine's stderr is bounded — mole chatter is suppressed and only
        // `die` writes a short line — so it can't fill its pipe and deadlock the
        // child while we read stdout. stderr feeds the nonzero-exit diagnostic.
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let errText = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let outText = String(data: data, encoding: .utf8) ?? ""
            let msg = errText.isEmpty ? outText : errText
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
