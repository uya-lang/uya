#!/usr/bin/env bash
#
# atomic i32 init/write/read must be an explicit MIR-C99 reject until a real
# atomic helper or target capability is wired, while the existing C99 oracle
# records the behavior this shard must match once support lands.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOST_CC="${HOST_CC:-cc}"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-atomic-i32.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

case_file="$tmp_dir/atomic_i32.uya"
cat >"$case_file" <<'UYA'
export fn main() i32 {
    var value: atomic i32 = 5;
    value = 7;
    const read: i32 = value;
    return read;
}
UYA

oracle_c="$tmp_dir/oracle.c"
oracle_log="$tmp_dir/oracle.generate.log"
oracle_bin="$tmp_dir/oracle.out"
bash "$REPO_ROOT/tests/c99_oracle_generate.sh" "$case_file" "$oracle_c" "$oracle_log"
"$HOST_CC" -std=c99 -Wall -Wextra -pedantic "$oracle_c" -o "$oracle_bin" \
    >"$tmp_dir/oracle.cc.out" 2>"$tmp_dir/oracle.cc.err"

set +e
"$oracle_bin" >"$tmp_dir/oracle.stdout" 2>"$tmp_dir/oracle.stderr"
oracle_status=$?
set -e
if [[ "$oracle_status" -ne 7 ]]; then
    echo "error: C99 oracle atomic i32 case exited with $oracle_status, expected 7" >&2
    cat "$tmp_dir/oracle.stdout" >&2
    cat "$tmp_dir/oracle.stderr" >&2
    exit 1
fi

mir_c="$tmp_dir/mir.c"
mir_log="$tmp_dir/mir.generate.log"
mir_out="$tmp_dir/mir.generate.out"
mir_err="$tmp_dir/mir.generate.err"
set +e
bash "$REPO_ROOT/tests/mir_c99_generate.sh" "$case_file" "$mir_c" "$mir_log" \
    >"$mir_out" 2>"$mir_err"
mir_status=$?
set -e

if [[ "$mir_status" -eq 0 ]]; then
    echo "error: MIR-C99 atomic i32 case unexpectedly generated C before atomic support" >&2
    exit 1
fi
if [[ -e "$mir_c" ]]; then
    echo "error: MIR-C99 atomic i32 reject left an output C file" >&2
    exit 1
fi

for pattern in \
    'subset=atomic_i32_init_write_read' \
    'status=rejected' \
    'reject_reason=atomic_capability' \
    'diagnostic_code=MIR_C99_VALUE_DIAG_UNSUPPORTED_ATOMIC_CAPABILITY'; do
    if ! grep -q "$pattern" "$mir_log"; then
        echo "error: MIR-C99 atomic i32 reject log missing pattern: $pattern" >&2
        cat "$mir_log" >&2
        exit 1
    fi
done

if grep -Eiq 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' \
    "$mir_log" "$mir_out" "$mir_err"; then
    echo "error: MIR-C99 atomic i32 reject mentioned legacy C99 fallback" >&2
    cat "$mir_log" >&2
    cat "$mir_out" >&2
    cat "$mir_err" >&2
    exit 1
fi

echo "OK: MIR-C99 atomic i32 init/write/read rejects explicitly before parity support"
