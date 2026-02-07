// C99 代码由 Uya Mini 编译器生成
// 使用 -std=c99 编译
//
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdarg.h>
#include <string.h>
#include <stdio.h>

// C99 兼容的 alignof 实现
#define uya_alignof(type) offsetof(struct { char c; type t; }, t)

// 错误联合类型（用于 !i64 等）
struct err_union_int64_t { uint32_t error_id; int64_t value; };


// 字符串常量
static const uint8_t str0[] = "Hello from syscall wrappers!\n";
static const uint8_t str1[] = "/tmp/test_file.txt";
static const uint8_t str2[] = "Writing via syscall!\n";

struct TypeInfo;


// 内置 TypeInfo 结构体（由 @mc_type 使用）
struct TypeInfo {
    int8_t * name;
    int32_t size;
    int32_t align;
    int32_t kind;
    bool is_integer;
    bool is_float;
    bool is_bool;
    bool is_pointer;
    bool is_array;
    bool is_void;
};

// 系统调用辅助函数（Linux x86-64）
#ifdef __x86_64__
static inline long uya_syscall0(long nr) {
    register long rax __asm__("rax") = nr;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax) : "rcx", "r11", "memory");
    return rax;
}

static inline long uya_syscall1(long nr, long a1) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi) : "rcx", "r11", "memory");
    return rax;
}

static inline long uya_syscall2(long nr, long a1, long a2) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    register long rsi __asm__("rsi") = a2;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi), "r"(rsi) : "rcx", "r11", "memory");
    return rax;
}

static inline long uya_syscall3(long nr, long a1, long a2, long a3) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    register long rsi __asm__("rsi") = a2;
    register long rdx __asm__("rdx") = a3;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi), "r"(rsi), "r"(rdx) : "rcx", "r11", "memory");
    return rax;
}

static inline long uya_syscall4(long nr, long a1, long a2, long a3, long a4) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    register long rsi __asm__("rsi") = a2;
    register long rdx __asm__("rdx") = a3;
    register long r10 __asm__("r10") = a4;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10) : "rcx", "r11", "memory");
    return rax;
}

static inline long uya_syscall5(long nr, long a1, long a2, long a3, long a4, long a5) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    register long rsi __asm__("rsi") = a2;
    register long rdx __asm__("rdx") = a3;
    register long r10 __asm__("r10") = a4;
    register long r8 __asm__("r8") = a5;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10), "r"(r8) : "rcx", "r11", "memory");
    return rax;
}

static inline long uya_syscall6(long nr, long a1, long a2, long a3, long a4, long a5, long a6) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    register long rsi __asm__("rsi") = a2;
    register long rdx __asm__("rdx") = a3;
    register long r10 __asm__("r10") = a4;
    register long r8 __asm__("r8") = a5;
    register long r9 __asm__("r9") = a6;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10), "r"(r8), "r"(r9) : "rcx", "r11", "memory");
    return rax;
}
#else
#error "@syscall currently only supports Linux x86-64"
#endif

struct err_union_int64_t { uint32_t error_id; int64_t value; };
struct err_union_int64_t sys_write(int64_t fd, int64_t buf, int64_t count);
struct err_union_int64_t sys_open(int64_t path, int64_t flags, int64_t mode);
struct err_union_int64_t sys_close(int64_t fd);
struct err_union_int64_t sys_getpid();
int32_t uya_main(void);

const int64_t SYS_write = 1;

const int64_t SYS_open = 2;

const int64_t SYS_close = 3;

const int64_t SYS_getpid = 39;

const int64_t O_RDONLY = 0;

const int64_t O_WRONLY = 1;

const int64_t O_RDWR = 2;

const int64_t O_CREAT = 64;

const int64_t O_TRUNC = 512;

const int64_t S_IRWXU = 448;

const int64_t STDOUT_FILENO = 1;

struct err_union_int64_t sys_write(int64_t fd, int64_t buf, int64_t count) {
    const struct err_union_int64_t result = ({ long _uya_syscall_ret = uya_syscall3(SYS_write, fd, buf, count); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    struct err_union_int64_t _uya_ret = result;
    return _uya_ret;
}

struct err_union_int64_t sys_open(int64_t path, int64_t flags, int64_t mode) {
    const struct err_union_int64_t result = ({ long _uya_syscall_ret = uya_syscall3(SYS_open, path, flags, mode); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    struct err_union_int64_t _uya_ret = result;
    return _uya_ret;
}

struct err_union_int64_t sys_close(int64_t fd) {
    const struct err_union_int64_t result = ({ long _uya_syscall_ret = uya_syscall1(SYS_close, fd); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    struct err_union_int64_t _uya_ret = result;
    return _uya_ret;
}

struct err_union_int64_t sys_getpid() {
    const struct err_union_int64_t result = ({ long _uya_syscall_ret = uya_syscall0(SYS_getpid); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    struct err_union_int64_t _uya_ret = result;
    return _uya_ret;
}

int32_t uya_main(void) {
const uint8_t * const msg1 = str0;
const int64_t len1 = 30;
(void)(0);
const uint8_t * const path = str1;
const struct err_union_int64_t fd_result = sys_open((int64_t)path, ((O_CREAT | O_WRONLY) | O_TRUNC), S_IRWXU);
const int64_t fd = ({ int32_t _uya_catch_result; const struct err_union_int64_t _uya_catch_tmp = fd_result; if (_uya_catch_tmp.error_id != 0) {
    int32_t _uya_ret = 2;
    return _uya_ret;
} else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
const uint8_t * const msg2 = str2;
const int64_t len2 = 21;
(void)(0);
(void)(0);
const struct err_union_int64_t pid_result = sys_getpid();
(void)(({ int32_t _uya_catch_result; const struct err_union_int64_t _uya_catch_tmp = pid_result; if (_uya_catch_tmp.error_id != 0) {
    int32_t _uya_ret = 5;
    return _uya_ret;
} else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; }));
int32_t _uya_ret = 0;
return _uya_ret;
}
