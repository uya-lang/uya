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

void set_hello(uint8_t * buf);
void set_world(uint8_t * buf);
void set_hell(uint8_t * buf);
int32_t test_strlen();
int32_t test_memcpy();
int32_t test_memset();
int32_t test_memcmp();
int32_t test_strcmp();
int32_t test_strcpy();
int32_t test_strncmp();
int32_t test_memchr();
int32_t uya_main(void);
uint8_t * memcpy(uint8_t * dest, uint8_t * src, size_t n);
uint8_t * memmove(uint8_t * dest, uint8_t * src, size_t n);
uint8_t * memset(uint8_t * s, uint8_t c, size_t n);
int32_t memcmp(uint8_t * s1, uint8_t * s2, size_t n);
int64_t memchr(uint8_t * s, uint8_t c, size_t n);
size_t strlen(uint8_t * s);
int32_t strcmp(uint8_t * s1, uint8_t * s2);
int32_t strncmp(uint8_t * s1, uint8_t * s2, size_t n);
uint8_t * strcpy(uint8_t * dest, uint8_t * src);
uint8_t * strncpy(uint8_t * dest, uint8_t * src, size_t n);
uint8_t * strcat(uint8_t * dest, uint8_t * src);
int64_t strchr(uint8_t * s, uint8_t c);
int64_t strrchr(uint8_t * s, uint8_t c);

void set_hello(uint8_t * buf) {
    buf[0] = (uint8_t)72;
    buf[1] = (uint8_t)101;
    buf[2] = (uint8_t)108;
    buf[3] = (uint8_t)108;
    buf[4] = (uint8_t)111;
    buf[5] = (uint8_t)0;
}

void set_world(uint8_t * buf) {
    buf[0] = (uint8_t)87;
    buf[1] = (uint8_t)111;
    buf[2] = (uint8_t)114;
    buf[3] = (uint8_t)108;
    buf[4] = (uint8_t)100;
    buf[5] = (uint8_t)0;
}

void set_hell(uint8_t * buf) {
    buf[0] = (uint8_t)72;
    buf[1] = (uint8_t)101;
    buf[2] = (uint8_t)108;
    buf[3] = (uint8_t)108;
    buf[4] = (uint8_t)0;
}

