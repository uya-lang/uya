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
int32_t arr1[5] = {1, 2, 3, 4, 5};
int32_t sum1 = 0;
{
    // for loop - array traversal
    size_t _len = sizeof(arr1) / sizeof(arr1[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t item = arr1[_i];
        if ((item == 3)) {
            break;
        }
        sum1 = (sum1 + item);
    }
}
if ((sum1 != 3)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
int32_t arr2[3] = {10, 20, 30};
int32_t count1 = 0;
{
    // for loop - array traversal
    size_t _len = sizeof(arr2) / sizeof(arr2[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t item = arr2[_i];
        count1 = (count1 + 1);
        break;
    }
}
if ((count1 != 1)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
int32_t arr3[5] = {1, 2, 3, 4, 5};
int32_t sum2 = 0;
{
    // for loop - array traversal
    size_t _len = sizeof(arr3) / sizeof(arr3[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t item = arr3[_i];
        if ((item == 3)) {
            continue;
        }
        sum2 = (sum2 + item);
    }
}
if ((sum2 != 12)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
int32_t arr4[6] = {10, 20, 30, 40, 50, 60};
int32_t sum3 = 0;
{
    // for loop - array traversal
    size_t _len = sizeof(arr4) / sizeof(arr4[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t item = arr4[_i];
        if (((item == 20) || (item == 40))) {
            continue;
        }
        sum3 = (sum3 + item);
    }
}
if ((sum3 != 150)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
int32_t arr5[5] = {1, 2, 3, 4, 5};
{
    // for loop - array traversal
    size_t _len = sizeof(arr5) / sizeof(arr5[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t *item = &arr5[_i];
        if (((*item) == 3)) {
            break;
        }
        (*item) = ((*item) * 2);
    }
}
if ((((arr5[0] != 2) || (arr5[1] != 4)) || (arr5[2] != 3))) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
int32_t arr6[5] = {1, 2, 3, 4, 5};
{
    // for loop - array traversal
    size_t _len = sizeof(arr6) / sizeof(arr6[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t *item = &arr6[_i];
        if (((*item) == 3)) {
            continue;
        }
        (*item) = ((*item) * 2);
    }
}
if ((((((arr6[0] != 2) || (arr6[1] != 4)) || (arr6[2] != 3)) || (arr6[3] != 8)) || (arr6[4] != 10))) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
int32_t arr7[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
int32_t sum4 = 0;
{
    // for loop - array traversal
    size_t _len = sizeof(arr7) / sizeof(arr7[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t item = arr7[_i];
        if ((item == 8)) {
            break;
        }
        if (((item == 3) || (item == 5))) {
            continue;
        }
        sum4 = (sum4 + item);
    }
}
if ((sum4 != 20)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
int32_t arr8[6] = {1, 2, 3, 4, 5, 6};
{
    // for loop - array traversal
    size_t _len = sizeof(arr8) / sizeof(arr8[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t *item = &arr8[_i];
        if (((*item) == 5)) {
            break;
        }
        if ((((*item) == 2) || ((*item) == 4))) {
            continue;
        }
        (*item) = ((*item) * 10);
    }
}
if ((((((arr8[0] != 10) || (arr8[1] != 2)) || (arr8[2] != 30)) || (arr8[3] != 4)) || (arr8[4] != 5))) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
int32_t arr9[3] = {1, 2, 3};
int32_t arr10[3] = {10, 20, 30};
int32_t sum5 = 0;
{
    // for loop - array traversal
    size_t _len = sizeof(arr9) / sizeof(arr9[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t item1 = arr9[_i];
        {
            // for loop - array traversal
            size_t _len = sizeof(arr10) / sizeof(arr10[0]);
            for (size_t _i = 0; _i < _len; _i++) {
                int32_t item2 = arr10[_i];
                if ((item2 == 20)) {
                    break;
                }
                sum5 = (sum5 + item2);
            }
        }
    }
}
if ((sum5 != 30)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
int32_t arr11[3] = {1, 2, 3};
int32_t sum6 = 0;
{
    // for loop - array traversal
    size_t _len = sizeof(arr11) / sizeof(arr11[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t item = arr11[_i];
        if ((item == 1)) {
            continue;
        }
        sum6 = (sum6 + item);
    }
}
if ((sum6 != 5)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
int32_t arr12[4] = {1, 2, 3, 4};
int32_t sum7 = 0;
{
    // for loop - array traversal
    size_t _len = sizeof(arr12) / sizeof(arr12[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t item = arr12[_i];
        sum7 = (sum7 + item);
        if ((item == 4)) {
            break;
        }
    }
}
if ((sum7 != 10)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
