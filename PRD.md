# MacBroom — Product Requirements Document (PRD)

> A safe, open-source system & AI cache cleaner for the macOS menu bar.
> Uses [`tw93/mole`](https://github.com/tw93/mole) (GPL-3.0) as its engine.

- **Status:** Released v1.0.0 · 2026-06-25
- **License:** GPL-3.0-or-later (mole derivative)
- **Platform:** macOS 13+ (Apple Silicon & Intel)
- **Distribution:** Notarized DMG (non-sandboxed, Full Disk Access)

---

## 1. Problem & Vision

Over time, macOS fills up with caches, logs, browser leftovers, and especially the large cache files produced by **AI development tools** (Codex, Claude, Gemini, Cursor). Existing solutions are either closed-source/paid (CleanMyMac) or require terminal knowledge (the mole CLI).

**Vision:** Put mole's battle-tested, safety-first cleaning engine behind a **menu bar app** that fits the Mac design language. One-click safe preview and cleanup; AI tool caches as a first-class feature.

## 2. Target Audience

- Developers who use AI tools heavily (their caches quickly grow into GBs).
- Mac users who don't want the terminal and want visual, safe cleanup.

## 3. Goals / Non-Goals

**Goals (MVP)**
1. **Safe** cleanup of AI tool caches (without touching state).
2. System cache cleanup (dry-run preview + confirmation).
3. Disk/system status panel.
4. App uninstaller (with leftovers).

**Non-goals (for now)**
- A Mac App Store version (GPL-3.0 + Full Disk Access → sandbox restrictions).
- Windows/Linux.

> Note: Scheduled automatic cleanup and disk analysis **shipped in v2**
> (see the roadmap below).

## 4. Core Principles

1. **Safety comes first.** Nothing is deleted without a preview (dry-run) and explicit confirmation. mole's `should_protect_path` / whitelist / path-traversal protections are preserved.
2. **State is never deleted by default.** The credentials (auth), sessions, memory, and history data of AI tools are protected by default.
3. **Transparency.** Every candidate file is listed with path + size + reason + category.
4. **Native feel.** The macOS design language (MenuBarExtra, SF Symbols, materials).

## 5. Architecture (overview)

```
MacBroom.app (SwiftUI MenuBarExtra)
   │  Process + JSON/NDJSON
macbroom-engine.sh (bridge, sources the mole lib)
   │  source
vendor/mole/ (git submodule, pinned: V1.43.1)
```

Rather than mole's interactive `clean` command, the bridge calls the functions inside `lib/clean/*.sh` in a **non-interactive + DRY_RUN** manner to produce JSON. This enables category-based selective control and avoids fragile TUI scraping.

## 6. Feature Requirements

### F1 — AI Cache Cleanup (P0)
- Tool-based cards: **Codex, Claude (Code + Desktop), Gemini, Cursor**.
- A "Safe (cache)" vs "Advanced (state)" distinction for each tool; the latter is off by default + a separate confirmation.
- Running-tool detection (`pgrep`) → skip/warn if running.
- Protected: Codex `auth.json`/`sessions/`/`history.jsonl`/`*.sqlite`; Claude `memory/`/projects/`.claude/worktrees`/auth; Gemini credentials/state.
- Cleaned (safe): Gemini `tmp/` & `antigravity-browser-profile/`, codex runtimes, old bundled Claude Desktop versions, Cursor agent session logs.

### F2 — System Cache Cleanup (P0)
- Categories (mole `lib/clean/*`): user caches, app caches, logs, browser leftovers, .DS_Store, dev caches.
- Dry-run preview required → category/item selection → confirmation → live progress → "X GB freed" summary.

### F3 — Disk/System Status (P1)
- Disk usage percentage/badge on the menu bar icon.
- Panel: disk usage, estimated reclaimable space, CPU/RAM (mole `status`).

### F4 — App Uninstaller (P1)
- Installed apps + leftover scan (Application Support, Caches, Preferences, Logs...).
- Selective removal + confirmation; system-critical apps are protected.

## 7. Security & Privacy
- Fully local; no network access (no telemetry).
- All deletions pass through the mole security layer.
- History/log: recorded via mole `history`; viewable from the UI.
- Full Disk Access is explicitly requested/guided on first launch.

## 8. Success Metrics
- < 3 clicks from first scan to cleanup.
- Zero false-positive state deletion (tested).
- Dry-run preview < 5 s (typical machine).

## 9. Roadmap
- **v1.0 (MVP):** F1–F4, notarized DMG, CI.
- **v2 (shipped):** shadcn design system + light/dark theme; 4 languages (TR/EN/ES/FR);
  Developer cleanup category; disk analysis / large file finder;
  scheduled automatic cleanup (hourly/daily/weekly/monthly) + running while the
  app is closed via launchd + notifications; accessibility; total reclaimed space;
  Homebrew cask + signed/notarized release + landing page.
- **Next:** Sparkle automatic updates; cleanup history chart.
  (Shipped since v2: rules/whitelist UI — user-protected paths;
  browser & maintenance cleanup categories.)

## 10. Attribution & License
MacBroom packages `tw93/mole`'s cleaning engine and depends on its `lib/` modules. For this reason it is distributed under **GPL-3.0-or-later**. Full attribution to mole appears in the README and in the app's "About" screen.
