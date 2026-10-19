# std/libc 标准库设计文档

> **最后核对**：2026-10-19。依据：`lib/std/` 实际目录、`lib/libc/`（16 个文件）、`lib/syscall/linux.uya`、`lib/std/platform.uya`、`src/main.uya`（`std.cfg` 与 `--outlibc` 实现）。§架构概览 的目录树、§分层依赖 的方向、各 Sprint 的完成状态已按现状标注；Sprint 代码块本身是**设计样稿**，不是当前源码。

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
├── syscall/                      # 实际位置：顶层 lib/syscall/，不在 std 下
│   └── linux.uya                 # Linux syscall 封装（export fn sys_*）
│
├── mem/                          # 顶层纯内存层
│   ├── mem.uya                   # copy / set / cmp
│   └── string.uya                # strlen / strcmp / strcpy...
│
├── osal/                         # 顶层 OS 抽象层
│   └── osal.uya
│
├── std/                          # Uya 风格标准库（使用现代特性）
│   ├── core/                     # 核心类型和 trait
│   │   ├── error.uya             # 错误类型定义
│   │   ├── option.uya            # Option<T> = union { Some: T, None } + i32 专用辅助
│   │   └── traits.uya            # Clone, Eq, Ord, Hash, Display（5 个 interface）
│   ├── io/                       # I/O 抽象
│   │   ├── writer.uya            # interface Writer
│   │   ├── reader.uya            # interface Reader
│   │   ├── file.uya              # File{fd, owns_fd} + file_open/read/write/close + FILE 流
│   │   └── stream.uya
│   ├── string/                   # 字符串操作
│   │   └── string.uya            # strlen/strcmp/strncmp/strcpy/strncpy/strcat/strchr/strrchr/strstr
│   ├── mem/                      # 内存操作
│   │   ├── mem.uya               # 内存函数
│   │   ├── allocator.uya         # IAllocator + MallocAllocator
│   │   ├── heap.uya              # HeapAllocator（libc.sys_mmap）
│   │   └── arena.uya             # Arena（bump）
│   ├── collections/              # 泛型容器
│   │   ├── vec.uya               # struct Vec<T>
│   │   ├── string_buf.uya        # struct StringBuf
│   │   ├── hashmap.uya
│   │   ├── ring_queue.uya
│   │   └── vec_helper.uya
│   ├── fmt/                      # 格式化
│   ├── runtime/                  # 运行时支持（entry / panic）
│   ├── testing/                  # 测试框架（test_suite_begin / run_test / assert_eq_*）
│   └── encoding/ crypto/ http/ json/ yaml/ protobuf/ sql/ image/
│       net/ mqtt/ script/ microapp/ exec_test/
│
└── libc/                         # C 兼容层（薄封装）
    ├── syscall.uya               # sys_* 封装（直接用 @syscall，不 use std）
    ├── string.uya                # C 签名：strlen, strcmp...
    ├── stdio.uya                 # C 签名：printf, fopen...
    ├── stdlib.uya                # C 签名：malloc, free...
    ├── mem.uya                   # C 签名：memcpy, memset...
    ├── heap.uya                  # malloc/free/realloc 堆
    ├── unistd.uya                # C 签名：read, write...
    ├── pthread.uya / time.uya / signal.uya / setjmp.uya
    ├── ctype.uya / errno.uya / math.uya / wchar.uya / stdarg.uya
```

**分层依赖（现状，2026-10-19 核对）**：

```
std/   →   libc/   →   内置 @syscall / lib/syscall
(Uya)      (C ABI)     (底层)
```

> 与设计稿的差异：设计稿写的是 `libc/ → std/ → syscall/`（libc 调用 std 实现），**实际是反方向**——`lib/std/` 有 23 个文件、共 154 条 `use libc.*`（`grep -rl "use libc\." lib/std/` / `grep -rh "^use libc\." lib/std/ | wc -l`，2026-10-19），而 `lib/libc/` 里**没有** `use std.*`（少数 shim 例外：`use std.runtime` 取 argv/env）。因此 `std` 位于 `libc` 之上，libc 仍是自包含实现，`std/ → libc/ → 内置 @syscall` 是当前真实链路。

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

**状态（2026-10-19）：部分完成。**

- `lib/std/core/option.uya`：`export union Option<T>` + `option_is_some_i32` / `option_is_none_i32` / `option_unwrap_or_i32`（目前只有 i32 专用辅助函数），测试 `tests/test_option_core.uya`、`tests/test_option_struct.uya`
- `lib/std/core/traits.uya`：5 个 `export interface`，但形状与设计稿不同 —— `Ord` 是 `fn lt(self: &Self, other: &Self) bool`（不是 `cmp -> i32`）、`Display` 是 `fn fmt_len(self: &Self) usize`（不是 `fmt(writer) !void`）
- `lib/std/core/error.uya`：**不是**设计稿的 `union Error`，而是 5 条**未加 `export`** 的 `error` 声明（`IOError`、`PermissionDenied`、`NotFound`、`InvalidArgument`、`UnexpectedEof`），注释说明是 `lib/std/error.uya` 的包装占位

**设计稿**（保留作目标形态）：

```uya
// 错误类型定义
union Error {
    None,                        // 无错误
    Message: &[i8],             // 错误消息
    Code: i32,                  // 错误码
    System: i32                 // 系统错误码（errno）
}

