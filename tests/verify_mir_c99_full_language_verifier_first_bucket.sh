#!/usr/bin/env bash
#
# Real fixed-CLI gate proving the old first MIR-C99 PortableMIR verifier bucket
# no longer ends in a verifier failure.
#
# This gate must:
#   - run the exact fixed `../uya/bin/uya build --mir-c99 tests/test_function_reachability_codegen.uya`
#     acceptance path;
#   - require stable `[MIR-C99]` routing evidence;
#   - require the old verifier diagnostic to be gone;
#   - require the current fail-closed frontier instead.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXED_UYA="$REPO_ROOT/../uya/bin/uya"
TMP_DIR="$(mktemp -d /tmp/uya-mir-c99-verifier-first-bucket.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

CASE_FILE="tests/test_function_reachability_codegen.uya"
CASE_LOG="$TMP_DIR/test_function_reachability_codegen.log"
CASE_OUT="$TMP_DIR/test_function_reachability_codegen.c"

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
    UYA_ROOT="$REPO_ROOT/lib/" "$FIXED_UYA" build \
        --mir-c99 "$CASE_FILE" -o "$CASE_OUT"
) >"$CASE_LOG" 2>&1
status=$?
set -e

grep -Fq '[MIR-C99]' "$CASE_LOG" || {
    cat "$CASE_LOG" >&2
    fail "verifier bucket log is missing [MIR-C99] routing evidence"
}

if [[ "$status" -eq 0 ]]; then
    cat "$CASE_LOG" >&2
    fail "verifier bucket unexpectedly succeeded; update this gate to the new success contract first"
fi

for forbidden in \
    '错误: MIR-C99 extern lowering 失败' \
    '错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序' \
    '错误: MIR-C99 PortableMIR verifier 失败'; do
    if grep -Fq "$forbidden" "$CASE_LOG"; then
        cat "$CASE_LOG" >&2
        fail "verifier bucket log still contains unexpected generic failure: $forbidden"
    fi
done

grep -Fq '错误: MIR-C99 unit output 写出失败' "$CASE_LOG" || {
    cat "$CASE_LOG" >&2
    fail "verifier-first-bucket log did not converge to the current unit-output frontier"
}

if [[ -e "$CASE_OUT" && -s "$CASE_OUT" ]]; then
    cat "$CASE_LOG" >&2
    fail "verifier bucket reject left a non-empty MIR-C99 output: $CASE_OUT"
fi

echo "OK: MIR-C99 first verifier bucket no longer ends in a PortableMIR verifier failure"
