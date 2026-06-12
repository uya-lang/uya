#!/usr/bin/env bash
#
# Default MIR-C99 generator command entrypoint must fail closed until hooked up.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"

if [[ ! -x "$GENERATOR" ]]; then
    echo "error: missing executable MIR-C99 generator command: $GENERATOR" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-default-generator.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
case_file="$tmp_dir/main.uya"
output_c="$tmp_dir/mir.c"
log_file="$tmp_dir/mir.log"
stdout_file="$tmp_dir/stdout.txt"
stderr_file="$tmp_dir/stderr.txt"
printf 'fn helper() i32 { return 1; }\nexport fn main() i32 { return helper(); }\n' >"$case_file"

set +e
"$GENERATOR" "$case_file" "$output_c" "$log_file" >"$stdout_file" 2>"$stderr_file"
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
    echo "error: default MIR-C99 generator reported success before source-to-PortableMIR hookup" >&2
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    exit 1
fi

if [[ -s "$output_c" ]]; then
    echo "error: default MIR-C99 generator left a C output on unsupported input" >&2
    ls -l "$output_c" >&2
    exit 1
fi

if [[ ! -f "$log_file" ]]; then
    echo "error: default MIR-C99 generator did not write a diagnostic log" >&2
    exit 1
fi

if ! grep -Eq 'source-to-PortableMIR|mir_c99_driver_run|MIR-C99 generator command' "$log_file"; then
    echo "error: default MIR-C99 generator log lacks hookup diagnostic" >&2
    cat "$log_file" >&2
    exit 1
fi

if grep -Eiq 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' \
    "$log_file" "$stdout_file" "$stderr_file"; then
    echo "error: default MIR-C99 generator mentioned legacy C99 fallback" >&2
    cat "$log_file" >&2
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    exit 1
fi

echo "OK: default MIR-C99 generator command fails closed without legacy fallback"
