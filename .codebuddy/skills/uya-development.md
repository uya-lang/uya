# Uya 开发技能文档

本文档记录 Uya 编译器开发过程中的关键经验，帮助 AI 助手更好地进行开发。

---

## 1. Uya 语法规则

### 1.1 字符串比较函数

`str_equals(s1, s2)` 函数约定：
- **返回 1**：字符串相等
- **返回 0**：字符串不相等

```uya
// 正确用法：判断相等
if str_equals(name, "expected") != 0 {
    // name == "expected"
}

// 正确用法：判断不相等
if str_equals(name, "expected") == 0 {
    // name != "expected"
}
```

**错误示例**：
```uya
// 错误！这会导致逻辑反转
if str_equals(name, "expected") == 0 {
    // 这里实际是"不相等"的情况
}
```

### 1.2 Union 变体类型限制

根据语言规范 §4.5.12：
- Union 变体**不能**包含引用类型 `&T`
- Union 变体**不能**包含切片类型 `&[T]`
- Union 变体**可以**包含 FFI 指针类型 `*T`（因为指针没有生命周期约束）

```uya
// ✅ 正确：FFI 指针类型
union ValuePtr {
    int_val: i32,
    point: *Point,      // FFI 指针可以
}

// ❌ 错误：引用类型（编译错误）
union ValueRef {
    int_val: i32,
    ref_val: &i32,      // ❌ 不能包含引用
}
```

**FFI 指针限制**：
- `*byte` 和 `*void` 只能在结构体字段中使用
- FFI 指针**不能**作为函数参数
- FFI 指针**不能**作为函数返回类型

```uya
// ✅ 正确：结构体字段中使用 FFI 指针
struct NodeData {
    name: *byte,
    next: *void,
}

// ❌ 错误：FFI 指针作为函数参数
fn process(ptr: *byte) void { ... }  // 编译错误

// ❌ 错误：FFI 指针作为返回类型
fn get_name() *byte { ... }  // 编译错误
```

### 1.3 Union match 表达式

```uya
union IntOrFloat {
    i: i32,
    f: f64
}

const v: IntOrFloat = IntOrFloat.i(42);

// match 表达式访问
match v {
    .i(x) => printf("int: %d\n", x),
    .f(x) => printf("float: %f\n", x)
}

// 结构体变体的字段访问
union Shape {
    point: Point,
    rect: Rect
}

match shape {
    .point(pt) => printf("x=%d, y=%d\n", pt.x, pt.y),  // pt.x 类型推断正确
    .rect(r) => printf("w=%d, h=%d\n", r.w, r.h),
    _ => printf("unknown\n")  // 通配符
}
```

**重要规则**：

1. **match 作为表达式**：所有分支返回类型必须完全一致
   ```uya
   // ✅ 正确：所有分支都用 as 转换（推荐，避免编译器 bug）
   const result: i32 = match node.data {
       .number(n) => n.value as i32,
       .binary(b) => b.op as i32,
       .program(p) => 0 as i32,  // 字面量也需要 as
   };

   // ✅ 正确：所有分支都返回结构体的 i32 字段
   const result: i32 = match node.data {
       .number(n) => n.value,    // i32
       .binary(b) => b.op,       // i32
       .program(p) => p.count,   // i32
   };

   // ❌ 错误：混用字段和字面量（编译器 bug，类型推断不一致）
   const result: i32 = match node.data {
       .number(n) => n.value,    // 编译器推断类型不一致
       .binary(b) => 0 as i32,   // 即使加了 as 也会失败
   };
   ```

   **解决方案**：所有分支都使用 `as 目标类型` 转换确保类型一致
   
   **已修复**（main 分支）：
   
   现在所有情况都能正确推断类型，无需强制使用 `as`：
   
   | 第一个分支 | 第二个分支 | 结果 |
   |-----------|-----------|------|
   | `x`（字段访问） | `0`（字面量） | ✅ 成功 |
   | `x`（字段访问） | `y`（字段访问） | ✅ 成功 |
   | `x as i32` | `0 as i32` | ✅ 成功 |
   
   **修复内容**：`checker_infer_type` 处理 match 表达式时，为分支变量创建符号表条目，字段访问类型推断正常工作。

### 1.7 FFI 指针限制

FFI 指针（`*byte`、`*void`、`*T`）有严格的使用限制：
- ✅ 可以在结构体字段中使用
- ❌ 不能作为函数参数
- ❌ 不能作为函数返回类型

```uya
// ✅ 正确：结构体字段
struct NodeData {
    name: *byte,
    next: *void,
}

// ❌ 错误：FFI 指针作为函数参数
fn process(ptr: *byte) void { ... }

// ❌ 错误：FFI 指针作为返回类型
fn get_name() *byte { ... }
```

**解决方案**：使用 `*void` 作为结构体字段存储指针，但函数不直接接受/返回 FFI 指针。

