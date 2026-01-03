# Uya 语言语法规范（BNF）

本文档包含 Uya 语言的完整 BNF 语法规范。

> **注意**：本文档是 [uya.md](./uya.md) 的补充，详细语法说明请参考主文档。

---

## 完整语法汇总

### 程序结构

```
program        = { declaration }
declaration    = fn_decl | struct_decl | interface_decl | const_decl 
               | error_decl | extern_decl | export_decl | import_stmt
               | impl_block | test_stmt
```

### 函数声明

```
fn_decl        = 'fn' ID '(' [ param_list ] ')' type '{' statements '}'
param_list     = param { ',' param }
param          = ID ':' type
```

### 结构体声明

```
struct_decl    = 'struct' ID '{' field_list '}'
field_list     = field { ',' field }
field          = ID ':' type
```

### 接口声明

```
interface_decl = 'interface' ID '{' method_sig+ '}'  # 一个或多个 method_sig
method_sig     = 'fn' ID '(' [ param_list ] ')' type ';'
impl_block     = 'impl' ID ':' ID '{' method_impl+ '}'  # 一个或多个 method_impl
method_impl    = fn_decl
```

**说明**：
- `method_sig+` 表示一个或多个方法签名（BNF 扩展语法，等价于 `method_sig { method_sig }`）
- 接口必须至少包含一个方法签名
- 详细语法说明见 [uya.md](./uya.md#6-接口interface)

### 类型系统

```
type           = base_type | pointer_type | array_type | slice_type 
               | struct_type | interface_type | atomic_type | error_union_type
               | extern_type

base_type      = 'i8' | 'i16' | 'i32' | 'i64' | 'u8' | 'u16' | 'u32' | 'u64'
               | 'f32' | 'f64' | 'bool' | 'byte' | 'void' | 'usize'
pointer_type   = '&' type | '*' type
array_type     = '[' type ';' NUM ']'
slice_type     = '&[' type ']' | '&[' type ';' NUM ']'
struct_type    = ID
interface_type = ID
atomic_type    = 'atomic' type
error_union_type = '!' type  # 错误联合类型，表示 T | Error
extern_type    = 'extern' 'struct' ID
```

### 变量声明

```
var_decl       = ('const' | 'var') ID ':' type '=' expr ';'
const_decl     = 'const' ID ':' type '=' expr ';'
```

### 语句

```
statement      = expr_stmt | var_decl | return_stmt | if_stmt | while_stmt
               | for_stmt | break_stmt | continue_stmt | defer_stmt | errdefer_stmt
               | block_stmt | match_stmt | test_stmt

expr_stmt      = expr ';'
return_stmt    = 'return' [ expr ] ';'
if_stmt        = 'if' expr '{' statements '}' [ 'else' '{' statements '}' ]
while_stmt     = 'while' expr '{' statements '}'
for_stmt       = 'for' expr '|' ID '|' '{' statements '}'           # 值迭代（只读）
               | 'for' expr '|' '&' ID '|' '{' statements '}'        # 引用迭代（可修改）
               | 'for' range '|' ID '|' '{' statements '}'           # 整数范围，有元素变量
               | 'for' expr '{' statements '}'                       # 丢弃元素，只循环次数
               | 'for' range '{' statements '}'                      # 整数范围，丢弃元素

# 详细说明：
# - expr：可迭代对象（数组、切片、迭代器等）
# - range：整数范围表达式，如 0..10 或 0..（无限范围）
# - |ID|：值迭代（只读），绑定元素值
# - |&ID|：引用迭代（可修改），绑定元素指针
# - 省略变量绑定：丢弃元素，只循环次数
# 详细语法说明见 [uya.md](./uya.md#8-控制流)
break_stmt     = 'break' ';'
continue_stmt  = 'continue' ';'
defer_stmt     = 'defer' ( statement | '{' statements '}' )
errdefer_stmt  = 'errdefer' ( statement | '{' statements '}' )
block_stmt     = '{' statements '}'
match_stmt     = match_expr
match_expr     = 'match' expr '{' pattern_list '}'
test_stmt      = 'test' STRING '{' statements '}'
```

### 表达式

```
expr           = assign_expr
assign_expr    = or_expr [ ('=' | '+=' | '-=' | '*=' | '/=' | '%=') assign_expr ]
or_expr        = xor_expr { '||' xor_expr }
xor_expr       = and_expr { '^' and_expr }
and_expr       = bitand_expr { '&&' bitand_expr }
bitand_expr    = eq_expr { '&' eq_expr }
eq_expr        = rel_expr { ('==' | '!=') rel_expr }
rel_expr       = shift_expr { ('<' | '>' | '<=' | '>=') shift_expr }
shift_expr     = add_expr { ('<<' | '>>') add_expr }
add_expr       = mul_expr { ('+' | '-' | '+|' | '-|' | '+%' | '-%') mul_expr }
mul_expr       = unary_expr { ('*' | '/' | '%' | '*|' | '*%') unary_expr }
unary_expr     = ('!' | '-' | '~' | '&' | '*' | 'try') unary_expr | cast_expr
cast_expr      = postfix_expr [ ('as' | 'as!') type ]
postfix_expr   = primary_expr { '.' ID | '[' expr ']' | '(' arg_list ')' | slice_op | catch_op }
catch_op       = 'catch' [ '|' ID '|' ] '{' statements '}'
primary_expr   = ID | NUM | STRING | 'true' | 'false' | 'null' | 'max' | 'min'
               | struct_literal | array_literal | match_expr | '(' expr ')'
```

### 特殊表达式

```
range          = expr '..' [ expr ]
slice_op       = '[' expr ':' expr ']'  // 切片操作，完整语法为 &expr[start:len]
struct_literal = ID '{' field_init_list '}'
field_init_list = [ field_init { ',' field_init } ]
field_init     = ID ':' expr
array_literal  = '[' expr_list ']' | '[' expr ';' NUM ']'
expr_list      = [ expr { ',' expr } ]
arg_list       = [ expr { ',' expr } ]
pattern_list   = pattern '=>' expr { ',' pattern '=>' expr } [ ',' 'else' '=>' expr ]
pattern        = literal | ID | struct_pattern | error_pattern
struct_pattern = ID '{' field_pattern_list '}'
field_pattern_list = [ field_pattern { ',' field_pattern } ]
field_pattern  = ID ':' (literal | ID)
error_pattern  = 'error' '.' ID
literal        = NUM | STRING | 'true' | 'false' | 'null'
```

### 模块系统

```
export_decl    = 'export' (fn_decl | struct_decl | interface_decl | const_decl 
               | error_decl | extern_decl)
import_stmt    = 'use' module_path [ 'as' ID ] ';'
module_path    = ID { '.' ID }
```

**说明**：
- **导出语法**：使用 `export` 关键字标记可导出的项
  - `export fn public_function() i32 { ... }`
  - `export struct PublicStruct { ... }`
  - `export interface PublicInterface { ... }`
  - `export const PUBLIC_CONST: i32 = 42;`
  - `export error PublicError;`
  - `export extern printf(fmt: *byte, ...) i32;`
- **导入语法**：
  - 导入整个模块：`use std.io;`（使用时需要模块前缀：`std.io.read_file()`）
  - 导入特定项：`use std.io.read_file;`（直接使用：`read_file()`）
  - 导入并重命名：`use std.io as io_module;`（使用别名：`io_module.read_file()`）
- **模块路径**：使用 `.` 分隔，相对于项目根目录
  - 项目根目录：`main` 模块
  - 子目录：`std/io/` → `std.io`
- 详细说明见 [uya.md](./uya.md#15-模块系统)

### 外部函数接口（FFI）

```
extern_decl    = 'extern' 'fn' ID '(' [ param_list ] ')' type ';'
               | 'extern' 'struct' ID '{' field_list '}'
```

### 错误处理

```
error_decl     = 'error' ID ';'                              # 预定义错误声明（可选）
error_type     = 'error' '.' ID                              # 错误类型引用（预定义或运行时错误）
```

**说明**：
- **预定义错误**（可选）：使用 `error ErrorName;` 在顶层声明，属于全局命名空间
- **运行时错误**：使用 `error.ErrorName` 语法直接创建，无需预先声明
- 两种错误类型在语法上使用相同的引用形式 `error.ErrorName`
- 详细说明见 [uya.md](./uya.md#2-类型系统) 错误类型部分

### 字符串插值

```
string_interp  = '"' { segment } '"'
segment        = TEXT | '${' expr [ ':' spec ] '}'
spec           = flag* width? precision? type
flag           = '#' | '0' | '-' | ' ' | '+'
width          = NUM | '*'
precision      = '.' NUM | '.*'
type           = 'd' | 'u' | 'x' | 'X' | 'f' | 'F' | 'e' | 'E' | 'g' | 'G' | 'c' | 'p'
```

### 注释

```
line_comment   = '//' .* '\n'
block_comment  = '/*' .* '*/'
```

### 词法规则

```
identifier     = [A-Za-z_][A-Za-z0-9_]*
NUM            = [0-9]+ | [0-9]+ '.' [0-9]+
STRING         = '"' .* '"'
TEXT           = [^${}]+
```

### 可选特性（泛型和宏）

```
// 泛型语法（可选特性）
generic_struct = 'struct' ID '(' type_param_list ')' '{' field_list '}'
generic_fn     = 'fn' ID '(' type_param_list ')' '(' [ param_list ] ')' [ '->' type ] '{' statements '}'
type_param_list = ID { ',' ID }

// 显式宏语法（可选特性）
macro_decl     = 'mc' ID '(' [ param_list ] ')' return_tag '{' statements '}'
return_tag     = 'expr' | 'stmt' | 'struct' | 'type'
```

---

## 语法规则快速参考

### 运算符优先级表

| 优先级 | 运算符 | 结合性 | 说明 |
|--------|--------|--------|------|
| 1 (最高) | `.` `[]` `()` `[start:len]` `catch` | 左结合 | 成员访问、数组索引、函数调用、切片、错误捕获 |
| 2 | `!` `-` `~` `&` `*` `try` | 右结合 | 逻辑非、取负、按位取反、取地址、解引用、错误传播/溢出检查 |
| 3 | `as` `as!` | 左结合 | 类型转换 |
| 4 | `*` `/` `%` `*|` `*%` | 左结合 | 乘除模、饱和乘、包装乘 |
| 5 | `+` `-` `+|` `-|` `+%` `-%` | 左结合 | 加减、饱和加减、包装加减 |
| 6 | `<<` `>>` | 左结合 | 位移 |
| 7 | `<` `>` `<=` `>=` | 左结合 | 关系比较 |
| 8 | `==` `!=` | 左结合 | 相等比较 |
| 9 | `&` | 左结合 | 按位与 |
| 10 | `^` | 左结合 | 按位异或 |
| 11 | `\|` | 左结合 | 按位或 |
| 12 | `&&` | 左结合 | 逻辑与 |
| 13 | `\|\|` | 左结合 | 逻辑或 |
| 14 (最低) | `=` `+=` `-=` `*=` `/=` `%=` | 右结合 | 赋值 |

---

## 详细语法说明

## 1. 词法规则

### 1.1 标识符

```
identifier = [A-Za-z_][A-Za-z0-9_]*
```

- 区分大小写
- 不能是关键字

### 1.2 关键字

```
struct const var fn return extern true false if while break continue
defer errdefer try catch error null interface impl atomic max min
export use
```

### 1.3 字符串插值

```
segment = TEXT | '${' expr [':' spec] '}'
spec    = flag* width? precision? type
flag    = '#' | '0' | '-' | ' ' | '+'
width   = NUM | '*'  // '*' 为未来特性，暂不支持
precision = '.' NUM | '.*'  // '.*' 为未来特性，暂不支持
type    = 'd' | 'u' | 'x' | 'X' | 'f' | 'F' | 'e' | 'E' | 'g' | 'G' | 'c' | 'p'
```

**说明**：
- `segment`：字符串插值的基本单元，可以是普通文本或插值表达式
- `spec`：格式说明符，与 C printf 保持一致
- `width` / `precision` 必须为编译期数字（`*` 暂不支持）
- 结果类型为 `[i8; N]`，宽度由格式字符串最大可能长度常量求值得出

---

## 2. 类型系统

### 2.1 接口类型

```
interface_decl = 'interface' ID '{' method_sig { method_sig } '}'
method_sig     = 'fn' ID '(' [ param_list ] ')' type ';'
impl_block     = 'impl' ID ':' ID '{' method_impl { method_impl } '}'
method_impl    = fn_decl
interface_type = ID  // 在类型标注中使用接口名称
```

**说明**：
- `interface_decl`：接口声明语法（详见[接口声明](#接口声明)部分）
- `interface_type`：接口类型标注，使用接口名称（ID）
- `method_sig`：方法签名
- `impl_block`：接口实现块
- `param`：参数定义，格式为 `param_name: type`
- `method_impl`：方法实现

---

## 3. 表达式

### 3.1 指针算术

```
ptr_expr = ptr '+' offset
         | ptr '-' offset
         | ptr '+=' offset
         | ptr '-=' offset
         | ptr1 '-' ptr2
```

**说明**：
- `ptr`：指针表达式
- `offset`：偏移量，类型为 `usize`
- `ptr1 - ptr2`：指针间距离计算，返回 `usize`

---

## 4. 语句

### 4.1 测试单元

```
test_stmt = 'test' STRING '{' statements '}'
```

**说明**：
- `test`：测试关键字
- `STRING`：测试说明文字
- `statements`：测试函数体语句
- 可写在任意文件、任意作用域（顶层/函数内/嵌套块）

---

## 5. 类型转换

### 5.1 转换语法

```
safe_cast   = expr 'as' type
force_cast  = expr 'as!' type
```

**说明**：
- `as`：安全转换，只允许无精度损失的转换，编译期检查
- `as!`：强转，允许所有转换，包括可能有精度损失的，返回错误联合类型 `!T`

---

## 6. 原子操作

### 6.1 原子类型

```
atomic_type = 'atomic' type
```

**说明**：
- `atomic`：原子类型关键字
- `type`：基础类型（如 `i32`, `i64`, `u32`, `u64` 等）
- 所有读/写/复合赋值操作自动生成原子指令

---

## 7. 模块系统

> **详细语法说明**：详见 [uya.md](./uya.md#15-模块系统)

### 7.1 导出语法

```
export_decl = 'export' (fn_decl | struct_decl | interface_decl | const_decl | error_decl | extern_decl)
```

**导出示例**：
```uya
export fn public_function() i32 { ... }
export struct PublicStruct { ... }
export interface PublicInterface { ... }
export const PUBLIC_CONST: i32 = 42;
export error PublicError;
export extern printf(fmt: *byte, ...) i32;
```

### 7.2 导入语法

```
import_stmt = 'use' module_path [ 'as' ID ] ';'
module_path = ID { '.' ID }
```

**导入示例**：
```uya
use std.io;                    // 导入整个模块
use std.io.read_file;          // 导入特定函数
use std.io as io_module;       // 导入并重命名
```

**说明**：
- `export`：导出关键字，标记可导出的项
- `use`：导入关键字
- `module_path`：模块路径，使用 `.` 分隔，相对于项目根目录
- `alias`：可选别名
- 项目根目录是 `main` 模块，子目录路径映射到模块路径（如 `std/io/` → `std.io`）

---

## 8. 控制流

### 8.1 for 循环

> **详细语法说明**：详见 [uya.md](./uya.md#8-控制流)

```
for_stmt = 'for' expr '|' ID '|' '{' statements '}'           # 值迭代（只读）
         | 'for' expr '|' '&' ID '|' '{' statements '}'        # 引用迭代（可修改）
         | 'for' range '|' ID '|' '{' statements '}'           # 整数范围，有元素变量
         | 'for' expr '{' statements '}'                       # 丢弃元素，只循环次数
         | 'for' range '{' statements '}'                      # 整数范围，丢弃元素

range    = expr '..' [ expr ]
```

**说明**：
- `expr`：可迭代对象（数组、切片、迭代器等）
- `range`：整数范围表达式，如 `0..10` 或 `0..`（无限范围）
- 循环变量绑定形式：
  - `|ID|`：值迭代（只读），绑定元素值
  - `|&ID|`：引用迭代（可修改），绑定元素指针
  - 对于数组和切片，也可以使用 `|i|` 绑定索引（类型为 `usize`）
  - 省略变量绑定：丢弃元素，只循环次数

### 8.2 match 表达式

```
match_expr = 'match' expr '{' pattern_list '}'
pattern    = literal | ID | struct_pattern | error_pattern
```

**说明**：
- `match`：模式匹配关键字
- `pattern`：匹配模式（常量、变量绑定、结构体解构、错误类型等）
- `else`：必须放在最后，捕获所有未匹配的情况

---

## 9. 错误处理

> **详细语法说明**：详见 [uya.md](./uya.md#2-类型系统) 错误类型部分和 [uya.md](./uya.md#5-函数) 错误处理部分

### 9.1 错误类型

```
error_decl     = 'error' ID ';'                              # 预定义错误声明（可选）
error_type     = 'error' '.' ID                              # 错误类型引用（预定义或运行时错误）
```

**说明**：
- **预定义错误**（可选）：使用 `error ErrorName;` 在顶层声明，属于全局命名空间
- **运行时错误**：使用 `error.ErrorName` 语法直接创建，无需预先声明
- 两种错误类型在语法上使用相同的引用形式 `error.ErrorName`
- 错误类型属于错误联合类型 `!T` 的一部分

### 9.2 try/catch

```
unary_expr = ... | 'try' unary_expr  # try 是一元运算符
catch_op   = 'catch' [ '|' ID '|' ] '{' statements '}'  # catch 是后缀运算符
```

**说明**：
- `try`：错误传播和溢出检查关键字，是一元运算符（优先级 2，右结合）
- `catch`：错误捕获语法，是后缀运算符（优先级 1，左结合）
- 支持绑定错误变量 `|err|` 或不绑定
- `catch` 作为后缀运算符，可以附加在任何表达式之后
- `~`：按位取反运算符，是一元运算符（优先级 2，右结合）

---

## 10. 注释

```
line_comment   = '//' .* '\n'
block_comment  = '/*' .* '*/'
```

**说明**：
- `//`：行注释，到行尾
- `/* */`：块注释，可嵌套

---

## 符号说明

### 终结符

- `ID`：标识符（`[A-Za-z_][A-Za-z0-9_]*`）
- `NUM`：数字字面量（整数或浮点数）
- `STRING`：字符串字面量（`"..."`）
- `TEXT`：普通文本（字符串插值中的非插值部分）
- 关键字：`struct`, `const`, `var`, `fn`, `return`, `extern`, `true`, `false`, `if`, `while`, `break`, `continue`, `defer`, `errdefer`, `try`, `catch`, `error`, `null`, `interface`, `impl`, `atomic`, `max`, `min`, `export`, `use`, `as`, `as!`, `test`

### 非终结符

- `program`：程序（顶层声明序列）
- `declaration`：声明（函数、结构体、接口等）
- `statement`：语句
- `expr`：表达式
- `type`：类型
- `statements`：语句序列

### BNF 元符号

- `'...'`：字面量字符串（必须完全匹配）
- `[...]`：可选部分（0次或1次）
- `{...}`：重复0次或多次
- `(...)`：分组
- `|`：选择（或）
- `=`：产生式定义

### 运算符优先级（从高到低）

1. 后缀运算符：`.` `[]` `()` `[start:len]` `catch`
2. 一元运算符：`!` `-` `~` `&` `*` `try`
3. 类型转换：`as` `as!`
4. 乘除：`*` `/` `%` `*|` `*%`
5. 加减：`+` `-` `+|` `-|` `+%` `-%`
6. 位移：`<<` `>>`
7. 关系：`<` `>` `<=` `>=`
8. 相等：`==` `!=`
9. 按位与：`&`
10. 按位异或：`^`
11. 按位或：`|`
12. 逻辑与：`&&`
13. 逻辑或：`||`
14. 赋值：`=` `+=` `-=` `*=` `/=` `%=`

---

## 参考

- [uya.md](./uya.md) - 完整语言规范
- [comparison.md](./comparison.md) - 与其他语言的对比

