#!/usr/bin/env bash
#
# Runtime/basic async MIR-C99 parity shard: ready/block_on, @async_fn ready
# return, direct await binding, and direct async error return.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-async-basic.XXXXXX)"
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

run_case "async_ready_block_on" 'use std.async;

export fn main() i32 {
    const f: Future<!i32> = future_ready_ok<i32>(7);
    const value: i32 = block_on<i32>(f) catch {
        return 9;
    };
    return value;
}'

run_case "async_fn_basic" '// mir_c99_async_fn_basic_case
use std.async;

@async_fn
fn answer() Future<!i32> {
    return 42;
}

export fn main() i32 {
    const value: i32 = block_on<i32>(answer()) catch {
        return 9;
    };
    return value;
}'

run_case "async_direct_await_err_union" '// mir_c99_async_direct_await_err_union_case
use std.async;

fn ready_i32_direct(v: i32) Future<!i32> {
    const p: Poll<!i32> = Poll<!i32>.Ready(ok<i32>(v));
    return Future<!i32>{ state: p };
}

@async_fn
fn bind_direct_err_union() Future<!i32> {
    const r: !i32 = @await ready_i32_direct(7);
    const v: i32 = r catch { 0 - 10; };
    return v + 5;
}

export fn main() i32 {
    const out: !i32 = block_on<i32>(bind_direct_err_union());
    const v: i32 = out catch { return 9; };
    return v;
}'

run_case "async_direct_return_error" '// mir_c99_async_direct_return_error_case
use std.async;

error DirectAsyncFailure;

@async_fn
fn async_direct_error_no_await(flag: i32) Future<!i32> {
    if flag != 0 {
        return error.DirectAsyncFailure;
    }
    return 11;
}

export fn main() i32 {
    const ok_r: !i32 = block_on<i32>(async_direct_error_no_await(0));
    const ok_v: i32 = ok_r catch { return 1; };
    if ok_v != 11 {
        return 2;
    }
    var err_seen: i32 = 0;
    const err_r: !i32 = block_on<i32>(async_direct_error_no_await(1));
    const err_v: i32 = err_r catch {
        err_seen = 1;
        0 - 2;
    };
    if err_seen != 1 || err_v != 0 - 2 {
        return 3;
    }
    return 13;
}'

echo "OK: MIR-C99 runtime/basic async parity matched C99 oracle"
