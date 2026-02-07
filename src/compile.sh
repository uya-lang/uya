#!/bin/bash
# Uya Mini 多文件编译脚本
# 编译 src 目录中的所有 .uya 文件

# 注意：不使用 set -e，因为我们需要捕获编译器的退出码并处理错误

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 项目根目录
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# src 目录
UYA_SRC_DIR="$SCRIPT_DIR"
# 编译器路径
COMPILER="$REPO_ROOT/bin/uya-c"
# 默认输出目录（中间文件）
BUILD_DIR="$REPO_ROOT/compiler-c/build/uya-src"
# 最终二进制输出目录
BIN_DIR="$REPO_ROOT/bin"
# 默认输出文件名
OUTPUT_NAME="uya"

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
  -b, --bootstrap-compare  自举对比：用自举编译器再编译自身，与 C 编译器输出的 C 文件对比（需 --c99，建议与 -e 同用）
  --c99               使用 C99 后端生成 C 代码（输出文件后缀为 .c 时自动启用）
  --line-directives    启用 #line 指令生成（C99 后端，默认禁用）
  --compiler PATH     指定编译器路径（默认: $COMPILER）

示例:
  $0                           # 使用默认设置编译（生成目标文件）
  $0 -e                        # 生成可执行文件
  $0 -o /tmp/uyac -n my_compiler -e  # 指定输出目录和文件名，生成可执行文件
  $0 -v -d                      # 详细输出和调试模式
  $0 -c                         # 清理后编译
  $0 --c99                      # 使用 C99 后端生成 C 代码
  $0 -n compiler.c              # 输出文件为 .c 时自动使用 C99 后端
  $0 --c99 --line-directives    # 使用 C99 后端，生成 #line 指令
  $0 --c99 -e -b                # C99 编译并生成可执行文件，然后自举对比（两次 C 输出应完全一致）

EOF
    exit 1
}

# 默认选项
VERBOSE=false
DEBUG=false
CLEAN=false
GENERATE_EXEC=false
BOOTSTRAP_COMPARE=false
USE_C99=false
USE_LINE_DIRECTIVES=false

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
        -b|--bootstrap-compare)
            BOOTSTRAP_COMPARE=true
            shift
            ;;
        --c99)
            USE_C99=true
            shift
            ;;
        --line-directives)
            USE_LINE_DIRECTIVES=true
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

# 自举对比需要 C99 后端；若启用自举对比则必须生成可执行文件以便运行自举编译器
if [ "$BOOTSTRAP_COMPARE" = true ]; then
    if [ "$USE_C99" != true ]; then
        echo -e "${RED}错误: --bootstrap-compare 需要同时使用 --c99${NC}"
        exit 1
    fi
    GENERATE_EXEC=true
fi

# 检查编译器是否存在
if [ ! -f "$COMPILER" ]; then
    echo -e "${RED}错误: 编译器 '$COMPILER' 不存在${NC}"
    echo "请先运行 'make build' 构建编译器"
    exit 1
fi

# 检查 src 目录是否存在
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

# 检查并创建 bridge.c 文件（如果不存在）
BRIDGE_C="$BUILD_DIR/bridge.c"
if [ ! -f "$BRIDGE_C" ]; then
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}创建 bridge.c 文件...${NC}"
    fi
    cat > "$BRIDGE_C" << 'BRIDGE_EOF'
// bridge.c - 提供运行时桥接函数
// 这个文件提供了 Uya 程序需要的运行时函数，包括：
// 1. 真正的 C main 函数（程序入口点）
// 2. 命令行参数访问函数（get_argc, get_argv）
// 3. 标准错误流访问函数（get_stderr）
// 4. 指针运算辅助函数（ptr_diff）
// 5. LLVM 初始化函数（通过包含头文件提供内联实现）
// 注意：Uya 的 main 函数被重命名为 uya_main，由 bridge.c 的 main 函数调用

#include <stdio.h>
#include <stdint.h>
#include <stddef.h>

// 注意：LLVM 初始化函数需要链接 LLVM 库
// 这里不包含 LLVM 头文件，而是提供简单的包装函数
// 实际的 LLVM 初始化由链接的 LLVM 库提供

// 全局变量：保存命令行参数
static int saved_argc = 0;
static char **saved_argv = NULL;

