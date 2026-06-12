#!/usr/bin/env bash
#
# Full-language MIR-C99 SIMD shard: vector/mask programs must remain an
# explicit capability reject until MIR-C99 has a real SIMD helper strategy.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"
HOST_CC="${HOST_CC:-cc}"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_simd_reject.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

case_file="$tmp_dir/simd_vector_mask.uya"
cat >"$case_file" <<'UYA'
type Vec4i32 = @vector(i32, 4);
type Mask4 = @mask(4);

export fn main() i32 {
    const lhs: Vec4i32 = @vector.splat(2);
    const rhs: Vec4i32 = @vector.splat(3);
    const product: Vec4i32 = lhs * rhs;
    const ok: Mask4 = product == @vector.splat(6);
    if @vector.all(ok) == false {
        return 1;
    }
    return 0;
}
UYA

oracle_c="$tmp_dir/oracle.c"
oracle_log="$tmp_dir/oracle.generate.log"
oracle_bin="$tmp_dir/oracle.out"
bash "$REPO_ROOT/tests/c99_oracle_generate.sh" "$case_file" "$oracle_c" "$oracle_log"
"$HOST_CC" -std=c99 -Wall -Wextra -pedantic "$oracle_c" -o "$oracle_bin" \
    >"$tmp_dir/oracle.cc.out" 2>"$tmp_dir/oracle.cc.err"

set +e
"$oracle_bin" >"$tmp_dir/oracle.stdout" 2>"$tmp_dir/oracle.stderr"
oracle_status=$?
set -e
if [[ "$oracle_status" -ne 0 ]]; then
    echo "error: C99 oracle SIMD vector/mask case exited with $oracle_status, expected 0" >&2
    cat "$tmp_dir/oracle.stdout" >&2
    cat "$tmp_dir/oracle.stderr" >&2
    exit 1
fi

mir_c="$tmp_dir/mir.c"
mir_log="$tmp_dir/mir.generate.log"
mir_out="$tmp_dir/mir.generate.out"
mir_err="$tmp_dir/mir.generate.err"
set +e
bash "$REPO_ROOT/tests/mir_c99_generate.sh" "$case_file" "$mir_c" "$mir_log" \
    >"$mir_out" 2>"$mir_err"
mir_status=$?
set -e

if [[ "$mir_status" -eq 0 ]]; then
    echo "error: MIR-C99 SIMD vector/mask case unexpectedly generated C before SIMD support" >&2
    exit 1
fi
if [[ -e "$mir_c" ]]; then
    echo "error: MIR-C99 SIMD vector/mask reject left an output C file" >&2
    exit 1
fi

for pattern in \
    'subset=simd_vector_mask_splat_mul_compare_all' \
    'status=rejected' \
    'reject_reason=vector_mask_capability' \
    'diagnostic_code=MIR_C99_VALUE_DIAG_UNSUPPORTED_VECTOR_MASK_CAPABILITY'; do
    if ! grep -q "$pattern" "$mir_log"; then
        echo "error: MIR-C99 SIMD vector/mask reject log missing pattern: $pattern" >&2
        cat "$mir_log" >&2
        cat "$mir_out" >&2
        cat "$mir_err" >&2
        exit 1
    fi
done

if grep -Eiq 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' \
    "$mir_log" "$mir_out" "$mir_err"; then
    echo "error: MIR-C99 SIMD vector/mask reject mentioned legacy C99 fallback" >&2
    cat "$mir_log" >&2
    cat "$mir_out" >&2
    cat "$mir_err" >&2
    exit 1
fi

for kind in AST_TYPE_VECTOR AST_TYPE_MASK CORE_EXPR_KIND_VECTOR CORE_EXPR_KIND_MASK; do
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| reject \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked reject in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
    if ! grep -E "\\| \`$kind\` \\|" "$MATRIX_DOC" | grep -Fq 'SIMD vector/mask reject shard'; then
        echo "error: $kind must record SIMD vector/mask reject shard evidence" >&2
        exit 1
    fi
done

echo "OK: MIR-C99 full-language SIMD vector/mask rejects explicitly before parity support"
