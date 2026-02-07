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

int32_t uya_main(void);

int32_t uya_main(void) {
const size_t usize_const = (size_t)0;
if ((usize_const != (size_t)0)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const size_t usize_const2 = (size_t)100;
if ((usize_const2 != (size_t)100)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
size_t usize_var = (size_t)42;
if ((usize_var != (size_t)42)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
usize_var = (size_t)200;
if ((usize_var != (size_t)200)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
const int32_t usize_size = sizeof(size_t);
if (((usize_size != 4) && (usize_size != 8))) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
const int32_t usize_var_size = sizeof(usize_var);
if ((usize_var_size != usize_size)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
const int32_t ptr_usize_size = sizeof(size_t *);
const int32_t ptr_i32_size = sizeof(int32_t *);
if ((ptr_usize_size != ptr_i32_size)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
if ((usize_size != ptr_usize_size)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
int32_t i32_val = 10;
size_t usize_val = (size_t)20;
size_t result_usize = ((size_t)i32_val + usize_val);
if ((result_usize != (size_t)30)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
size_t result_usize2 = (usize_val - (size_t)i32_val);
if ((result_usize2 != (size_t)10)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
size_t result_usize3 = ((size_t)i32_val * usize_val);
if ((result_usize3 != (size_t)200)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
size_t usize_a = (size_t)15;
size_t usize_b = (size_t)5;
size_t result_usize4 = (usize_a + usize_b);
if ((result_usize4 != (size_t)20)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
int32_t i32_val2 = 20;
size_t usize_val2 = (size_t)20;
if (((size_t)i32_val2 != usize_val2)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
if (((size_t)i32_val2 < usize_val2)) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
if (((size_t)i32_val2 > usize_val2)) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
int32_t i32_to_convert = 123;
size_t usize_from_i32 = (size_t)i32_to_convert;
if ((usize_from_i32 != (size_t)123)) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
size_t usize_to_convert = (size_t)456;
int32_t i32_from_usize = (int32_t)usize_to_convert;
if ((i32_from_usize != 456)) {
    int32_t _uya_ret = 17;
    return _uya_ret;
}
const int32_t usize_align = uya_alignof(size_t);
if ((usize_align != usize_size)) {
    int32_t _uya_ret = 18;
    return _uya_ret;
}
const int32_t usize_var_align = uya_alignof(size_t);
if ((usize_var_align != usize_align)) {
    int32_t _uya_ret = 19;
    return _uya_ret;
}
size_t * usize_ptr = (&usize_var);
if ((usize_ptr == NULL)) {
    int32_t _uya_ret = 20;
    return _uya_ret;
}
const size_t usize_val_read = (*usize_ptr);
if ((usize_val_read != (size_t)200)) {
    int32_t _uya_ret = 21;
    return _uya_ret;
}
(*usize_ptr) = (size_t)300;
if ((usize_var != (size_t)300)) {
    int32_t _uya_ret = 22;
    return _uya_ret;
}
const int32_t usize_ptr_var_size = sizeof(usize_ptr);
if ((usize_ptr_var_size != ptr_usize_size)) {
    int32_t _uya_ret = 23;
    return _uya_ret;
}
size_t * null_usize_ptr = NULL;
if ((null_usize_ptr != NULL)) {
    int32_t _uya_ret = 24;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
