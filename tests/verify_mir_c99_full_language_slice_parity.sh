#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for slice expressions and slice index loads.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_slice.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
slice_case="$tmp_dir/slice.uya"

cat >"$slice_case" <<'UYA'
export fn main() i32 {
    var values: [i32: 5] = [4, 6, 8, 10, 12];
    const window: &[i32] = values[1:3];
    const tail: &[i32] = window[1:2];
    return @len(window) as i32 + window[0] + window[2] + @len(tail) as i32 + tail[0] + tail[1];
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$slice_case" >/dev/null

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked partial in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_status "AST_ARRAY_ACCESS"
require_matrix_status "AST_SLICE_EXPR"
require_matrix_status "AST_TYPE_SLICE"
require_matrix_status "CORE_EXPR_KIND_SLICE"
require_matrix_status "CORE_PLACE_KIND_INDEX"
require_matrix_status "CORE_PLACE_KIND_SLICE"

echo "OK: MIR-C99 full-language slice parity matched C99 oracle"
