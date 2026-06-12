#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for try expression error propagation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_try_propagation.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
success_case="$tmp_dir/try_propagation_success.uya"
error_case="$tmp_dir/try_propagation_error.uya"

cat >"$success_case" <<'UYA'
use std.runtime.get_argc;

error FullLanguageTry;

fn maybe_argc(value: i32) !i32 {
    if value == 3 {
        return error.FullLanguageTry;
    }
    return 11;
}

fn wrap_argc(value: i32) !i32 {
    const inner: i32 = try maybe_argc(value);
    return inner + 4;
}

export fn main() i32 {
    const argc: i32 = get_argc();
    const result: i32 = wrap_argc(argc) catch { 29; };
    return result;
}
UYA

cat >"$error_case" <<'UYA'
use std.runtime.get_argc;

error FullLanguageTry;

fn maybe_argc(value: i32) !i32 {
    if value == 1 {
        return error.FullLanguageTry;
    }
    return 11;
}

fn wrap_argc(value: i32) !i32 {
    const inner: i32 = try maybe_argc(value);
    return inner + 4;
}

export fn main() i32 {
    const argc: i32 = get_argc();
    const result: i32 = wrap_argc(argc) catch { 29; };
    return result;
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

require_matrix_status "AST_TRY_EXPR"
require_matrix_status "AST_TYPE_ERROR_UNION"
require_matrix_status "CORE_STMT_KIND_ERROR_PROPAGATION"
require_matrix_note "AST_TRY_EXPR" "try propagation parity shard"
require_matrix_note "AST_TYPE_ERROR_UNION" "try propagation parity shard"
require_matrix_note "CORE_STMT_KIND_ERROR_PROPAGATION" "try propagation parity shard"

echo "OK: MIR-C99 full-language try propagation parity matched C99 oracle"
