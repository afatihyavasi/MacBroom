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
json_string() {
    local s="$1"
    s="${s//\\/\\\\}"   # backslash
    s="${s//\"/\\\"}"   # double quote
    s="${s//$'\n'/\\n}" # newline
    s="${s//$'\r'/\\r}" # carriage return
    s="${s//$'\t'/\\t}" # tab
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

# --------------------------------------------------------------------------
# Deletion sink. Isolated so the Trash-vs-permanent policy lives in one place.
# Default: permanent removal of the (already protection-checked, regenerable)
# path, matching `mo clean`. Returns 0 on success.
# --------------------------------------------------------------------------
_mb_remove() {
    rm -rf -- "$1" 2>/dev/null
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

# Membership test for the approved-path allowlist (bash 3.2 friendly).
_mb_is_approved() {
    [[ -n "$MB_PATHS_FILE" ]] || return 1
    grep -Fxq -- "$1" "$MB_PATHS_FILE"
}

# Handle one protection-cleared path according to the current mode.
_mb_handle() {
    local path="$1" label="$2"

    if [[ "$MB_MODE" == "scan" ]]; then
        local size; size="$(path_size_bytes "$path")"
        MB_CANDIDATES+=("{\"category\":$(json_string "$MB_CATEGORY"),\"label\":$(json_string "$label"),\"path\":$(json_string "$path"),\"size_bytes\":$size}")
        MB_COUNT=$((MB_COUNT + 1))
        return 0
    fi

    # clean mode: only delete paths the user explicitly approved.
    _mb_is_approved "$path" || return 0
    local size; size="$(path_size_bytes "$path")"
    if _mb_remove "$path"; then
        MB_FREED_BYTES=$((MB_FREED_BYTES + size))
        MB_COUNT=$((MB_COUNT + 1))
        emit "{\"event\":\"progress\",\"path\":$(json_string "$path"),\"freed_bytes\":$size}"
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
}

# --------------------------------------------------------------------------
# Category -> mole function mapping. Each function is guarded so version drift
# in the pinned submodule never crashes the engine.
# --------------------------------------------------------------------------
_run_fns() {
    local fn
    for fn in "$@"; do
        declare -F "$fn" >/dev/null 2>&1 && "$fn"
    done
}

# Safe, regenerable AI tool artifacts only. State (auth/sessions/memory/history)
# is preserved by mole's own functions (e.g. clean_codex_cli skips by default).
run_category_ai() {
    MB_CATEGORY="ai"
    _run_fns \
        clean_dev_ai_agents \
        clean_codex_runtimes \
        clean_codex_cli \
        clean_antigravity_caches \
        clean_chrome_devtools_mcp_caches \
        clean_ai_apps
}

run_category_system() {
    MB_CATEGORY="system"
    _run_fns \
        clean_app_caches \
        clean_code_editors \
        clean_user_gui_applications \
        clean_dev_misc
}

run_category() {
    case "$1" in
        ai)     run_category_ai ;;
        system) run_category_system ;;
        *)      ;; # unknown category ignored
    esac
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
cmd_scan() {
    local categories="ai,system"
    local arg
    for arg in "$@"; do
        case "$arg" in
            --categories=*) categories="${arg#*=}" ;;
        esac
    done

    MB_MODE="scan"
    load_mole

    local cat
    {
        IFS=',' read -ra _cats <<< "$categories"
        for cat in "${_cats[@]}"; do
            run_category "$cat"
        done
    } >/dev/null 2>&1

    emit_scan_result
}

cmd_clean() {
    local paths_file="" categories="ai,system"
    local arg
    for arg in "$@"; do
        case "$arg" in
            --paths-file=*) paths_file="${arg#*=}" ;;
            --categories=*) categories="${arg#*=}" ;;
        esac
    done
    [[ -n "$paths_file" && -f "$paths_file" ]] || die "clean requires --paths-file=FILE" 4

    MB_PATHS_FILE="$paths_file"
    MB_MODE="clean"
    load_mole

    local cat
    {
        IFS=',' read -ra _cats <<< "$categories"
        for cat in "${_cats[@]}"; do
            run_category "$cat"
        done
    } >/dev/null 2>&1

    emit "{\"event\":\"done\",\"freed_bytes\":$MB_FREED_BYTES,\"count\":$MB_COUNT}"
}

cmd_status() {
    # Disk snapshot for the volume backing $HOME, via df (POSIX, 512-byte blocks).
    local total used avail pct
    read -r total used avail pct < <(
        df -k "$HOME" 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $2*1024, $3*1024, $4*1024, $5; exit}'
    )
    : "${total:=0}" "${used:=0}" "${avail:=0}" "${pct:=0}"
    emit "{\"disk\":{\"total_bytes\":$total,\"used_bytes\":$used,\"free_bytes\":$avail,\"used_percent\":$pct}}"
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
        scan)     cmd_scan "$@" ;;
        clean)    cmd_clean "$@" ;;
        ai-scan)  cmd_scan --categories=ai "$@" ;;
        ai-clean) cmd_clean --categories=ai "$@" ;;
        status)   cmd_status "$@" ;;
        version)  cmd_version "$@" ;;
        ""|-h|--help)
            emit '{"usage":"macbroom-engine.sh {scan|clean|ai-scan|ai-clean|status|version}"}' ;;
        *) die "unknown subcommand: $sub" 64 ;;
    esac
}

main "$@"
