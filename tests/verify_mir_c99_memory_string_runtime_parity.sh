#!/usr/bin/env bash
#
# Memory and string primitive runtime helpers must match the C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-memory-string.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

case_file="$tmp_dir/memory_string.uya"
cat >"$case_file" <<'UYA'
use libc.memset;
use libc.strlen;

export fn main() i32 {
    var buf: [byte: 4] = [];
    _ = memset(&buf[0], 65, 3usize);
    const len: usize = strlen("hello\0" as *const byte);
    return buf[0] as i32 + buf[2] as i32 + len as i32;
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null

echo "OK: MIR-C99 memory/string runtime parity matched C99 oracle"
