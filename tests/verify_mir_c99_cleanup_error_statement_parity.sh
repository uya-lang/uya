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

compile_host_c() {
    local input_c="$1"
    local output_bin="$2"
    if ! cc -std=c99 -Wall -Wextra -pedantic "$input_c" -o "$output_bin" -lm \
        >"$tmp_dir/$(basename "$output_bin").cc.out" \
        2>"$tmp_dir/$(basename "$output_bin").cc.err"; then
        echo "error: host C compile failed for $input_c" >&2
        cat "$tmp_dir/$(basename "$output_bin").cc.out" >&2 || true
        cat "$tmp_dir/$(basename "$output_bin").cc.err" >&2 || true
        exit 1
    fi
}

run_binary_capture() {
    local bin="$1"
    local prefix="$2"
    set +e
    "$bin" >"$prefix.stdout" 2>"$prefix.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$prefix.exit"
}

build_candidate() {
    local candidate_c="$tmp_dir/cmd_build_candidate.c"
    local candidate_log="$tmp_dir/cmd_build_candidate.generate.log"
    CANDIDATE_BIN="$tmp_dir/cmd_build_candidate"

    if ! (
        cd "$REPO_ROOT"
        UYA_ROOT="$REPO_ROOT/lib/" ../uya/bin/uya build --mir-c99 \
            src/cmd/build/main.uya -o "$candidate_c"
    ) >"$candidate_log" 2>&1; then
        echo "error: MIR-C99 cleanup/error real CLI candidate build failed before case parity" >&2
        cat "$candidate_log" >&2
        exit 1
    fi
    if [[ ! -s "$candidate_c" ]]; then
        echo "error: MIR-C99 cleanup/error candidate did not write C output: $candidate_c" >&2
        exit 1
    fi
    compile_host_c "$candidate_c" "$CANDIDATE_BIN"
}

run_case() {
    local case_file="$1"
    local case_name
    local candidate_c
    local candidate_bin
    local oracle_c
    local oracle_bin
    local candidate_status
    local oracle_status

    case_name="$(basename "$case_file" .uya)"
    candidate_c="$tmp_dir/${case_name}.mir.c"
    candidate_bin="$tmp_dir/${case_name}.mir"
    oracle_c="$tmp_dir/${case_name}.oracle.c"
    oracle_bin="$tmp_dir/${case_name}.oracle"

    if ! (
        cd "$REPO_ROOT"
        UYA_ROOT="$REPO_ROOT/lib/" "$CANDIDATE_BIN" build --mir-c99 "$case_file" \
            -o "$candidate_c" --project-root "$tmp_dir"
    ) >"$tmp_dir/${case_name}.candidate.build.out" \
        2>"$tmp_dir/${case_name}.candidate.build.err"; then
        echo "error: MIR-C99 cleanup/error candidate build failed for $case_name" >&2
        cat "$tmp_dir/${case_name}.candidate.build.out" >&2 || true
        cat "$tmp_dir/${case_name}.candidate.build.err" >&2 || true
        exit 1
    fi
    if [[ ! -s "$candidate_c" ]]; then
        echo "error: MIR-C99 cleanup/error candidate did not write C output: $candidate_c" >&2
        exit 1
    fi
    if ! grep -Fq "[MIR-C99]" "$tmp_dir/${case_name}.candidate.build.out"; then
        echo "error: MIR-C99 cleanup/error candidate build log missing [MIR-C99] tag" >&2
        cat "$tmp_dir/${case_name}.candidate.build.out" >&2 || true
        cat "$tmp_dir/${case_name}.candidate.build.err" >&2 || true
        exit 1
    fi
    compile_host_c "$candidate_c" "$candidate_bin"

    if ! (
        cd "$REPO_ROOT"
        UYA_ROOT="$REPO_ROOT/lib/" ../uya/bin/uya build "$case_file" -o "$oracle_c" \
            --no-split-c --project-root "$tmp_dir"
    ) >"$tmp_dir/${case_name}.oracle.build.out" \
        2>"$tmp_dir/${case_name}.oracle.build.err"; then
        echo "error: cleanup/error oracle build failed for $case_name" >&2
        cat "$tmp_dir/${case_name}.oracle.build.out" >&2 || true
        cat "$tmp_dir/${case_name}.oracle.build.err" >&2 || true
        exit 1
    fi
    compile_host_c "$oracle_c" "$oracle_bin"

    run_binary_capture "$candidate_bin" "$tmp_dir/${case_name}.candidate"
    run_binary_capture "$oracle_bin" "$tmp_dir/${case_name}.oracle"

    candidate_status="$(cat "$tmp_dir/${case_name}.candidate.exit")"
    oracle_status="$(cat "$tmp_dir/${case_name}.oracle.exit")"
    if [[ "$candidate_status" != "$oracle_status" ]]; then
        echo "error: MIR-C99 cleanup/error exit differs for $case_name: mir=$candidate_status oracle=$oracle_status" >&2
        exit 1
    fi
    diff -u "$tmp_dir/${case_name}.oracle.stdout" "$tmp_dir/${case_name}.candidate.stdout"
    diff -u "$tmp_dir/${case_name}.oracle.stderr" "$tmp_dir/${case_name}.candidate.stderr"
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
build_candidate
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
