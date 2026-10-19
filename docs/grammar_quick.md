# Uya 语法速查手册（Quick Reference）

> **版本**：与 [uya.md](./uya.md) 0.49.55 同步（2026-10-19）

本文档是 Uya 语言的快速参考手册，包含精简语法定义、常用代码模式和速查表。

> **注意**：本文档是 [uya.md](./uya.md) 的补充，适合日常开发和快速查阅。  
> 对于完整的、无歧义的 BNF 语法定义，请参考 [grammar_formal.md](./grammar_formal.md)。

---

## 一、核心语法（30秒掌握）

### 基本结构

```uya
// 函数定义（返回类型可为任意类型，含切片 &[T]、错误联合 !T 或 !&[byte]）
fn add(a: i32, b: i32) i32 {
    return a + b;
}

// 结构体定义
struct Point {
    x: f32,
    y: f32
}

// 联合体定义
union IntOrFloat {
    i: i32,
    f: f64
}

// 变量声明
const x: i32 = 42;
var y: i32 = 10;
```

### 字符串与字符转义（**0.49.42**）

普通 **`"..."`** 与插值字符串的文本段支持 **`\\xHH`**（两位的十六进制字节）、**`\\uXXXX`**（四位 BMP 码点 → UTF-8；代理区非法）。字符 **`'...'`** 另支持 **`\\xHH`** 与 **`\\uXXXX`**（后者仅当数值 **≤255**）。原始字符串 **`` `...` ``** 无转义。

### 文件开头 shebang（**0.49.52**）

源文件首两个字节为 **`#!`** 时，第一行按 shebang 注释处理；该规则仅在文件开头生效。示例：`#!/usr/bin/env -S uya run`。

---

## 二、类型系统速查

| 类型 | 写法 | 示例 | 说明 |
|------|------|------|------|
| **整数** | `i8` `i16` `i32` `i64`<br>`u8` `u16` `u32` `u64` `usize` | `const x: i32 = 42;`<br>`const hex: i32 = 0xFF;`<br>`const oct: i32 = 0o755;`<br>`const bin: i32 = 0b1010;`<br>`const big: i32 = 1_000_000;`<br>`const small: i8 = 100i8;`<br>`const mask: u8 = 0xFFu8;` | 有符号/无符号整数<br>支持十六进制 (`0xFF`)、八进制 (`0o755`)、二进制 (`0b1010`)<br>支持下划线分隔符 (`1_000_000`)<br>支持类型后缀：`i8/i16/i32/i64/u8/u16/u32/u64/usize`（如 `100i8`、`0xFFu8`） |
| **浮点** | `f32` `f64` | `const pi: f64 = 3.14;`<br>`const e: f64 = 2.718_281_828;`<br>`const v32: f32 = 1.5f32;` | 单/双精度浮点数<br>支持下划线分隔符<br>支持类型后缀：`f32`/`f64`（如 `1.5f32`、`3.14f64`） |
| **布尔** | `bool` | `const flag: bool = true;` | 布尔值 |
| **数组** | `[T: N]` | `const arr: [i32: 5] = [1,2,3,4,5];`<br>`var buf: [byte: 8] = "hi"; buf = "xy";`<br>`var buf: [i32: 100] = [];` | 固定长度数组；字符串字面量可初始化/赋值 **`[byte: N]`**（**`N ≥` 可见字节+1**，自动 `\0`）；左值可为 **`obj.f` / `a.b.c`**（**0.49.43**）；`[]` 表示未初始化 |
| **切片** | `&[T]` `&[const T]` `&[T: N]` | `const slice: &[i32] = &arr[2:5];`<br>`const sub: &[byte] = &"hello"[0:3];`（**0.49.41**）<br>`var s: &[const byte] = "hi";`（**0.49.43**） | 动态/已知长度切片；字面量子区间仍用 **`&"..."[i:j]`**；字符串字面量赋给切片须 **`&[const byte]`**（**0.49.43**） |
| **指针** | `&T` `&const T` `*T` `*const T` | `const ptr: &i32 = &x;`<br>`const s: &byte = "hello";`<br>`const p: *byte = "hi";` | Uya指针/只读指针/FFI指针；字符串字面量可赋给 `&byte`/`*byte`（自动 `\0` 结尾） |
| **结构体** | `StructName`<br>`StructName<T>` | `const p: Point = Point{x: 1.0, y: 2.0};`<br>`const vec: Vec<i32> = ...;` | 结构体类型，支持泛型参数 |
| **联合体** | `UnionName` | `const v: IntOrFloat = IntOrFloat.i(42);` | 标签联合体，编译期证明安全 |
| **接口** | `InterfaceName`<br>`InterfaceName<T>` | `const writer: IWriter = ...;`<br>`const iter: Iterator<String> = ...;` | 接口类型，支持泛型参数 |
| **元组** | `(T1, T2, ...)` | `const t: (i32, f64) = (10, 3.14);` | 元组类型 |
| **错误联合** | `!T` | `fn may_fail() !i32 { ... }`<br>`fn encode() !&[byte] { ... }` | 可能返回错误；可与切片组合为返回值 `!&[byte]` |
| **原子类型** | `atomic T` | `value: atomic i32` | 原子类型 |
| **函数指针** | `fn(...) type` | `type Func = fn(i32, i32) i32;` | 函数指针类型 |
| **SIMD 向量/掩码** | `@vector(T, N)`<br>`@mask(N)` | `type Vec4i32 = @vector(i32, 4);`<br>`const lt: @mask(4) = u < v;`<br>`const neg: Vec4i32 = -u;`<br>`const w: Vec4f32 = @vector.splat(1.0f32);`<br>`const chunk: @vector(u8,16) = @vector.load(&buf[i]);`<br>`@vector.store(&buf[0], w);`<br>`const mix: Vec4i32 = @vector.select(lt, a, b);`<br>`const s: i32 = @vector.reduce_add(u);`<br>`const p: i32 = @vector.reduce_mul(v);`<br>`const mn: i32 = @vector.reduce_min(m);`<br>`const mx: i32 = @vector.reduce_max(n);` | 向量算术/比较/位运算；整数向量 `%`；有符号整数向量 `+|`/`-|`/`*|`；整数向量 `+%`/`-%`/`*%`；一元 `-`（整数/浮点元素）、`~`（仅整数元素）；`@vector.splat` / **`@vector.load` / `@vector.store` / `@vector.select` / `@vector.reduce_add` / `@vector.reduce_mul` / `@vector.reduce_min` / `@vector.reduce_max`**（**0.49.33** / **0.49.34** / **0.49.35** / **0.49.36** / **0.49.38** / **0.49.39**；`load`/`select` 目标 `@vector` 由上下文确定；`store` 为 **`void`**；`reduce_add`/`reduce_mul`/`reduce_min`/`reduce_max` 返回元素标量） |
| **异步帧类型** | `@frame(fn)`<br>`@frame(fn<T>)` | `var f: @frame(my_async_fn);`<br>`f.start(...);`<br>`const p: Poll<!i32> = f.poll(&w);`<br>`f.stop();` | 暴露 `@async_fn` 的状态机帧类型；高层方法 `start/poll/stop`；禁止按值移动/赋值/传参/返回；允许无初始化声明（**v0.9.3**） |

