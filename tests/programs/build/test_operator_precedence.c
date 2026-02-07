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
int32_t x = 5;
int32_t result1 = ((-x) * 2);
if ((result1 != (-10))) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
bool bool_val = false;
bool result2 = ((!bool_val) && true);
if ((result2 != true)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
int32_t i32_val = 10;
uint8_t byte_val = 2;
int32_t result3 = ((int32_t)(uint8_t)i32_val * (int32_t)byte_val);
if ((result3 != 20)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
int32_t result4 = (2 + (3 * 4));
if ((result4 != 14)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
int32_t result5 = (10 - (8 / 2));
if ((result5 != 6)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
int32_t result6 = (10 + (15 % 4));
if ((result6 != 13)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
int32_t result7 = ((24 / 4) / 2);
if ((result7 != 3)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
int32_t result8 = ((2 * 3) * 4);
if ((result8 != 24)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
int32_t result9 = (1 + (2 * 3));
if ((result9 != 7)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
int32_t result10 = ((10 - 3) - 2);
if ((result10 != 5)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
int32_t result11 = ((1 + 2) + 3);
if ((result11 != 6)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
bool result12 = ((1 + 2) < 5);
if ((result12 != true)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
bool result13 = ((10 - 3) > 5);
if ((result13 != true)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
int32_t a = 5;
int32_t b = 10;
int32_t c = 15;
bool result14 = ((a < b) && (b < c));
if ((result14 != true)) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
bool result15 = ((1 + 2) == 3);
if ((result15 != true)) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
bool result16 = ((5 < 10) == true);
if ((result16 != true)) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
bool result17 = (true || (false && false));
if ((result17 != true)) {
    int32_t _uya_ret = 17;
    return _uya_ret;
}
bool result18 = ((false && true) || true);
if ((result18 != true)) {
    int32_t _uya_ret = 18;
    return _uya_ret;
}
bool result19 = ((true && true) && false);
if ((result19 != false)) {
    int32_t _uya_ret = 19;
    return _uya_ret;
}
bool result20 = ((false && true) || true);
if ((result20 != true)) {
    int32_t _uya_ret = 20;
    return _uya_ret;
}
bool result21 = ((false || false) || true);
if ((result21 != true)) {
    int32_t _uya_ret = 21;
    return _uya_ret;
}
int32_t var1 = 10;
int32_t var2 = 20;
int32_t var3 = 0;
var3 = (var1 + var2);
if ((var3 != 30)) {
    int32_t _uya_ret = 22;
    return _uya_ret;
}
int32_t var4 = 1;
int32_t var5 = 2;
int32_t var6 = 3;
var4 = (var5 = var6);
if (((var4 != 3) || (var5 != 3))) {
    int32_t _uya_ret = 23;
    return _uya_ret;
}
int32_t result22 = ((2 * 3) + (4 * 5));
if ((result22 != 26)) {
    int32_t _uya_ret = 24;
    return _uya_ret;
}
bool result23 = (((1 + (2 * 3)) == 7) && (10 > 5));
if ((result23 != true)) {
    int32_t _uya_ret = 25;
    return _uya_ret;
}
bool result24 = (((!false) && (5 < 10)) || (3 > 5));
if ((result24 != true)) {
    int32_t _uya_ret = 26;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
