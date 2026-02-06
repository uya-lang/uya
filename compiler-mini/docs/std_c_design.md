# std.c 标准库设计文档

## 核心目标

1. **编译器完全不依赖外部 C 标准库**
   - Uya 编译器自身使用 std.c（自己实现的标准库）
   - 编译器构建时不需要链接 glibc/musl
   - 实现真正的自举：用 Uya 实现的编译器 + 用 Uya 实现的标准库
   - 编译器可在最小化环境下构建（如 FROM scratch 容器）

2. **生成无依赖的 libc 给第三方使用**
   - 通过 `--outlibc` 生成单文件 C 库（libuya.c + libuya.h）
   - 生成的库零外部依赖，可替代 musl/glibc
   - 第三方 C/C++/Rust 项目可直接使用
   - 支持 freestanding 编译（-nostdlib）

**设计目标**：构建分层的标准库架构,支持 hosted、freestanding、bare-metal 等多种运行环境，保持编译器核心简洁。

## 架构概览

```
std/
├── c/              # 纯 Uya 实现的 C 标准库（musl 替代）
│   ├── syscall/    # 系统调用封装（Linux/Windows/macOS）
│   ├── string.uya  # 字符串和内存操作
│   ├── stdio.uya   # 标准 I/O
│   ├── stdlib.uya  # 内存分配、进程控制
│   └── math.uya    # 数学函数
├── io/             # 平台无关同步 I/O 抽象（Writer, Reader）
├── async/          # 异步编程标准库（详见 std_async_design.md）
├── fmt/            # 格式化库（纯 Uya 实现）
├── bare_metal/     # 裸机平台支持
└── builtin/        # 编译器内置运行时
```

## 核心特性

- ✅ **完全用 Uya 实现**：std.c 是纯 Uya 代码，不是 FFI 绑定
- ✅ **零外部依赖**：直接使用系统调用，不依赖任何 C 库
- ✅ **双重用途**：
  - 编译器自身使用（构建时不依赖外部 libc）
  - 生成库给第三方（--outlibc）
- ✅ **单文件输出**：`--outlibc` 生成单个 .c 和 .h 文件
- ✅ **可替代 musl/glibc**：兼容 C ABI，可作为 libc 使用
- ✅ **零标准库头文件**：生成的代码自己定义所有类型

## 1. std.io - 同步 I/O 抽象层

**注意**：`std.io` 是**同步（阻塞）**I/O 接口。异步 I/O 请参见 [std.async 设计文档](std_async_design.md)。

### 核心接口

- [ ] **Writer 接口**：统一的同步输出抽象
  ```uya
  export interface Writer {
      fn write(self: &Self, data: &[u8]) !usize;
      fn write_str(self: &Self, s: &[i8]) !usize;
      fn flush(self: &Self) !void;
  }
  ```

- [ ] **Reader 接口**：统一的同步输入抽象
  ```uya
  export interface Reader {
      fn read(self: &Self, buf: &[u8]) !usize;
      fn read_exact(self: &Self, buf: &[u8]) !void;
  }
  ```

- [ ] **辅助函数**：
  - `print_to(writer: &Writer, s: &[i8]) !void`
  - `println_to(writer: &Writer, s: &[i8]) !void`

**涉及**：新建 `std/io/writer.uya`、`std/io/reader.uya`

**与异步的关系**：
- `std.io` 的同步接口返回 `!T`，**不能**被 `@await` 调用
- 在 `@async_fn` 中调用同步 `std.io` 方法虽然语法合法，但会**阻塞当前任务**
- 异步场景应使用 `std.async.io` 中的 `AsyncWriter` / `AsyncReader`（详见 [std.async 设计文档](std_async_design.md)）

## 2. std.c - 纯 Uya 实现的 C 标准库

**设计理念**：完全用 Uya 实现 C 标准库功能，作为 musl 的替代品，不依赖任何外部 C 库。

### 2.1 系统调用层（std/c/syscall/）

**是否需要汇编？是的，但有多种实现方案**

#### 方案对比

| 方案 | 优点 | 缺点 | 推荐度 | 说明 |
|------|------|------|--------|------|
| **A. 内置 `@syscall`** | 实现简单、跨架构 | 功能单一（仅 syscall） | ⭐⭐⭐⭐⭐ | **推荐方案** |
| **B. 外部汇编文件 `.s`** | 灵活 | 构建复杂、难维护 | ⭐⭐ | 需要多文件编译 |
| **C. C 函数 `syscall()`** | 最简单 | 依赖 glibc | ❌ | **违背零依赖目标** |

**说明**：
- Uya 语言规范**不包含 `asm` 关键字**
- 使用 `@syscall` 内置函数实现系统调用
- C99 后端生成内联汇编，利用 C 预处理器处理跨架构

#### 推荐方案：内置 `@syscall` 函数

**实现方案**：使用编译器内置函数 `@syscall`，在 C99 后端生成内联汇编。

- [ ] **编译器实现**：
  - Lexer：识别 `@syscall` 内置函数
  - AST：添加 `AST_BUILTIN_SYSCALL` 节点
  - Parser：解析 `@syscall(n, arg1, arg2, ...)`
  - Checker：验证参数类型（所有参数必须可转为 i64）
  - C99 Codegen：生成 GNU C 内联汇编代码

