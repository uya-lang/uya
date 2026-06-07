#!/usr/bin/env bash

# Phase 9：验证 native x86_64 整数/指针基础指令编码。

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
        echo "错误: x86_64 基础指令编码缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'x86_64_emit_mov_r64_r64' "寄存器 mov"
require_pattern 'x86_64_emit_add_r64_r64' "寄存器 add"
require_pattern 'x86_64_emit_sub_r64_r64' "寄存器 sub"
require_pattern 'x86_64_emit_cmp_r64_r64' "寄存器 cmp"
require_pattern 'x86_64_emit_add_r64_imm32' "imm32 add"
require_pattern 'x86_64_emit_sub_r64_imm32' "imm32 sub"
require_pattern 'x86_64_emit_load_r64_base_disp32' "指针 load"
require_pattern 'x86_64_emit_store_r64_base_disp32' "指针 store"
require_pattern 'x86_64_emit_lea_r64_base_disp32' "指针 lea"

tmp_dir="$(mktemp -d /tmp/uya-native-x86-int-ptr.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

{
    cat <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

EOF
    cat "$X86_FILE"
    cat <<'EOF'

fn ip_bval(buf: &byte, i: usize) i32 {
    return buf[i] as i32;
}

test "x86_64 register integer operations encode exact bytes" {
    var buf: [byte: 64] = [];
    var pos: usize = 0usize;

    try assert_eq_i32(x86_64_emit_mov_r64_r64(&buf[0], 64usize, &pos, X86_64_REG_RAX, X86_64_REG_R10), 0);
    try expect(pos == 3usize);
    try assert_eq_i32(ip_bval(&buf[0], 0usize), 76);   // REX.W|R
    try assert_eq_i32(ip_bval(&buf[0], 1usize), 137);  // 89
    try assert_eq_i32(ip_bval(&buf[0], 2usize), 208);  // d0

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_add_r64_r64(&buf[0], 64usize, &pos, X86_64_REG_RAX, X86_64_REG_RCX), 0);
    try assert_eq_i32(ip_bval(&buf[0], 0usize), 72);   // REX.W
    try assert_eq_i32(ip_bval(&buf[0], 1usize), 1);    // 01
    try assert_eq_i32(ip_bval(&buf[0], 2usize), 200);  // c8

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_sub_r64_r64(&buf[0], 64usize, &pos, X86_64_REG_R8, X86_64_REG_R9), 0);
    try assert_eq_i32(ip_bval(&buf[0], 0usize), 77);   // REX.W|R|B
    try assert_eq_i32(ip_bval(&buf[0], 1usize), 41);   // 29
    try assert_eq_i32(ip_bval(&buf[0], 2usize), 200);  // c8

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_cmp_r64_r64(&buf[0], 64usize, &pos, X86_64_REG_RDX, X86_64_REG_R11), 0);
    try assert_eq_i32(ip_bval(&buf[0], 0usize), 76);   // REX.W|R
    try assert_eq_i32(ip_bval(&buf[0], 1usize), 57);   // 39
    try assert_eq_i32(ip_bval(&buf[0], 2usize), 218);  // da
}

test "x86_64 immediate integer operations encode exact bytes" {
    var buf: [byte: 64] = [];
    var pos: usize = 0usize;

    try assert_eq_i32(x86_64_emit_add_r64_imm32(&buf[0], 64usize, &pos, X86_64_REG_RAX, 5), 0);
    try expect(pos == 7usize);
    try assert_eq_i32(ip_bval(&buf[0], 0usize), 72);   // REX.W
    try assert_eq_i32(ip_bval(&buf[0], 1usize), 129);  // 81
    try assert_eq_i32(ip_bval(&buf[0], 2usize), 192);  // /0 rax
    try assert_eq_i32(ip_bval(&buf[0], 3usize), 5);
    try assert_eq_i32(ip_bval(&buf[0], 4usize), 0);

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_sub_r64_imm32(&buf[0], 64usize, &pos, X86_64_REG_R9, -1), 0);
    try assert_eq_i32(ip_bval(&buf[0], 0usize), 73);   // REX.W|B
    try assert_eq_i32(ip_bval(&buf[0], 1usize), 129);  // 81
    try assert_eq_i32(ip_bval(&buf[0], 2usize), 233);  // /5 r9
    try assert_eq_i32(ip_bval(&buf[0], 3usize), 255);
    try assert_eq_i32(ip_bval(&buf[0], 4usize), 255);
    try assert_eq_i32(ip_bval(&buf[0], 5usize), 255);
    try assert_eq_i32(ip_bval(&buf[0], 6usize), 255);
}

test "x86_64 pointer load store and lea encode exact bytes" {
    var buf: [byte: 64] = [];
    var pos: usize = 0usize;

    try assert_eq_i32(x86_64_emit_load_r64_base_disp32(&buf[0], 64usize, &pos, X86_64_REG_RAX, X86_64_REG_RBP, -8), 0);
    try expect(pos == 7usize);
    try assert_eq_i32(ip_bval(&buf[0], 0usize), 72);   // REX.W
    try assert_eq_i32(ip_bval(&buf[0], 1usize), 139);  // 8b
    try assert_eq_i32(ip_bval(&buf[0], 2usize), 133);  // mod=2 reg=rax rm=rbp
    try assert_eq_i32(ip_bval(&buf[0], 3usize), 248);  // -8 disp32
    try assert_eq_i32(ip_bval(&buf[0], 4usize), 255);
    try assert_eq_i32(ip_bval(&buf[0], 5usize), 255);
    try assert_eq_i32(ip_bval(&buf[0], 6usize), 255);

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_store_r64_base_disp32(&buf[0], 64usize, &pos, X86_64_REG_RSP, 16, X86_64_REG_R10), 0);
    try expect(pos == 8usize);
    try assert_eq_i32(ip_bval(&buf[0], 0usize), 76);   // REX.W|R
    try assert_eq_i32(ip_bval(&buf[0], 1usize), 137);  // 89
    try assert_eq_i32(ip_bval(&buf[0], 2usize), 148);  // mod=2 reg=r10 rm=sib
    try assert_eq_i32(ip_bval(&buf[0], 3usize), 36);   // sib: none,rsp
    try assert_eq_i32(ip_bval(&buf[0], 4usize), 16);

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_lea_r64_base_disp32(&buf[0], 64usize, &pos, X86_64_REG_R11, X86_64_REG_R12, 32), 0);
    try expect(pos == 8usize);
    try assert_eq_i32(ip_bval(&buf[0], 0usize), 77);   // REX.W|R|B
    try assert_eq_i32(ip_bval(&buf[0], 1usize), 141);  // 8d
    try assert_eq_i32(ip_bval(&buf[0], 2usize), 156);  // mod=2 reg=r11 rm=sib
    try assert_eq_i32(ip_bval(&buf[0], 3usize), 36);   // sib: none,r12
    try assert_eq_i32(ip_bval(&buf[0], 4usize), 32);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native x86_64 integer/pointer instruction encoding verified"
