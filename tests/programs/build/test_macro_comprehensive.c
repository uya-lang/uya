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

int32_t test_math_constants();
int32_t test_config_constants();
int32_t test_bit_flags();
int32_t test_status_codes();
int32_t test_boolean_constants();
int32_t test_complex_scenario();
int32_t test_macro_in_expressions();
int32_t uya_main(void);

int32_t test_math_constants() {
    const int32_t pi = 3;
    const int32_t e = 2;
    const int32_t golden = 1;
    if ((pi != 3)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if ((e != 2)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if ((golden != 1)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    const int32_t sum = ((pi + e) + golden);
    if ((sum != 6)) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_config_constants() {
    const int32_t max_size = 1024;
    const int32_t min_size = 64;
    const int32_t timeout = 5000;
    if ((max_size != 1024)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if ((min_size != 64)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if ((timeout != 5000)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    if ((max_size <= min_size)) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    if ((timeout < max_size)) {
        int32_t _uya_ret = 5;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_bit_flags() {
    const int32_t read = 1;
    const int32_t write = 2;
    const int32_t execute = 4;
    const int32_t all = 7;
    if ((read != 1)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if ((write != 2)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if ((execute != 4)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    if ((all != 7)) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    const int32_t combined = ((read | write) | execute);
    if ((combined != all)) {
        int32_t _uya_ret = 5;
        return _uya_ret;
    }
    if (((all & read) != read)) {
        int32_t _uya_ret = 6;
        return _uya_ret;
    }
    if (((all & write) != write)) {
        int32_t _uya_ret = 7;
        return _uya_ret;
    }
    if (((all & execute) != execute)) {
        int32_t _uya_ret = 8;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_status_codes() {
    const int32_t ok = 0;
    const int32_t err_code = (-1);
    const int32_t pending = 1;
    if ((ok != 0)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if ((err_code != (-1))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if ((pending != 1)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    if ((ok != 0)) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    if ((err_code >= 0)) {
        int32_t _uya_ret = 5;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_boolean_constants() {
    const bool enabled = true;
    const bool debug = false;
    if ((!enabled)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if (debug) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if ((!(enabled && (!debug)))) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    if (((!enabled) || debug)) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_complex_scenario() {
    int32_t buffer_size = 64;
    if (true) {
        buffer_size = 1024;
    }
    if ((buffer_size != 1024)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t permissions = 0;
    if ((!false)) {
        permissions = (1 | 2);
    } else {
        permissions = 7;
    }
    if ((permissions != 3)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t status = 1;
    if ((status == 1)) {
        status = 0;
    }
    if ((status != 0)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_macro_in_expressions() {
    const int32_t val = 10;
    int32_t result = 0;
    if ((val > 3)) {
        result = 0;
    } else {
        result = (-1);
    }
    if ((result != 0)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    const int32_t calc = ((1024 - 64) / 3);
    if ((calc != 320)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    const int32_t flags = ((1 << 8) | 2);
    if ((flags != 258)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t uya_main(void) {
int32_t result = 0;
result = test_math_constants();
if ((result != 0)) {
    int32_t _uya_ret = (result + 100);
    return _uya_ret;
}
result = test_config_constants();
if ((result != 0)) {
    int32_t _uya_ret = (result + 200);
    return _uya_ret;
}
result = test_bit_flags();
if ((result != 0)) {
    int32_t _uya_ret = (result + 300);
    return _uya_ret;
}
result = test_status_codes();
if ((result != 0)) {
    int32_t _uya_ret = (result + 400);
    return _uya_ret;
}
result = test_boolean_constants();
if ((result != 0)) {
    int32_t _uya_ret = (result + 500);
    return _uya_ret;
}
result = test_complex_scenario();
if ((result != 0)) {
    int32_t _uya_ret = (result + 600);
    return _uya_ret;
}
result = test_macro_in_expressions();
if ((result != 0)) {
    int32_t _uya_ret = (result + 700);
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
