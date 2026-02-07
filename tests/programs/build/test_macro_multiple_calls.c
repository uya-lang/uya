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

int32_t test_same_expr();
int32_t test_same_function();
int32_t helper1();
int32_t helper2();
int32_t helper3();
int32_t test_different_functions();
int32_t test_loop_calls();
int32_t test_branch_calls();
int32_t test_nested_calls();
int32_t uya_main(void);

int32_t test_same_expr() {
    const int32_t result = ((42 + 42) + 42);
    if ((result != 126)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_same_function() {
    const int32_t a = 42;
    const int32_t b = 42;
    const int32_t c = 42;
    const int32_t d = 42;
    const int32_t e = 42;
    if ((a != 42)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if ((b != 42)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if ((c != 42)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    if ((d != 42)) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    if ((e != 42)) {
        int32_t _uya_ret = 5;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t helper1() {
    int32_t _uya_ret = 42;
    return _uya_ret;
}

int32_t helper2() {
    int32_t _uya_ret = (42 * 2);
    return _uya_ret;
}

int32_t helper3() {
    int32_t _uya_ret = (42 + 42);
    return _uya_ret;
}

int32_t test_different_functions() {
    if ((helper1() != 42)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if ((helper2() != 84)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if ((helper3() != 84)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_loop_calls() {
    int32_t sum = 0;
    int32_t i = 0;
    while ((i < 5)) {
        sum = (sum + 42);
        i = (i + 1);
    }
    if ((sum != 210)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_branch_calls() {
    const int32_t x = 42;
    int32_t result = 0;
    if ((x > 40)) {
        result = 42;
    } else {
        result = 0;
    }
    if ((result != 42)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_nested_calls() {
    int32_t i = 0;
    while ((i < 3)) {
        int32_t j = 0;
        while ((j < 2)) {
            const int32_t val = 42;
            if ((val != 42)) {
                int32_t _uya_ret = 1;
                return _uya_ret;
            }
            j = (j + 1);
        }
        i = (i + 1);
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t uya_main(void) {
int32_t result = 0;
result = test_same_expr();
if ((result != 0)) {
    int32_t _uya_ret = (result + 10);
    return _uya_ret;
}
result = test_same_function();
if ((result != 0)) {
    int32_t _uya_ret = (result + 20);
    return _uya_ret;
}
result = test_different_functions();
if ((result != 0)) {
    int32_t _uya_ret = (result + 30);
    return _uya_ret;
}
result = test_loop_calls();
if ((result != 0)) {
    int32_t _uya_ret = (result + 40);
    return _uya_ret;
}
result = test_branch_calls();
if ((result != 0)) {
    int32_t _uya_ret = (result + 50);
    return _uya_ret;
}
result = test_nested_calls();
if ((result != 0)) {
    int32_t _uya_ret = (result + 60);
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
