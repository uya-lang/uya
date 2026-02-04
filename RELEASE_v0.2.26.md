# Uya v0.2.26 版本说明

**发布日期**：2026-02-04

本版本主要实现了**原始字符串字面量**功能（反引号语法），并更新了待办文档状态。原始字符串支持无转义序列的字符串字面量，适用于包含特殊字符（如 Windows 路径、正则表达式等）的字符串。

---

## 核心亮点

### 1. 原始字符串字面量

- **反引号语法**：支持 `` `...` `` 原始字符串字面量，所有字符按字面量处理
- **无转义序列**：原始字符串不处理转义序列（如 `\n`、`\t`、`\\` 等），所有字符按原样存储
- **FFI 兼容**：原始字符串类型为 `*byte`，与普通字符串字面量一致，可用于 FFI 函数调用
- **C 实现与自举同步**：C 实现和 uya-src 自举编译器均已实现并测试通过

### 2. 待办文档状态更新

- **原子类型**：标记为已完成（C 实现与 uya-src 已同步，测试通过）
- **drop 测试**：标记为已修复（测试通过 `--c99` 与 `--uya --c99`）

---

## 模块变更

### C 实现（src）

| 模块 | 变更 |
|------|------|
| lexer.h | 添加 `TOKEN_RAW_STRING` token 类型，在 Lexer 结构体中添加 `raw_string_mode` 字段 |
| lexer.c | 实现原始字符串处理逻辑：识别反引号、进入原始字符串模式、读取字符直到结束反引号 |
| parser.c | 在 `primary_expr` 中添加对 `TOKEN_RAW_STRING` 的支持，生成 `AST_STRING` 节点 |

### 自举实现（uya-src）

| 模块 | 变更 |
|------|------|
| lexer.uya | 添加 `TOKEN_RAW_STRING` token 类型，在 Lexer 结构体中添加 `raw_string_mode` 字段，实现原始字符串处理逻辑 |
| parser.uya | 在 `primary_expr` 中添加对 `TOKEN_RAW_STRING` 的支持 |

### 测试与工具

- **新增测试用例**：`test_raw_string.uya` - 测试原始字符串字面量的基本功能
- **测试验证**：所有测试用例在 C 版和自举版编译器中均通过

---

## 测试验证

- **C 版编译器（`--c99`）**：`test_raw_string.uya` 通过
- **自举版编译器（`--uya --c99`）**：`test_raw_string.uya` 通过
- **原子类型测试**：`test_atomic_basic.uya`、`test_atomic_ops.uya`、`test_atomic_types.uya`、`test_atomic_struct.uya` 通过 `--uya --c99`
- **drop 测试**：`test_drop_simple.uya`、`test_drop_order.uya` 通过 `--c99` 与 `--uya --c99`

---

## 文件变更统计（自 v0.2.24 以来）

**C 实现（src）**：
- `compiler-mini/src/lexer.h` — 添加 `TOKEN_RAW_STRING` 和 `raw_string_mode` 字段
- `compiler-mini/src/lexer.c` — 实现原始字符串处理逻辑（约 30 行新增）
- `compiler-mini/src/parser.c` — 添加对 `TOKEN_RAW_STRING` 的支持（1 行修改）

**自举实现（uya-src）**：
- `compiler-mini/uya-src/lexer.uya` — 添加 `TOKEN_RAW_STRING` 和 `raw_string_mode` 字段，实现原始字符串处理逻辑（约 30 行新增）
- `compiler-mini/uya-src/parser.uya` — 添加对 `TOKEN_RAW_STRING` 的支持（1 行修改）

**测试用例**：
- `compiler-mini/tests/programs/test_raw_string.uya` — 新增原始字符串测试用例（15 行）

**文档**：
- `compiler-mini/todo_mini_to_full.md` — 更新原始字符串、原子类型、drop 测试状态

**统计**：7 个文件变更，约 80+ 行新增/修改

---

## 版本对比

### v0.2.24 → v0.2.26 变更