**C99 后端代码生成**（`codegen/c99/expr.c`）：

生成平台无关的 C 代码，利用 C 编译器的预处理器处理不同架构：

```c
case AST_BUILTIN_SYSCALL: {
    // 生成平台无关的内联汇编（让 C 编译器根据架构选择）
    fprintf(out, "({ ");
    
    // x86-64 架构
    fprintf(out, "#ifdef __x86_64__\n");
    fprintf(out, "register long rax __asm__(\"rax\") = %s; ", 
            gen_expr(node->args[0]));
    if (node->arg_count > 1) {
        fprintf(out, "register long rdi __asm__(\"rdi\") = %s; ", 
                gen_expr(node->args[1]));
    }
    if (node->arg_count > 2) {
        fprintf(out, "register long rsi __asm__(\"rsi\") = %s; ", 
                gen_expr(node->args[2]));
    }
    if (node->arg_count > 3) {
        fprintf(out, "register long rdx __asm__(\"rdx\") = %s; ", 
                gen_expr(node->args[3]));
    }
    fprintf(out, "__asm__ volatile(\"syscall\" : \"+r\"(rax)");
    if (node->arg_count > 1) {
        fprintf(out, " : \"r\"(rdi), \"r\"(rsi), \"r\"(rdx)");
    }
    fprintf(out, " : \"rcx\", \"r11\", \"memory\"); ");
    
    // ARM64 架构
    fprintf(out, "#elif defined(__aarch64__)\n");
    fprintf(out, "register long x8 __asm__(\"x8\") = %s; ", 
            gen_expr(node->args[0]));
    if (node->arg_count > 1) {
        fprintf(out, "register long x0 __asm__(\"x0\") = %s; ", 
                gen_expr(node->args[1]));
    }
    if (node->arg_count > 2) {
        fprintf(out, "register long x1 __asm__(\"x1\") = %s; ", 
                gen_expr(node->args[2]));
    }
    if (node->arg_count > 3) {
        fprintf(out, "register long x2 __asm__(\"x2\") = %s; ", 
                gen_expr(node->args[3]));
    }
    fprintf(out, "__asm__ volatile(\"svc #0\" : \"+r\"(x0)");
    if (node->arg_count > 1) {
        fprintf(out, " : \"r\"(x8), \"r\"(x1), \"r\"(x2)");
    }
    fprintf(out, " : \"memory\"); ");
    
    fprintf(out, "#else\n");
    fprintf(out, "#error \"Unsupported architecture\"\n");
    fprintf(out, "#endif\n");
    
    fprintf(out, "rax; })");  // x86-64 返回 rax
    break;
}
```

**Uya 使用示例**（`std/c/syscall/linux.uya`）：
```uya
// 系统调用号常量（x86-64 Linux）
const SYS_read: i64 = 0;
const SYS_write: i64 = 1;
const SYS_open: i64 = 2;
const SYS_close: i64 = 3;
const SYS_exit: i64 = 60;
const SYS_mmap: i64 = 9;
const SYS_munmap: i64 = 11;

// 编译器内置函数（C99 后端生成内联汇编）
export fn syscall0(n: i64) i64 {
    return @syscall(n);
}

export fn syscall1(n: i64, a1: i64) i64 {
    return @syscall(n, a1);
}

export fn syscall3(n: i64, a1: i64, a2: i64, a3: i64) i64 {
    return @syscall(n, a1, a2, a3);
}

export fn syscall6(n: i64, a1: i64, a2: i64, a3: i64, 
                   a4: i64, a5: i64, a6: i64) i64 {
    return @syscall(n, a1, a2, a3, a4, a5, a6);
}

// 高级封装（类型安全）
export fn sys_write(fd: i32, buf: &u8, count: usize) i64 {
    return syscall3(SYS_write, fd as i64, buf as i64, count as i64);
}

export fn sys_read(fd: i32, buf: &u8, count: usize) i64 {
    return syscall3(SYS_read, fd as i64, buf as i64, count as i64);
}

export fn sys_exit(code: i32) void {
    _ = syscall1(SYS_exit, code as i64);
}
```

**优势**：
- ✅ 快速实现：无需新增语言特性
- ✅ 编译器简单：只需添加一个内置函数
- ✅ 类型安全：Checker 验证参数
- ✅ 跨架构：C 编译器自动选择正确的汇编指令
- ✅ 可移植：不同平台使用相同的 Uya 代码

**说明**：
- Uya 语言规范中**不包含 `asm` 关键字**
- 通过 `@syscall` 内置函数实现系统调用
- C99 后端负责生成正确的汇编代码
- 利用 C 编译器的预处理器（`#ifdef __x86_64__`）处理不同架构

### 2.2 跨平台支持方案

**设计原则**：分层设计 = 平台特定层 + 统一抽象层 + `std.target` 宏

```
std/c/
├── syscall/
│   ├── common.uya      # 统一接口（所有平台）
│   ├── linux.uya       # Linux 实现（x86-64/ARM64/RISC-V）
│   ├── windows.uya     # Windows 实现
│   ├── macos.uya       # macOS 实现（BSD syscall）
│   └── arch/           # 架构特定实现
│       ├── x86_64.uya  # x86-64 汇编封装
│       ├── aarch64.uya # ARM64 汇编封装
│       └── riscv64.uya # RISC-V 汇编封装
├── string.uya          # 平台无关（纯 Uya）
├── stdio.uya           # 平台无关（基于 common）
├── stdlib.uya          # 平台无关（基于 common）
└── math.uya            # 平台无关（纯 Uya）
```

#### 阶段 1：统一接口层（`std/c/syscall/common.uya`）

提供平台无关的统一接口，使用 `std.target` 宏实现跨平台。

**实现**（使用 `std.target` 宏）：

```uya
// std/c/syscall/common.uya
use std.target;
use std.c.syscall.linux;
use std.c.syscall.windows;
use std.c.syscall.macos;

export const STDIN_FILENO: i32 = 0;
export const STDOUT_FILENO: i32 = 1;
export const STDERR_FILENO: i32 = 2;

// 统一接口（使用宏分发）
export fn read(fd: i32, buf: &u8, count: usize) i64 {
    target_os_linux({
        return linux.sys_read(fd, buf, count);
    });
    
    target_os_windows({
        return windows.win_read(fd, buf, count);
    });
    
    target_os_macos({
        return macos.sys_read(fd, buf, count);
    });
}

export fn write(fd: i32, buf: &u8, count: usize) i64 {
    target_os_linux({
        return linux.sys_write(fd, buf, count);
    });
    
    target_os_windows({
        return windows.win_write(fd, buf, count);
    });
    
    target_os_macos({
        return macos.sys_write(fd, buf, count);
    });
}

export fn exit(code: i32) void {
    target_os_linux({
        linux.sys_exit(code);
    });
    
    target_os_windows({
        windows.win_exit(code);
    });
    
    target_os_macos({
        macos.sys_exit(code);
    });
}
```

**第一阶段简化实现**（无需条件编译）：
```uya
// std/c/syscall/common.uya（第一阶段：仅 Linux）
use std.c.syscall.linux;

export const STDIN_FILENO: i32 = 0;
export const STDOUT_FILENO: i32 = 1;
export const STDERR_FILENO: i32 = 2;

export fn read(fd: i32, buf: &u8, count: usize) i64 {
    return linux.sys_read(fd, buf, count);
}

export fn write(fd: i32, buf: &u8, count: usize) i64 {
    return linux.sys_write(fd, buf, count);
}

export fn exit(code: i32) void {
    linux.sys_exit(code);
}
```

#### 阶段 2：Linux 平台实现（`std/c/syscall/linux.uya`）

使用 `std.target` 宏处理不同架构。

```uya
// std/c/syscall/linux.uya
use std.target;

// 根据架构定义不同的 syscall number
target_arch_x64({
    const SYS_read: i64 = 0;
    const SYS_write: i64 = 1;
    const SYS_open: i64 = 2;
    const SYS_close: i64 = 3;
    const SYS_exit: i64 = 60;
    const SYS_mmap: i64 = 9;
    const SYS_munmap: i64 = 11;
});

target_arch_arm64({
    const SYS_read: i64 = 63;
    const SYS_write: i64 = 64;
    const SYS_open: i64 = 56;
    const SYS_close: i64 = 57;
    const SYS_exit: i64 = 93;
    const SYS_mmap: i64 = 222;
    const SYS_munmap: i64 = 215;
});

// 使用 @syscall 内置函数（自动适配架构）
export fn sys_read(fd: i32, buf: &u8, count: usize) i64 {
    return @syscall(SYS_read, fd as i64, buf as i64, count as i64);
}

export fn sys_write(fd: i32, buf: &u8, count: usize) i64 {
    return @syscall(SYS_write, fd as i64, buf as i64, count as i64);
}

export fn sys_exit(code: i32) void {
    _ = @syscall(SYS_exit, code as i64);
}
```

**第一阶段简化实现**（仅 x86-64）：
```uya
// std/c/syscall/linux.uya（第一阶段：仅 x86-64）
const SYS_read: i64 = 0;
const SYS_write: i64 = 1;
const SYS_exit: i64 = 60;

// 直接使用 @syscall，无需中间层
export fn sys_read(fd: i32, buf: &u8, count: usize) i64 {
    return @syscall(SYS_read, fd as i64, buf as i64, count as i64);
}

export fn sys_write(fd: i32, buf: &u8, count: usize) i64 {
    return @syscall(SYS_write, fd as i64, buf as i64, count as i64);
}

export fn sys_exit(code: i32) void {
    _ = @syscall(SYS_exit, code as i64);
}
```

#### 阶段 3：架构特定实现（`std/c/syscall/arch/x86_64.uya`）

```uya
// std/c/syscall/arch/x86_64.uya
// x86-64 架构的 syscall 实现

export fn syscall0(n: i64) i64 {
    return @syscall(n);
}

export fn syscall1(n: i64, a1: i64) i64 {
    return @syscall(n, a1);
}

export fn syscall3(n: i64, a1: i64, a2: i64, a3: i64) i64 {
    return @syscall(n, a1, a2, a3);
}

export fn syscall6(n: i64, a1: i64, a2: i64, a3: i64, 
                   a4: i64, a5: i64, a6: i64) i64 {
    return @syscall(n, a1, a2, a3, a4, a5, a6);
}
```

