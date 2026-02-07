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

int32_t test_scope_nesting();
int32_t test_param_scope(int32_t x, int32_t y);
int32_t test_if_block_scope(bool condition);
int32_t test_while_block_scope();
int32_t test_for_block_scope();
int32_t test_function_call_scope();
int32_t test_deep_nesting();
int32_t uya_main(void);

const int32_t global_const = 100;

int32_t global_var = 200;

int32_t test_scope_nesting() {
    const int32_t local_const = 10;
    int32_t local_var = 20;
    if (((global_const != 100) || (global_var != 200))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if (((local_const != 10) || (local_var != 20))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    const int32_t block_const = 30;
    int32_t block_var = 40;
    if (((global_const != 100) || (local_const != 10))) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    if (((block_const != 30) || (block_var != 40))) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    local_var = 25;
    global_var = 250;
    if (((local_var != 25) || (global_var != 250))) {
        int32_t _uya_ret = 5;
        return _uya_ret;
    }
    const int32_t inner_block = 50;
    const int32_t inner_inner = 60;
    if (((((global_const != 100) || (local_const != 10)) || (inner_block != 50)) || (inner_inner != 60))) {
        int32_t _uya_ret = 6;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_param_scope(int32_t x, int32_t y) {
    if (((x != 1) || (y != 2))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    const int32_t block_val = (x + y);
    if ((block_val != 3)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_if_block_scope(bool condition) {
    if (condition) {
        const int32_t if_block_var = 100;
        if ((if_block_var != 100)) {
            int32_t _uya_ret = 1;
            return _uya_ret;
        }
    } else {
        const int32_t else_block_var = 200;
        if ((else_block_var != 200)) {
            int32_t _uya_ret = 2;
            return _uya_ret;
        }
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_while_block_scope() {
    int32_t count = 0;
    while ((count < 3)) {
        const int32_t loop_var = (count * 10);
        count = (count + 1);
        if (((loop_var < 0) || (loop_var > 20))) {
            int32_t _uya_ret = 1;
            return _uya_ret;
        }
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_for_block_scope() {
const int32_t arr[3] = {10, 20, 30};
    int32_t sum = 0;
    {
        // for loop - array traversal
        size_t _len = sizeof(arr) / sizeof(arr[0]);
        for (size_t _i = 0; _i < _len; _i++) {
            const int32_t item = arr[_i];
            const int32_t loop_const = (item * 2);
            sum = (sum + loop_const);
        }
    }
    if ((sum != 120)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_function_call_scope() {
    const int32_t local = 42;
    const int32_t result = test_param_scope(1, 2);
    if ((result != 0)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if ((local != 42)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_deep_nesting() {
    const int32_t level1 = 1;
    const int32_t level2 = 2;
    const int32_t level3 = 3;
    const int32_t level4 = 4;
    if (((((level1 != 1) || (level2 != 2)) || (level3 != 3)) || (level4 != 4))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t uya_main(void) {
const int32_t result1 = test_scope_nesting();
if ((result1 != 0)) {
    int32_t _uya_ret = result1;
    return _uya_ret;
}
const int32_t result2 = test_param_scope(1, 2);
if ((result2 != 0)) {
    int32_t _uya_ret = (10 + result2);
    return _uya_ret;
}
const int32_t result3 = test_if_block_scope(true);
if ((result3 != 0)) {
    int32_t _uya_ret = (20 + result3);
    return _uya_ret;
}
const int32_t result3b = test_if_block_scope(false);
if ((result3b != 0)) {
    int32_t _uya_ret = (30 + result3b);
    return _uya_ret;
}
const int32_t result4 = test_while_block_scope();
if ((result4 != 0)) {
    int32_t _uya_ret = (40 + result4);
    return _uya_ret;
}
const int32_t result5 = test_for_block_scope();
if ((result5 != 0)) {
    int32_t _uya_ret = (50 + result5);
    return _uya_ret;
}
const int32_t result6 = test_function_call_scope();
if ((result6 != 0)) {
    int32_t _uya_ret = (60 + result6);
    return _uya_ret;
}
const int32_t result7 = test_deep_nesting();
if ((result7 != 0)) {
    int32_t _uya_ret = (70 + result7);
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
