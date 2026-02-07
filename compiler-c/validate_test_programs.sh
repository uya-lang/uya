#!/bin/bash
# 验证所有测试程序是否符合 UYA_MINI_SPEC.md 规范

set +e  # 不立即退出，继续处理所有文件

SCRIPT_DIR="$(dirname "$0")"
PROGRAMS_DIR="$SCRIPT_DIR/../tests/programs"
SPEC_FILE="$SCRIPT_DIR/spec/UYA_MINI_SPEC.md"

echo "========================================="
echo "验证测试程序是否符合 UYA_MINI_SPEC.md 规范"
echo "========================================="
echo ""

# 检查规范文件是否存在
if [ ! -f "$SPEC_FILE" ]; then
    echo "❌ 错误：规范文件不存在: $SPEC_FILE"
    exit 1
fi

# 统计
TOTAL=0
PASSED=0
FAILED=0
WARNINGS=0
FAILED_FILES=()

# 验证单个文件的函数
validate_file() {
    local file="$1"
    local filename=$(basename "$file")
    local issues=0
    local warnings=0
    local issue_msgs=()
    local warning_msgs=()
    
    # 1. 检查是否有 main 函数且签名正确
    if ! grep -q "fn main() i32" "$file"; then
        issue_msgs+=("缺少 main 函数或签名不正确（应为 fn main() i32）")
        issues=$((issues + 1))
    fi
    
    # 2. 检查是否使用了不支持的关键字
    local unsupported_keywords="for match break continue error try catch defer errdefer"
    for keyword in $unsupported_keywords; do
        if grep -q "\\b${keyword}\\b" "$file"; then
            issue_msgs+=("使用了不支持的关键字: $keyword")
            issues=$((issues + 1))
        fi
    done
    
    # 3. 检查是否有数组语法（但排除注释）
    # 数组语法：identifier[expr] 或 type[expr]
    if grep -v '^[[:space:]]*//' "$file" | grep -qE '[a-zA-Z_][a-zA-Z0-9_]*\s*\[.*\]'; then
        issue_msgs+=("使用了数组语法（Uya Mini 不支持数组）")
        issues=$((issues + 1))
    fi
    
    # 4. 检查字符串字面量（警告级别，因为规范说"仅支持用于打印调试"）
    # 检查双引号字符串（但排除注释）
    if grep -v '^[[:space:]]*//' "$file" | grep -q '"[^"]*"'; then
        warning_msgs+=("包含字符串字面量（Uya Mini 不支持字符串，仅用于调试）")
        warnings=$((warnings + 1))
    fi
    
    # 5. 检查 extern 函数声明格式
    # extern 函数应该在单行，且以分号结尾，没有函数体
    if grep -q '^extern fn' "$file"; then
        # 使用 tr 去掉回车符，然后检查
        while IFS= read -r line; do
            # 去掉回车符（处理 Windows CRLF）
            line=$(echo "$line" | tr -d '\r')
            if echo "$line" | grep -q '^extern fn'; then
                # 检查是否有函数体（不应该有）
                if echo "$line" | grep -q '{'; then
                    issue_msgs+=("extern 函数声明不应该有函数体")
                    issues=$((issues + 1))
                fi
                # 检查是否以分号结尾（去掉尾部空白后）
                local trimmed_line=$(echo "$line" | sed 's/[[:space:]]*$//')
                if ! echo "$trimmed_line" | grep -q ';$'; then
                    issue_msgs+=("extern 函数声明应该以分号结尾")
                    issues=$((issues + 1))
                fi
            fi
        done < "$file"
    fi
    
    # 输出结果
    if [ $issues -gt 0 ] || [ $warnings -gt 0 ]; then
        echo "检查: $filename"
        for msg in "${issue_msgs[@]}"; do
            echo "  ❌ 错误：$msg"
        done
        for msg in "${warning_msgs[@]}"; do
            echo "  ⚠️  警告：$msg"
        done
        if [ $issues -eq 0 ]; then
            echo "  ⚠️  通过（有 $warnings 个警告）"
            return 1  # 返回1表示有警告但仍通过
        else
            echo "  ❌ 失败（$issues 个错误，$warnings 个警告）"
            return 2  # 返回2表示失败
        fi
    else
        echo "检查: $filename - ✅ 通过"
        return 0
    fi
}

# 遍历所有 .uya 文件
if [ ! -d "$PROGRAMS_DIR" ]; then
    echo "❌ 错误：测试程序目录不存在: $PROGRAMS_DIR"
    exit 1
fi

for file in "$PROGRAMS_DIR"/*.uya; do
    if [ -f "$file" ]; then
        TOTAL=$((TOTAL + 1))
        validate_file "$file"
        result=$?
        case $result in
            0)
                PASSED=$((PASSED + 1))
                ;;
            1)
                PASSED=$((PASSED + 1))
                WARNINGS=$((WARNINGS + 1))
                ;;
            2)
                FAILED=$((FAILED + 1))
                FAILED_FILES+=("$(basename "$file")")
                ;;
        esac
    fi
done

echo ""
echo "========================================="
echo "验证总结"
echo "========================================="
echo "总计: $TOTAL 个文件"
echo "通过: $PASSED 个（含 $WARNINGS 个有警告）"
echo "失败: $FAILED 个"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo "失败的文件："
    for file in "${FAILED_FILES[@]}"; do
        echo "  - $file"
    done
fi

echo ""

if [ $FAILED -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo "✅ 所有测试程序完全符合规范"
    else
        echo "✅ 所有测试程序通过规范验证（有 $WARNINGS 个警告，需要检查）"
    fi
    exit 0
else
    echo "❌ 有 $FAILED 个测试程序不符合规范"
    exit 1
fi
