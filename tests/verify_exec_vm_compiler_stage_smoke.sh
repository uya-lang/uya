#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${REPO_ROOT}/lib/"

TMP_COMPILER="$(mktemp /tmp/uya_exec_stage_smoke_bin.XXXXXX)"
TMP_STDOUT="$(mktemp)"
TMP_STDERR="$(mktemp)"
trap 'rm -f "$TMP_COMPILER" "$TMP_STDOUT" "$TMP_STDERR"' EXIT

echo "重编当前源码得到 staged smoke 编译器..."
"$COMPILER" build src/main.uya -o "$TMP_COMPILER" --no-safety-proof >"$TMP_STDOUT" 2>"$TMP_STDERR"
if [ ! -x "$TMP_COMPILER" ]; then
    echo "✗ staged smoke 编译器未生成"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  self-hosted smoke compiler ✓"

verify_src_main_vm_usage_path() {
    local label="$1"
    shift

    set +e
    "$TMP_COMPILER" run --vm src/main.uya "$@" >"$TMP_STDOUT" 2>"$TMP_STDERR"
    local status="$?"
    set -e

    if [ "$status" -ne 1 ]; then
        echo "✗ $label staged smoke returned unexpected status $status"
        cat "$TMP_STDERR"
        exit 1
    fi
    grep -q 'exec vm 运行耗时' "$TMP_STDERR"
    grep -q '程序运行返回码：1' "$TMP_STDERR"
    if grep -q 'exec backend 失败' "$TMP_STDERR" ||
        grep -q 'exec unsupported' "$TMP_STDERR" ||
        grep -q 'exec: 当前不支持' "$TMP_STDERR" ||
        grep -q 'frame slot 超出上限' "$TMP_STDERR" ||
        grep -q 'VM frame slot 超限' "$TMP_STDERR"; then
        echo "✗ $label staged smoke hit an exec backend blocker"
        cat "$TMP_STDERR"
        exit 1
    fi
}

echo "验证默认 proof 路线可完成 src/main.uya exec VM usage 路径..."
verify_src_main_vm_usage_path "default proof"
echo "  default proof src/main.uya --vm usage path ✓"

echo "验证 --no-safety-proof 路线可完成 src/main.uya exec VM usage 路径..."
verify_src_main_vm_usage_path "no-safety-proof" --no-safety-proof
echo "  no-safety-proof src/main.uya --vm usage path ✓"

# 8MB 栈硬上限是 Linux 常见默认值。编译器若把 UPMPackageBuildPlan 这类 4.6MB
# 结构留在 main_main 栈上，会在 upm 依赖解析路径直接 SIGSEGV（rc=139）。
# 这里在受限栈下重跑同一条 usage 路径，防止该回归再次引入。
echo "验证 8MB 栈上限下 src/main.uya --vm usage 路径不崩溃..."
if (ulimit -s 8192) 2>/dev/null; then
    set +e
    (ulimit -s 8192; "$TMP_COMPILER" run --vm src/main.uya >"$TMP_STDOUT" 2>"$TMP_STDERR")
    low_stack_status=$?
    set -e
    if [ "$low_stack_status" -ne 1 ]; then
        echo "✗ 8MB 栈下 staged smoke 返回意外状态 $low_stack_status（139 表示段错误）"
        cat "$TMP_STDERR"
        exit 1
    fi
    echo "  8MB 栈 src/main.uya --vm usage path ✓"
else
    echo "  当前环境不支持调整栈上限，跳过"
fi

echo "✓ exec vm compiler staged smoke passed"
