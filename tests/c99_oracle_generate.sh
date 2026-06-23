#!/usr/bin/env bash
#
# Default existing-C99 oracle generator command for MIR-C99 parity checks.
#
# Usage:
#   tests/c99_oracle_generate.sh <input.uya> <output.c> <log> [--project-root <dir>]

set -euo pipefail

if [[ $# -ne 3 && $# -ne 5 ]]; then
    echo "usage: $0 <input.uya> <output.c> <log> [--project-root <dir>]" >&2
    exit 64
fi

input="$1"
output="$2"
log="$3"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
compiler="../uya/bin/uya"
project_root="."

if [[ $# -eq 5 ]]; then
    if [[ "$4" != "--project-root" ]]; then
        echo "usage: $0 <input.uya> <output.c> <log> [--project-root <dir>]" >&2
        exit 64
    fi
    project_root="$5"
fi

mkdir -p "$(dirname "$log")"
mkdir -p "$(dirname "$output")"
rm -f "$output"

if [[ ! -f "$input" ]]; then
    {
        printf 'C99 oracle generator command\n'
        printf 'input=%s\n' "$input"
        printf 'output=%s\n' "$output"
        printf 'status=not-ready\n'
        printf 'error=missing input\n'
    } >"$log"
    echo "error: missing input: $input" >&2
    exit 66
fi

if [[ ! -x "$repo_root/$compiler" ]]; then
    {
        printf 'C99 oracle generator command\n'
        printf 'input=%s\n' "$input"
        printf 'output=%s\n' "$output"
        printf 'status=not-ready\n'
        printf 'error=missing compiler\n'
    } >"$log"
    echo "error: missing C99 oracle compiler" >&2
    exit 69
fi

tmp_stdout="$(mktemp /tmp/uya-c99-oracle-stdout.XXXXXX)"
tmp_stderr="$(mktemp /tmp/uya-c99-oracle-stderr.XXXXXX)"
trap 'rm -f "$tmp_stdout" "$tmp_stderr"' EXIT

set +e
(
    cd "$repo_root"
    UYA_ROOT="$repo_root/lib/" "$compiler" build --c99 "$input" -o "$output" --no-split-c --project-root "$project_root"
) >"$tmp_stdout" 2>"$tmp_stderr"
status=$?
set -e

{
    printf 'C99 oracle generator command\n'
    printf 'input=%s\n' "$input"
    printf 'output=%s\n' "$output"
    printf 'compiler=%s\n' "$compiler"
    printf 'status=%s\n' "$status"
    printf 'stdout_begin\n'
    cat "$tmp_stdout"
    printf 'stdout_end\n'
    printf 'stderr_begin\n'
    cat "$tmp_stderr"
    printf 'stderr_end\n'
} >"$log"

if [[ "$status" -ne 0 ]]; then
    echo "error: C99 oracle generation failed" >&2
    exit "$status"
fi
if [[ ! -s "$output" ]]; then
    echo "error: C99 oracle compiler did not write output: $output" >&2
    exit 70
fi

exit 0
