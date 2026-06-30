#!/bin/bash
# 验证 std.path 的平台条件测试能在 Linux / macOS / Windows 目标下生成并运行。
# 在 Linux 宿主上，macOS 目标通过最小 _NSGetEnviron shim 复用同一套纯路径语义测试。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build/std_path_platform_targets"
COMPILER="../uya/bin/uya"
TEST_FILE="tests/test_std_path_platform_cfg.uya"
CC_BIN="${CC:-cc}"
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

    echo "验证 std.path 平台条件：$label"
    if ! HOST_OS="$HOST_OS_NAME" HOST_ARCH="$HOST_ARCH_NAME" TARGET_OS="$target_os" TARGET_ARCH="$target_arch" TARGET_TRIPLE="$target_triple" \
        "$COMPILER" --c99 "$TEST_FILE" -o "$out_c" >"$compile_log" 2>&1; then
        cat "$compile_log"
        echo "✗ $label 目标生成 C 失败"
        exit 1
    fi

    if [ -n "$extra_source" ]; then
        if ! "$CC_BIN" -std=c99 -O0 -fno-builtin "$out_c" "$extra_source" -o "$out_bin" >"$link_log" 2>&1; then
            cat "$link_log"
            echo "✗ $label 目标宿主链接失败"
            exit 1
        fi
    else
        if ! "$CC_BIN" -std=c99 -O0 -fno-builtin "$out_c" -o "$out_bin" >"$link_log" 2>&1; then
            cat "$link_log"
            echo "✗ $label 目标宿主链接失败"
            exit 1
        fi
    fi

    if ! "$out_bin" >"$run_log" 2>&1; then
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
