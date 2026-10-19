# Naked 函数设计计划

> **状态：✅ 已实现** (2026-03-03)
> **版本：v0.7.2**
>
> **实现状态核对（2026-10-19，编译器 v0.10.4）**：`@naked_fn` 全链路在 `src/` 可用——AST 字段 `fn_decl_is_naked`（`src/ast.uya:232`）、parser（`src/parser/main.uya:776-838`，且 extern 函数禁用该属性）、codegen 发射 `__attribute__((naked))`（`src/codegen/c99/function.uya:1897`、`2079`）；用法示例 `lib/libc/setjmp.uya`，测试 `tests/test_naked_fn.uya` 与 `tests/test_longjmp_full.uya` 均存在。
> **与本文的差异**：§2.2 表格中"函数体只能包含 `@asm` 块"目前**没有编译期检查**——`export @naked_fn fn f() i32 { var x: i32 = 1; return x; }` 仍会通过并生成裸函数体（已用 `bin/uya --c99` 实测）。该约束目前只是使用约定，§5 风险表里的"添加编译时检查（可选）"尚未做。

## 1. 背景

### 问题
在实现 `setjmp/longjmp` 时发现，GCC 会为函数自动生成 prologue/epilogue（如 `push rbp; mov rbp, rsp`），导致：
- `longjmp` 恢复 `rsp` 后，栈上变量失效
- 无法实现完整的非本地跳转

### 目标
实现 `@naked_fn` 函数属性，让编译器生成 `__attribute__((naked))` 声明，禁止 GCC 生成 prologue/epilogue。

## 2. 技术方案

### 2.1 语法设计

```uya
// 函数声明/定义（与 @async_fn 命名风格一致）
export @naked_fn fn longjmp(env: &jmp_buf, val: i32) void {
    @asm {
        // 所有指令必须在单个 @asm 块中
        "testl %%esi, %%esi" ();
        "movl $1, %%eax" ();
        "cmovzl %%eax, %%esi" ();
        "movl %%esi, %%eax" ();
        "movq 0(%%rdi), %%rbx" ();
        // ... 恢复所有寄存器
        "movq 56(%%rdi), %%rax" ();
        "jmpq *%%rax" ();
    } clobbers = ["memory"];
}

// 与其他属性组合
export @naked_fn fn setjmp(env: &jmp_buf) i32 { ... }
```

**命名原因**：使用 `_fn` 后缀与现有 `@async_fn` 保持一致。

**关键发现**：
- 所有 ASM 指令必须在**单个** `@asm` 块中
- x86-64 调用约定：前 6 个参数在 `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`
- 裸函数中直接使用 `%%rdi`, `%%esi` 等寄存器名访问参数

### 2.2 语义约束

| 约束 | 原因 |
|------|------|
| 函数体只能包含 `@asm` 块 | naked 函数没有栈帧，无法访问局部变量 |
| 所有 ASM 指令必须在单个 `@asm` 块 | 多个块会导致控制流问题 |
| 参数通过寄存器访问（x86-64: rdi, rsi, rdx...） | naked 函数无 prologue，参数在调用者栈帧 |
| 必须使用 `ret` 指令返回 | 没有 epilogue 自动生成返回指令 |

**x86-64 调用约定**：
- 参数寄存器：`rdi` (arg1), `rsi` (arg2), `rdx` (arg3), `rcx` (arg4), `r8` (arg5), `r9` (arg6)
- 返回值：`rax`
- Callee-saved：`rbx`, `rbp`, `r12`, `r13`, `r14`, `r15`

### 2.3 生成代码示例

```c
// Uya 源码
@naked_fn fn longjmp(env: &jmp_buf, val: i32) void { ... }

// 生成的 C 代码
__attribute__((naked)) void longjmp(jmp_buf* env, int32_t val) {
    __asm__ volatile (
        "mov rbx, %0\n\t"
        "mov rbp, %1\n\t"
        // ...
        : : "r"(env->data[0]), "r"(env->data[1]) : "memory"
    );
}
```

## 3. 实现步骤（已完成）

### 3.1 AST 修改 (`src/ast.uya`) ✅

添加 `fn_decl_is_naked: i32` 字段到函数声明节点。

### 3.2 Lexer 修改 (`src/lexer.uya`) ✅

识别 `@naked_fn` 作为有效内置标识符。

### 3.3 Parser 修改 (`src/parser/main.uya`) ✅

解析 `@naked_fn` 属性，参照 `@async_fn` 模式。

### 3.4 代码生成修改 (`src/codegen/c99/function.uya`) ✅

在函数签名前输出 `__attribute__((naked))`。

### 3.5 ASM 块合并修复 (`src/codegen/c99/expr.uya`) ✅

修复 `gen_asm_block` 函数，将所有 ASM 指令合并为单个 `__asm__ volatile` 块。

### 3.6 测试文件 ✅

- `tests/test_naked_fn.uya`：裸函数属性测试
- `tests/test_longjmp_full.uya`：完整 longjmp 功能测试

### 3.7 实现文件 ✅

- `lib/libc/setjmp.uya`：使用 `@naked_fn` 重新实现 setjmp/longjmp

## 4. 验证流程

```bash
# 1. 修改代码后构建
make uya

# 2. 验证自举
make b

# 3. 运行测试
make tests

# 4. 检查生成的 C 代码
cat bin/uya.c | grep -A5 "naked"
```

## 5. 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| GCC 版本兼容性 | 旧版 GCC 可能不支持 | 文档说明最低 GCC 版本要求 |
| 调试困难 | naked 函数无栈帧 | 限制使用场景，提供警告 |
| 误用导致崩溃 | 用户在 naked 函数中使用局部变量 | 添加编译时检查（可选） |

## 6. 已完成的后续优化

1. **ASM 块合并**：所有 ASM 指令必须在单个 `@asm` 块中 ✅
2. **setjmp/longjmp 实现**：使用 `@naked_fn` 完整实现 ✅
3. **测试覆盖**：`test_naked_fn.uya` 和 `test_longjmp_full.uya` ✅

## 7. 文件清单（已实现）

| 文件 | 修改内容 |
|------|----------|
| `src/ast.uya` | 添加 `fn_decl_is_naked` 字段 |
| `src/lexer.uya` | 识别 `@naked_fn` 内置标识符 |
| `src/parser/main.uya` | 解析 `@naked_fn` 属性 |
| `src/codegen/c99/function.uya` | 生成 `__attribute__((naked))` |
| `src/codegen/c99/expr.uya` | 修复 ASM 块合并 |
| `lib/libc/setjmp.uya` | 使用 `@naked_fn` 实现 setjmp/longjmp |
| `tests/test_naked_fn.uya` | 裸函数属性测试 |
| `tests/test_longjmp_full.uya` | longjmp 功能测试 |
