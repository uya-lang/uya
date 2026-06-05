#!/bin/bash
# Uya Mini 多文件编译脚本
# 编译 src 目录中的所有 .uya 文件

# 注意：不使用 set -e，因为我们需要捕获编译器的退出码并处理错误

# 共享平台/工具链模型（可通过环境变量覆盖）
CFLAGS="${CFLAGS:--std=c99 -O0 -g -fno-builtin -Werror}"
LDFLAGS="${LDFLAGS:-}"
TOOLCHAIN="${TOOLCHAIN:-system}"
ZIG="${ZIG:-/home/winger/zig/zig}"
CC="${CC:-cc}"
if [ -z "${CC_DRIVER:-}" ]; then
    if [ "$TOOLCHAIN" = "zig" ]; then
        CC_DRIVER="$ZIG cc"
    else
        CC_DRIVER="$CC"
    fi
fi
CC_TARGET_FLAGS="${CC_TARGET_FLAGS:-}"
RUNTIME_MODE="${RUNTIME_MODE:-hosted}"
LINK_MODE="${LINK_MODE:-default}"
UYA_BOOTSTRAP_PROFILE="${UYA_BOOTSTRAP_PROFILE:-}"
UYA_NATIVE_BOOTSTRAP="${UYA_NATIVE_BOOTSTRAP:-}"

normalize_os() {
    case "$1" in
        Linux|linux) echo "linux" ;;
        Darwin|darwin|macos) echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*|mingw*|msys*|cygwin*|windows|win32) echo "windows" ;;
        *) echo "$1" | tr '[:upper:]' '[:lower:]' ;;
    esac
}

normalize_arch() {
    case "$1" in
        x86_64|amd64) echo "x86_64" ;;
        aarch64|arm64) echo "arm64" ;;
        riscv64) echo "riscv64" ;;
        *) echo "$1" ;;
    esac
}

HOST_OS="${HOST_OS:-$(normalize_os "$(uname -s)")}"
HOST_ARCH="${HOST_ARCH:-$(normalize_arch "$(uname -m)")}"
TARGET_OS="${TARGET_OS:-$HOST_OS}"
TARGET_ARCH="${TARGET_ARCH:-$HOST_ARCH}"
TARGET_TRIPLE="${TARGET_TRIPLE:-}"

HOST_OS="$(normalize_os "$HOST_OS")"
HOST_ARCH="$(normalize_arch "$HOST_ARCH")"
TARGET_OS="$(normalize_os "$TARGET_OS")"
TARGET_ARCH="$(normalize_arch "$TARGET_ARCH")"

if [ -n "$TARGET_TRIPLE" ] && [ -z "$CC_TARGET_FLAGS" ]; then
    CC_TARGET_FLAGS="-target $TARGET_TRIPLE"
fi

if [ "$TOOLCHAIN" = "zig" ] && [ ! -x "$ZIG" ]; then
    echo -e "${RED}错误: TOOLCHAIN=zig 但未找到可执行 zig: $ZIG${NC}"
    exit 1
fi

TARGET_EXE_SUFFIX=""
if [ "$TARGET_OS" = "windows" ]; then
    TARGET_EXE_SUFFIX=".exe"
fi

CC_CMD=()
if [ -n "$CC_DRIVER" ]; then
    read -r -a CC_CMD <<< "$CC_DRIVER"
fi
if [ ${#CC_CMD[@]} -eq 0 ]; then
    CC_CMD=("cc")
fi

if [ -n "$CC_TARGET_FLAGS" ]; then
    read -r -a CC_TARGET_FLAGS_ARR <<< "$CC_TARGET_FLAGS"
    CC_CMD+=("${CC_TARGET_FLAGS_ARR[@]}")
fi

cc_driver_is_clang_like() {
    case "$1" in
        *clang*|*"zig cc"*|*"zig c++"*) return 0 ;;
        *) return 1 ;;
    esac
}

cc_driver_uses_zig() {
    case "$1" in
        *"zig cc"*|*"zig c++"*) return 0 ;;
        *) return 1 ;;
    esac
}

append_clang_warning_compat() {
    local base="$1"
    if ! cc_driver_is_clang_like "$CC_DRIVER"; then
        printf '%s' "$base"
        return
    fi
    printf '%s' "$base"
    case " $base " in
        *" -Wno-pointer-sign "*) ;;
        *) printf ' %s' "-Wno-pointer-sign" ;;
    esac
    case " $base " in
        *" -Wno-parentheses-equality "*) ;;
        *) printf ' %s' "-Wno-parentheses-equality" ;;
    esac
    case " $base " in
        *" -Wno-ignored-optimization-argument "*) ;;
        *) printf ' %s' "-Wno-ignored-optimization-argument" ;;
    esac
}

build_make_cc_driver() {
    if [ -n "$CC_TARGET_FLAGS" ]; then
        printf '%s %s' "$CC_DRIVER" "$CC_TARGET_FLAGS"
    else
        printf '%s' "$CC_DRIVER"
    fi
}

CFLAGS_ARR=()
CFLAGS_EFFECTIVE="$(append_clang_warning_compat "$CFLAGS")"
if [ -n "$CFLAGS_EFFECTIVE" ]; then
    read -r -a CFLAGS_ARR <<< "$CFLAGS_EFFECTIVE"
fi

LDFLAGS_ARR=()
if [ -n "$LDFLAGS" ]; then
    read -r -a LDFLAGS_ARR <<< "$LDFLAGS"
fi

CC_MAKE_DRIVER="$(build_make_cc_driver)"

quote_cmd() {
    printf '%q ' "$@"
    echo
}

# 与 bin/uya（main.uya）一致：UYA_SPLIT_C 表示开启且非关闭值、且未指定 UYA_SPLIT_C_DIR 时，默认 .uyacache
if [ -z "${UYA_SPLIT_C_DIR:-}" ] && [ -n "${UYA_SPLIT_C:-}" ]; then
    case "$UYA_SPLIT_C" in
        0|false|no|off) ;;
        *) export UYA_SPLIT_C_DIR=".uyacache" ;;
    esac
fi

