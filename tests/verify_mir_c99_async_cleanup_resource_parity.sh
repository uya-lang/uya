#!/usr/bin/env bash
#
# Async cleanup/resource MIR-C99 parity shard: async error-union cleanup,
# async defer/errdefer execution, and frame release/resource cleanup.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-async-cleanup.XXXXXX)"
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

run_case "async_cleanup_resource" '// mir_c99_async_cleanup_resource_case
use std.async;

var cleanup_marker: i32 = 0;

error AsyncCleanupFailure;

fn ready_i32_cleanup(v: i32) Future<!i32> {
    const p: Poll<!i32> = Poll<!i32>.Ready(ok<i32>(v));
    return Future<!i32>{ state: p };
}

@async_fn
fn cleanup_async(flag: i32) Future<!i32> {
    const awaited: i32 = try @await ready_i32_cleanup(flag + 2);
    const value: i32 = try cleanup_inner(flag, awaited);
    return value;
}

fn cleanup_inner(flag: i32, awaited: i32) !i32 {
    cleanup_marker = 1;
    defer { cleanup_marker = cleanup_marker + 10; }
    errdefer { cleanup_marker = cleanup_marker + 40; }
    if flag != 0 {
        return error.AsyncCleanupFailure;
    }
    return awaited + cleanup_marker;
}

export fn main() i32 {
    cleanup_marker = 0;
    const ok_r: !i32 = block_on<i32>(cleanup_async(0));
    const ok_v: i32 = ok_r catch { return 1; };
    if ok_v != 3 || cleanup_marker != 11 {
        return 2;
    }

    cleanup_marker = 0;
    const err_r: !i32 = block_on<i32>(cleanup_async(1));
    var err_seen: i32 = 0;
    const err_v: i32 = err_r catch {
        err_seen = 1;
        0 - 5;
    };
    if err_seen != 1 || err_v != 0 - 5 || cleanup_marker != 51 {
        return 3;
    }
    return 17;
}'

run_case "async_frame_release_resource" '// mir_c99_async_frame_release_resource_case
use std.async;

var frame_release_marker: i32 = 0;

struct ReleaseOnStopFuture : Future<!i32> {
    value: i32,

    fn poll(self: &Self, waker: &Waker) Poll<!i32> {
        _ = self;
        _ = waker;
        return Poll<!i32>.Pending({});
    }

    fn release(self: &Self) void {
        frame_release_marker = frame_release_marker + self.value;
    }
}

fn pending_release_child(value: i32) Future<!i32> {
    return ReleaseOnStopFuture{ value: value };
}

@async_fn
fn frame_release_child(value: i32) Future<!i32> {
    const waited: i32 = try @await pending_release_child(value);
    return waited + 1;
}

export fn main() i32 {
    var frame: @frame(frame_release_child);
    const w: Waker = Waker{};

    frame_release_marker = 0;
    frame.start(6);
    const first_poll: Poll<!i32> = frame.poll(&w);
    var first_pending: i32 = 0;
    match first_poll {
        .Pending(_) => { first_pending = 1; },
        .Ready(_) => { first_pending = 0; },
    };
    frame.stop();
    if first_pending != 1 || frame_release_marker != 6 {
        return 1;
    }

    frame.start(8);
    const second_poll: Poll<!i32> = frame.poll(&w);
    var second_pending: i32 = 0;
    match second_poll {
        .Pending(_) => { second_pending = 1; },
        .Ready(_) => { second_pending = 0; },
    };
    frame.stop();
    if second_pending != 1 || frame_release_marker != 14 {
        return 2;
    }

    return 23;
}'

echo "OK: MIR-C99 async cleanup/resource parity matched C99 oracle"
