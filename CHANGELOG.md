# Changelog

This project follows [Semantic Versioning](https://semver.org/) and [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

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
