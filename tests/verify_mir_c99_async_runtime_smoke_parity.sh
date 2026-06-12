#!/usr/bin/env bash
#
# Minimal async runtime ready-future smoke must match the C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-async-runtime.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

case_file="$tmp_dir/async_runtime.uya"
cat >"$case_file" <<'UYA'
use std.async;

export fn main() i32 {
    const f: Future<!i32> = future_ready_ok<i32>(7);
    const value: i32 = block_on<i32>(f) catch {
        return 9;
    };
    return value;
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null

echo "OK: MIR-C99 async runtime smoke parity matched C99 oracle"
