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

int32_t test_i32_to_str();
int32_t test_put_char();
int32_t test_write_bytes();
int32_t uya_main(void);
int32_t put_char(int32_t c);
int32_t put_char_fd(int32_t c, int64_t fd);
int64_t write_bytes(uint8_t * buf, size_t n);
int64_t write_bytes_fd(uint8_t * buf, size_t n, int64_t fd);
int32_t put_str_len(uint8_t * s, size_t len);
int32_t get_char();
int64_t read_bytes(uint8_t * buf, size_t n);
int64_t read_bytes_fd(uint8_t * buf, size_t n, int64_t fd);
size_t i32_to_str(int32_t value, uint8_t * buf);
size_t i64_to_str(int64_t value, uint8_t * buf);
size_t print_i32(int32_t value);
size_t print_i64(int64_t value);

int32_t test_i32_to_str() {
uint8_t buf[16] = {0};
    const size_t len1 = i32_to_str(42, (uint8_t *)(&buf[0]));
    if ((len1 != 2)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if ((buf[0] != (uint8_t)52)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if ((buf[1] != (uint8_t)50)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    const size_t len2 = i32_to_str(0, (uint8_t *)(&buf[0]));
    if ((len2 != 1)) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    if ((buf[0] != (uint8_t)48)) {
        int32_t _uya_ret = 5;
        return _uya_ret;
    }
    const size_t len3 = i32_to_str((0 - 123), (uint8_t *)(&buf[0]));
    if ((len3 != 4)) {
        int32_t _uya_ret = 6;
        return _uya_ret;
    }
    if ((buf[0] != (uint8_t)45)) {
        int32_t _uya_ret = 7;
        return _uya_ret;
    }
    if ((buf[1] != (uint8_t)49)) {
        int32_t _uya_ret = 8;
        return _uya_ret;
    }
    if ((buf[2] != (uint8_t)50)) {
        int32_t _uya_ret = 9;
        return _uya_ret;
    }
    if ((buf[3] != (uint8_t)51)) {
        int32_t _uya_ret = 10;
        return _uya_ret;
    }
    const size_t len4 = i32_to_str(12345, (uint8_t *)(&buf[0]));
    if ((len4 != 5)) {
        int32_t _uya_ret = 11;
        return _uya_ret;
    }
    if ((buf[0] != (uint8_t)49)) {
        int32_t _uya_ret = 12;
        return _uya_ret;
    }
    if ((buf[4] != (uint8_t)53)) {
        int32_t _uya_ret = 13;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_put_char() {
    const int32_t result = put_char(65);
    if ((result != 65)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    const int32_t result2 = put_char(10);
    if ((result2 != 10)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_write_bytes() {
uint8_t msg[4] = {0};
    msg[0] = (uint8_t)79;
    msg[1] = (uint8_t)75;
    msg[2] = (uint8_t)10;
    const int64_t written = write_bytes((uint8_t *)(&msg[0]), 3);
    if ((written != 3)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

const int64_t SYS_write = 1;

const int64_t SYS_read = 0;

const int64_t STDIN = 0;

const int64_t STDOUT = 1;

const int64_t STDERR = 2;

int32_t put_char(int32_t c) {
    uint8_t ch = (uint8_t)c;
    struct err_union_int64_t result = ({ long _uya_syscall_ret = uya_syscall3(SYS_write, STDOUT, (int64_t)(&ch), 1); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    const int64_t written = ({ int32_t _uya_catch_result; struct err_union_int64_t _uya_catch_tmp = result; if (_uya_catch_tmp.error_id != 0) {
        int32_t _uya_ret = (0 - 1);
        return _uya_ret;
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
    if ((written == 1)) {
        int32_t _uya_ret = c;
        return _uya_ret;
    }
    int32_t _uya_ret = (0 - 1);
    return _uya_ret;
}

int32_t put_char_fd(int32_t c, int64_t fd) {
    uint8_t ch = (uint8_t)c;
    struct err_union_int64_t result = ({ long _uya_syscall_ret = uya_syscall3(SYS_write, fd, (int64_t)(&ch), 1); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    const int64_t written = ({ int32_t _uya_catch_result; struct err_union_int64_t _uya_catch_tmp = result; if (_uya_catch_tmp.error_id != 0) {
        int32_t _uya_ret = (0 - 1);
        return _uya_ret;
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
    if ((written == 1)) {
        int32_t _uya_ret = c;
        return _uya_ret;
    }
    int32_t _uya_ret = (0 - 1);
    return _uya_ret;
}

int64_t write_bytes(uint8_t * buf, size_t n) {
    struct err_union_int64_t result = ({ long _uya_syscall_ret = uya_syscall3(SYS_write, STDOUT, (int64_t)buf, (int64_t)n); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    const int64_t written = ({ int32_t _uya_catch_result; struct err_union_int64_t _uya_catch_tmp = result; if (_uya_catch_tmp.error_id != 0) {
        int64_t _uya_ret = (0 - 1);
        return _uya_ret;
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
    int64_t _uya_ret = written;
    return _uya_ret;
}

int64_t write_bytes_fd(uint8_t * buf, size_t n, int64_t fd) {
    struct err_union_int64_t result = ({ long _uya_syscall_ret = uya_syscall3(SYS_write, fd, (int64_t)buf, (int64_t)n); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    const int64_t written = ({ int32_t _uya_catch_result; struct err_union_int64_t _uya_catch_tmp = result; if (_uya_catch_tmp.error_id != 0) {
        int64_t _uya_ret = (0 - 1);
        return _uya_ret;
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
    int64_t _uya_ret = written;
    return _uya_ret;
}

int32_t put_str_len(uint8_t * s, size_t len) {
    struct err_union_int64_t result = ({ long _uya_syscall_ret = uya_syscall3(SYS_write, STDOUT, (int64_t)s, (int64_t)len); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    (void)(({ int32_t _uya_catch_result; struct err_union_int64_t _uya_catch_tmp = result; if (_uya_catch_tmp.error_id != 0) {
        int32_t _uya_ret = (0 - 1);
        return _uya_ret;
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; }));
    uint8_t newline = (uint8_t)10;
    struct err_union_int64_t nl_result = ({ long _uya_syscall_ret = uya_syscall3(SYS_write, STDOUT, (int64_t)(&newline), 1); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    (void)(({ int32_t _uya_catch_result; struct err_union_int64_t _uya_catch_tmp = nl_result; if (_uya_catch_tmp.error_id != 0) {
        int32_t _uya_ret = (0 - 1);
        return _uya_ret;
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; }));
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t get_char() {
    uint8_t ch = (uint8_t)0;
    struct err_union_int64_t result = ({ long _uya_syscall_ret = uya_syscall3(SYS_read, STDIN, (int64_t)(&ch), 1); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    const int64_t bytes_read = ({ int32_t _uya_catch_result; struct err_union_int64_t _uya_catch_tmp = result; if (_uya_catch_tmp.error_id != 0) {
        int32_t _uya_ret = (0 - 1);
        return _uya_ret;
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
    if ((bytes_read == 1)) {
        int32_t _uya_ret = (int32_t)ch;
        return _uya_ret;
    }
    int32_t _uya_ret = (0 - 1);
    return _uya_ret;
}

int64_t read_bytes(uint8_t * buf, size_t n) {
    struct err_union_int64_t result = ({ long _uya_syscall_ret = uya_syscall3(SYS_read, STDIN, (int64_t)buf, (int64_t)n); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    const int64_t bytes_read = ({ int32_t _uya_catch_result; struct err_union_int64_t _uya_catch_tmp = result; if (_uya_catch_tmp.error_id != 0) {
        int64_t _uya_ret = (0 - 1);
        return _uya_ret;
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
    int64_t _uya_ret = bytes_read;
    return _uya_ret;
}

int64_t read_bytes_fd(uint8_t * buf, size_t n, int64_t fd) {
    struct err_union_int64_t result = ({ long _uya_syscall_ret = uya_syscall3(SYS_read, fd, (int64_t)buf, (int64_t)n); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    const int64_t bytes_read = ({ int32_t _uya_catch_result; struct err_union_int64_t _uya_catch_tmp = result; if (_uya_catch_tmp.error_id != 0) {
        int64_t _uya_ret = (0 - 1);
        return _uya_ret;
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
    int64_t _uya_ret = bytes_read;
    return _uya_ret;
}

size_t i32_to_str(int32_t value, uint8_t * buf) {
    int32_t v = value;
    size_t len = 0;
    bool is_neg = false;
    if ((v < 0)) {
        is_neg = true;
        v = (0 - v);
    }
    if ((v == 0)) {
        buf[0] = (uint8_t)48;
        size_t _uya_ret = 1;
        return _uya_ret;
    }
    while ((v > 0)) {
        buf[len] = (uint8_t)((v % 10) + 48);
        v = (v / 10);
        len = (len + 1);
    }
    if (is_neg) {
        buf[len] = (uint8_t)45;
        len = (len + 1);
    }
    size_t left = 0;
    size_t right = (len - 1);
    while ((left < right)) {
        const uint8_t tmp = buf[left];
        buf[left] = buf[right];
        buf[right] = tmp;
        left = (left + 1);
        right = (right - 1);
    }
    size_t _uya_ret = len;
    return _uya_ret;
}

size_t i64_to_str(int64_t value, uint8_t * buf) {
    int64_t v = value;
    size_t len = 0;
    bool is_neg = false;
    if ((v < 0)) {
        is_neg = true;
        v = (0 - v);
    }
    if ((v == 0)) {
        buf[0] = (uint8_t)48;
        size_t _uya_ret = 1;
        return _uya_ret;
    }
    while ((v > 0)) {
        buf[len] = (uint8_t)((v % 10) + 48);
        v = (v / 10);
        len = (len + 1);
    }
    if (is_neg) {
        buf[len] = (uint8_t)45;
        len = (len + 1);
    }
    size_t left = 0;
    size_t right = (len - 1);
    while ((left < right)) {
        const uint8_t tmp = buf[left];
        buf[left] = buf[right];
        buf[right] = tmp;
        left = (left + 1);
        right = (right - 1);
    }
    size_t _uya_ret = len;
    return _uya_ret;
}

size_t print_i32(int32_t value) {
uint8_t buf[12] = {0};
    const size_t len = i32_to_str(value, (uint8_t *)(&buf[0]));
    (void)(write_bytes((uint8_t *)(&buf[0]), len));
    size_t _uya_ret = len;
    return _uya_ret;
}

size_t print_i64(int64_t value) {
uint8_t buf[21] = {0};
    const size_t len = i64_to_str(value, (uint8_t *)(&buf[0]));
    (void)(write_bytes((uint8_t *)(&buf[0]), len));
    size_t _uya_ret = len;
    return _uya_ret;
}

int32_t uya_main(void) {
int32_t result = 0;
result = test_i32_to_str();
if ((result != 0)) {
    int32_t _uya_ret = result;
    return _uya_ret;
}
result = test_put_char();
if ((result != 0)) {
    int32_t _uya_ret = (result + 20);
    return _uya_ret;
}
result = test_write_bytes();
if ((result != 0)) {
    int32_t _uya_ret = (result + 30);
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
