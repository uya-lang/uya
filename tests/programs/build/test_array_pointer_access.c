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
struct ASTNode;
struct CodeGen;



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

struct ASTNode {
    int32_t type;
    int32_t line;
    int32_t column;
};

struct CodeGen {
    struct ASTNode * nodes[10];
    int32_t count;
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

int32_t test_array_pointer_access(struct CodeGen * codegen);
int32_t test_extracted_pointer_vars(struct CodeGen * codegen);
int32_t test_nested_array_access(struct CodeGen * codegen);
int32_t test_pointer_assignment(struct CodeGen * codegen);
int32_t uya_main(void);

int32_t test_array_pointer_access(struct CodeGen * codegen) {
    int32_t i = 0;
    while ((i < codegen->count)) {
        if ((codegen->nodes[i]->type != 0)) {
            int32_t _uya_ret = 1;
            return _uya_ret;
        }
        if ((codegen->nodes[i]->line != 0)) {
            int32_t _uya_ret = 2;
            return _uya_ret;
        }
        if ((codegen->nodes[i]->column != 0)) {
            int32_t _uya_ret = 3;
            return _uya_ret;
        }
        i = (i + 1);
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_extracted_pointer_vars(struct CodeGen * codegen) {
    if ((codegen->nodes[0] == NULL)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    struct ASTNode * const node = codegen->nodes[0];
    if ((node->type != 0)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if ((node->line != 0)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    if ((node->column != 0)) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    struct ASTNode * const first_node = codegen->nodes[0];
    if ((first_node->type != 0)) {
        int32_t _uya_ret = 5;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_nested_array_access(struct CodeGen * codegen) {
    int32_t i = 0;
    while ((i < codegen->count)) {
        struct ASTNode * const node = codegen->nodes[i];
        if ((node->type != 0)) {
            int32_t _uya_ret = 1;
            return _uya_ret;
        }
        i = (i + 1);
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_pointer_assignment(struct CodeGen * codegen) {
    if ((codegen->nodes[0] == NULL)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    codegen->nodes[0]->type = 10;
    if ((codegen->nodes[0]->type != 10)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    codegen->nodes[0]->line = 20;
    if ((codegen->nodes[0]->line != 20)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    codegen->nodes[0]->column = 30;
    if ((codegen->nodes[0]->column != 30)) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t uya_main(void) {
struct ASTNode * nodes[10] = {0};
struct ASTNode node0 = (struct ASTNode){.type = 0, .line = 0, .column = 0};
struct ASTNode node1 = (struct ASTNode){.type = 0, .line = 0, .column = 0};
struct ASTNode node2 = (struct ASTNode){.type = 0, .line = 0, .column = 0};
nodes[0] = (&node0);
nodes[1] = (&node1);
nodes[2] = (&node2);
struct CodeGen codegen = (struct CodeGen){.nodes = {0}, .count = 3};
__uya_memcpy(codegen.nodes, nodes, sizeof(codegen.nodes));
const int32_t result1 = test_array_pointer_access((&codegen));
if ((result1 != 0)) {
    int32_t _uya_ret = result1;
    return _uya_ret;
}
const int32_t result2 = test_extracted_pointer_vars((&codegen));
if ((result2 != 0)) {
    int32_t _uya_ret = (result2 + 10);
    return _uya_ret;
}
const int32_t result3 = test_nested_array_access((&codegen));
if ((result3 != 0)) {
    int32_t _uya_ret = (result3 + 20);
    return _uya_ret;
}
const int32_t result4 = test_pointer_assignment((&codegen));
if ((result4 != 0)) {
    int32_t _uya_ret = (result4 + 30);
    return _uya_ret;
}
if ((((codegen.nodes[0]->type != 10) || (codegen.nodes[0]->line != 20)) || (codegen.nodes[0]->column != 30))) {
    int32_t _uya_ret = 40;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
