#!/usr/bin/env bash

# Phase 9：验证 native nostdlib _start 入口和 ELF e_entry。

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
        echo "错误: native nostdlib _start 缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'NATIVE_NOSTDLIB_START_CODE_OFFSET' "_start code offset 常量"
require_pattern 'native_nostdlib_start_entry_vaddr' "_start entry vaddr helper"
require_pattern 'native_encode_linux_x86_64_nostdlib_start' "_start 编码入口"
require_pattern 'native_encode_linux_x86_64_nostdlib_start\(&code\[0\]' "facade 使用 _start 编码"

tmp_dir="$(mktemp -d /tmp/uya-native-nostdlib-start.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/codegen/native"
cp "$NATIVE_DIR/elf64.uya" "$tmp_dir/codegen/native/elf64.uya"
cp "$NATIVE_DIR/x86_64.uya" "$tmp_dir/codegen/native/x86_64.uya"
cp "$NATIVE_DIR/main.uya" "$tmp_dir/codegen/native/main.uya"
output_path="$tmp_dir/native-start.bin"

cat >"$tmp_dir/main.uya" <<EOF
use std.testing.assert_eq_i32;
use std.testing.expect;
use libc.FILE;
use libc.fopen;
use libc.fread;
use libc.rewind;
use libc.fclose;
use codegen.native;

fn start_bval(buf: &byte, i: usize) i32 {
    return buf[i] as i32;
}

test "native nostdlib start has ELF entry at first code byte" {
    try expect(native_nostdlib_start_entry_vaddr(ELF64_DEFAULT_LOAD_VADDR) ==
        ELF64_DEFAULT_LOAD_VADDR + (ELF64_MIN_EXEC_HEADERS as i64));

    var code: [byte: 16] = [];
    var code_len: usize = 0usize;
    try assert_eq_i32(native_encode_linux_x86_64_nostdlib_start(&code[0], 16usize, &code_len), 0);
    try expect(code_len == X86_64_LINUX_EXIT0_SIZE as usize);
    try assert_eq_i32(start_bval(&code[0], 0usize), 184);  // mov eax, exit
    try assert_eq_i32(start_bval(&code[0], 7usize), 15);   // syscall

    const fp: &FILE = fopen("$output_path" as &const byte, "w+b" as &const byte);
    try expect(fp != null);
    const result: NativeEmitResult = native_emit_linux_x86_64_exit0_stream(fp);
    try assert_eq_i32(result.status, NATIVE_EMIT_STATUS_OK);

    rewind(fp);
    var out: [byte: 160] = [];
    const nread: usize = fread(&out[0], 1usize, result.output_bytes, fp);
    try expect(nread == result.output_bytes);

    // e_entry = 0x400078 => 78 00 40 00 00 00 00 00
    try assert_eq_i32(start_bval(&out[0], 24usize), 120);
    try assert_eq_i32(start_bval(&out[0], 25usize), 0);
    try assert_eq_i32(start_bval(&out[0], 26usize), 64);
    try assert_eq_i32(start_bval(&out[0], 27usize), 0);
    try assert_eq_i32(start_bval(&out[0], ELF64_MIN_EXEC_HEADERS as usize), 184);
    try assert_eq_i32(start_bval(&out[0], (ELF64_MIN_EXEC_HEADERS + 7) as usize), 15);
    _ = fclose(fp);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c --project-root "$tmp_dir/")

echo "✓ native nostdlib _start verified"