# 与 src/main.uya 中 link_split_with_make 对齐：多文件 C（UYA_SPLIT_C_DIR）下用 Makefile 链接
run_uya_split_make_link() {
    local split_dir="$1"
    local out_exe="$2"
    local ld_use="$LDFLAGS"
    if [ "$USE_NOSTDLIB" = true ]; then
        if [ "$TARGET_OS" != "linux" ] || [ "$TARGET_ARCH" != "x86_64" ]; then
            echo -e "${RED}✗ UYA_SPLIT_C_DIR 与 --nostdlib 组合仅支持 Linux x86_64${NC}"
            return 1
        fi
        ld_use="$LDFLAGS -nostdlib -static -lgcc"
    fi
    local jobs="${UYA_GCC_JOBS:-2}"
    if [ "$VERBOSE" = true ]; then
        echo "多文件 C 链接: env -u MAKEFLAGS … make -C \"$split_dir\" -j$jobs UYA_OUT=\"$out_exe\" …"
    fi
    # 避免在外层 make -j 时子 make 继承 jobserver 导致死锁（与 src/main.uya link_split_with_make 一致）
    if cc_driver_uses_zig "$CC_DRIVER"; then
        local zig_local_cache="${ZIG_LOCAL_CACHE_DIR:-$split_dir/.zig-cache-local}"
        local zig_global_cache="${ZIG_GLOBAL_CACHE_DIR:-$split_dir/.zig-cache-global}"
        mkdir -p "$zig_local_cache" "$zig_global_cache"
        env -u MAKEFLAGS -u MFLAGS -u GNUMAKEFLAGS \
            ZIG_LOCAL_CACHE_DIR="$zig_local_cache" \
            ZIG_GLOBAL_CACHE_DIR="$zig_global_cache" \
            make -C "$split_dir" -j"$jobs" UYA_OUT="$out_exe" CC="$CC_MAKE_DRIVER" CFLAGS="$CFLAGS_EFFECTIVE" LDFLAGS="$ld_use"
    else
        env -u MAKEFLAGS -u MFLAGS -u GNUMAKEFLAGS make -C "$split_dir" -j"$jobs" UYA_OUT="$out_exe" CC="$CC_MAKE_DRIVER" CFLAGS="$CFLAGS_EFFECTIVE" LDFLAGS="$ld_use"
    fi
}

cleanup_uya_split_cache_dir() {
    local split_dir="$1"
    local makefile="$split_dir/Makefile"
    if [ -z "$split_dir" ] || [ "$split_dir" = "/" ] || [ "$split_dir" = "." ] || [ ! -d "$split_dir" ]; then
        return
    fi
    if [ ! -f "$makefile" ]; then
        return
    fi
    if ! grep -q '^# Generated by Uya --split-c-dir$' "$makefile"; then
        return
    fi

    echo -e "${YELLOW}清理多文件 C 旧缓存: $split_dir${NC}"
    while IFS=: read -r target deps; do
        case "$target" in
            *.o)
                rm -f "$split_dir/$target"
                for dep in $deps; do
                    case "$dep" in
                        *.c|*.h)
                            rm -f "$split_dir/$dep"
                            ;;
                    esac
                done
                ;;
        esac
    done < "$makefile"
    rm -f "$makefile"
    rm -f "${split_dir}/uya" "${split_dir}/uya.build" "${split_dir}/a.out"
    find "$split_dir" -type f -name '*.o' -delete
    find "$split_dir" -depth -type d -empty ! -path "$split_dir" -delete
}

# 多文件自举对比：主编译产物在 src/.uyacache/…，自举产物在 src/build/bootstrap_split_c/…。
# 若 CFLAGS 含 -g，GCC 写入的 DWARF 含绝对路径，两目录路径长度不同会使 .debug_* 与 .note.gnu.build-id 不同，
# 但 .text/.rodata 等一致。此处剥离符号与调试段并去掉 build-id 后再 cmp，用于验证「可执行代码一致」。
uya_bootstrap_cmp_exe_normalized() {
    local a="$1" b="$2"
    if ! command -v strip >/dev/null 2>&1; then
        return 1
    fi
    local t1 t2 nb1 nb2
    t1=$(mktemp)
    t2=$(mktemp)
    nb1=$(mktemp)
    nb2=$(mktemp)
    cp -f "$a" "$t1" && cp -f "$b" "$t2"
    strip "$t1" "$t2" 2>/dev/null || true
    if command -v objcopy >/dev/null 2>&1; then
        if objcopy --remove-section=.note.gnu.build-id "$t1" "$nb1" 2>/dev/null; then
            mv -f "$nb1" "$t1"
        fi
        if objcopy --remove-section=.note.gnu.build-id "$t2" "$nb2" 2>/dev/null; then
            mv -f "$nb2" "$t2"
        fi
    fi
    local rc=1
    cmp -s "$t1" "$t2" && rc=0
    rm -f "$t1" "$t2" "$nb1" "$nb2"
    return "$rc"
}

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 项目根目录
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# src 目录
UYA_SRC_DIR="$SCRIPT_DIR"
# 编译器路径（默认 bin/uya；hosted 分线可用 UYA_COMPILER 覆盖）
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
# 默认输出目录（中间文件）
BUILD_DIR="$REPO_ROOT/src/build"
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
  -b, --bootstrap-compare  自举验证：单文件 diff C；多文件 cmp 可执行文件（含 -g 时若输出目录不同，整文件 cmp 失败后会再剥离调试与 build-id 后 cmp）
  --c99               使用 C99 后端生成 C 代码（输出文件后缀为 .c 时自动启用）
  --line-directives    启用 #line 指令生成（C99 后端，默认禁用）
  --nostdlib          链接时不使用标准库（仅在使用 -e 时有效）
  --safety-proof      启用内存安全检查（传给 uya；默认启用）
  --no-safety-proof   禁用内存安全检查
  --stack-size KB     设置堆栈大小（KB），编译器启动时使用 setrlimit 设置
  --compiler PATH     指定编译器路径（默认: $COMPILER）

