# MacBroom Safety Model

MacBroom can perform destructive (deletion) operations. The design is based on the **safe-by-default** principle and inherits mole's safety layer.

## Multi-layered protection

1. **Mandatory dry-run** — every cleanup is previewed first; nothing is deleted without the user seeing it.
2. **mole `should_protect_path` / `should_protect_data`** — system-critical paths and protected application data are rejected.
3. **Whitelist** — expensive-to-rebuild paths such as `~/Library/Caches/com.apple.Spotlight*`, JetBrains, `.ollama/models` are protected by default.
4. **Path-traversal rejection** — paths containing `..` or that are not absolute are rejected; `/`, `/System`, `/bin`, `/usr`, etc. are always protected.
5. **Explicit confirmation** — a separate confirmation step before deletion.

## AI tools: state is never deleted by default

| Tool | Protected (UNTOUCHED) | Cleanable (safe) |
|------|----------------------|--------------------------|
| **Codex** (`~/.codex`) | `auth.json`, `sessions/`, `history.jsonl`, `*.sqlite`, `session_index.jsonl` | runtime/temporary files |
| **Claude** (`~/.claude`, `~/Library/Application Support/Claude`) | `memory/`, projects, `.claude/worktrees`, auth | old bundled Desktop versions, regenerable cache |
| **Gemini** (`~/.gemini`) | identity/state | `tmp/`, `antigravity-browser-profile/` |
| **Cursor** | project data, auth | agent session logs |

Additional protection: **if a tool is running** (detected via `pgrep`), that tool is skipped and the user is warned.

## "Advanced" (state) cleanup

Advanced cleanup options that include state are **disabled by default** in the UI, require a separate and explicit confirmation, and the risk is clearly stated.

## Privacy

- Runs entirely locally; there is no network connection / telemetry.
- Deletion history is kept locally via mole `history`; it can be viewed from the UI.
