#!/bin/bash
# Uya Mini 编译器测试程序运行脚本
# 自动编译和运行所有测试程序，验证编译器生成的二进制正确性

COMPILER="./build/compiler-mini"
TEST_DIR="tests/programs"
BUILD_DIR="$TEST_DIR/build"
PASSED=0
FAILED=0

# 检查编译器是否存在
if [ ! -f "$COMPILER" ]; then
    echo "错误: 编译器 '$COMPILER' 不存在"
    echo "请先运行 'make build' 构建编译器"
    exit 1
fi

# 检查测试目录是否存在
if [ ! -d "$TEST_DIR" ]; then
    echo "错误: 测试目录 '$TEST_DIR' 不存在"
    exit 1
fi

# 创建构建输出目录
mkdir -p "$BUILD_DIR"

echo "开始运行 Uya 测试程序..."
echo ""

# 遍历所有 .uya 文件
for uya_file in "$TEST_DIR"/*.uya; do
    if [ -f "$uya_file" ]; then
        base_name=$(basename "$uya_file" .uya)
        echo "测试: $base_name"
        
        # 编译（生成目标文件）
        $COMPILER "$uya_file" -o "$BUILD_DIR/${base_name}.o"
        if [ $? -ne 0 ]; then
            echo "  ❌ 编译失败"
            FAILED=$((FAILED + 1))
            continue
        fi
        
        # 链接目标文件为可执行文件
        gcc "$BUILD_DIR/${base_name}.o" -o "$BUILD_DIR/$base_name"
        if [ $? -ne 0 ]; then
            echo "  ❌ 链接失败"
            FAILED=$((FAILED + 1))
            continue
        fi
        
        # 运行
        "$BUILD_DIR/$base_name"
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo "  ✓ 测试通过"
            PASSED=$((PASSED + 1))
        else
            echo "  ❌ 测试失败（退出码: $exit_code）"
            FAILED=$((FAILED + 1))
        fi
    fi
done

echo ""
echo "================================"
echo "总计: $((PASSED + FAILED)) 个测试"
echo "通过: $PASSED"
echo "失败: $FAILED"
echo "================================"

if [ $FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi

