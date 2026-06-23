#!/usr/bin/env bash
#
# Cleanup/error statement MIR-C99 parity shard: defer, errdefer, lexical drop,
# and try/error propagation must agree with the C99 oracle on success and error
# paths.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

tmp_dir="$(mktemp -d /tmp/uya_mir_c99_cleanup_error_stmt.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
success_case="$tmp_dir/cleanup_error_statement_success.uya"
error_case="$tmp_dir/cleanup_error_statement_error.uya"

write_case() {
    local path="$1"
    local error_argc="$2"
    cat >"$path" <<UYA
use std.runtime.get_argc;

var cleanup_marker: i32 = 0;

error FullLanguageCleanupError;

struct CleanupDrop {
    value: i32,
    fn drop(self: CleanupDrop) void {
        cleanup_marker = cleanup_marker + self.value;
    }
}

fn maybe_cleanup(value: i32) !i32 {
    if value == $error_argc {
        return error.FullLanguageCleanupError;
    }
    return 13;
}

fn cleanup_path(value: i32) !i32 {
    cleanup_marker = 1;
    const dropped: CleanupDrop = CleanupDrop{ value: 5 };
    defer { cleanup_marker = cleanup_marker + 7; }
    errdefer { cleanup_marker = cleanup_marker + 11; }
    const inner: i32 = try maybe_cleanup(value);
    return inner + cleanup_marker;
}

export fn main() i32 {
    cleanup_marker = 0;
    const result: i32 = cleanup_path(get_argc()) catch { cleanup_marker + 23; };
    return result + cleanup_marker;
}
UYA
}

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

write_case "$success_case" 3
write_case "$error_case" 1
run_case "$success_case"
run_case "$error_case"

for kind in \
    AST_DEFER_STMT \
    AST_ERRDEFER_STMT \
    AST_TRY_EXPR \
    AST_TYPE_ERROR_UNION \
    CORE_STMT_KIND_DEFER \
    CORE_STMT_KIND_ERRDEFER \
    CORE_STMT_KIND_DROP \
    CORE_STMT_KIND_ERROR_PROPAGATION; do
    require_matrix_status "$kind"
    require_matrix_note "$kind" "cleanup/error statement parity shard"
done

echo "OK: MIR-C99 cleanup/error statement parity matched C99 oracle"
