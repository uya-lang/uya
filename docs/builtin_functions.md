# Uya 内置函数详细使用手册

> **版本**: 0.42  
> **最后更新**: 2026-02-06

---

## 目录

1. [概述](#概述)
2. [类型查询函数](#类型查询函数)
   - [@size_of](#size_of)
   - [@align_of](#align_of)
   - [@len](#len)
3. [类型极值常量](#类型极值常量)
   - [@max](#max)
   - [@min](#min)
4. [源代码位置函数](#源代码位置函数)
   - [@file](#file)
   - [@line](#line)
5. [高级内置函数](#高级内置函数)
   - [@params](#params)
6. [编译时内置函数（宏内）](#编译时内置函数宏内)
   - [@mc_eval](#mc_eval)
   - [@mc_type](#mc_type)
   - [@mc_ast](#mc_ast)
   - [@mc_code](#mc_code)
   - [@mc_error](#mc_error)
   - [@mc_get_env](#mc_get_env)
7. [最佳实践](#最佳实践)
8. [常见错误与解决方案](#常见错误与解决方案)

---

## 概述

Uya 语言的所有内置函数均以 `@` 开头，无需导入即可使用。这些函数在编译期求值，提供零运行时开销的类型信息查询、源代码位置追踪等功能。

### 内置函数签名总览

```uya
// 类型查询函数
fn @size_of(T: type) i32;                    // 返回类型 T 的字节大小
fn @align_of(T: type) i32;                   // 返回类型 T 的对齐字节数
fn @len<T, N>(array: [T: N]) i32;            // 返回数组元素个数

// 类型极值常量（类型从上下文推断）
const @max: T;                                // 整数类型的最大值
const @min: T;                                // 整数类型的最小值

// 源代码位置函数
const @file: *byte;                           // 当前源文件路径
const @line: i32;                             // 当前源代码行号

// 高级内置函数
const @params: (T1, T2, ..., Tn);            // 函数参数元组（仅函数体内）

// 编译时内置函数（仅宏内使用）
fn @mc_eval<T>(expr: expr) T;                // 编译时求值
fn @mc_type<T>(expr: expr) TypeInfo;         // 编译时类型反射
fn @mc_ast(code: any) AST;                   // 代码转 AST
fn @mc_code(ast: AST) code;                  // AST 转代码
fn @mc_error(message: *byte) never;          // 编译时报错
fn @mc_get_env(name: *byte) ?*byte;          // 读取环境变量

// 异步编程（规范 §18）
fn @async_fn() type;                          // 异步函数类型标记
fn @await<T>(future: Future<T>) !T;          // 异步等待
```

### 设计原则

1. **零运行时开销**: 所有内置函数在编译期展开为常量
2. **类型安全**: 编译器进行完整的类型检查
3. **明确语义**: 函数名清晰表达其功能
4. **统一命名**: 单一概念用短形式（`@len`），复合概念用下划线分隔（`@size_of`）

### 命名规范

- **单一概念**: `@len`, `@max`, `@min`（短形式）
- **复合概念**: `@size_of`, `@align_of`, `@async_fn`（snake_case）

---

## 类型查询函数

### @size_of

#### 函数签名
```uya
fn @size_of(T: type) i32
```

**伪类型系统表示**:
```uya
// 内置函数声明（编译器内部）
@builtin
fn @size_of(T: type) i32;

// 泛型参数说明：
//   T: type - 任意完全已知的类型（不能含待填充的泛型参数）
// 返回值：
//   i32 - 类型 T 的字节大小（编译期常量）
```

#### 功能说明
返回类型 `T` 的字节大小（编译期常量）。

#### 语法
```uya
@size_of(T) → i32
```

#### 参数
- `T`: 任意完全已知的类型（不能含待填充的泛型参数）

#### 返回值
- 类型: `i32`
- 值: 类型 `T` 的字节大小

#### 支持的类型

| 类型类别 | 示例 | 大小规则 |
|---------|------|---------|
| 基础整数 | `i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64` | 1, 2, 4, 8 字节 |
| 浮点数 | `f32`, `f64` | 4, 8 字节 |
| 布尔 | `bool` | 1 字节 |
| 指针 | `&T`, `*T` | 4 或 8 字节（取决于平台） |
| 数组 | `[T: N]` | `N * @size_of(T)` |
| 结构体 | `struct S{...}` | 按 C 规则布局，包含填充 |
| 联合体 | `union U{...}` | 最大变体的大小 |
| 原子类型 | `atomic T` | 与 `T` 相同 |

#### 使用示例

**基础类型查询**:
```uya
// 必要的外部函数声明
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    printf("i32 size: %d\n" as *byte, @size_of(i32));      // 4
    printf("f64 size: %d\n" as *byte, @size_of(f64));      // 8
    printf("bool size: %d\n" as *byte, @size_of(bool));    // 1
    return 0;
}
```

**结构体大小**:
```uya
extern fn printf(fmt: *byte, ...) i32;

struct Point {
    x: i32,
    y: i32,
}

fn main() i32 {
    const size: i32 = @size_of(Point);  // 8 (4 + 4)
    printf("Point size: %d\n" as *byte, size);
    return 0;
}
```

**数组大小**:
```uya
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    const arr_size: i32 = @size_of([i32: 100]);  // 400 (100 * 4)
    printf("Array size: %d\n" as *byte, arr_size);
    return 0;
}
```

**动态内存分配**:
```uya
extern fn malloc(size: i32) *byte;

struct Buffer {
    data: [i32: 1024],
    count: i32,
}

fn create_buffer() *Buffer {
    const size: i32 = @size_of(Buffer);
    const ptr: *byte = malloc(size);
    return ptr as *Buffer;
}
```

#### 常量表达式用法
```uya
// 在数组大小声明中使用
struct Packet {
    header: [byte: @size_of(i32) * 2],  // 8 字节头部
    data: [byte: 256],
}

// 在全局常量中使用
const BUFFER_SIZE: i32 = @size_of(i64) * 128;  // 1024
```

#### 注意事项

1. **类型必须完全已知**: 不能对泛型参数直接使用
   ```uya
   // ❌ 错误
   fn generic_size<T>() i32 {
       return @size_of(T);  // 编译错误：泛型参数
   }
   ```

2. **不支持表达式**: 只能对类型使用，不能对表达式
   ```uya
   // ❌ 错误
   const x: i32 = 42;
   const size: i32 = @size_of(x);  // 编译错误
   
   // ✅ 正确
   const size: i32 = @size_of(i32);
   ```

3. **返回值类型固定为 i32**: 超大类型会导致编译错误

---

### @align_of

#### 函数签名
```uya
fn @align_of(T: type) i32
```

**伪类型系统表示**:
```uya
// 内置函数声明（编译器内部）
@builtin
fn @align_of(T: type) i32;

// 泛型参数说明：
//   T: type - 任意完全已知的类型
// 返回值：
//   i32 - 类型 T 的对齐字节数（编译期常量）
```

#### 功能说明
返回类型 `T` 的对齐字节数（编译期常量）。

#### 语法
```uya
@align_of(T) → i32
```

#### 参数
- `T`: 任意完全已知的类型

#### 返回值
- 类型: `i32`
- 值: 类型 `T` 的对齐要求（字节数）

#### 对齐规则

| 类型类别 | 对齐规则 |
|---------|---------|
| 基础整数 | 等于类型大小（1, 2, 4, 8） |
| 浮点数 | 等于类型大小（4, 8） |
| 布尔 | 1 字节 |
| 指针 | 平台字长（4 或 8） |
| 数组 | 等于元素类型对齐 |
| 结构体 | 等于最大字段对齐 |
| 联合体 | 等于最大变体对齐 |

#### 使用示例

**基础类型对齐**:
```uya
// 必要的外部函数声明
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    printf("i8 align: %d\n" as *byte, @align_of(i8));      // 1
    printf("i16 align: %d\n" as *byte, @align_of(i16));    // 2
    printf("i32 align: %d\n" as *byte, @align_of(i32));    // 4
    printf("i64 align: %d\n" as *byte, @align_of(i64));    // 8
    return 0;
}
```

**结构体对齐**:
```uya
extern fn printf(fmt: *byte, ...) i32;

struct Mixed {
    a: i8,    // 1 字节，对齐 1
    b: i32,   // 4 字节，对齐 4
    c: i16,   // 2 字节，对齐 2
}

fn main() i32 {
    // 结构体对齐等于最大字段对齐
    const align: i32 = @align_of(Mixed);  // 4
    printf("Mixed align: %d\n" as *byte, align);
    return 0;
}
```

**对齐内存分配**:
```uya
extern fn aligned_alloc(alignment: i32, size: i32) *byte;

struct CacheAligned {
    data: [i64: 8],  // 64 字节
}

fn create_aligned() *CacheAligned {
    const align: i32 = @align_of(CacheAligned);  // 8
    const size: i32 = @size_of(CacheAligned);    // 64
    const ptr: *byte = aligned_alloc(align, size);
    return ptr as *CacheAligned;
}
```

#### 应用场景

1. **SIMD 对齐**: 确保数据满足 SIMD 指令要求
2. **缓存行对齐**: 避免伪共享
3. **硬件接口**: 满足硬件设备的对齐要求
4. **FFI 调用**: 确保与 C 结构体布局一致

---

### @len

#### 函数签名
```uya
fn @len<T, N>(array: [T: N]) i32
```

**伪类型系统表示**:
```uya
// 内置函数声明（编译器内部）
@builtin
fn @len<T, N>(array: [T: N]) i32;

// 泛型参数说明：
//   T: type - 数组元素类型
//   N: const i32 - 数组大小（编译期常量）
// 参数：
//   array: [T: N] - 任意数组类型
// 返回值：
//   i32 - 数组大小 N（编译期常量）
```

#### 功能说明
返回数组的元素个数（编译期常量）。

#### 语法
```uya
@len(array: [T: N]) → i32
```

#### 参数
- `array`: 任意数组类型 `[T: N]`

#### 返回值
- 类型: `i32`
- 值: 数组大小 `N`

#### 使用示例

**基础用法**:
```uya
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    const arr: [i32: 10] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    const len: i32 = @len(arr);  // 10
    printf("Array length: %d\n" as *byte, len);
    return 0;
}
```

**数组遍历**:
```uya
fn sum_array(arr: [i32: 100]) i32 {
    var total: i32 = 0;
    var i: i32 = 0;
    while i < @len(arr) {
        total = total + arr[i];
        i = i + 1;
    }
    return total;
}
```

**边界检查**:
```uya
fn safe_access(arr: [i32: 50], index: i32) !i32 {
    if index < 0 || index >= @len(arr) {
        return error.IndexOutOfBounds;
    }
    return arr[index];
}
```

**多维数组**:
```uya
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    const matrix: [[i32: 3]: 4] = [[0: 3]: 4];
    const rows: i32 = @len(matrix);        // 4
    const cols: i32 = @len(matrix[0]);     // 3
    printf("Matrix: %d x %d\n" as *byte, rows, cols);
    return 0;
}
```

#### 特殊行为：空数组字面量

对于空数组字面量 `[]`，`@len` 返回数组声明时的大小，而不是 0：

```uya
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    var buffer: [i32: 100] = [];  // 空初始化
    const len: i32 = @len(buffer);  // 100（从类型声明获取）
    printf("Buffer length: %d\n" as *byte, len);
    return 0;
}
```

#### 与 for 循环配合

```uya
extern fn printf(fmt: *byte, ...) i32;

fn print_array(arr: [i32: 10]) void {
    for i | 0..@len(arr) {
        printf("%d " as *byte, arr[i]);
    }
    printf("\n" as *byte);
}
```

---

## 类型极值常量

### @max

#### 常量签名
```uya
const @max: T  // T 从上下文推断
```

**伪类型系统表示**:
```uya
// 内置常量声明（编译器内部）
@builtin
const @max: <infer T from context>;

// 类型推断规则：
//   T 必须是有符号或无符号整数类型
//   从变量声明、函数参数、返回值等上下文推断
// 返回值：
//   T - 类型 T 的最大值（编译期常量）
```

#### 功能说明
返回整数类型的最大值（编译期常量，类型从上下文推断）。

#### 语法
```uya
@max → T  // T 从上下文推断
```

#### 支持的类型
- `i8`, `i16`, `i32`, `i64`
- `u8`, `u16`, `u32`, `u64`
- `usize`

#### 类型推断规则

编译器从以下上下文推断类型：
1. **变量类型注解**: `const x: i32 = @max;`
2. **函数参数类型**: `fn foo(x: i32) { ... foo(@max); }`
3. **返回类型**: `fn get_max() i32 { return @max; }`
4. **二元运算类型**: `if x > @max - 10 { ... }`

#### 使用示例

**基础用法**:
```uya
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    const max_i32: i32 = @max;      // 2147483647
    const max_i64: i64 = @max;      // 9223372036854775807
    const max_u8: u8 = @max;        // 255
    
    printf("i32 max: %d\n" as *byte, max_i32);
    printf("i64 max: %ld\n" as *byte, max_i64);
    printf("u8 max: %u\n" as *byte, max_u8);
    return 0;
}
```

**边界检查**:
```uya
fn safe_add(a: i32, b: i32) !i32 {
    // 检查是否会溢出
    if b > 0 && a > @max - b {
        return error.Overflow;
    }
    if b < 0 && a < @min - b {
        return error.Overflow;
    }
    return a + b;
}
```

**范围验证**:
```uya
fn validate_percentage(value: i32) !i32 {
    const MIN: i32 = 0;
    const MAX: i32 = 100;
    
    if value < MIN || value > MAX {
        return error.OutOfRange;
    }
    return value;
}

fn validate_u8_range(value: i32) !u8 {
    const max_u8: i32 = @max as i32;  // 类型推断为 u8，然后转换
    if value < 0 || value > max_u8 {
        return error.OutOfRange;
    }
    return value as u8;
}
```

**初始化最小值查找**:
```uya
fn find_min(arr: [i32: 100]) i32 {
    var min: i32 = @max;  // 初始化为最大值
    for i | 0..@len(arr) {
        if arr[i] < min {
            min = arr[i];
        }
    }
    return min;
}
```

---

### @min

#### 常量签名
```uya
const @min: T  // T 从上下文推断
```

**伪类型系统表示**:
```uya
// 内置常量声明（编译器内部）
@builtin
const @min: <infer T from context>;

// 类型推断规则：
//   T 必须是有符号或无符号整数类型
//   从变量声明、函数参数、返回值等上下文推断
// 返回值：
//   T - 类型 T 的最小值（编译期常量）
```

#### 功能说明
返回整数类型的最小值（编译期常量，类型从上下文推断）。

#### 语法
```uya
@min → T  // T 从上下文推断
```

#### 使用示例

**基础用法**:
```uya
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    const min_i32: i32 = @min;      // -2147483648
    const min_i64: i64 = @min;      // -9223372036854775808
    const min_u8: u8 = @min;        // 0
    
    printf("i32 min: %d\n" as *byte, min_i32);
    printf("i64 min: %ld\n" as *byte, min_i64);
    printf("u8 min: %u\n" as *byte, min_u8);
    return 0;
}
```

**初始化最大值查找**:
```uya
fn find_max(arr: [i32: 100]) i32 {
    var max: i32 = @min;  // 初始化为最小值
    for i | 0..@len(arr) {
        if arr[i] > max {
            max = arr[i];
        }
    }
    return max;
}
```

**负数检查**:
```uya
fn is_negative(value: i32) bool {
    return value < 0;
}

fn abs(value: i32) i32 {
    // 特殊处理最小值（因为 -MIN 会溢出）
    if value == @min {
        return @max;  // 或返回错误
    }
    return if value < 0 { -value } else { value };
}
```

---

## 源代码位置函数

### @file

#### 常量签名
```uya
const @file: *byte
```

**伪类型系统表示**:
```uya
// 内置常量声明（编译器内部）
@builtin
const @file: *byte;

// 返回值：
//   *byte - 当前源文件路径（C 字符串，null 终止）
//   每次使用时展开为所在文件的路径字符串字面量
```

#### 功能说明
返回当前源文件的路径（编译期常量）。

#### 语法
```uya
@file → *byte
```

#### 返回值
- 类型: `*byte`（C 字符串指针，null 终止）
- 值: 当前源文件的路径字符串

#### 使用示例

**日志记录**:
```uya
// 必要的外部函数声明
extern fn printf(fmt: *byte, ...) i32;

fn log_info(message: *byte) void {
    printf("[INFO] %s:%d - %s\n" as *byte, @file, @line, message);
}

fn log_error(message: *byte) void {
    printf("[ERROR] %s:%d - %s\n" as *byte, @file, @line, message);
}

fn main() i32 {
    log_info("程序启动" as *byte);
    log_error("发现错误" as *byte);
    return 0;
}
```

**断言实现**:
```uya
fn assert(condition: bool, message: *byte) void {
    if !condition {
        printf("断言失败于 %s:%d: %s\n" as *byte, 
               @file, @line, message);
        // 这里可以调用 abort() 终止程序
    }
}

fn main() i32 {
    const x: i32 = 10;
    assert(x > 0, "x 必须为正数" as *byte);
    assert(x < 100, "x 必须小于 100" as *byte);
    return 0;
}
```

**调试信息**:
```uya
fn debug_print(value: i32) void {
    printf("Debug [%s:%d]: value = %d\n" as *byte, 
           @file, @line, value);
}

fn main() i32 {
    var counter: i32 = 0;
    debug_print(counter);  // 显示文件名和行号
    counter = counter + 1;
    debug_print(counter);
    return 0;
}
```

**错误追踪**:
```uya
struct ErrorInfo {
    file: *byte,
    line: i32,
    message: *byte,
}

fn create_error(message: *byte) ErrorInfo {
    return ErrorInfo{
        file: @file,
        line: @line,
        message: message,
    };
}

fn report_error(error: ErrorInfo) void {
    printf("错误发生于 %s:%d\n  消息: %s\n" as *byte,
           error.file, error.line, error.message);
}
```

#### 特性

1. **编译期展开**: 直接替换为字符串字面量
2. **零运行时开销**: 不涉及函数调用或运行时计算
3. **完整路径**: 通常包含相对或绝对路径
4. **每次调用独立**: 每个 `@file` 都会展开为其所在文件的路径

---

### @line

#### 常量签名
```uya
const @line: i32
```

**伪类型系统表示**:
```uya
// 内置常量声明（编译器内部）
@builtin
const @line: i32;

// 返回值：
//   i32 - 当前源代码行号（从 1 开始）
//   每次使用时展开为所在位置的行号整数字面量
```

#### 功能说明
返回当前源代码的行号（编译期常量）。

#### 语法
```uya
@line → i32
```

#### 返回值
- 类型: `i32`
- 值: 当前代码所在的行号（从 1 开始）

#### 使用示例

**简单日志**:
```uya
// 必要的外部函数声明
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    printf("执行到第 %d 行\n" as *byte, @line);  // 第 5 行
    
    const x: i32 = 42;
    printf("x = %d（第 %d 行）\n" as *byte, x, @line);  // 第 8 行
    
    return 0;
}
```

**性能分析标记**:
```uya
extern fn get_timestamp() i64;

struct ProfilePoint {
    file: *byte,
    line: i32,
    timestamp: i64,
}

fn mark_point() ProfilePoint {
    return ProfilePoint{
        file: @file,
        line: @line,
        timestamp: get_timestamp(),
    };
}

fn main() i32 {
    const start: ProfilePoint = mark_point();
    
    // 执行一些操作
    var sum: i32 = 0;
    for i | 0..1000000 {
        sum = sum + i;
    }
    
    const end: ProfilePoint = mark_point();
    
    printf("从 %s:%d 到 %s:%d\n耗时: %ld\n" as *byte,
           start.file, start.line,
           end.file, end.line,
           end.timestamp - start.timestamp);
    
    return 0;
}
```

**条件断点**:
```uya
fn process_item(index: i32, value: i32) void {
    // 只在特定条件下记录调试信息
    if value < 0 {
        printf("警告：负值 %d（第 %d 行，索引 %d）\n" as *byte,
               value, @line, index);
    }
}
```

**测试框架**:
```uya
struct TestCase {
    name: *byte,
    file: *byte,
    line: i32,
}

fn register_test(name: *byte) TestCase {
    return TestCase{
        name: name,
        file: @file,
        line: @line,
    };
}

fn main() i32 {
    const test1: TestCase = register_test("加法测试" as *byte);
    const test2: TestCase = register_test("减法测试" as *byte);
    
    printf("测试 '%s' 定义于 %s:%d\n" as *byte,
           test1.name, test1.file, test1.line);
    printf("测试 '%s' 定义于 %s:%d\n" as *byte,
           test2.name, test2.file, test2.line);
    
    return 0;
}
```

#### 特殊行为

**同一行多次使用**:
```uya
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    const line1: i32 = @line; const line2: i32 = @line;
    // line1 和 line2 的值相同（都是这一行的行号）
    printf("两个值都是 %d\n" as *byte, line1);
    return 0;
}
```

**不同行使用**:
```uya
extern fn printf(fmt: *byte, ...) i32;

fn main() i32 {
    const line1: i32 = @line;  // 假设是第 N 行
    const line2: i32 = @line;  // 假设是第 N+1 行
    // line2 == line1 + 1
    printf("line1=%d, line2=%d\n" as *byte, line1, line2);
    return 0;
}
```

---

## 高级内置函数

### @params

#### 常量签名
```uya
const @params: (T1, T2, ..., Tn)  // 类型从函数参数推断
```

**伪类型系统表示**:
```uya
// 内置常量声明（编译器内部）
@builtin
const @params: <tuple of function parameters>;

// 上下文要求：
//   只能在函数体内使用
// 返回值：
//   (T1, T2, ..., Tn) - 当前函数的参数元组
```

#### 功能说明
在函数体内访问参数元组（编译期类型推断）。

#### 语法
```uya
@params → (T1, T2, ..., Tn)
```

#### 返回值
- 类型: 元组类型，包含所有函数参数
- 值: 当前函数的参数元组

#### 使用示例

**参数转发**:
```uya
extern fn printf(fmt: *byte, ...) i32;

fn log_call(name: *byte, args: (i32, i32)) void {
    printf("调用 %s(%d, %d)\n" as *byte, 
           name, args.0, args.1);
}

fn add(x: i32, y: i32) i32 {
    log_call("add" as *byte, @params);
    return x + y;
}

fn multiply(x: i32, y: i32) i32 {
    log_call("multiply" as *byte, @params);
    return x * y;
}
```

**泛型参数访问**:
```uya
fn process<T>(value: T) void {
    // @params 类型为 (T,)
    const params: (T,) = @params;
    printf("处理值: " as *byte);
    // ... 使用 params.0
}
```

#### 限制
- 只能在函数体内使用
- 不能在全局作用域或结构体中使用

---

## 编译时内置函数（宏内）

这些函数只能在宏定义内部使用，用于编译时元编程。

### @mc_eval

#### 函数签名
```uya
fn @mc_eval<T>(expr: expr) T
```

**伪类型系统表示**:
```uya
// 编译时内置函数声明（编译器内部）
@builtin @compile_time
fn @mc_eval<T>(expr: expr) T;

// 泛型参数说明：
//   T: type - 表达式的求值结果类型
// 参数：
//   expr: expr - 编译时表达式（宏参数）
// 返回值：
//   T - 表达式在编译期的求值结果
// 上下文要求：
//   只能在宏定义内使用
```

#### 功能说明
编译时求值表达式。

#### 语法
```uya
@mc_eval(expr) → 求值结果
```

#### 使用示例

```uya
mc square(x: expr) expr {
    return @mc_eval(x * x);
}

fn main() i32 {
    const result: i32 = square(5);  // 编译期计算为 25
    return result;
}
```

---

### @mc_type

#### 函数签名
```uya
fn @mc_type(expr: expr) TypeInfo
```

**伪类型系统表示**:
```uya
// 编译时内置函数声明（编译器内部）
@builtin @compile_time
fn @mc_type(expr: expr) TypeInfo;

// 参数：
//   expr: expr - 任意表达式或类型（宏参数）
// 返回值：
//   TypeInfo - 类型信息结构体
// 上下文要求：
//   只能在宏定义内使用
```

#### 功能说明
编译时类型反射，返回 `TypeInfo` 结构体。

#### 语法
```uya
@mc_type(expr) → TypeInfo
```

#### TypeInfo 结构体

```uya
struct TypeInfo {
    name: *i8,
    size: i32,
    align: i32,
    kind: i32,
    is_integer: bool,
    is_float: bool,
    is_bool: bool,
    is_pointer: bool,
    is_array: bool,
    is_void: bool,
}
```

#### 使用示例

```uya
mc print_type_info(T: type) stmt {
    const info: TypeInfo = @mc_type(T);
    return @mc_code({
        printf("类型: %s\n" as *byte, info.name);
        printf("大小: %d 字节\n" as *byte, info.size);
        printf("对齐: %d 字节\n" as *byte, info.align);
    });
}

fn main() i32 {
    print_type_info(i32);
    print_type_info(f64);
    return 0;
}
```

---

### @mc_ast

#### 函数签名
```uya
fn @mc_ast(code: any) AST
```

**伪类型系统表示**:
```uya
// 编译时内置函数声明（编译器内部）
@builtin @compile_time
fn @mc_ast(code: expr | stmt | block) AST;

// 参数：
//   code: expr | stmt | block - 代码片段
// 返回值：
//   AST - 抽象语法树表示
// 上下文要求：
//   只能在宏定义内使用
```

#### 功能说明
将代码转换为抽象语法树（AST）表示。

#### 语法
```uya
@mc_ast(code) → AST
```

---

### @mc_code

#### 函数签名
```uya
fn @mc_code(ast: AST) code
```

**伪类型系统表示**:
```uya
// 编译时内置函数声明（编译器内部）
@builtin @compile_time
fn @mc_code(ast: AST) code;

// 参数：
//   ast: AST - 抽象语法树
// 返回值：
//   code - 代码表示（expr | stmt | block）
// 上下文要求：
//   只能在宏定义内使用
```

#### 功能说明
将 AST 转换回代码。

#### 语法
```uya
@mc_code(ast) → code
```

---

### @mc_error

#### 函数签名
```uya
fn @mc_error(message: *byte) never
```

**伪类型系统表示**:
```uya
// 编译时内置函数声明（编译器内部）
@builtin @compile_time
fn @mc_error(message: *byte) never;

// 参数：
//   message: *byte - 错误消息字符串
// 返回值：
//   never - 不返回（终止编译）
// 上下文要求：
//   只能在宏定义内使用
```

#### 功能说明
在编译时报告错误。

#### 语法
```uya
@mc_error(message)
```

#### 使用示例

```uya
mc assert_positive(value: expr) expr {
    const val: i32 = @mc_eval(value);
    if val < 0 {
        @mc_error("值必须为正数");
    }
    return value;
}

fn main() i32 {
    const x: i32 = assert_positive(10);  // 通过
    // const y: i32 = assert_positive(-5);  // 编译错误
    return x;
}
```

---

### @mc_get_env

#### 函数签名
```uya
fn @mc_get_env(name: *byte) ?*byte
```

**伪类型系统表示**:
```uya
// 编译时内置函数声明（编译器内部）
@builtin @compile_time
fn @mc_get_env(name: *byte) ?*byte;

// 参数：
//   name: *byte - 环境变量名称
// 返回值：
//   ?*byte - 环境变量值（存在时）或 null（不存在时）
// 上下文要求：
//   只能在宏定义内使用
```

#### 功能说明
读取编译时环境变量。

#### 语法
```uya
@mc_get_env(name) → 字符串或空
```

#### 使用示例

```uya
mc get_version() expr {
    const version: *byte = @mc_get_env("VERSION");
    return version;
}

fn main() i32 {
    const ver: *byte = get_version();
    printf("版本: %s\n" as *byte, ver);
    return 0;
}
```

---

## 最佳实践

### 1. 使用 @size_of 和 @align_of 进行安全的内存操作

```uya
extern fn malloc(size: i32) *byte;
extern fn memset(ptr: *byte, value: i32, size: i32) *byte;

fn allocate_zeroed<T>() *T {
    const size: i32 = @size_of(T);
    const ptr: *byte = malloc(size);
    memset(ptr, 0, size);
    return ptr as *T;
}
```

### 2. 使用 @len 进行安全的数组访问

```uya
fn bounds_check_access(arr: [i32: 100], index: i32) !i32 {
    if index < 0 || index >= @len(arr) {
        return error.IndexOutOfBounds;
    }
    return arr[index];
}
```

### 3. 使用 @max/@min 进行溢出检查

```uya
fn safe_multiply(a: i32, b: i32) !i32 {
    if a > 0 && b > 0 && a > @max / b {
        return error.Overflow;
    }
    if a < 0 && b < 0 && a < @max / b {
        return error.Overflow;
    }
    return a * b;
}
```

### 4. 使用 @file/@line 进行调试

```uya
fn debug_assert(condition: bool, message: *byte) void {
    if !condition {
        printf("断言失败 [%s:%d]: %s\n" as *byte,
               @file, @line, message);
    }
}
```

### 5. 组合使用多个内置函数

```uya
fn validate_array_access(arr: [i32: 50], index: i32) !void {
    if index < 0 || index >= @len(arr) {
        printf("错误 [%s:%d]: 索引 %d 越界（数组长度 %d）\n" as *byte,
               @file, @line, index, @len(arr));
        return error.IndexOutOfBounds;
    }
}
```

---

## 常见错误与解决方案

### 错误 1: 对泛型参数使用 @size_of

```uya
// ❌ 错误
fn generic_alloc<T>() *T {
    const size: i32 = @size_of(T);  // 编译错误
    return malloc(size) as *T;
}

// ✅ 解决方案：使用宏
mc generic_alloc(T: type) expr {
    const size: i32 = @size_of(T);  // 在宏内可以使用
    return @mc_code({
        malloc(size) as *T
    });
}
```

### 错误 2: 对表达式使用 @size_of

```uya
// ❌ 错误
const x: i32 = 42;
const size: i32 = @size_of(x);  // 编译错误

// ✅ 正确
const size: i32 = @size_of(i32);
```

### 错误 3: @max/@min 类型推断失败

```uya
// ❌ 错误：无法推断类型
const max_val = @max;  // 编译错误

// ✅ 正确：提供类型注解
const max_val: i32 = @max;

// ✅ 正确：从上下文推断
fn get_max() i32 {
    return @max;
}
```

### 错误 4: 在全局作用域使用 @params

```uya
// ❌ 错误
const global_params = @params;  // 编译错误

// ✅ 正确：只在函数内使用
fn example(x: i32, y: i32) void {
    const params = @params;  // 正确
}
```

### 错误 5: @file/@line 的值不是编译期常量

实际上 `@file` 和 `@line` 就是编译期常量：

```uya
// ✅ 可以在常量表达式中使用
const SOURCE_FILE: *byte = @file;
const SOURCE_LINE: i32 = @line;

// ✅ 可以在数组大小中使用（如果逻辑合理）
// 注意：这只是示例，实际用途有限
const DEBUG_INFO: [byte: @line] = [0: @line];
```

---

## 总结

Uya 的内置函数提供了强大的编译期能力：

1. **类型查询** (`@size_of`, `@align_of`, `@len`): 编译期获取类型信息
2. **类型极值** (`@max`, `@min`): 类型安全的边界检查
3. **源码定位** (`@file`, `@line`): 调试和错误报告
4. **元编程** (`@params`, `@mc_*`): 高级编译期编程

所有这些函数都遵循"零运行时开销"原则，在编译期完全展开，为高性能和类型安全提供坚实基础。

---

**相关文档**:
- [uya.md](../uya.md) - 完整语言规范
- [grammar_formal.md](../grammar_formal.md) - 正式语法规范
- [UYA_MINI_SPEC.md](../compiler-mini/spec/UYA_MINI_SPEC.md) - Mini 子集规范
