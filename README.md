<div align="center">

# 🧹 MacBroom

**A safe, open-source system & AI cache cleaner for the macOS menu bar.**

Powered by [`tw93/mole`](https://github.com/tw93/mole) · SwiftUI · GPL-3.0

</div>

---

## What is it?

MacBroom puts [mole](https://github.com/tw93/mole)'s safety-first cleaning engine behind a **menu bar app** that follows the Mac design language. No terminal required.

Headline feature: it safely cleans the cache files of AI tools like **Codex, Claude, Gemini, and Cursor** — **without touching** identity, session, or memory data.

## Features

- 🤖 **AI cache cleanup** — Codex / Claude / Gemini / Cursor; state is preserved, only regenerable caches are removed.
- 🧽 **System cache cleanup** — with a dry-run preview and explicit confirmation.
- 📊 **Disk & system status** — live in the menu bar.
- 🗑️ **App uninstaller** — the app plus its leftovers.

## Safety

MacBroom never deletes anything without a preview and confirmation. Every deletion passes through mole's `should_protect_path`, whitelist, and path-traversal protections. The auth / sessions / memory / history data of AI tools is **protected by default**. Details: [`docs/SAFETY.md`](docs/SAFETY.md).

## Setup (development)

```bash
git clone --recurse-submodules https://github.com/<you>/macbroom.git
cd macbroom
swift build           # the app
bats engine/tests/    # bridge tests
```

> Notarized DMG releases will be available on the Releases page.

## Architecture

```
MacBroom.app (SwiftUI MenuBarExtra)
   │  Process + JSON/NDJSON
engine/macbroom-engine.sh (sources mole's lib)
   │
vendor/mole (git submodule, pinned V1.43.1)
```

Details: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · Product requirements: [`PRD.md`](PRD.md).

## License & Attribution

MacBroom is distributed under **GPL-3.0-or-later** because it uses mole's GPL-3.0-licensed `lib/` modules. Thanks to [tw93/mole](https://github.com/tw93/mole) for the cleaning engine and safety design.
