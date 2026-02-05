# Uya 语言完整语法 AI 提示词

## 核心特性

Uya 是系统编程语言，零GC、默认高级安全、编译期证明（本函数内）。

**设计哲学**：坚如磐石 - 程序员提供证明，编译器在当前函数内验证证明，运行时绝对安全。常量错误→编译错误，变量证明超时→自动插入运行时检查。

## 关键字

```
struct const var fn return extern true false if while break continue
defer errdefer try catch error null interface atomic union
export use mc
```

**内置函数**（以 `@` 开头）：
- 运行时：`@size_of`、`@align_of`、`@len`、`@max`、`@min`
- 编译时（宏内）：`@mc_eval`、`@mc_type`、`@mc_ast`、`@mc_code`、`@mc_error`、`@mc_get_env`

## 类型系统

| 类型 | 大小/对齐 | 说明 |
|------|----------|------|
| `i8` `i16` `i32` `i64` | 1/2/4/8 B | 有符号整数，对齐=大小 |
| `u8` `u16` `u32` `u64` | 1/2/4/8 B | 无符号整数，对齐=大小 |
| `usize` | 4/8 B | 平台相关，32位=4B，64位=8B |
| `f32` `f64` | 4/8 B | 浮点数，对齐=大小 |
| `bool` | 1 B | 布尔值，对齐1B |
| `byte` | 1 B | 无符号字节，对齐1B |
| `void` | 0 B | 仅用于函数返回类型 |
| `*byte` | 4/8 B | FFI指针类型，C字符串指针 |
| `&T` | 4/8 B（平台相关） | 普通指针，无lifetime符号；32位平台=4B，64位平台=8B |
| `&void` | 4/8 B（平台相关） | 通用指针类型，可转换为任何指针类型（`&void` → `&T`）；32位平台=4B，64位平台=8B |
| `&atomic T` | 4/8 B（平台相关） | 原子指针；32位平台=4B，64位平台=8B |
| `atomic T` | sizeof(T) | 原子类型 |
| `[T: N]` | N·sizeof(T) | 固定数组，N为编译期常量 |
| `[[T: N]: M]` | M·N·sizeof(T) | 多维数组，行优先存储 |
| `&[T]` | 8/16 B（平台相关） | 切片引用（动态长度），指针(4/8B) + 长度(4/8B)；32位平台=8B，64位平台=16B |
| `&[T: N]` | 8/16 B（平台相关） | 切片引用（已知长度），指针(4/8B) + 长度(4/8B)；32位平台=8B，64位平台=16B |
| `struct S { }` | 字段顺序布局 | 对齐=最大字段对齐，C内存布局 |
| `union U { ... }` | 最大变体大小 | 对齐=最大变体对齐，编译期标签跟踪，与C union兼容 |
| `interface I { }` | 8/16 B（平台相关） | vtable指针(4/8B) + 数据指针(4/8B)；32位平台=8B，64位平台=16B |
| `enum E { }` | sizeof(底层类型) | 枚举，默认底层i32 |
| `(T1, T2, ...)` | 字段顺序布局 | 元组类型，对齐=最大字段对齐 |
| `fn(...) type` | 4/8 B（平台相关） | 函数指针类型，用于FFI回调 |
| `!T` | max(sizeof(T), sizeof(错误标记)) | 错误联合类型，T\|Error |

**内置函数**（以 `@` 开头）：
- `@max`/`@min`：访问整数类型极值常量（编译期推断类型）
- 无隐式转换，类型必须完全一致

## 基本语法

### 变量声明
```uya
const name: Type = value;  // 不可变变量
var name: Type = value;    // 可变变量
```

**重要规则**：
- 必须显式类型注解，不支持类型推断
- `const` 为编译期常量，可作为数组大小
- 忽略标识符 `_`：`_ = process();` 显式忽略返回值

