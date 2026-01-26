#!/bin/bash
# Uya Mini 多文件编译脚本
# 编译 uya-src 目录中的所有 .uya 文件

# 注意：不使用 set -e，因为我们需要捕获编译器的退出码并处理错误

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 项目根目录（compiler-mini）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# uya-src 目录
UYA_SRC_DIR="$SCRIPT_DIR"
# 编译器路径
COMPILER="$PROJECT_ROOT/build/compiler-mini"
# 默认输出目录
BUILD_DIR="$PROJECT_ROOT/build/uya-compiler"
# 默认输出文件名
OUTPUT_NAME="compiler"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 使用说明
usage() {
    cat << EOF
用法: $0 [选项] [输出文件]

选项:
  -h, --help          显示此帮助信息
  -v, --verbose       详细输出模式
  -d, --debug         调试模式（保留中间文件）
  -o, --output DIR    指定输出目录（默认: $BUILD_DIR）
  -n, --name NAME     指定输出文件名（默认: $OUTPUT_NAME）
  -c, --clean         清理输出目录后再编译
  -e, --exec          生成可执行文件（自动链接）
  --compiler PATH     指定编译器路径（默认: $COMPILER）

示例:
  $0                           # 使用默认设置编译（生成目标文件）
  $0 -e                        # 生成可执行文件
  $0 -o /tmp/uyac -n my_compiler -e  # 指定输出目录和文件名，生成可执行文件
  $0 -v -d                      # 详细输出和调试模式
  $0 -c                         # 清理后编译

EOF
    exit 1
}

# 默认选项
VERBOSE=false
DEBUG=false
CLEAN=false
GENERATE_EXEC=false

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
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -e|--exec)
            GENERATE_EXEC=true
            shift
            ;;
        -o|--output)
            BUILD_DIR="$2"
            shift 2
            ;;
        -n|--name)
            OUTPUT_NAME="$2"
            shift 2
            ;;
        --compiler)
            COMPILER="$2"
            shift 2
            ;;
        *)
            # 如果参数不以 - 开头，可能是输出文件
            if [[ "$1" != -* ]]; then
                OUTPUT_NAME="$1"
                shift
            else
                echo -e "${RED}错误: 未知选项 $1${NC}"
                usage
            fi
            ;;
    esac
done

# 检查编译器是否存在
if [ ! -f "$COMPILER" ]; then
    echo -e "${RED}错误: 编译器 '$COMPILER' 不存在${NC}"
    echo "请先运行 'make build' 构建编译器"
    exit 1
fi

# 检查 uya-src 目录是否存在
if [ ! -d "$UYA_SRC_DIR" ]; then
    echo -e "${RED}错误: 源代码目录 '$UYA_SRC_DIR' 不存在${NC}"
    exit 1
fi

# 清理输出目录
if [ "$CLEAN" = true ]; then
    if [ -d "$BUILD_DIR" ]; then
        echo -e "${YELLOW}清理输出目录: $BUILD_DIR${NC}"
        rm -rf "$BUILD_DIR"
    fi
fi

# 创建输出目录
mkdir -p "$BUILD_DIR"

# 输出文件路径
OUTPUT_FILE="$BUILD_DIR/$OUTPUT_NAME"

# 收集所有 .uya 文件（按依赖顺序排列）
# 注意：文件顺序可能影响编译结果，按逻辑顺序排列
UYA_FILES=(
    "arena.uya"
    "str_utils.uya"
    "extern_decls.uya"
    "llvm_api.uya"
    "ast.uya"
    "lexer.uya"
    "parser.uya"
    "checker.uya"
    "codegen.uya"
    "main.uya"
)

# 验证文件存在并构建完整路径（使用绝对路径）
FULL_PATHS=()
for file in "${UYA_FILES[@]}"; do
    full_path="$UYA_SRC_DIR/$file"
    # 转换为绝对路径
    full_path=$(cd "$(dirname "$full_path")" && pwd)/$(basename "$full_path")
    if [ ! -f "$full_path" ]; then
        echo -e "${RED}警告: 文件 $file 不存在，跳过${NC}"
        continue
    fi
    FULL_PATHS+=("$full_path")
done

