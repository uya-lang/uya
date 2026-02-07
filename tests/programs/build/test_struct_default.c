// C99 代码由 Uya Mini 编译器生成
// 使用 -std=c99 编译
//
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>

// C99 兼容的 alignof 实现
#define uya_alignof(type) offsetof(struct { char c; type t; }, t)

static inline void *__uya_memcpy(void *dest, const void *src, size_t n) {
    char *d = (char *)dest; const char *s = (const char *)src;
    for (size_t i = 0; i < n; i++) d[i] = s[i]; return dest;
}
static inline int __uya_memcmp(const void *s1, const void *s2, size_t n) {
    const unsigned char *a = (const unsigned char *)s1, *b = (const unsigned char *)s2;
    for (size_t i = 0; i < n; i++) { if (a[i] != b[i]) return a[i] - b[i]; } return 0;
}

// 错误联合类型（用于 !i64 等）
struct err_union_int64_t { uint32_t error_id; int64_t value; };


struct TypeInfo;
struct Config;
struct Point;
struct Server;



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

struct Config {
    int32_t port;
    int32_t max_connections;
    bool debug;
};

struct Point {
    int32_t x;
    int32_t y;
    int32_t z;
};

struct Server {
    uint8_t * name;
    struct Config config;
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

int32_t uya_main(void);

int32_t uya_main(void) {
struct Config cfg;
cfg.port = 8080;
cfg.max_connections = 100;
cfg.debug = false;
if ((cfg.port != 8080)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
if ((cfg.max_connections != 100)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
if ((cfg.debug != false)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
struct Config cfg2 = (struct Config){.port = 3000, .max_connections = 100, .debug = false};
if ((cfg2.port != 3000)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
if ((cfg2.max_connections != 100)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
struct Config cfg3 = (struct Config){.port = 9000, .max_connections = 50, .debug = true};
if ((cfg3.port != 9000)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
if ((cfg3.debug != true)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
struct Point pt = (struct Point){.x = 10, .y = 0, .z = 0};
if ((pt.x != 10)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
if ((pt.y != 0)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
if ((pt.z != 0)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
struct Point pt2 = (struct Point){.x = 5, .y = 15, .z = 0};
if ((pt2.x != 5)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
if ((pt2.y != 15)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
if ((pt2.z != 0)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
