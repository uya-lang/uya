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

int32_t process_array(int32_t arr_param[3]);
struct uya_array_i32_3 {
    int32_t data[3];
};
struct uya_array_i32_3 create_array();
int32_t uya_main(void);

int32_t process_array(int32_t arr_param[3]) {
    // 数组参数按值传递：创建局部副本
    int32_t arr[3];
        memcpy(arr, arr_param, sizeof(arr));
    int32_t sum = 0;
    int32_t i = 0;
    while ((i < 3)) {
        sum = (sum + arr[i]);
        i = (i + 1);
    }
    arr[0] = 999;
    int32_t _uya_ret = sum;
    return _uya_ret;
}

struct uya_array_i32_3 create_array() {
    struct uya_array_i32_3 _uya_ret = (struct uya_array_i32_3) { .data = {100, 200, 300} };
    return _uya_ret;
}

int32_t uya_main(void) {
int32_t arr1[3] = {1, 2, 3};
int32_t arr2[3];
__uya_memcpy(arr2, arr1, sizeof(arr2));
if ((((arr2[0] != 1) || (arr2[1] != 2)) || (arr2[2] != 3))) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
arr1[0] = 100;
if ((arr2[0] != 1)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
arr2[1] = 200;
if ((arr1[1] != 2)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
uint8_t arr3[4] = {10, 20, 30, 40};
uint8_t arr4[4];
__uya_memcpy(arr4, arr3, sizeof(arr4));
if (((((arr4[0] != 10) || (arr4[1] != 20)) || (arr4[2] != 30)) || (arr4[3] != 40))) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
arr3[0] = 100;
if ((arr4[0] != 10)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
struct Point arr5[2] = {(struct Point){.x = 1, .y = 2}, (struct Point){.x = 3, .y = 4}};
struct Point arr6[2];
__uya_memcpy(arr6, arr5, sizeof(arr6));
if (((((arr6[0].x != 1) || (arr6[0].y != 2)) || (arr6[1].x != 3)) || (arr6[1].y != 4))) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
arr5[0].x = 100;
if ((arr6[0].x != 1)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
arr6[1].y = 200;
if ((arr5[1].y != 4)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
int32_t arr7[3] = {10, 20, 30};
int32_t arr8[3];
__uya_memcpy(arr8, arr7, sizeof(arr8));
if ((((arr8[0] != 10) || (arr8[1] != 20)) || (arr8[2] != 30))) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
int32_t arr9[5] = {0};
int32_t arr10[5];
__uya_memcpy(arr10, arr9, sizeof(arr10));
int32_t arr11[3] = {1, 2, 3};
int32_t sum = process_array(arr11);
if ((sum != 6)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
if ((arr11[0] != 1)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
int32_t arr12[3];
__uya_memcpy(arr12, create_array().data, sizeof(arr12));
if ((((arr12[0] != 100) || (arr12[1] != 200)) || (arr12[2] != 300))) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
int32_t arr13[2][2] = {{1, 2}, {3, 4}};
int32_t arr14[2][2];
__uya_memcpy(arr14, arr13, sizeof(arr14));
if (((((arr14[0][0] != 1) || (arr14[0][1] != 2)) || (arr14[1][0] != 3)) || (arr14[1][1] != 4))) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
arr13[0][0] = 999;
if ((arr14[0][0] != 1)) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
