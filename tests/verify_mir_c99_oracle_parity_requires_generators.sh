#!/usr/bin/env bash
#
# MIR-C99 parity harness must not treat missing generators as a passing parity gate.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HARNESS="$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh"

if [[ ! -x "$HARNESS" ]]; then
    echo "error: missing executable harness: $HARNESS" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-generator-required.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
case_file="$tmp_dir/main.uya"
stdout_file="$tmp_dir/stdout.txt"
stderr_file="$tmp_dir/stderr.txt"
printf 'export fn main() i32 { return 0; }\n' >"$case_file"

set +e
env -u MIR_C99_GENERATE_CMD -u C99_ORACLE_GENERATE_CMD \
    "$HARNESS" --case "$case_file" >"$stdout_file" 2>"$stderr_file"
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
    echo "error: MIR-C99 parity harness accepted missing generator commands" >&2
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    exit 1
fi

if ! grep -Eq 'generator command.*required|required.*generator command' "$stderr_file"; then
    echo "error: missing generator failure did not explain required generator commands" >&2
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    exit 1
fi

if grep -Eiq 'OK: MIR-C99/oracle parity harness installed|pending backend hookup' "$stdout_file" "$stderr_file"; then
    echo "error: missing generator path still looks like a passing pending-hookup gate" >&2
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    exit 1
fi

"$HARNESS" --self-test >/dev/null

echo "OK: MIR-C99 parity harness requires real generator commands"