---

## 三、控制流速查

### if-else

```uya
if x > 0 {
    // ...
} else {
    // ...
}
```

### while 循环

```uya
var i: i32 = 0;
while i < 10 {
    // ...
    i = i + 1;
}
```

### for 循环

```uya
// 值迭代（只读）
for arr |v| {
    // 使用 v
}

// 引用迭代（可修改）
for arr |&ptr| {
    // 可以修改 *ptr
}

// 整数范围迭代
for 0..10 |i| {
    // i 从 0 到 9
}

// 只循环次数（不绑定变量）
for 0..10 {
    // 只执行10次
}
```

### match 匹配

```uya
match value {
    1 => handle_one(),
    error.Err => handle_err(),
    else => default()
};

// 联合体模式匹配（必须处理所有变体）
match union_value {
    .i(x) => printf("整数: %d\n", x),
    .f(x) => printf("浮点: %f\n", x)
}
```

---

## 四、错误处理速查

### 定义错误

```uya
// 预定义错误（可选）
error MyError;

// 运行时错误（无需预定义）
// 直接使用 error.ErrorName
```

**error_id 稳定性**：`error_id = hash(error_name)`，相同错误名在任意编译中映射到相同 `error_id`；hash 冲突时编译器报错并提示冲突名称。

**错误名字符串**：`@error_name(err)` 可返回语言级命名错误的名字（不带 `error.` 前缀）；对未知或 `@syscall` 错误，当前统一回退为 `"UnknownError"`。

### 返回错误

```uya
fn may_fail() !i32 {
    if condition {
        return error.MyError;
    }
    return 42;
}
```

### 传播错误

```uya
const x: i32 = try may_fail();  // 自动传播错误
```

### 捕获错误

```uya
const x: i32 = may_fail() catch |err| {
    // 处理错误
    return 0;
};
```

---

## 五、常用模式模板

### 函数定义模板

```uya
// 内部函数（生成的 C 代码添加 static）
fn name(param: Type) ReturnType {
    // 函数体
    return value;
}

// 导出函数（生成的 C 代码不添加 static，带 uya_ 前缀）
export fn public_function(param: Type) ReturnType {
    // 函数体
    return value;
}

// 外部 C 函数声明
extern fn c_function(param: *byte) i32;

// 外部 C 函数实现（Uya 实现，以裸函数名导出，不带 uya_ 前缀）
extern fn my_wrapper(param: *byte) i32 {
    // Uya 实现代码
    return 0;
}

// 导出外部 C 函数声明（无函数体）→ 链接到 C 标准库
export extern fn malloc(size: usize) *void;

// 导出外部 C 函数实现（有函数体）→ Uya 实现，以裸函数名导出
export extern fn strcmp(s1: &const byte, s2: &const byte) i32 {
    // Uya 实现代码
    return 0;
}

// extern "libc" 语法（0.43 新增）：显式声明 C 标准库函数
// byte 直接对应 C 的 char，与 C 字符串兼容
extern "libc" fn strlen(s: &byte) usize;
extern "libc" fn atoi(s: &byte) i32;
extern "libc" fn printf(fmt: &byte, ...) i32;

// extern 变量支持（0.43 新增）：导入/导出 C 全局变量
// 导入 C 标准库全局变量
extern const errno: i32;           // 只读：extern const int errno;
extern var optind: i32;            // 可变：extern int optind;
extern const stdout: *void;        // C: extern FILE *stdout;

// 导出 Uya 变量给 C
export const VERSION: &byte = "1.0.0";  // C: const char *VERSION = "1.0.0";
export var debug_mode: i32 = 0;         // C: int debug_mode = 0;

// 链接到 C 库定义的变量（不生成代码）
export extern const ENOENT: i32;

// 可能失败的函数
fn name(param: Type) !ReturnType {
    if error_condition {
        return error.ErrorName;
    }
    return value;
}

// 泛型函数
fn max<T: Ord>(a: T, b: T) T {
    if a > b { return a; }
    return b;
}

// 函数属性（可选，写在 export 之后、fn 之前；顺序固定）
@async_fn
fn fetch(handle: i32) Future<!i32> {
    return handle;
}

@align(64)          // 帧对齐（仅对 @async_fn 生成的帧结构体生效），必须写在 @async_fn 之前
@async_fn
fn aligned_fetch(handle: i32) Future<!i32> {
    return handle;
}

// @naked_fn：无标准序言/尾声，只用于极底层函数（见 lib/libc/setjmp.uya 的
// `export @naked_fn fn setjmp(env: &jmp_buf) i32 { ... }`）

// 属性顺序：'export' → 'opaque'（仅 struct） → '@align(N)' → '@async_fn' | '@naked_fn' → 声明关键字
// 'extern' 函数不能加 @async_fn / @naked_fn；'@align' 不是内置函数，只能出现在声明位置
```

