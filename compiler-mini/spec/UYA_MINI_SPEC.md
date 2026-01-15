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

- **基础类型**：`i32`（32位有符号整数）、`usize`（平台相关的无符号大小类型）、`bool`（布尔类型）、`byte`（无符号字节）、`void`（仅用于函数返回类型）
- **枚举类型**：支持枚举定义、枚举值访问、显式赋值、自动递增
- **数组类型**：固定大小数组（`[T: N]`），N 为编译期常量
- **指针类型**：`&T`（普通指针）和 `*T`（FFI 指针）
- **结构体类型**：支持结构体定义和实例化
- **变量声明**：`const` 和 `var`
- **函数声明和调用**
- **外部函数调用**：支持 `extern` 关键字，允许 `*T` 作为 FFI 指针参数和返回值
- **基本控制流**：`if`、`while`、`for`（数组遍历）、`break`、`continue`
- **基本表达式**：算术运算、逻辑运算、比较运算、函数调用、结构体字段访问、数组访问、类型转换
- **内置函数**：`sizeof`（类型大小查询）、`len`（数组长度查询）、`alignof`（类型对齐查询）

**不支持的特性**：
- 接口
- 错误处理（error、try/catch）
- defer/errdefer
- match 表达式
- 模块系统
- 字符串插值（不支持字符串插值语法）
- 整数范围 for 循环（仅支持数组遍历）

**字符串字面量支持**（✅ 已实现）：
- 字符串字面量类型：`*byte`（FFI 指针类型）
- 仅可作为 `extern` 函数参数使用（不能赋值给变量）
- 编译器在只读数据段中存储字符串字面量（创建全局常量变量）
- 不提供内置字符串操作，需要通过 `extern` 调用 C 函数（如 `strcmp`）

**注意**：Uya Mini 支持 `extern` 关键字用于声明外部 C 函数（如 LLVM C API），支持基础类型参数和返回值，以及 FFI 指针类型参数（`*T`）。`*T` 类型仅用于 extern 函数声明/调用，不能用于普通变量声明。

---

## 1. 关键字

```
enum struct const var fn extern return true false if else while for break continue null as
```

**说明**：
- `enum`：枚举声明
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
- `as`：类型转换关键字

---

## 2. 类型系统

### 2.1 支持的类型

| 类型 | 大小 | 说明 |
|------|------|------|
| `i32` | 4 B | 32位有符号整数 |
| `usize` | 4/8 B（平台相关） | 无符号大小类型，用于内存地址和大小；32位平台=4B，64位平台=8B |
| `bool` | 1 B | 布尔类型（true/false） |
| `byte` | 1 B | 无符号字节，对齐 1 B，用于字节数组 |
| `void` | 0 B | 仅用于函数返回类型 |
| `enum Name` | 4 B | 枚举类型（底层类型为 i32） |
| `struct Name` | 字段大小之和（含对齐填充） | 用户定义的结构体类型 |
| `[T: N]` | `sizeof(T) * N` | 固定大小数组类型，其中 T 为元素类型，N 为编译期常量 |
| `&T` | 4/8 B（平台相关） | 普通指针类型，用于普通变量和函数参数；32位平台=4B，64位平台=8B |
| `*T` | 4/8 B（平台相关） | FFI 指针类型，仅用于 extern 函数声明/调用；32位平台=4B，64位平台=8B |

**类型说明**：
- **结构体类型**：
  - 结构体使用 C 内存布局，字段顺序存储
  - 对齐 = 最大字段对齐值
  - 与 C 结构体 100% 兼容
  - **内存布局详细规则**（见下方 2.3 节）
- **数组类型** (`[T: N]`)：
  - N 必须是编译期常量（字面量或 const 变量）
  - 对齐 = 元素类型 T 的对齐值
  - 多维数组：`[[T: N]: M]`
- **`usize` 类型**：
  - 平台相关的无符号整数类型，用于表示内存地址、数组索引和大小
  - 32位平台：`usize` = `u32`（4 字节）
  - 64位平台：`usize` = `u64`（8 字节）
  - 对齐值 = 类型大小（自然对齐）
  - 用途：表示指针大小、数组索引、内存大小等平台相关的值
  - 示例：`const ptr_size: usize = sizeof(&i32);`（用于检测平台字长）
- **指针类型**：
  - `&T`：普通指针类型，用于普通变量和函数参数，可通过 `&expr` 获取地址
  - `*T`：FFI 指针类型，仅用于 `extern` 函数声明/调用，不能用于普通变量声明
  - 指针大小：64位平台为 8 字节，32位平台为 4 字节
  - 指针大小等于 `usize` 大小（`sizeof(&T) == sizeof(usize)`）

### 2.2 类型规则

- **无隐式转换**：类型必须完全一致
- **显式类型注解**：所有变量和函数参数必须显式指定类型
- **类型检查**：编译期进行类型检查，类型不匹配即编译错误

### 2.3 结构体内存布局详细规则

本节详细说明结构体的内存布局规则，包括字段对齐、填充、嵌套结构体等。

