#!/usr/bin/env bash
#
# Integer arithmetic, comparison, and boolean combinations must match the C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-integer-values.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
arithmetic_case="$tmp_dir/integer_arithmetic.uya"
boolean_case="$tmp_dir/integer_boolean.uya"

cat >"$arithmetic_case" <<'UYA'
export fn main() i32 {
    const a: i32 = 6;
    const b: i32 = 4;
    const sum: i32 = a + b;
    const result: i32 = sum - b;
    return result;
}
UYA

cat >"$boolean_case" <<'UYA'
export fn main() i32 {
    const a: i32 = 6;
    const b: i32 = 4;
    if (a > b && b < 5) || a == 9 {
        return 8;
    }
    return 1;
}
UYA

run_case() {
    local case_file="$1"
    MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
    C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
    bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null
}

run_case "$arithmetic_case"
run_case "$boolean_case"

echo "OK: MIR-C99 integer value parity matched C99 oracle"
