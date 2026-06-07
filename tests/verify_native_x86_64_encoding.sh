#!/usr/bin/env bash

# Phase 9：验证 native x86_64 基础编码层存在，并锁定关键指令的字节输出。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
X86_FILE="$REPO_ROOT/src/codegen/native/x86_64.uya"

if [[ ! -f "$X86_FILE" ]]; then
    echo "错误: 缺少 $X86_FILE" >&2
    exit 1
fi

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$X86_FILE"; then
        echo "错误: x86_64 编码层缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'X86_64_REG_RAX' "通用寄存器编号常量"
require_pattern 'X86_64_REX_BASE' "REX prefix 常量"
require_pattern 'x86_64_rex' "REX 组合 helper"
require_pattern 'x86_64_modrm' "ModRM 组合 helper"
require_pattern 'x86_64_emit_mov_r32_imm32' "mov r32, imm32 编码"
require_pattern 'x86_64_emit_mov_r64_imm64' "mov r64, imm64 编码"
require_pattern 'x86_64_emit_xor_r32_r32' "xor r32, r32 编码"
require_pattern 'x86_64_emit_syscall' "syscall 编码"
require_pattern 'x86_64_emit_linux_exit0' "Linux exit(0) 最小序列"

tmp_dir="$(mktemp -d /tmp/uya-native-x86-64.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

{
    cat <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

EOF
    cat "$X86_FILE"
    cat <<'EOF'

fn bval(buf: &byte, i: usize) i32 {
    return buf[i] as i32;
}

test "x86_64 REX, ModRM and register helpers" {
    try assert_eq_i32(x86_64_is_gpr(X86_64_REG_RAX), 1);
    try assert_eq_i32(x86_64_is_gpr(X86_64_REG_R15), 1);
    try assert_eq_i32(x86_64_is_gpr(16), 0);
    try assert_eq_i32(x86_64_gpr_low3(X86_64_REG_RAX), 0);
    try assert_eq_i32(x86_64_gpr_low3(X86_64_REG_R9), 1);
    try assert_eq_i32(x86_64_gpr_needs_rex(X86_64_REG_RDI), 0);
    try assert_eq_i32(x86_64_gpr_needs_rex(X86_64_REG_R8), 1);
    try assert_eq_i32(x86_64_rex(1, 0, 0, 0), 72);    // 0x48
    try assert_eq_i32(x86_64_rex(1, 1, 0, 1), 77);    // 0x4d
    try assert_eq_i32(x86_64_modrm(3, X86_64_REG_RDI, X86_64_REG_RDI), 255);
    try assert_eq_i32(x86_64_modrm(4, 0, 0), -1);
}

test "x86_64 mov and xor encode exact bytes" {
    var buf: [byte: 64] = [];
    var pos: usize = 0usize;

    try assert_eq_i32(x86_64_emit_mov_r32_imm32(&buf[0], 64usize, &pos, X86_64_REG_RAX, 60), 0);
    try expect(pos == 5usize);
    try assert_eq_i32(bval(&buf[0], 0usize), 184);  // b8
    try assert_eq_i32(bval(&buf[0], 1usize), 60);
    try assert_eq_i32(bval(&buf[0], 2usize), 0);
    try assert_eq_i32(bval(&buf[0], 3usize), 0);
    try assert_eq_i32(bval(&buf[0], 4usize), 0);

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_mov_r32_imm32(&buf[0], 64usize, &pos, X86_64_REG_R8, -1), 0);
    try expect(pos == 6usize);
    try assert_eq_i32(bval(&buf[0], 0usize), 65);   // REX.B
    try assert_eq_i32(bval(&buf[0], 1usize), 184);  // b8 + low3(r8)
    try assert_eq_i32(bval(&buf[0], 2usize), 255);
    try assert_eq_i32(bval(&buf[0], 3usize), 255);
    try assert_eq_i32(bval(&buf[0], 4usize), 255);
    try assert_eq_i32(bval(&buf[0], 5usize), 255);

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_xor_r32_r32(&buf[0], 64usize, &pos, X86_64_REG_RDI, X86_64_REG_RDI), 0);
    try expect(pos == 2usize);
    try assert_eq_i32(bval(&buf[0], 0usize), 49);   // 31
    try assert_eq_i32(bval(&buf[0], 1usize), 255);  // ff

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_mov_r64_imm64(&buf[0], 64usize, &pos, X86_64_REG_R9, 72623859790382856i64), 0);
    try expect(pos == 10usize);
    try assert_eq_i32(bval(&buf[0], 0usize), 73);   // REX.W|B
    try assert_eq_i32(bval(&buf[0], 1usize), 185);  // b8 + low3(r9)
    try assert_eq_i32(bval(&buf[0], 2usize), 8);
    try assert_eq_i32(bval(&buf[0], 3usize), 7);
    try assert_eq_i32(bval(&buf[0], 4usize), 6);
    try assert_eq_i32(bval(&buf[0], 5usize), 5);
    try assert_eq_i32(bval(&buf[0], 6usize), 4);
    try assert_eq_i32(bval(&buf[0], 7usize), 3);
    try assert_eq_i32(bval(&buf[0], 8usize), 2);
    try assert_eq_i32(bval(&buf[0], 9usize), 1);
}

test "x86_64 syscall, ret and linux exit0 encode exact bytes" {
    var buf: [byte: 16] = [];
    var pos: usize = 0usize;

    try assert_eq_i32(x86_64_emit_syscall(&buf[0], 16usize, &pos), 0);
    try assert_eq_i32(x86_64_emit_ret(&buf[0], 16usize, &pos), 0);
    try expect(pos == 3usize);
    try assert_eq_i32(bval(&buf[0], 0usize), 15);
    try assert_eq_i32(bval(&buf[0], 1usize), 5);
    try assert_eq_i32(bval(&buf[0], 2usize), 195);

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_linux_exit0(&buf[0], 16usize, &pos), 0);
    try expect(pos == X86_64_LINUX_EXIT0_SIZE as usize);
    try assert_eq_i32(bval(&buf[0], 0usize), 184);  // mov eax, 60
    try assert_eq_i32(bval(&buf[0], 1usize), 60);
    try assert_eq_i32(bval(&buf[0], 2usize), 0);
    try assert_eq_i32(bval(&buf[0], 3usize), 0);
    try assert_eq_i32(bval(&buf[0], 4usize), 0);
    try assert_eq_i32(bval(&buf[0], 5usize), 49);   // xor edi, edi
    try assert_eq_i32(bval(&buf[0], 6usize), 255);
    try assert_eq_i32(bval(&buf[0], 7usize), 15);   // syscall
    try assert_eq_i32(bval(&buf[0], 8usize), 5);

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_linux_exit0(&buf[0], 8usize, &pos), -1);
    try expect(pos == 0usize);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native x86_64 byte encoding verified"
