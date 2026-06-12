#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for generic function instances.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_generic_fn.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
generic_case="$tmp_dir/generic_function.uya"

cat >"$generic_case" <<'UYA'
fn pick<T>(left: T, right: T, choose_left: bool) T {
    if choose_left {
        return left;
    }
    return right;
}

export fn main() i32 {
    const selected_i32: i32 = pick<i32>(14, 99, true);
    const selected_f64: f64 = pick<f64>(2.0, 5.0, false);
    return selected_i32 + (selected_f64 as i32);
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

require_matrix_status "AST_CALL_EXPR"
require_matrix_status "CORE_EXPR_KIND_CALL"
require_matrix_note "AST_CALL_EXPR" "generic function parity shard"
require_matrix_note "CORE_EXPR_KIND_CALL" "generic function parity shard"

echo "OK: MIR-C99 full-language generic function parity matched C99 oracle"