#### 2.3.1 字段对齐规则

结构体字段的对齐遵循以下规则：

1. **基础类型对齐**：
   - `i8`, `byte`, `bool`：对齐值 = 1 字节
   - `i16`：对齐值 = 2 字节
   - `i32`：对齐值 = 4 字节
   - `i64`：对齐值 = 8 字节
   - `usize`, `&T`, `*T`（FFI指针）：对齐值 = 4/8 字节（平台相关）

2. **字段偏移计算**：
   - 第一个字段的偏移 = 0
   - 后续字段的偏移 = 向上对齐到该字段对齐值的倍数
   - 偏移量计算公式：`offset(field_n) = align_up(offset(field_n-1) + sizeof(field_n-1), alignof(field_n))`
   - **`align_up(value, alignment)` 函数说明**：
     - 功能：将 `value` 向上对齐到 `alignment` 的倍数
     - 定义：`align_up(value, alignment) = ((value + alignment - 1) / alignment) * alignment`
     - 等价于：`align_up(value, alignment) = (value + alignment - 1) & ~(alignment - 1)`（当 alignment 是 2 的幂时）
     - 示例：
       - `align_up(5, 4) = 8`（5 向上对齐到 4 的倍数 = 8）
       - `align_up(8, 4) = 8`（8 已经是 4 的倍数，保持不变）
       - `align_up(0, 8) = 0`（0 向上对齐到 8 的倍数 = 0）
       - `align_up(9, 8) = 16`（9 向上对齐到 8 的倍数 = 16）

3. **填充字节插入**：
   - 在字段之间插入填充字节以满足对齐要求
   - **填充字节的内容明确为 0**（零填充）
   - 这确保了结构体布局的可预测性
   - 注意：虽然 C 标准中填充字节内容是未定义的，但 Uya Mini 明确指定为 0 填充，以提供确定的行为

**示例 1：基本对齐**：
```uya
struct Example1 {
    a: i32,   // 偏移 0，大小 4
    b: i32,   // 偏移 4，大小 4
    c: i32,   // 偏移 8，大小 4
}
// 大小 = 12 字节，对齐 = 4 字节
```

**示例 2：需要填充的结构体**：
```uya
struct Example2 {
    a: byte,  // 偏移 0，大小 1
    b: i32,   // 偏移 4（跳过 1-3 填充），大小 4
    c: byte,  // 偏移 8，大小 1
}
// 64位平台：大小 = 12 字节（最后填充 3 字节以满足数组对齐），对齐 = 4 字节
// 32位平台：大小 = 12 字节，对齐 = 4 字节
```

#### 2.3.2 嵌套结构体布局

嵌套结构体字段的对齐规则：

1. **嵌套结构体字段对齐**：
   - 嵌套结构体的对齐值 = 其最大字段的对齐值
   - 嵌套结构体字段的偏移必须对齐到嵌套结构体的对齐值

2. **嵌套结构体大小**：
   - 嵌套结构体的大小包括其所有字段和填充字节

**示例 3：嵌套结构体**：
```uya
struct Inner {
    x: i32,  // 偏移 0，大小 4
    y: i32,  // 偏移 4，大小 4
} // Inner 大小 = 8 字节，对齐 = 4 字节

struct Outer {
    a: byte,        // 偏移 0，大小 1
    inner: Inner,   // 偏移 4（跳过 1-3 填充，对齐到 4），大小 8
    b: byte,        // 偏移 12，大小 1
}
// 大小 = 16 字节（最后填充 3 字节），对齐 = 4 字节
```

#### 2.3.3 数组字段布局

数组字段的内存布局：

1. **数组字段对齐**：
   - 数组字段的对齐值 = 元素类型的对齐值
   - 数组字段的偏移必须对齐到元素类型的对齐值

2. **数组字段大小**：
   - 数组字段大小 = `N * sizeof(T)`（N 为元素数量，T 为元素类型）

**示例 4：数组字段**：
```uya
struct Example4 {
    a: byte,           // 偏移 0，大小 1
    arr: [i32: 3],     // 偏移 4（跳过 1-3 填充，对齐到 4），大小 12
    b: i32,            // 偏移 16，大小 4
}
// 大小 = 20 字节，对齐 = 4 字节
```

#### 2.3.4 结构体大小和对齐

1. **结构体对齐值**：
   - 结构体的对齐值 = 所有字段对齐值的最大值
   - 包括嵌套结构体字段的对齐值

2. **结构体大小计算**：
   - 结构体大小 = 最后一个字段的偏移 + 最后一个字段的大小
   - 最终大小向上对齐到结构体的对齐值
   - 这是为了确保结构体在数组中正确对齐

**示例 5：结构体大小计算**：
```uya
struct Example5 {
    a: byte,   // 偏移 0，大小 1，对齐 = 1
    b: i32,    // 偏移 4，大小 4，对齐 = 4
    c: i32,    // 偏移 8，大小 4，对齐 = 4
}
// 最后一个字段 c 的偏移 + 大小 = 8 + 4 = 12
// 结构体对齐值 = max(1, 4) = 4
// 最终大小 = 12（已对齐到 4）
```

