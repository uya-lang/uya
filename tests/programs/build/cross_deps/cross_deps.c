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
    int32_t x;
    int32_t y;
    int32_t width;
    int32_t height;
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

struct Point create_point(int32_t x, int32_t y);
bool point_in_rectangle(struct Point p, struct Rectangle r);
int32_t test_cross_file_call();
struct Rectangle create_rectangle(int32_t x, int32_t y, int32_t width, int32_t height);
int32_t calculate_rectangle_area(struct Rectangle r);
int32_t test_cross_file_call_b();
int32_t uya_main(void);

struct Point create_point(int32_t x, int32_t y) {
    struct Point _uya_ret = (struct Point){.x = x, .y = y};
    return _uya_ret;
}

bool point_in_rectangle(struct Point p, struct Rectangle r) {
    if (((p.x >= r.x) && (p.x <= (r.x + r.width)))) {
        if (((p.y >= r.y) && (p.y <= (r.y + r.height)))) {
            bool _uya_ret = true;
            return _uya_ret;
        }
    }
    bool _uya_ret = false;
    return _uya_ret;
}

int32_t test_cross_file_call() {
    struct Point p = create_point(5, 10);
    struct Rectangle r = create_rectangle(0, 0, 20, 20);
    const bool inside = point_in_rectangle(p, r);
    if ((!inside)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    struct Rectangle r2 = create_rectangle(0, 0, 20, 20);
    const int32_t area = calculate_rectangle_area(r2);
    if ((area != 400)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

struct Rectangle create_rectangle(int32_t x, int32_t y, int32_t width, int32_t height) {
    struct Rectangle _uya_ret = (struct Rectangle){.x = x, .y = y, .width = width, .height = height};
    return _uya_ret;
}

int32_t calculate_rectangle_area(struct Rectangle r) {
    int32_t _uya_ret = (r.width * r.height);
    return _uya_ret;
}

int32_t test_cross_file_call_b() {
    struct Rectangle r = create_rectangle(10, 20, 30, 40);
    struct Point p = create_point(15, 25);
    const bool inside = point_in_rectangle(p, r);
    if ((!inside)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    struct Rectangle r2 = create_rectangle(10, 20, 30, 40);
    const int32_t area = calculate_rectangle_area(r2);
    if ((area != 1200)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t uya_main(void) {
const int32_t result1 = test_cross_file_call();
if ((result1 != 0)) {
    int32_t _uya_ret = (10 + result1);
    return _uya_ret;
}
const int32_t result2 = test_cross_file_call_b();
if ((result2 != 0)) {
    int32_t _uya_ret = (20 + result2);
    return _uya_ret;
}
struct Point p = create_point(100, 200);
if (((p.x != 100) || (p.y != 200))) {
    int32_t _uya_ret = 30;
    return _uya_ret;
}
struct Rectangle r = create_rectangle(0, 0, 50, 60);
if (((((r.x != 0) || (r.y != 0)) || (r.width != 50)) || (r.height != 60))) {
    int32_t _uya_ret = 40;
    return _uya_ret;
}
const int32_t area = calculate_rectangle_area(r);
if ((area != 3000)) {
    int32_t _uya_ret = 50;
    return _uya_ret;
}
struct Rectangle r2 = create_rectangle(0, 0, 50, 60);
const bool inside = point_in_rectangle(p, r2);
if (inside) {
    int32_t _uya_ret = 60;
    return _uya_ret;
}
struct Point p2 = create_point(25, 30);
struct Rectangle r3 = create_rectangle(0, 0, 50, 60);
const bool inside2 = point_in_rectangle(p2, r3);
if ((!inside2)) {
    int32_t _uya_ret = 70;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
