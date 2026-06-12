#!/usr/bin/env bash
#
# Float/double arithmetic, comparison, cast, and return must match the C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-float-values.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
float_case="$tmp_dir/float_values.uya"

cat >"$float_case" <<'UYA'
export fn main() i32 {
    const x: f32 = 3.5;
    const y: f32 = 1.5;
    const sum: f32 = x + y;
    const a: f64 = 1.5;
    const b: f64 = 2.5;
    const product: f64 = a * b;
    const widened: f64 = sum as f64 + product;
    const result: i32 = widened as i32;
    if widened > 8.74 && widened < 8.76 {
        return result;
    }
    return 1;
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$float_case" >/dev/null

echo "OK: MIR-C99 float value parity matched C99 oracle"
