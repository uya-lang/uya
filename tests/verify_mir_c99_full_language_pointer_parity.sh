#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for pointer address/deref load-store.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_pointer.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
pointer_case="$tmp_dir/pointer.uya"

cat >"$pointer_case" <<'UYA'
fn bump(ptr: &i32, delta: i32) i32 {
    const before: i32 = *ptr;
    *ptr = before + delta;
    return *ptr;
}

export fn main() i32 {
    var value: i32 = 10;
    var other: i32 = 2;
    var ptr: &i32 = &value;
    var alias: &i32 = ptr;
    const before: i32 = *alias;
    *ptr = before + 5;
    var out: &i32 = &other;
    *out = *ptr + before;
    const after: i32 = bump(out, 3);
    return value + other + after;
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$pointer_case" >/dev/null

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked partial in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_status "AST_UNARY_EXPR"
require_matrix_status "AST_TYPE_POINTER"
require_matrix_status "CORE_PLACE_KIND_LOCAL"

echo "OK: MIR-C99 full-language pointer parity matched C99 oracle"
