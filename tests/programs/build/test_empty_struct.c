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
struct Empty;
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

struct Empty {
    char _empty;
};

struct Container {
    int32_t data;
    struct Empty empty;
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

struct Empty process_empty(struct Empty e);
int32_t uya_main(void);

struct Empty process_empty(struct Empty e) {
    struct Empty _uya_ret = e;
    return _uya_ret;
}

int32_t uya_main(void) {
const int32_t empty_size = sizeof(struct Empty);
if ((empty_size != 1)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
struct Empty empty;
memset((void *)&empty, 0, sizeof(empty));
const int32_t empty_var_size = sizeof(empty);
if ((empty_var_size != 1)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
const int32_t empty_align = uya_alignof(struct Empty);
if ((empty_align != 1)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
const int32_t empty_var_align = uya_alignof(struct Empty);
if ((empty_var_align != 1)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
const int32_t empty_ptr_size = sizeof(struct Empty *);
if (((empty_ptr_size != 4) && (empty_ptr_size != 8))) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
struct Empty * empty_ptr = (&empty);
if ((empty_ptr == NULL)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
struct Empty empty1;
memset((void *)&empty1, 0, sizeof(empty1));
struct Empty empty2;
memset((void *)&empty2, 0, sizeof(empty2));
if ((0)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
struct Empty empty3 = empty1;
if ((0)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
struct Empty empty_array[3] = {(struct Empty){}, (struct Empty){}, (struct Empty){}};
const int32_t empty_array_size = sizeof(empty_array);
if ((empty_array_size != 3)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
struct Empty empty4 = process_empty(empty2);
struct Empty empty_cmp;
memset((void *)&empty_cmp, 0, sizeof(empty_cmp));
if ((0)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
struct Container container = (struct Container){.data = 42, .empty = (struct Empty){}};
const int32_t container_size = sizeof(struct Container);
if ((container_size != 8)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
