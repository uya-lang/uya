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
struct Data;
struct Nested;
struct ArrayStruct;
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

struct Point {
    int32_t x;
    int32_t y;
};

struct Data {
    int32_t value;
    bool flag;
};

struct Nested {
    struct Point point;
    int32_t count;
};

struct ArrayStruct {
    int32_t items[3];
    int32_t size;
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
struct Point p1 = (struct Point){.x = 10, .y = 20};
struct Point p2 = (struct Point){.x = 10, .y = 20};
if ((!(((p1).x == (p2).x) && ((p1).y == (p2).y)))) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
struct Point p3 = (struct Point){.x = 10, .y = 30};
if ((((p1).x == (p3).x) && ((p1).y == (p3).y))) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
struct Point p4 = (struct Point){.x = 20, .y = 20};
if ((((p1).x == (p4).x) && ((p1).y == (p4).y))) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
struct Data d1 = (struct Data){.value = 42, .flag = true};
struct Data d2 = (struct Data){.value = 100, .flag = true};
if ((((d1).value == (d2).value) && ((d1).flag == (d2).flag))) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
struct Data d3 = (struct Data){.value = 42, .flag = false};
if ((((d1).value == (d3).value) && ((d1).flag == (d3).flag))) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
struct Data d4 = (struct Data){.value = 42, .flag = true};
if ((!(((d1).value == (d4).value) && ((d1).flag == (d4).flag)))) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
struct Nested n1 = (struct Nested){.point = (struct Point){.x = 1, .y = 2}, .count = 10};
struct Nested n2 = (struct Nested){.point = (struct Point){.x = 1, .y = 2}, .count = 10};
if ((!((__uya_memcmp(&(n1).point, &(n2).point, sizeof((n1).point)) == 0) && ((n1).count == (n2).count)))) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
struct Nested n3 = (struct Nested){.point = (struct Point){.x = 1, .y = 3}, .count = 10};
if (((__uya_memcmp(&(n1).point, &(n3).point, sizeof((n1).point)) == 0) && ((n1).count == (n3).count))) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
struct Nested n4 = (struct Nested){.point = (struct Point){.x = 1, .y = 2}, .count = 20};
if (((__uya_memcmp(&(n1).point, &(n4).point, sizeof((n1).point)) == 0) && ((n1).count == (n4).count))) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
struct ArrayStruct a1 = (struct ArrayStruct){.items = {1, 2, 3}, .size = 3};
struct ArrayStruct a2 = (struct ArrayStruct){.items = {1, 2, 3}, .size = 3};
if ((!((__uya_memcmp(&(a1).items, &(a2).items, sizeof((a1).items)) == 0) && ((a1).size == (a2).size)))) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
struct ArrayStruct a3 = (struct ArrayStruct){.items = {1, 2, 4}, .size = 3};
if (((__uya_memcmp(&(a1).items, &(a3).items, sizeof((a1).items)) == 0) && ((a1).size == (a3).size))) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
struct Point p5 = (struct Point){.x = 5, .y = 6};
struct Point p6 = (struct Point){.x = 5, .y = 6};
int32_t result = 0;
if ((((p5).x == (p6).x) && ((p5).y == (p6).y))) {
    result = 100;
} else {
    result = 200;
}
if ((result != 100)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
struct Point p7 = (struct Point){.x = 1, .y = 1};
struct Point p8 = (struct Point){.x = 2, .y = 2};
int32_t count = 0;
while (((!(((p7).x == (p8).x) && ((p7).y == (p8).y))) && (count < 1))) {
    p7.x = p8.x;
    p7.y = p8.y;
    count = (count + 1);
}
if ((!(((p7).x == (p8).x) && ((p7).y == (p8).y)))) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
struct Point p9 = (struct Point){.x = 10, .y = 20};
struct Point p10 = p9;
if (((p10.x != 10) || (p10.y != 20))) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
p10.x = 30;
if (((p10.x != 30) || (p10.y != 20))) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
struct Point p11 = (struct Point){.x = 1, .y = 2};
struct Point * ptr1 = (&p11);
struct Point * ptr2 = (&p11);
if ((ptr1 != ptr2)) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
struct Point p12 = (struct Point){.x = 1, .y = 2};
struct Point * ptr3 = (&p12);
if ((ptr1 == ptr3)) {
    int32_t _uya_ret = 17;
    return _uya_ret;
}
struct Empty e1;
memset((void *)&e1, 0, sizeof(e1));
struct Empty e2;
memset((void *)&e2, 0, sizeof(e2));
if ((0)) {
    int32_t _uya_ret = 18;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