### 2.3 std.target - 条件编译宏系统

**目标**：提供类型安全的条件编译机制，用于跨平台代码。

**设计原则**：
- 基于 Uya 标准的 `mc` 宏系统
- 通过 `@mc_get_env("TARGET")` 获取目标平台
- 编译期展开，零运行时开销
- 语法清晰，类似 Rust 的 `cfg!` 宏

**模块文件**：`std/target.uya`

#### 实现清单

- [ ] **平台+架构宏**（精确匹配）：
  ```uya
  target_linux_x64(code: stmt)
  target_linux_arm64(code: stmt)
  target_linux_riscv64(code: stmt)
  target_macos_x64(code: stmt)
  target_macos_arm64(code: stmt)
  target_windows_x64(code: stmt)
  target_windows_arm64(code: stmt)
  ```

- [ ] **操作系统宏**（匹配所有架构）：
  ```uya
  target_os_linux(code: stmt)
  target_os_macos(code: stmt)
  target_os_windows(code: stmt)
  target_os_bsd(code: stmt)
  ```

- [ ] **架构宏**（匹配所有操作系统）：
  ```uya
  target_arch_x64(code: stmt)
  target_arch_arm64(code: stmt)
  target_arch_riscv64(code: stmt)
  target_arch_x86(code: stmt)      // 32位
  ```

- [ ] **通用条件宏**：
  ```uya
  target_if(condition: expr, code: stmt)
  target_match(target_expr: expr, arms: stmt)
  ```

#### 完整实现代码

```uya
// std/target.uya
// 条件编译宏系统

// ===== 平台+架构宏 =====

export mc target_linux_x64(code: stmt) stmt {
    const target = @mc_get_env("TARGET");
    if target == "linux-x64" or 
       target == "linux-x86_64" or 
       target == "x86_64-linux-gnu" or
       target == "x86_64-unknown-linux-gnu" {
        @mc_code(code);
    }
}

export mc target_linux_arm64(code: stmt) stmt {
    const target = @mc_get_env("TARGET");
    if target == "linux-arm64" or 
       target == "linux-aarch64" or 
       target == "aarch64-linux-gnu" or
       target == "aarch64-unknown-linux-gnu" {
        @mc_code(code);
    }
}

export mc target_macos_x64(code: stmt) stmt {
    const target = @mc_get_env("TARGET");
    if target == "macos-x64" or 
       target == "x86_64-apple-darwin" {
        @mc_code(code);
    }
}

export mc target_macos_arm64(code: stmt) stmt {
    const target = @mc_get_env("TARGET");
    if target == "macos-arm64" or 
       target == "aarch64-apple-darwin" or
       target == "arm64-apple-darwin" {
        @mc_code(code);
    }
}

export mc target_windows_x64(code: stmt) stmt {
    const target = @mc_get_env("TARGET");
    if target == "windows-x64" or 
       target == "x86_64-pc-windows-msvc" or
       target == "x86_64-w64-mingw32" {
        @mc_code(code);
    }
}

// ===== 操作系统宏 =====

export mc target_os_linux(code: stmt) stmt {
    const target = @mc_get_env("TARGET");
    // 匹配所有 Linux 架构
    if target == "linux-x64" or target == "x86_64-linux-gnu" or
       target == "linux-arm64" or target == "aarch64-linux-gnu" or
       target == "linux-riscv64" or target == "riscv64-linux-gnu" {
        @mc_code(code);
    }
}

export mc target_os_macos(code: stmt) stmt {
    const target = @mc_get_env("TARGET");
    if target == "macos-x64" or target == "x86_64-apple-darwin" or
       target == "macos-arm64" or target == "aarch64-apple-darwin" {
        @mc_code(code);
    }
}

export mc target_os_windows(code: stmt) stmt {
    const target = @mc_get_env("TARGET");
    if target == "windows-x64" or target == "x86_64-pc-windows-msvc" or
       target == "windows-arm64" or target == "aarch64-pc-windows-msvc" {
        @mc_code(code);
    }
}

// ===== 架构宏 =====

export mc target_arch_x64(code: stmt) stmt {
    const target = @mc_get_env("TARGET");
    // 匹配所有 x86-64 平台
    if target == "linux-x64" or target == "x86_64-linux-gnu" or
       target == "macos-x64" or target == "x86_64-apple-darwin" or
       target == "windows-x64" or target == "x86_64-pc-windows-msvc" {
        @mc_code(code);
    }
}

export mc target_arch_arm64(code: stmt) stmt {
    const target = @mc_get_env("TARGET");
    // 匹配所有 ARM64 平台
    if target == "linux-arm64" or target == "aarch64-linux-gnu" or
       target == "macos-arm64" or target == "aarch64-apple-darwin" or
       target == "windows-arm64" or target == "aarch64-pc-windows-msvc" {
        @mc_code(code);
    }
}

export mc target_arch_riscv64(code: stmt) stmt {
    const target = @mc_get_env("TARGET");
    if target == "linux-riscv64" or target == "riscv64-linux-gnu" {
        @mc_code(code);
    }
}
```

