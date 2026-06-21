#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
DRIVER_ARGS=("$@")
CC_BIN="${CC:-cc}"
OUT_C="$(mktemp /tmp/async_nested_future_boundary.XXXXXX.c)"
OUT_O="${OUT_C%.c}.o"
UYA_LOG="${OUT_C%.c}.uya.log"
CC_LOG="${OUT_C%.c}.cc.log"

cleanup() {
    rm -f "$OUT_C" "$OUT_O" "$UYA_LOG" "$CC_LOG"
}
trap cleanup EXIT

if [ ! -x "$COMPILER" ]; then
    echo "missing compiler: $COMPILER"
    echo "hint: run 'make uya' first"
    exit 1
fi

if ! "$COMPILER" test "${DRIVER_ARGS[@]}" --c99 "$REPO_ROOT/tests/test_async_nested.uya" >"$UYA_LOG" 2>&1; then
    echo "expected supported nested future regression to pass"
    cat "$UYA_LOG"
    exit 1
fi

if ! "$COMPILER" "${DRIVER_ARGS[@]}" --c99 "$REPO_ROOT/tests/test_async_nested_future_poll.uya" -o "$OUT_C" >"$UYA_LOG" 2>&1; then
    echo "expected C emission success for nested future boundary source"
    cat "$UYA_LOG"
    exit 1
fi

if ! grep -Fq "err_union_uya_interface_Future_i32" "$OUT_C"; then
    echo "missing expected nested future error-union payload marker in generated C"
    cat "$OUT_C"
    exit 1
fi

if ! "$CC_BIN" -std=c99 -O0 -c "$OUT_C" -o "$OUT_O" >"$CC_LOG" 2>&1; then
    echo "expected host C compile success for tests/test_async_nested_future_poll.uya"
    cat "$CC_LOG"
    exit 1
fi

echo "verify_async_nested_future_boundary: nested poll subset passes and !Future<Future<T>> C emission compiles"
