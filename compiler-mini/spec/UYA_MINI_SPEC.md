# Uya Mini 语言规范

## 概述

Uya Mini 是 Uya 语言的最小子集，设计目标是能够编译自身，实现编译器的自举。本规范定义了 Uya Mini 的完整语法和语义规则，用于：

1. 实现 C99 版本的 Uya Mini 编译器（无堆分配）
2. 将 C99 编译器翻译成 Uya 版本
3. 实现编译器的自举

## 设计原则

- **最小子集**：仅包含编译自身所需的最少功能
- **简单性**：语法和语义尽可能简单，减少实现复杂度
- **自举能力**：能够编译一个简化版的编译器

## 核心特性

Uya Mini 是 Uya 语言的最小子集，包含：

- **基础类型**：`i32`（32位有符号整数）、`bool`（布尔类型）、`void`（仅用于函数返回类型）
- **结构体类型**：支持结构体定义和实例化
- **变量声明**：`const` 和 `var`
- **函数声明和调用**
- **基本控制流**：`if`、`while`
- **基本表达式**：算术运算、逻辑运算、比较运算、函数调用、结构体字段访问
- **内置函数**：`sizeof`（类型大小查询）

**不支持的特性**：
- 数组、指针、枚举、接口
- 错误处理（error、try/catch）
- defer/errdefer
- for 循环、match 表达式
- 模块系统
- 字符串插值、字符串字面量（仅支持用于打印调试）

**注意**：Uya Mini 支持 `extern` 关键字用于声明外部 C 函数（如 LLVM C API），但当前版本仅支持基础类型参数和返回值，不支持指针类型参数（`*T`）。

---

## 1. 关键字

```
struct const var fn extern return true false if else while
```

**说明**：
- `struct`：结构体声明
- `const`：不可变变量声明
- `var`：可变变量声明
- `fn`：函数声明
- `extern`：外部函数声明（用于 FFI，调用外部 C 函数，如 LLVM C API）
- `return`：函数返回
- `true`、`false`：布尔字面量
- `if`、`else`：条件语句
- `while`：循环语句

---

## 2. 类型系统

### 2.1 支持的类型

| 类型 | 大小 | 说明 |
|------|------|------|
| `i32` | 4 B | 32位有符号整数 |
| `bool` | 1 B | 布尔类型（true/false） |
| `void` | 0 B | 仅用于函数返回类型 |
| `struct Name` | 字段对齐 | 用户定义的结构体类型 |

**结构体类型**：
- 结构体使用 C 内存布局，字段顺序存储
- 对齐 = 最大字段对齐值
- 与 C 结构体 100% 兼容

### 2.2 类型规则

- **无隐式转换**：类型必须完全一致
- **显式类型注解**：所有变量和函数参数必须显式指定类型
- **类型检查**：编译期进行类型检查，类型不匹配即编译错误

---

## 3. 词法规则

### 3.1 标识符

```
identifier = [A-Za-z_][A-Za-z0-9_]*
```

- 以字母或下划线开头
- 后续字符可以是字母、数字或下划线
- 区分大小写
- 不能是关键字

### 3.2 数字字面量

```
number = [0-9]+
```

- 十进制整数
- 类型为 `i32`
- 示例：`0`、`42`、`100`

### 3.3 布尔字面量

```
boolean = 'true' | 'false'
```

- `true`：真值
- `false`：假值
- 类型为 `bool`

### 3.4 运算符

```
运算符列表：
+  -  *  /  %        // 算术运算符
== != < > <= >=     // 比较运算符
&& ||               // 逻辑运算符
!                   // 逻辑非
-                   // 一元负号（与减法运算符相同符号）
```

### 3.5 标点符号

```
( ) { } ; , =
```

- `(` `)`：函数调用、表达式分组
- `{` `}`：代码块
- `;`：语句结束
- `,`：参数列表、参数分隔
- `=`：赋值、变量初始化

### 3.6 注释

```
// 单行注释：从 // 开始到行尾
```

---

## 4. 语法规范（BNF）

### 4.1 程序结构

```
program        = { declaration }
declaration    = fn_decl | extern_decl | struct_decl | var_decl
extern_decl    = 'extern' 'fn' ID '(' [ param_list ] ')' type ';'
```

**说明**：
- 程序由零个或多个声明组成
- 声明可以是函数声明、结构体声明或变量声明（顶层常量）

### 4.2 函数声明

```
fn_decl        = 'fn' ID '(' [ param_list ] ')' type '{' statements '}'
                | 'extern' 'fn' ID '(' [ param_list ] ')' type ';'
param_list     = param { ',' param }
param          = ID ':' type
```