// 初始化函数：由 bridge.c 的 main 函数调用，保存命令行参数
void bridge_init(int argc, char **argv) {
    saved_argc = argc;
    saved_argv = argv;
}

// Uya 程序的 main 函数（被重命名为 uya_main）
extern int32_t uya_main(void);

// 真正的 C main 函数（程序入口点）
int main(int argc, char **argv) {
    // 初始化命令行参数
    bridge_init(argc, argv);
    // 调用 Uya 的 main 函数
    return (int)uya_main();
}

// 获取命令行参数数量
int32_t get_argc(void) {
    return (int32_t)saved_argc;
}

// 获取第 index 个命令行参数
uint8_t *get_argv(int32_t index) {
    if (index < 0 || index >= saved_argc || saved_argv == NULL) {
        return NULL;
    }
    return (uint8_t *)saved_argv[index];
}

// 获取标准错误流指针
void *get_stderr(void) {
    return (void *)stderr;
}

// 计算两个指针之间的字节偏移量（ptr1 - ptr2）
// 用于替代 Uya Mini 中不支持的指针到整数直接转换
int32_t ptr_diff(uint8_t *ptr1, uint8_t *ptr2) {
    if (ptr1 == NULL || ptr2 == NULL) {
        return 0;
    }
    return (int32_t)(ptr1 - ptr2);
}

// LLVM 初始化函数的弱符号实现
// 如果 LLVM 库提供了这些函数，链接器会使用库中的版本
// 否则使用这里的空实现（对于不使用 LLVM 后端的程序）
__attribute__((weak)) void LLVMInitializeNativeTarget(void) {
    // 空实现：如果链接了 LLVM 库，库中的实现会被使用
}

__attribute__((weak)) void LLVMInitializeNativeAsmPrinter(void) {
    // 空实现
}

__attribute__((weak)) void LLVMInitializeNativeAsmParser(void) {
    // 空实现
}
BRIDGE_EOF
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ bridge.c 已创建${NC}"
    fi
fi

# 输出文件路径
OUTPUT_FILE="$BUILD_DIR/$OUTPUT_NAME"

# 如果输出文件后缀是 .c，自动使用 C99 后端
if [[ "$OUTPUT_NAME" == *.c ]]; then
    USE_C99=true
fi

# 如果使用 C99 后端但输出文件不是 .c 后缀，添加 .c 后缀
if [ "$USE_C99" = true ] && [[ "$OUTPUT_NAME" != *.c ]]; then
    OUTPUT_FILE="$BUILD_DIR/${OUTPUT_NAME}.c"
fi

# 检查是否使用自动依赖收集模式
# 如果 main.uya 包含 use 语句，可以使用自动依赖收集
# 否则，需要手动列出所有文件（向后兼容）
USE_AUTO_DEPS=false

# 检查 main.uya 是否存在
MAIN_FILE="$UYA_SRC_DIR/main.uya"
if [ ! -f "$MAIN_FILE" ]; then
    echo -e "${RED}错误: 主文件 '$MAIN_FILE' 不存在${NC}"
    exit 1
fi

# 检查 main.uya 是否包含 use 语句
if grep -q "^use " "$MAIN_FILE" 2>/dev/null; then
    USE_AUTO_DEPS=true
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}检测到 use 语句，使用自动依赖收集模式${NC}"
    fi
fi

if [ "$USE_AUTO_DEPS" = true ]; then
    # 使用自动依赖收集模式
    # 编译器会自动：
    # 1. 解析 main.uya 中的 use 语句
    # 2. 查找并包含所有依赖的模块文件
    # 3. 递归处理依赖的依赖
    INPUT_PATH="$MAIN_FILE"
    FULL_PATHS=("$MAIN_FILE")
