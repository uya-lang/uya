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
struct Box_i32;
struct Pair_i32_bool;
struct Container_i32;



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

struct Box_i32 {
    int32_t value;
};

struct Pair_i32_bool {
    int32_t key;
    bool value;
};

struct Container_i32 {
    int32_t data;
    bool valid;
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

int32_t identity_i32(int32_t x);
bool identity_bool(bool x);
int64_t identity_i64(int64_t x);
int8_t identity_i8(int8_t x);
int32_t first_i32_i64(int32_t a, int64_t b);
int64_t second_i32_i64(int32_t a, int64_t b);
int32_t max_i32(int32_t a, int32_t b);
int32_t min_i32(int32_t a, int32_t b);
void swap_i32(int32_t * a, int32_t * b);
int32_t uya_main(void);

int32_t identity_i32(int32_t x) {
    int32_t _uya_ret = x;
    return _uya_ret;
}

bool identity_bool(bool x) {
    bool _uya_ret = x;
    return _uya_ret;
}

int64_t identity_i64(int64_t x) {
    int64_t _uya_ret = x;
    return _uya_ret;
}

int8_t identity_i8(int8_t x) {
    int8_t _uya_ret = x;
    return _uya_ret;
}

int32_t first_i32_i64(int32_t a, int64_t b) {
    int32_t _uya_ret = a;
    return _uya_ret;
}

int64_t second_i32_i64(int32_t a, int64_t b) {
    int64_t _uya_ret = b;
    return _uya_ret;
}

int32_t max_i32(int32_t a, int32_t b) {
    if ((a > b)) {
        int32_t _uya_ret = a;
        return _uya_ret;
    }
    int32_t _uya_ret = b;
    return _uya_ret;
}

int32_t min_i32(int32_t a, int32_t b) {
    if ((a < b)) {
        int32_t _uya_ret = a;
        return _uya_ret;
    }
    int32_t _uya_ret = b;
    return _uya_ret;
}

void swap_i32(int32_t * a, int32_t * b) {
    const int32_t temp = (*a);
    (*a) = (*b);
    (*b) = temp;
}

int32_t uya_main(void) {
const int32_t id1 = identity_i32(42);
if ((id1 != 42)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const bool id2 = identity_bool(true);
if ((id2 != true)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
const int32_t f1 = first_i32_i64(10, 20);
if ((f1 != 10)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
const int64_t s1 = second_i32_i64(10, 20);
if ((s1 != 20)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
const int32_t m1 = max_i32(10, 20);
if ((m1 != 20)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
const int32_t m2 = min_i32(10, 20);
if ((m2 != 10)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
int32_t a = 100;
int32_t b = 200;
swap_i32((&a), (&b));
if ((a != 200)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
if ((b != 100)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
struct Box_i32 box1 = (struct Box_i32){.value = 999};
if ((box1.value != 999)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
struct Pair_i32_bool pair1 = (struct Pair_i32_bool){.key = 42, .value = true};
if ((pair1.key != 42)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
if ((pair1.value != true)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
struct Container_i32 container1 = (struct Container_i32){.data = 123, .valid = true};
if ((container1.data != 123)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
if ((container1.valid != true)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
const int32_t i1 = identity_i32(1);
const int64_t i2 = identity_i64(2);
const int8_t i3 = identity_i8(3);
if ((i1 != 1)) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
if ((i2 != 2)) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
if ((i3 != 3)) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
const int32_t nested = identity_i32(identity_i32(identity_i32(42)));
if ((nested != 42)) {
    int32_t _uya_ret = 17;
    return _uya_ret;
}
const int32_t id_val = identity_i32(10);
const int32_t max_val = max_i32(5, 3);
const int32_t expr_result = (id_val + max_val);
if ((expr_result != 15)) {
    int32_t _uya_ret = 18;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
