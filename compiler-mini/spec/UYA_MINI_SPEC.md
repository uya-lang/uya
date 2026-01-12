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

- **基础类型**：`i32`（32位有符号整数）、`bool`（布尔类型）、`byte`（无符号字节）、`void`（仅用于函数返回类型）
- **数组类型**：固定大小数组（`[T: N]`），N 为编译期常量
- **指针类型**：`&T`（普通指针）和 `*T`（FFI 指针）
- **结构体类型**：支持结构体定义和实例化
- **变量声明**：`const` 和 `var`
- **函数声明和调用**
- **外部函数调用**：支持 `extern` 关键字，允许 `*T` 作为 FFI 指针参数和返回值
- **基本控制流**：`if`、`while`、`for`（数组遍历）、`break`、`continue`
- **基本表达式**：算术运算、逻辑运算、比较运算、函数调用、结构体字段访问、数组访问
- **内置函数**：`sizeof`（类型大小查询）

**不支持的特性**：
- 枚举、接口
- 错误处理（error、try/catch）
- defer/errdefer
- match 表达式
- 模块系统
- 字符串插值（不支持字符串插值语法）
- 整数范围 for 循环（仅支持数组遍历）

**字符串字面量支持**（有限支持）：
- 字符串字面量类型：`*byte`（FFI 指针类型）
- 仅可作为 `extern` 函数参数使用（不能赋值给变量）
- 编译器在只读数据段中存储字符串字面量
- 不提供内置字符串操作，需要通过 `extern` 调用 C 函数（如 `strcmp`）

**注意**：Uya Mini 支持 `extern` 关键字用于声明外部 C 函数（如 LLVM C API），支持基础类型参数和返回值，以及 FFI 指针类型参数（`*T`）。`*T` 类型仅用于 extern 函数声明/调用，不能用于普通变量声明。

---

## 1. 关键字

```
struct const var fn extern return true false if else while for break continue null
```

**说明**：
- `struct`：结构体声明
- `const`：不可变变量声明
- `var`：可变变量声明
- `fn`：函数声明
- `extern`：外部函数声明（用于 FFI，调用外部 C 函数，如 LLVM C API）
- `return`：函数返回
- `true`、`false`：布尔字面量
- `null`：空指针字面量
- `if`、`else`：条件语句
- `while`：循环语句
- `for`：循环语句（数组遍历）
- `break`：跳出循环
- `continue`：跳过当前循环迭代，继续下一次

---

## 2. 类型系统

### 2.1 支持的类型

| 类型 | 大小 | 说明 |
|------|------|------|
| `i32` | 4 B | 32位有符号整数 |
| `bool` | 1 B | 布尔类型（true/false） |
| `byte` | 1 B | 无符号字节，对齐 1 B，用于字节数组 |
| `void` | 0 B | 仅用于函数返回类型 |
| `struct Name` | 字段大小之和（含对齐填充） | 用户定义的结构体类型 |
| `[T: N]` | `sizeof(T) * N` | 固定大小数组类型，其中 T 为元素类型，N 为编译期常量 |
| `&T` | 8 B | 普通指针类型，用于普通变量和函数参数 |
| `*T` | 8 B | FFI 指针类型，仅用于 extern 函数声明/调用 |

**类型说明**：
- **结构体类型**：
  - 结构体使用 C 内存布局，字段顺序存储
  - 对齐 = 最大字段对齐值
  - 与 C 结构体 100% 兼容
- **数组类型** (`[T: N]`)：
  - N 必须是编译期常量（字面量或 const 变量）
  - 对齐 = 元素类型 T 的对齐值
  - 多维数组：`[[T: N]: M]`
- **指针类型**：
  - `&T`：普通指针类型，用于普通变量和函数参数，可通过 `&expr` 获取地址
  - `*T`：FFI 指针类型，仅用于 `extern` 函数声明/调用，不能用于普通变量声明
  - 指针大小：64位平台为 8 字节，32位平台为 4 字节

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

### 3.4 字符串字面量

```
string_literal = '"' { character } '"'
```

- 字符串字面量，用双引号包围
- 类型为 `*byte`（FFI 指针类型）
- 仅可作为 `extern` 函数参数使用（不能赋值给变量、不能用于普通表达式）
- 编译器在只读数据段中存储字符串字面量（null 终止）
- 示例：`"hello"`、`"i32"`、`"filename.txt"`
- 注意：Uya Mini 不提供内置字符串操作，需要通过 `extern` 调用 C 函数（如 `strcmp`）

