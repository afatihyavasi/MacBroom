# MacBroom v2 — Audit & UX Plan

Date: 2026-06-21 · Branch: v2

Findings from a three-track audit (Swift app, engine shell, UX). Severities:
P0 = crash/data-loss/safety · P1 = wrong behavior · P2 = minor/polish.

---

## Phase 1 — Correctness & safety bugs (do first)

1. **P1 · Refresh during cleaning corrupts shared state.** Header refresh is
   disabled only for `.scanning`/`.discovering`, not `.cleaning`. Refreshing
   mid-clean runs `discover()`, which wipes `candidates`/`selected` while the
   clean loop still writes `phase`/mutates the lists. → add an `isBusy` guard.
2. **P1 · Cache cleaning swallows failed deletions.** `_mb_handle` (the
   `cmd_clean` sink) does `if _mb_remove …; then` with no post-condition check
   and never emits a `skipped` event — the same silent-failure bug we fixed for
   app-uninstall. → verify `[[ ! -e ]]`, emit `skipped`+reason, count `failed`,
   add `failed` to the `done` event; surface it in the cache result screen.
3. **P1 · `json_string` doesn't escape C0 control chars (<0x20).** A path/label
   with e.g. `\b`/`\f`/ESC emits invalid JSON → `JSONDecoder` rejects the whole
   result. → `\u00xx`-escape remaining control chars (guarded, so no fork in the
   common case).
4. **P2(safety) · `should_protect_path` fails open if the mole submodule drifts.**
   `cmd_app_scan`/`cmd_app_clean` call it unguarded. → wrap in `_protected`
   that fails **closed** (treat as protected) when the function is missing.
5. **P1 · Engine error messages are empty.** `runCollecting` sends stderr to
   `nullDevice` but builds `nonZeroExit` from stdout. → capture stderr for the
   message.
6. **P2 · No cancellation on the streaming clean.** `AsyncThrowingStream` sets no
   `onTermination`, so a cancelled Task leaves the child process running. → set
   `onTermination` to terminate the process.
7. **P2 · Temp file leak if `proc.run()` throws** in `streamingClean`. → remove
   it in the `catch`.

## Phase 2 — UX, high ROI

8. **Accessibility (P0, mechanical):** VoiceOver `accessibilityLabel`/`Value` on
   checkboxes, status cards, progress, icon buttons; gate animations behind
   `accessibilityReduceMotion`; widen hit targets (contentShape) on small
   controls.
9. **Keyboard (P1):** `⌘R` refresh, `⌘1/2/3` tabs, return on primary action,
   escape on back/cancel.
10. **Live payoff (P1):** show running freed bytes during cleaning
    (`Cleaning… 3/12 · 240 MB`) and the selected size on the action button
    (`Clean · 1.2 GB`).
11. **Cache partial-failure result (P1, couples with #2):** "N couldn't be
    removed" + Full Disk Access hint, mirroring the uninstall result.
12. **Trust UX (P1):** make the "auth/sessions/memory never touched" promise a
    persistent pill on the AI tab; show protected-but-kept items per tool.
13. **FDA banner state (P1):** show a granted/dismissed state and re-check on
    window focus.

## Phase 3 — Polish (P2)

14. Sort rows by size + per-row relative-size bar.
15. Differentiate cold "Nothing to clean" from post-run "All clean — X freed".
16. Skeleton rows while scanning; freed-bytes count-up + success-seal micro-anim
    (respecting reduce-motion).
17. Engine niceties: `cmd_clean` cross-volume Trash safety, `df -kP`,
    newline-in-path sizing, silence `git describe` in packaged builds.

---

### Sequencing
Phase 1 (bugs) → Phase 2 #8–#11 (a11y + keyboard + live payoff + failure
surfacing) → Phase 2 #12–#13 (trust) → Phase 3 polish. Each step builds, runs
self-tests + bats, and commits independently.
