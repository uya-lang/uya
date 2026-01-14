# 阶段6：代码生成器

## 概述

翻译代码生成器（CodeGen）模块，代码量最大（3,456行），逻辑最复杂。

**优先级**：P0

**工作量估算**：10-15 小时

**依赖**：阶段0（准备工作 - str_utils.uya, llvm_api.uya）、阶段1（Arena）、阶段2（AST）、阶段5（Checker）

**原因**：编译器核心功能，生成目标代码。

---

## 任务列表

### 任务 6.1：阅读和理解 C99 代码

- [ ] 阅读 `src/codegen.h` - 理解 CodeGen 接口
- [ ] 阅读 `src/codegen.c` - 理解 CodeGen 实现
- [ ] 理解代码生成的工作原理：
  - [ ] LLVM 上下文和模块创建
  - [ ] 类型到 LLVM 类型的映射
  - [ ] 表达式代码生成
  - [ ] 语句代码生成
  - [ ] 函数代码生成
  - [ ] 结构体代码生成
  - [ ] 变量和常量处理
  - [ ] 控制流代码生成

**参考**：代码量最大（3,456行），逻辑最复杂（LLVM API 调用）

---

### 任务 6.2：翻译 CodeGen 结构体定义

**文件**：`uya-src/codegen.uya`

- [ ] 翻译 `CodeGen` 结构体：
  - [ ] LLVM 上下文字段（`context`, `module`, `builder` 等）
  - [ ] Arena 分配器字段（`arena`）
  - [ ] 变量表字段（`variables`, `variable_count` 等）
  - [ ] 函数表字段（`functions`, `function_count` 等）
  - [ ] 当前函数字段（`current_function` 等）
  - [ ] 其他辅助字段

**类型映射**：
- LLVM 类型（`LLVMContextRef`, `LLVMValueRef` 等）→ `*void` 或具体结构体指针
- `Arena *` → `&Arena`
- `int` → `i32`
- `size_t` → `i32`

---

### 任务 6.3：完善 LLVM API 声明

- [ ] 在 `llvm_api.uya` 中添加 CodeGen 需要的 LLVM C API 函数声明：
  - [ ] 基础类型和上下文函数（`LLVMContextCreate`, `LLVMContextDispose` 等）
  - [ ] 模块和函数创建函数（`LLVMModuleCreateWithName`, `LLVMAddFunction` 等）
  - [ ] 基本块和指令构建函数（`LLVMAppendBasicBlock`, `LLVMBuildAdd` 等）
  - [ ] 类型创建函数（`LLVMInt32Type`, `LLVMPointerType` 等）
  - [ ] 常量创建函数（`LLVMConstInt`, `LLVMConstNull` 等）
  - [ ] 其他 CodeGen 需要的函数
- [ ] 确保所有 LLVM API 函数声明正确
- [ ] 确保类型映射正确（LLVM 类型使用 `*void` 或具体结构体）

**关键挑战**：
- LLVM C API 的 `extern` 函数声明（数百个函数）
- 类型映射（LLVM 类型到 Uya Mini 类型）

---

### 任务 6.4：翻译 CodeGen 初始化函数

- [ ] 翻译 `codegen_init` 函数：
  - [ ] 创建 LLVM 上下文
  - [ ] 创建 LLVM 模块
  - [ ] 创建 LLVM 构建器
  - [ ] 初始化变量表和函数表
- [ ] 翻译 `codegen_cleanup` 函数：
  - [ ] 清理 LLVM 资源

---

### 任务 6.5：翻译类型映射函数

- [ ] 翻译类型映射函数：
  - [ ] `type_to_llvm` - 将 Uya Mini 类型映射到 LLVM 类型
  - [ ] `llvm_type_size` - 获取 LLVM 类型大小
  - [ ] `llvm_type_align` - 获取 LLVM 类型对齐
  - [ ] 处理基础类型（`i32`, `bool`, `byte`, `void`）
  - [ ] 处理指针类型（`&T`, `*T`）
  - [ ] 处理数组类型（`[T: N]`）
  - [ ] 处理结构体类型

---

### 任务 6.6：翻译表达式代码生成函数

- [ ] 翻译表达式代码生成函数：
  - [ ] `codegen_expr` - 表达式代码生成入口
  - [ ] `codegen_int_literal` - 整数字面量
  - [ ] `codegen_bool_literal` - 布尔字面量
  - [ ] `codegen_ident` - 标识符（变量访问）
  - [ ] `codegen_binary_op` - 二元运算
  - [ ] `codegen_unary_op` - 一元运算
  - [ ] `codegen_call` - 函数调用
  - [ ] `codegen_field_access` - 字段访问
  - [ ] `codegen_array_access` - 数组访问
  - [ ] `codegen_deref` - 指针解引用
  - [ ] `codegen_addr_of` - 取地址
  - [ ] `codegen_sizeof` - sizeof 内置函数
  - [ ] `codegen_type_cast` - 类型转换
  - [ ] 其他表达式类型

---

### 任务 6.7：翻译语句代码生成函数

- [ ] 翻译语句代码生成函数：
  - [ ] `codegen_stmt` - 语句代码生成入口
  - [ ] `codegen_block` - 代码块
  - [ ] `codegen_if` - if 语句
  - [ ] `codegen_while` - while 语句
  - [ ] `codegen_for` - for 语句（数组遍历）
  - [ ] `codegen_break` - break 语句
  - [ ] `codegen_continue` - continue 语句
  - [ ] `codegen_return` - return 语句
  - [ ] `codegen_assign` - 赋值语句
  - [ ] `codegen_variable_decl` - 变量声明
  - [ ] 其他语句类型