2. **match 作为语句**：所有分支必须返回 void
   ```uya
   // ✅ 正确：所有分支都是语句块
   match node.data {
       .number(n) => { n.value = 10; },
       .binary(b) => { b.op = 20; },
       .program(p) => {},  // 空块也返回 void
   };
   ```

3. **必须处理所有变体**：union match 必须处理所有变体
   ```uya
   // ✅ 正确：处理所有变体
   match u {
       .a(x) => ...,
       .b(x) => ...,
   }
   
   // ✅ 正确：使用 else 处理剩余变体
   match u {
       .a(x) => ...,
       else => ...,
   }
   
   // ❌ Uya 不支持 _ 作为忽略变量
   match u {
       .a(_) => ...,  // ❌ 编译错误
   }
   ```

4. **变量命名**：不能使用 `_` 忽略变量，必须使用实际变量名
   ```uya
   // ❌ 错误：Uya 不支持 _ 忽略变量
   match u {
       .number(_) => 0,  // 编译错误
   }
   
   // ✅ 正确：使用变量名
   match u {
       .number(n) => 0,  // 即使不使用 n，也要声明变量名
   }
   ```

### 1.4 类型转换语法

```uya
// 使用 as 关键字
const ptr: &byte = "hello" as *byte;
const num: i64 = value as i64;
```

### 1.5 错误处理

```uya
// 使用 ! 表示可能失败
fn may_fail() !void {
    return error("something went wrong");
}

// try 传播错误
fn caller() !void {
    try may_fail();  // 失败时立即返回
}

// catch 捕获错误
fn handle_error() void {
    may_fail() catch |err| {
        printf("error: %s\n", err);
    };
}
```

---

## 2. 编译器架构理解

### 2.1 分支开发流程（重要）

| 分支 | 角色 | 用途 |
|------|------|------|
| `main` | 编译工具 | 当前稳定版编译器，用于编译其他分支 |
| `astnode_size` | 开发目标 | 下一版本编译器，正在进行 ASTNode 内存优化 |

**使用 git worktree 创建两个工作区**：

```bash
# 在当前 uya 目录（astnode_size 分支）
git worktree add ../uya-main main

# 目录结构：
# ~/uya/          → astnode_size 分支（开发目标）
# ~/uya-main/     → main 分支（编译工具，提供稳定编译器）
```

**开发流程**：

```bash
# 1. 确保 main 工作区有可用编译器
cd ~/uya-main && make from-c

# 2. 在 astnode_size 工作区开发
cd ~/uya
# 用 main 的编译器编译 astnode_size
../uya-main/bin/uya src/main.uya -o bin/uya

# 3. 或者修改 Makefile 使用外部编译器
# UYA_COMPILER = ../uya-main/bin/uya
make uya

# 4. 验证
make b && make tests-uya
```

### 2.2 自举编译流程

```
bin/uya.c (已提交的 C99 代码)
    ↓ gcc -std=c99
bin/uya (可执行编译器)
    ↓ 编译 src/*.uya
bin/uya.c (新生成的 C99 代码)
    ↓ 自举验证 (make b)
提交新版本
```

### 2.3 关键文件

| 文件 | 说明 |
|------|------|
| `src/*.uya` | 编译器源代码（唯一维护源） |
| `bin/uya.c` | 自举 C99 代码（种子文件） |
| `tests/programs/*.uya` | 测试文件 |

### 2.3 代码生成顺序

生成 C 代码时，类型定义必须在使用之前：
- 结构体必须在引用它的类型之前定义
- Union 嵌套结构体时，需要先生成依赖的结构体

---

## 3. 开发最佳实践

### 3.1 修改代码前

```bash
# 1. 验证当前状态
make tests-uya  # 应该 348/348 通过

# 2. 理解代码上下文
# 阅读相关源码，理解数据结构和控制流
```

### 3.2 修改代码后

```bash
# 1. 构建新版本
make uya

# 2. 验证自举
make b  # 必须通过！

# 3. 运行测试
make tests-uya  # 必须全部通过

# 4. 验证通过后备份（可选但推荐）
make backup  # 只有自举和测试都通过才会执行备份
```

### 3.3 自举失败处理

如果 `make b` 失败：
1. 检查修改是否影响代码生成顺序
2. 排序相关的输出必须稳定
3. 确保 err_union 等类型按名称排序

### 3.4 不要做的事

- ❌ 不要修改 `compiler-c/` 目录（已退役）
- ❌ 不要跳过自举验证
- ❌ 不要在测试失败时提交代码
- ❌ 不要删除有意义的测试
- ❌ 不要瞎编乱造语法

---

## 4. 常见陷阱

### 4.1 str_equals 返回值

**问题**：容易混淆返回值含义

**解决**：记住 `!= 0` 表示相等

### 4.2 Union 变体不能是引用

**问题**：试图在 union 变体中使用引用类型

**解决**：使用指针或值类型

### 4.3 代码生成顺序

