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
static const uint8_t str0[] = "hello";
static const uint8_t str1[] = "i32";
static const uint8_t str2[] = "f64";

struct TypeInfo;
struct Point;
struct Box_i32;
struct Box_Box_i32;
struct Pair_i32_i32;
struct Pair_ptr_byte_i32;
struct TypeInfo;

typedef int32_t Int;
typedef uint8_t Byte;
typedef double Float;
typedef int32_t * IntPtr;
typedef int32_t IntArray[4];
typedef struct Point Pt;
typedef Int MyInt;
typedef Byte MyByte;
typedef struct Box_i32 IntBox;
typedef struct Box_ptr_byte StringBox;
typedef struct Pair_i32_i32 IntPair;
typedef struct Pair_ptr_byte_i32 StrIntPair;
typedef struct Box_Box_i32 BoxOfBox;
typedef struct TypeInfo TI;


struct Point {
    int32_t x;
    int32_t y;
};

struct Box_i32 {
    int32_t value;
};


struct Box_Box_i32 {
    struct Box_i32 value;
};

struct Pair_i32_i32 {
    int32_t key;
    int32_t val;
};

struct Pair_ptr_byte_i32 {
    uint8_t * key;
    int32_t val;
};

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
Int a = 42;
Byte b = 255;
Float c = 3.1400000000000001;
int32_t x = 100;
IntPtr ptr = (&x);
IntArray arr = {1, 2, 3, 4};
Pt p = (struct Point){.x = 10, .y = 20};
MyInt m = 50;
MyByte n = 128;
if ((a != 42)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
if ((b != 255)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
if (((*ptr) != 100)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
if ((arr[0] != 1)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
if ((p.x != 10)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
if ((m != 50)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
IntBox ibox = (struct Box_i32){.value = 123};
if ((ibox.value != 123)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
IntPair ipair = (struct Pair_i32_i32){.key = 1, .val = 2};
if ((ipair.key != 1)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
if ((ipair.val != 2)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
StrIntPair spair = (struct Pair_ptr_byte_i32){.key = (uint8_t *)str0, .val = 42};
if ((spair.val != 42)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
struct Box_i32 inner = (struct Box_i32){.value = 999};
BoxOfBox bbox = (struct Box_Box_i32){.value = inner};
if ((bbox.value.value != 999)) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
const TI ti = (struct TypeInfo){.name = (int8_t *)(uint8_t *)str1, .size = 4, .align = 4, .kind = 1, .is_integer = true, .is_float = false, .is_bool = false, .is_pointer = false, .is_array = false, .is_void = false};
if ((ti.size != 4)) {
    int32_t _uya_ret = 20;
    return _uya_ret;
}
if ((!ti.is_integer)) {
    int32_t _uya_ret = 21;
    return _uya_ret;
}
const TI f64_info = (struct TypeInfo){.name = (int8_t *)(uint8_t *)str2, .size = 8, .align = 8, .kind = 2, .is_integer = false, .is_float = true, .is_bool = false, .is_pointer = false, .is_array = false, .is_void = false};
if ((f64_info.size != 8)) {
    int32_t _uya_ret = 22;
    return _uya_ret;
}
if ((!f64_info.is_float)) {
    int32_t _uya_ret = 23;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