### 3.5 运算符

```
运算符列表：
+  -  *  /  %        // 算术运算符
== != < > <= >=     // 比较运算符
&& ||               // 逻辑运算符
!                   // 逻辑非
-                   // 一元负号（与减法运算符相同符号）
&                   // 取地址运算符（用于获取变量的地址）
*                   // 解引用运算符（用于获取指针指向的值）
```

### 3.6 标点符号

```
( ) { } ; , = |
```

- `(` `)`：函数调用、表达式分组
- `{` `}`：代码块
- `;`：语句结束
- `,`：参数列表、参数分隔
- `=`：赋值、变量初始化
- `|`：for 循环变量绑定分隔符

### 3.7 注释

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
struct_decl    = 'struct' ID '{' field_list '}'
field_list     = field { ',' field }
field          = ID ':' type ';'
```

**说明**：
- 程序由零个或多个声明组成
- 声明可以是函数声明、结构体声明或变量声明（顶层常量）
- 结构体声明：`struct ID { field_list }`，字段列表用逗号分隔，每个字段以分号结尾

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
  - 参数和返回值类型支持：
    - 基础类型：`i32`、`bool`、`byte`、`void`、结构体类型
    - FFI 指针类型：`*T`（如 `*byte`、`*void`、`*i32` 等）
  - 注意：`*T` 类型仅用于 extern 函数声明/调用，不能用于普通变量声明
  - 示例：
    ```uya
    // 声明外部 C 函数
    extern fn llvm_context_create() void;
    extern fn llvm_module_create(name: i32) i32;
    
    // 支持 FFI 指针类型参数
    extern fn fopen(filename: *byte, mode: *byte) *FILE;
    extern fn strcmp(s1: *byte, s2: *byte) i32;
    
    fn main() i32 {
        llvm_context_create();
        // 字符串字面量可以作为 extern 函数参数
        const result: i32 = strcmp("i32", "i32");  // 字符串字面量类型为 *byte
        return result;
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
type           = 'i32' | 'bool' | 'byte' | 'void' | array_type | pointer_type | ffi_pointer_type | struct_type
array_type     = '[' type ':' NUM ']'
pointer_type   = '&' type
ffi_pointer_type = '*' type
struct_type    = 'struct' ID
```

**说明**：
- `i32`：32位有符号整数
- `bool`：布尔类型
- `byte`：无符号字节（1 字节）
- `void`：仅用于函数返回类型
- `&T`：普通指针类型，用于普通变量和函数参数
- `*T`：FFI 指针类型，仅用于 extern 函数声明/调用
- `[T: N]`：固定大小数组类型，N 为编译期常量
- `struct Name`：结构体类型

### 4.5 语句

```
statement      = expr_stmt | var_decl | return_stmt | if_stmt | while_stmt | for_stmt | break_stmt | continue_stmt | block_stmt

expr_stmt      = expr ';'
return_stmt    = 'return' [ expr ] ';'
if_stmt        = 'if' expr '{' statements '}' [ 'else' '{' statements '}' ]
while_stmt     = 'while' expr '{' statements '}'
for_stmt       = 'for' expr '|' ID '|' '{' statements '}'           # 值迭代（只读）
               | 'for' expr '|' '&' ID '|' '{' statements '}'        # 引用迭代（可修改）
break_stmt     = 'break' ';'
continue_stmt  = 'continue' ';'
block_stmt     = '{' statements '}'
statements     = { statement }
```

**说明**：
- 表达式语句：表达式后加分号
- return 语句：`void` 函数可以省略返回值
- if 语句：条件必须为 `bool` 类型，else 分支可选
- while 语句：条件必须为 `bool` 类型
- for 语句：
  - `for expr | ID | { statements }`：值迭代（只读），遍历 expr 的元素，将每个元素赋值给 ID
  - `for expr | &ID | { statements }`：引用迭代（可修改），遍历 expr 的元素，将每个元素的引用赋值给 ID
  - expr 必须是数组类型（`[T: N]`）
  - 在引用迭代形式中，循环体内通过 `*ID` 访问元素值，通过 `*ID = value` 修改元素
  - 只有可变数组（`var arr`）才能使用引用迭代形式
- break 语句：跳出当前循环（while 或 for）
- continue 语句：跳过当前循环迭代，继续下一次迭代
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
unary_expr     = ('!' | '-' | '&' | '*') unary_expr | primary_expr
primary_expr   = ID | NUM | 'true' | 'false' | 'null' | STRING | struct_literal | array_literal | member_access | array_access | call_expr | sizeof_expr | '(' expr ')'
sizeof_expr    = 'sizeof' '(' (type | expr) ')'
struct_literal = ID '{' field_init_list '}'
array_literal  = '[' expr_list ']'
expr_list      = [ expr { ',' expr } ]
field_init_list = field_init { ',' field_init }
field_init     = ID ':' expr
member_access  = primary_expr '.' ID
array_access   = primary_expr '[' expr ']'
call_expr      = ID '(' [ arg_list ] ')'
arg_list       = expr { ',' expr }
```

**说明**：
- **结构体字面量**：`StructName{ field1: value1, field2: value2 }`
  - 所有字段必须初始化
  - 字段顺序必须与结构体定义一致
  - 示例：`Point{ x: 10, y: 20 }`

- **数组字面量**：`[expr1, expr2, ...]`
  - 所有元素类型必须相同
  - 元素类型从第一个元素推断，数组大小从元素个数推断
  - 元素个数必须与数组大小匹配（如果显式指定了数组类型）
  - 示例：`[1, 2, 3]`（类型推断为 `[i32: 3]`），`var arr: [i32: 3] = [1, 2, 3];`（类型显式指定）

- **字段访问**：`expr.field_name`
  - 左侧表达式必须是结构体类型或指向结构体的指针类型（`&StructName`）
  - 字段名必须是结构体中定义的字段
  - 结果类型为字段的类型
  - 示例：`p.x`、`p.y`、`ptr.field`（如果 ptr 是指向结构体的指针）

- **数组访问**：`arr[index]`
  - 左侧表达式必须是数组类型或指针类型
  - index 必须是 `i32` 类型
  - 结果类型为数组元素类型
  - 示例：`arr[0]`、`arr[i]`

- **null 字面量**：`null`
  - 类型为指针类型（`&T` 或 `*T`），从上下文推断或显式指定
  - 用于指针初始化和比较
  - 示例：`var p: &Node = null;`（类型从变量声明推断）

- **字符串字面量**：`"..."`
  - 类型为 `*byte`（FFI 指针类型）
  - 仅可作为 `extern` 函数参数使用（不能赋值给变量、不能用于普通表达式）
  - 编译器在只读数据段中存储字符串字面量（null 终止）
  - 不提供内置字符串操作，需要通过 `extern` 调用 C 函数
  - 示例：
    ```uya
    extern fn strcmp(s1: *byte, s2: *byte) i32;
    extern fn fopen(filename: *byte, mode: *byte) *FILE;
    
    fn compare_type(s: *byte) bool {
        return strcmp(s, "i32") == 0;  // 字符串字面量 "i32" 类型为 *byte
    }
    ```

- **指针解引用**：`*expr`
  - 操作数必须是指针类型 `&T`
  - 返回类型 `T`（指针指向的值类型）
  - 示例：`*ptr`、`*item`（在 for 循环引用迭代中）
  - 注意：`ptr.field` 是语法糖，等价于 `(*ptr).field`（当 ptr 是指向结构体的指针时）

- **运算符优先级**（从高到低）：
  1. 一元运算符：`!`（逻辑非）、`-`（负号）、`&`（取地址）、`*`（解引用）
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
  - 取地址运算符：`&expr`（操作数必须是左值，返回指向操作数的指针类型 `&T`）
  - 解引用运算符：`*expr`（操作数必须是指针类型 `&T`，返回类型 `T`）
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
- `sizeof([T: N])` - 获取数组类型的总大小（`sizeof(T) * N`，字节数）
- `sizeof(array)` - 获取数组表达式的总大小（字节数）
- `sizeof(&T)` - 获取指针类型的大小（64位平台为 8 字节，32位平台为 4 字节）
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

// 数组类型大小
const array_type_size: i32 = sizeof([i32: 10]);  // 10个i32的数组大小（40字节）

// 数组表达式大小
var nums: [i32: 5] = [1, 2, 3, 4, 5];
const nums_size: i32 = sizeof(nums);        // 20字节（5个i32）

// 用于数组大小计算
const ptr_array_size: i32 = sizeof(&Node) * 10; // 10 个指针的大小
```

**设计说明**：
- Uya Mini 作为最小子集，不依赖模块系统
- 因此 `sizeof` 作为内置函数而非标准库函数（完整 Uya 中 `sizeof` 是标准库函数，需要 `use std.mem;`）
- 这简化了使用，无需导入即可使用

---

### 4.9 for 循环示例

**值迭代（只读）**：
```uya
const arr: [i32: 5] = [1, 2, 3, 4, 5];
var sum: i32 = 0;

for arr |item| {
    sum = sum + item;  // item 是元素值，只读
}
// sum = 15
```

**引用迭代（可修改）**：
```uya
var arr: [i32: 5] = [1, 2, 3, 4, 5];

for arr |&item| {
    *item = *item * 2;  // 修改每个元素，乘以2
}
// arr = [2, 4, 6, 8, 10]
```

**使用 break 和 continue**：
```uya
var arr: [i32: 10] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
var sum: i32 = 0;

for arr |item| {
    if item == 5 {
        continue;  // 跳过 5
    }
    if item == 8 {
        break;     // 遇到 8 时跳出循环
    }
    sum = sum + item;
}
// sum = 1 + 2 + 3 + 4 + 6 + 7 = 23
```

**说明**：
- `for arr |item| { }`：值迭代形式，`item` 是元素值的副本，只读
- `for arr |&item| { }`：引用迭代形式，`item` 是指向元素的指针（`&T`），可修改
- 在引用迭代形式中，通过 `*item` 访问元素值，通过 `*item = value` 修改元素
- 只有可变数组（`var arr`）才能使用引用迭代形式
- `break` 和 `continue` 只能在循环体内使用
- `break` 跳出最近的循环（while 或 for）
- `continue` 跳过当前迭代，继续下一次迭代

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
   - 取地址运算符：`&expr`，返回指向 expr 的指针类型 `&T`

4. **if/while/for 条件类型**：
   - if/while 条件表达式必须是 `bool` 类型
   - for 循环的可迭代对象必须是数组类型（`[T: N]`）

5. **for 循环类型规则**：
   - 值迭代形式：`for arr |item| { }`，`item` 的类型为数组元素类型 `T`
   - 引用迭代形式：`for arr |&item| { }`，`item` 的类型为 `&T`（指向元素的指针）
   - 引用迭代形式只能用于可变数组（`var arr`）

6. **break/continue 语句规则**：
   - `break` 和 `continue` 只能在循环体内使用（while 或 for）
   - `break` 跳出最近的循环
   - `continue` 跳过当前迭代，继续下一次迭代

7. **结构体类型规则**：
   - 结构体比较：仅支持 `==` 和 `!=`，逐字段比较
   - 结构体赋值：按值复制（所有字段复制）
   - 字段访问：只能访问已定义的字段

8. **数组类型规则**：
   - 数组大小必须是编译期常量
   - 数组访问：索引必须是 `i32` 类型
   - 数组赋值：按值复制（复制所有元素）

9. **指针类型规则**：
   - `&T` 类型可用于普通变量和函数参数
   - `*T` 类型仅用于 `extern` 函数声明/调用
   - 指针比较：支持 `==` 和 `!=`，可以与 `null` 比较
   - 指针解引用：
     - 使用 `*expr` 解引用指针（通用方式）
     - 使用 `ptr.field` 访问字段（语法糖，等价于 `(*ptr).field`，当 ptr 是指向结构体的指针时）
     - 示例：`*ptr`、`ptr.x`（如果 ptr 是 `&Point` 类型）

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

Uya Mini 支持结构体和数组类型，这些特性使得编译器实现更加自然和高效。

---

## 9. 与完整 Uya 的区别

| 特性 | Uya Mini | 完整 Uya |
|------|----------|----------|
| 类型系统 | i32, bool, byte, void, struct, [T: N], &T, *T | 完整的类型系统（结构体、数组、指针、枚举、接口等） |
| 结构体 | 支持（无方法、无接口实现） | 完整支持（方法、接口实现、drop） |
| 数组 | 支持固定大小数组 `[T: N]` | 支持固定大小数组和切片 |
| 指针 | 支持 `&T`（普通指针）和 `*T`（FFI指针） | 完整支持（包括 lifetime） |
| 控制流 | if, while, for（数组遍历）, break, continue | if, while, for（数组遍历、整数范围）, match, break, continue |
| 错误处理 | 不支持 | error, try, catch, !T |
| 内存管理 | 不支持 | defer, errdefer, RAII |
| 模块系统 | 不支持 | 完整的模块系统 |
| 字符串 | 字符串字面量（类型为 `*byte`，仅用于 FFI 函数参数） | 完整的字符串支持 |
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

