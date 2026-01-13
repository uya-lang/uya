# Uya Mini 编译器自举实现计划

## 概述

本文档详细规划了将现有的 C99 版本的 Uya Mini 编译器翻译成 Uya Mini 语言版本的完整策略和步骤，实现编译器的自举。

## 当前状态

### C99 编译器代码规模

基于代码行数统计（2026-01-13）：

| 模块 | .c 文件行数 | .h 文件行数 | 总行数 | 复杂度 |
|------|------------|------------|--------|--------|
| arena | 54 | 26 | 80 | 低（最简单） |
| ast | 159 | 250 | 409 | 低 |
| lexer | 365 | 100 | 465 | 中 |
| parser | 2,506 | 50 | 2,556 | 高（最大模块） |
| checker | 1,575 | 103 | 1,678 | 高 |
| codegen | 3,338 | 118 | 3,456 | 高（最大模块） |
| main | 187 | - | 187 | 低 |
| **总计** | **8,184** | **647** | **8,831** | - |

### 模块依赖关系

```
main.c
  ├── arena.h/c (无依赖)
  ├── lexer.h/c (依赖 arena)
  ├── parser.h/c (依赖 arena, lexer, ast)
  ├── checker.h/c (依赖 arena, ast)
  └── codegen.h/c (依赖 arena, ast, checker, LLVM C API)
```

### 关键特性要求

根据 [UYA_MINI_SPEC.md](spec/UYA_MINI_SPEC.md)，Uya Mini 支持：
- ✅ 基础类型：`i32`, `bool`, `byte`, `void`
- ✅ 数组类型：`[T: N]`（固定大小数组）
- ✅ 指针类型：`&T`（普通指针）、`*T`（FFI指针，仅用于extern函数）
- ✅ 结构体类型
- ✅ 控制流：`if`, `while`, `for`（数组遍历）, `break`, `continue`
- ✅ 内置函数：`sizeof`, `len`
- ✅ 外部函数调用：`extern` 函数（调用 LLVM C API 和 C 标准库）

## 翻译策略

### 总体原则

1. **保持功能等价**：翻译后的 Uya Mini 代码必须与 C99 版本功能完全一致
2. **遵循 Uya Mini 规范**：严格遵循 `UYA_MINI_SPEC.md` 中定义的语言特性
3. **无堆分配约束**：Uya Mini 编译器自身不使用堆分配，使用 Arena 分配器
4. **模块化翻译**：按模块顺序翻译，确保依赖关系正确
5. **渐进式验证**：每个模块翻译后立即验证功能正确性
6. **字符串函数封装**：封装常用字符串操作为辅助函数，简化代码翻译

### C99 → Uya Mini 映射规则

#### 1. 类型映射

| C99 类型 | Uya Mini 类型 | 说明 |
|----------|--------------|------|
| `int` | `i32` | 32位有符号整数 |
| `size_t` | `i32` | 大小类型（Uya Mini 使用 i32） |
| `uint8_t` | `byte` | 无符号字节 |
| `void` | `void` | 仅用于函数返回类型 |
| `struct Name` | `struct Name` | 结构体类型（保持不变） |
| `Type *` | `&Type` | 普通指针（用于函数参数和局部变量） |
| `Type *` (extern函数参数) | `*Type` | FFI指针（仅用于extern函数） |
| `Type array[N]` | `[Type: N]` | 固定大小数组 |

#### 2. 内存管理映射

| C99 | Uya Mini | 说明 |
|-----|----------|------|
| `malloc/calloc` | ❌ 不支持 | 使用 Arena 分配器 |
| `free` | ❌ 不支持 | Arena 自动管理 |
| `static Type var[N]` | `var arr: [Type: N] = [];` | 固定大小数组（栈上分配） |
| `Type *ptr = &var` | `var ptr: &Type = &var;` | 取地址运算符 |

#### 3. 函数声明映射

```c
// C99
int function_name(int param1, struct Type *param2);

// Uya Mini
fn function_name(param1: i32, param2: &Type) i32 {
    // 函数体
}
```

