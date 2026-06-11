#!/usr/bin/env bash
#
# Phase 9B: hosted native stdlib_entry parity for `return get_argc()`.
#
# This gate proves that hosted --native no longer rejects the basic stdlib
# entry case with native_hosted_portable_mir_lowering_missing. The executable
# must read the real Linux process argc from the entry stack and match the C99
# oracle for both argc=1 and argc=3.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-hosted-native-stdlib-entry.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "SKIP: hosted native stdlib entry parity currently requires x86_64 host" >&2
    exit 0
fi

UYA_BIN="$REPO_ROOT/bin/uya"
if [[ ! -x "$UYA_BIN" ]]; then
    echo "error: missing or non-executable bin/uya; run \`make uya\` first" >&2
    exit 1
fi

SRC="$TMP_DIR/stdlib_entry.uya"
cat >"$SRC" <<'EOF'
use std.runtime;

export fn main() i32 {
    return get_argc();
}
EOF

C99_BIN="$TMP_DIR/stdlib_entry.c99"
C99_ERR="$TMP_DIR/stdlib_entry.c99.err"
(cd "$REPO_ROOT" && "$UYA_BIN" build "$SRC" -o "$C99_BIN" \
    --no-split-c --project-root "$TMP_DIR" \
    >"$TMP_DIR/stdlib_entry.c99.out" 2>"$C99_ERR")
chmod +x "$C99_BIN"

NATIVE_BIN="$TMP_DIR/stdlib_entry.native"
NATIVE_OUT="$TMP_DIR/stdlib_entry.native.build.out"
NATIVE_ERR="$TMP_DIR/stdlib_entry.native.build.err"
set +e
(cd "$REPO_ROOT" && "$UYA_BIN" build "$SRC" -o "$NATIVE_BIN" \
    --native --no-split-c --project-root "$TMP_DIR" \
    >"$NATIVE_OUT" 2>"$NATIVE_ERR")
NATIVE_BUILD_STATUS=$?
set -e
if [[ "$NATIVE_BUILD_STATUS" -ne 0 ]]; then
    echo "error: stdlib_entry native build must succeed" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi
if [[ ! -s "$NATIVE_BIN" ]]; then
    echo "error: stdlib_entry native build reported success without output" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi
chmod +x "$NATIVE_BIN"

if grep -q 'native_hosted_portable_mir_lowering_missing' "$NATIVE_ERR"; then
    echo "error: stdlib_entry native parity still reports MIR lowering missing" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi
if grep -q '后端类型: C99' "$NATIVE_ERR"; then
    echo "error: stdlib_entry native build stderr mentions C99 fallback" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: stdlib_get_argc_path=1' "$NATIVE_ERR"; then
    echo "error: stdlib_entry native build did not report get_argc writer path" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi
if ! grep -q 'native_exit_code: argc' "$NATIVE_ERR"; then
    echo "error: stdlib_entry native build lacks argc exit-code evidence" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi
if ! grep -q 'native_hosted_coreir_preflight: status=0' "$NATIVE_ERR"; then
    echo "error: stdlib_entry native build lacks CoreIR preflight evidence" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi
if ! grep -q 'native_hosted_preflight: status=0' "$NATIVE_ERR"; then
    echo "error: stdlib_entry native build lacks PortableMIR preflight evidence" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi

run_case() {
    local label="$1"
    local expected="$2"
    shift 2
    local c99_out="$TMP_DIR/$label.c99.run.out"
    local c99_err="$TMP_DIR/$label.c99.run.err"
    local native_run_out="$TMP_DIR/$label.native.run.out"
    local native_run_err="$TMP_DIR/$label.native.run.err"
    set +e
    "$C99_BIN" "$@" >"$c99_out" 2>"$c99_err"
    local c99_status=$?
    "$NATIVE_BIN" "$@" >"$native_run_out" 2>"$native_run_err"
    local native_status=$?
    set -e
    if [[ "$c99_status" -ne "$expected" ]]; then
        echo "error: $label C99 oracle exited with $c99_status (expected $expected)" >&2
        cat "$c99_out" >&2
        cat "$c99_err" >&2
        exit 1
    fi
    if [[ "$native_status" -ne "$expected" ]]; then
        echo "error: $label native executable exited with $native_status (expected $expected)" >&2
        cat "$native_run_out" >&2
        cat "$native_run_err" >&2
        exit 1
    fi
    if ! cmp -s "$c99_out" "$native_run_out"; then
        echo "error: $label native/C99 stdout differ" >&2
        diff "$c99_out" "$native_run_out" >&2 || true
        exit 1
    fi
}

run_case argc1 1
run_case argc3 3 alpha beta

echo "OK: hosted native stdlib_entry get_argc parity verified"
