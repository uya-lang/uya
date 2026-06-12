#!/usr/bin/env bash
#
# Default MIR-C99 generator must write host-compile-ready C for the supported subset.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"
HOST_CC="${HOST_CC:-cc}"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-generator-subset.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
case_file="$tmp_dir/return_7.uya"
output_c="$tmp_dir/mir.c"
log_file="$tmp_dir/mir.log"
stdout_file="$tmp_dir/stdout.txt"
stderr_file="$tmp_dir/stderr.txt"
bin_file="$tmp_dir/mir.out"
run_stdout="$tmp_dir/run.stdout"
run_stderr="$tmp_dir/run.stderr"

printf 'export fn main() i32 { return 7; }\n' >"$case_file"

"$GENERATOR" "$case_file" "$output_c" "$log_file" >"$stdout_file" 2>"$stderr_file"

if [[ ! -s "$output_c" ]]; then
    echo "error: default MIR-C99 generator did not write C for supported subset" >&2
    cat "$log_file" >&2 || true
    exit 1
fi

for pattern in 'handoff_status=verified' 'writer_status=done' 'subset=return_i32_main'; do
    if ! grep -q "$pattern" "$log_file"; then
        echo "error: generator log missing $pattern" >&2
        cat "$log_file" >&2
        exit 1
    fi
done

if grep -Eiq 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' \
    "$log_file" "$stdout_file" "$stderr_file" "$output_c"; then
    echo "error: default MIR-C99 generator mentioned disallowed C99 source path" >&2
    cat "$log_file" >&2
    exit 1
fi

"$HOST_CC" -std=c99 -Wall -Wextra -pedantic "$output_c" -o "$bin_file"
set +e
"$bin_file" >"$run_stdout" 2>"$run_stderr"
status=$?
set -e

if [[ "$status" -ne 7 ]]; then
    echo "error: compiled MIR-C99 subset program returned $status, expected 7" >&2
    cat "$run_stdout" >&2
    cat "$run_stderr" >&2
    exit 1
fi

echo "OK: default MIR-C99 generator writes host-compile-ready C for supported subset"
