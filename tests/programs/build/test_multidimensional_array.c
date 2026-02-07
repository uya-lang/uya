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

int32_t sum_2d_array(int32_t arr_param[3][2]);
int32_t uya_main(void);

int32_t sum_2d_array(int32_t arr_param[3][2]) {
    // 数组参数按值传递：创建局部副本
    int32_t arr[3][2];
        memcpy(arr, arr_param, sizeof(arr));
    int32_t total = 0;
    int32_t i3 = 0;
    while ((i3 < 3)) {
        int32_t j3 = 0;
        while ((j3 < sizeof(arr[i3]) / sizeof((arr[i3])[0]))) {
            total = (total + arr[i3][j3]);
            j3 = (j3 + 1);
        }
        i3 = (i3 + 1);
    }
    int32_t _uya_ret = total;
    return _uya_ret;
}

int32_t uya_main(void) {
int32_t arr2d[3][2] = {{1, 2}, {3, 4}, {5, 6}};
if (((arr2d[0][0] != 1) || (arr2d[0][1] != 2))) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
if (((arr2d[1][0] != 3) || (arr2d[1][1] != 4))) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
if (((arr2d[2][0] != 5) || (arr2d[2][1] != 6))) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
arr2d[0][0] = 10;
if ((arr2d[0][0] != 10)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
arr2d[1][1] = 40;
if ((arr2d[1][1] != 40)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
const int32_t arr2d_type_size = sizeof(int32_t[3][2]);
if ((arr2d_type_size != 24)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
const int32_t arr2d_var_size = sizeof(arr2d);
if ((arr2d_var_size != 24)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
const int32_t arr1d_size = sizeof(arr2d[0]);
if ((arr1d_size != 8)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
const int32_t arr2d_len = 3;
if ((arr2d_len != 3)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
const int32_t arr1d_len = sizeof(arr2d[0]) / sizeof((arr2d[0])[0]);
if ((arr1d_len != 2)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
int32_t arr3d[2][2][2] = {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}};
if (((arr3d[0][0][0] != 1) || (arr3d[0][0][1] != 2))) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
if (((arr3d[1][1][0] != 7) || (arr3d[1][1][1] != 8))) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
const int32_t arr3d_size = sizeof(arr3d);
if ((arr3d_size != 32)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
const int32_t arr3d_len = 2;
if ((arr3d_len != 2)) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
const int32_t arr2d_inner_len = sizeof(arr3d[0]) / sizeof((arr3d[0])[0]);
if ((arr2d_inner_len != 2)) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
int32_t sum = 0;
int32_t i = 0;
while ((i < 3)) {
    int32_t j = 0;
    while ((j < sizeof(arr2d[i]) / sizeof((arr2d[i])[0]))) {
        sum = (sum + arr2d[i][j]);
        j = (j + 1);
    }
    i = (i + 1);
}
if ((sum != 66)) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
int32_t sum2 = 0;
{
    // for loop - array traversal
    size_t _len = sizeof(arr2d) / sizeof(arr2d[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t row[2];
        __uya_memcpy(row, arr2d[_i], sizeof(row));
        int32_t j2 = 0;
        while ((j2 < sizeof(row) / sizeof((row)[0]))) {
            sum2 = (sum2 + row[j2]);
            j2 = (j2 + 1);
        }
    }
}
if ((sum2 != 66)) {
    int32_t _uya_ret = 17;
    return _uya_ret;
}
int32_t arr2d2[3][2] = {{1, 1}, {1, 1}, {1, 1}};
int32_t total = sum_2d_array(arr2d2);
if ((total != 6)) {
    int32_t _uya_ret = 18;
    return _uya_ret;
}
const int32_t arr2d_align = uya_alignof(int32_t);
if ((arr2d_align != 4)) {
    int32_t _uya_ret = 19;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
