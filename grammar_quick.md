# Uya 语法速查手册（Quick Reference）

本文档是 Uya 语言的快速参考手册，包含精简语法定义、常用代码模式和速查表。

> **注意**：本文档是 [uya.md](./uya.md) 的补充，适合日常开发和快速查阅。  
> 对于完整的、无歧义的 BNF 语法定义，请参考 [grammar_formal.md](./grammar_formal.md)。

---

## 一、核心语法（30秒掌握）

### 基本结构

```uya
// 函数定义
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

---

## 二、类型系统速查

| 类型 | 写法 | 示例 | 说明 |
|------|------|------|------|
| **整数** | `i8` `i16` `i32` `i64`<br>`u8` `u16` `u32` `u64` | `const x: i32 = 42;` | 有符号/无符号整数 |
| **浮点** | `f32` `f64` | `const pi: f64 = 3.14;` | 单/双精度浮点数 |
| **布尔** | `bool` | `const flag: bool = true;` | 布尔值 |
| **数组** | `[T: N]` | `const arr: [i32: 5] = [1,2,3,4,5];`<br>`var buf: [i32: 100] = [];` | 固定长度数组，`[]` 表示未初始化 |
| **切片** | `&[T]` `&[T: N]` | `const slice: &[i32] = &arr[2:5];` | 动态/已知长度切片 |
| **指针** | `&T` `*T` | `const ptr: &i32 = &x;` | Uya指针/FFI指针 |
| **结构体** | `StructName` | `const p: Point = Point{x: 1.0, y: 2.0};` | 结构体类型 |
| **联合体** | `UnionName` | `const v: IntOrFloat = IntOrFloat.i(42);` | 标签联合体，编译期证明安全 |
| **接口** | `InterfaceName` | `const writer: IWriter = ...;` | 接口类型 |
| **元组** | `(T1, T2, ...)` | `const t: (i32, f64) = (10, 3.14);` | 元组类型 |
| **错误联合** | `!T` | `fn may_fail() !i32 { ... }` | 可能返回错误 |
| **原子类型** | `atomic T` | `value: atomic i32` | 原子类型 |
| **函数指针** | `fn(...) type` | `type Func = fn(i32, i32) i32;` | 函数指针类型 |

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
const x = try may_fail();  // 自动传播错误
```

### 捕获错误

```uya
const x = may_fail() catch |err| {
    // 处理错误
    return 0;
};
```

---

## 五、常用模式模板

### 函数定义模板

```uya
// 普通函数
fn name(param: Type) ReturnType {
    // 函数体
    return value;
}

// 可能失败的函数
fn name(param: Type) !ReturnType {
    if error_condition {
        return error.ErrorName;
    }
    return value;
}
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
    
    fn method(self: *Self) ReturnType {
        // 方法体
    }
}

// 结构体方法（外部定义）
struct Name {
    field: Type
}

Name {
    fn method(self: *Self) ReturnType {
        // 方法体
    }
}

### 联合体定义模板

```uya
// 基本联合体
union Name {
    variant1: Type1,
    variant2: Type2
}

// 创建：UnionName.variant(expr)
const v = IntOrFloat.i(42);
const f = IntOrFloat.f(3.14);

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
    fn write(self: *Self, buf: *byte, len: i32) i32;
}

// 接口实现
struct MyStruct : IWriter {
    field: Type,
    