### 结构体定义模板

```uya
// 基本结构体
struct Name {
    field1: Type1,
    field2: Type2
}

// 结构体带方法（内部定义）
struct Name {
    field: Type,
    
    fn method(self: &Self) ReturnType {
        // 方法体
    }
}

// 结构体方法（外部定义）
struct Name {
    field: Type
}

Name {
    fn method(self: &Self) ReturnType {
        // 方法体
    }
}

// 实例方法参数名不限，只要首参类型是 &Self / &Name
Name {
    fn method2(this: &Self) ReturnType {
        // 方法体
    }
}

// 静态方法：无 self，使用 Type.method(...) 调用
struct Factory {
    value: i32
}

Factory {
    fn new() Self {
        return Factory{ value: 1 };
    }
}

const f: Factory = Factory.new();

// 统一方法命名空间与链式调用：Type.make().next().finish()
// 实例方法也支持按类型显式传 receiver：Type.method(value, ...)

// async 方法也可以写在结构体内部或外部方法块
struct AsyncName {
    field: i32,

    @async_fn
    fn next(self: &Self) Future<!i32> {
        return self.field;
    }
}

// 泛型结构体
struct Vec<T: Default> {
    data: &T,
    len: i32,
    cap: i32
}

// 泛型方法（0.47 新增）
struct Container<T> {
    value: T,
    
    // 泛型方法：独立类型参数 U
    fn as_type<U>(self: &Self) U {
        return self.value as U;
    }
}

// 调用泛型方法
const c: Container<i32> = Container<i32>{ value: 42 };
const v: i64 = c.as_type<i64>();  // 显式指定类型参数
const same: i32 = Container<i32>{ value: 7 }.as_type<i32>();
// 若返回值本身仍支持后缀操作，则可继续写成 obj.method<T>().next()
```

### 联合体定义模板

```uya
// 基本联合体
union Name {
    variant1: Type1,
    variant2: Type2
}

// 创建：UnionName.variant(expr)
const v: IntOrFloat = IntOrFloat.i(42);
const f: IntOrFloat = IntOrFloat.f(3.14);

// 访问：必须 match 或已知标签直接访问
match v {
    .i(x) => printf("%d\n", x),
    .f(x) => printf("%f\n", x)
}
```

### 接口定义和实现模板

```uya
// 接口定义
interface IWriter {
    fn write(self: &Self, buf: *byte, len: i32) i32;
}

// async 接口签名
interface IAsyncReader {
    @async_fn
    fn read(self: &Self, n: usize) Future<!usize>;
}

// 接口实现
struct MyStruct : IWriter {
    field: Type,
    
    fn write(self: &Self, buf: *byte, len: i32) i32 {
        // 实现
        return len;
    }
}

// 泛型接口
interface Iterator<T> {
    fn next(self: &Self) union Option<T>;
}
```

### 枚举定义模板

```uya
enum Color {
    Red,
    Green,
    Blue
}

// 带显式值
enum HttpStatus : u16 {
    Ok = 200,
    NotFound = 404,
    Error = 500
}
```

---

## 六、运算符优先级

