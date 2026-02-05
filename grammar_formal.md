# Uya 语言正式语法规范（Formal BNF）

本文档包含 Uya 语言的完整、无歧义的 BNF 语法定义，用于：
- 编译器/解析器实现
- 语言标准化参考
- 语法形式化验证

> **注意**：本文档是 [uya.md](./uya.md) 的补充，详细语法说明请参考主文档。  
> 对于日常开发和快速参考，请使用 [grammar_quick.md](./grammar_quick.md)。

---

## 完整语法汇总

### 程序结构

```
program        = { declaration }
declaration    = fn_decl | struct_decl | struct_method_block | union_decl | union_method_block
               | interface_decl | enum_decl | const_decl | error_decl | extern_decl | export_decl
               | import_stmt | test_stmt | macro_decl
```

### 函数声明

```
fn_decl        = 'fn' ID [ '<' type_param_list '>' ] '(' [ param_list ] ')' type '{' statements '}'
param_list     = param { ',' param }
param          = ID ':' type
type_param_list = type_param { ',' type_param }
type_param     = ID [ ':' constraint_list ]
constraint_list = ID { '+' ID }
```

**说明**：
- 泛型函数语法：`fn max<T: Ord>(a: T, b: T) T { ... }`
- 类型参数列表可选，使用尖括号 `<T>` 或 `<T: Constraint>`
- 多约束使用 `+` 连接：`<T: Ord + Clone + Default>`

### 结构体声明

```
struct_decl    = 'struct' ID [ '<' type_param_list '>' ] [ ':' interface_list ] '{' struct_body '}'
interface_list = ID { ',' ID }
struct_body    = ( field_list | method_list | field_list method_list )
field_list     = field { ',' field }
field          = ID ':' type
method_list    = method_decl { method_decl }
method_decl    = fn_decl  # self 参数必须为 &Self 或 &StructName

# 结构体外部方法定义（方式2）
struct_method_block = ID '{' method_list '}'
type_param_list = type_param { ',' type_param }
type_param     = ID [ ':' constraint_list ]
constraint_list = ID { '+' ID }
```

**说明**：
- **接口声明**：结构体定义时可以声明实现的接口，语法为 `struct StructName : InterfaceName1, InterfaceName2 { ... }`
  - 接口声明是可选的，如果结构体不实现接口，可以不声明
  - 接口方法作为结构体方法定义，可以在结构体内部或外部方法块中定义
- **方式1：结构体内部定义**：方法定义在结构体花括号内，与字段定义并列
  - 语法：`struct StructName : InterfaceName { field: Type, fn method(self: &Self) ReturnType { ... } }`
- **方式2：结构体外部定义**：使用块语法在结构体定义后添加方法
  - 语法：`StructName { fn method(self: &Self) ReturnType { ... } }`