#### 2.3.5 平台差异

不同平台的结构体布局差异主要来自指针大小的不同：

| 类型 | 32位平台 | 64位平台 |
|------|---------|---------|
| `&T` | 4字节，对齐4 | 8字节，对齐8 |
| `*T`（FFI） | 4字节，对齐4 | 8字节，对齐8 |
| `usize` | 4字节，对齐4 | 8字节，对齐8 |

**示例 6：平台差异**：
```uya
struct PlatformStruct {
    ptr: &i32,
    len: usize,
}
// 32位平台：ptr(4B, offset=0) + len(4B, offset=4) = 8字节，对齐=4
// 64位平台：ptr(8B, offset=0) + len(8B, offset=8) = 16字节，对齐=8
```

#### 2.3.6 空结构体

空结构体（无字段）的特殊规则：

- **大小**：1 字节（C 标准要求，确保每个结构体实例有唯一地址）
- **对齐**：1 字节
- **用途**：主要用于类型标记

```uya
struct Empty { }  // 大小 = 1 字节，对齐 = 1 字节
```

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
- 编译器在只读数据段中存储字符串字面量（null 终止，创建全局常量变量）
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
declaration    = fn_decl | extern_decl | enum_decl | struct_decl | var_decl
extern_decl    = 'extern' 'fn' ID '(' [ param_list ] ')' type ';'
enum_decl      = 'enum' ID '{' enum_variant_list '}'
enum_variant_list = enum_variant { ',' enum_variant }
enum_variant   = ID [ '=' NUM ]
struct_decl    = 'struct' ID '{' field_list '}'
field_list     = field { ',' field }
field          = ID ':' type ';'
```

**说明**：
- 程序由零个或多个声明组成
- 声明可以是函数声明、枚举声明、结构体声明或变量声明（顶层常量）
- 枚举声明：`enum ID { variant_list }`，变体列表用逗号分隔，每个变体可以显式赋值（`Variant = NUM`）或使用自动递增
- 结构体声明：`struct ID { field_list }`，字段列表用逗号分隔，每个字段以分号结尾

### 4.2 函数声明

```
fn_decl        = 'fn' ID '(' [ param_list ] ')' type '{' statements '}'
                | 'extern' 'fn' ID '(' [ param_list ] ')' type ';'
param_list     = param { ',' param } [ ',' '...' ]
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
    - 基础类型：`i32`、`usize`、`bool`、`byte`、`void`、结构体类型
    - FFI 指针类型：`*T`（如 `*byte`、`*void`、`*i32` 等）
  - 注意：`*T` 类型仅用于 extern 函数声明/调用，不能用于普通变量声明
  - **Uya 指针传递给 FFI 函数**：
    - ✅ **Uya 普通指针 `&T` 可以通过显式转换传递给 FFI 函数的指针类型参数 `*T`**
    - 使用 `as` 进行显式转换：`&T as *T`（安全转换，无精度损失，编译期检查）
    - 示例：`extern write(fd: i32, buf: *byte, count: i32) i32;` 调用时使用 `write(1, &buffer[0] as *byte, 10);`
    - 这是 FFI 调用时的显式规则，符合 Uya Mini "显式控制"的设计原则
  - **可变参数支持**：
    - 使用 `...` 表示可变参数列表（C 风格的变参函数）
    - 语法：`extern fn name(param1: type1, param2: type2, ...) return_type;`
    - `...` 必须是参数列表的最后一个元素
    - 可变参数函数的调用必须提供至少等于固定参数数量的参数
    - 示例：`extern printf(fmt: *byte, ...) i32;`
  - 示例：
    ```uya
    // 声明外部 C 函数
    extern fn llvm_context_create() void;
    extern fn llvm_module_create(name: i32) i32;
    
    // 支持 FFI 指针类型参数
    extern fn fopen(filename: *byte, mode: *byte) *FILE;
    extern fn strcmp(s1: *byte, s2: *byte) i32;
    
    // 可变参数函数声明
    extern fn printf(fmt: *byte, ...) i32;
    extern fn sprintf(buf: *byte, fmt: *byte, ...) i32;
    
    fn main() i32 {
        llvm_context_create();
        // 字符串字面量可以作为 extern 函数参数
        const result: i32 = strcmp("i32", "i32");  // 字符串字面量类型为 *byte
        
        // 调用可变参数函数
        printf("Hello, world!\n");
        printf("x = %d, y = %d\n", 10, 20);
        
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
type           = 'i32' | 'usize' | 'bool' | 'byte' | 'void' | array_type | pointer_type | ffi_pointer_type | struct_type
array_type     = '[' type ':' NUM ']'
pointer_type   = '&' type
ffi_pointer_type = '*' type
struct_type    = 'struct' ID
```

