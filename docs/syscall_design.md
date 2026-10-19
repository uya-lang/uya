# @syscall 内置函数设计文档

> **核对头（2026-10-19，v0.10.4）**：`@syscall` **已实现**，且已覆盖 Linux / macOS / Windows 三类目标。
> 实现现状以 `src/lexer.uya`、`src/parser/primary.uya`、`src/checker/check_expr.uya`、
> `src/codegen/c99/main.uya`、`lib/libc/syscall.uya` 与 `tests/test_syscall_*.uya` 为准；
> 下文的「设计清单」保留历史写法。

**版本**：v0.3.0  
**创建日期**：2026-02-06  
**状态**：已实现（v0.10.4；Linux / macOS / Windows 目标均已落地）

---

## 1. 概述

`@syscall` 是一个编译期内置函数，用于直接调用操作系统内核提供的系统调用接口。它是构建零依赖标准库（`std.c`）的基石。

**目标**：
- 提供类型安全的系统调用接口
- 零外部依赖（不依赖 glibc/musl）
- 支持 Linux x86-64（初期），后续扩展到其他平台
- 自动错误处理（返回 `!i64`）

---

## 2. 语法设计

### 2.1 函数签名

```uya
@syscall(nr: i64, arg1?: i64, arg2?: i64, arg3?: i64, arg4?: i64, arg5?: i64, arg6?: i64) !i64
```

**参数**：
- `nr`：系统调用号（必须是编译期常量）
- `arg1-arg6`：系统调用参数（可选，最多 6 个）

**返回值**：
- `!i64`：成功返回非负值，失败返回错误（负数错误码自动转换）

### 2.2 使用示例

```uya
// 示例 1：SYS_write（3 个参数）
const SYS_write: i64 = 1;
const result: !i64 = @syscall(SYS_write, 1, "Hello\n" as i64, 6);
const bytes_written = try result;

// 示例 2：SYS_exit（1 个参数）
const SYS_exit: i64 = 60;
@syscall(SYS_exit, 0);  // noreturn

// 示例 3：错误处理
const SYS_open: i64 = 2;
const fd = @syscall(SYS_open, "/tmp/test" as i64, 0, 0) catch |err| {
    // err 为错误码（如 ENOENT）
    return error.OpenFailed;
};
```

---

## 3. 系统调用约定

### 3.1 Linux x86-64 调用约定

| 寄存器 | 用途 |
|--------|------|
| `rax` | 系统调用号（输入），返回值（输出） |
| `rdi` | 第 1 个参数 |
| `rsi` | 第 2 个参数 |
| `rdx` | 第 3 个参数 |
| `r10` | 第 4 个参数 |
| `r8`  | 第 5 个参数 |
| `r9`  | 第 6 个参数 |
| `rcx`, `r11` | 被 syscall 指令破坏 |

**汇编指令**：
```asm
mov rax, <syscall_nr>
mov rdi, <arg1>
mov rsi, <arg2>
mov rdx, <arg3>
mov r10, <arg4>
mov r8,  <arg5>
mov r9,  <arg6>
syscall
; 返回值在 rax
```

### 3.2 错误码处理

**规则**：
- 返回值 `>= 0`：成功
- 返回值 `< 0`：失败，`-返回值` 为 errno

**示例**：
```c
// 系统调用返回 -9（-EBADF）
// @syscall 自动转换为 error（错误联合类型）
```

---

## 4. 类型系统集成

### 4.1 类型检查

**Checker 规则**：
1. `nr` 必须是整数类型的编译期常量
2. `arg1-arg6` 必须可转换为 `i64`
3. 返回类型固定为 `!i64`

**错误示例**：
```uya
var x: i64 = 1;
@syscall(x, 1, 2, 3);  // ❌ 错误：nr 必须是编译期常量

@syscall(1, "hello");  // ❌ 错误：字符串不能直接用作参数
                       // 需要：@syscall(1, "hello" as i64)
```

### 4.2 错误类型

返回的 `!i64` 类型：
```uya
// 成功值
const result: !i64 = @syscall(1, 1, buf, len);
const bytes: i64 = try result;  // 展开成功值

// 错误处理
const result2: !i64 = @syscall(2, "/bad/path" as i64, 0, 0);
const fd = result2 catch |err| {
    // err.error_id 为负数错误码（如 -ENOENT = -2）
    return error.OpenFailed;
};
```

---

## 5. 代码生成

### 5.1 生成策略

为每种参数个数生成一个内联函数：

