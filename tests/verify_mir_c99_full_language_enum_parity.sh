#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for enum tags, explicit/auto values,
# comparisons, casts, and enum match arms.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_enum.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
enum_case="$tmp_dir/enum.uya"

cat >"$enum_case" <<'UYA'
enum Mode {
    Idle,
    Busy = 10,
    Done,
}

fn mode_score(mode: Mode) i32 {
    return match mode {
        Mode.Idle => 3,
        Mode.Busy => 5,
        Mode.Done => 7,
        else => 9,
    };
}

export fn main() i32 {
    const busy: Mode = Mode.Busy;
    const done: Mode = Mode.Done;
    var total: i32 = mode_score(busy) + mode_score(done);
    if busy < done {
        total = total + (busy as i32);
    } else {
        total = total + 100;
    }
    return total + (done as i32);
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$enum_case" >/dev/null

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked partial in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_status "AST_ENUM_DECL"
require_matrix_status "AST_MATCH_EXPR"
require_matrix_status "AST_CAST_EXPR"
require_matrix_status "AST_BINARY_EXPR"

echo "OK: MIR-C99 full-language enum parity matched C99 oracle"
