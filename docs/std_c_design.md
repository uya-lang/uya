# std/libc 标准库设计文档

## 核心目标

1. **编译器完全不依赖外部 C 标准库**
   - Uya 编译器自身使用 libc（自己实现的标准库）
   - 编译器构建时不需要链接 glibc/musl
   - 实现真正的自举：用 Uya 实现的编译器 + 用 Uya 实现的标准库

2. **生成无依赖的 libc 给第三方使用**
   - 通过 `--outlibc` 生成单文件 C 库（libuya.c + libuya.h）
   - 生成的库零外部依赖，可替代 musl/glibc
   - 支持 freestanding 编译（-nostdlib）

---

## 架构概览

```
lib/
├── std/                          # Uya 风格标准库（使用现代特性）
│   ├── core/                     # 核心类型和 trait（v0.6.0 Sprint 6）
│   │   ├── error.uya             # 错误类型定义（使用 union）
│   │   ├── option.uya            # Option<T> = union { some: T, none }
│   │   # （不引入 Result<T, E>，使用 !T 代替）
│   │   └── traits.uya            # 核心接口（Clone, Eq, Ord, Hash）
│   ├── io/                       # I/O 抽象（v0.6.0 Sprint 7）
│   │   ├── writer.uya            # interface Writer
│   │   ├── reader.uya            # interface Reader
│   │   └── file.uya              # struct File : Writer, Reader
│   ├── string/                   # 字符串操作（v0.6.0 Sprint 8）
│   │   └── string.uya            # 安全字符串函数
│   ├── mem/                      # 内存操作
│   │   └── mem.uya               # 内存函数
│   ├── collections/              # 泛型容器（v0.6.0 Sprint 9）
│   │   ├── vec.uya               # struct Vec<T>
│   │   └── string_buf.uya        # struct StringBuf
│   ├── syscall/                  # 系统调用封装
│   │   └── linux.uya             # Linux syscall 封装
│   ├── fmt/                      # 格式化
│   │   └── fmt.uya               # format<T: Display>
│   └── runtime/                  # 运行时支持
│       └── runtime.uya           # 程序入口、panic 处理
│
└── libc/                         # C 兼容层（薄封装，v0.6.0 Sprint 10）
    ├── syscall.uya               # syscall 封装（调用 std.syscall）
    ├── string.uya                # C 签名：strlen, strcmp...（调用 std.string）
    ├── stdio.uya                 # C 签名：printf, fopen...（调用 std.io）
    ├── stdlib.uya                # C 签名：malloc, free...（调用 std.mem）
    ├── mem.uya                   # C 签名：memcpy, memset...
    └── unistd.uya                # C 签名：read, write...
```

**分层依赖**：
```
libc/  →  std/  →  syscall/
(C ABI)  (Uya)    (底层)
```

---

## 已实现模块（v0.5.x）

### 1. libc.syscall - 系统调用封装

**文件**：`lib/libc/syscall.uya`

**已实现**：
- ✅ `@syscall` 内置函数封装
- ✅ Linux x86-64 系统调用号常量
- ✅ 系统调用封装：`sys_write`, `sys_read`, `sys_open`, `sys_close`, `sys_exit`, `sys_mmap`, `sys_munmap`, `sys_lseek`, `sys_access`, `sys_unlink`, `sys_mkdir`, `sys_rmdir`, `sys_chdir`, `sys_getcwd`, `sys_getpid`, `sys_getdents64`, `sys_stat`, `sys_readlink`

### 2. libc.string - 字符串操作

**文件**：`lib/libc/string.uya`

**已实现**：
- ✅ `strlen`, `strcmp`, `strncmp`, `strcasecmp`, `strncasecmp`
- ✅ `strcpy`, `strncpy`, `strcat`, `strncat`
- ✅ `strchr`, `strrchr`, `strstr`
- ✅ `strdup`, `strndup`
- ✅ `strcspn`, `strspn`, `strpbrk`, `strtok`

### 3. libc.stdio - 标准 I/O

**文件**：`lib/libc/stdio.uya`

**已实现**：
- ✅ `FILE` 结构体、`stdin`/`stdout`/`stderr`
- ✅ `put_char`, `printf`, `fprintf`, `sprintf`
- ✅ `fopen`, `fclose`, `fread`, `fwrite`
- ✅ `fgets`, `fputs`, `fgetc`, `fputc`
- ✅ `fseek`, `ftell`, `fflush`, `feof`

### 4. libc.stdlib - 标准库

**文件**：`lib/libc/stdlib.uya`

**已实现**：
- ✅ `malloc`, `free`, `calloc`, `realloc`（基于 mmap）
- ✅ `exit`, `abort`
- ✅ `atoi`, `atol`, `atof`, `strtod`, `strtol`, `strtoul`
- ✅ `abs`, `labs`
- ✅ `getenv`, `stat`, `readlink`
- ✅ `opendir`, `readdir`, `closedir`

### 5. libc.mem - 内存操作

**文件**：`lib/libc/mem.uya`

