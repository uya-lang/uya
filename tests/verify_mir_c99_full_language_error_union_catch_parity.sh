#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for error-union success/error catch paths.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_error_union_catch.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
success_case="$tmp_dir/error_union_catch_success.uya"
error_case="$tmp_dir/error_union_catch_error.uya"

cat >"$success_case" <<'UYA'
use std.runtime.get_argc;

error FullLanguageCatch;

fn maybe_argc(value: i32) !i32 {
    if value == 3 {
        return error.FullLanguageCatch;
    }
    return 17;
}

export fn main() i32 {
    const argc: i32 = get_argc();
    const value: i32 = maybe_argc(argc) catch { 23; };
    return value;
}
UYA

cat >"$error_case" <<'UYA'
use std.runtime.get_argc;

error FullLanguageCatch;

fn maybe_argc(value: i32) !i32 {
    if value == 1 {
        return error.FullLanguageCatch;
    }
    return 17;
}

export fn main() i32 {
    const argc: i32 = get_argc();
    const value: i32 = maybe_argc(argc) catch { 23; };
    return value;
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

run_case "$success_case"
run_case "$error_case"

require_matrix_status "AST_ERROR_DECL"
require_matrix_status "AST_CATCH_EXPR"
require_matrix_status "AST_ERROR_VALUE"
require_matrix_status "AST_TYPE_ERROR_UNION"
require_matrix_note "AST_ERROR_DECL" "error union catch parity shard"
require_matrix_note "AST_CATCH_EXPR" "error union catch parity shard"
require_matrix_note "AST_ERROR_VALUE" "error union catch parity shard"
require_matrix_note "AST_TYPE_ERROR_UNION" "error union catch parity shard"

echo "OK: MIR-C99 full-language error-union catch parity matched C99 oracle"