**说明**：
- **普通函数声明**：`fn ID(...) type { ... }`
  - 函数必须指定返回类型（可以是 `void`）
  - 参数列表可以为空
  - 函数体必须用花括号包围
  - 示例：
    ```uya
    fn add(a: i32, b: i32) i32 {
        return a + b;
    }
    
    fn print_hello() void {
        // void 函数可以省略 return
    }
    ```

- **外部函数声明**：`extern fn ID(...) type;`
  - 用于声明外部 C 函数（如 LLVM C API）
  - 以分号结尾，无函数体
  - 必须在顶层声明
  - 参数和返回值类型当前仅支持基础类型（`i32`、`bool`、`void`、结构体类型）
  - 示例：
    ```uya
    // 声明外部 C 函数（假设为简化版本，仅支持基础类型）
    extern fn llvm_context_create() void;
    extern fn llvm_module_create(name: i32) i32;
    
    fn main() i32 {
        llvm_context_create();
        return 0;
    }
    ```

### 4.3 变量声明

```
var_decl       = ('const' | 'var') ID ':' type '=' expr ';'
```

**说明**：
- `const`：不可变变量，初始化后不能修改
- `var`：可变变量，可以重新赋值
- 必须显式指定类型
- 必须初始化（提供初始值）
- 示例：
  ```uya
  const x: i32 = 10;
  var y: i32 = 20;
  y = 30;  // var 变量可以重新赋值
  ```

### 4.4 类型

```
type           = 'i32' | 'bool' | 'void'
```

**说明**：
- `i32`：32位有符号整数
- `bool`：布尔类型
- `void`：仅用于函数返回类型

### 4.6 语句

```
statement      = expr_stmt | var_decl | return_stmt | if_stmt | while_stmt | block_stmt

expr_stmt      = expr ';'
return_stmt    = 'return' [ expr ] ';'
if_stmt        = 'if' expr '{' statements '}' [ 'else' '{' statements '}' ]
while_stmt     = 'while' expr '{' statements '}'
block_stmt     = '{' statements '}'
statements     = { statement }
```

**说明**：
- 表达式语句：表达式后加分号
- return 语句：`void` 函数可以省略返回值
- if 语句：条件必须为 `bool` 类型，else 分支可选
- while 语句：条件必须为 `bool` 类型
- 代码块：用花括号包围的语句序列

### 4.7 表达式

```
expr           = assign_expr
assign_expr    = or_expr [ '=' assign_expr ]
or_expr        = and_expr { '||' and_expr }
and_expr       = eq_expr { '&&' eq_expr }
eq_expr        = rel_expr { ('==' | '!=') rel_expr }
rel_expr       = add_expr { ('<' | '>' | '<=' | '>=') add_expr }
add_expr       = mul_expr { ('+' | '-') mul_expr }
mul_expr       = unary_expr { ('*' | '/' | '%') unary_expr }
unary_expr     = ('!' | '-') unary_expr | primary_expr
primary_expr   = ID | NUM | 'true' | 'false' | struct_literal | member_access | call_expr | '(' expr ')'
struct_literal = ID '{' field_init_list '}'
field_init_list = field_init { ',' field_init }
field_init     = ID ':' expr
member_access  = primary_expr '.' ID
call_expr      = ID '(' [ arg_list ] ')'
arg_list       = expr { ',' expr }
```

**说明**：
- **结构体字面量**：`StructName{ field1: value1, field2: value2 }`
  - 所有字段必须初始化
  - 字段顺序必须与结构体定义一致
  - 示例：`Point{ x: 10, y: 20 }`

- **字段访问**：`expr.field_name`
  - 左侧表达式必须是结构体类型
  - 字段名必须是结构体中定义的字段
  - 结果类型为字段的类型
  - 示例：`p.x`、`p.y`

**说明**：
- **运算符优先级**（从高到低）：
  1. 一元运算符：`!`（逻辑非）、`-`（负号）
  2. 乘除模：`*` `/` `%`
  3. 加减：`+` `-`
  4. 比较：`<` `>` `<=` `>=`
  5. 相等性：`==` `!=`
  6. 逻辑与：`&&`
  7. 逻辑或：`||`
  8. 赋值：`=`

- **运算符说明**：
  - 算术运算符：`+` `-` `*` `/` `%`（操作数必须是 `i32`，结果类型为 `i32`）
  - 比较运算符：`==` `!=` `<` `>` `<=` `>=`（操作数类型必须相同，结果类型为 `bool`）
  - 逻辑运算符：`&&` `||`（操作数必须是 `bool`，结果类型为 `bool`）
  - 逻辑非：`!`（操作数必须是 `bool`，结果类型为 `bool`）
  - 一元负号：`-`（操作数必须是 `i32`，结果类型为 `i32`）
  - 赋值：`=`（左侧必须是 `var` 变量，类型必须匹配）

