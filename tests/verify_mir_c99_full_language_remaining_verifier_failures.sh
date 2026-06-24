#!/usr/bin/env bash
#
# Real fixed-CLI gate for eliminating the last three MIR-C99 PortableMIR
# verifier failures.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXED_UYA="$REPO_ROOT/../uya/bin/uya"

fail() {
    echo "error: $*" >&2
    exit 1
}

if [[ ! -x "$FIXED_UYA" ]]; then
    fail "missing fixed compiler path: $FIXED_UYA"
fi

run_case() {
    local case_file="$1"
    local log_file="$2"
    set +e
    (
        cd "$REPO_ROOT"
        UYA_TEST_STDOUT_LINEBUF=1 \
        UYA_COMPILER="$FIXED_UYA" \
        PARALLEL_JOBS=8 \
        CFLAGS='-std=c99 -O2 -fno-builtin -Werror' \
        LDFLAGS='' \
        ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass "$case_file"
    ) >"$log_file" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status"
}

TMP_DIR="$(mktemp -d /tmp/uya-mir-c99-remaining-verifier-failures.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOST_LOG="$TMP_DIR/test_function_reachability_codegen.log"
MICROAPP_LOG="$TMP_DIR/test_function_reachability_codegen_microapp.log"
SEMANTIC_LOG="$TMP_DIR/test_semantic_lookup_function_family.log"

host_status="$(run_case "tests/test_function_reachability_codegen.uya" "$HOST_LOG")"
microapp_status="$(run_case "tests/test_function_reachability_codegen_microapp.uya" "$MICROAPP_LOG")"
semantic_status="$(run_case "tests/test_semantic_lookup_function_family.uya" "$SEMANTIC_LOG")"

if [[ "$host_status" -eq 0 ]]; then
    fail "test_function_reachability_codegen unexpectedly succeeded; update this gate to the new success contract first"
fi
if grep -Fq '错误: MIR-C99 PortableMIR verifier 失败' "$HOST_LOG"; then
    cat "$HOST_LOG" >&2
    fail "test_function_reachability_codegen still fails in the verifier"
fi
grep -Fq '错误: MIR-C99 unit output 写出失败' "$HOST_LOG" || {
    cat "$HOST_LOG" >&2
    fail "test_function_reachability_codegen did not converge to the current unit-output frontier"
}

if [[ "$microapp_status" -eq 0 ]]; then
    fail "test_function_reachability_codegen_microapp unexpectedly succeeded; update this gate to the new success contract first"
fi
if grep -Fq '错误: MIR-C99 PortableMIR verifier 失败' "$MICROAPP_LOG"; then
    cat "$MICROAPP_LOG" >&2
    fail "test_function_reachability_codegen_microapp still fails in the verifier"
fi
grep -Fq 'mir_c99_capability_diagnostic: kind=AST_ASSIGN reason=assign_dest_requires_local_i32_binding' "$MICROAPP_LOG" || {
    cat "$MICROAPP_LOG" >&2
    fail "test_function_reachability_codegen_microapp did not converge to the expected AST_ASSIGN capability diagnostic"
}

if [[ "$semantic_status" -ne 0 ]]; then
    cat "$SEMANTIC_LOG" >&2
    fail "test_semantic_lookup_function_family should now pass"
fi

echo "OK: MIR-C99 remaining verifier-failure cases no longer end in PortableMIR verifier failures"
