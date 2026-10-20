#!/bin/bash
# 饱和 / 包装运算符的 C99 ↔ exec VM 一致性验证
#
# 背景：C99 后端曾把 u8/u16/u32 的饱和边界错写成有符号极值
# （`uint8_t` 里含子串 `int8`），使得 `255 +| 1` 得到 127，而 VM 得到 255 ——
# 同一份源码在两个后端给出不同结果。本脚本同时跑两条路径并要求都返回 0。
#
# 用法：./tests/verify_saturating_parity.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${REPO_ROOT}/lib/"
TEST_FILE="$SCRIPT_DIR/test_saturating_parity.uya"

FAILED=0
log() { printf '[sat-parity] %s\n' "$*"; }
fail() { printf '[sat-parity] FAIL: %s\n' "$*" >&2; FAILED=1; }

if [ ! -x "$COMPILER" ]; then
    echo "错误: 找不到编译器 $COMPILER" >&2
    exit 1
fi

log "1/3 C99 后端：无符号/有符号饱和与包装语义"
if "$COMPILER" run "$TEST_FILE" > /tmp/uya_sat_c99.log 2>&1; then
    log "  ✓ C99 返回 0"
else
    rc=$?
    fail "C99 返回 $rc（期望 0）"
    cat /tmp/uya_sat_c99.log >&2
fi

log "2/3 exec VM 后端：同一份源码"
if "$COMPILER" run --vm "$TEST_FILE" > /tmp/uya_sat_vm.log 2>&1; then
    log "  ✓ VM 返回 0"
else
    rc=$?
    fail "VM 返回 $rc（期望 0）"
    cat /tmp/uya_sat_vm.log >&2
fi

log "3/3 两个后端结果一致（都通过即等价）"
if [ "$FAILED" -eq 0 ]; then
    log "  ✓ C99 与 VM 语义一致"
fi

echo ""
if [ "$FAILED" -ne 0 ]; then
    echo "✗ 饱和/包装后端一致性验证失败" >&2
    exit 1
fi
echo "✓ 饱和/包装后端一致性验证通过"
