#!/usr/bin/env bash

# Phase 9：验证 codegen.native facade 存在，并能经 x86_64 + ELF64 streaming
# writer 生成最小 Linux x86_64 exit(0) executable 字节流。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NATIVE_DIR="$REPO_ROOT/src/codegen/native"
MAIN_FILE="$NATIVE_DIR/main.uya"

if [[ ! -f "$MAIN_FILE" ]]; then
    echo "错误: 缺少 $MAIN_FILE" >&2
    exit 1
fi

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$MAIN_FILE"; then
        echo "错误: native facade 缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'use codegen\.native\.elf64' "接入 ELF64 writer"
require_pattern 'use codegen\.native\.x86_64' "接入 x86_64 编码层"
require_pattern 'export struct NativeEmitResult' "native 输出结果摘要"
require_pattern 'native_encode_linux_x86_64_exit0_code' "最小 x86_64 exit0 机器码入口"
require_pattern 'native_emit_linux_x86_64_exit0_stream' "最小 ELF64 streaming 输出入口"
require_pattern 'elf64_write_executable_stream' "streaming writer 调用"

tmp_dir="$(mktemp -d /tmp/uya-native-main-facade.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/codegen/native"
cp "$NATIVE_DIR/elf64.uya" "$tmp_dir/codegen/native/elf64.uya"
cp "$NATIVE_DIR/x86_64.uya" "$tmp_dir/codegen/native/x86_64.uya"
cp "$NATIVE_DIR/main.uya" "$tmp_dir/codegen/native/main.uya"
output_path="$tmp_dir/native-main-exit0.bin"

cat >"$tmp_dir/main.uya" <<EOF
use std.testing.assert_eq_i32;
use std.testing.expect;
use libc.FILE;
use libc.fopen;
use libc.fread;
use libc.rewind;
use libc.fclose;
use codegen.native;

fn main_bval(buf: &byte, i: usize) i32 {
    return buf[i] as i32;
}

test "native facade writes minimal linux x86_64 exit0 executable" {
    var code: [byte: 16] = [];
    var code_len: usize = 99usize;
    try assert_eq_i32(native_default_target(), NATIVE_TARGET_LINUX_X86_64);
    try assert_eq_i32(native_encode_linux_x86_64_exit0_code(&code[0], 16usize, &code_len), 0);
    try expect(code_len == X86_64_LINUX_EXIT0_SIZE as usize);
    try assert_eq_i32(main_bval(&code[0], 0usize), 184);
    try assert_eq_i32(main_bval(&code[0], 1usize), 60);
    try assert_eq_i32(main_bval(&code[0], 5usize), 49);
    try assert_eq_i32(main_bval(&code[0], 7usize), 15);
    try assert_eq_i32(main_bval(&code[0], 8usize), 5);

    const fp: &FILE = fopen("$output_path" as &const byte, "w+b" as &const byte);
    try expect(fp != null);
    const result: NativeEmitResult = native_emit_linux_x86_64_exit0_stream(fp);
    try assert_eq_i32(result.status, NATIVE_EMIT_STATUS_OK);
    try assert_eq_i32(result.target, NATIVE_TARGET_LINUX_X86_64);
    try expect(result.code_bytes == X86_64_LINUX_EXIT0_SIZE as usize);
    try expect(result.output_bytes == (ELF64_MIN_EXEC_HEADERS + X86_64_LINUX_EXIT0_SIZE) as usize);
    try expect(result.temp_peak_bytes == (ELF64_MIN_EXEC_HEADERS + X86_64_LINUX_EXIT0_SIZE) as usize);

    rewind(fp);
    var out: [byte: 160] = [];
    const nread: usize = fread(&out[0], 1usize, result.output_bytes, fp);
    try expect(nread == result.output_bytes);

    try assert_eq_i32(main_bval(&out[0], 0usize), 127);
    try assert_eq_i32(main_bval(&out[0], 1usize), 69);
    try assert_eq_i32(main_bval(&out[0], 2usize), 76);
    try assert_eq_i32(main_bval(&out[0], 3usize), 70);
    try assert_eq_i32(main_bval(&out[0], 18usize), EM_X86_64);
    try assert_eq_i32(main_bval(&out[0], 56usize), 1);
    try assert_eq_i32(main_bval(&out[0], 60usize), 0);
    try assert_eq_i32(main_bval(&out[0], ELF64_MIN_EXEC_HEADERS as usize), 184);
    try assert_eq_i32(main_bval(&out[0], (ELF64_MIN_EXEC_HEADERS + 1) as usize), 60);
    try assert_eq_i32(main_bval(&out[0], (ELF64_MIN_EXEC_HEADERS + 5) as usize), 49);
    try assert_eq_i32(main_bval(&out[0], (ELF64_MIN_EXEC_HEADERS + 7) as usize), 15);
    try assert_eq_i32(main_bval(&out[0], (ELF64_MIN_EXEC_HEADERS + 8) as usize), 5);

    _ = fclose(fp);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c --project-root "$tmp_dir/")

echo "✓ native facade verified"
