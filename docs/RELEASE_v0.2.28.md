# Uya v0.2.28 版本说明

**发布日期**：2026-02-05

本版本主要完成了**宏系统的自举编译器同步**，实现了完整的编译时元编程功能。C 实现与 uya-src 自举编译器现已完全同步，所有 271 个测试用例全部通过，自举对比一致。

---

## 核心亮点

### 1. 宏系统完整实现（自举同步）

- **宏声明解析**：支持 `mc` 关键字声明宏，包括参数类型（`expr`、`stmt`、`type`、`pattern`、`ident`）和返回标签（`expr`、`stmt`、`struct`、`type`）
- **宏内置函数**：
  - `@mc_code` - 输出 AST 到宏结果
  - `@mc_ast` - 构造 AST 字面量
  - `@mc_eval` - 编译时求值表达式
  - `@mc_error` - 编译时错误报告
  - `@mc_type` - 编译时类型反射
  - `@mc_get_env` - 获取编译时环境变量
- **宏插值语法**：支持 `${expr}` 在宏体中插入参数
- **跨模块宏导出**：支持 `export mc` 导出宏供其他模块使用

### 2. 内置 TypeInfo 结构体

- **自动生成**：编译器自动生成 `TypeInfo` 结构体定义（如果用户未定义）
- **类型反射**：`@mc_type(T)` 返回包含类型元信息的 `TypeInfo` 结构体
- **字段信息**：包含 `name`、`size`、`align`、`kind`、`is_integer`、`is_float`、`is_bool`、`is_pointer`、`is_array`、`is_void` 等字段

### 3. 编译器警告修复

- **const 修饰符**：修复 `&Self` 参数类型的 const 修饰符生成，根据 `is_ffi_pointer` 决定是否添加 const
- **未使用参数**：修复 `c99_type_to_c_with_self_opt` 函数的未使用参数警告
- **字符串字面量**：修复 `create_string_as_ptr` 中字符串字面量赋值的 const 警告

---

## 模块变更

### C 实现（src）

| 模块 | 变更 |
|------|------|
| ast.h/ast.c | 新增宏相关 AST 节点类型和字段 |
| lexer.h/lexer.c | 新增 `TOKEN_INTERP_OPEN`、`TOKEN_AT_IDENTIFIER` 等 token 类型 |
| parser.h/parser.c | 实现宏声明、宏调用、宏内置函数的解析 |
| checker.h/checker.c | 实现宏展开、参数替换、编译时求值、类型反射 |
| codegen/c99/types.c | 修复 `&Self` 参数的 const 修饰符生成 |
| codegen/c99/main.c | 自动生成内置 `TypeInfo` 结构体 |
| codegen/c99/expr.c | 新增块表达式（GCC statement expression）支持 |

### 自举实现（uya-src）

| 模块 | 变更 |
|------|------|
| ast.uya | 新增宏相关 AST 节点字段 |
| lexer.uya | 新增 `TOKEN_INTERP_OPEN` 处理，支持 `${expr}` 语法 |
| parser.uya | 实现宏声明参数解析、宏内置函数解析、类型位置宏调用、方法块宏调用 |
| checker.uya | 实现 `MacroParamBinding`、`MacroExpandContext`、`deep_copy_ast_with_params`、`macro_eval_expr`、`create_type_info_struct` 等 |
| codegen/c99/types.uya | 修复 `&Self` 参数的 const 修饰符生成 |
| codegen/c99/main.uya | 自动生成内置 `TypeInfo` 结构体 |
| codegen/c99/expr.uya | 新增块表达式支持 |

### 测试用例

新增 30+ 个宏相关测试用例：

- `test_macro_basic.uya` - 基本宏功能
- `test_macro_with_params.uya` - 带参数宏
- `test_macro_interp.uya` - 宏插值语法
- `test_macro_complex_stmt.uya` - 复杂语句宏
- `test_macro_param_stmt.uya` - 语句参数宏
- `test_macro_param_type.uya` - 类型参数宏
- `test_macro_type_return.uya` - 类型返回宏
- `test_macro_struct_return.uya` - 结构体返回宏
- `test_macro_mc_eval.uya` - 编译时求值
- `test_macro_mc_type.uya` - 类型反射
- `test_macro_mc_type_auto.uya` - 自动 TypeInfo
- `test_macro_sugar.uya` - 宏语法糖
- `error_macro_mc_error.uya` - 编译时错误
- 等等...

