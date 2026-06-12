#!/usr/bin/env bash
#
# Dynamic catch success/error paths must match the existing C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-dynamic-catch.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
success_case="$tmp_dir/dynamic_catch_success.uya"
error_case="$tmp_dir/dynamic_catch_error.uya"

cat >"$success_case" <<'UYA'
use std.runtime.get_argc;

fn maybe_argc(value: i32) !i32 {
    if value == 3 {
        return error.DynamicCatchArgc;
    }
    return 9;
}

export fn main() i32 {
    const argc: i32 = get_argc();
    const value: i32 = maybe_argc(argc) catch { 5; };
    return value;
}
UYA

cat >"$error_case" <<'UYA'
use std.runtime.get_argc;

fn maybe_argc(value: i32) !i32 {
    if value == 1 {
        return error.DynamicCatchArgc;
    }
    return 9;
}

export fn main() i32 {
    const argc: i32 = get_argc();
    const value: i32 = maybe_argc(argc) catch { 5; };
    return value;
}
UYA

run_case() {
    local case_file="$1"
    MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
    C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
    bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null
}

run_case "$success_case"
run_case "$error_case"

echo "OK: MIR-C99 dynamic catch success/error parity matched C99 oracle"
