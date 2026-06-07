#!/usr/bin/env bash

# Phase 9：验证 native ABI 基础合同文件存在并可执行基本分类/寄存器查询。

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
        echo "错误: native ABI 合同缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'export struct NativeAbiLocation' "ABI 位置结构"
require_pattern 'export struct NativeAbiSignature' "ABI 签名摘要结构"
require_pattern 'NATIVE_ABI_SYSV_STACK_ALIGN: i32 = 16' "SysV 栈对齐常量"
require_pattern 'NATIVE_ABI_SYSV_GPR_ARG_COUNT: i32 = 6' "SysV GPR 参数寄存器数量"
require_pattern 'NATIVE_ABI_SYSV_SSE_ARG_COUNT: i32 = 8' "SysV SSE 参数寄存器数量"
require_pattern 'native_abi_classify_scalar' "标量 ABI 分类 helper"
require_pattern 'native_abi_sysv_gpr_arg_reg' "SysV GPR 参数寄存器查询 helper"
require_pattern 'native_abi_sysv_sse_arg_reg' "SysV SSE 参数寄存器查询 helper"

tmp_dir="$(mktemp -d /tmp/uya-native-abi-contract.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

{
    cat <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

EOF
    cat "$ABI_FILE"
    cat <<'EOF'

test "native ABI scalar classes and alignment" {
    try assert_eq_i32(native_abi_classify_scalar(0, 0), NATIVE_ABI_CLASS_VOID);
    try assert_eq_i32(native_abi_classify_scalar(1, 0), NATIVE_ABI_CLASS_INTEGER);
    try assert_eq_i32(native_abi_classify_scalar(8, 0), NATIVE_ABI_CLASS_INTEGER);
    try assert_eq_i32(native_abi_classify_scalar(9, 0), NATIVE_ABI_CLASS_MEMORY);
    try assert_eq_i32(native_abi_classify_scalar(4, 1), NATIVE_ABI_CLASS_SSE);
    try assert_eq_i32(native_abi_classify_scalar(8, 1), NATIVE_ABI_CLASS_SSE);
    try assert_eq_i32(native_abi_classify_scalar(3, 1), NATIVE_ABI_CLASS_INVALID);

    try assert_eq_i32(native_abi_align_i32(0, NATIVE_ABI_SYSV_STACK_ALIGN), 0);
    try assert_eq_i32(native_abi_align_i32(1, NATIVE_ABI_SYSV_STACK_ALIGN), 16);
    try assert_eq_i32(native_abi_align_i32(16, NATIVE_ABI_SYSV_STACK_ALIGN), 16);
    try assert_eq_i32(native_abi_align_i32(17, NATIVE_ABI_SYSV_STACK_ALIGN), 32);
}

test "native ABI SysV argument register roles" {
    try assert_eq_i32(native_abi_sysv_gpr_arg_reg(0), NATIVE_ABI_REG_RDI);
    try assert_eq_i32(native_abi_sysv_gpr_arg_reg(1), NATIVE_ABI_REG_RSI);
    try assert_eq_i32(native_abi_sysv_gpr_arg_reg(2), NATIVE_ABI_REG_RDX);
    try assert_eq_i32(native_abi_sysv_gpr_arg_reg(3), NATIVE_ABI_REG_RCX);
    try assert_eq_i32(native_abi_sysv_gpr_arg_reg(4), NATIVE_ABI_REG_R8);
    try assert_eq_i32(native_abi_sysv_gpr_arg_reg(5), NATIVE_ABI_REG_R9);
    try assert_eq_i32(native_abi_sysv_gpr_arg_reg(6), NATIVE_ABI_REG_NONE);

    try assert_eq_i32(native_abi_sysv_sse_arg_reg(0), NATIVE_ABI_REG_XMM0);
    try assert_eq_i32(native_abi_sysv_sse_arg_reg(7), NATIVE_ABI_REG_XMM0 + 7);
    try assert_eq_i32(native_abi_sysv_sse_arg_reg(8), NATIVE_ABI_REG_NONE);

    const loc: NativeAbiLocation = native_abi_empty_location();
    try assert_eq_i32(loc.class, NATIVE_ABI_CLASS_INVALID);
    try assert_eq_i32(loc.role, NATIVE_ABI_ROLE_NONE);
    try assert_eq_i32(loc.reg, NATIVE_ABI_REG_NONE);
    try expect(NATIVE_ABI_SYSV_GPR_ARG_COUNT == 6);
    try expect(NATIVE_ABI_SYSV_SSE_ARG_COUNT == 8);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native ABI contract verified"
