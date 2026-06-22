#!/bin/bash
# 验证 macOS hosted 单文件 seed 输出保留关键 C99 extern/shim 声明。
# 由 make check / make check-hosted 调用。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$SCRIPT_DIR/build/macos_hosted_seed_decl_verify"
OUT_C="$OUT_DIR/uya-hosted.c"

mkdir -p "$OUT_DIR"

if [ -n "${UYA_COMPILER:-}" ]; then
    COMPILER="$UYA_COMPILER"
elif [ -x "$REPO_ROOT/bin/uya" ]; then
    COMPILER="$REPO_ROOT/bin/uya"
elif [ -x "$REPO_ROOT/bin/uya-hosted" ]; then
    COMPILER="$REPO_ROOT/bin/uya-hosted"
else
    echo "✗ 未找到可用编译器（请先 make uya 或 make uya-hosted）"
    exit 1
fi

if [ ! -x "$COMPILER" ]; then
    echo "✗ 编译器不可执行: $COMPILER"
    exit 1
fi

echo "验证 macOS hosted 单文件 seed extern 声明..."
HOST_OS=macos HOST_ARCH=x86_64 TARGET_OS=macos TARGET_ARCH=x86_64 TARGET_TRIPLE= \
TOOLCHAIN="${TOOLCHAIN:-system}" ZIG="${ZIG:-}" RUNTIME_MODE=hosted LINK_MODE="${LINK_MODE:-dynamic}" \
UYA_SINGLE_FILE_C=1 UYA_SPLIT_C=0 UYA_SPLIT_C_DIR= UYA_MULTI_FILE_C= UYA_SPLIT_C_MIRROR= \
UYA_BOOTSTRAP_PROFILE=darwin-hosted UYA_NATIVE_BOOTSTRAP=0 \
"$COMPILER" --c99 "$REPO_ROOT/src/main.uya" -o "$OUT_C" >/dev/null 2>&1

require_line() {
    local expected="$1"
    local label="$2"

    if ! grep -Fqx "$expected" "$OUT_C"; then
        echo "✗ 生成的 uya-hosted.c 缺少 $label"
        exit 1
    fi
}

require_line 'extern ssize_t read(int, void *, size_t);' 'read extern 声明'
require_line 'extern ssize_t write(int, const void *, size_t);' 'write extern 声明'
require_line 'extern int uya_host_getsockname(int, void *, uint32_t *) __asm__("_getsockname");' 'getsockname host extern 声明'
require_line 'extern int uya_host_getpeername(int, void *, uint32_t *) __asm__("_getpeername");' 'getpeername host extern 声明'
require_line 'extern int uya_host_poll(void *, uint32_t, int) __asm__("_poll");' 'poll host extern 声明'
require_line 'struct PollFd;' 'PollFd 前向声明'

if ! grep -Fq 'struct err_union_int32_t uya_macos_getsockname(int32_t sockfd, void *addr, uint32_t *addrlen) {' "$OUT_C"; then
    echo "✗ 生成的 uya-hosted.c 缺少 uya_macos_getsockname shim"
    exit 1
fi

if ! grep -Fq 'struct err_union_int32_t uya_macos_getpeername(int32_t sockfd, void *addr, uint32_t *addrlen) {' "$OUT_C"; then
    echo "✗ 生成的 uya-hosted.c 缺少 uya_macos_getpeername shim"
    exit 1
fi

if ! grep -Fq 'struct err_union_int32_t uya_macos_poll(struct PollFd *fds, size_t nfds, int32_t timeout_ms) {' "$OUT_C"; then
    echo "✗ 生成的 uya-hosted.c 缺少 uya_macos_poll shim"
    exit 1
fi

pollfd_decl_line="$(grep -Fn 'struct PollFd;' "$OUT_C" | head -n 1 | cut -d: -f1)"
poll_shim_line="$(grep -Fn 'struct err_union_int32_t uya_macos_poll(struct PollFd *fds, size_t nfds, int32_t timeout_ms) {' "$OUT_C" | head -n 1 | cut -d: -f1)"
if [ -z "$pollfd_decl_line" ] || [ -z "$poll_shim_line" ] || [ "$pollfd_decl_line" -ge "$poll_shim_line" ]; then
    echo "✗ PollFd 前向声明必须早于 uya_macos_poll shim"
    exit 1
fi

echo "✓ macOS hosted 单文件 seed extern 声明通过"