- `self` 参数必须显式声明，使用指针：`self: &Self` 或 `self: *StructName`
- 推荐使用 `Self` 占位符：`self: &Self` 更简洁
- 详细语法说明见 [uya.md](./uya.md#29-扩展特性) 结构体方法部分

### 接口声明

```
interface_decl = 'interface' ID [ '<' type_param_list '>' ] '{' (method_sig | interface_name)+ '}'  # 方法签名或组合接口名
method_sig     = 'fn' ID '(' [ param_list ] ')' type ';'
interface_name = ID ';'  # 组合接口名，用分号分隔
type_param_list = type_param { ',' type_param }
type_param     = ID [ ':' constraint_list ]
constraint_list = ID { '+' ID }
```

**说明**：
- `method_sig+` 表示一个或多个方法签名（BNF 扩展语法，等价于 `method_sig { method_sig }`）
- `interface_name` 表示接口组合，在接口体中直接列出被组合的接口名，用分号分隔
- 接口必须至少包含一个方法签名或组合接口名
- 接口实现：结构体在定义时声明接口（`struct StructName : InterfaceName { ... }`），接口方法作为结构体方法定义
- 详细语法说明见 [uya.md](./uya.md#6-接口interface)

### 联合体声明

```
union_decl     = 'union' ID [ ':' interface_list ] '{' union_body '}'
union_body     = ( field_list | method_list | field_list method_list )
union_method_block = ID '{' method_list '}'  # 联合体外部方法定义（同结构体方式2）
```

**说明**：
- 联合体语法与结构体类似，但所有变体共享同一内存区域
- 变体命名遵循标识符规则，创建语法：`UnionName.variant(expr)`
- 访问必须通过模式匹配（`match`）或编译器可证明的已知标签直接访问
- 详细语法说明见 [uya.md](./uya.md#45-联合体union)

### 枚举声明

```
enum_decl      = 'enum' ID [ ':' underlying_type ] '{' enum_variant_list '}'
underlying_type = base_type  # 底层类型，必须是整数类型（i8, i16, i32, i64, u8, u16, u32, u64）
enum_variant_list = enum_variant { ',' enum_variant }
enum_variant   = ID [ '=' NUM ]  # 枚举变体，可选显式赋值
```

**说明**：
- 枚举声明在顶层（与函数、结构体定义同级）
- 默认底层类型为 `i32`（如果未指定）
- 枚举变体可以显式指定值（使用 `=` 后跟整数常量）
- 枚举值在编译期确定，类型安全
- 详细语法说明见 [uya.md](./uya.md#2-类型系统) 枚举类型部分

### 类型系统

```
type           = base_type | pointer_type | array_type | slice_type 
               | struct_type | union_type | interface_type | enum_type | tuple_type
               | atomic_type | error_union_type | function_pointer_type | extern_type

base_type      = 'i8' | 'i16' | 'i32' | 'i64' | 'u8' | 'u16' | 'u32' | 'u64'
               | 'f32' | 'f64' | 'bool' | 'byte' | 'void' | 'usize'
pointer_type   = '&' type | '*' type
array_type     = '[' type ':' NUM ']'
slice_type     = '&[' type ']' | '&[' type ';' NUM ']'
struct_type    = ID [ '<' type_arg_list '>' ]
union_type     = ID [ '<' type_arg_list '>' ] | 'union' ID  # 联合体类型；'union' ID 用于外部 C 联合体
interface_type = ID [ '<' type_arg_list '>' ]
type_arg_list  = type { ',' type }
enum_type      = ID  # 枚举类型，通过枚举声明定义
tuple_type     = '(' type { ',' type } ')'  # 元组类型，如 (i32, f64)
atomic_type    = 'atomic' type
error_union_type = '!' type  # 错误联合类型，表示 T | Error
function_pointer_type = 'fn' '(' [ param_type_list ] ')' type  # 函数指针类型
param_type_list = type { ',' type }  # 函数指针类型的参数类型列表（无参数名）
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

# defer/errdefer 块内禁止：return、break、continue 等控制流语句
# 允许：表达式、赋值、函数调用、语句块
# 替代方案：使用变量记录状态，在 defer/errdefer 外处理控制流
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
postfix_expr   = primary_expr { '.' (ID | NUM) | '[' expr ']' | '(' arg_list ')' | slice_op | catch_op }
                # '.' NUM 用于元组字段访问，如 tuple.0, tuple.1
catch_op       = 'catch' [ '|' ID '|' ] '{' statements '}'
primary_expr   = ID | NUM | STRING | 'true' | 'false' | 'null'
               | builtin_expr
               | struct_literal | array_literal | tuple_literal | enum_literal | union_literal
               | match_expr | '(' expr ')'
builtin_expr   = '@' ('sizeof' | 'alignof' | 'len' | 'max' | 'min' | 'params')
               # @size_of(T)、@align_of(T)、@len(expr) 为调用形式；@max、@min 为值形式；@params 为函数体内参数元组（uya.md §5.4）
union_literal  = ID '.' ID '(' expr ')'  # 联合体创建，如 IntOrFloat.i(42)、NetworkPacket.ipv4([...])
```

### 特殊表达式

```
range          = expr '..' [ expr ]
slice_op       = '[' expr ':' expr ']'  // 切片操作，完整语法为 &expr[start:len]
struct_literal = ID '{' field_init_list '}'
field_init_list = [ field_init { ',' field_init } ]
field_init     = ID ':' expr
array_literal  = '[' expr_list ']' | '[' expr ':' expr ']'  # 数组字面量；重复形式 [value: N] 与类型 [T: N] 一致；空列表 [] 表示未初始化（仅当变量类型已明确时可用）
tuple_literal  = '(' expr_list ')'  # 元组字面量，如 (10, 20, 30)
enum_literal   = ID '.' ID  # 枚举字面量，如 Color.RED, HttpStatus.OK
expr_list      = [ expr { ',' expr } ]  # 表达式列表，可以为空（空数组字面量 []）
arg_list       = [ expr { ',' expr } [ ',' '...' ] ]  # 可变参数转发：末尾 ... 表示转发剩余参数
pattern_list   = pattern '=>' expr { ',' pattern '=>' expr } [ ',' 'else' '=>' expr ]
pattern        = literal | ID | '_' | struct_pattern | tuple_pattern | enum_pattern
               | union_pattern | error_pattern
struct_pattern = ID '{' field_pattern_list '}'
field_pattern_list = [ field_pattern { ',' field_pattern } ]
field_pattern  = ID ':' (literal | ID | '_')
tuple_pattern  = '(' tuple_pattern_list ')'  # 元组模式，如 (x, _, z)
tuple_pattern_list = pattern { ',' pattern }  # 用于元组模式的模式列表
enum_pattern   = ID '.' ID  # 枚举模式，如 Color.RED, HttpStatus.OK
union_pattern  = '.' ID [ '(' (ID | '_') ')' ]  # 联合体模式，如 .i(x)、.f(_)
error_pattern  = 'error' '.' ID
literal        = NUM | STRING | 'true' | 'false' | 'null'
```

### 模块系统

```
export_decl    = 'export' (fn_decl | struct_decl | union_decl | interface_decl | enum_decl
               | const_decl | error_decl | extern_decl)
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
  - `export extern printf(fmt: *byte, ...) i32;`（导出外部 C 函数声明）
  - `export extern my_callback(x: i32, y: i32) i32 { ... }`（导出函数给 C）
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
extern_decl    = 'extern' 'fn' ID '(' [ param_list ] ')' type (';' | '{' statements '}')
               | 'extern' 'union' ID '{' field_list '}'  # 外部 C 联合体声明
```

**说明**：
- `extern fn name(...) type;` - 声明外部 C 函数（导入，供 Uya 调用）
- `extern fn name(...) type { ... }` - 导出 Uya 函数为 C 函数（导出，供 C 调用）
  - 导出的函数可以使用 `&name` 获取函数指针，传递给需要函数指针的 C 函数
  - 函数必须使用 C 兼容的类型（FFI 指针类型 `*T`、基本类型等）
- 所有 `struct` 统一使用 C 内存布局，无需 `extern` 关键字
- 结构体可以包含所有类型（包括切片、interface 等），编译器自动生成对应的 C 兼容布局

### 错误处理

```
error_decl     = 'error' ID ';'                              # 预定义错误声明（可选）
error_type     = 'error' '.' ID                              # 错误类型引用（预定义或运行时错误）
```

**说明**：
- **预定义错误**（可选）：使用 `error ErrorName;` 在顶层声明，属于全局命名空间
- **运行时错误**：使用 `error.ErrorName` 语法直接创建，无需预先声明
- 两种错误类型在语法上使用相同的引用形式 `error.ErrorName`
- **error_id 稳定性**：`error_id = hash(error_name)`，相同错误名在任意编译中映射到相同 `error_id`；hash 冲突时编译器报错
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

**泛型语法说明**：
- 泛型语法已整合到主要声明中（见[函数声明](#函数声明)、[结构体声明](#结构体声明)、[接口声明](#接口声明)）
- 使用尖括号 `<T>`，约束紧邻参数 `<T: Ord>`，多约束连接 `<T: Ord + Clone + Default>`
- **函数泛型示例**：`fn max<T: Ord>(a: T, b: T) T { ... }`
- **结构体泛型示例**：`struct Vec<T: Default> { ... }`
- **接口泛型示例**：`interface Iterator<T> { ... }`
- **类型参数使用示例**：`Vec<i32>`, `Iterator<String>`

**显式宏语法（可选特性）**：
```
macro_decl     = [ 'export' ] 'mc' ID '(' [ param_list ] ')' return_tag '{' statements '}'
param_list     = param { ',' param }
param          = ID ':' param_type [ '=' default_value ]
param_type     = 'expr' | 'stmt' | 'type' | 'pattern' | 'ident'
return_tag     = 'expr' | 'stmt' | 'struct' | 'type'
macro_call     = ID '(' arg_list ')'
```

**说明**：
- `mc` 关键字用于声明宏
- `export mc` 可导出宏供其他模块使用
- 参数类型：`expr`（表达式）、`stmt`（语句）、`type`（类型）、`pattern`（模式）、`ident`（标识符）
- 返回标签：`expr`（表达式）、`stmt`（语句）、`struct`（结构体成员）、`type`（类型标识符）
- 参数默认值：支持为参数指定默认值，语法与函数参数默认值相同
- 宏调用语法与普通函数调用完全一致
- 跨模块宏导入：`use module.macro_name;`
- 详细说明见 [uya.md](./uya.md#25-宏系统)

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
defer errdefer try catch error null interface atomic union
export use as as! test
```

**说明**：内置函数以 `@` 开头（`@size_of`、`@align_of`、`@len`、`@max`、`@min`），非关键字，见 `builtin_expr`。

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
- 结果类型为 `[i8: N]`，宽度由格式字符串最大可能长度常量求值得出

---

## 2. 类型系统

### 2.1 结构体方法

> **详细语法说明**：详见 [uya.md](./uya.md#29-扩展特性) 结构体方法部分

```
struct_decl    = 'struct' ID [ '<' type_param_list '>' ] [ ':' interface_list ] '{' struct_body '}'
struct_body    = ( field_list | method_list | field_list method_list )
struct_method_block = ID '{' method_list '}'  # 结构体外部方法定义
method_list    = method_decl { method_decl }
method_decl    = fn_decl  # self 参数必须为 &Self 或 &StructName
type_param_list = type_param { ',' type_param }
type_param     = ID [ ':' constraint_list ]
constraint_list = ID { '+' ID }
```

**说明**：
- **方式1：结构体内部定义**：方法定义在结构体花括号内，与字段定义并列
  - 语法：`struct StructName { field: Type, fn method(self: &Self) ReturnType { ... } }`
- **方式2：结构体外部定义**：使用块语法在结构体定义后添加方法
  - 语法：`StructName { fn method(self: &Self) ReturnType { ... } }`
- `self` 参数必须显式声明，使用指针：`self: &Self` 或 `self: *StructName`
- 推荐使用 `Self` 占位符：`self: &Self` 更简洁、与接口实现语法一致
- 方法调用语法：`obj.method()` 展开为 `StructName_method(&obj)`（传递指针，不移动）

### 2.2 接口类型

```
interface_decl = 'interface' ID [ '<' type_param_list '>' ] '{' (method_sig | interface_name) { method_sig | interface_name } '}'
method_sig     = 'fn' ID '(' [ param_list ] ')' type ';'
interface_name = ID ';'  // 组合接口名，用分号分隔
interface_type = ID [ '<' type_arg_list '>' ]  // 在类型标注中使用接口名称，支持泛型参数
type_param_list = type_param { ',' type_param }
type_param     = ID [ ':' constraint_list ]
constraint_list = ID { '+' ID }
type_arg_list  = type { ',' type }
```

**说明**：
- `interface_decl`：接口声明语法（详见[接口声明](#接口声明)部分）
- `interface_type`：接口类型标注，使用接口名称（ID）
- `method_sig`：方法签名
- `param`：参数定义，格式为 `param_name: type`
- 接口实现：结构体在定义时声明接口（`struct StructName : InterfaceName { ... }`），接口方法作为结构体方法定义（详见[结构体声明](#结构体声明)部分）

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
export_decl = 'export' (fn_decl | struct_decl | union_decl | interface_decl | enum_decl | const_decl | error_decl | extern_decl)
```

**导出示例**：
```uya
export fn public_function() i32 { ... }
export struct PublicStruct { ... }
export interface PublicInterface { ... }
export const PUBLIC_CONST: i32 = 42;
export error PublicError;
export extern printf(fmt: *byte, ...) i32;
export extern my_callback(x: i32, y: i32) i32 { ... }  // 导出函数给 C
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
- 关键字：`struct`, `const`, `var`, `fn`, `return`, `extern`, `true`, `false`, `if`, `while`, `break`, `continue`, `defer`, `errdefer`, `try`, `catch`, `error`, `null`, `interface`, `atomic`, `export`, `use`, `as`, `as!`, `test`
- 内置函数（以 `@` 开头）：`@size_of`, `@align_of`, `@len`, `@max`, `@min`

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
- [grammar_quick.md](./grammar_quick.md) - 语法速查手册
- [comparison.md](./comparison.md) - 与其他语言的对比

