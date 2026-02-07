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
static const uint8_t str0[] = "Hello from syscall wrappers!\n";
static const uint8_t str1[] = "/tmp/test_file.txt";
static const uint8_t str2[] = "Writing via syscall!\n";

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
struct err_union_int64_t sys_write(int64_t fd, int64_t buf, int64_t count);
struct err_union_int64_t sys_read(int64_t fd, int64_t buf, int64_t count);
struct err_union_int64_t sys_open(int64_t path, int64_t flags, int64_t mode);
struct err_union_int64_t sys_close(int64_t fd);
void sys_exit(int64_t status);
int64_t sys_getpid();
struct err_union_int64_t sys_lseek(int64_t fd, int64_t offset, int64_t whence);
struct err_union_int64_t sys_access(int64_t path, int64_t mode);
struct err_union_int64_t sys_unlink(int64_t path);
struct err_union_int64_t sys_mkdir(int64_t path, int64_t mode);
struct err_union_int64_t sys_rmdir(int64_t path);
struct err_union_int64_t sys_chdir(int64_t path);
struct err_union_int64_t sys_getcwd(int64_t buf, int64_t size);

const int64_t SYS_read = 0;

const int64_t SYS_write = 1;

const int64_t SYS_open = 2;

const int64_t SYS_close = 3;

const int64_t SYS_stat = 4;

const int64_t SYS_fstat = 5;

const int64_t SYS_lseek = 8;

const int64_t SYS_mmap = 9;

const int64_t SYS_munmap = 11;

const int64_t SYS_brk = 12;

const int64_t SYS_ioctl = 16;

const int64_t SYS_access = 21;

const int64_t SYS_dup = 32;

const int64_t SYS_dup2 = 33;

const int64_t SYS_getpid = 39;

const int64_t SYS_fork = 57;

const int64_t SYS_execve = 59;

const int64_t SYS_exit = 60;

const int64_t SYS_kill = 62;

const int64_t SYS_getcwd = 79;

const int64_t SYS_chdir = 80;

const int64_t SYS_mkdir = 83;

const int64_t SYS_rmdir = 84;

const int64_t SYS_unlink = 87;

const int64_t O_RDONLY = 0;

const int64_t O_WRONLY = 1;

const int64_t O_RDWR = 2;

const int64_t O_CREAT = 64;

const int64_t O_EXCL = 128;

const int64_t O_TRUNC = 512;

const int64_t O_APPEND = 1024;

const int64_t S_IRWXU = 448;

const int64_t S_IRUSR = 256;

const int64_t S_IWUSR = 128;

const int64_t S_IXUSR = 64;

const int64_t S_IRWXG = 56;

const int64_t S_IRGRP = 32;

const int64_t S_IWGRP = 16;

const int64_t S_IXGRP = 8;

const int64_t S_IRWXO = 7;

const int64_t S_IROTH = 4;

const int64_t S_IWOTH = 2;

const int64_t S_IXOTH = 1;

const int64_t UYA_SEEK_SET = 0;

const int64_t UYA_SEEK_CUR = 1;

const int64_t UYA_SEEK_END = 2;

const int64_t STDIN_FILENO = 0;

const int64_t STDOUT_FILENO = 1;

const int64_t STDERR_FILENO = 2;

const int32_t EPERM = 1;

const int32_t ENOENT = 2;

const int32_t ESRCH = 3;

const int32_t EINTR = 4;

const int32_t EIO = 5;

const int32_t ENXIO = 6;

const int32_t E2BIG = 7;

const int32_t ENOEXEC = 8;

const int32_t EBADF = 9;

const int32_t ECHILD = 10;

const int32_t EAGAIN = 11;

const int32_t ENOMEM = 12;

const int32_t EACCES = 13;

const int32_t EFAULT = 14;

const int32_t ENOTBLK = 15;

const int32_t EBUSY = 16;

const int32_t EEXIST = 17;

const int32_t EXDEV = 18;

const int32_t ENODEV = 19;

const int32_t ENOTDIR = 20;

const int32_t EISDIR = 21;

const int32_t EINVAL = 22;

