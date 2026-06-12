#!/usr/bin/env bash
#
# Multi-arg direct calls, method dispatch, and generic instances must match the C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-call.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
call_case="$tmp_dir/call.uya"

cat >"$call_case" <<'UYA'
struct Acc {
    base: i32,
}

Acc {
    fn add(self: &Self, x: i32, y: i32) i32 {
        return self.base + x + y;
    }
}

fn sum3(a: i32, b: i32, c: i32) i32 {
    return a + b + c;
}

fn id<T>(value: T) T {
    return value;
}

export fn main() i32 {
    const acc: Acc = Acc{ base: 5 };
    const direct: i32 = sum3(1, 2, 3);
    const method: i32 = acc.add(4, 6);
    const generic: i32 = id<i32>(7);
    return direct + method + generic;
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$call_case" >/dev/null

echo "OK: MIR-C99 call parity matched C99 oracle"
