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
struct Rectangle;
struct Container;



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

struct Rectangle {
    struct Point top_left;
    struct Point bottom_right;
};

struct Container {
    struct Point * point;
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

int32_t test_pointer_param(struct Rectangle * rect);
int32_t test_nested_pointer(struct Point * point);
int32_t test_struct_with_pointer_field(struct Container * container);
int32_t uya_main(void);

int32_t test_pointer_param(struct Rectangle * rect) {
    const int32_t x1 = rect->top_left.x;
    const int32_t y1 = rect->top_left.y;
    const int32_t x2 = rect->bottom_right.x;
    const int32_t y2 = rect->bottom_right.y;
    if (((((x1 != 0) || (y1 != 0)) || (x2 != 10)) || (y2 != 20))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    rect->top_left.x = 5;
    rect->top_left.y = 5;
    rect->bottom_right.x = 15;
    rect->bottom_right.y = 25;
    if (((rect->top_left.x != 5) || (rect->top_left.y != 5))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if (((rect->bottom_right.x != 15) || (rect->bottom_right.y != 25))) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_nested_pointer(struct Point * point) {
    const int32_t x = point->x;
    const int32_t y = point->y;
    if (((x != 0) || (y != 0))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    point->x = 100;
    point->y = 200;
    if (((point->x != 100) || (point->y != 200))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_struct_with_pointer_field(struct Container * container) {
    const int32_t x = container->point->x;
    const int32_t y = container->point->y;
    if (((x != 0) || (y != 0))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    container->point->x = 50;
    container->point->y = 60;
    if (((container->point->x != 50) || (container->point->y != 60))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t uya_main(void) {
struct Rectangle rect = (struct Rectangle){.top_left = (struct Point){.x = 0, .y = 0}, .bottom_right = (struct Point){.x = 10, .y = 20}};
struct Point point = (struct Point){.x = 0, .y = 0};
struct Point container_point = (struct Point){.x = 0, .y = 0};
struct Container container = (struct Container){.point = (&container_point)};
const int32_t result1 = test_pointer_param((&rect));
if ((result1 != 0)) {
    int32_t _uya_ret = result1;
    return _uya_ret;
}
if (((rect.top_left.x != 5) || (rect.top_left.y != 5))) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
if (((rect.bottom_right.x != 15) || (rect.bottom_right.y != 25))) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
const int32_t result2 = test_nested_pointer((&point));
if ((result2 != 0)) {
    int32_t _uya_ret = (result2 + 20);
    return _uya_ret;
}
if (((point.x != 100) || (point.y != 200))) {
    int32_t _uya_ret = 30;
    return _uya_ret;
}
const int32_t result3 = test_struct_with_pointer_field((&container));
if ((result3 != 0)) {
    int32_t _uya_ret = (result3 + 40);
    return _uya_ret;
}
if (((container_point.x != 50) || (container_point.y != 60))) {
    int32_t _uya_ret = 50;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
