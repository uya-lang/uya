// C99 代码由 Uya Mini 编译器生成
// 使用 -std=c99 编译
//
#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

// @asm_target 平台检测
#if defined(__x86_64__) || defined(_M_X64)
  #if defined(__linux__)
    #define UYA_ASM_TARGET_X86_64_LINUX 0
  #elif defined(__APPLE__)
    #define UYA_ASM_TARGET_X86_64_LINUX 1
  #elif defined(_WIN32)
    #define UYA_ASM_TARGET_X86_64_LINUX 2
  #else
    #define UYA_ASM_TARGET_X86_64_LINUX 0
  #endif
#elif defined(__aarch64__) || defined(_M_ARM64)
  #if defined(__linux__)
    #define UYA_ASM_TARGET_X86_64_LINUX 3
  #elif defined(__APPLE__)
    #define UYA_ASM_TARGET_X86_64_LINUX 4
  #elif defined(_WIN32)
    #define UYA_ASM_TARGET_X86_64_LINUX 5
  #else
    #define UYA_ASM_TARGET_X86_64_LINUX 3
  #endif
#elif defined(__riscv) && __riscv_xlen == 64
  #define UYA_ASM_TARGET_X86_64_LINUX 6
#else
  #define UYA_ASM_TARGET_X86_64_LINUX 0
#endif
#define UYA_TARGET_PLATFORM UYA_ASM_TARGET_X86_64_LINUX
#if defined(__linux__)
  #define UYA_TARGET_OS_LINUX 1
  #define UYA_TARGET_OS_DARWIN 0
  #define UYA_TARGET_OS_WINDOWS 0
#elif defined(__APPLE__)
  #define UYA_TARGET_OS_LINUX 0
  #define UYA_TARGET_OS_DARWIN 1
  #define UYA_TARGET_OS_WINDOWS 0
#elif defined(_WIN32)
  #define UYA_TARGET_OS_LINUX 0
  #define UYA_TARGET_OS_DARWIN 0
  #define UYA_TARGET_OS_WINDOWS 1
#else
  #define UYA_TARGET_OS_LINUX 0
  #define UYA_TARGET_OS_DARWIN 0
  #define UYA_TARGET_OS_WINDOWS 0
#endif
#if defined(__x86_64__) || defined(_M_X64)
  #define UYA_TARGET_ARCH_X86_64 1
  #define UYA_TARGET_ARCH_ARM64 0
  #define UYA_TARGET_ARCH_RISCV64 0
#elif defined(__aarch64__) || defined(_M_ARM64)
  #define UYA_TARGET_ARCH_X86_64 0
  #define UYA_TARGET_ARCH_ARM64 1
  #define UYA_TARGET_ARCH_RISCV64 0
#elif defined(__riscv) && __riscv_xlen == 64
  #define UYA_TARGET_ARCH_X86_64 0
  #define UYA_TARGET_ARCH_ARM64 0
  #define UYA_TARGET_ARCH_RISCV64 1
#else
  #define UYA_TARGET_ARCH_X86_64 0
  #define UYA_TARGET_ARCH_ARM64 0
  #define UYA_TARGET_ARCH_RISCV64 0
#endif

#include <stddef.h>
// 标准类型定义（不依赖标准库头文件）
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;
typedef signed char int8_t;
typedef signed short int16_t;
typedef signed int int32_t;
typedef signed long long int64_t;
typedef signed long ssize_t;
typedef unsigned long uintptr_t;
typedef signed long intptr_t;
#ifndef NULL
#define NULL ((void *)0)
#endif
#ifndef offsetof
#define offsetof(type, member) ((size_t)&((type *)0)->member)
#endif
#ifndef true
#define true 1
#endif
#ifndef false
#define false 0
#endif
typedef _Bool bool;
struct uya_tagged_Poll_err_i32;
typedef struct uya_tagged_Poll_err_i32 uya_tagged_Poll_T;
typedef __builtin_va_list va_list;
#define va_start(v, l) __builtin_va_start(v, l)
#define va_end(v) __builtin_va_end(v)
#define va_arg(v, l) __builtin_va_arg(v, l)
#define va_copy(d, s) __builtin_va_copy(d, s)


// C99 兼容的 alignof 实现
#define uya_alignof(type) offsetof(struct { char c; type t; }, t)

static inline void *__uya_memcpy(void *dest, const void *src, size_t n) {
    char *d = (char *)dest; const char *s = (const char *)src;
    for (size_t i = 0; i < n; i++) d[i] = s[i];
    return dest;
}
static inline int __uya_memcmp(const void *s1, const void *s2, size_t n) {
    const unsigned char *a = (const unsigned char *)s1, *b = (const unsigned char *)s2;
    for (size_t i = 0; i < n; i++) { if (a[i] != b[i]) return a[i] - b[i]; } return 0;
}

// 错误联合类型（用于 !i64 等）
struct err_union_int64_t { uint32_t error_id; int64_t value; };
struct err_union_int32_t { uint32_t error_id; int32_t value; };
struct err_union_void { uint32_t error_id; };
static uint8_t *uya_error_name_from_id(uint32_t uya_error_id) {
    switch (uya_error_id) {
        default: return (uint8_t *)"UnknownError";
    }
}

