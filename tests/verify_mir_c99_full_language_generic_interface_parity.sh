#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for generic interface instances.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_generic_interface.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
generic_interface_case="$tmp_dir/generic_interface.uya"

cat >"$generic_interface_case" <<'UYA'
interface Scorer<T> {
    fn score(self: &Self, value: T) i32;
}

struct IntScorer : Scorer<i32> {
    base: i32,
}

IntScorer {
    fn score(self: &Self, value: i32) i32 {
        return self.base + value;
    }
}

struct FloatScorer : Scorer<f64> {
    base: i32,
}

FloatScorer {
    fn score(self: &Self, value: f64) i32 {
        return self.base + (value as i32);
    }
}

fn use_int(scorer: Scorer<i32>, value: i32) i32 {
    return scorer.score(value);
}

fn use_float(scorer: Scorer<f64>, value: f64) i32 {
    return scorer.score(value);
}

export fn main() i32 {
    const int_scorer: IntScorer = IntScorer{ base: 40 };
    const float_scorer: FloatScorer = FloatScorer{ base: 5 };
    return use_int(int_scorer, 2) + use_float(float_scorer, 9.0);
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$generic_interface_case" >/dev/null

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

require_matrix_status "AST_INTERFACE_DECL"
require_matrix_status "AST_STRUCT_DECL"
require_matrix_status "AST_METHOD_BLOCK"
require_matrix_status "AST_CALL_EXPR"
require_matrix_status "CORE_EXPR_KIND_CALL"
require_matrix_note "AST_INTERFACE_DECL" "generic interface parity shard"
require_matrix_note "AST_STRUCT_DECL" "generic interface parity shard"
require_matrix_note "AST_METHOD_BLOCK" "generic interface parity shard"
require_matrix_note "AST_CALL_EXPR" "generic interface parity shard"
require_matrix_note "CORE_EXPR_KIND_CALL" "generic interface parity shard"

echo "OK: MIR-C99 full-language generic interface parity matched C99 oracle"
