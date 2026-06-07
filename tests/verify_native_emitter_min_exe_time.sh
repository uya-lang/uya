#!/usr/bin/env bash

# Phase 9 KPI：native emitter 生成最小 executable 的运行时间应低于 100ms。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NATIVE_DIR="$REPO_ROOT/src/codegen/native"
THRESHOLD_MS="${UYA_NATIVE_EMITTER_MIN_EXE_THRESHOLD_MS:-100}"

now_ns() {
    date +%s%N
}

tmp_dir="$(mktemp -d /tmp/uya-native-emitter-min-exe.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/codegen/native"
cp "$NATIVE_DIR/elf64.uya" "$tmp_dir/codegen/native/elf64.uya"
cp "$NATIVE_DIR/x86_64.uya" "$tmp_dir/codegen/native/x86_64.uya"
cp "$NATIVE_DIR/main.uya" "$tmp_dir/codegen/native/main.uya"

native_output_path="$tmp_dir/native-min-exe.bin"

cat >"$tmp_dir/main.uya" <<EOF
use std.testing.assert_eq_i32;
use std.testing.expect;
use libc.FILE;
use libc.fopen;
use libc.fclose;
use libc.printf;
use libc.syscall;
use codegen.native;

const CLOCK_MONOTONIC: i32 = 1;
const NATIVE_EMITTER_THRESHOLD_NS: i64 = ${THRESHOLD_MS}i64 * 1000000i64;

fn native_emitter_elapsed_ns(start_ts: &TimeSpec, end_ts: &TimeSpec) i64 {
    return (end_ts.tv_sec - start_ts.tv_sec) * 1000000000i64 + (end_ts.tv_nsec - start_ts.tv_nsec);
}

test "native emitter generates minimal executable under threshold" {
    var start_ts: TimeSpec = TimeSpec{ tv_sec: 0i64, tv_nsec: 0i64 };
    var end_ts: TimeSpec = TimeSpec{ tv_sec: 0i64, tv_nsec: 0i64 };

    const fp: &FILE = fopen("$native_output_path" as &const byte, "wb" as &const byte);
    try expect(fp != null);

    try sys_clock_gettime(CLOCK_MONOTONIC, &start_ts);
    const result: NativeEmitResult = native_emit_linux_x86_64_exit0_stream(fp);
    try sys_clock_gettime(CLOCK_MONOTONIC, &end_ts);
    _ = fclose(fp);

    const elapsed_ns: i64 = native_emitter_elapsed_ns(&start_ts, &end_ts);
    printf("native_emitter_elapsed_ns=%ld\n" as &const byte, elapsed_ns);
    try assert_eq_i32(result.status, NATIVE_EMIT_STATUS_OK);
    try assert_eq_i32(result.target, NATIVE_TARGET_LINUX_X86_64);
    try expect(result.code_bytes == X86_64_LINUX_EXIT0_SIZE as usize);
    try expect(result.output_bytes == (ELF64_MIN_EXEC_HEADERS + X86_64_LINUX_EXIT0_SIZE) as usize);
    try expect(elapsed_ns >= 0i64);
    try expect(elapsed_ns < NATIVE_EMITTER_THRESHOLD_NS);
}
EOF

script_start_ns="$(now_ns)"
(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c --project-root "$tmp_dir/")
script_end_ns="$(now_ns)"
script_elapsed_ms=$(( (script_end_ns - script_start_ns + 999999) / 1000000 ))

if [[ ! -s "$native_output_path" ]]; then
    echo "错误: native emitter 未生成最小 executable: $native_output_path" >&2
    exit 1
fi

chmod +x "$native_output_path"
"$native_output_path"

echo "verify_native_emitter_min_exe_time: ok (emitter_threshold_ms=$THRESHOLD_MS script_elapsed_ms=$script_elapsed_ms)"
