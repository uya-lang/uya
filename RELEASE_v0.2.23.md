# Uya v0.2.23 版本说明

**发布日期**：2026-02-04

本版本主要完成 **C 编译器修改同步到 uya-src** 和 **迭代器支持完整实现**：将 C 编译器中的迭代器支持、!void 错误联合类型修复、结构体方法类型推断等功能同步到自举编译器，修复了多个编译错误和代码生成问题。

---

## 核心亮点

### 1. 迭代器支持完整实现

- **for 循环迭代器支持**：实现了通过接口进行迭代的完整支持，`for obj |v|` 和 `for obj |&v|` 形式
- **迭代器接口检查**：Checker 中检查迭代器接口（next 和 value 方法），next 方法必须返回 `!void`，value 方法返回元素类型
- **迭代器代码生成**：Codegen 中生成 while(1) 循环，调用 next() 检查 error_id，调用 value() 获取当前值
- **数组类型回退**：如果对象不是迭代器，自动回退到数组类型处理，保持向后兼容

### 2. 错误联合类型 !void 修复

- **修复 type_from_ast**：移除对 `TYPE_VOID` payload 的特殊检查，允许 `!void` 作为有效的错误联合类型
- **修复 catch 表达式**：支持 void payload，不声明结果变量，正确处理 `!void` 类型的 catch 表达式
- **修复函数返回**：为 `!void` 返回类型的函数添加默认返回语句（`return (struct err_union_void){ .error_id = 0 }`）
- **修复 void 变量处理**：void 类型变量生成 `(void)(expr);` 而不是变量声明，正确处理 catch 表达式中的 break/continue

### 3. 结构体方法类型推断增强

- **方法调用类型推断**：在 `checker_infer_type` 中为 `AST_CALL_EXPR` 添加结构体方法调用的类型推断
- **成员访问类型推断**：在 `get_c_type_of_expr` 中支持方法类型推断，先查找字段，字段不存在时查找方法
- **递归类型推断**：支持 `obj.method()` 形式的递归类型推断，正确推断方法返回类型

### 4. 代码生成问题修复

- **修复 err_union_void 结构体定义位置**：预先生成接口方法签名中使用的错误联合类型结构体定义，避免在 vtable 内部生成结构体定义
- **修复变量移动错误**：使用 `copy_type` 避免变量移动，修复 for 循环中的类型检查错误
- **修复变量遮蔽错误**：重命名内层循环变量，避免与外层作用域变量冲突
- **修复语法错误**：将不支持的 `if ... then ... else ...` 语法改为标准的 if-else 语句

---

## 模块变更

### C 实现（compiler-mini/src）

| 模块 | 变更 |
|------|------|
| checker.c | 修复错误联合类型 !void 的处理；添加结构体方法调用的类型推断；添加 for 循环的迭代器支持 |
| codegen/c99/expr.c | 修复 catch 表达式中 !void 类型的处理，支持 void payload |
| codegen/c99/function.c | 为 !void 返回类型的函数添加默认返回语句 |
| codegen/c99/types.c | 修复成员访问和函数调用的类型推断，支持方法调用 |
| codegen/c99/stmt.c | 添加 void 类型变量处理；添加 for 循环的迭代器代码生成 |
| codegen/c99/structs.c | 修复 err_union_void 结构体定义在 vtable 内部的问题，预先生成错误联合类型结构体定义 |

### 自举实现（uya-src）

| 模块 | 变更 |
|------|------|
| checker.uya | 修复错误联合类型 !void 的处理；添加结构体方法调用的类型推断；添加 for 循环的迭代器支持（使用 copy_type 避免变量移动） |
| codegen/c99/expr.uya | 修复 catch 表达式中 !void 类型的处理，支持 void payload |
| codegen/c99/function.uya | 为 !void 返回类型的函数添加默认返回语句；修复语法错误（if-then-else 改为 if-else） |
| codegen/c99/types.uya | 修复成员访问和函数调用的类型推断，支持方法调用 |
| codegen/c99/stmt.uya | 添加 void 类型变量处理；for 循环的迭代器代码生成（已存在） |
| codegen/c99/structs.uya | 修复 err_union_void 结构体定义在 vtable 内部的问题，添加 pregenerate_error_union_structs_for_interface 函数 |

### 测试与工具

