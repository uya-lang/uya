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

int32_t test_array_size();
int32_t test_init_value();
int32_t test_loop();
int32_t test_condition();
int32_t test_for_range();
int32_t test_struct_init();
int32_t add(int32_t a, int32_t b);
int32_t test_function_call();
int32_t test_assignment();
int32_t test_array_index();
int32_t uya_main(void);

int32_t test_array_size() {
int32_t arr[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    arr[0] = 42;
    if ((arr[0] != 42)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_init_value() {
    const int32_t val = 42;
    if ((val != 42)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t mutable = 42;
    mutable = (mutable + 1);
    if ((mutable != 43)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_loop() {
    int32_t sum = 0;
    int32_t i = 0;
    while ((i < 5)) {
        sum = (sum + 1);
        i = (i + 1);
    }
    if ((sum != 5)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_condition() {
    const int32_t val = 50;
    if ((val < 100)) {
        int32_t _uya_ret = 0;
        return _uya_ret;
    }
    int32_t _uya_ret = 1;
    return _uya_ret;
}

int32_t test_for_range() {
    int32_t sum = 0;
    {
        // for range
        int32_t i = 0;
        int32_t _uya_end = 5;
        for (; i < _uya_end; i++) {
            sum = (sum + i);
        }
    }
    if ((sum != 10)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_struct_init() {
    struct Point p = (struct Point){.x = 42, .y = 42};
    if ((p.x != 42)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if ((p.y != 42)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t add(int32_t a, int32_t b) {
    int32_t _uya_ret = (a + b);
    return _uya_ret;
}

int32_t test_function_call() {
    const int32_t result = add(42, 5);
    if ((result != 47)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_assignment() {
    int32_t x = 0;
    x = 42;
    if ((x != 42)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    x = (x + 5);
    if ((x != 47)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_array_index() {
int32_t arr[50] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    arr[42] = 100;
    if ((arr[42] != 100)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t uya_main(void) {
int32_t result = 0;
result = test_array_size();
if ((result != 0)) {
    int32_t _uya_ret = (result + 10);
    return _uya_ret;
}
result = test_init_value();
if ((result != 0)) {
    int32_t _uya_ret = (result + 20);
    return _uya_ret;
}
result = test_loop();
if ((result != 0)) {
    int32_t _uya_ret = (result + 30);
    return _uya_ret;
}
result = test_condition();
if ((result != 0)) {
    int32_t _uya_ret = (result + 40);
    return _uya_ret;
}
result = test_for_range();
if ((result != 0)) {
    int32_t _uya_ret = (result + 50);
    return _uya_ret;
}
result = test_struct_init();
if ((result != 0)) {
    int32_t _uya_ret = (result + 60);
    return _uya_ret;
}
result = test_function_call();
if ((result != 0)) {
    int32_t _uya_ret = (result + 70);
    return _uya_ret;
}
result = test_assignment();
if ((result != 0)) {
    int32_t _uya_ret = (result + 80);
    return _uya_ret;
}
result = test_array_index();
if ((result != 0)) {
    int32_t _uya_ret = (result + 90);
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
