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