### 函数声明
```uya
fn name(param1: Type1, param2: Type2) ReturnType {
    statements
    return value;
}

// void函数
fn void_func() void {
    // 可省略return
}

// 错误联合类型
fn may_fail() !i32 {
    if condition {
        return error.ErrorName;  // 返回错误
    }
    return 42;  // 返回正常值
}

// 泛型函数
fn max<T: Ord>(a: T, b: T) T {
    if a > b { return a; }
    return b;
}

// 多约束泛型
fn clone_and_compare<T: Clone + Ord>(a: T, b: T) bool {
    const cloned = a.clone();
    return cloned > b;
}
```

**程序入口**：
```uya
fn main() i32 { ... }      // 简单签名，必须用catch处理错误
fn main() !i32 { ... }     // 完整签名，可用try传播错误（推荐）
```

### 联合体
```uya
// 联合体定义
union IntOrFloat {
    i: i32,
    f: f64
}

// 创建：UnionName.variant(expr)
const v = IntOrFloat.i(42);

// 访问：必须 match 处理所有变体
match v {
    .i(x) => printf("%d\n", x),
    .f(x) => printf("%f\n", x)
}
```

### 结构体
```uya
// 基本结构体
struct Point {
    x: f32,
    y: f32
}

// 声明接口
struct File : IWriter {
    fd: i32,
    fn write(self: &Self, buf: *byte, len: i32) i32 { ... }
}

// 外部方法定义（方式2）
File {
    fn read(self: &Self, buf: *byte, len: i32) !i32 { ... }
}

// 泛型结构体
struct Vec<T: Default> {
    data: &T,
    len: i32,
    cap: i32
}

// 使用泛型结构体
const vec: Vec<i32> = Vec<i32>{ data: ..., len: 0, cap: 0 };

// 结构体字面量
const p: Point = Point{ x: 1.0, y: 2.0 };

// 字段访问
const x: f32 = p.x;  // 直接访问
var ptr: &Point = &p;
const y: f32 = ptr.y;  // 指针自动解引用（等价于 (*ptr).y）

// 字段赋值
p.x = 10.0;  // 直接赋值
ptr.y = 20.0;  // 指针自动解引用后赋值（等价于 (*ptr).y = 20.0）
```

**重要规则**：
- 所有结构体使用C内存布局，100% C兼容
- 可以有方法、drop、实现接口，同时保持C兼容
- `self` 参数必须为 `&Self` 或 `&StructName`（指针）
- **指针自动解引用**：`ptr.field` 等价于 `(*ptr).field`（当 `ptr` 是指向结构体的指针时）
- **字段赋值**：支持 `obj.field = value` 和 `ptr.field = value`（指针自动解引用）

### 接口
```uya
interface IWriter {
    fn write(self: &Self, buf: *byte, len: i32) i32;
}

// 泛型接口
interface Iterator<T> {
    fn next(self: &Self) union Option<T>;
}

// 多约束泛型接口
interface Cloneable<T: Clone + Default> {
    fn clone(self: &Self) T;
}

// 结构体实现接口
struct Console : IWriter {
    fd: i32,
    fn write(self: &Self, buf: *byte, len: i32) i32 {
        extern write(fd: i32, buf: *void, count: i32) i32;
        return write(self.fd, buf, len);
    }
}

// 使用接口
fn use_writer(w: IWriter) void {
    w.write(&buffer[0], 10);  // 动态派发
}

// 使用泛型接口
fn use_iterator<T>(iter: Iterator<T>) void {
    // 使用迭代器
}
```

**重要规则**：
- 接口值16字节（vtable指针+数据指针）
- 编译期生成vtable，零运行时注册
- 生命周期：接口值不能逃逸底层数据生命周期

### 枚举
```uya
// 基本枚举（默认底层类型i32）
enum Color {
    RED,
    GREEN,
    BLUE
}

// 显式赋值
enum HttpStatus {
    OK = 200,
    NOT_FOUND = 404,
    SERVER_ERROR = 500
}

// 指定底层类型
enum SmallEnum : u8 {
    A = 1,
    B = 2
}

// 使用
const c: Color = Color.RED;
const status: HttpStatus = HttpStatus.OK;
```

