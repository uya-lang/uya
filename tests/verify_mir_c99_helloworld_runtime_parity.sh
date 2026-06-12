#!/usr/bin/env bash
#
# HelloWorld stdout runtime helper must match the C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-helloworld.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

case_file="$tmp_dir/helloworld.uya"
cat >"$case_file" <<'UYA'
export fn main() i32 {
    @println("Hello, World!");
    return 0;
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null

echo "OK: MIR-C99 HelloWorld runtime parity matched C99 oracle"