**问题**：union 嵌套结构体时生成顺序错误

**解决**：使用 `emit_struct_deps_for_union` 确保依赖先生成

**深入理解**（2026-02-15 修复）：

union 变体是值类型结构体时，需要**递归收集嵌套依赖**：

```uya
// 示例：Location 被 ProgramData 依赖
struct Location { line: i32, column: i32 }
struct ProgramData { location: Location, ... }
union NodeData { program: ProgramData }
```

**拓扑排序**：被依赖的结构体先输出

```
Location → ProgramData → NodeData
```

**关键函数**：`collect_value_struct_deps_from_type`
- 递归处理结构体字段的值类型依赖
- 自动过滤指针类型（指针可用前向声明）

### 4.4 自举对比差异

**问题**：修改后自举对比失败

**解决**：
- 确保类型按名称排序
- 确保字段输出顺序稳定
- 每次小改动后立即验证

---

## 5. 测试编写规范

### 5.1 测试文件结构

```uya
// tests/programs/test_feature.uya
use std.testing.*;

fn test_feature_case() !void {
    const result: i32 = my_function(input);
    try assert_eq_i32(result, expected, "description");
}

fn main() i32 {
    test_suite_begin("Feature Tests");
    run_test("feature case", test_feature_case);
    return test_suite_end();
}
```

### 5.2 测试命名

- 测试文件以 `test_` 开头
- 测试函数以 `test_` 开头
- 描述性名称，说明测试什么功能

---

## 6. 记忆要点

1. **str_equals(a, b) != 0** → 字符串相等
2. **Union 变体不能是引用** → 使用 FFI 指针 `*T` 替代
3. **FFI 指针限制** → 只能在结构体字段中使用，不能作为函数参数/返回类型
4. **match 表达式规则** → 所有分支返回类型必须一致，不能混用字面量和字段
5. **match 必须处理所有变体** → 使用 `else` 处理剩余变体
6. **Uya 不支持 `_` 忽略变量** → 必须使用实际变量名
7. **自举验证必须通过** → `make b` 是最终检验
8. **测试先行** → TDD 是最佳实践
9. **不要瞎编语法** → 参考现有代码和测试
10. **测试运行方式** → 使用 `./tests/run_programs_parallel.sh file.uya --uya`
11. **测试链接** → 需要 `tests/bridge.c` 提供 `main` 函数
12. **Arena 字符串复制** → 存储指针到 Arena 数据时，必须复制字符串内容，不能只存指针
13. **泛型方法单态化** → 需要二级类型参数查找（结构体类型参数 + 方法类型参数）

---

## 7. 泛型方法单态化实现

### 7.1 核心问题

泛型方法 `obj.method<T>()` 的单态化需要处理两层类型参数：
1. **结构体类型参数**：如 `Container<T>` 的 `T`
2. **方法类型参数**：如 `as_type<U>(self: &Self) U` 的 `U`

### 7.2 实现要点

#### 7.2.1 二级类型参数查找

在 `C99CodeGenerator` 中需要两组类型参数上下文：

```uya
// 结构体类型参数上下文（用于二级查找）
struct_type_params: &TypeParam,
struct_type_param_count: i32,
struct_type_args: & & ASTNode,
struct_type_arg_count: i32,

// 方法类型参数上下文
current_type_params: &TypeParam,
current_type_param_count: i32,
current_type_args: & & ASTNode,
current_type_arg_count: i32,
```

类型替换时先查找方法参数，再查找结构体参数。

#### 7.2.2 单态化实例名称

泛型方法的单态化实例名称格式：`StructName_TypeArg_MethodName_TypeArg`

例如 `Container<i32>.as_type<i64>()` → `Container_i32_as_type_i64`

#### 7.2.3 Self 类型处理

在 `c99_type_to_c_with_self` 函数中处理 `Self` 类型，将其替换为结构体的单态化名称。

#### 7.2.4 字符串复制陷阱

在 `register_mono_instance` 中，`generic_name` 必须复制到 Arena：

```uya
// ❌ 错误：直接存储指针（可能是局部数组）
checker.mono_instances[idx].generic_name = generic_name;

// ✅ 正确：复制字符串到 Arena
const name_copy: &byte = arena_alloc(checker.arena, (name_len + 1) as usize) as &byte;
// ... 复制内容 ...
checker.mono_instances[idx].generic_name = name_copy;
```

### 7.3 相关文件

- `src/checker.uya`：类型检查、单态化实例注册
- `src/codegen/c99/main.uya`：单态化函数生成入口
- `src/codegen/c99/function.uya`：`gen_mono_method_prototype`、`gen_mono_method_function`
- `src/codegen/c99/types.uya`：`c99_type_to_c`（二级类型参数查找）
- `src/codegen/c99/structs.uya`：`get_mono_struct_name`、`append_type_arg_suffix`
- `tests/programs/test_generic_method_call.uya`：测试用例
