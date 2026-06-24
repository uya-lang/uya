#!/usr/bin/env bash
#
# Focused real-CLI gate for the current first generic MIR-C99 PortableMIR-lowering bucket.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"

if [[ ! -x "$COMPILER" ]]; then
    echo "error: fixed MIR-C99 compiler is missing or not executable: $COMPILER" >&2
    exit 69
fi

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-simd-select-first-bucket.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

log_file="$tmp_dir/test_simd_c99_select_emit_u32x2_and_u32x4.log"
output_file="$tmp_dir/test_simd_c99_select_emit_u32x2_and_u32x4.c"

set +e
(
    cd "$REPO_ROOT"
    UYA_ROOT="$REPO_ROOT/lib/" "$COMPILER" build --mir-c99 \
        tests/test_simd_c99_select_emit_u32x2_and_u32x4.uya -o "$output_file"
) >"$log_file" 2>&1
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
    echo "error: expected tests/test_simd_c99_select_emit_u32x2_and_u32x4.uya to fail closed under real --mir-c99" >&2
    exit 1
fi

grep -q '\[MIR-C99\]' "$log_file" || {
    cat "$log_file" >&2
    echo "error: missing [MIR-C99] routing evidence" >&2
    exit 1
}

if grep -Fq '错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序' "$log_file"; then
    cat "$log_file" >&2
    echo "error: SIMD select bucket still falls through to the generic PortableMIR lowering failure" >&2
    exit 1
fi

grep -Eq 'mir_c99_capability_diagnostic: kind=AST_TYPE_VECTOR reason=vector_type_requires_target_helper_capability file=(.*/)?tests/test_simd_c99_select_emit_u32x2_and_u32x4\.uya line=2' "$log_file" || {
    cat "$log_file" >&2
    echo "error: missing AST_TYPE_VECTOR SIMD helper capability diagnostic" >&2
    exit 1
}

if [[ -e "$output_file" && -s "$output_file" ]]; then
    cat "$log_file" >&2
    echo "error: reject left a non-empty MIR-C99 output: $output_file" >&2
    exit 1
fi

echo "OK: MIR-C99 real CLI SIMD select first bucket now fails closed with explicit capability diagnostics"