---

## 测试验证

- **C 版编译器（`--c99`）**：271 个测试全部通过
- **自举版编译器（`--uya --c99`）**：271 个测试全部通过
- **自举对比**：C 编译器与自举编译器生成的 C 文件完全一致

---

## 文件变更统计（自 v0.2.27 以来）

**统计**：57 个文件变更，约 7441 行新增，387 行删除

**主要变更**：
- `compiler-mini/src/checker.c` — +1334 行（宏展开实现）
- `compiler-mini/src/parser.c` — +1486 行（宏解析实现）
- `compiler-mini/uya-src/checker.uya` — +1165 行（自举宏展开）
- `compiler-mini/uya-src/parser.uya` — +598 行（自举宏解析）
- `compiler-mini/tests/programs/` — 30+ 个新测试用例

---

## 版本对比

### v0.2.27 → v0.2.28 变更

- **新增功能**：
  - ✅ 宏系统自举编译器同步
  - ✅ `@mc_eval` 编译时求值
  - ✅ `@mc_type` 编译时类型反射
  - ✅ `@mc_error` 编译时错误报告
  - ✅ 内置 `TypeInfo` 结构体自动生成
  - ✅ 类型位置宏调用支持
  - ✅ 方法块宏调用支持
  - ✅ 跨模块宏导出与导入

- **Bug 修复**：
  - ✅ 修复 `&Self` 参数 const 修饰符生成
  - ✅ 修复未使用参数警告
  - ✅ 修复字符串字面量 const 警告

- **非破坏性**：向后兼容，现有代码行为不变

---

## 技术细节

### 宏展开流程

1. **解析阶段**：Parser 识别 `mc` 关键字，解析宏声明（参数、返回标签、宏体）
2. **类型检查阶段**：Checker 在遇到宏调用时触发展开
3. **参数绑定**：创建 `MacroParamBinding` 映射参数名到实参 AST
4. **深拷贝替换**：`deep_copy_ast_with_params` 递归拷贝宏体，替换参数引用
5. **内置处理**：处理 `@mc_eval`、`@mc_type`、`@mc_error` 等内置函数
6. **结果输出**：根据返回标签（`expr`、`stmt`、`struct`、`type`）输出展开结果

### TypeInfo 结构体

```uya
struct TypeInfo {
    name: *i8,       // 类型名称
    size: i32,       // 类型大小（字节）
    align: i32,      // 类型对齐（字节）
    kind: i32,       // 类型种类（0=基本类型, 1=指针, 2=数组, 3=结构体）
    is_integer: bool,
    is_float: bool,
    is_bool: bool,
    is_pointer: bool,
    is_array: bool,
    is_void: bool,
}
```

### 宏示例

```uya
// 编译时类型反射
mc get_type_info(T: type) expr {
    const info: TypeInfo = @mc_type(T);
    @mc_code(info);
}

// 编译时求值
mc double_it(x: expr) expr {
    const result: i32 = @mc_eval(x * 2);
    @mc_code(result);
}

// 方法生成宏
mc add_getter() struct {
    @mc_code(@mc_ast(
        fn get_value(self: &Self) i32 {
            return self.value;
        }
    ));
}

struct Counter {
    value: i32,
}

Counter {
    add_getter();  // 生成 get_value 方法
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

- **语言规范**：`uya.md` §15 - 宏系统
- **语法规范**：`grammar_formal.md` - 宏声明 BNF
- **实现文档**：`compiler-c-spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md` §15 - 宏系统
- **测试用例**：`compiler-mini/tests/programs/test_macro_*.uya`

---

**本版本完成了宏系统的自举编译器同步，实现了完整的编译时元编程功能。C 实现与 uya-src 自举编译器现已完全同步，所有 271 个测试用例全部通过，自举对比一致。**

