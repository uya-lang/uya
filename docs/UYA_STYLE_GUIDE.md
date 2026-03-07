# Uya 编码规范

本文档定义 Uya 语言的官方编码风格，作为格式化器的输出目标。

## 1. 文件结构

### 1.1 文件头注释

每个文件应以描述性注释开头：

```uya
// filename.uya - 简短描述
// 可选的额外说明
```

### 1.2 模块导入顺序

```uya
// 1. 文件头注释
// 2. 空行
// 3. 模块导入（按字母顺序或依赖顺序）
use std.io;
use std.testing.assert_eq_i32;

// 4. 空行
// 5. 常量定义
const MAX_SIZE: i32 = 1024;

// 6. 空行
// 7. 类型定义（struct, enum, type）
struct Point {
    x: i32,
    y: i32,
}

// 8. 空行
// 9. 函数定义
fn main() i32 {
    // ...
}
```

## 2. 缩进与空格

### 2.1 缩进

- 使用 **4 空格** 缩进
- 不使用 Tab

```uya
fn example() void {
    if true {
        do_something();
    }
}
```

### 2.2 行宽

- 最大行宽：**100 字符**
- 超过行宽时，在运算符或逗号后换行

## 3. 类型注解

### 3.1 变量声明

```uya
// 冒号后空格
const x: i32 = 10;
var name: &byte = "hello";

// 初始化表达式
const result: i32 = compute(a, b);
```

### 3.2 函数签名

```uya
// 返回类型前有空格
fn foo() i32 {
    return 0;
}

// 参数列表
fn add(a: i32, b: i32) i32 {
    return a + b;
}

// 指针参数
fn process(data: &byte, len: usize) void {
    // ...
}
```

### 3.3 结构体字段

```uya
struct Point {
    x: i32,
    y: i32,
}
```

## 4. 运算符

### 4.1 二元运算符

运算符前后各一个空格：

```uya
// 算术运算
a + b
a - b
a * b
a / b
a % b

// 比较运算
a == b
a != b
a < b
a > b
a <= b
a >= b

// 逻辑运算
a && b
a || b

// 位运算
a & b
a | b
a ^ b
a << 2
a >> 2

// 赋值
x = 10
x += 1
```

### 4.2 一元运算符

运算符与操作数之间无空格：

```uya
!flag
-count
&variable
*pointer
~bits
```

### 4.3 优先级明确

使用括号明确优先级：

```uya
// 好
const result: i32 = (a + b) * c;
const valid: bool = (x > 0) && (y > 0);

// 避免（依赖运算符优先级）
const result: i32 = a + b * c;
```

## 5. 控制语句

### 5.1 if 语句

```uya
// 基本形式
if condition {
    do_something();
}

// if-else
if condition {
    do_a();
} else {
    do_b();
}

// if-else if-else
if condition1 {
    do_a();
} else if condition2 {
    do_b();
} else {
    do_c();
}
```

### 5.2 while 语句

```uya
while condition {
    do_something();
}
```

### 5.3 for 语句

```uya
for items |item| {
    process(item);
}

// 带索引
for items |item, index| {
    process(item, index);
}
```

### 5.4 match 语句

```uya
match value {
    .variant1 => result1,
    .variant2 => result2,
    else => default_result,
}
```

## 6. 函数定义

### 6.1 单行函数

```uya
fn double(x: i32) i32 {
    return x * 2;
}
```

### 6.2 多参数函数

```uya
// 参数较多时，可换行对齐
fn process_data(
    input: &byte,
    input_len: usize,
    output: &byte,
    output_max: usize
) i32 {
    // ...
}
```

### 6.3 函数注释

```uya
// 计算两数之和
// 参数：a - 第一个数，b - 第二个数
// 返回：a + b
fn add(a: i32, b: i32) i32 {
    return a + b;
}
```

## 7. 结构体与枚举

### 7.1 结构体

```uya
struct Person {
    name: &byte,
    age: i32,
    email: &byte,
}

// 初始化
const p: Person = Person {
    name: "Alice",
    age: 30,
    email: "alice@example.com",
};
```

### 7.2 枚举

```uya
enum Color {
    RED,
    GREEN,
    BLUE,
}

// 带值的枚举
enum Status {
    STATUS_OK = 0,
    STATUS_ERROR = 1,
    STATUS_PENDING = 2,
}
```

### 7.3 Union

```uya
union Value {
    int_val: i32,
    float_val: f64,
    str_val: &byte,
}
```

## 8. 空行规则

### 8.1 必须的空行

- 函数之间：**1 个空行**
- 结构体/枚举定义后：**1 个空行**
- 导入语句块后：**1 个空行**
- 常量定义块后：**1 个空行**

### 8.2 可选的空行

- 逻辑块之间：**最多 1 个空行**
- 函数内部分组：**最多 1 个空行**

### 8.3 禁止的空行

- 连续多个空行（最多 1 个）
- 大括号内的首尾空行
- 行尾空白字符

## 9. 注释规范

### 9.1 单行注释

```uya
// 这是单行注释
const x: i32 = 10;  // 行尾注释（两个空格后）
```

### 9.2 文件头注释

```uya
// main.uya - 编译器主程序
// Uya 自举编译器
// 架构：export fn main 编译为 main_main
```

### 9.3 函数注释

```uya
// 初始化解析器
// 参数：parser - 解析器结构体指针
// 返回：成功返回 0，失败返回 -1
fn parser_init(parser: &Parser) i32 {
    // ...
}
```

## 10. 命名规范

### 10.1 变量与函数

- 使用 **snake_case**

