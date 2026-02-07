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
    struct Point points[2];
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

int32_t add(int32_t a, int32_t b);
int32_t multiply(int32_t a, int32_t b);
int32_t get_value(struct Data d);
int32_t get_point_x(struct Point * p);
int32_t get_index(int32_t arr_param[3], int32_t index);
int32_t uya_main(void);

int32_t add(int32_t a, int32_t b) {
    int32_t _uya_ret = (a + b);
    return _uya_ret;
}

int32_t multiply(int32_t a, int32_t b) {
    int32_t _uya_ret = (a * b);
    return _uya_ret;
}

int32_t get_value(struct Data d) {
    int32_t _uya_ret = d.value;
    return _uya_ret;
}

int32_t get_point_x(struct Point * p) {
    int32_t _uya_ret = p->x;
    return _uya_ret;
}

int32_t get_index(int32_t arr_param[3], int32_t index) {
    // 数组参数按值传递：创建局部副本
    int32_t arr[3];
        memcpy(arr, arr_param, sizeof(arr));
    int32_t _uya_ret = arr[index];
    return _uya_ret;
}

int32_t uya_main(void) {
int32_t result1 = (((2 * 3) + (4 * 5)) - (6 / 2));
if ((result1 != 23)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
int32_t result2 = ((2 + 3) * (4 + 5));
if ((result2 != 45)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
struct Data data = (struct Data){.value = 100, .points = {(struct Point){.x = 10, .y = 20}, (struct Point){.x = 30, .y = 40}}};
int32_t point_x = data.points[0].x;
if ((point_x != 10)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
int32_t point_y = data.points[1].y;
if ((point_y != 40)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
data.points[0].x = 50;
if ((data.points[0].x != 50)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
int32_t result3 = add(multiply(2, 3), multiply(4, 5));
if ((result3 != 26)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
int32_t result4 = multiply(add(1, 2), add(3, 4));
if ((result4 != 21)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
struct Point p = (struct Point){.x = 100, .y = 200};
int32_t result5 = add(p.x, p.y);
if ((result5 != 300)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
data.points[1].x = add(10, 20);
if ((data.points[1].x != 30)) {
    int32_t _uya_ret = 23;
    return _uya_ret;
}
int32_t result6 = get_value(data);
if ((result6 != 100)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
int32_t result7 = get_point_x((&p));
if ((result7 != 100)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
uint8_t byte_val = 10;
int32_t i32_val = 20;
int32_t result8 = ((int32_t)byte_val + i32_val);
if ((result8 != 30)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
bool bool_val = (bool)i32_val;
if ((bool_val != true)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
int32_t result9 = add((int32_t)byte_val, i32_val);
if ((result9 != 30)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
struct Point * ptr = (&p);
int32_t x_value = (*ptr).x;
if ((x_value != 100)) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
int32_t y_value = ptr->y;
if ((y_value != 200)) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
ptr->x = 300;
if ((p.x != 300)) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
int32_t arr[3] = {10, 20, 30};
int32_t result10 = add(arr[0], arr[1]);
if ((result10 != 30)) {
    int32_t _uya_ret = 17;
    return _uya_ret;
}
int32_t result11 = get_index(arr, 2);
if ((result11 != 30)) {
    int32_t _uya_ret = 18;
    return _uya_ret;
}
int32_t a = 10;
int32_t b = 20;
int32_t c = 30;
bool result12 = (((a < b) && (b < c)) && (c > a));
if ((result12 != true)) {
    int32_t _uya_ret = 19;
    return _uya_ret;
}
bool result13 = ((add(a, b) > 25) && (multiply(a, 2) < 30));
if ((result13 != true)) {
    int32_t _uya_ret = 20;
    return _uya_ret;
}
struct Point p2 = (struct Point){.x = 1, .y = 2};
p2.x = add(5, 5);
if ((p2.x != 10)) {
    int32_t _uya_ret = 21;
    return _uya_ret;
}
arr[0] = multiply(3, 4);
if ((arr[0] != 12)) {
    int32_t _uya_ret = 22;
    return _uya_ret;
}
int32_t size1 = (sizeof(struct Point) * 2);
if ((size1 != 16)) {
    int32_t _uya_ret = 24;
    return _uya_ret;
}
int32_t align1 = uya_alignof(struct Point);
if ((align1 != 4)) {
    int32_t _uya_ret = 25;
    return _uya_ret;
}
int32_t arr2[5] = {1, 2, 3, 4, 5};
int32_t sum = 0;
int32_t i = 0;
while ((i < 5)) {
    sum = (sum + arr2[i]);
    i = (i + 1);
}
if ((sum != 15)) {
    int32_t _uya_ret = 26;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
