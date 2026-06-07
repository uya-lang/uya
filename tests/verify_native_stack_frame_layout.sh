#!/usr/bin/env bash

# Phase 9：验证 native Linux x86_64 SysV 栈帧布局 helper。

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
        echo "错误: 栈帧布局实现缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'export struct NativeStackFrameLayout' "栈帧布局结构"
require_pattern 'export struct NativeStackSlot' "栈 slot 结构"
require_pattern 'native_stack_frame_begin' "栈帧初始化"
require_pattern 'native_stack_frame_add_local' "local slot 分配"
require_pattern 'native_stack_frame_add_spill' "spill slot 分配"
require_pattern 'native_stack_frame_set_outgoing_arg_bytes' "outgoing 参数区预留"
require_pattern 'native_stack_frame_finalize' "frame size finalize"

tmp_dir="$(mktemp -d /tmp/uya-native-stack-frame.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

{
    cat <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

EOF
    cat "$ABI_FILE"
    cat <<'EOF'

test "native stack frame lays out locals spills and outgoing args" {
    var frame: NativeStackFrameLayout = native_stack_frame_begin();
    try assert_eq_i32(frame.uses_frame_pointer, 1);
    try assert_eq_i32(frame.frame_size, 0);

    const local4: NativeStackSlot = native_stack_frame_add_local(&frame, 4, 4);
    try assert_eq_i32(local4.kind, NATIVE_STACK_SLOT_LOCAL);
    try assert_eq_i32(local4.offset, -4);
    try assert_eq_i32(frame.used_bytes, 4);

    const local8: NativeStackSlot = native_stack_frame_add_local(&frame, 8, 8);
    try assert_eq_i32(local8.kind, NATIVE_STACK_SLOT_LOCAL);
    try assert_eq_i32(local8.offset, -16);
    try assert_eq_i32(frame.used_bytes, 16);

    const spill8: NativeStackSlot = native_stack_frame_add_spill(&frame, 8, 8);
    try assert_eq_i32(spill8.kind, NATIVE_STACK_SLOT_SPILL);
    try assert_eq_i32(spill8.offset, -24);
    try assert_eq_i32(frame.used_bytes, 24);
    try assert_eq_i32(frame.slot_count, 3);

    try assert_eq_i32(native_stack_frame_set_outgoing_arg_bytes(&frame, 9), 0);
    try assert_eq_i32(frame.outgoing_arg_bytes, 16);
    try assert_eq_i32(native_stack_frame_finalize(&frame), 48);
    try assert_eq_i32(frame.frame_size, 48);
    try assert_eq_i32(frame.max_align, NATIVE_ABI_SYSV_STACK_ALIGN);
}

test "native stack frame defaults tiny align and rejects invalid slots" {
    var frame: NativeStackFrameLayout = native_stack_frame_begin();
    const tiny: NativeStackSlot = native_stack_frame_add_local(&frame, 1, 0);
    try assert_eq_i32(tiny.kind, NATIVE_STACK_SLOT_LOCAL);
    try assert_eq_i32(tiny.align, 1);
    try assert_eq_i32(tiny.offset, -1);

    const bad: NativeStackSlot = native_stack_frame_add_spill(&frame, 0, 8);
    try assert_eq_i32(bad.kind, NATIVE_STACK_SLOT_INVALID);
    try assert_eq_i32(frame.slot_count, 1);

    try assert_eq_i32(native_stack_frame_set_outgoing_arg_bytes(&frame, -1), -1);
    try assert_eq_i32(native_stack_frame_finalize(&frame), 16);
    try expect(frame.frame_size == 16);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native stack frame layout verified"
