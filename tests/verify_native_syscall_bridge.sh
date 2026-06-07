#!/usr/bin/env bash

# Phase 9：验证 native Linux x86_64 syscall bridge 的 ABI 寄存器约定和编码。

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
        echo "错误: native syscall bridge 缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'X86_64_LINUX_SYSCALL_MAX_ARGS' "syscall 最大参数数"
require_pattern 'X86_64_LINUX_SYSCALL_NR_REG' "syscall number 寄存器"
require_pattern 'x86_64_linux_syscall_arg_reg' "syscall 参数寄存器映射"
require_pattern 'x86_64_linux_syscall_clobbers' "syscall clobber 集合"
require_pattern 'x86_64_linux_syscall_imm_size' "syscall bridge 长度计算"
require_pattern 'x86_64_emit_linux_syscall_imm' "syscall bridge 编码入口"

tmp_dir="$(mktemp -d /tmp/uya-native-syscall-bridge.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

{
    cat <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

EOF
    cat "$X86_FILE"
    cat <<'EOF'

fn syscall_bval(buf: &byte, i: usize) i32 {
    return buf[i] as i32;
}

test "linux syscall bridge exposes ABI register metadata" {
    try assert_eq_i32(x86_64_linux_syscall_arg_reg(0), X86_64_REG_RDI);
    try assert_eq_i32(x86_64_linux_syscall_arg_reg(1), X86_64_REG_RSI);
    try assert_eq_i32(x86_64_linux_syscall_arg_reg(2), X86_64_REG_RDX);
    try assert_eq_i32(x86_64_linux_syscall_arg_reg(3), X86_64_REG_R10);
    try assert_eq_i32(x86_64_linux_syscall_arg_reg(4), X86_64_REG_R8);
    try assert_eq_i32(x86_64_linux_syscall_arg_reg(5), X86_64_REG_R9);
    try assert_eq_i32(x86_64_linux_syscall_arg_reg(6), -1);
    try assert_eq_i32(x86_64_linux_syscall_clobbers(X86_64_REG_RCX), 1);
    try assert_eq_i32(x86_64_linux_syscall_clobbers(X86_64_REG_R11), 1);
    try assert_eq_i32(x86_64_linux_syscall_clobbers(X86_64_REG_RAX), 0);
    try assert_eq_i32(x86_64_linux_syscall_clobbers(99), -1);
    try assert_eq_i32(x86_64_linux_syscall_imm_size(0), 7);
    try assert_eq_i32(x86_64_linux_syscall_imm_size(6), 67);
    try assert_eq_i32(x86_64_linux_syscall_imm_size(7), -1);
}

test "linux syscall bridge encodes zero arg syscall" {
    var buf: [byte: 80] = [];
    var pos: usize = 0usize;
    try assert_eq_i32(x86_64_emit_linux_syscall_imm(&buf[0], 80usize, &pos, 39, null, 0), 0);
    try expect(pos == 7usize);
    try assert_eq_i32(syscall_bval(&buf[0], 0usize), 184);  // mov eax, 39
    try assert_eq_i32(syscall_bval(&buf[0], 1usize), 39);
    try assert_eq_i32(syscall_bval(&buf[0], 2usize), 0);
    try assert_eq_i32(syscall_bval(&buf[0], 3usize), 0);
    try assert_eq_i32(syscall_bval(&buf[0], 4usize), 0);
    try assert_eq_i32(syscall_bval(&buf[0], 5usize), 15);   // syscall
    try assert_eq_i32(syscall_bval(&buf[0], 6usize), 5);
}

test "linux syscall bridge encodes six arg syscall register order" {
    var buf: [byte: 80] = [];
    var args: [i64: 6] = [];
    args[0] = 1i64;
    args[1] = 2i64;
    args[2] = 3i64;
    args[3] = 4i64;
    args[4] = 5i64;
    args[5] = 6i64;
    var pos: usize = 0usize;
    try assert_eq_i32(x86_64_emit_linux_syscall_imm(&buf[0], 80usize, &pos, 1, &args[0], 6), 0);
    try expect(pos == 67usize);

    try assert_eq_i32(syscall_bval(&buf[0], 0usize), 184);   // mov eax, 1
    try assert_eq_i32(syscall_bval(&buf[0], 1usize), 1);
    try assert_eq_i32(syscall_bval(&buf[0], 5usize), 72);    // mov rdi, 1
    try assert_eq_i32(syscall_bval(&buf[0], 6usize), 191);
    try assert_eq_i32(syscall_bval(&buf[0], 15usize), 72);   // mov rsi, 2
    try assert_eq_i32(syscall_bval(&buf[0], 16usize), 190);
    try assert_eq_i32(syscall_bval(&buf[0], 25usize), 72);   // mov rdx, 3
    try assert_eq_i32(syscall_bval(&buf[0], 26usize), 186);
    try assert_eq_i32(syscall_bval(&buf[0], 35usize), 73);   // mov r10, 4
    try assert_eq_i32(syscall_bval(&buf[0], 36usize), 186);
    try assert_eq_i32(syscall_bval(&buf[0], 45usize), 73);   // mov r8, 5
    try assert_eq_i32(syscall_bval(&buf[0], 46usize), 184);
    try assert_eq_i32(syscall_bval(&buf[0], 55usize), 73);   // mov r9, 6
    try assert_eq_i32(syscall_bval(&buf[0], 56usize), 185);
    try assert_eq_i32(syscall_bval(&buf[0], 65usize), 15);   // syscall
    try assert_eq_i32(syscall_bval(&buf[0], 66usize), 5);

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_linux_syscall_imm(&buf[0], 66usize, &pos, 1, &args[0], 6), -1);
    try expect(pos == 0usize);
    try assert_eq_i32(x86_64_emit_linux_syscall_imm(&buf[0], 80usize, &pos, 1, null, 1), -1);
    try expect(pos == 0usize);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native syscall bridge verified"
