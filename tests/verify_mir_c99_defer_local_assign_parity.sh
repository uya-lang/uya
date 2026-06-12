#!/usr/bin/env bash
#
# Defer local assignment must match the existing C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-defer-local.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
return_local_case="$tmp_dir/defer_return_local.uya"
return_const_case="$tmp_dir/defer_return_const.uya"

cat >"$return_local_case" <<'UYA'
export fn main() i32 {
    var value: i32 = 3;
    defer { value = 9; }
    return value;
}
UYA

cat >"$return_const_case" <<'UYA'
export fn main() i32 {
    var value: i32 = 3;
    defer value = 9;
    return 4;
}
UYA

run_case() {
    local case_file="$1"
    MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
    C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
    bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null
}

run_case "$return_local_case"
run_case "$return_const_case"

echo "OK: MIR-C99 defer local assignment parity matched C99 oracle"