- **新增功能**：
  - ✅ 原始字符串字面量（反引号语法 `` `...` ``）
  - ✅ 原始字符串 Lexer 支持（C 实现与 uya-src 同步）
  - ✅ 原始字符串 Parser 支持（C 实现与 uya-src 同步）

- **文档更新**：
  - ✅ 更新原子类型状态为已完成
  - ✅ 更新 drop 测试状态为已修复

- **非破坏性**：向后兼容，现有代码行为不变

---

## 技术细节

### 原始字符串实现

**语法**：使用反引号 `` `...` `` 定义原始字符串，所有字符按字面量处理，不进行转义序列处理。

**实现方式**：
1. **Lexer**：
   - 添加 `TOKEN_RAW_STRING` token 类型
   - 在 Lexer 结构体中添加 `raw_string_mode` 字段，用于跟踪是否在原始字符串模式中
   - 识别反引号字符（ASCII 96），进入原始字符串模式
   - 在原始字符串模式中，读取所有字符直到遇到结束反引号，不处理转义序列
   - 遇到结束反引号时，返回 `TOKEN_RAW_STRING` token

2. **Parser**：
   - 在 `primary_expr` 中识别 `TOKEN_RAW_STRING` token
   - 生成 `AST_STRING` 节点（与普通字符串字面量使用相同的 AST 节点类型）
   - 原始字符串和普通字符串在 AST 层面没有区别，区别在于 Lexer 处理方式

3. **类型系统**：
   - 原始字符串类型为 `*byte`，与普通字符串字面量一致
   - 可用于 FFI 函数调用，如 `printf(\`C:\\Users\\name\n\`);`

**示例**：
```uya
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    // 原始字符串：反斜杠不会被转义
    printf(`C:\Users\name\n`);        // 输出：C:\Users\name\n（字面量）
    
    // 普通字符串：反斜杠会被转义
    printf("C:\\Users\\name\\n");    // 输出：C:\Users\name（换行）
    
    // 原始字符串：制表符不会被转义
    printf(`path\to\file\n`);         // 输出：path\to\file\n（字面量）
    
    return 0;
}
```

**与普通字符串的区别**：
- 普通字符串 `"..."`：处理转义序列（`\n`、`\t`、`\\`、`\"`、`\0`）
- 原始字符串 `` `...` ``：不处理转义序列，所有字符按字面量处理

---

## 使用示例

### 原始字符串基本使用

```uya
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    // Windows 路径（反斜杠不会被转义）
    printf(`C:\Users\name\file.txt\n`);
    
    // 正则表达式（特殊字符不会被转义）
    printf(`\d+\s+\w+\n`);
    
    // 包含双引号的字符串
    printf(`say "hello"\n`);
    
    // 包含反斜杠的字符串
    printf(`backslash\\test\n`);
    
    return 0;
}
```

### 原始字符串与普通字符串对比

```uya
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    // 普通字符串：\n 被转义为换行符
    printf("line1\nline2\n");  // 输出两行
    
    // 原始字符串：\n 按字面量处理
    printf(`line1\nline2\n`);  // 输出：line1\nline2\n（字面量）
    
    return 0;
}
```

---

## 下一步计划

根据 `todo_mini_to_full.md`：
- **&atomic T**：原子指针（待实现）
- **内存安全证明**：数组越界/空指针/未初始化/溢出/除零检查（待实现）
- **泛型（Generics）**：类型参数、泛型函数、泛型结构体（待实现）
- **异步编程（Async）**：async/await、Future 类型（待实现）

---

## 相关资源

- **语言规范**：`uya.md` §1 - 字符串字面量（原始字符串）
- **实现文档**：`compiler-mini/spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md` §10 - 字符串插值
- **测试用例**：`compiler-mini/tests/programs/test_raw_string.uya`

---

**本版本实现了原始字符串字面量功能，支持无转义序列的字符串字面量，适用于包含特殊字符的字符串场景。C 实现与 uya-src 自举编译器均已实现并测试通过。**