#### 使用示例

**示例 1：根据架构定义不同常量**
```uya
use std.target;

target_arch_x64({
    const SYS_write: i64 = 1;
    const SYS_exit: i64 = 60;
});

target_arch_arm64({
    const SYS_write: i64 = 64;
    const SYS_exit: i64 = 93;
});
```

**示例 2：平台特定函数实现**
```uya
use std.target;

export fn get_page_size() usize {
    target_os_linux({
        return 4096;
    });
    
    target_os_macos({
        return 4096;
    });
    
    target_os_windows({
        return 65536;
    });
}
```

**示例 3：完整的跨平台模块**
```uya
// std/c/syscall/common.uya
use std.target;
use std.c.syscall.linux;
use std.c.syscall.macos;
use std.c.syscall.windows;

export fn write(fd: i32, buf: &u8, count: usize) i64 {
    target_os_linux({
        return linux.sys_write(fd, buf, count);
    });
    
    target_os_macos({
        return macos.sys_write(fd, buf, count);
    });
    
    target_os_windows({
        return windows.win_write(fd, buf, count);
    });
}
```

#### 编译方式

```bash
# 设置 TARGET 环境变量
TARGET=linux-x64 ./uya-compiler --c99 --outlibc

# 或使用命令行选项（未来支持）
./uya-compiler --c99 --outlibc --target linux-x64
```

#### 测试用例

- [ ] `test_target_linux_x64.uya` - 测试 Linux x64 条件编译
- [ ] `test_target_macos_arm64.uya` - 测试 macOS ARM64 条件编译
- [ ] `test_target_os_linux.uya` - 测试 Linux 操作系统宏
- [ ] `test_target_arch_x64.uya` - 测试 x64 架构宏
- [ ] `test_target_multi_platform.uya` - 测试多平台代码

**涉及**：新建 `std/target.uya`

### 2.4 核心库实现（纯 Uya）

- [ ] **std.c.string**（`std/c/string.uya`）：
  - `memcpy`, `memset`, `memcmp`, `memmove` - 内存操作
  - `strlen`, `strcmp`, `strncmp` - 字符串比较
  - `strcpy`, `strncpy`, `strcat`, `strncat` - 字符串拷贝
  - 完全用 Uya while 循环实现，无汇编

- [ ] **std.c.stdio**（`std/c/stdio.uya`）：
  - File 结构体（基于文件描述符）
  - `putchar`, `puts` - 基础输出（基于 sys_write）
  - `printf` 简化实现（配合 std.fmt）
  - `fopen`, `fclose`, `fread`, `fwrite` - 文件 I/O
  - 缓冲 I/O 支持

- [ ] **std.c.stdlib**（`std/c/stdlib.uya`）：
  - `malloc`, `free` - 基于 mmap 的内存分配器
  - `calloc`, `realloc` - 内存管理
  - `exit`, `abort` - 进程控制（基于 sys_exit）
  - `getenv` - 环境变量（基于 sys_getenv 或解析 environ）
  - `atoi`, `atof` - 字符串转数字

- [ ] **std.c.math**（`std/c/math.uya`）：
  - `sqrt` - 牛顿迭代法实现
  - `sin`, `cos`, `tan` - 泰勒级数实现
  - `pow`, `exp`, `log` - 数学函数
  - `floor`, `ceil`, `round` - 取整函数
  - 纯 Uya 算法，不依赖 CPU 指令

**实现示例**（memcpy）：
```uya
// std/c/string.uya
export fn memcpy(dest: &u8, src: &u8, n: usize) &u8 {
    var i: usize = 0;
    while i < n {
        dest[i] = src[i];
        i = i + 1;
    }
    return dest;
}
```

**实现示例**（系统调用）：
```uya
// std/c/syscall/linux.uya
export fn sys_write(fd: i32, buf: &[u8]) i64 {
    return syscall3(SYS_write, fd as i64, 
                   &buf[0] as i64, @len(buf) as i64);
}
```

## 3. std.fmt - 格式化库

**纯 Uya 实现的格式化功能**，无需依赖 C 标准库：

- [ ] **基础格式化函数**：
  - `format_i32(buf: &[i8], n: i32) i32` - 整数转字符串
  - `format_i64(buf: &[i8], n: i64) i32`
  - `format_u32(buf: &[i8], n: u32) i32`
  - `format_u64(buf: &[i8], n: u64) i32`
  - `format_bool(buf: &[i8], b: bool) i32` - 布尔值转字符串
  - `format_f32(buf: &[i8], f: f32, precision: i32) i32` - 浮点数转字符串
  - `format_f64(buf: &[i8], f: f64, precision: i32) i32`

- [ ] **Writer 格式化**：
  - `write_i32(writer: &Writer, n: i32) !void`
  - `write_bool(writer: &Writer, b: bool) !void`
  - `write_f64(writer: &Writer, f: f64) !void`

