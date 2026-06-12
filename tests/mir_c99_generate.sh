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

mkdir -p "$(dirname "$log")"
rm -f "$output"

{
    printf 'MIR-C99 generator command\n'
    printf 'input=%s\n' "$input"
    printf 'output=%s\n' "$output"
    printf 'status=not-ready\n'
    printf 'reason=source-to-PortableMIR hookup has not reached mir_c99_driver_run\n'
} >"$log"

if [[ ! -f "$input" ]]; then
    printf 'error=missing input\n' >>"$log"
    echo "error: missing input: $input" >&2
    exit 66
fi

echo "error: MIR-C99 generator command is not connected to source-to-PortableMIR yet" >&2
exit 70