#### 4. 结构体映射

```c
// C99
typedef struct {
    int field1;
    const char *field2;
} StructName;

// Uya Mini
struct StructName {
    field1: i32;
    field2: &byte;  // 或 *byte（如果是extern函数参数）
}
```

#### 5. 数组操作映射

```c
// C99
Type arr[100];
arr[0] = value;
size_t len = sizeof(arr) / sizeof(arr[0]);

// Uya Mini
var arr: [Type: 100] = [];
arr[0] = value;
const len: i32 = len(arr);  // 或 sizeof(arr) / sizeof(Type)
```

#### 6. 字符串处理（重要）

**策略：封装字符串函数**

Uya Mini 不直接支持字符串类型，但可以通过封装 C 标准库字符串函数来解决：

1. **创建字符串辅助函数模块** (`str_utils.uya`)：
   - 封装常用 C 标准库字符串函数为 `extern` 函数
   - 提供统一的字符串操作接口
   - 字符串字面量作为 `extern` 函数参数（类型为 `*byte`）

2. **封装的字符串函数示例**：

```uya
// str_utils.uya - 字符串辅助函数模块

// C 标准库字符串函数声明
extern fn strlen(s: *byte) i32;
extern fn strcmp(s1: *byte, s2: *byte) i32;
extern fn strncmp(s1: *byte, s2: *byte, n: i32) i32;
extern fn strcpy(dest: *byte, src: *byte) *byte;
extern fn strncpy(dest: *byte, src: *byte, n: i32) *byte;
extern fn strcat(dest: *byte, src: *byte) *byte;
extern fn sprintf(s: *byte, format: *byte, ...) i32;
extern fn fprintf(stream: *void, format: *byte, ...) i32;
extern fn snprintf(s: *byte, n: i32, format: *byte, ...) i32;

// 封装函数（可选，提供更友好的接口）
fn str_equals(s1: *byte, s2: *byte) bool {
    return strcmp(s1, s2) == 0;
}

fn str_length(s: *byte) i32 {
    return strlen(s);
}
```

3. **使用方式**：

```c
// C99 代码
if (strcmp(token->value, "fn") == 0) {
    // ...
}
fprintf(stderr, "Error: %s\n", message);

// Uya Mini 代码
if strcmp(token.value, "fn") == 0 {
    // ...
}
fprintf(stderr, "Error: %s\n", message);  // 字符串字面量作为 *byte 参数
```

4. **内部字符串存储**：
   - 对于需要存储的字符串（如标识符名称），使用 `[byte: N]` 数组
   - 使用索引和循环进行字符串操作
   - 关键字符串（如错误消息）可以作为全局常量数组或使用字符串字面量

5. **优势**：
   - 简化代码翻译过程
   - 保持与 C99 代码的相似性
   - 充分利用 C 标准库的字符串函数
   - 减少手动实现字符串操作的复杂度

#### 7. 外部函数调用（LLVM C API 和 C 标准库）

```c
// C99
#include <llvm-c/Core.h>
#include <stdio.h>
LLVMValueRef value = LLVMBuildAdd(...);
fprintf(stderr, "error\n");

// Uya Mini
extern fn LLVMBuildAdd(...) *void;
extern fn fprintf(stream: *void, format: *byte, ...) i32;
const value: *void = LLVMBuildAdd(...);
fprintf(stderr, "error\n");  // 字符串字面量作为 *byte 参数
```

### 关键挑战和解决方案

#### 挑战1：LLVM C API 类型定义

**问题**：LLVM C API 使用大量 `typedef` 类型（如 `LLVMContextRef`, `LLVMValueRef` 等），这些类型在 Uya Mini 中如何处理？

**解决方案**：
- 将 LLVM 类型定义为结构体指针类型（`*void` 或具体结构体）
- 在 Uya Mini 中使用 `extern` 函数声明，参数和返回值使用 `*T` 类型
- 示例：`extern fn LLVMBuildAdd(builder: *void, lhs: *void, rhs: *void, name: *byte) *void;`

