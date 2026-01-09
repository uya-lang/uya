#!/bin/bash
# 验证错误处理相关测试程序的正确性

COMPILER="./uyac"
TEST_DIR="tests"
TEMP_DIR="/tmp/uya_error_test_verify"

mkdir -p "$TEMP_DIR"

echo "=========================================="
echo "错误处理测试程序 GCC 验证报告"
echo "=========================================="
echo ""

# 测试文件列表（带main函数的）
declare -a test_files_with_main=(
    "test_error_decl.uya"
    "test_error_decl_usage.uya"
    "test_error_decl_only_used.uya"
    "test_error_decl_all_used.uya"
    "test_error_decl_mixed.uya"
)

# 测试文件列表（不带main，仅编译验证）
declare -a test_files_no_main=(
    "test_error_collision.uya"
)

success_compile=0
success_gcc=0
fail_compile=0
fail_gcc=0

# 验证带main的测试文件
echo "--- 带main函数的测试文件 ---"
for test_file in "${test_files_with_main[@]}"; do
    test_path="$TEST_DIR/$test_file"
    
    if [ ! -f "$test_path" ]; then
        echo "⚠️  跳过: $test_file (文件不存在)"
        continue
    fi
    
    c_file="$TEMP_DIR/${test_file%.uya}_gen.c"
    exe_file="$TEMP_DIR/${test_file%.uya}"
    
    printf "%-40s " "$test_file:"
    
    # Uya编译
    if $COMPILER "$test_path" "$c_file" >/dev/null 2>&1; then
        if [ -f "$c_file" ]; then
            printf "✓Uya "
            ((success_compile++))
            
            # gcc编译
            if gcc -std=c99 -Wall -Wextra -O2 "$c_file" -o "$exe_file" 2>/dev/null; then
                printf "✓gcc "
                ((success_gcc++))
                echo "✅ 通过"
            else
                printf "✗gcc "
                ((fail_gcc++))
                echo "❌ gcc编译失败"
            fi
        else
            printf "✗Uya "
            ((fail_compile++))
            echo "❌ 未生成C文件"
        fi
    else
        printf "✗Uya "
        ((fail_compile++))
        echo "❌ Uya编译失败"
    fi
done

echo ""
echo "--- 仅编译验证的测试文件 ---"
for test_file in "${test_files_no_main[@]}"; do
    test_path="$TEST_DIR/$test_file"
    
    if [ ! -f "$test_path" ]; then
        echo "⚠️  跳过: $test_file (文件不存在)"
        continue
    fi
    
    c_file="$TEMP_DIR/${test_file%.uya}_gen.c"
    
    printf "%-40s " "$test_file:"
    
    # Uya编译
    if $COMPILER "$test_path" "$c_file" >/dev/null 2>&1; then
        if [ -f "$c_file" ]; then
            printf "✓Uya "
            ((success_compile++))
            echo "✅ 通过（无main函数，仅编译验证）"
        else
            printf "✗Uya "
            ((fail_compile++))
            echo "❌ 未生成C文件"
        fi
    else
        printf "✗Uya "
        ((fail_compile++))
        echo "❌ Uya编译失败"
    fi
done

echo ""
echo "--- 重复定义检测验证 ---"
printf "%-40s " "test_error_decl_duplicate.uya:"
if $COMPILER "$TEST_DIR/test_error_decl_duplicate.uya" "$TEMP_DIR/test_dup.c" 2>&1 | grep -q "重复定义"; then
    echo "✅ 正确检测到重复定义错误"
else
    echo "❌ 未检测到重复定义"
fi

# 清理
rm -rf "$TEMP_DIR"

echo ""
echo "=========================================="
echo "验证结果汇总"
echo "=========================================="
echo "Uya编译: $success_compile 成功, $fail_compile 失败"
echo "gcc编译: $success_gcc 成功, $fail_gcc 失败"
echo ""

if [ $fail_compile -eq 0 ] && [ $fail_gcc -eq 0 ]; then
    echo "🎉 所有测试验证通过！"
    exit 0
else
    echo "⚠️  有测试失败"
    exit 1
fi
