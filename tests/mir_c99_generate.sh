#!/usr/bin/env bash
#
# Default MIR-C99 generator command for the parity harness.
#
# Usage:
#   tests/mir_c99_generate.sh <input.uya> <output.c> <log>

set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "usage: $0 <input.uya> <output.c> <log>" >&2
    exit 64
fi

input="$1"
output="$2"
log="$3"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$(dirname "$log")"
rm -f "$output"

if [[ ! -f "$input" ]]; then
    {
        printf 'MIR-C99 generator command\n'
        printf 'input=%s\n' "$input"
        printf 'output=%s\n' "$output"
        printf 'status=not-ready\n'
        printf 'error=missing input\n'
    } >"$log"
    echo "error: missing input: $input" >&2
    exit 66
fi

bash "$script_dir/verify_mir_c99_generator_driver_handoff.sh"

{
    printf 'MIR-C99 generator command\n'
    printf 'input=%s\n' "$input"
    printf 'output=%s\n' "$output"
    printf 'handoff_status=verified\n'
    printf 'writer_status=pending\n'
    printf 'status=not-ready\n'
    printf 'reason=MIR-C99 writer has not emitted host-compile-ready C yet\n'
} >"$log"

echo "error: MIR-C99 generator command writer is pending" >&2
exit 70