#ifdef __APPLE__
#define stat uya_macos_native_stat_call
#define fstat uya_macos_native_fstat_call
#define lstat uya_macos_native_lstat_call
#define fstatat uya_macos_native_fstatat_call
#define mkdir uya_macos_native_mkdir_decl_hidden
#define time_t uya_macos_native_time_t
#define timespec uya_macos_native_timespec_tag
#define tv_sec uya_macos_native_tv_sec_hidden
#define tv_nsec uya_macos_native_tv_nsec_hidden
#include <sys/stat.h>
#undef stat
#undef fstat
#undef lstat
#undef fstatat
#undef mkdir
#undef time_t
#undef timespec
#undef tv_sec
#undef tv_nsec
#ifdef st_atime
#undef st_atime
#endif
#ifdef st_mtime
#undef st_mtime
#endif
#ifdef st_ctime
#undef st_ctime
#endif
#ifdef S_IFMT
#undef S_IFMT
#endif
#ifdef S_IFDIR
#undef S_IFDIR
#endif
#ifdef S_IFREG
#undef S_IFREG
#endif
#ifdef S_IRWXU
#undef S_IRWXU
#endif
#ifdef S_IRUSR
#undef S_IRUSR
#endif
#ifdef S_IWUSR
#undef S_IWUSR
#endif
#ifdef S_IXUSR
#undef S_IXUSR
#endif
#ifdef S_IRWXG
#undef S_IRWXG
#endif
#ifdef S_IRGRP
#undef S_IRGRP
#endif
#ifdef S_IWGRP
#undef S_IWGRP
#endif
#ifdef S_IXGRP
#undef S_IXGRP
#endif
#ifdef S_IRWXO
#undef S_IRWXO
#endif
#ifdef S_IROTH
#undef S_IROTH
#endif
#ifdef S_IWOTH
#undef S_IWOTH
#endif
#ifdef S_IXOTH
#undef S_IXOTH
#endif
extern void *dlsym(void *, const char *);
typedef int (*uya_macos_stat_fn)(const char *, struct uya_macos_native_stat_call *);
typedef intptr_t (*uya_macos_readlink_fn)(const char *, char *, size_t);
typedef int (*uya_macos_pid_fn)(void);
typedef void (*uya_macos_exit_fn)(int);
typedef int (*uya_macos_access_fn)(const char *, int);
typedef int (*uya_macos_path_i_fn)(const char *);
typedef char *(*uya_macos_getcwd_fn)(char *, size_t);
typedef int (*uya_macos_dup2_fn)(int, int);
typedef int (*uya_macos_pipe_fn)(int *);
typedef void *(*uya_macos_opendir_fn)(const char *);
typedef void *(*uya_macos_readdir_fn)(void *);
typedef int (*uya_macos_closedir_fn)(void *);
extern int uya_macos_real_fstat(int, struct uya_macos_native_stat_call *) __asm__("_fstat");
extern int uya_macos_real_lstat(const char *, struct uya_macos_native_stat_call *) __asm__("_lstat");
struct Stat;
struct TimeSpec;
struct uya_macos_native_timespec { int64_t tv_sec; int64_t tv_nsec; };
struct uya_macos_uya_timespec { int64_t tv_sec; int64_t tv_nsec; };
struct uya_macos_uya_stat {
    int64_t st_dev;
    int64_t st_ino;
    int64_t st_nlink;
    int32_t st_mode;
    int32_t st_uid;
    int32_t st_gid;
    int32_t _pad0;
    int64_t st_rdev;
    int64_t st_size;
    int64_t st_blksize;
    int64_t st_blocks;
    int64_t st_atime;
    int64_t st_atime_nsec;
    int64_t st_mtime;
    int64_t st_mtime_nsec;
    int64_t st_ctime;
    int64_t st_ctime_nsec;
    int64_t _unused0;
    int64_t _unused1;
    int64_t _unused2;
};
extern intptr_t uya_host_read(int, void *, size_t) __asm__("_read");
extern intptr_t uya_host_write(int, const void *, size_t) __asm__("_write");
extern int uya_host_open(const char *, int, ...) __asm__("_open");
extern int uya_host_close(int) __asm__("_close");
extern int64_t uya_host_lseek(int, int64_t, int) __asm__("_lseek");
extern int uya_host_access(const char *, int) __asm__("_access");
extern intptr_t uya_host_readlink(const char *, char *, size_t) __asm__("_readlink");
extern int uya_host_chdir(const char *) __asm__("_chdir");
extern char *uya_host_getcwd(char *, size_t) __asm__("_getcwd");
extern int uya_host_system(const char *) __asm__("_system");
extern int uya_host_socket(int, int, int) __asm__("_socket");
extern int uya_host_bind(int, const void *, uint32_t) __asm__("_bind");
extern int uya_host_listen(int, int) __asm__("_listen");
extern int uya_host_accept(int, void *, uint32_t *) __asm__("_accept");
extern int uya_host_connect(int, const void *, uint32_t) __asm__("_connect");
extern intptr_t uya_host_sendto(int, const void *, size_t, int, const void *, uint32_t) __asm__("_sendto");
extern intptr_t uya_host_recvfrom(int, void *, size_t, int, void *, uint32_t *) __asm__("_recvfrom");
extern int uya_host_shutdown(int, int) __asm__("_shutdown");
extern int uya_host_setsockopt(int, int, int, const void *, uint32_t) __asm__("_setsockopt");
extern int uya_host_fork(void) __asm__("_fork");
extern int uya_host_waitpid(int, int *, int) __asm__("_waitpid");
extern void *uya_host_dlsym(void *, const char *) __asm__("_dlsym");
typedef void *(*uya_host_opendir_fn)(const char *);
typedef void *(*uya_host_readdir_fn)(void *);
typedef int (*uya_host_closedir_fn)(void *);
extern int fcntl(int, int, ...);
extern int clock_gettime(int, struct uya_macos_native_timespec *);
extern int nanosleep(const struct uya_macos_native_timespec *, struct uya_macos_native_timespec *);
extern int *__error(void);
static int uya_macos_errno_value(void) { return *__error(); }
static struct err_union_int32_t uya_macos_err_i32(int err) { return (struct err_union_int32_t){ .error_id = (uint32_t)err, .value = 0 }; }
static struct err_union_int32_t uya_macos_ok_i32(int value) { return (struct err_union_int32_t){ .error_id = 0, .value = value }; }
static struct err_union_int64_t uya_macos_err_i64(int err) { return (struct err_union_int64_t){ .error_id = (uint32_t)err, .value = 0 }; }
static struct err_union_int64_t uya_macos_ok_i64(int64_t value) { return (struct err_union_int64_t){ .error_id = 0, .value = value }; }
struct err_union_int64_t uya_macos_write(int32_t fd, const char *buf, size_t count) {
    intptr_t ret = uya_host_write((int)fd, buf, count);
    if (ret == -1) return uya_macos_err_i64(uya_macos_errno_value());
    return uya_macos_ok_i64((int64_t)ret);
}
struct err_union_int64_t uya_macos_read(int32_t fd, char *buf, size_t count) {
    if (buf == (char *)0 && count != 0) return uya_macos_err_i64(22);
    intptr_t ret = uya_host_read((int)fd, buf, count);
    if (ret == -1) return uya_macos_err_i64(uya_macos_errno_value());
    return uya_macos_ok_i64((int64_t)ret);
}
struct err_union_int32_t uya_macos_open(const char *pathname, int32_t flags, int32_t mode) {
    int ret = uya_host_open(pathname, (int)flags, (int)mode);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
struct err_union_int32_t uya_macos_close(int32_t fd) {
    int ret = uya_host_close((int)fd);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
struct err_union_int64_t uya_macos_lseek(int32_t fd, int64_t offset, int32_t whence) {
    int64_t ret = uya_host_lseek((int)fd, offset, (int)whence);
    if (ret == -1) return uya_macos_err_i64(uya_macos_errno_value());
    return uya_macos_ok_i64(ret);
}
struct err_union_int32_t uya_macos_access(const char *pathname, int32_t mode) {
    static uya_macos_access_fn real_access = (uya_macos_access_fn)0;
    if (real_access == (uya_macos_access_fn)0) real_access = (uya_macos_access_fn)dlsym((void *)-1, "access");
    if (real_access == (uya_macos_access_fn)0) return uya_macos_err_i32(78);
    int ret = real_access(pathname, (int)mode);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
static void uya_macos_copy_stat(struct Stat *dst, const struct uya_macos_native_stat_call *src) {
    struct uya_macos_uya_stat *dst_stat = (struct uya_macos_uya_stat *)dst;
    if (dst_stat == (struct uya_macos_uya_stat *)0 || src == (const struct uya_macos_native_stat_call *)0) return;
    dst_stat->st_dev = (int64_t)src->st_dev; dst_stat->st_ino = (int64_t)src->st_ino; dst_stat->st_nlink = (int64_t)src->st_nlink;
    dst_stat->st_mode = (int32_t)src->st_mode; dst_stat->st_uid = (int32_t)src->st_uid; dst_stat->st_gid = (int32_t)src->st_gid; dst_stat->_pad0 = 0;
    dst_stat->st_rdev = (int64_t)src->st_rdev; dst_stat->st_size = src->st_size; dst_stat->st_blksize = (int64_t)src->st_blksize; dst_stat->st_blocks = src->st_blocks;
    dst_stat->st_atime = (int64_t)src->st_atime; dst_stat->st_atime_nsec = (int64_t)src->st_atimensec;
    dst_stat->st_mtime = (int64_t)src->st_mtime; dst_stat->st_mtime_nsec = (int64_t)src->st_mtimensec;
    dst_stat->st_ctime = (int64_t)src->st_ctime; dst_stat->st_ctime_nsec = (int64_t)src->st_ctimensec;
    dst_stat->_unused0 = 0; dst_stat->_unused1 = 0; dst_stat->_unused2 = 0;
}
struct err_union_int32_t uya_macos_stat(const char *pathname, struct Stat *statbuf) {
    struct uya_macos_native_stat_call native_stat;
    if (pathname == (const char *)0 || statbuf == (struct Stat *)0) return uya_macos_err_i32(22);
    static uya_macos_stat_fn real_stat = (uya_macos_stat_fn)0;
    if (real_stat == (uya_macos_stat_fn)0) real_stat = (uya_macos_stat_fn)dlsym((void *)-1, "stat");
    if (real_stat == (uya_macos_stat_fn)0) return uya_macos_err_i32(78);
    if (real_stat(pathname, &native_stat) != 0) return uya_macos_err_i32(uya_macos_errno_value());
    uya_macos_copy_stat(statbuf, &native_stat);
    return uya_macos_ok_i32(0);
}
struct err_union_int32_t uya_macos_fstat(int32_t fd, struct Stat *statbuf) {
    struct uya_macos_native_stat_call native_stat;
    if (statbuf == (struct Stat *)0) return uya_macos_err_i32(22);
    if (uya_macos_real_fstat((int)fd, &native_stat) != 0) return uya_macos_err_i32(uya_macos_errno_value());
    uya_macos_copy_stat(statbuf, &native_stat);
    return uya_macos_ok_i32(0);
}
struct err_union_int32_t uya_macos_lstat(const char *pathname, struct Stat *statbuf) {
    struct uya_macos_native_stat_call native_stat;
    if (pathname == (const char *)0 || statbuf == (struct Stat *)0) return uya_macos_err_i32(22);
    if (uya_macos_real_lstat(pathname, &native_stat) != 0) return uya_macos_err_i32(uya_macos_errno_value());
    uya_macos_copy_stat(statbuf, &native_stat);
    return uya_macos_ok_i32(0);
}
struct err_union_int64_t uya_macos_readlink(const char *pathname, char *buf, size_t bufsiz) {
    if (pathname == (const char *)0 || buf == (char *)0) return uya_macos_err_i64(22);
    static uya_macos_readlink_fn real_readlink = (uya_macos_readlink_fn)0;
    if (real_readlink == (uya_macos_readlink_fn)0) real_readlink = (uya_macos_readlink_fn)dlsym((void *)-1, "readlink");
    if (real_readlink == (uya_macos_readlink_fn)0) return uya_macos_err_i64(78);
    intptr_t ret = real_readlink(pathname, buf, bufsiz);
    if (ret == -1) return uya_macos_err_i64(uya_macos_errno_value());
    return uya_macos_ok_i64((int64_t)ret);
}
struct err_union_int32_t uya_macos_chdir(const char *pathname) {
    static uya_macos_path_i_fn real_chdir = (uya_macos_path_i_fn)0;
    if (real_chdir == (uya_macos_path_i_fn)0) real_chdir = (uya_macos_path_i_fn)dlsym((void *)-1, "chdir");
    if (real_chdir == (uya_macos_path_i_fn)0) return uya_macos_err_i32(78);
    int ret = real_chdir(pathname);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
struct err_union_int64_t uya_macos_getcwd(char *buf, size_t size) {
    if (buf == (char *)0 || size == 0) return uya_macos_err_i64(22);
    static uya_macos_getcwd_fn real_getcwd = (uya_macos_getcwd_fn)0;
    if (real_getcwd == (uya_macos_getcwd_fn)0) real_getcwd = (uya_macos_getcwd_fn)dlsym((void *)-1, "getcwd");
    if (real_getcwd == (uya_macos_getcwd_fn)0) return uya_macos_err_i64(78);
    if (real_getcwd(buf, size) == (char *)0) return uya_macos_err_i64(uya_macos_errno_value());
    size_t len = 0; while (len < size && buf[len] != 0) len++;
    if (len >= size || len > 0x7fffffffu) return uya_macos_err_i64(34);
    return uya_macos_ok_i64((int64_t)len);
}
struct err_union_int32_t uya_macos_fcntl(int32_t fd, int32_t cmd, int32_t arg) {
    int ret = fcntl((int)fd, (int)cmd, (int)arg);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
struct err_union_int32_t uya_macos_dup2(int32_t oldfd, int32_t newfd) {
    static uya_macos_dup2_fn real_dup2 = (uya_macos_dup2_fn)0;
    if (real_dup2 == (uya_macos_dup2_fn)0) real_dup2 = (uya_macos_dup2_fn)dlsym((void *)-1, "dup2");
    if (real_dup2 == (uya_macos_dup2_fn)0) return uya_macos_err_i32(78);
    int ret = real_dup2((int)oldfd, (int)newfd);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
struct err_union_int32_t uya_macos_fcntl_getpath(int32_t fd, char *buf, size_t size) {
    size_t len = 0;
    if (buf == (char *)0) return uya_macos_err_i32(22);
    if (size < 1024u) return uya_macos_err_i32(34);
    if (fcntl((int)fd, 50, buf) == -1) return uya_macos_err_i32(uya_macos_errno_value());
    while (len < size && buf[len] != 0) len++;
    if (len >= size || len > 0x7fffffffu) return uya_macos_err_i32(34);
    return uya_macos_ok_i32((int32_t)len);
}
static int uya_macos_apply_pipe_flags(int fd, int flags) {
    if ((flags & ~(0x00000004 | 0x01000000)) != 0) return 22;
    if ((flags & 0x00000004) != 0) {
        int cur = fcntl(fd, 3, 0);
        if (cur == -1) return uya_macos_errno_value();
        if (fcntl(fd, 4, cur | 0x00000004) == -1) return uya_macos_errno_value();
    }
    if ((flags & 0x01000000) != 0) {
        int curfd = fcntl(fd, 1, 0);
        if (curfd == -1) return uya_macos_errno_value();
        if (fcntl(fd, 2, curfd | 1) == -1) return uya_macos_errno_value();
    }
    return 0;
}
struct err_union_int32_t uya_macos_pipe2(int32_t *pipefd, int32_t flags) {
    int fds[2];
    int err = 0;
    if (pipefd == (int32_t *)0) return uya_macos_err_i32(22);
    static uya_macos_pipe_fn real_pipe = (uya_macos_pipe_fn)0;
    if (real_pipe == (uya_macos_pipe_fn)0) real_pipe = (uya_macos_pipe_fn)dlsym((void *)-1, "pipe");
    if (real_pipe == (uya_macos_pipe_fn)0) return uya_macos_err_i32(78);
    if (real_pipe(fds) != 0) return uya_macos_err_i32(uya_macos_errno_value());
    err = uya_macos_apply_pipe_flags(fds[0], (int)flags);
    if (err == 0) err = uya_macos_apply_pipe_flags(fds[1], (int)flags);
    if (err != 0) { uya_host_close(fds[0]); uya_host_close(fds[1]); return uya_macos_err_i32(err); }
    pipefd[0] = (int32_t)fds[0]; pipefd[1] = (int32_t)fds[1];
    return uya_macos_ok_i32(0);
}
struct err_union_int32_t uya_macos_clock_gettime(int32_t clock_id, struct TimeSpec *tp) {
    struct uya_macos_native_timespec native_tp;
    struct uya_macos_uya_timespec *uya_tp = (struct uya_macos_uya_timespec *)tp;
    if (uya_tp == (struct uya_macos_uya_timespec *)0) return uya_macos_err_i32(22);
    if (clock_gettime((int)clock_id, &native_tp) != 0) return uya_macos_err_i32(uya_macos_errno_value());
    uya_tp->tv_sec = native_tp.tv_sec; uya_tp->tv_nsec = native_tp.tv_nsec;
    return uya_macos_ok_i32(0);
}
struct err_union_int32_t uya_macos_nanosleep(const struct TimeSpec *req, struct TimeSpec *rem) {
    struct uya_macos_native_timespec native_req;
    struct uya_macos_native_timespec native_rem;
    const struct uya_macos_uya_timespec *uya_req = (const struct uya_macos_uya_timespec *)req;
    struct uya_macos_uya_timespec *uya_rem = (struct uya_macos_uya_timespec *)rem;
    if (uya_req == (const struct uya_macos_uya_timespec *)0 || uya_rem == (struct uya_macos_uya_timespec *)0) return uya_macos_err_i32(22);
    native_req.tv_sec = uya_req->tv_sec; native_req.tv_nsec = uya_req->tv_nsec;
    if (nanosleep(&native_req, &native_rem) != 0) {
        uya_rem->tv_sec = native_rem.tv_sec; uya_rem->tv_nsec = native_rem.tv_nsec;
        return uya_macos_err_i32(uya_macos_errno_value());
    }
    uya_rem->tv_sec = 0; uya_rem->tv_nsec = 0;
    return uya_macos_ok_i32(0);
}
struct err_union_int32_t uya_macos_system(const char *cmd) {
    static uya_macos_path_i_fn real_system = (uya_macos_path_i_fn)0;
    if (real_system == (uya_macos_path_i_fn)0) real_system = (uya_macos_path_i_fn)dlsym((void *)-1, "system");
    if (real_system == (uya_macos_path_i_fn)0) return uya_macos_err_i32(78);
    int ret = real_system(cmd);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
struct err_union_int32_t uya_macos_socket(int32_t domain, int32_t type, int32_t protocol) {
    int ret = uya_host_socket((int)domain, (int)type, (int)protocol);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
struct err_union_int32_t uya_macos_bind(int32_t sockfd, void *addr, uint32_t addrlen) {
    int ret = uya_host_bind((int)sockfd, (const void *)addr, addrlen);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
struct err_union_int32_t uya_macos_listen(int32_t sockfd, int32_t backlog) {
    int ret = uya_host_listen((int)sockfd, (int)backlog);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
struct err_union_int32_t uya_macos_accept(int32_t sockfd, void *addr, uint32_t *addrlen) {
    int ret = uya_host_accept((int)sockfd, addr, addrlen);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
struct err_union_int32_t uya_macos_connect(int32_t sockfd, void *addr, uint32_t addrlen) {
    int ret = uya_host_connect((int)sockfd, (const void *)addr, addrlen);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
struct err_union_int64_t uya_macos_sendto(int32_t sockfd, const char *buf, size_t len, int32_t flags, void *dest, uint32_t destlen) {
    intptr_t ret = uya_host_sendto((int)sockfd, (const void *)buf, len, (int)flags, (const void *)dest, destlen);
    if (ret == -1) return uya_macos_err_i64(uya_macos_errno_value());
    return uya_macos_ok_i64((int64_t)ret);
}
struct err_union_int64_t uya_macos_recvfrom(int32_t sockfd, char *buf, size_t len, int32_t flags, void *src, uint32_t *srclen) {
    intptr_t ret = uya_host_recvfrom((int)sockfd, (void *)buf, len, (int)flags, src, srclen);
    if (ret == -1) return uya_macos_err_i64(uya_macos_errno_value());
    return uya_macos_ok_i64((int64_t)ret);
}
struct err_union_int32_t uya_macos_shutdown(int32_t sockfd, int32_t how) {
    int ret = uya_host_shutdown((int)sockfd, (int)how);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
struct err_union_int32_t uya_macos_setsockopt(int32_t sockfd, int32_t level, int32_t optname, void *optval, uint32_t optlen) {
    int ret = uya_host_setsockopt((int)sockfd, (int)level, (int)optname, (const void *)optval, optlen);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
struct err_union_int64_t uya_macos_fork(void) {
    int ret = uya_host_fork();
    if (ret == -1) return uya_macos_err_i64(uya_macos_errno_value());
    return uya_macos_ok_i64((int64_t)ret);
}
struct err_union_int32_t uya_macos_waitpid(int32_t pid, int32_t *status, int32_t options) {
    int ret = uya_host_waitpid((int)pid, (int *)status, (int)options);
    if (ret == -1) return uya_macos_err_i32(uya_macos_errno_value());
    return uya_macos_ok_i32(ret);
}
int32_t uya_macos_getpid(void) {
    static uya_macos_pid_fn real_getpid = (uya_macos_pid_fn)0;
    if (real_getpid == (uya_macos_pid_fn)0) real_getpid = (uya_macos_pid_fn)dlsym((void *)-1, "getpid");
    if (real_getpid == (uya_macos_pid_fn)0) return 0;
    return (int32_t)real_getpid();
}
int32_t uya_macos_getppid(void) {
    static uya_macos_pid_fn real_getppid = (uya_macos_pid_fn)0;
    if (real_getppid == (uya_macos_pid_fn)0) real_getppid = (uya_macos_pid_fn)dlsym((void *)-1, "getppid");
    if (real_getppid == (uya_macos_pid_fn)0) return 0;
    return (int32_t)real_getppid();
}
void uya_macos_exit(int32_t status) {
    static uya_macos_exit_fn real_exit = (uya_macos_exit_fn)0;
    if (real_exit == (uya_macos_exit_fn)0) real_exit = (uya_macos_exit_fn)dlsym((void *)-1, "_exit");
    if (real_exit != (uya_macos_exit_fn)0) real_exit((int)status);
    __builtin_trap();
}
void *uya_macos_host_opendir(const char *path) {
    static uya_macos_opendir_fn real_opendir = (uya_macos_opendir_fn)0;
    if (real_opendir == (uya_macos_opendir_fn)0) real_opendir = (uya_macos_opendir_fn)dlsym((void *)-1, "opendir");
    if (real_opendir == (uya_macos_opendir_fn)0) return (void *)0;
    return real_opendir(path);
}
int32_t uya_macos_host_readdir_fill(void *dirp, void *out) {
    unsigned char *src = (unsigned char *)0;
    unsigned char *dst = (unsigned char *)0;
    size_t clear_idx = 0;
    size_t name_len = 0;
    if (dirp == (void *)0 || out == (void *)0) return -1;
    static uya_macos_readdir_fn real_readdir = (uya_macos_readdir_fn)0;
    if (real_readdir == (uya_macos_readdir_fn)0) real_readdir = (uya_macos_readdir_fn)dlsym((void *)-1, "readdir");
    if (real_readdir == (uya_macos_readdir_fn)0) return -1;
    src = (unsigned char *)real_readdir(dirp);
    if (src == (unsigned char *)0) return 0;
    dst = (unsigned char *)out;
    while (clear_idx < 275u) {
        dst[clear_idx] = 0;
        clear_idx++;
    }
    dst[18] = src[20];
    while (name_len < 255u && src[21 + name_len] != 0) {
        dst[19 + name_len] = src[21 + name_len];
        name_len++;
    }
    dst[19 + name_len] = 0;
    return 1;
}
int32_t uya_macos_host_closedir(void *dirp) {
    if (dirp == (void *)0) return -1;
    static uya_macos_closedir_fn real_closedir = (uya_macos_closedir_fn)0;
    if (real_closedir == (uya_macos_closedir_fn)0) real_closedir = (uya_macos_closedir_fn)dlsym((void *)-1, "closedir");
    if (real_closedir == (uya_macos_closedir_fn)0) return -1;
    return real_closedir(dirp);
}
#endif


// 字符串常量（char 类型以满足 -Wformat= 对 fprintf/snprintf 格式参数的要求）
static const char str0[] = "build";
static const char str1[] = "check";
static const char str2[] = "run";
static const char str3[] = "test";
static const char str4[] = "fmt";
static const char str5[] = "upm";
static const char str6[] = "microapp";
static const char str7[] = "/proc/self/exe";
static const char str8[] = "%scmd/%s";
static const char str9[] = "错误: 无法构造 cmd/%s 路径\n";
static const char str10[] = "错误: 缺少可执行子命令 %s；请先运行 make cmds\n";
static const char str11[] = "错误: 无法为 cmd/%s 调度参数分配内存\n";
static const char str12[] = "错误: 无法获取 cmd/%s 调度参数（索引 %d）\n";
static const char str13[] = "错误: 无法执行子命令 %s\n";
static const char str14[] = "uya";
static const char str15[] = "Uya 编译器 launcher\n";
static const char str16[] = "版本：v0.9.9\n";
static const char str17[] = "\n用法:\n";
static const char str18[] = "  %s build <文件> [-o <输出>] [选项]\n";
static const char str19[] = "  %s check <文件> [选项]\n";
static const char str20[] = "  %s run <文件> [选项] [-- <参数>...]\n";
static const char str21[] = "  %s test <文件> [选项]\n";
static const char str22[] = "  %s fmt <文件> [选项]\n";
static const char str23[] = "  %s upm <子命令> [参数]\n";
static const char str24[] = "  %s microapp <build|pack|inspect|verify|run> [参数]\n";
static const char str25[] = "\n说明: 隐式编译入口已移除；请使用 `uya build ...`。\n";
static const char str26[] = "错误: 隐式编译入口已移除，请使用 `%s build ...`\n";
static const char str27[] = "提示: 子命令二进制位于 bin/cmd/；若缺失请先运行 make cmds\n";
static const char str28[] = "错误: 顶层 `%s` 已迁移，请使用 `%s microapp %s ...`\n";
static const char str29[] = "提示: microapp image/payload 逻辑位于独立子命令 bin/cmd/microapp\n";
static const char str30[] = "--help";
static const char str31[] = "-h";
static const char str32[] = "--version";
static const char str33[] = "-v";
static const char str34[] = "Uya 编译器版本 v0.9.9\n";
static const char str35[] = "pack-image";
static const char str36[] = "pack";
static const char str37[] = "inspect-image";
static const char str38[] = "inspect";
static const char str39[] = "verify-image";
static const char str40[] = "verify";
static const char str41[] = "Sun";
static const char str42[] = "Mon";
static const char str43[] = "Tue";
static const char str44[] = "Wed";
static const char str45[] = "Thu";
static const char str46[] = "Fri";
static const char str47[] = "Sat";
static const char str48[] = "Sunday";
static const char str49[] = "Monday";
static const char str50[] = "Tuesday";
static const char str51[] = "Wednesday";
static const char str52[] = "Thursday";
static const char str53[] = "Friday";
static const char str54[] = "Saturday";
static const char str55[] = "Jan";
static const char str56[] = "Feb";
static const char str57[] = "Mar";
static const char str58[] = "Apr";
static const char str59[] = "May";
static const char str60[] = "Jun";
static const char str61[] = "Jul";
static const char str62[] = "Aug";
static const char str63[] = "Sep";
static const char str64[] = "Oct";
static const char str65[] = "Nov";
static const char str66[] = "Dec";
static const char str67[] = "January";
static const char str68[] = "February";
static const char str69[] = "March";
static const char str70[] = "April";
static const char str71[] = "June";
static const char str72[] = "July";
static const char str73[] = "August";
static const char str74[] = "September";
static const char str75[] = "October";
static const char str76[] = "November";
static const char str77[] = "December";

struct TypeInfo;
struct err_union_size_t;
struct err_union_voidptr;
struct err_union_intptr_t;
struct EntryRLimit;
struct ChunkHeader;
struct FreeChunk;
struct HeapRegion;
struct pthread_t;
struct pthread_desc;
struct pthread_registry_entry;
struct pthread_mutexattr_t;
struct pthread_mutex_t;
struct pthread_cond_t;
struct timeval;
struct pthread_once_t;
struct pthread_attr_t;
struct pthread_condattr_t;
struct pthread_key_t;
struct timespec;
struct pthread_spinlock_t;
struct pthread_rwlock_t;
struct pthread_rwlockattr_t;
struct pthread_barrier_t;
struct pthread_barrierattr_t;
struct cpu_set_t;
struct jmp_buf;
struct sigjmp_buf;
struct sigaction;
struct sigset_t;
struct FILE;
struct _FmtContext;
struct div_t;
struct ldiv_t;
struct lldiv_t;
struct DIR;
struct DirState;
struct TimeVal;
struct Stat;
struct Dirent;
struct IOVec;
struct RLimit;
struct TimeSpec;
struct EpollEvent;
struct tm;
struct timezone;
struct mbstate_t;

enum std_platform_HostOS {
    std_platform_HostOS_hos_linux,
    std_platform_HostOS_hos_macos,
    std_platform_HostOS_hos_windows,
    std_platform_HostOS_hos_unknown
};

enum std_platform_HostArch {
    std_platform_HostArch_ha_x86_64,
    std_platform_HostArch_ha_arm64,
    std_platform_HostArch_ha_riscv64,
    std_platform_HostArch_ha_unknown
};

enum std_platform_TargetOS {
    std_platform_TargetOS_tos_linux,
    std_platform_TargetOS_tos_macos,
    std_platform_TargetOS_tos_windows,
    std_platform_TargetOS_tos_unknown
};

enum std_platform_TargetArch {
    std_platform_TargetArch_ta_x86_64,
    std_platform_TargetArch_ta_arm,
    std_platform_TargetArch_ta_arm64,
    std_platform_TargetArch_ta_riscv64,
    std_platform_TargetArch_ta_unknown
};

typedef int64_t time_t;
typedef uint64_t clock_t;
typedef int32_t wchar_t;
typedef int32_t wint_t;


struct err_union_size_t { uint32_t error_id; size_t value; };
struct err_union_voidptr { uint32_t error_id; void * value; };
struct err_union_intptr_t { uint32_t error_id; intptr_t value; };
struct err_union_bool { uint32_t error_id; bool value; };
struct err_union_uint8_t { uint32_t error_id; uint8_t value; };

// 内置 FieldInfo（由 TypeInfo.fields 使用）
struct FieldInfo { int8_t *name; int8_t *type_name; };

// 内置 TypeInfo 结构体（由 @mc_type 使用）
struct TypeInfo {
    int8_t * name;
    int32_t size;
    int32_t align;
    int32_t kind;
    int32_t type_id;
    bool is_integer;
    bool is_float;
    bool is_bool;
    bool is_pointer;
    bool is_array;
    bool is_void;
    int32_t field_count;
    struct FieldInfo fields[64];
};

struct EntryRLimit {
    uint64_t rlim_cur;
    uint64_t rlim_max;
};

struct ChunkHeader {
    uint64_t magic;
    size_t size;
};

struct FreeChunk {
    struct ChunkHeader header;
    struct FreeChunk * prev;
    struct FreeChunk * next;
};

struct HeapRegion {
    struct HeapRegion * next;
    struct ChunkHeader * base;
    size_t size;
};

struct pthread_t {
    int64_t tid;
    void * stack;
    size_t stack_size;
    _Atomic(int32_t) detached;
    _Atomic(int32_t) exited;
    void * result;
    void * start_routine;
    void * arg;
};

struct pthread_desc {
    int64_t tid;
    void * stack;
    size_t stack_size;
    _Atomic(int32_t) detached;
    _Atomic(int32_t) exited;
    _Atomic(int32_t) resources_released;
    _Atomic(int32_t) started;
    void * result;
    struct pthread_t * pub_handle;
    void * start_routine;
    void * arg;
    _Atomic(int32_t) joinstate;
    _Atomic(int32_t) cancel_state;
    _Atomic(int32_t) cancel_type;
    _Atomic(int32_t) cancel_pending;
    void * * tsd_values;
};

struct pthread_registry_entry {
    int64_t tid;
    struct pthread_desc * desc;
};

struct pthread_mutexattr_t {
    int32_t type;
};

struct pthread_mutex_t {
    _Atomic(int32_t) state;
    int64_t owner;
    int32_t type;
};

struct pthread_cond_t {
    _Atomic(int32_t) waiters;
    _Atomic(int32_t) seq;
    int32_t clock;
};

struct timeval {
    int64_t tv_sec;
    int64_t tv_usec;
};

struct pthread_once_t {
    _Atomic(int32_t) state;
};

struct pthread_attr_t {
    size_t stack_size;
    int32_t detached;
};

struct pthread_condattr_t {
    int32_t clock;
};

struct pthread_key_t {
    int32_t seq;
    void * destructor;
};

struct timespec {
    int64_t tv_sec;
    int64_t tv_nsec;
};

struct pthread_spinlock_t {
    _Atomic(int32_t) lock;
};

struct pthread_rwlock_t {
    _Atomic(int32_t) readers;
    _Atomic(int32_t) writer;
    int64_t writer_tid;
};

struct pthread_rwlockattr_t {
    int32_t _unused;
};

struct pthread_barrier_t {
    int32_t count;
    _Atomic(int32_t) arrived;
    _Atomic(int32_t) generation;
    struct pthread_mutex_t mutex;
    struct pthread_cond_t cond;
};

struct pthread_barrierattr_t {
    int32_t _unused;
};

struct cpu_set_t {
    uint64_t bits0;
    uint64_t bits1;
    uint64_t bits2;
    uint64_t bits3;
    uint64_t bits4;
    uint64_t bits5;
    uint64_t bits6;
    uint64_t bits7;
    uint64_t bits8;
    uint64_t bits9;
    uint64_t bits10;
    uint64_t bits11;
    uint64_t bits12;
    uint64_t bits13;
    uint64_t bits14;
    uint64_t bits15;
};

struct jmp_buf {
    uint64_t data[8];
};

struct sigjmp_buf {
    uint64_t data[16];
};

struct sigaction {
    void * sa_handler;
    uint64_t sa_flags;
    void * sa_restorer;
    uint64_t sa_mask;
};

struct sigset_t {
    uint64_t val;
};

struct FILE {
    int64_t fd;
    uint8_t buffer[65536];
    size_t buf_pos;
    size_t buf_len;
    int32_t buf_mode;
};

struct _FmtContext {
    uint8_t * buf;
    size_t buf_pos;
    size_t buf_max;
    struct FILE * stream;
    size_t total_len;
};

struct div_t {
    int32_t quot;
    int32_t rem;
};

struct ldiv_t {
    int64_t quot;
    int64_t rem;
};

struct lldiv_t {
    int64_t quot;
    int64_t rem;
};



struct DIR {
    char _empty;
};

struct DirState {
    int64_t fd;
    int64_t dir_pos;
    uint8_t buf[8192];
    size_t buf_pos;
    intptr_t buf_len;
};

struct TimeVal {
    int64_t tv_sec;
    int64_t tv_usec;
};

struct Stat {
    int64_t st_dev;
    int64_t st_ino;
    int64_t st_nlink;
    int32_t st_mode;
    int32_t st_uid;
    int32_t st_gid;
    int32_t _pad0;
    int64_t st_rdev;
    int64_t st_size;
    int64_t st_blksize;
    int64_t st_blocks;
    int64_t uya_st_atime;
    int64_t st_atime_nsec;
    int64_t uya_st_mtime;
    int64_t st_mtime_nsec;
    int64_t uya_st_ctime;
    int64_t st_ctime_nsec;
    int64_t _unused0;
    int64_t _unused1;
    int64_t _unused2;
};

struct Dirent {
    int64_t d_ino;
    int64_t d_off;
    int16_t d_reclen;
    int8_t d_type;
    uint8_t d_name[256];
};

struct IOVec {
    const uint8_t * iov_base;
    size_t iov_len;
};

struct RLimit {
    uint64_t rlim_cur;
    uint64_t rlim_max;
};

struct TimeSpec {
    int64_t tv_sec;
    int64_t tv_nsec;
};


struct EpollEvent {
    uint32_t events;
    uint32_t _pad;
    uint64_t data;
};

struct tm {
    int32_t tm_sec;
    int32_t tm_min;
    int32_t tm_hour;
    int32_t tm_mday;
    int32_t tm_mon;
    int32_t tm_year;
    int32_t tm_wday;
    int32_t tm_yday;
    int32_t tm_isdst;
};


struct timezone {
    int32_t tz_minuteswest;
    int32_t tz_dsttime;
};

struct mbstate_t {
    int32_t _state;
};

// std.thread：宿主工具链间接调用（跨 -O0/-O2 稳定；见 lib/std/thread.uya）
int32_t uya_call0_i32(void *fn) {
    typedef int32_t (*uya_fn0_i32)(void);
    return ((uya_fn0_i32)fn)();
}
int32_t uya_call0_i32_stack(void *fn, void *stack_top) {
    typedef int32_t (*uya_fn0_i32)(void);
#if defined(__x86_64__) || defined(_M_X64)
    uintptr_t top = ((uintptr_t)stack_top) & ~(uintptr_t)0xFUL;
    int32_t ret;
    __asm__ volatile(
        "mov %%rsp, %%rbx\n\t"
        "mov %1, %%rsp\n\t"
        "call *%2\n\t"
        "mov %%rbx, %%rsp\n\t"
        : "=a"(ret)
        : "r"((void *)top), "r"(fn)
        : "rbx", "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11", "memory", "cc");
    return ret;
#elif defined(__aarch64__) || defined(_M_ARM64)
    uintptr_t top = ((uintptr_t)stack_top) & ~(uintptr_t)0xFUL;
    int32_t ret;
    __asm__ volatile(
        "mov x9, sp\n\t"
        "mov sp, %1\n\t"
        "blr %2\n\t"
        "mov %w0, w0\n\t"
        "mov sp, x9\n\t"
        : "=r"(ret)
        : "r"((void *)top), "r"(fn)
        : "x0", "x9", "x30", "memory", "cc");
    return ret;
#else
    (void)stack_top;
    return ((uya_fn0_i32)fn)();
#endif
}
int32_t uya_thread_call_i32(void *fn, int32_t arg) {
    typedef int32_t (*uya_thrd_fn_i32)(int32_t);
    return ((uya_thrd_fn_i32)fn)(arg);
}
uint32_t uya_thread_call_u32(void *fn, uint32_t arg) {
    typedef uint32_t (*uya_thrd_fn_u32)(uint32_t);
    return ((uya_thrd_fn_u32)fn)(arg);
}
size_t uya_thread_call_usize(void *fn, size_t arg) {
    typedef size_t (*uya_thrd_fn_usz)(size_t);
    return ((uya_thrd_fn_usz)fn)(arg);
}
int64_t uya_thread_call_i64(void *fn, int64_t arg) {
    typedef int64_t (*uya_thrd_fn_i64)(int64_t);
    return ((uya_thrd_fn_i64)fn)(arg);
}
uint64_t uya_thread_call_u64(void *fn, uint64_t arg) {
    typedef uint64_t (*uya_thrd_fn_u64)(uint64_t);
    return ((uya_thrd_fn_u64)fn)(arg);
}
int16_t uya_thread_call_i16(void *fn, int16_t arg) {
    typedef int16_t (*uya_thrd_fn_i16)(int16_t);
    return ((uya_thrd_fn_i16)fn)(arg);
}
uint16_t uya_thread_call_u16(void *fn, uint16_t arg) {
    typedef uint16_t (*uya_thrd_fn_u16)(uint16_t);
    return ((uya_thrd_fn_u16)fn)(arg);
}
int8_t uya_thread_call_i8(void *fn, int8_t arg) {
    typedef int8_t (*uya_thrd_fn_i8)(int8_t);
    return ((uya_thrd_fn_i8)fn)(arg);
}
uint8_t uya_thread_call_u8(void *fn, uint8_t arg) {
    typedef uint8_t (*uya_thrd_fn_u8)(uint8_t);
    return ((uya_thrd_fn_u8)fn)(arg);
}
int32_t uya_thread_call_bool(void *fn, int32_t arg) {
    typedef int32_t (*uya_thrd_fn_bool)(int32_t);
    return ((uya_thrd_fn_bool)fn)(arg);
}
// f32/f64：槽位内仍为 u32/u64 位模式；间接调用须用真实 float/double 调用约定（不可伪装成整数函数指针）。
uint32_t uya_thread_call_f32(void *fn, uint32_t arg_bits) {
    typedef float (*uya_thrd_fn_f32)(float);
    union { uint32_t u; float f; } a;
    union { uint32_t u; float f; } out;
    a.u = arg_bits;
    out.f = ((uya_thrd_fn_f32)fn)(a.f);
    return out.u;
}
uint64_t uya_thread_call_f64(void *fn, uint64_t arg_bits) {
    typedef double (*uya_thrd_fn_f64)(double);
    union { uint64_t u; double d; } a;
    union { uint64_t u; double d; } out;
    a.u = arg_bits;
    out.d = ((uya_thrd_fn_f64)fn)(a.d);
    return out.u;
}

// 系统调用辅助函数：Linux/Darwin x86-64；Linux/Darwin AArch64；Linux ARM32 EABI
#if (defined(__x86_64__) || defined(_M_X64)) && defined(__linux__)
static inline long uya_syscall0(long nr) {
    long ret;
    __asm__ volatile("syscall" : "=a"(ret) : "a"(nr) : "rcx", "r11", "cc", "memory");
    return ret;
}

static inline long uya_syscall1(long nr, long a1) {
    long ret;
    __asm__ volatile("syscall" : "=a"(ret) : "a"(nr), "D"(a1) : "rcx", "r11", "cc", "memory");
    return ret;
}

static inline long uya_syscall2(long nr, long a1, long a2) {
    long ret;
    __asm__ volatile("syscall" : "=a"(ret) : "a"(nr), "D"(a1), "S"(a2) : "rcx", "r11", "cc", "memory");
    return ret;
}

static inline long uya_syscall3(long nr, long a1, long a2, long a3) {
    long ret;
    __asm__ volatile("syscall" : "=a"(ret) : "a"(nr), "D"(a1), "S"(a2), "d"(a3) : "rcx", "r11", "cc", "memory");
    return ret;
}

static inline long uya_syscall4(long nr, long a1, long a2, long a3, long a4) {
    register long r10 __asm__("r10") = a4;
    long ret;
    __asm__ volatile("syscall" : "=a"(ret) : "a"(nr), "D"(a1), "S"(a2), "d"(a3), "r"(r10) : "rcx", "r11", "cc", "memory");
    return ret;
}

static inline long uya_syscall5(long nr, long a1, long a2, long a3, long a4, long a5) {
    register long r10 __asm__("r10") = a4;
    register long r8 __asm__("r8") = a5;
    long ret;
    __asm__ volatile("syscall" : "=a"(ret) : "a"(nr), "D"(a1), "S"(a2), "d"(a3), "r"(r10), "r"(r8) : "rcx", "r11", "cc", "memory");
    return ret;
}

static inline long uya_syscall6(long nr, long a1, long a2, long a3, long a4, long a5, long a6) {
    register long r10 __asm__("r10") = a4;
    register long r8 __asm__("r8") = a5;
    register long r9 __asm__("r9") = a6;
    long ret;
    __asm__ volatile("syscall" : "=a"(ret) : "a"(nr), "D"(a1), "S"(a2), "d"(a3), "r"(r10), "r"(r8), "r"(r9) : "rcx", "r11", "cc", "memory");
    return ret;
}
#elif (defined(__x86_64__) || defined(_M_X64)) && defined(__APPLE__)
static inline long uya_syscall0(long nr) {
    long ret;
    unsigned char uya_err;
    __asm__ volatile("syscall\n\tsetc %1" : "=a"(ret), "=qm"(uya_err) : "a"(nr + 0x2000000L) : "rcx", "r11", "cc", "memory");
    return uya_err != 0 ? -ret : ret;
}

static inline long uya_syscall1(long nr, long a1) {
    long ret;
    unsigned char uya_err;
    __asm__ volatile("syscall\n\tsetc %1" : "=a"(ret), "=qm"(uya_err) : "a"(nr + 0x2000000L), "D"(a1) : "rcx", "r11", "cc", "memory");
    return uya_err != 0 ? -ret : ret;
}

static inline long uya_syscall2(long nr, long a1, long a2) {
    long ret;
    unsigned char uya_err;
    __asm__ volatile("syscall\n\tsetc %1" : "=a"(ret), "=qm"(uya_err) : "a"(nr + 0x2000000L), "D"(a1), "S"(a2) : "rcx", "r11", "cc", "memory");
    return uya_err != 0 ? -ret : ret;
}

static inline long uya_syscall3(long nr, long a1, long a2, long a3) {
    long ret;
    unsigned char uya_err;
    __asm__ volatile("syscall\n\tsetc %1" : "=a"(ret), "=qm"(uya_err) : "a"(nr + 0x2000000L), "D"(a1), "S"(a2), "d"(a3) : "rcx", "r11", "cc", "memory");
    return uya_err != 0 ? -ret : ret;
}

static inline long uya_syscall4(long nr, long a1, long a2, long a3, long a4) {
    register long r10 __asm__("r10") = a4;
    long ret;
    unsigned char uya_err;
    __asm__ volatile("syscall\n\tsetc %1" : "=a"(ret), "=qm"(uya_err) : "a"(nr + 0x2000000L), "D"(a1), "S"(a2), "d"(a3), "r"(r10) : "rcx", "r11", "cc", "memory");
    return uya_err != 0 ? -ret : ret;
}

static inline long uya_syscall5(long nr, long a1, long a2, long a3, long a4, long a5) {
    register long r10 __asm__("r10") = a4;
    register long r8 __asm__("r8") = a5;
    long ret;
    unsigned char uya_err;
    __asm__ volatile("syscall\n\tsetc %1" : "=a"(ret), "=qm"(uya_err) : "a"(nr + 0x2000000L), "D"(a1), "S"(a2), "d"(a3), "r"(r10), "r"(r8) : "rcx", "r11", "cc", "memory");
    return uya_err != 0 ? -ret : ret;
}

static inline long uya_syscall6(long nr, long a1, long a2, long a3, long a4, long a5, long a6) {
    register long r10 __asm__("r10") = a4;
    register long r8 __asm__("r8") = a5;
    register long r9 __asm__("r9") = a6;
    long ret;
    unsigned char uya_err;
    __asm__ volatile("syscall\n\tsetc %1" : "=a"(ret), "=qm"(uya_err) : "a"(nr + 0x2000000L), "D"(a1), "S"(a2), "d"(a3), "r"(r10), "r"(r8), "r"(r9) : "rcx", "r11", "cc", "memory");
    return uya_err != 0 ? -ret : ret;
}

#elif (defined(__aarch64__) || defined(_M_ARM64)) && defined(__linux__)
static inline long uya_syscall0(long nr) {
    register long x8 __asm__("x8") = nr;
    register long x0 __asm__("x0");
    __asm__ volatile("svc 0" : "=r"(x0) : "r"(x8) : "memory", "cc");
    return x0;
}

static inline long uya_syscall1(long nr, long a1) {
    register long x8 __asm__("x8") = nr;
    register long x0 __asm__("x0") = a1;
    __asm__ volatile("svc 0" : "+r"(x0) : "r"(x8) : "memory", "cc");
    return x0;
}

static inline long uya_syscall2(long nr, long a1, long a2) {
    register long x8 __asm__("x8") = nr;
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    __asm__ volatile("svc 0" : "+r"(x0) : "r"(x1), "r"(x8) : "memory", "cc");
    return x0;
}

static inline long uya_syscall3(long nr, long a1, long a2, long a3) {
    register long x8 __asm__("x8") = nr;
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    register long x2 __asm__("x2") = a3;
    __asm__ volatile("svc 0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x8) : "memory", "cc");
    return x0;
}

static inline long uya_syscall4(long nr, long a1, long a2, long a3, long a4) {
    register long x8 __asm__("x8") = nr;
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    register long x2 __asm__("x2") = a3;
    register long x3 __asm__("x3") = a4;
    __asm__ volatile("svc 0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x3), "r"(x8) : "memory", "cc");
    return x0;
}

static inline long uya_syscall5(long nr, long a1, long a2, long a3, long a4, long a5) {
    register long x8 __asm__("x8") = nr;
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    register long x2 __asm__("x2") = a3;
    register long x3 __asm__("x3") = a4;
    register long x4 __asm__("x4") = a5;
    __asm__ volatile("svc 0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x8) : "memory", "cc");
    return x0;
}

static inline long uya_syscall6(long nr, long a1, long a2, long a3, long a4, long a5, long a6) {
    register long x8 __asm__("x8") = nr;
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    register long x2 __asm__("x2") = a3;
    register long x3 __asm__("x3") = a4;
    register long x4 __asm__("x4") = a5;
    register long x5 __asm__("x5") = a6;
    __asm__ volatile("svc 0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5), "r"(x8) : "memory", "cc");
    return x0;
}

#elif (defined(__aarch64__) || defined(_M_ARM64)) && defined(__APPLE__)
static inline long uya_syscall0(long nr) {
    register long x16 __asm__("x16") = nr;
    register long x0 __asm__("x0");
    register unsigned long uya_err __asm__("x15");
    __asm__ volatile("svc #0x80\n\tcset %w1, cs" : "=r"(x0), "=r"(uya_err) : "r"(x16) : "memory", "cc");
    return uya_err != 0 ? -x0 : x0;
}

static inline long uya_syscall1(long nr, long a1) {
    register long x16 __asm__("x16") = nr;
    register long x0 __asm__("x0") = a1;
    register unsigned long uya_err __asm__("x15");
    __asm__ volatile("svc #0x80\n\tcset %w1, cs" : "+r"(x0), "=r"(uya_err) : "r"(x16) : "memory", "cc");
    return uya_err != 0 ? -x0 : x0;
}

static inline long uya_syscall2(long nr, long a1, long a2) {
    register long x16 __asm__("x16") = nr;
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    register unsigned long uya_err __asm__("x15");
    __asm__ volatile("svc #0x80\n\tcset %w1, cs" : "+r"(x0), "=r"(uya_err) : "r"(x1), "r"(x16) : "memory", "cc");
    return uya_err != 0 ? -x0 : x0;
}

static inline long uya_syscall3(long nr, long a1, long a2, long a3) {
    register long x16 __asm__("x16") = nr;
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    register long x2 __asm__("x2") = a3;
    register unsigned long uya_err __asm__("x15");
    __asm__ volatile("svc #0x80\n\tcset %w1, cs" : "+r"(x0), "=r"(uya_err) : "r"(x1), "r"(x2), "r"(x16) : "memory", "cc");
    return uya_err != 0 ? -x0 : x0;
}

static inline long uya_syscall4(long nr, long a1, long a2, long a3, long a4) {
    register long x16 __asm__("x16") = nr;
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    register long x2 __asm__("x2") = a3;
    register long x3 __asm__("x3") = a4;
    register unsigned long uya_err __asm__("x15");
    __asm__ volatile("svc #0x80\n\tcset %w1, cs" : "+r"(x0), "=r"(uya_err) : "r"(x1), "r"(x2), "r"(x3), "r"(x16) : "memory", "cc");
    return uya_err != 0 ? -x0 : x0;
}

static inline long uya_syscall5(long nr, long a1, long a2, long a3, long a4, long a5) {
    register long x16 __asm__("x16") = nr;
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    register long x2 __asm__("x2") = a3;
    register long x3 __asm__("x3") = a4;
    register long x4 __asm__("x4") = a5;
    register unsigned long uya_err __asm__("x15");
    __asm__ volatile("svc #0x80\n\tcset %w1, cs" : "+r"(x0), "=r"(uya_err) : "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x16) : "memory", "cc");
    return uya_err != 0 ? -x0 : x0;
}

static inline long uya_syscall6(long nr, long a1, long a2, long a3, long a4, long a5, long a6) {
    register long x16 __asm__("x16") = nr;
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    register long x2 __asm__("x2") = a3;
    register long x3 __asm__("x3") = a4;
    register long x4 __asm__("x4") = a5;
    register long x5 __asm__("x5") = a6;
    register unsigned long uya_err __asm__("x15");
    __asm__ volatile("svc #0x80\n\tcset %w1, cs" : "+r"(x0), "=r"(uya_err) : "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5), "r"(x16) : "memory", "cc");
    return uya_err != 0 ? -x0 : x0;
}

#elif defined(__arm__) && !defined(__aarch64__) && defined(__linux__)
/* ARM32 Linux EABI：nr→r7；参数 r0-r5；Thumb 下用临时寄存器保存/恢复 r7（与 musl 思路一致） */
static inline long uya_syscall0(long nr) {
    register long r0 __asm__("r0");
    __asm__ volatile(
        "mov %[sc_tmp], r7\n\tmov r7, %[sc_nr]\n\tsvc 0\n\tmov r7, %[sc_tmp]"
        : "=r"(r0), [sc_tmp]"=&r"((int){0})
        : [sc_nr]"r"(nr)
        : "memory", "cc"
    );
    return r0;
}

static inline long uya_syscall1(long nr, long a1) {
    register long r0 __asm__("r0") = a1;
    __asm__ volatile(
        "mov %[sc_tmp], r7\n\tmov r7, %[sc_nr]\n\tsvc 0\n\tmov r7, %[sc_tmp]"
        : "+r"(r0), [sc_tmp]"=&r"((int){0})
        : [sc_nr]"r"(nr)
        : "memory", "cc"
    );
    return r0;
}

static inline long uya_syscall2(long nr, long a1, long a2) {
    register long r0 __asm__("r0") = a1;
    register long r1 __asm__("r1") = a2;
    __asm__ volatile(
        "mov %[sc_tmp], r7\n\tmov r7, %[sc_nr]\n\tsvc 0\n\tmov r7, %[sc_tmp]"
        : "+r"(r0), [sc_tmp]"=&r"((int){0})
        : [sc_nr]"r"(nr), "r"(r1)
        : "memory", "cc"
    );
    return r0;
}

static inline long uya_syscall3(long nr, long a1, long a2, long a3) {
    register long r0 __asm__("r0") = a1;
    register long r1 __asm__("r1") = a2;
    register long r2 __asm__("r2") = a3;
    __asm__ volatile(
        "mov %[sc_tmp], r7\n\tmov r7, %[sc_nr]\n\tsvc 0\n\tmov r7, %[sc_tmp]"
        : "+r"(r0), [sc_tmp]"=&r"((int){0})
        : [sc_nr]"r"(nr), "r"(r1), "r"(r2)
        : "memory", "cc"
    );
    return r0;
}

static inline long uya_syscall4(long nr, long a1, long a2, long a3, long a4) {
    register long r0 __asm__("r0") = a1;
    register long r1 __asm__("r1") = a2;
    register long r2 __asm__("r2") = a3;
    register long r3 __asm__("r3") = a4;
    __asm__ volatile(
        "mov %[sc_tmp], r7\n\tmov r7, %[sc_nr]\n\tsvc 0\n\tmov r7, %[sc_tmp]"
        : "+r"(r0), [sc_tmp]"=&r"((int){0})
        : [sc_nr]"r"(nr), "r"(r1), "r"(r2), "r"(r3)
        : "memory", "cc"
    );
    return r0;
}

static inline long uya_syscall5(long nr, long a1, long a2, long a3, long a4, long a5) {
    register long r0 __asm__("r0") = a1;
    register long r1 __asm__("r1") = a2;
    register long r2 __asm__("r2") = a3;
    register long r3 __asm__("r3") = a4;
    register long r4 __asm__("r4") = a5;
    __asm__ volatile(
        "mov %[sc_tmp], r7\n\tmov r7, %[sc_nr]\n\tsvc 0\n\tmov r7, %[sc_tmp]"
        : "+r"(r0), [sc_tmp]"=&r"((int){0})
        : [sc_nr]"r"(nr), "r"(r1), "r"(r2), "r"(r3), "r"(r4)
        : "memory", "cc"
    );
    return r0;
}

static inline long uya_syscall6(long nr, long a1, long a2, long a3, long a4, long a5, long a6) {
    register long r0 __asm__("r0") = a1;
    register long r1 __asm__("r1") = a2;
    register long r2 __asm__("r2") = a3;
    register long r3 __asm__("r3") = a4;
    register long r4 __asm__("r4") = a5;
    register long r5 __asm__("r5") = a6;
    __asm__ volatile(
        "mov %[sc_tmp], r7\n\tmov r7, %[sc_nr]\n\tsvc 0\n\tmov r7, %[sc_tmp]"
        : "+r"(r0), [sc_tmp]"=&r"((int){0})
        : [sc_nr]"r"(nr), "r"(r1), "r"(r2), "r"(r3), "r"(r4), "r"(r5)
        : "memory", "cc"
    );
    return r0;
}

#else
#error "@syscall C99 backend: supported targets are Linux/Darwin x86-64, Linux/Darwin AArch64, and Linux ARM32 EABI. Other OS/arch need a backend."
#endif


static __attribute__((used)) int32_t launcher_is_external_cmd(uint8_t * name);
static __attribute__((used)) int32_t launcher_get_dir(uint8_t * argv0, uint8_t * buffer, size_t buffer_size);
static __attribute__((used)) int32_t launcher_build_cmd_path(uint8_t * command_name, uint8_t * out, size_t out_cap);
static __attribute__((used)) int32_t launcher_dispatch_external_cmd(uint8_t * command_name);
static __attribute__((used)) void launcher_print_help(uint8_t * program_name);
static __attribute__((used)) int32_t launcher_print_compat_diagnostic(uint8_t * program_name);
static __attribute__((used)) int32_t launcher_print_microapp_image_migration(uint8_t * program_name, uint8_t * old_command, uint8_t * new_command);
int32_t main_main();
extern int32_t main_main();
void std_runtime_entry_set_process_stack_limit_bytes(uint64_t limit_bytes);
extern int32_t main(int32_t argc, char **argv);
int32_t std_runtime_get_argc();
uint8_t * std_runtime_get_argv(int32_t index);
int32_t std_runtime_ptr_diff(uint8_t * ptr1, uint8_t * ptr2);
static __attribute__((used)) void _heap_lock_acquire();
static __attribute__((used)) void _heap_lock_release();
static __attribute__((used)) size_t heap_align_up(size_t size);
static __attribute__((used)) bool is_null(void * ptr);
static __attribute__((used)) struct ChunkHeader * to_header(void * ptr);
static __attribute__((used)) void * to_user_ptr(struct ChunkHeader * hdr);
static __attribute__((used)) bool owns_ptr(void * ptr);
static __attribute__((used)) bool is_free(struct ChunkHeader * hdr);
static __attribute__((used)) void set_free(struct ChunkHeader * hdr, bool free);
static __attribute__((used)) size_t get_size(struct ChunkHeader * hdr);
static __attribute__((used)) void remove_free(struct FreeChunk * chunk);
static __attribute__((used)) void set_prev_link(struct FreeChunk * target, struct FreeChunk * prev);
static __attribute__((used)) void add_free(struct FreeChunk * chunk);
static __attribute__((used)) struct ChunkHeader * morecore(size_t needed);
static __attribute__((used)) struct FreeChunk * find_chunk(size_t needed);
static __attribute__((used)) void split_chunk(struct FreeChunk * chunk, size_t needed);
static __attribute__((used)) void * _malloc_impl(size_t size);
void * malloc(size_t size);
static __attribute__((used)) void _free_impl(void * ptr);
void free(void * ptr);
char * memcpy(char * dest, const char * src, size_t n);
static __attribute__((used,noinline)) void * _pthread_call_start(void * start_fn, void * start_arg);
static __attribute__((used)) void _pthread_run_tsd_destructors(struct pthread_desc * desc);
static __attribute__((used)) void _pthread_thread_exit(struct pthread_desc * desc, void * retval);
void libc__pthread_child_bootstrap(struct pthread_desc * desc);
int32_t libc_pthread_yield();
static __attribute__((used)) intptr_t _stdio_write_fail_isize();
int32_t flush_buffer(struct FILE * stream);
int64_t write_to_buffer(struct FILE * stream, const char * buf, size_t n);
static __attribute__((used)) size_t _fmt_f64_to_buf(uint8_t * buf, size_t buf_pos, size_t buf_max, double val, int32_t precision, int32_t force_scientific, int32_t scientific_uppercase, int32_t uppercase_inf_nan);
static __attribute__((used)) size_t _fmt_f64_hex_to_buf(uint8_t * buf, size_t buf_pos, size_t buf_max, double val, int32_t precision, int32_t uppercase);
int32_t fprintf(struct FILE * stream, const char * format, ...);
static __attribute__((used)) void _fmt_pad_spaces(struct _FmtContext * ctx, int32_t n);
static __attribute__((used)) void _fmt_pad_zeros(struct _FmtContext * ctx, int32_t n);
static __attribute__((used)) void _fmt_copy_to_ctx(struct _FmtContext * ctx, uint8_t * temp, size_t temp_len);
static __attribute__((used)) void _fmt_apply_padding(struct _FmtContext * ctx, uint8_t * temp, size_t temp_len, int32_t width, int32_t left_align, int32_t zero_pad);
static __attribute__((used)) void _fmt_i32_to_buf_full(struct _FmtContext * ctx, int32_t value, int32_t flags, int32_t precision);
static __attribute__((used)) void _fmt_u32_hex_to_buf_prefix(struct _FmtContext * ctx, uint32_t value, int32_t uppercase, int32_t hash);
static __attribute__((used)) void _fmt_u32_octal_to_buf(struct _FmtContext * ctx, uint32_t value);
static __attribute__((used)) void _fmt_u64_hex_to_buf(struct _FmtContext * ctx, uint64_t value, int32_t uppercase);
static __attribute__((used)) void _fmt_u64_octal_to_buf(struct _FmtContext * ctx, uint64_t value);
static __attribute__((used)) void _fmt_str_to_buf_limited(struct _FmtContext * ctx, const uint8_t * s, int32_t precision);
static __attribute__((used)) int32_t _vfprintf_impl(struct FILE * stream, const uint8_t * format, va_list ap, int32_t use_buf, uint8_t * out_buf, size_t buf_size);
static __attribute__((used)) void _fmt_u32_to_buf(struct _FmtContext * ctx, uint32_t value);
static __attribute__((used)) void _fmt_u64_to_buf(struct _FmtContext * ctx, uint64_t value);
int32_t vfprintf(struct FILE * stream, const char * format, va_list ap);
int32_t vsnprintf(char * buf, size_t n, const char * format, va_list ap);
int32_t snprintf(char * buf, size_t n, const char * format, ...);
int32_t readlink(const char * path, char * buf, size_t bufsiz);
size_t strlen(const char * s);
int32_t strcmp(const char * s1, const char * s2);
char * strrchr(const char * s, int32_t c);
struct err_union_intptr_t sys_write(int32_t fd, const char * buf, size_t count);
void sys_exit(int32_t status);
struct err_union_int32_t sys_access(const char * pathname, int32_t mode);
struct err_union_voidptr sys_mmap(void * addr, size_t length, int32_t prot, int32_t flags, int32_t fd, int64_t offset);
int32_t sys_futex(int32_t * uaddr, int32_t op, int32_t val, void * timeout);
struct err_union_intptr_t sys_readlink(const char * pathname, char * buf, size_t bufsiz);
struct err_union_int32_t sys_execve(const char * path, const char * * argv, const char * * envp);
int32_t execve(const char * pathname, char * * argv, char * * envp);
int32_t access(const char * pathname, int32_t mode);

extern struct FILE _stdin, _stdout, _stderr;
__attribute__((used)) const size_t PATH_MAX = 4096ULL;

__attribute__((used)) const int32_t ENTRY_RLIMIT_STACK = 3;

__attribute__((used)) const uint64_t ENTRY_DEFAULT_STACK_LIMIT_BYTES = /* optimized */ 67108864;

int32_t saved_argc = 0;
uint8_t * * saved_argv = NULL;
uint8_t * * saved_envp = NULL;
const int32_t libc_EPERM = 1;
const int32_t libc_ENOENT = 2;
const int32_t libc_ESRCH = 3;
const int32_t libc_EINTR = 4;
const int32_t libc_EIO = 5;
const int32_t libc_ENXIO = 6;
const int32_t libc_E2BIG = 7;
const int32_t libc_ENOEXEC = 8;
const int32_t libc_EBADF = 9;
const int32_t libc_ECHILD = 10;
const int32_t libc_ENOMEM = 12;
const int32_t libc_EACCES = 13;
const int32_t libc_EFAULT = 14;
const int32_t libc_ENOTBLK = 15;
const int32_t libc_EBUSY = 16;
const int32_t libc_EEXIST = 17;
const int32_t libc_EXDEV = 18;
const int32_t libc_ENODEV = 19;
const int32_t libc_ENOTDIR = 20;
const int32_t libc_EISDIR = 21;
const int32_t libc_EINVAL = 22;
const int32_t libc_ENFILE = 23;
const int32_t libc_EMFILE = 24;
const int32_t libc_ENOTTY = 25;
const int32_t libc_ETXTBSY = 26;
const int32_t libc_EFBIG = 27;
const int32_t libc_ENOSPC = 28;
const int32_t libc_ESPIPE = 29;
const int32_t libc_EROFS = 30;
const int32_t libc_EMLINK = 31;
const int32_t libc_EPIPE = 32;
const int32_t libc_EDOM = 33;
const int32_t libc_ERANGE = 34;
const int32_t libc_EDEADLK = 35;
const int32_t libc_ENAMETOOLONG = 36;
const int32_t libc_ENOLCK = 37;
const int32_t libc_ENOSYS = 38;
const int32_t libc_ENOTEMPTY = 39;
const int32_t libc_ELOOP = 40;
const int32_t libc_EWOULDBLOCK = 11;
const int32_t libc_ENOMSG = 42;
const int32_t libc_EIDRM = 43;
const int32_t libc_EILSEQ = 84;
const int32_t libc_EAGAIN = 11;
const int32_t libc_ENOTSOCK = 88;
const int32_t libc_EDESTADDRREQ = 89;
const int32_t libc_EMSGSIZE = 90;
const int32_t libc_EPROTOTYPE = 91;
const int32_t libc_ENOPROTOOPT = 92;
const int32_t libc_EPROTONOSUPPORT = 93;
const int32_t libc_ESOCKTNOSUPPORT = 94;
const int32_t libc_EOPNOTSUPP = 95;
const int32_t libc_EPFNOSUPPORT = 96;
const int32_t libc_EAFNOSUPPORT = 97;
const int32_t libc_EADDRINUSE = 98;
const int32_t libc_EADDRNOTAVAIL = 99;
const int32_t libc_ENETDOWN = 100;
const int32_t libc_ENETUNREACH = 101;
const int32_t libc_ENETRESET = 102;
const int32_t libc_ECONNABORTED = 103;
const int32_t libc_ECONNRESET = 104;
const int32_t libc_ENOBUFS = 105;
const int32_t libc_EISCONN = 106;
const int32_t libc_ENOTCONN = 107;
const int32_t libc_ESHUTDOWN = 108;
const int32_t libc_ETIMEDOUT = 110;
const int32_t libc_ECONNREFUSED = 111;
const int32_t libc_EHOSTDOWN = 112;
const int32_t libc_EHOSTUNREACH = 113;
const int32_t libc_EALREADY = 114;
const int32_t libc_EINPROGRESS = 115;
int32_t libc_errno = 0;
__attribute__((used)) const int32_t HEAP_ATOMIC_SEQ_CST = 5;

__attribute__((used)) const size_t MALLOC_ALIGN = 16;

__attribute__((used)) const size_t MIN_CHUNK_SIZE = 64;

__attribute__((used)) const size_t HEAP_PAGE_SIZE = 4096;

__attribute__((used)) const uint64_t CHUNK_MAGIC = ((int64_t)(uint32_t)0xDEADBEEFULL + ((int64_t)(uint32_t)0x0ULL << 32));

__attribute__((used)) const int32_t HEAP_MAP_PRIVATE = 2;

__attribute__((used)) const int32_t HEAP_PROT_READ = 1;

__attribute__((used)) const int32_t HEAP_PROT_WRITE = 2;

__attribute__((used)) const int32_t HEAP_MAP_ANONYMOUS = 32;

const double libc_E = 2.71828182845904509;
const double libc_PI = 3.14159265358979311;
const double libc_PI_2 = 1.57079632679489655;
const double libc_PI_4 = 0.78539816339744819;
const double libc_TWO_PI = 6.28318530717958623;
const double libc_SQRT2 = 1.41421356237309510;
const double libc_SQRT1_2 = 0.70710678118654737;
const double libc_LN2 = 0.69314718055994521;
const double libc_LN10 = 2.30258509299404590;
const double libc_INFINITY = 1.79769313486231530e+308;
const double libc_NAN = 0.00000000000000000;
const double libc_HUGE_VAL = 1.79769313486231530e+308;
const float libc_HUGE_VALF = (float)libc_INFINITY;
const double libc_HUGE_VALL = 1.79769313486231530e+308;
__attribute__((used)) const int32_t PTHREAD_ATOMIC_SEQ_CST = 5;

__attribute__((used)) const size_t PTHREAD_STACK_SIZE = /* optimized */ 8388608;

__attribute__((used)) const int64_t CLONE_FLAGS = 1380096;

__attribute__((used)) const int32_t PTHREAD_JOINSTATE_JOINABLE = 0;

__attribute__((used)) const int32_t PTHREAD_JOINSTATE_EXITED = 1;

__attribute__((used)) const int32_t PTHREAD_JOINSTATE_JOINED = 2;

__attribute__((used)) const int32_t PTHREAD_JOINSTATE_DETACHED = 3;

__attribute__((used)) const int32_t PTHREAD_DESTRUCTOR_ITERATIONS = 4;

__attribute__((used)) const size_t PTHREAD_MAX_THREADS = 1024;

const int32_t libc_PTHREAD_MUTEX_NORMAL = 0;
const int32_t libc_PTHREAD_MUTEX_RECURSIVE = 1;
const int32_t libc_PTHREAD_MUTEX_ERRORCHECK = 2;
const int32_t libc_PTHREAD_CREATE_JOINABLE = 0;
const int32_t libc_PTHREAD_CREATE_DETACHED = 1;
const int32_t libc_CLOCK_REALTIME = 0;
const int32_t libc_CLOCK_MONOTONIC = 1;
__attribute__((used)) const size_t PTHREAD_KEYS_MAX = 1024;

const int32_t libc_PTHREAD_CANCEL_ENABLE = 0;
const int32_t libc_PTHREAD_CANCEL_DISABLE = 1;
const int32_t libc_PTHREAD_CANCEL_DEFERRED = 0;
const int32_t libc_PTHREAD_CANCEL_ASYNCHRONOUS = 1;
void * libc_PTHREAD_CANCELED = (void *)(int64_t)(-1);
const int32_t libc_PTHREAD_BARRIER_SERIAL_THREAD = 1;
const size_t libc__JB_SIZE = 8;
const size_t libc__JB_SIG_SIZE = 16;
const int32_t libc_SIGHUP = 1;
const int32_t libc_SIGINT = 2;
const int32_t libc_SIGQUIT = 3;
const int32_t libc_SIGILL = 4;
const int32_t libc_SIGTRAP = 5;
const int32_t libc_SIGABRT = 6;
const int32_t libc_SIGIOT = 6;
const int32_t libc_SIGBUS = 7;
const int32_t libc_SIGFPE = 8;
const int32_t libc_SIGKILL = 9;
const int32_t libc_SIGUSR1 = 10;
const int32_t libc_SIGSEGV = 11;
const int32_t libc_SIGUSR2 = 12;
const int32_t libc_SIGPIPE = 13;
const int32_t libc_SIGALRM = 14;
const int32_t libc_SIGTERM = 15;
const int32_t libc_SIGSTKFLT = 16;
const int32_t libc_SIGCHLD = 17;
const int32_t libc_SIGCONT = 18;
const int32_t libc_SIGSTOP = 19;
const int32_t libc_SIGTSTP = 20;
const int32_t libc_SIGTTIN = 21;
const int32_t libc_SIGTTOU = 22;
const int32_t libc_SIGURG = 23;
const int32_t libc_SIGXCPU = 24;
const int32_t libc_SIGXFSZ = 25;
const int32_t libc_SIGVTALRM = 26;
const int32_t libc_SIGPROF = 27;
const int32_t libc_SIGWINCH = 28;
const int32_t libc_SIGPOLL = 29;
const int32_t libc_SIGIO = 29;
const int32_t libc_SIGPWR = 30;
const int32_t libc_SIGSYS = 31;
const int32_t libc_NSIG = 65;
const int32_t libc_SIG_BLOCK = 0;
const int32_t libc_SIG_UNBLOCK = 1;
const int32_t libc_SIG_SETMASK = 2;
const size_t libc_SIG_DFL = 0;
const size_t libc_SIG_IGN = 1;
const size_t libc_SIG_ERR = ((int64_t)(uint32_t)0xFFFFFFFFULL + ((int64_t)(uint32_t)0x0ULL << 32));
__attribute__((used)) const int64_t SYS_rt_sigaction = 13;

__attribute__((used)) const int64_t SYS_rt_sigprocmask = 14;

__attribute__((used)) const int64_t SYS_rt_sigpending = 127;

__attribute__((used)) const int64_t SYS_rt_sigsuspend = 130;

__attribute__((used)) const int64_t SYS_kill_sig = 62;

__attribute__((used)) const int64_t SYS_tgkill = 234;

__attribute__((used)) const int64_t SYS_alarm = 37;

__attribute__((used)) const int64_t SYS_pause = 34;

__attribute__((used)) const size_t ATEXIT_MAX = 32;

struct FILE * stdin = (&_stdin);
struct FILE * stdout = (&_stdout);
struct FILE * stderr = (&_stderr);
const int64_t libc_STDIN = 0;
const int64_t libc_STDOUT = 1;
const int64_t libc_STDERR = 2;
__attribute__((used)) const int64_t _FOPEN_W_FLAGS = ((1 | 64) | 512);

__attribute__((used)) const int64_t _FOPEN_A_FLAGS = ((1 | 64) | 1024);

__attribute__((used)) const int64_t _FOPEN_W_PLUS_FLAGS = ((2 | 64) | 512);

__attribute__((used)) const int64_t _FOPEN_A_PLUS_FLAGS = ((2 | 64) | 1024);

__attribute__((used)) const size_t _VSPRINTF_BUF_CAP = 2147483647;

__attribute__((used)) const int32_t _FMT_MINUS = 1;

__attribute__((used)) const int32_t _FMT_PLUS = 2;

__attribute__((used)) const int32_t _FMT_SPACE = 4;

__attribute__((used)) const int32_t _FMT_ZERO = 8;

__attribute__((used)) const int32_t _FMT_HASH = 16;

__attribute__((used)) const int32_t _TMPFILE_O_FLAGS = 194;

__attribute__((used)) const int32_t _TMPFILE_MODE = 384;

const int32_t libc_RAND_MAX = 0;
const int64_t CLOCKS_PER_SEC = 1000000;
__attribute__((used)) const size_t READDIR_BUF_SIZE = 8192;

const int64_t libc_AT_FDCWD = (-100);
const int32_t libc_AT_REMOVEDIR = 512;
const int32_t libc_AT_SYMLINK_NOFOLLOW = 256;
const int64_t libc_SYS_read = 0;
const int64_t libc_SYS_write = 1;
const int64_t libc_SYS_writev = 20;
const int64_t libc_SYS_open = 2;
const int64_t libc_SYS_close = 3;
const int64_t libc_SYS_stat = 4;
const int64_t libc_SYS_fstat = 5;
const int64_t libc_SYS_lstat = 6;
const int64_t libc_SYS_lseek = 8;
const int64_t libc_SYS_mmap = 9;
const int64_t libc_SYS_munmap = 11;
const int64_t libc_SYS_mprotect = 10;
const int64_t libc_SYS_brk = 12;
const int64_t libc_SYS_ioctl = 16;
const int64_t libc_SYS_access = 21;
const int64_t libc_SYS_dup = 32;
const int64_t libc_SYS_dup2 = 33;
const int64_t libc_SYS_dup3 = 292;
const int64_t libc_SYS_getpid = 39;
const int64_t libc_SYS_getppid = 110;
const int64_t libc_SYS_fork = 57;
const int64_t libc_SYS_execve = 59;
const int64_t libc_SYS_exit = 60;
const int64_t libc_SYS_waitpid = 61;
const int64_t libc_SYS_kill = 62;
const int64_t libc_SYS_tgkill = 234;
const int64_t libc_SYS_getcwd = 79;
const int64_t libc_SYS_chdir = 80;
const int64_t libc_SYS_mkdir = 83;
const int64_t libc_SYS_rmdir = 84;
const int64_t libc_SYS_unlink = 87;
const int64_t libc_SYS_rename = 82;
const int64_t libc_SYS_readlink = 89;
const int64_t libc_SYS_getdents64 = 217;
const int64_t libc_SYS_setrlimit = 160;
const int64_t libc_SYS_getrlimit = 97;
const int64_t libc_SYS_clone = 56;
const int64_t libc_SYS_futex = 202;
const int64_t libc_SYS_set_tid_address = 218;
const int64_t libc_SYS_eventfd = 290;
const int64_t libc_SYS_sched_setaffinity = 203;
const int64_t libc_SYS_sched_getaffinity = 204;
const int64_t libc_SYS_sched_yield = 24;
const int64_t libc_SYS_nanosleep = 35;
const int64_t libc_SYS_clock_gettime = 228;
const int64_t libc_SYS_gettimeofday = 96;
const int64_t libc_SYS_fcntl = 72;
const int64_t libc_SYS_pipe2 = 293;
const int64_t libc_SYS_socket = 41;
const int64_t libc_SYS_bind = 49;
const int64_t libc_SYS_listen = 50;
const int64_t libc_SYS_accept = 43;
const int64_t libc_SYS_connect = 42;
const int64_t libc_SYS_send = 44;
const int64_t libc_SYS_recv = 45;
const int64_t libc_SYS_sendto = 44;
const int64_t libc_SYS_recvfrom = 45;
const int64_t libc_SYS_shutdown = 48;
const int64_t libc_SYS_setsockopt = 54;
const int64_t libc_SYS_getsockopt = 55;
const int64_t libc_SYS_getsockname = 51;
const int64_t libc_SYS_getpeername = 52;
const int64_t libc_SYS_openat = 257;
const int64_t libc_SYS_newfstatat = 262;
const int64_t libc_SYS_faccessat = 269;
const int64_t libc_SYS_unlinkat = 263;
const int64_t libc_SYS_mkdirat = 258;
const int64_t libc_SYS_renameat = 264;
const int64_t libc_SYS_readlinkat = 267;
const int64_t libc_SYS_epoll_create1 = 291;
const int64_t libc_SYS_epoll_ctl = 233;
const int64_t libc_SYS_epoll_wait = 232;
const int64_t libc_SYS_epoll_pwait = 281;
const int64_t libc_SYS_getuid = 102;
const int64_t libc_SYS_getgid = 104;
const int64_t libc_SYS_setuid = 105;
const int64_t libc_SYS_setgid = 106;
const int64_t libc_SYS_geteuid = 107;
const int64_t libc_SYS_getegid = 108;
const int64_t libc_SYS_gettid = 186;
const int32_t libc_AF_INET = 2;
const int32_t libc_AF_INET6 = 10;
const int32_t libc_SOCK_STREAM = 1;
const int32_t libc_SOCK_DGRAM = 2;
const int32_t libc_IPPROTO_TCP = 6;
const int32_t libc_IPPROTO_UDP = 17;
const int32_t libc_SHUT_RD = 0;
const int32_t libc_SHUT_WR = 1;
const int32_t libc_SHUT_RDWR = 2;
const int32_t libc_SOL_SOCKET = 1;
const int32_t libc_SO_REUSEADDR = 2;
const int32_t libc_SO_REUSEPORT = 15;
const int32_t libc_SO_SNDBUF = 7;
const int32_t libc_TCP_NODELAY = 1;
const int32_t libc_SO_RCVTIMEO = 20;
const int32_t libc_SO_SNDTIMEO = 21;
const int32_t libc_FUTEX_WAIT = 0;
const int32_t libc_FUTEX_WAKE = 1;
const int32_t libc_FUTEX_WAIT_PRIVATE = 128;
const int32_t libc_FUTEX_WAKE_PRIVATE = 129;
const int32_t libc_FUTEX_WAIT_BITSET = 9;
const int32_t libc_FUTEX_WAKE_BITSET = 10;
const int32_t libc_FUTEX_CLOCK_REALTIME = 256;
const int64_t libc_CLONE_VM = 256;
const int64_t libc_CLONE_FS = 512;
const int64_t libc_CLONE_FILES = 1024;
const int64_t libc_CLONE_SIGHAND = 2048;
const int64_t libc_CLONE_THREAD = 65536;
const int64_t libc_CLONE_SYSVSEM = 262144;
const int64_t libc_CLONE_SETTLS = 524288;
const int64_t libc_CLONE_PARENT_SETTID = 1048576;
const int64_t libc_CLONE_CHILD_CLEARTID = 2097152;
const int64_t libc_O_RDONLY = 0;
const int64_t libc_O_WRONLY = 1;
const int64_t libc_O_RDWR = 2;
const int64_t libc_O_CREAT = 64;
const int64_t libc_O_EXCL = 128;
const int64_t libc_O_TRUNC = 512;
const int64_t libc_O_APPEND = 1024;
const int64_t libc_O_DIRECTORY = 65536;
const int32_t libc_O_NONBLOCK = 2048;
const int32_t libc_O_CLOEXEC = 524288;
const int32_t libc_EFD_SEMAPHORE = 1;
const int32_t libc_EFD_NONBLOCK = 2048;
const int32_t libc_EFD_CLOEXEC = 524288;
const int32_t libc_F_DUPFD = 0;
const int32_t libc_F_GETFD = 1;
const int32_t libc_F_SETFD = 2;
const int32_t libc_F_GETFL = 3;
const int32_t libc_F_SETFL = 4;
const int32_t libc_F_GETPATH = 0;
const int32_t libc_F_DUPFD_CLOEXEC = 1030;
const int32_t libc_FD_CLOEXEC = 1;
const int32_t libc_EPOLLIN = 1;
const int32_t libc_EPOLLOUT = 4;
const int32_t libc_EPOLL_CTL_ADD = 1;
const int32_t libc_EPOLL_CTL_DEL = 2;
const int32_t libc_EPOLL_CTL_MOD = 3;
const int32_t libc_EPOLL_CLOEXEC = 524288;
const int64_t libc_S_IRWXU = 448;
const int64_t libc_S_IRUSR = 256;
const int64_t libc_S_IWUSR = 128;
const int64_t libc_S_IXUSR = 64;
const int64_t libc_S_IRWXG = 56;
const int64_t libc_S_IRGRP = 32;
const int64_t libc_S_IWGRP = 16;
const int64_t libc_S_IXGRP = 8;
const int64_t libc_S_IRWXO = 7;
const int64_t libc_S_IROTH = 4;
const int64_t libc_S_IWOTH = 2;
const int64_t libc_S_IXOTH = 1;
const int64_t libc_UYA_STDIN_FILENO = 0;
const int64_t libc_UYA_STDOUT_FILENO = 1;
const int64_t libc_UYA_STDERR_FILENO = 2;
const int32_t libc_MAP_SHARED = 1;
const int32_t libc_MAP_PRIVATE = 2;
const int32_t libc_MAP_ANONYMOUS = 32;
const int32_t libc_PROT_READ = 1;
const int32_t libc_PROT_WRITE = 2;
const int32_t libc_PROT_EXEC = 4;
const int32_t libc_RLIMIT_STACK = 3;
__attribute__((used)) const int32_t DAYS_IN_MONTH[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

__attribute__((used)) const uint8_t * _WDAY_ABBREV[7] = {(const uint8_t *)"Sun", (const uint8_t *)"Mon", (const uint8_t *)"Tue", (const uint8_t *)"Wed", (const uint8_t *)"Thu", (const uint8_t *)"Fri", (const uint8_t *)"Sat"};

__attribute__((used)) const uint8_t * _WDAY_FULL[7] = {(const uint8_t *)"Sunday", (const uint8_t *)"Monday", (const uint8_t *)"Tuesday", (const uint8_t *)"Wednesday", (const uint8_t *)"Thursday", (const uint8_t *)"Friday", (const uint8_t *)"Saturday"};

__attribute__((used)) const uint8_t * _MON_ABBREV[12] = {(const uint8_t *)"Jan", (const uint8_t *)"Feb", (const uint8_t *)"Mar", (const uint8_t *)"Apr", (const uint8_t *)"May", (const uint8_t *)"Jun", (const uint8_t *)"Jul", (const uint8_t *)"Aug", (const uint8_t *)"Sep", (const uint8_t *)"Oct", (const uint8_t *)"Nov", (const uint8_t *)"Dec"};

__attribute__((used)) const uint8_t * _MON_FULL[12] = {(const uint8_t *)"January", (const uint8_t *)"February", (const uint8_t *)"March", (const uint8_t *)"April", (const uint8_t *)"May", (const uint8_t *)"June", (const uint8_t *)"July", (const uint8_t *)"August", (const uint8_t *)"September", (const uint8_t *)"October", (const uint8_t *)"November", (const uint8_t *)"December"};

const int32_t libc_STDIN_FILENO = 0;
const int32_t libc_STDOUT_FILENO = 1;
const int32_t libc_STDERR_FILENO = 2;
const int32_t libc_SEEK_SET = 0;
const int32_t libc_SEEK_CUR = 1;
const int32_t libc_SEEK_END = 2;
const int32_t libc_F_OK = 0;
const int32_t libc_R_OK = 4;
const int32_t libc_W_OK = 2;
const int32_t libc_X_OK = 1;
const size_t libc_PATH_MAX = 4096;
const wint_t libc_WEOF = (0 - 1);
__attribute__((used)) _Atomic(int32_t) _heap_lock = 0;

__attribute__((used)) struct FreeChunk * free_list_head = NULL;

__attribute__((used)) struct HeapRegion * heap_regions = NULL;

__attribute__((used)) int32_t _remquo_quo = 0;

__attribute__((used)) struct pthread_desc * _pthread_child_desc = NULL;

__attribute__((used)) void * _pthread_start_fn_tmp = NULL;

__attribute__((used)) void * _pthread_start_arg_tmp = NULL;

__attribute__((used)) struct pthread_registry_entry _pthread_registry[1024] = {0};

__attribute__((used)) struct pthread_desc _pthread_main_desc = {.tid = 0, .stack = NULL, .stack_size = 0, .detached = 0, .exited = 0, .resources_released = 0, .started = 1, .result = NULL, .pub_handle = NULL, .start_routine = NULL, .arg = NULL, .joinstate = 0, .cancel_state = 0, .cancel_type = 0, .cancel_pending = 0, .tsd_values = NULL};

__attribute__((used)) struct pthread_t _pthread_main_handle = {.tid = 0, .stack = NULL, .stack_size = 0, .detached = 0, .exited = 0, .result = NULL, .start_routine = NULL, .arg = NULL};

__attribute__((used)) _Atomic(int32_t) _pthread_main_initialized = 0;

__attribute__((used)) struct pthread_mutex_t _pthread_create_mutex = {.state = 0, .owner = 0, .type = 0};

__attribute__((used)) struct pthread_mutex_t _cond_mutex = {.state = 0, .owner = 0, .type = 0};

__attribute__((used)) struct pthread_key_t * _pthread_keys = (struct pthread_key_t *)NULL;

__attribute__((used)) struct pthread_mutex_t _pthread_key_mutex = {.state = 0, .owner = 0, .type = 0};

__attribute__((used)) int32_t _pthread_key_next = 0;

__attribute__((used)) int32_t _pthread_key_count = 0;

__attribute__((used)) void * _signal_handlers[65] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};

__attribute__((used)) void * _atexit_handlers[32] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};

__attribute__((used)) size_t _atexit_count = 0;

__attribute__((used)) void * _on_exit_handler = NULL;

__attribute__((used)) void * _on_exit_arg = NULL;

__attribute__((used)) struct FILE _stdin = {.fd = 0, .buf_pos = 0, .buf_len = 0, .buf_mode = 0};

__attribute__((used)) struct FILE _stdout = {.fd = 1, .buf_pos = 0, .buf_len = 0, .buf_mode = 1};

__attribute__((used)) struct FILE _stderr = {.fd = 2, .buf_pos = 0, .buf_len = 0, .buf_mode = 0};

__attribute__((used)) struct FILE fopen_fd_storage[128] = {0};

__attribute__((used)) int32_t _tmpfile_counter = 0;

__attribute__((used)) struct FILE _file_storage[16] = {0};

__attribute__((used)) size_t _file_storage_idx = 0;

__attribute__((used)) int64_t rand_seed = 1;

__attribute__((used)) int64_t rand_max_val = 2147483647;

__attribute__((used)) struct DirState opendir_storage[64] = {0};

__attribute__((used)) struct Dirent readdir_result = {.d_ino = 0, .d_off = 0, .d_reclen = 0, .d_type = 0, .d_name = {0}};

__attribute__((used)) uint8_t * _strtok_saved = NULL;

__attribute__((used)) clock_t _clock_start = 0;

__attribute__((used)) struct tm _gmtime_result = {.tm_sec = 0, .tm_min = 0, .tm_hour = 0, .tm_mday = 0, .tm_mon = 0, .tm_year = 0, .tm_wday = 0, .tm_yday = 0, .tm_isdst = 0};

__attribute__((used)) uint8_t _asctime_buf[26] = {0};

static __attribute__((used)) int32_t launcher_is_external_cmd(uint8_t * name) {
    (void)name;
    if (name == NULL) {
                {
            int32_t _uya_ret = 0;
            return _uya_ret;
                }
    }
    if (strcmp((const char *)(uint8_t *)name, (const char *)(uint8_t *)(uint8_t *)str0) == 0) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    if (strcmp((const char *)(uint8_t *)name, (const char *)(uint8_t *)(uint8_t *)str1) == 0) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    if (strcmp((const char *)(uint8_t *)name, (const char *)(uint8_t *)(uint8_t *)str2) == 0) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    if (strcmp((const char *)(uint8_t *)name, (const char *)(uint8_t *)(uint8_t *)str3) == 0) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    if (strcmp((const char *)(uint8_t *)name, (const char *)(uint8_t *)(uint8_t *)str4) == 0) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    if (strcmp((const char *)(uint8_t *)name, (const char *)(uint8_t *)(uint8_t *)str5) == 0) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    if (strcmp((const char *)(uint8_t *)name, (const char *)(uint8_t *)(uint8_t *)str6) == 0) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
        {
        int32_t _uya_ret = 0;
        return _uya_ret;
        }
}

static __attribute__((used)) int32_t launcher_get_dir(uint8_t * argv0, uint8_t * buffer, size_t buffer_size) {
    (void)argv0;
    (void)buffer;
    (void)buffer_size;
    if ((((argv0 == NULL) || (buffer == NULL)) || (buffer_size == 0ULL))) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    uint8_t * const argv_slash = (uint8_t *)strrchr((const char *)(uint8_t *)argv0, 47);
    if (argv_slash != NULL) {
        struct err_union_size_t dir_len_tmp = ({ struct err_union_size_t _uya_asbang = { .error_id = 0, .value = (size_t)(std_runtime_ptr_diff((uint8_t *)argv_slash, (uint8_t *)argv0)) }; _uya_asbang; });
        const size_t dir_len = dir_len_tmp.value;
        if ((dir_len + 1ULL) < buffer_size) {
            (void)((uint8_t *)memcpy((char *)(uint8_t *)buffer, (const char *)(const uint8_t *)argv0, dir_len)            );
            buffer[dir_len] = (uint8_t)47;
            buffer[(dir_len + 1ULL)] = (uint8_t)0;
                        {
                int32_t _uya_ret = 0;
                return _uya_ret;
                        }
        }
    }
    uint8_t resolved_path[4096] = {0};
    const int32_t len = readlink((const char *)(uint8_t *)(uint8_t *)str7, (char *)(&resolved_path[0]), (PATH_MAX - 1ULL));
    if (len != (-1)) {
        resolved_path[(size_t)len] = (uint8_t)0;
        uint8_t * const last_slash = (uint8_t *)strrchr((const char *)(&resolved_path[0]), 47);
        if (last_slash != NULL) {
            struct err_union_size_t dir_len2_tmp = ({ struct err_union_size_t _uya_asbang = { .error_id = 0, .value = (size_t)(std_runtime_ptr_diff((uint8_t *)last_slash, (uint8_t *)(&resolved_path[0]))) }; _uya_asbang; });
            const size_t dir_len2 = dir_len2_tmp.value;
            if ((dir_len2 + 1ULL) < buffer_size) {
                (void)((uint8_t *)memcpy((char *)(uint8_t *)buffer, (const char *)(const uint8_t *)(&resolved_path[0]), dir_len2)                );
                buffer[dir_len2] = (uint8_t)47;
                buffer[(dir_len2 + 1ULL)] = (uint8_t)0;
                                {
                    int32_t _uya_ret = 0;
                    return _uya_ret;
                                }
            }
        }
    }
    if (buffer_size > 2ULL) {
        buffer[0] = (uint8_t)46;
        buffer[1] = (uint8_t)47;
        buffer[2] = (uint8_t)0;
                {
            int32_t _uya_ret = 0;
            return _uya_ret;
                }
    }
        {
        int32_t _uya_ret = 1;
        return _uya_ret;
        }
}

static __attribute__((used)) int32_t launcher_build_cmd_path(uint8_t * command_name, uint8_t * out, size_t out_cap) {
    (void)command_name;
    (void)out;
    (void)out_cap;
    if (((((command_name == NULL) || (command_name[0] == (uint8_t)0)) || (out == NULL)) || (out_cap == 0ULL))) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    uint8_t * const argv0 = std_runtime_get_argv(0);
    if (argv0 == NULL) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    uint8_t compiler_dir[4096] = {0};
    if (launcher_get_dir((uint8_t *)argv0, (uint8_t *)(&compiler_dir[0]), PATH_MAX) != 0) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    const int32_t written = snprintf((char *)(uint8_t *)out, out_cap, (const char *)str8, (uint8_t *)(&compiler_dir[0]), (uint8_t *)command_name);
    if (((written <= 0) || (written >= (int32_t)out_cap))) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
        {
        int32_t _uya_ret = 0;
        return _uya_ret;
        }
}

static __attribute__((used)) int32_t launcher_dispatch_external_cmd(uint8_t * command_name) {
    (void)command_name;
    uint8_t cmd_path[4096] = {0};
    if (launcher_build_cmd_path((uint8_t *)command_name, (uint8_t *)(&cmd_path[0]), PATH_MAX) != 0) {
        (void)(fprintf(stderr, (const char *)str9, (uint8_t *)command_name)        );
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    if (access((const char *)(const uint8_t *)(&cmd_path[0]), libc_X_OK) != 0) {
        (void)(fprintf(stderr, (const char *)str10, (uint8_t *)(&cmd_path[0]))        );
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    const int32_t argc = std_runtime_get_argc();
    int32_t arg_index = 2;
    int32_t forwarded_argc = (argc - arg_index);
    if (forwarded_argc < 0) {
        forwarded_argc = 0;
    }
    const int32_t dispatch_argc = (forwarded_argc + 1);
    const size_t argv_bytes = (/* optimized */ 8 * (size_t)(dispatch_argc + 1));
    uint8_t * * const dispatch_argv = (uint8_t * *)malloc(argv_bytes);
    if (dispatch_argv == NULL) {
        (void)(fprintf(stderr, (const char *)str11, (uint8_t *)command_name)        );
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    dispatch_argv[0] = (uint8_t *)(&cmd_path[0]);
    int32_t dst_index = 1;
    while (arg_index < argc) {
        uint8_t * const arg = std_runtime_get_argv(arg_index);
        if (arg == NULL) {
            (void)(fprintf(stderr, (const char *)str12, (uint8_t *)command_name, arg_index)            );
            (void)(free((void *)dispatch_argv)            );
                        {
                int32_t _uya_ret = 1;
                return _uya_ret;
                        }
        }
        dispatch_argv[dst_index] = (uint8_t *)arg;
        dst_index = (dst_index + 1);
        arg_index = (arg_index + 1);
    }
    dispatch_argv[dst_index] = NULL;
    uint8_t * empty_env[1] = {NULL};
    uint8_t * * envp = (uint8_t * *)(&empty_env[0]);
    if (saved_envp != NULL) {
        envp = (uint8_t * *)saved_envp;
    }
    (void)(execve((const char *)(const uint8_t *)(&cmd_path[0]), (char * *)dispatch_argv, (char * *)(uint8_t * *)envp)    );
    (void)(fprintf(stderr, (const char *)str13, (uint8_t *)(&cmd_path[0]))    );
    (void)(free((void *)dispatch_argv)    );
        {
        int32_t _uya_ret = 127;
        return _uya_ret;
        }
}

static __attribute__((used)) void launcher_print_help(uint8_t * program_name) {
    (void)program_name;
    uint8_t * name = program_name;
    if (name == NULL) {
        name = (uint8_t *)(uint8_t *)str14;
    }
    (void)(fprintf(stderr, (const char *)str15)    );
    (void)(fprintf(stderr, (const char *)str16)    );
    (void)(fprintf(stderr, (const char *)str17)    );
    (void)(fprintf(stderr, (const char *)str18, (uint8_t *)name)    );
    (void)(fprintf(stderr, (const char *)str19, (uint8_t *)name)    );
    (void)(fprintf(stderr, (const char *)str20, (uint8_t *)name)    );
    (void)(fprintf(stderr, (const char *)str21, (uint8_t *)name)    );
    (void)(fprintf(stderr, (const char *)str22, (uint8_t *)name)    );
    (void)(fprintf(stderr, (const char *)str23, (uint8_t *)name)    );
    (void)(fprintf(stderr, (const char *)str24, (uint8_t *)name)    );
    (void)(fprintf(stderr, (const char *)str25)    );
}

static __attribute__((used)) int32_t launcher_print_compat_diagnostic(uint8_t * program_name) {
    (void)program_name;
    uint8_t * name = program_name;
    if (name == NULL) {
        name = (uint8_t *)(uint8_t *)str14;
    }
    (void)(fprintf(stderr, (const char *)str26, (uint8_t *)name)    );
    (void)(fprintf(stderr, (const char *)str27)    );
        {
        int32_t _uya_ret = 1;
        return _uya_ret;
        }
}

static __attribute__((used)) int32_t launcher_print_microapp_image_migration(uint8_t * program_name, uint8_t * old_command, uint8_t * new_command) {
    (void)program_name;
    (void)old_command;
    (void)new_command;
    uint8_t * name = program_name;
    if (name == NULL) {
        name = (uint8_t *)(uint8_t *)str14;
    }
    (void)(fprintf(stderr, (const char *)str28, (uint8_t *)old_command, (uint8_t *)name, (uint8_t *)new_command)    );
    (void)(fprintf(stderr, (const char *)str29)    );
        {
        int32_t _uya_ret = 1;
        return _uya_ret;
        }
}


void std_runtime_entry_set_process_stack_limit_bytes(uint64_t limit_bytes) {
    (void)limit_bytes;
    struct EntryRLimit rlim = (struct EntryRLimit){.rlim_cur = limit_bytes, .rlim_max = limit_bytes};
    const int64_t SYS_setrlimit_x86_64 = 160;
    struct err_union_int64_t setrlimit_result_x86_64 = ({ long _uya_syscall_ret = uya_syscall2(SYS_setrlimit_x86_64, (int64_t)ENTRY_RLIMIT_STACK, (int64_t)(&rlim)); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    (void)(({ struct err_union_int64_t _uya_catch_tmp = setrlimit_result_x86_64; __typeof__(_uya_catch_tmp.value) _uya_catch_result; if (_uya_catch_tmp.error_id != 0) {
        _uya_catch_result = (0LL);
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; })    );
}

int32_t std_runtime_get_argc() {
        {
        int32_t _uya_ret = saved_argc;
        return _uya_ret;
        }
}

uint8_t * std_runtime_get_argv(int32_t index) {
    (void)index;
    if (((index < 0) || (index >= saved_argc))) {
                {
            uint8_t * _uya_ret = NULL;
            return _uya_ret;
                }
    }
    if (saved_argv == NULL) {
                {
            uint8_t * _uya_ret = NULL;
            return _uya_ret;
                }
    }
        {
        uint8_t * _uya_ret = saved_argv[index];
        return _uya_ret;
        }
}

int32_t std_runtime_ptr_diff(uint8_t * ptr1, uint8_t * ptr2) {
    (void)ptr1;
    (void)ptr2;
    if (((ptr1 == NULL) || (ptr2 == NULL))) {
                {
            int32_t _uya_ret = 0;
            return _uya_ret;
                }
    }
    const size_t addr1 = (uintptr_t)((void *)ptr1);
    const size_t addr2 = (uintptr_t)((void *)ptr2);
    if (addr1 >= addr2) {
                {
            int32_t _uya_ret = (int32_t)(addr1 - addr2);
            return _uya_ret;
                }
    } else {
                {
            int32_t _uya_ret = (0 - (int32_t)(addr2 - addr1));
            return _uya_ret;
                }
    }
        return 0;
}



static __attribute__((used)) void _heap_lock_acquire() {
    int32_t expected = 0;
    while (__atomic_compare_exchange_n((int32_t *)&_heap_lock, (&expected), 1, 0, HEAP_ATOMIC_SEQ_CST, HEAP_ATOMIC_SEQ_CST) == 0) {
        expected = 0;
    }
}

static __attribute__((used)) void _heap_lock_release() {
    __atomic_store_n((int32_t *)&_heap_lock, 0, __ATOMIC_SEQ_CST);
}

static __attribute__((used)) size_t heap_align_up(size_t size) {
    (void)size;
    if (size == 0) {
                {
            size_t _uya_ret = MALLOC_ALIGN;
            return _uya_ret;
                }
    }
    size_t q = (size / MALLOC_ALIGN);
    size_t r = (size - (q * MALLOC_ALIGN));
    if (r == 0) {
                {
            size_t _uya_ret = size;
            return _uya_ret;
                }
    }
        {
        size_t _uya_ret = ((q + 1) * MALLOC_ALIGN);
        return _uya_ret;
        }
}

static __attribute__((used)) bool is_null(void * ptr) {
    (void)ptr;
        {
        bool _uya_ret = ((size_t)(uint8_t *)ptr == 0);
        return _uya_ret;
        }
}

static __attribute__((used)) struct ChunkHeader * to_header(void * ptr) {
    (void)ptr;
        {
        struct ChunkHeader * _uya_ret = (struct ChunkHeader *)((uint8_t *)ptr - (int32_t)sizeof(struct ChunkHeader));
        return _uya_ret;
        }
}

static __attribute__((used)) void * to_user_ptr(struct ChunkHeader * hdr) {
    (void)hdr;
        {
        void * _uya_ret = (void *)((uint8_t *)hdr + (int32_t)sizeof(struct ChunkHeader));
        return _uya_ret;
        }
}

static __attribute__((used)) bool owns_ptr(void * ptr) {
    (void)ptr;
    const size_t addr = (size_t)ptr;
    struct HeapRegion * region = heap_regions;
    while ((!is_null((void *)region))) {
        const size_t base = (size_t)region->base;
        const size_t size = region->size;
        const size_t start = (base + (int32_t)sizeof(struct ChunkHeader));
        const size_t end = (base + size);
        if (((addr >= start) && (addr < end))) {
                        {
                bool _uya_ret = true;
                return _uya_ret;
                        }
        }
        region = region->next;
    }
        {
        bool _uya_ret = false;
        return _uya_ret;
        }
}

static __attribute__((used)) bool is_free(struct ChunkHeader * hdr) {
    (void)hdr;
        {
        bool _uya_ret = (((int64_t)hdr->size % (int64_t)2) != 0);
        return _uya_ret;
        }
}

static __attribute__((used)) void set_free(struct ChunkHeader * hdr, bool free) {
    (void)hdr;
    (void)free;
    size_t base = ((size_t)((int64_t)hdr->size / (int64_t)2) * 2);
    if (free) {
        hdr->size = (base + 1);
    } else {
        hdr->size = base;
    }
}

static __attribute__((used)) size_t get_size(struct ChunkHeader * hdr) {
    (void)hdr;
        {
        size_t _uya_ret = ((size_t)((int64_t)hdr->size / (int64_t)2) * 2);
        return _uya_ret;
        }
}

static __attribute__((used)) void remove_free(struct FreeChunk * chunk) {
    (void)chunk;
    if (is_null((void *)chunk)) {
        return;
    }
    if ((!is_null((void *)chunk->prev))) {
        chunk->prev->next = chunk->next;
    } else {
        free_list_head = chunk->next;
    }
    if ((!is_null((void *)chunk->next))) {
        chunk->next->prev = chunk->prev;
    }
}

static __attribute__((used)) void set_prev_link(struct FreeChunk * target, struct FreeChunk * prev) {
    (void)target;
    (void)prev;
    if (is_null((void *)target)) {
        return;
    }
    target->prev = prev;
}

static __attribute__((used)) void add_free(struct FreeChunk * chunk) {
    (void)chunk;
    if (is_null((void *)chunk)) {
        return;
    }
    (void)(set_free((&chunk->header), true)    );
    chunk->prev = NULL;
    chunk->next = free_list_head;
    (void)(set_prev_link(free_list_head, chunk)    );
    free_list_head = chunk;
}

static __attribute__((used)) struct ChunkHeader * morecore(size_t needed) {
    (void)needed;
    size_t alloc_size = (needed + (int32_t)sizeof(struct ChunkHeader));
    if (alloc_size < HEAP_PAGE_SIZE) {
        alloc_size = HEAP_PAGE_SIZE;
    }
    const size_t region_size_aligned = (((((int32_t)sizeof(struct HeapRegion) + MALLOC_ALIGN) - 1) / MALLOC_ALIGN) * MALLOC_ALIGN);
    const size_t map_size = (alloc_size + region_size_aligned);
    struct err_union_voidptr result = sys_mmap((void *)NULL, map_size, (HEAP_PROT_READ | HEAP_PROT_WRITE), (HEAP_MAP_PRIVATE | HEAP_MAP_ANONYMOUS), (0 - 1), 0);
    void * const mapped = ({ struct err_union_voidptr _uya_catch_tmp = result; __typeof__(_uya_catch_tmp.value) _uya_catch_result; if (_uya_catch_tmp.error_id != 0) {
                {
            struct ChunkHeader * _uya_ret = NULL;
            return _uya_ret;
                }
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
    if (mapped == NULL) {
                {
            struct ChunkHeader * _uya_ret = NULL;
            return _uya_ret;
                }
    }
    struct HeapRegion * region = (struct HeapRegion *)mapped;
    struct ChunkHeader * hdr = (struct ChunkHeader *)((uint8_t *)mapped + region_size_aligned);
    hdr->magic = CHUNK_MAGIC;
    hdr->size = alloc_size;
    (void)(set_free(hdr, true)    );
    region->base = hdr;
    region->size = alloc_size;
    region->next = heap_regions;
    heap_regions = region;
    struct FreeChunk * chunk = (struct FreeChunk *)hdr;
    chunk->prev = NULL;
    chunk->next = NULL;
        {
        struct ChunkHeader * _uya_ret = hdr;
        return _uya_ret;
        }
}

static __attribute__((used)) struct FreeChunk * find_chunk(size_t needed) {
    (void)needed;
    struct FreeChunk * cur = free_list_head;
    while ((!is_null((void *)cur))) {
        size_t sz = get_size((&cur->header));
        if (sz >= (needed + (int32_t)sizeof(struct ChunkHeader))) {
                        {
                struct FreeChunk * _uya_ret = cur;
                return _uya_ret;
                        }
        }
        cur = cur->next;
    }
        {
        struct FreeChunk * _uya_ret = NULL;
        return _uya_ret;
        }
}

static __attribute__((used)) void split_chunk(struct FreeChunk * chunk, size_t needed) {
    (void)chunk;
    (void)needed;
    struct ChunkHeader * hdr = (&chunk->header);
    size_t sz = get_size(hdr);
    size_t alloc_size = (needed + (int32_t)sizeof(struct ChunkHeader));
    size_t rem = (sz - alloc_size);
    if (rem >= (MIN_CHUNK_SIZE + (int32_t)sizeof(struct ChunkHeader))) {
        hdr->size = alloc_size;
        if (is_free(hdr)) {
            hdr->size = (alloc_size + 1);
        }
        struct ChunkHeader * new_hdr = (struct ChunkHeader *)((uint8_t *)hdr + alloc_size);
        new_hdr->magic = CHUNK_MAGIC;
        new_hdr->size = rem;
        (void)(set_free(new_hdr, true)        );
        struct FreeChunk * new_chunk = (struct FreeChunk *)new_hdr;
        new_chunk->prev = NULL;
        new_chunk->next = NULL;
        (void)(add_free(new_chunk)        );
    }
}

static __attribute__((used)) void * _malloc_impl(size_t size) {
    (void)size;
    if (size == 0) {
                {
            void * _uya_ret = NULL;
            return _uya_ret;
                }
    }
    size_t aligned = heap_align_up(size);
    if (aligned < MIN_CHUNK_SIZE) {
        aligned = MIN_CHUNK_SIZE;
    }
    struct FreeChunk * chunk = find_chunk(aligned);
    if (is_null((void *)chunk)) {
        struct ChunkHeader * hdr = morecore(aligned);
        if (is_null((void *)hdr)) {
                        {
                void * _uya_ret = NULL;
                return _uya_ret;
                        }
        }
        (void)(add_free((struct FreeChunk *)hdr)        );
        chunk = find_chunk(aligned);
    }
    if (is_null((void *)chunk)) {
                {
            void * _uya_ret = NULL;
            return _uya_ret;
                }
    }
    (void)(remove_free(chunk)    );
    (void)(set_free((&chunk->header), false)    );
    (void)(split_chunk(chunk, aligned)    );
        {
        void * _uya_ret = to_user_ptr((&chunk->header));
        return _uya_ret;
        }
}

__attribute__((used)) void * malloc(size_t size) {
    (void)size;
    (void)(_heap_lock_acquire()    );
    void * const result = _malloc_impl(size);
    (void)(_heap_lock_release()    );
        {
        void * _uya_ret = result;
        return _uya_ret;
        }
}

static __attribute__((used)) void _free_impl(void * ptr) {
    (void)ptr;
    if (is_null(ptr)) {
        return;
    }
    if ((!owns_ptr(ptr))) {
        return;
    }
    struct ChunkHeader * hdr = to_header(ptr);
    if (hdr->magic != CHUNK_MAGIC) {
        return;
    }
    struct FreeChunk * chunk = (struct FreeChunk *)hdr;
    (void)(add_free(chunk)    );
}

__attribute__((used)) void free(void * ptr) {
    (void)ptr;
    (void)(_heap_lock_acquire()    );
    (void)(_free_impl(ptr)    );
    (void)(_heap_lock_release()    );
}

__attribute__((used)) char * memcpy(char * dest, const char * src, size_t n) {
    (void)dest;
    (void)src;
    (void)n;
    if ((((dest == NULL) || (src == NULL)) || (n == 0))) {
                {
            char * _uya_ret = (char *)dest;
            return _uya_ret;
                }
    }
    size_t i = 0;
    while (i < n) {
        dest[i] = src[i];
        i = (i + 1);
    }
        {
        char * _uya_ret = (char *)dest;
        return _uya_ret;
        }
}





static __attribute__((used,noinline)) void * _pthread_call_start(void * start_fn, void * start_arg) {
    (void)start_fn;
    (void)start_arg;
    size_t r = 0;
__asm__ volatile ("movq %%rsp, %%r10\n\tandq $-16, %%rsp\n\tsubq $16, %%rsp\n\tmovq %%r10, (%%rsp)\n\tmovq %1, %%r11\n\tmovq %2, %%rdi\n\tcall *%%r11\n\tmovq (%%rsp), %%rsp\n\tmovq %%rax, %0\n\t"
    : "=r"(r)
    : "r"(start_fn), "r"(start_arg)
    : "memory", "rax", "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11"
    );
        {
        void * _uya_ret = (void *)r;
        return _uya_ret;
        }
}

static __attribute__((used)) void _pthread_run_tsd_destructors(struct pthread_desc * desc) {
    (void)desc;
    if ((((desc == NULL) || (desc->tsd_values == NULL)) || (_pthread_keys == NULL))) {
        return;
    }
    int32_t round = 0;
    while (round < PTHREAD_DESTRUCTOR_ITERATIONS) {
        int32_t any_called = 0;
        size_t i = 0;
        while (i < PTHREAD_KEYS_MAX) {
            struct pthread_key_t * k = (struct pthread_key_t *)((size_t)_pthread_keys + (i * (int32_t)sizeof(struct pthread_key_t)));
            if (k->seq > 0) {
                void * * const val_ptr = (void * *)((size_t)desc->tsd_values + (i * (int32_t)sizeof(void *)));
                void * const val = val_ptr[0];
                if (val != NULL) {
                    val_ptr[0] = NULL;
                    if (k->destructor != NULL) {
                        (void)(_pthread_call_start(k->destructor, val)                        );
                        any_called = 1;
                    }
                }
            }
            i = (i + 1);
        }
        if (any_called == 0) {
            break;
        }
        round = (round + 1);
    }
}

static __attribute__((used)) void _pthread_thread_exit(struct pthread_desc * desc, void * retval) {
    (void)desc;
    (void)retval;
    if (desc != NULL) {
        desc->result = retval;
        (void)(_pthread_run_tsd_destructors(desc)        );
        __atomic_store_n((int32_t *)&(desc->exited), 1, __ATOMIC_SEQ_CST);
        while (true) {
            const int32_t state = __atomic_load_n((int32_t *)&(desc->joinstate), __ATOMIC_SEQ_CST);
            if (state == PTHREAD_JOINSTATE_DETACHED) {
                break;
            }
            if (state == PTHREAD_JOINSTATE_JOINABLE) {
                int32_t expected = PTHREAD_JOINSTATE_JOINABLE;
                if (__atomic_compare_exchange_n((int32_t *)(&desc->joinstate), (&expected), PTHREAD_JOINSTATE_EXITED, 0, PTHREAD_ATOMIC_SEQ_CST, PTHREAD_ATOMIC_SEQ_CST) != 0) {
                    (void)(sys_futex((int32_t *)(&desc->joinstate), libc_FUTEX_WAKE, 1, NULL)                    );
                    break;
                }
                continue;
            }
            break;
        }
    }
    (void)(sys_exit(0)    );
}

__attribute__((used)) void libc__pthread_child_bootstrap(struct pthread_desc * desc) {
    (void)desc;
    if (desc == NULL) {
        (void)(sys_exit(0)        );
        return;
    }
    while (__atomic_load_n((int32_t *)&(desc->started), __ATOMIC_SEQ_CST) == 0) {
        (void)(libc_pthread_yield());
    }
    (void)(_pthread_thread_exit(desc, _pthread_call_start(desc->start_routine, desc->arg))    );
}

__attribute__((used)) int32_t libc_pthread_yield() {
    struct err_union_int64_t ret = ({ long _uya_syscall_ret = uya_syscall6(libc_SYS_sched_yield, 0, 0, 0, 0, 0, 0); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    (void)(({ struct err_union_int64_t _uya_catch_tmp = ret; __typeof__(_uya_catch_tmp.value) _uya_catch_result; if (_uya_catch_tmp.error_id != 0) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; }));
        {
        int32_t _uya_ret = 0;
        return _uya_ret;
        }
        return 0;
}

static __attribute__((used)) intptr_t _stdio_write_fail_isize() {
        {
        intptr_t _uya_ret = (intptr_t)(-1);
        return _uya_ret;
        }
}

__attribute__((used)) int32_t flush_buffer(struct FILE * stream) {
    (void)stream;
    if (stream == NULL) {
                {
            int32_t _uya_ret = (-1);
            return _uya_ret;
                }
    }
    if (stream->buf_len == 0) {
                {
            int32_t _uya_ret = 0;
            return _uya_ret;
                }
    }
    struct err_union_intptr_t result = sys_write((int32_t)stream->fd, (const char *)(const uint8_t *)(&stream->buffer[0]), stream->buf_len);
    const intptr_t written = ({ struct err_union_intptr_t _uya_catch_tmp = result; __typeof__(_uya_catch_tmp.value) _uya_catch_result; if (_uya_catch_tmp.error_id != 0) {
        _uya_catch_result = (_stdio_write_fail_isize());
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
    if (written < (intptr_t)0) {
                {
            int32_t _uya_ret = (-1);
            return _uya_ret;
                }
    }
    stream->buf_pos = 0;
    stream->buf_len = 0;
        {
        int32_t _uya_ret = 0;
        return _uya_ret;
        }
}

__attribute__((used)) int64_t write_to_buffer(struct FILE * stream, const char * buf, size_t n) {
    (void)stream;
    (void)buf;
    (void)n;
    if (((stream == NULL) || ((buf == NULL) && (n != 0)))) {
                {
            int64_t _uya_ret = (-1);
            return _uya_ret;
                }
    }
    if (n == 0) {
                {
            int64_t _uya_ret = 0;
            return _uya_ret;
                }
    }
    if (((stream == NULL) || (buf == NULL))) {
                {
            int64_t _uya_ret = (-1);
            return _uya_ret;
                }
    }
    const size_t buf_size = (sizeof(stream->buffer) / sizeof((stream->buffer)[0]));
    if (((stream->buf_mode == 0) || (n >= buf_size))) {
        struct err_union_intptr_t result = sys_write((int32_t)stream->fd, (const char *)(const uint8_t *)buf, n);
        const intptr_t written = ({ struct err_union_intptr_t _uya_catch_tmp = result; __typeof__(_uya_catch_tmp.value) _uya_catch_result; if (_uya_catch_tmp.error_id != 0) {
            _uya_catch_result = (_stdio_write_fail_isize());
        } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
                {
            int64_t _uya_ret = (int64_t)written;
            return _uya_ret;
                }
    }
    size_t bytes_written = 0;
    size_t remaining = n;
    size_t src_offset = 0;
    while (remaining > 0) {
        size_t space_left = (buf_size - stream->buf_len);
        if (space_left == 0) {
            if (flush_buffer(stream) < 0) {
                                {
                    int64_t _uya_ret = (-1);
                    return _uya_ret;
                                }
            }
            space_left = buf_size;
        }
        size_t to_copy = 0;
        if (remaining < space_left) {
            to_copy = remaining;
        } else {
            to_copy = space_left;
        }
        size_t i = 0;
        while (i < to_copy) {
            stream->buffer[(stream->buf_len + i)] = buf[(src_offset + i)];
            i = (i + 1);
        }
        stream->buf_len = (stream->buf_len + to_copy);
        stream->buf_pos = stream->buf_len;
        src_offset = (src_offset + to_copy);
        bytes_written = (bytes_written + to_copy);
        remaining = (remaining - to_copy);
        if (stream->buf_mode == 1) {
            size_t buf_start = (stream->buf_len - to_copy);
            size_t j = buf_start;
            bool need_flush = false;
            while (j < stream->buf_len) {
                if (j < buf_size) {
                    if (stream->buffer[j] == 10) {
                        need_flush = true;
                        break;
                    }
                }
                j = (j + 1);
            }
            if (need_flush) {
                if (flush_buffer(stream) < 0) {
                                        {
                        int64_t _uya_ret = (-1);
                        return _uya_ret;
                                        }
                }
            }
        }
    }
        {
        int64_t _uya_ret = (int64_t)bytes_written;
        return _uya_ret;
        }
}

static __attribute__((used)) size_t _fmt_f64_to_buf(uint8_t * buf, size_t buf_pos, size_t buf_max, double val, int32_t precision, int32_t force_scientific, int32_t scientific_uppercase, int32_t uppercase_inf_nan) {
    (void)buf;
    (void)buf_pos;
    (void)buf_max;
    (void)val;
    (void)precision;
    (void)force_scientific;
    (void)scientific_uppercase;
    (void)uppercase_inf_nan;
    size_t pos = buf_pos;
    if (pos >= buf_max) {
                {
            size_t _uya_ret = pos;
            return _uya_ret;
                }
    }
    double x = val;
    if (x != x) {
        if (uppercase_inf_nan != 0) {
            if (pos < buf_max) {
                buf[pos] = 78;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 65;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 78;
                pos = (pos + 1);
            }
        } else {
            if (pos < buf_max) {
                buf[pos] = 110;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 97;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 110;
                pos = (pos + 1);
            }
        }
                {
            size_t _uya_ret = pos;
            return _uya_ret;
                }
    }
    if (((x != 0.00000000000000000) && ((x * 2.00000000000000000) == x))) {
        if (x < 0.00000000000000000) {
            buf[pos] = 45;
            pos = (pos + 1);
            if (pos >= buf_max) {
                                {
                    size_t _uya_ret = pos;
                    return _uya_ret;
                                }
            }
        }
        if (uppercase_inf_nan != 0) {
            if (pos < buf_max) {
                buf[pos] = 73;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 78;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 70;
                pos = (pos + 1);
            }
        } else {
            if (pos < buf_max) {
                buf[pos] = 105;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 110;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 102;
                pos = (pos + 1);
            }
        }
                {
            size_t _uya_ret = pos;
            return _uya_ret;
                }
    }
    if (x < 0.00000000000000000) {
        buf[pos] = 45;
        pos = (pos + 1);
        x = (0.00000000000000000 - x);
    }
    if (x == 0.00000000000000000) {
        buf[pos] = 48;
        pos = (pos + 1);
        if (((precision > 0) && (pos < buf_max))) {
            buf[pos] = 46;
            pos = (pos + 1);
            int32_t i = 0;
            while (((i < precision) && (pos < buf_max))) {
                buf[pos] = 48;
                pos = (pos + 1);
                i = (i + 1);
            }
        }
                {
            size_t _uya_ret = pos;
            return _uya_ret;
                }
    }
    int32_t exp = 0;
    double normalized = x;
    while (normalized >= 10.00000000000000000) {
        normalized = (normalized / 10.00000000000000000);
        exp = (exp + 1);
    }
    while (((normalized < 1.00000000000000000) && (normalized > 0.00000000000000000))) {
        normalized = (normalized * 10.00000000000000000);
        exp = (exp - 1);
    }
    const bool use_scientific = (((exp > 15) || (exp < (-4))) || (force_scientific != 0));
    if (use_scientific) {
        int32_t prec = precision;
        if (prec < 0) {
            prec = 6;
        }
        const int32_t int_digit = (int32_t)normalized;
        buf[pos] = (uint8_t)(48 + int_digit);
        pos = (pos + 1);
        if (((prec > 0) && (pos < buf_max))) {
            buf[pos] = 46;
            pos = (pos + 1);
            double frac = (normalized - (double)int_digit);
            int32_t k = 0;
            while (((k < prec) && (pos < buf_max))) {
                frac = (frac * 10.00000000000000000);
                const int32_t d = (int32_t)frac;
                buf[pos] = (uint8_t)(48 + d);
                pos = (pos + 1);
                frac = (frac - (double)d);
                k = (k + 1);
            }
        }
        if (pos < buf_max) {
            uint8_t e_char = 101;
            if (scientific_uppercase != 0) {
                e_char = 69;
            }
            buf[pos] = e_char;
            pos = (pos + 1);
        }
        if (exp < 0) {
            if (pos < buf_max) {
                buf[pos] = 45;
                pos = (pos + 1);
            }
            exp = (0 - exp);
        } else {
            if (pos < buf_max) {
                buf[pos] = 43;
                pos = (pos + 1);
            }
        }
        if (exp >= 100) {
            buf[pos] = (uint8_t)(48 + (exp / 100));
            pos = (pos + 1);
            exp = (exp % 100);
        }
        if (exp >= 10) {
            buf[pos] = (uint8_t)(48 + (exp / 10));
            pos = (pos + 1);
            exp = (exp % 10);
        } else {
            if (pos > (buf_pos + 1)) {
                buf[pos] = 48;
                pos = (pos + 1);
            }
        }
        buf[pos] = (uint8_t)(48 + exp);
        pos = (pos + 1);
    } else {
        int64_t int_part = (int64_t)x;
        double frac = (x - (double)int_part);
        uint8_t digits[24] = {0};
        size_t di = 0;
        if (int_part == 0) {
            digits[di] = 48;
            di = (di + 1);
        } else {
            int64_t t = int_part;
            while (((t > 0) && (di < 24))) {
                digits[di] = (uint8_t)(48 + (int32_t)(t % 10));
                di = (di + 1);
                t = (t / 10);
            }
        }
        size_t i = 0;
        while (((i < di) && (pos < buf_max))) {
            buf[pos] = digits[((di - 1) - i)];
            pos = (pos + 1);
            i = (i + 1);
        }
        int32_t prec = precision;
        if (prec < 0) {
            prec = 6;
        }
        if (((prec > 0) && (pos < buf_max))) {
            buf[pos] = 46;
            pos = (pos + 1);
            i = 0;
            while (((i < prec) && (pos < buf_max))) {
                frac = (frac * 10.00000000000000000);
                const int32_t d = (int32_t)frac;
                buf[pos] = (uint8_t)(48 + d);
                pos = (pos + 1);
                frac = (frac - (double)d);
                i = (i + 1);
            }
        }
    }
        {
        size_t _uya_ret = pos;
        return _uya_ret;
        }
}

static __attribute__((used)) size_t _fmt_f64_hex_to_buf(uint8_t * buf, size_t buf_pos, size_t buf_max, double val, int32_t precision, int32_t uppercase) {
    (void)buf;
    (void)buf_pos;
    (void)buf_max;
    (void)val;
    (void)precision;
    (void)uppercase;
    size_t pos = buf_pos;
    double x = val;
    bool default_precision = (precision < 0);
    if (x != x) {
        if (uppercase != 0) {
            if (pos < buf_max) {
                buf[pos] = 78;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 65;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 78;
                pos = (pos + 1);
            }
        } else {
            if (pos < buf_max) {
                buf[pos] = 110;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 97;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 110;
                pos = (pos + 1);
            }
        }
                {
            size_t _uya_ret = pos;
            return _uya_ret;
                }
    }
    if (((x != 0.00000000000000000) && ((x * 2.00000000000000000) == x))) {
        if (x < 0.00000000000000000) {
            if (pos < buf_max) {
                buf[pos] = 45;
                pos = (pos + 1);
            }
        }
        if (uppercase != 0) {
            if (pos < buf_max) {
                buf[pos] = 73;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 78;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 70;
                pos = (pos + 1);
            }
        } else {
            if (pos < buf_max) {
                buf[pos] = 105;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 110;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 102;
                pos = (pos + 1);
            }
        }
                {
            size_t _uya_ret = pos;
            return _uya_ret;
                }
    }
    if (x < 0.00000000000000000) {
        if (pos < buf_max) {
            buf[pos] = 45;
            pos = (pos + 1);
        }
        x = (0.00000000000000000 - x);
    }
    if (x == 0.00000000000000000) {
        if (uppercase != 0) {
            if (pos < buf_max) {
                buf[pos] = 48;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 88;
                pos = (pos + 1);
            }
        } else {
            if (pos < buf_max) {
                buf[pos] = 48;
                pos = (pos + 1);
            }
            if (pos < buf_max) {
                buf[pos] = 120;
                pos = (pos + 1);
            }
        }
        if (pos < buf_max) {
            buf[pos] = 48;
            pos = (pos + 1);
        }
        int32_t prec = precision;
        if (prec < 0) {
            prec = 0;
        }
        if (prec > 0) {
            if (pos < buf_max) {
                buf[pos] = 46;
                pos = (pos + 1);
            }
        }
        int32_t i = 0;
        while (((i < prec) && (pos < buf_max))) {
            buf[pos] = 48;
            pos = (pos + 1);
            i = (i + 1);
        }
        if (uppercase != 0) {
            if (pos < buf_max) {
                buf[pos] = 80;
                pos = (pos + 1);
            }
        } else {
            if (pos < buf_max) {
                buf[pos] = 112;
                pos = (pos + 1);
            }
        }
        if (pos < buf_max) {
            buf[pos] = 43;
            pos = (pos + 1);
        }
        if (pos < buf_max) {
            buf[pos] = 48;
            pos = (pos + 1);
        }
                {
            size_t _uya_ret = pos;
            return _uya_ret;
                }
    }
    int32_t exp = 0;
    while (x >= 1.00000000000000000) {
        x = (x / 2.00000000000000000);
        exp = (exp + 1);
    }
    while (x < 0.50000000000000000) {
        x = (x * 2.00000000000000000);
        exp = (exp - 1);
    }
    exp = (exp - 1);
    if (uppercase != 0) {
        if (pos < buf_max) {
            buf[pos] = 48;
            pos = (pos + 1);
        }
        if (pos < buf_max) {
            buf[pos] = 88;
            pos = (pos + 1);
        }
    } else {
        if (pos < buf_max) {
            buf[pos] = 48;
            pos = (pos + 1);
        }
        if (pos < buf_max) {
            buf[pos] = 120;
            pos = (pos + 1);
        }
    }
    if (pos < buf_max) {
        buf[pos] = 49;
        pos = (pos + 1);
    }
    double frac = ((x * 2.00000000000000000) - 1.00000000000000000);
    int32_t prec = precision;
    if (prec < 0) {
        prec = 13;
    }
    size_t frac_dot_pos = pos;
    size_t frac_start_pos = pos;
    if (prec > 0) {
        if (pos < buf_max) {
            buf[pos] = 46;
            pos = (pos + 1);
        }
        frac_start_pos = pos;
        int32_t k = 0;
        while (((k < prec) && (pos < buf_max))) {
            frac = (frac * 16.00000000000000000);
            int32_t d = (int32_t)frac;
            if (d >= 16) {
                d = 15;
            }
            frac = (frac - (double)d);
            if (uppercase != 0) {
                if (d >= 10) {
                    buf[pos] = (uint8_t)((65 + d) - 10);
                } else {
                    buf[pos] = (uint8_t)(48 + d);
                }
            } else {
                if (d >= 10) {
                    buf[pos] = (uint8_t)((97 + d) - 10);
                } else {
                    buf[pos] = (uint8_t)(48 + d);
                }
            }
            pos = (pos + 1);
            k = (k + 1);
        }
    }
    if (default_precision) {
        while (pos > frac_start_pos) {
            if (buf[(pos - 1)] != 48) {
                break;
            }
            pos = (pos - 1);
        }
        if (pos == frac_start_pos) {
            pos = frac_dot_pos;
        }
    }
    if (uppercase != 0) {
        if (pos < buf_max) {
            buf[pos] = 80;
            pos = (pos + 1);
        }
    } else {
        if (pos < buf_max) {
            buf[pos] = 112;
            pos = (pos + 1);
        }
    }
    if (exp < 0) {
        if (pos < buf_max) {
            buf[pos] = 45;
            pos = (pos + 1);
        }
        exp = (0 - exp);
    } else {
        if (pos < buf_max) {
            buf[pos] = 43;
            pos = (pos + 1);
        }
    }
    if (exp >= 100) {
        if (pos < buf_max) {
            buf[pos] = (uint8_t)(48 + (exp / 100));
            pos = (pos + 1);
        }
        exp = (exp % 100);
    }
    if (exp >= 10) {
        if (pos < buf_max) {
            buf[pos] = (uint8_t)(48 + (exp / 10));
            pos = (pos + 1);
        }
        exp = (exp % 10);
    }
    if (pos < buf_max) {
        buf[pos] = (uint8_t)(48 + exp);
        pos = (pos + 1);
    }
        {
        size_t _uya_ret = pos;
        return _uya_ret;
        }
}

__attribute__((used)) int32_t fprintf(struct FILE * stream, const char * format, ...) {
    (void)stream;
    (void)format;
    if (((stream == NULL) || (format == NULL))) {
                {
            int32_t _uya_ret = (0 - 1);
            return _uya_ret;
                }
    }
    va_list ap;
    (void)(va_start(ap, format)    );
    const int32_t result = vfprintf(stream, (const char *)format, ap);
    (void)(va_end(ap)    );
        {
        int32_t _uya_ret = result;
        return _uya_ret;
        }
}

static __attribute__((used)) void _fmt_pad_spaces(struct _FmtContext * ctx, int32_t n) {
    (void)ctx;
    (void)n;
    int32_t i = 0;
    while (((i < n) && (ctx->buf_pos < ctx->buf_max))) {
        ctx->buf[ctx->buf_pos] = 32;
        ctx->buf_pos = (ctx->buf_pos + 1);
        i = (i + 1);
    }
    ctx->total_len = (ctx->total_len + (size_t)n);
}

static __attribute__((used)) void _fmt_pad_zeros(struct _FmtContext * ctx, int32_t n) {
    (void)ctx;
    (void)n;
    int32_t i = 0;
    while (((i < n) && (ctx->buf_pos < ctx->buf_max))) {
        ctx->buf[ctx->buf_pos] = 48;
        ctx->buf_pos = (ctx->buf_pos + 1);
        i = (i + 1);
    }
    ctx->total_len = (ctx->total_len + (size_t)n);
}

static __attribute__((used)) void _fmt_copy_to_ctx(struct _FmtContext * ctx, uint8_t * temp, size_t temp_len) {
    (void)ctx;
    (void)temp;
    (void)temp_len;
    size_t i = 0;
    while (((i < temp_len) && (ctx->buf_pos < ctx->buf_max))) {
        ctx->buf[ctx->buf_pos] = temp[i];
        ctx->buf_pos = (ctx->buf_pos + 1);
        i = (i + 1);
    }
    ctx->total_len = (ctx->total_len + temp_len);
}

static __attribute__((used)) void _fmt_apply_padding(struct _FmtContext * ctx, uint8_t * temp, size_t temp_len, int32_t width, int32_t left_align, int32_t zero_pad) {
    (void)ctx;
    (void)temp;
    (void)temp_len;
    (void)width;
    (void)left_align;
    (void)zero_pad;
    if (((width < 0) || ((size_t)width <= temp_len))) {
        (void)(_fmt_copy_to_ctx(ctx, (uint8_t *)temp, temp_len)        );
        return;
    }
    const int32_t pad = (width - (int32_t)temp_len);
    if (left_align != 0) {
        (void)(_fmt_copy_to_ctx(ctx, (uint8_t *)temp, temp_len)        );
        (void)(_fmt_pad_spaces(ctx, pad)        );
    } else {
        if ((((zero_pad != 0) && (temp_len > 0)) && ((temp[0] == 45) || (temp[0] == 43)))) {
            ctx->total_len = (ctx->total_len + 1);
            if (ctx->buf_pos < ctx->buf_max) {
                ctx->buf[ctx->buf_pos] = temp[0];
                ctx->buf_pos = (ctx->buf_pos + 1);
            }
            (void)(_fmt_pad_zeros(ctx, pad)            );
            size_t i = 1;
            while (((i < temp_len) && (ctx->buf_pos < ctx->buf_max))) {
                ctx->buf[ctx->buf_pos] = temp[i];
                ctx->buf_pos = (ctx->buf_pos + 1);
                i = (i + 1);
            }
            ctx->total_len = ((ctx->total_len + temp_len) - 1);
        } else {
            if (zero_pad != 0) {
                (void)(_fmt_pad_zeros(ctx, pad)                );
                (void)(_fmt_copy_to_ctx(ctx, (uint8_t *)temp, temp_len)                );
            } else {
                (void)(_fmt_pad_spaces(ctx, pad)                );
                (void)(_fmt_copy_to_ctx(ctx, (uint8_t *)temp, temp_len)                );
            }
        }
    }
}

static __attribute__((used)) void _fmt_i32_to_buf_full(struct _FmtContext * ctx, int32_t value, int32_t flags, int32_t precision) {
    (void)ctx;
    (void)value;
    (void)flags;
    (void)precision;
    int32_t num = value;
    int32_t is_neg = 0;
    if (num < 0) {
        is_neg = 1;
        num = (0 - num);
    }
    uint8_t digits[16] = {0};
    size_t digit_idx = 0;
    if (num == 0) {
        digits[0] = 48;
        digit_idx = 1;
    } else {
        int32_t temp = num;
        while (temp > 0) {
            const int32_t digit = (temp % 10);
            digits[digit_idx] = (uint8_t)(48 + digit);
            digit_idx = (digit_idx + 1);
            temp = (temp / 10);
        }
    }
    if (is_neg > 0) {
        ctx->total_len = (ctx->total_len + 1);
        if (ctx->buf_pos < ctx->buf_max) {
            ctx->buf[ctx->buf_pos] = 45;
            ctx->buf_pos = (ctx->buf_pos + 1);
        }
    } else {
        if ((flags & _FMT_PLUS) != 0) {
            ctx->total_len = (ctx->total_len + 1);
            if (ctx->buf_pos < ctx->buf_max) {
                ctx->buf[ctx->buf_pos] = 43;
                ctx->buf_pos = (ctx->buf_pos + 1);
            }
        } else {
            if ((flags & _FMT_SPACE) != 0) {
                ctx->total_len = (ctx->total_len + 1);
                if (ctx->buf_pos < ctx->buf_max) {
                    ctx->buf[ctx->buf_pos] = 32;
                    ctx->buf_pos = (ctx->buf_pos + 1);
                }
            }
        }
    }
    int32_t min_digits = precision;
    if (min_digits < 0) {
        min_digits = 0;
    }
    if ((size_t)min_digits > digit_idx) {
        size_t pad = ((size_t)min_digits - digit_idx);
        ctx->total_len = (ctx->total_len + pad);
        size_t pi = 0;
        while (((pi < pad) && (ctx->buf_pos < ctx->buf_max))) {
            ctx->buf[ctx->buf_pos] = 48;
            ctx->buf_pos = (ctx->buf_pos + 1);
            pi = (pi + 1);
        }
    }
    ctx->total_len = (ctx->total_len + digit_idx);
    size_t i = 0;
    while (((i < digit_idx) && (ctx->buf_pos < ctx->buf_max))) {
        ctx->buf[ctx->buf_pos] = digits[((digit_idx - 1) - i)];
        ctx->buf_pos = (ctx->buf_pos + 1);
        i = (i + 1);
    }
}

static __attribute__((used)) void _fmt_u32_hex_to_buf_prefix(struct _FmtContext * ctx, uint32_t value, int32_t uppercase, int32_t hash) {
    (void)ctx;
    (void)value;
    (void)uppercase;
    (void)hash;
    if (((hash != 0) && (value != 0))) {
        ctx->total_len = (ctx->total_len + 2);
        if (ctx->buf_pos < ctx->buf_max) {
            ctx->buf[ctx->buf_pos] = 48;
            ctx->buf_pos = (ctx->buf_pos + 1);
        }
        if (ctx->buf_pos < ctx->buf_max) {
            uint8_t x_char = 120;
            if (uppercase != 0) {
                x_char = 88;
            }
            ctx->buf[ctx->buf_pos] = x_char;
            ctx->buf_pos = (ctx->buf_pos + 1);
        }
    }
    uint32_t num = value;
    const uint8_t hex_lower[16] = {48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 97, 98, 99, 100, 101, 102};
    const uint8_t hex_upper[16] = {48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70};
    const uint32_t sixteen = 16;
    uint8_t hdigits[8] = {0};
    size_t hidx = 0;
    if (num == 0) {
        hdigits[0] = 48;
        hidx = 1;
    } else {
        while (((num > 0) && (hidx < 8))) {
            const size_t idx = (size_t)(num % sixteen);
            if (((idx >= 0) && (idx < 16))) {
                if (uppercase > 0) {
                    hdigits[hidx] = hex_upper[idx];
                } else {
                    hdigits[hidx] = hex_lower[idx];
                }
            }
            hidx = (hidx + 1);
            num = (num / sixteen);
        }
    }
    ctx->total_len = (ctx->total_len + hidx);
    size_t i = 0;
    while (((i < hidx) && (ctx->buf_pos < ctx->buf_max))) {
        ctx->buf[ctx->buf_pos] = hdigits[((hidx - 1) - i)];
        ctx->buf_pos = (ctx->buf_pos + 1);
        i = (i + 1);
    }
}

static __attribute__((used)) void _fmt_u32_octal_to_buf(struct _FmtContext * ctx, uint32_t value) {
    (void)ctx;
    (void)value;
    uint32_t num = value;
    const uint32_t eight = 8;
    uint8_t odigits[12] = {0};
    size_t oidx = 0;
    if (num == 0) {
        odigits[0] = 48;
        oidx = 1;
    } else {
        while (((num > 0) && (oidx < 12))) {
            const size_t idx = (size_t)(num % eight);
            odigits[oidx] = (uint8_t)(48 + idx);
            oidx = (oidx + 1);
            num = (num / eight);
        }
    }
    ctx->total_len = (ctx->total_len + oidx);
    size_t i = 0;
    while (((i < oidx) && (ctx->buf_pos < ctx->buf_max))) {
        ctx->buf[ctx->buf_pos] = odigits[((oidx - 1) - i)];
        ctx->buf_pos = (ctx->buf_pos + 1);
        i = (i + 1);
    }
}

static __attribute__((used)) void _fmt_u64_hex_to_buf(struct _FmtContext * ctx, uint64_t value, int32_t uppercase) {
    (void)ctx;
    (void)value;
    (void)uppercase;
    uint64_t num = value;
    const uint8_t hex_lower[16] = {48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 97, 98, 99, 100, 101, 102};
    const uint8_t hex_upper[16] = {48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70};
    const uint64_t sixteen = 16;
    uint8_t hdigits[16] = {0};
    size_t hidx = 0;
    if (num == 0) {
        hdigits[0] = 48;
        hidx = 1;
    } else {
        while (((num > 0) && (hidx < 16))) {
            const size_t idx = (size_t)(num % sixteen);
            if (idx < 16) {
                if (uppercase > 0) {
                    hdigits[hidx] = hex_upper[idx];
                } else {
                    hdigits[hidx] = hex_lower[idx];
                }
            }
            hidx = (hidx + 1);
            num = (num / sixteen);
        }
    }
    ctx->total_len = (ctx->total_len + hidx);
    size_t i = 0;
    while (((i < hidx) && (ctx->buf_pos < ctx->buf_max))) {
        ctx->buf[ctx->buf_pos] = hdigits[((hidx - 1) - i)];
        ctx->buf_pos = (ctx->buf_pos + 1);
        i = (i + 1);
    }
}

static __attribute__((used)) void _fmt_u64_octal_to_buf(struct _FmtContext * ctx, uint64_t value) {
    (void)ctx;
    (void)value;
    uint64_t num = value;
    const uint64_t eight = 8;
    uint8_t odigits[22] = {0};
    size_t oidx = 0;
    if (num == 0) {
        odigits[0] = 48;
        oidx = 1;
    } else {
        while (((num > 0) && (oidx < 22))) {
            const size_t idx = (size_t)(num % eight);
            odigits[oidx] = (uint8_t)(48 + idx);
            oidx = (oidx + 1);
            num = (num / eight);
        }
    }
    ctx->total_len = (ctx->total_len + oidx);
    size_t i = 0;
    while (((i < oidx) && (ctx->buf_pos < ctx->buf_max))) {
        ctx->buf[ctx->buf_pos] = odigits[((oidx - 1) - i)];
        ctx->buf_pos = (ctx->buf_pos + 1);
        i = (i + 1);
    }
}

static __attribute__((used)) void _fmt_str_to_buf_limited(struct _FmtContext * ctx, const uint8_t * s, int32_t precision) {
    (void)ctx;
    (void)s;
    (void)precision;
    if (s == NULL) {
        return;
    }
    size_t len = strlen((const char *)s);
    if (((precision >= 0) && ((size_t)precision < len))) {
        len = (size_t)precision;
    }
    ctx->total_len = (ctx->total_len + len);
    size_t i = 0;
    while (((i < len) && (ctx->buf_pos < ctx->buf_max))) {
        ctx->buf[ctx->buf_pos] = s[i];
        ctx->buf_pos = (ctx->buf_pos + 1);
        i = (i + 1);
    }
}

static __attribute__((used)) int32_t _vfprintf_impl(struct FILE * stream, const uint8_t * format, va_list ap, int32_t use_buf, uint8_t * out_buf, size_t buf_size) {
    (void)stream;
    (void)format;
    (void)ap;
    (void)use_buf;
    (void)out_buf;
    (void)buf_size;
    if (format == NULL) {
                {
            int32_t _uya_ret = (0 - 1);
            return _uya_ret;
                }
    }
    uint8_t local_buf[4096] = {0};
    struct _FmtContext ctx = (struct _FmtContext){.buf = (&local_buf[0]), .buf_pos = 0, .buf_max = 4095, .stream = stream, .total_len = 0};
    if (((use_buf > 0) && (out_buf != NULL))) {
        ctx.buf = out_buf;
        if (buf_size > 0) {
            ctx.buf_max = (buf_size - 1);
        } else {
            ctx.buf_max = 0;
        }
    }
    size_t format_pos = 0;
    const size_t format_len = strlen((const char *)format);
    while (format_pos < format_len) {
        const uint8_t c = format[format_pos];
        if (c == 37) {
            format_pos = (format_pos + 1);
            if (format_pos >= format_len) {
                break;
            }
            int32_t flags = 0;
            int32_t width = (0 - 1);
            int32_t precision = (0 - 1);
            int32_t length = 0;
            while (format_pos < format_len) {
                const uint8_t ch = format[format_pos];
                if (ch == 45) {
                    flags = (flags | _FMT_MINUS);
                    format_pos = (format_pos + 1);
                } else {
                    if (ch == 43) {
                        flags = (flags | _FMT_PLUS);
                        format_pos = (format_pos + 1);
                    } else {
                        if (ch == 32) {
                            flags = (flags | _FMT_SPACE);
                            format_pos = (format_pos + 1);
                        } else {
                            if (ch == 48) {
                                flags = (flags | _FMT_ZERO);
                                format_pos = (format_pos + 1);
                            } else {
                                if (ch == 35) {
                                    flags = (flags | _FMT_HASH);
                                    format_pos = (format_pos + 1);
                                } else {
                                    if (((ch >= 49) && (ch <= 57))) {
                                        width = 0;
                                        while ((((format_pos < format_len) && (format[format_pos] >= 48)) && (format[format_pos] <= 57))) {
                                            width = ((width * 10) + (int32_t)(format[format_pos] - 48));
                                            format_pos = (format_pos + 1);
                                        }
                                    } else {
                                        if (ch == 42) {
                                            width = va_arg(ap, int32_t);
                                            format_pos = (format_pos + 1);
                                        } else {
                                            if (ch == 46) {
                                                format_pos = (format_pos + 1);
                                                precision = 0;
                                                if (((format_pos < format_len) && (format[format_pos] == 42))) {
                                                    precision = va_arg(ap, int32_t);
                                                    format_pos = (format_pos + 1);
                                                } else {
                                                    while ((((format_pos < format_len) && (format[format_pos] >= 48)) && (format[format_pos] <= 57))) {
                                                        precision = ((precision * 10) + (int32_t)(format[format_pos] - 48));
                                                        format_pos = (format_pos + 1);
                                                    }
                                                }
                                            } else {
                                                if (((((((ch == 104) || (ch == 108)) || (ch == 106)) || (ch == 122)) || (ch == 116)) || (ch == 76))) {
                                                    if ((((ch == 104) && ((format_pos + 1) < format_len)) && (format[(format_pos + 1)] == 104))) {
                                                        length = 2;
                                                        format_pos = (format_pos + 2);
                                                    } else {
                                                        if ((((ch == 108) && ((format_pos + 1) < format_len)) && (format[(format_pos + 1)] == 108))) {
                                                            length = 4;
                                                            format_pos = (format_pos + 2);
                                                        } else {
                                                            if (ch == 104) {
                                                                length = 1;
                                                                format_pos = (format_pos + 1);
                                                            } else {
                                                                if (ch == 108) {
                                                                    length = 3;
                                                                    format_pos = (format_pos + 1);
                                                                } else {
                                                                    if (ch == 106) {
                                                                        length = 5;
                                                                        format_pos = (format_pos + 1);
                                                                    } else {
                                                                        if (ch == 122) {
                                                                            length = 6;
                                                                            format_pos = (format_pos + 1);
                                                                        } else {
                                                                            if (ch == 116) {
                                                                                length = 7;
                                                                                format_pos = (format_pos + 1);
                                                                            } else {
                                                                                format_pos = (format_pos + 1);
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                } else {
                                                    break;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if (format_pos >= format_len) {
                break;
            }
            const uint8_t spec = format[format_pos];
            format_pos = (format_pos + 1);
            if (spec == 110) {
                int32_t * const n_ptr = va_arg(ap, int32_t *);
                if (n_ptr != NULL) {
                    n_ptr[0] = (int32_t)ctx.total_len;
                }
            } else {
                if (spec == 115) {
                    const uint8_t * const s = va_arg(ap, const uint8_t *);
                    uint8_t temp_buf[256] = {0};
                    struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                    (void)(_fmt_str_to_buf_limited((&temp_ctx), s, precision)                    );
                    const size_t content_len = temp_ctx.buf_pos;
                    (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), content_len, width, (flags & _FMT_MINUS), 0)                    );
                } else {
                    if (((spec == 100) || (spec == 105))) {
                        uint8_t temp_buf[256] = {0};
                        struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                        if ((((length == 4) || (length == 5)) || (length == 7))) {
                            const int64_t lld = va_arg(ap, int64_t);
                            if (lld < 0) {
                                temp_ctx.buf[temp_ctx.buf_pos] = 45;
                                temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                temp_ctx.total_len = (temp_ctx.total_len + 1);
                                (void)(_fmt_u64_to_buf((&temp_ctx), (uint64_t)(0 - lld))                                );
                            } else {
                                (void)(_fmt_i32_to_buf_full((&temp_ctx), (int32_t)lld, flags, precision)                                );
                            }
                        } else {
                            if (length == 3) {
                                const int64_t ld = va_arg(ap, int64_t);
                                if (ld < 0) {
                                    temp_ctx.buf[temp_ctx.buf_pos] = 45;
                                    temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                    temp_ctx.total_len = (temp_ctx.total_len + 1);
                                    (void)(_fmt_u64_to_buf((&temp_ctx), (uint64_t)(0 - ld))                                    );
                                } else {
                                    (void)(_fmt_i32_to_buf_full((&temp_ctx), (int32_t)ld, flags, precision)                                    );
                                }
                            } else {
                                if (((length == 1) || (length == 2))) {
                                    int32_t hv = va_arg(ap, int32_t);
                                    if (length == 2) {
                                        hv = ((hv << 24) >> 24);
                                    } else {
                                        hv = ((hv << 16) >> 16);
                                    }
                                    (void)(_fmt_i32_to_buf_full((&temp_ctx), hv, flags, precision)                                    );
                                } else {
                                    const int32_t d = va_arg(ap, int32_t);
                                    (void)(_fmt_i32_to_buf_full((&temp_ctx), d, flags, precision)                                    );
                                }
                            }
                        }
                        const size_t content_len = temp_ctx.buf_pos;
                        (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), content_len, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                        );
                    } else {
                        if (((spec == 117) && (length == 4))) {
                            const uint64_t llu = va_arg(ap, uint64_t);
                            uint8_t temp_buf[256] = {0};
                            struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                            (void)(_fmt_u64_to_buf((&temp_ctx), llu)                            );
                            (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), temp_ctx.buf_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                            );
                        } else {
                            if (((spec == 111) && (length == 4))) {
                                const uint64_t llo = va_arg(ap, uint64_t);
                                uint8_t temp_buf[256] = {0};
                                struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                                if ((((flags & _FMT_HASH) != 0) && (llo != 0))) {
                                    temp_ctx.buf[temp_ctx.buf_pos] = 48;
                                    temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                    temp_ctx.total_len = (temp_ctx.total_len + 1);
                                }
                                (void)(_fmt_u64_octal_to_buf((&temp_ctx), llo)                                );
                                (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), temp_ctx.buf_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                );
                            } else {
                                if ((((spec == 120) || (spec == 88)) && (length == 4))) {
                                    const uint64_t llx = va_arg(ap, uint64_t);
                                    uint8_t temp_buf[256] = {0};
                                    struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                                    if ((((flags & _FMT_HASH) != 0) && (llx != 0))) {
                                        temp_ctx.buf[temp_ctx.buf_pos] = 48;
                                        temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                        temp_ctx.total_len = (temp_ctx.total_len + 1);
                                        uint8_t x_char = 120;
                                        if (spec == 88) {
                                            x_char = 88;
                                        }
                                        temp_ctx.buf[temp_ctx.buf_pos] = x_char;
                                        temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                        temp_ctx.total_len = (temp_ctx.total_len + 1);
                                    }
                                    int32_t up = 0;
                                    if (spec == 88) {
                                        up = 1;
                                    }
                                    (void)(_fmt_u64_hex_to_buf((&temp_ctx), llx, up)                                    );
                                    (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), temp_ctx.buf_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                    );
                                } else {
                                    if (((spec == 100) && (length == 3))) {
                                        const int64_t ld = va_arg(ap, int64_t);
                                        uint8_t temp_buf[256] = {0};
                                        struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                                        if (ld < 0) {
                                            temp_ctx.buf[temp_ctx.buf_pos] = 45;
                                            temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                            temp_ctx.total_len = (temp_ctx.total_len + 1);
                                            (void)(_fmt_u64_to_buf((&temp_ctx), (uint64_t)(0 - ld))                                            );
                                        } else {
                                            (void)(_fmt_i32_to_buf_full((&temp_ctx), (int32_t)ld, flags, precision)                                            );
                                        }
                                        (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), temp_ctx.buf_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                        );
                                    } else {
                                        if ((((spec == 117) && (length != 4)) && (length != 6))) {
                                            uint8_t temp_buf[256] = {0};
                                            struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                                            if (length == 3) {
                                                const uint64_t lu_val = va_arg(ap, uint64_t);
                                                (void)(_fmt_u64_to_buf((&temp_ctx), lu_val)                                                );
                                            } else {
                                                uint32_t uval = va_arg(ap, uint32_t);
                                                if (length == 2) {
                                                    uval = (uval & (uint32_t)255);
                                                } else {
                                                    if (length == 1) {
                                                        uval = (uval & (uint32_t)65535);
                                                    }
                                                }
                                                (void)(_fmt_u32_to_buf((&temp_ctx), uval)                                                );
                                            }
                                            (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), temp_ctx.buf_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                            );
                                        } else {
                                            if (((spec == 120) && (length != 4))) {
                                                uint32_t xval = va_arg(ap, uint32_t);
                                                if (length == 2) {
                                                    xval = (xval & (uint32_t)255);
                                                } else {
                                                    if (length == 1) {
                                                        xval = (xval & (uint32_t)65535);
                                                    }
                                                }
                                                uint8_t temp_buf[256] = {0};
                                                struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                                                (void)(_fmt_u32_hex_to_buf_prefix((&temp_ctx), xval, 0, (flags & _FMT_HASH))                                                );
                                                (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), temp_ctx.buf_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                );
                                            } else {
                                                if (((spec == 88) && (length != 4))) {
                                                    uint32_t xval = va_arg(ap, uint32_t);
                                                    if (length == 2) {
                                                        xval = (xval & (uint32_t)255);
                                                    } else {
                                                        if (length == 1) {
                                                            xval = (xval & (uint32_t)65535);
                                                        }
                                                    }
                                                    uint8_t temp_buf[256] = {0};
                                                    struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                                                    (void)(_fmt_u32_hex_to_buf_prefix((&temp_ctx), xval, 1, (flags & _FMT_HASH))                                                    );
                                                    (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), temp_ctx.buf_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                    );
                                                } else {
                                                    if (((spec == 111) && (length != 4))) {
                                                        uint32_t oval = va_arg(ap, uint32_t);
                                                        if (length == 2) {
                                                            oval = (oval & (uint32_t)255);
                                                        } else {
                                                            if (length == 1) {
                                                                oval = (oval & (uint32_t)65535);
                                                            }
                                                        }
                                                        uint8_t temp_buf[256] = {0};
                                                        struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                                                        if ((((flags & _FMT_HASH) != 0) && (oval != 0))) {
                                                            temp_ctx.buf[temp_ctx.buf_pos] = 48;
                                                            temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                            temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                        }
                                                        (void)(_fmt_u32_octal_to_buf((&temp_ctx), oval)                                                        );
                                                        (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), temp_ctx.buf_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                        );
                                                    } else {
                                                        if (spec == 112) {
                                                            const size_t pval = va_arg(ap, size_t);
                                                            uint8_t temp_buf[256] = {0};
                                                            struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                                                            temp_ctx.buf[temp_ctx.buf_pos] = 48;
                                                            temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                            temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                            temp_ctx.buf[temp_ctx.buf_pos] = 120;
                                                            temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                            temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                            (void)(_fmt_u64_hex_to_buf((&temp_ctx), (uint64_t)pval, 0)                                                            );
                                                            (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), temp_ctx.buf_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                            );
                                                        } else {
                                                            if (spec == 99) {
                                                                const int32_t cval = va_arg(ap, int32_t);
                                                                uint8_t temp_buf[8] = {0};
                                                                temp_buf[0] = (uint8_t)cval;
                                                                (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), 1, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                                );
                                                            } else {
                                                                if (((spec == 117) && (length == 6))) {
                                                                    const size_t zu_val = va_arg(ap, size_t);
                                                                    uint8_t temp_buf[256] = {0};
                                                                    struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                                                                    (void)(_fmt_u64_to_buf((&temp_ctx), (uint64_t)zu_val)                                                                    );
                                                                    (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), temp_ctx.buf_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                                    );
                                                                } else {
                                                                    if (((spec == 100) && (length == 6))) {
                                                                        const int64_t zd_val = va_arg(ap, int64_t);
                                                                        uint8_t temp_buf[256] = {0};
                                                                        struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                                                                        if (zd_val < 0) {
                                                                            temp_ctx.buf[temp_ctx.buf_pos] = 45;
                                                                            temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                                            temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                                            (void)(_fmt_u64_to_buf((&temp_ctx), (uint64_t)(0 - zd_val))                                                                            );
                                                                        } else {
                                                                            (void)(_fmt_u64_to_buf((&temp_ctx), (uint64_t)zd_val)                                                                            );
                                                                        }
                                                                        (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), temp_ctx.buf_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                                        );
                                                                    } else {
                                                                        if (length == 5) {
                                                                            uint8_t temp_buf[256] = {0};
                                                                            struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                                                                            if (((spec == 100) || (spec == 105))) {
                                                                                const int64_t jd = va_arg(ap, int64_t);
                                                                                if (jd < 0) {
                                                                                    temp_ctx.buf[temp_ctx.buf_pos] = 45;
                                                                                    temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                                                    temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                                                    (void)(_fmt_u64_to_buf((&temp_ctx), (uint64_t)(0 - jd))                                                                                    );
                                                                                } else {
                                                                                    (void)(_fmt_i32_to_buf_full((&temp_ctx), (int32_t)jd, flags, precision)                                                                                    );
                                                                                }
                                                                            } else {
                                                                                if (spec == 117) {
                                                                                    const uint64_t ju = va_arg(ap, uint64_t);
                                                                                    (void)(_fmt_u64_to_buf((&temp_ctx), ju)                                                                                    );
                                                                                } else {
                                                                                    if (spec == 111) {
                                                                                        const uint64_t jo = va_arg(ap, uint64_t);
                                                                                        (void)(_fmt_u64_octal_to_buf((&temp_ctx), jo)                                                                                        );
                                                                                    } else {
                                                                                        if (spec == 120) {
                                                                                            const uint64_t jx = va_arg(ap, uint64_t);
                                                                                            if ((((flags & _FMT_HASH) != 0) && (jx != 0))) {
                                                                                                temp_ctx.buf[temp_ctx.buf_pos] = 48;
                                                                                                temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                                                                temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                                                                temp_ctx.buf[temp_ctx.buf_pos] = 120;
                                                                                                temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                                                                temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                                                            }
                                                                                            (void)(_fmt_u64_hex_to_buf((&temp_ctx), jx, 0)                                                                                            );
                                                                                        } else {
                                                                                            if (spec == 88) {
                                                                                                const uint64_t jX = va_arg(ap, uint64_t);
                                                                                                if ((((flags & _FMT_HASH) != 0) && (jX != 0))) {
                                                                                                    temp_ctx.buf[temp_ctx.buf_pos] = 48;
                                                                                                    temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                                                                    temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                                                                    temp_ctx.buf[temp_ctx.buf_pos] = 88;
                                                                                                    temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                                                                    temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                                                                }
                                                                                                (void)(_fmt_u64_hex_to_buf((&temp_ctx), jX, 1)                                                                                                );
                                                                                            } else {
                                                                                                ctx.total_len = (ctx.total_len + 2);
                                                                                                if (ctx.buf_pos < ctx.buf_max) {
                                                                                                    ctx.buf[ctx.buf_pos] = 37;
                                                                                                    ctx.buf_pos = (ctx.buf_pos + 1);
                                                                                                }
                                                                                                if (ctx.buf_pos < ctx.buf_max) {
                                                                                                    ctx.buf[ctx.buf_pos] = 106;
                                                                                                    ctx.buf_pos = (ctx.buf_pos + 1);
                                                                                                }
                                                                                                if (ctx.buf_pos < ctx.buf_max) {
                                                                                                    ctx.buf[ctx.buf_pos] = spec;
                                                                                                    ctx.buf_pos = (ctx.buf_pos + 1);
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                    }
                                                                                }
                                                                            }
                                                                            if (((((((spec == 100) || (spec == 105)) || (spec == 117)) || (spec == 111)) || (spec == 120)) || (spec == 88))) {
                                                                                (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), temp_ctx.buf_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                                                );
                                                                            }
                                                                        } else {
                                                                            if (length == 7) {
                                                                                uint8_t temp_buf[256] = {0};
                                                                                struct _FmtContext temp_ctx = (struct _FmtContext){.buf = (&temp_buf[0]), .buf_pos = 0, .buf_max = 255, .stream = NULL, .total_len = 0};
                                                                                if (((spec == 100) || (spec == 105))) {
                                                                                    const int64_t td = va_arg(ap, int64_t);
                                                                                    if (td < 0) {
                                                                                        temp_ctx.buf[temp_ctx.buf_pos] = 45;
                                                                                        temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                                                        temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                                                        (void)(_fmt_u64_to_buf((&temp_ctx), (uint64_t)(0 - td))                                                                                        );
                                                                                    } else {
                                                                                        (void)(_fmt_i32_to_buf_full((&temp_ctx), (int32_t)td, flags, precision)                                                                                        );
                                                                                    }
                                                                                } else {
                                                                                    if (spec == 117) {
                                                                                        const uint64_t tu = va_arg(ap, uint64_t);
                                                                                        (void)(_fmt_u64_to_buf((&temp_ctx), tu)                                                                                        );
                                                                                    } else {
                                                                                        if (spec == 111) {
                                                                                            const uint64_t to = va_arg(ap, uint64_t);
                                                                                            (void)(_fmt_u64_octal_to_buf((&temp_ctx), to)                                                                                            );
                                                                                        } else {
                                                                                            if (spec == 120) {
                                                                                                const uint64_t tx = va_arg(ap, uint64_t);
                                                                                                if ((((flags & _FMT_HASH) != 0) && (tx != 0))) {
                                                                                                    temp_ctx.buf[temp_ctx.buf_pos] = 48;
                                                                                                    temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                                                                    temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                                                                    temp_ctx.buf[temp_ctx.buf_pos] = 120;
                                                                                                    temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                                                                    temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                                                                }
                                                                                                (void)(_fmt_u64_hex_to_buf((&temp_ctx), tx, 0)                                                                                                );
                                                                                            } else {
                                                                                                if (spec == 88) {
                                                                                                    const uint64_t tX = va_arg(ap, uint64_t);
                                                                                                    if ((((flags & _FMT_HASH) != 0) && (tX != 0))) {
                                                                                                        temp_ctx.buf[temp_ctx.buf_pos] = 48;
                                                                                                        temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                                                                        temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                                                                        temp_ctx.buf[temp_ctx.buf_pos] = 88;
                                                                                                        temp_ctx.buf_pos = (temp_ctx.buf_pos + 1);
                                                                                                        temp_ctx.total_len = (temp_ctx.total_len + 1);
                                                                                                    }
                                                                                                    (void)(_fmt_u64_hex_to_buf((&temp_ctx), tX, 1)                                                                                                    );
                                                                                                } else {
                                                                                                    ctx.total_len = (ctx.total_len + 2);
                                                                                                    if (ctx.buf_pos < ctx.buf_max) {
                                                                                                        ctx.buf[ctx.buf_pos] = 37;
                                                                                                        ctx.buf_pos = (ctx.buf_pos + 1);
                                                                                                    }
                                                                                                    if (ctx.buf_pos < ctx.buf_max) {
                                                                                                        ctx.buf[ctx.buf_pos] = 116;
                                                                                                        ctx.buf_pos = (ctx.buf_pos + 1);
                                                                                                    }
                                                                                                    if (ctx.buf_pos < ctx.buf_max) {
                                                                                                        ctx.buf[ctx.buf_pos] = spec;
                                                                                                        ctx.buf_pos = (ctx.buf_pos + 1);
                                                                                                    }
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                    }
                                                                                }
                                                                                if (((((((spec == 100) || (spec == 105)) || (spec == 117)) || (spec == 111)) || (spec == 120)) || (spec == 88))) {
                                                                                    (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), temp_ctx.buf_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                                                    );
                                                                                }
                                                                            } else {
                                                                                if (spec == 103) {
                                                                                    const double fval = va_arg(ap, double);
                                                                                    uint8_t temp_buf[256] = {0};
                                                                                    int32_t prec = precision;
                                                                                    if (prec < 0) {
                                                                                        prec = 6;
                                                                                    }
                                                                                    const size_t end_pos = _fmt_f64_to_buf((&temp_buf[0]), 0, 255, fval, prec, 0, 0, 0);
                                                                                    (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), end_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                                                    );
                                                                                } else {
                                                                                    if (spec == 71) {
                                                                                        const double fval = va_arg(ap, double);
                                                                                        uint8_t temp_buf[256] = {0};
                                                                                        int32_t prec = precision;
                                                                                        if (prec < 0) {
                                                                                            prec = 6;
                                                                                        }
                                                                                        const size_t end_pos = _fmt_f64_to_buf((&temp_buf[0]), 0, 255, fval, prec, 0, 1, 1);
                                                                                        (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), end_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                                                        );
                                                                                    } else {
                                                                                        if (spec == 101) {
                                                                                            const double fval = va_arg(ap, double);
                                                                                            uint8_t temp_buf[256] = {0};
                                                                                            int32_t prec = precision;
                                                                                            if (prec < 0) {
                                                                                                prec = 6;
                                                                                            }
                                                                                            const size_t end_pos = _fmt_f64_to_buf((&temp_buf[0]), 0, 255, fval, prec, 1, 0, 0);
                                                                                            (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), end_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                                                            );
                                                                                        } else {
                                                                                            if (spec == 69) {
                                                                                                const double fval = va_arg(ap, double);
                                                                                                uint8_t temp_buf[256] = {0};
                                                                                                int32_t prec = precision;
                                                                                                if (prec < 0) {
                                                                                                    prec = 6;
                                                                                                }
                                                                                                const size_t end_pos = _fmt_f64_to_buf((&temp_buf[0]), 0, 255, fval, prec, 1, 1, 0);
                                                                                                (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), end_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                                                                );
                                                                                            } else {
                                                                                                if (spec == 102) {
                                                                                                    const double fval = va_arg(ap, double);
                                                                                                    uint8_t temp_buf[256] = {0};
                                                                                                    int32_t prec = precision;
                                                                                                    if (prec < 0) {
                                                                                                        prec = 6;
                                                                                                    }
                                                                                                    const size_t end_pos = _fmt_f64_to_buf((&temp_buf[0]), 0, 255, fval, prec, 0, 0, 0);
                                                                                                    (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), end_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                                                                    );
                                                                                                } else {
                                                                                                    if (spec == 70) {
                                                                                                        const double fval = va_arg(ap, double);
                                                                                                        uint8_t temp_buf[256] = {0};
                                                                                                        int32_t prec = precision;
                                                                                                        if (prec < 0) {
                                                                                                            prec = 6;
                                                                                                        }
                                                                                                        const size_t end_pos = _fmt_f64_to_buf((&temp_buf[0]), 0, 255, fval, prec, 0, 0, 1);
                                                                                                        (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), end_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                                                                        );
                                                                                                    } else {
                                                                                                        if (spec == 97) {
                                                                                                            const double fval = va_arg(ap, double);
                                                                                                            uint8_t temp_buf[256] = {0};
                                                                                                            const size_t end_pos = _fmt_f64_hex_to_buf((&temp_buf[0]), 0, 255, fval, precision, 0);
                                                                                                            (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), end_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                                                                            );
                                                                                                        } else {
                                                                                                            if (spec == 65) {
                                                                                                                const double fval = va_arg(ap, double);
                                                                                                                uint8_t temp_buf[256] = {0};
                                                                                                                const size_t end_pos = _fmt_f64_hex_to_buf((&temp_buf[0]), 0, 255, fval, precision, 1);
                                                                                                                (void)(_fmt_apply_padding((&ctx), (&temp_buf[0]), end_pos, width, (flags & _FMT_MINUS), (flags & _FMT_ZERO))                                                                                                                );
                                                                                                            } else {
                                                                                                                if (spec == 37) {
                                                                                                                    ctx.total_len = (ctx.total_len + 1);
                                                                                                                    if (ctx.buf_pos < ctx.buf_max) {
                                                                                                                        ctx.buf[ctx.buf_pos] = 37;
                                                                                                                        ctx.buf_pos = (ctx.buf_pos + 1);
                                                                                                                    }
                                                                                                                } else {
                                                                                                                    ctx.total_len = (ctx.total_len + 2);
                                                                                                                    if (ctx.buf_pos < ctx.buf_max) {
                                                                                                                        ctx.buf[ctx.buf_pos] = 37;
                                                                                                                        ctx.buf_pos = (ctx.buf_pos + 1);
                                                                                                                    }
                                                                                                                    if (ctx.buf_pos < ctx.buf_max) {
                                                                                                                        ctx.buf[ctx.buf_pos] = spec;
                                                                                                                        ctx.buf_pos = (ctx.buf_pos + 1);
                                                                                                                    }
                                                                                                                }
                                                                                                            }
                                                                                                        }
                                                                                                    }
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                    }
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            continue;
        } else {
            ctx.total_len = (ctx.total_len + 1);
            if (ctx.buf_pos < ctx.buf_max) {
                ctx.buf[ctx.buf_pos] = c;
                ctx.buf_pos = (ctx.buf_pos + 1);
            }
        }
        format_pos = (format_pos + 1);
    }
    if (((use_buf == 0) && (stream != NULL))) {
        if (write_to_buffer(stream, (const char *)(&local_buf[0]), ctx.buf_pos) < 0) {
                        {
                int32_t _uya_ret = (0 - 1);
                return _uya_ret;
                        }
        }
    } else {
        if (((out_buf != NULL) && (buf_size > 0))) {
            const size_t term_pos = ctx.buf_pos;
            if (term_pos < buf_size) {
                out_buf[term_pos] = 0;
            } else {
                out_buf[(buf_size - 1)] = 0;
            }
        }
    }
    if (use_buf > 0) {
                {
            int32_t _uya_ret = (int32_t)ctx.total_len;
            return _uya_ret;
                }
    }
        {
        int32_t _uya_ret = (int32_t)ctx.buf_pos;
        return _uya_ret;
        }
}

static __attribute__((used)) void _fmt_u32_to_buf(struct _FmtContext * ctx, uint32_t value) {
    (void)ctx;
    (void)value;
    uint32_t num = value;
    uint8_t digits[16] = {0};
    size_t digit_idx = 0;
    if (num == 0) {
        digits[0] = 48;
        digit_idx = 1;
    } else {
        const uint32_t ten = 10;
        while (((num > 0) && (digit_idx < 16))) {
            const int32_t digit = (int32_t)(num % ten);
            digits[digit_idx] = (uint8_t)(48 + digit);
            digit_idx = (digit_idx + 1);
            num = (num / ten);
        }
    }
    ctx->total_len = (ctx->total_len + digit_idx);
    size_t i = 0;
    while (((i < digit_idx) && (ctx->buf_pos < ctx->buf_max))) {
        ctx->buf[ctx->buf_pos] = digits[((digit_idx - 1) - i)];
        ctx->buf_pos = (ctx->buf_pos + 1);
        i = (i + 1);
    }
}

static __attribute__((used)) void _fmt_u64_to_buf(struct _FmtContext * ctx, uint64_t value) {
    (void)ctx;
    (void)value;
    uint64_t num = value;
    uint8_t digits[24] = {0};
    size_t digit_idx = 0;
    if (num == 0) {
        digits[0] = 48;
        digit_idx = 1;
    } else {
        const uint64_t ten = 10;
        while (((num > 0) && (digit_idx < 24))) {
            const int32_t digit = (int32_t)(num % ten);
            digits[digit_idx] = (uint8_t)(48 + digit);
            digit_idx = (digit_idx + 1);
            num = (num / ten);
        }
    }
    ctx->total_len = (ctx->total_len + digit_idx);
    size_t i = 0;
    while (((i < digit_idx) && (ctx->buf_pos < ctx->buf_max))) {
        ctx->buf[ctx->buf_pos] = digits[((digit_idx - 1) - i)];
        ctx->buf_pos = (ctx->buf_pos + 1);
        i = (i + 1);
    }
}

__attribute__((used)) int32_t vfprintf(struct FILE * stream, const char * format, va_list ap) {
    (void)stream;
    (void)format;
    (void)ap;
    if (((stream == NULL) || (format == NULL))) {
                {
            int32_t _uya_ret = (0 - 1);
            return _uya_ret;
                }
    }
    const int64_t fd = stream->fd;
    if (fd < 0) {
                {
            int32_t _uya_ret = (0 - 1);
            return _uya_ret;
                }
    }
        {
        int32_t _uya_ret = _vfprintf_impl(stream, (const uint8_t *)format, ap, 0, NULL, 0);
        return _uya_ret;
        }
}

__attribute__((used)) int32_t vsnprintf(char * buf, size_t n, const char * format, va_list ap) {
    (void)buf;
    (void)n;
    (void)format;
    (void)ap;
    if (((buf == NULL) || (format == NULL))) {
                {
            int32_t _uya_ret = (0 - 1);
            return _uya_ret;
                }
    }
        {
        int32_t _uya_ret = _vfprintf_impl(NULL, (const uint8_t *)format, ap, 1, (uint8_t *)buf, n);
        return _uya_ret;
        }
}


__attribute__((used)) int32_t snprintf(char * buf, size_t n, const char * format, ...) {
    (void)buf;
    (void)n;
    (void)format;
    if ((((buf == NULL) || (format == NULL)) || (n == 0))) {
                {
            int32_t _uya_ret = (0 - 1);
            return _uya_ret;
                }
    }
    va_list ap;
    (void)(va_start(ap, format)    );
    const int32_t result = vsnprintf((char *)buf, n, (const char *)format, ap);
    (void)(va_end(ap)    );
        {
        int32_t _uya_ret = result;
        return _uya_ret;
        }
}



__attribute__((used)) int32_t readlink(const char * path, char * buf, size_t bufsiz) {
    (void)path;
    (void)buf;
    (void)bufsiz;
    if ((((path == NULL) || (buf == NULL)) || (bufsiz == 0))) {
                {
            int32_t _uya_ret = (0 - 1);
            return _uya_ret;
                }
    }
    struct err_union_intptr_t result = sys_readlink((const char *)(const uint8_t *)path, (char *)(uint8_t *)buf, bufsiz);
    const intptr_t ret = ({ struct err_union_intptr_t _uya_catch_tmp = result; __typeof__(_uya_catch_tmp.value) _uya_catch_result; if (_uya_catch_tmp.error_id != 0) {
                {
            int32_t _uya_ret = (0 - 1);
            return _uya_ret;
                }
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
    if (ret < 0) {
                {
            int32_t _uya_ret = (0 - 1);
            return _uya_ret;
                }
    }
        {
        int32_t _uya_ret = (int32_t)ret;
        return _uya_ret;
        }
}




__attribute__((used)) size_t strlen(const char * s) {
    (void)s;
    if (s == NULL) {
                {
            size_t _uya_ret = 0;
            return _uya_ret;
                }
    }
    size_t len = 0;
    while (s[len] != 0) {
        len = (len + 1);
    }
        {
        size_t _uya_ret = len;
        return _uya_ret;
        }
}

__attribute__((used)) int32_t strcmp(const char * s1, const char * s2) {
    (void)s1;
    (void)s2;
    if (((s1 == NULL) || (s2 == NULL))) {
                {
            int32_t _uya_ret = 0;
            return _uya_ret;
                }
    }
    size_t i = 0;
    while (((s1[i] != 0) && (s2[i] != 0))) {
        const uint8_t b1 = s1[i];
        const uint8_t b2 = s2[i];
        if (b1 < b2) {
                        {
                int32_t _uya_ret = (-1);
                return _uya_ret;
                        }
        }
        if (b1 > b2) {
                        {
                int32_t _uya_ret = 1;
                return _uya_ret;
                        }
        }
        i = (i + 1);
    }
    if (((s1[i] == 0) && (s2[i] != 0))) {
                {
            int32_t _uya_ret = (-1);
            return _uya_ret;
                }
    }
    if (((s1[i] != 0) && (s2[i] == 0))) {
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
        {
        int32_t _uya_ret = 0;
        return _uya_ret;
        }
}


__attribute__((used)) char * strrchr(const char * s, int32_t c) {
    (void)s;
    (void)c;
    if (s == NULL) {
                {
            char * _uya_ret = (char *)NULL;
            return _uya_ret;
                }
    }
    const uint8_t val = (uint8_t)c;
    uint8_t * last = NULL;
    size_t i = 0;
    while (s[i] != 0) {
        if (s[i] == val) {
            last = (uint8_t *)(void *)(uintptr_t)(((uintptr_t)(s) + i));
        }
        i = (i + 1);
    }
    if (val == 0) {
                {
            char * _uya_ret = (char *)(uint8_t *)(void *)(uintptr_t)(((uintptr_t)(s) + i));
            return _uya_ret;
                }
    }
        {
        char * _uya_ret = (char *)last;
        return _uya_ret;
        }
}































__attribute__((used)) struct err_union_intptr_t sys_write(int32_t fd, const char * buf, size_t count) {
    (void)fd;
    (void)buf;
    (void)count;
        {
        struct err_union_intptr_t _uya_ret = ({ struct err_union_int64_t _uya_asbang_src = ({ long _uya_syscall_ret = uya_syscall3(libc_SYS_write, (int64_t)fd, (int64_t)buf, (int64_t)count); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; }); struct err_union_intptr_t _uya_asbang; if (_uya_asbang_src.error_id != 0) { _uya_asbang.error_id = _uya_asbang_src.error_id; _uya_asbang.value = (intptr_t){0}; } else { _uya_asbang.error_id = 0; _uya_asbang.value = (intptr_t)(_uya_asbang_src.value); } _uya_asbang; });
        return _uya_ret;
        }
        return (struct err_union_intptr_t){0};
}

__attribute__((used)) void sys_exit(int32_t status) {
    (void)status;
    (void)(({ long _uya_syscall_ret = uya_syscall1(libc_SYS_exit, (int64_t)status); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; }));
}

__attribute__((used)) struct err_union_int32_t sys_access(const char * pathname, int32_t mode) {
    (void)pathname;
    (void)mode;
        {
        struct err_union_int32_t _uya_ret = ({ struct err_union_int64_t _uya_asbang_src = ({ long _uya_syscall_ret = uya_syscall2(libc_SYS_access, (int64_t)pathname, (int64_t)mode); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; }); struct err_union_int32_t _uya_asbang; if (_uya_asbang_src.error_id != 0) { _uya_asbang.error_id = _uya_asbang_src.error_id; _uya_asbang.value = (int32_t){0}; } else { _uya_asbang.error_id = 0; _uya_asbang.value = (int32_t)(_uya_asbang_src.value); } _uya_asbang; });
        return _uya_ret;
        }
        return (struct err_union_int32_t){0};
}

__attribute__((used)) struct err_union_voidptr sys_mmap(void * addr, size_t length, int32_t prot, int32_t flags, int32_t fd, int64_t offset) {
    (void)addr;
    (void)length;
    (void)prot;
    (void)flags;
    (void)fd;
    (void)offset;
        {
        struct err_union_voidptr _uya_ret = ({ struct err_union_int64_t _uya_asbang_src = ({ long _uya_syscall_ret = uya_syscall6(libc_SYS_mmap, (int64_t)addr, (int64_t)length, (int64_t)prot, (int64_t)flags, (int64_t)fd, (int64_t)offset); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; }); struct err_union_voidptr _uya_asbang; if (_uya_asbang_src.error_id != 0) { _uya_asbang.error_id = _uya_asbang_src.error_id; _uya_asbang.value = (void *){0}; } else { _uya_asbang.error_id = 0; _uya_asbang.value = (void *)(_uya_asbang_src.value); } _uya_asbang; });
        return _uya_ret;
        }
        return (struct err_union_voidptr){0};
}

__attribute__((used)) int32_t sys_futex(int32_t * uaddr, int32_t op, int32_t val, void * timeout) {
    (void)uaddr;
    (void)op;
    (void)val;
    (void)timeout;
    struct err_union_int64_t r = ({ long _uya_syscall_ret = uya_syscall6(libc_SYS_futex, (int64_t)uaddr, (int64_t)op, (int64_t)val, (int64_t)timeout, 0, 0); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; });
    const int64_t v = ({ struct err_union_int64_t _uya_catch_tmp = r; __typeof__(_uya_catch_tmp.value) _uya_catch_result; if (_uya_catch_tmp.error_id != 0) {
                {
            int32_t _uya_ret = (-1);
            return _uya_ret;
                }
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; });
        {
        int32_t _uya_ret = (int32_t)v;
        return _uya_ret;
        }
}

__attribute__((used)) struct err_union_intptr_t sys_readlink(const char * pathname, char * buf, size_t bufsiz) {
    (void)pathname;
    (void)buf;
    (void)bufsiz;
        {
        struct err_union_intptr_t _uya_ret = ({ struct err_union_int64_t _uya_asbang_src = ({ long _uya_syscall_ret = uya_syscall3(libc_SYS_readlink, (int64_t)pathname, (int64_t)buf, (int64_t)bufsiz); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; }); struct err_union_intptr_t _uya_asbang; if (_uya_asbang_src.error_id != 0) { _uya_asbang.error_id = _uya_asbang_src.error_id; _uya_asbang.value = (intptr_t){0}; } else { _uya_asbang.error_id = 0; _uya_asbang.value = (intptr_t)(_uya_asbang_src.value); } _uya_asbang; });
        return _uya_ret;
        }
        return (struct err_union_intptr_t){0};
}

__attribute__((used)) struct err_union_int32_t sys_execve(const char * path, const char * * argv, const char * * envp) {
    (void)path;
    (void)argv;
    (void)envp;
        {
        struct err_union_int32_t _uya_ret = ({ struct err_union_int64_t _uya_asbang_src = ({ long _uya_syscall_ret = uya_syscall3(libc_SYS_execve, (int64_t)path, (int64_t)argv, (int64_t)envp); struct err_union_int64_t _uya_result; if (_uya_syscall_ret < 0) { _uya_result.error_id = (int)(-_uya_syscall_ret); } else { _uya_result.error_id = 0; _uya_result.value = _uya_syscall_ret; } _uya_result; }); struct err_union_int32_t _uya_asbang; if (_uya_asbang_src.error_id != 0) { _uya_asbang.error_id = _uya_asbang_src.error_id; _uya_asbang.value = (int32_t){0}; } else { _uya_asbang.error_id = 0; _uya_asbang.value = (int32_t)(_uya_asbang_src.value); } _uya_asbang; });
        return _uya_ret;
        }
}



__attribute__((used)) int32_t execve(const char * pathname, char * * argv, char * * envp) {
    (void)pathname;
    (void)argv;
    (void)envp;
    struct err_union_int32_t result = sys_execve((const char *)pathname, (const char * *)(const uint8_t * *)argv, (const char * *)(const uint8_t * *)envp);
    (void)(({ struct err_union_int32_t _uya_catch_tmp = result; __typeof__(_uya_catch_tmp.value) _uya_catch_result; if (_uya_catch_tmp.error_id != 0) {
        libc_errno = libc_ENOENT;
                {
            int32_t _uya_ret = (0 - 1);
            return _uya_ret;
                }
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; })    );
        {
        int32_t _uya_ret = (0 - 1);
        return _uya_ret;
        }
}

__attribute__((used)) int32_t access(const char * pathname, int32_t mode) {
    (void)pathname;
    (void)mode;
    struct err_union_int32_t result = sys_access((const char *)(const uint8_t *)pathname, mode);
    (void)(({ struct err_union_int32_t _uya_catch_tmp = result; __typeof__(_uya_catch_tmp.value) _uya_catch_result; if (_uya_catch_tmp.error_id != 0) {
        libc_errno = libc_ENOENT;
                {
            int32_t _uya_ret = (0 - 1);
            return _uya_ret;
                }
    } else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; })    );
        {
        int32_t _uya_ret = 0;
        return _uya_ret;
        }
}

int32_t main_main(void) {
    const int32_t argc = std_runtime_get_argc();
    uint8_t * const program_name = std_runtime_get_argv(0);
    if (argc <= 1) {
        (void)(launcher_print_help((uint8_t *)program_name)        );
                {
            int32_t _uya_ret = 1;
            return _uya_ret;
                }
    }
    uint8_t * const first_arg = std_runtime_get_argv(1);
    if (first_arg == NULL) {
                {
            int32_t _uya_ret = launcher_print_compat_diagnostic((uint8_t *)program_name);
            return _uya_ret;
                }
    }
    if (((strcmp((const char *)first_arg, (const char *)(uint8_t *)(uint8_t *)str30) == 0) || (strcmp((const char *)first_arg, (const char *)(uint8_t *)(uint8_t *)str31) == 0))) {
        (void)(launcher_print_help((uint8_t *)program_name)        );
                {
            int32_t _uya_ret = 0;
            return _uya_ret;
                }
    }
    if (((strcmp((const char *)first_arg, (const char *)(uint8_t *)(uint8_t *)str32) == 0) || (strcmp((const char *)first_arg, (const char *)(uint8_t *)(uint8_t *)str33) == 0))) {
        (void)(fprintf(stderr, (const char *)str34)        );
                {
            int32_t _uya_ret = 0;
            return _uya_ret;
                }
    }
    if (strcmp((const char *)first_arg, (const char *)(uint8_t *)(uint8_t *)str35) == 0) {
                {
            int32_t _uya_ret = launcher_print_microapp_image_migration((uint8_t *)program_name, (uint8_t *)first_arg, (uint8_t *)(uint8_t *)str36);
            return _uya_ret;
                }
    }
    if (strcmp((const char *)first_arg, (const char *)(uint8_t *)(uint8_t *)str37) == 0) {
                {
            int32_t _uya_ret = launcher_print_microapp_image_migration((uint8_t *)program_name, (uint8_t *)first_arg, (uint8_t *)(uint8_t *)str38);
            return _uya_ret;
                }
    }
    if (strcmp((const char *)first_arg, (const char *)(uint8_t *)(uint8_t *)str39) == 0) {
                {
            int32_t _uya_ret = launcher_print_microapp_image_migration((uint8_t *)program_name, (uint8_t *)first_arg, (uint8_t *)(uint8_t *)str40);
            return _uya_ret;
                }
    }
    if (launcher_is_external_cmd((uint8_t *)first_arg) != 0) {
                {
            int32_t _uya_ret = launcher_dispatch_external_cmd((uint8_t *)first_arg);
            return _uya_ret;
                }
    }
        {
        int32_t _uya_ret = launcher_print_compat_diagnostic((uint8_t *)program_name);
        return _uya_ret;
        }
}
int32_t main(int32_t argc, char **argv) {
    saved_argc = argc;
    saved_argv = (uint8_t **)argv;
    if (((argv != NULL) && (argc >= 0))) {
        const size_t argv_addr = (uintptr_t)((void *)argv);
        const size_t envp_addr = (argv_addr + (((size_t)argc + 1) * /* optimized */ 8));
        saved_envp = (uint8_t * *)(void *)(uintptr_t)(envp_addr);
    } else {
        saved_envp = NULL;
    }
    (void)(std_runtime_entry_set_process_stack_limit_bytes(ENTRY_DEFAULT_STACK_LIMIT_BYTES)    );
        {
        int32_t _uya_ret = main_main();
        return _uya_ret;
        }
}
int32_t _uya_async_frame_heap_fallback = 0;