共享工具链环境变量:
  TOOLCHAIN          system / zig（默认: system）
  ZIG                zig 可执行文件路径（默认: /home/winger/zig/zig）
  CC                 默认宿主编译器（默认: cc）
  CC_DRIVER          实际调用的 C 编译器命令，可为多词命令（如 "zig cc"）
  CC_TARGET_FLAGS    目标平台额外参数（如 "-target x86_64-windows-gnu"）
  HOST_OS/HOST_ARCH  宿主平台（默认自动探测）
  TARGET_OS/TARGET_ARCH/TARGET_TRIPLE
                     目标平台（默认继承宿主）
  RUNTIME_MODE       hosted / nostdlib
  LINK_MODE          default / static
  UYA_SPLIT_C_DIR    若设置：C99 多文件输出目录 + Makefile，链接走 make -j（默认镜像多 .c；UYA_SPLIT_C_MIRROR=0 为 part1+part2）
  UYA_MULTI_FILE_C   C99 且 -e 时：设为 1/true 则 -o 指向可执行文件，默认多文件 .uyacache（make uya）
  UYA_SINGLE_FILE_C  设为 1/true 则强制单文件 build/<name>.c（make backup 种子；与编译器 --no-split-c 同类效果）
  UYA_GCC_JOBS       上述 make 的并行度（默认 2）
  UYA_BOOTSTRAP_COMPARE_BIN  设为 1/true 时，-b 用 cmp 比较两次可执行文件而非 diff C

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
  $0 --c99 -e --nostdlib        # C99 编译并生成可执行文件，不使用标准库链接

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
USE_NOSTDLIB=false
USE_SAFETY_PROOF=true  # 默认向 uya 传 --safety-proof

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
        --nostdlib)
            USE_NOSTDLIB=true
            shift
            ;;
        --safety-proof)
            USE_SAFETY_PROOF=true
            shift
            ;;
        --no-safety-proof)
            USE_SAFETY_PROOF=false
            shift
            ;;
        --stack-size)
            STACK_SIZE="$2"
            shift 2
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

if [ "$RUNTIME_MODE" = "nostdlib" ]; then
    USE_NOSTDLIB=true
fi
if [ "$USE_NOSTDLIB" = true ]; then
    RUNTIME_MODE="nostdlib"
    if [ "$LINK_MODE" = "default" ]; then
        LINK_MODE="static"
    fi
else
    RUNTIME_MODE="hosted"
fi

if [ -z "$UYA_BOOTSTRAP_PROFILE" ]; then
    if [ "$RUNTIME_MODE" = "nostdlib" ] && [ "$TARGET_OS" = "linux" ] && [ "$TARGET_ARCH" = "x86_64" ]; then
        UYA_BOOTSTRAP_PROFILE="linux-nostdlib"
    elif [ "$RUNTIME_MODE" = "hosted" ] && [ "$TARGET_OS" = "macos" ]; then
        UYA_BOOTSTRAP_PROFILE="darwin-hosted"
    elif [ "$RUNTIME_MODE" = "hosted" ] && [ "$TARGET_OS" = "windows" ]; then
        UYA_BOOTSTRAP_PROFILE="windows-hosted"
    elif [ "$RUNTIME_MODE" = "hosted" ]; then
        UYA_BOOTSTRAP_PROFILE="hosted"
    else
        UYA_BOOTSTRAP_PROFILE="generic"
    fi
fi

if [ -z "$UYA_NATIVE_BOOTSTRAP" ]; then
    if [ "$UYA_BOOTSTRAP_PROFILE" = "darwin-hosted" ] && [ "$HOST_OS" = "macos" ] && [ "$TARGET_OS" = "macos" ] && [ "$HOST_ARCH" = "$TARGET_ARCH" ]; then
        UYA_NATIVE_BOOTSTRAP="1"
    else
        UYA_NATIVE_BOOTSTRAP="0"
    fi
fi

# --nostdlib 选项需要生成可执行文件
if [ "$USE_NOSTDLIB" = true ] && [ "$GENERATE_EXEC" != true ]; then
    echo -e "${RED}错误: --nostdlib 需要同时使用 -e 或 --exec 选项${NC}"
    exit 1
fi

# 显示共享平台/工具链配置
if [ "$VERBOSE" = true ]; then
    echo "共享平台模型:"
    echo "  HOST_OS=$HOST_OS HOST_ARCH=$HOST_ARCH"
    echo "  TARGET_OS=$TARGET_OS TARGET_ARCH=$TARGET_ARCH TARGET_TRIPLE=$TARGET_TRIPLE"
    echo "  RUNTIME_MODE=$RUNTIME_MODE LINK_MODE=$LINK_MODE"
    echo "  UYA_BOOTSTRAP_PROFILE=$UYA_BOOTSTRAP_PROFILE"
    echo "  UYA_NATIVE_BOOTSTRAP=$UYA_NATIVE_BOOTSTRAP"
    echo "  TOOLCHAIN=$TOOLCHAIN"
    echo "  ZIG=$ZIG"
    echo "  CC=$CC"
    echo "  CC_DRIVER=$CC_DRIVER"
    echo "  CC_TARGET_FLAGS=$CC_TARGET_FLAGS"
fi

# 检查编译器是否存在，如果不存在则从备份恢复
if [ ! -f "$COMPILER" ]; then
    echo -e "${YELLOW}编译器 '$COMPILER' 不存在，尝试从备份恢复...${NC}"
    BACKUP_COMPILER_C="$REPO_ROOT/backup/uya.c"
    if [ "$TARGET_OS" = "macos" ]; then
        if [ -f "$REPO_ROOT/backup/uya-hosted-macos.c" ]; then
            BACKUP_COMPILER_C="$REPO_ROOT/backup/uya-hosted-macos.c"
        elif [ -f "$REPO_ROOT/backup/uya-hosted-macos-$TARGET_ARCH.c" ]; then
            BACKUP_COMPILER_C="$REPO_ROOT/backup/uya-hosted-macos-$TARGET_ARCH.c"
        else
            echo -e "${RED}错误: 编译器 '$COMPILER' 不存在，且未找到 macOS 本机 seed${NC}"
            echo "请先运行 'make from-c-native' 构建编译器"
            exit 1
        fi
    fi
    if [ -f "$BACKUP_COMPILER_C" ]; then
        mkdir -p "$REPO_ROOT/bin"
        cp "$BACKUP_COMPILER_C" "$REPO_ROOT/bin/uya.c"
        if [ -f "$REPO_ROOT/bin/uya.c" ]; then
            echo "编译 bin/uya.c ..."
            echo "CFLAGS: $CFLAGS"
            "${CC_CMD[@]}" "${CFLAGS_ARR[@]}" "$REPO_ROOT/bin/uya.c" -o "$COMPILER" "${LDFLAGS_ARR[@]}"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ 编译器已从备份恢复: $COMPILER${NC}"
            else
                echo -e "${RED}错误: 编译 bin/uya.c 失败${NC}"
                exit 1
            fi
        else
            echo -e "${RED}错误: 复制后未找到 bin/uya.c${NC}"
            exit 1
        fi
    else
        echo -e "${RED}错误: 编译器 '$COMPILER' 和备份种子都不存在${NC}"
        if [ "$TARGET_OS" = "macos" ]; then
            echo "请先运行 'make from-c-native' 构建编译器"
        else
            echo "请先运行 'make from-c' 构建编译器"
        fi
        exit 1
    fi
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

