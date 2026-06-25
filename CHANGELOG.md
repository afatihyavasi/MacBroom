# Changelog

This project follows [Semantic Versioning](https://semver.org/) and [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

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