- **新增测试用例**：`test_for_iterator.uya`、`test_iter_simple.uya`、`test_struct_method_err.uya`
- **自举对比验证**：`./compile.sh --c99 -b` 完全一致（C 版与自举版生成 C 完全一致）
- **测试用例验证**：所有测试用例在 C 版和自举版编译器中均通过

---

## 测试验证

- **C 版编译器（`--c99`）**：所有测试用例通过
- **自举版编译器（`--uya --c99`）**：所有测试用例通过
- **自举对比**：`./compile.sh --c99 -b` 完全一致（C 版与自举版生成 C 完全一致）
- **迭代器测试**：`test_for_iterator.uya`、`test_iter_simple.uya` 通过 `--c99` 与 `--uya --c99`
- **结构体方法测试**：`test_struct_method_err.uya` 通过 `--c99` 与 `--uya --c99`

---

## 文件变更统计（自 v0.2.22 以来）

**C 实现**：
- `compiler-mini/src/checker.c` — 修复 !void 处理、添加方法类型推断、添加迭代器支持
- `compiler-mini/src/codegen/c99/expr.c` — 修复 catch 表达式中 !void 处理
- `compiler-mini/src/codegen/c99/function.c` — 为 !void 返回类型添加默认返回
- `compiler-mini/src/codegen/c99/types.c` — 修复方法类型推断
- `compiler-mini/src/codegen/c99/stmt.c` — 添加 void 变量处理和迭代器代码生成
- `compiler-mini/src/codegen/c99/structs.c` — 修复 err_union_void 结构体定义位置

**自举实现（uya-src）**：
- `compiler-mini/uya-src/checker.uya` — 同步 C 版本的所有修改，修复变量移动错误
- `compiler-mini/uya-src/codegen/c99/expr.uya` — 同步 catch 表达式 !void 处理
- `compiler-mini/uya-src/codegen/c99/function.uya` — 同步 !void 返回类型处理，修复语法错误
- `compiler-mini/uya-src/codegen/c99/types.uya` — 同步方法类型推断
- `compiler-mini/uya-src/codegen/c99/stmt.uya` — 同步 void 变量处理（迭代器代码生成已存在）
- `compiler-mini/uya-src/codegen/c99/structs.uya` — 同步 err_union_void 结构体定义修复

**测试用例**：
- `compiler-mini/tests/programs/test_for_iterator.uya` — 迭代器接口测试
- `compiler-mini/tests/programs/test_iter_simple.uya` — 简单迭代器测试
- `compiler-mini/tests/programs/test_struct_method_err.uya` — 结构体方法错误处理测试

**文档**：
- `compiler-mini/todo_mini_to_full.md` — 更新迭代器支持状态、结构体方法类型推断、!void 修复说明

**统计**：12 个文件变更，约 300+ 行新增，50+ 行修改

---

## 版本对比

### v0.2.22 → v0.2.23 变更

- **新增功能**：
  - ✅ 完整实现 for 循环迭代器支持（通过接口）
  - ✅ 添加结构体方法调用的类型推断
  - ✅ 支持 void 类型变量的正确处理

- **修复**：
  - ✅ 修复错误联合类型 !void 的处理（允许 !void 作为有效类型）
  - ✅ 修复 catch 表达式中 !void 类型的处理
  - ✅ 修复 !void 返回类型函数的默认返回语句
  - ✅ 修复 err_union_void 结构体定义在 vtable 内部的问题
  - ✅ 修复变量移动错误（使用 copy_type）
  - ✅ 修复变量遮蔽错误（重命名内层变量）
  - ✅ 修复语法错误（if-then-else 改为 if-else）

- **同步**：
  - ✅ 将 C 编译器的所有修改同步到 uya-src
  - ✅ 确保 C 版与自举版编译器行为完全一致

- **非破坏性**：向后兼容，现有测试用例行为不变

---

## 技术细节

### 迭代器支持实现

**接口检查**：Checker 中检查迭代器接口，要求：
- `next(self: &Self) !void` 方法存在
- `value(self: &Self) T` 方法存在（T 为元素类型）

**代码生成**：生成 while(1) 循环，调用 next() 检查 error_id，调用 value() 获取当前值：

```c
// 生成的 C 代码示例
struct RangeIterator _uya_iter = ...;
while (1) {
    struct err_union_void _uya_next_result = uya_RangeIterator_next(&_uya_iter);
    if (_uya_next_result.error_id != 0) {
        break;  // error.IterEnd
    }
    int32_t v = uya_RangeIterator_value(&_uya_iter);
    // 循环体
}
```