**规则**：
- 默认底层类型为`i32`
- 支持显式指定底层类型（`u8`, `u16`, `u32`, `i8`, `i16`, `i32`, `i64`）
- 枚举变体可以显式赋值
- 类型安全：枚举值只能与相同枚举类型比较
- 与C枚举完全兼容

### 元组
```uya
// 元组类型
type Point = (i32, i32);
const p: (i32, i32) = (10, 20);

// 字段访问（使用.0, .1, .2等索引）
const x: i32 = p.0;  // 访问第一个元素
const y: i32 = p.1;  // 访问第二个元素

// 解构赋值
const (x, y) = p;
const (x, _, z) = get_tuple();  // 使用_忽略中间元素
```

**规则**：
- 字段访问使用数字索引（从0开始）
- 支持解构赋值
- 对齐规则与结构体相同（对齐=最大字段对齐值）
- 编译期边界检查：访问越界立即编译错误

### 类型别名
```uya
// 基础类型别名
type UserId = i32;
type Distance = f64;

// 元组类型别名
type Point = (i32, i32);

// 函数指针类型别名
type ComparFunc = fn(*void, *void) i32;

// 错误联合类型别名
type FileResult = !i32;
```

### 数组
```uya
// 数组声明
const arr: [i32: 10] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
const zeros: [i32: 10] = [0: 10];  // 重复初始化

// 未初始化数组（空数组字面量）
var buf: [f32: 64] = [];  // 必须在使用前初始化
// 注意：空数组字面量 [] 仅当变量类型已明确时可用，表示未初始化
// len(buf) 返回数组声明时的大小（64），而不是 0

// 多维数组
const matrix: [[i32: 4]: 3] = [
    [1, 2, 3, 4],
    [5, 6, 7, 8],
    [9, 10, 11, 12]
];

// 数组访问（需要边界检查证明）
if i >= 0 && i < 10 {
    const value: i32 = arr[i];
}
```

**切片语法**：
```uya
const slice: &[i32] = &arr[2:5];           // 动态长度切片
const exact: &[i32: 3] = &arr[2:3];        // 已知长度切片
const tail: &[i32] = &arr[-3:3];           // 负数索引，从倒数第3个开始
```

### 控制流

**if语句**：
```uya
if condition {
    statements
} else {
    statements
}

// else if
if c1 {
} else if c2 {
} else {
}
```

**while循环**：
```uya
while condition {
    statements
    break;      // 跳出循环
    continue;   // 继续下一次迭代
}
```

**for循环**：
```uya
// 可迭代对象（值迭代，只读）
for obj |v| {
    // v是元素值
}

// 可迭代对象（引用迭代，可修改）
for obj |&v| {
    *v = *v * 2;  // 修改元素
}

// 索引迭代
for obj |i| {
    // i是索引，类型usize
}

// 整数范围
for 0..10 |i| {  // [0, 10)，左闭右开
    // i从0到9
}

for 5.. |i| {    // 从5开始的无限范围
    // 由迭代器结束条件终止
}

// 丢弃元素
for obj { }      // 只执行循环体
for 0..10 { }    // 只执行10次
```

**match表达式**：
```uya
// 作为表达式
const result: i32 = match value {
    1 => 10,
    2 => 20,
    else => 0
};

// 作为语句
match status {
    200 => process_success(),
    error.FileNotFound => handle_error(),
    else => handle_default()
};

// 结构体解构
match point {
    Point{ x: 0, y: 0 } => handle_origin(),
    Point{ x, y } => process(x, y)
};

// 枚举匹配
match color {
    Color.RED => handle_red(),
    Color.GREEN => handle_green(),
    Color.BLUE => handle_blue()
};

// 错误类型匹配
match result {
    error.DivisionByZero => handle_div_zero(),
    error.Overflow => handle_overflow(),
    value => use_value(value)
};
```

