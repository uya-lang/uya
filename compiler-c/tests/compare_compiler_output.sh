#!/bin/bash
# 对比 C 编译器与 Uya 编译器对同一 .uya 文件生成的 C 输出
# 用法: ./tests/compare_compiler_output.sh [测试文件或目录]
# 示例: ./tests/compare_compiler_output.sh test_struct_comparison.uya
#       ./tests/compare_compiler_output.sh tests/programs

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

C_COMPILER="./build/compiler-c"
UYA_COMPILER="./build/uya-compiler/compiler"
TEST_DIR="tests/programs"
TMP_DIR="${TMPDIR:-/tmp}/uya_compare_$$"
mkdir -p "$TMP_DIR"
trap "rm -rf '$TMP_DIR'" EXIT

# 收集要测试的文件
FILES=()
if [ $# -eq 0 ]; then
    for f in "$TEST_DIR"/*.uya; do
        [ -f "$f" ] && FILES+=("$f")
    done
else
    for arg in "$@"; do
        if [ -f "$arg" ]; then
            FILES+=("$arg")
        elif [ -f "$TEST_DIR/$arg" ]; then
            FILES+=("$TEST_DIR/$arg")
        elif [ -d "$arg" ]; then
            for f in "$arg"/*.uya; do
                [ -f "$f" ] && FILES+=("$f")
            done
        fi
    done
fi

SAME=0
DIFF=0
FAIL_C=0
FAIL_UYA=0

for uya in "${FILES[@]}"; do
    base=$(basename "$uya" .uya)
    out_c="$TMP_DIR/${base}_c.c"
    out_uya="$TMP_DIR/${base}_uya.c"
    ok_c=false
    ok_uya=false

    if "$C_COMPILER" "$uya" -o "$out_c" --c99 >/dev/null 2>&1; then
        ok_c=true
    fi
    if "$UYA_COMPILER" "$uya" -o "$out_uya" --c99 >/dev/null 2>&1; then
        ok_uya=true
    fi

    if ! $ok_c; then
        echo "[C 失败]   $uya"
        ((FAIL_C++)) || true
        continue
    fi
    if ! $ok_uya; then
        echo "[Uya 失败] $uya"
        ((FAIL_UYA++)) || true
        continue
    fi

    if diff -q "$out_c" "$out_uya" >/dev/null 2>&1; then
        echo "[一致]     $uya"
        ((SAME++)) || true
    else
        echo "[有差异]   $uya"
        ((DIFF++)) || true
        echo "  diff: diff -u $out_c $out_uya"
    fi
done

echo ""
echo "汇总: 一致=$SAME, 有差异=$DIFF, C 编译失败=$FAIL_C, Uya 编译失败=$FAIL_UYA"
echo "详细对比可查看: $TMP_DIR (脚本退出后会被删除)"
echo "或对单个文件: $C_COMPILER <file.uya> -o /tmp/a.c --c99 && $UYA_COMPILER <file.uya> -o /tmp/b.c --c99 && diff -u /tmp/a.c /tmp/b.c"
