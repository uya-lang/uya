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


struct uya_slice_int32_t { int32_t *ptr; size_t len; };


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

int32_t get_index();
int32_t process_element(int32_t val);
int32_t uya_main(void);

int32_t get_index() {
    int32_t _uya_ret = 3;
    return _uya_ret;
}

int32_t process_element(int32_t val) {
    int32_t _uya_ret = (val * 2);
    return _uya_ret;
}

int32_t uya_main(void) {
const int32_t arr1[3] = {10, 20, 30};
if ((arr1[0] != 10)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
if ((arr1[2] != 30)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
if ((arr1[1] != 20)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
int32_t index = 0;
if ((arr1[index] != 10)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
index = 2;
if ((arr1[index] != 30)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
const int32_t arr2[5] = {1, 2, 3, 4, 5};
int32_t sum = 0;
int32_t i = 0;
while ((i < 5)) {
    sum = (sum + arr2[i]);
    i = (i + 1);
}
if ((sum != 15)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
int32_t sum2 = 0;
{
    // for loop - array traversal
    size_t _len = sizeof(arr2) / sizeof(arr2[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        const int32_t item = arr2[_i];
        sum2 = (sum2 + item);
    }
}
if ((sum2 != 15)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
const int32_t arr3[3][2] = {{1, 2}, {3, 4}, {5, 6}};
if ((arr3[0][0] != 1)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
if ((arr3[2][1] != 6)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
if ((arr3[1][0] != 3)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
const int32_t arr4[4] = {100, 200, 300, 400};
if ((arr4[(1 + 1)] != 300)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
int32_t idx1 = 1;
int32_t idx2 = 1;
if ((arr4[(idx1 + idx2)] != 300)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
if ((arr4[get_index()] != 400)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
int32_t arr5[3] = {1, 2, 3};
arr5[0] = 10;
if ((arr5[0] != 10)) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
arr5[2] = 30;
if ((arr5[2] != 30)) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
int32_t arr6[3] = {1, 2, 3};
struct uya_slice_int32_t arr6_ptr = (struct uya_slice_int32_t){ .ptr = arr6 + 0, .len = 3};
if (((arr6_ptr).ptr[0] != 1)) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
if (((arr6_ptr).ptr[2] != 3)) {
    int32_t _uya_ret = 17;
    return _uya_ret;
}
(arr6_ptr).ptr[1] = 20;
if ((arr6[1] != 20)) {
    int32_t _uya_ret = 18;
    return _uya_ret;
}
const struct Point arr7[3] = {(struct Point){.x = 1, .y = 2}, (struct Point){.x = 3, .y = 4}, (struct Point){.x = 5, .y = 6}};
if (((arr7[0].x != 1) || (arr7[0].y != 2))) {
    int32_t _uya_ret = 19;
    return _uya_ret;
}
if (((arr7[2].x != 5) || (arr7[2].y != 6))) {
    int32_t _uya_ret = 20;
    return _uya_ret;
}
struct Point arr8[2] = {(struct Point){.x = 10, .y = 20}, (struct Point){.x = 30, .y = 40}};
arr8[0].x = 100;
if ((arr8[0].x != 100)) {
    int32_t _uya_ret = 21;
    return _uya_ret;
}
const int32_t arr9[1] = {42};
if ((arr9[0] != 42)) {
    int32_t _uya_ret = 22;
    return _uya_ret;
}
const int32_t arr10[10] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
if ((arr10[0] != 0)) {
    int32_t _uya_ret = 23;
    return _uya_ret;
}
if ((arr10[9] != 9)) {
    int32_t _uya_ret = 24;
    return _uya_ret;
}
const int32_t arr11[3] = {1, 2, 3};
if ((((arr11[0] == 1) && (arr11[1] == 2)) && (arr11[2] == 3))) {
} else {
    int32_t _uya_ret = 25;
    return _uya_ret;
}
const int32_t arr12[3] = {10, 20, 30};
const int32_t result = process_element(arr12[1]);
if ((result != 40)) {
    int32_t _uya_ret = 26;
    return _uya_ret;
}
const int32_t arr13[2][2] = {{1, 2}, {3, 4}};
if ((arr13[0][1] != 2)) {
    int32_t _uya_ret = 27;
    return _uya_ret;
}
if ((arr13[1][0] != 3)) {
    int32_t _uya_ret = 28;
    return _uya_ret;
}
int32_t arr14[2][2] = {{10, 20}, {30, 40}};
arr14[0][1] = 200;
if ((arr14[0][1] != 200)) {
    int32_t _uya_ret = 29;
    return _uya_ret;
}
const int32_t arr15[5] = {1, 2, 3, 4, 5};
int32_t safe_index = 3;
if (((safe_index >= 0) && (safe_index < 5))) {
    if ((arr15[safe_index] != 4)) {
        int32_t _uya_ret = 30;
        return _uya_ret;
    }
} else {
    int32_t _uya_ret = 31;
    return _uya_ret;
}
const int32_t arr16[4] = {1, 2, 3, 4};
const int32_t sum3 = (((arr16[0] + arr16[1]) + arr16[2]) + arr16[3]);
if ((sum3 != 10)) {
    int32_t _uya_ret = 32;
    return _uya_ret;
}
if ((((arr16[0] < arr16[1]) && (arr16[1] < arr16[2])) && (arr16[2] < arr16[3]))) {
} else {
    int32_t _uya_ret = 33;
    return _uya_ret;
}
int32_t arr17[1] = {0};
int32_t _uya_ret = 0;
return _uya_ret;
}