### 错误处理

**错误类型**：
```uya
// 预定义错误（可选）
error DivisionByZero;
error FileNotFound;

// 运行时错误（无需预定义）
return error.RuntimeError;

// 使用
if err == error.DivisionByZero { ... }
```

**error_id 稳定性**：`error_id = hash(error_name)`，相同错误名在任意编译中映射到相同 `error_id`；hash 冲突时编译器报错并提示冲突名称。

**try关键字**：
```uya
// 错误传播
const result: i32 = try divide(10, 2);  // 自动传播错误

// 溢出检查
const sum: i32 = try a + b;   // 溢出时返回error.Overflow
const diff: i32 = try a - b;  // 溢出检查
const prod: i32 = try a * b;  // 溢出检查
```

**catch语法**：
```uya
// 捕获错误并返回值
const result: i32 = divide(10, 0) catch |err| {
    if err == error.DivisionByZero {
        return 0;  // 返回默认值
    }
    return -1;
};

// 捕获所有错误（不绑定变量）
const result: i32 = divide(10, 0) catch {
    return 0;  // 默认值
};

// catch中使用return提前返回函数
const result: i32 = divide(10, 0) catch {
    return error;  // 直接返回函数，退出函数
};
```

### defer和errdefer

```uya
fn example() !void {
    defer {
        cleanup();  // 作用域结束时执行（正常或错误返回）
    }
    
    errdefer {
        rollback();  // 仅在错误返回时执行
    }
    
    // 执行顺序：正常返回时 defer → drop
    // 错误返回时 errdefer → defer → drop
}
```

**块内禁止**：`return`、`break`、`continue` 等控制流语句。允许：表达式、赋值、函数调用、语句块。替代：用变量记录状态，在 defer/errdefer 外处理控制流。

### 运算符

**优先级表**（从高到低）：
1. `()` `.` `[]` `[start:end]` - 调用、字段、下标、切片
2. `-` `!` `~` - 一元运算符
3. `*` `/` `%` `*|` `*%` - 乘除模、饱和乘法、包装乘法
4. `+` `-` `+|` `-|` `+%` `-%` - 加减、饱和运算、包装运算
5. `<<` `>>` - 移位
6. `<` `>` `<=` `>=` - 比较
7. `==` `!=` - 相等性
8. `&` - 按位与
9. `^` - 按位异或
10. `|` - 按位或
11. `&&` - 逻辑与
12. `||` - 逻辑或
13. `=` - 赋值

**特殊运算符**：
- **饱和运算符**：`+|` `-|` `*|` - 溢出时返回极值
- **包装运算符**：`+%` `-%` `*%` - 溢出时包装（模运算）
- **try运算符**：`try expr` - 错误传播或溢出检查

**重要规则**：
- 无隐式转换，类型必须完全一致
- 赋值运算符 `=` 仅用于 `var` 变量
- 不支持 `++` `--` `+=` `-=` 等复合赋值
- 不支持三元运算符 `?:`，使用if-else

### 类型转换

```uya
// 安全转换（as）- 仅无精度损失
const f: f64 = i as f64;        // ✅ i32→f64无损失
const i: i32 = f as i32;        // ❌ 编译错误，可能损失精度

// 强转（as!）- 返回错误联合类型
const i: i32 = try f as! i32;   // ✅ 可能损失精度，返回!i32

// 指针类型转换（FFI调用）
extern write(fd: i32, buf: *byte, count: i32) i32;
var buffer: [byte: 100] = [];
const result: i32 = write(1, &buffer[0] as *byte, 100);  // ✅ &T as *T
```