struct err_union_int64_t sys_write(int64_t fd, int64_t buf, int64_t count) {
    struct err_union_int64_t _uya_ret = ({ long _uya_syscall_ret = uya_syscall3(SYS_write, fd, buf, count); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    return _uya_ret;
}

struct err_union_int64_t sys_read(int64_t fd, int64_t buf, int64_t count) {
    struct err_union_int64_t _uya_ret = ({ long _uya_syscall_ret = uya_syscall3(SYS_read, fd, buf, count); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    return _uya_ret;
}

struct err_union_int64_t sys_open(int64_t path, int64_t flags, int64_t mode) {
    struct err_union_int64_t _uya_ret = ({ long _uya_syscall_ret = uya_syscall3(SYS_open, path, flags, mode); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    return _uya_ret;
}

struct err_union_int64_t sys_close(int64_t fd) {
    struct err_union_int64_t _uya_ret = ({ long _uya_syscall_ret = uya_syscall1(SYS_close, fd); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    return _uya_ret;
}

void sys_exit(int64_t status) {
    (void)(({ long _uya_syscall_ret = uya_syscall1(SYS_exit, status); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; }));
}

int64_t sys_getpid() {
    struct err_union_int64_t result = ({ long _uya_syscall_ret = uya_syscall0(SYS_getpid); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    const int64_t pid = ({ int32_t _uya_catch_result; struct err_union_int64_t _uya_catch_tmp = result; if (_uya_catch_tmp.error_id != 0) {
        int64_t _uya_ret = 0;
        return _uya_ret;
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
    int64_t _uya_ret = pid;
    return _uya_ret;
}

struct err_union_int64_t sys_lseek(int64_t fd, int64_t offset, int64_t whence) {
    struct err_union_int64_t _uya_ret = ({ long _uya_syscall_ret = uya_syscall3(SYS_lseek, fd, offset, whence); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    return _uya_ret;
}

struct err_union_int64_t sys_access(int64_t path, int64_t mode) {
    struct err_union_int64_t _uya_ret = ({ long _uya_syscall_ret = uya_syscall2(SYS_access, path, mode); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    return _uya_ret;
}

struct err_union_int64_t sys_unlink(int64_t path) {
    struct err_union_int64_t _uya_ret = ({ long _uya_syscall_ret = uya_syscall1(SYS_unlink, path); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    return _uya_ret;
}

struct err_union_int64_t sys_mkdir(int64_t path, int64_t mode) {
    struct err_union_int64_t _uya_ret = ({ long _uya_syscall_ret = uya_syscall2(SYS_mkdir, path, mode); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    return _uya_ret;
}

struct err_union_int64_t sys_rmdir(int64_t path) {
    struct err_union_int64_t _uya_ret = ({ long _uya_syscall_ret = uya_syscall1(SYS_rmdir, path); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    return _uya_ret;
}

struct err_union_int64_t sys_chdir(int64_t path) {
    struct err_union_int64_t _uya_ret = ({ long _uya_syscall_ret = uya_syscall1(SYS_chdir, path); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    return _uya_ret;
}

struct err_union_int64_t sys_getcwd(int64_t buf, int64_t size) {
    struct err_union_int64_t _uya_ret = ({ long _uya_syscall_ret = uya_syscall2(SYS_getcwd, buf, size); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    return _uya_ret;
}

int32_t uya_main(void) {
const uint8_t * const msg1 = (uint8_t *)str0;
const int64_t len1 = 30;
(void)(0);
const uint8_t * const path = (uint8_t *)str1;
struct err_union_int64_t fd_result = sys_open((int64_t)path, ((O_CREAT | O_WRONLY) | O_TRUNC), S_IRWXU);
const int64_t fd = ({ int32_t _uya_catch_result; struct err_union_int64_t _uya_catch_tmp = fd_result; if (_uya_catch_tmp.error_id != 0) {
    int32_t _uya_ret = 2;
    return _uya_ret;
} else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
const uint8_t * const msg2 = (uint8_t *)str2;
const int64_t len2 = 21;
(void)(0);
(void)(0);
const int64_t pid = sys_getpid();
if ((pid <= 0)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
