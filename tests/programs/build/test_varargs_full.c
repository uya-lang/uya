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


// 字符串常量
static const uint8_t str0[] = "direct: %d %d\n";
static const uint8_t str1[] = "add_two(10,20)=%d\n";
static const uint8_t str2[] = "mul_two(5,6)=%d\n";
static const uint8_t str3[] = "sum_three(1,2,3)=%d\n";
static const uint8_t str4[] = "all varargs tests ok\n";

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

int32_t wrap_printf(const uint8_t * fmt, ...);
int32_t add_two(int32_t a, int32_t b);
int32_t mul_two(int32_t x, int32_t y);
int32_t identity_one(int32_t n);
int32_t sum_three(int32_t a, int32_t b, int32_t c);
int32_t test_direct();
int32_t uya_main(void);


int32_t wrap_printf(const uint8_t * fmt, ...) {
    int32_t _uya_ret =     ((void)0, ({
        va_list uya_va;
        va_start(uya_va, fmt);
        int32_t _uya_ret = vprintf(fmt, uya_va);
        va_end(uya_va);
        _uya_ret;
    }));
    return _uya_ret;
}

int32_t add_two(int32_t a, int32_t b) {
    struct { int32_t f0; int32_t f1; } p = {.f0 = a, .f1 = b};
    int32_t _uya_ret = (p.f0 + p.f1);
    return _uya_ret;
}

int32_t mul_two(int32_t x, int32_t y) {
    int32_t _uya_ret = ((struct { int32_t f0; int32_t f1; }){.f0 = x, .f1 = y}.f0 * (struct { int32_t f0; int32_t f1; }){.f0 = x, .f1 = y}.f1);
    return _uya_ret;
}

int32_t identity_one(int32_t n) {
    int32_t _uya_ret = n;
    return _uya_ret;
}

int32_t sum_three(int32_t a, int32_t b, int32_t c) {
    struct { int32_t f0; int32_t f1; int32_t f2; } t = {.f0 = a, .f1 = b, .f2 = c};
    int32_t _uya_ret = ((t.f0 + t.f1) + t.f2);
    return _uya_ret;
}

int32_t test_direct() {
    printf((const char *)(uint8_t *)str0, 1, 2);
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t uya_main(void) {
const int32_t r1 = add_two(10, 20);
wrap_printf((uint8_t *)(uint8_t *)str1, r1);
if ((r1 != 30)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t r2 = mul_two(5, 6);
wrap_printf((uint8_t *)(uint8_t *)str2, r2);
if ((r2 != 30)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
const int32_t r3 = identity_one(42);
if ((r3 != 42)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
const int32_t r4 = sum_three(1, 2, 3);
wrap_printf((uint8_t *)(uint8_t *)str3, r4);
if ((r4 != 6)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
test_direct();
wrap_printf((uint8_t *)(uint8_t *)str4);
int32_t _uya_ret = 0;
return _uya_ret;
}