- **函数调用**：
  - 函数名必须是已声明的函数
  - 参数个数和类型必须匹配
  - 返回值类型必须匹配上下文要求

---

### 4.8 内置函数

Uya Mini 提供以下内置函数，无需导入即可使用：

#### `sizeof(T)` - 类型大小查询

**语法**：`sizeof(Type)` 或 `sizeof(expr)`

**功能**：返回类型或表达式的字节大小（编译期常量）

**返回值**：`i32`（字节数）

**说明**：
- `sizeof(Type)` - 获取类型的大小（编译时计算）
- `sizeof(expr)` - 获取表达式结果类型的大小（编译时计算）
- `sizeof(array)` - 获取整个数组的总大小（字节数）
- `sizeof(&T)` - 获取指针类型的大小（通常 8 字节）
- 必须是编译时常量，可在任何需要编译期常量的位置使用
- 编译器在编译期直接折叠为常数，不生成函数调用

**示例**：
```uya
struct Node {
    value: i32;
}

const node_size: i32 = sizeof(Node);        // 类型大小
const ptr_size: i32 = sizeof(&Node);        // 指针类型大小

var node: Node = Node{ value: 10 };
const node_size2: i32 = sizeof(node);       // 表达式大小（与 sizeof(Node) 相同）

// 用于数组大小计算
const array_size: i32 = sizeof(&Node) * 10; // 10 个指针的大小
```

**设计说明**：
- Uya Mini 作为最小子集，不依赖模块系统
- 因此 `sizeof` 作为内置函数而非标准库函数（完整 Uya 中 `sizeof` 是标准库函数，需要 `use std.mem;`）
- 这简化了使用，无需导入即可使用

---

## 5. 语义规则

### 5.1 作用域规则

- **全局作用域**：顶层声明（函数、常量）在全局作用域
- **局部作用域**：函数参数和函数体内的变量在函数作用域
- **块作用域**：代码块内声明的变量在块作用域
- **作用域嵌套**：内层作用域可以访问外层作用域，但禁止变量遮蔽（内层作用域不能声明与外层作用域同名的变量）

### 5.2 类型检查规则

1. **赋值类型匹配**：
   - `var x: i32 = 10;` ✅
   - `var x: i32 = true;` ❌ 类型不匹配

2. **函数调用类型匹配**：
   - 参数个数必须匹配
   - 参数类型必须匹配
   - 返回值类型必须匹配使用上下文

3. **运算符类型要求**：
   - 算术运算符：操作数必须是 `i32`
   - 比较运算符：操作数类型必须相同（`i32`、`bool` 或相同结构体类型）
   - 逻辑运算符：操作数必须是 `bool`

4. **if/while 条件类型**：
   - 条件表达式必须是 `bool` 类型

5. **结构体类型规则**：
   - 结构体比较：仅支持 `==` 和 `!=`，逐字段比较
   - 结构体赋值：按值复制（所有字段复制）
   - 字段访问：只能访问已定义的字段

### 5.3 变量规则

- **const 变量**：初始化后不能重新赋值
- **var 变量**：可以重新赋值，但类型必须匹配
- **未初始化**：所有变量必须初始化
- **结构体变量**：按值存储，赋值时复制所有字段

### 5.4 函数规则

- **main 函数**：程序必须有一个 `main` 函数，签名必须是 `fn main() i32`
- **返回值**：非 `void` 函数必须返回对应类型的值
- **void 函数**：可以省略 `return` 语句，或使用 `return;`

---

## 6. 完整示例

示例代码已移至独立文件，便于查看和测试：

- [简单函数示例](examples/simple_function.uya) - 基本的函数定义和调用
- [控制流示例](examples/control_flow.uya) - if/while 语句的使用
- [布尔逻辑示例](examples/boolean_logic.uya) - 布尔类型和逻辑运算

---

## 7. 编译器实现要求

### 7.1 编译器阶段

Uya Mini 编译器应包含以下阶段：

1. **词法分析（Lexer）**：
   - 将源代码转换为 Token 流
   - 识别关键字、标识符、数字、运算符、标点符号

2. **语法分析（Parser）**：
   - 使用递归下降解析构建 AST
   - 验证语法正确性

3. **类型检查（Checker）**：
   - 验证类型安全
   - 检查变量使用
   - 检查函数调用

