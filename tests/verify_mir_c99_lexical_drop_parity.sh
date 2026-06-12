#!/usr/bin/env bash
#
# Lexical drop scope cleanup must match the existing C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-lexical-drop.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
scope_case="$tmp_dir/lexical_drop_scope.uya"
return_case="$tmp_dir/lexical_drop_return.uya"

cat >"$scope_case" <<'UYA'
var drop_count: i32 = 0;

struct SmokeDrop {
    value: i32,
    fn drop(self: SmokeDrop) void {
        drop_count = drop_count + self.value;
    }
}

export fn main() i32 {
    drop_count = 0;
    {
        const dropped: SmokeDrop = SmokeDrop{ value: 7 };
    }
    return drop_count;
}
UYA

cat >"$return_case" <<'UYA'
var drop_count: i32 = 0;

struct SmokeDrop {
    value: i32,
    fn drop(self: SmokeDrop) void {
        drop_count = drop_count + self.value;
    }
}

fn early_return() i32 {
    {
        const dropped: SmokeDrop = SmokeDrop{ value: 11 };
        return 5;
    }
}

export fn main() i32 {
    drop_count = 0;
    const returned: i32 = early_return();
    return returned + drop_count;
}
UYA

run_case() {
    local case_file="$1"
    MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
    C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
    bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null
}

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

run_case "$scope_case"
run_case "$return_case"

require_matrix_status "CORE_STMT_KIND_DROP"
require_matrix_note "CORE_STMT_KIND_DROP" "lexical drop scope / return cleanup parity shard"

echo "OK: MIR-C99 lexical drop parity matched C99 oracle"