    fn write(self: *Self, buf: *byte, len: i32) i32 {
        // 实现
        return len;
    }
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

## 六、运算符优先级表（从高到低）

| 优先级 | 运算符 | 说明 |
|--------|--------|------|
| 1 (最高) | `.` `[]` `()` `[start:len]` `catch` | 成员访问、调用、切片、错误捕获 |
| 2 | `!` `-` `~` `&` `*` `try` | 一元运算 |
| 3 | `as` `as!` | 类型转换 |
| 4 | `*` `/` `%` `*|` `*%` | 乘除模、饱和乘、包装乘 |
| 5 | `+` `-` `+|` `-|` `+%` `-%` | 加减、饱和加减、包装加减 |
| 6 | `<<` `>>` | 位移 |
| 7 | `<` `>` `<=` `>=` | 关系比较 |
| 8 | `==` `!=` | 相等比较 |
| 9 | `&` | 按位与 |
| 10 | `^` | 按位异或 |
| 11 | `\|` | 按位或 |
| 12 | `&&` | 逻辑与 |
| 13 | `\|\|` | 逻辑或 |
| 14 (最低) | `=` `+=` `-=` `*=` `/=` `%=` | 赋值 |

---

## 七、模块系统速查

### 导出

```uya
export fn public_function() i32 { ... }
export struct PublicStruct { ... }
export interface PublicInterface { ... }
export const PUBLIC_CONST: i32 = 42;
export error PublicError;
```

### 导入

```uya
// 导入整个模块
use std.io;

// 导入特定项
use std.io.read_file;

// 导入并重命名
use std.io as io_module;
```

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

fn sum(...) i32 {
    const args = @params;  // 所有参数作为元组
    var total: i32 = 0;
    for args |val| { total += val; }
    return total;
}
```

- 声明：`...` 为参数列表最后一项
- 转发：`printf(fmt, ...)` 将可变参数转发
- `@params`：函数体内访问所有参数作为元组

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

// 基本切片
const slice1: &[i32] = &arr[2:5];      // [2, 3, 4]

// 负数索引切片
const slice2: &[i32] = &arr[-3:3];     // [7, 8, 9]（等价于 &arr[7:3]）

// 已知长度切片
const exact: &[i32: 3] = &arr[2:3];    // [2, 3, 4]

// for循环迭代切片
for slice1 |v| {
    // 使用 v
}
```

---

## 十、字符串插值速查

```uya
const name = "Uya";
const value: i32 = 42;

// 简单插值
const msg1 = "Hello, ${name}!";

// 格式化插值
const msg2 = "Value: ${value:d}";      // 十进制整数
const msg3 = "Pi: ${pi:.2f}";          // 浮点数，2位小数
const msg4 = "Hex: ${value:x}";        // 十六进制
```

---

## 十一、原子操作速查

```uya
struct Counter {
    value: atomic i32
}

fn increment(counter: *Counter) void {
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
- ✅ 替代：使用变量记录状态，在 defer/errdefer 外处理控制流

---

## 十三、常见问题与解答

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
A: 在结构体内部定义，或使用外部方法块 `StructName { fn method(self: *Self) ... }`

### Q: 如何实现接口？
A: 在结构体定义时声明：`struct MyStruct : InterfaceName { ... }`

### Q: 切片和数组的区别？
A: 数组是固定长度的值类型 `[T: N]`，切片是动态长度的引用类型 `&[T]`

### Q: 如何捕获错误？
A: 使用 `catch` 后缀运算符：`value catch |err| { ... }`

### Q: `try` 关键字的作用？
A: `try` 用于错误传播和整数溢出检查，是一元运算符

### Q: 如何定义枚举？
A: `enum Color { Red, Green, Blue }` 或 `enum Status : u16 { Ok = 200 }`

---

## 十四、完整示例

```uya
// 接口定义
interface IWriter {
    fn write(self: *Self, buf: *byte, len: i32) i32;
}

// 结构体实现接口
struct File : IWriter {
    fd: i32,
    
    fn write(self: *Self, buf: *byte, len: i32) i32 {
        // 实现写入逻辑
        return len;
    }
    
    fn drop(self: *Self) void {
        // 清理资源
    }
}

// 错误定义
error FileNotFound;

// 函数定义
fn open_file(path: *byte) !File {
    // 可能失败的操作
    if not_found {
        return error.FileNotFound;
    }
    return File{ fd: 1 };
}

// 使用
fn main() i32 {
    const file = try open_file("test.txt");
    defer file.drop();
    
    const data = "Hello";
    file.write(data, 5);
    
    return 0;
}
```

---

## 十五、下一步学习

- **完整语法**：查看 [grammar_formal.md](./grammar_formal.md)（完整BNF定义）
- **语言规范**：查看 [uya.md](./uya.md)（完整语义说明）
- **示例代码**：查看 `/examples` 目录
- **编译器实现**：查看 `/compiler` 目录

---

## 参考

- [uya.md](./uya.md) - 完整语言规范
- [grammar_formal.md](./grammar_formal.md) - 正式BNF语法规范
- [comparison.md](./comparison.md) - 与其他语言的对比

