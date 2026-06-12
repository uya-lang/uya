#!/usr/bin/env bash
#
# Channel/scheduler async MIR-C99 parity shard: channel send/recv, MPSC
# pending-until-recv, and scheduler event allocator/signature coexist.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-async-channel-scheduler.XXXXXX)"
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

run_case "async_channel_scheduler" '// mir_c99_async_channel_scheduler_case
use std.async;
use std.async_channel;
use std.async_scheduler;
use std.mem.allocator.g_allocator;

export fn main() i32 {
    const wk: Waker = Waker{};
    var ch: Channel<i32> = channel_new<i32>();
    const send_f: Future<usize> = ch.send(42);
    const send_p: Poll<usize> = send_f.poll(&wk);
    var send_ready: i32 = 0;
    match send_p {
        .Ready(_) => { send_ready = 1; },
        .Pending(_) => { send_ready = 0; },
    };
    if send_ready != 1 {
        return 1;
    }

    const recv_f: Future<i32> = ch.recv();
    const recv_p: Poll<i32> = recv_f.poll(&wk);
    var got: i32 = 0;
    match recv_p {
        .Ready(v) => { got = v; },
        .Pending(_) => { got = 0 - 1; },
    };
    if got != 42 {
        return 2;
    }

    var mpsc: MpscChannel<i32> = mpsc_channel_new<i32>(g_allocator, 1);
    const first_send_f: Future<usize> = mpsc.send(11);
    const first_send_p: Poll<usize> = first_send_f.poll(&wk);
    var first_ready: i32 = 0;
    match first_send_p {
        .Ready(_) => { first_ready = 1; },
        .Pending(_) => { first_ready = 0; },
    };
    if first_ready != 1 {
        return 3;
    }

    const second_send_f: Future<usize> = mpsc.send(22);
    const second_send_p: Poll<usize> = second_send_f.poll(&wk);
    var second_pending: i32 = 0;
    match second_send_p {
        .Ready(_) => { second_pending = 0; },
        .Pending(_) => { second_pending = 1; },
    };
    if second_pending != 1 {
        return 4;
    }

    const first_recv_f: Future<i32> = mpsc.recv();
    const first_recv_p: Poll<i32> = first_recv_f.poll(&wk);
    var first_value: i32 = 0;
    match first_recv_p {
        .Ready(v) => { first_value = v; },
        .Pending(_) => { first_value = 0 - 1; },
    };
    if first_value != 11 {
        return 5;
    }

    const third_send_f: Future<usize> = mpsc.send(22);
    const third_send_p: Poll<usize> = third_send_f.poll(&wk);
    var third_ready: i32 = 0;
    match third_send_p {
        .Ready(_) => { third_ready = 1; },
        .Pending(_) => { third_ready = 0; },
    };
    if third_ready != 1 {
        return 6;
    }

    const second_recv_f: Future<i32> = mpsc.recv();
    const second_recv_p: Poll<i32> = second_recv_f.poll(&wk);
    var second_value: i32 = 0;
    match second_recv_p {
        .Ready(v) => { second_value = v; },
        .Pending(_) => { second_value = 0 - 1; },
    };
    if second_value != 22 {
        return 7;
    }

    var s: Scheduler = scheduler_new();
    const pool: &AsyncFramePool = scheduler_frame_pool(&s);
    if pool == null {
        return 8;
    }

    return 21;
}'

echo "OK: MIR-C99 channel/scheduler async parity matched C99 oracle"