int32_t test_strlen() {
uint8_t hello[10] = {0};
    set_hello((uint8_t *)(&hello[0]));
    const size_t len1 = strlen((uint8_t *)(&hello[0]));
    if ((len1 != 5)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
uint8_t empty[4] = {0};
    empty[0] = (uint8_t)0;
    const size_t len2 = strlen((uint8_t *)(&empty[0]));
    if ((len2 != 0)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
uint8_t single[4] = {0};
    single[0] = (uint8_t)65;
    single[1] = (uint8_t)0;
    const size_t len3 = strlen((uint8_t *)(&single[0]));
    if ((len3 != 1)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_memcpy() {
uint8_t src[10] = {0};
    set_hello((uint8_t *)(&src[0]));
uint8_t dest[10] = {0};
    (void)(memcpy((uint8_t *)(&dest[0]), (uint8_t *)(&src[0]), 6));
    if ((dest[0] != (uint8_t)72)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if ((dest[4] != (uint8_t)111)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if ((dest[5] != (uint8_t)0)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
uint8_t partial[10] = {0};
    (void)(memcpy((uint8_t *)(&partial[0]), (uint8_t *)(&src[0]), 3));
    if ((partial[0] != (uint8_t)72)) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    if ((partial[2] != (uint8_t)108)) {
        int32_t _uya_ret = 5;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_memset() {
uint8_t buf[10] = {0};
    (void)(memset((uint8_t *)(&buf[0]), (uint8_t)65, 5));
    if ((buf[0] != (uint8_t)65)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if ((buf[4] != (uint8_t)65)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if ((buf[5] != (uint8_t)0)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
uint8_t buf2[10] = {0};
    buf2[0] = (uint8_t)100;
    buf2[1] = (uint8_t)100;
    (void)(memset((uint8_t *)(&buf2[0]), (uint8_t)0, 5));
    if ((buf2[0] != (uint8_t)0)) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    if ((buf2[4] != (uint8_t)0)) {
        int32_t _uya_ret = 5;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_memcmp() {
uint8_t a[10] = {0};
uint8_t b[10] = {0};
    set_hello((uint8_t *)(&a[0]));
    set_hello((uint8_t *)(&b[0]));
    const int32_t cmp1 = memcmp((uint8_t *)(&a[0]), (uint8_t *)(&b[0]), 5);
    if ((cmp1 != 0)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    set_hello((uint8_t *)(&a[0]));
    set_world((uint8_t *)(&b[0]));
    const int32_t cmp2 = memcmp((uint8_t *)(&a[0]), (uint8_t *)(&b[0]), 1);
    if ((cmp2 >= 0)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    const int32_t cmp3 = memcmp((uint8_t *)(&b[0]), (uint8_t *)(&a[0]), 1);
    if ((cmp3 <= 0)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_strcmp() {
uint8_t a[10] = {0};
uint8_t b[10] = {0};
    set_hello((uint8_t *)(&a[0]));
    set_hello((uint8_t *)(&b[0]));
    const int32_t cmp1 = strcmp((uint8_t *)(&a[0]), (uint8_t *)(&b[0]));
    if ((cmp1 != 0)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    set_hello((uint8_t *)(&a[0]));
    set_world((uint8_t *)(&b[0]));
    const int32_t cmp2 = strcmp((uint8_t *)(&a[0]), (uint8_t *)(&b[0]));
    if ((cmp2 >= 0)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    set_hello((uint8_t *)(&a[0]));
    set_hell((uint8_t *)(&b[0]));
    const int32_t cmp3 = strcmp((uint8_t *)(&a[0]), (uint8_t *)(&b[0]));
    if ((cmp3 <= 0)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_strcpy() {
uint8_t src[10] = {0};
    set_hello((uint8_t *)(&src[0]));
uint8_t dest[10] = {0};
    (void)(strcpy((uint8_t *)(&dest[0]), (uint8_t *)(&src[0])));
    const size_t len = strlen((uint8_t *)(&dest[0]));
    if ((len != 5)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if ((dest[0] != (uint8_t)72)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if ((dest[4] != (uint8_t)111)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    if ((dest[5] != (uint8_t)0)) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_strncmp() {
uint8_t a[10] = {0};
uint8_t b[10] = {0};
    set_hello((uint8_t *)(&a[0]));
    set_hell((uint8_t *)(&b[0]));
    const int32_t cmp1 = strncmp((uint8_t *)(&a[0]), (uint8_t *)(&b[0]), 4);
    if ((cmp1 != 0)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    set_hello((uint8_t *)(&a[0]));
    set_world((uint8_t *)(&b[0]));
    const int32_t cmp2 = strncmp((uint8_t *)(&a[0]), (uint8_t *)(&b[0]), 3);
    if ((cmp2 >= 0)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_memchr() {
uint8_t buf[10] = {0};
    set_hello((uint8_t *)(&buf[0]));
    const int64_t pos1 = memchr((uint8_t *)(&buf[0]), (uint8_t)108, 5);
    if ((pos1 != 2)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    const int64_t pos2 = memchr((uint8_t *)(&buf[0]), (uint8_t)120, 5);
    if ((pos2 != (0 - 1))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    const int64_t pos3 = memchr((uint8_t *)(&buf[0]), (uint8_t)72, 5);
    if ((pos3 != 0)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

uint8_t * memcpy(uint8_t * dest, uint8_t * src, size_t n) {
    size_t i = 0;
    while ((i < n)) {
        dest[i] = src[i];
        i = (i + 1);
    }
    uint8_t * _uya_ret = dest;
    return _uya_ret;
}

uint8_t * memmove(uint8_t * dest, uint8_t * src, size_t n) {
    if (((int64_t)dest <= (int64_t)src)) {
        size_t i = 0;
        while ((i < n)) {
            dest[i] = src[i];
            i = (i + 1);
        }
    } else {
        size_t i = n;
        while ((i > 0)) {
            i = (i - 1);
            dest[i] = src[i];
        }
    }
    uint8_t * _uya_ret = dest;
    return _uya_ret;
}

uint8_t * memset(uint8_t * s, uint8_t c, size_t n) {
    size_t i = 0;
    while ((i < n)) {
        s[i] = c;
        i = (i + 1);
    }
    uint8_t * _uya_ret = s;
    return _uya_ret;
}

int32_t memcmp(uint8_t * s1, uint8_t * s2, size_t n) {
    size_t i = 0;
    while ((i < n)) {
        if ((s1[i] != s2[i])) {
            int32_t _uya_ret = ((int32_t)s1[i] - (int32_t)s2[i]);
            return _uya_ret;
        }
        i = (i + 1);
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int64_t memchr(uint8_t * s, uint8_t c, size_t n) {
    size_t i = 0;
    while ((i < n)) {
        if ((s[i] == c)) {
            int64_t _uya_ret = (int64_t)i;
            return _uya_ret;
        }
        i = (i + 1);
    }
    int64_t _uya_ret = (0 - 1);
    return _uya_ret;
}

size_t strlen(uint8_t * s) {
    size_t len = 0;
    while ((s[len] != (uint8_t)0)) {
        len = (len + 1);
    }
    size_t _uya_ret = len;
    return _uya_ret;
}

int32_t strcmp(uint8_t * s1, uint8_t * s2) {
    size_t i = 0;
    while (((s1[i] != (uint8_t)0) && (s2[i] != (uint8_t)0))) {
        if ((s1[i] != s2[i])) {
            int32_t _uya_ret = ((int32_t)s1[i] - (int32_t)s2[i]);
            return _uya_ret;
        }
        i = (i + 1);
    }
    int32_t _uya_ret = ((int32_t)s1[i] - (int32_t)s2[i]);
    return _uya_ret;
}

int32_t strncmp(uint8_t * s1, uint8_t * s2, size_t n) {
    size_t i = 0;
    while ((((i < n) && (s1[i] != (uint8_t)0)) && (s2[i] != (uint8_t)0))) {
        if ((s1[i] != s2[i])) {
            int32_t _uya_ret = ((int32_t)s1[i] - (int32_t)s2[i]);
            return _uya_ret;
        }
        i = (i + 1);
    }
    if ((i >= n)) {
        int32_t _uya_ret = 0;
        return _uya_ret;
    }
    int32_t _uya_ret = ((int32_t)s1[i] - (int32_t)s2[i]);
    return _uya_ret;
}

uint8_t * strcpy(uint8_t * dest, uint8_t * src) {
    size_t i = 0;
    while ((src[i] != (uint8_t)0)) {
        dest[i] = src[i];
        i = (i + 1);
    }
    dest[i] = (uint8_t)0;
    uint8_t * _uya_ret = dest;
    return _uya_ret;
}

uint8_t * strncpy(uint8_t * dest, uint8_t * src, size_t n) {
    size_t i = 0;
    while (((i < n) && (src[i] != (uint8_t)0))) {
        dest[i] = src[i];
        i = (i + 1);
    }
    while ((i < n)) {
        dest[i] = (uint8_t)0;
        i = (i + 1);
    }
    uint8_t * _uya_ret = dest;
    return _uya_ret;
}

uint8_t * strcat(uint8_t * dest, uint8_t * src) {
    size_t dest_len = strlen((uint8_t *)dest);
    size_t i = 0;
    while ((src[i] != (uint8_t)0)) {
        dest[(dest_len + i)] = src[i];
        i = (i + 1);
    }
    dest[(dest_len + i)] = (uint8_t)0;
    uint8_t * _uya_ret = dest;
    return _uya_ret;
}

int64_t strchr(uint8_t * s, uint8_t c) {
    size_t i = 0;
    while ((s[i] != (uint8_t)0)) {
        if ((s[i] == c)) {
            int64_t _uya_ret = (int64_t)i;
            return _uya_ret;
        }
        i = (i + 1);
    }
    if ((c == (uint8_t)0)) {
        int64_t _uya_ret = (int64_t)i;
        return _uya_ret;
    }
    int64_t _uya_ret = (0 - 1);
    return _uya_ret;
}

int64_t strrchr(uint8_t * s, uint8_t c) {
    int64_t last = (0 - 1);
    size_t i = 0;
    while ((s[i] != (uint8_t)0)) {
        if ((s[i] == c)) {
            last = (int64_t)i;
        }
        i = (i + 1);
    }
    if ((c == (uint8_t)0)) {
        int64_t _uya_ret = (int64_t)i;
        return _uya_ret;
    }
    int64_t _uya_ret = last;
    return _uya_ret;
}

int32_t uya_main(void) {
int32_t result = 0;
result = test_strlen();
if ((result != 0)) {
    int32_t _uya_ret = result;
    return _uya_ret;
}
result = test_memcpy();
if ((result != 0)) {
    int32_t _uya_ret = (result + 10);
    return _uya_ret;
}
result = test_memset();
if ((result != 0)) {
    int32_t _uya_ret = (result + 20);
    return _uya_ret;
}
result = test_memcmp();
if ((result != 0)) {
    int32_t _uya_ret = (result + 30);
    return _uya_ret;
}
result = test_strcmp();
if ((result != 0)) {
    int32_t _uya_ret = (result + 40);
    return _uya_ret;
}
result = test_strcpy();
if ((result != 0)) {
    int32_t _uya_ret = (result + 50);
    return _uya_ret;
}
result = test_strncmp();
if ((result != 0)) {
    int32_t _uya_ret = (result + 60);
    return _uya_ret;
}
result = test_memchr();
if ((result != 0)) {
    int32_t _uya_ret = (result + 70);
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
