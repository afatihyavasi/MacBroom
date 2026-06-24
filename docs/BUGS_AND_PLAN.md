# MacBroom — Bug Analysis, Performance and Resolution Plan

Date: 2026-06-20

## User report
"When I want to delete an app and press *Delete permanently*, the app
closes." This is a **crash**, not a permission issue — however, a permission
issue does also exist as a separate hidden bug (silently swallowed). Both are
covered below.

---

## Bugs found (in order of severity)

### P0 — App crashes during deletion (ROOT CAUSE)
`app/Sources/MacBroomCore/EngineBridge.swift` → `streamingClean(...)`

- `handle.availableData` is used inside
  `pipe.fileHandleForReading.readabilityHandler`. When the subprocess (engine)
  finishes, the read end of the pipe closes, and the final read arriving at
  that moment throws an `NSFileHandleOperationException: Bad file descriptor`
  **Objective-C exception**.
- Swift cannot catch this ObjC exception with `try/catch` → `SIGABRT` →
  **the entire menu bar app closes instantly.**
- Because `terminationHandler` sets `readabilityHandler = nil` while a read is
  still in flight, a race condition is triggered almost every time; since
  app-clean finishes quickly, the user perceives this as "it always crashes".
- The same code is also used for `clean` (cache cleanup) → that flow is risky too.

**Solution:** Use the Swift-throwing `read(upToCount:)` instead of
`availableData` (returns a Swift error rather than an ObjC exception), make
`continuation.finish()` a locked one-shot, and handle the `proc.run()` error
separately.

### P1 — Permission/failed deletion silently swallowed (no notification to user)
`engine/macbroom-engine.sh` → `_mb_remove` `rm -rf -- "$1" 2>/dev/null`

- If the app under `/Applications` is owned by root, or if there is no Full
  Disk Access, `rm` fails, the error is swallowed by `2>/dev/null`, and the
  item is simply skipped.
- The UI says "Removed" but in reality nothing may have been deleted → the user
  is misled. The user's request to "notify if it's permission-related" maps
  exactly here.

**Solution:** On a failed deletion the engine emits
`{"event":"skipped",...,"reason":...}`; `.skipped` is added to `EngineEvent`;
`AppState` counts the failures; `UninstallView` shows "N items could not be
deleted — Full Disk Access may be required" + a settings button.

### P2 — Minor robustness/performance issues in the stream
- If the last line does not end with `\n`, the buffer is not flushed → the
  "done" event may be lost (total `freed` is still summed from the progress
  events, cosmetic).
- `du` has already been removed (fast list); app-scan sizing can be slow for
  large apps — background sizing in the future.

---

## Implementation order
1. **P0 crash fix** — read EngineBridge streaming safely. ✅ (this round)
2. **P1 permission feedback** — engine + model + state + view. ✅ (this round)
3. **P2** — buffer flush. ✅ (this round, minor)