4. **代码生成（Codegen）**：
   - 使用 LLVM C API 直接从 AST 生成 LLVM IR
   - 使用 LLVM 优化和代码生成后端生成目标平台二进制
   - 输出可执行文件（或目标文件）

### 7.2 内存管理约束

**无堆分配要求**：
- 编译器自身代码不能使用 `malloc`、`calloc`、`realloc`、`free`
- 使用 Arena 分配器：大型静态缓冲区 + bump pointer
- 所有数据结构（AST 节点、Token、字符串）从 Arena 分配
- 固定大小限制：AST 节点池、Token 池等使用固定大小数组
- **注意**：LLVM API 内部会使用堆分配，但编译器自身代码不使用堆分配

### 7.3 LLVM C API 代码生成

编译器使用 LLVM C API 生成二进制代码：

**主要 LLVM API 使用**：
- `LLVMContextRef`：LLVM 上下文
- `LLVMModuleRef`：LLVM 模块
- `LLVMBuilderRef`：IR 构建器
- `LLVMTypeRef`：类型定义
- `LLVMValueRef`：值（函数、变量、常量等）
- `LLVMPassManagerRef`：优化管理器

**类型映射**：
- `i32` → `LLVMInt32Type()`
- `bool` → `LLVMInt1Type()` 或 `LLVMInt8Type()`（使用 1 位更精确）
- `void` → `LLVMVoidType()`
- `struct Type` → `LLVMStructType()`（结构体类型）

**代码生成流程**：
1. 创建 LLVM 模块和上下文
2. 为每个结构体定义创建 LLVM 结构体类型
3. 为每个函数创建 LLVM 函数声明/定义
4. 生成函数体：遍历 AST，生成对应的 LLVM IR 指令
5. 运行优化器（可选）
6. 生成目标代码：使用 `LLVMTargetMachineEmitToFile()` 或类似 API
7. 清理 LLVM 资源

**示例**：参见 [LLVM IR 代码生成示例](examples/llvm_ir_example.c)

**结构体处理**：
- 结构体类型使用 `LLVMStructType()` 定义
- 结构体字面量：使用 `LLVMConstStruct()` 或分别创建字段常量
- 字段访问：使用 `LLVMBuildExtractValue()` 获取字段值
- 字段赋值：使用 `LLVMBuildInsertValue()` 设置字段值
- 结构体比较：生成逐字段比较的代码

**依赖**：
- 需要链接 LLVM 库（如 `-llvm`）
- 包含头文件：`<llvm-c/Core.h>`, `<llvm-c/Target.h>`, `<llvm-c/TargetMachine.h>` 等

---

## 8. 自举能力说明

Uya Mini 设计为能够编译一个简化版的编译器，因此必须支持：

1. **数据结构定义**：通过固定大小数组和索引实现
2. **字符串处理**：字符数组和索引操作
3. **控制流**：if/while 实现解析逻辑
4. **函数调用**：模块化编译器实现
5. **基本算法**：哈希表（开放寻址）、递归下降解析等

虽然 Uya Mini 不支持结构体和数组，但在实现编译器时，可以通过 C99 的固定大小数组和索引来模拟这些结构。

---

## 9. 与完整 Uya 的区别

| 特性 | Uya Mini | 完整 Uya |
|------|----------|----------|
| 类型系统 | i32, bool, void, struct | 完整的类型系统（结构体、数组、指针、枚举、接口等） |
| 结构体 | 支持（无方法、无接口实现） | 完整支持（方法、接口实现、drop） |
| 控制流 | if, while | if, while, for, match, break, continue |
| 错误处理 | 不支持 | error, try, catch, !T |
| 内存管理 | 不支持 | defer, errdefer, RAII |
| 模块系统 | 不支持 | 完整的模块系统 |
| 字符串 | 不支持（仅用于调试） | 完整的字符串支持 |
| 类型推断 | 不支持 | 不支持（显式类型） |
| `sizeof` | 内置函数（无需导入） | 标准库函数（需导入 `std.mem`） |
| 代码生成 | LLVM C API → 二进制 | C99 代码 → C 编译器 |

---

## 版本信息

- **版本**：0.1.0
- **创建日期**：2026-01-09
- **目的**：Uya Mini 编译器自举实现

---

## 参考文档

- [uya.md](../uya.md) - Uya 语言完整规范
- [uya_ai_prompt.md](../uya_ai_prompt.md) - Uya 语言 AI 提示词
- [grammar_formal.md](../grammar_formal.md) - Uya 语言正式 BNF 语法
- [compiler/architecture.md](../compiler/architecture.md) - Uya 编译器架构设计

