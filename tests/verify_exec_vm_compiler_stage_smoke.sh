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

echo "✓ exec vm compiler staged smoke passed"
