#!/usr/bin/env bash
#
# Phase 9B: hosted native stdlib_entry boundary for `return get_argc()`.
#
# This gate proves that the C99 oracle still reads the real Linux process argc,
# while hosted --native fails closed at the current CoreBody/PortableMIR
# preflight boundary. It must not silently fall back to C99 or produce a native
# executable until the hosted stdlib entry path is verifier-clean.

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
    :
else
    echo "error: stdlib_entry native build unexpectedly succeeded before verifier-clean entry support" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi
if [[ -e "$NATIVE_BIN" ]]; then
    echo "error: stdlib_entry native build produced output despite fail-closed boundary" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi

if grep -q '后端类型: C99' "$NATIVE_ERR"; then
    echo "error: stdlib_entry native build stderr mentions C99 fallback" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi
if ! grep -Eq 'native_hosted_coreir_preflight: status=-1 verifier_error=0 functions=[1-9][0-9]* core_bodies=[1-9][0-9]* pending_bodies=[1-9][0-9]*' "$NATIVE_ERR"; then
    echo "error: stdlib_entry native build lacks current CoreIR fail-closed preflight evidence" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi
if ! grep -Eq 'native_hosted_preflight: status=-1 verifier_error=[1-9][0-9]* mir_extern_functions=[1-9][0-9]* mir_body_functions=[1-9][0-9]* mir_types=[1-9][0-9]* extern_symbols=0 c_import_objects=0 hosted_link_objects=0' "$NATIVE_ERR"; then
    echo "error: stdlib_entry native build lacks current PortableMIR fail-closed preflight evidence" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi
if ! grep -q 'native_hosted_entry_frontier:' "$NATIVE_ERR"; then
    echo "error: stdlib_entry native build lacks entry frontier evidence" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi
if ! grep -q 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_preflight_failed' "$NATIVE_ERR"; then
    echo "error: stdlib_entry native build lacks explicit fail-closed reason" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi
if grep -q 'native_hosted_portable_mir_lowering_missing' "$NATIVE_ERR"; then
    echo "error: stdlib_entry native build regressed to lowering-missing boundary" >&2
    cat "$NATIVE_ERR" >&2
    exit 1
fi

run_case() {
    local label="$1"
    local expected="$2"
    shift 2
    local c99_out="$TMP_DIR/$label.c99.run.out"
    local c99_err="$TMP_DIR/$label.c99.run.err"
    set +e
    "$C99_BIN" "$@" >"$c99_out" 2>"$c99_err"
    local c99_status=$?
    set -e
    if [[ "$c99_status" -ne "$expected" ]]; then
        echo "error: $label C99 oracle exited with $c99_status (expected $expected)" >&2
        cat "$c99_out" >&2
        cat "$c99_err" >&2
        exit 1
    fi
}

run_case argc1 1
run_case argc3 3 alpha beta

echo "OK: hosted native stdlib_entry verified C99 argc oracle and native fail-closed boundary"
