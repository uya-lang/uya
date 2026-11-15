#!/usr/bin/env bash
# 校验「Darwin 目标的生成 C」能过 clang 语法检查。
#
# 为什么需要它：Linux 上的 gcc/clang 看不到 Darwin 头文件里的坑。典型例子是
# `<string.h>` 在 Darwin 上把 `memmove`/`memset`/`memchr`/`memcpy` 定义成**函数式宏**
# （`secure/_string.h` 的 `__memmove_chk_func`），生成 C 里任何
# `extern void *memmove(void *, const void *, size_t);` 都会被宏展开成语法垃圾 ——
# 2026-10-31 的 hosted 判空包装（844fbf0b）就是这样把 macos-ci 的 `make uya-hosted` 打红的，
# 而 Linux 侧全绿。
#
# 做法：用 bin/uya 现场生成一份 macOS arm64 目标的 C（预置一个用到 mem 族的探针程序），
# 再用 zig 自带的 Darwin SDK 头做 `-fsyntax-only`。没有 zig 时跳过（不判失败），
# 与 tests/verify_std_path_platform_targets.sh 等脚本的约定一致。
#
# 参数：无。
# 返回：0 = 通过或跳过；1 = Darwin 目标生成 C 无法通过语法检查。
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

if [ ! -x bin/uya ]; then
    echo "⊘ 跳过 macOS 生成 C 语法检查：bin/uya 不存在（先 make uya）"
    exit 0
fi

ZIG_BIN="${ZIG:-$(bash -c 'command -v zig' 2>/dev/null)}"
if [ -z "$ZIG_BIN" ] || [ ! -x "$ZIG_BIN" ]; then
    echo "⊘ 跳过 macOS 生成 C 语法检查：未找到 zig（需要 zig cc 提供的 Darwin SDK 头）"
    exit 0
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cat > "$WORK_DIR/probe.uya" <<'PROBE'
use libc;

export fn main() i32 {
    var src: [i32: 4] = [1, 2, 3, 4];
    var dst: [i32: 4] = [0, 0, 0, 0];
    var p: *byte = memmove(
        @ptr_from_usize(@usize_from_ptr(&dst)) as *byte,
        @ptr_from_usize(@usize_from_ptr(&src)) as *const byte,
        4 *| @size_of(i32)
    );
    memset(@ptr_from_usize(@usize_from_ptr(&dst)) as *void, 0, 4 *| @size_of(i32));
    var q: *byte = memchr(
        @ptr_from_usize(@usize_from_ptr(&src)) as *const void,
        3,
        4 *| @size_of(i32)
    );
    _ = p;
    _ = q;
    return dst[0];
}
PROBE

echo "生成 macOS arm64 目标 C（hosted）..."
if ! TARGET_OS=macos TARGET_ARCH=arm64 ./bin/uya build "$WORK_DIR/probe.uya" --c99 \
        -o "$WORK_DIR/probe.c" > "$WORK_DIR/gen.log" 2>&1; then
    echo "✗ 生成 macOS 目标 C 失败："
    tail -20 "$WORK_DIR/gen.log"
    exit 1
fi
if [ ! -f "$WORK_DIR/probe.c" ]; then
    echo "✗ 生成 macOS 目标 C 失败：未产出 probe.c"
    tail -20 "$WORK_DIR/gen.log"
    exit 1
fi

# -Werror 与 macos-ci（Apple clang + -Werror）对齐；-Wno-gcc-install-dir-libstdcxx 只用于
# 屏蔽 zig 自带的「未来版本会优先选 GCC 安装目录」提示，对 Apple clang 无副作用。
# 用 -c 只编译不链接：`zig cc` 直接跑会进入链接阶段，Linux 上给不了 macOS 的
# libSystem（报 FileNotFound），那不是语法问题。
echo "用 zig cc -target aarch64-macos 做编译检查..."
if "$ZIG_BIN" cc -target aarch64-macos -std=c99 -c -Werror \
        -Wno-gcc-install-dir-libstdcxx -Wno-unused-command-line-argument \
        "$WORK_DIR/probe.c" -o "$WORK_DIR/probe.o" > "$WORK_DIR/check.log" 2>&1; then
    echo "✓ macOS arm64 目标生成 C 编译检查通过"
    exit 0
fi

echo "✗ macOS arm64 目标生成 C 编译检查失败（Apple clang 下 make uya-hosted 会编译不过）："
head -40 "$WORK_DIR/check.log"
exit 1