**已实现**：
- ✅ `memcpy`, `memmove`, `memset`, `memcmp`, `memchr`

### 6. libc.unistd - UNIX 标准

**文件**：`lib/libc/unistd.uya`

**已实现**：
- ✅ `read`, `write`, `close`, `lseek`
- ✅ `access`, `unlink`, `mkdir`, `rmdir`, `chdir`, `getcwd`

### 7. libc.ctype - 字符分类

**文件**：`lib/libc/ctype.uya`

**已实现**：
- ✅ `isalpha`, `isdigit`, `isalnum`, `isspace`, `isupper`, `islower`
- ✅ `toupper`, `tolower`

### 8. libc.errno - 错误码

**文件**：`lib/libc/errno.uya`

**已实现**：
- ✅ 标准错误码常量（EPERM, ENOENT, ESRCH, EINTR, EIO, ...）
- ✅ `errno` 全局变量
- ✅ `strerror` - 错误码转字符串

---

## v0.6.0 重构计划

详见 [`docs/std_refactor_design.md`](./std_refactor_design.md)

### Sprint 6: std.core 核心类型

**目标**：实现 Option<T>, Error 等核心类型（使用 !T 处理错误）

```uya
// 错误类型定义
union Error {
    None,                        // 无错误
    Message: &[i8],             // 错误消息
    Code: i32,                  // 错误码
    System: i32                 // 系统错误码（errno）
}

// Option<T> - 可选值（非错误语义）
union Option<T> {
    Some: T,
    None
}

// 错误处理使用 !T（error union type）
// fn open(path: &const byte) !File;  // 返回 File 或 error

// 核心接口
interface Clone {
    fn clone(self: &Self) Self;
}

interface Eq {
    fn eq(self: &Self, other: &Self) bool;
}

interface Ord {
    fn cmp(self: &Self, other: &Self) i32;
}

interface Hash {
    fn hash(self: &Self) u64;
}

interface Display {
    fn fmt(self: &Self, writer: &Writer) !void;
}
```

### Sprint 7: std.io I/O 抽象层

**目标**：使用 interface 定义 I/O 抽象

```uya
interface Writer {
    fn write(self: &Self, data: &[u8]) !usize;
    fn write_str(self: &Self, s: &const byte) !usize;
    fn flush(self: &Self) !void;
}

interface Reader {
    fn read(self: &Self, buf: &[u8]) !usize;
    fn read_exact(self: &Self, buf: &[u8]) !void;
}

struct File : Writer, Reader {
    fd: i32,
    // ...
}
```

### Sprint 8: std.string 安全字符串操作

**目标**：使用 !T 错误处理重构字符串操作

```uya
// 返回错误版本
export fn parse_int(s: &const byte) !i32;
export fn parse_uint(s: &const byte) !u32;
export fn parse_float(s: &const byte) !f64;

// 安全复制（带边界检查）
export fn copy_safe(dst: &byte, dst_len: usize, src: &const byte) !void;
```

### Sprint 9: std.collections 泛型容器

**目标**：实现泛型容器

```uya
struct Vec<T> {
    data: &T,
    len: usize,
    cap: usize,
    
    fn push(self: &Self, value: T) !void;
    fn pop(self: &Self) Option<T>;
    fn get(self: &Self, i: usize) !&T;
}

struct StringBuf {
    buf: Vec<u8>,
    
    fn push_str(self: &Self, s: &const byte) !void;
    fn as_str(self: &Self) &[i8];
}
```

### Sprint 10: libc 薄封装

**目标**：在 std 基础上实现 C 兼容层

```uya
// libc.string - 调用 std 实现，保持 C 签名
export extern fn strlen(s: *const byte) usize {
    return std.strlen(s as &const byte);
}

export extern fn strcmp(s1: *const byte, s2: *const byte) i32 {
    return std.strcmp(s1 as &const byte, s2 as &const byte);
}
```

---

## --outlibc 功能

**命令**：`uya --outlibc <目录>`

**生成文件**：
- `libuya.h` - 头文件（类型定义 + 函数声明）
- `libuya.c` - 实现文件（所有函数实现）

**使用方法**：
```bash
# 生成库
uya --outlibc /tmp/libuya

# 编译
gcc -c libuya.c -o libuya.o

# freestanding 模式
gcc -nostdlib -ffreestanding your_program.c libuya.o -o your_program -lgcc
```

---

## 核心特性

- ✅ **完全用 Uya 实现**：所有模块都是纯 Uya 代码
- ✅ **零外部依赖**：直接使用系统调用
- ✅ **单文件输出**：`--outlibc` 生成单个 .c 和 .h 文件
- ✅ **可替代 musl/glibc**：兼容 C ABI
- ✅ **零标准库头文件**：生成的代码自己定义所有类型

## v0.6.0 新特性

- 🎯 **类型安全**：std 使用 !T, Option<T>
- 🎯 **接口抽象**：Writer, Reader, Clone, Eq, Ord
- 🎯 **泛型容器**：Vec<T>, StringBuf
- 🎯 **libc 薄封装**：调用 std 实现，零重复代码
