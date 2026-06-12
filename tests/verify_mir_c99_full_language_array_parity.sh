#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for array literals and index load/store.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_array.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
array_case="$tmp_dir/array.uya"

cat >"$array_case" <<'UYA'
export fn main() i32 {
    var values: [i32: 4] = [2, 3, 5, 7];
    values[1] = values[0] + values[2];
    var zeroed: [i32: 2] = [];
    zeroed[0] = values[3];
    return values[1] + zeroed[0] + zeroed[1];
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$array_case" >/dev/null

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked partial in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_status "AST_ARRAY_ACCESS"
require_matrix_status "AST_ARRAY_LITERAL"
require_matrix_status "CORE_PLACE_KIND_INDEX"

echo "OK: MIR-C99 full-language array parity matched C99 oracle"
