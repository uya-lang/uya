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
struct Example1;
struct Example2;
struct Inner;
struct Outer;
struct Example4;
struct Example5;
struct PlatformStruct;
struct Empty;



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

struct Example1 {
    int32_t a;
    int32_t b;
    int32_t c;
};

struct Example2 {
    uint8_t a;
    int32_t b;
    uint8_t c;
};

struct Inner {
    int32_t x;
    int32_t y;
};

struct Outer {
    uint8_t a;
    struct Inner inner;
    uint8_t b;
};

struct Example4 {
    uint8_t a;
    int32_t arr[3];
    int32_t b;
};

struct Example5 {
    uint8_t a;
    int32_t b;
    int32_t c;
};

struct PlatformStruct {
    int32_t * ptr;
    size_t size;
};

struct Empty {
    char _empty;
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
const int32_t size1 = sizeof(struct Example1);
const int32_t align1 = uya_alignof(struct Example1);
if (((size1 != 12) || (align1 != 4))) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t size2 = sizeof(struct Example2);
const int32_t align2 = uya_alignof(struct Example2);
if (((size2 != 12) || (align2 != 4))) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
const int32_t inner_size = sizeof(struct Inner);
const int32_t inner_align = uya_alignof(struct Inner);
if (((inner_size != 8) || (inner_align != 4))) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
const int32_t outer_size = sizeof(struct Outer);
const int32_t outer_align = uya_alignof(struct Outer);
if (((outer_size != 16) || (outer_align != 4))) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
const int32_t size4 = sizeof(struct Example4);
const int32_t align4 = uya_alignof(struct Example4);
if (((size4 != 20) || (align4 != 4))) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
const int32_t size5 = sizeof(struct Example5);
const int32_t align5 = uya_alignof(struct Example5);
if (((size5 != 12) || (align5 != 4))) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
const int32_t platform_size = sizeof(struct PlatformStruct);
const int32_t platform_align = uya_alignof(struct PlatformStruct);
const int32_t ptr_size = sizeof(int32_t *);
const int32_t usize_size = sizeof(size_t);
if (((ptr_size != 4) && (ptr_size != 8))) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
if ((usize_size != ptr_size)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
if ((platform_size != (ptr_size * 2))) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
if ((platform_align != ptr_size)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
const int32_t empty_size = sizeof(struct Empty);
const int32_t empty_align = uya_alignof(struct Empty);
if (((empty_size != 1) || (empty_align != 1))) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
struct Example1 e1 = (struct Example1){.a = 1, .b = 2, .c = 3};
if ((((e1.a != 1) || (e1.b != 2)) || (e1.c != 3))) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
struct Example2 e2 = (struct Example2){.a = 1, .b = 2, .c = 3};
if ((((e2.a != 1) || (e2.b != 2)) || (e2.c != 3))) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
struct Example4 e4 = (struct Example4){.a = 1, .arr = {10, 20, 30}, .b = 4};
if ((((((e4.a != 1) || (e4.arr[0] != 10)) || (e4.arr[1] != 20)) || (e4.arr[2] != 30)) || (e4.b != 4))) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
struct Outer outer = (struct Outer){.a = 1, .inner = (struct Inner){.x = 10, .y = 20}, .b = 2};
if (((((outer.a != 1) || (outer.inner.x != 10)) || (outer.inner.y != 20)) || (outer.b != 2))) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
