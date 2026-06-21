#!/usr/bin/env bash
#
# MacBroom engine — a JSON bridge over mole's cleaning library.
#
# This script SOURCES mole's GPL-3.0 `lib/` modules and re-uses its audited
# deletion safety layer (`should_protect_path`, `is_path_whitelisted`) and its
# extensive knowledge of *which* paths are safe to remove. The only thing we
# replace is the deletion *sink*: we override `safe_clean` so we can either
#   - record candidates as JSON (scan mode), or
#   - delete only user-approved paths and stream NDJSON progress (clean mode).
#
# Because it links against mole's GPL-3.0 code, MacBroom is GPL-3.0-or-later.
#
# Protocol (stdout):
#   - intermediate lines: NDJSON progress events  {"event":"progress",...}
#   - final line:         a single JSON result object
#   - exit code:          0 ok, non-zero on fatal error ({"error":"..."} on stdout)
#
# Subcommands:
#   scan   --categories=ai,system        dry-run; emit candidate list
#   clean  --paths-file=FILE             delete approved paths; stream progress
#   ai-scan                              convenience: scan --categories=ai
#   ai-clean --paths-file=FILE           convenience clean restricted to AI dirs
#   status                               disk/memory snapshot as JSON
#   version                              {"macbroom":"..","mole":".."}

set -uo pipefail

readonly MACBROOM_VERSION="0.1.0"

# --------------------------------------------------------------------------
# Locate mole
# --------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOLE_DIR="${MACBROOM_MOLE_DIR:-$SCRIPT_DIR/../vendor/mole}"

die() {
    # Emit a JSON error on stdout and exit non-zero.
    printf '{"error":%s}\n' "$(json_string "$1")"
    exit "${2:-1}"
}

# --------------------------------------------------------------------------
# Minimal JSON helpers (no jq dependency)
# --------------------------------------------------------------------------
# Escape a raw string into a quoted JSON string literal.
# Escape any remaining C0 control bytes (< 0x20) as \u00xx. Operates byte-wise
# under LC_ALL=C so multibyte UTF-8 sequences (all bytes >= 0x80) pass through
# untouched and reassemble correctly on the Swift side.
_json_escape_controls() {
    LC_ALL=C awk '
        BEGIN { for (i = 0; i < 256; i++) ord[sprintf("%c", i)] = i }
        {
            out = ""
            for (j = 1; j <= length($0); j++) {
                c = substr($0, j, 1)
                if (ord[c] < 32) out = out sprintf("\\u%04x", ord[c])
                else out = out c
            }
            print out
        }'
}

json_string() {
    local s="$1"
    s="${s//\\/\\\\}"   # backslash
    s="${s//\"/\\\"}"   # double quote
    s="${s//$'\n'/\\n}" # newline
    s="${s//$'\r'/\\r}" # carriage return
    s="${s//$'\t'/\\t}" # tab
    # Rare: a path/label with other control chars would otherwise emit invalid
    # JSON and fail the whole result. Only fork awk when one is actually present.
    case "$s" in
        *[[:cntrl:]]*) s="$(printf '%s' "$s" | _json_escape_controls)" ;;
    esac
    printf '"%s"' "$s"
}

# --------------------------------------------------------------------------
# Engine state (shared with our safe_clean override)
# --------------------------------------------------------------------------
MB_MODE="scan"            # scan | clean
MB_CATEGORY="system"      # tag attached to each candidate
MB_FREED_BYTES=0
MB_COUNT=0
MB_PATHS_FILE=""          # clean mode: file of approved absolute paths (one per line)
declare -a MB_CANDIDATES=()   # JSON object strings (scan mode)
declare -a MB_SCAN_PATHS=()   # raw candidate paths (scan mode; used by auto-clean)
# NOTE: macOS ships bash 3.2 (no associative arrays), so the approved-path set
# is kept as a file and membership is tested with a fixed-string grep.

# Real stdout is preserved on fd 9 so mole's human-readable chatter can be sent
# to /dev/null while our protocol output still reaches the caller.
exec 9>&1
emit() { printf '%s\n' "$1" >&9; }

# Size of a path in bytes (directories summed). Best-effort; 0 on failure.
path_size_bytes() {
    local kb
    kb="$(du -sk -- "$1" 2>/dev/null | awk 'NR==1{print $1; exit}')"
    [[ "$kb" =~ ^[0-9]+$ ]] || kb=0
    printf '%s' "$((kb * 1024))"
}