// Option<T> - 可选值
union Option<T> {
    Some: T,
    None
}

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

**状态（2026-10-19）：部分完成。** `writer.uya`（5 行）、`reader.uya`（6 行）只有接口声明；`file.uya` 提供 `export struct File { fd: i32, owns_fd: bool }` + `file_open` / `file_close` / `file_read` / `file_write`，以及一套同布局的 `FILE` 流缓冲（`fopen`/`fread`/`fwrite`/`fgetc`/`fputc`/`fputs`/`fflush`…）。**`struct File : Writer, Reader` 尚未落地**（`File` 没有声明接口实现），测试见 `tests/test_std_io_file.uya`。

**设计稿**（保留作目标形态）：

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

**状态（2026-10-19）：** 基本未做。`lib/std/string/string.uya` 只导出 C 风格函数：`strlen`、`strcmp`、`strncmp`、`strcpy`、`strncpy`、`strcat`、`strchr`、`strrchr`、`strstr`；`grep -rn "parse_int\|parse_uint\|parse_float\|copy_safe" lib/std/string/` 无命中——设计稿列出的 `parse_int` / `parse_uint` / `parse_float` / `copy_safe` **都不存在**。

**设计稿**（保留作目标形态）：

```uya
// 返回错误版本
export fn parse_int(s: &const byte) !i32;
export fn parse_uint(s: &const byte) !u32;
export fn parse_float(s: &const byte) !f64;

// 安全复制（带边界检查）
export fn copy_safe(dst: &byte, dst_len: usize, src: &const byte) !void;
```

### Sprint 9: std.collections 泛型容器

**状态（2026-10-19）：已完成。** `lib/std/collections/vec.uya`（`export struct Vec<T>` + `export fn vec_new<T>(allocator: IAllocator)`）、`string_buf.uya`、`hashmap.uya`、`ring_queue.uya`、`vec_helper.uya` 均已落地；测试 `tests/test_vec.uya`、`test_string_buf.uya`、`test_string_buf_vec_field.uya`、`test_hashmap.uya`、`test_std_ring_queue.uya`、`test_vec_helper.uya`。实际字段/方法与下方设计稿不完全一致，以源码为准。

**设计稿**（保留作目标形态）：

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
    data: &byte,
    len: usize,
    cap: usize,
    
    fn push(self: &Self, c: byte) !void;
    fn push_str(self: &Self, s: &const byte) !void;
    fn as_str(self: &Self) &[const byte];
    fn append_slice(self: &Self, s: &[const byte]) !void;
    fn clear(self: &Self) void;
}
```

### Sprint 10: libc 薄封装

**状态（2026-10-19）：未开始。** `grep -rln "use osal\|use mem\." lib/libc/` 无命中，`lib/libc/string.uya` 等仍是自包含实现（不调用 `std.string` / `std.mem`），因此「libc 调用 std 实现、零重复代码」的目标尚未达成（也见 `std_refactor_design.md` Phase 4 的搁置说明）。

**设计稿**（保留作目标形态）：

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

**实现状态（2026-10-19）**：CLI 侧已接线——`src/main.uya:105` 定义 `COMMAND_OUTLIBC`，usage 文本在 `:1083`，参数解析在 `:1674+`（`outlibc_index`）。生成了什么内容本轮未运行验证，只确认了入口存在。

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

## v0.6.0 新特性（2026-10-19 核对状态）

- 🎯 **类型安全**：std 使用 !T, Option<T> —— 部分（`Option<T>` 在 `std.core.option`，只有 i32 辅助函数；`!T` 已是全局风格）
- 🎯 **接口抽象**：Writer, Reader, Clone, Eq, Ord —— 已声明（`std.io` 2 个 + `std.core.traits` 5 个），但几乎没有实现者
- 🎯 **泛型容器**：Vec<T>, StringBuf —— 已完成（另有 hashmap / ring_queue / vec_helper）
- 🎯 **libc 薄封装**：调用 std 实现，零重复代码 —— **未开始**（libc 仍自包含）

---

## `std.cfg` / `std` 平台选择器：条件编译（第一版）

**目标**：在**编译期**按平台裁剪代码，使 Linux 产物不引用 Darwin 符号（反之亦然），从而用纯 Uya 替代编译器里为宿主差异而写的 C 垫片（如 `host_executable_path.c`）。

**当前接口**：

```uya
use std;

