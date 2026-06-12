#!/usr/bin/env bash
#
# Basic CFG shapes must compile through MIR-C99 and match the existing C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-cfg.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
if_case="$tmp_dir/local_if_return.uya"
nested_case="$tmp_dir/nested_branch.uya"
loop_case="$tmp_dir/loop_backedge.uya"

cat >"$if_case" <<'UYA'
export fn main() i32 {
    const value: i32 = 7;
    if value == 7 {
        return 3;
    }
    return 4;
}
UYA

cat >"$nested_case" <<'UYA'
export fn main() i32 {
    const value: i32 = 5;
    if value > 3 {
        if value == 5 {
            return 6;
        }
        return 7;
    }
    return 8;
}
UYA

cat >"$loop_case" <<'UYA'
export fn main() i32 {
    var i: i32 = 0;
    var sum: i32 = 0;
    while i < 4 {
        sum = sum + 1;
        i = i + 1;
    }
    return sum;
}
UYA

run_case() {
    local case_file="$1"
    MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
    C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
    bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null
}

run_case "$if_case"
run_case "$nested_case"
run_case "$loop_case"

echo "OK: MIR-C99 CFG parity matched C99 oracle"
