#!/usr/bin/env bash
#
# A minimal AsyncFramePool buffer + heap fallback case must match the existing
# C99 oracle when generated through the MIR-C99 default generator.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-async-frame-pool.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
case_file="$tmp_dir/async_frame_pool_heap_mode.uya"

cat >"$case_file" <<'UYA_EOF'
// mir_c99_async_frame_pool_heap_mode_case
use std.async_frame.AsyncFramePool;
use std.async_frame.async_frame_pool_init_with_buffer;
use std.async_frame.async_frame_pool_alloc_aligned;
use std.async_frame.async_frame_pool_free_aligned;
use std.async_frame.async_frame_pool_stats;

fn ptr_in_range(base: &byte, size: usize, ptr: &byte) bool {
    if base == null || ptr == null || size == 0 {
        return false;
    }
    const base_addr: usize = @usize_from_ptr(base as &void);
    const ptr_addr: usize = @usize_from_ptr(ptr as &void);
    return ptr_addr >= base_addr && ptr_addr < base_addr + size;
}

export fn main() i32 {
    var storage: [byte: 256] = [];
    var pool: AsyncFramePool = AsyncFramePool{};
    async_frame_pool_init_with_buffer(&pool, &storage[0] as &byte, 256usize, 1, 64usize);

    const small_ptr: &byte = async_frame_pool_alloc_aligned(&pool, 32usize, 8usize);
    if small_ptr == null || !ptr_in_range(&storage[0] as &byte, 256usize, small_ptr) {
        return 2;
    }
    const large_ptr: &byte = async_frame_pool_alloc_aligned(&pool, 96usize, 8usize);
    if large_ptr == null || ptr_in_range(&storage[0] as &byte, 256usize, large_ptr) {
        return 3;
    }

    async_frame_pool_free_aligned(&pool, small_ptr, 32usize, 8usize);
    async_frame_pool_free_aligned(&pool, large_ptr, 96usize, 8usize);

    var total_alloc: i32 = 0;
    var total_free: i32 = 0;
    var full_count: i32 = 0;
    var heap_fallback: i32 = 0;
    async_frame_pool_stats(&pool, &total_alloc, &total_free, &full_count, &heap_fallback);
    if total_alloc < 1 || total_free < 1 || heap_fallback < 1 {
        return 4;
    }
    return 9;
}
UYA_EOF

MIR_C99_GENERATE_CMD='bash ./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null

echo "OK: MIR-C99 async frame pool heap fallback parity matched C99 oracle"