```c
// 0 个参数
static inline long uya_syscall0(long nr) {
    register long rax __asm__("rax") = nr;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax) : "rcx", "r11", "memory");
    return rax;
}

// 1 个参数
static inline long uya_syscall1(long nr, long a1) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi) : "rcx", "r11", "memory");
    return rax;
}

// 2 个参数
static inline long uya_syscall2(long nr, long a1, long a2) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    register long rsi __asm__("rsi") = a2;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi), "r"(rsi) 
                     : "rcx", "r11", "memory");
    return rax;
}

// ... 依此类推到 uya_syscall6
```

### 5.2 调用代码生成

```uya
// Uya 代码
const result: !i64 = @syscall(1, fd, buf, len);
```

生成的 C 代码：
```c
// 生成辅助函数（文件开头）
static inline long uya_syscall3(long nr, long a1, long a2, long a3) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    register long rsi __asm__("rsi") = a2;
    register long rdx __asm__("rdx") = a3;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi), "r"(rsi), "r"(rdx)
                     : "rcx", "r11", "memory");
    return rax;
}

// 生成调用代码
long _uya_syscall_ret = uya_syscall3(1, fd, buf, len);
struct err_union_i64 result;
if (_uya_syscall_ret < 0) {
    result.error_id = (int)(-_uya_syscall_ret);  // 转换为正数错误码
} else {
    result.error_id = 0;
    result.value = _uya_syscall_ret;
}
```

---

## 6. 实现清单

> 状态（v0.10.4）：以下条目**全部已实现**，括号内为落点文件。

### 6.1 Lexer（`src/lexer.uya`）

- [x] 识别 `@syscall` 为合法内置函数（`TOKEN_AT_IDENTIFIER` 白名单里的 `str_equals_lexer(value, "syscall")` 分支）
- [x] 未知内置错误文案已把 `@syscall` 列入支持列表

### 6.2 AST（`src/ast.uya`）

- [x] 新增 `AST_SYSCALL` 节点类型
- [x] 添加字段：
  ```uya
  syscall_number: &ASTNode,   // 系统调用号（编译期常量）
  syscall_args: &&ASTNode,    // 参数数组
  syscall_arg_count: i32,     // 参数个数（0-6；microapp 用户代码 0-2）
  ```

### 6.3 Parser（`src/parser/primary.uya`）

- [x] 在 `primary_expr` 中识别 `TOKEN_AT_IDENTIFIER` 值为 `"syscall"` 的情况
- [x] 解析 `@syscall(nr, ...args)` 语法
- [x] 验证参数个数（普通模式 1-7 个，第一个为 nr；microapp 用户代码最多 2 个参数）

### 6.4 Checker（`src/checker/check_expr.uya` 的 `infer_syscall`）

- [x] 类型检查：
  - [x] 验证 `syscall_number` 为整数类型编译期常量
  - [x] 验证参数类型可转换为 `i64`（或整数/指针）
  - [x] 返回类型固定为 `!i64`
- [x] 编译期求值 `syscall_number`（如果是常量表达式）

### 6.5 Codegen（`src/codegen/c99/`）

- [x] **`utils.uya` / `main.uya`**：按需生成辅助函数 `uya_syscall0` - `uya_syscall6`
      （`codegen.needs_syscall_helpers` 为真才发射；镜像分 TU 时追加到 `uya_part1_types.h` 供全 TU 含入）
- [x] **`expr.uya`**：生成 `@syscall` 调用代码
  - 调用对应的 `uya_syscall{N}` 函数
  - 生成错误联合类型包装代码

### 6.6 测试用例（`tests/`）

- [x] `test_syscall_write.uya`（SYS_write）
- [x] `test_syscall_exit.uya`（SYS_exit）
- [x] `test_syscall_error.uya`（错误处理）
- [x] `error_syscall_not_const.uya`（nr 非常量，预期失败）
- [x] 另有 `test_syscall_read/dir/file/ioctl/mem/process/thread/time/user/layer/module`、
      `syscall_c99_cross.uya`、`test_std_syscall*.uya` 等 20 个左右的用例

---

## 7. 测试策略

### 7.1 单元测试

```uya
// test_syscall_write.uya
fn main() i32 {
    const SYS_write: i64 = 1;
    const msg = "Hello, syscall!\n";
    const result = @syscall(SYS_write, 1, msg as i64, 16);
    
    const bytes = try result catch {
        return 1;  // 失败
    };
    
    if bytes != 16 {
        return 1;  // 写入字节数不对
    }
    
    return 0;  // 成功
}
```

### 7.2 验证方法

```bash
# 单个用例
./bin/uya test tests/test_syscall_write.uya

# 或走并行回归脚本
./tests/run_programs_parallel.sh test_syscall_write.uya

# 交叉目标（Linux AArch64 / ARM32）的 @syscall C99 汇总闸门
bash tests/verify_syscall_c99_cross.sh
```

