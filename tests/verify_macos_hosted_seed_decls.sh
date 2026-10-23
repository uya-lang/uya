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

require_text() {
    local expected="$1"
    local label="$2"

    if ! grep -Fq "$expected" "$OUT_C"; then
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

# macOS 原生 struct stat / struct dirent 的布局与项目统一的 Stat / Dirent 不同。
# stat / opendir / readdir / closedir 必须保留 uya 实现体，走
# sys_stat -> uya_macos_stat、uya_macos_host_* 逐字段转换；一旦退回宿主裸符号，
# is_file 会把真实存在的文件判成「既不是文件也不是目录」（make uya-hosted 直接失败），
# 模块扫描也读不到目录项（use codegen.c99 等报未找到导出项）。
require_text '__attribute__((used)) int32_t stat(const char * path, struct Stat * buf) {' 'uya 版 stat 桥接实现'
require_text 'struct err_union_int32_t result = sys_stat((const char *)(const uint8_t *)path, buf);' 'stat 转发 sys_stat'
require_text '__attribute__((used)) struct DIR * opendir(const char * name) {' 'uya 版 opendir 桥接实现'
require_text 'void * const host_dir = uya_macos_host_opendir((const char *)name);' 'opendir 走 uya_macos_host_opendir 桥接'
require_text '__attribute__((used)) struct Dirent * readdir(struct DIR * dirp) {' 'uya 版 readdir 桥接实现'
require_text 'uya_macos_host_readdir_fill((void *)dirp, (void *)(&readdir_result))' 'readdir 走 uya_macos_host_readdir_fill 桥接'
require_text '__attribute__((used)) int32_t closedir(struct DIR * dirp) {' 'uya 版 closedir 桥接实现'

# Darwin 的 syscall 编号与 Linux 不同：mmap 族绝不能在 macOS 种子里继续走
# @syscall(SYS_mmap/SYS_munmap/SYS_mprotect)，否则 Apple Silicon 上会执行到不相干的
# syscall（SIGSYS 直接杀进程），make uya-hosted 编译期随机崩在 140。
require_text 'static void *uya_macos_mmap(void *addr, size_t length, int32_t prot, int32_t flags, int32_t fd, int64_t offset) {' 'uya_macos_mmap 宿主绑定'
require_text 'static int32_t uya_macos_munmap(void *addr, size_t length) {' 'uya_macos_munmap 宿主绑定'
require_text 'static int32_t uya_macos_mprotect(void *addr, size_t length, int32_t prot) {' 'uya_macos_mprotect 宿主绑定'
require_text 'uya_macos_mmap(addr, length, prot, flags, fd, offset)' 'sys_mmap 转发 uya_macos_mmap'
require_text 'uya_macos_munmap(addr, length)' 'sys_munmap 转发 uya_macos_munmap'
require_text 'uya_macos_mprotect(addr, length, prot)' 'sys_mprotect 转发 uya_macos_mprotect'
if grep -Fq 'uya_syscall6(libc_SYS_mmap' "$OUT_C"; then
    echo "✗ 生成的 uya-hosted.c 仍在 macOS 上使用裸 mmap syscall"
    exit 1
fi
if grep -Fq 'uya_syscall2(libc_SYS_munmap' "$OUT_C"; then
    echo "✗ 生成的 uya-hosted.c 仍在 macOS 上使用裸 munmap syscall"
    exit 1
fi
if grep -Fq 'uya_syscall3(libc_SYS_mprotect' "$OUT_C"; then
    echo "✗ 生成的 uya-hosted.c 仍在 macOS 上使用裸 mprotect syscall"
    exit 1
fi

echo "✓ macOS hosted 单文件 seed extern 声明通过"
