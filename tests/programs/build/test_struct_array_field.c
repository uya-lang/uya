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
struct Data;
struct MultiArray;
struct Inner;
struct Outer;



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

struct Data {
    int32_t values[3];
    int32_t count;
};

struct MultiArray {
    int32_t arr1[2];
    uint8_t arr2[4];
    int32_t count;
};

struct Inner {
    int32_t items[2];
};

struct Outer {
    struct Inner inner;
    int32_t size;
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

int32_t process_array_field(struct Data d);
int32_t uya_main(void);

int32_t process_array_field(struct Data d) {
    int32_t total = 0;
    int32_t i2 = 0;
    while ((i2 < sizeof(d.values) / sizeof((d.values)[0]))) {
        total = (total + d.values[i2]);
        i2 = (i2 + 1);
    }
    int32_t _uya_ret = total;
    return _uya_ret;
}

int32_t uya_main(void) {
struct Data data = (struct Data){.values = {10, 20, 30}, .count = 3};
if ((((data.values[0] != 10) || (data.values[1] != 20)) || (data.values[2] != 30))) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
if ((data.count != 3)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
int32_t value1 = data.values[0];
if ((value1 != 10)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
data.values[1] = 200;
if ((data.values[1] != 200)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
data.count = 5;
if ((data.count != 5)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
const int32_t data_type_size = sizeof(struct Data);
if ((data_type_size != 16)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
const int32_t data_var_size = sizeof(data);
if ((data_var_size != 16)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
const int32_t values_size = sizeof(data.values);
if ((values_size != 12)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
const int32_t values_len = sizeof(data.values) / sizeof((data.values)[0]);
if ((values_len != 3)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
int32_t sum = 0;
int32_t i = 0;
while ((i < sizeof(data.values) / sizeof((data.values)[0]))) {
    sum = (sum + data.values[i]);
    i = (i + 1);
}
if ((sum != 240)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
int32_t sum2 = 0;
{
    // for loop - array traversal
    size_t _len = sizeof(data.values) / sizeof(data.values[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t item = data.values[_i];
        sum2 = (sum2 + item);
    }
}
if ((sum2 != 240)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
{
    // for loop - array traversal
    size_t _len = sizeof(data.values) / sizeof(data.values[0]);
    for (size_t _i = 0; _i < _len; _i++) {
        int32_t *item = &data.values[_i];
        (*item) = ((*item) * 2);
    }
}
if ((((data.values[0] != 20) || (data.values[1] != 400)) || (data.values[2] != 60))) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
const int32_t data_align = uya_alignof(struct Data);
if ((data_align != 4)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
struct MultiArray multi = (struct MultiArray){.arr1 = {1, 2}, .arr2 = {10, 20, 30, 40}, .count = 2};
if (((multi.arr1[0] != 1) || (multi.arr1[1] != 2))) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
if (((multi.arr2[0] != 10) || (multi.arr2[3] != 40))) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
struct Data data2 = (struct Data){.values = {1, 2, 3}, .count = 3};
int32_t total = process_array_field(data2);
if ((total != 6)) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
struct Data data3 = (struct Data){.values = {100, 200, 300}, .count = 3};
struct Data * ptr = (&data3);
int32_t value2 = ptr->values[0];
if ((value2 != 100)) {
    int32_t _uya_ret = 17;
    return _uya_ret;
}
ptr->values[1] = 250;
if ((data3.values[1] != 250)) {
    int32_t _uya_ret = 18;
    return _uya_ret;
}
struct Outer outer = (struct Outer){.inner = (struct Inner){.items = {10, 20}}, .size = 2};
if (((outer.inner.items[0] != 10) || (outer.inner.items[1] != 20))) {
    int32_t _uya_ret = 19;
    return _uya_ret;
}
outer.inner.items[0] = 100;
if ((outer.inner.items[0] != 100)) {
    int32_t _uya_ret = 20;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