- [ ] **格式说明符支持**：
  - 宽度：`format_i32_width(buf: &[i8], n: i32, width: i32, pad: i8) i32`
  - 十六进制：`format_hex(buf: &[i8], n: u32, uppercase: bool) i32`
  - 八进制：`format_oct(buf: &[i8], n: u32) i32`
  - 二进制：`format_bin(buf: &[i8], n: u32) i32`

**涉及**：新建 `std/fmt/format.uya`、`std/fmt/parse.uya`

## 4. std.bare_metal - 裸机支持

**平台特定的硬件访问实现**：

- [ ] **ARM Cortex-M UART**（`std/bare_metal/arm/uart.uya`）：
  - Uart 结构体（寄存器基地址配置）
  - `putc(c: u8)` 方法
  - `write_bytes(data: &[u8])` 方法
  - 实现 Writer 接口
  - 全局实例与便捷函数

- [ ] **RISC-V UART**（`std/bare_metal/riscv/uart.uya`）：
  - 类似 ARM 实现
  - 适配 RISC-V 寄存器布局

- [ ] **x86 VGA 文本模式**（`std/bare_metal/x86/vga.uya`）：
  - VGA 内存映射（0xB8000）
  - 光标管理
  - 颜色属性支持
  - 实现 Writer 接口

- [ ] **通用弱符号接口**：
  - 提供默认的 `__uya_putchar` 弱符号实现
  - 用户可覆盖

**涉及**：新建 `std/bare_metal/arm/uart.uya`、`std/bare_metal/riscv/uart.uya`、`std/bare_metal/x86/vga.uya`

## 5. std.builtin - 编译器内置运行时

**编译器自动注入的最小运行时**：

- [ ] **条件编译适配**（未来特性）：
  ```uya
  // 注：以下是伪代码，需要通过宏系统或其他方案实现
  mc freestanding_io() stmt {
      const mode = @mc_get_env("BUILD_MODE");
      if mode == "freestanding" {
          @mc_code(@mc_ast( 
              extern fn __uya_putchar(c: i32) void;
          ));
      } else {
          @mc_code(@mc_ast( 
              use std.c.stdio;
          ));
      }
  }
  ```

- [ ] **默认 I/O 函数**：
  - 根据编译模式选择后端
  - Hosted: 使用 std.c.stdio
  - Freestanding: 使用弱符号 __uya_putchar

**涉及**：新建 `std/builtin/runtime.uya`、`std/builtin/print.uya`

## 6. --outlibc 编译器功能

**命令行接口**：`./uya-compiler --c99 --outlibc [-o <file>]`

**功能说明**：将 std.c 标准库编译为单个 C 文件和配套头文件，可直接分发给第三方使用。

### 核心特性

- [ ] **自动查找标准库**：
  - 搜索顺序：
    1. `./std/c/`（当前目录）
    2. `<compiler-dir>/std/c/`（编译器所在目录）
    3. `$UYA_ROOT/std/c/`（环境变量）
    4. `/usr/local/share/uya/std/c/`（系统安装）
    5. `/usr/share/uya/std/c/`（系统安装）
  - 用户无需指定源文件，编译器自动收集

- [ ] **自动生成头文件**：
  - 用户只需 `-o lib.c`，自动生成 `lib.c` 和 `lib.h`
  - 头文件包含所有 export 函数的声明
  - **零依赖头文件**：不包含任何标准库头文件

- [ ] **零依赖类型定义**：
  ```c
  // 生成的 .h 文件自己定义所有类型
  typedef signed char        int8_t;
  typedef unsigned char      uint8_t;
  // ... 更多类型
  typedef uint8_t bool;
  #define true  ((bool)1)
  #define false ((bool)0)
  #define NULL  ((void*)0)
  ```

- [ ] **单文件 C 实现**：
  - 所有模块合并为一个 .c 文件
  - 包含清晰的模块分隔注释
  - 零外部依赖，可用 `-nostdinc -ffreestanding` 编译

### 实现步骤

- [ ] **命令行解析**：
  - 识别 `--outlibc` 标志
  - 解析 `-o` 参数（可选）
  - 验证选项组合（需要 `--c99`）

- [ ] **标准库查找**：
  - 实现 `find_std_lib_dir()` 函数
  - 按优先级搜索路径
  - 友好的错误提示（列出所有搜索路径）

- [ ] **源文件收集**：
  - 实现 `collect_std_lib_sources()` 函数
  - 递归扫描 `std/c/` 目录
  - 收集所有 `.uya` 文件

- [ ] **文件名推导**：
  - 实现 `derive_output_files()` 函数
  - 从 `-o lib.c` 推导出 `lib.c` 和 `lib.h`
  - 支持无扩展名（`-o lib` → `lib.c` + `lib.h`）
  - 默认名称：`libuya.c` 和 `libuya.h`

- [ ] **头文件生成**（`generate_library_h()`）：
  - Header guard（基于文件名）
  - C++ 兼容性（`extern "C"`）
  - 零依赖类型定义（int8_t, size_t, bool 等）
  - 用户类型定义（struct, enum, union）
  - export 函数声明（按模块分组）

- [ ] **C 文件生成**（`generate_library_c()`）：
  - 文件头注释（版本、模块数、构建时间）
  - `#include "xxx.h"`（包含配套头文件）
  - 按模块生成实现（带模块分隔注释）
  - 内部辅助函数（static）

