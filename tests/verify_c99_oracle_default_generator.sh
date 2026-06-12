#!/usr/bin/env bash
#
# Default existing-C99 oracle generator must write host-compile-ready C.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATOR="$REPO_ROOT/tests/c99_oracle_generate.sh"
HOST_CC="${HOST_CC:-cc}"

tmp_dir="$(mktemp -d /tmp/uya-c99-oracle-generator.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
case_file="$tmp_dir/return_7.uya"
output_c="$tmp_dir/oracle.c"
log_file="$tmp_dir/oracle.log"
stdout_file="$tmp_dir/stdout.txt"
stderr_file="$tmp_dir/stderr.txt"
bin_file="$tmp_dir/oracle.out"

printf 'export fn main() i32 { return 7; }\n' >"$case_file"

bash "$GENERATOR" "$case_file" "$output_c" "$log_file" >"$stdout_file" 2>"$stderr_file"

if [[ ! -s "$output_c" ]]; then
    echo "error: C99 oracle generator did not write C" >&2
    cat "$log_file" >&2 || true
    exit 1
fi
if ! grep -q 'C99 oracle generator command' "$log_file" ||
   ! grep -q 'status=0' "$log_file"; then
    echo "error: C99 oracle generator log lacks success evidence" >&2
    cat "$log_file" >&2
    exit 1
fi

"$HOST_CC" -std=c99 "$output_c" -o "$bin_file" -lm
set +e
"$bin_file" >/dev/null 2>"$tmp_dir/run.stderr"
status=$?
set -e
if [[ "$status" -ne 7 ]]; then
    echo "error: compiled C99 oracle returned $status, expected 7" >&2
    cat "$tmp_dir/run.stderr" >&2
    exit 1
fi

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null

echo "OK: default C99 oracle generator writes host-compile-ready C"
