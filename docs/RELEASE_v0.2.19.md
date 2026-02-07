# Uya v0.2.19 版本说明

**发布日期**：2026-02-02

本版本完成 **类型转换 as!**（强转返回 `!T`，需 try/catch）的 C 实现及自举编译器（uya-src）同步。规范见 uya.md §11.3。

---

## 核心亮点

### 1. 类型转换 as!（强转）

- **语法**：`expr as! T`，与安全转换 `expr as T` 区分
- **语义**：允许所有类型转换（包括可能有精度损失的），返回错误联合类型 `!T`
- **错误处理**：必须使用 `try` 或 `catch` 处理，符合显式错误传播规范
- **C 生成**：包装为 `{ .error_id = 0, .value = (T)(expr) }` 的 `struct err_union_X`

### 2. try/catch 与操作数类型修正

- **try**：当操作数为 `!T`（如 `as! f32` 得 `!f32`）且函数返回 `!R` 时，使用操作数类型作为临时变量类型，错误传播时转换为函数返回类型
- **catch**：当操作数为 `as! T` 时，使用操作数的 `!T` 类型及 payload 类型生成 catch 临时变量与结果
- **类型推断**：`get_c_type_of_expr` 对 `as!` 返回 `struct err_union_X`，保证 try/catch 正确识别操作数类型

### 3. !T 结构体预定义

- 在 `collect` 阶段预先收集 `as!` 使用的 `!T` 类型并定义 `struct err_union_X`，避免在表达式内联中生成导致 C 编译错误

---

## 模块变更

### C 实现（compiler-mini/src）

| 模块 | 变更 |
|------|------|
| lexer.h / lexer.c | TOKEN_AS_BANG；read_identifier_or_keyword 识别 "as" 后 `!` 为单 token |
| ast.h / ast.c | cast_expr 增加 is_force_cast 字段 |
| parser.c | cast_expr 解析 TOKEN_AS / TOKEN_AS_BANG 并设置 is_force_cast |
| checker.c | infer_type 对 AST_CAST_EXPR 且 is_force_cast 返回 TYPE_ERROR_UNION |
| codegen/c99/expr.c | as! 生成 !T 包装；try 使用操作数类型并转换错误传播；catch 使用操作数类型及 payload |
| codegen/c99/types.c | get_c_type_of_expr 对 AST_CAST_EXPR 且 is_force_cast 返回 err_union_X |
| codegen/c99/main.c | collect_slice_types_from_node 对 as! 预调用 c99_type_to_c 定义 !T 结构体 |

### 自举实现（uya-src）

| 模块 | 变更 |
|------|------|
| lexer.uya | TOKEN_AS_BANG；read_identifier_or_keyword 识别 as! |
| ast.uya | cast_expr_is_force_cast 字段 |
| parser.uya | TOKEN_AS / TOKEN_AS_BANG 分支及 is_force_cast |
| checker.uya | infer_type 对 as! 返回 TYPE_ERROR_UNION |
| codegen/c99/expr.uya | as! 包装 !T；try/catch 操作数类型逻辑 |
| codegen/c99/types.uya | get_c_type_of_expr 对 as! 返回 err_union_X |
| codegen/c99/main.uya | collect 阶段预定义 as! 的 !T 结构体 |

### 规范与测试

- **todo_mini_to_full.md**：类型转换 as! 勾选完成
- **tests/programs/test_as_force_cast.uya**：新增，覆盖 try、catch、f64→f32、i32→f32、f64→i32

---

## 测试验证

- **C 版编译器（`--c99`）**：test_as_force_cast.uya 通过
- **自举版编译器（`--uya --c99`）**：test_as_force_cast.uya 通过
- **自举构建**：`./compile.sh --c99 -e` 成功
- **全量**：225 个测试在 `--c99` 下全部通过，无回归

---

## 文件变更统计（自 v0.2.18 以来）

**C 实现**：
- `compiler-mini/src/lexer.h` — TOKEN_AS_BANG
- `compiler-mini/src/lexer.c` — as! 识别
- `compiler-mini/src/ast.h` / `ast.c` — cast_expr.is_force_cast
- `compiler-mini/src/parser.c` — as/as! 分支
- `compiler-mini/src/checker.c` — as! 推断 !T
- `compiler-mini/src/codegen/c99/expr.c` — as! 生成、try/catch 操作数类型
- `compiler-mini/src/codegen/c99/types.c` — get_c_type_of_expr as! 分支
- `compiler-mini/src/codegen/c99/main.c` — collect !T 预定义

**自举实现（uya-src）**：
- `compiler-mini/uya-src/lexer.uya` — TOKEN_AS_BANG、as! 识别
- `compiler-mini/uya-src/ast.uya` — cast_expr_is_force_cast
- `compiler-mini/uya-src/parser.uya` — as/as! 分支
- `compiler-mini/uya-src/checker.uya` — as! 推断 !T
- `compiler-mini/uya-src/codegen/c99/expr.uya` — as! 生成、try/catch 操作数类型
- `compiler-mini/uya-src/codegen/c99/types.uya` — get_c_type_of_expr as! 分支
- `compiler-mini/uya-src/codegen/c99/main.uya` — collect !T 预定义

**文档**：
- `compiler-mini/todo_mini_to_full.md` — as! 勾选完成

**测试**：
- `compiler-mini/tests/programs/test_as_force_cast.uya` — 新增

---

## 版本对比

### v0.2.18 → v0.2.19 变更

- **新增**：
  - ✅ 类型转换 `as!`：强转返回 `!T`，需 try/catch（C + uya-src）
  - ✅ try/catch 对操作数类型 `!T` 与函数返回类型 `!R` 不同的情形正确生成代码
  - ✅ `!T` 结构体在 collect 阶段预定义，避免表达式内联生成

- **非破坏性**：纯新增语法，`as` 安全转换行为不变，无破坏性变更

---

## 使用示例

### as! 强转与 try

```uya
fn main() !i32 {
    const x: f64 = 3.14;
    const y: f32 = try (x as! f32);  // f64→f32，可能损失精度，需 try

    const pi: f64 = 3.14;
    const n: i32 = try (pi as! i32);  // f64→i32 截断
    if n != 3 { return 3; }

    return 0;
}
```

### as! 强转与 catch

```uya
fn main() !i32 {
    const large: i32 = 100;
    const f: f32 = large as! f32 catch |_| { 0.0 };  // 错误时使用默认值

    if f < 99.0 || f > 101.0 { return 2; }
    return 0;
}
```

---

## 下一步计划

根据 `todo_mini_to_full.md`：
- **内存安全证明**：数组越界/空指针/未初始化/溢出/除零
- **原子类型**：atomic T、&atomic T
- **模块系统**：目录即模块、export/use 语法

---

## 相关资源

- **语言规范**：`uya.md`（§11 类型转换、§11.3 强转 as!）
- **实现文档**：`compiler-c-spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md`
- **测试用例**：`compiler-mini/tests/programs/test_as_force_cast.uya`

---

**本版本完成类型转换 as!（强转返回 !T）的 C 实现及 uya-src 同步，try/catch 正确支持操作数与函数返回类型不同的情形。**