- [ ] **进度显示**：
  - 显示查找标准库的过程
  - 列出找到的模块
  - 显示解析/检查进度
  - 显示生成的文件和行数

### 使用示例

```bash
# 基本用法（最简单）
./uya-compiler --c99 --outlibc
# 输出：libuya.c 和 libuya.h

# 自定义输出名
./uya-compiler --c99 --outlibc -o mylib.c
# 输出：mylib.c 和 mylib.h

# 指定目录
./uya-compiler --c99 --outlibc -o build/uya-std.c
# 输出：build/uya-std.c 和 build/uya-std.h

# 显示标准库路径
./uya-compiler --show-std-dir
```

### 第三方使用

生成的库可以直接给 C/C++/Rust 等项目使用：

```c
// user_app.c
#include "libuya.h"  // 零依赖！

int main(void) {
    char buf[100];
    memset(buf, 0, sizeof(buf));
    puts("Hello from Uya libc!");
    return 0;
}
```

```bash
# 标准编译
gcc user_app.c libuya.c -o app

# Freestanding 编译
gcc -nostdinc -nostdlib -ffreestanding \
    user_app.c libuya.c -lgcc -o app
```

### 生成的文件格式

**libuya.h 示例**：
```c
#ifndef LIBUYA_H
#define LIBUYA_H

#ifdef __cplusplus
extern "C" {
#endif

/* 零依赖类型定义 */
typedef signed char int8_t;
typedef unsigned char uint8_t;
// ...
typedef uint8_t bool;
#define true ((bool)1)
#define false ((bool)0)
#define NULL ((void*)0)

/* 函数声明 */
void* memcpy(void* dest, const void* src, size_t n);
void* memset(void* s, int c, size_t n);
// ...

#ifdef __cplusplus
}
#endif

#endif /* LIBUYA_H */
```

**libuya.c 示例**：
```c
/* Single-file C library generated by Uya compiler */
#include "libuya.h"

/* ========== Module: string.uya ========== */
void* memcpy(void* dest, const void* src, size_t n) {
    // 纯 Uya 生成的实现
}
// ...

/* ========== Module: stdio.uya ========== */
int putchar(int c) {
    // 基于系统调用的实现
}
// ...
```

### 测试

- [ ] `test_outlibc_basic.sh` - 基本生成测试
- [ ] `test_outlibc_compile.sh` - 编译生成的库
- [ ] `test_outlibc_freestanding.sh` - freestanding 模式测试
- [ ] `test_outlibc_usage.c` - C 项目使用示例

**涉及**：`src/main.c` 命令行解析、新增 codegen 函数

**优先级**：高（与标准库实现配合）

## 7. 实现优先级

### 目标实现路径

**目标 1：编译器不依赖外部 C 标准库**
- 阶段 1-3：实现基础 std.c（string, syscall）
- 阶段 4-5：实现 I/O 和格式化
- 修改编译器：将所有 C 标准库调用替换为 std.c
- 验证：编译器使用 `-nostdlib` 构建成功

**目标 2：生成无依赖 libc**
- 阶段 1：实现 `--outlibc` 编译器功能
- 阶段 2-5：补充必要的 std.c 函数
- 阶段 6：测试生成的库在第三方项目中使用
- 验证：生成的 libuya.c 可用 `-nostdlib` 编译

| 阶段 | 内容 | 优先级 | 目标 | 说明 |
|------|------|--------|------|------|
| 1 | **--outlibc 编译器功能** | ⭐⭐⭐⭐⭐ | 目标 2 | 核心基础设施 |
| 2 | **std.c.string 基础实现** | ⭐⭐⭐⭐⭐ | 目标 1+2 | memcpy, memset, strlen 等 |
| 3 | **std.c.syscall.linux 基础** | ⭐⭐⭐⭐⭐ | 目标 1+2 | read, write, exit |
| 4 | **std.c.stdio 基础输出** | ⭐⭐⭐⭐ | 目标 1+2 | putchar, puts |
| 5 | **std.fmt 基础格式化** | ⭐⭐⭐⭐ | 目标 1+2 | i32, bool 格式化 |
| 6 | **测试和验证** | ⭐⭐⭐⭐ | 目标 2 | 确保生成的库可用 |
| 7 | **编译器迁移到 std.c** | ⭐⭐⭐⭐ | 目标 1 | 替换编译器中的 libc 调用 |
| 8 | **std.c.stdlib 内存管理** | ⭐⭐⭐ | 目标 1+2 | malloc, free |
| 9 | **std.c.stdio 完整实现** | ⭐⭐⭐ | 目标 1+2 | printf, 文件 I/O |
| 10 | **std.c.math 数学库** | ⭐⭐ | 目标 2 | sqrt, sin, cos 等 |
| 11 | **std.io 同步抽象层** | ⭐⭐ | 扩展 | Writer/Reader 同步接口 |
| 12 | **std.async 异步标准库** | ⭐⭐ | 扩展 | 详见 [std_async_design.md](std_async_design.md) |
| 13 | **std.bare_metal 裸机支持** | ⭐ | 扩展 | ARM/RISC-V UART |

