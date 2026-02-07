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
struct Node;
struct Data;



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

struct Node {
    int32_t value;
    struct Node * next;
};

struct Data {
    int32_t x;
    int32_t y;
    struct Data * ptr;
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

struct Node * create_node(int32_t value);
int32_t uya_main(void);

struct Node * create_node(int32_t value) {
    struct Node * _uya_ret = NULL;
    return _uya_ret;
}

int32_t uya_main(void) {
int32_t * ptr_i32 = NULL;
void * ptr_void = NULL;
struct Node * ptr_node = NULL;
size_t * ptr_usize = NULL;
bool * ptr_bool = NULL;
uint8_t * ptr_byte = NULL;
if (((((((ptr_i32 != NULL) || (ptr_void != NULL)) || (ptr_node != NULL)) || (ptr_usize != NULL)) || (ptr_bool != NULL)) || (ptr_byte != NULL))) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
int32_t x = 42;
int32_t * ptr = (&x);
if ((ptr == NULL)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
ptr = NULL;
if ((ptr != NULL)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
int32_t * ptr1 = NULL;
int32_t * ptr2 = NULL;
if ((ptr1 != ptr2)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
if ((ptr1 != NULL)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
int32_t y = 10;
int32_t * ptr3 = (&y);
if ((ptr3 == NULL)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
int32_t * ptr4 = NULL;
if ((ptr4 != NULL)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
int32_t * ptr5 = NULL;
if ((ptr5 != NULL)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
int32_t z = 20;
int32_t * ptr6 = (&z);
if ((ptr6 == NULL)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
struct Node * node_ptr = NULL;
if ((node_ptr != NULL)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
struct Data * data_ptr = NULL;
if ((data_ptr != NULL)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
void * void_ptr = NULL;
if ((void_ptr != NULL)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
int32_t w = 30;
int32_t * i32_ptr = (&w);
void_ptr = (void *)i32_ptr;
if ((void_ptr == NULL)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
void_ptr = NULL;
if ((void_ptr != NULL)) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
int32_t * ptr7 = NULL;
int32_t count = 0;
while (((ptr7 == NULL) && (count < 5))) {
    count = (count + 1);
}
if ((count != 5)) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
const int32_t ptr_type_size = sizeof(int32_t *);
if ((ptr_type_size <= 0)) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
int32_t * null1 = NULL;
int32_t * null2 = NULL;
struct Node * null3 = NULL;
if ((null1 != null2)) {
    int32_t _uya_ret = 17;
    return _uya_ret;
}
int32_t * ptr_a = NULL;
int32_t * ptr_b = NULL;
int32_t * ptr_c = NULL;
ptr_a = NULL;
ptr_b = ptr_a;
ptr_c = ptr_b;
if ((((ptr_a != NULL) || (ptr_b != NULL)) || (ptr_c != NULL))) {
    int32_t _uya_ret = 18;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
