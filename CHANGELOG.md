# Changelog

This project follows [Semantic Versioning](https://semver.org/) and [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- **Six new scan targets**, all wired to mole's protection-gated sink: frontend
  build caches (node-gyp, Turbo, Vite, …), mobile development caches (XCTest
  devices, simulator runtime/dyld caches, SwiftPM, Android, Expo), JVM caches
  (Gradle, SBT, Ivy), cloud & CI tool caches, updater leftovers (ShipIt staged
  update bundles, skipped while ShipIt runs; old iOS firmware) and old Mail
  attachments. Package caches now also cover Homebrew downloads; toolchain
  caches cover Go build, DotSlash, Composer, NuGet, Deno and Bazel.
- New app icon.

### Changed
- **One permission ask instead of a stream of dialogs.** Analyzing without
  Full Disk Access used to raise a separate macOS prompt for Desktop,
  Documents, Downloads, other apps' data, Calendars, Contacts, … The first
  Analyze now asks once: grant Full Disk Access (picked up automatically, no
  relaunch) or continue with a limited scan. Without access the engine runs
  under a `sandbox-exec` profile that denies protected folders up front, so no
  dialog can appear; launchd auto-cleans are always sandboxed this way.
- **Auto-clean banners come from the app.** The engine no longer posts an
  `osascript` notification (shown as Script Editor, English-only, even for a
  few KB). MacBroom posts a localized banner itself, only when at least 100 MB
  was freed; launchd runs are announced when the app folds the reclaimed
  ledger (checked every minute). Developer ID builds use
  `UNUserNotificationCenter`; ad-hoc builds, which macOS denies notification
  authorization, fall back to in-process AppleScript.

### Fixed
- A path reached by two cleaners (e.g. Slack's `Cache_Data`) was listed twice,
  double-counting its size in the scan total.
- Selecting a target whose mole function sources a module with `set -e`
  (`clean_dev_jvm` → `maven.sh`) could abort the engine and return an empty
  result for **every** selected target.
- `make app` failed to find the universal binary on newer SwiftPM
  (`.build/out` instead of `.build/apple`).

## [1.0.2] - 2026-07-03

### Security / Safety (engine)
- **Scan really is read-only now.** mole has two deletion channels that bypass
  the engine's `safe_clean`/`safe_remove` sink, and both could fire during a
  supposedly read-only scan: `clean_tool_cache` executes purge commands
  directly (`npm cache clean --force`, `pip3 cache purge`, `pnpm store prune`,
  …), and `safe_sudo_remove` is a real `sudo rm -rf` used by browser/system
  cleaners whenever a sudo timestamp is alive. Both channels are now neutered;
  everything routes through the scan → approve → clean contract.
- **Unmatched glob targets are no longer word-split.** An unmatched pattern
  like `…/Google/Chrome/*/Application Cache/*` was split on spaces and each
  fragment re-globbed **relative to the engine's working directory**, so paths
  that were never cache files could be surfaced — and via auto-clean deleted.
  Patterns now expand without word splitting.
- **Every deletion passes mole's `validate_path_for_deletion`.** The engine's
  sink now rejects relative paths, `..` traversal, control characters, and
  critical system paths before any `rm -rf`/Trash move — a corrupt approved-
  paths file can no longer translate into an unguarded delete.

### Fixed
- **"Empty Trash" in Move-to-Trash mode did nothing while reporting freed
  bytes** (items were renamed in place inside `~/.Trash`); it now really
  deletes. Trash name collisions within the same second no longer nest one
  trashed folder inside another (which also corrupted restore paths).
- **"Logs & .DS_Store" now actually cleans `.DS_Store` files** — the registry
  pointed at a mole function that was never sourced and, even if it had been,
  needed arguments; the target silently skipped that half.
- **App uninstall respects the user's "Protected paths" list** when collecting
  candidates, and a protected path that still reaches app-clean emits a
  `skipped` event instead of disappearing silently from the totals.
- **`analyze` no longer emits truncated paths** for filenames containing a
  newline (the truncated first line used to pass the guard), and its numeric
  arguments are regex-validated instead of arithmetic-evaluated.
- **"MacBroom is damaged" persisted after 1.0.1 on Apple Silicon.** The 1.0.1
  ad-hoc seal made the bundle *valid*, but Gatekeeper still reports a
  *quarantined* ad-hoc-signed app as "damaged" on Apple Silicon, and
  right-click → Open does not bypass that dialog — only clearing the
  quarantine flag (or notarization) does. Install paths now handle this:
  - The Homebrew cask clears the quarantine flag in a `postflight` step, so
    `brew install --cask afatihyavasi/tap/macbroom` opens with no dialog.
  - The DMG ships a READ ME with the one-line fix
    (`xattr -d com.apple.quarantine /Applications/MacBroom.app`), and the
    release notes / README / website say the same instead of the old,
    incorrect "right-click → Open" advice.
- **DMG only ran on Apple Silicon.** CI builds on an arm64 runner produced an
  arm64-only binary, so Intel Macs got "this application is not supported on
  this type of Mac". `make-app.sh` now builds a universal (arm64 + x86_64)
  binary; `MACBROOM_ARCHS=native` keeps fast single-arch local builds.
- **DMG staging could invalidate the code signature.** `make-dmg.sh` now
  copies the app with `ditto` (preserves extended attributes and signature
  metadata) instead of `cp -R`.

## [1.0.1] - 2026-06-25

### Fixed
- **"MacBroom is damaged and can't be opened" on download.** `make-app.sh`
  assembled the bundle but only code-signed it when a Developer ID was present,
  so unsigned release builds shipped with just the linker's ad-hoc signature on
  the inner binary — an inconsistent bundle seal that macOS flags as damaged on
  Apple Silicon once the app is quarantined. The bundle is now **always signed**
  (Developer ID when available, otherwise an ad-hoc signature that seals the
  bundle), so an unsigned download shows the normal "unidentified developer"
  prompt (right-click → Open) instead of "damaged".

## [1.0.0] - 2026-06-25

First public release. Highlights below; the `(beta)` / `(v2)` tags mark the
development phase each item landed in on the way to 1.0.0.

### Added (beta)
- **Undo last cleanup:** Move-to-Trash cleanups now record where each item
  landed (the engine reports a `trashed_to` path), so Settings shows an "Undo
  last cleanup" action that puts the items back. Permanent deletes report
  nothing (nothing to restore).
- **Scheduled cleaning for System targets:** automation is no longer AI-only —
  any installed System target (caches, Xcode, language toolchains, Trash, …) can
  run on the same hourly/daily/weekly/monthly schedule.
- **"Why is this safe?" reason** under every cache row: a conservative, accurate
  hint (already in Trash / superseded version / regenerable AI cache /
  regenerable system cache), in all four languages.
- **Cleaning-history chart:** a compact, dependency-free bar chart of reclaimed
  space per recent cleanup, above the Settings history list.
- **New cleaning targets** (under System): Xcode device support (old iOS/watchOS/
  tvOS debug symbols), language toolchain caches (Rust, Ruby), and the Docker
  BuildX cache. Each routes through mole's `safe_clean`/`safe_remove` sink, so
  scan only lists and clean only removes approved paths — verified by a bats test
  that a scan never deletes. (Homebrew, the Xcode simulator runtime/system
  caches, and Go were deliberately *not* wired up: those mole functions delete
  via `brew cleanup` / `go clean` / `safe_sudo_remove`, which bypass the preview
  gate and would delete — or prompt for sudo — during a scan.)
- **Protected paths (rules / whitelist):** add files or folders in Settings that
  are never scanned or deleted. Subtree match — protecting a folder shields
  everything inside it. Enforced in the engine's single deletion sink (and the
  app-uninstaller loop) as a defense-in-depth layer on top of mole's own
  protections; covered by a self-test.
- **Full Disk Access detection:** the app now reflects the live FDA permission
  state in the UI instead of always prompting.
- **Native notifications:** scheduled cleanups post real MacBroom banners; the
  engine no longer raises osascript "Script Editor" notices.

### Fixed (beta)
- Relative time and the progress-bar accessibility percent now follow the app
  language (the picker), not the OS locale — an English UI no longer showed
  Turkish strings like "2 dk. önce".
- Removed `UNUserNotificationCenter`, which crashed the unsigned app.
- Scheduled-cleaning failures are no longer swallowed: if a launchd agent can't
  be installed, Automation now shows which tools failed instead of silently
  accepting a schedule that will never fire.

### Engineering (beta)
- CI now builds with `-Xswiftc -warnings-as-errors` and runs on the `beta`
  branch as well as `main`. (swift-format was evaluated and deliberately not
  adopted — it conflicts with the codebase's hand-tuned style.)
- Documentation: English app screenshots added to the README and landing page.

### Added
- Project skeleton: PRD, README, GPL-3.0 license, contribution guide.
- `vendor/mole` submodule (pinned V1.43.1).
- `macbroom-engine.sh`: a JSON bridge that sources mole's `lib/`
  (`scan/clean/ai-scan/ai-clean/apps/app-scan/app-clean/status/version`).
- SwiftUI `MenuBarExtra` app (`MacBroomCore` + `MacBroom`).
- AI cache cleanup: Codex/Claude/Gemini/Cursor tool-based, state preserved.
- System cache cleanup (opt-in selection).
- Live disk + memory status panel.
- App uninstaller (app + leftovers, confirmed deletion).
- Settings: deletion method (permanent / Trash), Full Disk Access guidance,
  mole attribution; first-launch FDA banner.

### Added (v2)
- shadcn-inspired SwiftUI design system (tokens + reusable
  components); light/dark/system **appearance** selection (NSApp.appearance).
- Localization: Turkish / English / Spanish / French (4 languages), instant
  language switching from Settings; guarded by missing-key + placeholder tests.
- **Developer** cleanup category (Xcode DerivedData, npm/pip/poetry).
- **Disk analysis / large file finder** (read-only scan; reveal in Finder;
  deletion only via the protected `app-clean` and **always to the Trash**).
- **Scheduled automatic cleanup**: per AI tool, hourly (every N hours) /
  daily / weekly (day of week) / monthly (day of month, hour:minute); edited in
  a separate panel, applied via **Save**.
- **launchd agents**: scheduled cleanup runs even when the app is closed;
  local notification on success.
- Total reclaimed space statistic; per-row size bars; icon
  caching.
- Accessibility: VoiceOver labels, Reduce Motion, larger touch
  targets.

### Fixed (v2)
- The menu-bar panel closing during deletion (Settings/Automation/Disk analysis
  now open in their own real windows); uninstall confirmation is in-panel.
- A crash in the deletion flow (`availableData` → throwing `read`), the "0 KB freed"
  race, failed deletions being silently swallowed, the `json_string` control-character
  escape; the AI/System tabs leaking into each other.

### Engineering (v2)
- Engine: `auto-clean`, `analyze` subcommands; `safe_remove` protection pass.
- CI/distribution: signed + notarized release (graceful fallback), Homebrew cask,
  landing page; expanded bats + self-test coverage.
