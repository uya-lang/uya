# Uya v0.2.21 版本说明

**发布日期**：2026-02-02

本版本完成 **模块系统基础支持** 和 **类型转换 as! 特性**：实现目录即模块、`export`/`use` 语句、模块依赖检测，以及强类型转换 `as!` 操作符。规范见 uya.md。

---

## 核心亮点

### 1. 模块系统基础支持

- **目录即模块**：目录结构自动映射为模块路径，如 `std/io/` 对应模块 `std.io`
- **export 语句**：标记函数、结构体、联合体、接口为可导出项
- **use 语句**：导入其他模块的导出项，支持多级路径（如 `use std.io.read_file;`）
- **模块可见性**：未导出的项仅在同一模块内可见，跨模块访问需通过 `export`
- **路径解析**：自动从文件路径提取模块路径，支持多级目录结构

### 2. 类型转换 as! 特性

- **强类型转换**：`expr as! T` 将表达式转换为类型 `T`，返回 `!T`（错误类型）
- **错误处理**：转换失败时返回错误值，需使用 `try` 或 `?` 处理
- **类型安全**：编译时检查转换的合法性，确保类型安全

### 3. 模块依赖检测

- **循环依赖检测**：使用 DFS 算法检测模块间的循环依赖，编译时报错
- **未定义模块检测**：引用不存在的模块时，编译时报错
- **依赖关系记录**：维护模块依赖表，支持依赖分析和错误定位

### 4. 测试程序增强

- **自动模块文件收集**：测试脚本自动收集 `use` 语句引用的模块文件
- **多文件编译支持**：支持多文件模块的测试，确保所有依赖文件被正确编译
- **项目根目录识别**：自动识别包含 `main` 函数的文件所在目录为项目根目录

---

## 模块变更

### C 实现（compiler-mini/src）

| 模块 | 变更 |
|------|------|
| ast.c/ast.h | 新增 `AST_USE_STMT`、`AST_EXPORT` 标记；`AST_CAST_EXPR` 支持 `as!` 操作符 |
| parser.c | 解析 `use` 语句和 `export` 关键字；解析 `as!` 类型转换表达式 |
| checker.c/checker.h | 模块系统核心实现：模块表、导出表、依赖检测、循环依赖检测、路径提取 |
| codegen/c99/expr.c | 生成 `as!` 类型转换的 C 代码；slice 数组访问修复（指针类型使用 `->`） |
| codegen/c99/function.c | slice 类型参数通过指针传递；slice 参数注册为指针类型 |
| codegen/c99/types.c | slice 结构体名称生成修复（去除多余的 `*`） |
| lexer.c/lexer.h | 新增 `TOKEN_USE`、`TOKEN_EXPORT`、`TOKEN_AS_BANG` 词法单元 |

### 自举实现（uya-src）

| 模块 | 变更 |
|------|------|
| ast.uya | 新增 `AST_USE_STMT`、`AST_EXPORT` 标记；`AST_CAST_EXPR` 支持 `as!` |
| parser.uya | 解析 `use` 语句和 `export` 关键字；解析 `as!` 类型转换表达式 |
| checker.uya | 模块系统完整实现：模块表、导出表、依赖检测、循环依赖检测、路径提取（752 行新增代码） |
| codegen/c99/expr.uya | 生成 `as!` 类型转换的 C 代码 |
| codegen/c99/function.uya | slice 类型参数处理（与 C 版同步） |
| codegen/c99/types.uya | slice 结构体名称生成修复（与 C 版同步） |
| lexer.uya | 新增 `TOKEN_USE`、`TOKEN_EXPORT`、`TOKEN_AS_BANG` 词法单元 |

### 测试与工具

- **run_programs.sh**：增强模块文件收集功能，修复 bash 循环名称引用警告
- **测试用例**：新增 10+ 个模块系统测试用例，覆盖基本导入、多级模块、错误检测等场景

---

## 测试验证

