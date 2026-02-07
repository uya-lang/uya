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

enum Priority {
    LOW = 1,
    MEDIUM = 2,
    HIGH = 3
};

enum Status {
    PENDING,
    RUNNING,
    COMPLETED
};

enum Mixed {
    FIRST = 10,
    SECOND,
    THIRD = 20,
    FOURTH
};



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
enum Priority p1 = LOW;
enum Priority p2 = LOW;
if ((p1 != p2)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
enum Priority p3 = MEDIUM;
if ((p1 == p3)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
if ((p1 == p3)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
if ((p1 != p2)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
if ((p1 >= p3)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
if ((p3 >= HIGH)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
if ((p1 < p2)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
if ((p3 <= p1)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
if ((HIGH <= p3)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
if ((p1 > p2)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
if ((p1 > p2)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
if ((p1 > p3)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
if ((p3 > HIGH)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
if ((p1 < p2)) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
if ((p3 < p1)) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
if ((HIGH < p3)) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
enum Status s1 = PENDING;
enum Status s2 = RUNNING;
enum Status s3 = COMPLETED;
if ((s1 >= s2)) {
    int32_t _uya_ret = 17;
    return _uya_ret;
}
if ((s2 >= s3)) {
    int32_t _uya_ret = 18;
    return _uya_ret;
}
if ((s3 <= s2)) {
    int32_t _uya_ret = 19;
    return _uya_ret;
}
enum Mixed m1 = FIRST;
enum Mixed m2 = SECOND;
enum Mixed m3 = THIRD;
enum Mixed m4 = FOURTH;
if ((m1 >= m2)) {
    int32_t _uya_ret = 20;
    return _uya_ret;
}
if ((m2 >= m3)) {
    int32_t _uya_ret = 21;
    return _uya_ret;
}
if ((m3 >= m4)) {
    int32_t _uya_ret = 22;
    return _uya_ret;
}
int32_t result = 0;
if ((p1 < p3)) {
    result = 100;
} else {
    result = 200;
}
if ((result != 100)) {
    int32_t _uya_ret = 23;
    return _uya_ret;
}
enum Priority p4 = HIGH;
if (((p1 < p3) && (p3 < p4))) {
} else {
    int32_t _uya_ret = 24;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