# C99 + -e：UYA_MULTI_FILE_C=1 时编译器 -o 指向 bin/<name>（非 .c），触发默认多文件 .uyacache
# UYA_SINGLE_FILE_C=1 时强制单文件 build/<name>.c（与 main.uya 一致，用于 make backup 等）
MULTI_FILE_C=0
if [ "$USE_C99" = true ] && [ "$GENERATE_EXEC" = true ]; then
    case "${UYA_SINGLE_FILE_C:-}" in
        1|true|yes|YES) ;;
        *)
            if [ "${UYA_MULTI_FILE_C:-}" = "1" ] || [ "${UYA_MULTI_FILE_C:-}" = "true" ]; then
                MULTI_FILE_C=1
            fi
            ;;
    esac
fi

# 输出文件路径
OUTPUT_FILE="$BUILD_DIR/$OUTPUT_NAME"

# 如果输出文件后缀是 .c，自动使用 C99 后端
if [[ "$OUTPUT_NAME" == *.c ]]; then
    USE_C99=true
fi

# 如果使用 C99 后端但输出文件不是 .c 后缀，默认单文件时为 build/<name>.c；多文件模式不写该单文件
if [ "$USE_C99" = true ] && [[ "$OUTPUT_NAME" != *.c ]]; then
    if [ "$MULTI_FILE_C" = "1" ]; then
        OUTPUT_FILE=""
    else
        OUTPUT_FILE="$BUILD_DIR/${OUTPUT_NAME}.c"
    fi
fi

mkdir -p "$BIN_DIR"
EXECUTABLE_FILE="$BIN_DIR/$OUTPUT_NAME$TARGET_EXE_SUFFIX"
COMPILER_OUTPUT_FOR_UYA="$OUTPUT_FILE"
# 多文件自举：-o 与正在运行的 bin/uya 同一路径时，打开写会截断/覆盖可执行文件，导致编译失败。改用临时名再 mv。
MULTI_FILE_OUT_STAGING=""
if [ "$MULTI_FILE_C" = "1" ]; then
    if [ -z "${UYA_SPLIT_C_DIR:-}" ]; then
        export UYA_SPLIT_C_DIR=".uyacache"
    fi
    export UYA_SPLIT_C=1
    COMPILER_OUTPUT_FOR_UYA="$EXECUTABLE_FILE"
    if [ -f "$COMPILER" ]; then
        _cr="$(realpath "$COMPILER" 2>/dev/null || echo "$COMPILER")"
        _out="$(realpath "$COMPILER_OUTPUT_FOR_UYA" 2>/dev/null || echo "$COMPILER_OUTPUT_FOR_UYA")"
        if [ "$_cr" = "$_out" ]; then
            MULTI_FILE_OUT_STAGING=1
            EXECUTABLE_FILE="${BIN_DIR}/${OUTPUT_NAME}.build${TARGET_EXE_SUFFIX}"
            COMPILER_OUTPUT_FOR_UYA="$EXECUTABLE_FILE"
        fi
    fi
    SPLIT_CACHE_DIR="${UYA_SPLIT_C_DIR:-.uyacache}"
    cleanup_uya_split_cache_dir "$SPLIT_CACHE_DIR"
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

# 自举编译器自身时，自动依赖可能漏掉 codegen/c99 子模块；
# 通过环境变量强制走手动文件列表，保证按固定顺序编译完整源码树。
if [ "${UYA_FORCE_MANUAL_DEPS:-0}" = "1" ] || [ "${UYA_FORCE_MANUAL_DEPS:-false}" = "true" ]; then
    USE_AUTO_DEPS=false
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}检测到 UYA_FORCE_MANUAL_DEPS，使用手动文件列表模式${NC}"
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
        "parser/declarations.uya"
        "parser/expressions.uya"
        "parser/primary.uya"
        "parser/statements.uya"
        "parser/types.uya"
        "parser/main.uya"
        "checker/types.uya"
        "checker/symbols.uya"
        "checker/lookup.uya"
        "checker/interval.uya"
        "checker/type_accessors.uya"
        "checker/type_utils.uya"
        "checker/type_from_ast.uya"
        "checker/proof.uya"
        "checker/generics.uya"
        "checker/modules.uya"
        "checker/macro_expand.uya"
        "checker/optimizer.uya"
        "checker/check_expr.uya"
        "checker/check_expr_extra.uya"
        "checker/check_call.uya"
        "checker/check_node_extra.uya"
        "checker/check_stmt.uya"
        "checker/async_frame_meta.uya"
        "checker/main.uya"
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
if [ "$MULTI_FILE_C" = "1" ]; then
    echo "编译器 -o: $COMPILER_OUTPUT_FOR_UYA（多文件 C，默认 .uyacache）"
else
    echo "输出文件: $OUTPUT_FILE"
fi
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

# 设置 UYA_ROOT 环境变量，指向 lib 目录
# 这样编译器可以找到标准库文件（lib/std/...）
export UYA_ROOT="$REPO_ROOT/lib/"

# 执行编译
if [ "$USE_AUTO_DEPS" = true ]; then
    # 自动依赖：仅传主文件。entry.uya 由 compile_files 在检测到 export fn main 时注入；
    # 若此处再传 entry.uya，processed_files[0] 可能先为 entry 路径，use main 会误扫 lib/.../entry/ 而非 src/，导致合并为空、链接缺 main。
    COMPILER_CMD=("$COMPILER" "$INPUT_PATH" -o "$COMPILER_OUTPUT_FOR_UYA")
else
    # 使用手动文件列表模式：传递所有文件
    COMPILER_CMD=("$COMPILER" "${FULL_PATHS[@]}" -o "$COMPILER_OUTPUT_FOR_UYA")
fi
if [ "$USE_C99" = true ]; then
    COMPILER_CMD+=(--c99)
fi
if [ "$USE_NOSTDLIB" = true ]; then
    COMPILER_CMD+=(--nostdlib)