#### 挑战2：固定大小数组限制

**问题**：Uya Mini 数组大小必须是编译期常量，但某些地方可能需要动态大小？

**解决方案**：
- 使用足够大的固定大小数组（如 `[Type: 1024]`）
- 使用运行时索引变量跟踪实际使用的大小
- 在规范允许的范围内，使用最大的合理固定大小

#### 挑战3：字符串处理 ✅ 已解决

**问题**：C99 代码中大量使用字符串（`const char *`），Uya Mini 不支持字符串类型。

**解决方案**：**字符串函数封装**
- 创建 `str_utils.uya` 模块，封装 C 标准库字符串函数
- 字符串字面量作为 `extern` 函数参数（类型为 `*byte`）
- 内部字符串使用 `[byte: N]` 数组存储（如需要）
- 使用封装的函数进行字符串操作（`strcmp`, `strlen`, `fprintf` 等）

#### 挑战4：头文件包含

**问题**：C99 使用 `#include`，Uya Mini 不支持模块系统。

**解决方案**：
- 将所有需要的声明合并到一个 Uya Mini 源文件中
- `extern` 函数声明直接写在源文件中
- 结构体定义直接写在源文件中（按依赖顺序）
- 创建 `llvm_api.uya` 和 `str_utils.uya` 作为共享声明文件

#### 挑战5：条件编译

**问题**：C99 代码中有 `#ifdef` 等条件编译指令。

**解决方案**：
- 根据需要选择一种配置（如选择 Linux/Unix 配置）
- 手动展开条件编译，保留需要的代码
- 移除不需要的条件分支

## 翻译顺序

### 阶段0：准备工作（字符串函数封装）

**模块**：创建字符串辅助函数模块和 LLVM API 声明文件

**优先级**：P0（最高）

**工作量估算**：1-2 小时

**任务**：
1. 创建 `uya-src/str_utils.uya` - 字符串辅助函数模块
   - 声明常用的 C 标准库字符串函数（`strcmp`, `strlen`, `strcpy`, `fprintf`, `sprintf` 等）
   - 可选：创建封装函数提供更友好的接口
2. 创建 `uya-src/llvm_api.uya` - LLVM C API 外部函数声明
   - 声明 CodeGen 模块需要的 LLVM C API 函数
   - 逐步添加，根据代码生成模块的需要

**验证方法**：
- 创建简单的测试程序验证字符串函数封装

---

### 阶段1：基础模块（无依赖）

**模块**：`arena.h/c`

**优先级**：P0

**原因**：所有其他模块都依赖 Arena 分配器，必须最先翻译。

**工作量估算**：1-2 小时
- 代码量小（80行）
- 无外部依赖
- 逻辑简单

**验证方法**：
- 翻译后编译测试程序验证 Arena 功能

---

### 阶段2：AST 数据结构

**模块**：`ast.h/c`

**优先级**：P0

**原因**：Parser、Checker、CodeGen 都依赖 AST 定义。

**工作量估算**：2-3 小时
- 代码量中等（409行）
- 主要是数据结构定义
- 需要仔细映射 C 结构体到 Uya Mini 结构体

**验证方法**：
- 创建简单的 AST 节点测试程序

---

### 阶段3：词法分析器

**模块**：`lexer.h/c`

**优先级**：P0

**原因**：Parser 依赖 Lexer。

**工作量估算**：3-4 小时
- 代码量中等（465行）
- 需要处理字符串操作（使用封装的字符串函数）
- 状态机逻辑相对简单

**关键挑战**：
- 字符串处理（使用 `str_utils.uya` 中的封装函数）
- 标识符、关键字匹配（使用 `strcmp`）

**验证方法**：
- 使用现有的 lexer 测试程序验证

---

### 阶段4：语法分析器

**模块**：`parser.h/c`

**优先级**：P0

**原因**：Checker 和 CodeGen 依赖 Parser。

**工作量估算**：8-12 小时
- 代码量最大（2,556行）
- 逻辑复杂（递归下降解析）
- 需要仔细处理错误处理和递归调用

