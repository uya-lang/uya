#!/usr/bin/env bash
#
# Extern calls backed by a @c_import object must match the C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-extern-object.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/c_import"
cat >"$tmp_dir/c_import/add.c" <<'C_EOF'
int add_i32(int a, int b) {
    return a + b;
}
C_EOF

case_file="$tmp_dir/main.uya"
cat >"$case_file" <<'UYA'
@c_import("c_import/add.c");

extern fn add_i32(a: i32, b: i32) i32;

export fn main() i32 {
    return add_i32(20, 22);
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null

echo "OK: MIR-C99 extern object call parity matched C99 oracle"
