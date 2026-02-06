# @syscall 内置函数设计文档

**版本**：v0.3.0  
**创建日期**：2026-02-06  
**状态**：设计阶段

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

### 6.1 Lexer（src/lexer.c）

- [ ] 识别 `@syscall` 为合法内置函数
- [ ] 在 `is_builtin_function` 中添加 `"syscall"` 分支

### 6.2 AST（src/ast.h, src/ast.c）

- [ ] 新增 `AST_SYSCALL` 节点类型
- [ ] 添加字段：
  ```c
  struct {
      ASTNode *syscall_number;  // 系统调用号（编译期常量）
      ASTNode **args;            // 参数数组
      int arg_count;             // 参数个数（0-6）
  } syscall;
  ```

### 6.3 Parser（src/parser.c）

- [ ] 在 `primary_expr` 中识别 `TOKEN_AT_IDENTIFIER` 值为 `"syscall"` 的情况
- [ ] 解析 `@syscall(nr, ...args)` 语法
- [ ] 验证参数个数（1-7 个，第一个为 nr）

### 6.4 Checker（src/checker.c）

- [ ] 类型检查：
  - [ ] 验证 `syscall_number` 为整数类型编译期常量
  - [ ] 验证参数类型可转换为 `i64`
  - [ ] 返回类型固定为 `!i64`
- [ ] 编译期求值 `syscall_number`（如果是常量表达式）

### 6.5 Codegen（src/codegen/c99/）

- [ ] **utils.c**：生成辅助函数 `uya_syscall0` - `uya_syscall6`
- [ ] **expr.c**：生成 `@syscall` 调用代码
  - 调用对应的 `uya_syscall{N}` 函数
  - 生成错误联合类型包装代码

### 6.6 测试用例（tests/programs/）

- [ ] `test_syscall_write.uya`（SYS_write）
- [ ] `test_syscall_exit.uya`（SYS_exit）
- [ ] `test_syscall_read.uya`（SYS_read）
- [ ] `test_syscall_error.uya`（错误处理）
- [ ] `error_syscall_not_const.uya`（nr 非常量，预期失败）

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
# C 版编译器测试
make build
./build/compiler-mini --c99 tests/programs/test_syscall_write.uya
gcc tests/programs/build/test_syscall_write.c -o test
./test
# 输出：Hello, syscall!
# 退出码：0

# 自举版编译器测试（稍后）
cd uya-src && ./compile.sh --c99 -e
./tests/run_programs.sh --uya --c99 test_syscall_write.uya
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

### 9.1 多平台支持（v0.5.0+）

| 平台 | 系统调用指令 | 调用约定 |
|------|------------|---------|
| Linux x86-64 | `syscall` | rax=nr, rdi/rsi/rdx/r10/r8/r9 |
| Linux ARM64 | `svc #0` | x8=nr, x0-x5 |
| macOS x86-64 | `syscall` | rax=nr+0x2000000 |
| macOS ARM64 | `svc #0x80` | x16=nr, x0-x5 |
| Windows x64 | 无直接支持 | 调用 NtXxx 函数 |

### 9.2 条件编译支持（v0.5.0+）

```uya
// 使用 std.target 条件编译
if @target.os == .linux {
    const SYS_write: i64 = 1;
} else if @target.os == .macos {
    const SYS_write: i64 = 0x2000004;
}
```

---

## 10. 参考资料

- **Linux 系统调用表**：`/usr/include/asm/unistd_64.h`
- **系统调用手册**：`man 2 syscall`
- **ABI 文档**：[System V AMD64 ABI](https://refspecs.linuxbase.org/elf/x86_64-abi-0.99.pdf)
- **内联汇编**：[GCC Inline Assembly](https://gcc.gnu.org/onlinedocs/gcc/Extended-Asm.html)

---

**版本历史**：
- v1.0（2026-02-06）：初始设计文档