# Size many paths in ONE du pass: prints the KB (1024-byte blocks) for each
# argument, one per line, in argument order. One fork instead of N — the win
# for app-scan, where a big app can have dozens of leftover paths. The caller
# multiplies to bytes in bash (64-bit safe; awk would overflow into floats).
_sizes_kb() {
    [[ $# -gt 0 ]] || return 0
    du -sk -- "$@" 2>/dev/null | awk -F'\t' '{print $1}'
}

# --------------------------------------------------------------------------
# Deletion sink. Isolated so the Trash-vs-permanent policy lives in one place.
# Honors MACBROOM_DELETE_MODE: "trash" moves to ~/.Trash (reversible),
# anything else permanently removes (matching `mo clean`). The path has already
# passed mole's protection + whitelist checks. Returns 0 on success.
# --------------------------------------------------------------------------
_mb_remove() {
    if [[ "${MACBROOM_DELETE_MODE:-permanent}" == "trash" ]]; then
        _mb_trash "$1"
    else
        rm -rf -- "$1" 2>/dev/null
    fi
}

# Move a path into the user's Trash, disambiguating name collisions.
_mb_trash() {
    local src="$1"
    local trash="$HOME/.Trash"
    [[ -d "$trash" ]] || mkdir -p "$trash" 2>/dev/null || return 1
    local base dest
    base="$(basename "$src")"
    dest="$trash/$base"
    if [[ -e "$dest" ]]; then
        dest="$trash/${base} $(date +%Y%m%d-%H%M%S)-$$"
    fi
    mv -f -- "$src" "$dest" 2>/dev/null
}

# --------------------------------------------------------------------------
# Our override of mole's safe_clean.
# mole calls it as:  safe_clean <target...> <description>
#   - exactly one arg  -> arg is both the target and the description
#   - more than one    -> last arg is the description, the rest are targets/globs
# --------------------------------------------------------------------------
safe_clean() {
    [[ $# -eq 0 ]] && return 0

    local description
    local -a targets
    if [[ $# -eq 1 ]]; then
        description="$1"; targets=("$1")
    else
        description="${*: -1}"; targets=("${@:1:$#-1}")
    fi

    local target
    for target in "${targets[@]}"; do
        local -a expanded=()
        if [[ "$target" == *"*"* ]]; then
            shopt -s nullglob
            # shellcheck disable=SC2206  # intentional glob expansion
            expanded=( $target )
            shopt -u nullglob
        else
            expanded=("$target")
        fi

        local p
        for p in "${expanded[@]}"; do
            [[ -e "$p" || -L "$p" ]] || continue
            # Re-use mole's audited protection + whitelist before touching anything.
            if declare -F should_protect_path >/dev/null 2>&1 && should_protect_path "$p"; then
                continue
            fi
            if declare -F is_path_whitelisted >/dev/null 2>&1 && is_path_whitelisted "$p"; then
                continue
            fi
            _mb_handle "$p" "$description"
        done
    done
}

# --------------------------------------------------------------------------
# Our override of mole's safe_remove.
# mole calls it as:  safe_remove <path> [silent] [precomputed_size_kb]
# Some clean functions (e.g. clean_xcode_derived_data) delete via safe_remove
# instead of safe_clean. Route those through the same protection-gated sink so
# they surface in scan mode and obey the approved-path allowlist in clean mode,
# exactly like safe_clean. The extra args (silent/size) are mole-internal and
# irrelevant to us. Returns 0 so callers that count successes keep working.
#
# NOTE: unlike safe_clean (which mole never defines), mole DOES define its own
# safe_remove in lib/core/file_ops.sh, sourced by load_mole. So our override is
# clobbered when mole loads and MUST be re-applied afterwards. The body lives in
# _mb_install_safe_remove_override so load_mole can re-install it at the end.
# --------------------------------------------------------------------------
_mb_install_safe_remove_override() {
    safe_remove() {
        local path="$1"
        [[ -n "$path" ]] || return 0
        [[ -e "$path" || -L "$path" ]] || return 0
        if declare -F should_protect_path >/dev/null 2>&1 && should_protect_path "$path"; then
            return 0
        fi
        if declare -F is_path_whitelisted >/dev/null 2>&1 && is_path_whitelisted "$path"; then
            return 0
        fi
        _mb_handle "$path" "$(basename "$path")"
        return 0
    }
}
_mb_install_safe_remove_override

# Membership test for the approved-path allowlist (bash 3.2 friendly).
_mb_is_approved() {
    [[ -n "$MB_PATHS_FILE" ]] || return 1
    grep -Fxq -- "$1" "$MB_PATHS_FILE"
}

# Protection gate that fails CLOSED: if mole's `should_protect_path` is missing
# (submodule drift), treat every path as protected so we never list/delete a
# path unguarded. Returns 0 (protected) when the function is unavailable.
_protected() {
    if declare -F should_protect_path >/dev/null 2>&1; then
        should_protect_path "$1"
    else
        return 0
    fi
}

# Handle one protection-cleared path according to the current mode.
_mb_handle() {
    local path="$1" label="$2"

    if [[ "$MB_MODE" == "scan" ]]; then
        local size; size="$(path_size_bytes "$path")"
        MB_CANDIDATES+=("{\"category\":$(json_string "$MB_CATEGORY"),\"label\":$(json_string "$label"),\"path\":$(json_string "$path"),\"size_bytes\":$size}")
        MB_SCAN_PATHS+=("$path")   # raw paths, for auto-clean's scan→clean
        MB_COUNT=$((MB_COUNT + 1))
        return 0
    fi

    # clean mode: only delete paths the user explicitly approved.
    _mb_is_approved "$path" || return 0
    local size; size="$(path_size_bytes "$path")"
    if _mb_remove "$path" && [[ ! -e "$path" && ! -L "$path" ]]; then
        MB_FREED_BYTES=$((MB_FREED_BYTES + size))
        MB_COUNT=$((MB_COUNT + 1))
        emit "{\"event\":\"progress\",\"path\":$(json_string "$path"),\"freed_bytes\":$size}"
    else
        # Removal failed (path still present) — report it so the UI can tell the
        # user, instead of silently counting it as cleaned.
        local reason
        if [[ ! -w "$(dirname "$path")" ]]; then reason="permission"; else reason="failed"; fi
        MB_FAILED=$((${MB_FAILED:-0} + 1))
        emit "{\"event\":\"skipped\",\"path\":$(json_string "$path"),\"reason\":\"$reason\"}"
    fi
}

# --------------------------------------------------------------------------
# Load mole and a small compatibility shim for orchestration helpers that
# normally live in mole's interactive bin/clean.sh (not in lib/).
# --------------------------------------------------------------------------
load_mole() {
    [[ -d "$MOLE_DIR/lib/clean" ]] || die "mole not found at $MOLE_DIR (run: git submodule update --init)" 2

    # shellcheck disable=SC1091
    source "$MOLE_DIR/lib/core/common.sh" || die "failed to source mole common.sh" 3

    local m
    for m in dev caches user system app_caches; do
        # shellcheck disable=SC1090
        source "$MOLE_DIR/lib/clean/$m.sh" 2>/dev/null || true
    done

    # Helpers referenced by lib/clean functions but defined in bin/clean.sh.
    # Define as harmless no-ops only if mole did not already provide them.
    declare -F register_dry_run_cleanup_target >/dev/null 2>&1 || register_dry_run_cleanup_target() { return 0; }
    declare -F start_inline_spinner             >/dev/null 2>&1 || start_inline_spinner() { return 0; }
    declare -F stop_section_spinner             >/dev/null 2>&1 || stop_section_spinner() { return 0; }
    declare -F start_section                     >/dev/null 2>&1 || start_section() { return 0; }
    declare -F print_section_header             >/dev/null 2>&1 || print_section_header() { return 0; }

    # mole code uses DRY_RUN extensively; our override ignores it but keep it set.
    DRY_RUN="${DRY_RUN:-false}"

    # mole's lib/clean functions are normally orchestrated by its interactive
    # bin/clean.sh, which defines several globals (CURRENT_SECTION,
    # whitelist_skipped_count, MOLE_UNINSTALL_MODE, ...). We call those functions
    # directly, so those globals are unset. Under `set -u` an unset reference is
    # FATAL even with errexit off, so relax both nounset and errexit here. The
    # deletion safety we rely on (should_protect_path / is_path_whitelisted) does
    # not depend on these shell options.
    set +eu

    # mole's file_ops.sh defined its own safe_remove just now, clobbering our
    # protection-gated override. Re-install ours so safe_remove-based cleaners
    # (e.g. clean_xcode_derived_data) route through the engine sink. safe_clean
    # needs no such treatment — mole never defines it.
    _mb_install_safe_remove_override
}

# --------------------------------------------------------------------------
# Target registry.
#
# Each line: id|label|category|detect|fns
#   detect : ':'-separated existence checks ('~' = $HOME); '*' = always present
#   fns    : space-separated mole functions to run for this target
#
# This is what makes scoped, fast analysis possible: discovery just checks
# `detect` (no `du`), and a scan runs only the union of `fns` for the targets
# the user selected — instead of every category function every time.
# --------------------------------------------------------------------------
_mb_targets() {
    cat <<'EOF'
ai:gemini|Gemini / Antigravity|ai|~/.gemini|clean_antigravity_caches
ai:codex|Codex / ChatGPT|ai|~/.codex:~/.cache/codex-runtimes:~/Library/Caches/com.openai.chat|clean_codex_runtimes clean_codex_cli clean_ai_apps
ai:claude|Claude|ai|~/.local/share/claude:~/Library/Caches/com.anthropic.claudefordesktop:~/Library/Logs/Claude|clean_dev_ai_agents clean_ai_apps
ai:cursor|Cursor|ai|~/.local/share/cursor-agent|clean_dev_ai_agents
ai:copilot|GitHub Copilot|ai|~/.copilot|clean_dev_ai_agents
ai:devtools-mcp|Chrome DevTools MCP|ai|~/.cache/chrome-devtools-mcp:~/Library/Caches/chrome-devtools-mcp|clean_chrome_devtools_mcp_caches
system:app-caches|Uygulama önbellekleri|system|*|clean_app_caches
system:editors|Kod editörleri|system|~/Library/Application Support/Code:~/Library/Application Support/Cursor:~/Library/Application Support/JetBrains|clean_code_editors
system:gui-apps|GUI uygulama önbellekleri|system|*|clean_user_gui_applications
system:dev-misc|Geliştirici artıkları|system|*|clean_dev_misc
developer:xcode|Xcode DerivedData|developer|~/Library/Developer/Xcode/DerivedData|clean_xcode_derived_data
developer:pkg-caches|Paket yöneticisi önbellekleri|developer|~/.npm:~/.yarn/cache:~/Library/Caches/pip:~/.cache/poetry|clean_dev_npm clean_dev_python
EOF
}

_expand_home() { printf '%s' "${1/#\~/$HOME}"; }

# 0 if any detect path exists (or detect is '*').
_target_installed() {
    local detect="$1" path
    [[ "$detect" == "*" ]] && return 0
    local IFS=:
    for path in $detect; do
        [[ -e "$(_expand_home "$path")" ]] && return 0
    done
    return 1
}

# Run the union of mole functions for the given target ids (CSV), de-duplicated,
# each tagged with its target's category. Guarded so submodule drift never
# crashes the engine.
_run_targets() {
    local wanted=",$1,"   # CSV wrapped for substring matching
    local ran=" "
    local id label category detect fns fn
    while IFS='|' read -r id label category detect fns; do
        [[ -n "$id" ]] || continue
        [[ "$wanted" == *",$id,"* ]] || continue
        MB_CATEGORY="$category"
        for fn in $fns; do
            [[ "$ran" == *" $fn "* ]] && continue   # already run this scan
            ran+="$fn "
            declare -F "$fn" >/dev/null 2>&1 && "$fn"
        done
    done < <(_mb_targets)
}

# Expand category names (ai,system) to their target ids.
_targets_for_categories() {
    local cats=",$1," id _ category _rest out=""
    while IFS='|' read -r id _ category _rest; do
        [[ -n "$id" ]] || continue
        [[ "$cats" == *",$category,"* ]] && out+="${out:+,}$id"
    done < <(_mb_targets)
    printf '%s' "$out"
}

emit_scan_result() {
    local joined=""
    local i
    for ((i = 0; i < ${#MB_CANDIDATES[@]}; i++)); do
        joined+="${MB_CANDIDATES[$i]}"
        [[ $i -lt $((${#MB_CANDIDATES[@]} - 1)) ]] && joined+=","
    done
    emit "{\"candidates\":[$joined],\"count\":$MB_COUNT}"
}

# --------------------------------------------------------------------------
# Subcommands
# --------------------------------------------------------------------------
# Fast: list every analyzable target and whether it is present on this system.
# No `du`, no mole load — just existence checks, so it returns instantly.
cmd_discover() {
    local out="" first=1
    local id label category detect _fns installed
    while IFS='|' read -r id label category detect _fns; do
        [[ -n "$id" ]] || continue
        if _target_installed "$detect"; then installed="true"; else installed="false"; fi
        [[ $first -eq 1 ]] || out+=","
        first=0
        out+="{\"id\":$(json_string "$id"),\"label\":$(json_string "$label"),\"category\":$(json_string "$category"),\"installed\":$installed}"
    done < <(_mb_targets)
    emit "{\"targets\":[$out]}"
}

# Resolve --targets / --categories args to a concrete CSV of target ids.
_resolve_targets() {
    local sel="" cats="" arg
    for arg in "$@"; do
        case "$arg" in
            --targets=*)    sel="${arg#*=}" ;;
            --categories=*) cats="${arg#*=}" ;;
        esac
    done
    if [[ -n "$sel" ]]; then
        printf '%s' "$sel"
    elif [[ -n "$cats" ]]; then
        _targets_for_categories "$cats"
    else
        _targets_for_categories "ai,system"
    fi
}

cmd_scan() {
    local targets
    targets="$(_resolve_targets "$@")"

    MB_MODE="scan"
    load_mole

    { _run_targets "$targets"; } >/dev/null 2>&1

    emit_scan_result
}

cmd_clean() {
    local paths_file=""
    local arg
    for arg in "$@"; do
        case "$arg" in --paths-file=*) paths_file="${arg#*=}" ;; esac
    done
    [[ -n "$paths_file" && -f "$paths_file" ]] || die "clean requires --paths-file=FILE" 4

    local targets
    targets="$(_resolve_targets "$@")"

    MB_PATHS_FILE="$paths_file"
    MB_MODE="clean"
    load_mole

    { _run_targets "$targets"; } >/dev/null 2>&1

    emit "{\"event\":\"done\",\"freed_bytes\":$MB_FREED_BYTES,\"count\":$MB_COUNT,\"failed\":${MB_FAILED:-0}}"
}

# Human-readable byte count for notifications (e.g. "1.2 GB").
_human_bytes() {
    awk -v b="$1" 'BEGIN {
        split("B KB MB GB TB", u); i = 1
        while (b >= 1024 && i < 5) { b /= 1024; i++ }
        printf (i == 1 ? "%d %s" : "%.1f %s"), b, u[i]
    }'
}

# Best-effort native banner (works even when launched from launchd, no app).
_mb_notify() {
    command -v osascript >/dev/null 2>&1 || return 0
    local msg="$1"
    osascript -e "display notification \"$msg\" with title \"MacBroom\"" >/dev/null 2>&1 || true
}

# Scheduled automation: scan the target(s) and clean everything they surface,
# in one shot. Same safety contract as a manual clean (mole-protection-filtered
# candidates only); honors MACBROOM_DELETE_MODE. Posts a notification on success
# so the user knows a background clean happened. Used by the launchd agent.
cmd_auto_clean() {
    local targets="" arg
    for arg in "$@"; do case "$arg" in --targets=*) targets="${arg#*=}" ;; esac; done
    [[ -n "$targets" ]] || die "auto-clean requires --targets=ID[,ID]" 4

    load_mole

    # Phase 1 — scan to collect candidate paths.
    MB_MODE="scan"; MB_CANDIDATES=(); MB_SCAN_PATHS=()
    { _run_targets "$targets"; } >/dev/null 2>&1

    if [[ ${#MB_SCAN_PATHS[@]} -eq 0 ]]; then
        emit "{\"event\":\"done\",\"freed_bytes\":0,\"count\":0,\"failed\":0}"
        return 0
    fi

    # Phase 2 — clean exactly those paths.
    local tmp; tmp="$(mktemp)"
    printf '%s\n' "${MB_SCAN_PATHS[@]}" > "$tmp"
    MB_MODE="clean"; MB_PATHS_FILE="$tmp"; MB_FREED_BYTES=0; MB_COUNT=0; MB_FAILED=0
    { _run_targets "$targets"; } >/dev/null 2>&1
    rm -f "$tmp"

    if [[ "${MB_FREED_BYTES:-0}" -gt 0 ]]; then
        _mb_notify "$(_human_bytes "$MB_FREED_BYTES") boşaltıldı"
    fi
    emit "{\"event\":\"done\",\"freed_bytes\":$MB_FREED_BYTES,\"count\":$MB_COUNT,\"failed\":${MB_FAILED:-0}}"
}

# --------------------------------------------------------------------------
# App uninstaller
# --------------------------------------------------------------------------
_app_bundle_id() {
    plutil -extract CFBundleIdentifier raw "$1/Contents/Info.plist" 2>/dev/null \
        || defaults read "$1/Contents/Info" CFBundleIdentifier 2>/dev/null \
        || echo ""
}

# List user-removable applications as JSON. Intentionally does NOT size each
# app (no `du`) so the list returns instantly; the size is computed lazily by
# app-scan when the user selects a specific app.
cmd_apps() {
    load_mole
    local -a roots=("/Applications" "$HOME/Applications")
    local out="" first=1
    local root app name bundle
    for root in "${roots[@]}"; do
        [[ -d "$root" ]] || continue
        for app in "$root"/*.app; do
            [[ -d "$app" ]] || continue
            name="$(basename "$app" .app)"
            bundle="$(_app_bundle_id "$app")"
            # Skip system-critical / protected apps.
            if declare -F should_protect_from_uninstall >/dev/null 2>&1 \
                && should_protect_from_uninstall "$bundle" 2>/dev/null; then
                continue
            fi
            [[ $first -eq 1 ]] || out+=","
            first=0
            out+="{\"name\":$(json_string "$name"),\"path\":$(json_string "$app"),\"bundle_id\":$(json_string "$bundle")}"
        done
    done
    emit "{\"apps\":[$out]}"
}

# Scan one app: the bundle itself + its leftover files, as removal candidates.
cmd_app_scan() {
    local app=""
    local arg
    for arg in "$@"; do
        case "$arg" in --app=*) app="${arg#*=}";; esac
    done
    [[ -n "$app" && -d "$app" ]] || die "app-scan requires --app=/path/App.app" 4

    export MOLE_UNINSTALL_MODE=1
    MB_MODE="scan"; MB_CATEGORY="app"
    load_mole

    local name bundle
    name="$(basename "$app" .app)"
    bundle="$(_app_bundle_id "$app")"

    # Collect candidate paths + labels first (cheap existence/protection checks),
    # then size them all in one du pass — so a large app's review screen no
    # longer stalls behind dozens of serial `du` forks.
    local -a paths labels
    paths+=("$app"); labels+=("$name")

    local p
    while IFS= read -r p; do
        [[ -n "$p" && ( -e "$p" || -L "$p" ) ]] || continue
        if _protected "$p"; then continue; fi
        paths+=("$p"); labels+=("$(basename "$p")")
    done < <(find_app_files "$bundle" "$name" 2>/dev/null || true)

    # One du pass; KB align with `paths` by position. If the count doesn't match
    # (a path failed to stat), fall back to per-path sizing for correctness.
    local -a kbs=() sizes=()
    while IFS= read -r p; do kbs+=("$p"); done < <(_sizes_kb "${paths[@]}")
    if [[ "${#kbs[@]}" -eq "${#paths[@]}" ]]; then
        local kb
        for kb in "${kbs[@]}"; do
            [[ "$kb" =~ ^[0-9]+$ ]] || kb=0
            sizes+=("$((kb * 1024))")
        done
    else
        for p in "${paths[@]}"; do sizes+=("$(path_size_bytes "$p")"); done
    fi

    local i
    for i in "${!paths[@]}"; do
        MB_CANDIDATES+=("{\"category\":\"app\",\"label\":$(json_string "${labels[$i]}"),\"path\":$(json_string "${paths[$i]}"),\"size_bytes\":${sizes[$i]:-0}}")
        MB_COUNT=$((MB_COUNT + 1))
    done

    emit_scan_result
}

# Remove the approved app + leftover paths.
cmd_app_clean() {
    local paths_file=""
    local arg
    for arg in "$@"; do
        case "$arg" in --paths-file=*) paths_file="${arg#*=}";; esac
    done
    [[ -n "$paths_file" && -f "$paths_file" ]] || die "app-clean requires --paths-file=FILE" 4

    export MOLE_UNINSTALL_MODE=1
    MB_MODE="clean"
    load_mole

    local p size reason
    while IFS= read -r p || [[ -n "$p" ]]; do
        [[ -n "$p" && ( -e "$p" || -L "$p" ) ]] || continue
        if _protected "$p"; then continue; fi
        size="$(path_size_bytes "$p")"
        if _mb_remove "$p" && [[ ! -e "$p" && ! -L "$p" ]]; then
            MB_FREED_BYTES=$((MB_FREED_BYTES + size))
            MB_COUNT=$((MB_COUNT + 1))
            emit "{\"event\":\"progress\",\"path\":$(json_string "$p"),\"freed_bytes\":$size}"
        else
            # Removal failed (path still exists). Classify so the UI can tell the
            # user whether granting Full Disk Access / admin would help.
            if [[ ! -w "$(dirname "$p")" ]]; then reason="permission"; else reason="failed"; fi
            MB_FAILED=$((${MB_FAILED:-0} + 1))
            emit "{\"event\":\"skipped\",\"path\":$(json_string "$p"),\"reason\":\"$reason\"}"
        fi
    done < "$paths_file"

    emit "{\"event\":\"done\",\"freed_bytes\":$MB_FREED_BYTES,\"count\":$MB_COUNT,\"failed\":${MB_FAILED:-0}}"
}

cmd_status() {
    # Disk snapshot for the volume backing $HOME, via df (POSIX, 1K blocks).
    local total used avail pct
    read -r total used avail pct < <(
        df -k "$HOME" 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $2*1024, $3*1024, $4*1024, $5; exit}'
    )
    : "${total:=0}" "${used:=0}" "${avail:=0}" "${pct:=0}"

    # Memory snapshot. "available" ~= free + inactive + speculative + purgeable
    # (reclaimable without pressure); used = total - available.
    local mem_total mem_used mem_pct
    mem_total="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
    local page avail_pages
    page="$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)"
    avail_pages="$(vm_stat 2>/dev/null | awk -F'[:.]' '
        /Pages free/        {f=$2}
        /Pages inactive/    {i=$2}
        /Pages speculative/ {s=$2}
        /Pages purgeable/   {p=$2}
        END {print f+i+s+p}
    ')"
    : "${avail_pages:=0}"
    local mem_avail=$((avail_pages * page))
    mem_used=$((mem_total - mem_avail))
    [[ "$mem_used" -lt 0 ]] && mem_used=0
    if [[ "$mem_total" -gt 0 ]]; then
        mem_pct=$((mem_used * 100 / mem_total))
    else
        mem_pct=0
    fi

    emit "{\"disk\":{\"total_bytes\":$total,\"used_bytes\":$used,\"free_bytes\":$avail,\"used_percent\":$pct},\"memory\":{\"total_bytes\":$mem_total,\"used_bytes\":$mem_used,\"used_percent\":$mem_pct}}"
}

cmd_version() {
    local mole_ver="unknown"
    [[ -f "$MOLE_DIR/mo" ]] && mole_ver="$(git -C "$MOLE_DIR" describe --tags 2>/dev/null || echo unknown)"
    emit "{\"macbroom\":$(json_string "$MACBROOM_VERSION"),\"mole\":$(json_string "$mole_ver")}"
}

# --------------------------------------------------------------------------
# Dispatch
# --------------------------------------------------------------------------
main() {
    local sub="${1:-}"
    [[ $# -gt 0 ]] && shift
    case "$sub" in
        discover)  cmd_discover "$@" ;;
        scan)      cmd_scan "$@" ;;
        clean)     cmd_clean "$@" ;;
        auto-clean) cmd_auto_clean "$@" ;;
        ai-scan)   cmd_scan --categories=ai "$@" ;;
        ai-clean)  cmd_clean --categories=ai "$@" ;;
        apps)      cmd_apps "$@" ;;
        app-scan)  cmd_app_scan "$@" ;;
        app-clean) cmd_app_clean "$@" ;;
        status)    cmd_status "$@" ;;
        version)   cmd_version "$@" ;;
        ""|-h|--help)
            emit '{"usage":"macbroom-engine.sh {discover|scan|clean|ai-scan|ai-clean|apps|app-scan|app-clean|status|version}"}' ;;
        *) die "unknown subcommand: $sub" 64 ;;
    esac
}

main "$@"
