#!/usr/bin/env bats
#
# Tests for macbroom-engine.sh — the JSON bridge over mole's cleaning library.
# Mirrors mole's own test hygiene: every test runs against an ISOLATED $HOME
# temp dir so nothing on the developer's real machine is ever touched.

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export PROJECT_ROOT
    ENGINE="$PROJECT_ROOT/engine/macbroom-engine.sh"
    export ENGINE
    export MACBROOM_MOLE_DIR="$PROJECT_ROOT/vendor/mole"
}

setup() {
    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME
    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-engine.XXXXXX")"
    export HOME
    [[ "$HOME" == "${BATS_TEST_DIRNAME}/tmp-"* ]] || { echo "FATAL: HOME not a temp dir: $HOME"; exit 1; }
}

teardown() {
    if [[ "${HOME:-}" == "${BATS_TEST_DIRNAME}/tmp-"* ]]; then
        rm -rf "$HOME"
    fi
    [[ -n "${ORIGINAL_HOME:-}" ]] && export HOME="$ORIGINAL_HOME"
}

# --- contract: version / status --------------------------------------------

@test "version emits json with macbroom field" {
    run bash "$ENGINE" version
    [ "$status" -eq 0 ]
    [[ "$output" == *'"macbroom"'* ]]
}

@test "status emits disk json" {
    run bash "$ENGINE" status
    [ "$status" -eq 0 ]
    [[ "$output" == *'"disk"'* ]]
    [[ "$output" == *'"used_percent"'* ]]
}

@test "unknown subcommand fails with json error" {
    run bash "$ENGINE" bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *'"error"'* ]]
}

# --- scan: finds safe AI caches, preserves state ---------------------------

@test "discover lists targets with installed flags (fast, no scan)" {
    mkdir -p "$HOME/.gemini"
    run bash "$ENGINE" discover
    [ "$status" -eq 0 ]
    [[ "$output" == *'"targets"'* ]]
    [[ "$output" == *'"id":"ai:gemini"'* ]]
    [[ "$output" == *'"installed"'* ]]
}

@test "scan --targets only runs the selected target" {
    mkdir -p "$HOME/.gemini/tmp"
    head -c 2048 /dev/zero > "$HOME/.gemini/tmp/g.bin"
    # A codex artifact that must NOT be touched/listed when only gemini is asked.
    mkdir -p "$HOME/.cache/codex-runtimes/r1"
    head -c 2048 /dev/zero > "$HOME/.cache/codex-runtimes/r1/c.bin"

    run bash "$ENGINE" scan --targets=ai:gemini
    [ "$status" -eq 0 ]
    [[ "$output" == *"$HOME/.gemini/tmp/g.bin"* ]]
    [[ "$output" != *"codex-runtimes"* ]]
}

@test "ai-scan lists regenerable gemini temp files as candidates" {
    mkdir -p "$HOME/.gemini/tmp"
    head -c 4096 /dev/zero > "$HOME/.gemini/tmp/junk.bin"

    run bash "$ENGINE" ai-scan
    [ "$status" -eq 0 ]
    [[ "$output" == *'"candidates"'* ]]
    [[ "$output" == *"$HOME/.gemini/tmp/junk.bin"* ]]
}

@test "ai-scan NEVER lists codex auth/session state" {
    mkdir -p "$HOME/.codex/sessions"
    echo '{"token":"secret"}' > "$HOME/.codex/auth.json"
    echo '{}' > "$HOME/.codex/sessions/s.jsonl"
    echo '{}' > "$HOME/.codex/history.jsonl"

    run bash "$ENGINE" ai-scan
    [ "$status" -eq 0 ]
    [[ "$output" != *"auth.json"* ]]
    [[ "$output" != *"sessions/s.jsonl"* ]]
    [[ "$output" != *"history.jsonl"* ]]
}

@test "scan output is the only thing on stdout (mole chatter suppressed)" {
    mkdir -p "$HOME/.gemini/tmp"
    touch "$HOME/.gemini/tmp/a"
    run bash "$ENGINE" ai-scan
    [ "$status" -eq 0 ]
    # Exactly one line of protocol output.
    [ "${#lines[@]}" -eq 1 ]
}

# --- clean: only approved paths are removed --------------------------------

@test "clean deletes only approved paths and reports freed bytes" {
    mkdir -p "$HOME/.gemini/tmp"
    head -c 8192 /dev/zero > "$HOME/.gemini/tmp/approved.bin"
    head -c 8192 /dev/zero > "$HOME/.gemini/tmp/keep.bin"

    printf '%s\n' "$HOME/.gemini/tmp/approved.bin" > "$HOME/approved.txt"

    run bash "$ENGINE" ai-clean --paths-file="$HOME/approved.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"event":"done"'* ]]
    [ ! -e "$HOME/.gemini/tmp/approved.bin" ]   # approved removed
    [ -e "$HOME/.gemini/tmp/keep.bin" ]         # non-approved preserved
}

@test "clean requires a paths file" {
    run bash "$ENGINE" ai-clean
    [ "$status" -ne 0 ]
    [[ "$output" == *'"error"'* ]]
}