**指针转换规则**：
- ✅ `&T` ↔ `*T`：同类型指针可通过 `as` 互相转换
- ✅ `&void ↔ &T`：通用指针与具体指针类型之间的转换
  - `&void as &T`：通用指针转换为具体指针类型（类型擦除恢复）
  - `&T as &void`：具体指针转换为通用指针类型（类型擦除）
  - 示例：`var ptr: &void = &buffer as &void; var byte_ptr: &byte = ptr as &byte;`

### 模块系统

```uya
// 导出
export fn helper() i32 { return 42; }
export struct Point { x: f32, y: f32 }

// 导入
use std.io;                    // 导入整个模块
use std.io.read_file;          // 导入特定项
use std.io as io;              // 使用别名

// 使用
std.io.read_file(...);         // 模块前缀
read_file(...);                // 直接使用（导入特定项后）
io.read_file(...);             // 别名前缀
```

**模块规则**：
- 每个目录自动成为一个模块
- 项目根目录（包含main的目录）是`main`模块
- 路径映射：`std/io/` → `std.io`
- 所有结构体使用C内存布局，可直接互操作

### 可变参数与 @params（uya.md §5.4）

- **声明**：沿用 C 的 `...` 语法：`fn printf(fmt: *byte, ...) i32;`、`fn sum(...) i32`
- **@params**：内置变量，函数体内包含所有参数（固定+可变）的元组视图；`const args = @params;` 可用 `.0`/`.1`、遍历、解构
- **参数转发**：`printf(fmt, ...)` 将可变参数转发给其他可变参数函数
- **编译器优化**：未使用 `@params` 时零开销直接转发；使用 `@params` 时生成元组打包代码

### FFI（外部C函数）

```uya
// 声明外部C函数
extern printf(fmt: *byte, ...) i32;
extern malloc(size: usize) *void;

// 调用
printf("Hello\n");
const ptr: *void = malloc(100);

// 导出函数给C
extern fn compare(a: *void, b: *void) i32 {
    // Uya代码
    return 0;
}
```

**FFI指针类型 `*T`**：
- 仅用于FFI函数声明/调用
- 支持所有C兼容类型：`*i8` `*i16` `*i32` `*i64` `*u8` `*u16` `*u32` `*u64` `*f32` `*f64` `*bool` `*byte` `*void` `*CStruct`
- 支持下标访问 `ptr[i]`，但必须提供长度约束证明
- 不能用于普通变量声明

**Uya指针传递给FFI函数**：
- ✅ `&T as *T`：Uya普通指针可以通过 `as` 显式转换为FFI指针类型（安全转换，无精度损失）
- 仅在FFI函数调用时使用，符合"显式控制"设计哲学
- 示例：`extern write(fd: i32, buf: *byte, count: i32) i32;` 调用时使用 `write(1, &buffer[0] as *byte, 100);`
- 编译期检查，无运行时开销

**函数指针类型**：
```uya
// 函数指针类型
type ComparFunc = fn(*void, *void) i32;

// 声明需要函数指针的C函数
extern qsort(base: *void, nmemb: usize, size: usize, compar: ComparFunc) void;

// 导出函数给C（可以作为函数指针传递）
extern fn compare(a: *void, b: *void) i32 {
    // Uya代码
    return 0;
}

// 使用
qsort(&arr[0], 10, 4, &compare);  // 传递函数指针
```

### 原子操作

```uya
struct Counter {
    value: atomic i32
}

fn increment(counter: *Counter) void {
    counter.value += 1;        // 自动原子fetch_add
    const v: i32 = counter.value;  // 自动原子load
    counter.value = 10;        // 自动原子store
}
```

**规则**：
- `atomic T` 类型的所有读写操作自动生成原子指令
- 零运行时锁，直接硬件原子指令
- 默认使用sequentially consistent内存序

### 内存安全规则

**编译期证明机制**：
- **常量错误**：编译期常量直接检查，溢出/越界立即编译错误
- **变量证明超时**：编译器无法在有限时间内证明安全时，自动插入运行时检查