std.cfg(std.host_os == .hos_linux, {
    // 仅 Linux 保留
}, {
    // 非 Linux 分支
})
```

- `std.cfg(cond, then, else)` 在语法分析阶段裁剪未命中分支；未选中分支不会进入依赖收集、符号收集或链接路径。
- `else` 分支现在可省略，等价于“未命中时展开为空声明/空语句块”，因此也可以写成多条并列的 `std.cfg(cond, then)` 来替代 `else -> std.cfg(...)` 的嵌套链。
- `then` / `else` 分支在只包含单个顶层声明或单个语句时可以不写 `{}`。
- 当前支持的编译期平台选择器为：`std.host_os`、`std.host_arch`、`std.target_os`、`std.target_arch`。
- `HostOS`、`HostArch`、`TargetOS`、`TargetArch` 枚举定义位于 `lib/std/platform.uya`（变体名带前缀如 `hos_linux`、`ta_x86_64`，避免合并进同一 C 翻译单元时枚举常量重名）；`std.host_os` / `std.target_arch` 等可在普通表达式中作为对应枚举值使用。

例如，可以把多平台分支写成并列形式：

```uya
use std;

std.cfg(std.host_os == .hos_linux, const HOST_TAG: i32 = 1;)
std.cfg(std.host_os == .hos_macos, const HOST_TAG: i32 = 2;)
std.cfg(std.host_os == .hos_windows, const HOST_TAG: i32 = 3;)
```

### 必须区分的维度

| 维度 | 含义 | 典型用途 |
|------|------|----------|
| **宿主（host）** | 正在构建 / 运行当前二进制（如 `bin/uya`）的操作系统与架构 | 编译器自身的 `get_compiler_dir`、`readdir`/`dirent` 布局 |
| **目标（target）** | 用户程序或被编译代码的目标平台（`TARGET_OS` / `UYA_TARGET_OS_*`） | `@asm`、用户态 syscall 映射、`--outlibc` 产物 |

第一版条件编译的**首个落地用例**必须能表达 **host**，以便编译器源码在单仓库内维护、交叉构建时行为正确。

### 首个用例（验收标准）

1. **编译器宿主可执行路径**
   - Linux（含 nostdlib）：`/proc/self/exe` + `readlink`（或等价 syscall）。
   - Darwin：`_NSGetExecutablePath` + `realpath`（或等价）。
   - 未选中的宿主分支**不得**进入链接单元（无未解析 Mach 符号出现在 Linux 上等）。

2. **`struct dirent` 布局**
   - Linux glibc x86_64：`d_type` / `d_name` 偏移与当前一致（如 18 / 19）。
   - Darwin：`d_type` / `d_name` 偏移与 `sys/dirent.h` 一致（如 20 / 21）。
   - 同上：仅生成当前 **host** 对应分支，避免运行时探测或 C 里的 `uya_host_dirent_layout()`。

**当前实现状态**：

- 已在 `src/main.uya` 中用 `std.cfg` 裁剪 Linux 的 `/proc/self/exe` 路径分支。
- 已将 `struct dirent` 的 `d_type` / `d_name` 偏移切到 `std.cfg(std.host_os == ...)` 编译期常量。
- Darwin 宿主：`get_compiler_dir` 在 `hos_macos` 分支用 `_NSGetExecutablePath` + `realpath`（仅该分支进 AST，Linux 产物无 Mach 符号）。

### 与现有能力的关系

- `@asm_target()` 与运行期 `if @asm_target() == …` **不足以**替代上述需求（另一平台代码仍会进入语义/链接路径，除非整段删除）。
- 第一版 `std.cfg` 落地后，`src/main.uya` 已开始将宿主路径与目录扫描改为条件编译分支；后续可继续删除仅为此存在的宿主 C 垫片（在构建链全部改接 Uya 之后）。

**跟踪**：路线图见 [`todo_mini_to_full.md`](./todo_mini_to_full.md) 中 `std.cfg` / 平台选择器条目。
