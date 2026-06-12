#!/usr/bin/env bash
#
# Float/double arguments, return values, and extern calls must match the C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-float-call.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/c_import"
cat >"$tmp_dir/c_import/float_ops.c" <<'C_EOF'
double extern_mix(float a, double b) {
    return (double)a + b + 4.0;
}
C_EOF

case_file="$tmp_dir/main.uya"
cat >"$case_file" <<'UYA'
@c_import("c_import/float_ops.c");

extern fn extern_mix(a: f32, b: f64) f64;

fn local_mix(a: f32, b: f64) f64 {
    return a as f64 + b;
}

fn local_f32(x: f32) f32 {
    return x + 1.5f32;
}

export fn main() i32 {
    const a: f32 = 2.5;
    const b: f64 = 3.25;
    const local: f64 = local_mix(a, b);
    const external: f64 = extern_mix(a, b);
    const back: f32 = local_f32(a);
    const total: f64 = local + external + back as f64;
    return total as i32;
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null

echo "OK: MIR-C99 float call parity matched C99 oracle"
