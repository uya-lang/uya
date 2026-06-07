#!/usr/bin/env bash

# Phase 5A/L394：验证 native ELF 输出策略：
# - v1 不生成 debug sections；
# - streaming writer 只保留固定 header 临时缓冲，不构造完整 ELF 镜像副本。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NATIVE_DIR="$REPO_ROOT/src/codegen/native"
ELF64_FILE="$NATIVE_DIR/elf64.uya"

if [[ ! -f "$ELF64_FILE" ]]; then
    echo "错误: 缺少 $ELF64_FILE" >&2
    exit 1
fi

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$ELF64_FILE"; then
        echo "错误: native 输出策略缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'export const ELF64_NATIVE_DEBUG_SECTION_COUNT: i32 = 0' "debug section 数量固定为 0"
require_pattern 'export fn elf64_native_debug_section_count' "debug section 策略查询入口"
require_pattern 'export fn elf64_stream_peak_temp_bytes' "streaming writer 临时缓冲上界查询入口"
require_pattern 'export fn elf64_write_executable_stream' "ELF64 streaming 输出入口"
require_pattern 'var headers: \[byte: ELF64_MIN_EXEC_HEADERS\]' "streaming writer 仅保留固定 header 缓冲"
require_pattern 'fwrite\(&headers\[0\] as &const byte, 1usize, headers_size, stream\)' "streaming writer 先写 header"
require_pattern 'fwrite\(code, 1usize, code_len, stream\)' "streaming writer 直接写机器码输入"

if grep -RIn --include='*.uya' '"\.debug' "$NATIVE_DIR" >/dev/null; then
    echo "错误: native 后端源码中出现 .debug* section 字符串" >&2
    exit 1
fi

if grep -nE '\b(malloc|realloc)\b' "$ELF64_FILE" >/dev/null; then
    echo "错误: native ELF 输出路径不应通过 malloc/realloc 构造完整临时镜像" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-native-output-policy.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
output_path="$tmp_dir/native-output.bin"

{
    cat <<EOF
use std.testing.assert_eq_i32;
use std.testing.expect;
use libc.FILE;
use libc.fopen;
use libc.fread;
use libc.rewind;
use libc.fclose;

EOF
    cat "$ELF64_FILE"
    cat <<EOF

fn policy_bval(buf: &byte, i: usize) i32 {
    return buf[i] as i32;
}

test "elf64 streaming writer has no debug sections and no full image temp" {
    var code: [byte: 4] = [];
    code[0] = 1 as byte;
    code[1] = 2 as byte;
    code[2] = 3 as byte;
    code[3] = 4 as byte;

    const fp: &FILE = fopen("$output_path" as &const byte, "w+b" as &const byte);
    try expect(fp != null);

    const total: i32 = ELF64_MIN_EXEC_HEADERS + 4;
    try assert_eq_i32(elf64_write_executable_stream(fp, &code[0] as &const byte, 4usize,
        EM_X86_64, ELF64_DEFAULT_LOAD_VADDR), total);

    rewind(fp);
    var out: [byte: 128] = [];
    const nread: usize = fread(&out[0], 1usize, total as usize, fp);
    try assert_eq_i32(nread as i32, total);

    try assert_eq_i32(policy_bval(&out[0], 0usize), 127);
    try assert_eq_i32(policy_bval(&out[0], 1usize), 69);
    try assert_eq_i32(policy_bval(&out[0], 2usize), 76);
    try assert_eq_i32(policy_bval(&out[0], 3usize), 70);
    try assert_eq_i32(policy_bval(&out[0], 56usize), 1);  // e_phnum
    try assert_eq_i32(policy_bval(&out[0], 60usize), 0);  // e_shnum: no section headers
    try assert_eq_i32(policy_bval(&out[0], 62usize), 0);  // e_shstrndx
    try assert_eq_i32(policy_bval(&out[0], ELF64_MIN_EXEC_HEADERS as usize), 1);
    try assert_eq_i32(policy_bval(&out[0], (ELF64_MIN_EXEC_HEADERS + 1) as usize), 2);
    try assert_eq_i32(policy_bval(&out[0], (ELF64_MIN_EXEC_HEADERS + 2) as usize), 3);
    try assert_eq_i32(policy_bval(&out[0], (ELF64_MIN_EXEC_HEADERS + 3) as usize), 4);

    try assert_eq_i32(elf64_native_debug_section_count(), 0);
    try expect(elf64_stream_peak_temp_bytes(4usize) == ELF64_MIN_EXEC_HEADERS as usize);
    try expect(elf64_stream_peak_temp_bytes(4096usize) == ELF64_MIN_EXEC_HEADERS as usize);

    _ = fclose(fp);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native output policy verified: no debug sections, streaming ELF writer uses fixed header temp"
