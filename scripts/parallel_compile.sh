#!/bin/bash
# parallel_compile.sh - 并行编译脚本
# 使用多线程并行编译多个 .uya 文件
#
# 用法:
#   ./scripts/parallel_compile.sh <目录> [-j <线程数>]
#   ./scripts/parallel_compile.sh file1.uya file2.uya ... [-j <线程数>]
#
# 示例:
#   ./scripts/parallel_compile.sh src/ -j 4
#   ./scripts/parallel_compile.sh a.uya b.uya c.uya -j 2

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/bin/uya"

# 默认并行数
PARALLEL_JOBS=${PARALLEL_JOBS:-$(nproc)}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_usage() {
    echo "用法: $0 [选项] <文件或目录...>"
    echo ""
    echo "选项:"
    echo "  -j <N>    并行任务数（默认: \$(nproc) = $(nproc)）"
    echo "  -o <dir>  输出目录（默认: ./build）"
    echo "  -h        显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 src/ -j 4              # 并行编译 src 目录"
    echo "  $0 *.uya -j 2             # 并行编译当前目录所有 .uya 文件"
    echo "  PARALLEL_JOBS=8 $0 src/   # 通过环境变量设置并行数"
}

# 解析参数
OUTPUT_DIR="./build"
FILES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -j)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        -o)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            FILES+=("$1")
            shift
            ;;
    esac
done

# 如果没有指定文件，显示用法
if [ ${#FILES[@]} -eq 0 ]; then
    show_usage
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 收集所有 .uya 文件
ALL_FILES=()
for item in "${FILES[@]}"; do
    if [ -d "$item" ]; then
        # 目录：收集所有 .uya 文件
        while IFS= read -r -d '' file; do
            ALL_FILES+=("$file")
        done < <(find "$item" -name "*.uya" -print0 2>/dev/null)
    elif [ -f "$item" ]; then
        ALL_FILES+=("$item")
    else
        echo -e "${YELLOW}警告: '$item' 不存在，跳过${NC}"
    fi
done

TOTAL_FILES=${#ALL_FILES[@]}

if [ $TOTAL_FILES -eq 0 ]; then
    echo "错误: 没有找到 .uya 文件"
    exit 1
fi

echo "=========================================="
echo "并行编译 (线程数: $PARALLEL_JOBS)"
echo "=========================================="
echo "文件数量: $TOTAL_FILES"
echo "输出目录: $OUTPUT_DIR"
echo ""

# 编译单个文件的函数
compile_single() {
    local uya_file="$1"
    local output_dir="$2"
    local compiler="$3"
    
    local basename=$(basename "$uya_file" .uya)
    local output_c="$output_dir/${basename}.c"
    
    # 编译
    if $compiler "$uya_file" -o "$output_c" --nostdlib --c99 2>/dev/null; then
        echo "OK:$uya_file"
    else
        echo "FAIL:$uya_file"
    fi
}

export -f compile_single

# 并行编译
echo "开始编译..."
START_TIME=$(date +%s.%N)

# 使用 xargs 并行执行
COMPILE_RESULTS=$(printf '%s\n' "${ALL_FILES[@]}" | \
    xargs -P "$PARALLEL_JOBS" -I {} bash -c \
    'compile_single "$1" "$2" "$3"' _ {} "$OUTPUT_DIR" "$COMPILER")

END_TIME=$(date +%s.%N)
ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)

# 统计结果
SUCCESS=$(echo "$COMPILE_RESULTS" | grep -c "^OK:" || true)
FAILED=$(echo "$COMPILE_RESULTS" | grep -c "^FAIL:" || true)

echo ""
echo "=========================================="
echo "编译完成"
echo "=========================================="
echo "成功: $SUCCESS"
echo "失败: $FAILED"
echo "耗时: ${ELAPSED}s"
echo ""

# 显示失败的文件
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}失败的文件:${NC}"
    echo "$COMPILE_RESULTS" | grep "^FAIL:" | sed 's/^FAIL:/  /'
    exit 1
fi

exit 0
