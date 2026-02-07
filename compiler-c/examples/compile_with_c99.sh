#!/bin/bash
# Uya Mini C99 后端编译脚本
# 使用 C99 后端编译 Uya Mini 程序并生成可执行文件

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILER_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(cd "$COMPILER_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/bin/uya-c"

# 检查编译器是否存在
if [ ! -f "$COMPILER" ]; then
    echo "错误: 编译器 '$COMPILER' 不存在"
    echo "请先运行 'cd compiler-c && make build' 构建编译器"
    exit 1
fi

# 显示使用说明
show_usage() {
    echo "用法: $0 [选项] <输入文件> [输出文件]"
    echo ""
    echo "选项:"
    echo "  -h, --help      显示此帮助信息"
    echo "  -c, --c-only    只生成 C99 代码，不编译"
    echo "  -r, --run       编译后运行程序"
    echo ""
    echo "参数:"
    echo "  <输入文件>      Uya Mini 源文件（.uya）"
    echo "  [输出文件]      可选的输出文件名（默认：输入文件名去掉扩展名）"
    echo ""
    echo "示例:"
    echo "  $0 example.uya              # 编译并生成可执行文件"
    echo "  $0 example.uya -c           # 只生成 C99 代码"
    echo "  $0 example.uya -r           # 编译并运行"
    echo "  $0 example.uya output       # 指定输出文件名"
}

# 解析参数
C_ONLY=false
RUN=false
INPUT_FILE=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -c|--c-only)
            C_ONLY=true
            shift
            ;;
        -r|--run)
            RUN=true
            shift
            ;;
        -*)
            echo "错误: 未知选项 $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$INPUT_FILE" ]; then
                INPUT_FILE="$1"
            elif [ -z "$OUTPUT_FILE" ]; then
                OUTPUT_FILE="$1"
            else
                echo "错误: 多余的参数 $1"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# 检查输入文件
if [ -z "$INPUT_FILE" ]; then
    echo "错误: 未指定输入文件"
    show_usage
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "错误: 文件 '$INPUT_FILE' 不存在"
    exit 1
fi

# 确定输出文件名
if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="${INPUT_FILE%.uya}"
fi

C_FILE="${OUTPUT_FILE}.c"
EXEC_FILE="$OUTPUT_FILE"

# 生成 C99 代码
echo -e "${BLUE}使用 C99 后端编译: $INPUT_FILE${NC}"
"$COMPILER" "$INPUT_FILE" -o "$C_FILE" --c99

if [ $? -ne 0 ]; then
    echo "错误: C99 代码生成失败"
    exit 1
fi

echo -e "${GREEN}✓ C99 代码已生成: $C_FILE${NC}"

# 如果只生成 C 代码，退出
if [ "$C_ONLY" = true ]; then
    echo -e "${GREEN}完成！${NC}"
    exit 0
fi

# 编译 C99 代码
echo -e "${BLUE}使用 gcc 编译 C99 代码...${NC}"
gcc --std=c99 -Wall -Wextra -o "$EXEC_FILE" "$C_FILE"

if [ $? -ne 0 ]; then
    echo "错误: C99 代码编译失败"
    exit 1
fi

echo -e "${GREEN}✓ 可执行文件已生成: $EXEC_FILE${NC}"

# 如果指定运行，执行程序
if [ "$RUN" = true ]; then
    echo -e "${YELLOW}运行程序:${NC}"
    echo "---"
    "$EXEC_FILE"
    EXIT_CODE=$?
    echo "---"
    echo -e "${GREEN}程序退出码: $EXIT_CODE${NC}"
fi

echo -e "${GREEN}完成！${NC}"