fi
if [ "$USE_LINE_DIRECTIVES" = true ]; then
    COMPILER_CMD+=(--line-directives)
fi
if [ "$USE_SAFETY_PROOF" = true ]; then
    COMPILER_CMD+=(--safety-proof)
else
    COMPILER_CMD+=(--no-safety-proof)
fi
# 不传递 -exec 给编译器：自举编译器使用 std.runtime 提供 main()，若用 -exec 会链接 bridge.c 导致重复 main 和 uya_main 未定义。
# 可执行文件由本脚本在编译成功后统一链接生成（见下方 LINK_CMD）。

if [ "$VERBOSE" = true ]; then
    echo "开始多文件编译..."
    echo "UYA_ROOT: $UYA_ROOT"
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
# 注意：确保 UYA_ROOT 环境变量被传递给编译器
# 堆栈大小由 Uya 编译器在启动时使用 setrlimit 设置
if [ "$VERBOSE" = true ] || [ "$DEBUG" = true ]; then
    # 详细模式：显示所有输出
    env UYA_ROOT="$UYA_ROOT" "${COMPILER_CMD[@]}" 2>&1 | tee "$TEMP_OUTPUT"
    COMPILER_EXIT=${PIPESTATUS[0]}
else
    # 普通模式：只显示关键信息，过滤调试输出
    env UYA_ROOT="$UYA_ROOT" "${COMPILER_CMD[@]}" > "$TEMP_OUTPUT" 2>&1
    COMPILER_EXIT=$?
    
    # 提取关键信息：阶段标题、进度、错误、警告
    # 显示编译阶段信息（=== 开头的行、解析/合并/类型检查/代码生成完成等进度）
    awk '
        /^===|  解析完成|AST 合并完成|类型检查通过|代码生成完成/ {
            print;
            count++;
            if (count >= 50) exit;
        }
    ' "$TEMP_OUTPUT"
    # 显示错误和警告（但不显示调试信息）
    awk '
        /错误:|警告:/ && $0 !~ /调试:/ {
            print;
            count++;
            if (count >= 30) exit;
        }
    ' "$TEMP_OUTPUT"

    if [ $COMPILER_EXIT -ne 0 ]; then
        echo ""
        echo "编译失败，显示最近 120 行详细输出："
        tail -n 120 "$TEMP_OUTPUT"
        echo ""
        echo "提示: 可加 --verbose 查看完整编译日志"
    fi
fi

# 提取所有错误信息到单独文件
grep -E "错误:" "$TEMP_OUTPUT" > "$TEMP_ERRORS" || true

SPLIT_LINK_DIR=""
if [ -n "${UYA_SPLIT_C_DIR:-}" ]; then
    SPLIT_LINK_DIR="$UYA_SPLIT_C_DIR"
elif [ "$MULTI_FILE_C" = "1" ]; then
    SPLIT_LINK_DIR=".uyacache"
fi

# 兼容旧编译器的内部多文件链接缺陷：
# 若 C 代码与 split Makefile 已成功生成，但编译器在最后一步调用其内部 make 链接失败，
# 则交由本脚本后续的 run_uya_split_make_link 统一完成外部链接。
if [ $COMPILER_EXIT -ne 0 ] && [ "$MULTI_FILE_C" = "1" ] && [ -n "$SPLIT_LINK_DIR" ]; then
    if [ -f "$SPLIT_LINK_DIR/Makefile" ] && grep -q "代码生成完成" "$TEMP_OUTPUT"; then
        if grep -q "错误：make 链接失败" "$TEMP_OUTPUT" || grep -q "错误：链接失败" "$TEMP_OUTPUT"; then
            echo ""
            echo -e "${YELLOW}检测到旧编译器内部多文件链接失败，改由脚本执行外部链接...${NC}"
            COMPILER_EXIT=0
        fi
    fi
fi

