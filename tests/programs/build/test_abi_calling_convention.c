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
struct SmallStruct;
struct MediumStruct;
struct LargeStruct;
struct VeryLargeStruct;



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

struct SmallStruct {
    int32_t x;
    int32_t y;
};

struct MediumStruct {
    int32_t a;
    int32_t b;
    int32_t c;
    int32_t d;
};

struct LargeStruct {
    int32_t a;
    int32_t b;
    int32_t c;
    int32_t d;
    int32_t e;
    int32_t f;
};

struct VeryLargeStruct {
    int32_t a;
    int32_t b;
    int32_t c;
    int32_t d;
    int32_t e;
    int32_t f;
    int32_t g;
    int32_t h;
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

int32_t test_small_struct_param(struct SmallStruct s);
int32_t test_small_struct_param_call();
int32_t test_medium_struct_param(struct MediumStruct m);
int32_t test_medium_struct_param_call();
int32_t test_large_struct_param(struct LargeStruct l);
int32_t test_large_struct_param_call();
struct SmallStruct test_small_struct_return();
int32_t test_small_struct_return_call();
struct MediumStruct test_medium_struct_return();
int32_t test_medium_struct_return_call();
struct LargeStruct test_large_struct_return();
int32_t test_large_struct_return_call();
int32_t test_mixed_params(int32_t a, struct SmallStruct s, int32_t b);
int32_t test_mixed_params_call();
int32_t test_multiple_small_structs(struct SmallStruct s1, struct SmallStruct s2);
int32_t test_multiple_small_structs_call();
struct SmallStruct test_struct_param_and_return(struct SmallStruct s);
int32_t test_struct_param_and_return_call();
int32_t test_recursive_struct(int32_t n, struct SmallStruct s);
int32_t test_recursive_struct_call();
extern int32_t c_small_struct_param(struct SmallStruct s);
extern int32_t c_medium_struct_param(struct MediumStruct m);
extern int32_t c_large_struct_param(struct LargeStruct *l);
extern struct SmallStruct c_small_struct_return();
extern struct MediumStruct c_medium_struct_return();
extern struct LargeStruct c_large_struct_return();
extern int32_t c_mixed_params(int32_t a, struct SmallStruct s, int32_t b);
int32_t test_c_small_struct_param();
int32_t test_c_medium_struct_param();
int32_t test_c_large_struct_param();
int32_t test_c_small_struct_return();
int32_t test_c_medium_struct_return();
int32_t test_c_large_struct_return();
int32_t test_c_mixed_params();
int32_t uya_main(void);

int32_t test_small_struct_param(struct SmallStruct s) {
    if (((s.x != 10) || (s.y != 20))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_small_struct_param_call() {
    struct SmallStruct s = (struct SmallStruct){.x = 10, .y = 20};
    const int32_t result = test_small_struct_param(s);
    int32_t _uya_ret = result;
    return _uya_ret;
}

int32_t test_medium_struct_param(struct MediumStruct m) {
    if (((((m.a != 1) || (m.b != 2)) || (m.c != 3)) || (m.d != 4))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_medium_struct_param_call() {
    struct MediumStruct m = (struct MediumStruct){.a = 1, .b = 2, .c = 3, .d = 4};
    const int32_t result = test_medium_struct_param(m);
    int32_t _uya_ret = result;
    return _uya_ret;
}

int32_t test_large_struct_param(struct LargeStruct l) {
    if (((((((l.a != 1) || (l.b != 2)) || (l.c != 3)) || (l.d != 4)) || (l.e != 5)) || (l.f != 6))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_large_struct_param_call() {
    struct LargeStruct l = (struct LargeStruct){.a = 1, .b = 2, .c = 3, .d = 4, .e = 5, .f = 6};
    const int32_t result = test_large_struct_param(l);
    int32_t _uya_ret = result;
    return _uya_ret;
}

struct SmallStruct test_small_struct_return() {
    struct SmallStruct _uya_ret = (struct SmallStruct){.x = 100, .y = 200};
    return _uya_ret;
}

int32_t test_small_struct_return_call() {
    struct SmallStruct s = test_small_struct_return();
    if (((s.x != 100) || (s.y != 200))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

struct MediumStruct test_medium_struct_return() {
    struct MediumStruct _uya_ret = (struct MediumStruct){.a = 10, .b = 20, .c = 30, .d = 40};
    return _uya_ret;
}

int32_t test_medium_struct_return_call() {
    struct MediumStruct m = test_medium_struct_return();
    if (((((m.a != 10) || (m.b != 20)) || (m.c != 30)) || (m.d != 40))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

struct LargeStruct test_large_struct_return() {
    struct LargeStruct _uya_ret = (struct LargeStruct){.a = 1, .b = 2, .c = 3, .d = 4, .e = 5, .f = 6};
    return _uya_ret;
}

int32_t test_large_struct_return_call() {
    struct LargeStruct l = test_large_struct_return();
    if (((((((l.a != 1) || (l.b != 2)) || (l.c != 3)) || (l.d != 4)) || (l.e != 5)) || (l.f != 6))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_mixed_params(int32_t a, struct SmallStruct s, int32_t b) {
    if (((((a != 1) || (s.x != 10)) || (s.y != 20)) || (b != 2))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_mixed_params_call() {
    struct SmallStruct s = (struct SmallStruct){.x = 10, .y = 20};
    const int32_t result = test_mixed_params(1, s, 2);
    int32_t _uya_ret = result;
    return _uya_ret;
}

int32_t test_multiple_small_structs(struct SmallStruct s1, struct SmallStruct s2) {
    if (((((s1.x != 1) || (s1.y != 2)) || (s2.x != 3)) || (s2.y != 4))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_multiple_small_structs_call() {
    struct SmallStruct s1 = (struct SmallStruct){.x = 1, .y = 2};
    struct SmallStruct s2 = (struct SmallStruct){.x = 3, .y = 4};
    const int32_t result = test_multiple_small_structs(s1, s2);
    int32_t _uya_ret = result;
    return _uya_ret;
}

struct SmallStruct test_struct_param_and_return(struct SmallStruct s) {
    struct SmallStruct _uya_ret = (struct SmallStruct){.x = (s.x * 2), .y = (s.y * 2)};
    return _uya_ret;
}

int32_t test_struct_param_and_return_call() {
    struct SmallStruct input = (struct SmallStruct){.x = 5, .y = 10};
    struct SmallStruct output = test_struct_param_and_return(input);
    if (((output.x != 10) || (output.y != 20))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_recursive_struct(int32_t n, struct SmallStruct s) {
    if ((n <= 0)) {
        int32_t _uya_ret = (s.x + s.y);
        return _uya_ret;
    }
    struct SmallStruct new_s = (struct SmallStruct){.x = (s.x + 1), .y = (s.y + 1)};
    int32_t _uya_ret = test_recursive_struct((n - 1), new_s);
    return _uya_ret;
}

int32_t test_recursive_struct_call() {
    struct SmallStruct s = (struct SmallStruct){.x = 1, .y = 2};
    const int32_t result = test_recursive_struct(2, s);
    if ((result != 7)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}








int32_t test_c_small_struct_param() {
    struct SmallStruct s = (struct SmallStruct){.x = 100, .y = 200};
    const int32_t result = c_small_struct_param(s);
    if ((result != 300)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_c_medium_struct_param() {
    struct MediumStruct m = (struct MediumStruct){.a = 1, .b = 2, .c = 3, .d = 4};
    const int32_t result = c_medium_struct_param(m);
    if ((result != 10)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_c_large_struct_param() {
    struct LargeStruct l = (struct LargeStruct){.a = 1, .b = 2, .c = 3, .d = 4, .e = 5, .f = 6};
    const int32_t result = c_large_struct_param(&l);
    if ((result != 21)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_c_small_struct_return() {
    struct SmallStruct s = c_small_struct_return();
    if (((s.x != 50) || (s.y != 60))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_c_medium_struct_return() {
    struct MediumStruct m = c_medium_struct_return();
    if (((((m.a != 11) || (m.b != 22)) || (m.c != 33)) || (m.d != 44))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_c_large_struct_return() {
    struct LargeStruct l = c_large_struct_return();
    if (((((((l.a != 1) || (l.b != 2)) || (l.c != 3)) || (l.d != 4)) || (l.e != 5)) || (l.f != 6))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_c_mixed_params() {
    struct SmallStruct s = (struct SmallStruct){.x = 7, .y = 8};
    const int32_t result = c_mixed_params(5, s, 6);
    if ((result != 26)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t uya_main(void) {
const int32_t result1 = test_small_struct_param_call();
if ((result1 != 0)) {
    int32_t _uya_ret = (10 + result1);
    return _uya_ret;
}
const int32_t result2 = test_medium_struct_param_call();
if ((result2 != 0)) {
    int32_t _uya_ret = (20 + result2);
    return _uya_ret;
}
const int32_t result3 = test_large_struct_param_call();
if ((result3 != 0)) {
    int32_t _uya_ret = (30 + result3);
    return _uya_ret;
}
const int32_t result4 = test_small_struct_return_call();
if ((result4 != 0)) {
    int32_t _uya_ret = (40 + result4);
    return _uya_ret;
}
const int32_t result5 = test_medium_struct_return_call();
if ((result5 != 0)) {
    int32_t _uya_ret = (50 + result5);
    return _uya_ret;
}
const int32_t result6 = test_large_struct_return_call();
if ((result6 != 0)) {
    int32_t _uya_ret = (60 + result6);
    return _uya_ret;
}
const int32_t result7 = test_mixed_params_call();
if ((result7 != 0)) {
    int32_t _uya_ret = (70 + result7);
    return _uya_ret;
}
const int32_t result8 = test_multiple_small_structs_call();
if ((result8 != 0)) {
    int32_t _uya_ret = (80 + result8);
    return _uya_ret;
}
const int32_t result9 = test_struct_param_and_return_call();
if ((result9 != 0)) {
    int32_t _uya_ret = (90 + result9);
    return _uya_ret;
}
const int32_t result10 = test_recursive_struct_call();
if ((result10 != 0)) {
    int32_t _uya_ret = (100 + result10);
    return _uya_ret;
}
const int32_t result12 = test_c_small_struct_param();
if ((result12 != 0)) {
    int32_t _uya_ret = (120 + result12);
    return _uya_ret;
}
const int32_t result13 = test_c_medium_struct_param();
if ((result13 != 0)) {
    int32_t _uya_ret = (130 + result13);
    return _uya_ret;
}
const int32_t result14 = test_c_large_struct_param();
if ((result14 != 0)) {
    int32_t _uya_ret = (140 + result14);
    return _uya_ret;
}
const int32_t result15 = test_c_small_struct_return();
if ((result15 != 0)) {
    int32_t _uya_ret = (150 + result15);
    return _uya_ret;
}
const int32_t result16 = test_c_medium_struct_return();
if ((result16 != 0)) {
    int32_t _uya_ret = (160 + result16);
    return _uya_ret;
}
const int32_t result17 = test_c_large_struct_return();
if ((result17 != 0)) {
    int32_t _uya_ret = (170 + result17);
    return _uya_ret;
}
const int32_t result18 = test_c_mixed_params();
if ((result18 != 0)) {
    int32_t _uya_ret = (180 + result18);
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
