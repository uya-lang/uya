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

size_t add_usize(size_t a, size_t b);
int32_t uya_main(void);

size_t add_usize(size_t a, size_t b) {
    size_t _uya_ret = (a + b);
    return _uya_ret;
}

int32_t uya_main(void) {
int32_t i32_val = 10;
size_t usize_val = (size_t)20;
size_t result1 = ((size_t)i32_val + usize_val);
if ((result1 != (size_t)30)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
size_t result2 = (usize_val + (size_t)i32_val);
if ((result2 != (size_t)30)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
size_t result3 = ((size_t)i32_val - (size_t)5);
if ((result3 != (size_t)5)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
size_t result4 = (usize_val - (size_t)i32_val);
if ((result4 != (size_t)10)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
size_t result5 = ((size_t)i32_val * usize_val);
if ((result5 != (size_t)200)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
size_t result6 = (usize_val * (size_t)i32_val);
if ((result6 != (size_t)200)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
int32_t i32_val2 = 20;
size_t usize_val2 = (size_t)4;
size_t result7 = ((size_t)i32_val2 / usize_val2);
if ((result7 != (size_t)5)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
size_t result8 = (usize_val2 / (size_t)i32_val2);
if ((result8 != (size_t)0)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
int32_t i32_val3 = 17;
size_t usize_val3 = (size_t)5;
size_t result9 = ((size_t)i32_val3 % usize_val3);
if ((result9 != (size_t)2)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
size_t result10 = (usize_val3 % (size_t)i32_val3);
if ((result10 != (size_t)5)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
int32_t i32_val4 = 5;
size_t usize_val4 = (size_t)3;
size_t result11 = (((size_t)i32_val4 + usize_val4) * (size_t)2);
if ((result11 != (size_t)16)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
int32_t i32_val5 = 10;
size_t usize_val5 = (size_t)20;
size_t result12 = add_usize((size_t)i32_val5, usize_val5);
if ((result12 != (size_t)30)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
int32_t i32_val6 = 10;
size_t usize_val6 = (size_t)20;
if (((size_t)i32_val6 < usize_val6)) {
} else {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
int32_t i32_val7 = 10;
int32_t i32_val8 = 20;
int32_t result13 = (i32_val7 + i32_val8);
if ((result13 != 30)) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
size_t usize_val7 = (size_t)15;
size_t usize_val8 = (size_t)5;
size_t result14 = (usize_val7 + usize_val8);
if ((result14 != (size_t)20)) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
int32_t ptr_size = sizeof(int32_t *);
int32_t usize_size = sizeof(size_t);
if ((usize_size != ptr_size)) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
