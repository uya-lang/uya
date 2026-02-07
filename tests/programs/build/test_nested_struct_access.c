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
struct Inner;
struct Outer;
struct DeepInner;
struct DeepMiddle;
struct DeepOuter;
struct ArrayOuter;



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

struct Inner {
    int32_t value;
};

struct Outer {
    struct Inner inner;
    int32_t count;
};

struct DeepInner {
    int32_t data;
};

struct DeepMiddle {
    struct DeepInner deep;
    int32_t middle;
};

struct DeepOuter {
    struct DeepMiddle middle;
    int32_t outer;
};

struct ArrayOuter {
    struct Inner items[3];
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

int32_t get_inner_value(struct Outer o);
void modify_inner_value(struct Outer * o);
int32_t uya_main(void);

int32_t get_inner_value(struct Outer o) {
    int32_t _uya_ret = o.inner.value;
    return _uya_ret;
}

void modify_inner_value(struct Outer * o) {
    o->inner.value = 700;
}

int32_t uya_main(void) {
struct Outer outer = (struct Outer){.inner = (struct Inner){.value = 42}, .count = 10};
int32_t inner_value = outer.inner.value;
if ((inner_value != 42)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
outer.inner.value = 100;
if ((outer.inner.value != 100)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
struct Inner inner = (struct Inner){.value = 50};
struct Outer outer2 = (struct Outer){.inner = inner, .count = 20};
struct Inner * inner_ptr = (&outer2.inner);
int32_t value1 = inner_ptr->value;
if ((value1 != 50)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
inner_ptr->value = 200;
if ((outer2.inner.value != 200)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
struct DeepOuter deep = (struct DeepOuter){.middle = (struct DeepMiddle){.deep = (struct DeepInner){.data = 300}, .middle = 200}, .outer = 100};
int32_t deep_data = deep.middle.deep.data;
if ((deep_data != 300)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
deep.middle.deep.data = 400;
if ((deep.middle.deep.data != 400)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
int32_t middle_value = deep.middle.middle;
if ((middle_value != 200)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
struct DeepOuter * deep_ptr = (&deep);
int32_t data1 = deep_ptr->middle.deep.data;
if ((data1 != 400)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
deep_ptr->middle.deep.data = 500;
if ((deep.middle.deep.data != 500)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
struct DeepMiddle * middle_ptr = (&deep.middle);
int32_t data2 = middle_ptr->deep.data;
if ((data2 != 500)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
struct ArrayOuter array_outer = (struct ArrayOuter){.items = {(struct Inner){.value = 1}, (struct Inner){.value = 2}, (struct Inner){.value = 3}}, .size = 3};
int32_t item_value = array_outer.items[0].value;
if ((item_value != 1)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
array_outer.items[1].value = 20;
if ((array_outer.items[1].value != 20)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
struct Outer outer3 = (struct Outer){.inner = (struct Inner){.value = 600}, .count = 30};
int32_t value2 = get_inner_value(outer3);
if ((value2 != 600)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
struct Outer outer3b = (struct Outer){.inner = (struct Inner){.value = 600}, .count = 30};
modify_inner_value((&outer3b));
if ((outer3b.inner.value != 700)) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
struct Outer outer4 = (struct Outer){.inner = (struct Inner){.value = 100}, .count = 10};
struct Outer outer5 = (struct Outer){.inner = (struct Inner){.value = 100}, .count = 10};
if ((!((__uya_memcmp(&(outer4).inner, &(outer5).inner, sizeof((outer4).inner)) == 0) && ((outer4).count == (outer5).count)))) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
struct Outer outer6 = (struct Outer){.inner = (struct Inner){.value = 200}, .count = 10};
if (((__uya_memcmp(&(outer4).inner, &(outer6).inner, sizeof((outer4).inner)) == 0) && ((outer4).count == (outer6).count))) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
