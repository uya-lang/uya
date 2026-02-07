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
struct Buffer;


struct uya_interface_IReader { void *vtable; void *data; };
struct uya_vtable_IReader {
    int32_t (*read)(void *self);
};
struct uya_interface_IWriter { void *vtable; void *data; };
struct uya_vtable_IWriter {
    void (*write)(void *self, int32_t);
};
struct uya_interface_IReadWriter { void *vtable; void *data; };
struct uya_vtable_IReadWriter {
    int32_t (*read)(void *self);
    void (*write)(void *self, int32_t);
    int32_t (*flush)(void *self);
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

struct Buffer {
    int32_t data;
    int32_t flushed;
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

int32_t uya_Buffer_read(const struct Buffer * self);
void uya_Buffer_write(const struct Buffer * self, int32_t value);
int32_t uya_Buffer_flush(const struct Buffer * self);
int32_t test_read_writer(struct uya_interface_IReadWriter rw);
int32_t uya_main(void);
static const struct uya_vtable_IReadWriter uya_vtable_IReadWriter_Buffer = { (int32_t (*)(void *self))&uya_Buffer_read, (void (*)(void *self, int32_t))&uya_Buffer_write, (int32_t (*)(void *self))&uya_Buffer_flush };

int32_t uya_Buffer_read(const struct Buffer * self) {
    int32_t _uya_ret = self->data;
    return _uya_ret;
}

void uya_Buffer_write(const struct Buffer * self, int32_t value) {
}

int32_t uya_Buffer_flush(const struct Buffer * self) {
    int32_t _uya_ret = self->flushed;
    return _uya_ret;
}

int32_t test_read_writer(struct uya_interface_IReadWriter rw) {
    const int32_t val = ((struct uya_vtable_IReadWriter *)(rw).vtable)->read((rw).data);
    ((struct uya_vtable_IReadWriter *)(rw).vtable)->write((rw).data, 100);
    const int32_t f = ((struct uya_vtable_IReadWriter *)(rw).vtable)->flush((rw).data);
    int32_t _uya_ret = (val + f);
    return _uya_ret;
}

int32_t uya_main(void) {
struct Buffer buf = (struct Buffer){.data = 42, .flushed = 10};
const int32_t result1 = test_read_writer((struct uya_interface_IReadWriter){ .vtable = (void*)&uya_vtable_IReadWriter_Buffer, .data = (void*)&(buf) });
if ((result1 != 52)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
