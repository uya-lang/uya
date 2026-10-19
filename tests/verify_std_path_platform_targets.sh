#!/bin/bash
# 验证 std.path 的平台条件测试能在 Linux / macOS / Windows 目标下生成并运行。
# 在 Linux 宿主上，macOS 目标通过最小 _NSGetEnviron shim 复用同一套纯路径语义测试。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build/std_path_platform_targets"
# 环境变量：UYA_COMPILER 覆盖编译器路径（默认 <root>/bin/uya）。
# 不要用 `../uya/bin/uya` 这类相对路径：它只在「仓库目录名恰好是 uya」的
# 布局下才碰巧指回仓库自己，在 worktree / 改名目录下会直接找不到编译器。
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
TEST_FILE="tests/test_std_path_platform_cfg.uya"
CC_BIN="${CC:-cc}"
# windows 目标用 zig cc 交叉编译（见 compile_and_run_target 说明）。
ZIG_BIN="${ZIG:-zig}"
# 在非 windows 宿主上运行 windows 产物需要 wine；默认探测常见路径。
WINE_BIN="${WINE:-$(command -v wine 2>/dev/null || echo /opt/deepin-wine-staging/bin/wine)}"
HOST_OS_NAME="${HOST_OS:-$(uname -s | tr '[:upper:]' '[:lower:]' | sed -e 's/darwin/macos/' -e 's/msys.*/windows/' -e 's/mingw.*/windows/' -e 's/cygwin.*/windows/')}"
HOST_ARCH_NAME="${HOST_ARCH:-$(uname -m | sed -e 's/amd64/x86_64/' -e 's/aarch64/arm64/')}"
MACOS_SHIM_C="$BUILD_DIR/macos_env_shim.c"

mkdir -p "$BUILD_DIR"
cd "$REPO_ROOT"

if [ ! -x "$COMPILER" ]; then
    echo "✗ 未找到 $COMPILER（请先构建编译器）"
    exit 1
fi

write_macos_env_shim() {
    cat > "$MACOS_SHIM_C" <<'EOF'
extern char **environ;

char ***_NSGetEnviron(void) {
    return &environ;
}
EOF
}

compile_and_run_target() {
    local label="$1"
    local target_os="$2"
    local target_arch="$3"
    local target_triple="$4"
    local extra_source="$5"
    local out_c="$BUILD_DIR/${label}.c"
    local out_bin="$BUILD_DIR/${label}"
    local compile_log="$BUILD_DIR/${label}.compile.log"
    local link_log="$BUILD_DIR/${label}.link.log"
    local run_log="$BUILD_DIR/${label}.run.log"

    # windows 目标的生成 C 会包含 MinGW 头文件（<io.h>/<windows.h> 等，见 codegen 的
    # UYA_TARGET_WINDOWS bridge），宿主 cc 无法编译；必须用 zig cc 交叉编译。
    # 这里按目标选择编译器：windows+非 windows 宿主 -> zig；其它沿用 CC_BIN。
    local target_cc=("$CC_BIN")
    local target_cc_flags=()
    local target_link_libs=()
    if [ "$target_os" = "windows" ] && [ "$HOST_OS_NAME" != "windows" ]; then
        if [ ! -x "$ZIG_BIN" ]; then
            echo "✗ 需要 zig 交叉编译 windows 目标，但未找到可执行 zig: $ZIG_BIN"
            echo "  提示: 设置 ZIG=/path/to/zig，或跳过本项验证"
            exit 1
        fi
        target_cc=("$ZIG_BIN" cc)
        target_cc_flags=(-target "$target_triple"
            -Wno-pointer-sign -Wno-parentheses-equality -Wno-ignored-optimization-argument)
        # Windows 目标的 C 里有 Winsock 桥（send/recv/closesocket/WSAStartup，
        # 见 codegen 的 UYA_TARGET_WINDOWS 段），MinGW 下这些符号在 ws2_32 里；
        # 不显式链接会报一批 `undefined symbol: __declspec(dllimport) send`。
        target_link_libs=(-lws2_32)
    fi

    echo "验证 std.path 平台条件：$label"
    if ! HOST_OS="$HOST_OS_NAME" HOST_ARCH="$HOST_ARCH_NAME" TARGET_OS="$target_os" TARGET_ARCH="$target_arch" TARGET_TRIPLE="$target_triple" \
        "$COMPILER" --c99 "$TEST_FILE" -o "$out_c" >"$compile_log" 2>&1; then
        cat "$compile_log"
        echo "✗ $label 目标生成 C 失败"
        exit 1
    fi

    if [ -n "$extra_source" ]; then
        if ! "${target_cc[@]}" "${target_cc_flags[@]}" -std=c99 -O0 -fno-builtin "$out_c" "$extra_source" -o "$out_bin" "${target_link_libs[@]}" >"$link_log" 2>&1; then
            cat "$link_log"
            echo "✗ $label 目标宿主链接失败"
            exit 1
        fi
    else
        if ! "${target_cc[@]}" "${target_cc_flags[@]}" -std=c99 -O0 -fno-builtin "$out_c" -o "$out_bin" "${target_link_libs[@]}" >"$link_log" 2>&1; then
            cat "$link_log"
            echo "✗ $label 目标宿主链接失败"
            exit 1
        fi
    fi

    # 运行阶段：windows 目标在非 windows 宿主上需要 wine；无 wine 时明确跳过运行，
    # 只保留「生成 + 交叉编译通过」这一级的验证结论，不假装跑过。
    local runner=("$out_bin")
    if [ "$target_os" = "windows" ] && [ "$HOST_OS_NAME" != "windows" ]; then
        if [ ! -x "$WINE_BIN" ]; then
            echo "  提示: 未找到 wine ($WINE_BIN)，跳过 $label 的运行验证（仅验证生成与交叉编译）"
            return 0
        fi
        runner=("$WINE_BIN" "$out_bin")
    fi

    if ! "${runner[@]}" >"$run_log" 2>&1; then
        cat "$run_log"
        echo "✗ $label 目标运行测试失败"
        exit 1
    fi
}

write_macos_env_shim

compile_and_run_target "std_path_platform_linux_x86_64" "linux" "x86_64" "" ""
compile_and_run_target "std_path_platform_macos_x86_64" "macos" "x86_64" "" "$MACOS_SHIM_C"
compile_and_run_target "std_path_platform_windows_x86_64" "windows" "x86_64" "x86_64-windows-gnu" ""

echo "✓ std.path Linux/macOS/Windows 平台条件验证通过"