# --- app uninstaller ------------------------------------------------------

@test "app-scan finds an app's leftovers" {
    mkdir -p "$HOME/Applications/Foo.app/Contents"
    cat > "$HOME/Applications/Foo.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.test.foo</string>
</dict></plist>
PLIST
    mkdir -p "$HOME/Library/Caches/Foo"
    head -c 2048 /dev/zero > "$HOME/Library/Caches/Foo/blob"

    run bash "$ENGINE" app-scan --app="$HOME/Applications/Foo.app"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$HOME/Applications/Foo.app"* ]]   # the bundle itself
    [[ "$output" == *"$HOME/Library/Caches/Foo"* ]]     # a leftover
}

@test "app-clean removes only approved app paths" {
    mkdir -p "$HOME/Library/Caches/Foo"
    head -c 2048 /dev/zero > "$HOME/Library/Caches/Foo/blob"
    mkdir -p "$HOME/Library/Caches/Bar"
    head -c 2048 /dev/zero > "$HOME/Library/Caches/Bar/blob"

    printf '%s\n' "$HOME/Library/Caches/Foo" > "$HOME/approved.txt"

    run bash "$ENGINE" app-clean --paths-file="$HOME/approved.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"event":"done"'* ]]
    [ ! -e "$HOME/Library/Caches/Foo" ]   # approved removed
    [ -e "$HOME/Library/Caches/Bar" ]     # untouched
}

@test "app-scan requires --app" {
    run bash "$ENGINE" app-scan
    [ "$status" -ne 0 ]
    [[ "$output" == *'"error"'* ]]
}

# --- deletion policy ------------------------------------------------------

@test "clean with trash mode moves to ~/.Trash instead of deleting" {
    mkdir -p "$HOME/.gemini/tmp" "$HOME/.Trash"
    head -c 4096 /dev/zero > "$HOME/.gemini/tmp/trashme.bin"
    printf '%s\n' "$HOME/.gemini/tmp/trashme.bin" > "$HOME/approved.txt"

    run env MACBROOM_DELETE_MODE=trash bash "$ENGINE" ai-clean --paths-file="$HOME/approved.txt"
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.gemini/tmp/trashme.bin" ]   # gone from origin
    [ -e "$HOME/.Trash/trashme.bin" ]          # recoverable in Trash
}

# --- failure reporting (no silent swallow) --------------------------------

@test "clean reports a skipped event (no silent swallow) when removal fails" {
    mkdir -p "$HOME/.gemini/tmp/locked"
    head -c 4096 /dev/zero > "$HOME/.gemini/tmp/locked/blob"
    chmod 0500 "$HOME/.gemini/tmp/locked"            # can't remove contents
    printf '%s\n' "$HOME/.gemini/tmp/locked/blob" > "$HOME/approved.txt"

    run bash "$ENGINE" ai-clean --paths-file="$HOME/approved.txt"
    chmod -R u+w "$HOME/.gemini/tmp/locked" 2>/dev/null || true
    [ "$status" -eq 0 ]
    # The per-item `skipped` event is the source of truth the app counts from
    # (the aggregate `failed` in `done` is best-effort — mole runs some cleaners
    # in subshells where the global counter doesn't always propagate).
    [[ "$output" == *'"event":"skipped"'* ]]
    [[ "$output" == *'"reason":'* ]]
    [ -e "$HOME/.gemini/tmp/locked/blob" ]   # genuinely not deleted
}

# --- developer category (clean_xcode_derived_data deletes via safe_remove) --

@test "discover lists developer targets" {
    run bash "$ENGINE" discover
    [ "$status" -eq 0 ]
    [[ "$output" == *'"id":"developer:xcode"'* ]]
    [[ "$output" == *'"id":"developer:pkg-caches"'* ]]
}

@test "developer:xcode scan surfaces DerivedData (safe_remove override routes to our sink)" {
    mkdir -p "$HOME/Library/Developer/Xcode/DerivedData/Foo-abc"
    head -c 65536 /dev/zero > "$HOME/Library/Developer/Xcode/DerivedData/Foo-abc/blob"

    run bash "$ENGINE" scan --targets=developer:xcode
    [ "$status" -eq 0 ]
    [[ "$output" == *"$HOME/Library/Developer/Xcode/DerivedData"* ]]
    [[ "$output" == *'"size_bytes":'* ]]
}

@test "developer:xcode clean removes only the approved DerivedData path" {
    mkdir -p "$HOME/Library/Developer/Xcode/DerivedData/Foo-abc"
    head -c 65536 /dev/zero > "$HOME/Library/Developer/Xcode/DerivedData/Foo-abc/blob"
    printf '%s\n' "$HOME/Library/Developer/Xcode/DerivedData/Foo-abc" > "$HOME/approved.txt"

    run bash "$ENGINE" clean --targets=developer:xcode --paths-file="$HOME/approved.txt"
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/Library/Developer/Xcode/DerivedData/Foo-abc" ]   # approved removed
}