**说明**：
- `i32`：32位有符号整数
- `usize`：平台相关的无符号大小类型（32位平台=4B，64位平台=8B），用于内存地址和大小
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
if_stmt        = 'if' expr '{' statements '}' [ else_clause ]
else_clause    = 'else' 'if' expr '{' statements '}' [ else_clause ]
               | 'else' '{' statements '}'
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
- if 语句：条件必须为 `bool` 类型，支持 `else if` 链和可选的 `else` 分支
  - 语法：`if expr { statements } [ else if expr { statements } ]* [ else { statements } ]`
  - 可以包含多个 `else if` 分支，形成条件链
  - 可选的最终 `else` 分支处理所有其他情况
  - 示例：
    ```uya
    if x == 1 {
        // ...
    } else if x == 2 {
        // ...
    } else if x == 3 {
        // ...
    } else {
        // ...
    }
    ```
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
mul_expr       = cast_expr { ('*' | '/' | '%') cast_expr }
cast_expr      = unary_expr [ 'as' type ]
unary_expr     = ('!' | '-' | '&' | '*') unary_expr | primary_expr
primary_expr   = ID | NUM | 'true' | 'false' | 'null' | STRING | struct_literal | array_literal | member_access | array_access | call_expr | sizeof_expr | alignof_expr | len_expr | '(' expr ')'
sizeof_expr    = 'sizeof' '(' (type | expr) ')'
alignof_expr   = 'alignof' '(' (type | expr) ')'
len_expr       = 'len' '(' expr ')'
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

- **数组字面量**：`[expr1, expr2, ...]` 或 `[]`
  - 所有元素类型必须相同
  - **非空数组字面量**（`[expr1, expr2, ...]`）：
    - 元素类型从第一个元素推断，数组大小从元素个数推断
    - 元素个数必须与数组大小匹配（如果显式指定了数组类型）
    - 示例：`[1, 2, 3]`（类型推断为 `[i32: 3]`），`var arr: [i32: 3] = [1, 2, 3];`（类型显式指定）
  - **空数组字面量**（`[]`）：
    - 仅当变量类型已明确指定时可以使用（如 `var arr: [i32: 100] = [];`）
    - 表示未初始化，数组内容未定义
    - 类型和大小从变量声明中获取，不能独立使用空数组字面量进行类型推断
    - 示例：`var arr: [i32: 100] = [];`（未初始化数组，`len(arr)` 返回 100）

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

- **字符串字面量**：`"..."` ✅ 已实现
  - 类型为 `*byte`（FFI 指针类型）
  - 仅可作为 `extern` 函数参数使用（不能赋值给变量、不能用于普通表达式）
  - 编译器在只读数据段中存储字符串字面量（null 终止，创建全局常量变量）
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
  2. 类型转换：`as`
  3. 乘除模：`*` `/` `%`
  4. 加减：`+` `-`
  5. 比较：`<` `>` `<=` `>=`
  6. 相等性：`==` `!=`
  7. 逻辑与：`&&`
  8. 逻辑或：`||`
  9. 赋值：`=`

- **运算符说明**：
  - 算术运算符：`+` `-` `*` `/` `%`
    - 操作数类型：`i32` 或 `usize`（`i32` 和 `usize` 可以混合运算）
    - 结果类型：如果两个操作数都是 `i32`，结果为 `i32`；如果至少有一个是 `usize`，结果为 `usize`
    - 示例：`i32 + i32` → `i32`，`i32 + usize` → `usize`，`usize + usize` → `usize`
  - 比较运算符：`==` `!=` `<` `>` `<=` `>=`
    - 操作数类型必须相同（`i32`、`usize`、`bool`、相同枚举类型或相同结构体类型）
    - `i32` 和 `usize` 不能直接比较，需要显式转换（如 `(i32_val as usize) == usize_val`）
    - 枚举类型可以进行比较，比较的是枚举值的数值
    - 结果类型为 `bool`
  - 逻辑运算符：`&&` `||`（操作数必须是 `bool`，结果类型为 `bool`）
  - 逻辑非：`!`（操作数必须是 `bool`，结果类型为 `bool`）
  - 一元负号：`-`（操作数必须是 `i32`，结果类型为 `i32`；`usize` 是无符号类型，不支持负号）
  - 取地址运算符：`&expr`（操作数必须是左值，返回指向操作数的指针类型 `&T`）
  - 解引用运算符：`*expr`（操作数必须是指针类型 `&T`，返回类型 `T`）
  - 赋值：`=`（左侧必须是 `var` 变量，类型必须匹配）

- **函数调用**：
  - 函数名必须是已声明的函数
  - 参数个数和类型必须匹配
  - 返回值类型必须匹配上下文要求
  - **可变参数函数调用**：
    - 可变参数函数调用必须提供至少等于固定参数数量的参数
    - 可变参数部分可以传递任意数量的额外参数
    - 编译器进行有限的编译期检查（参数数量至少满足固定参数要求）

---

### 4.8 类型转换

Uya Mini 支持显式类型转换，使用 `as` 关键字：

**语法**：`expr as type`

**功能**：将表达式转换为指定类型

