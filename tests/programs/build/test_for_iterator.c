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


// 字符串常量
static const uint8_t str0[] = "Test 1 failed: sum = %d, expected 10\n";
static const uint8_t str1[] = "Test 2 failed: sum2 = %d, expected 10\n";
static const uint8_t str2[] = "All tests passed!\n";

struct TypeInfo;
struct RangeIterator;


struct err_union_void { uint32_t error_id; };
struct uya_interface_IIteratorI32 { void *vtable; void *data; };
struct uya_vtable_IIteratorI32 {
    struct err_union_void (*next)(void *self);
    int32_t (*value)(void *self);
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

struct RangeIterator {
    int32_t current;
    int32_t end_val;
    int32_t started;
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

struct err_union_void uya_RangeIterator_next(const struct RangeIterator * self);
int32_t uya_RangeIterator_value(const struct RangeIterator * self);
struct RangeIterator make_range(int32_t start, int32_t end_val);
int32_t uya_main(void);
static const struct uya_vtable_IIteratorI32 uya_vtable_IIteratorI32_RangeIterator = { (struct err_union_void (*)(void *self))&uya_RangeIterator_next, (int32_t (*)(void *self))&uya_RangeIterator_value };


struct err_union_void uya_RangeIterator_next(const struct RangeIterator * self) {
    if ((self->started == 0)) {
        ((struct RangeIterator *)self)->started = 1;
    } else {
        ((struct RangeIterator *)self)->current = (self->current + 1);
    }
    if ((self->current >= self->end_val)) {
        return (struct err_union_void){ .error_id = 219462544U };
    }
    return (struct err_union_void){ .error_id = 0 };
}

int32_t uya_RangeIterator_value(const struct RangeIterator * self) {
    int32_t _uya_ret = self->current;
    return _uya_ret;
}

struct RangeIterator make_range(int32_t start, int32_t end_val) {
    struct RangeIterator _uya_ret = (struct RangeIterator){.current = start, .end_val = end_val, .started = 0};
    return _uya_ret;
}

int32_t uya_main(void) {
struct RangeIterator iter = make_range(0, 5);
int32_t sum = 0;
while (true) {
    struct err_union_void _uya_catch_tmp = uya_RangeIterator_next(&(iter)); if (_uya_catch_tmp.error_id != 0) {
        break;
    }
    const int32_t v = uya_RangeIterator_value(&(iter));
    sum = (sum + v);
}
if ((sum != 10)) {
    printf((const char *)(uint8_t *)str0, sum);
    int32_t _uya_ret = 1;
    return _uya_ret;
}
struct RangeIterator iter2 = make_range(0, 5);
int32_t sum2 = 0;
{
    // for loop - iterator interface
    struct RangeIterator _uya_iter = iter2;
    while (1) {
        struct err_union_void _uya_next_result = uya_RangeIterator_next(&_uya_iter);
        if (_uya_next_result.error_id != 0) {
            break;  // error.IterEnd
        }
        int32_t v = uya_RangeIterator_value(&_uya_iter);
        sum2 = (sum2 + v);
    }
}
if ((sum2 != 10)) {
    printf((const char *)(uint8_t *)str1, sum2);
    int32_t _uya_ret = 2;
    return _uya_ret;
}
printf("%s", (const char *)(uint8_t *)str2);
int32_t _uya_ret = 0;
return _uya_ret;
}
