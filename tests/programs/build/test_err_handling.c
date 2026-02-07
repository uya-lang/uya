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

struct err_union_int32_t { uint32_t error_id; int32_t value; };
struct err_union_int32_t div(int32_t a, int32_t b);
struct err_union_int32_t uya_main(void);

struct err_union_int32_t div(int32_t a, int32_t b) {
    if ((b == 0)) {
        return (struct err_union_int32_t){ .error_id = 1496558053U, .value = 0 };
    }
    struct err_union_int32_t _uya_ret = (struct err_union_int32_t){ .error_id = 0, .value = (a / b) };
    return _uya_ret;
}

struct err_union_int32_t uya_main(void) {
const int32_t x = ({ struct err_union_int32_t _uya_try_tmp = div(10, 2); if (_uya_try_tmp.error_id != 0) return _uya_try_tmp; _uya_try_tmp.value; });
const int32_t y = ({ int32_t _uya_catch_result; struct err_union_int32_t _uya_catch_tmp = div(10, 0); if (_uya_catch_tmp.error_id != 0) {
    _uya_catch_result = (0);
} else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
const int32_t z = ({ int32_t _uya_catch_result; struct err_union_int32_t _uya_catch_tmp = div(8, 4); if (_uya_catch_tmp.error_id != 0) {
    struct err_union_int32_t e = _uya_catch_tmp;
    if ((e.error_id == 1496558053U)) {
        struct err_union_int32_t _uya_ret = (struct err_union_int32_t){ .error_id = 0, .value = 1 };
        return _uya_ret;
    }
    _uya_catch_result = (0);
} else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
if ((x != 5)) {
    struct err_union_int32_t _uya_ret = (struct err_union_int32_t){ .error_id = 0, .value = 2 };
    return _uya_ret;
}
if ((y != 0)) {
    struct err_union_int32_t _uya_ret = (struct err_union_int32_t){ .error_id = 0, .value = 3 };
    return _uya_ret;
}
if ((z != 2)) {
    struct err_union_int32_t _uya_ret = (struct err_union_int32_t){ .error_id = 0, .value = 4 };
    return _uya_ret;
}
struct err_union_int32_t _uya_ret = (struct err_union_int32_t){ .error_id = 0, .value = 0 };
return _uya_ret;
}