### !void 错误联合类型修复

**问题**：之前对 `!void` 类型有特殊检查，导致 `!void` 被错误地转换为 `TYPE_VOID`。

**修复**：移除特殊检查，允许 `!void` 作为有效的错误联合类型：

```uya
// 修复前：!void 被转换为 TYPE_VOID
if payload.kind == TypeKind.TYPE_VOID && payload_node != null {
    result.kind = TypeKind.TYPE_VOID;
    return result;  // ❌ 错误
}

// 修复后：!void 是有效的错误联合类型
// 注意：!void 是有效的错误联合类型，payload 可以是 TYPE_VOID
// ✅ 正确
```

### err_union_void 结构体定义修复

**问题**：生成 vtable 结构体时，如果方法返回类型是 `!void`，`c99_type_to_c` 会在 vtable 内部立即生成 `struct err_union_void` 的定义，导致结构体定义被放在 vtable 内部。

**修复**：在生成 vtable 之前，预先生成所有接口方法签名中使用的错误联合类型结构体定义：

```c
// 修复前：结构体定义在 vtable 内部
struct uya_vtable_IIteratorI32 {
struct err_union_void { uint32_t error_id; };  // ❌ 错误位置
    struct err_union_void (*next)(void *self);
    ...
};

// 修复后：结构体定义在 vtable 之前
struct err_union_void { uint32_t error_id; };  // ✅ 正确位置
struct uya_vtable_IIteratorI32 {
    struct err_union_void (*next)(void *self);
    ...
};
```

### 变量移动错误修复

**问题**：在 for 循环检查中，`expr_type` 和 `var_type` 被移动后再次使用，导致编译错误。

**修复**：使用 `copy_type` 避免变量移动：

```uya
// 修复前：直接赋值导致移动
var expr_type: Type = checker_infer_type(checker, node.for_stmt_array);
var array_type: Type = expr_type;  // ❌ expr_type 被移动

// 修复后：使用 copy_type
const expr_type: Type = checker_infer_type(checker, node.for_stmt_array);
var array_type: Type = copy_type(&expr_type);  // ✅ 复制而不是移动
```

---

## 使用示例

### 迭代器接口使用

```uya
// 定义迭代器接口
interface IIteratorI32 {
    fn next(self: &Self) !void;
    fn value(self: &Self) i32;
}

// 实现迭代器
struct RangeIterator {
    start: i32,
    end: i32,
    current: i32,
}

RangeIterator {
    fn next(self: &Self) !void {
        if self.current >= self.end {
            return error.IterEnd;
        }
        self.current = self.current + 1;
    }
    
    fn value(self: &Self) i32 {
        return self.current;
    }
}

// 使用迭代器
fn main() i32 {
    const iter: RangeIterator = RangeIterator{ start: 0, end: 10, current: 0 };
    for iter |v| {
        // v 的类型是 i32（从 value() 方法返回类型推断）
        // ...
    }
    return 0;
}
```

### !void 错误联合类型使用

```uya
// !void 作为有效的错误联合类型
fn may_fail() !void {
    // 函数体没有显式返回时，自动添加：
    // return (struct err_union_void){ .error_id = 0 };
}

// catch 表达式处理 !void
fn main() i32 {
    const _: void = may_fail() catch |err| {
        // 错误处理
        return 1;
    };
    return 0;
}
```

---

## 下一步计划

根据 `todo_mini_to_full.md`：
- **原子类型**：atomic T、&atomic T
- **泛型（Generics）**：类型参数、泛型函数、泛型结构体
- **异步编程（Async）**：async/await、Future 类型
- **test 关键字**：测试单元支持
- **消灭所有警告**：消除编译器和生成的 C 代码中的所有警告

---

## 相关资源

- **语言规范**：`uya.md`（迭代器接口、错误处理、结构体方法）
- **实现文档**：`compiler-mini/spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md`
- **测试用例**：`compiler-mini/tests/programs/test_for_iterator.uya`、`test_iter_simple.uya`、`test_struct_method_err.uya`

---

**本版本完成了迭代器支持的完整实现和 C 编译器修改的同步，修复了多个编译错误和代码生成问题，确保了 C 版与自举版编译器的完全一致性。**