**关键挑战**：
- 递归函数调用（Uya Mini 支持）
- 错误处理（使用返回值代替异常，使用 `fprintf` 输出错误消息）
- 字符串操作（使用 `str_utils.uya` 中的封装函数）

**验证方法**：
- 使用现有的 parser 测试程序验证
- 解析简单的 Uya Mini 程序

---

### 阶段5：类型检查器

**模块**：`checker.h/c`

**优先级**：P0

**原因**：CodeGen 依赖 Checker。

**工作量估算**：6-8 小时
- 代码量大（1,678行）
- 逻辑复杂（类型系统、符号表）
- 需要仔细处理哈希表和数据结构

**关键挑战**：
- 哈希表实现（使用固定大小数组和开放寻址）
- 符号表管理（作用域、符号查找）
- 类型系统实现（递归类型、类型比较）
- 字符串操作（使用 `str_utils.uya` 中的封装函数）

**验证方法**：
- 使用现有的 checker 测试程序验证

---

### 阶段6：代码生成器

**模块**：`codegen.h/c`

**优先级**：P0

**原因**：编译器核心功能，生成目标代码。

**工作量估算**：10-15 小时
- 代码量最大（3,456行）
- 逻辑最复杂（LLVM API 调用）
- 需要大量 `extern` 函数声明

**关键挑战**：
- LLVM C API 的 `extern` 函数声明（数百个函数，使用 `llvm_api.uya`）
- 类型映射（LLVM 类型到 Uya Mini 类型）
- 复杂的数据结构（变量表、函数表等）
- 字符串操作（使用 `str_utils.uya` 中的封装函数）

**验证方法**：
- 使用现有的 codegen 测试程序验证
- 编译简单的 Uya Mini 程序生成二进制

---

### 阶段7：主程序

**模块**：`main.c`

**优先级**：P0

**原因**：编译器入口点。

**工作量估算**：2-3 小时
- 代码量小（187行）
- 主要是流程控制
- 需要处理命令行参数和文件 I/O

**关键挑战**：
- 文件 I/O（需要使用 `extern` 函数调用 C 标准库：`fopen`, `fread`, `fclose` 等）
- 命令行参数处理（使用 `extern` 函数）
- 字符串操作（使用 `str_utils.uya` 中的封装函数）

**验证方法**：
- 编译完整的编译器，测试编译 Uya Mini 程序

---

## 实施步骤

### 步骤1：准备工作

1. ✅ 创建实现计划文档（本文档）
2. ⏳ 创建翻译工作目录结构
   - `compiler-mini/uya-src/` - Uya Mini 源代码目录
   - `compiler-mini/uya-src/arena.uya` - Arena 模块
   - `compiler-mini/uya-src/ast.uya` - AST 模块
   - `compiler-mini/uya-src/lexer.uya` - Lexer 模块
   - `compiler-mini/uya-src/parser.uya` - Parser 模块
   - `compiler-mini/uya-src/checker.uya` - Checker 模块
   - `compiler-mini/uya-src/codegen.uya` - CodeGen 模块
   - `compiler-mini/uya-src/main.uya` - Main 模块
3. ⏳ 创建字符串辅助函数模块
   - `compiler-mini/uya-src/str_utils.uya` - 字符串辅助函数 extern 声明
4. ⏳ 创建 LLVM C API 外部函数声明文件
   - `compiler-mini/uya-src/llvm_api.uya` - LLVM C API extern 声明（逐步添加）

### 步骤2：翻译基础模块（阶段0-2）

1. 创建 `str_utils.uya` 和 `llvm_api.uya` 框架（阶段0）
2. 翻译 `arena.uya`（阶段1）
3. 翻译 `ast.uya`（阶段2）
4. 验证基础模块功能

### 步骤3：翻译核心模块（阶段3-4）

1. 翻译 `lexer.uya`（使用 `str_utils.uya`）
2. 翻译 `parser.uya`（使用 `str_utils.uya`）
3. 验证词法和语法分析功能