- **C 版编译器（`--c99`）**：所有模块系统测试用例通过
- **自举版编译器（`--uya --c99`）**：所有模块系统测试用例通过
- **自举对比**：`./compile.sh --c99 -b` 一致（C 版与自举版生成 C 完全一致）
- **编译警告**：所有编译警告已修复，包括 slice 相关问题和 bash 脚本警告

---

## 文件变更统计（自 v0.2.20 以来）

**C 实现**：
- `compiler-mini/src/ast.c/ast.h` — 新增 `AST_USE_STMT`、`AST_EXPORT`、`as!` 支持
- `compiler-mini/src/parser.c` — `use`/`export` 解析，`as!` 解析
- `compiler-mini/src/checker.c/checker.h` — 模块系统核心实现（模块表、导出表、依赖检测）
- `compiler-mini/src/codegen/c99/expr.c` — `as!` 代码生成，slice 数组访问修复
- `compiler-mini/src/codegen/c99/function.c` — slice 类型参数处理修复
- `compiler-mini/src/codegen/c99/types.c` — slice 结构体名称生成修复
- `compiler-mini/src/lexer.c/lexer.h` — 新增词法单元

**自举实现（uya-src）**：
- `compiler-mini/uya-src/ast.uya` — 新增 AST 节点类型
- `compiler-mini/uya-src/parser.uya` — `use`/`export`/`as!` 解析（213 行新增）
- `compiler-mini/uya-src/checker.uya` — 模块系统完整实现（752 行新增）
- `compiler-mini/uya-src/lexer.uya` — 新增词法单元
- `compiler-mini/uya-src/codegen/c99/*.uya` — 与 C 版同步的修复

**测试与工具**：
- `compiler-mini/tests/run_programs.sh` — 模块文件收集功能，bash 警告修复
- `compiler-mini/tests/programs/*.uya` — 新增 10+ 个模块系统测试用例
- `compiler-mini/todo_mini_to_full.md` — 更新模块系统和类型转换状态

**统计**：40 个文件变更，4208 行新增，32 行删除

---

## 版本对比

### v0.2.20 → v0.2.21 变更

- **新增功能**：
  - ✅ 模块系统基础支持（目录即模块、export/use 语句）
  - ✅ 类型转换 `as!` 操作符
  - ✅ 模块依赖检测（循环依赖、未定义模块）
  - ✅ 测试程序自动模块文件收集

- **修复**：
  - ✅ slice 结构体名称生成问题（去除多余的 `*`）
  - ✅ slice 类型参数传递问题（通过指针传递）
  - ✅ slice 数组访问问题（指针类型使用 `->`）
  - ✅ bash 脚本循环名称引用警告

- **非破坏性**：向后兼容，现有测试用例行为不变

---

## 使用示例

### 模块系统

```uya
// std/io/io.uya
export fn read_file(path: &byte) !&byte {
    // ...
}

// main.uya
use std.io.read_file;

fn main() i32 {
    const content = try read_file("test.txt");
    return 0;
}
```

### 类型转换 as!

```uya
fn parse_int(s: &byte) !i32 {
    // 解析失败时返回错误
    const n = parse(s) as! i32;
    return n;
}

fn main() i32 {
    const n = try parse_int("123");
    return 0;
}
```

### 多级模块

```uya
// std/io/file.uya
export struct File {
    // ...
}

// main.uya
use std.io.file.File;

fn main() i32 {
    var f: File = // ...
    return 0;
}
```

---

## 下一步计划

根据 `todo_mini_to_full.md`：
- **模块系统增强**：模块别名、模块重导出、条件编译
- **内存安全证明**：数组越界/空指针/未初始化/溢出/除零
- **原子类型**：atomic T、&atomic T
- **原始字符串**：`` `...` `` 无转义

---

## 相关资源

- **语言规范**：`uya.md`（模块系统、类型转换）
- **实现文档**：`compiler-mini/spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md`
- **测试用例**：`compiler-mini/tests/programs/test_module_*.uya`

---

**本版本完成模块系统基础支持和类型转换 as! 特性，实现了目录即模块、export/use 语句、模块依赖检测等核心功能，为后续模块系统增强奠定了基础。**

