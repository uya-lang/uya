#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for union construction, tagged layout, and
# payload field access through match.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-union.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
union_case="$tmp_dir/union.uya"

cat >"$union_case" <<'UYA'
struct Payload {
    left: i32,
    right: i32,
}

union Value {
    number: i32,
    payload: Payload,
}

fn score(value: Value) i32 {
    return match value {
        .number(x) => x,
        .payload(p) => p.left + p.right,
    };
}

export fn main() i32 {
    const value: Value = Value.payload(Payload{ left: 11, right: 31 });
    const other: Value = Value.number(7);
    return score(value) + score(other);
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$union_case" >/dev/null

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked partial in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_status "AST_UNION_DECL"
require_matrix_status "AST_MATCH_EXPR"
require_matrix_status "AST_MEMBER_ACCESS"
require_matrix_status "CORE_PLACE_KIND_FIELD"

echo "OK: MIR-C99 full-language union parity matched C99 oracle"
