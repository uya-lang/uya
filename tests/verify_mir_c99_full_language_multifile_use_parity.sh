#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for multi-file module item use.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

run_case() {
    local case_file="$1"
    local case_root
    case_root="$(dirname "$case_file")"
    MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
    C99_ORACLE_GENERATE_CMD="bash ./tests/c99_oracle_generate.sh {input} {output} {log} --project-root $case_root" \
    bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null
}

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked partial in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

tmp_dir="$REPO_ROOT/tests/build/mir_c99_multifile_use.$$"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/dep"
cat >"$tmp_dir/dep/dep.uya" <<'UYA'
export fn exported_sum(x: i32, y: i32) i32 {
    return x + y;
}
UYA
cat >"$tmp_dir/main.uya" <<'UYA'
use dep.exported_sum;

fn main() i32 {
    const sum: i32 = exported_sum(20, 22);
    if sum != 42 {
        return 1;
    }
    return 0;
}
UYA

run_case "$tmp_dir/main.uya"

require_matrix_status "AST_USE_STMT"
require_matrix_status "CORE_EXPR_KIND_CALL"

echo "OK: MIR-C99 full-language multi-file module item use parity matched C99 oracle"
