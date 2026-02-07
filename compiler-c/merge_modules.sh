#!/bin/bash

# Uya 模块合并脚本
# 将多个 .uya 文件合并成一个文件，用于当前不支持模块系统的 Uya Mini 编译器

set -e  # 遇到错误时退出

usage() {
    echo "用法: $0 [选项] <输出文件> <输入文件1> [输入文件2] ..."
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -v, --verbose  详细输出模式"
    echo ""
    echo "示例: $0 combined.uya module1.uya module2.uya main.uya"
    echo "      $0 -v lib.uya math.uya utils.uya"
    exit 1
}

VERBOSE=false

# 解析命令行选项
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            echo "未知选项: $1"
            usage
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -lt 2 ]; then
    usage
fi

OUTPUT_FILE="$1"
shift

if [ "$VERBOSE" = true ]; then
    echo "开始合并 $# 个 Uya 模块文件到 $OUTPUT_FILE..."
fi

# 清空输出文件
> "$OUTPUT_FILE"

echo "// 自动生成的合并文件 - $(date)" >> "$OUTPUT_FILE"
echo "// 包含文件: $*" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

for file in "$@"; do
    if [ ! -f "$file" ]; then
        echo "错误: 文件 $file 不存在"
        exit 1
    fi

    if [ "$VERBOSE" = true ]; then
        echo "正在处理: $file"
    fi

    echo "// ========== 来自文件: $file ==========" >> "$OUTPUT_FILE"

    # 读取文件内容并追加到输出文件
    cat "$file" >> "$OUTPUT_FILE"

    # 确保文件末尾有换行
    echo "" >> "$OUTPUT_FILE"
done

if [ "$VERBOSE" = true ]; then
    echo "成功将 $# 个文件合并到 $OUTPUT_FILE"
    echo "文件统计:"
    echo "  总行数: $(wc -l < "$OUTPUT_FILE")"
    echo "  总字符数: $(wc -c < "$OUTPUT_FILE")"
else
    echo "成功将 $# 个文件合并到 $OUTPUT_FILE"
fi