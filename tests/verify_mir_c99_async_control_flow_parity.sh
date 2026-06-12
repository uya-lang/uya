#!/usr/bin/env bash
#
# Control-flow async MIR-C99 parity shard: if/else-if, while, range/array for,
# nested blocks, multiple await points, and compound try-await expressions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-async-control.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

run_case() {
    local name="$1"
    local body="$2"
    local case_file="$tmp_dir/${name}.uya"
    printf '%s\n' "$body" >"$case_file"
    MIR_C99_GENERATE_CMD='bash ./tests/mir_c99_generate.sh {input} {output} {log}' \
    C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
    bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null
}

run_case "async_control_flow" '// mir_c99_async_control_flow_case
use std.async;

fn ready_i32_cf(v: i32) Future<!i32> {
    return Future<!i32>{ state: Poll<!i32>.Ready(ok<i32>(v)) };
}

@async_fn
fn control_flow_async(mode: i32) Future<!i32> {
    var total: i32 = 0;

    if mode == 1 {
        const a: i32 = try @await ready_i32_cf(2);
        total = total + a + 8;
    } else if mode == 2 {
        var copied: i32 = 0;
        while copied < 3 {
            const n: i32 = try @await ready_i32_cf(1);
            copied = copied + n;
        }
        total = total + copied + 40;
    } else {
        total = total + 5;
    }

    for 0..3 |k| {
        const x: i32 = try @await ready_i32_cf(2);
        total = total + x + (k as i32);
    }

    var arr: [i32: 3] = [1, 2, 3];
    for arr |e| {
        const y: i32 = try @await ready_i32_cf(1);
        total = total + e + y;
    }

    {
        const left: i32 = try @await ready_i32_cf(4);
        const right: i32 = try @await ready_i32_cf(5);
        total = total + left + right;
    }

    total = total + (try @await ready_i32_cf(6));
    return total + (try @await ready_i32_cf(7));
}

export fn main() i32 {
    const r1: !i32 = block_on<i32>(control_flow_async(1));
    const v1: i32 = r1 catch { return 1; };
    if v1 != 47 {
        return 2;
    }

    const r2: !i32 = block_on<i32>(control_flow_async(2));
    const v2: i32 = r2 catch { return 3; };
    if v2 != 80 {
        return 4;
    }

    const r3: !i32 = block_on<i32>(control_flow_async(3));
    const v3: i32 = r3 catch { return 5; };
    if v3 != 42 {
        return 6;
    }

    return 12;
}'

echo "OK: MIR-C99 control-flow async parity matched C99 oracle"