### 步骤4：翻译高级模块（阶段5-6）

1. 翻译 `checker.uya`（使用 `str_utils.uya`）
2. 翻译 `codegen.uya`（使用 `llvm_api.uya` 和 `str_utils.uya`）
3. 验证类型检查和代码生成功能

### 步骤5：整合和测试（阶段7）

1. 翻译 `main.uya`（使用 `str_utils.uya` 和文件 I/O extern 函数）
2. 整合所有模块（合并所有 `.uya` 文件为一个源文件，或使用链接器）
3. 使用 C99 编译器编译 Uya Mini 版本
4. 验证自举编译器功能

### 步骤6：自举验证

1. 使用 C99 编译器编译 Uya Mini 编译器（生成 `compiler-mini-uya-v1`）
2. 使用 `compiler-mini-uya-v1` 编译自身（生成 `compiler-mini-uya-v2`）
3. 比较 `v1` 和 `v2` 的功能等价性
4. 使用 `v2` 编译测试程序，验证功能正确性

## 字符串函数封装详细设计

### str_utils.uya 模块结构

```uya
// str_utils.uya - 字符串辅助函数模块
// 封装 C 标准库字符串函数，简化 Uya Mini 代码中的字符串操作

// ===== C 标准库字符串函数声明 =====

// 字符串长度
extern fn strlen(s: *byte) i32;

// 字符串比较
extern fn strcmp(s1: *byte, s2: *byte) i32;
extern fn strncmp(s1: *byte, s2: *byte, n: i32) i32;

// 字符串复制
extern fn strcpy(dest: *byte, src: *byte) *byte;
extern fn strncpy(dest: *byte, src: *byte, n: i32) *byte;

// 字符串连接
extern fn strcat(dest: *byte, src: *byte) *byte;

// 字符串格式化输出
extern fn sprintf(s: *byte, format: *byte, ...) i32;
extern fn fprintf(stream: *void, format: *byte, ...) i32;
extern fn snprintf(s: *byte, n: i32, format: *byte, ...) i32;

// 字符分类（ctype.h）
extern fn isalpha(c: i32) i32;
extern fn isdigit(c: i32) i32;
extern fn isalnum(c: i32) i32;
extern fn isspace(c: i32) i32;

// ===== 封装函数（可选，提供更友好的接口）=====

// 字符串相等判断
fn str_equals(s1: *byte, s2: *byte) bool {
    return strcmp(s1, s2) == 0;
}

// 字符串长度（类型为 i32）
fn str_length(s: *byte) i32 {
    return strlen(s);
}
```

### 使用示例

```uya
// 在 lexer.uya 中使用
fn is_keyword(token_value: *byte) bool {
    if strcmp(token_value, "fn") == 0 {
        return true;
    }
    if strcmp(token_value, "if") == 0 {
        return true;
    }
    // ...
    return false;
}

// 在 parser.uya 中使用
fn report_error(message: *byte) void {
    fprintf(stderr, "Error: %s\n", message);
}

// 在 main.uya 中使用
fn print_usage(program_name: *byte) void {
    fprintf(stderr, "Usage: %s <input> -o <output>\n", program_name);
}
```

## 验证策略

### 单元测试验证

每个模块翻译后，使用现有的测试程序验证：
- `test_arena.c` → 翻译为 Uya Mini 测试程序
- `test_lexer.c` → 翻译为 Uya Mini 测试程序
- `test_parser.c` → 翻译为 Uya Mini 测试程序
- `test_checker.c` → 翻译为 Uya Mini 测试程序
- `test_codegen.c` → 翻译为 Uya Mini 测试程序

### 集成测试验证

1. **功能测试**：使用 Uya Mini 编译器编译现有的测试程序（`tests/programs/*.uya`）
2. **输出比较**：比较 C99 版本和 Uya Mini 版本编译同一程序的输出
3. **自举测试**：使用 Uya Mini 编译器编译自身

### 回归测试

维护测试用例列表，确保翻译后的编译器能够通过所有现有测试。