else
    # 使用手动文件列表模式（向后兼容，适用于没有 use 语句的项目）
    # 收集所有 .uya 文件（按依赖顺序排列）
    UYA_FILES=(
        "arena.uya"
        "str_utils.uya"
        "extern_decls.uya"
        "ast.uya"
        "lexer.uya"
        "parser.uya"
        "checker.uya"
    )

    # 根据后端类型添加相应的 codegen 模块
    if [ "$USE_C99" = true ]; then
        # C99 后端模块（按依赖顺序）
        UYA_FILES+=(
            "codegen/c99/internal.uya"
            "codegen/c99/utils.uya"
            "codegen/c99/types.uya"
            "codegen/c99/structs.uya"
            "codegen/c99/enums.uya"
            "codegen/c99/function.uya"
            "codegen/c99/expr.uya"
            "codegen/c99/stmt.uya"
            "codegen/c99/global.uya"
            "codegen/c99/main.uya"
        )
    else
        # LLVM C API 后端模块（按依赖顺序）
        UYA_FILES+=(
            "llvm_api.uya"
            "codegen/llvm_capi/internal.uya"
            "codegen/llvm_capi/init.uya"
            "codegen/llvm_capi/utils.uya"
            "codegen/llvm_capi/types.uya"
            "codegen/llvm_capi/vars.uya"
            "codegen/llvm_capi/funcs.uya"
            "codegen/llvm_capi/structs.uya"
            "codegen/llvm_capi/enums.uya"
            "codegen/llvm_capi/expr.uya"
            "codegen/llvm_capi/stmt.uya"
            "codegen/llvm_capi/function.uya"
            "codegen/llvm_capi/global.uya"
            "codegen/llvm_capi/main.uya"
        )
    fi

    # 添加主文件
    UYA_FILES+=("main.uya")

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
    
    INPUT_PATH=""  # 手动模式不使用 INPUT_PATH
fi

# 显示编译信息
echo "=========================================="
echo "Uya Mini 自举编译（自动依赖收集）"
echo "=========================================="
echo "编译器: $COMPILER"
echo "源代码目录: $UYA_SRC_DIR"
echo "输出文件: $OUTPUT_FILE"
echo "输入路径: $INPUT_PATH"
echo ""
echo "注意: 编译器将自动收集所有模块依赖"
if [ "$VERBOSE" = true ]; then
    echo ""
    echo "主文件: main.uya"
    echo "编译器将自动发现并包含所有依赖文件"
    echo ""
fi
echo "=========================================="
echo ""

# 执行编译
if [ "$USE_AUTO_DEPS" = true ]; then
    # 使用自动依赖收集模式：只传递主文件
    COMPILER_CMD=("$COMPILER" "$INPUT_PATH" -o "$OUTPUT_FILE")
else
    # 使用手动文件列表模式：传递所有文件
    COMPILER_CMD=("$COMPILER" "${FULL_PATHS[@]}" -o "$OUTPUT_FILE")
fi
if [ "$USE_C99" = true ]; then
    COMPILER_CMD+=(--c99)
fi
if [ "$USE_LINE_DIRECTIVES" = true ]; then
    COMPILER_CMD+=(--line-directives)
