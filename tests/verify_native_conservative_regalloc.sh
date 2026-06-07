#!/usr/bin/env bash

# Phase 9：验证 native v1 保守寄存器分配器。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ABI_FILE="$REPO_ROOT/src/codegen/native/abi.uya"

if [[ ! -f "$ABI_FILE" ]]; then
    echo "错误: 缺少 $ABI_FILE" >&2
    exit 1
fi

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$ABI_FILE"; then
        echo "错误: 寄存器分配实现缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'export struct NativeRegAllocState' "寄存器分配状态"
require_pattern 'export struct NativeRegAllocResult' "寄存器分配结果"
require_pattern 'native_reg_alloc_gpr' "scratch GPR 顺序"
require_pattern 'native_reg_alloc_begin' "分配器初始化"
require_pattern 'native_reg_alloc_value' "值分配入口"
require_pattern 'native_reg_alloc_finalize_frame' "spill frame finalize"
require_pattern 'NATIVE_REG_ALLOC_GPR_COUNT: i32 = 7' "保守 GPR 数量"

tmp_dir="$(mktemp -d /tmp/uya-native-regalloc.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

{
    cat <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

EOF
    cat "$ABI_FILE"
    cat <<'EOF'

test "conservative register allocator hands out scratch GPRs first" {
    try assert_eq_i32(native_reg_alloc_gpr(0), NATIVE_ABI_REG_R10);
    try assert_eq_i32(native_reg_alloc_gpr(1), NATIVE_ABI_REG_R11);
    try assert_eq_i32(native_reg_alloc_gpr(2), NATIVE_ABI_REG_RAX);
    try assert_eq_i32(native_reg_alloc_gpr(3), NATIVE_ABI_REG_RCX);
    try assert_eq_i32(native_reg_alloc_gpr(4), NATIVE_ABI_REG_RDX);
    try assert_eq_i32(native_reg_alloc_gpr(5), NATIVE_ABI_REG_R8);
    try assert_eq_i32(native_reg_alloc_gpr(6), NATIVE_ABI_REG_R9);
    try assert_eq_i32(native_reg_alloc_gpr(7), NATIVE_ABI_REG_NONE);

    var state: NativeRegAllocState = native_reg_alloc_begin();
    var i: i32 = 0;
    while i < NATIVE_REG_ALLOC_GPR_COUNT {
        const alloc: NativeRegAllocResult = native_reg_alloc_value(&state, 8, 8);
        try assert_eq_i32(alloc.kind, NATIVE_REG_ALLOC_REGISTER);
        try assert_eq_i32(alloc.reg, native_reg_alloc_gpr(i));
        i = i + 1;
    }
    try assert_eq_i32(state.allocated_regs, NATIVE_REG_ALLOC_GPR_COUNT);
    try assert_eq_i32(state.spill_slots, 0);
    try assert_eq_i32(state.value_count, NATIVE_REG_ALLOC_GPR_COUNT);
}

test "conservative register allocator spills after GPRs and for wide values" {
    var state: NativeRegAllocState = native_reg_alloc_begin();
    var i: i32 = 0;
    while i < NATIVE_REG_ALLOC_GPR_COUNT {
        _ = native_reg_alloc_value(&state, 8, 8);
        i = i + 1;
    }
    const spill0: NativeRegAllocResult = native_reg_alloc_value(&state, 8, 8);
    try assert_eq_i32(spill0.kind, NATIVE_REG_ALLOC_SPILL);
    try assert_eq_i32(spill0.reg, NATIVE_ABI_REG_NONE);
    try assert_eq_i32(spill0.stack_offset, -8);

    const spill1: NativeRegAllocResult = native_reg_alloc_value(&state, 16, 8);
    try assert_eq_i32(spill1.kind, NATIVE_REG_ALLOC_SPILL);
    try assert_eq_i32(spill1.stack_offset, -24);
    try assert_eq_i32(state.spill_slots, 2);
    try assert_eq_i32(native_reg_alloc_finalize_frame(&state), 32);
    try assert_eq_i32(state.frame.frame_size, 32);
}

test "conservative register allocator rejects invalid values" {
    var state: NativeRegAllocState = native_reg_alloc_begin();
    const bad: NativeRegAllocResult = native_reg_alloc_value(&state, 0, 8);
    try assert_eq_i32(bad.kind, NATIVE_REG_ALLOC_INVALID);
    try assert_eq_i32(state.value_count, 0);
    try assert_eq_i32(native_reg_alloc_finalize_frame(null), 0);
    try expect(state.frame.frame_size == 0);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native conservative register allocation verified"