---

### 任务 6.8：翻译声明代码生成函数

- [ ] 翻译声明代码生成函数：
  - [ ] `codegen_declaration` - 声明代码生成入口
  - [ ] `codegen_function` - 函数代码生成
  - [ ] `codegen_struct` - 结构体代码生成
  - [ ] `codegen_extern` - extern 函数声明
  - [ ] 其他声明类型

---

### 任务 6.9：翻译变量和函数表管理函数

- [ ] 翻译变量表管理函数：
  - [ ] `add_variable` - 添加变量
  - [ ] `lookup_variable` - 查找变量
  - [ ] `remove_variable` - 移除变量（作用域退出时）
- [ ] 翻译函数表管理函数：
  - [ ] `add_function` - 添加函数
  - [ ] `lookup_function` - 查找函数

---

### 任务 6.10：翻译输出函数

- [ ] 翻译输出函数：
  - [ ] `codegen_emit_ir` - 输出 LLVM IR
  - [ ] `codegen_emit_object` - 输出目标代码
  - [ ] 使用 LLVM API 进行输出

---

### 任务 6.11：使用字符串辅助函数

- [ ] 在 `codegen.uya` 中包含或引用 `str_utils.uya` 的声明
- [ ] 将所有字符串操作改为使用 `str_utils.uya` 中的函数
- [ ] 确保所有错误消息使用 `fprintf` 输出

---

### 任务 6.12：添加中文注释

- [ ] 为所有结构体添加中文注释
- [ ] 为所有函数添加中文注释
- [ ] 为 LLVM API 调用添加中文注释
- [ ] 为类型映射逻辑添加中文注释
- [ ] 为代码生成逻辑添加中文注释

---

### 任务 6.13：验证功能

- [ ] 创建简单的测试程序（`uya-src/test_codegen.uya`）：
  - [ ] 测试表达式代码生成
  - [ ] 测试语句代码生成
  - [ ] 测试函数代码生成
  - [ ] 测试结构体代码生成
  - [ ] 测试生成的 LLVM IR 正确性
- [ ] 使用 C99 编译器编译测试程序
- [ ] 运行测试程序验证功能正确性

**参考**：`tests/test_codegen.c` - 现有的 C99 测试程序

---

## 完成标准

- [ ] `codegen.uya` 已创建，包含完整的 CodeGen 实现
- [ ] `llvm_api.uya` 已完善，包含所有需要的 LLVM API 声明
- [ ] 所有结构体已翻译
- [ ] 所有初始化函数已翻译
- [ ] 所有类型映射函数已翻译
- [ ] 所有表达式代码生成函数已翻译
- [ ] 所有语句代码生成函数已翻译
- [ ] 所有声明代码生成函数已翻译
- [ ] 所有变量和函数表管理函数已翻译
- [ ] 所有输出函数已翻译
- [ ] 使用 `str_utils.uya` 和 `llvm_api.uya`
- [ ] 所有代码使用中文注释
- [ ] 功能与 C99 版本完全一致
- [ ] 测试程序通过
- [ ] 已更新 `PROGRESS.md`，标记阶段6为完成

---

## 参考文档

- `src/codegen.h` - C99 版本的 CodeGen 接口
- `src/codegen.c` - C99 版本的 CodeGen 实现
- `tests/test_codegen.c` - CodeGen 测试程序
- `uya-src/str_utils.uya` - 字符串辅助函数模块
- `uya-src/llvm_api.uya` - LLVM C API 外部函数声明
- `spec/UYA_MINI_SPEC.md` - Uya Mini 语言规范
- `BOOTSTRAP_PLAN.md` - LLVM API 类型映射规则
- LLVM C API 文档：https://llvm.org/doxygen/group__LLVMCCore.html

---

## 注意事项

1. **LLVM API 声明**：确保所有 LLVM API 函数声明正确，类型映射正确
2. **类型映射**：LLVM 类型（如 `LLVMValueRef`）映射为 `*void` 或具体结构体指针类型
3. **复杂数据结构**：变量表、函数表等使用固定大小的指针数组
4. **字符串处理**：必须使用 `str_utils.uya` 中的封装函数
5. **文件大小**：如果文件超过 1500 行，需要拆分为多个文件（如 `codegen_expr.uya`, `codegen_stmt.uya`）

---

## C99 → Uya Mini 映射示例

```c
// C99
#include <llvm-c/Core.h>

LLVMValueRef codegen_expr(CodeGen *cg, Expr *expr) {
    switch (expr->kind) {
        case EXPR_INT:
            return LLVMConstInt(LLVMInt32Type(), expr->data.int_value, 0);
        // ...
    }
}

// Uya Mini
// 在 llvm_api.uya 中声明
extern fn LLVMConstInt(ty: *void, n: i64, sign_extend: i32) *void;
extern fn LLVMInt32Type() *void;

fn codegen_expr(cg: &CodeGen, expr: &Expr) *void {
    match expr.kind {
        EXPR_INT => {
            return LLVMConstInt(LLVMInt32Type(), expr.data.int_value, 0);
        }
        // ...
    }
}
```