**必须证明安全的场景**：
1. **数组越界**：常量索引越界→编译错误；变量索引→证明`i >= 0 && i < len`
2. **空指针解引用**：证明`ptr != null`或前序有检查
3. **使用未初始化**：证明「首次使用前已赋值」
4. **整数溢出**：常量溢出→编译错误；变量→显式检查或编译器证明
5. **除零错误**：常量除零→编译错误；变量→证明`y != 0`

**证明范围**：仅限当前函数内，跨函数调用需显式处理返回值

### RAII和drop

```uya
// 用户自定义 drop，只能在结构体内部或方法块中定义
File {
    fn drop(self: File) void {
        extern close(fd: i32) i32;
        close(self.fd);
    }
}

// 自动调用：离开作用域时按字段逆序调用 drop
```

**规则**：
- 离开作用域时自动调用drop
- 递归drop：先drop字段，再drop外层结构体
- 数组元素按索引逆序drop

### 移动语义

**规则**：
- 结构体赋值时转移所有权（移动），基本类型使用值语义（复制）
- 移动后变量不能再次使用
- 存在活跃指针时禁止移动
- 移动不会调用源对象的drop，只有目标对象离开作用域时才调用drop

### 字符串

**字符串字面量**：
```uya
// 普通字符串字面量（类型为*byte，仅用于FFI）
extern printf(fmt: *byte, ...) i32;
printf("Hello\n");  // ✅ 可以作为FFI函数参数

// 原始字符串字面量（无转义序列）
const path: *byte = `C:\Users\name`;  // 所有字符按字面量处理
```

**字符串字面量使用规则**：
- ✅ 可以作为FFI函数调用的参数
- ✅ 可以作为FFI函数声明的参数类型
- ✅ 可以与`null`比较（如果函数返回`*byte`）
- ❌ 不能赋值给变量（编译错误）
- ❌ 不能用于数组索引或其他非FFI操作

**字符串插值**：
```uya
const x: u32 = 255;
const pi: f64 = 3.14159;

// 基本形式
const msg1: [i8: 64] = "x=${x}\n";

// 格式化形式（与C printf一致）
const msg2: [i8: 64] = "hex=${x:#06x}, pi=${pi:.2f}\n";
const msg3: [i8: 64] = "pi=${pi:.2e}\n";  // 科学计数法
```

**字符串插值规则**：
- 结果类型为`[i8: N]`（定长栈数组）
- 编译期计算缓冲区大小
- 格式说明符与C printf保持一致
- 零运行时解析开销，零堆分配

### 内置函数（以 @ 开头）

```uya
// 内置函数（以 @ 开头，无需导入，自动可用）
@len(arr)           // 返回数组元素个数（编译期常量）
// 对于空数组字面量 []，@len 返回数组声明时的大小，而不是 0
var buffer: [i32: 100] = [];
const len_val: i32 = @len(buffer);  // 100（从声明中获取）

@size_of(T)          // 返回类型大小（编译期常量）
@align_of(T)         // 返回类型对齐（编译期常量）
@max               // 整数类型最大值（类型从上下文推断）
@min               // 整数类型最小值（类型从上下文推断）
```

## 完整示例