---

## 8. 性能考虑

### 8.1 零开销抽象

- 内联函数，零函数调用开销
- 寄存器变量，编译器直接生成寄存器分配
- 无运行时检查，所有检查在编译期完成

### 8.2 编译器优化友好

```c
// GCC 可以优化常量传播
const long result = uya_syscall1(60, 0);  // SYS_exit(0)
// → 直接内联为 syscall 指令
```

---

## 9. 未来扩展

### 9.1 多平台支持（**已实现**，v0.10.4）

唯一汇聚点在 `src/codegen/c99/main.uya` 的 syscall 助手发射段（第七步 d）：所有 `@syscall`
都被 lower 成 `uya_syscall0..6`，再按目标平台分流。

| 平台 | 系统调用指令 / 汇聚点 | 调用约定 |
|------|----------------------|---------|
| Windows x64 | `uya_windows_syscall(...)`（Win32 API + Winsock，`#if defined(_WIN32) \|\| defined(UYA_TARGET_WINDOWS)` 分支排在最前） | 参数一律用 `int64_t` 承载（LLP64 下 `long` 只有 32 位，用 `long` 会截断指针） |
| Linux x86-64 | `syscall` | rax=nr, rdi/rsi/rdx/r10/r8/r9 |
| Linux ARM64 | `svc #0` | x8=nr, x0-x5 |
| Linux ARM32 (EABI) | `svc` | 见生成代码分支 |
| macOS x86-64 | `syscall` + `setc` | rax=nr+0x2000000 |
| macOS ARM64 | `svc #0x80` + `cset x15` | x16=nr, x0-x5 |
| Unknown / Web hosted | 无原生内联 `@syscall` | 生成 C 时 `#error "…supported targets are…"`；此类目标走 `libc.sys_*` 与宿主 bridge（`tests/verify_emcc_unknown_runtime.sh`） |

补充：Windows 分支必须排在 Linux/Darwin 判据**之前**——MinGW / zig cc 在 x86_64 Windows 上同样
定义 `__x86_64__` 但不定义 `__linux__`，若先判 `(__x86_64__ && __linux__)` 就不会命中，而链尾
`#else` 会把它判成「无后端」。

### 9.2 hosted 与 `--nostdlib` 的 ABI 边界

- `@syscall` 与宿主 libc 是**两条独立通道**：`hosted` 模式下 `lib/libc/*` 里的封装仍通过
  `uya_syscall*` 直接下发内核调用（Linux/macOS）或 Win32 API（Windows），不经过生成的
  `#include <...>` libc 函数；`extern "libc" fn` / `lib/std/c/*` 才是走宿主 C 库的通道。
- `--nostdlib` 只是**链接策略**：生成的 C 自带 `_start`，链接时不带系统 libc
  （`-nostdlib -static` + `crti.o`/`crtn.o`），因此程序只能依赖 `@syscall` 通道与 Uya 自己实现的
  `libc`/`std`；该路径目前仅 Linux x86_64 可用。
- Windows 目标只有 `hosted` 路线：`@syscall` 落到 Win32 API（需要 zig cc 链接 `-lws2_32` 等）。

### 9.3 条件编译支持（v0.5.0+）

```uya
use std;

// 使用 std.cfg 在编译期裁剪平台分支
std.cfg(std.target_os == .tos_linux, {
    const SYS_write: i64 = 1;
}, std.cfg(std.target_os == .tos_macos, {
    const SYS_write: i64 = 0x2000004;
}, {
    const SYS_write: i64 = -1;
}))
```

补充说明：`std.target_os == .tos_unknown`（例如 emcc / Web hosted smoke）当前不走原生 `@syscall` backend；此类目标应通过 `libc.sys_*` 与宿主 bridge 暴露最小运行时能力。当前仓库中的验证脚本为 `tests/verify_emcc_unknown_runtime.sh`，可通过 `make tests-emcc` 运行。

---

## 10. 参考资料

- **Linux 系统调用表**：`/usr/include/asm/unistd_64.h`
- **系统调用手册**：`man 2 syscall`
- **ABI 文档**：[System V AMD64 ABI](https://refspecs.linuxbase.org/elf/x86_64-abi-0.99.pdf)
- **内联汇编**：[GCC Inline Assembly](https://gcc.gnu.org/onlinedocs/gcc/Extended-Asm.html)

---

**版本历史**：
- v1.0（2026-02-06）：初始设计文档
- v0.10.4 核对（2026-10-19）：全文回填实现状态；§6 清单全部勾选并标注落点文件；
  §9.1 补 Windows 分支与汇聚点说明；新增 §9.2 hosted / `--nostdlib` ABI 边界
