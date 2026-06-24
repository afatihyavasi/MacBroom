# MacBroom Architecture

## Layers

```
┌─────────────────────────────────────────────┐
│  MacBroom.app  (SwiftUI, MenuBarExtra)        │  native UI
│  Views / ViewModels / Models / EngineBridge   │
└───────────────┬─────────────────────────────┘
                │ Process spawn · no stdin · stdout: JSON (result) + NDJSON (progress)
┌───────────────▼─────────────────────────────┐
│  engine/macbroom-engine.sh   (bridge, GPL-3.0) │
│  subcommands: scan | clean | status |        │
│                ai-scan | ai-clean | version    │
└───────────────┬─────────────────────────────┘
                │ source (bash)
┌───────────────▼─────────────────────────────┐
│  vendor/mole/  (git submodule · pinned tag)   │
│  lib/core/*.sh  lib/clean/*.sh  cmd/* (Go)     │
└─────────────────────────────────────────────┘
```

## Why a bridge script?

mole's `clean`/`uninstall` commands are **interactive** (TTY prompts, `-t 1` checks) and have no `--json` output; they are also monolithic (no category selection). The menu bar app, on the other hand, requires:
- category/item-based selective control,
- structured (JSON) data,
- non-interactive operation.

The most robust way to provide this, instead of mimicking mole's interactive entry points, is to **source the functions in `lib/clean/*.sh` directly** and call them in `DRY_RUN`/non-interactive mode. This way mole's audited deletion primitive `safe_clean` and its protection layer `should_protect_path` are preserved exactly as-is; only the UI/protocol layer is added.

## Bridge protocol

- **stdout last line(s)**: a single JSON object (command result).
- **intermediate lines (NDJSON)**: `{"event":"progress", ...}` progress events (for the long-running `clean`).
- **exit code**: 0 on success, !=0 on error; error JSON `{"error": "..."}`.

### Commands
| Command | Output | Description |
|-------|-------|----------|
| `scan --categories=ai,system` | `{candidates:[{category,label,path,size_bytes,protected,reason}]}` | dry-run scan |
| `clean --paths-file=F` | NDJSON progress + `{freed_bytes,count}` | deletes the selected paths |
| `ai-scan` | AI tool-based candidate list | specific to F1 |
| `ai-clean --tools=codex,gemini` | progress + summary | AI cache cleanup |
| `status` | `{disk,cpu,memory,cleanable_bytes}` | mole status metrics |
| `version` | `{macbroom,mole}` | versions |

## Swift side

- `EngineBridge`: runs the bundled script via `Process`; reads line by line; decodes JSON into `Decodable` models; emits progress through an `AsyncStream`.
- The engine + `vendor/mole` are copied under `.app/Contents/Resources/engine/` during the build; the script is granted execute permission.

## Distribution

Notarized DMG (Developer ID). NO sandbox — the cleaner requires Full Disk Access. On first launch, onboarding directs the user to System Settings > Privacy & Security > Full Disk Access.
