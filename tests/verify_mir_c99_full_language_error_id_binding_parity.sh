#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for catch error binding and error metadata.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_error_id_binding.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
success_case="$tmp_dir/error_id_binding_success.uya"
error_case="$tmp_dir/error_id_binding_error.uya"

cat >"$success_case" <<'UYA'
use libc.strcmp;
use std.runtime.get_argc;

error FullLanguageBinding;

fn maybe_argc(value: i32) !i32 {
    if value == 3 {
        return error.FullLanguageBinding;
    }
    return 19;
}

export fn main() i32 {
    const argc: i32 = get_argc();
    const value: i32 = maybe_argc(argc) catch |err| {
        const caught_id: u32 = @error_id(err);
        const expected_id: u32 = @error_id(error.FullLanguageBinding);
        if caught_id != expected_id {
            return 41;
        }
        if strcmp(@error_name(err) as *const byte, "FullLanguageBinding\0" as *const byte) != 0 {
            return 43;
        }
        37;
    };
    return value;
}
UYA

cat >"$error_case" <<'UYA'
use libc.strcmp;
use std.runtime.get_argc;

error FullLanguageBinding;

fn maybe_argc(value: i32) !i32 {
    if value == 1 {
        return error.FullLanguageBinding;
    }
    return 19;
}

export fn main() i32 {
    const argc: i32 = get_argc();
    const value: i32 = maybe_argc(argc) catch |err| {
        const caught_id: u32 = @error_id(err);
        const expected_id: u32 = @error_id(error.FullLanguageBinding);
        if caught_id != expected_id {
            return 41;
        }
        if strcmp(@error_name(err) as *const byte, "FullLanguageBinding\0" as *const byte) != 0 {
            return 43;
        }
        37;
    };
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

require_builtin_status() {
    local name="$1"
    if ! grep -Eq "\\| \`$name\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $name must be marked partial in the MIR-C99 builtin coverage matrix" >&2
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

require_matrix_status "AST_CATCH_EXPR"
require_matrix_status "AST_ERROR_VALUE"
require_matrix_status "AST_ERROR_ID"
require_matrix_status "AST_ERROR_NAME"
require_matrix_status "AST_TYPE_ERROR_UNION"
require_builtin_status "@error_id"
require_builtin_status "@error_name"
require_matrix_note "AST_CATCH_EXPR" "error-id binding parity shard"
require_matrix_note "AST_ERROR_VALUE" "error-id binding parity shard"
require_matrix_note "AST_ERROR_ID" "error-id binding parity shard"
require_matrix_note "AST_ERROR_NAME" "error-id binding parity shard"
require_matrix_note "AST_TYPE_ERROR_UNION" "error-id binding parity shard"
require_matrix_note "@error_id" "error-id binding parity shard"
require_matrix_note "@error_name" "error-id binding parity shard"

echo "OK: MIR-C99 full-language catch error binding/error-id parity matched C99 oracle"