if [ ${#FULL_PATHS[@]} -eq 0 ]; then
    echo -e "${RED}错误: 没有找到任何 .uya 文件${NC}"
    exit 1
fi

# 显示编译信息
echo "=========================================="
echo "Uya Mini 多文件编译"
echo "=========================================="
echo "编译器: $COMPILER"
echo "源代码目录: $UYA_SRC_DIR"
echo "输出文件: $OUTPUT_FILE"
echo "文件数量: ${#FULL_PATHS[@]}"
if [ "$VERBOSE" = true ]; then
    echo ""
    echo "源文件列表:"
    for i in "${!FULL_PATHS[@]}"; do
        printf "  %2d. %s\n" $((i+1)) "$(basename "${FULL_PATHS[$i]}")"
    done
    echo ""
fi
echo "=========================================="
echo ""

# 执行编译（多文件编译模式）
# 构建编译命令
COMPILER_CMD=("$COMPILER" "${FULL_PATHS[@]}" -o "$OUTPUT_FILE")
if [ "$GENERATE_EXEC" = true ]; then
    COMPILER_CMD+=(-exec)
fi

if [ "$VERBOSE" = true ]; then
    echo "开始多文件编译..."
    echo "命令: ${COMPILER_CMD[*]}"
    echo ""
fi

# 使用多文件编译（传递多个 .uya 文件给编译器，不使用文件合并）
# 编译器会自动处理多文件编译，包括 AST 合并和类型检查

# 创建临时文件来捕获编译输出
TEMP_OUTPUT=$(mktemp)
TEMP_ERRORS=$(mktemp)
trap "rm -f '$TEMP_OUTPUT' '$TEMP_ERRORS'" EXIT

# 执行编译，捕获所有输出
if [ "$VERBOSE" = true ] || [ "$DEBUG" = true ]; then
    # 详细模式：显示所有输出
    "${COMPILER_CMD[@]}" 2>&1 | tee "$TEMP_OUTPUT"
    COMPILER_EXIT=${PIPESTATUS[0]}
else
    # 普通模式：只显示关键信息，过滤调试输出
    "${COMPILER_CMD[@]}" > "$TEMP_OUTPUT" 2>&1
    COMPILER_EXIT=$?
    
    # 提取关键信息：阶段标题、错误、警告
    # 显示编译阶段信息（=== 开头的行）
    grep -E "^===" "$TEMP_OUTPUT" | head -20
    # 显示错误和警告（但不显示调试信息）
    grep -E "错误:|警告:" "$TEMP_OUTPUT" | grep -v "调试:" | head -30
fi

# 提取所有错误信息到单独文件
grep -E "错误:" "$TEMP_OUTPUT" > "$TEMP_ERRORS" || true

# 检查编译结果
if [ $COMPILER_EXIT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ 编译成功！${NC}"
    echo ""
    
    # 确定实际生成的文件路径
    # 如果使用 -exec，编译器会生成可执行文件（去掉 .o 或添加 _exec）
    EXECUTABLE_FILE=""
    if [ "$GENERATE_EXEC" = true ]; then
        # 如果输出文件以 .o 结尾，可执行文件去掉 .o
        if [[ "$OUTPUT_FILE" == *.o ]]; then
            EXECUTABLE_FILE="${OUTPUT_FILE%.o}"
        else
            # 否则添加 _exec 后缀
            EXECUTABLE_FILE="${OUTPUT_FILE}_exec"
        fi
        
        # 检查可执行文件是否成功生成
        if [ ! -f "$EXECUTABLE_FILE" ]; then
            echo ""
            echo -e "${RED}✗ 可执行文件生成失败${NC}"
            echo "预期可执行文件路径: $EXECUTABLE_FILE"
            echo "目标文件路径: $OUTPUT_FILE"
            if [ -f "$OUTPUT_FILE" ]; then
                echo ""
                echo "目标文件已生成，但链接失败。可能的原因："
                echo "  1. 系统未安装链接器（gcc、clang 或 lld）"
                echo "  2. 链接器执行失败（检查编译输出中的错误信息）"
                echo ""
                echo "可以尝试手动链接："
                if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
                    echo "  gcc -no-pie \"$OUTPUT_FILE\" -o \"${EXECUTABLE_FILE}.exe\""
                else
                    echo "  gcc -no-pie \"$OUTPUT_FILE\" -o \"$EXECUTABLE_FILE\""
                fi
            fi
            exit 1
        fi
        
        # 检查文件是否可执行
        if [ ! -x "$EXECUTABLE_FILE" ]; then
            echo ""
            echo -e "${YELLOW}警告: 生成的文件不可执行${NC}"
            echo "文件路径: $EXECUTABLE_FILE"
            echo "尝试添加执行权限..."
            chmod +x "$EXECUTABLE_FILE" 2>/dev/null || true
        fi
        
        # 显示可执行文件信息
        echo ""
        echo "可执行文件: $EXECUTABLE_FILE"
        file_size=$(du -h "$EXECUTABLE_FILE" 2>/dev/null | cut -f1 || echo "未知")
        echo "文件大小: $file_size"
        echo "类型: 可执行文件"
        if [ -f "$OUTPUT_FILE" ]; then
            echo "目标文件: $OUTPUT_FILE（中间文件，可删除）"
        fi
    elif [ -f "$OUTPUT_FILE" ]; then
        # 只生成了目标文件
        echo ""
        echo "输出文件: $OUTPUT_FILE"
        file_size=$(du -h "$OUTPUT_FILE" 2>/dev/null | cut -f1 || echo "未知")
        echo "文件大小: $file_size"
        
        # 检查是否是可执行文件
        if [ -x "$OUTPUT_FILE" ]; then
            echo "类型: 可执行文件"
        else
            echo "类型: 目标文件（.o）"
            echo ""
            echo "提示: 如果要生成可执行文件，使用 -e 或 --exec 选项："
            echo "  $0 -e"
            echo "或者手动链接："
            # 在 Windows 上使用 .exe 扩展名，在 Linux/Unix 上不使用
            if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
                echo "  gcc -no-pie \"$OUTPUT_FILE\" -o \"${OUTPUT_FILE%.o}.exe\""
            else
                echo "  gcc -no-pie \"$OUTPUT_FILE\" -o \"${OUTPUT_FILE%.o}\""
            fi
        fi
    else
        # 没有生成任何文件
        echo ""
        echo -e "${RED}✗ 未生成输出文件${NC}"
        echo "预期输出文件: $OUTPUT_FILE"
        exit 1
    fi
    
    # 如果是调试模式，显示详细信息
    if [ "$DEBUG" = true ]; then
        echo ""
        echo "调试信息:"
        echo "  输出目录: $BUILD_DIR"
        echo "  编译器版本信息: $($COMPILER --version 2>&1 || echo '版本信息不可用')"
    fi
    
    exit 0
else
    EXIT_CODE=$COMPILER_EXIT
    echo ""
    echo -e "${RED}✗ 编译失败（退出码: $EXIT_CODE）${NC}"
    
    # 如果使用了 -e 选项，提示不会生成可执行文件
    if [ "$GENERATE_EXEC" = true ]; then
        echo ""
        echo -e "${YELLOW}注意: 由于编译失败，不会生成可执行文件${NC}"
    fi
    
    # 显示错误摘要
    ERROR_COUNT=$(wc -l < "$TEMP_ERRORS" 2>/dev/null || echo "0")
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}错误摘要（共 $ERROR_COUNT 个错误）:${NC}"
        # 显示前10个唯一错误（去除重复）
        grep -E "错误:" "$TEMP_ERRORS" | sed 's/.*错误: //' | sort -u | head -10 | while read -r err; do
            echo "  - $err"
        done
        
        if [ "$ERROR_COUNT" -gt 10 ]; then
            echo "  ... 还有 $((ERROR_COUNT - 10)) 个错误（使用 -v 查看完整输出）"
        fi
    fi
    
    # 如果输出文件存在但编译失败，保留它（可能包含有用的信息）
    if [ "$DEBUG" = true ] && [ -f "$OUTPUT_FILE" ]; then
        echo ""
        echo "调试模式: 保留输出文件 $OUTPUT_FILE"
        echo "完整错误日志已保存到: $TEMP_OUTPUT"
    fi
    
    # 在详细模式下，显示更多错误信息
    if [ "$VERBOSE" = true ] && [ "$ERROR_COUNT" -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}所有错误列表:${NC}"
        cat "$TEMP_ERRORS"
    fi
    
    exit $EXIT_CODE
fi

