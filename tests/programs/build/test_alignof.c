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
struct Point;
struct Mixed;



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

struct Point {
    int32_t x;
    int32_t y;
};

struct Mixed {
    uint8_t a;
    int32_t b;
    int32_t c;
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
const int32_t i32_align = uya_alignof(int32_t);
if ((i32_align != 4)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t bool_align = uya_alignof(bool);
if ((bool_align != 1)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t byte_align = uya_alignof(uint8_t);
if ((byte_align != 1)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t ptr_i32_align = uya_alignof(int32_t *);
if (((ptr_i32_align != 4) && (ptr_i32_align != 8))) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t ptr_bool_align = uya_alignof(bool *);
if ((ptr_bool_align != ptr_i32_align)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t platform_word_align = ptr_i32_align;
int32_t x = 42;
const int32_t x_align = uya_alignof(int32_t);
if ((x_align != 4)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
bool b = true;
const int32_t b_align = uya_alignof(bool);
if ((b_align != 1)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
uint8_t byte_val = 0;
const int32_t byte_val_align = uya_alignof(uint8_t);
if ((byte_val_align != 1)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t point_align = uya_alignof(struct Point);
if ((point_align != 4)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t mixed_align = uya_alignof(struct Mixed);
if ((mixed_align != 4)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
struct Point p = (struct Point){.x = 10, .y = 20};
const int32_t p_align = uya_alignof(struct Point);
if ((p_align != 4)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t array_i32_align = uya_alignof(int32_t);
if ((array_i32_align != 4)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t array_bool_align = uya_alignof(bool);
if ((array_bool_align != 1)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
int32_t arr[5] = {1, 2, 3, 4, 5};
const int32_t arr_align = uya_alignof(int32_t);
if ((arr_align != 4)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t arr_size = sizeof(arr);
const int32_t arr_align2 = uya_alignof(int32_t);
if (((arr_size != 20) || (arr_align2 != 4))) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
