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
const int32_t a = 42;
if ((a != 42)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t b = (10 + 1);
if ((b != 11)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
const int32_t c = (5 + 5);
if ((c != 10)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
const int32_t d = (3 + 7);
if ((d != 10)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
const int32_t e = ((1 + 2) + 3);
if ((e != 6)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
const int32_t f = ((2 * 3) + 4);
if ((f != 10)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
const int32_t g = ((3 + 7) * 2);
if ((g != 20)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
const bool h1 = (10 > 5);
if ((!h1)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
const bool h2 = (3 > 8);
if (h2) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
const bool i1 = ((5 > 0) && (3 > 0));
if ((!i1)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
const bool i2 = (((-1) > 0) && (3 > 0));
if (i2) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
const int32_t val = 50;
if (((val < 0) || (val > 100))) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t j = ((5 + 5) + 3);
if ((j != 13)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
const int32_t k = ((10 + 5) * (8 - 3));
if ((k != 75)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
const int32_t l1 = (15 | 240);
if ((l1 != 255)) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
const int32_t l2 = (255 & 15);
if ((l2 != 15)) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
const int32_t l3 = (255 ^ 15);
if ((l3 != 240)) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
const int32_t m1 = (1 << 4);
if ((m1 != 16)) {
    int32_t _uya_ret = 17;
    return _uya_ret;
}
const int32_t m2 = (256 >> 4);
if ((m2 != 16)) {
    int32_t _uya_ret = 18;
    return _uya_ret;
}
const int32_t n1 = ((1 * 100) + ((1 - 1) * 200));
if ((n1 != 100)) {
    int32_t _uya_ret = 19;
    return _uya_ret;
}
const int32_t n2 = ((0 * 100) + ((1 - 0) * 200));
if ((n2 != 200)) {
    int32_t _uya_ret = 20;
    return _uya_ret;
}
if ((10 <= 0)) {
    int32_t _uya_ret = 100;
    return _uya_ret;
}
int32_t o = 0;
o = (15 + 25);
if ((o != 40)) {
    int32_t _uya_ret = 21;
    return _uya_ret;
}
const int32_t p = (((((2 * 3) * 4) + 2) + 3) + 4);
if ((p != 33)) {
    int32_t _uya_ret = 22;
    return _uya_ret;
}
const int32_t q1 = (0 - 10);
if ((q1 != (-10))) {
    int32_t _uya_ret = 23;
    return _uya_ret;
}
const int32_t q2 = (0 - (-5));
if ((q2 != 5)) {
    int32_t _uya_ret = 24;
    return _uya_ret;
}
const int32_t r1 = ((10 + (10 >> 31)) ^ (10 >> 31));
if ((r1 != 10)) {
    int32_t _uya_ret = 25;
    return _uya_ret;
}
const int32_t r2 = (((-10) + ((-10) >> 31)) ^ ((-10) >> 31));
if ((r2 != 10)) {
    int32_t _uya_ret = 26;
    return _uya_ret;
}
const int32_t s1 = (10 - ((10 - 20) & ((10 - 20) >> 31)));
if ((s1 != 20)) {
    int32_t _uya_ret = 27;
    return _uya_ret;
}
const int32_t s2 = (30 - ((30 - 15) & ((30 - 15) >> 31)));
if ((s2 != 30)) {
    int32_t _uya_ret = 28;
    return _uya_ret;
}
const int32_t t1 = (20 + ((10 - 20) & ((10 - 20) >> 31)));
if ((t1 != 10)) {
    int32_t _uya_ret = 29;
    return _uya_ret;
}
const int32_t t2 = (15 + ((30 - 15) & ((30 - 15) >> 31)));
if ((t2 != 15)) {
    int32_t _uya_ret = 30;
    return _uya_ret;
}
const int32_t u = (7 * 7);
if ((u != 49)) {
    int32_t _uya_ret = 31;
    return _uya_ret;
}
const int32_t v = ((3 * 3) * 3);
if ((v != 27)) {
    int32_t _uya_ret = 32;
    return _uya_ret;
}
const bool w1 = ((10 & 1) == 0);
if ((!w1)) {
    int32_t _uya_ret = 33;
    return _uya_ret;
}
const bool w2 = ((7 & 1) == 0);
if (w2) {
    int32_t _uya_ret = 34;
    return _uya_ret;
}
const bool w3 = ((7 & 1) == 1);
if ((!w3)) {
    int32_t _uya_ret = 35;
    return _uya_ret;
}
const bool w4 = ((10 & 1) == 1);
if (w4) {
    int32_t _uya_ret = 36;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
