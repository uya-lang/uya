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

enum Color {
    RED,
    GREEN,
    BLUE
};

enum Status {
    PENDING = 1,
    RUNNING = 2,
    COMPLETED = 3
};

enum Priority {
    LOW = 10,
    MEDIUM = 20,
    HIGH = 30
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

enum Color get_red();
enum Color get_green();
enum Color get_blue();
enum Status get_status_by_value(int32_t value);
enum Priority get_priority_by_level(int32_t level);
enum Color get_default_color();
bool check_color_match(enum Color c);
int32_t uya_main(void);

enum Color get_red() {
    enum Color _uya_ret = RED;
    return _uya_ret;
}

enum Color get_green() {
    enum Color _uya_ret = GREEN;
    return _uya_ret;
}

enum Color get_blue() {
    enum Color _uya_ret = BLUE;
    return _uya_ret;
}

enum Status get_status_by_value(int32_t value) {
    if ((value == 1)) {
        enum Status _uya_ret = PENDING;
        return _uya_ret;
    } else {
        if ((value == 2)) {
            enum Status _uya_ret = RUNNING;
            return _uya_ret;
        } else {
            enum Status _uya_ret = COMPLETED;
            return _uya_ret;
        }
    }
}

enum Priority get_priority_by_level(int32_t level) {
    if ((level < 15)) {
        enum Priority _uya_ret = LOW;
        return _uya_ret;
    } else {
        if ((level < 25)) {
            enum Priority _uya_ret = MEDIUM;
            return _uya_ret;
        } else {
            enum Priority _uya_ret = HIGH;
            return _uya_ret;
        }
    }
}

enum Color get_default_color() {
    enum Color _uya_ret = get_red();
    return _uya_ret;
}

bool check_color_match(enum Color c) {
    bool _uya_ret = (c == RED);
    return _uya_ret;
}

int32_t uya_main(void) {
const enum Color c1 = get_red();
if ((c1 != RED)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const enum Color c2 = get_green();
if ((c2 != GREEN)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
const enum Color c3 = get_blue();
if ((c3 != BLUE)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
if ((get_red() != RED)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
if ((get_green() != GREEN)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
if ((get_blue() != BLUE)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
const enum Status s1 = get_status_by_value(1);
if ((s1 != PENDING)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
const enum Status s2 = get_status_by_value(2);
if ((s2 != RUNNING)) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
const enum Status s3 = get_status_by_value(3);
if ((s3 != COMPLETED)) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
const enum Priority p1 = get_priority_by_level(10);
if ((p1 != LOW)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
const enum Priority p2 = get_priority_by_level(20);
if ((p2 != MEDIUM)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
const enum Priority p3 = get_priority_by_level(30);
if ((p3 != HIGH)) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
const enum Color c4 = get_default_color();
if ((c4 != RED)) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
if ((!check_color_match(RED))) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
if (check_color_match(GREEN)) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
if ((get_red() == RED)) {
} else {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
enum Color color = get_red();
if ((color != RED)) {
    int32_t _uya_ret = 17;
    return _uya_ret;
}
color = get_green();
if ((color != GREEN)) {
    int32_t _uya_ret = 18;
    return _uya_ret;
}
color = get_blue();
if ((color != BLUE)) {
    int32_t _uya_ret = 19;
    return _uya_ret;
}
const enum Status status = get_status_by_value(2);
if ((status == RUNNING)) {
} else {
    int32_t _uya_ret = 20;
    return _uya_ret;
}
const enum Priority priority = get_priority_by_level(25);
if (((priority == HIGH) && (priority != LOW))) {
} else {
    int32_t _uya_ret = 21;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
