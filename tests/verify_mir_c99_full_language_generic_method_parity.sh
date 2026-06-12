#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for generic method instances.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_generic_method.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
generic_case="$tmp_dir/generic_method.uya"

cat >"$generic_case" <<'UYA'
struct Box<T> {
    value: T,
    tag: i32,

    fn make(value: T, tag: i32) Self {
        return Box<T>{ value: value, tag: tag };
    }

    fn get(self: &Self) T {
        return self.value;
    }

    fn tag_with<U>(self: &Self, extra: U) i32 {
        _ = extra;
        return self.tag + 1;
    }
}

export fn main() i32 {
    const int_box: Box<i32> = Box<i32>.make(11, 4);
    const float_box: Box<f64> = Box<f64>.make(3.0, 8);
    const direct: i32 = int_box.get();
    const via_type: i32 = Box<i32>.get(int_box);
    const generic_i32: i32 = int_box.tag_with<i32>(7);
    const generic_f64: i32 = float_box.tag_with<f64>(1.0);
    return direct + via_type + generic_i32 + (float_box.get() as i32) + generic_f64;
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
require_matrix_status "AST_METHOD_BLOCK"
require_matrix_status "AST_CALL_EXPR"
require_matrix_status "AST_MEMBER_ACCESS"
require_matrix_status "CORE_EXPR_KIND_CALL"
require_matrix_note "AST_STRUCT_DECL" "generic method parity shard"
require_matrix_note "AST_METHOD_BLOCK" "generic method parity shard"
require_matrix_note "AST_CALL_EXPR" "generic method parity shard"
require_matrix_note "AST_MEMBER_ACCESS" "generic method parity shard"
require_matrix_note "CORE_EXPR_KIND_CALL" "generic method parity shard"

echo "OK: MIR-C99 full-language generic method parity matched C99 oracle"
