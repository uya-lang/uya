#!/usr/bin/env bash

# Phase 9：验证 Linux x86_64 SysV 标量调用约定分配器。

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
        echo "错误: SysV ABI 实现缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'native_abi_sysv_signature_begin' "SysV 签名摘要入口"
require_pattern 'native_abi_sysv_return_location' "SysV 返回值位置分配"
require_pattern 'native_abi_sysv_place_arg' "SysV 参数位置分配"
require_pattern 'NATIVE_ABI_ROLE_STACK_ARG' "栈参数角色"
require_pattern 'NATIVE_ABI_ROLE_MEMORY_RETURN' "memory return 角色"
require_pattern 'native_abi_sysv_aligned_stack_arg_bytes' "call-site 栈参数对齐"

tmp_dir="$(mktemp -d /tmp/uya-native-sysv-abi.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

{
    cat <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

EOF
    cat "$ABI_FILE"
    cat <<'EOF'

test "SysV return locations classify scalar and memory returns" {
    const r_i64: NativeAbiLocation = native_abi_sysv_return_location(8, 0);
    try assert_eq_i32(r_i64.class, NATIVE_ABI_CLASS_INTEGER);
    try assert_eq_i32(r_i64.role, NATIVE_ABI_ROLE_GPR_RETURN);
    try assert_eq_i32(r_i64.reg, NATIVE_ABI_REG_RAX);

    const r_f64: NativeAbiLocation = native_abi_sysv_return_location(8, 1);
    try assert_eq_i32(r_f64.class, NATIVE_ABI_CLASS_SSE);
    try assert_eq_i32(r_f64.role, NATIVE_ABI_ROLE_SSE_RETURN);
    try assert_eq_i32(r_f64.reg, NATIVE_ABI_REG_XMM0);

    const r_void: NativeAbiLocation = native_abi_sysv_return_location(0, 0);
    try assert_eq_i32(r_void.class, NATIVE_ABI_CLASS_VOID);
    try assert_eq_i32(r_void.role, NATIVE_ABI_ROLE_NONE);
    try assert_eq_i32(r_void.reg, NATIVE_ABI_REG_NONE);

    const r_mem: NativeAbiLocation = native_abi_sysv_return_location(16, 0);
    try assert_eq_i32(r_mem.class, NATIVE_ABI_CLASS_MEMORY);
    try assert_eq_i32(r_mem.role, NATIVE_ABI_ROLE_MEMORY_RETURN);
    try assert_eq_i32(r_mem.reg, NATIVE_ABI_REG_NONE);

    const sret: NativeAbiLocation = native_abi_sysv_sret_pointer_location();
    try assert_eq_i32(sret.role, NATIVE_ABI_ROLE_GPR_ARG);
    try assert_eq_i32(sret.reg, NATIVE_ABI_REG_RDI);
    try assert_eq_i32(sret.size, 8);
}

test "SysV integer arguments use six GPRs then stack slots" {
    var sig: NativeAbiSignature = native_abi_sysv_signature_begin(0, 0);
    const a0: NativeAbiLocation = native_abi_sysv_place_arg(&sig, 8, 0);
    const a1: NativeAbiLocation = native_abi_sysv_place_arg(&sig, 8, 0);
    const a2: NativeAbiLocation = native_abi_sysv_place_arg(&sig, 8, 0);
    const a3: NativeAbiLocation = native_abi_sysv_place_arg(&sig, 8, 0);
    const a4: NativeAbiLocation = native_abi_sysv_place_arg(&sig, 8, 0);
    const a5: NativeAbiLocation = native_abi_sysv_place_arg(&sig, 8, 0);
    const a6: NativeAbiLocation = native_abi_sysv_place_arg(&sig, 4, 0);
    const a7: NativeAbiLocation = native_abi_sysv_place_arg(&sig, 1, 0);

    try assert_eq_i32(a0.reg, NATIVE_ABI_REG_RDI);
    try assert_eq_i32(a1.reg, NATIVE_ABI_REG_RSI);
    try assert_eq_i32(a2.reg, NATIVE_ABI_REG_RDX);
    try assert_eq_i32(a3.reg, NATIVE_ABI_REG_RCX);
    try assert_eq_i32(a4.reg, NATIVE_ABI_REG_R8);
    try assert_eq_i32(a5.reg, NATIVE_ABI_REG_R9);
    try assert_eq_i32(a6.role, NATIVE_ABI_ROLE_STACK_ARG);
    try assert_eq_i32(a6.stack_offset, 0);
    try assert_eq_i32(a7.role, NATIVE_ABI_ROLE_STACK_ARG);
    try assert_eq_i32(a7.stack_offset, 8);
    try assert_eq_i32(sig.arg_count, 8);
    try assert_eq_i32(sig.gpr_arg_count, 6);
    try assert_eq_i32(sig.stack_arg_bytes, 16);
    try assert_eq_i32(native_abi_sysv_aligned_stack_arg_bytes(&sig), 16);
}

test "SysV SSE arguments use eight XMM registers then stack" {
    var sig: NativeAbiSignature = native_abi_sysv_signature_begin(8, 1);
    var i: i32 = 0;
    while i < 8 {
        const loc: NativeAbiLocation = native_abi_sysv_place_arg(&sig, 8, 1);
        try assert_eq_i32(loc.role, NATIVE_ABI_ROLE_SSE_ARG);
        try assert_eq_i32(loc.reg, NATIVE_ABI_REG_XMM0 + i);
        i = i + 1;
    }
    const overflow: NativeAbiLocation = native_abi_sysv_place_arg(&sig, 8, 1);
    try assert_eq_i32(overflow.class, NATIVE_ABI_CLASS_SSE);
    try assert_eq_i32(overflow.role, NATIVE_ABI_ROLE_STACK_ARG);
    try assert_eq_i32(overflow.stack_offset, 0);
    try assert_eq_i32(sig.sse_arg_count, 8);
    try assert_eq_i32(sig.stack_arg_bytes, 8);
    try assert_eq_i32(native_abi_sysv_aligned_stack_arg_bytes(&sig), 16);
}

test "SysV memory arguments are assigned to aligned stack slots" {
    var sig: NativeAbiSignature = native_abi_sysv_signature_begin(0, 0);
    const mem0: NativeAbiLocation = native_abi_sysv_place_arg(&sig, 24, 0);
    const mem1: NativeAbiLocation = native_abi_sysv_place_arg(&sig, 9, 0);
    try assert_eq_i32(mem0.class, NATIVE_ABI_CLASS_MEMORY);
    try assert_eq_i32(mem0.role, NATIVE_ABI_ROLE_STACK_ARG);
    try assert_eq_i32(mem0.stack_offset, 0);
    try assert_eq_i32(mem1.class, NATIVE_ABI_CLASS_MEMORY);
    try assert_eq_i32(mem1.role, NATIVE_ABI_ROLE_STACK_ARG);
    try assert_eq_i32(mem1.stack_offset, 24);
    try assert_eq_i32(sig.stack_arg_bytes, 40);
    try assert_eq_i32(native_abi_sysv_aligned_stack_arg_bytes(&sig), 48);
    try expect(sig.gpr_arg_count == 0);
    try expect(sig.sse_arg_count == 0);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native SysV calling convention verified"