# 检查编译结果
if [ $COMPILER_EXIT -eq 0 ]; then
    # 注意：--nostdlib 模式暂不重新编译标准库
    # 当前编译器源代码已通过 use 语句导入了 std.* 标准库
    # 这些标准库函数已经在编译器源代码中声明，不需要额外重新编译
    
    echo ""
    echo -e "${GREEN}✓ 编译成功！${NC}"
    echo ""
    
    # 确定实际生成的文件路径（EXECUTABLE_FILE 在解析 OUTPUT 时已设）
    if [ "$GENERATE_EXEC" = true ]; then
        mkdir -p "$BIN_DIR"
        
        # 检查可执行文件是否需要由本脚本补充链接（多文件 C 时编译器已链接则跳过）
        NEED_LINK=false
        if [ "$MULTI_FILE_C" = "1" ]; then
            if [ ! -f "$EXECUTABLE_FILE" ]; then
                NEED_LINK=true
            fi
        elif [ "$USE_NOSTDLIB" = true ]; then
            NEED_LINK=true
        elif [ ! -f "$EXECUTABLE_FILE" ]; then
            NEED_LINK=true
        elif [ "$USE_C99" = true ] && [ -n "${UYA_SPLIT_C_DIR:-}" ] && [ -f "${UYA_SPLIT_C_DIR}/uya_part1.c" ] && [ -f "$EXECUTABLE_FILE" ] && [ "${UYA_SPLIT_C_DIR}/uya_part1.c" -nt "$EXECUTABLE_FILE" ]; then
            NEED_LINK=true
        elif [ "$USE_C99" = true ] && [ -n "$OUTPUT_FILE" ] && [ -f "$OUTPUT_FILE" ] && [ -f "$EXECUTABLE_FILE" ] && [ "$OUTPUT_FILE" -nt "$EXECUTABLE_FILE" ]; then
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

            # 对于 C99 后端，尝试自动链接
            # 方案 C：双入口，不再需要 bridge.c
            # std.runtime 提供 export extern "libc" fn main(argc, argv) 作为 C 入口
            # 用户 export fn main() 被编译为 main_main()
            if [ "$USE_C99" = true ] && [ -n "${UYA_SPLIT_C_DIR:-}" ] && [ -f "${UYA_SPLIT_C_DIR}/Makefile" ]; then
                LINK_CMD_DESC="make -C ${UYA_SPLIT_C_DIR} -j\${UYA_GCC_JOBS:-2} UYA_OUT=${EXECUTABLE_FILE} CC=${CC_DRIVER} ..."
                if run_uya_split_make_link "$UYA_SPLIT_C_DIR" "$EXECUTABLE_FILE"; then
                    echo -e "${GREEN}✓ C99 可执行文件已生成（多文件 C / make）: $EXECUTABLE_FILE${NC}"
                else
                    echo -e "${RED}✗ 多文件 C 链接失败${NC}"
                    echo "  可尝试: $LINK_CMD_DESC"
                    exit 1
                fi
            elif [ "$USE_C99" = true ] && [ "$MULTI_FILE_C" = "1" ] && [ -f ".uyacache/Makefile" ]; then
                LINK_CMD_DESC="make -C .uyacache -j\${UYA_GCC_JOBS:-2} UYA_OUT=${EXECUTABLE_FILE} ..."
                if run_uya_split_make_link ".uyacache" "$EXECUTABLE_FILE"; then
                    echo -e "${GREEN}✓ C99 可执行文件已生成（默认 .uyacache / make）: $EXECUTABLE_FILE${NC}"
                else
                    echo -e "${RED}✗ 默认多文件 C 链接失败${NC}"
                    echo "  可尝试: $LINK_CMD_DESC"
                    exit 1
                fi
            elif [ "$USE_C99" = true ] && [ -n "$OUTPUT_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
                LINK_CMD_DESC=""
                if [ "$USE_NOSTDLIB" = true ]; then
                    if [ "$TARGET_OS" != "linux" ] || [ "$TARGET_ARCH" != "x86_64" ]; then
                        echo -e "${RED}✗ 当前 --nostdlib 仅实现 Linux x86_64 路径${NC}"
                        echo "目标平台: ${TARGET_OS}/${TARGET_ARCH}"
                        echo "请先使用 hosted 路径，或为该目标平台单独实现 nostdlib 入口与链接策略"
                        exit 1
                    fi

                    # --nostdlib：编译器在传入 --nostdlib 时已在生成 C 内含 _start 与 main 原型，勿再前置片段（否则重复定义 _start）
                    UYA_O="$BUILD_DIR/uya.o"
                    # make clean 会删掉 src/build；若中间有步骤未重建目录，此处保证存在（避免 cc 无法创建 .o）
                    mkdir -p "$BUILD_DIR"
                    if [ "$VERBOSE" = true ]; then
                        echo "编译 $OUTPUT_FILE -> $UYA_O (-nostdlib)"
                    fi

                    if ! "${CC_CMD[@]}" "${CFLAGS_ARR[@]}" -fno-stack-protector -c "$OUTPUT_FILE" -o "$UYA_O" 2>&1; then
                        echo -e "${RED}✗ 编译 nostdlib 目标 C 失败${NC}"
                        exit 1
                    fi

                    # 获取 crt 文件路径（仅 crti.o 和 crtn.o，不使用 crt1.o）
                    CRTI="$("${CC_CMD[@]}" -print-file-name=crti.o 2>/dev/null)"
                    CRTN="$("${CC_CMD[@]}" -print-file-name=crtn.o 2>/dev/null)"
                    if [ -z "$CRTI" ] || [ "$CRTI" = "crti.o" ] || [ ! -f "$CRTI" ] || [ -z "$CRTN" ] || [ "$CRTN" = "crtn.o" ] || [ ! -f "$CRTN" ]; then
                        echo -e "${RED}✗ 当前工具链无法提供 Linux nostdlib 所需的 CRT 对象${NC}"
                        echo "CC_DRIVER: $CC_DRIVER"
                        echo "CC_TARGET_FLAGS: $CC_TARGET_FLAGS"
                        echo "建议：使用支持 Linux x86_64 nostdlib 的工具链，或切换到 hosted 路径"
                        exit 1
                    fi

                    LINK_CMD=("${CC_CMD[@]}" "${CFLAGS_ARR[@]}" -fno-stack-protector -no-pie -nostdlib -static -o "$EXECUTABLE_FILE" "$CRTI" "$UYA_O" "$CRTN" "${LDFLAGS_ARR[@]}")
                else
                    # 普通模式：直接编译链接（stderr 使用 libc.stderr，无需 get_stderr 桥接）
                    # Darwin / hosted 主线：使用系统 libc 与默认链接路径，不走 Linux 的 -nostdlib -static
                    # 注意：不使用 -static，避免 errno TLS 冲突
                    EXTRA_HOST_SOURCES=()
                    if [ "$HOST_OS" = "macos" ] && [ "$TARGET_OS" = "macos" ] && [ "$RUNTIME_MODE" = "hosted" ] && [ -f "$REPO_ROOT/src/host/macos_stat_shim.c" ]; then
                        EXTRA_HOST_SOURCES+=("$REPO_ROOT/src/host/macos_stat_shim.c")
                    fi
                    LINK_CMD=("${CC_CMD[@]}" "${CFLAGS_ARR[@]}" "$OUTPUT_FILE" "${EXTRA_HOST_SOURCES[@]}" -o "$EXECUTABLE_FILE" "${LDFLAGS_ARR[@]}")
                fi

                LINK_CMD_DESC="$(quote_cmd "${LINK_CMD[@]}")"

                if [ "$VERBOSE" = true ]; then
                    echo "执行链接命令: $LINK_CMD_DESC"
                fi

                if "${LINK_CMD[@]}" 2>&1; then
                    echo -e "${GREEN}✓ C99 可执行文件已生成: $EXECUTABLE_FILE${NC}"
                else
                    echo -e "${RED}✗ 链接失败${NC}"
                    echo ""
                    echo "可以尝试手动链接："
                    echo "  $LINK_CMD_DESC"
                    exit 1
                fi
            else
                # 非 C99 后端或文件不存在
                echo -e "${RED}✗ 可执行文件生成失败${NC}"
                echo "预期可执行文件路径: $EXECUTABLE_FILE"
                echo "目标文件路径: $OUTPUT_FILE"
                if [ "$USE_C99" = true ] && [ -n "${UYA_SPLIT_C_DIR:-}" ]; then
                    echo "提示: 已设置 UYA_SPLIT_C_DIR=${UYA_SPLIT_C_DIR}，但未找到 ${UYA_SPLIT_C_DIR}/Makefile（代码生成是否成功？）"
                fi
                if [ -f "$OUTPUT_FILE" ]; then
                    echo ""
                    echo "目标文件已生成，但链接失败。可能的原因："
                    echo "  1. 系统未安装链接器（gcc、clang 或 lld）"
                    echo "  2. 链接器执行失败（检查编译输出中的错误信息）"
                    echo ""
                    echo "可以尝试手动链接："
                    if [ "$USE_NOSTDLIB" = true ]; then
                        echo "  ${CC_DRIVER} ${CC_TARGET_FLAGS} $CFLAGS -no-pie -nostdlib -static \"$OUTPUT_FILE\" -o \"$EXECUTABLE_FILE\" $LDFLAGS"
                    else
                        echo "  ${CC_DRIVER} ${CC_TARGET_FLAGS} $CFLAGS \"$OUTPUT_FILE\" -o \"$EXECUTABLE_FILE\" $LDFLAGS"
                    fi
                fi
                exit 1
            fi
        fi
        # 多文件自举：-o 曾指向 bin/uya.build，成功后移回 bin/uya
        if [ "$MULTI_FILE_C" = "1" ] && [ -n "${MULTI_FILE_OUT_STAGING:-}" ]; then
            if [ -f "${BIN_DIR}/${OUTPUT_NAME}.build${TARGET_EXE_SUFFIX}" ]; then
                mv -f "${BIN_DIR}/${OUTPUT_NAME}.build${TARGET_EXE_SUFFIX}" "${BIN_DIR}/${OUTPUT_NAME}${TARGET_EXE_SUFFIX}"
            fi
            EXECUTABLE_FILE="${BIN_DIR}/${OUTPUT_NAME}${TARGET_EXE_SUFFIX}"
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
        if [ -n "$OUTPUT_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
            echo "目标文件: $OUTPUT_FILE（中间文件，可删除）"
        elif [ -n "${UYA_SPLIT_C_DIR:-}" ]; then
            echo "多文件 C 输出目录: ${UYA_SPLIT_C_DIR}（Makefile + uya_part1.c；默认镜像为多 .c，UYA_SPLIT_C_MIRROR=0 时为 uya_part2.c）"
        elif [ "$MULTI_FILE_C" = "1" ] && [ -d ".uyacache" ]; then
            echo "多文件 C 输出目录: .uyacache（默认镜像；UYA_SPLIT_C_MIRROR=0 时为 uya_part1+part2）"
        fi

        # 自举对比：默认 diff 两次 C；UYA_SPLIT_C_DIR / UYA_MULTI_FILE_C / UYA_BOOTSTRAP_COMPARE_BIN 时改为 cmp 两次可执行文件
        if [ "$BOOTSTRAP_COMPARE" = true ] && [ -f "$EXECUTABLE_FILE" ]; then
            BOOTSTRAP_BIN_COMPARE=false
            case "${UYA_BOOTSTRAP_COMPARE_BIN:-}" in
                1|true|yes|YES) BOOTSTRAP_BIN_COMPARE=true ;;
            esac
            if [ "$UYA_BOOTSTRAP_PROFILE" = "darwin-hosted" ] && [ "$MULTI_FILE_C" != "1" ] && [ -z "${UYA_SPLIT_C_DIR:-}" ]; then
                # Darwin 主线默认优先比较 C 输出，避免依赖 GNU/ELF 风格的二进制规范化工具链。
                BOOTSTRAP_BIN_COMPARE=false
            fi
            if [ -n "${UYA_SPLIT_C_DIR:-}" ] || [ "$MULTI_FILE_C" = "1" ]; then
                BOOTSTRAP_BIN_COMPARE=true
            fi
            if [ "$BOOTSTRAP_BIN_COMPARE" != true ] && [ ! -f "$OUTPUT_FILE" ]; then
                echo ""
                echo -e "${YELLOW}跳过自举对比：未生成单文件 C（$OUTPUT_FILE），且未启用二进制对比${NC}"
            else
            echo ""
            echo "=========================================="
            if [ "$BOOTSTRAP_BIN_COMPARE" = true ]; then
                echo "自举对比：用自举编译器编译自身，对比可执行文件（cmp）"
            else
                echo "自举对比：用自举编译器编译自身，对比 C 输出（diff）"
                if [ "$UYA_BOOTSTRAP_PROFILE" = "darwin-hosted" ]; then
                    echo "Darwin hosted（单文件自举）：默认优先使用 C 输出对比，避免依赖 GNU/ELF 风格的二进制规范化。"
                fi
            fi
            echo "=========================================="
            BOOTSTRAP_C="$BUILD_DIR/compiler_bootstrap.c"
            BOOTSTRAP_EXE="$BUILD_DIR/uya_bootstrap_compare${TARGET_EXE_SUFFIX}"
            BOOTSTRAP_SPLIT_DIR="${BUILD_DIR}/bootstrap_split_c"
            if [ "$VERBOSE" = true ]; then
                echo "自举编译器: $EXECUTABLE_FILE"
                echo "输入路径: $INPUT_PATH"
                if [ "$BOOTSTRAP_BIN_COMPARE" != true ]; then
                    echo "C 编译器输出: $OUTPUT_FILE"
                fi
                echo "自举输出 C: $BOOTSTRAP_C"
                echo "自举对比可执行文件: $BOOTSTRAP_EXE"
            fi
            BOOTSTRAP_LOG=$(mktemp)
            BOOTSTRAP_UYA_FLAGS=(--c99)
            if [ "$USE_NOSTDLIB" = true ]; then
                BOOTSTRAP_UYA_FLAGS+=(--nostdlib)
            fi
            # 与主编译 COMPILER_CMD 一致：默认保持 safety proof 开启
            if [ "$USE_SAFETY_PROOF" = true ]; then
                BOOTSTRAP_UYA_FLAGS+=(--safety-proof)
            else
                BOOTSTRAP_UYA_FLAGS+=(--no-safety-proof)
            fi
            # 多文件自举：须与主编译一致（-o 为可执行文件 + UYA_SPLIT_C_DIR）；勿用 -o *.c，否则会走单文件 C 与主编译多文件不一致
            if [ "$BOOTSTRAP_BIN_COMPARE" = true ] && { [ -n "${UYA_SPLIT_C_DIR:-}" ] || [ "$MULTI_FILE_C" = "1" ]; }; then
                rm -rf "$BOOTSTRAP_SPLIT_DIR"
                mkdir -p "$BOOTSTRAP_SPLIT_DIR"
            fi
            if [ "$USE_AUTO_DEPS" = true ]; then
                ENTRY_FILE="$REPO_ROOT/lib/std/runtime/entry/entry.uya"
                if [ "$BOOTSTRAP_BIN_COMPARE" = true ] && { [ -n "${UYA_SPLIT_C_DIR:-}" ] || [ "$MULTI_FILE_C" = "1" ]; }; then
                    (ulimit -s 65536 2>/dev/null || true; UYA_ROOT="$UYA_ROOT" UYA_SPLIT_C_DIR="$BOOTSTRAP_SPLIT_DIR" "$EXECUTABLE_FILE" "$INPUT_PATH" "$ENTRY_FILE" -o "$BOOTSTRAP_EXE" "${BOOTSTRAP_UYA_FLAGS[@]}") >"$BOOTSTRAP_LOG" 2>&1
                else
                    (ulimit -s 65536 2>/dev/null || true; UYA_ROOT="$UYA_ROOT" "$EXECUTABLE_FILE" "$INPUT_PATH" "$ENTRY_FILE" -o "$BOOTSTRAP_C" "${BOOTSTRAP_UYA_FLAGS[@]}") >"$BOOTSTRAP_LOG" 2>&1
                fi
            else
                if [ "$BOOTSTRAP_BIN_COMPARE" = true ] && { [ -n "${UYA_SPLIT_C_DIR:-}" ] || [ "$MULTI_FILE_C" = "1" ]; }; then
                    (ulimit -s 65536 2>/dev/null || true; UYA_ROOT="$UYA_ROOT" UYA_SPLIT_C_DIR="$BOOTSTRAP_SPLIT_DIR" "$EXECUTABLE_FILE" "${FULL_PATHS[@]}" -o "$BOOTSTRAP_EXE" "${BOOTSTRAP_UYA_FLAGS[@]}") >"$BOOTSTRAP_LOG" 2>&1
                else
                    (ulimit -s 65536 2>/dev/null || true; UYA_ROOT="$UYA_ROOT" "$EXECUTABLE_FILE" "${FULL_PATHS[@]}" -o "$BOOTSTRAP_C" "${BOOTSTRAP_UYA_FLAGS[@]}") >"$BOOTSTRAP_LOG" 2>&1
                fi
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
            else
                rm -f "$BOOTSTRAP_LOG"
                if [ "$BOOTSTRAP_BIN_COMPARE" = true ]; then
                    rm -f "$BOOTSTRAP_EXE"
                    if { [ -n "${UYA_SPLIT_C_DIR:-}" ] || [ "$MULTI_FILE_C" = "1" ]; } && [ -f "${BOOTSTRAP_SPLIT_DIR}/Makefile" ]; then
                        if ! run_uya_split_make_link "$BOOTSTRAP_SPLIT_DIR" "$BOOTSTRAP_EXE"; then
                            echo -e "${RED}✗ 自举阶段多文件 C 链接失败${NC}"
                            exit 1
                        fi
                    elif [ -f "$BOOTSTRAP_C" ]; then
                        if [ "$USE_NOSTDLIB" = true ]; then
                            if [ "$TARGET_OS" != "linux" ] || [ "$TARGET_ARCH" != "x86_64" ]; then
                                echo -e "${RED}✗ 二进制自举对比暂不支持当前平台的 --nostdlib${NC}"
                                exit 1
                            fi
                            UYA_O_B="$BUILD_DIR/uya_bootstrap.o"
                            mkdir -p "$BUILD_DIR"
                            if ! "${CC_CMD[@]}" "${CFLAGS_ARR[@]}" -fno-stack-protector -c "$BOOTSTRAP_C" -o "$UYA_O_B" 2>&1; then
                                echo -e "${RED}✗ 自举 C 编译为 .o 失败${NC}"
                                exit 1
                            fi
                            CRTI="$("${CC_CMD[@]}" -print-file-name=crti.o 2>/dev/null)"
                            CRTN="$("${CC_CMD[@]}" -print-file-name=crtn.o 2>/dev/null)"
                            if ! "${CC_CMD[@]}" "${CFLAGS_ARR[@]}" -fno-stack-protector -no-pie -nostdlib -static -o "$BOOTSTRAP_EXE" "$CRTI" "$UYA_O_B" "$CRTN" "${LDFLAGS_ARR[@]}" 2>&1; then
                                echo -e "${RED}✗ 自举可执行文件链接失败${NC}"
                                exit 1
                            fi
                        else
                            if ! "${CC_CMD[@]}" "${CFLAGS_ARR[@]}" "$BOOTSTRAP_C" -o "$BOOTSTRAP_EXE" "${LDFLAGS_ARR[@]}" 2>&1; then
                                echo -e "${RED}✗ 自举可执行文件链接失败${NC}"
                                exit 1
                            fi
                        fi
                    else
                        echo -e "${RED}✗ 自举未生成可供链接的输出${NC}"
                        exit 1
                    fi
                    if cmp -s "$EXECUTABLE_FILE" "$BOOTSTRAP_EXE"; then
                        echo -e "${GREEN}✓ 自举对比一致：主编译器与自举编译器生成的可执行文件字节相同（cmp）${NC}"
                    elif uya_bootstrap_cmp_exe_normalized "$EXECUTABLE_FILE" "$BOOTSTRAP_EXE"; then
                        echo -e "${GREEN}✓ 自举对比一致：剥离调试信息与 build-id 后可执行文件相同（多文件 + -g 时 DWARF 源路径因输出目录不同而变化，整文件 cmp 可能失败）${NC}"
                    else
                        echo -e "${RED}✗ 自举对比不一致：两次可执行文件不同${NC}"
                        echo "  主编译器: $EXECUTABLE_FILE"
                        echo "  自举编译器: $BOOTSTRAP_EXE"
                        if command -v sha256sum >/dev/null 2>&1; then
                            sha256sum "$EXECUTABLE_FILE" "$BOOTSTRAP_EXE"
                        fi
                        exit 1
                    fi
                elif [ -f "$BOOTSTRAP_C" ] && [ -f "$OUTPUT_FILE" ]; then
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
        fi
    elif [ -n "$OUTPUT_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
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
            echo "  ${CC_DRIVER} ${CC_TARGET_FLAGS} $CFLAGS \"$OUTPUT_FILE\" -o \"${OUTPUT_FILE%.o}${TARGET_EXE_SUFFIX}\" $LDFLAGS"
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
