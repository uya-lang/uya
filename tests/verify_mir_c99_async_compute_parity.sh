#!/usr/bin/env bash
#
# async_compute MIR-C99 parity shard: integer/float async_compute wrappers and
# scheduler result path.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-async-compute.XXXXXX)"
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

run_case "async_compute" '// mir_c99_async_compute_case
use std.async;
use std.async_event;
use std.async_scheduler;
use std.thread;

fn double_i32(v: i32) i32 {
    return v * 2;
}

fn add_half_f32(v: f32) f32 {
    return v + 0.5f32;
}

export fn main() i32 {
    var pool: ThreadPool = thread_pool_new(2);
    defer {
        thread_pool_shutdown(&pool);
    }

    var scheduler: Scheduler = scheduler_new();
    var loop_impl: LinuxEpoll = linux_epoll_create(0) catch {
        return 1;
    };
    defer {
        _ = sys_close(loop_impl.epfd) catch {};
    }
    const loop_i32: EventLoop = loop_impl;
    const int_future: Future<!i32> = async_compute<i32>(&pool, &double_i32 as &void, 21);
    const int_result: i32 = scheduler_run_with_event_loop<i32>(&scheduler, loop_i32, int_future, 1000) catch {
        return 2;
    };
    if int_result != 42 {
        return 3;
    }

    var loop_impl_f32: LinuxEpoll = linux_epoll_create(0) catch {
        return 4;
    };
    defer {
        _ = sys_close(loop_impl_f32.epfd) catch {};
    }
    const loop_f32: EventLoop = loop_impl_f32;
    const float_future: Future<!f32> = async_compute<f32>(&pool, &add_half_f32 as &void, 1.5f32);
    const float_result: f32 = scheduler_run_with_event_loop<f32>(&scheduler, loop_f32, float_future, 1000) catch {
        return 5;
    };
    if float_result < 1.99f32 || float_result > 2.01f32 {
        return 6;
    }

    return 26;
}'

echo "OK: MIR-C99 async_compute parity matched C99 oracle"