**支持的转换**：
- `i32` ↔ `byte`：整数类型与字节类型之间的转换
  - `i32 as byte`：将 i32 值截断为 byte（保留低 8 位）
  - `byte as i32`：将 byte 值零扩展为 i32（无符号扩展）
- `i32` ↔ `bool`：整数类型与布尔类型之间的转换
  - `i32 as bool`：非零值为 `true`，零值为 `false`
  - `bool as i32`：`true` 转换为 `1`，`false` 转换为 `0`
- `i32` ↔ `usize`：有符号整数与无符号大小类型之间的转换
  - `i32 as usize`：将 i32 值转换为 usize（保持数值，但类型变为无符号）
  - `usize as i32`：将 usize 值转换为 i32（保持数值，但类型变为有符号）
  - **注意**：转换时数值保持不变，但类型改变（有符号 ↔ 无符号）
  - **平台相关**：`usize` 的大小取决于平台（32位=4B，64位=8B），转换时需要考虑大小匹配
- `&T` ↔ `*T`：Uya 普通指针与 FFI 指针类型之间的转换
  - `&T as *T`：将 Uya 普通指针转换为 FFI 指针类型（安全转换，无精度损失）
    - ✅ 使用 `as` 进行安全转换（编译期检查）
    - 仅在 FFI 函数调用时使用
    - 示例：`extern write(fd: i32, buf: *byte, count: i32) i32;` 调用时使用 `&buffer[0] as *byte`
  - `*T as &T`：将 FFI 指针转换为 Uya 普通指针（不推荐，需要显式强转）
    - ❌ 不支持（类型系统不兼容，Uya Mini 不支持 `as!` 强转）

**说明**：
- 类型转换是显式的，必须使用 `as` 关键字
- 转换可能改变值的表示（如 i32 截断为 byte）
- 类型转换的优先级高于乘除运算，低于一元运算符
- 指针类型转换：`&T as *T` 是允许的（仅用于 FFI 上下文），`*T as &T` 不支持
- 结构体类型转换：不支持（结构体类型不能转换）

**示例**：
```uya
// i32 与 byte 转换
var x: i32 = 256;
var b: byte = x as byte;  // b = 0（截断，只保留低 8 位）

var b2: byte = 42;
var x2: i32 = b2 as i32;  // x2 = 42（零扩展）

// i32 与 bool 转换
var n: i32 = 42;
var flag: bool = n as bool;  // flag = true（非零值）

var flag2: bool = false;
var n2: i32 = flag2 as i32;  // n2 = 0

// 用于比较运算（解决类型不匹配问题）
var byte_val: byte = 42;
if (byte_val as i32) != 0 {  // 转换为 i32 后再比较
    // ...
}

// 指针类型转换（FFI 调用）
extern fn write(fd: i32, buf: *byte, count: i32) i32;

fn main() i32 {
    var buffer: [byte: 100] = [];
    // Uya 普通指针转换为 FFI 指针类型
    const result: i32 = write(1, &buffer[0] as *byte, 100);
    return result;
}
```

---

### 4.9 内置函数

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
- `sizeof(usize)` - 获取 `usize` 类型的大小（64位平台为 8 字节，32位平台为 4 字节，等于指针大小）
- `sizeof(usize) == sizeof(&T)` - `usize` 大小始终等于指针大小（平台字长）
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

// usize 类型大小（平台相关）
const usize_size: i32 = sizeof(usize);  // 32位平台=4，64位平台=8
const ptr_size_check: i32 = sizeof(&i32);
// 验证：指针大小应该等于 usize 大小
// if ptr_size_check != usize_size { return 1; }
```

**设计说明**：
- Uya Mini 作为最小子集，不依赖模块系统
- 因此 `sizeof` 和 `alignof` 作为内置函数，无需导入即可使用
- 这简化了使用，与 `len` 函数保持一致

#### `alignof(T)` - 类型对齐查询

**语法**：`alignof(Type)` 或 `alignof(expr)`

**功能**：返回类型或表达式的对齐字节数（编译期常量）

**返回值**：`i32`（对齐字节数）

**说明**：
- `alignof(Type)` - 获取类型的对齐值（编译时计算）
- `alignof(expr)` - 获取表达式结果类型的对齐值（编译时计算）
- `alignof([T: N])` - 获取数组类型的对齐值（等于 `alignof(T)`）
- `alignof(&T)` - 获取指针类型的对齐值（等于指针大小，平台相关）
- `alignof(usize)` - 获取 `usize` 类型的对齐值（等于类型大小，平台相关）
- `alignof(struct S)` - 获取结构体类型的对齐值（等于最大字段对齐值）
- 必须是编译时常量，可在任何需要编译期常量的位置使用
- 编译器在编译期直接折叠为常数，不生成函数调用

**示例**：
```uya
struct Node {
    value: i32;
}

const node_align: i32 = alignof(Node);        // 类型对齐（4字节）
const ptr_align: i32 = alignof(&Node);        // 指针类型对齐（平台相关）

var node: Node = Node{ value: 10 };
const node_align2: i32 = alignof(node);       // 表达式对齐（与 alignof(Node) 相同）

