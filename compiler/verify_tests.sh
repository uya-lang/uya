#!/bin/bash

# 验证所有 uya 测试文件生成的 C 代码能否用 gcc 编译

COMPILER="./uyac"
GCC="gcc"
GCC_FLAGS="-std=c99 -Wall -Wextra -pedantic -O2"

TEST_DIR="tests"
OUTPUT_DIR="test_outputs"
TEMP_DIR=$(mktemp -d)

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 统计
TOTAL=0
PASSED=0
FAILED=0
FAILED_FILES=()

echo "开始验证所有测试文件..."
echo "=========================================="

# 查找所有 .uya 文件
find "$TEST_DIR" -name "*.uya" -type f | sort | while read -r uya_file; do
    TOTAL=$((TOTAL + 1))
    
    # 生成输出文件名
    base_name=$(basename "$uya_file" .uya)
    c_file="$OUTPUT_DIR/${base_name}.c"
    obj_file="$TEMP_DIR/${base_name}.o"
    
    echo -n "测试: $uya_file ... "
    
    # 运行 uyac 编译器
    if ! "$COMPILER" "$uya_file" "$c_file" > /dev/null 2>&1; then
        echo "❌ 编译失败 (uyac 错误)"
        FAILED=$((FAILED + 1))
        FAILED_FILES+=("$uya_file (uyac 错误)")
        continue
    fi
    
    # 检查生成的 C 文件是否存在
    if [ ! -f "$c_file" ]; then
        echo "❌ 未生成 C 文件"
        FAILED=$((FAILED + 1))
        FAILED_FILES+=("$uya_file (未生成 C 文件)")
        continue
    fi
    
    # 尝试用 gcc 编译
    if "$GCC" $GCC_FLAGS -c "$c_file" -o "$obj_file" > /dev/null 2>&1; then
        echo "✅ 通过"
        PASSED=$((PASSED + 1))
        rm -f "$obj_file"
    else
        echo "❌ gcc 编译失败"
        FAILED=$((FAILED + 1))
        FAILED_FILES+=("$uya_file")
        # 显示 gcc 错误信息
        echo "   gcc 错误:"
        "$GCC" $GCC_FLAGS -c "$c_file" -o "$obj_file" 2>&1 | sed 's/^/   /'
    fi
done

# 清理临时目录
rm -rf "$TEMP_DIR"

echo ""
echo "=========================================="
echo "验证完成:"
echo "  总计: $TOTAL"
echo "  通过: $PASSED"
echo "  失败: $FAILED"

if [ ${#FAILED_FILES[@]} -gt 0 ]; then
    echo ""
    echo "失败的文件:"
    for file in "${FAILED_FILES[@]}"; do
        echo "  - $file"
    done
    exit 1
else
    echo ""
    echo "🎉 所有测试文件都通过了 gcc 编译验证！"
    exit 0
fi

