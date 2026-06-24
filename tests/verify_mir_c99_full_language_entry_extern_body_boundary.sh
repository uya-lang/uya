#!/usr/bin/env bash
#
# Focused real-CLI gate for std.runtime.entry export extern main.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXED_UYA="$REPO_ROOT/../uya/bin/uya"
TMP_DIR="$(mktemp -d /tmp/uya-mir-c99-entry-extern-body.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

CASE_FILE="tests/test_simple_fn.uya"
CASE_LOG="$TMP_DIR/test_simple_fn.log"
CASE_OUT="$TMP_DIR/test_simple_fn.c"

fail() {
    echo "error: $*" >&2
    exit 1
}

if [[ ! -x "$FIXED_UYA" ]]; then
    fail "missing fixed compiler path: $FIXED_UYA"
fi

set +e
(
    cd "$REPO_ROOT"
    UYA_ROOT="$REPO_ROOT/lib/" "$FIXED_UYA" build --mir-c99 "$CASE_FILE" -o "$CASE_OUT"
) >"$CASE_LOG" 2>&1
status=$?
set -e

grep -Fq '[MIR-C99]' "$CASE_LOG" || {
    cat "$CASE_LOG" >&2
    fail "entry extern body log is missing [MIR-C99] routing evidence"
}

if [[ "$status" -eq 0 ]]; then
    cat "$CASE_LOG" >&2
    fail "entry extern body unexpectedly succeeded; update this gate to the new success contract first"
fi

for forbidden in \
    'extern_signature_requires_i32_scalars' \
    '错误: MIR-C99 extern lowering 失败' \
    '错误: MIR-C99 PortableMIR verifier 失败'; do
    if grep -Fq "$forbidden" "$CASE_LOG"; then
        cat "$CASE_LOG" >&2
        fail "entry extern body log still contains unexpected frontier: $forbidden"
    fi
done

grep -Eq 'mir_c99_capability_diagnostic: kind=AST_FN_DECL reason=entry_extern_main_requires_runtime_bridge file=.*/lib/std/runtime/entry/entry\.uya line=79' "$CASE_LOG" || {
    cat "$CASE_LOG" >&2
    fail "entry extern body log did not converge to the dedicated runtime-bridge capability diagnostic"
}

if [[ -e "$CASE_OUT" && -s "$CASE_OUT" ]]; then
    cat "$CASE_LOG" >&2
    fail "entry extern body reject left a non-empty MIR-C99 output: $CASE_OUT"
fi

echo "OK: MIR-C99 entry extern main now fails closed at the dedicated runtime-bridge boundary"