// 数组类型对齐
const array_align: i32 = alignof([i32: 10]);  // 等于 alignof(i32) = 4

// usize 类型对齐（平台相关）
const usize_align: i32 = alignof(usize);  // 32位平台=4，64位平台=8
```

**设计说明**：
- Uya Mini 作为最小子集，不依赖模块系统
- 因此 `alignof` 作为内置函数，无需导入即可使用
- 这简化了使用，与 `sizeof` 和 `len` 保持一致

#### `len(array)` - 数组长度查询

**语法**：`len(expr)`

**功能**：返回数组的元素个数（编译期常量）

**返回值**：`i32`（元素个数）

**说明**：
- `len(array)` - 获取数组表达式的元素个数（编译时计算）
- 参数必须是数组类型表达式（`[T: N]`）
- 必须是编译时常量，可在任何需要编译期常量的位置使用
- 编译器在编译期直接折叠为常数，不生成函数调用
- `len` 返回元素个数，而 `sizeof` 返回字节大小

**示例**：
```uya
// 数组表达式长度
var nums: [i32: 5] = [1, 2, 3, 4, 5];
const nums_len: i32 = len(nums);        // 5（元素个数）

// 用于循环和计算
var arr: [i32: 8] = [1, 2, 3, 4, 5, 6, 7, 8];
const count: i32 = len(arr);  // 8

// len 与 sizeof 的区别
var arr2: [i32: 5] = [1, 2, 3, 4, 5];
const len_val: i32 = len(arr2);      // 5（元素个数）
const size_val: i32 = sizeof(arr2);  // 20（字节大小：5 * 4）

// 在循环中使用
var values: [i32: 10] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
var i: i32 = 0;
while i < len(values) {
    // 处理元素
    i = i + 1;
}

