#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for tuple literals and numeric member
# access.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_tuple.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
tuple_case="$tmp_dir/tuple.uya"

cat >"$tuple_case" <<'UYA'
export fn main() i32 {
    const pair: (i32, i32) = (10, 20);
    const first: i32 = pair.0;
    const second: i32 = pair.1;
    const shifted: (i32, i32) = (first + 3, second + 4);
    return shifted.0 + shifted.1;
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$tuple_case" >/dev/null

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked partial in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_status "AST_TUPLE_LITERAL"
require_matrix_status "AST_MEMBER_ACCESS"
require_matrix_status "CORE_PLACE_KIND_FIELD"

echo "OK: MIR-C99 full-language tuple parity matched C99 oracle"
