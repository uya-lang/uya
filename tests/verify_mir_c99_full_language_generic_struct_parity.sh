#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for generic struct instances.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_generic_struct.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
generic_case="$tmp_dir/generic_struct.uya"

cat >"$generic_case" <<'UYA'
struct Box<T> {
    value: T,
    tag: i32,
}

export fn main() i32 {
    const int_box: Box<i32> = Box<i32>{ value: 21, tag: 4 };
    const float_box: Box<f64> = Box<f64>{ value: 3.0, tag: 8 };
    return int_box.value + int_box.tag + (float_box.value as i32) + float_box.tag;
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$generic_case" >/dev/null

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked partial in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_note() {
    local kind="$1"
    local needle="$2"
    if ! grep -E "\\| \`$kind\` \\|" "$MATRIX_DOC" | grep -Fq "$needle"; then
        echo "error: $kind must record $needle in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_status "AST_STRUCT_DECL"
require_matrix_status "AST_STRUCT_INIT"
require_matrix_status "AST_MEMBER_ACCESS"
require_matrix_status "CORE_PLACE_KIND_FIELD"
require_matrix_note "AST_STRUCT_DECL" "generic struct parity shard"
require_matrix_note "AST_STRUCT_INIT" "generic struct parity shard"
require_matrix_note "AST_MEMBER_ACCESS" "generic struct parity shard"
require_matrix_note "CORE_PLACE_KIND_FIELD" "generic struct parity shard"

echo "OK: MIR-C99 full-language generic struct parity matched C99 oracle"
