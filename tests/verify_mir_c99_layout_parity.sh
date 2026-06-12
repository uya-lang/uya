#!/usr/bin/env bash
#
# @size_of/@align_of and struct/array/slice layout must match the C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-layout.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
layout_case="$tmp_dir/layout.uya"

cat >"$layout_case" <<'UYA'
struct LayoutPair {
    a: i32,
    b: i32,
}

export fn main() i32 {
    var array: [i32: 4] = [1, 2, 3, 4];
    const slice: &[i32] = array[1:2];
    const total: i32 = @size_of(LayoutPair) + @align_of(LayoutPair) + @size_of(array) + @align_of(array) + @size_of(slice) + @align_of(slice);
    if total > 255 {
        return 99;
    }
    return total;
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$layout_case" >/dev/null

echo "OK: MIR-C99 layout parity matched C99 oracle"