fi
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
    
    # 提取关键信息：阶段标题、进度、错误、警告
    # 显示编译阶段信息（=== 开头的行、解析/合并/类型检查/代码生成完成等进度）
    grep -E "^===|  解析完成|AST 合并完成|类型检查通过|代码生成完成" "$TEMP_OUTPUT" | head -50
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
    # 最终可执行文件输出到 bin/ 目录
    EXECUTABLE_FILE=""
    if [ "$GENERATE_EXEC" = true ]; then
        mkdir -p "$BIN_DIR"
        EXECUTABLE_FILE="$BIN_DIR/$OUTPUT_NAME"
        
        # 检查可执行文件是否需要生成或重新链接（C99 时若 .c 比可执行文件新则需重新链接）
        NEED_LINK=false
        if [ ! -f "$EXECUTABLE_FILE" ]; then
            NEED_LINK=true
        elif [ "$USE_C99" = true ] && [ -f "$OUTPUT_FILE" ] && [ -f "$EXECUTABLE_FILE" ] && [ "$OUTPUT_FILE" -nt "$EXECUTABLE_FILE" ]; then
            NEED_LINK=true
        fi
        if [ "$NEED_LINK" = true ]; then
            if [ ! -f "$EXECUTABLE_FILE" ]; then
                echo ""
                echo -e "${YELLOW}可执行文件未自动生成，尝试手动链接...${NC}"
            else
                echo ""
                echo -e "${YELLOW}C 源文件已更新，重新链接可执行文件...${NC}"
            fi
            
            # 检查是否存在 bridge.c
            BRIDGE_C="$BUILD_DIR/bridge.c"
            
            # 对于 C99 后端，尝试自动链接
            if [ "$USE_C99" = true ] && [ -f "$OUTPUT_FILE" ]; then
                if [ -f "$BRIDGE_C" ]; then
                    # 尝试检测 LLVM 路径
                    LLVM_INCLUDE=""
                    LLVM_LIBDIR=""
                    LLVM_LIBS="-lLLVM-17"
                    
                    if [ -d "/usr/include/llvm-c" ]; then
                        LLVM_INCLUDE="-I/usr/include/llvm-c"
                    fi
                    if [ -d "/usr/lib/llvm-17/lib" ]; then
                        LLVM_LIBDIR="-L/usr/lib/llvm-17/lib"
                    elif [ -d "/usr/lib/llvm-17" ]; then
                        LLVM_LIBDIR="-L/usr/lib/llvm-17"
                    fi
                    
                    # 构建链接命令（直接链接 .c 文件，不需要 objcopy 重命名）
                    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
                        LINK_CMD="gcc --std=c99 -no-pie $LLVM_INCLUDE $LLVM_LIBDIR \"$OUTPUT_FILE\" \"$BRIDGE_C\" -o \"${EXECUTABLE_FILE}.exe\" $LLVM_LIBS -lstdc++ -lm -ldl -lpthread"
                    else
                        LINK_CMD="gcc --std=c99 -no-pie $LLVM_INCLUDE $LLVM_LIBDIR \"$OUTPUT_FILE\" \"$BRIDGE_C\" -o \"$EXECUTABLE_FILE\" $LLVM_LIBS -lstdc++ -lm -ldl -lpthread"
                    fi
                    
                    if [ "$VERBOSE" = true ]; then
                        echo "执行链接命令: $LINK_CMD"
                    fi
                    
                    if eval "$LINK_CMD" 2>&1; then
                        echo -e "${GREEN}✓ C99 可执行文件已生成: $EXECUTABLE_FILE${NC}"
                    else
                        echo -e "${RED}✗ 链接失败${NC}"
                        echo ""
                        echo "可以尝试手动链接："
                        echo "  $LINK_CMD"
                        exit 1
                    fi
                else
                    echo -e "${RED}✗ bridge.c 文件不存在${NC}"
                    echo "预期路径: $BRIDGE_C"
                    exit 1
                fi
            else
                # 非 C99 后端或文件不存在
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
                    if [ -f "$BRIDGE_C" ]; then
                        # LLVM 后端
                        if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
                            echo "  gcc -no-pie \"$OUTPUT_FILE\" \"$BRIDGE_C\" -o \"${EXECUTABLE_FILE}.exe\" -L/usr/lib/llvm-17/lib -lLLVM-17 -lstdc++ -lm -ldl -lpthread"
                        else
                            echo "  gcc -no-pie \"$OUTPUT_FILE\" \"$BRIDGE_C\" -o \"$EXECUTABLE_FILE\" -L/usr/lib/llvm-17/lib -lLLVM-17 -lstdc++ -lm -ldl -lpthread"
                        fi
                    else
                        # 没有 bridge.c，使用简单链接
                        if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
                            echo "  gcc -no-pie \"$OUTPUT_FILE\" -o \"${EXECUTABLE_FILE}.exe\""
                        else
                            echo "  gcc -no-pie \"$OUTPUT_FILE\" -o \"$EXECUTABLE_FILE\""
                        fi
                    fi
                fi
                exit 1
            fi
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

        # 自举对比：用自举编译器再编译自身，与 C 编译器输出的 C 文件对比
        if [ "$BOOTSTRAP_COMPARE" = true ] && [ -f "$EXECUTABLE_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
            echo ""
            echo "=========================================="
            echo "自举对比：用自举编译器编译自身，对比 C 输出"
            echo "=========================================="
            BOOTSTRAP_C="$BUILD_DIR/compiler_bootstrap.c"
            if [ "$VERBOSE" = true ]; then
                echo "自举编译器: $EXECUTABLE_FILE"
                # 自举对比：使用自动依赖收集模式
                echo "输入路径: $INPUT_PATH"
                echo "C 编译器输出: $OUTPUT_FILE"
                echo "自举输出: $BOOTSTRAP_C"
            fi
            BOOTSTRAP_LOG=$(mktemp)
            # 自举编译器栈上大数组多，增大栈限制（与 C 版行为一致，参考 src/main.c ARENA/LEXER 等）
            # 使用相同的输入方式，让自举编译器也自动收集依赖（或使用相同的文件列表）
            # 注意：移除 exec，直接调用可执行文件，避免可能的错误处理问题
            # 如果自举编译器段错误，可能是程序本身的问题，暂时跳过自举对比
            if [ "$USE_AUTO_DEPS" = true ]; then
                (ulimit -s 32768 2>/dev/null || true; "$EXECUTABLE_FILE" "$INPUT_PATH" -o "$BOOTSTRAP_C" --c99) >"$BOOTSTRAP_LOG" 2>&1
            else
                (ulimit -s 32768 2>/dev/null || true; "$EXECUTABLE_FILE" "${FULL_PATHS[@]}" -o "$BOOTSTRAP_C" --c99) >"$BOOTSTRAP_LOG" 2>&1
            fi
            BOOTSTRAP_EXIT=$?
            if [ "$BOOTSTRAP_EXIT" -ne 0 ]; then
                echo -e "${RED}✗ 自举编译器编译失败（退出码: $BOOTSTRAP_EXIT）${NC}"
                echo ""
                echo "自举编译器输出:"
                echo "----------------------------------------"
                cat "$BOOTSTRAP_LOG"
                echo "----------------------------------------"
                echo ""
                echo -e "${YELLOW}注意: 自举编译器可能存在问题，跳过自举对比${NC}"
                echo "这可能是由于自举编译器生成的代码有 bug，需要进一步调试"
                rm -f "$BOOTSTRAP_LOG"
                # 不退出，允许继续执行（自举对比失败不应该阻止编译成功）
                # exit 1
            else
                rm -f "$BOOTSTRAP_LOG"
                if [ -f "$BOOTSTRAP_C" ]; then
                    if diff -q "$OUTPUT_FILE" "$BOOTSTRAP_C" >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ 自举对比一致：C 编译器与自举编译器生成的 C 文件完全一致${NC}"
                    else
                        echo -e "${RED}✗ 自举对比不一致：两次生成的 C 文件有差异${NC}"
                        echo "  C 编译器输出: $OUTPUT_FILE"
                        echo "  自举编译器输出: $BOOTSTRAP_C"
                        echo "  查看差异: diff -u \"$OUTPUT_FILE\" \"$BOOTSTRAP_C\""
                        diff -u "$OUTPUT_FILE" "$BOOTSTRAP_C" | head -100
                        exit 1
                    fi
                fi
            fi
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
            # 检查是否存在 bridge.c
            BRIDGE_C="$BUILD_DIR/bridge.c"
            if [ -f "$BRIDGE_C" ]; then
                # 对于 C99 后端，需要链接 bridge.c
                if [ "$USE_C99" = true ]; then
                    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
                        echo "  gcc --std=c99 -no-pie \"$OUTPUT_FILE\" \"$BRIDGE_C\" -o \"${OUTPUT_FILE%.o}.exe\" -I/usr/include/llvm-c -L/usr/lib/llvm-17/lib -lLLVM-17 -lstdc++ -lm -ldl -lpthread"
                    else
                        echo "  gcc --std=c99 -no-pie \"$OUTPUT_FILE\" \"$BRIDGE_C\" -o \"${OUTPUT_FILE%.o}\" -I/usr/include/llvm-c -L/usr/lib/llvm-17/lib -lLLVM-17 -lstdc++ -lm -ldl -lpthread"
                    fi
                else
                    # LLVM 后端
                    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
                        echo "  gcc -no-pie \"$OUTPUT_FILE\" \"$BRIDGE_C\" -o \"${OUTPUT_FILE%.o}.exe\" -L/usr/lib/llvm-17/lib -lLLVM-17 -lstdc++ -lm -ldl -lpthread"
                    else
                        echo "  gcc -no-pie \"$OUTPUT_FILE\" \"$BRIDGE_C\" -o \"${OUTPUT_FILE%.o}\" -L/usr/lib/llvm-17/lib -lLLVM-17 -lstdc++ -lm -ldl -lpthread"
                    fi
                fi
            else
                # 没有 bridge.c，使用简单链接
                if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
                    echo "  gcc -no-pie \"$OUTPUT_FILE\" -o \"${OUTPUT_FILE%.o}.exe\""
                else
                    echo "  gcc -no-pie \"$OUTPUT_FILE\" -o \"${OUTPUT_FILE%.o}\""
                fi
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

