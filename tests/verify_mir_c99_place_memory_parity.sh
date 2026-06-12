#!/usr/bin/env bash
#
# Struct fields, array/slice indexes, and out-param writeback must match the C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-place-memory.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
place_case="$tmp_dir/place_memory.uya"

cat >"$place_case" <<'UYA'
struct Point {
    x: i32,
    y: i32,
}

fn write_out(out: &i32, value: i32) void {
    *out = value;
}

export fn main() i32 {
    var p: Point = Point{ x: 2, y: 3 };
    p.y = p.y + 4;
    var array: [i32: 4] = [1, 2, 3, 4];
    const slice: &[i32] = array[1:2];
    var written: i32 = 0;
    write_out(&written, p.x + p.y + array[2] + slice[0] + slice[1]);
    return written;
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$place_case" >/dev/null

echo "OK: MIR-C99 place/memory parity matched C99 oracle"