```uya
extern printf(fmt: *byte, ...) i32;

// 错误定义
error DivisionByZero;

// 枚举定义
enum Color {
    RED,
    GREEN,
    BLUE
}

// 类型别名
type Point = (i32, i32);

// 结构体定义
struct Vec3 {
    x: f32,
    y: f32,
    z: f32
}

// 接口定义
interface IWriter {
    fn write(self: &Self, buf: *byte, len: i32) i32;
}

// 结构体实现接口
struct Console : IWriter {
    fd: i32,
    fn write(self: &Self, buf: *byte, len: i32) i32 {
        extern write(fd: i32, buf: *void, count: i32) i32;
        return write(self.fd, buf, len);
    }
}

// 函数定义
fn divide(a: i32, b: i32) !i32 {
    if b == 0 {
        return error.DivisionByZero;
    }
    return a / b;
}

fn main() !i32 {
    // 变量声明
    const x: i32 = 10;
    var y: i32 = 5;
    
    // 错误处理
    const result: i32 = try divide(x, y);
    
    // 枚举使用
    const color: Color = Color.RED;
    
    // 元组使用
    const point: Point = (10, 20);
    const x_coord: i32 = point.0;
    
    // 数组和切片
    var arr: [i32: 10] = [0: 10];
    const slice: &[i32] = &arr[2:5];
    
    // for循环
    for slice |value| {
        printf("%d\n", value);
    }
    
    // match表达式
    match color {
        Color.RED => printf("Red\n"),
        Color.GREEN => printf("Green\n"),
        Color.BLUE => printf("Blue\n")
    };
    
    // 字符串插值
    const msg: [i8: 64] = "result=${result}\n";
    printf(&msg[0]);
    
    return 0;
}
```

## 宏系统

### 宏定义语法

```uya
mc macro_name(param1: expr, param2: type) return_tag {
    // 宏体：编译时执行的代码
    const value = @mc_eval(param1)  // 编译时求值
    const type_info = @mc_type(param2)  // 类型反射
    @mc_code(@mc_ast( /* 生成的代码 */ ))
}
```

**参数类型**：
- `expr`：表达式参数
- `stmt`：语句参数
- `type`：类型参数
- `pattern`：模式参数

**返回标签**：
- `expr`：返回表达式
- `stmt`：返回语句
- `struct`：返回结构体成员
- `type`：返回类型标识符

### 编译时内置函数（宏内使用）

- `@mc_eval(expr)`：编译时求值常量表达式
- `@mc_type(expr)`：获取类型信息，返回 `TypeInfo` 结构体
- `@mc_ast(expr)`：将代码转换为抽象语法树
- `@mc_code(ast)`：将 AST 转换回代码
- `@mc_error(msg)`：报告编译时错误并终止编译
- `@mc_get_env(name)`：读取编译时环境变量

### 宏调用

```uya
const result = macro_name(arg1, arg2);  // 与函数调用语法一致
```

宏在编译时展开，调用被替换为宏生成的代码。

### 示例

```uya
// 编译时断言宏
mc assert(cond) stmt {
    const val = @mc_eval(cond)
    if !val { @mc_error("断言失败") }
    @mc_code(@mc_ast({}))
}

// 类型驱动代码生成
mc define_getter(field: expr) struct {
    const field_ast = @mc_ast(field)
    @mc_code(@mc_ast({
        fn get_${field_ast}(self: &Self) i32 {
            return self.${field_ast}
        }
    }))
}
```

## 重要设计原则

1. **泛型语法**：使用尖括号 `<T>`，约束紧邻参数 `<T: Ord>`，多约束连接 `<T: Ord + Clone + Default>`
   - 函数泛型：`fn max<T: Ord>(a: T, b: T) T { ... }`
   - 结构体泛型：`struct Vec<T: Default> { ... }`
   - 接口泛型：`interface Iterator<T> { ... }`
   - 类型参数使用：`Vec<i32>`, `Iterator<String>`
2. **宏系统**：编译时元编程，支持类型反射、代码生成、环境变量访问
   - 宏定义：`mc name(params) return_tag { ... }`
   - 编译时内置函数：`@mc_eval`、`@mc_type`、`@mc_ast`、`@mc_code`、`@mc_error`、`@mc_get_env`
   - 零运行时开销，编译期确定性
3. **编译期证明**：在当前函数内验证安全性，证明超时自动插入运行时检查
4. **显式控制**：所有类型注解显式，无隐式转换
5. **C兼容性**：所有结构体使用C内存布局，100% C互操作
6. **零运行时开销**：编译期完成所有可以静态确定的工作

---

**版本**：Uya 0.41  
**更新日期**：2026-02-01

