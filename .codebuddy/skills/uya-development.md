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
- Union 变体**可以**包含指针类型（因为指针没有生命周期约束）

```uya
// ✅ 正确：指针类型
union ValuePtr {
    int_val: i32,
    point: &Point,      // 指针可以
}

// ❌ 错误：引用类型（编译错误）
union ValueRef {
    int_val: i32,
    point: &Point,      // 这里 Point 本身是结构体类型，不是引用
    ref_val: &i32,      // ❌ 不能包含引用
}
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

### 2.1 自举编译流程

```
bin/uya.c (已提交的 C99 代码)
    ↓ gcc -std=c99
bin/uya (可执行编译器)
    ↓ 编译 src/*.uya
bin/uya.c (新生成的 C99 代码)
    ↓ 自举验证 (make b)
提交新版本
```

### 2.2 关键文件

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
14. **整数溢出检测** → 在 C 语言中，有符号整数溢出是未定义行为，不能依赖溢出后的结果判断；必须使用安全方法（如 `left > I32_MAX - right`）
15. **I32_MIN 定义** → 使用 `-2147483647 - 1` 而非 `-2147483648`，后者会被解析为一元负运算导致溢出
16. **枚举值引用问题** → 某些情况下 Uya 编译器会错误地生成 `TokenType.TOKEN_XXX` 而不是 `TOKEN_XXX`，导致 C 编译错误。临时解决方案：使用数字常量代替枚举值
17. **@await 验证** → `@await` 只能在 `@async_fn` 函数中使用，通过 `checker.current_function_decl.fn_decl_is_async` 判断
18. **错误测试命名** → 测试文件以 `error_` 前缀命名，测试系统自动识别为"预期编译失败"

---

## 7. 异步编程实现

### 7.1 当前状态

| 模块 | 状态 | 说明 |
|------|------|------|
| Lexer | ✅ | `@async_fn`、`@await` 已识别 |
| Parser | ✅ | AST 节点已生成 |
| Checker | ✅ | `@await` 上下文验证已实现 |
| Codegen | ⚠️ | 暂时直接生成操作数代码，CPS 变换待实现 |

### 7.2 @await 验证逻辑

在 `checker_infer_type` 中检查：

```uya
// 1. 检查是否在函数体内
if checker.in_function == 0 || checker.current_function_decl == null {
    checker_report_error(checker, expr, "@await 只能在函数体内使用");
    return TYPE_VOID;
}

// 2. 检查当前函数是否是 @async_fn
if checker.current_function_decl.fn_decl_is_async == 0 {
    checker_report_error(checker, expr, "@await 只能在 @async_fn 函数中使用");
    return TYPE_VOID;
}
```

### 7.3 测试用例

- 正常测试：`test_async_await_validation.uya` - 验证语法正确
- 错误测试：`error_await_outside_async.uya` - 验证错误检测

### 7.4 待实现

1. **类型验证**：验证 `@await` 操作数是 `!Future<T>` 类型
2. **CPS 变换**：代码生成阶段实现状态机
3. **标准库**：`std.async` 模块（`Future<T>`, `Poll<T>`, `Waker`）

---

## 8. 泛型方法单态化实现

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

---

## 8. 内存安全证明系统

### 8.1 区间算术（Interval Arithmetic）

用于处理非线性表达式的边界检查：

```uya
// 区间结构
struct Interval {
    min: i32,        // 最小值
    max: i32,        // 最大值
    is_valid: i32,   // 是否有效
}

// 区间运算函数
fn interval_add(a: Interval, b: Interval) Interval;
fn interval_sub(a: Interval, b: Interval) Interval;
fn interval_mul(a: Interval, b: Interval) Interval;
fn interval_div(a: Interval, b: Interval) Interval;
fn interval_shl(a: Interval, b: Interval) Interval;  // 左移
fn interval_shr(a: Interval, b: Interval) Interval;  // 右移
```

**应用场景**：当索引表达式包含乘法、除法、移位运算时，使用区间分析估计表达式的值范围，判断是否在数组边界内。

### 8.2 无符号类型约束

无符号类型（`u8`, `u16`, `u32`, `u64`, `usize`, `byte`）的变量自动获得 `>= 0` 约束：

```uya
// 自动约束
var i: usize = get_value();
// i 自动满足 i >= 0

// 类型转换表达式支持
var base: i32 = 3;
arr[(base + 3) as usize] = 42;  // 可以正确处理类型转换
```

### 8.3 Token 类型名称

在 `checker.uya` 中引用 Token 类型时，使用正确的枚举名称：

- `TOKEN_PLUS`（加法 `+`）
- `TOKEN_MINUS`（减法 `-`）
- `TOKEN_ASTERISK`（乘法 `*`，不是 `TOKEN_STAR`）
- `TOKEN_SLASH`（除法 `/`）
- `TOKEN_LSHIFT`（左移 `<<`，不是 `TOKEN_SHL`）
- `TOKEN_RSHIFT`（右移 `>>`，不是 `TOKEN_SHR`）

### 8.4 边界检查流程

```
1. 常量索引 → 直接检查是否越界
2. 变量索引（线性表达式）→ 使用约束系统验证
3. 变量索引（非线性表达式）→ 使用区间分析验证
4. 无法验证 → 报告编译错误
```

### 8.5 相关文件

- `src/checker.uya`：
  - `Interval` 结构和区间运算函数
  - `extract_linear_expr`：提取线性表达式（支持类型转换）
  - `eval_expr_interval`：表达式区间求值
  - `verify_expr_bounds_interval`：区间边界验证
  - `is_unsigned_type`：判断无符号类型
- `tests/programs/test_usize_constraints.uya`：usize 约束测试
- `tests/programs/test_nonlinear_bounds.uya`：非线性表达式测试

### 8.6 const 变量在安全证明中的识别（2026-02-19 修复）

**问题**：编译器无法识别 `const limit = C99_MAX_MONO_INSTANCES` 与字面量是同一个值

**根本原因**：
1. `extract_linear_expr` 不识别 `const` 变量
2. `checker_eval_const_expr` 只检查全局 `const` 变量，不检查局部 `const` 变量

**修复**：
```uya
// extract_linear_expr: 识别 const 变量
if expr.type == ASTNodeType.AST_IDENTIFIER {
    const symbol: &Symbol = symbol_table_lookup(checker, expr.identifier_name);
    if symbol != null && symbol.is_const != 0 {
        const const_val: i32 = checker_eval_const_expr(checker, expr);
        if const_val != -1 {
            // 作为常量处理
            result.var_name = null;
            result.offset = const_val;
            result.is_valid = 1;
            return result;
        }
    }
    // 否则作为变量处理
    ...
}

// checker_eval_const_expr: 检查符号表中的局部 const 变量
const symbol: &Symbol = symbol_table_lookup(checker, expr.identifier_name);
if symbol != null && symbol.is_const != 0 && symbol.decl_node != null {
    const decl: &ASTNode = symbol.decl_node;
    if decl.type == ASTNodeType.AST_VAR_DECL && decl.var_decl_init != null {
        return checker_eval_const_expr(checker, decl.var_decl_init);
    }
}
```

**效果**：`while i < LIMIT`（其中 `const LIMIT = 10`）现在可以正确识别约束 `i < 10`

### 8.7 安全证明错误提示改进（2026-02-19 修复）

**问题**：安全证明错误只显示 "数组索引安全证明失败"，没有给出具体修复指导

**改进后的错误提示**：
```
/tmp/test.uya:(5:9): 错误: 数组索引安全证明失败
  变量: i, 数组大小: 10
  已知下界: i >= 0
  缺少上界: 需要 i < 10
  建议: 在数组访问前添加边界检查
    if i >= 0 && i < 10 { arr[i] ... }
```

**实现要点**：
- 在 `checker_report_error_ex` 中分析并显示当前约束状态
- 区分"已知约束"和"缺少约束"
- 提供具体的修复代码示例

### 8.8 数组边界与循环上限匹配（2026-02-19 修复）

**问题**：`checker.mono_instances` 数组大小是 512，但循环使用 `C99_MAX_MONO_INSTANCES = 1024`

**教训**：
- 循环上限必须使用被访问数组的实际大小
- 字面量常量比命名常量更容易被安全证明系统识别
- 两个模块中的同名常量可能有不同的值

**正确写法**：
```uya
// checker.mono_instances 大小是 512
while i < 512 {
    if i < checker.mono_instance_count {
        // 访问 checker.mono_instances[i] 是安全的
    }
    i = i + 1;
}
```
