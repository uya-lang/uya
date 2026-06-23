#!/usr/bin/env bash
#
# Focused real-CLI gate for nested capability diagnostics inside top-level test blocks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"

if [[ ! -x "$COMPILER" ]]; then
    echo "error: fixed MIR-C99 compiler is missing or not executable: $COMPILER" >&2
    exit 69
fi

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-test-stmt-capability.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

case_file="$tmp_dir/test_stmt_inline_asm.uya"
output_file="$tmp_dir/test_stmt_inline_asm.mir.c"
log_file="$tmp_dir/test_stmt_inline_asm.mir.log"

cat >"$case_file" <<'UYA'
test "asm is target sensitive" {
    @asm {
        "nop" ();
    }
}
UYA

set +e
(
    cd "$REPO_ROOT"
    UYA_ROOT="$REPO_ROOT/lib/" "$COMPILER" build --mir-c99 "$case_file" -o "$output_file"
) >"$log_file" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
    echo "error: expected top-level test inline asm case to fail closed under real --mir-c99" >&2
    exit 1
fi

grep -q '\[MIR-C99\]' "$log_file" || {
    cat "$log_file" >&2
    echo "error: missing [MIR-C99] routing evidence" >&2
    exit 1
}

grep -q 'mir_c99_capability_diagnostic: kind=AST_ASM reason=inline_asm_requires_target_capability' "$log_file" || {
    cat "$log_file" >&2
    echo "error: nested top-level test capability did not surface AST_ASM reject reason" >&2
    exit 1
}

if [[ -e "$output_file" && -s "$output_file" ]]; then
    cat "$log_file" >&2
    echo "error: reject left a non-empty MIR-C99 output: $output_file" >&2
    exit 1
fi

echo "OK: MIR-C99 top-level test capability diagnostics now descend into nested unsupported nodes"
