#!/usr/bin/env bash
#
# Frame/pool async MIR-C99 parity shard: @frame type/methods, inline temp,
# caller-owned frame storage, AsyncFramePool stats, and stack-limit plumbing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-async-frame-pool.XXXXXX)"
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

run_case "async_frame_pool" '// mir_c99_async_frame_pool_case
use std.async;
use std.async_frame.AsyncFramePool;
use std.async_frame.async_frame_pool_init;
use std.async_frame.async_frame_pool_init_with_buffer;
use std.async_frame.async_frame_pool_alloc_aligned;
use std.async_frame.async_frame_pool_free_aligned;
use std.async_frame.async_frame_pool_stats;

@async_fn
fn frame_child(n: i32) Future<!i32> {
    return n + 1;
}

@async_fn
fn inline_temp_outer() Future<!i32> {
    var f: Future<!i32> = frame_child(41);
    const v: i32 = try @await f;
    return v;
}

@align(64)
@async_fn
fn aligned_child() Future<!i32> {
    return 42;
}

fn poll_ready_i32(p: Poll<!i32>) i32 {
    match p {
        .Ready(v) => {
            return v catch { 0 - 3; };
        },
        .Pending(_) => {
            return 0 - 2;
        },
    }
}

fn use_frame_ref(f: &@frame(frame_child)) i32 {
    _ = f;
    return 7;
}

fn ptr_in_range(base: &byte, size: usize, ptr: &byte) bool {
    if base == null || ptr == null || size == 0 {
        return false;
    }
    const base_addr: usize = @usize_from_ptr(base as &void);
    const ptr_addr: usize = @usize_from_ptr(ptr as &void);
    return ptr_addr >= base_addr && ptr_addr < base_addr + size;
}

export fn main() i32 {
    var frame: @frame(frame_child);
    const w: Waker = Waker{};

    frame.stop();
    frame.start(41);
    const first: i32 = poll_ready_i32(frame.poll(&w));
    if first != 42 {
        return 1;
    }
    frame.stop();

    frame.start(9);
    const second: i32 = poll_ready_i32(frame.poll(&w));
    if second != 10 {
        return 2;
    }
    if use_frame_ref(&frame) != 7 {
        return 3;
    }
    frame.stop();

    const inline_f: Future<!i32> = inline_temp_outer();
    const inline_value: i32 = poll_ready_i32(inline_f.poll(&w));
    if inline_value != 42 {
        return 4;
    }

    const align_value: i32 = @align_of(@frame(aligned_child));
    if align_value != 64 {
        return 5;
    }
    const aligned_f: Future<!i32> = aligned_child();
    const aligned_value: i32 = poll_ready_i32(aligned_f.poll(&w));
    if aligned_value != 42 {
        return 6;
    }

    var zero_pool: AsyncFramePool = AsyncFramePool{};
    async_frame_pool_init(&zero_pool, 0, 0);
    var za: i32 = 0;
    var zf: i32 = 0;
    var zfull: i32 = 0;
    var zheap: i32 = 0;
    async_frame_pool_stats(&zero_pool, &za, &zf, &zfull, &zheap);
    if za != 0 || zf != 0 {
        return 7;
    }

    var storage: [byte: 256] = [];
    var pool: AsyncFramePool = AsyncFramePool{};
    async_frame_pool_init_with_buffer(&pool, &storage[0] as &byte, 256usize, 1, 64usize);

    const small_ptr: &byte = async_frame_pool_alloc_aligned(&pool, 32usize, 8usize);
    if small_ptr == null || !ptr_in_range(&storage[0] as &byte, 256usize, small_ptr) {
        return 8;
    }

    const large_ptr: &byte = async_frame_pool_alloc_aligned(&pool, 96usize, 8usize);
    if large_ptr == null || ptr_in_range(&storage[0] as &byte, 256usize, large_ptr) {
        return 9;
    }

    async_frame_pool_free_aligned(&pool, small_ptr, 32usize, 8usize);
    async_frame_pool_free_aligned(&pool, large_ptr, 96usize, 8usize);

    var total_alloc: i32 = 0;
    var total_free: i32 = 0;
    var full_count: i32 = 0;
    var heap_fallback: i32 = 0;
    async_frame_pool_stats(&pool, &total_alloc, &total_free, &full_count, &heap_fallback);
    if total_alloc < 1 || total_free < 1 || heap_fallback < 1 {
        return 10;
    }

    return 15;
}'

echo "OK: MIR-C99 frame/pool async parity matched C99 oracle"
