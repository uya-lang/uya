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

int32_t uya_main(void);

int32_t uya_main(void) {
const int32_t max_i32 = 2147483647;
const int32_t min_i32 = ((-2147483647) - 1);
const int32_t a = 2000000000;
const int32_t b = 2000000000;
const int32_t sat_add = ({ int32_t _l = (a); int32_t _r = (b); int32_t _s; __builtin_add_overflow(_l, _r, &_s) ? (_l>=0 && _r>=0 ? 2147483647 : (-2147483647-1)) : _s; });
if ((sat_add != max_i32)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t c = (-2000000000);
const int32_t d = (-2000000000);
const int32_t sat_add_neg = ({ int32_t _l = (c); int32_t _r = (d); int32_t _s; __builtin_add_overflow(_l, _r, &_s) ? (_l>=0 && _r>=0 ? 2147483647 : (-2147483647-1)) : _s; });
if ((sat_add_neg != min_i32)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
const int32_t normal_add = ({ int32_t _l = (10); int32_t _r = (20); int32_t _s; __builtin_add_overflow(_l, _r, &_s) ? (_l>=0 && _r>=0 ? 2147483647 : (-2147483647-1)) : _s; });
if ((normal_add != 30)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
const int32_t e = (-2000000000);
const int32_t f = 2000000000;
const int32_t sat_sub = ({ int32_t _l = (e); int32_t _r = (f); int32_t _s; __builtin_sub_overflow(_l, _r, &_s) ? (_l>=0 && _r<0 ? 2147483647 : (-2147483647-1)) : _s; });
if ((sat_sub != min_i32)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
const int32_t g = 2000000000;
const int32_t h = (-2000000000);
const int32_t sat_sub_pos = ({ int32_t _l = (g); int32_t _r = (h); int32_t _s; __builtin_sub_overflow(_l, _r, &_s) ? (_l>=0 && _r<0 ? 2147483647 : (-2147483647-1)) : _s; });
if ((sat_sub_pos != max_i32)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
const int32_t normal_sub = ({ int32_t _l = (50); int32_t _r = (8); int32_t _s; __builtin_sub_overflow(_l, _r, &_s) ? (_l>=0 && _r<0 ? 2147483647 : (-2147483647-1)) : _s; });
if ((normal_sub != 42)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
const int32_t m1 = 50000;
const int32_t m2 = 50000;
const int32_t sat_mul = ({ int32_t _l = (m1); int32_t _r = (m2); int32_t _s; int32_t _res; if (__builtin_mul_overflow(_l, _r, &_s)) _res = ((_l>=0 && _r>=0) || (_l<0 && _r<0)) ? 2147483647 : (-2147483647-1); else _res = _s; _res; });
if ((sat_mul != max_i32)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
const int32_t normal_mul = ({ int32_t _l = (3); int32_t _r = (7); int32_t _s; int32_t _res; if (__builtin_mul_overflow(_l, _r, &_s)) _res = ((_l>=0 && _r>=0) || (_l<0 && _r<0)) ? 2147483647 : (-2147483647-1); else _res = _s; _res; });
if ((normal_mul != 21)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
const int32_t w1 = max_i32;
const int32_t w2 = 1;
const int32_t wrap_add = ((const int32_t)((uint32_t)(w1) + (uint32_t)(w2)));
if ((wrap_add != min_i32)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
const int32_t wrap_add2 = ((int32_t)((uint32_t)(100) + (uint32_t)(200)));
if ((wrap_add2 != 300)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
const int32_t w3 = min_i32;
const int32_t w4 = 1;
const int32_t wrap_sub = ((const int32_t)((uint32_t)(w3) - (uint32_t)(w4)));
if ((wrap_sub != max_i32)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
const int32_t w5 = 65536;
const int32_t w6 = 65536;
const int32_t wrap_mul = ((const int32_t)((uint32_t)(w5) * (uint32_t)(w6)));
if ((wrap_mul != 0)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
