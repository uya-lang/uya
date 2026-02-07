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
static const uint8_t str0[] = "hex=";
static const uint8_t str1[] = "%#06x";
static const uint8_t str2[] = "\n";
static const uint8_t str3[] = "x=";
static const uint8_t str4[] = "%d";
static const uint8_t str5[] = ", pi=";
static const uint8_t str6[] = "%.2f";
static const uint8_t str7[] = "n=";
static const uint8_t str8[] = "";
static const uint8_t str9[] = "plain\n";
static const uint8_t str10[] = "a=";
static const uint8_t str11[] = " b=";
static const uint8_t str12[] = " end\n";
static const uint8_t str13[] = " world\n";
static const uint8_t str14[] = "w=";
static const uint8_t str15[] = "b\n";
static const uint8_t str16[] = "1=";
static const uint8_t str17[] = " 2=";
static const uint8_t str18[] = " 3=";
static const uint8_t str19[] = "\t\n";
static const uint8_t str20[] = "k=";
static const uint8_t str21[] = "%ld";
static const uint8_t str22[] = "f=";
static const uint8_t str23[] = "%.1f";
static const uint8_t str24[] = "z=";
static const uint8_t str25[] = "%zu";
static const uint8_t str26[] = "u8=";
static const uint8_t str27[] = ">";
static const uint8_t str28[] = "<\n";
static const uint8_t str29[] = "sum=";

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
const uint32_t x = 255;
const double pi = 3.1415926000000001;
const int32_t n = (-42);
const uint32_t u = 100;
int8_t msg[64];
int _off_0 = 0;
__uya_memcpy(msg + _off_0, str0, 4);
_off_0 += 4;
_off_0 += sprintf(msg + _off_0, str1, x);
__uya_memcpy(msg + _off_0, str2, 1);
_off_0 += 1;
msg[_off_0] = '\0';
printf("%s", (&msg[0]));
int8_t msg2[64];
int _off_1 = 0;
__uya_memcpy(msg2 + _off_1, str3, 2);
_off_1 += 2;
_off_1 += sprintf(msg2 + _off_1, str4, x);
__uya_memcpy(msg2 + _off_1, str5, 5);
_off_1 += 5;
_off_1 += sprintf(msg2 + _off_1, str6, pi);
__uya_memcpy(msg2 + _off_1, str2, 1);
_off_1 += 1;
msg2[_off_1] = '\0';
printf("%s", (&msg2[0]));
printf("n=%d\n", n);
int8_t only_interp[32];
int _off_2 = 0;
__uya_memcpy(only_interp + _off_2, str8, 0);
_off_2 += 0;
_off_2 += sprintf(only_interp + _off_2, str4, n);
only_interp[_off_2] = '\0';
printf("%s", (&only_interp[0]));
printf("%s", (const char *)(uint8_t *)str9);
int8_t multi[64];
int _off_3 = 0;
__uya_memcpy(multi + _off_3, str10, 2);
_off_3 += 2;
_off_3 += sprintf(multi + _off_3, str4, u);
__uya_memcpy(multi + _off_3, str11, 3);
_off_3 += 3;
_off_3 += sprintf(multi + _off_3, str4, n);
__uya_memcpy(multi + _off_3, str12, 5);
_off_3 += 5;
multi[_off_3] = '\0';
printf("%s", (&multi[0]));
int8_t simple[32];
int _off_4 = 0;
__uya_memcpy(simple + _off_4, str7, 2);
_off_4 += 2;
_off_4 += sprintf(simple + _off_4, str4, n);
__uya_memcpy(simple + _off_4, str2, 1);
_off_4 += 1;
simple[_off_4] = '\0';
printf("%s", (&simple[0]));
const int32_t v = 123;
printf("%d world\n", v);
int32_t w = 99;
printf("w=%d\n", w);
int8_t ab[64];
int _off_5 = 0;
__uya_memcpy(ab + _off_5, str10, 2);
_off_5 += 2;
_off_5 += sprintf(ab + _off_5, str4, x);
__uya_memcpy(ab + _off_5, str8, 0);
_off_5 += 0;
_off_5 += sprintf(ab + _off_5, str4, n);
__uya_memcpy(ab + _off_5, str15, 2);
_off_5 += 2;
ab[_off_5] = '\0';
printf("%s", (&ab[0]));
int8_t concat[32];
int _off_6 = 0;
__uya_memcpy(concat + _off_6, str8, 0);
_off_6 += 0;
_off_6 += sprintf(concat + _off_6, str4, x);
__uya_memcpy(concat + _off_6, str8, 0);
_off_6 += 0;
_off_6 += sprintf(concat + _off_6, str4, n);
concat[_off_6] = '\0';
printf("%s", (&concat[0]));
const int32_t a = 1;
const int32_t b = 2;
const int32_t c = 3;
int8_t three[64];
int _off_7 = 0;
__uya_memcpy(three + _off_7, str16, 2);
_off_7 += 2;
_off_7 += sprintf(three + _off_7, str4, a);
__uya_memcpy(three + _off_7, str17, 3);
_off_7 += 3;
_off_7 += sprintf(three + _off_7, str4, b);
__uya_memcpy(three + _off_7, str18, 3);
_off_7 += 3;
_off_7 += sprintf(three + _off_7, str4, c);
__uya_memcpy(three + _off_7, str2, 1);
_off_7 += 1;
three[_off_7] = '\0';
printf("%s", (&three[0]));
int8_t escaped[64];
int _off_8 = 0;
__uya_memcpy(escaped + _off_8, str2, 1);
_off_8 += 1;
_off_8 += sprintf(escaped + _off_8, str4, n);
__uya_memcpy(escaped + _off_8, str19, 2);
_off_8 += 2;
escaped[_off_8] = '\0';
printf("%s", (&escaped[0]));
const int64_t k = 999;
int8_t ki[64];
int _off_9 = 0;
__uya_memcpy(ki + _off_9, str20, 2);
_off_9 += 2;
_off_9 += sprintf(ki + _off_9, str21, k);
__uya_memcpy(ki + _off_9, str2, 1);
_off_9 += 1;
ki[_off_9] = '\0';
printf("%s", (&ki[0]));
const float f = 1.5;
printf("f=%.1f\n", f);
const size_t z = (size_t)42;
int8_t zmsg[32];
int _off_10 = 0;
__uya_memcpy(zmsg + _off_10, str24, 2);
_off_10 += 2;
_off_10 += sprintf(zmsg + _off_10, str25, z);
__uya_memcpy(zmsg + _off_10, str2, 1);
_off_10 += 1;
zmsg[_off_10] = '\0';
printf("%s", (&zmsg[0]));
const uint8_t b8 = 200;
int8_t u8msg[32];
int _off_11 = 0;
__uya_memcpy(u8msg + _off_11, str26, 3);
_off_11 += 3;
_off_11 += sprintf(u8msg + _off_11, str4, b8);
__uya_memcpy(u8msg + _off_11, str2, 1);
_off_11 += 1;
u8msg[_off_11] = '\0';
printf("%s", (&u8msg[0]));
int8_t head_tail[64];
int _off_12 = 0;
__uya_memcpy(head_tail + _off_12, str27, 1);
_off_12 += 1;
_off_12 += sprintf(head_tail + _off_12, str4, n);
__uya_memcpy(head_tail + _off_12, str28, 2);
_off_12 += 2;
head_tail[_off_12] = '\0';
printf("%s", (&head_tail[0]));
int8_t sum[32];
int _off_13 = 0;
__uya_memcpy(sum + _off_13, str29, 4);
_off_13 += 4;
_off_13 += sprintf(sum + _off_13, str4, (a + b));
__uya_memcpy(sum + _off_13, str2, 1);
_off_13 += 1;
sum[_off_13] = '\0';
printf("%s", (&sum[0]));
int32_t _uya_ret = 0;
return _uya_ret;
}