```uya
const max_count: i32 = 100;
var current_index: i32 = 0;

fn compute_result() i32 {
    // ...
}
```

### 10.2 类型

- 结构体、枚举、Union：**PascalCase**
- 枚举成员：**SCREAMING_SNAKE_CASE**

```uya
struct HttpRequest {
    method: HttpMethod,
    path: &byte,
}

enum HttpMethod {
    HTTP_GET,
    HTTP_POST,
    HTTP_PUT,
    HTTP_DELETE,
}
```

### 10.3 常量

- 全局常量：**SCREAMING_SNAKE_CASE**
- 局部常量：**snake_case**

```uya
// 全局常量
const MAX_BUFFER_SIZE: i32 = 1024 * 1024;
const DEFAULT_TIMEOUT_MS: i32 = 5000;

// 局部常量
fn process() void {
    const buffer_size: i32 = 256;
}
```

## 11. 特殊语法

### 11.1 try 表达式

```uya
const result: i32 = try risky_operation();
```

### 11.2 defer 语句

```uya
fn process_file(path: &byte) i32 {
    const file: *void = fopen(path, "r");
    defer fclose(file);
    
    // 处理文件...
    return 0;
}
```

### 11.3 内置函数

```uya
const size: usize = @size_of(Point);
const aligned: usize = @align_of(i32);
const len: usize = @len(array);
```

### 11.4 泛型

```uya
fn max(a: T, b: T) T {
    if a > b {
        return a;
    }
    return b;
}
```

### 11.5 方法块

```uya
Point {
    fn distance(self: &Self, other: &Self) f64 {
        const dx: i32 = self.x - other.x;
        const dy: i32 = self.y - other.y;
        return @sqrt(dx * dx + dy * dy);
    }
}
```

## 12. 错误处理

### 12.1 错误声明

```uya
error FileNotFound;
error PermissionDenied;
error InvalidFormat;
```

### 12.2 错误返回

```uya
fn read_file(path: &byte) !&byte {
    if !file_exists(path) {
        return error.FileNotFound;
    }
    // ...
    return content;
}
```

### 12.3 错误捕获

```uya
const content: &byte = read_file(path) catch |err| {
    if err == error.FileNotFound {
        @println("文件不存在");
        return null;
    }
    return err;
};
```

## 13. 测试格式

### 13.1 测试块

```uya
test "test_name" {
    const result: i32 = add(1, 2);
    try assert_eq_i32(result, 3, "1 + 2 should equal 3");
}
```

### 13.2 测试文件组织

```
tests/
├── test_basic.uya        # 基础功能测试
├── test_types.uya        # 类型系统测试
└── test_errors/          # 错误处理测试
    └── test_runtime_error.uya
```

## 14. 禁止事项

### 14.1 不允许的风格

```uya
// ❌ 禁止：Tab 缩进
fn bad() void {
	return 0;  // Tab
}

// ❌ 禁止：多余空行
fn bad() void {
    const x: i32 = 1;



    return x;
}

// ❌ 禁止：运算符无空格
const result=i32=a+b*c;

// ❌ 禁止：类型注解无空格
const x:i32=10;

// ❌ 禁止：行尾空白
const x: i32 = 10;   
//                ^^^ 行尾空格

// ❌ 禁止：连续分号
const x: i32 = 1;;

// ❌ 禁止：空语句
;
```

## 15. 格式化示例

### 15.1 格式化前

```uya
export fn main( )i32{
// comment
const x:i32=1+2;
return x;}
```

### 15.2 格式化后

```uya
export fn main() i32 {
    // comment
    const x: i32 = 1 + 2;
    return x;
}
```

### 15.3 完整示例

```uya
// point.uya - 点类型定义
// 二维坐标点及其操作

use std.math.sqrt;

const ORIGIN_X: i32 = 0;
const ORIGIN_Y: i32 = 0;

struct Point {
    x: i32,
    y: i32,
}

enum DistanceUnit {
    UNIT_PIXELS,
    UNIT_METERS,
    UNIT_FEET,
}

Point {
    fn new(x: i32, y: i32) Self {
        return Self { x: x, y: y };
    }

    fn origin() Self {
        return Self { x: ORIGIN_X, y: ORIGIN_Y };
    }

    fn distance(self: &Self, other: &Self) f64 {
        const dx: i32 = self.x - other.x;
        const dy: i32 = self.y - other.y;
        return sqrt((dx * dx + dy * dy) as f64);
    }

    fn translate(self: &Self, dx: i32, dy: i32) void {
        self.x = self.x + dx;
        self.y = self.y + dy;
    }
}

test "test_distance" {
    const p1: Point = Point.origin();
    const p2: Point = Point.new(3, 4);
    
    const dist: f64 = p1.distance(&p2);
    try assert_eq_f64(dist, 5.0, "Distance should be 5.0");
}
```

## 16. 格式化器实现参考

### 16.1 核心规则总结

| 规则 | 实现 |
|------|------|
| 缩进 | 4 空格，大括号内增加一级 |
| 运算符空格 | 二元运算符前后各 1 空格 |
| 类型注解 | 冒号后 1 空格 |
| 函数返回 | 参数括号后 1 空格 |
| 大括号 | 同行开，独行闭 |
| 逗号 | 逗号后 1 空格 |
| 空行 | 最多 1 个连续空行 |
| 行尾 | 删除空白字符 |

### 16.2 AST 节点格式化优先级

1. 注释位置保留（挂载到对应节点）
2. 缩进级别计算
3. 运算符空格处理
4. 换行点选择
5. 行宽检查

---

**版本**: v1.0
**更新日期**: 2026-03-07
