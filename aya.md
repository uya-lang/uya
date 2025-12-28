# 阿雅语言规范 0.9（完整版 · 2025-12-28）

> 零GC · 默认Rust级安全 · 单页纸可读完 · 通过路径零指令  
> 无lifetime符号 · 无隐式控制

---

## 目录

- [0.9 核心特性](#09-核心特性)
- [设计哲学](#设计哲学)
- [1. 文件与词法](#1-文件与词法)
- [2. 类型系统](#2-类型系统)
- [3. 变量与作用域](#3-变量与作用域)
- [4. 结构体](#4-结构体)
- [5. 函数](#5-函数)
  - [5.1 普通函数](#51-普通函数)
  - [5.2 外部 C 函数（FFI）](#52-外部-c-函数ffi)
- [6. 接口（interface）](#6-接口interface)
- [7. 栈式数组（零 GC）](#7-栈式数组零-gc)
- [8. 控制流](#8-控制流)
- [9. defer 和 errdefer](#9-defer-和-errdefer)
- [10. 运算符与优先级](#10-运算符与优先级)
- [11. 类型转换](#11-类型转换)
- [12. 内存模型 & RAII](#12-内存模型--raii)
- [13. 原子操作（0.9 终极简洁）](#13-原子操作09-终极简洁)
- [14. 内存安全（0.9 强制）](#14-内存安全09-强制)
- [15. 并发安全（0.9 强制）](#15-并发安全09-强制)
- [16. 标准库（0.9 最小集）](#16-标准库09-最小集)
- [17. 完整示例：结构体 + 栈数组 + FFI](#17-完整示例结构体--栈数组--ffi)
- [18. 完整示例：错误处理 + defer/errdefer](#18-完整示例错误处理--defererrdefer)
- [19. 完整示例：默认安全并发](#19-完整示例默认安全并发)
- [20. 完整示例：Zig风格的for循环](#20-完整示例zig风格的for循环)
- [21. 字符串与格式化（0.9）](#21-字符串与格式化09)
- [22. 未实现/将来](#22-未实现将来)
- [23. 一句话总结](#23-一句话总结)
- [术语表](#术语表)

---

## 0.9 核心特性

- **原子类型**（第 13 章）：`atomic T` 关键字，自动原子指令，零运行时锁
- **内存安全强制**（第 14 章）：所有 UB 必须被编译期证明为安全，失败即编译错误
- **并发安全强制**（第 15 章）：零数据竞争，通过路径零指令
- **字符串插值**（第 21 章）：支持 `"a${x}"` 和 `"pi=${pi:.2f}"` 两种形式

---

## 设计哲学

### 核心思想

将运行时的"可能越界"转化为编译期的"要么证明安全，要么返回显式错误"。

**核心机制**：
- 程序员必须提供**显式边界检查**，帮助编译器完成证明
- 编译器在编译期验证这些证明，无法证明安全即编译错误
- 每个数组访问都有明确的**数学证明**，消除运行时不确定性

**示例对比**：

```c
// C/C++：程序员负责，编译器不检查
int arr[10];
int i = get_index();  // 可能越界
int x = arr[i];       // 运行时可能崩溃，编译器不警告
```

```rust
// Rust：借用检查器帮助，但需要所有权系统
let arr = [0; 10];
let i = get_index();
if i < arr.len() {
    let x = arr[i];  // 借用检查器保证安全
} else {
    // 需要处理越界情况
}
```

```aya
// 阿雅：程序员提供证明，编译器验证证明
let arr: [i32; 10] = [0; 10];
let i: i32 = get_index();
if i < 0 || i >= 10 {
    return error.OutOfBounds;  // 显式检查，返回错误
}
let x: i32 = arr[i];  // 编译器证明 i >= 0 && i < 10，安全
```

### 责任转移的哲学

这不是语言限制，而是**责任转移**：

| 语言 | 安全责任 | 编译器角色 |
|------|---------|-----------|
| **C/C++** | 程序员负责安全 | 编译器不帮忙，只生成代码 |
| **Rust** | 编译器通过借用检查器帮忙 | 编译器主动检查所有权和生命周期 |
| **阿雅** | 程序员必须提供证明，编译器验证证明 | 编译器验证数学证明，失败即编译错误 |

**哲学差异**：

- **C/C++**：信任程序员，但错误代价高昂（缓冲区溢出、空指针解引用等）
- **Rust**：编译器主动介入，通过所有权系统自动管理，但需要学习借用规则
- **阿雅**：程序员显式证明，编译器验证证明，**零运行时开销，失败路径不存在**

### 结果与收益

虽然代码可能更长（需要显式边界检查），但带来以下收益：

1. **数学证明的确定性**：每个数组访问都有明确的数学证明（`i >= 0 && i < len`）
2. **消除整类安全漏洞**：彻底消除缓冲区溢出等内存安全漏洞
3. **零运行时开销**：所有检查在编译期完成，通过路径零指令
4. **失败路径不存在**：无法证明安全的代码不生成，运行时不会出现未定义行为

**性能对比**：

```aya
// 阿雅：编译期证明，零运行时检查
fn safe_access(arr: [i32; 10], i: i32) -> !i32 {
    if i < 0 || i >= 10 {
        return error.OutOfBounds;  // 显式错误返回
    }
    return arr[i];  // 编译器证明安全，直接访问，零运行时检查
}

// 编译后生成（x86-64）：
//   cmp  edi, 9
//   jg   .error
//   mov  eax, [rsi + rdi*4]  // 直接访问，无运行时边界检查
//   ret
```


### 一句话总结

> **阿雅的设计哲学 = 程序员提供证明，编译器验证证明**；  
> **将运行时的不确定性转化为编译期的确定性，零运行时开销，失败路径不存在。**

---

## 1 文件与词法

- 文件编码 UTF-8，Unix 换行 `\n`。
- 关键字保留：
  ```
  struct let mut const fn return extern true false if while break continue
  defer errdefer try catch error null interface impl atomic max min
  ```
- 标识符 `[A-Za-z_][A-Za-z0-9_]*`，区分大小写。
- 数值字面量：
  - 整数字面量：`123`（默认类型 `i32`，除非上下文需要其他整数类型）
  - 浮点字面量：`123.456`（默认类型 `f64`，除非上下文需要 `f32`）
- 布尔字面量：`true`、`false`，类型为 `bool`
- 空指针字面量：`null`，类型为 `byte*`
  - 用于与 `byte*` 类型比较，表示空指针：`if ptr == null { ... }`
  - 可以作为 FFI 函数参数（如果函数接受 `byte*`）：`some_function(null);`
  - 0.9 不支持将 `null` 赋值给 `byte*` 类型的变量（后续版本可能支持）
- 字符串字面量：
  - **普通字符串字面量**：`"..."`，类型为 `byte*`（FFI 专用类型，不是普通指针）
    - **重要说明**：`byte*` 是专门用于 FFI（外部函数接口）的特殊类型，表示 C 字符串指针（null 终止）
    - `byte*` 与普通指针类型 `&T` 不同：`byte*` 仅用于 FFI 上下文，不能进行指针运算或解引用
    - 支持转义序列：`\n` 换行、`\t` 制表符、`\\` 反斜杠、`\"` 双引号、`\0` null 字符
    - 0.9 不支持 `\xHH` 或 `\uXXXX`（后续版本支持）
    - 字符串字面量在 FFI 调用时自动添加 null 终止符
    - **字符串字面量的使用规则**：
      - ✅ 可以作为 FFI 函数调用的参数：`printf("hello\n");`
      - ✅ 可以作为 FFI 函数声明的参数类型示例：`extern i32 printf(byte* fmt, ...);`
      - ✅ 可以与 `null` 比较（如果函数返回 `byte*`）：`if ptr == null { ... }`
      - ❌ 不能赋值给变量：`let s: byte* = "hello";`（编译错误）
      - ❌ 不能用于数组索引：`arr["hello"]`（编译错误）
      - ❌ 不能用于其他非 FFI 操作
  - **原始字符串字面量**：`` `...` ``，类型为 `byte*`（无转义序列，用于包含特殊字符的字符串）
    - 不支持任何转义序列，所有字符按字面量处理
    - 示例：`` `C:\Users\name` `` 表示字面量字符串，不进行转义
  - **字符串插值**：`"text${expr}text"` 或 `"text${expr:format}text"`，类型为 `[i8; N]`（编译期展开的定长栈数组）
    - **类型说明**：`i8` 是有符号 8 位整数，与 `byte`（无符号 8 位整数）大小相同但符号不同
    - 字符串插值使用 `i8` 是因为 C 字符串通常使用 `char`（有符号），与 C 互操作兼容
    - 支持两种形式：
      - 基本形式：`"a${x}"`（无格式说明符）
      - 格式化形式：`"pi=${pi:.2f}"`（带格式说明符，与 C printf 保持一致）
    - 语法：`segment = TEXT | '${' expr [':' spec] '}'`
    - 格式说明符 `spec` 与 C printf 保持一致，详见第 21 章
    - 编译期展开为定长栈数组，零运行时解析开销，零堆分配
    - 示例：`let msg: [i8; 64] = "hex=${x:#06x}, pi=${pi:.2f}\n";`
- 数组字面量：
  - 列表式：`[expr1, expr2, ..., exprN]`（元素数量必须等于数组大小）
  - 重复式：`[value; N]`（value 重复 N 次，N 为编译期常量）
  - 数组字面量的所有元素类型必须完全一致
  - 元素类型必须与数组声明类型匹配（0.9 不支持类型推断）
  - 示例：`let arr: [f32; 4] = [1.0, 2.0, 3.0, 4.0];`（元素类型 `f32` 必须与数组元素类型 `f32` 完全匹配）
- 注释 `// 到行尾` 或 `/* 块 */`（可嵌套）。

---

## 2 类型系统

| 阿雅类型        | C 对应        | 大小/对齐 | 备注                     |
|-----------------|---------------|-----------|--------------------------|
| `i8` `i16` `i32` `i64` | 同宽 signed | 1 2 4 8 B | 对齐 = 类型大小；支持 `max/min` 关键字访问极值（类型推断） |
| `f32` `f64`     | float/double  | 4/8 B     | 对齐 = 类型大小          |
| `bool`          | uint8_t       | 1 B       | 0/1，对齐 1 B            |
| `byte`          | uint8_t       | 1 B       | 无符号字节，对齐 1 B，用于字节数组 |
| `void`          | void          | 0 B       | 仅用于函数返回类型       |
| `byte*`         | char*         | 4/8 B（平台相关） | 用于 FFI 函数参数和返回值，指向 C 字符串；32位平台=4B，64位平台=8B；可与 `null` 比较（空指针）|
| `&T`            | 普通指针      | 8 B       | 无 lifetime 符号，见下方说明 |
| `&atomic T`  | 原子指针      | 8 B       | 关键字驱动，见第 13 章 |
| `atomic T`      | 原子类型      | sizeof(T) | 语言级原子类型，见第 13 章 |
| `[T; N]`        | T[N]          | N·sizeof(T) | N 为编译期正整数，对齐 = T 的对齐 |
| `struct S { }`  | struct S      | 字段顺序布局 | 对齐 = 最大字段对齐，见下方说明 |
| `interface I { }` | -         | 16 B (64位) | vtable 指针(8B) + 数据指针(8B)，见第 6 章接口 |
| `extern` 函数   | C 函数声明    | -         | 0.9 不支持函数指针类型，`extern` 仅用于声明外部 C 函数，见 5.2 |
| `!T`            | 错误联合类型  | max(sizeof(T), sizeof(错误标记)) + 对齐填充 | `T | Error`，见下方说明 |

- 无隐式转换；无指针算术；无 lifetime 符号。

**类型相关的极值常量**：
- 整数类型（`i8`, `i16`, `i32`, `i64`）支持通过 `max` 和 `min` 关键字访问极值
- 语法：`max` 和 `min`（编译器从上下文类型推断）
- 编译器根据上下文类型自动推断极值类型，这些是编译期常量，零运行时开销
- 示例：
  ```aya
  const MAX: i32 = max;  // 2147483647（从类型注解 i32 推断）
  const MIN: i32 = min;  // -2147483648（从类型注解 i32 推断）
  
  // 在溢出检查中使用（从变量类型推断）
  let a: i32 = ...;
  let b: i32 = ...;
  if a > 0 && b > 0 && a > max - b {  // 从 a 和 b 的类型 i32 推断
      return error.Overflow;
  }
  ```

**指针类型说明**：
- `byte*`：专门用于 FFI，表示 C 字符串指针（null 终止），只能用于：
  - FFI 函数参数和返回值类型声明
  - 与 `null` 比较（空指针检查）
  - 字符串字面量在 FFI 调用时自动转换为 `byte*`
  - 0.9 不支持将 `byte*` 赋值给变量或进行其他操作
- `&T`：普通指针类型，8 字节（64位平台），无 lifetime 符号
  - 用于指向类型 `T` 的值
  - 空指针检查：`if ptr == null { ... }`（需要显式检查，编译期证明失败即编译错误）
  - 0.9 不支持指针算术
- `&atomic T`：原子指针类型，8 字节，关键字驱动
  - 用于指向原子类型 `atomic T` 的指针
  - 见第 13 章原子操作
- `*T`：仅用于接口方法签名，表示指针参数，不能用于普通变量声明或 FFI 函数声明
  - **语法规则**：
    - `*T` 语法仅在接口定义和 `impl` 块的方法签名中使用
    - `*T` 表示指向类型 `T` 的指针参数（按引用传递，但语法使用 `*` 前缀）
    - 与 `&T` 的区别：`&T` 用于普通变量和函数参数，`*T` 仅用于接口方法签名
  - **示例**：接口方法 `fn write(self: *Self, buf: *byte, len: i32)` 中：
    - `*Self` 表示指向实现接口的结构体类型的指针（`Self` 是占位符，编译期替换为具体类型）
    - `*byte` 表示指向 `byte` 类型的指针参数
  - **FFI 调用规则**：接口方法内部调用 FFI 函数时，参数类型应使用 `byte*`（FFI 语法），而不是 `*byte`（接口语法）
  - 0.9 仅支持 `*T` 语法（不支持 `T*`）
  - 接口方法调用时，`self` 参数自动传递（无需显式传递）

**错误类型和错误联合类型**：

- **错误类型定义**：使用 `error ErrorName;` 定义错误类型
  - 错误类型必须在**顶层**（文件级别，与函数、结构体定义同级）定义，不能在函数内定义
  - 错误类型是编译期常量，用于标识不同的错误情况
  - 错误类型名称必须唯一（全局命名空间）
  - 错误类型属于全局命名空间，使用点号（`.`）访问：`error.ErrorName`
  - 定义示例：`error DivisionByZero;`、`error FileNotFound;`
  - 使用示例：`return error.DivisionByZero;`、`return error.FileNotFound;`

- **错误联合类型**：`!T` 表示 `T | Error`
  - `!T` 在内存中表示为 `T` 或错误码的联合体
  - 需要标记位区分值和错误（具体实现由编译器决定）
  - 错误码可以是枚举或整数
  - 示例：`!i32` 表示 `i32 | Error`，`!void` 表示 `void | Error`

- **错误类型的大小和对齐**：
  - 错误类型本身不占用运行时内存（编译期常量）
  - **错误联合类型 `!T` 的大小计算**：
    - 基础大小 = `max(sizeof(T), sizeof(错误标记))`
    - 对齐值 = `max(alignof(T), alignof(错误标记))`
    - 最终大小 = 向上对齐到对齐值的倍数
    - 错误标记通常是一个整数（错误码），大小取决于实现（通常为 1-4 字节）
  - **示例**：`!i32` 在 64 位系统上：
    - `sizeof(i32)` = 4 字节，`sizeof(错误标记)` = 假设 1 字节
    - 基础大小 = `max(4, 1)` = 4 字节
    - 对齐值 = `max(4, 1)` = 4 字节
    - 最终大小 = 4 字节（已对齐）
- 所有对象大小必须在**编译期**确定。
- **类型对齐规则**：
  - 基础类型对齐 = 类型大小（自然对齐）
  - 结构体对齐 = 最大字段对齐值
  - 数组对齐 = 元素类型对齐
  - 与 C11 `_Alignas` 语义一致

---

## 3 变量与作用域

```aya
let x: i32 = 10;        // 函数内局部变量，默认不可变
let mut i: i32 = 0;     // 可变变量，可重新赋值
let arr: [f32; 4] = [1.0, 2.0, 3.0, 4.0];
i = i + 1;              // 只有 mut 变量可赋值
```

- 初始化表达式类型必须与声明完全一致。
- `let` 声明的变量默认**不可变**；使用 `let mut` 声明可变变量。
- 可变变量可重新赋值；不可变变量赋值会编译错误。
- **常量变量**：使用 `const NAME: Type = value;` 声明编译期常量
  - 常量必须在编译期求值
  - 常量可在编译期常量表达式中使用（如数组大小 `[T; SIZE]`）
  - 常量不可重新赋值
  - `const` 常量可以在顶层或函数内声明
  - `const` 常量可以作为数组大小：`const N: i32 = 10; let arr: [i32; N] = ...;`
- **编译期常量表达式**：
  - 字面量：整数、浮点、布尔、字符串
  - 常量变量：`const NAME`
  - 算术运算：`+`, `-`, `*`, `/`, `%`（如果操作数都是常量）
  - 位运算：`&`, `|`, `^`, `~`, `<<`, `>>`（如果操作数都是常量）
  - 比较运算：`==`, `!=`, `<`, `>`, `<=`, `>=`（如果操作数都是常量）
  - 逻辑运算：`&&`, `||`, `!`（如果操作数都是常量）
  - 不支持：函数调用、变量引用（非常量）、数组/结构体字面量（0.9）
- **类型推断**：0.9 不支持类型推断，所有变量必须显式类型注解
- **变量遮蔽**：
  - 同一作用域内不能有同名变量
  - 内层作用域可以声明与外层作用域同名的变量（遮蔽外层变量）
  - 离开内层作用域后，外层变量重新可见
- 作用域 = 最近 `{ }`；离开作用域按字段逆序调用 `drop(T)`（RAII）。

---

## 4 结构体

```aya
struct Vec3 {
  x: f32,
  y: f32,
  z: f32
}

let v: Vec3 = Vec3{ x: 1.0, y: 2.0, z: 3.0 };
```

- 内存布局与 C 相同，字段顺序保留。
- **结构体前向引用**：结构体可以在定义之前使用（如果编译器支持多遍扫描），或必须在定义之后使用（单遍扫描实现）
- **字段填充规则**：与 C 标准一致
  - 每个字段按自身对齐要求对齐
  - 字段之间插入填充字节以满足对齐
  - 结构体末尾可能插入填充以满足数组元素对齐
  - **示例**：`struct { i8 a; i32 b; }` 在 64 位系统上：
    - `a`（`i8`）在偏移 0，对齐值 = 1 字节
    - `b`（`i32`）在偏移 4（中间 3 字节填充），对齐值 = 4 字节
    - 结构体大小 = 8 字节，对齐值 = 4 字节（最大字段对齐值）
- 结构体可以嵌套固定大小数组或其他结构体，**不可自引用**。
- 空结构体大小 = 1 字节（C 标准）
- **结构体字面量语法**：`TypeName{ field1: value1, field2: value2, ... }`
  - 字段名必须与结构体定义中的字段名完全匹配
  - 字段顺序可以任意（语法允许），但为了可读性和一致性，**强烈建议按定义顺序**
- 支持字段访问 `v.x`、数组元素 `arr[i]`（i 必须为 `i32`）。
- 支持嵌套访问：`struct_var.field.subfield`、`struct_var.array_field[index]`（访问链从左到右求值）
- 支持多维数组访问：`struct_var.array_field[i][j]`（如果字段是多维数组）
- 访问链可以任意嵌套：`struct_var.field1.array_field[i].subfield`
- **数组边界检查**（适用于所有数组访问）：0.9 强制编译期证明
  - 常量索引越界 → **编译错误**
  - 变量索引 → 必须证明 `i >= 0 && i < len`，证明失败 → **编译错误**
  - 零运行时检查，通过路径零指令
- **字段可变性**：只有 `mut` 结构体变量才能修改其字段
  - `let s: S = ...` 时，`s.field = value` 会编译错误
  - `let mut s: S = ...` 时，可以修改 `s.field`
  - 字段可变性由外层变量决定，不支持字段级 `mut`
  - **嵌套结构体示例**：
    ```aya
    struct Inner { x: i32 }
    struct Outer { inner: Inner }
    
    let mut outer: Outer = Outer{ inner: Inner{ x: 10 } };
    outer.inner.x = 20;  // ✅ 可以修改，因为 outer 是 mut
    ```
- **结构体初始化**：必须提供所有字段的值，不支持部分初始化或默认值

---

## 5 函数

### 5.1 普通函数

```aya
fn add(a: i32, b: i32) -> i32 {
  return a + b;
}

fn print_hello() -> void {
  // void 函数可省略 return
}
```

- **函数调用语法**：`func_name(arg1, arg2, ...)`
- 参数按值传递（`memcpy`）。
- **返回值处理规则**：
  - 返回值 ≤ 16 byte 用寄存器，>16 byte 用 sret 指针（与 C 一致）
  - 错误联合类型 `!T` 的返回值处理：
    - 如果 `!T` 的大小 ≤ 16 byte，使用寄存器返回
    - 如果 `!T` 的大小 > 16 byte，使用 sret 指针返回
    - 错误标记的处理方式由编译器实现决定（通常不影响返回值大小计算）
- 返回类型可以是具体类型、`void` 或错误联合类型 `!T`。
- `void` 函数可以省略 `return` 语句，或使用 `return;`。
- **递归函数**：支持递归函数调用（函数可以调用自身），递归深度受栈大小限制
- **函数前向引用**：函数可以在定义之前调用（编译器多遍扫描）
- **函数指针**：0.9 不支持函数指针类型，函数名不能作为值传递或存储，仅支持直接函数调用
- **变参函数调用**：参数数量必须与 C 函数声明匹配（编译期检查有限）
- **程序入口点**：必须定义 `fn main() -> i32`（程序退出码）
  - 0.9 不支持命令行参数（后续版本支持 `main(argc: i32, argv: byte**)`）
- **`return` 语句**：
  - `return expr;` 用于有返回值的函数
  - `return;` 用于 `void` 函数（可省略）
  - `return error.ErrorName;` 用于返回错误（错误联合类型函数）
  - `return` 语句后的代码不可达
  - 函数末尾的 `return` 可以省略（如果返回类型是 `void`）

- **`try` 关键字**：
  - `try expr` 用于传播错误
  - 如果 `expr` 返回错误，当前函数立即返回该错误
  - 如果 `expr` 返回值，继续执行
  - **只能在返回错误联合类型的函数中使用**，且 `expr` 必须是返回错误联合类型的表达式
  - 示例：`let result: i32 = try divide(10, 2);`（`divide` 必须返回 `!i32`）

- **`catch` 语法**：
  - `expr catch |err| { statements }` 用于捕获并处理错误
  - `expr catch { statements }` 用于捕获所有错误（不绑定错误变量）
  - 如果 `expr` 返回错误，执行 catch 块
  - 如果 `expr` 返回值，跳过 catch 块
  - **类型规则**：`catch` 表达式的类型是 `expr` 成功时的值类型（不是错误联合类型）
    - `expr catch { default_value }` 的类型 = `expr` 的值类型
    - `catch` 块必须返回与 `expr` 成功值类型相同的值
    - **重要限制**：`catch` 块**不能返回错误联合类型**，只能返回值类型或使用 `return` 提前返回函数
  - **catch 块的返回方式**：
    - 表达式返回值：catch 块的最后一条表达式作为返回值（不需要 `return`）
    - 使用 `return` 语句：在函数中使用 `return` 可以提前返回函数（不是返回 catch 块的值）
    - **重要**：catch 块中的 `return` 会立即返回函数，跳过后续所有 defer 和 drop
  - 示例：
    ```aya
    // 示例 1：catch 块使用表达式返回值
    let result: i32 = divide(10, 0) catch |err| {
        // err 是 Error 类型，支持相等性比较
        if err == error.DivisionByZero {
            // 处理除零错误
            printf("Division by zero error\n");
        }
        // 提供默认值，catch 块的最后一条表达式作为返回值
        0  // catch 块必须返回 i32 类型
    };
    // result 的类型是 i32（不是 !i32）
    
    // 示例 2：catch 块使用 return 提前返回函数
    fn main() -> i32 {
        let result: i32 = read_file("test.txt") catch |err| {
            printf("Failed to read file\n");
            return 1;  // 提前返回函数，退出 main 函数（跳过后续 defer 和 drop）
        };
        printf("Read %d bytes\n", result);
        return 0;
    }
    ```
- **错误处理**（0.9）：
  - 0.9 支持**错误联合类型** `!T` 和 **try/catch** 语法，用于函数错误返回
  - 函数可以返回错误联合类型：`fn foo() !i32` 表示返回 `i32` 或 `Error`
  - 使用 `try` 关键字传播错误：`let result: i32 = try divide(10, 2);`
  - 使用 `catch` 语法捕获错误：`let result: i32 = divide(10, 0) catch |err| { ... };`
  - **无运行时 panic 路径**：所有 UB 必须被编译期证明为安全，失败即编译错误
- **错误类型的操作**：
  - 错误类型支持相等性比较：`if err == error.FileNotFound { ... }`
  - 错误类型不支持不等性比较（0.9 仅支持 `==`）
  - catch 块中可以判断错误类型并做不同处理
  - 错误类型不能直接打印，需要通过模式匹配处理
  
**错误处理设计哲学**（0.9）：
- **零开销抽象**：错误处理是编译期检查，零运行时开销（非错误路径）
- **显式错误**：错误是类型系统的一部分，必须显式处理
- **编译期检查**：编译器确保所有错误都被处理
- **无 panic、无断言**：所有 UB 必须被编译期证明为安全，失败即编译错误

**错误处理与内存安全的关系**（0.9）：
- **`try`/`catch` 只用于函数错误返回**，不用于捕获 UB
- **所有 UB 必须被编译期证明为安全**，失败即编译错误，不生成代码
- 错误处理用于处理可预测的、显式的错误情况（如文件不存在、网络错误等）

**示例：错误处理**：
```aya
// ✅ 使用错误联合类型处理可预测错误
fn safe_divide(a: i32, b: i32) !i32 {
    if b == 0 {
        return error.DivisionByZero;  // 显式检查，返回错误
    }
    return a / b;
}

// ✅ 使用 catch 捕获错误
fn main() -> i32 {
    let result: i32 = safe_divide(10, 0) catch |err| {
        if err == error.DivisionByZero {
            printf("Division by zero\n");
        }
        return 1;  // 提前返回函数
    };
    printf("Result: %d\n", result);
    return 0;
}
```

### 5.2 外部 C 函数（FFI）

**步骤 1：顶层声明**  
```aya
extern i32 printf(byte* fmt, ...);   // 变参
extern f64 sin(f64);
```

**步骤 2：正常调用**  
```aya
let pi: f64 = 3.1415926;
printf("sin(pi/2)=%f\n", sin(pi / 2.0));
```

- 声明必须出现在**顶层**；不可与调用混写在一行。
- 调用生成原生 `call rel32` 或 `call *rax`，**无包装函数**（零开销）。
- 返回后按 C 调用约定清理参数。
- **调用约定**：与目标平台的 C 调用约定一致（如 x86-64 System V ABI 或 Microsoft x64 calling convention），具体由后端实现决定

**重要说明**：
- FFI 函数调用的格式字符串（如 `printf` 的 `"%f"`）是 C 函数的特性，不是阿雅语言本身的特性
- 阿雅语言仅提供 FFI 机制来调用 C 函数，格式字符串的语法和语义遵循 C 标准
- 字符串插值（第 21 章）是阿雅语言本身的特性，编译期展开，与 FFI 的格式字符串不同

---

## 6 接口（interface）

### 6.1 设计目标

- **Go 的鸭子类型 + 动态派发**体验；  
- **Zig 的零注册表 + 编译期生成**；  
- **C 的内存布局 + 单条 call 指令**；  
- **无 lifetime 符号、无 new 关键字、无运行时锁**。

### 6.2 语法

```
type += interface_type
interface_type = 'interface' ID '{' method_sig { method_sig } '}'
method_sig     = 'fn' ID '(' [param { ',' param } ')' ] '->' type ';'
impl_block     = 'impl' struct_name ':' interface_name '{' method_impl { method_impl } '}'
```

### 6.3 语义总览

| 项 | 内容 |
|---|---|
| 接口值 | 16 B 结构体 `{ vptr: *const VTable, data: *any }` |
| VTable | **编译期唯一生成**；单元素函数指针数组；只读静态数据 |
| 装箱 | 局部变量/参数/返回值处自动生成；**无运行期注册** |
| 调用 | `call [vtable+offset]` → **单条指令**，零额外开销 |
| 生命期 | 由作用域 RAII 保证；**逃逸即编译错误**（见 6.4 节） |

### 6.4 Self 类型

- `Self` 是接口方法签名中的特殊占位符，代表实现该接口的具体结构体类型
- 仅在接口定义和 `impl` 块的方法签名中使用
- `Self` 不是一个实际类型，而是编译期的类型替换标记
- 示例：`fn write(self: *Self, buf: *byte, len: i32)` 中，`Self` 在实际实现时被替换为具体类型（如 `Console`）
- `*Self` 表示指向实现接口的结构体类型的指针

### 6.5 生命周期（零语法版）

- **无 `'static`、无 `'a`**；  
- 编译器只在「赋值/返回/传参」路径检查：  
  ```
  if (target_scope < owner_scope) → error: field may outlive its target
  ```
- 检查失败**仅一行报错**；通过者**零运行时成本**。

**逃逸检查规则**：

接口值不能逃逸出其底层数据的生命周期。编译器在以下路径检查：

1. **返回接口值**：
   ```aya
   // ❌ 编译错误：s 的生命周期不足以支撑返回的接口值
   fn example() -> IWriter {
       let s: Console = Console{ fd: 1 };
       return s;  // 编译错误：s 的生命周期不足
   }
   
   // ✅ 编译通过：返回具体类型，调用者装箱
   fn example() -> Console {
       return Console{ fd: 1 };
   }
   ```

2. **赋值给外部变量**：
   ```aya
   // ❌ 编译错误：s 的生命周期不足以支撑外部接口值
   fn example() -> void {
       let s: Console = Console{ fd: 1 };
       let mut external: IWriter = s;  // 如果 external 生命周期更长，编译错误
   }
   
   // ✅ 编译通过：局部装箱，生命周期匹配
   fn example() -> void {
       let s: Console = Console{ fd: 1 };
       let local: IWriter = s;  // 局部变量，生命周期匹配
       // 使用 local...
   }
   ```

3. **传递参数**：
   ```aya
   // ✅ 编译通过：参数传递，生命周期由调用者保证
   fn use_writer(w: IWriter) -> void {
       // 使用 w...
   }
   
   fn example() -> void {
       let s: Console = Console{ fd: 1 };
       use_writer(s);  // 编译通过：参数传递
   }
   ```

**编译器检查算法**：
- 对于每个接口值赋值/返回/传参，检查底层数据的生命周期是否 ≥ 目标位置的生命周期
- 如果 `底层数据作用域 < 目标作用域`，则报告编译错误
- 作用域层级：函数参数 > 局部变量 > 内层块变量

### 6.6 接口方法调用

- 接口方法调用语法：`interface_value.method_name(arg1, arg2, ...)`
- `self` 参数自动传递，无需显式传递
- 示例：`w.write(&msg[0], 5);` 中，`w` 是接口值，`write` 方法会自动接收 `self` 参数

### 6.7 完整示例

```aya
// ① 定义接口
interface IWriter {
  fn write(self: *Self, buf: *byte, len: i32) -> i32;
}

// ② 具体实现
struct Console {
  fd: i32
}

impl Console : IWriter {
  fn write(self: *Self, buf: *byte, len: i32) -> i32 {
    extern i32 write(i32 fd, byte* buf, i32 len);
    return write(self.fd, buf, len);
  }
}

// ③ 使用接口
fn echo(w: IWriter) -> void {
  let msg: [byte; 6] = "hello\n";
  w.write(&msg[0], 5);
}

fn main() -> i32 {
  let cons: Console = Console{ fd: 1 };   // stdout
  echo(cons);                             // 自动装箱为接口
  return 0;
}
```

编译后生成（x86-64）：

```asm
lea     rax, [vtable.Console.IWriter]
lea     rdx, [cons]
mov     qword [w], rax
mov     qword [w+8], rdx
call    [rax]           ; ← 单条 call 指令
```

**接口方法调用说明**：
- 调用 `w.write(&msg[0], 5);` 时，`w` 是接口值（包含 vtable 和数据指针）
- 编译器自动从 vtable 中加载方法地址，并将 `w` 的数据指针作为 `self` 参数传递
- `self` 参数在调用时隐式传递，用户代码中不需要显式传递

**调用约定（ABI）**：
- 接口方法调用遵循与普通函数相同的调用约定（与目标平台的 C 调用约定一致）
- `self` 参数作为第一个参数传递（x86-64 System V ABI：`rdi` 寄存器）
- 其他参数按顺序传递（x86-64 System V ABI：`rsi`、`rdx`、`rcx`、`r8`、`r9`，然后栈）
- 返回值处理与普通函数相同（≤16 字节用寄存器，>16 字节用 sret 指针）

### 6.8 限制（保持简单）

| 限制 | 说明 |
|---|---|
| 无字段接口 | `struct S { w: IWriter }` → ❌ 编译错误（0.9 限制） |
| 无数组/切片接口 | `let arr: [IWriter; 3]` → ❌ |
| 无自引用 | 接口值不能指向自己 |
| 无运行时注册 | 所有 vtable 编译期生成，**零 map 零锁** |

### 6.9 与 C 互操作

- 接口值首地址 = `&vtable`，可直接当 `void*` 塞给 C；  
- C 侧回调：
  ```c
  typedef struct { void* vt; void* obj; } IWriter;
  int writer_write(IWriter w, char* buf, int len){
      int (*f)(void*,char*,int) = *(int(**)(void*,char*,int))w.vt;
      return f(w.obj, buf, len);
  }
  ```

### 6.10 后端实现要点

1. **语法树收集** → 扫描所有 `impl T : I` 生成唯一 vtable 常量。  
2. **类型检查** → 确保 `T` 实现 `I` 的全部方法签名。  
3. **装箱点** →  
   - 局部：`let iface: I = concrete;`  
   - 传参 / 返回：按值复制 16 B。  
4. **调用点** →  
   - 加载 `vptr` → 计算方法偏移 → `call [reg+offset]`。  
5. **逃逸检查** → 6.4 节生命周期规则；失败即报错。

### 6.11 迁移指南

| 旧需求（extern+函数指针） | 新做法（接口） |
|---|---|
| `extern i32 call(int(*f)(int), int x);` | `fn use(IFunc f);` |
| 手动管理函数地址 | 编译期 vtable，无地址赋值 |
| 类型不安全 | 接口签名强制检查 |
| 需全局注册表 | 零注册，零锁 |

### 6.12 迭代器接口（用于for循环）

**设计目标**：
- 通过接口机制支持Zig风格的for循环迭代
- 零运行时开销，编译期生成vtable
- 支持所有实现了迭代器接口的类型

**迭代器接口定义**：

由于Aya 0.9没有泛型，迭代器接口需要针对具体元素类型定义。以下以 `i32` 类型为例：

```aya
// 迭代器结束错误
error IterEnd;
// 迭代器状态错误（用于value()方法的边界检查）
error InvalidIteratorState;

// i32数组迭代器接口
interface IIteratorI32 {
    // 移动到下一个元素，返回错误表示迭代结束
    fn next(self: *Self) -> !void;
    // 获取当前元素值
    fn value(self: *Self) -> i32;
}

// 带索引的i32数组迭代器接口
interface IIteratorI32WithIndex {
    fn next(self: *Self) -> !void;
    fn value(self: *Self) -> i32;
    fn index(self: *Self) -> i32;
}
```

**数组迭代器实现示例**：

```aya
// i32数组迭代器结构体
struct ArrayIteratorI32 {
    arr: *[i32; N],  // 指向数组的指针
    current: i32,    // 当前索引（从0开始，指向下一个要访问的元素）
    len: i32         // 数组长度
}

impl ArrayIteratorI32 : IIteratorI32 {
    fn next(self: *Self) -> !void {
        if self.current >= self.len {
            return error.IterEnd;  // 迭代结束
        }
        self.current = self.current + 1;
    }
    
    fn value(self: *Self) -> i32 {
        // 编译器证明：由于next()成功返回，我们有 self.current > 0 && self.current <= self.len
        // 因此 idx = current - 1 满足 idx >= 0 && idx < len
        // 实际访问的是 current - 1 位置的元素
        let idx: i32 = self.current - 1;
        // 编译期证明：由于 next() 成功返回（current > 0 && current <= len），
        // 我们有 idx >= 0 && idx < len，因此数组访问安全
        // 如果编译器无法证明，需要显式检查：
        if idx < 0 || idx >= self.len {
            // 根据设计，next() 成功返回后，这种情况不应该发生
            // 但为了满足编译期证明要求，需要显式处理
            // 注意：实际上这个分支永远不会执行（由 next() 的语义保证）
            return error.InvalidIteratorState;  // 或使用 unreachable
        }
        return (*self.arr)[idx];
    }
}

// 带索引的数组迭代器实现
impl ArrayIteratorI32 : IIteratorI32WithIndex {
    fn next(self: *Self) -> !void {
        if self.current >= self.len {
            return error.IterEnd;
        }
        self.current = self.current + 1;
    }
    
    fn value(self: *Self) -> i32 {
        let idx: i32 = self.current - 1;
        // 编译期证明：由于 next() 成功返回，idx 在有效范围内
        if idx < 0 || idx >= self.len {
            return error.InvalidIteratorState;  // 根据设计，这种情况不应该发生
        }
        return (*self.arr)[idx];
    }
    
    fn index(self: *Self) -> i32 {
        return self.current - 1;  // 返回当前索引（从0开始）
    }
}
```

**使用示例**：

```aya
fn create_iterator(arr: *[i32; 10]) -> ArrayIteratorI32 {
    return ArrayIteratorI32{
        arr: arr,
        current: 0,
        len: 10
    };
}

fn iterate_example() -> void {
    let arr: [i32; 5] = [1, 2, 3, 4, 5];
    let iter: IIteratorI32 = create_iterator(&arr);  // 自动装箱为接口
    
    // 手动迭代（for循环会自动展开为类似代码）
    while true {
        let result: void = iter.next() catch |err| {
            if err == error.IterEnd {
                break;  // 迭代结束
            }
            // 其他错误处理...
        };
        let value: i32 = iter.value();
        // 使用value...
    }
}
```

**设计说明**：
- 迭代器接口遵循Aya接口的设计原则：编译期生成vtable，零运行时开销
- 使用错误联合类型 `!void` 表示迭代结束，符合Aya的错误处理机制
- 需要为每种元素类型定义对应的迭代器接口（0.9限制）
- for循环语法会自动使用这些接口进行迭代（见第8章）

### 6.13 一句话总结

> **阿雅接口 = Go 的鸭子派发 + Zig 的零注册 + C 的内存布局**；  
> **语法零新增、生命周期零符号、调用零开销**；  
> **今天就能用，明天可放开字段限制**。

---

## 7 栈式数组（零 GC）

```aya
let buf: [f32; 64] = [];   // 64 个 f32 在当前栈帧
```

- **栈数组语法**：使用 `[]` 表示未初始化的栈数组，类型由左侧变量的类型注解确定。
- `[]` 不能独立使用，必须与类型注解一起使用：`let buf: [T; N] = [];`
- **数组初始化**：`[]` 返回的数组**未初始化**（包含未定义值），用户必须在使用前初始化数组元素
  - 初始化示例：
    ```aya
    let mut buf: [f32; 64] = [];
    // 手动初始化数组元素
    let mut i: i32 = 0;
    while i < 64 {
        buf[i] = 0.0;  // 初始化每个元素
        i = i + 1;
    }
    ```
  - 注意：使用未初始化的数组元素是未定义行为（UB）
- 数组大小 `N` 必须是**编译期常量表达式**：
  - 字面量：`64`, `100`
  - 常量变量：`const SIZE: i32 = 64;` 然后使用 `SIZE`
  - 常量算术运算：`2 + 3`, `SIZE * 2`
  - 不支持函数调用（除非是 `const fn`，0.9 暂不支持）
- **语法规则**：
  - `[]` 表示栈分配的未初始化数组
  - 数组大小由类型注解 `[T; N]` 中的 `N` 指定
  - 示例：`let buf: [f32; 64] = [];` 表示分配 64 个 `f32` 的栈数组
- 生命周期 = 所在 `{}` 块；返回上层即编译错误（逃逸检测）。
- 后端映射为 `alloca` 或机器栈数组，**零开销**。
- **逃逸检测规则**：`[]` 分配的对象不能：
  - 被函数返回
  - 被赋值给生命周期更长的变量
  - 被传递给可能存储引用的函数

---

## 8 控制流

```aya
if expr block [ else block ]
while expr block
break; continue; return expr;
```

- 条件表达式必须是 `bool`（无隐式转布尔）。
- `block` 必须用大括号。
- **语句**：
  - 表达式后跟分号 `;` 构成表达式语句
  - 支持空语句：单独的 `;`
  - 支持空块：`{ }`
  - 函数调用、赋值等表达式可以作为语句使用
- **语法形式**：
  - `if` 语句：`if condition { statements } [ else { statements } ]`
  - 支持 `else if`：`if c1 { } else if c2 { } else { }`
  - `while` 语句：`while condition { statements }`
- **`break` 和 `continue`**：
  - `break;` 跳出最近的 `while` 或 `for` 循环
  - `continue;` 跳过当前循环迭代，继续下一次
  - 0.9 不支持 `break label` 或 `continue label`（后续版本支持）
  - `break` 和 `continue` 只能在循环体内使用

- **`for` 循环**：Zig风格的迭代循环，通过接口机制支持所有可迭代类型
  - **语法形式**：
    ```
    for_stmt = 'for' '(' expr ')' '|' ID '|' block
             | 'for' '(' expr ',' index_range ')' '|' ID ',' ID '|' block
    
    index_range = expr '..' [expr]
    ```
    - `index_range`：索引范围表达式
      - `start..`：从 `start` 开始的无限范围（通常用于 `0..` 表示从0开始）
      - `start..end`：从 `start` 到 `end-1` 的范围（0.9 暂不支持带结束值的范围）
  - **基本形式**：`for (iterable) |item| { statements }`
    - `iterable` 必须是实现了迭代器接口的类型（如数组迭代器）
    - `item` 是循环变量，类型由迭代器的 `value()` 方法返回类型决定
    - 自动调用迭代器的 `next()` 方法，返回 `error.IterEnd` 时循环结束
  - **带索引形式**：`for (iterable, index_range) |item, index| { statements }`
    - `iterable` 必须是实现了带索引迭代器接口的类型
    - `index_range` 是索引范围表达式（如 `0..` 表示从0开始的索引）
      - 0.9 仅支持 `0..` 形式，表示从0开始的索引
      - 结束值由迭代器决定（通常等于数组长度）
    - `item` 是元素值，`index` 是当前索引（从0开始）
    - 自动调用迭代器的 `next()` 和 `index()` 方法
  - **语义**：
    - for循环是语法糖，编译期展开为while循环（见展开规则）
    - 迭代器自动装箱为接口类型，使用动态派发
    - 零运行时开销，编译期生成vtable
  - **示例**：
    ```aya
    // 基本迭代
    let arr: [i32; 5] = [1, 2, 3, 4, 5];
    for (arr) |item| {
        printf("%d\n", item);
    }
    
    // 带索引迭代
    for (arr, 0..) |item, index| {
        printf("arr[%d] = %d\n", index, item);
    }
    ```
  - **展开规则**：for循环在编译期展开为while循环
    - **基本形式展开**：
      ```aya
      // 原始代码
      for (iterable) |item| {
          // body
      }
      
      // 展开为
      {
          let mut iter: IIteratorT = iterable;  // 自动装箱为接口（T为元素类型）
          while true {
              let result: void = iter.next() catch |err| {
                  if err == error.IterEnd {
                      break;  // 迭代结束，跳出循环
                  }
                  return err;  // 其他错误传播（如果函数返回错误联合类型）
              };
              let item: T = iter.value();  // 获取当前元素
              // body（可以使用item）
          }
      }
      ```
    - **带索引形式展开**：
      ```aya
      // 原始代码
      for (iterable, 0..) |item, index| {
          // body
      }
      
      // 展开为
      {
          let mut iter: IIteratorTWithIndex = iterable;  // 自动装箱为带索引接口
          while true {
              let result: void = iter.next() catch |err| {
                  if err == error.IterEnd {
                      break;
                  }
                  return err;
              };
              let item: T = iter.value();      // 获取当前元素
              let index: i32 = iter.index();   // 获取当前索引
              // body（可以使用item和index）
          }
      }
      ```
    - **展开说明**：
      - 编译器自动识别可迭代类型，并选择合适的迭代器接口
      - 数组类型自动创建对应的数组迭代器（通过标准库函数 `iter()`）
      - 展开后的代码遵循Aya的内存安全规则，所有数组访问都有编译期证明
      - 零运行时开销：接口调用是单条call指令，与手写while循环性能相同

- **`match` 表达式/语句**：模式匹配，仿照 Zig 的 switch 语法
  - **语法形式**：`match expr { pattern1 => expr, pattern2 => expr, else => expr }`
  - **作为表达式**：match 可以作为表达式使用，所有分支返回类型必须一致
    ```aya
    let result: i32 = match x {
        0 => 10,
        1 => 20,
        else => 30,
    };
    ```
  - **作为语句**：如果所有分支返回 `void`，match 可以作为语句使用
    ```aya
    match status {
        0 => printf("OK\n"),
        1 => printf("Error\n"),
        else => printf("Unknown\n"),
    }
    ```
  - **支持的模式类型**：
    1. **常量模式**：整数、布尔、错误类型常量
       ```aya
       match x {
           0 => expr1,
           1 => expr2,
           true => expr3,
           error.FileNotFound => expr4,
           else => expr5,
       }
       ```
    2. **变量绑定模式**：捕获匹配的值
       ```aya
       match x {
           0 => expr1,
           y => expr2,  // y 绑定到 x 的值
           else => expr3,
       }
       ```
    3. **结构体解构**：匹配并解构结构体字段
       ```aya
       match point {
           Point{ x: 0, y: 0 } => expr1,
           Point{ x: x_val, y: y_val } => expr2,  // 绑定字段
           else => expr3,
       }
       ```
    4. **错误类型匹配**：匹配错误联合类型
       ```aya
       match result {
           error.FileNotFound => expr1,
           error.PermissionDenied => expr2,
           value => expr3,  // 成功值绑定
           else => expr4,
       }
       ```
    5. **字符串数组匹配**：匹配 `[i8; N]` 数组（字符串插值的结果）
       ```aya
       match msg {
           "hello" => expr1,  // 编译期常量字符串，编译期比较
           "world" => expr2,
           x => expr3,  // 运行时字符串，运行时比较
           else => expr4,
       }
       ```
       - 编译期常量字符串：如果模式和表达式都是编译期常量，编译器在编译期比较
       - 运行时字符串：如果模式或表达式是运行时值，生成运行时字符串比较代码（调用标准库比较函数）
       - 数组长度检查：不同长度的数组不匹配（编译期检查）
  - **语义规则**：
    1. **表达式 vs 语句**：
       - 作为表达式：match 表达式的类型是所有分支返回类型的统一类型（必须完全一致）
       - 作为语句：如果所有分支返回 `void`，match 可以作为语句使用
       - 上下文决定：编译器根据上下文判断 match 是表达式还是语句
    2. **匹配顺序**：从上到下依次匹配，第一个匹配的分支执行
    3. **变量绑定作用域**：绑定的变量仅在对应的分支内有效
    4. **类型检查**：
       - 所有分支的返回类型必须完全一致（Aya 无隐式转换）
       - 如果作为表达式，所有分支必须返回相同类型
       - 如果作为语句，所有分支必须返回 `void`
    5. **编译期常量匹配**：常量模式在编译期验证，常量越界等错误在编译期捕获
    6. **else 分支**：必须放在最后，捕获所有未匹配的情况
  - **编译期检查**：
    - 常量索引越界：如果 match 的表达式是编译期常量，且所有分支都是常量模式，编译器应验证覆盖范围
    - 类型不匹配：模式类型必须与表达式类型兼容
    - 数组长度匹配：字符串数组 match 时，模式字符串的长度必须与表达式数组长度匹配（编译期检查）
  - **后端实现**：
    - 代码生成：
      - 整数/布尔常量：展开为 if-else 链或跳转表（对于密集整数常量）
      - 编译期常量字符串：编译期比较，直接展开
      - 运行时字符串：生成运行时字符串比较代码（调用标准库比较函数）
      - 结构体解构：展开为字段比较和提取
    - 零运行时开销：编译期常量匹配直接展开，无运行时模式匹配引擎
    - 路径零指令：未匹配路径不生成代码
    - 字符串比较：运行时字符串比较使用标准库函数（如 `strcmp` 的等价实现）
  - **完整示例**：
    ```aya
    // 示例 1：整数常量匹配（表达式形式）
    fn classify_score(score: i32) -> i32 {
        let grade: i32 = match score {
            90 => 5,
            80 => 4,
            70 => 3,
            60 => 2,
            else => 1,  // 其他分数
        };
        return grade;
    }
    
    // 示例 2：错误类型匹配
    fn handle_result(result: !i32) -> i32 {
        let value: i32 = match result {
            error.FileNotFound => -1,
            error.PermissionDenied => -2,
            x => x,  // 成功值（绑定到 result 中的 i32 值）
        };
        return value;
    }
    
    // 示例 3：结构体解构匹配
    struct Point {
        x: i32,
        y: i32
    }
    
    fn classify_point(p: Point) -> i32 {
        let quadrant: i32 = match p {
            Point{ x: 0, y: 0 } => 0,  // 原点
            Point{ x: x, y: y } => {
                if x > 0 && y > 0 {
                    1  // 第一象限（块表达式的最后一条表达式作为返回值）
                } else if x < 0 && y > 0 {
                    2  // 第二象限
                } else if x < 0 && y < 0 {
                    3  // 第三象限
                } else {
                    4  // 第四象限
                }
            },
        };
        return quadrant;
    }
    
    // 示例 4：字符串数组匹配（语句形式）
    fn print_greeting(msg: [i8; 6]) -> void {
        match msg {
            "hello" => printf("Hello, world!\n"),
            "world" => printf("World, hello!\n"),
            else => printf("Unknown greeting\n"),
        };
    }
    ```

---

## 9 defer 和 errdefer

### 9.1 defer 语句

**语法**：
```aya
defer statement;
defer { statements }
```

**语义**：
- 在当前作用域结束时执行（正常返回或错误返回）
- 执行顺序：LIFO（后声明的先执行）
- 可以出现在函数内的任何位置
- 支持单语句和语句块

**示例**：
```aya
fn example() -> void {
    defer {
        printf("Cleanup 1\n");
    }
    defer {
        printf("Cleanup 2\n");
    }
    // 使用资源...
    // 退出时执行顺序：
    // printf("Cleanup 2\n");  // 后声明的先执行
    // printf("Cleanup 1\n");
}
```

### 9.2 errdefer 语句

**语法**：
```aya
errdefer statement;
errdefer { statements }
```

**语义**：
- 仅在函数返回错误时执行
- 执行顺序：LIFO（后声明的先执行）
- 必须在可能返回错误的函数中使用（返回类型为 `!T`）
- 用于错误情况下的资源清理

**示例**：
```aya
fn example() !i32 {
    defer {
        printf("Always cleanup\n");  // 总是执行
    }
    errdefer {
        printf("Error cleanup\n");  // 仅错误时执行
    }
    
    let result: i32 = try some_operation();
    return result;
    
    // 正常返回时：只执行 defer
    // 错误返回时：先执行 errdefer，再执行 defer
}
```

### 9.3 执行顺序

**正常返回时**：
1. `defer`（LIFO 顺序，后声明的先执行）
2. `drop`（逆序，变量声明的逆序）

**错误返回时**：
1. `errdefer`（LIFO 顺序，后声明的先执行）
2. `defer`（LIFO 顺序，后声明的先执行）
3. `drop`（逆序，变量声明的逆序）

**重要规则**：
- **defer 先于 drop 执行**：defer 中的代码可以访问作用域内的变量（变量尚未 drop）
- **defer 中不会触发 drop**：defer 执行时，变量仍然有效，不会自动 drop
- **变量在 defer 执行完成后才 drop**

**示例**：
```aya
fn example() !void {
    let file: File = try open_file("test.txt");
    
    defer {
        // ✅ defer 中可以访问 file，因为 defer 先于 drop 执行
        printf("File fd: %d\n", file.fd);
        // file 在这里仍然有效，还没有 drop
    }
    
    // 使用 file...
    
    // 退出时执行顺序：
    // 1. defer { printf(...) }  // file 仍有效
    // 2. drop(file)              // file 在这里才 drop
}
```

### 9.4 与 RAII/drop 的关系

- defer/errdefer **复用 drop 的代码插入机制**
- 在同一个作用域退出点，统一处理所有清理逻辑
- 编译器维护清理代码列表，按顺序执行

**使用场景**：
- **drop**：基于类型的自动清理（文件关闭、内存释放等）
- **defer**：补充清理逻辑（日志记录、状态更新等）
- **errdefer**：错误情况下的特殊清理（回滚操作、错误日志等）

**完整示例**：
```aya
fn process_file(path: byte*) !i32 {
    let file: File = try open_file(path);
    
    defer {
        printf("File processing finished\n");  // 总是记录完成
    }
    errdefer {
        printf("Error during file processing\n");  // 错误时记录错误
        rollback_transaction();  // 错误时回滚事务
    }
    
    // 处理文件...
    let result: i32 = try process(file);
    
    // 正常返回：defer -> drop
    // 错误返回：errdefer -> defer -> drop
    return result;
}
```

### 9.5 作用域规则

- defer/errdefer 绑定到当前作用域
- 嵌套作用域有独立的 defer/errdefer 栈
- 内层作用域的 defer 先于外层执行

**示例**：
```aya
fn nested_example() !void {
    defer {
        printf("Outer defer\n");
    }
    
    {
        defer {
            printf("Inner defer\n");
        }
        // 内层作用域退出时：先执行 "Inner defer"
    }
    // 外层作用域退出时：执行 "Outer defer"
}
```

---

## 10 运算符与优先级

| 级别 | 运算符 | 结合性 | 说明 |
|----|--------|--------|------|
| 1  | `()` `.` `[]` | 左 | 调用、字段、下标 |
| 2  | `-` `!` `~` (一元) | 右 | 负号、逻辑非、按位取反 |
| 3  | `* / %` | 左 | 乘、除、取模 |
| 4  | `+ -` | 左 | 加、减 |
| 5  | `<< >>` | 左 | 左移、右移 |
| 6  | `< > <= >=` | 左 | 比较 |
| 7  | `== !=` | 左 | 相等性 |
| 8  | `&` | 左 | 按位与 |
| 9  | `^` | 左 | 按位异或 |
| 10 | `\|` | 左 | 按位或 |
| 11 | `&&` | 左 | 逻辑与 |
| 12 | `\|\|` | 左 | 逻辑或 |
| 13 | `=` | 右 | 赋值（最低优先级）|

- 无隐式转换；两边类型必须完全一致。
- 赋值运算符 `=` 仅用于 `mut` 变量。
- **位运算符**：
  - `&`：按位与，两个操作数都必须是整数类型（`i8`, `i16`, `i32`, `i64`），结果类型与操作数相同
  - `|`：按位或，两个操作数都必须是整数类型，结果类型与操作数相同
  - `^`：按位异或，两个操作数都必须是整数类型，结果类型与操作数相同
  - `~`：按位取反（一元），操作数必须是整数类型，结果类型与操作数相同
  - `<<`：左移，左操作数必须是整数类型，右操作数必须是 `i32`，结果类型与左操作数相同
  - `>>`：右移（算术右移，对于有符号数保留符号位），左操作数必须是整数类型，右操作数必须是 `i32`，结果类型与左操作数相同
  - 位运算符的操作数类型必须完全一致（移位运算符的右操作数除外，必须是 `i32`）
  - 示例：
    ```aya
    let a: i32 = 0b1010;        // 10
    let b: i32 = 0b1100;        // 12
    let c: i32 = a & b;         // 0b1000 = 8
    let d: i32 = a | b;         // 0b1110 = 14
    let e: i32 = a ^ b;         // 0b0110 = 6
    let f: i32 = ~a;            // 按位取反
    let g: i32 = a << 2;        // 左移 2 位 = 40
    let h: i32 = a >> 1;        // 右移 1 位 = 5
    ```
- **不支持的运算符**（0.9）：
  - 自增/自减：`++`, `--`（必须使用 `i = i + 1;` 形式）
  - 复合赋值：`+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`（必须使用完整形式）
  - 三元运算符：`?:`（必须使用 `if-else` 语句）
- **类型比较规则**：
  - 基础类型（整数、浮点、布尔）支持 `==` 和 `!=` 比较
  - 浮点数比较使用 IEEE 754 标准，进行精确比较（可能受浮点精度影响）
  - 错误类型支持 `==` 比较（0.9）
  - 0.9 不支持结构体的 `==` 和 `!=` 比较（后续版本支持）
  - 0.9 不支持数组的 `==` 和 `!=` 比较（后续版本支持）
- **表达式求值顺序**：从左到右（left-to-right）
  - 函数参数求值顺序：从左到右
  - 数组字面量元素表达式求值顺序：从左到右
  - 结构体字面量字段表达式求值顺序：从左到右（按字面量中的顺序）
  - 副作用（赋值）立即生效
- **逻辑运算符短路求值**：
  - `expr1 && expr2`：如果 `expr1` 为 `false`，不计算 `expr2`
  - `expr1 || expr2`：如果 `expr1` 为 `true`，不计算 `expr2`
- **整数溢出和除零**（0.9 强制编译期证明）：
  - **整数溢出**：
    - 常量运算溢出 → **编译错误**（编译期直接检查）
    - 变量运算 → 必须显式检查溢出条件，或编译器能够证明无溢出
    - 无法证明无溢出 → **编译错误**
    - 零运行时检查，通过路径零指令
  - **除零错误**：
    - 常量除零 → **编译错误**
    - 变量 → 必须证明 `y != 0`，证明失败 → **编译错误**
    - 零运行时检查，通过路径零指令
  
  **溢出检查示例**：
  ```aya
  // ✅ 编译通过：常量运算无溢出
  let x: i32 = 100 + 200;  // 编译期证明：300 < 2147483647
  
  // ❌ 编译错误：常量溢出
  let y: i32 = 2147483647 + 1;  // 编译错误
  
  // ✅ 编译通过：显式溢出检查，返回错误
  fn add_safe(a: i32, b: i32) -> !i32 {
      if a > 0 && b > 0 && a > 2147483647 - b {
          return error.Overflow;  // 返回错误
      }
      return a + b;  // 编译器证明：经过检查后无溢出
  }
  
  // ✅ 编译通过：显式溢出检查，返回饱和值（有效数值）
  fn add_saturating(a: i32, b: i32) -> i32 {
      if a > 0 && b > 0 && a > 2147483647 - b {
          return 2147483647;  // 上溢时返回最大值
      }
      if a < 0 && b < 0 && a < -2147483648 - b {
          return -2147483648;  // 下溢时返回最小值
      }
      return a + b;  // 编译器证明：经过检查后无溢出
  }
  
  // ✅ 编译通过：显式溢出检查，返回包装值（有效数值）
  // 注意：包装算术需要显式处理，不能依赖未定义行为
  fn add_wrapping(a: i32, b: i32) -> i32 {
      // 显式检查溢出，如果溢出则返回包装后的值
      if a > 0 && b > 0 && a > 2147483647 - b {
          // 包装算术：溢出时返回 (a + b) % 2^32，但需要显式计算
          // 实际实现可能需要使用更大的类型进行计算
          let sum: i64 = (a as i64) + (b as i64);
          return (sum as! i32);  // 显式截断到 i32 范围
      }
      if a < 0 && b < 0 && a < -2147483648 - b {
          let sum: i64 = (a as i64) + (b as i64);
          return (sum as! i32);  // 显式截断到 i32 范围
      }
      return a + b;  // 编译器证明：经过检查后无溢出
  }
  
  // ❌ 编译错误：无法证明无溢出
  fn add_unsafe(a: i32, b: i32) -> i32 {
      return a + b;  // 编译错误
  }
  ```

**0.9 内存安全强制**：

所有 UB 场景必须被编译期证明为安全，失败即编译错误：

1. **数组越界访问**：
   - 常量索引越界 → **编译错误**
   - 变量索引 → 必须证明 `i >= 0 && i < len`，证明失败 → **编译错误**

2. **整数溢出**：
   - 常量运算溢出 → **编译错误**（编译期直接检查）
   - 变量运算 → 必须显式检查溢出条件，或编译器能够证明无溢出
   - 无法证明无溢出 → **编译错误**
   - 溢出检查模式：
     - 加法上溢：`a > 0 && b > 0 && a > MAX - b`
     - 加法下溢：`a < 0 && b < 0 && a < MIN - b`
     - 乘法上溢：`a > 0 && b > 0 && a > MAX / b`

3. **除零错误**：
   - 常量除零 → **编译错误**
   - 变量 → 必须证明 `y != 0`，证明失败 → **编译错误**

4. **使用未初始化内存**：
   - 必须证明「首次使用前已赋值」或「前序有赋值路径」，证明失败 → **编译错误**

5. **空指针解引用**：
   - 必须证明 `ptr != null` 或前序有 `if ptr == null { return error; }`，证明失败 → **编译错误**

**0.9 安全策略**：
- **编译期证明**：所有 UB 必须被编译器证明为安全
- **失败即错误**：证明失败 → 编译错误，不生成代码
- **零运行时开销**：通过路径零指令，失败路径不存在
- **无 panic、无 catch、无断言**：所有检查在编译期完成
- **优先级示例**：
  ```aya
  let mut x: i32 = 1 + 2 * 3;        // = 7，不是 9（* 优先级高于 +）
  let mut y: bool = true && false || true;  // = true（&& 优先级高于 ||）
  let mut z: i32 = 0;
  z = z + 1;                          // 先计算 z + 1，再赋值（= 优先级最低）
  let mut a: i32 = 0b1010;
  let mut b: i32 = a << 2 & 0xFF;    // = (a << 2) & 0xFF（<< 优先级高于 &）
  let mut c: i32 = a & b | 0x10;     // = (a & b) | 0x10（& 优先级高于 |）
  ```

---

## 11 类型转换

### 11.1 转换语法

阿雅提供两种类型转换语法：

1. **安全转换 `as`**：只允许无精度损失的转换
2. **强转 `as!`**：允许所有转换，包括可能有精度损失的

### 11.2 安全转换（as）

安全转换只允许无精度损失的转换，可能损失精度的转换会编译错误：

```aya
// ✅ 允许的转换（无精度损失）
let x: f32 = 1.5;
let y: f64 = x as f64;  // f32 -> f64，扩展精度，无损失

let i: i32 = 42;
let f: f64 = i as f64;  // i32 -> f64，无损失

let small: i8 = 100;
let f32_val: f32 = small as f32;  // i8 -> f32，小整数，无损失

// ❌ 编译错误（可能有精度损失）
let x: f64 = 3.141592653589793;
let y: f32 = x as f32;  // 编译错误：f64 -> f32 可能有精度损失

let large: i32 = 100000000;
let f: f32 = large as f32;  // 编译错误：i32 -> f32 可能损失精度

let pi: f64 = 3.14;
let n: i32 = pi as i32;  // 编译错误：f64 -> i32 截断转换
```

### 11.3 强转（as!）

当确实需要进行可能有精度损失的转换时，使用 `as!` 强转语法：

```aya
// ✅ 强转允许精度损失
let x: f64 = 3.141592653589793;
let y: f32 = x as! f32;  // 程序员明确知道可能有精度损失

let large: i32 = 100000000;
let f: f32 = large as! f32;  // i32 -> f32，使用强转

let pi: f64 = 3.14;
let n: i32 = pi as! i32;  // f64 -> i32，截断为 3

let i64_val: i64 = 9007199254740992;  // 超过 f64 精度范围
let f: f64 = i64_val as! f64;  // i64 -> f64，可能损失精度
```

### 11.4 转换规则表

| 源类型 | 目标类型 | `as` | `as!` | 说明 |
|--------|---------|------|-------|------|
| `f32` | `f64` | ✅ | ✅ | 扩展精度，无损失 |
| `f64` | `f32` | ❌ | ✅ | 可能损失精度 |
| `i32` | `f64` | ✅ | ✅ | f64 可精确表示所有 i32 |
| `i32` | `f32` | ❌ | ✅ | 超出 ±16,777,216 可能损失精度 |
| `i64` | `f64` | ❌ | ✅ | 大整数可能损失精度 |
| `i64` | `f32` | ❌ | ✅ | 可能损失精度 |
| `i8` | `f32` | ✅ | ✅ | 小整数，无损失 |
| `i16` | `f32` | ✅ | ✅ | 小整数，无损失 |
| `f64` | `i32` | ❌ | ✅ | 截断，可能损失 |
| `f32` | `i32` | ❌ | ✅ | 截断，可能损失 |
| `f64` | `i64` | ❌ | ✅ | 截断，可能损失 |
| `f32` | `i64` | ❌ | ✅ | 截断，可能损失 |

**精度说明**：
- `f32` 可以精确表示的整数范围：-2^24 到 2^24（-16,777,216 到 16,777,216）
- `f64` 可以精确表示的整数范围：-2^53 到 2^53（-9,007,199,254,740,992 到 9,007,199,254,740,992）
- 超出这些范围的整数转换为浮点数时可能损失精度

### 11.5 编译期常量转换

```aya
// 编译期常量转换，零运行时开销
const PI_F64: f64 = 3.141592653589793;
const PI_F32: f32 = PI_F64 as! f32;  // 编译期求值，使用强转

const MAX_I32: i32 = 2147483647;
const MAX_F64: f64 = MAX_I32 as f64;  // 编译期求值，安全转换

// 编译后直接是常量，无运行时转换
```

### 11.6 错误信息示例

```aya
// 源代码
let x: f64 = 3.14;
let y: f32 = x as f32;

// 编译错误信息
error: 类型转换可能有精度损失
  --> example.aya:2:18
   |
 2 | let y: f32 = x as f32;
   |              ^^^^^^^^
   |
   = note: f64 -> f32 转换可能损失精度
   = help: 如果确实需要此转换，请使用 'as!' 强转语法
   = help: 例如: let y: f32 = x as! f32;
```

### 11.7 设计哲学

- **默认安全**：普通 `as` 转换只允许无精度损失的转换，防止意外精度损失
- **显式强转**：`as!` 语法明确表示程序员知道可能有精度损失，意图清晰
- **零运行时开销**：所有转换在编译期或运行时生成单条机器指令
- **编译期检查**：转换安全性在编译期验证，失败即编译错误

### 11.8 代码生成

```aya
// 源代码
let x: f64 = 3.14;
let y: f32 = x as! f32;

// x86-64 生成的代码（伪代码）
//   movsd  xmm0, [x]      ; 加载 f64
//   cvtsd2ss xmm0, xmm0   ; 转换为 f32（单条指令）
//   movss  [y], xmm0      ; 存储 f32
// 零运行时开销，与普通 as 相同
```

---

## 12 内存模型 & RAII

1. 编译期为每个类型 `T` 生成 `drop(T)`（空函数或用户自定义）。  
2. 离开作用域时按字段逆序插入 `drop` 调用。  
3. **递归 drop 规则**：先 drop 字段，再 drop 外层结构体；字段按声明逆序 drop。
4. **数组 drop 规则**：
   - 数组元素按索引逆序 drop（`arr[N-1]`, `arr[N-2]`, ..., `arr[0]`）
   - 然后 drop 数组本身（数组本身的 drop 是空函数，但会调用元素的 drop）
   - 如果数组元素类型有自定义 drop，会调用元素的 drop；如果元素类型是基本类型，drop 是空函数
5. **用户自定义 drop**：`fn drop(self: T) -> void { ... }`
   - 允许用户为自定义类型定义清理逻辑
   - 实现真正的 RAII 模式（文件自动关闭、内存自动释放等）
   - 每个类型只能有一个 drop 函数
   - 参数必须是 `self: T`（按值传递），返回类型必须是 `void`
   - 递归调用：结构体的 drop 会先调用字段的 drop，再调用自身的 drop

**drop 使用示例**：

```aya
struct Point {
  x: f32,
  y: f32
}

fn example() -> void {
  let p: Point = Point{ x: 1.0, y: 2.0 };
  // 使用 p...
  // 离开作用域时，编译器自动插入：
  // drop(p.y);  // 先 drop 字段（逆序）
  // drop(p.x);
  // drop(p);   // 再 drop 外层结构体
}

// 嵌套结构体示例
struct Line {
  start: Point,
  end: Point
}

fn nested_example() -> void {
  let line: Line = Line{
    start: Point{ x: 0.0, y: 0.0 },
    end: Point{ x: 1.0, y: 1.0 }
  };
  // 离开作用域时，编译器自动插入：
  // drop(line.end.y);   // 递归 drop：先字段
  // drop(line.end.x);
  // drop(line.end);     // 再外层
  // drop(line.start.y);
  // drop(line.start.x);
  // drop(line.start);
  // drop(line);
}
```

**用户自定义 drop 示例**：

```aya
// 示例 1：文件句柄自动关闭
extern i32 open(byte* path, i32 flags);
extern i32 close(i32 fd);

struct File {
    fd: i32
}

fn drop(self: File) -> void {
    if self.fd >= 0 {
        close(self.fd);
    }
}

fn example1() -> void {
    let f: File = File{ fd: open("file.txt", 0) };
    // 使用文件...
    // 离开作用域时自动调用 drop，自动关闭文件
}

// 示例 2：堆内存自动释放
extern void* malloc(i32 size);
extern void free(void* ptr);

struct HeapBuffer {
    data: byte*,
    size: i32
}

fn drop(self: HeapBuffer) -> void {
    if self.data != null {
        free(self.data);
    }
}

fn example2() -> void {
    let buf: HeapBuffer = HeapBuffer{
        data: malloc(100),
        size: 100
    };
    // 使用缓冲区...
    // 离开作用域时自动释放内存
}

// 示例 3：嵌套结构体的 drop
struct FileReader {
    file: File,           // File 有自定义 drop
    buffer: [byte; 1024]  // 数组本身的 drop 是空函数，但会调用元素的 drop（byte 的 drop 是空函数）
}

fn example3() -> void {
    let reader: FileReader = FileReader{
        file: File{ fd: open("file.txt", 0) },
        buffer: [0; 1024]
    };
    // 离开作用域时：
    // 1. drop(reader.buffer) - 先 drop 数组元素（byte 的 drop 是空函数），再 drop 数组本身（空函数）
    // 2. drop(reader.file) - 调用 File 的 drop，关闭文件
    // 3. drop(reader) - 空函数（如果 FileReader 没有自定义 drop）
}
```

**drop 使用示例（基本类型和结构体）**：

```aya
// 基本类型：drop 是空函数
fn example_basic() -> void {
  let x: i32 = 10;
  let y: f64 = 3.14;
  // 离开作用域时，编译器会插入：
  // drop(y);  // 空函数，无操作
  // drop(x);  // 空函数，无操作
}

// 数组：元素按索引逆序 drop
fn example_array() -> void {
  let arr: [f32; 4] = [1.0, 2.0, 3.0, 4.0];
  // 离开作用域时，编译器会插入：
  // drop(arr[3]);  // 逆序 drop 元素
  // drop(arr[2]);
  // drop(arr[1]);
  // drop(arr[0]);
  // drop(arr);
}

// 作用域嵌套：变量在各自作用域结束时 drop
fn example_scope() -> void {
  let outer: i32 = 10;
  {
    let inner: i32 = 20;
    // inner 在这里 drop（离开内层作用域）
  }
  // outer 在这里 drop（离开外层作用域）
}

// 函数参数：按值传递，函数返回时会 drop
fn process(data: Point) -> void {
  // data 在这里 drop（函数返回时）
}

// 函数返回值：被调用者接收，在调用者作用域中 drop
fn create_point() -> Point {
  return Point{ x: 1.0, y: 2.0 };
  // 返回值不会在这里 drop，而是传递给调用者
}
```

**重要说明**：
- `drop` 是**自动调用**的，无需手动调用
- 对于基本类型（`i32`, `f64`, `bool` 等），`drop` 是空函数，无运行时开销
- 用户可以为自定义类型定义 `drop` 函数，实现 RAII 模式
- 编译器自动插入 drop 调用，确保资源正确释放

**未来版本特性**（后续版本）：
- 移动语义优化：避免不必要的拷贝
  - 赋值、函数参数、返回值自动使用移动语义
  - 零开销的所有权转移，提高性能
- drop 标记：`#[no_drop]` 用于无需清理的类型
  - 标记纯数据类型，编译器跳过 drop 调用
  - 进一步优化性能，零运行时开销

---

## 13 原子操作（0.9 终极简洁）

### 13.1 设计目标

- **关键字 `atomic T`** → 语言层原子类型
- **读/写/复合赋值 = 自动原子指令** → 零运行时锁
- **通过路径 = 零指令**
- **失败 = 类型非 `atomic T` → 编译错误**

### 13.2 语法

```aya
struct Counter {
  value: atomic i32
}

fn increment(counter: *Counter) -> void {
  counter.value += 1;  // 自动原子 fetch_add
  let v: i32 = counter.value;  // 自动原子 load
  counter.value = 10;  // 自动原子 store
}
```

### 13.3 语义

| 操作 | 自动生成 | 说明 |
|---|---|---|
| `let v = cnt;` | 原子 load | 读取原子类型值 |
| `cnt = val;` | 原子 store | 写入原子类型值 |
| `cnt += val;` | 原子 fetch_add | 复合赋值自动原子化（硬件支持） |
| `cnt -= val;` | 原子 fetch_sub | 复合赋值自动原子化（硬件支持） |
| `cnt *= val;` | 原子 fetch_mul | 复合赋值自动原子化（**软件实现**，硬件通常不支持） |
| `cnt /= val;` | 原子 fetch_div | 复合赋值自动原子化（**软件实现**，硬件不支持） |
| `cnt %= val;` | 原子 fetch_mod | 复合赋值自动原子化（**软件实现**，硬件不支持） |

**硬件支持说明**：
- **硬件直接支持**：`+=`、`-=`（大多数架构支持）
- **软件实现**：`*=`、`/=`、`%=` 等操作需要软件实现（使用 compare-and-swap 循环）
- 所有原子操作都保证原子性，但软件实现的操作可能有更高的性能开销

### 13.4 内存序（Memory Ordering）

- **默认内存序**：所有原子操作使用 **sequentially consistent (seq_cst)** 内存序
  - 保证所有线程看到相同的操作顺序
  - 提供最强的内存同步保证
  - 与 C++ `std::memory_order_seq_cst` 语义一致
- **0.9 限制**：不支持自定义内存序（如 acquire、release、relaxed）
  - 后续版本可能支持显式内存序参数
- **性能考虑**：seq_cst 可能比 relaxed 内存序有更高的性能开销，但提供最强的安全性保证

### 13.5 限制

- **类型必须是 `atomic T`**：非原子类型进行原子操作 → 编译错误
- **零新符号**：无需额外的语法标记
- **通过路径零指令**：所有原子操作直接生成硬件原子指令

### 13.6 一句话总结

> **阿雅 0.9 原子操作 = `atomic T` 关键字 + 自动原子指令**；  
> **读/写/复合赋值自动原子化，零运行时锁，通过路径零指令。**

---

## 14 内存安全（0.9 强制）

### 14.1 设计目标

- **所有 UB 必须被编译期证明为安全**
- **失败即编译错误，不生成代码**
- **零运行时检查，通过路径零指令**

### 14.2 内存安全强制表

| UB 场景 | 必须证明为安全 | 失败结果 |
|---|---|---|
| 数组越界 | 常量索引越界 → 编译错误；变量索引 → 证明 `i >= 0 && i < len` | **编译错误** |
| 空指针解引用 | 证明 `ptr != null` 或前序有 `if ptr == null { return error; }` | **编译错误** |
| 使用未初始化 | 证明「首次使用前已赋值」或「前序有赋值路径」 | **编译错误** |
| 整数溢出 | 常量溢出 → 编译错误；变量 → 显式检查或编译器证明无溢出 | **编译错误** |
| 除零错误 | 常量除零 → 编译错误；变量 → 证明 `y != 0` | **编译错误** |

### 14.3 证明机制

- **编译期静态分析**：编译器分析所有代码路径
- **常量折叠**：编译期常量直接检查
- **路径敏感分析**：跟踪变量状态和条件分支
- **失败即错误**：无法证明安全 → 编译错误，不生成代码

### 14.4 示例

```aya
// ✅ 编译通过：常量索引在范围内
let arr: [i32; 10] = [0; 10];
let x: i32 = arr[5];  // 5 < 10，编译期证明安全

// ❌ 编译错误：常量索引越界
let y: i32 = arr[10];  // 10 >= 10，编译错误

// ✅ 编译通过：变量索引有证明
fn safe_access(arr: [i32; 10], i: i32) -> i32 {
  if i < 0 || i >= 10 {
    return error.OutOfBounds;
  }
  return arr[i];  // 编译器证明 i >= 0 && i < 10，在范围内
}

// ❌ 编译错误：变量索引无证明
fn unsafe_access(arr: [i32; 10], i: i32) -> i32 {
  return arr[i];  // 无法证明 i >= 0 && i < 10，编译错误
}
```

**整数溢出处理示例**：

```aya
// ✅ 编译通过：常量运算，编译器可以证明无溢出
// 使用 max/min 关键字访问极值（推荐，最优雅）
let x: i32 = 100 + 200;  // 编译期常量折叠，证明无溢出（300 < max）

// 也可以用于常量定义（类型推断）
const MAX_I32: i32 = max;  // 从类型注解 i32 推断出是 i32 的最大值
const MIN_I32: i32 = min;  // 从类型注解 i32 推断出是 i32 的最小值

// ❌ 编译错误：常量溢出
let y: i32 = 2147483647 + 1;  // 编译错误：常量溢出
let z: i32 = -2147483648 - 1;  // 编译错误：常量下溢

// ✅ 编译通过：变量运算有显式溢出检查
error Overflow;

// 方式1：返回错误（错误联合类型）
// 使用标准库函数（推荐，最优雅）
error Overflow;

fn add_safe(a: i32, b: i32) -> !i32 {
    return checked_add(a, b);  // 自动检查溢出，溢出返回错误
}

// 注意：error Overflow; 必须在顶层定义，不能在函数内定义

// 方式1（备选）：手动检查（如果需要自定义逻辑）
fn add_safe_manual(a: i32, b: i32) -> !i32 {
    // 显式检查上溢：a > 0 && b > 0 && a + b > MAX
    // 编译器从 a 和 b 的类型 i32 推断 max 和 min 的类型
    if a > 0 && b > 0 && a > max - b {
        return error.Overflow;  // 返回错误
    }
    // 显式检查下溢：a < 0 && b < 0 && a + b < MIN
    if a < 0 && b < 0 && a < min - b {
        return error.Overflow;  // 返回错误
    }
    // 编译器证明：经过检查后，a + b 不会溢出
    return a + b;
}

// 方式2：返回饱和值（有效数值）
// 使用标准库函数（推荐，最优雅）
fn add_saturating(a: i32, b: i32) -> i32 {
    return saturating_add(a, b);  // 自动饱和，溢出返回极值
}

// 方式2（备选）：手动检查（如果需要自定义逻辑）
fn add_saturating_manual(a: i32, b: i32) -> i32 {
    // 显式检查上溢：返回最大值
    // 编译器从函数返回类型和参数类型推断 max/min 的类型
    if a > 0 && b > 0 && a > max - b {
        return max;  // 上溢时返回最大值
    }
    // 显式检查下溢：返回最小值
    if a < 0 && b < 0 && a < min - b {
        return min;  // 下溢时返回最小值
    }
    // 编译器证明：经过检查后，a + b 不会溢出
    return a + b;
}

// 方式3：返回包装值（有效数值）
// 使用标准库函数（推荐，最优雅）
fn add_wrapping(a: i32, b: i32) -> i32 {
    return wrapping_add(a, b);  // 自动包装，溢出返回包装值
}

// 方式3（备选）：手动检查（如果需要自定义逻辑）
fn add_wrapping_manual(a: i32, b: i32) -> i32 {
    // 包装算术的实现：使用更大的类型进行计算，然后截断
    // 这样即使溢出，也会自动包装回类型的另一端
    let sum: i64 = (a as i64) + (b as i64);
    return (sum as! i32);  // 显式截断到 i32 范围，溢出时自动包装
    
    // 说明：
    // - 如果 a + b 在 i32 范围内，结果正常
    // - 如果 a + b 溢出，截断会保留低 32 位，自动包装
    //   例如：2147483647 + 1 = 2147483648 (i64)
    //        截断为 i32 后 = -2147483648 (包装后的值)
    //   例如：-2147483648 - 1 = -2147483649 (i64)
    //        截断为 i32 后 = 2147483647 (包装后的值)
}

// ✅ 编译通过：乘法溢出检查
// 使用标准库函数（推荐，最优雅）
fn mul_safe(a: i32, b: i32) -> !i32 {
    return checked_mul(a, b);  // 自动检查溢出，溢出返回错误
}

// 方式（备选）：手动检查（如果需要自定义逻辑）
fn mul_safe_manual(a: i32, b: i32) -> !i32 {
    if a == 0 || b == 0 {
        return 0;  // 零乘法，无溢出
    }
    // 检查上溢：a > 0 && b > 0 && a * b > MAX
    // 编译器从参数类型推断 max/min 的类型
    if a > 0 && b > 0 && a > max / b {
        return error.Overflow;
    }
    // 检查下溢：a < 0 && b < 0 && a * b > MAX（负负得正）
    if a < 0 && b < 0 && a < max / b {
        return error.Overflow;
    }
    // 检查混合符号：a > 0 && b < 0 && a * b < MIN
    if a > 0 && b < 0 && a > min / b {
        return error.Overflow;
    }
    // 检查混合符号：a < 0 && b > 0 && a * b < MIN
    if a < 0 && b > 0 && b > min / a {
        return error.Overflow;
    }
    // 编译器证明：经过检查后，a * b 不会溢出
    return a * b;
}

// ❌ 编译错误：无法证明无溢出
fn add_unsafe(a: i32, b: i32) -> i32 {
    return a + b;  // 编译错误：无法证明 a + b 不会溢出
}

// ❌ 编译错误：无法证明无溢出
fn mul_unsafe(a: i32, b: i32) -> i32 {
    return a * b;  // 编译错误：无法证明 a * b 不会溢出
}

// ✅ 编译通过：已知范围的变量
fn add_known_range(a: i32, b: i32) -> i32 {
    // 如果编译器可以证明 a 和 b 都在安全范围内
    // 例如：a 和 b 都是数组索引（已验证 < 1000）
    // 编译器可以证明 a + b < 2000 < 2147483647，无溢出
    if a < 0 || a >= 1000 || b < 0 || b >= 1000 {
        return error.OutOfBounds;
    }
    return a + b;  // 编译器证明：a < 1000 && b < 1000，所以 a + b < 2000，无溢出
}

// ========== i64 溢出处理示例 ==========

// ✅ 编译通过：i64 常量运算无溢出
// 使用 max/min 关键字访问极值（推荐，最优雅）
let x64: i64 = 1000000000 + 2000000000;  // 编译期常量折叠，证明无溢出

// ❌ 编译错误：i64 常量溢出
let y64: i64 = max + 1;  // 编译错误：常量溢出（从类型注解 i64 推断）
let z64: i64 = min - 1;  // 编译错误：常量下溢（从类型注解 i64 推断）

// ✅ 编译通过：i64 变量运算有显式溢出检查
// 使用标准库函数（推荐，最优雅）
fn add_safe_i64(a: i64, b: i64) -> !i64 {
    return checked_add(a, b);  // 自动检查溢出，溢出返回错误
}

// 方式（备选）：手动检查（如果需要自定义逻辑）
fn add_safe_i64_manual(a: i64, b: i64) -> !i64 {
    // 显式检查上溢：a > 0 && b > 0 && a + b > MAX
    // 编译器从参数类型 i64 推断 max/min 的类型
    if a > 0 && b > 0 && a > max - b {
        return error.Overflow;
    }
    // 显式检查下溢：a < 0 && b < 0 && a + b < MIN
    if a < 0 && b < 0 && a < min - b {
        return error.Overflow;
    }
    // 编译器证明：经过检查后，a + b 不会溢出
    return a + b;
}

// ✅ 编译通过：i64 乘法溢出检查
// 使用标准库函数（推荐，最优雅）
fn mul_safe_i64(a: i64, b: i64) -> !i64 {
    return checked_mul(a, b);  // 自动检查溢出，溢出返回错误
}

// 方式（备选）：手动检查（如果需要自定义逻辑）
fn mul_safe_i64_manual(a: i64, b: i64) -> !i64 {
    if a == 0 || b == 0 {
        return 0;  // 零乘法，无溢出
    }
    // 检查上溢：a > 0 && b > 0 && a * b > MAX
    // 编译器从参数类型 i64 推断 max/min 的类型
    if a > 0 && b > 0 && a > max / b {
        return error.Overflow;
    }
    // 检查下溢：a < 0 && b < 0 && a * b > MAX（负负得正）
    if a < 0 && b < 0 && a < max / b {
        return error.Overflow;
    }
    // 检查混合符号：a > 0 && b < 0 && a * b < MIN
    if a > 0 && b < 0 && a > min / b {
        return error.Overflow;
    }
    // 检查混合符号：a < 0 && b > 0 && a * b < MIN
    if a < 0 && b > 0 && b > min / a {
        return error.Overflow;
    }
    // 编译器证明：经过检查后，a * b 不会溢出
    return a * b;
}

// ❌ 编译错误：i64 无法证明无溢出
fn add_unsafe_i64(a: i64, b: i64) -> i64 {
    return a + b;  // 编译错误：无法证明 a + b 不会溢出
}

// ✅ 编译通过：i64 已知范围的变量
fn add_known_range_i64(a: i64, b: i64) -> !i64 {
    // 如果编译器可以证明 a 和 b 都在安全范围内
    // 例如：a 和 b 都是已验证的范围（< 1000000000）
    if a < 0 || a >= 1000000000 || b < 0 || b >= 1000000000 {
        return error.OutOfBounds;
    }
    return a + b;  // 编译器证明：a < 1000000000 && b < 1000000000，所以 a + b < 2000000000，无溢出
}
```

**溢出检查规则**：

1. **常量运算**：
   - 编译期常量运算直接检查，溢出即编译错误
   - 示例：
     - `let x: i32 = 2147483647 + 1;` → 编译错误（i32 溢出）
     - `let y: i64 = 9223372036854775807 + 1;` → 编译错误（i64 溢出）

2. **标准库函数（最推荐，最优雅）**：
   - 使用标准库函数 `checked_*`、`saturating_*`、`wrapping_*` 进行溢出检查
   - 一行代码替代多行溢出检查，代码简洁优雅
   - 编译期展开，零运行时开销，与手写代码性能相同
   - 示例：
     ```aya
     error Overflow;
     
     // checked 系列：返回错误联合类型
     fn add_safe(a: i32, b: i32) -> !i32 {
         return checked_add(a, b);  // 自动检查溢出
     }
     
     // saturating 系列：返回饱和值
     fn add_saturating(a: i32, b: i32) -> i32 {
         return saturating_add(a, b);  // 自动饱和
     }
     
     // wrapping 系列：返回包装值
     fn add_wrapping(a: i32, b: i32) -> i32 {
         return wrapping_add(a, b);  // 自动包装
     }
     ```
   - **支持的函数**：
     - `checked_add(a, b)`、`checked_sub(a, b)`、`checked_mul(a, b)`
     - `saturating_add(a, b)`、`saturating_sub(a, b)`、`saturating_mul(a, b)`
     - `wrapping_add(a, b)`、`wrapping_sub(a, b)`、`wrapping_mul(a, b)`
   - **支持的类型**：`i8`, `i16`, `i32`, `i64`
   - **编译期展开**：这些函数在编译期展开为相应的溢出检查代码，零运行时开销

3. **max/min 关键字（备选方式）**：
   - 使用 `max` 和 `min` 关键字访问类型的极值常量
   - `max` 和 `min` 是语言关键字，编译器从上下文类型自动推断极值类型
   - 适用于需要自定义溢出检查逻辑的场景
   - 示例：
     ```aya
     // 使用 max/min 关键字访问极值（类型推断）
     let a: i32 = ...;
     let b: i32 = ...;
     if a > 0 && b > 0 && a > max - b {  // 从 a 和 b 的类型 i32 推断
         return error.Overflow;
     }
     
     // 也可以用于常量定义（类型推断）
     const MAX_I32: i32 = max;  // 从类型注解 i32 推断出是 i32 的最大值
     const MIN_I32: i32 = min;  // 从类型注解 i32 推断出是 i32 的最小值
     ```
   - **类型推断规则**：
     - 常量定义：从类型注解推断，如 `const MAX: i32 = max;` → `max i32`
     - 表达式上下文：从操作数类型推断，如 `a > max - b`（a 和 b 是 i32）→ `max i32`
     - 函数返回：从返回类型推断，如 `return max;`（函数返回 i32）→ `max i32`
   - **极值对应表**：
     - `max`（i32 上下文）：2147483647
     - `min`（i32 上下文）：-2147483648
     - `max`（i64 上下文）：9223372036854775807
     - `min`（i64 上下文）：-9223372036854775808
   - **编译期常量**：这些表达式在编译期求值，零运行时开销

4. **变量运算**：
   - 必须显式检查溢出条件，或编译器能够证明无溢出
   - 无法证明无溢出 → 编译错误
   - 显式检查后，编译器可以证明后续运算安全
   - **溢出处理方式**：
     - **返回错误**：使用错误联合类型 `!T`，溢出时返回 `error.Overflow`
     - **返回饱和值**：溢出时返回类型的最大值或最小值（饱和算术）
     - **返回包装值**：溢出时返回包装后的值（包装算术，需要显式计算）

5. **溢出检查模式**（适用于所有整数类型：i8, i16, i32, i64，手动检查时使用）：
   - **加法上溢**：`a > 0 && b > 0 && a > MAX - b`
   - **加法下溢**：`a < 0 && b < 0 && a < MIN - b`
   - **乘法上溢**：`a > 0 && b > 0 && a > MAX / b`
   - **乘法下溢**：需要检查所有符号组合（正×负、负×正、负×负）
   - **类型范围**：
     - `i32`：MAX = 2,147,483,647，MIN = -2,147,483,648
     - `i64`：MAX = 9,223,372,036,854,775,807，MIN = -9,223,372,036,854,775,808
   - **示例**：
     - i32 加法上溢检查：`if a > 0 && b > 0 && a > 2147483647 - b { return error.Overflow; }`
     - i64 加法上溢检查：`if a > 0 && b > 0 && a > 9223372036854775807 - b { return error.Overflow; }`
   - **乘法下溢**：需要检查所有符号组合

6. **编译器证明**：
   - 如果编译器可以通过路径敏感分析证明无溢出，则编译通过
   - 例如：已知 `a < 1000 && b < 1000`，可以证明 `a + b < 2000`，无溢出

### 14.5 一句话总结

> **阿雅 0.9 内存安全 = 所有 UB 必须被编译期证明为安全 → 失败即编译错误**；  
> **零运行时检查，通过路径零指令，失败路径不存在。**

---

## 15 并发安全（0.9 强制）

### 15.1 设计目标

- **原子类型 `atomic T`** → 语言层原子
- **读/写/复合赋值 = 自动原子指令** → **零运行时锁**
- **数据竞争 = 零**（所有原子操作自动序列化）
- **零新符号**：无需额外的语法标记

### 15.2 并发安全机制

| 特性 | 0.9 实现 | 说明 |
|---|---|---|
| 原子类型 | `atomic T` 关键字 | 语言层原子类型 |
| 原子操作 | 自动生成原子指令 | 读/写/复合赋值自动原子化 |
| 数据竞争 | 零（编译期保证） | 所有原子操作自动序列化 |
| 运行时锁 | 零 | 无锁编程，直接硬件原子指令 |

### 15.3 示例

```aya
struct Counter {
  value: atomic i32
}

impl Counter : IIncrement {
  fn inc(self: *Self) -> i32 {
    self.value += 1;  // 自动原子 fetch_add
    return self.value;  // 自动原子 load
  }
}

fn main() -> i32 {
  let counter: Counter = Counter{ value: 0 };
  // 多线程并发递增，零数据竞争
  // 所有操作自动原子化，无需锁
  return 0;
}
```

### 15.4 限制

- **只靠原子类型**：并发安全只靠 `atomic T` + 自动原子指令

### 15.5 一句话总结

> **阿雅 0.9 并发安全 = 原子类型 + 自动原子指令**；  
> **零数据竞争，零运行时锁，通过路径零指令。**

---

## 16 标准库（0.9 最小集）

| 函数 | 签名 | 说明 |
|------|------|------|
| `len` | `fn len(a: [T; N]) -> i32` | 返回数组元素个数 `N`（编译期常量） |
| `iter` | `fn iter(arr: *[T; N]) -> IteratorT` | 为数组创建迭代器，返回类型取决于元素类型 `T` |
| `range` | `fn range(start: i32, end: i32) -> RangeIterator` | 创建整数范围迭代器，迭代从 `start` 到 `end-1` |
| `checked_add` | `fn checked_add(a: T, b: T) -> !T` | 检查加法溢出，溢出返回错误，否则返回值 |
| `checked_sub` | `fn checked_sub(a: T, b: T) -> !T` | 检查减法溢出，溢出返回错误，否则返回值 |
| `checked_mul` | `fn checked_mul(a: T, b: T) -> !T` | 检查乘法溢出，溢出返回错误，否则返回值 |
| `saturating_add` | `fn saturating_add(a: T, b: T) -> T` | 饱和加法，溢出返回极值 |
| `saturating_sub` | `fn saturating_sub(a: T, b: T) -> T` | 饱和减法，溢出返回极值 |
| `saturating_mul` | `fn saturating_mul(a: T, b: T) -> T` | 饱和乘法，溢出返回极值 |
| `wrapping_add` | `fn wrapping_add(a: T, b: T) -> T` | 包装加法，溢出返回包装值 |
| `wrapping_sub` | `fn wrapping_sub(a: T, b: T) -> T` | 包装减法，溢出返回包装值 |
| `wrapping_mul` | `fn wrapping_mul(a: T, b: T) -> T` | 包装乘法，溢出返回包装值 |

**说明**：
- `T` 支持：`i8`, `i16`, `i32`, `i64`
- 这些函数是编译器内置的，编译期展开，零运行时开销
- 自动可用，无需导入或声明

**函数详细说明**：

1. **`len(a: [T; N]) -> i32`**
   - 功能：返回数组的元素个数
   - 参数：`a` 是任意类型 `T` 的数组，大小为 `N`
   - 返回值：`i32` 类型，值为 `N`（编译期常量）
   - 注意：由于 `N` 是编译期常量，此函数在编译期求值，零运行时开销
   - 示例：
     ```aya
     let arr: [i32; 10] = [0; 10];
     let size: i32 = len(arr);  // size = 10（编译期常量）
     ```

2. **`iter(arr: *[T; N]) -> IteratorT`**
   - 功能：为数组创建迭代器
   - 参数：`arr` 是指向数组的指针（类型 `*[T; N]`）
   - 返回值：返回类型取决于数组元素类型 `T`
     - 对于 `i32` 数组：返回 `ArrayIteratorI32`
     - 对于 `f64` 数组：返回 `ArrayIteratorF64`
     - 0.9 需要为每种元素类型定义对应的迭代器类型
   - 行为：创建的迭代器可以自动装箱为对应的迭代器接口（如 `IIteratorI32`）
   - for循环会自动调用此函数为数组创建迭代器
   - 示例：
     ```aya
     let arr: [i32; 5] = [1, 2, 3, 4, 5];
     let iter: IIteratorI32 = iter(&arr);  // 自动装箱为接口
     ```

3. **`range(start: i32, end: i32) -> RangeIterator`**
   - 功能：创建整数范围迭代器，迭代从 `start` 到 `end-1` 的整数（左闭右开区间）
   - 参数：
     - `start`：起始值（包含）
     - `end`：结束值（不包含）
   - 返回值：`RangeIterator` 类型，实现 `IIteratorI32` 接口
   - 行为：迭代器依次返回 `start`, `start+1`, ..., `end-1`
   - 示例：
     ```aya
     // 迭代 0 到 9（10 个整数）
     for (range(0, 10)) |i| {
         printf("%d\n", i);  // 输出 0, 1, 2, ..., 9
     }
     ```
   - 注意：`start` 和 `end` 必须是 `i32` 类型，范围必须在 `i32` 的有效范围内

4. **溢出检查函数**（`checked_*`, `saturating_*`, `wrapping_*`）
   - 功能：提供优雅的溢出检查方式，避免重复编写溢出检查代码
   - 支持的类型：`i8`, `i16`, `i32`, `i64`
   - 编译期展开：这些函数在编译期展开为相应的溢出检查代码，零运行时开销
   - **checked 系列**：返回错误联合类型，溢出时返回 `error.Overflow`
     - **功能**：检查运算是否溢出，溢出时返回错误，否则返回计算结果
     - **返回类型**：`!T`（错误联合类型），需要 `catch` 处理错误
     - **使用场景**：需要明确处理溢出错误的情况（如输入验证、关键计算）
     - **示例**：
       ```aya
       error Overflow;
       
       // 优雅的溢出检查
       fn add_safe(a: i32, b: i32) -> !i32 {
           return checked_add(a, b);  // 自动检查溢出，溢出返回错误
       }
       
       // 使用示例：处理溢出错误
       let result: i32 = checked_add(x, y) catch |err| {
           if err == error.Overflow {
               printf("Overflow occurred\n");
               // 处理溢出情况，如返回默认值或报告错误
           }
           return 0;  // 提供默认值
       };
       
       // 使用示例：传播错误
       fn calculate(a: i32, b: i32, c: i32) -> !i32 {
           let sum: i32 = try checked_add(a, b);  // 溢出时向上传播错误
           return checked_add(sum, c);  // 继续检查
       }
       ```
     - **行为说明**：
       - 如果运算结果在类型范围内，返回计算结果
       - 如果运算结果溢出，返回 `error.Overflow`
       - 必须使用 `catch` 或 `try` 处理可能的错误
   - **saturating 系列**：返回饱和值，溢出时返回类型的最大值或最小值
     - **功能**：执行饱和算术，溢出时返回类型的极值（最大值或最小值），而不是错误
     - **返回类型**：`T`（普通类型），不会返回错误，总是返回有效数值
     - **使用场景**：需要限制结果在类型范围内的场景（如信号处理、图形处理、游戏开发）
     - **示例**：
       ```aya
       // 优雅的饱和算术
       fn add_saturating(a: i32, b: i32) -> i32 {
           return saturating_add(a, b);  // 自动饱和，溢出返回极值
       }
       
       // 使用示例：限制结果范围
       let result: i32 = saturating_add(x, y);  // 溢出时自动返回 max 或 min
       
       // 数值示例（i32 类型）
       let max: i32 = max;  // 2147483647
       let min: i32 = min;  // -2147483648
       
       // 上溢饱和：超过最大值时返回最大值
       let result1: i32 = saturating_add(max, 1);  // 结果 = 2147483647（保持最大值）
       
       // 下溢饱和：小于最小值时返回最小值
       let result2: i32 = saturating_sub(min, 1);  // 结果 = -2147483648（保持最小值）
       
       // 正常情况：不溢出时行为与普通加法相同
       let result3: i32 = saturating_add(100, 200);  // 结果 = 300
       ```
     - **行为说明**：
       - 如果运算结果在类型范围内，返回计算结果
       - 如果运算结果上溢（超过最大值），返回类型的最大值
       - 如果运算结果下溢（小于最小值），返回类型的最小值
       - 总是返回有效数值，无需错误处理
   - **wrapping 系列**：返回包装值，溢出时返回包装后的值
     ```aya
     // 优雅的包装算术
     fn add_wrapping(a: i32, b: i32) -> i32 {
         return wrapping_add(a, b);  // 自动包装，溢出返回包装值
     }
     
     // 使用示例
     let result: i32 = wrapping_add(x, y);  // 溢出时自动包装
     ```
   - **三种方式的对比**：
     | 方式 | 溢出行为 | 返回类型 | 使用场景 |
     |------|----------|----------|----------|
     | `checked_*` | 返回错误 | `!T` | 需要明确处理溢出错误（输入验证、关键计算） |
     | `saturating_*` | 返回极值 | `T` | 需要限制结果范围（信号处理、图形处理） |
     | `wrapping_*` | 返回包装值 | `T` | 需要明确的溢出行为（加密算法、循环计数器） |
     
     **选择建议**：
     - 需要错误处理时 → 使用 `checked_*`
     - 需要限制范围时 → 使用 `saturating_*`
     - 需要包装行为时 → 使用 `wrapping_*`
   
   - **编译期展开示例**：
     ```aya
     // 源代码
     let result: i32 = checked_add(a, b);
     
     // 编译期展开为（伪代码）
     // if a > 0 && b > 0 && a > max - b {
     //     return error.Overflow;
     // }
     // if a < 0 && b < 0 && a < min - b {
     //     return error.Overflow;
     // }
     // return a + b;
     ```
   
   - **优势**：
     - 代码简洁：一行代码替代多行溢出检查
     - 零运行时开销：编译期展开，与手写代码性能相同
     - 类型安全：编译器自动推断类型
     - 统一接口：所有整数类型使用相同的函数名
     - 语义清晰：函数名直接表达溢出处理方式

> 更多函数通过 `extern` 直接调用 C 库即可。

---

## 17 完整示例：结构体 + 栈数组 + FFI

```aya
struct Mat4 {
  m: [f32; 16]
}

extern i32 printf(byte* fmt, ...);

fn print_mat(mat: Mat4) -> void {
  let mut i: i32 = 0;
  while i < 16 {
    printf("%f ", mat.m[i]);
    i = i + 1;
    if (i % 4) == 0 { printf("\n"); }
  }
}

fn main() -> i32 {
  let mut m: Mat4 = Mat4{ m: [0.0; 16] };
  m.m[0]  = 1.0;
  m.m[5]  = 1.0;
  m.m[10] = 1.0;
  m.m[15] = 1.0;
  print_mat(m);
  return 0;
}
```

编译运行（后端示例）：
```
$ ayac demo.aya && ./demo
1.000000 0.000000 0.000000 0.000000
0.000000 1.000000 0.000000 0.000000
0.000000 0.000000 1.000000 0.000000
0.000000 0.000000 0.000000 1.000000
```

---

## 18 完整示例：错误处理 + defer/errdefer

```aya
error FileError;
error ParseError;

extern i32 open(byte* path, i32 flags);  // 简化示例，实际 C 函数需要 flags 参数
extern i32 close(i32 fd);
extern i32 read(i32 fd, byte* buf, i32 size);
extern i32 printf(byte* fmt, ...);

struct File {
    fd: i32
}

fn open_file(path: byte*) !File {
    let fd: i32 = open(path, 0);  // 0 是只读标志（简化示例）
    if fd < 0 {
        return error.FileError;
    }
    return File{ fd: fd };
}

fn drop(self: File) -> void {
    if self.fd >= 0 {
        close(self.fd);
    }
}

fn read_file(path: byte*) !i32 {
    let file: File = try open_file(path);
    defer {
        printf("File operation completed\n");
    }
    errdefer {
        printf("Error occurred, cleaning up\n");
    }
    
    let mut buf: [byte; 1024] = [];
    let n: i32 = read(file.fd, buf, 1024);
    if n < 0 {
        return error.FileError;
    }
    
    return n;
}

fn main() -> i32 {
    let result: i32 = read_file("test.txt") catch |err| {
        // err 是 Error 类型，支持相等性比较
        if err == error.FileError {
            printf("File error occurred\n");
        }
        // 使用 return 提前返回函数（退出 main 函数）
        return 1;
    };
    
    printf("Read %d bytes\n", result);
    return 0;
}
```

---

## 19 完整示例：默认安全并发

```aya
struct Counter {
  value: atomic i32
}

interface IIncrement {
  fn inc(self: *Self) -> i32;
}

impl Counter : IIncrement {
  fn inc(self: *Self) -> i32 {
    self.value += 1;                           // 自动原子 fetch_add
    return self.value;                         // 自动原子 load
  }
}

fn main() -> i32 {
  let counter: Counter = Counter{ value: 0 };
  // 多线程并发递增，零数据竞争
  // 所有操作自动原子化，无需锁
  return 0;
}
```

---

## 20 完整示例：Zig风格的for循环

```aya
extern i32 printf(byte* fmt, ...);

// 迭代器结束错误
error IterEnd;
// 迭代器状态错误（用于value()方法的边界检查）
error InvalidIteratorState;

// i32数组迭代器接口
interface IIteratorI32 {
    fn next(self: *Self) -> !void;
    fn value(self: *Self) -> i32;
}

// 带索引的i32数组迭代器接口
interface IIteratorI32WithIndex {
    fn next(self: *Self) -> !void;
    fn value(self: *Self) -> i32;
    fn index(self: *Self) -> i32;
}

// i32数组迭代器结构体
struct ArrayIteratorI32 {
    arr: *[i32; N],
    current: i32,
    len: i32
}

impl ArrayIteratorI32 : IIteratorI32 {
    fn next(self: *Self) -> !void {
        if self.current >= self.len {
            return error.IterEnd;
        }
        self.current = self.current + 1;
    }
    
    fn value(self: *Self) -> i32 {
        let idx: i32 = self.current - 1;
        // 编译期证明：由于 next() 成功返回，idx 在有效范围内
        if idx < 0 || idx >= self.len {
            return error.InvalidIteratorState;  // 根据设计，这种情况不应该发生
        }
        return (*self.arr)[idx];
    }
}

impl ArrayIteratorI32 : IIteratorI32WithIndex {
    fn next(self: *Self) -> !void {
        if self.current >= self.len {
            return error.IterEnd;
        }
        self.current = self.current + 1;
    }
    
    fn value(self: *Self) -> i32 {
        let idx: i32 = self.current - 1;
        // 编译期证明：由于 next() 成功返回，idx 在有效范围内
        if idx < 0 || idx >= self.len {
            return error.InvalidIteratorState;  // 根据设计，这种情况不应该发生
        }
        return (*self.arr)[idx];
    }
    
    fn index(self: *Self) -> i32 {
        return self.current - 1;
    }
}

// 标准库函数：为数组创建迭代器
fn iter(arr: *[i32; N]) -> ArrayIteratorI32 {
    return ArrayIteratorI32{
        arr: arr,
        current: 0,
        len: N
    };
}

fn main() -> i32 {
    let arr: [i32; 5] = [10, 20, 30, 40, 50];
    
    // 示例1：基本迭代（只获取元素值）
    printf("Basic iteration:\n");
    for (iter(&arr)) |item| {
        printf("  value: %d\n", item);
    }
    
    // 示例2：带索引迭代
    printf("\nIteration with index:\n");
    for (iter(&arr), 0..) |item, index| {
        printf("  arr[%d] = %d\n", index, item);
    }
    
    // 示例3：计算数组元素之和
    let mut sum: i32 = 0;
    for (iter(&arr)) |item| {
        sum = sum + item;
    }
    printf("\nSum of array elements: %d\n", sum);
    
    // 示例4：查找最大值及其索引
    let mut max_val: i32 = 0;
    let mut max_idx: i32 = 0;
    for (iter(&arr), 0..) |item, index| {
        if index == 0 || item > max_val {
            max_val = item;
            max_idx = index;
        }
    }
    printf("Maximum value: %d at index %d\n", max_val, max_idx);
    
    return 0;
}
```

**编译运行结果**：
```
Basic iteration:
  value: 10
  value: 20
  value: 30
  value: 40
  value: 50

Iteration with index:
  arr[0] = 10
  arr[1] = 20
  arr[2] = 30
  arr[3] = 40
  arr[4] = 50

Sum of array elements: 150
Maximum value: 50 at index 4
```

**说明**：
- for循环自动调用 `iter()` 函数为数组创建迭代器
- 迭代器自动装箱为接口类型，使用动态派发
- 零运行时开销，编译期展开为while循环
- 支持基本迭代和带索引迭代两种形式

---

## 21 字符串与格式化（0.9）

### 21.1 设计目标
- 支持 `"hex=${x:#06x}"`、`"pi=${pi:.2f}"` 等常用格式；  
- 仍保持「编译期展开 + 定长栈数组」；  
- 无运行时解析开销，无堆分配；  
- 语法一眼看完。

### 21.2 语法（单页纸）

```
segment = TEXT | '${' expr [':' spec] '}'
spec    = flag* width? precision? type
flag    = '#' | '0' | '-' | ' ' | '+'
width   = NUM | '*'  // '*' 为未来特性，0.9 不支持
precision = '.' NUM | '.*'  // '.*' 为未来特性，0.9 不支持
type    = 'd' | 'u' | 'x' | 'X' | 'f' | 'F' | 'g' | 'G' | 'c' | 'p'
```

- 整体格式 **与 C printf 保持一致**，减少学习成本。  
- `width` / `precision` 必须为**编译期数字**（`*` 暂不支持）。  
- 结果类型仍为 `[i8; N]`，宽度由「格式字符串最大可能长度」常量求值得出。

### 21.3 宽度常量表（0.9）

| 格式 | 最大宽度（含 NUL） | 说明 |
|----|----------------|------|
| `%d` `%u` (i32/u32) | 11 B | 32 位有符号/无符号整数 |
| `%ld` `%lu` (i64/u64) | 21 B | 64 位有符号/无符号整数 |
| `%x` `%X` (i32/u32) | 8 B | 32 位十六进制 |
| `%lx` `%lX` (i64/u64) | 17 B | 64 位十六进制 |
| `%#x` (i32/u32) | 10 B | 32 位带 `0x` 前缀 |
| `%#lx` (i64/u64) | 19 B | 64 位带 `0x` 前缀 |
| `%06x` | 8 B | 字段宽 6，32 位仍 ≤ 8 |
| `%f` `%F` (f64) | 24 B | 双精度浮点默认精度 |
| `%.2f` (f64) | 24 B | 双精度保留 2 位小数（宽度不变） |
| `%f` `%F` (f32) | 16 B | 单精度浮点默认精度 |
| `%.2f` (f32) | 16 B | 单精度保留 2 位小数（宽度不变） |
| `%g` `%G` (f64) | 24 B | 双精度自动精度 |
| `%g` `%G` (f32) | 16 B | 单精度自动精度 |
| `%c` | 2 B | 单字符 |
| `%p` | 18 B | 指针：0x + 16 位十六进制（64位平台） |

**宽度计算规则**：
- 整数类型：根据类型宽度（32位/64位）和符号计算最大字符串长度
- 浮点类型：f64 使用 24 字节，f32 使用 16 字节（包含符号、整数部分、小数点、小数部分、指数部分）
- 指针类型：64位平台使用 18 字节（"0x" + 16位十六进制 + NUL）
- 不同 `width` / `precision` 只选**最宽值**参与总长度计算

> 表格已内置在编译器；编译器根据表达式的实际类型选择对应的宽度值。

### 21.4 完整示例

```aya
extern i32 printf(byte* fmt, ...);

fn main() -> i32 {
  let x: u32 = 255;
  let pi: f64 = 3.1415926;

  let msg: [i8; 64] = "hex=${x:#06x}, pi=${pi:.2f}\n";
  printf(&msg[0]);
  return 0;
}
```

**编译期展开过程**：

1. **编译期常量求值**：编译器根据表达式的类型和格式说明符，查表计算所需的最大缓冲区大小
   - `"hex=${x:#06x}"`：`x` 是 `u32`，格式 `#06x` 最大宽度 10 字节（包含 "0x" 前缀）
   - `"pi=${pi:.2f}"`：`pi` 是 `f64`，格式 `.2f` 最大宽度 24 字节（包含符号、整数、小数、指数部分）
   - 文本段：`"hex="` (5字节) + `", pi="` (6字节) + `"\n"` (2字节)
   - 总宽度：5 + 10 + 6 + 24 + 2 = 47 字节，向上对齐到 64 字节（方便对齐）

2. **代码生成**：编译器生成如下代码（伪代码，实际后端实现可能不同）：

```llvm
%buf = alloca [64 x i8]  ; 编译期计算大小
call memcpy(ptr %buf, ptr @str.0, i64 5)               ; "hex="
call sprintf(ptr %buf+5, "%#06x", i32 %x)              ; 0x00ff（运行时格式化）
call memcpy(ptr %buf+13, ptr @str.1, i64 6)            ; ", pi="
call sprintf(ptr %buf+19, "%.2f", double %pi)          ; 3.14（运行时格式化）
call memcpy(ptr %buf+43, ptr @str.2, i64 2)            ; "\n"
```

**重要说明**：
- **"编译期展开"** 的含义：
  - ✅ 编译期计算缓冲区大小（`[i8; N]` 中的 `N`）
  - ✅ 编译期识别文本段和插值段
  - ✅ 编译期生成格式字符串常量（如 `"%#06x"`）
  - ⚠️ 实际的格式化操作（`sprintf` 调用）在**运行时**执行
  - ✅ 零运行时解析开销：格式字符串在编译期确定，无需运行时解析格式字符串
- **零堆、零 GC**：缓冲区在栈上分配（`alloca`），无需堆分配
- **性能**：与手写 C 代码使用 `sprintf` 的性能相同，无额外开销

### 21.5 后端实现要点

1. **词法** → 识别 `':' spec` 并解析为 `(flag, width, precision, type)` 四元组。  
2. **常量求值** → 根据「类型 + 格式」查表得最大字节数。  
3. **代码生成** →  
   - 文本段 = `memcpy`；  
   - 插值段 = `sprintf(buf+offset, "格式化串", 值)`；  
   - 格式串本身 = 编译期常量。  

### 21.6 限制（保持简单）

| 限制 | 说明 |
|---|---|
| `width/precision` | 必须为**编译期数字**；`*` 暂不支持 |
| 类型不匹配 | `%.2f` 但表达式是 `i32` → 编译错误 |
| 嵌套字符串 | `${"abc"}` → ❌ 表达式内不能再有字符串字面量 |
| 动态宽度 | `"%*d"` → 后续版本支持 |

### 21.7 零开销保证

- **宽度编译期常数** → 不占用寄存器；  
- **无运行时解析** → 无 `vsnprintf` 扫描；  
- **无堆分配** → 仍是 `alloca [N x i8]`；  
- **单条 `sprintf` 调用** → 与手写 C 同速。

### 21.8 一句话总结

> 阿雅自定义格式 `"a=${x:#06x}"` → **编译期展开成定长栈数组**，格式与 C printf 100% 对应，**零运行时解析、零堆、零 GC**，性能 = 手写 `sprintf`。

---

## 22 未实现/将来

### 22.1 核心特性
- 泛型 `template<T>`  
- 指针算术 `*T +/- usize`  
- 宏系统  
- 官方包管理器 `ay`

### 22.2 drop 机制增强（后续版本）
- **移动语义优化**：避免不必要的拷贝
  - 赋值、函数参数、返回值自动使用移动语义
  - 零开销的所有权转移，提高性能
  - 详见 `drop_advanced_features.md`
- **drop 标记**：`#[no_drop]` 用于无需清理的类型
  - 标记纯数据类型，编译器跳过 drop 调用
  - 进一步优化性能，零运行时开销

### 22.3 AI 友好性增强（后续版本）
- **标准库文档字符串**：注释式或结构化文档
  - 帮助 AI 理解函数用途、参数、返回值
  - 提高代码生成准确性
- **更丰富的错误信息**：详细的错误描述和修复建议
  - 类型错误、作用域错误、语法错误的详细说明
  - 提供修复建议，帮助 AI 和用户快速定位问题
- **内置常见模式**：`for` 循环等语法糖
  - `for i in 0..10 { }` 展开为 `while` 循环
  - 标准库模式函数
- **类型推断增强**：局部类型推断（后续版本）
  - 函数内支持类型推断，函数签名仍需显式类型
  - 提高代码简洁性，保持可读性
- **类型别名**：`type UserId = i32;`
  - 提高代码可读性和语义清晰度

---

## 23 一句话总结

> **阿雅 0.9 = 默认即 Rust 级内存安全 + 并发安全**；  
> **只加 1 个关键字 `atomic T`，其余零新符号**；  
> **所有 UB 必须被编译期证明为安全 → 失败即编译错误**；  
> **通过路径零指令，失败路径不存在，不降级、不插运行时锁。**

---