**第一个里程碑**（最小可用）：
完成阶段 1-3，可以生成一个包含基础字符串操作的库，能够用 `-nostdlib` 编译。

**第二个里程碑**（实用版本）：
完成阶段 1-6，可以生成包含 I/O 和格式化的完整库，可以替代大部分 C 标准库功能。

**第三个里程碑**（编译器自举）：
完成阶段 1-7，Uya 编译器完全不依赖外部 C 标准库，实现真正的自举。

**验证标准**：
- ✅ 目标 1：`gcc -nostdlib uya-compiler.c std/c/*.c -o uya-compiler` 编译成功
- ✅ 目标 2：第三方项目 `gcc -nostdlib app.c libuya.c -o app` 编译成功

## 8. 与其他实现对比

| 实现 | 语言 | 大小 | 类型安全 | 自举 | 可读性 |
|------|------|------|---------|------|--------|
| **std.c (Uya)** | Uya | ~500KB | ✅ 完全 | ✅ 是 | ⭐⭐⭐⭐⭐ |
| musl | C | ~1MB | ⚠️ C级别 | ❌ 否 | ⭐⭐⭐ |
| glibc | C | ~2MB | ⚠️ C级别 | ❌ 否 | ⭐⭐ |

### 实现示例对比

**C 语言实现（musl）**：
```c
void *memcpy(void *dest, const void *src, size_t n) {
    unsigned char *d = dest;
    const unsigned char *s = src;
    for (; n; n--) *d++ = *s++;
    return dest;
}
```

**Uya 实现（std.c）**：
```uya
export fn memcpy(dest: &u8, src: &u8, n: usize) &u8 {
    var i: usize = 0;
    while i < n {
        dest[i] = src[i];  // 类型安全的数组访问
        i = i + 1;
    }
    return dest;
}
```

**编译后的 C 代码（生成的 libuya.c）**：
```c
void* memcpy(void* dest, const void* src, size_t n) {
    uint8_t* d = (uint8_t*)dest;
    const uint8_t* s = (const uint8_t*)src;
    size_t i = 0;
    while (i < n) {
        d[i] = s[i];
        i = i + 1;
    }
    return dest;
}
```

**优势**：
- ✅ Uya 源码类型安全（编译时检查）
- ✅ 生成的 C 代码可读性好
- ✅ 不需要手动指针运算
- ✅ 零依赖，可独立分发

## 9. 使用场景

1. **替代 musl**：作为更安全的 C 标准库实现
2. **嵌入式开发**：零依赖，适合资源受限环境
3. **操作系统内核**：可用于内核开发（freestanding）
4. **容器镜像**：极小化镜像（FROM scratch）
5. **教学用途**：可读的纯 Uya 实现
6. **安全审计**：类型安全的 Uya 代码易于审计

## 10. 修正后的实施路线图

### 阶段 0：基础设施（必须先完成）
- [ ] 实现 `@syscall` 内置函数（硬编码 Linux x86-64）
- [ ] 实现基础错误联合类型 `!T`

### 阶段 1：单平台验证（MVP）
- [ ] 实现 `std.c.syscall_linux_x64.uya`（单文件，无条件编译）
- [ ] 实现 `std.c.string.uya`（纯 Uya，平台无关）
- [ ] 实现 `std.c.stdio.uya`（基于 syscall）
- [ ] 实现 `--outlibc` 生成 Linux x86-64 单平台库
- [ ] 测试：在 Linux x86-64 上完整运行

### 阶段 2：实现 `std.target` 条件编译宏
- [ ] 创建 `std/target.uya` 模块
- [ ] 实现平台检测宏：
  - `target_linux_x64(code)`, `target_linux_arm64(code)`
  - `target_macos_x64(code)`, `target_macos_arm64(code)`
  - `target_windows_x64(code)`
- [ ] 实现通用宏：
  - `target_os_linux(code)`, `target_os_macos(code)`, `target_os_windows(code)`
  - `target_arch_x64(code)`, `target_arch_arm64(code)`
- [ ] 重构 `std/c/syscall/linux.uya` 使用宏
- [ ] 测试：验证宏展开正确性

### 阶段 3：多平台扩展
- [ ] 添加 macOS x86-64/ARM64 支持
  - 创建 `std/c/syscall/macos.uya`
  - 使用 `std.target` 宏处理架构差异
- [ ] 添加 Linux ARM64 支持
  - 扩展 `std/c/syscall/linux.uya`
  - 使用 `target_arch_arm64()` 宏
- [ ] 实现统一接口层 `std/c/syscall/common.uya`
  - 使用 `target_os_*()` 宏分发到不同平台

### 阶段 4：Windows 支持（可选）
- [ ] 研究 Windows syscall 或 Win32 API 方案
- [ ] 创建 `std/c/syscall/windows.uya`
- [ ] 使用 `target_os_windows()` 宏集成

**关键修改**：
1. ✅ 将条件编译移到跨平台之前
2. ✅ 第一阶段只支持 Linux x86-64
3. ✅ 简化目录结构（单文件起步）
4. ✅ 明确基础设施依赖

这样可以在 **不依赖条件编译** 的情况下，先完成 MVP 验证核心设计！🎯

