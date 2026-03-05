#!/bin/bash
# 编译 Uya 格式化工具

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPILER="$REPO_ROOT/bin/uya"
OUTPUT_DIR="$SCRIPT_DIR/build"
OUTPUT_FILE="$OUTPUT_DIR/fmt_tool.c"
OUTPUT_BIN="$OUTPUT_DIR/uya-fmt"

# 检查编译器
if [ ! -f "$COMPILER" ]; then
    echo "错误：编译器不存在：$COMPILER"
    echo "请先运行 'make uya' 构建编译器"
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 编译
echo "编译格式化工具..."
echo "输入：$SCRIPT_DIR/fmt_tool.uya"
echo "输出：$OUTPUT_FILE"

"$COMPILER" "$SCRIPT_DIR/fmt_tool.uya" -o "$OUTPUT_FILE" --c99

if [ -f "$OUTPUT_FILE" ]; then
    echo "编译成功！"
    echo ""
    echo "链接可执行文件..."
    gcc -std=c99 -O2 "$OUTPUT_FILE" -o "$OUTPUT_BIN"
    
    if [ -f "$OUTPUT_BIN" ]; then
        echo "✓ 格式化工具已构建：$OUTPUT_BIN"
        echo ""
        echo "使用方法:"
        echo "  $OUTPUT_BIN <文件|目录> [选项]"
        echo ""
        echo "选项:"
        echo "  -c, --check      检查模式"
        echo "  -r, --recursive  递归处理"
        echo "  -o, --output     输出文件"
        echo "  -h, --help       显示帮助"
    else
        echo "错误：链接失败"
        exit 1
    fi
else
    echo "错误：编译失败"
    exit 1
fi