## 文件结构规划

```
compiler-mini/
├── src/                    # C99 源代码（保持不变）
│   ├── arena.c/h
│   ├── lexer.c/h
│   └── ...
├── uya-src/                # Uya Mini 源代码（新增）
│   ├── str_utils.uya       # 字符串辅助函数模块（新增）
│   ├── llvm_api.uya        # LLVM C API extern 声明（新增）
│   ├── arena.uya
│   ├── ast.uya
│   ├── lexer.uya
│   ├── parser.uya
│   ├── checker.uya
│   ├── codegen.uya
│   └── main.uya
├── build-uya/              # Uya Mini 编译器构建目录（新增）
│   └── compiler-mini-uya   # 编译后的 Uya Mini 编译器
└── ...
```

## 时间估算

基于代码规模和复杂度：

| 阶段 | 模块 | 工作量估算 | 累计时间 |
|------|------|-----------|---------|
| 阶段0 | str_utils, llvm_api | 1-2 小时 | 1-2 小时 |
| 阶段1 | arena | 1-2 小时 | 2-4 小时 |
| 阶段2 | ast | 2-3 小时 | 4-7 小时 |
| 阶段3 | lexer | 3-4 小时 | 7-11 小时 |
| 阶段4 | parser | 8-12 小时 | 15-23 小时 |
| 阶段5 | checker | 6-8 小时 | 21-31 小时 |
| 阶段6 | codegen | 10-15 小时 | 31-46 小时 |
| 阶段7 | main | 2-3 小时 | 33-49 小时 |
| 整合和测试 | - | 4-6 小时 | 37-55 小时 |
| 自举验证 | - | 2-4 小时 | 39-59 小时 |

**总计**：约 40-60 小时（5-8 个工作日）

## 风险和控制

### 风险1：LLVM API 声明错误

**影响**：代码生成功能失败

**缓解措施**：
- 仔细对照 LLVM C API 文档
- 创建独立的 LLVM API 声明文件，便于维护
- 逐步添加 API 声明，每个模块验证后再继续

### 风险2：字符串处理复杂 ✅ 已缓解

**影响**：某些功能可能难以实现

**缓解措施**：
- ✅ **字符串函数封装**：创建 `str_utils.uya` 模块，封装常用字符串操作
- 优先实现核心功能，字符串处理使用封装的函数
- 使用字节数组和索引代替复杂的字符串操作
- 关键字符串作为全局常量或使用字符串字面量

### 风险3：数组大小限制

**影响**：某些数据结构可能超出固定大小限制

**缓解措施**：
- 使用足够大的固定大小（如 1024、2048）
- 在规范允许的范围内调整大小
- 如果必要，可以考虑扩展 Uya Mini 规范（但需要谨慎）

### 风险4：翻译错误

**影响**：功能不正确

**缓解措施**：
- 每个模块翻译后立即验证
- 使用现有测试程序验证功能
- 代码审查和对比 C99 版本

## 后续工作

1. **性能优化**：翻译后的 Uya Mini 编译器可能性能不如 C99 版本，可以后续优化
2. **代码清理**：移除不必要的代码，简化实现
3. **文档更新**：更新 README 和文档，说明自举过程
4. **扩展功能**：如果翻译过程中发现 Uya Mini 规范需要扩展，可以后续讨论

## 参考文档

- [UYA_MINI_SPEC.md](spec/UYA_MINI_SPEC.md) - Uya Mini 语言规范
- [PROGRESS.md](PROGRESS.md) - 编译器实现进度
- [README.md](README.md) - 项目说明
- LLVM C API 文档：https://llvm.org/doxygen/group__LLVMCCore.html
- C 标准库文档：https://en.cppreference.com/w/c/string/byte

## 状态跟踪

- **创建日期**：2026-01-13
- **当前状态**：计划阶段
- **下一步行动**：开始阶段0（字符串函数封装和 LLVM API 声明框架）

---

**注意**：本文档是动态文档，在翻译过程中会根据实际情况更新和调整。