> 完整说明：详见 [uya.md](./uya.md#运算符)

下表按 `src/parser/expressions.uya` 的实际解析顺序列出（`parser_parse_expression` → `assign_expr` → `pipeline_expr` → `or_expr` → … → `postfix_expr`）；**高 → 低**：

| 级别 | 运算符 | 结合性 | 说明 |
|------|--------|--------|------|
| 1 | `()` `.` `[]` `[start:len]` | 左 | 调用、字段/元组下标访问、下标、切片（`postfix_expr`） |
| 2 | `-` `!` `~` `&` `*`（一元） | 右 | 取负、逻辑非、按位取反、取址、解引用（`unary_expr`） |
| 3 | `as` `as!` | — | 类型转换，比乘除更紧；`-x as i64` 即 `(-x) as i64`（`cast_expr`） |
| 4 | `*` `/` `%` `*|` `*%` | 左 | 乘、除、取模、饱和乘法、包装乘法 |
| 5 | `+` `-` `+|` `-|` `+%` `-%` | 左 | 加、减、饱和加减、包装加减 |
| 6 | `<<` `>>` | 左 | 左移、右移 |
| 7 | `<` `>` `<=` `>=` | 左 | 比较 |
| 8 | `==` `!=` | 左 | 相等性 |
| 9 | `&` | 左 | 按位与 |
| 10 | `&&` | 左 | 逻辑与 |
| 11 | `^` | 左 | 按位异或 |
| 12 | `\|` | 左 | 按位或 |
| 13 | `\|\|` | 左 | 逻辑或 |
| 14 | `\|>` | 左 | 类型化管道（仅 `Pipeline` / `!Pipeline`，见下） |
| 15 | `=` `+=` `-=` `*=` `/=` `%=` | 右 | 赋值与复合赋值（最低优先级） |

- `&` / `^` / `|` 只接受整数操作数，`&&` / `||` 只接受 `bool`；混用会被类型检查拒绝，因此第 9–13 级的相对次序在合法程序中通常不可见
- `try expr` 位于一元级，**操作数按「相对表达式」解析**：`try a + b` 即 `try (a + b)`，无需加括号。`try` 传播 `!T`；整数算术操作数按 checked 求值（溢出 → `error.Overflow`，除零 → `error.DivisionByZero`）。`catch` 是 cast 级后缀，就地处理整条算术要写 `(a + b) catch |e| { … }`
- `catch` 不是独立优先级：它是 `expr catch [|err|] { ... }` 的**后缀**，写在 `as` / `as!` 之后

### 区间契约 `@range(lo, hi)`（**0.49.55**）

声明参数 / 局部变量 / 返回值的取值区间，供 `--strict-overflow` 证明器使用。
属**声明属性**，语义是「声明 + **运行时验证**」：静态可证处检查被优化掉，违约则由 `__builtin_trap()` 终止（不会静默回绕）。

```uya
fn advance(line: i32 @range(0, 1000000),
           off: i32 @range(0, 1000)) i32 @range(0, 1001000) {
    return line + off;
}

fn count_up(n: i32 @range(0, 1000000)) i32 @range(0, 1000000) {
    var c: i32 @range(0, 1000000) = 0;   // 局部计数器上界
    while c < n { c = c + 1; }
    return c;
}
```

`lo`/`hi` 为整型常量表达式，支持 `@max`/`@min`。

### 类型化管道 `|>`（**0.49.54**）

```uya
use std.process;

fn run() !void {
    const args: [&const byte: 1] = ["src"];
    try (pipeline()
        |> cmd_argv("rg", &args[0:1])
        |> stdout_file("out.txt")
        |> check());
}
```

- **语法**：`pipeline_expr = or_expr { '|>' postfix_expr }`，左结合；右侧只能是「最外层是调用」的后缀表达式（`o |> f(a, b)` 等价于 `f(o, a, b)`）
- **类型要求**（`src/checker/check_expr_extra.uya:793-870`）：
  - 左侧必须是 `Pipeline`（`std.process` 的 `export opaque struct Pipeline`）或 `!Pipeline`
  - 右侧被调用函数的**第一个参数**必须是 `Pipeline`；**不能**是带隐式 `self` receiver 的实例方法调用
  - 左侧为 `!Pipeline` 时按 try-forward 处理（等价 `f(try lhs, ...)`），整体类型为 `!R`，且只能在返回错误联合类型的函数（或返回 `Future<!T>` 的 `@async_fn`）中使用
  - `Pipeline` 是 move-only：一条链只消费最左侧变量一次，链尾 sink 之后再接 `|>` 是错误
- ✅ 正例：`pipeline() |> cmd_argv("ls", &empty[0:0]) |> check()`
- ❌ 负例：`1 |> check()`（左侧不是 `Pipeline`）；`p |> sink() |> again()`（sink 已返回非 `Pipeline`）；`p |> s.instance_method()`（隐式 self receiver）

---

## 七、模块系统速查

### 导出

```uya
export fn public_function() i32 { ... }
export struct PublicStruct { ... }
export opaque struct Resource { handle: usize }
export interface PublicInterface { ... }
export const PUBLIC_CONST: i32 = 42;
export error PublicError;
export mc public_macro() expr { ... }  // 导出宏
```

### 导入

```uya
// 导入整个模块
use std.io;

// 导入特定项
use std.io.read_file;

// 按文件模块导入特定项（兼容目录模块写法）
use std.io.file.read_file;

// 导入并重命名
use std.io as io_module;

// 导入宏
use math_macros.square;
```

**同目录文件合并规则**：
- 同一目录下的所有 `.uya` 文件都属于同一个模块
- 模块路径由目录路径决定，不包含文件名
- 例如：`std/io/file.uya` 和 `std/io/stream.uya` 都属于 `std.io` 模块
- 使用：`use std.io.fopen;` 或 `use std.io.fgetc;`（不需要 `std.io.file.fopen`）

**单文件模块兼容规则**：
- 每个 `.uya` 文件也可用包含文件名的模块路径导入
- 例如：`std/io/file.uya` 也可写 `use std.io.file.fopen;`
- 目录模块写法和文件模块写法都兼容；整体模块导入遇到同名目录和同名文件时优先目录模块

---

## 八、FFI（外部函数接口）速查

### 声明外部 C 函数

```uya
extern printf(fmt: *byte, ...) i32;
```

### 可变参数与 @params（uya.md §5.4）

```uya
// Uya 可变参数函数
fn log_error(fmt: *byte, ...) void {
    printf("ERROR: ");
    printf(fmt, ...);  // 使用 ... 转发可变参数
}

fn add_two(a: i32, b: i32) i32 {
    const p: (i32, i32) = @params;  // 所有命名参数作为元组（必须显式写元组类型）
    return p.0 + p.1;
}

fn mul_two(x: i32, y: i32) i32 {
    return @params.0 * @params.1;
}
```

- 声明：`...` 为参数列表最后一项
- 转发：`printf(fmt, ...)` 将可变参数转发
- `@params`：函数体内把**已命名参数**作为元组访问（`@params.0`、`@params.1` 或用 `const p: (T1, T2) = @params;` 解构）；元组不能直接 `for` 迭代
- `@va_start` / `@va_end` / `@va_arg` / `@va_copy`：可变参数栈访问
  - 声明：`@va_start(&ap, last)`、`@va_end(&ap)`、`@va_arg(ap, Type)`、`@va_copy(&dest, src)`
  - 初始化：`var ap: va_list = va_list{}; @va_start(&ap, last_param);`
  - 遍历：`@va_arg(ap, i32)`、`@va_arg(ap, &byte)`、`@va_arg(ap, i64)` 等
  - 复制：`@va_copy(&ap2, ap1)` 用于多次遍历

### 导出函数给 C

```uya
extern fn my_callback(x: i32, y: i32) i32 {
    return x + y;
}
```

### 函数指针类型

```uya
type ComparFunc = fn(*void, *void) i32;
const cmp: ComparFunc = &my_compare;
```

### Uya 指针传递给 FFI 函数

```uya
extern write(fd: i32, buf: *byte, count: i32) i32;

fn main() i32 {
    var buffer: [byte: 100] = [];
    // Uya 普通指针通过 as 显式转换为 FFI 指针类型
    const result: i32 = write(1, &buffer[0] as *byte, 100);
    return result;
}
```

**说明**：
- ✅ `&T as *T`：Uya 普通指针可以显式转换为 FFI 指针类型（安全转换，无精度损失）
- 仅在 FFI 函数调用时使用，符合"显式控制"设计哲学
- 编译期检查，无运行时开销

---

## 九、切片语法速查

```uya
var arr: [i32: 10] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

// 基本切片：&arr[start:len]（第二项是长度）
const slice1: &[i32] = &arr[2:5];      // [2, 3, 4, 5, 6]，len = 5

// 已知长度切片
const exact: &[i32: 3] = &arr[2:3];    // [2, 3, 4]

// 遍历切片：`for slice |v|` 当前不被接受（for 只支持定长数组 / 迭代器接口 / 整数范围），
// 用下标范围循环
for 0..slice1.len as i32 |i| {
    const v: i32 = slice1[i];
}
```

> 说明：
> - `&arr[start:len]` 的第二项是**长度**而不是结束下标
> - **没有负索引**：`&arr[-3:3]` 不是「从末尾往前数」，编译器不会做该换算，会切出越界内容；要从末尾取请自行算出非负下标

---

## 十、字符串插值速查

```uya
const name: &[const byte] = "Uya";
const value: i32 = 42;
const pi: f64 = 3.14159;

// 插值结果落在定长数组里（容量自己写，需容纳可见字节 + 结尾 \0）
const msg1: [i8: 32] = "Hello, ${name}!";

// 格式化插值
const msg2: [i8: 32] = "Value: ${value:d}";      // 十进制整数
const msg3: [i8: 32] = "Pi: ${pi:.2f}";          // 浮点数，2位小数
const msg4: [i8: 32] = "Hex: ${value:x}";        // 十六进制
```

- 插值只能写在双引号字符串里；`` `...` `` 原始字符串不做插值
- 插值结果是定长数组（`[i8: N]` 形式），**不是** `&[byte]`；最常用法是直接写 `@println("a ${x}")`

---

## 十一、原子操作速查

```uya
struct Counter {
    value: atomic i32
}

fn increment(counter: &Counter) void {   // 用 &Counter；*T 是 FFI 指针，不能作普通函数参数
    counter.value += 1;      // 自动原子 fetch_add
    const v: i32 = counter.value;  // 自动原子 load
    counter.value = 10;      // 自动原子 store
}
```

---

## 十二、defer 和 errdefer 速查

```uya
fn example() !void {
    defer {
        // 无论成功或失败都执行
        cleanup();
    }
    
    errdefer {
        // 只在错误返回时执行
        rollback();
    }
    
    // 函数逻辑...
}
```

**块内禁止控制流语句**（defer/errdefer 相同）：
- ✅ 允许：表达式、赋值、函数调用、语句块
- ❌ 禁止：`return`、`break`、`continue` 等控制流语句
- ❌ 禁止：`@await`；清理逻辑必须保持同步
- ✅ 替代：使用变量记录状态，在 defer/errdefer 外处理控制流

---

## 十三、内联汇编速查

### 基本语法格式

```uya
@asm {
    "add {a}, {b}" (a, b, -> result);   // 输入…, -> 输出…
    "mov rax, 1" ();                    // 没有操作数的指令写 ()
} clobbers = ["rax", "memory"];         // clobbers 只写在 '}' 之后
```

**语法元素**：
- `instruction template`：汇编指令模板（字符串字面量），使用 `{name}` 占位符
- `inputs`：输入表达式列表（普通表达式，指向内存时直接传 `&T` / `&const T`）
- `outputs`：输出表达式列表（`->` 之后）；输出变量必须在块外先声明并初始化
- `clobbers`：被修改的寄存器列表，只在 `@asm { ... }` 块的 `}` **之后**声明（没有逐指令 clobbers 语法）
- `_` 不能作为输出操作数（`(-> _)` 会报「输出表达式类型无效」）；无输出就只写 `()` 或只写输入

### 常用指令示例

```uya
// 基本算术
fn add_asm(a: i32, b: i32) i32 {
    var result: i32 = 0;
    @asm {
        "add {a}, {b}" (a, b, -> result);
    }
    return result;
}

// 系统调用（x86-64 Linux）
fn syscall_write(fd: i32, buf: &const byte, count: i32) !i32 {
    var result: i64 = 0;
    @asm {
        "mov rax, 1" ();
        "mov rdi, {fd}" (fd);
        "mov rsi, {buf}" (buf);
        "mov rdx, {count}" (count);
        "syscall" (-> result);
    } clobbers = ["rcx", "r11", "memory"];
    
    if result < 0 { return error.SyscallFailed; }
    return result as! i32;
}

// 内存操作数：直接传指针（没有 @asm_mem(...) 这个内置调用）
fn store_u32(ptr: &u32, v: u32) u32 {
    var old: u32 = 0;
    @asm {
        "mov {old}, [{ptr}]" (ptr, -> old);
    }
    return old;
}

// CPUID 指令
fn cpuid(leaf: u32) (u32, u32, u32, u32) {
    var eax: u32 = 0;
    var ebx: u32 = 0;
    var ecx: u32 = 0;
    var edx: u32 = 0;
    @asm {
        "mov eax, {leaf}" (leaf, -> eax);
        "cpuid" (eax, -> eax, ebx, ecx, edx);
    }
    return (eax, ebx, ecx, edx);
}
```

### 类型支持列表

#### 寄存器类型

| 类型 | 说明 | 平台 |
|------|------|------|
| `@asm_reg` | 编译器自动分配的通用寄存器 | 跨平台 |
| `@asm_reg_x64` | x86-64 通用寄存器 | x86-64 |
| `@asm_reg_x64_xmm` / `@asm_reg_x64_ymm` / `@asm_reg_x64_zmm` | x86-64 SSE / AVX / AVX-512 寄存器 | x86-64 |
| `@asm_reg_x86` | x86 专用寄存器 | x86 |
| `@asm_reg_arm64` | ARM64 专用寄存器 | ARM64 |
| `@asm_reg_arm64_v` | ARM64 NEON 寄存器 | ARM64 |

#### 内存操作类型

`@asm_mem` 是**内置类型名**（C 侧映射为 `void *`），用来说明「这个操作数是内存操作数」；它**没有** `@asm_mem(expr)` 调用形式，也不是可以用 `type` 声明的普通类型（`src/checker/type_from_ast.uya:632-634`、`src/codegen/c99/types.uya:939-941`）。

**使用示例**（内存操作数直接传指针）：
```uya
fn read_u32(ptr: &u32) u32 {
    var value: u32 = 0;
    @asm {
        "mov {value}, [{ptr}]" (ptr, -> value);
    }
    return value;
}
```

> **注意**：以 `"lock "` 开头的指令模板会被检查器要求 `clobbers = ["memory"]`，而 `"memory"` 目前只写入 `asm_clobbers_memory`、不进入 clobber 列表（`src/parser/primary.uya:1331`、`src/checker/check_expr.uya:4007-4023`），因此手写 `"lock ..."` 模板暂时无法通过检查；原子读改写请用 `atomic T` 的隐式原子操作（见[十一、原子操作速查](#十一原子操作速查)）。

### 平台差异说明

#### x86-64 平台

```uya
// 系统调用号
const SYS_write: i64 = 1;
const SYS_read: i64 = 0;

// 系统调用约定
// rax = 系统调用号
// rdi, rsi, rdx, r10, r8, r9 = 参数
// rax = 返回值

@asm {
    "mov rax, {nr}" (syscall_nr);
    "mov rdi, {arg1}" (arg1);
    "syscall" (-> result);
} clobbers = ["rcx", "r11", "memory"];
```

#### ARM64 平台

```uya
// 系统调用号
const SYS_write: i64 = 64;
const SYS_read: i64 = 63;

// 系统调用约定
// x8 = 系统调用号
// x0-x5 = 参数
// x0 = 返回值

@asm {
    "mov x8, {nr}" (syscall_nr);
    "mov x0, {arg1}" (arg1);
    "svc #0" (-> result);
} clobbers = ["x16", "x17", "memory"];
```

### 平台检测

```uya
// @asm_target() 返回当前平台枚举值（按 i32 使用）：
// x86_64_linux=0, x86_64_macos=1, x86_64_windows=2,
// arm64_linux=3, arm64_macos=4, arm64_windows=5, riscv64_linux=6
const target: i32 = @asm_target();

// 条件编译
if target == 0 {
    // x86-64 Linux 代码
} else if target == 3 {
    // ARM64 Linux 代码
}
```

> `@asm_target` 是内置名字（不是可用 `enum` 声明的普通枚举），`.x86_64_linux` 这类省略枚举名的写法也不存在；见 `tests/test_asm_target.uya`。

### 安全约束

1. **类型检查**：输入/输出类型必须匹配
2. **寄存器验证**：寄存器约束不能与调用约定冲突
3. **内存安全**：内存操作必须有明确类型
4. **并发安全**：原子操作必须使用 `atomic T` 类型
5. **clobber 声明**：必须声明所有被修改的寄存器

### 错误示例

```uya
// ❌ 错误：@asm 输入必须是整数或 Uya 指针（f64 会被拒绝）
var d: f64 = 3.14159;
var result: i32 = 0;
@asm {
    "mov %0, %1" (d, -> result);
}

// ❌ 错误：FFI 指针 *T 不能直接作为 @asm 操作数（先转成 &T）
extern fn malloc(size: usize) *void;
var p: *i32 = malloc(4) as *i32;
@asm {
    "nop" (p, -> result);
}

// ✅ 正确：显式声明被修改的寄存器
@asm {
    "mov rax, 1" ();
    "nop" ();
} clobbers = ["rax"];
```

（对应反向测试：`tests/error_asm_f64_input.uya`、`tests/error_asm_ffi_pointer.uya`、`tests/error_asm_empty_block.uya`。）

### 最佳实践

1. **优先使用编译器优化**：能用 Uya 原生语法的，不要用 @asm
2. **显式声明 clobbers**：声明所有被修改的寄存器
3. **内存操作数直接传 `&T` / `&const T` 指针**：没有 `@asm_mem(...)` 包装函数
4. **平台抽象**：使用 `@asm_target()` 进行条件编译
5. **优先使用原子类型**：使用 `atomic T` 类型

**详细文档**：
- [内联汇编设计文档](asm_design.md)
- [内联汇编 API 参考](asm_api_reference.md)
- [内联汇编最佳实践](asm_best_practices.md)

---

## 十四、宏系统速查

### 宏定义

```uya
// 基本宏定义
mc macro_name(param1: expr, param2: type) stmt {
    // 宏体（返回标签写 expr / stmt / struct / type 之一）
}

// 导出宏（供其他模块使用）
export mc add(a: expr, b: expr) expr {
    ${a} + ${b};
}
```

**参数类型**：`expr`（表达式）、`stmt`（语句）、`type`（类型）、`pattern`（模式）、`ident`（标识符）

**返回标签**：`expr`（表达式）、`stmt`（语句）、`struct`（结构体成员）、`type`（类型标识符）

**卫生宏**：Uya 宏是**卫生宏**——宏体内引入的局部变量、`for` 循环变量、`catch |err|` 错误变量在展开时会被重命名，
不会与调用处的同名标识符冲突；宏参数与 `@mc_eval`/`@mc_type` 绑定的语义不变
（详见 [uya.md §25.2.2](./uya.md#2522-卫生宏宏卫生化)）。

### 编译时内置函数

| 函数 | 说明 | 示例 |
|------|------|------|
| `@mc_eval(expr)` | 编译时求值 | `@mc_eval(2 + 3)` → `5` |
| `@mc_type(T)` | 类型反射 | `@mc_type(i32)` → `TypeInfo` |
| `@mc_ast(code)` | 代码转 AST | `@mc_ast(x + y)` |
| `@mc_source(expr)` | 表达式源码字符串 | `@mc_source(a > 0)` → `"a > 0"` |
| `@mc_code(ast)` | AST 转代码 | `@mc_code(ast_node)` |
| `@mc_error(msg)` | 编译时错误 | `@mc_error("类型不匹配")` |
| `@mc_get_env(name)` | 读取环境变量 | `@mc_get_env("DEBUG")` |

**TypeInfo**：`@mc_type(expr)` 返回的结构体，定义见 `lib/std/macro_typeinfo.uya`（含 `name`、`size`、`align`、`kind`、`is_*`、`field_count`、`fields`）；**获取 fields 大小请用 `@len(info.fields)`**。**FieldInfo** 含 `name`、`type_name`（*i8）。用于宏内类型查询与 `for info.fields` 编译期展开。详见 [uya.md](uya.md) §25.4.2、[grammar_formal.md](grammar_formal.md)。

### 资源嵌入内置函数

| 函数 | 说明 | 示例 |
|------|------|------|
| `@embed("path")` | 编译期嵌入单个普通文件，返回 `&[const byte]` | `const cert: &[const byte] = @embed("assets/cert.der");` |
| `@embed_dir("path")` | 编译期递归嵌入目录，返回 `&[const EmbedDirEntry]` | `const assets: &[const EmbedDirEntry] = @embed_dir("assets");` |

```uya
struct EmbedDirEntry {
    path: &[const byte],
    data: &[const byte],
}
```

速记：
- 参数必须是字符串字面量
- 相对路径相对于当前源文件所在目录解析
- 条目按相对路径排序
- 目录中的 symlink / 特殊文件会报错

### C 构建导入指令

| 指令 | 说明 | 示例 |
|------|------|------|
| `@c_import("file.c");` | 顶层构建指令；导入单个 `.c` 文件 | `@c_import("fixtures/c_import/add_impl.c");` |
| `@c_import("dir/");` | 顶层构建指令；递归导入目录下全部 `*.c` | `@c_import("fixtures/c_import/dir");` |
| `@c_import("path", "cflags", "ldflags");` | 顶层构建指令；为导入项追加 per-import `cflags` 与程序级 `ldflags` | `@c_import("flag_impl.c", "-DC_IMPORT_MAGIC=7");` |

速记：
- 只能在顶层使用
- 首参数必须是字符串字面量
- 文件模式与目录模式都支持
- `uya build -o app.c --c99` 时若程序包含 `@c_import`，会额外生成 `app.cimports.sh`
- split-C 路径由 Makefile 直接处理导入的 C object，不额外生成 sidecar

### 宏调用与跨模块使用

```uya
// 宏调用（与函数调用语法一致）
const result: i32 = add(10, 20);

// 导入其他模块的宏
use math_macros.square;
const sq: i32 = square(5);  // 25
```

### 语法糖

```uya
// 简化写法（自动包装为 @mc_code(@mc_ast(...))）
mc double(x: expr) expr {
    ${x} * 2;
}

// 等价于显式写法
mc double_explicit(x: expr) expr {
    @mc_code(@mc_ast(${x} * 2));
}
```
---

## 十五、常见问题与解答

### Q: 如何声明数组？
A: `const arr: [i32: 5] = [1,2,3,4,5];`

### Q: 如何定义可能失败的函数？
A: 使用 `!` 返回类型：`fn may_fail() !i32`

### Q: 如何导入模块？
A: `use std.io;` 或 `use std.io.read_file;`

### Q: 如何获取指针？
A: `const ptr: &i32 = &variable;`（Uya指针）、`const void_ptr: &void = &buffer as &void;`（通用指针）或 `const fptr: *void = ...;`（FFI指针）

### Q: 如何访问结构体字段？
A: `obj.field`（直接访问）或 `ptr.field`（指针自动解引用，等价于 `(*ptr).field`）

### Q: 如何给结构体字段赋值？
A: `obj.field = value;`（直接赋值）或 `ptr.field = value;`（指针自动解引用后赋值）

### Q: 如何定义结构体方法？
A: 在结构体内部定义，或使用外部方法块 `StructName { fn method(self: &Self) ... }`

### Q: 如何写链式方法调用？
A: 后缀链没有层数限制，可写成 `obj.method().next().finish()`、`Type.make().next()`、`arr[i].method().next()` 或 `obj.method<T>().next()`

### Q: 如何实现接口？
A: 在结构体定义时声明：`struct MyStruct : InterfaceName { ... }`

### Q: 切片和数组的区别？
A: 数组是固定长度的值类型 `[T: N]`，切片是动态长度的引用类型 `&[T]`

### Q: 如何捕获错误？
A: 使用 `catch` 后缀运算符：`value catch |err| { ... }`

### Q: `try` 关键字的作用？
A: `try` 传播 `!T`：在返回 `!T`（或 `@async_fn` 返回 `Future<!T>`）的函数里把错误向外抛。`!T` 可由两类操作数提供——本身是错误联合类型，或是整数算术表达式（checked 求值，溢出 → `error.Overflow`，除零 → `error.DivisionByZero`）；就地处理写 `(a + b) catch |e| { … }`。饱和/包装运算符 `+|` `+%` 仍然可用（见 §六）

### Q: 如何定义枚举？
A: `enum Color { Red, Green, Blue }` 或 `enum Status : u16 { Ok = 200 }`

### Q: 泛型语法是什么？
A: 使用尖括号 `<T>`，约束紧邻参数 `<T: Ord>`，多约束连接 `<T: Ord + Clone + Default>`
   - 函数：`fn max<T: Ord>(a: T, b: T) T { ... }`
   - 结构体：`struct Vec<T: Default> { ... }`
   - 接口：`interface Iterator<T> { ... }`
   - 使用：`Vec<i32>`, `Iterator<String>`

### Q: 如何定义 SIMD 向量类型？
A: 使用 `@vector(T, N)` 与 `@mask(N)`，例如：
   - `type Vec4f32 = @vector(f32, 4);`
   - `const lt: @mask(4) = a < b;`
   - `if @vector.any(lt) { ... }`

---

## 十六、完整示例

```uya
// 接口定义
interface IWriter {
    fn write(self: &Self, buf: *byte, len: i32) i32;
}

// 结构体实现接口
struct File : IWriter {
    fd: i32,
    
    fn write(self: &Self, buf: *byte, len: i32) i32 {
        // 实现写入逻辑
        return len;
    }
    
    fn close(self: &Self) void {
        // 普通显式清理方法
    }
}

// 错误定义
error FileNotFound;

// 函数定义（参数用 Uya 指针 &const byte，不能用 FFI 指针 *byte）
fn open_file(path: &const byte) !File {
    // 可能失败的操作
    if @len(path) == 0 {
        return error.FileNotFound;
    }
    return File{ fd: 1 };
}

// 使用：try 只能在返回 !T 的函数里用
fn run() !i32 {
    const file: File = try open_file("test.txt");
    defer file.close();
    
    const data: &[const byte] = "Hello";
    return file.write(&data[0] as *byte, 5);
}

export fn main() i32 {
    const n: i32 = run() catch |_| { return 1; };
    return n - 5;
}
```

`drop` 是特殊的 RAII 清理函数：只能声明为 `fn drop(self: T) void`，并且只能由编译器在离开作用域时自动插入；`drop(x)`、`T.drop(x)`、`x.drop()` 都是编译错误。

---

## 十七、下一步学习

- **完整语法**：查看 [grammar_formal.md](./grammar_formal.md)（完整BNF定义）
- **语言规范**：查看 [uya.md](./uya.md)（完整语义说明）
- **示例代码**：查看 `/examples` 目录
- **编译器实现**：查看 `/compiler` 目录

---

## 参考

- [uya.md](./uya.md) - 完整语言规范
- [grammar_formal.md](./grammar_formal.md) - 正式BNF语法规范
- [comparison.md](./comparison.md) - 与其他语言的对比