// 空数组字面量（未初始化）
var arr: [i32: 100] = [];
const arr_len: i32 = len(arr);  // 100（从声明中获取大小）
const arr_size: i32 = sizeof(arr);  // 400（100 * 4 字节）
```

**设计说明**：
- `len` 作为内置函数，与 `sizeof` 类似，无需导入即可使用
- `len` 返回数组的元素个数，`sizeof` 返回数组的字节大小
- 对于数组 `[T: N]`：`len(array)` 返回 `N`（元素个数），`sizeof(array)` 返回 `sizeof(T) * N`（字节大小）
- `len` 只接受数组表达式，不接受类型参数（与 `sizeof` 不同，`sizeof` 可以接受类型或表达式）

**实现状态**：✅ 已完整实现
- 词法分析器：识别 `len` 关键字
- 语法分析器：解析 `len(array)` 表达式
- 类型检查器：检查参数必须是数组类型，返回 i32 类型
- 代码生成器：生成 LLVM 代码，返回数组元素个数（编译期常量）

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
   - 算术运算符：操作数必须是 `i32` 或 `usize`（`i32` 和 `usize` 可以混合运算，结果类型为较大的类型）
   - 比较运算符：操作数类型必须相同（`i32`、`usize`、`bool`、相同枚举类型或相同结构体类型），`i32` 和 `usize` 可以比较（需要显式转换）
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

7. **枚举类型规则**：
   - 枚举声明：`enum Name { Variant1, Variant2, ... }` 或 `enum Name { Variant1 = 42, Variant2, ... }`
   - 枚举值：可以显式赋值（`Variant = NUM`）或使用自动递增（默认从 0 开始，或基于前一个变体的值 + 1）
   - 混合赋值：可以混合使用显式赋值和自动递增
   - 枚举比较：支持 `==`、`!=`、`<`、`>`、`<=`、`>=`，比较的是枚举值的数值
   - 枚举赋值：按值复制（复制枚举值）
   - 枚举值访问：`EnumName.VariantName`，返回枚举类型
   - 枚举底层类型：`i32`（大小为 4 字节）
   - 枚举 sizeof：`sizeof(EnumName)` 和 `sizeof(enum_var)` 都返回 `i32` 类型，值为 4

8. **结构体类型规则**：
   - 结构体比较：仅支持 `==` 和 `!=`，逐字段比较
   - 结构体赋值：按值复制（所有字段复制）
   - 字段访问：只能访问已定义的字段

9. **数组类型规则**：
   - 数组大小必须是编译期常量
   - 数组访问：索引必须是 `i32` 类型
   - 数组赋值：按值复制（复制所有元素）

10. **指针类型规则**：
   - `&T` 类型可用于普通变量和函数参数
   - `*T` 类型仅用于 `extern` 函数声明/调用
   - **指针类型转换**：
     - ✅ `&T as *T`：Uya 普通指针可以显式转换为 FFI 指针类型（仅在 FFI 函数调用时）
     - ❌ `*T as &T`：FFI 指针不能转换为 Uya 普通指针（类型系统不兼容）
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
- **函数调用约定**：Uya Mini 遵循目标平台的 C 调用约定（C ABI），详见下方 5.5 节

### 5.5 函数调用约定详细说明

本节详细说明函数调用约定（ABI），包括参数传递、返回值传递、寄存器使用等规则。

**调用约定原则**：
- Uya Mini 遵循目标平台的 C 调用约定（C ABI）
- 不同平台有不同的调用约定规则
- 编译器根据目标平台自动选择合适的调用约定
- LLVM 会自动处理调用约定的细节

#### 5.5.1 x86-64 System V ABI（Linux、macOS、BSD）

这是 x86-64 平台上最常用的调用约定，用于 Linux、macOS 和大多数 Unix 系统。

**参数传递规则**：
1. **整数和指针参数**（前 6 个）：
   - 第 1 个参数 → `rdi` 寄存器
   - 第 2 个参数 → `rsi` 寄存器
   - 第 3 个参数 → `rdx` 寄存器
   - 第 4 个参数 → `rcx` 寄存器
   - 第 5 个参数 → `r8` 寄存器
   - 第 6 个参数 → `r9` 寄存器
   - 第 7 个及以后的参数 → 栈（从右到左压栈）

2. **结构体参数**：
   - 如果结构体大小 ≤ 16 字节：
     - 使用寄存器传递（最多 2 个 8 字节寄存器）
   - 如果结构体大小 > 16 字节：
     - 使用指针传递（调用者分配内存并传递指针）

**返回值传递规则**：
1. **整数和指针返回值**：
   - 返回值大小 ≤ 8 字节 → `rax` 寄存器
   - 返回值大小 = 16 字节 → `rax`（低 8 字节）+ `rdx`（高 8 字节）

2. **结构体返回值**：
   - 如果结构体大小 ≤ 16 字节：
     - 使用寄存器返回（`rax` + `rdx`）
   - 如果结构体大小 > 16 字节：
     - 使用 sret 指针返回
     - 调用者在栈上分配内存，传递指针作为隐式第一个参数（在 `rdi` 中）

**栈对齐**：
- 函数调用时，栈指针必须 16 字节对齐

#### 5.5.2 x86-64 Microsoft x64 Calling Convention（Windows）

Windows x86-64 平台使用不同的调用约定。

**参数传递规则**：
1. **整数和指针参数**（前 4 个）：
   - 第 1 个参数 → `rcx` 寄存器
   - 第 2 个参数 → `rdx` 寄存器
   - 第 3 个参数 → `r8` 寄存器
   - 第 4 个参数 → `r9` 寄存器
   - 第 5 个及以后的参数 → 栈（从右到左压栈）

2. **结构体参数**：
   - 如果结构体大小 ≤ 8 字节：
     - 使用寄存器传递（1 个 8 字节寄存器）
   - 如果结构体大小 > 8 字节：
     - 使用指针传递（调用者分配内存并传递指针）

**返回值传递规则**：
- 返回值大小 ≤ 8 字节 → `rax` 寄存器
- 返回值大小 > 8 字节 → 使用 sret 指针返回（不是 16 字节）

#### 5.5.3 ARM64 ABI（AArch64）

ARM64 平台的调用约定。

**参数传递规则**：
1. **整数和指针参数**（前 8 个）：
   - 使用 `x0` ~ `x7` 寄存器
   - 第 9 个及以后的参数 → 栈

2. **结构体参数**：
   - 如果结构体大小 ≤ 16 字节且可放入寄存器：
     - 使用 `x0` ~ `x7` 传递
   - 如果结构体大小 > 16 字节：
     - 使用指针传递

**返回值传递规则**：
- 返回值大小 ≤ 16 字节 → `x0` 或 `x0`+`x1`
- 返回值大小 > 16 字节 → 使用 sret 指针返回（`x8` 传递返回值的指针）

#### 5.5.4 32位平台调用约定

32位 x86 平台遵循 cdecl 调用约定（x86 平台的 C 标准调用约定）。

**参数传递规则**：
- 所有参数通过栈传递（从右到左压栈）
- 参数按 4 字节对齐（或按类型对齐值对齐）

**返回值传递规则**：
- 返回值大小 ≤ 4 字节 → `eax` 寄存器
- 返回值大小 = 8 字节 → `eax`（低4字节）+ `edx`（高4字节）
- 返回值大小 > 8 字节 → 使用 sret 指针返回

#### 5.5.5 调用约定总结

| 平台 | 整数参数寄存器 | 返回值寄存器 | sret 阈值 |
|------|--------------|-------------|-----------|
| x86-64 System V | rdi, rsi, rdx, rcx, r8, r9 | rax (+ rdx) | 16 字节 |
| x86-64 Windows | rcx, rdx, r8, r9 | rax | 8 字节 |
| ARM64 | x0 ~ x7 | x0 (+ x1) | 16 字节 |
| 32位 x86 | 栈 | eax (+ edx) | 8 字节 |

**重要说明**：
- 所有调用约定都与 C ABI 完全兼容
- 编译器根据目标平台自动选择正确的调用约定
- 参数和返回值的具体传递方式由 LLVM 后端处理
- 程序员无需关心底层细节，只需编写符合 Uya Mini 语法的代码

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
   - **两遍检查机制**（✅ 已实现）：
     - 第一遍：收集所有函数声明（只注册函数签名，不检查函数体）
     - 第二遍：检查所有声明（包括函数体、结构体、变量等）
     - 解决函数循环依赖问题：函数 A 调用函数 B，B 调用 A 的情况
     - 解决前向引用问题：函数 A 调用函数 B，B 在 A 之后声明的情况

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
- `usize` → `LLVMInt32Type()`（32位平台）或 `LLVMInt64Type()`（64位平台），根据目标平台自动选择
- `bool` → `LLVMInt1Type()` 或 `LLVMInt8Type()`（使用 1 位更精确）
- `byte` → `LLVMInt8Type()`
- `void` → `LLVMVoidType()`
- `struct Type` → `LLVMStructType()`（结构体类型）

**代码生成流程**：
1. 创建 LLVM 模块和上下文
2. 为每个结构体定义创建 LLVM 结构体类型
   - 按照内存布局详细规则（见 2.3 节）计算字段偏移和对齐
   - 确保与 C 结构体布局 100% 兼容
3. 为每个函数创建 LLVM 函数声明/定义
   - 按照函数调用约定（见 5.5 节）设置函数签名
   - LLVM 会自动处理调用约定的细节
4. 生成函数体：遍历 AST，生成对应的 LLVM IR 指令
5. 运行优化器（可选）
6. 生成目标代码：使用 `LLVMTargetMachineEmitToFile()` 或类似 API
7. 清理 LLVM 资源

**示例**：参见 [LLVM IR 代码生成示例](examples/llvm_ir_example.c)

**结构体处理**：
- 结构体类型使用 `LLVMStructType()` 定义
  - 必须按照内存布局详细规则（见 2.3 节）计算字段偏移和对齐
  - 使用 `LLVMStructSetBody()` 设置结构体字段类型和填充
  - 确保与 C 结构体布局 100% 兼容
- 结构体字面量：使用 `LLVMConstStruct()` 或分别创建字段常量
- 字段访问：使用 `LLVMBuildExtractValue()` 获取字段值
- 字段赋值：使用 `LLVMBuildInsertValue()` 设置字段值
- 结构体比较：生成逐字段比较的代码
- **内存布局实现**：
  - 编译器必须按照 2.3 节的规则计算结构体布局
  - 字段偏移必须正确对齐
  - 填充字节必须初始化为 0
  - 结构体大小和对齐值必须正确计算

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
| 类型系统 | i32, usize, bool, byte, void, enum, struct, [T: N], &T, *T | 完整的类型系统（结构体、数组、指针、枚举、接口等） |
| 结构体 | 支持（无方法、无接口实现） | 完整支持（方法、接口实现、drop） |
| 数组 | 支持固定大小数组 `[T: N]` | 支持固定大小数组和切片 |
| 指针 | 支持 `&T`（普通指针）和 `*T`（FFI指针） | 完整支持（包括 lifetime） |
| 控制流 | if, while, for（数组遍历）, break, continue | if, while, for（数组遍历、整数范围）, match, break, continue |
| 错误处理 | 不支持 | error, try, catch, !T |
| 内存管理 | 不支持 | defer, errdefer, RAII |
| 模块系统 | 不支持 | 完整的模块系统 |
| 字符串 | 字符串字面量（类型为 `*byte`，仅用于 FFI 函数参数） | 完整的字符串支持 |
| 类型推断 | 不支持 | 不支持（显式类型） |
| 类型转换 | 支持 `as`（基础类型之间） | 支持 `as` 和 `as!`（完整类型系统） |
| `sizeof` | 内置函数（无需导入） | 内置函数（无需导入） |
| `alignof` | 内置函数（无需导入） | 内置函数（无需导入） |
| 代码生成 | LLVM C API → 二进制 | C99 代码 → C 编译器 |

---

## 版本信息

- **版本**：0.1.0
- **创建日期**：2026-01-09
- **最后更新**：2026-01-13
- **基于 Uya 规范版本**：0.29
- **目的**：Uya Mini 编译器自举实现
- **状态说明**：规范文档定义了完整的语法和语义规则。编译器实现状态请参考 `TODO_implementation.md`
- **更新说明**：
  - 2026-01-13：同步 Uya 0.29 版本的结构体内存布局详细规则和函数调用约定详细说明
  - 2026-01-13：添加类型检查器两遍检查机制说明（解决函数循环依赖问题）
  - 2026-01-13：确认 `len` 函数已完整实现
  - 2026-01-13：添加枚举类型支持（从"不支持的特性"列表中移除"枚举"，添加枚举语法和语义规则）
  - 2026-01-13：添加 `else if` 语句支持（更新语法规范和示例）

---

## 参考文档

- [uya.md](../uya.md) - Uya 语言完整规范
- [uya_ai_prompt.md](../uya_ai_prompt.md) - Uya 语言 AI 提示词
- [grammar_formal.md](../grammar_formal.md) - Uya 语言正式 BNF 语法
- [compiler/architecture.md](../compiler/architecture.md) - Uya 编译器架构设计

