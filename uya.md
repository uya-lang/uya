# Uya 语言规范 0.28（完整版 · 2026-01-09）

> 零GC · 默认高级安全 · 单页纸可读完  
> 无lifetime符号 · 无隐式控制 · 编译期证明（本函数内）

---

## 目录

- [核心特性](#核心特性)
- [设计哲学](#设计哲学)
- [语法规范](./grammar_formal.md) - 完整BNF语法规范（编译器实现参考）
- [语法速查](./grammar_quick.md) - 语法速查手册（日常开发参考）
- [1. 文件与词法](#1-文件与词法)
- [1.5. 模块系统](#15-模块系统)
- [2. 类型系统](#2-类型系统)
- [3. 变量与作用域](#3-变量与作用域)
- [4. 结构体](#4-结构体)
- [5. 函数](#5-函数)
  - [5.1. 普通函数](#51-普通函数)
  - [5.2. 外部 C 函数（FFI）](#52-外部-c-函数ffi)
  - [5.3. 外部 C 结构体（FFI）](#53-外部-c-结构体ffi)
- [6. 接口（interface）](#6-接口interface)
- [7. 栈式数组（零 GC）](#7-栈式数组零-gc)
- [8. 控制流](#8-控制流)
- [9. defer 和 errdefer](#9-defer-和-errdefer)
- [10. 运算符与优先级](#10-运算符与优先级)
- [11. 类型转换](#11-类型转换)
- [12. 内存模型 & RAII](#12-内存模型--raii)
  - [12.5. 移动语义](#125-移动语义)
- [13. 原子操作](#13-原子操作)
- [14. 内存安全](#14-内存安全)
- [15. 并发安全](#15-并发安全)
- [16. 标准库](#16-标准库)
- [17. 字符串与格式化](#17-字符串与格式化)
- [附录 A. 完整示例](#附录-a-完整示例)
- [附录 B. 未实现/将来](#附录-b-未实现将来)
- [术语表](#术语表)

---

## 核心特性

- **原子类型**（第 13 章）：`atomic T` 关键字，自动原子指令，零运行时锁
- **内存安全强制**（第 14 章）：所有 UB 必须被编译期证明为安全（在当前函数内），常量错误→编译错误，变量证明超时→自动插入运行时检查
- **并发安全强制**（第 15 章）：零数据竞争
- **移动语义**（第 12.5 章）：结构体赋值时转移所有权，避免不必要的拷贝
- **字符串插值**（第 17 章）：支持 `"a${x}"` 和 `"pi=${pi:.2f}"` 两种形式
- **安全指针算术**（第 18 章）：支持 `ptr +/- offset`，必须通过编译期证明安全
- **模块系统**（第 1.5 章）：目录级模块、显式导出、路径导入，编译期解析
- **简化 for 循环语法**（第 8 章）：支持 `for obj |v| {}`、`for 0..10 |v| {}`、`for obj |&v| {}` 等简化语法
- **运算符简化**（第 10 章）：`try` 关键字用于溢出检查，`+|`/`-|`/`*|` 用于饱和运算，`+%`/`-%`/`*%` 用于包装运算

---


## 设计哲学

### 核心思想：坚如磐石

Uya语言的设计哲学是**坚如磐石**（绝对可靠、不可动摇），将所有运行时不确定性转化为编译期的确定性结果：要么证明绝对安全，要么返回显式错误。

**核心机制**：
- 程序员提供**显式证明**，编译器验证证明的正确性
- 编译器在**当前函数内**完成所有安全验证，证明超时则自动插入运行时检查
- 每个操作都有明确的**数学证明**，消除任何运行时不确定性
- 证明范围：仅限当前函数内的代码路径，跨函数调用需要显式处理
- 证明超时：编译器在有限时间内无法完成证明时，自动插入运行时检查，不报错
- 零运行时未定义行为，程序行为完全可预测

**示例**：

[examples/example_000.uya](./examples/example_000.uya)

> **注**：如需了解 Uya 与其他语言的对比，请参阅 [comparison.md](./comparison.md)

### 结果与收益

Uya的"坚如磐石"设计哲学带来以下不可动摇的收益：

1. **绝对的安全性**：通过数学证明彻底消除缓冲区溢出、空指针解引用等内存安全漏洞
2. **完全的可预测性**：程序行为在编译期完全确定，无任何运行时未定义行为
3. **最优的性能**：开发者编写显式安全检查，编译器在当前函数内验证其充分性，消除冗余的运行时安全检查，仅保留必要的错误处理逻辑
4. **明确的错误处理**：可能失败的操作返回错误联合类型`!T`，强制显式错误处理
5. **长期的可维护性**：代码行为清晰可预测，减少调试和维护成本

**性能保证**：

[examples/safe_access.uya](./examples/safe_access.uya)

**关键说明**：
- 编译器在当前函数内进行证明，证明超时则自动插入运行时检查
- 错误路径保留显式检查，确保安全
- 编译器自动消除冗余检查，只保留必要的错误处理逻辑
- 证明超时：编译器在有限时间内无法完成证明时，自动生成运行时边界检查代码


### 一句话总结

> **Uya 的设计哲学 = 坚如磐石 = 程序员提供证明，编译器在当前函数内验证证明，运行时绝对安全**；  
> **将运行时的不确定性转化为编译期的确定性，证明超时则自动插入运行时检查。**

---

## 1 文件与词法

- 文件编码 UTF-8，Unix 换行 `\n`。
- **模块系统**：每个目录自动成为一个模块，详见[第 1.5 章](#15-模块系统)。
  - 项目根目录（包含 `main` 函数的目录）是 `main` 模块
  - 子目录路径映射到模块路径（如 `std/io/` → `std.io`）
  - 目录下的所有 `.uya` 文件都属于同一个模块
- 关键字保留：
  ```
  struct const var fn return extern true false if while break continue
  defer errdefer try catch error null interface atomic max min
  export use
  ```
- 标识符 `[A-Za-z_][A-Za-z0-9_]*`，区分大小写。
- 数值字面量：
  - 整数字面量：`123`（默认类型 `i32`，除非上下文需要其他整数类型）
  - 浮点字面量：`123.456`（默认类型 `f64`，除非上下文需要 `f32`）
- 布尔字面量：`true`、`false`，类型为 `bool`
- 空指针字面量：`null`，类型为 `*byte`
  - 用于与 `*byte` 类型比较，表示空指针：`if ptr == null { ... }`
  - 可以作为 FFI 函数参数（如果函数接受 `*byte`）：`some_function(null);`
  - 不支持将 `null` 赋值给 `*byte` 类型的变量（未来可能支持）
- 字符串字面量：
  - **普通字符串字面量**：`"..."`，类型为 `*byte`（FFI 专用类型，不是普通指针）
    - **重要说明**：`*byte` 是专门用于 FFI（外部函数接口）的特殊类型，表示 C 字符串指针（null 终止），是 FFI 指针 `*T` 的一个实例（T=byte）
    - `*byte` 与普通指针类型 `&T` 不同：`*byte` 仅用于 FFI 上下文，不能进行指针运算或解引用
    - 支持转义序列：`\n` 换行、`\t` 制表符、`\\` 反斜杠、`\"` 双引号、`\0` null 字符
    - 不支持 `\xHH` 或 `\uXXXX`（未来支持）
    - 字符串字面量在 FFI 调用时自动添加 null 终止符
    - **字符串字面量的使用规则**：
      - ✅ 可以作为 FFI 函数调用的参数：`printf("hello\n");`
      - ✅ 可以作为 FFI 函数声明的参数类型示例：`extern printf(fmt: *byte, ...) i32;`
      - ✅ 可以与 `null` 比较（如果函数返回 `*byte`）：`if ptr == null { ... }`
      - ❌ 不能赋值给变量：`const s: *byte = "hello";`（编译错误）
      - ❌ 不能用于数组索引：`arr["hello"]`（编译错误）
      - ❌ 不能用于其他非 FFI 操作
  - **原始字符串字面量**：`` `...` ``，类型为 `*byte`（无转义序列，用于包含特殊字符的字符串）
    - 不支持任何转义序列，所有字符按字面量处理
    - 示例：`` `C:\Users\name` `` 表示字面量字符串，不进行转义
  - **字符串插值**：`"text${expr}text"` 或 `"text${expr:format}text"`，类型为 `[i8: N]`（编译期展开的定长栈数组）
    - **类型说明**：`i8` 是有符号 8 位整数，与 `byte`（无符号 8 位整数）大小相同但符号不同
    - 字符串插值使用 `i8` 是因为 C 字符串通常使用 `char`（有符号），与 C 互操作兼容
    - 支持两种形式：
      - 基本形式：`"a${x}"`（无格式说明符）
      - 格式化形式：`"pi=${pi:.2f}"`（带格式说明符，与 C printf 保持一致）
    - 语法：详见 [grammar_formal.md](./grammar_formal.md#13-字符串插值)
    - 格式说明符 `spec` 与 C printf 保持一致，[详见第 17 章](#17-字符串与格式化)
    - 编译期展开为定长栈数组，零运行时解析开销，零堆分配
    - 示例：`const msg: [i8: 64] = "hex=${x:#06x}, pi=${pi:.2f}\n";`
- 数组字面量：
  - 列表式：`[expr1, expr2, ..., exprN]`（元素数量必须等于数组大小）
  - 重复式：`[value; N]`（value 重复 N 次，N 为编译期常量）
  - 数组字面量的所有元素类型必须完全一致
  - 元素类型必须与数组声明类型匹配（不支持类型推断）
  - 示例：`const arr: [f32: 4] = [1.0, 2.0, 3.0, 4.0];`（元素类型 `f32` 必须与数组元素类型 `f32` 完全匹配）
- 注释 `// 到行尾` 或 `/* 块 */`（可嵌套）。

---

## 1.5 模块系统

> **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#7-模块系统)

### 1.5.1 设计目标

- **目录级模块系统**：每个目录自动成为一个模块
- **显式导出机制**：使用 `export` 关键字标记可导出的项
- **路径式导入**：使用 `use` 关键字和路径语法导入模块
- **编译期解析**：所有模块解析在编译期完成

### 1.5.2 模块定义

- 每个目录自动成为一个模块
- 模块名默认为目录名
- **模块路径基准**：模块路径相对于 **项目根目录**（包含 `main` 函数的目录）计算
- 项目根目录是模块系统的根
- 所有模块路径都相对于项目根目录解析
- **根目录模块**：项目根目录本身是一个特殊模块，模块名为 `main`
  - 项目根目录是包含 `main` 函数的目录
  - 项目根目录下的所有 `.uya` 文件都属于 `main` 模块
  - 使用：`use main.some_function;` 或 `use main;`
- **子目录模块**：目录路径（相对于项目根目录）直接映射到模块路径
  - 项目根目录下的 `std/io/` → 模块路径 `std.io`
  - 项目根目录下的 `math/utils/` → 模块路径 `math.utils`
  - 目录下的所有 `.uya` 文件都属于同一个模块
- **限制**：不支持 `mod` 关键字（块级模块），仅支持目录级模块，符合零新关键字哲学

### 1.5.3 导出机制

- 使用 `export` 关键字标记可导出的项
- 语法：`export fn`, `export struct`, `export interface`, `export const`, `export error`
- **FFI 导出**：
  - `export extern` 用于导出 C FFI 函数：`export extern printf(fmt: *byte, ...) i32;`
  - `export struct` 用于导出结构体：`export struct MyStruct { field1: i32; field2: f64; }`
  - **统一标准**：
    - 所有结构体统一使用 C 内存布局，支持所有类型（包括切片、interface 等）
    - 导出的结构体可以直接与 C 代码互操作
    - 结构体可以有方法、drop、实现接口，同时保持 100% C 兼容性
    - 详见 [4.1 C 内存布局说明](#41-c-内存布局说明)
  - 导出后，其他模块可以通过 `use` 导入并使用这些 FFI 函数/结构体
  - 详见 [5.3 外部 C 结构体（FFI）](#53-外部-c-结构体ffi)
- 未标记 `export` 的项仅在模块内可见
- **为什么使用 `export` 而不是 `pub`**：
  - `export` 语义更明确，专门用于模块导出
  - `pub` 通常表示"公开可见性"（public vs private），概念更通用
  - Uya 选择 `export` 以强调模块间的导出关系，语义更清晰

### 1.5.4 导入机制

- 使用 `use` 关键字导入模块
- 路径语法：`use math.utils;` 或 `use math.utils.add;`
- 支持别名：`use math.utils as math_utils;`
- **限制**：不支持通配符导入（`use math.*;`），避免命名污染和可读性下降
- **模块间引用规则**：
  - 根目录模块（main）可以引用子目录模块：`use std.io;`
  - 子目录模块可以引用其他子目录模块：`use std.io;`
  - **子目录引用 main 模块的处理方式**：
    - **允许但检测循环依赖**（推荐）：
      - 允许子目录模块引用 main 模块：`use main.helper;`
      - 编译器在编译期检测循环依赖并报错
      - 程序员需要手动打破循环（将共享功能提取到独立模块）
      - 示例：如果 `main.uya` 引用 `std.io`，`std.io` 引用 `main.helper`，编译器检测到循环并报错
- 所有模块引用都是显式的，需要通过 `use` 导入
- **导入后的使用方式**：
  - **导入整个模块**：`use main;` 或 `use std.io;`
    - 使用模块中的导出项时，需要加上模块名前缀：`main.helper_func()` 或 `std.io.read_file()`
    - 示例：
[examples/example.uya](./examples/example.uya)
  - **导入特定项**：`use main.helper_func;` 或 `use std.io.read_file;`
    - 导入后可以直接使用，无需模块名前缀
    - 示例：
[examples/example_1.uya](./examples/example_1.uya)
  - **导入结构体/接口**：`use std.io.File;` 或 `use std.io.IWriter;`
    - 导入后可以直接使用类型名，无需模块名前缀
    - 示例：
[examples/example_2.uya](./examples/example_2.uya)
  - **使用别名导入**：`use std.io as io;`
    - 使用别名时，需要用别名作为前缀
    - 示例：
[examples/example_3.uya](./examples/example_3.uya)
  - **混合使用**：可以同时导入整个模块和特定项
    - 示例：
[examples/example_4.uya](./examples/example_4.uya)

### 1.5.5 模块路径

- **路径基准**：所有模块路径相对于 **项目根目录**（包含 `main` 函数的目录）计算
- **根目录**：特殊模块名 `main`
  - 项目根目录是包含 `main` 函数的目录
  - 项目根目录下的文件 → `main` 模块
  - 示例：`use main.helper;` 或 `use main;`
- **子目录**：目录路径（相对于项目根目录）直接映射到模块路径（目录分隔符 `/` 转换为 `.`）
  - 项目根目录下的 `std/io/` → 模块路径 `std.io`
  - 项目根目录下的 `math/utils/` → 模块路径 `math.utils`
  - 使用：`use std.io;` 或 `use std.io.read_file;`
- 使用 `.` 分隔路径段
- **路径解析规则**：
  - 编译器在项目根目录中查找模块
  - 模块路径 `std.io` 对应项目根目录下的 `std/io/` 目录
  - 所有模块引用都相对于项目根目录解析

### 1.5.6 项目根目录说明

- **项目根目录识别**：模块系统的根目录是包含 `fn main() i32` 函数的目录
- **自动识别逻辑**：
  - 编译器扫描所有源文件，找到包含 `fn main() i32` 的文件
  - 该文件所在的最顶层目录即为项目根目录
  - 示例：如果 `project/src/main.uya` 包含 `fn main() i32`，则 `project/src/` 是项目根目录
- **限制**：不支持显式指定项目根目录（如通过 `-root` 编译选项），未来可能支持
- 所有模块路径都相对于项目根目录计算
- 编译器在项目根目录中查找和解析模块
- 项目根目录本身是 `main` 模块
- **路径解析**：
  - `use std.io;` 在项目根目录下查找 `std/io/` 目录
  - `use main.helper;` 在项目根目录下查找 `helper.uya` 文件
  - 所有模块引用都相对于项目根目录解析（绝对相对于项目根目录）
- **多入口项目说明**：
  - 如果项目中有多个 `fn main() i32`，编译器会报错，要求明确项目根目录
  - 测试/工具等应作为独立的子目录模块，不包含 `main` 函数
- **项目结构示例**：
[examples/example_008.txt](./examples/example_008.txt)

### 1.5.7 限制和说明

- **循环依赖处理**：
  - **允许子目录引用 main，但检测循环依赖**：
    - 允许 `use main.xxx;` 在子目录中使用
    - 编译器在编译期构建依赖图，检测强连通分量（循环依赖）
    - **循环依赖是编译错误，非运行时行为**：发现循环依赖时立即编译错误，要求程序员手动打破循环
    - 检测算法：构建有向图，使用 DFS 或 Tarjan 算法检测强连通分量
  - **打破循环的方法**：
    - 将共享功能提取到独立的子目录模块中（如 `common/`）
    - 所有模块都引用 `common` 模块，而不是相互引用
    - 示例：`main` 和 `std.io` 都引用 `common.helper`，而不是相互引用
- **模块可见性规则**：
  - **未 export 的项严格私有**：未标记 `export` 的项仅在模块内可见，其他模块无法访问
  - 所有模块引用都是显式的，需要通过 `use` 导入
- **模块初始化**：
  - **明确不支持模块初始化**（如 `init` 函数）
  - 所有模块解析在编译期完成
- **编译期解析规则**：
  - 所有模块路径在编译期解析
  - 模块依赖关系在编译期构建，用于循环依赖检测
- 与现有特性的兼容性
- 模块路径必须相对于项目根目录（包含 main 函数的目录）

### 1.5.8 完整示例

[examples/file.uya](./examples/file.uya)

---

## 2 类型系统

| Uya 类型        | 大小/对齐 | 备注                     |
|-----------------|-----------|--------------------------|
| `i8` `i16` `i32` `i64` | 1 2 4 8 B | 对齐 = 类型大小；支持 `max/min` 关键字访问极值 |
| `u8` `u16` `u32` `u64` | 1 2 4 8 B | 对齐 = 类型大小；无符号整数类型，用于与 C 互操作和格式化 |
| `usize`         | 4/8 B（平台相关） | 无符号大小类型，用于内存地址和大小；32位平台=4B，64位平台=8B |
| `f32` `f64`     | 4/8 B     | 对齐 = 类型大小          |
| `bool`          | 1 B       | 0/1，对齐 1 B            |
| `byte`          | 1 B       | 无符号字节，对齐 1 B，用于字节数组 |
| `void`          | 0 B       | 仅用于函数返回类型       |
| `*byte`         | 4/8 B（平台相关） | FFI 指针类型 `*T` 的一个实例（T=byte），用于 FFI 函数参数和返回值，指向 C 字符串；32位平台=4B，64位平台=8B；可与 `null` 比较（空指针）；FFI 指针类型 `*T` 支持所有 C 兼容类型（见第 5.2 章）|
| `&T`            | 8 B       | 无 lifetime 符号，见下方说明 |
| `&atomic T`  | 8 B       | 原子指针，关键字驱动，[见第 13 章](#13-原子操作012-终极简洁) |
| `atomic T`      | sizeof(T) | 语言级原子类型，[见第 13 章](#13-原子操作012-终极简洁) |
| `[T: N]`        | N·sizeof(T) | N 为编译期正整数，对齐 = T 的对齐 |
| `[[T: N]: M]`   | M·N·sizeof(T) | 多维数组，M 和 N 为编译期正整数，对齐 = T 的对齐 |
| `&[T]`          | 16 B       | 切片引用（动态长度），指针(8B) + 长度(8B) |
| `&[T: N]`       | 16 B       | 切片引用（编译期已知长度），指针(8B) + 长度(8B) |
| `struct S { }`  | 字段顺序布局 | 对齐 = 最大字段对齐，见下方说明 |
| `interface I { }` | 16 B (64位) | vtable 指针(8B) + 数据指针(8B)，[见第 6 章接口](#6-接口interface) |
| `fn(...) type` | 4/8 B（平台相关） | 函数指针类型，用于 FFI 回调，[见 5.2](#52-外部-c-函数ffi) |
| `enum E { }` | sizeof(底层类型) | 枚举类型，默认底层类型为 i32，见下方说明 |
| `(T1, T2, ...)` | 字段顺序布局 | 元组类型，见下方说明 |
| `!T`            | 错误联合类型  | max(sizeof(T), sizeof(错误标记)) + 对齐填充 | `T | Error`，见下方说明 |

- 无隐式转换；支持安全指针算术（见第 18 章）；无 lifetime 符号。

**多维数组类型说明**：
- **声明语法**：`[[T: N]: M]` 表示 M 行 N 列的二维数组，类型为 `T`
  - `T` 是元素类型（如 `i32`, `f32` 等）
  - `N` 是列数（内层维度），必须是编译期正整数
  - `M` 是行数（外层维度），必须是编译期正整数
  - 更高维度的数组可以继续嵌套：`[[[T: N]: M]: K]` 表示三维数组
- **内存布局**：多维数组在内存中按行优先顺序存储（row-major order）
  - 二维数组 `[[T: N]: M]` 的内存布局：`[row0_col0, row0_col1, ..., row0_colN-1, row1_col0, ..., rowM-1_colN-1]`
  - 大小计算：`M * N * sizeof(T)` 字节
  - 对齐规则：对齐值 = `T` 的对齐值
- **访问语法**：使用多个索引访问多维数组元素
  - 二维数组：`arr[i][j]` 访问第 i 行第 j 列的元素
  - 三维数组：`arr[i][j][k]` 访问第 i 层第 j 行第 k 列的元素
- **边界检查**：所有维度的索引都需要编译期证明安全
  - 对于 `arr[i][j]`，必须证明 `i >= 0 && i < M && j >= 0 && j < N`
  - 常量错误 → 编译错误；变量证明超时 → 自动插入运行时检查
- **示例**：
[examples/example_010.uya](./examples/example_010.uya)

**类型相关的极值常量**：
- 整数类型（`i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`）支持通过 `max` 和 `min` 关键字访问极值
- 语法：`max` 和 `min`（编译器从上下文类型推断）
- 编译器根据上下文类型自动推断极值类型，这些是编译期常量
- 示例：
[examples/example_011.uya](./examples/example_011.uya)

**指针类型说明**：
- `*byte`：FFI 指针类型 `*T` 的一个实例（T=byte），专门用于 FFI，表示 C 字符串指针（null 终止），只能用于：
  - FFI 函数参数和返回值类型声明
  - 与 `null` 比较（空指针检查）
  - 字符串字面量在 FFI 调用时自动转换为 `*byte`
  - 不支持将 `*byte` 赋值给变量或进行其他操作
- **FFI 指针类型 `*T`**：支持所有 C 兼容类型，包括：
  - 整数类型：`*i8`, `*i16`, `*i32`, `*i64`, `*u8`, `*u16`, `*u32`, `*u64`
  - 浮点类型：`*f32`, `*f64`
  - 特殊类型：`*bool`, `*byte`（C 字符串），`*void`（通用指针）
  - C 结构体：`*CStruct`（指向外部 C 结构体的指针）
  - **使用规则**：
    - ✅ 仅用于 FFI 函数声明/调用和 extern struct 字段
    - ✅ 支持下标访问 `ptr[i]`（展开为 `*(ptr + i)`），但必须提供长度约束证明
    - ❌ 不能用于普通变量声明（编译错误）
    - ❌ 不能进行普通指针算术（只能用于 FFI 上下文）
  - 详见 [第 5.2 章](#52-外部-c-函数ffi) 和 [第 5.3 章](#53-外部-c-结构体ffi)
- `&T`：普通指针类型，8 字节（64位平台），无 lifetime 符号
  - 用于指向类型 `T` 的值
  - 空指针检查：`if ptr == null { ... }`（需要显式检查，编译期证明超时则自动插入运行时检查）
  - 支持安全指针算术（见第 18 章）
- `&atomic T`：原子指针类型，8 字节，关键字驱动
  - 用于指向原子类型 `atomic T` 的指针
  - [见第 13 章原子操作](#13-原子操作012-终极简洁)
- `*T`：用于方法签名和 FFI 函数声明，表示指针参数，不能用于普通变量声明
  - **语法规则**：
    - `*T` 语法在以下场景中使用：
      - 接口定义和结构体方法的方法签名
      - FFI 函数声明（如 `extern printf(fmt: *byte, ...) i32;`）
    - `*T` 表示指向类型 `T` 的指针参数（按引用传递，但语法使用 `*` 前缀）
    - 与 `&T` 的区别：`&T` 用于普通变量和普通函数参数，`*T` 用于方法签名和 FFI 函数声明
  - **示例**：
    - 接口方法：`fn write(self: *Self, buf: *byte, len: i32)` 中，`*Self` 表示指向实现接口的结构体类型的指针
    - 结构体方法：`fn distance(self: *Self) f32` 中，`*Self` 表示指向当前结构体类型的指针
    - `*byte` 表示指向 `byte` 类型的指针参数
    - `Self` 是占位符，编译期替换为具体类型
  - **FFI 调用规则**：接口方法内部调用 FFI 函数时，参数类型应使用 `*byte`（FFI 语法），与接口语法一致
  - 仅支持 `*T` 语法（不支持 `T*`）
  - 接口方法调用时，`self` 参数自动传递（无需显式传递）

**错误类型和错误联合类型**：

> **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#9-错误处理)

- **错误类型定义**：使用 `error.ErrorName` 语法，支持预定义和运行时错误
  - **预定义错误**（可选）：使用 `error ErrorName;` 定义
    - 错误类型可在**顶层**（文件级别，与函数、结构体定义同级）预定义
    - 预定义错误类型是编译期常量，用于标识不同的错误情况
    - 预定义错误类型名称必须唯一（全局命名空间）
    - 预定义错误类型属于全局命名空间，使用点号（`.`）访问：`error.ErrorName`
    - 预定义错误定义示例：`error DivisionByZero;`、`error FileNotFound;`
    - 预定义错误使用示例：`return error.DivisionByZero;`、`return error.FileNotFound;`
  - **运行时错误**（新增）：使用 `error.ErrorName` 语法直接创建错误，无需预定义
    - 语法：`return error.ErrorMessage;`
    - 错误名称在使用时自动创建，无需预先声明
    - 编译器在编译期收集所有使用的错误名称，生成错误类型
    - 支持任意错误名称，无需预先定义
    - 示例：`return error.FileNotFound;`、`return error.OutOfMemory;`、`return error.InvalidInput;`
  - **错误名称规则**：
    - 错误名称遵循标识符规则：`[A-Za-z_][A-Za-z0-9_]*`
    - 错误名称区分大小写
    - 同一文件中，相同错误名称指向同一错误类型
    - 不同文件中的相同错误名称是不同的错误类型（除非通过接口传递）
  - **错误类型推断**：
    - 函数返回 `!T` 类型时，所有可能的错误类型自动推断
    - 编译器自动推断函数可能返回的所有错误
    - 无需显式声明函数可能返回的错误集合

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

**枚举类型说明**：

- **语法**：`enum EnumName { Variant1, Variant2, ... }` 或 `enum EnumName : UnderlyingType { Variant1 = value1, Variant2 = value2, ... }`
- **默认底层类型**：`i32`（如果未指定）
- **显式赋值**：支持为枚举变体显式指定值
- **底层类型指定**：支持指定底层整数类型（`u8`, `u16`, `u32`, `i8`, `i16`, `i32`, `i64` 等）
- **内存布局**：与 C 枚举完全兼容，大小和对齐由底层类型决定
- **类型安全**：编译期类型检查，枚举值只能与相同枚举类型比较
- **与 match 集成**：支持在 match 表达式中匹配枚举，支持穷尽性检查（必须处理所有变体或使用 else 分支）
- **示例**：
```uya
enum Color { RED, GREEN, BLUE }
enum HttpStatus {
    OK = 200,
    NOT_FOUND = 404,
    SERVER_ERROR = 500
}
enum SmallEnum : u8 { A = 1, B = 2 }
```

**元组类型说明**：

- **语法**：`(T1, T2, ..., Tn)`，其中 `Ti` 是类型
- **类型别名**：支持使用 `type` 关键字定义元组类型别名，如 `type Point = (i32, i32);`
- **字面量语法**：`(value1, value2, ...)`
- **字段访问**：使用 `.0`, `.1`, `.2` 等索引访问元组字段（从 0 开始）
- **编译期边界检查**：访问越界立即编译错误（如 `tuple.5` 访问只有 3 个元素的元组）
- **内存布局**：字段按顺序存储，对齐规则与结构体相同（对齐 = 最大字段对齐值）
- **解构赋值**：支持元组解构，如 `const (x, y) = point;` 或 `const (x, _, z) = get_tuple();`
- **独立类型系统**：元组是一级类型，非语法糖，有明确的类型语义和错误信息
- **示例**：
```uya
type Point = (i32, i32);
const p: (i32, i32) = (10, 20);
const x = p.0;  // 访问第一个元素
const y = p.1;  // 访问第二个元素
```

---

## 3 变量与作用域

[examples/variables_scope.uya](./examples/variables_scope.uya)

- 初始化表达式类型必须与声明完全一致。
- `const` 声明的变量**不可变**；使用 `var` 声明可变变量。
- 可变变量可重新赋值；不可变变量赋值会编译错误。
- **常量变量**：使用 `const NAME: Type = value;` 声明编译期常量
  - 常量必须在编译期求值
  - 常量可在编译期常量表达式中使用（如数组大小 `[T; SIZE]`）
  - 常量不可重新赋值
  - `const` 常量可以在顶层或函数内声明
  - `const` 常量可以作为数组大小：`const N: i32 = 10; const arr: [i32: N] = ...;`
- **编译期常量表达式**：
  - 字面量：整数、浮点、布尔、字符串
  - 常量变量：`const NAME`
  - 算术运算：`+`, `-`, `*`, `/`, `%`（如果操作数都是常量）
  - 位运算：`&`, `|`, `^`, `~`, `<<`, `>>`（如果操作数都是常量）
  - 比较运算：`==`, `!=`, `<`, `>`, `<=`, `>=`（如果操作数都是常量）
  - 逻辑运算：`&&`, `||`, `!`（如果操作数都是常量）
  - 不支持：函数调用、变量引用（非常量）、数组/结构体字面量
- **类型推断**：不支持类型推断，所有变量必须显式类型注解
- **变量遮蔽**：
  - 同一作用域内不能有同名变量
  - **禁止变量遮蔽**：内层作用域不能声明与外层作用域同名的变量（编译错误）
  - 所有作用域内的变量名必须唯一，不能遮蔽外层作用域的变量
- **忽略标识符 `_`**：特殊语法标记，用于显式忽略值
  - `_` 不是普通标识符，不能引用或赋值
  - **显式忽略返回值**：`_ = process_data();` 强制显式忽略返回值（编译期检查）
  - **解构忽略**：`const (x, _, z) = get_tuple();` 在元组解构中忽略中间元素
  - **模式匹配忽略**：在 match 表达式中使用 `_` 作为通配符忽略值，如 `match result { (200, _, body) => process(body), _ => handle_default() }`
  - **可重复使用**：`_` 可以在同一作用域内多次使用，不会冲突
  - **禁止作为变量名**：不能将 `_` 用作普通变量名（编译错误）
  - **示例**：
```uya
_ = process_data()                    // 显式忽略返回值
const (x, _, z) = get_tuple()         // 解构忽略中间元素
match result {
    (200, _, body) => process(body),  // 模式匹配忽略
    _ => handle_default()             // 通配忽略
}
```
- 作用域 = 最近 `{ }`；离开作用域按字段逆序调用 `drop(T)`（RAII）。

---

## 4 结构体

[examples/vec3.uya](./examples/vec3.uya)

- **统一标准**：所有 `struct` 统一使用 C 内存布局，无需 `extern` 关键字
- **支持所有类型**：结构体可以包含所有类型（包括切片、interface、错误联合类型等）
- 内存布局与 C 相同，字段顺序保留。
- **C 兼容性**：所有结构体都可以直接与 C 代码互操作，编译器自动生成对应的 C 兼容布局
- **完整 Uya 能力**：所有结构体都可以有方法、drop（RAII）、实现接口，同时保持 100% C 兼容性
  - ✅ 可以有方法（结构体内部或外部定义）
  - ✅ 可以有 drop 函数（实现 RAII 自动资源管理）
  - ✅ 可以实现接口（支持动态派发）
  - ✅ C 代码看到：纯数据，标准布局，100% C 兼容
  - ✅ Uya 代码看到：完整对象，有方法、接口、RAII，100% Uya 能力
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
- **字段类型支持**：
  - 基础类型：`i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`, `f32`, `f64`, `bool`, `byte`, `usize`
  - 数组类型：`[T: N]`（固定大小数组）
  - 切片类型：`&[T]` 或 `&[T: N]`（在 C 中表示为 `{ void* ptr; size_t len; }`）
  - 接口类型：`InterfaceName`（在 C 中表示为 `{ void* vtable; void* data; }`）
  - 指针类型：`&T`（在 C 中表示为 `T*`）
  - 错误联合类型：`!T`（在 C 中表示为带标记的联合体）
  - 原子类型：`atomic T`（在 C 中表示为 `_Atomic T`）
  - 嵌套结构体：其他结构体类型
- **结构体字面量语法**：`TypeName{ field1: value1, field2: value2, ... }`
  - 字段名必须与结构体定义中的字段名完全匹配
  - 字段顺序可以任意（语法允许），但为了可读性和一致性，**强烈建议按定义顺序**
- 支持字段访问 `v.x`、数组元素 `arr[i]`（i 必须为 `i32`）。
- 支持嵌套访问：`struct_var.field.subfield`、`struct_var.array_field[index]`（访问链从左到右求值）
- **多维数组字段**：结构体字段可以是多维数组
  - 声明示例：`struct Matrix { data: [[f32: 4]: 4] }`（4x4 矩阵）
  - 访问语法：`struct_var.array_field[i][j]`（如果字段是多维数组）
  - 所有维度的索引都需要边界检查证明
  - 示例：
[examples/mat3x4.uya](./examples/mat3x4.uya)
- 访问链可以任意嵌套：`struct_var.field1.array_field[i].subfield`
- **数组边界检查**（适用于所有数组访问）：强制编译期证明
  - 常量索引越界 → **编译错误**
  - 变量索引 → 必须证明 `i >= 0 && i < len`，证明超时 → **自动插入运行时检查**
  - 编译期证明安全（在当前函数内），证明超时则自动插入运行时检查
- **切片语法**：支持切片语法 `&arr[start:len]`
  - **操作符语法**：`&arr[start:len]` 返回从索引 `start` 开始，长度为 `len` 的切片视图（引用）
  - **负数索引**：支持负数索引，`-1` 表示最后一个元素，`-n` 表示倒数第 n 个元素
    - 例如：`&arr[-3:3]` 表示从倒数第3个元素开始，长度为3的切片
    - 例如：`&arr[-5:2]` 表示从倒数第5个元素开始，长度为2的切片
  - **切片边界检查**：编译期或运行时证明 `start >= -len(arr) && start < len(arr) && len >= 0 && start + len <= len(arr)`
    - 如果使用负数索引，编译器会自动转换为正数索引：`-n` 转换为 `len(arr) - n`
    - 例如：`&arr[-3:3]` 对于长度为10的数组，-3转换为7，验证 `7 >= 0 && 7 < 10 && 3 >= 0 && 7 + 3 <= 10`
  - **切片结果类型**：
    - 动态长度切片：`&arr[start:len]` 返回 `&[T]`（切片引用，动态长度）
    - 已知长度切片：如果 `len` 是编译期常量，可以显式指定为 `&[T: N]`（已知长度切片引用）
    - 示例：`const slice: &[i32] = &arr[2:5];`（动态长度）
    - 示例：`const exact_slice: &[i32: 3] = &arr[2:3];`（已知长度）
  - **切片语义**：切片是原数据的视图，修改原数组会影响切片，切片不拥有数据
  - 切片是胖指针（指针+长度），无堆分配，编译期验证安全，运行时直接访问内存
- **字段可变性**：只有 `var` 结构体变量才能修改其字段
  - `const s: S = ...` 时，`s.field = value` 会编译错误
  - `var s: S = ...` 时，可以修改 `s.field`
  - 字段可变性由外层变量决定，不支持字段级可变性标记
  - **嵌套结构体示例**：
[examples/inner.uya](./examples/inner.uya)
- **结构体初始化**：必须提供所有字段的值，不支持部分初始化或默认值

### 4.1 C 内存布局说明

所有结构体遵循 C 标准内存布局，可以直接与 C 代码互操作：

**基础类型布局**：
- 与 C 标准类型完全一致（`int`, `float`, `double`, `char` 等）
- 对齐规则遵循 C11 `_Alignas` 语义

**切片类型 `&[T]` 在 C 中的表示**：
```c
struct slice {
    void* ptr;    // 8 bytes (64位) 或 4 bytes (32位)
    size_t len;   // 8 bytes (64位) 或 4 bytes (32位)
};
```
- 总大小：16 bytes (64位) 或 8 bytes (32位)
- 对齐：8 bytes (64位) 或 4 bytes (32位)

**接口类型 `InterfaceName` 在 C 中的表示**：
```c
struct interface {
    void* vtable;  // 8 bytes (64位) 或 4 bytes (32位)
    void* data;    // 8 bytes (64位) 或 4 bytes (32位)
};
```
- 总大小：16 bytes (64位) 或 8 bytes (32位)
- 对齐：8 bytes (64位) 或 4 bytes (32位)

**错误联合类型 `!T` 在 C 中的表示**：
```c
// 错误联合类型的通用定义
struct error_union_T {
    uint32_t error_id; // 错误码：0 = 成功（使用 value），非0 = 错误（使用 error_id）
    T value;           // 成功时的值类型
};
```

**语义说明**：
- `error_id == 0`：表示成功，使用 `value` 字段
- `error_id != 0`：表示错误，`error_id` 包含错误类型标识符，`value` 字段未定义

**具体示例**：

`!i32` 在 C 中的表示：
```c
struct error_union_i32 {
    uint32_t error_id; // 0 = 成功，非0 = 错误类型标识符
    int32_t value;     // 成功时：i32 值
};
```

`!void` 在 C 中的表示：
```c
struct error_union_void {
    uint32_t error_id; // 0 = 成功，非0 = 错误类型标识符
    // void 类型无需 value 字段
};
```

`!Point`（结构体类型）在 C 中的表示：
```c
struct error_union_Point {
    uint32_t error_id;      // 0 = 成功，非0 = 错误类型标识符
    struct Point value;      // 成功时：Point 结构体
};
```

**大小和对齐规则**：
- 大小：`sizeof(uint32_t) + sizeof(T) + 对齐填充`
- 对齐：`max(alignof(uint32_t), alignof(T))`
- 错误码（`error_id`）为 32 位无符号整数，用于标识错误类型
- `error_id == 0` 表示成功，非零值表示不同的错误类型

**使用示例**：
```c
// C 代码中使用错误联合类型
struct error_union_i32 result = some_function();
if (result.error_id == 0) {
    // 成功：使用 result.value
    int32_t value = result.value;
} else {
    // 错误：使用 result.error_id
    uint32_t error = result.error_id;
}
```

**示例：包含切片、接口和错误联合类型的结构体**：
```uya
struct Container {
    id: i32,
    data: &[i32],           // 切片字段
    writer: IWriter,        // 接口字段
    result: !i32,           // 错误联合类型字段
    count: usize
}
```

对应的 C 结构体：
```c
struct Container {
    int32_t id;
    struct {
        void* ptr;
        size_t len;
    } data;                 // 切片在 C 中的表示
    struct {
        void* vtable;
        void* data;
    } writer;              // 接口在 C 中的表示
    struct {
        uint32_t error_id; // 0 = 成功，非0 = 错误类型标识符
        int32_t value;     // 成功时：i32 值
    } result;              // 错误联合类型在 C 中的表示
    size_t count;
};
```

**与 C 互操作**：
- 所有 Uya 结构体可以直接传递给 C 函数
- C 结构体可以直接在 Uya 中使用（无需 `extern` 关键字）
- 编译器自动处理布局转换，确保 100% C 兼容性

**完整 Uya 能力**：
所有结构体（包括与 C 互操作的结构体）都可以有方法、drop（RAII）、实现接口，同时保持 100% C 兼容性：

```uya
// 结构体定义（C 兼容布局）
struct File {
    fd: i32
}

// ✅ 可以有方法（结构体内部定义）
struct File {
    fd: i32,
    fn read(self: *Self, buf: *byte, len: i32) !i32 {
        extern read(fd: i32, buf: *void, count: i32) i32;
        const result: i32 = read(self.fd, buf, len);
        if result < 0 {
            return error.ReadFailed;
        }
        return result;
    }
}

// ✅ 可以有方法（结构体外部定义）
File {
    fn write(self: *Self, buf: *byte, len: i32) !i32 {
        extern write(fd: i32, buf: *void, count: i32) i32;
        const result: i32 = write(self.fd, buf, len);
        if result < 0 {
            return error.WriteFailed;
        }
        return result;
    }
}

// ✅ 可以有 drop（RAII 自动资源管理）
fn drop(self: File) void {
    extern close(fd: i32) i32;
    close(self.fd);
}

// ✅ 可以实现接口（在结构体定义时声明接口）
interface IReadable {
    fn read(self: *Self, buf: *byte, len: i32) !i32;
}

struct File : IReadable {
    fd: i32,
    fn read(self: *Self, buf: *byte, len: i32) !i32 {
        extern read(fd: i32, buf: *void, count: i32) i32;
        const result: i32 = read(self.fd, buf, len);
        if result < 0 {
            return error.ReadFailed;
        }
        return result;
    }
}

// 使用示例
fn example() !void {
    extern open(path: *byte, flags: i32) i32;
    const file: File = File{ fd: open("test.txt", 0) };
    
    // 使用结构体方法
    const bytes: i32 = try file.read(&buffer[0], 100);
    
    // 实现接口，支持动态派发
    const reader: IReadable = file;
    const bytes2: i32 = try reader.read(&buffer[0], 100);
    
    // 离开作用域时自动调用 drop，关闭文件（RAII）
}
```

**核心特性**：同一个结构体，两面性：
- **C 代码看到**：纯数据，标准布局，100% C 兼容
- **Uya 代码看到**：完整对象，有方法、接口、RAII，100% Uya 能力

---

## 5 函数

### 5.1 普通函数

[examples/add.uya](./examples/add.uya)

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
- **返回值证明规则**：
  - **函数内部**：编译器可以证明返回值的安全性（在 `return` 语句之前）
  - **调用者**：编译器不能自动证明函数返回值的安全性，必须显式处理
  - 返回值是指针时，调用者需要显式检查（如 `if ptr == null { return error; }`）
  - 返回值是错误联合类型时，必须使用 `try` 或 `catch` 处理
  - 返回值用于数组索引时，调用者需要显式检查边界
  - 示例：`const result: i32 = try divide(10, 2);` 显式处理可能的错误
  - 示例：`const ptr: &i32 = get_pointer(); if ptr == null { return error; }` 显式检查空指针
- **递归函数**：支持递归函数调用（函数可以调用自身），递归深度受栈大小限制
- **函数前向引用**：函数可以在定义之前调用（编译器多遍扫描）
- **函数指针**：支持函数指针类型（语法：`fn(param_types) return_type`），用于 FFI 回调场景
  - 可以使用 `&function_name` 获取导出函数的函数指针
  - 支持类型别名：`type ComparFunc = fn(*void, *void) i32;`
  - 详见 [5.2 外部 C 函数（FFI）](#52-外部-c-函数ffi)
- **变参函数调用**：参数数量必须与 C 函数声明匹配（编译期检查有限）
- **程序入口点**：必须定义 `fn main() i32` 或 `fn main() !i32`（程序退出码）
  - 不支持命令行参数（未来支持 `main(argc: i32, argv: *byte)`）
  - 详见 [5.1.1 main函数签名](#511-main函数签名)
- **`return` 语句**：
  - `return expr;` 用于有返回值的函数
  - `return;` 用于 `void` 函数（可省略）
  - `return error.ErrorName;` 用于返回错误（错误联合类型函数）
  - `return` 语句后的代码不可达
  - 函数末尾的 `return` 可以省略（如果返回类型是 `void`）

#### 5.1.1 main函数签名

Uya支持两种`main`函数签名：

1. **简单签名**：`fn main() i32`
   - 用于简单程序，无错误处理需求
   - 不能使用`try`关键字（编译错误）
   - 必须使用`catch`处理所有可能的错误

2. **完整签名**：`fn main() !i32`（推荐）
   - 用于需要错误处理的程序
   - 可以使用`try`关键字传播错误
   - 程序成功时返回0，错误时返回非0退出码
   - 编译器自动处理错误到退出码的转换

**推荐使用`fn main() !i32`**，以符合Uya的"显式控制"和"编译期证明"哲学。

- **切片参数**：函数可以直接接受切片类型作为参数
  - **语法**：`fn func_name(param: &[T]) ReturnType` 或 `fn func_name(param: &[T: N]) ReturnType`
  - **切片类型**：
    - `&[T]`：动态长度切片引用（胖指针：指针8B + 长度8B）
    - `&[T: N]`：已知长度切片引用（胖指针：指针8B + 长度8B，N 为编译期常量）
  - **函数体内访问**：
    - `param[i]` 访问切片元素（需要边界检查证明）
    - `len(param)` 获取切片长度（对于 `&[T]`）或使用编译期常量 `N`（对于 `&[T: N]`）
  - **调用方式**：直接传递切片 `&arr[start:len]` 或 `&arr[start:N]`
  - 切片是胖指针，直接传递，无额外包装
  - **示例**：
[examples/process.uya](./examples/process.uya)

- **`try` 关键字**：
  - `try expr` 用于传播错误和溢出检查
  - **错误传播**：如果 `expr` 返回错误，当前函数立即返回该错误
  - **溢出检查**：如果 `expr` 是算术运算（`+`, `-`, `*`, `/`），自动检查溢出，溢出时返回 `error.Overflow`
  - 如果 `expr` 返回值，继续执行
  - **只能在返回错误联合类型的函数中使用**，且 `expr` 必须是返回错误联合类型的表达式或算术运算
  - **可能抛出的错误类型**：
    - **错误传播模式**：`try expr` 可能抛出 `expr` 返回的所有错误类型
      - 例如：`try divide(10, 2)` 可能抛出 `divide` 函数返回的所有错误（如 `error.DivisionByZero`）
    - **溢出检查模式**：`try a + b`、`try a - b`、`try a * b`、`try a / b` 可能抛出 `error.Overflow`
      - 加法溢出：`try a + b` 在 `a + b` 超出类型范围时返回 `error.Overflow`
      - 减法溢出：`try a - b` 在 `a - b` 超出类型范围时返回 `error.Overflow`
      - 乘法溢出：`try a * b` 在 `a * b` 超出类型范围时返回 `error.Overflow`
      - 除法溢出：`try a / b` 在 `a / b` 超出类型范围时返回 `error.Overflow`（如 `min / -1`）
  - **错误传播示例**：`const result: i32 = try divide(10, 2);`（`divide` 必须返回 `!i32`，可能抛出 `error.DivisionByZero` 等）
  - **溢出检查示例**：
    - `const result: i32 = try a + b;`（自动检查 `a + b` 是否溢出，可能抛出 `error.Overflow`）
    - `const result: i32 = try a - b;`（自动检查 `a - b` 是否溢出，可能抛出 `error.Overflow`）
    - `const result: i32 = try a * b;`（自动检查 `a * b` 是否溢出，可能抛出 `error.Overflow`）
    - `const result: i32 = try a / b;`（自动检查 `a / b` 是否溢出，可能抛出 `error.Overflow`）

- **`catch` 语法**：
  - `expr catch |err| { statements }` 用于捕获并处理错误
  - `expr catch { statements }` 用于捕获所有错误（不绑定错误变量）
  - 如果 `expr` 返回错误，执行 catch 块
  - 如果 `expr` 返回值，跳过 catch 块
  - **类型规则**：`catch` 表达式的类型是 `expr` 成功时的值类型（不是错误联合类型）
    - `expr catch { default_value }` 的类型 = `expr` 的值类型
    - `catch` 块必须返回与 `expr` 成功值类型相同的值
    - **重要限制**：`catch` 块**不能返回错误联合类型**，只能返回值类型或使用 `return` 提前返回函数
  - **catch 块的返回方式**（两种方式，语义不同）：
    
    **方式 1：表达式返回值**（catch 块返回一个值给 catch 表达式）
    - catch 块的最后一条表达式作为返回值（不需要 `return` 关键字）
    - 这个值会成为整个 `catch` 表达式的值
    - 示例：
[examples/example_018.uya](./examples/example_018.uya)
    
    **方式 2：使用 `return` 提前返回函数**（catch 块直接退出函数）
    - catch 块中使用 `return` 会**立即返回函数**（不是返回 catch 块的值）
    - 跳过后续所有 defer 和 drop
    - 示例：
[examples/main.uya](./examples/main.uya)
    
    **重要区别**：
    - 表达式返回值：catch 块返回一个值，程序继续执行
    - `return` 语句：catch 块直接退出函数，程序不继续执行
- **错误处理**：
  - 支持**错误联合类型** `!T` 和 **try/catch** 语法，用于函数错误返回
  - 函数可以返回错误联合类型：`fn foo() !i32` 表示返回 `i32` 或 `Error`
  - 使用 `try` 关键字传播错误：`const result: i32 = try divide(10, 2);`
  - 使用 `catch` 语法捕获错误：`const result: i32 = divide(10, 0) catch |err| { ... };`
  - **无运行时 panic 路径**：所有 UB 必须被编译期证明为安全，失败即编译错误
  - **灵活错误定义**：支持预定义错误（`error ErrorName;`）和运行时错误（`error.ErrorName`），无需预先声明
- **错误类型的操作**：
  - 错误类型支持相等性比较：`if err == error.FileNotFound { ... }` 或 `if err == error.SomeRuntimeError { ... }`
  - 错误类型不支持不等性比较（仅支持 `==`）
  - catch 块中可以判断错误类型并做不同处理
  - 错误类型不能直接打印，需要通过模式匹配处理
  - 支持预定义错误和运行时错误的混合比较：`if err == error.PredefinedError || err == error.RuntimeError { ... }`
  
**错误处理设计哲学**：
- **编译期检查**：错误处理是编译期检查，编译器在当前函数内验证错误处理
- **显式错误**：错误是类型系统的一部分，必须显式处理
- **编译期检查**：编译器确保所有错误都被处理
- **无 panic、无断言**：所有 UB 必须被编译期证明为安全，失败即编译错误

**错误处理与内存安全的关系**：
- **`try`/`catch` 只用于函数错误返回**，不用于捕获 UB
- **所有 UB 必须被编译期证明为安全**，失败即编译错误，不生成代码
- 错误处理用于处理可预测的、显式的错误情况（如文件不存在、网络错误等）

**示例：错误处理**：
[examples/safe_divide.uya](./examples/safe_divide.uya)

### 5.2 外部 C 函数（FFI）

**步骤 1：顶层声明**  
[examples/extern_c_function.uya](./examples/extern_c_function.uya)

**步骤 2：正常调用**  
[examples/extern_c_function_1.uya](./examples/extern_c_function_1.uya)

#### 5.2.1 导入 C 函数（声明外部函数）

- 语法：`extern fn name(...) type;`（分号结尾，无函数体）
- 用于声明外部 C 函数，供 Uya 代码调用

**重要语法规则**：
- extern 函数声明必须使用 Uya 的函数参数语法：`param_name: type`
- **FFI 指针类型 `*T`**：支持所有 C 兼容类型
  - 整数类型：`*i8`, `*i16`, `*i32`, `*i64`, `*u8`, `*u16`, `*u32`, `*u64`
  - 浮点类型：`*f32`, `*f64`
  - 特殊类型：`*bool`, `*byte`（C 字符串），`*void`（通用指针）
  - C 结构体：`*CStruct`（指向外部 C 结构体的指针）
- 指针类型参数使用 `*T` 语法（如 `*byte` 表示指向 `byte` 的指针，`*u16` 表示指向 `u16` 的指针）
- **返回值类型**：返回值类型放在参数列表的 `)` 后面，遵循 Uya 的函数语法
  - 指针类型返回值使用 `*T` 语法（如 `*void` 表示指向 `void` 的指针，对应 C 的 `void*`）
  - 示例：`extern malloc(size: i32) *void;`（返回 `void*` 指针）
  - 示例：`extern printf(fmt: *byte, ...) i32;`（返回 `i32`）
  - 也支持箭头语法：`extern malloc(size: i32) -> *void;`
- 变参函数使用 `...` 表示可变参数列表

- 声明必须出现在**顶层**；不可与调用混写在一行。
- 调用生成原生 `call rel32` 或 `call *rax`，**无包装函数**。
- 返回后按 C 调用约定清理参数。
- **调用约定**：与目标平台的 C 调用约定一致（如 x86-64 System V ABI 或 Microsoft x64 calling convention），具体由后端实现决定

#### 5.2.2 导出函数给 C（导出函数）

- 语法：`extern fn name(...) type { ... }`（花括号包含函数体）
- 用于将 Uya 函数导出为 C 函数，供 C 代码调用
- 导出的函数可以使用 `&name` 获取函数指针，传递给需要函数指针的 C 函数
- 函数参数和返回值必须使用 C 兼容的类型

**示例**：
```uya
// 导出函数给 C
extern fn compare(a: *void, b: *void) i32 {
    const val_a: i32 = *(a as *i32);
    const val_b: i32 = *(b as *i32);
    if val_a < val_b { return -1; }
    if val_a > val_b { return 1; }
    return 0;
}

// 使用函数指针类型别名
type ComparFunc = fn(*void, *void) i32;

// 声明需要函数指针的 C 函数
extern qsort(base: *void, nmemb: usize, size: usize, compar: ComparFunc) void;

fn main() i32 {
    const arr: [i32: 5] = [5, 2, 8, 1, 9];
    
    // 使用 &compare 获取函数指针并传递给 C 函数
    qsort(&arr[0], 5, 4, &compare);
    
    return 0;
}
```

**函数指针类型**：
- 语法：`fn(param_types) return_type`
- 支持类型别名：`type FuncAlias = fn(...) type;`
- `&function_name` 的类型是函数指针类型（不是 `*void`）
- 仅在 FFI 上下文中使用，用于与 C 函数指针互操作

**FFI 指针使用示例**：

[examples/safe_access_1.uya](./examples/safe_access_1.uya)

**FFI 指针使用规则**：
- ✅ 仅用于 FFI 函数声明/调用和 extern struct 字段
- ✅ 支持下标访问 `ptr[i]`（展开为 `*(ptr + i)`），但必须提供长度约束证明
- ❌ 不能用于普通变量声明（编译错误）
- ❌ 不能进行普通指针算术（只能用于 FFI 上下文）

**禁止用法示例**：
[examples/safe_example.uya](./examples/safe_example.uya)

**统一指针语法的完整规则**：

1. **普通指针** `&T`：Uya 内部安全指针
   - **用途**：Uya 内部安全指针
   - **支持**：所有 Uya 类型
   - **边界检查**：必须编译期证明
   - **示例**：`&i32`, `&f64`, `&MyStruct`

2. **FFI 指针** `*T`：仅用于 C 语言互操作
   - **用途**：仅用于 C 语言互操作
   - **支持**：所有 C 兼容类型（`*i8`, `*i16`, `*i32`, `*i64`, `*u8`, `*u16`, `*u32`, `*u64`, `*f32`, `*f64`, `*bool`, `*byte`, `*void`, `*CStruct`）
   - **特殊规则**：
     - ✅ 支持下标访问 `ptr[i]`（展开为 `*(ptr + i)`）
     - ✅ **必须**提供长度约束证明
     - ❌ 不能用于普通变量声明（编译错误）
     - ❌ 不能进行普通指针算术（只能用于 FFI 上下文）

3. **切片类型** `&[T]` 和 `&[T: N]`：切片引用类型
   - **用途**：表示数组的切片视图（指针+长度的组合）
   - **类型**：
     - `&[T]`：动态长度切片引用（胖指针：指针8B + 长度8B）
     - `&[T: N]`：已知长度切片引用（胖指针：指针8B + 长度8B，N 为编译期常量）
   - **创建方式**：使用切片语法 `&arr[start:len]` 或 `&arr[start:N]`
   - **内部访问**：`buf[i]` 访问切片元素（需要边界检查证明），`len(buf)` 获取长度
   - 切片是胖指针，直接传递，无额外包装

**设计哲学一致性**：

FFI 指针设计符合"坚如磐石"哲学：
1. **显式区分**：`&T`（安全内部）vs `*T`（FFI 专用）
2. **安全强化**：FFI 指针下标访问**必须**长度约束证明
3. **编译期验证**：所有边界检查在编译期完成
4. **零隐式转换**：两种指针类型不能混用
5. **C 兼容性**：支持所有 C 语言指针类型

**重要说明**：
- FFI 函数调用的格式字符串（如 `printf` 的 `"%f"`）是 C 函数的特性，不是 Uya 语言本身的特性
- Uya 语言仅提供 FFI 机制来调用 C 函数，格式字符串的语法和语义遵循 C 标准
- 字符串插值（第 17 章）是 Uya 语言本身的特性，编译期展开，与 FFI 的格式字符串不同

### 5.3 与 C 结构体互操作

**统一标准**：
- 所有 Uya `struct` 统一使用 C 内存布局，无需 `extern` 关键字
- 所有结构体都可以直接与 C 代码互操作
- 支持所有类型（包括切片、interface、错误联合类型等）

**使用 C 结构体**：
- 可以直接在 Uya 中使用 C 结构体，无需特殊声明
- 编译器自动识别 C 结构体布局，确保 100% 兼容性

**示例**：
```uya
// Uya 结构体，可以直接传递给 C 函数
struct Point {
    x: f32,
    y: f32
}

// C 函数声明
extern draw_point(p: *Point) void;

fn main() i32 {
    const p: Point = Point{ x: 1.0, y: 2.0 };
    draw_point(&p);  // 直接传递，编译器自动处理布局
    return 0;
}
```

**FFI 指针类型 `*T`**：
- 仅用于 FFI 函数声明/调用和函数参数
- 支持所有 C 兼容类型（`*i8`, `*i16`, `*i32`, `*i64`, `*u8`, `*u16`, `*u32`, `*u64`, `*f32`, `*f64`, `*bool`, `*byte`, `*void`, `*CStruct`）
- 使用规则：
  1. 仅用于 FFI 声明/调用
  2. 下标访问必须提供长度约束证明
  3. 不能用于普通变量声明
  4. 与 `&T` 严格区分

**一句话总结**：

> **统一标准：所有 struct 使用 C 内存布局，支持所有类型，可以直接与 C 互操作。**  
> **编译器自动处理布局转换，确保 100% C 兼容性。**

---

## 6 接口（interface）

### 6.1 设计目标

- **鸭子类型 + 动态派发**体验；  
- **零注册表 + 编译期生成**；  
- **标准内存布局 + 单条 call 指令**；  
- **无 lifetime 符号、无 new 关键字、无运行时锁**。

### 6.2 语法

> **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#21-接口类型)

接口类型定义语法：
- `interface InterfaceName { method_sig ... }`
- 结构体在定义时声明接口：`struct StructName : InterfaceName { ... }`
- 接口方法作为结构体方法定义，可以在结构体内部或外部方法块中定义

### 6.3 语义总览

| 项 | 内容 |
|---|---|
| 接口值 | 16 B 结构体 `{ vptr: *const VTable, data: *any }` |
| VTable | **编译期唯一生成**；单元素函数指针数组；只读静态数据 |
| 装箱 | 局部变量/参数/返回值处自动生成；**无运行期注册** |
| 调用 | `call [vtable+offset]` → **单条指令**，零额外开销 |
| 生命期 | 由作用域 RAII 保证；**逃逸即编译错误**（见 6.4 节） |

### 6.4 Self 类型

- `Self` 是方法签名中的特殊占位符，代表当前结构体类型
- 在接口定义和结构体方法的方法签名中使用
- `Self` 不是一个实际类型，而是编译期的类型替换标记
- 示例：
  - 结构体方法：`Point { fn distance(self: *Self) f32 { ... } }` 中，`Self` 被替换为 `Point`
  - 接口方法：`struct Console : IWriter { fn write(self: *Self, ...) { ... } }` 中，`Self` 被替换为 `Console`
- `*Self` 表示指向当前结构体类型的指针
- 结构体方法（包括接口方法）都可以使用 `Self`，语法一致，语义清晰

### 6.5 生命周期（零语法版）

- **无 `'static`、无 `'a`**；  
- 编译器只在「赋值/返回/传参」路径检查：  
[examples/example_028.txt](./examples/example_028.txt)
- 检查失败**仅一行报错**；通过者**无额外运行时成本**。

**逃逸检查规则**：

接口值不能逃逸出其底层数据的生命周期。编译器在以下路径检查：

1. **返回接口值**：
[examples/example_5.uya](./examples/example_5.uya)

2. **赋值给外部变量**：
[examples/example_6.uya](./examples/example_6.uya)

3. **传递参数**：
[examples/use_writer.uya](./examples/use_writer.uya)

**编译器检查算法**：基于作用域层级检查，数据作用域必须 ≥ 目标作用域，否则编译错误。

**切片生命周期规则**：

切片生命周期必须 ≤ 原数据的生命周期。编译器在以下路径检查：

1. **返回切片**：
[examples/valid.uya](./examples/valid.uya)

2. **切片赋值**：
[examples/example_7.uya](./examples/example_7.uya)

3. **核心规则**：
   - 切片是原数据的视图，不拥有数据
   - 切片的生命周期自动绑定到原数据的生命周期
   - 编译器验证切片不会超过原数据的生命周期
   - 修改原数组会影响切片，切片和原数组共享同一块内存

### 6.6 接口方法调用

- 接口方法调用语法：`interface_value.method_name(arg1, arg2, ...)`
- `self` 参数自动传递，无需显式传递
- 示例：`w.write(&msg[0], 5);` 中，`w` 是接口值，`write` 方法会自动接收 `self` 参数

### 6.7 完整示例

[examples/console.uya](./examples/console.uya)

编译后生成（x86-64）：

[examples/example_035.txt](./examples/example_035.txt)

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
| 无字段接口 | `struct S { w: IWriter }` → ❌ 编译错误（当前限制） |
| 无数组/切片接口 | `const arr: [IWriter: 3]` → ❌ |
| 无自引用 | 接口值不能指向自己 |
| 无运行时注册 | 所有 vtable 编译期生成，**零 map 零锁** |

### 6.9 与 C 互操作

- 接口值首地址 = `&vtable`，可直接当 `void*` 塞给 C；  
- C 侧回调：
[examples/example_036.c](./examples/example_036.c)

### 6.10 后端实现要点

1. **语法树收集** → 扫描所有在结构体定义中声明接口的结构体（`struct T : I { ... }`），生成唯一 vtable 常量。  
2. **类型检查** → 确保结构体方法实现了所有声明接口的全部方法签名。  
3. **装箱点** →  
   - 局部：`const iface: I = concrete;`  
   - 传参 / 返回：按值复制 16 B。  
4. **调用点** →  
   - 加载 `vptr` → 计算方法偏移 → `call [reg+offset]`。  
5. **逃逸检查** → 6.4 节生命周期规则；失败即报错。

### 6.11 迁移指南

| 旧需求（extern+函数指针） | 新做法（接口） |
|---|---|
| `extern call(f: IFunc, x: i32) i32;` | `fn use(IFunc f);` |
| 手动管理函数地址 | 编译期 vtable，无地址赋值 |
| 类型不安全 | 接口签名强制检查 |
| 需全局注册表 | 零注册，零锁 |

### 6.12 迭代器接口（用于for循环）

**设计目标**：
- 通过接口机制支持 for 循环迭代
- 编译期生成vtable
- 支持所有实现了迭代器接口的类型

**迭代器接口定义**：

由于 Uya 没有泛型，迭代器接口需要针对具体元素类型定义。以下以 `i32` 类型为例：

[examples/next.uya](./examples/next.uya)

**数组迭代器实现示例**：

[examples/arrayiteratori32.uya](./examples/arrayiteratori32.uya)

**使用示例**：

[examples/create_iterator.uya](./examples/create_iterator.uya)

**设计说明**：
- 迭代器接口遵循 Uya 接口的设计原则：编译期生成vtable
- 使用错误联合类型 `!void` 表示迭代结束，符合 Uya 的错误处理机制
- 需要为每种元素类型定义对应的迭代器接口（当前限制，泛型功能在未来版本中提供）
- for循环语法会自动使用这些接口进行迭代（[见第8章](#8-控制流)）

### 6.13 一句话总结

> **Uya 接口 = 鸭子派发 + 零注册 + 标准内存布局**；  
> **语法零新增、生命周期零符号、编译期证明**；  
> **今天就能用，明天可放开字段限制**。

---

## 7 栈式数组（零 GC）

[examples/summary_example.uya](./examples/summary_example.uya)

- **栈数组语法**：使用 `[]` 表示未初始化的栈数组，类型由左侧变量的类型注解确定。
- `[]` 不能独立使用，必须与类型注解一起使用：`var buf: [T: N] = [];`
- **数组初始化**：`[]` 返回的数组**未初始化**（包含未定义值），用户必须在使用前初始化数组元素
- **`len` 函数行为**：对于空数组字面量 `[]`，`len` 返回数组声明时的大小，而不是 0
  - 示例：`var buffer: [i32: 100] = []; const len_val: i32 = len(buffer);` → `len_val = 100`
  - 初始化示例：
[examples/example_041.uya](./examples/example_041.uya)
  - 注意：使用未初始化的数组元素是未定义行为（UB）
- 数组大小 `N` 必须是**编译期常量表达式**：
  - 字面量：`64`, `100`
  - 常量变量：`const SIZE: i32 = 64;` 然后使用 `SIZE`
  - 常量算术运算：`2 + 3`, `SIZE * 2`
  - 不支持函数调用（除非是 `const fn`，暂不支持）
- **语法规则**：
  - `[]` 表示栈分配的未初始化数组
  - 数组大小由类型注解 `[T: N]` 中的 `N` 指定
  - 示例：`var buf: [f32: 64] = [];` 表示分配 64 个 `f32` 的栈数组
- **多维数组初始化**：
  - **未初始化多维数组**：使用嵌套的 `[]` 语法
[examples/example_042.uya](./examples/example_042.uya)
  - **多维数组字面量**：使用嵌套的数组字面量
[examples/example_043.uya](./examples/example_043.uya)
  - **多维数组边界检查**：所有维度的索引都需要编译期证明
    - 对于 `matrix[i][j]`，必须证明 `i >= 0 && i < 3 && j >= 0 && j < 4`
    - 常量索引越界 → 编译错误
    - 变量索引无证明 → 编译错误
- 生命周期 = 所在 `{}` 块；返回上层即编译错误（逃逸检测）。
- 后端映射为 `alloca` 或机器栈数组。
- **逃逸检测规则**：`[]` 分配的对象不能：
  - 被函数返回
  - 被赋值给生命周期更长的变量
  - 被传递给可能存储引用的函数

---

## 8 控制流

[examples/control_flow.uya](./examples/control_flow.uya)

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
  - 不支持 `break label` 或 `continue label`（未来支持）
  - `break` 和 `continue` 只能在循环体内使用

- **`for` 循环**：迭代循环，支持可迭代对象和整数范围
  - **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#81-for-循环)
  - **语法形式**：
[examples/example_045.txt](./examples/example_045.txt)
    - `range_expr`：整数范围表达式
      - `start..end`：从 `start` 到 `end-1` 的范围（左闭右开区间 `[start, end)`）
      - `start..`：从 `start` 开始的无限范围，由迭代器结束条件终止
  - **基本形式（有元素变量，只读）**：`for obj |v| { statements }`
    - `obj` 必须是实现了迭代器接口的类型（如数组、切片、迭代器）
    - `v` 是循环变量，类型由迭代器的 `value()` 方法返回类型决定
    - `v` 是只读的，不能修改
    - 自动调用迭代器的 `next()` 方法，返回 `error.IterEnd` 时循环结束
  - **基本形式（有元素变量，可修改）**：`for obj |&v| { statements }`
    - `obj` 必须是实现了迭代器接口的类型（如数组、切片、迭代器）
    - `&v` 是循环变量，类型是指向元素的指针（`&T`），可以修改元素
    - 在循环体中可以通过 `*v` 访问元素值，通过 `*v = value` 修改元素
    - 自动调用迭代器的 `next()` 方法，返回 `error.IterEnd` 时循环结束
    - 注意：只有可变数组（`var arr`）或可变切片才能使用此形式
  - **索引迭代形式**：`for obj |i| { statements }`
    - `obj` 可以是数组或切片
    - `i` 是当前元素的索引，类型为 `usize`
    - 适用于只需要索引，不需要元素值的场景
  - **整数范围形式（有元素变量）**：`for start..end |v| { statements }` 或 `for start.. |v| { statements }`
    - `start..end`：迭代从 `start` 到 `end-1` 的整数（`[start, end)`）
    - `start..`：从 `start` 开始的无限范围，由迭代器结束条件终止
    - `v` 是当前迭代的整数值
  - **丢弃元素形式**：`for obj { statements }` 或 `for start..end { statements }`
    - 不绑定元素变量，只执行循环体指定次数
    - 适用于只需要循环次数，不需要元素值的场景
  - **语义**：
    - for循环是语法糖，编译期展开为while循环（见展开规则）
    - 可迭代对象自动装箱为接口类型，使用动态派发
    - 整数范围直接展开为整数循环
    - 编译期生成vtable
  - **示例**：
[examples/example_046.uya](./examples/example_046.uya)
  - **展开规则**：for循环在编译期展开为while循环
    - **可迭代对象展开（有元素变量，只读）**：
[examples/example_047.uya](./examples/example_047.uya)
    - **可迭代对象展开（有元素变量，可修改）**：
[examples/example_048.uya](./examples/example_048.uya)
      - 注意：
        - 迭代器接口需要提供 `ptr()` 方法返回指向当前元素的指针（类型 `&T`）
        - `item` 是指针类型，需要通过 `*item` 访问和修改元素值
        - 只有可变数组（`var arr`）才能使用此形式，常量数组（`const arr`）使用此形式会编译错误
    - **展开说明**：
      - 可迭代对象：自动装箱为接口，使用迭代器接口进行迭代
      - 整数范围：直接展开为 while 循环
      - 编译器自动识别类型并选择合适的展开方式
      - 所有数组访问都有编译期证明（在当前函数内）

- **`match` 表达式/语句**：模式匹配
  - **语法形式**：`match expr { pattern1 => expr, pattern2 => expr, else => expr }`
  - **作为表达式**：match 可以作为表达式使用，所有分支返回类型必须一致
[examples/example_049.uya](./examples/example_049.uya)
  - **作为语句**：如果所有分支返回 `void`，match 可以作为语句使用
[examples/example_050.uya](./examples/example_050.uya)
  - **支持的模式类型**：
    1. **常量模式**：整数、布尔、错误类型常量
[examples/example_051.uya](./examples/example_051.uya)
    2. **变量绑定模式**：捕获匹配的值
[examples/example_052.uya](./examples/example_052.uya)
    3. **结构体解构**：匹配并解构结构体字段
[examples/example_053.uya](./examples/example_053.uya)
    4. **错误类型匹配**：匹配错误联合类型（支持预定义和运行时错误）
[examples/example_054.uya](./examples/example_054.uya)
    5. **字符串数组匹配**：匹配 `[i8: N]` 数组（字符串插值的结果）
[examples/example_055.uya](./examples/example_055.uya)
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
       - 所有分支的返回类型必须完全一致（Uya 无隐式转换）
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
    - 编译期常量匹配直接展开，无运行时模式匹配引擎
    - 未匹配路径不生成代码
    - 字符串比较：运行时字符串比较使用标准库函数（如 `strcmp` 的等价实现）
  - **示例**：
[examples/example_056.uya](./examples/example_056.uya)

---

## 9 defer 和 errdefer

### 9.1 defer 语句

**语法**：
[examples/defer_errdefer.uya](./examples/defer_errdefer.uya)

**语义**：
- 在当前作用域结束时执行（正常返回或错误返回）
- 执行顺序：LIFO（后声明的先执行）
- 可以出现在函数内的任何位置
- 支持单语句和语句块

**示例**：
[examples/example_8.uya](./examples/example_8.uya)

### 9.2 errdefer 语句

**语法**：
[examples/errdefer_statement.uya](./examples/errdefer_statement.uya)

**语义**：
- 仅在函数返回错误时执行
- 执行顺序：LIFO（后声明的先执行）
- 必须在可能返回错误的函数中使用（返回类型为 `!T`）
- 用于错误情况下的资源清理

**示例**：
[examples/example_9.uya](./examples/example_9.uya)

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
[examples/example_10.uya](./examples/example_10.uya)

### 9.4 与 RAII/drop 的关系

- defer/errdefer **复用 drop 的代码插入机制**
- 在同一个作用域退出点，统一处理所有清理逻辑
- 编译器维护清理代码列表，按顺序执行

**使用场景**：
- **drop**：基于类型的自动清理（文件关闭、内存释放等）
- **defer**：补充清理逻辑（日志记录、状态更新等）
- **errdefer**：错误情况下的特殊清理（回滚操作、错误日志等）

**完整示例**：
[examples/process_file.uya](./examples/process_file.uya)

### 9.5 作用域规则

- defer/errdefer 绑定到当前作用域
- 嵌套作用域有独立的 defer/errdefer 栈
- 内层作用域的 defer 先于外层执行

**示例**：
[examples/nested_example.uya](./examples/nested_example.uya)

---

## 10 运算符与优先级

| 级别 | 运算符 | 结合性 | 说明 |
|----|--------|--------|------|
| 1  | `()` `.` `[]` `[start:end]` | 左 | 调用、字段、下标、切片 |
| 2  | `-` `!` `~` (一元) | 右 | 负号、逻辑非、按位取反 |
| 3  | `* / %` `*|` `*%` | 左 | 乘、除、取模、饱和乘法、包装乘法 |
| 4  | `+ -` `+|` `-|` `+%` `-%` | 左 | 加、减、饱和加法、饱和减法、包装加法、包装减法 |
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
- 赋值运算符 `=` 仅用于 `var` 变量。
- **饱和运算符**：
  - `+|`：饱和加法，溢出时返回类型的最大值或最小值（上溢返回最大值，下溢返回最小值）
  - `-|`：饱和减法，溢出时返回类型的最大值或最小值
  - `*|`：饱和乘法，溢出时返回类型的最大值或最小值
  - 操作数必须是整数类型（`i8`, `i16`, `i32`, `i64`），结果类型与操作数相同
  - 饱和运算符的操作数类型必须完全一致
  - 示例：
[examples/example_064.uya](./examples/example_064.uya)
- **包装运算符**：
  - `+%`：包装加法，溢出时返回包装后的值（模运算）
  - `-%`：包装减法，溢出时返回包装后的值（模运算）
  - `*%`：包装乘法，溢出时返回包装后的值（模运算）
  - 操作数必须是整数类型（`i8`, `i16`, `i32`, `i64`），结果类型与操作数相同
  - 包装运算符的操作数类型必须完全一致
  - 示例：
[examples/example_065.uya](./examples/example_065.uya)
- **位运算符**：
  - `&`：按位与，两个操作数都必须是整数类型（`i8`, `i16`, `i32`, `i64`），结果类型与操作数相同
  - `|`：按位或，两个操作数都必须是整数类型，结果类型与操作数相同
  - `^`：按位异或，两个操作数都必须是整数类型，结果类型与操作数相同
  - `~`：按位取反（一元），操作数必须是整数类型，结果类型与操作数相同
  - `<<`：左移，左操作数必须是整数类型，右操作数必须是 `i32`，结果类型与左操作数相同
  - `>>`：右移（算术右移，对于有符号数保留符号位），左操作数必须是整数类型，右操作数必须是 `i32`，结果类型与左操作数相同
  - 位运算符的操作数类型必须完全一致（移位运算符的右操作数除外，必须是 `i32`）
  - 示例：
[examples/example_066.uya](./examples/example_066.uya)
- **不支持的运算符**：
  - 自增/自减：`++`, `--`（必须使用 `i = i + 1;` 形式）
  - 复合赋值：`+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`（必须使用完整形式）
  - 三元运算符：`?:`（必须使用 `if-else` 语句）
- **类型比较规则**：
  - 基础类型（整数、浮点、布尔）支持 `==` 和 `!=` 比较
  - 浮点数比较使用 IEEE 754 标准，进行精确比较（可能受浮点精度影响）
  - 错误类型支持 `==` 比较
  - 不支持结构体的 `==` 和 `!=` 比较（未来支持）
  - 不支持数组的 `==` 和 `!=` 比较（未来支持）
- **表达式求值顺序**：从左到右（left-to-right）
  - 函数参数求值顺序：从左到右
  - 数组字面量元素表达式求值顺序：从左到右
  - 结构体字面量字段表达式求值顺序：从左到右（按字面量中的顺序）
  - 副作用（赋值）立即生效
- **逻辑运算符短路求值**：
  - `expr1 && expr2`：如果 `expr1` 为 `false`，不计算 `expr2`
  - `expr1 || expr2`：如果 `expr1` 为 `true`，不计算 `expr2`
- **整数溢出和除零**（强制编译期证明）：
  - **整数溢出**：
  - 常量运算溢出 → **编译错误**（编译期直接检查）
  - 变量运算 → 必须显式检查溢出条件，或编译器能够证明无溢出
  - 证明超时 → **自动插入运行时检查**
  - 编译期证明安全（在当前函数内），证明超时则自动插入运行时检查
  - **除零错误**：
    - 常量除零 → **编译错误**
    - 变量 → 必须证明 `y != 0`，证明超时 → **自动插入运行时检查**
    - 编译期证明安全（在当前函数内），证明超时则自动插入运行时检查
  
  **溢出检查示例**：
[examples/add_safe.uya](./examples/add_safe.uya)

**内存安全强制**：

所有 UB 场景必须被编译期证明为安全，证明超时则自动插入运行时检查：

1. **数组越界访问**：
   - 常量索引越界 → **编译错误**
   - 变量索引 → 必须证明 `i >= 0 && i < len`，证明超时 → **自动插入运行时检查**

2. **整数溢出**：
   - 常量运算溢出 → **编译错误**（编译期直接检查）
   - 变量运算 → 必须显式检查溢出条件，或编译器能够证明无溢出
   - 证明超时 → **自动插入运行时检查**
   - 溢出检查模式：
     - 加法上溢：`a > 0 && b > 0 && a > MAX - b`
     - 加法下溢：`a < 0 && b < 0 && a < MIN - b`
     - 乘法上溢：`a > 0 && b > 0 && a > MAX / b`

3. **除零错误**：
   - 常量除零 → **编译错误**
   - 变量 → 必须证明 `y != 0`，证明超时 → **自动插入运行时检查**

4. **使用未初始化内存**：
   - 必须证明「首次使用前已赋值」或「前序有赋值路径」，证明超时 → **自动插入运行时检查**

5. **空指针解引用**：
   - 必须证明 `ptr != null` 或前序有 `if ptr == null { return error; }`，证明超时 → **自动插入运行时检查**

**安全策略**：
- **编译期证明**：所有 UB 必须被编译器证明为安全
- **证明超时处理**：证明超时则自动插入运行时检查，不报错
- **编译期证明**：编译器在当前函数内验证安全性，证明超时则自动插入运行时检查
- **常量错误**：编译期常量错误仍然直接报错（如常量溢出、常量除零）
- **优先级示例**：
[examples/example_068.uya](./examples/example_068.uya)

---

## 11 类型转换

### 11.1 转换语法

> **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#51-转换语法)

Uya 提供两种类型转换语法：

1. **安全转换 `as`**：只允许无精度损失的转换，编译期检查
2. **强转 `as!`**：允许所有转换，包括可能有精度损失的，返回错误联合类型 `!T`

### 11.2 安全转换（as）

安全转换只允许无精度损失的转换，可能损失精度的转换会编译错误：

[examples/safe_cast_as.uya](./examples/safe_cast_as.uya)

### 11.3 强转（as!）

当确实需要进行可能有精度损失的转换时，使用 `as!` 强转语法。`as!` 返回错误联合类型 `!T`，需要使用 `try` 或 `catch` 处理可能的错误：

[examples/force_cast_as.uya](./examples/force_cast_as.uya)

`as!` 可能返回的错误类型：
- `error.PrecisionLoss`：转换导致精度损失
- `error.OverflowError`：转换导致数值溢出
- `error.InvalidConversion`：无效的类型转换（如 NaN 转换为整数）

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

[examples/const_cast.uya](./examples/const_cast.uya)

### 11.6 错误信息示例

[examples/error_message_example.uya](./examples/error_message_example.uya)

### 11.7 设计哲学

- **默认安全**：普通 `as` 转换只允许无精度损失的转换，防止意外精度损失
- **显式强转**：`as!` 语法明确表示程序员知道可能有精度损失，意图清晰
- **安全强转**：`as!` 返回错误联合类型 `!T`，强制程序员处理可能的转换错误
- **编译期证明**：对于编译期可证明安全的转换（在当前函数内），生成单条机器指令，无错误检查
- **编译期检查**：转换安全性在编译期验证，失败即编译错误；可能有损失的转换在运行时检查

### 11.8 代码生成

#### 编译期可证明安全的转换（在当前函数内）
[examples/codegen_example.uya](./examples/codegen_example.uya)

#### 需要运行时检查的转换
[examples/convert.uya](./examples/convert.uya)

---

## 12 内存模型 & RAII

1. 编译期为每个类型 `T` 生成 `drop(T)`（空函数或用户自定义）。  
2. 离开作用域时按字段逆序插入 `drop` 调用。  
3. **递归 drop 规则**：先 drop 字段，再 drop 外层结构体；字段按声明逆序 drop。
4. **数组 drop 规则**：
   - 数组元素按索引逆序 drop（`arr[N-1]`, `arr[N-2]`, ..., `arr[0]`）
   - 然后 drop 数组本身（数组本身的 drop 是空函数，但会调用元素的 drop）
   - 如果数组元素类型有自定义 drop，会调用元素的 drop；如果元素类型是基本类型，drop 是空函数
5. **用户自定义 drop**：`fn drop(self: T) void { ... }`
   - 允许用户为自定义类型定义清理逻辑
   - 实现真正的 RAII 模式（文件自动关闭、内存自动释放等）
   - 每个类型只能有一个 drop 函数
   - 参数必须是 `self: T`（按值传递），返回类型必须是 `void`
   - 递归调用：结构体的 drop 会先调用字段的 drop，再调用自身的 drop

**drop 使用示例**：

[examples/point.uya](./examples/point.uya)

**用户自定义 drop 示例**：

[examples/file_2.uya](./examples/file_2.uya)

**drop 使用示例（基本类型和结构体）**：

[examples/example_basic.uya](./examples/example_basic.uya)

**重要说明**：
- `drop` 是**自动调用**的，无需手动调用
- 对于基本类型（`i32`, `f64`, `bool` 等），`drop` 是空函数，无运行时开销
- 用户可以为自定义类型定义 `drop` 函数，实现 RAII 模式
- 编译器自动插入 drop 调用，确保资源正确释放

**未来版本特性**：
- drop 标记：`#[no_drop]` 用于无需清理的类型
  - 标记纯数据类型，编译器跳过 drop 调用
  - 进一步优化性能

---

## 12.5 移动语义

### 12.5.1 设计目标

- **避免不必要的拷贝**：结构体赋值时转移所有权，而非复制
- **编译期所有权转移**：移动操作在编译期完成
- **自动移动，无需显式语法**：编译器自动识别移动场景
- **与 RAII 完美配合**：移动后只有目标对象调用 drop，防止 double free
- **防止悬垂指针**：存在活跃指针时禁止移动，确保内存安全

### 12.5.2 移动语义规则

移动语义是 Uya 语言的核心机制，用于避免不必要的拷贝并保证资源安全：

1. **移动语义适用于结构体类型**：基本类型使用值语义（复制），结构体使用移动语义（转移所有权）
2. **自动移动**：编译器自动识别移动场景，无需显式语法
3. **编译期检查**：所有移动相关的检查在编译期完成（在当前函数内）
4. **严格检查机制**：存在活跃指针时禁止移动，防止悬垂指针

### 12.5.3 自动移动场景

以下场景会自动触发移动语义：

1. **赋值操作**：`const x: Struct = y;`（`y` 的所有权转移给 `x`）
2. **函数参数传递**：按值传递结构体参数时，所有权转移给函数参数
   - **例外**：方法调用 `obj.method()` 不会移动 `obj`，调用时自动传递指针（`&obj`），确保方法调用后原对象仍然可用
   - **推荐**：方法签名使用 `self: *StructName`（指针），更显式、语义一致
3. **函数返回值**：返回结构体时，所有权转移给调用者
4. **结构体字段初始化**：`Container{ field: struct_value }`（`struct_value` 的所有权转移给字段）
5. **数组元素赋值**：`arr[i] = struct_value`（`struct_value` 的所有权转移给数组元素）

### 12.5.4 移动后的变量状态

- 变量被移动后变为"已移动"状态
- 已移动的变量不能再次使用（编译错误）
- 编译器在编译期检查移动后使用错误
- 移动不会调用源对象的 drop，只有目标对象离开作用域时才调用 drop

**示例**：

[examples/file_3.uya](./examples/file_3.uya)

### 12.5.5 指针与移动语义的交互

**核心规则**：如果变量存在指向它的活跃指针（`&var`），则不能移动该变量。

- **检查时机**：在移动操作前，编译器检查是否存在指向该变量的活跃指针
- **活跃指针定义**：指针在作用域内（包括外层作用域），且可能被使用
- **检查范围**：编译器检查**所有作用域层级**（包括外层作用域），只要存在指向变量的指针，就不能移动
- **错误信息**：`错误：变量 'var' 存在活跃指针，不能移动`
- **设计原则**：采用严格检查，避免跨作用域的复杂情况和悬垂指针问题

**示例：存在活跃指针时禁止移动**：

[examples/example_11.uya](./examples/example_11.uya)

**正确的使用方式：指针离开作用域后再移动**：

[examples/example_12.uya](./examples/example_12.uya)

**错误的移动：跨作用域指针阻止移动**：

[examples/example_13.uya](./examples/example_13.uya)

**使用指针参数，不移动对象**：

[examples/process_1.uya](./examples/process_1.uya)

**函数参数指针的活跃性**：

[examples/process_2.uya](./examples/process_2.uya)

### 12.5.6 条件分支和循环中的移动

**条件分支中的移动检查**：

同一变量在不同分支中不能多次移动。编译器需要路径敏感分析，确保变量在所有可能执行路径中只移动一次。

[examples/example_14.uya](./examples/example_14.uya)

**循环中的移动检查**：

循环中的变量不能移动，因为循环可能执行多次，导致多次移动同一个变量。

[examples/example_15.uya](./examples/example_15.uya)

### 12.5.7 数组和接口值的移动

**数组移动语义**：

数组本身使用值语义（复制），但数组元素如果是结构体，则使用移动语义。

[examples/example_16.uya](./examples/example_16.uya)

**接口值移动**：

接口值是16字节结构体（vtable指针+数据指针），移动接口值只是复制16字节，不涉及底层数据的移动。底层数据的生命周期仍然由原始对象决定。

[examples/example_17.uya](./examples/example_17.uya)

### 12.5.8 嵌套结构体和字段访问

**嵌套结构体移动**：

移动外层结构体时，所有字段（包括嵌套结构体字段）一起移动。

[examples/inner_1.uya](./examples/inner_1.uya)

**字段访问与指针的区别**：

- 直接字段访问（`struct.field`）不是指针，可以移动
- 通过指针访问（`ptr.field`）意味着存在指向对象的指针，不能移动

[examples/container.uya](./examples/container.uya)

### 12.5.9 与 drop 的关系

移动语义与 RAII 和 drop 机制完美配合：

- **移动不会调用源对象的 drop**：移动只是转移所有权，不触发资源释放
- **只有目标对象离开作用域时才调用 drop**：资源在目标对象离开作用域时释放
- **防止 double free 和资源泄漏**：确保每个资源只被释放一次

**示例：堆内存安全移动（解决 double free 问题）**：

[examples/heapbuffer.uya](./examples/heapbuffer.uya)

### 12.5.10 完整示例

**基本移动示例**：

[examples/file_4.uya](./examples/file_4.uya)

**函数参数移动**：

[examples/process_file_1.uya](./examples/process_file_1.uya)

**返回值移动**：

[examples/create_file.uya](./examples/create_file.uya)

### 12.5.11 限制说明

- **移动语义仅适用于结构体类型**：基本类型始终使用值语义（复制）
- **移动后变量不能再次使用**：编译器在编译期检查移动后使用错误
- **存在活跃指针时不能移动**：检查所有作用域层级，只要存在指向变量的指针就不能移动
- **条件分支中的移动**：同一变量在不同分支中不能多次移动（编译器路径敏感分析，确保只移动一次）
- **循环中的移动**：循环中的变量不能移动（因为可能执行多次，导致多次移动）
- **数组移动**：数组本身使用值语义（复制），但数组元素如果是结构体，则使用移动语义
- **接口值移动**：接口值移动只复制16字节（vtable指针+数据指针），不移动底层数据
- **嵌套结构体移动**：移动外层结构体时，所有字段（包括嵌套结构体字段）一起移动
- **字段访问与指针**：直接字段访问（`struct.field`）不是指针，可以移动；通过指针访问（`ptr.field`）意味着存在指针，不能移动
- **函数参数指针**：传递指针给函数后，原指针变量仍然被认为是"活跃指针"，函数返回后仍然阻止移动
- **编译器在编译期检查**：所有移动相关的检查在编译期完成（在当前函数内）
- **采用严格检查机制**：避免悬垂指针问题，规则简单明确

### 12.5.12 一句话总结

> **Uya 移动语义 = 结构体自动移动 + 指针严格检查 + 编译期验证**；  
> **防止 double free 和悬垂指针，与 RAII 完美配合**；  
> **只移动结构体，基本类型值语义，数组值语义但元素可移动**。

---


## 13 原子操作

### 13.1 设计目标

- **关键字 `atomic T`** → 语言层原子类型
- **读/写/复合赋值 = 自动原子指令** → 零运行时锁
- **编译期证明（在当前函数内）**
- **失败 = 类型非 `atomic T` → 编译错误**

### 13.2 语法

> **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#61-原子类型)

[examples/counter.uya](./examples/counter.uya)

### 13.3 语义

| 操作 | 自动生成 | 说明 |
|---|---|---|
| `const v = cnt;` | 原子 load | 读取原子类型值 |
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
  - 提供最强的内存同步保证
- **限制**：不支持自定义内存序（如 acquire、release、relaxed）
  - 未来可能支持显式内存序参数
- **性能考虑**：seq_cst 可能比 relaxed 内存序有更高的性能开销，但提供最强的安全性保证

### 13.5 限制

- **类型必须是 `atomic T`**：非原子类型进行原子操作 → 编译错误
- **零新符号**：无需额外的语法标记
- **自动原子指令**：所有原子操作直接生成硬件原子指令

### 13.6 一句话总结

> **Uya 原子操作 = `atomic T` 关键字 + 自动原子指令**；  
> **读/写/复合赋值自动原子化，零运行时锁。**

---

## 14 内存安全

### 14.1 设计目标

- **所有 UB 必须被编译期证明为安全**（在当前函数内）
- **证明超时则自动插入运行时检查**，不报错，确保程序安全
- **证明范围**：仅限当前函数内的代码路径
- **函数返回值**：编译器不能自动证明函数返回值的安全性，调用者必须显式处理
- **跨函数调用**：需要显式处理返回值（使用 `try`、`catch` 或显式检查）
- **证明超时机制**：编译器在有限时间内无法完成证明时，自动生成运行时安全检查代码

### 14.2 内存安全强制表

| UB 场景 | 必须证明为安全 | 失败结果 |
|---|---|---|
| 数组越界 | 常量索引越界 → 编译错误；变量索引 → 证明 `i >= 0 && i < len` | **常量错误：编译错误；变量证明超时：自动插入运行时检查** |
| 空指针解引用 | 证明 `ptr != null` 或前序有 `if ptr == null { return error; }` | **常量错误：编译错误；变量证明超时：自动插入运行时检查** |
| 使用未初始化 | 证明「首次使用前已赋值」或「前序有赋值路径」 | **常量错误：编译错误；变量证明超时：自动插入运行时检查** |
| 整数溢出 | 常量溢出 → 编译错误；变量 → 显式检查或编译器证明无溢出 | **常量错误：编译错误；变量证明超时：自动插入运行时检查** |
| 除零错误 | 常量除零 → 编译错误；变量 → 证明 `y != 0` | **常量错误：编译错误；变量证明超时：自动插入运行时检查** |

### 14.3 证明机制

Uya 语言的编译期证明机制采用**分层验证策略**，**证明范围仅限当前函数内**：

1. **常量折叠**（最简单）：
   - 编译期常量直接检查，溢出/越界立即报错
   - 示例：`const x: i32 = 2147483647 + 1;` → 编译错误

2. **路径敏感分析**（中等复杂度）：
   - 编译器在当前函数内跟踪所有代码路径，分析变量状态
   - 通过条件分支建立约束条件
   - 示例：`if i < 0 || i >= 10 { return error; }` 后，编译器知道 `i >= 0 && i < 10`

3. **符号执行**（复杂场景）：
   - 对于复杂表达式，编译器在当前函数内使用符号执行技术
   - 建立约束系统，验证数学关系
   - 示例：`if a > 0 && b > 0 && a > max - b { return error; }` 后，证明 `a + b <= max`

4. **函数返回值证明**：
   - **函数内部**：编译器可以证明返回值的安全性（在 `return` 语句之前）
   - **调用者**：编译器不能自动证明函数返回值的安全性，需要显式处理
   - **返回值类型决定处理方式**：
     - 错误联合类型 `!T`：必须使用 `try` 或 `catch` 处理
     - 指针类型 `&T`：调用者需要显式检查（如 `if ptr == null { return error; }`）
     - 数组/切片：调用者需要显式检查边界（如果使用返回值进行索引访问）
   - 示例：`const result: i32 = try divide(10, 2);` 显式处理可能的错误
   - 示例：`const ptr: &i32 = get_pointer(); if ptr == null { return error; }` 显式检查空指针

5. **跨函数调用处理**：
   - 函数调用的返回值需要显式处理（使用 `try`、`catch` 或显式检查）
   - 编译器不跨函数进行证明，确保证明范围明确
   - 调用者必须信任函数签名，但需要显式处理返回值

5. **证明超时处理**：
   - **常量错误**：编译期常量直接检查，溢出/越界立即报错（如 `const x: i32 = 2147483647 + 1;` → 编译错误）
   - **变量证明超时**：编译器在有限时间内无法完成证明时，自动插入运行时检查，不报错
   - **运行时检查行为**：编译器自动生成边界检查代码，检查失败时返回错误或触发安全处理
   - **建议**：使用 `try` 关键字、饱和运算符（`+|`, `-|`, `*|`）或包装运算符（`+%`, `-%`, `*%`）简化证明，减少证明超时

**实现说明**：
- **证明范围**：仅限当前函数内的代码路径
- **证明超时机制**：编译器设置证明时间限制，超时则自动插入运行时检查
- 优先实现**常量折叠**和**路径敏感分析**
- 复杂符号执行可能超时，此时编译器自动插入运行时检查
- **跨函数调用必须显式处理**，编译器不进行跨函数证明

### 14.4 示例

[examples/safe_access_2.uya](./examples/safe_access_2.uya)

**整数溢出处理示例**：

[examples/add_safe_1.uya](./examples/add_safe_1.uya)

**溢出检查规则**：

1. **常量运算**：
   - 编译期常量运算直接检查，溢出即编译错误
   - 示例：
     - `const x: i32 = 2147483647 + 1;` → 编译错误（i32 溢出）
     - `const y: i64 = 9223372036854775807 + 1;` → 编译错误（i64 溢出）

2. **`try` 关键字和饱和运算符（最推荐）**：
   - 使用 `try` 关键字进行溢出检查，或使用饱和运算符 `+|`, `-|`, `*|` 进行溢出处理
   - 一行代码替代多行溢出检查，代码简洁
   - 编译期展开，与手写代码性能相同
   - 示例：
[examples/add_safe_2.uya](./examples/add_safe_2.uya)
   - **`try` 关键字支持的操作**：
     - `try a + b`（加法溢出检查）
     - `try a - b`（减法溢出检查）
     - `try a * b`（乘法溢出检查）
   - **饱和运算符**：
     - `a +| b`（饱和加法）
     - `a -| b`（饱和减法）
     - `a *| b`（饱和乘法）
   - **包装运算符**：
     - `a +% b`（包装加法）
     - `a -% b`（包装减法）
     - `a *% b`（包装乘法）
   - **支持的类型**：`i8`, `i16`, `i32`, `i64`
   - **编译期展开**：`try` 关键字和饱和运算符在编译期展开为相应的溢出检查代码

3. **max/min 关键字（备选方式）**：
   - 使用 `max` 和 `min` 关键字访问类型的极值常量
   - `max` 和 `min` 是语言关键字，编译器从上下文类型自动推断极值类型
   - 适用于需要自定义溢出检查逻辑的场景
   - 示例：
[examples/example_098.uya](./examples/example_098.uya)
   - **类型推断规则**：
     - 常量定义：从类型注解推断，如 `const MAX: i32 = max;` → `max i32`
     - 表达式上下文：从操作数类型推断，如 `a > max - b`（a 和 b 是 i32）→ `max i32`
     - 函数返回：从返回类型推断，如 `return max;`（函数返回 i32）→ `max i32`
   - **极值对应表**：
     - `max`（i32 上下文）：2147483647
     - `min`（i32 上下文）：-2147483648
     - `max`（i64 上下文）：9223372036854775807
     - `min`（i64 上下文）：-9223372036854775808
   - **编译期常量**：这些表达式在编译期求值

4. **变量运算**：
   - 必须显式检查溢出条件，或编译器能够证明无溢出
   - 证明超时 → 自动插入运行时检查
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
   - 如果编译器可以在当前函数内通过路径敏感分析证明无溢出，则编译通过
   - 例如：已知 `a < 1000 && b < 1000`，可以证明 `a + b < 2000`，无溢出
   - 如果证明超时，编译器自动插入运行时溢出检查

### 14.5 一句话总结

> **Uya 内存安全 = 所有 UB 必须被编译期证明为安全（在当前函数内）→ 证明超时则自动插入运行时检查**；  
> **证明范围仅限当前函数，跨函数调用需要显式处理。常量错误仍然直接报错。**

---

## 15 并发安全

### 15.1 设计目标

- **原子类型 `atomic T`** → 语言层原子
- **读/写/复合赋值 = 自动原子指令** → **零运行时锁**
- **数据竞争 = 零**（所有原子操作自动序列化）
- **零新符号**：无需额外的语法标记

### 15.2 并发安全机制

| 特性 | 实现 | 说明 |
|---|---|---|
| 原子类型 | `atomic T` 关键字 | 语言层原子类型 |
| 原子操作 | 自动生成原子指令 | 读/写/复合赋值自动原子化 |
| 数据竞争 | 零（编译期保证） | 所有原子操作自动序列化 |
| 运行时锁 | 零 | 无锁编程，直接硬件原子指令 |

### 15.3 示例

[examples/counter_1.uya](./examples/counter_1.uya)

### 15.4 限制

- **只靠原子类型**：并发安全只靠 `atomic T` + 自动原子指令

### 15.5 一句话总结

> **Uya 并发安全 = 原子类型 + 自动原子指令**；  
> **零数据竞争，零运行时锁。**

---

## 16 标准库

| 函数 | 签名 | 说明 |
|------|------|------|
| `len` | `fn len(a: [T: N]) i32` | 返回数组元素个数 `N`（编译期常量） |
| `sizeof` | `fn sizeof(T) i32` | 返回类型 `T` 的字节大小（编译期常量，内置函数） |
| `alignof` | `fn alignof(T) i32` | 返回类型 `T` 的对齐字节数（编译期常量，需导入 `std.mem`） |

**说明**：
- `len` 和 `sizeof` 函数是编译器内置的，编译期展开，自动可用，无需导入或声明
- `alignof` 是标准库函数（位于 `std/mem.uya`），需要导入使用，编译期折叠为常数

**函数详细说明**：

1. **`len(a: [T: N]) i32`**
   - 功能：返回数组的元素个数
   - 参数：`a` 是任意类型 `T` 的数组，大小为 `N`
   - 返回值：`i32` 类型，值为 `N`（编译期常量）
   - 注意：由于 `N` 是编译期常量，此函数在编译期求值
   - **空数组字面量**：对于空数组字面量 `[]`，`len` 返回数组声明时的大小，而不是 0
     - 示例：`var buffer: [i32: 100] = []; const len_val: i32 = len(buffer);` → `len_val = 100`
   - 示例：
[examples/example_100.uya](./examples/example_100.uya)

2. **`try` 关键字、饱和运算符**（`+|`, `-|`, `*|`）**和包装运算符**（`+%`, `-%`, `*%`）
   - 功能：提供简洁的溢出检查和处理方式，避免重复编写溢出检查代码
   - 支持的类型：`i8`, `i16`, `i32`, `i64`
   - 编译期展开：`try` 关键字和饱和运算符在编译期展开为相应的溢出检查代码
   - **`try` 关键字用于溢出检查**：
     - **功能**：对算术运算（`+`, `-`, `*`）进行溢出检查，溢出时返回 `error.Overflow`
     - **语法**：`try expr`，其中 `expr` 是算术运算表达式
     - **返回类型**：`!T`（错误联合类型），需要 `catch` 处理错误
     - **可能抛出的错误**：
       - `error.Overflow`：当算术运算结果超出类型范围时抛出
       - 加法溢出：`try a + b` 在 `a + b` 超出类型范围时返回 `error.Overflow`
       - 减法溢出：`try a - b` 在 `a - b` 超出类型范围时返回 `error.Overflow`
       - 乘法溢出：`try a * b` 在 `a * b` 超出类型范围时返回 `error.Overflow`
     - **使用场景**：需要明确处理溢出错误的情况（如输入验证、关键计算）
     - **示例**：
[examples/add_safe_3.uya](./examples/add_safe_3.uya)
     - **行为说明**：
       - 如果运算结果在类型范围内，返回计算结果
       - 如果运算结果溢出，返回 `error.Overflow`
       - 必须使用 `catch` 或 `try` 处理可能的错误
       - 支持的操作：`+`（加法）、`-`（减法）、`*`（乘法）
   - **饱和运算符**（`+|`, `-|`, `*|`）：返回饱和值，溢出时返回类型的最大值或最小值
     - **功能**：执行饱和算术，溢出时返回类型的极值（最大值或最小值），而不是错误
     - **返回类型**：`T`（普通类型），不会返回错误，总是返回有效数值
     - **使用场景**：需要限制结果在类型范围内的场景（如信号处理、图形处理、游戏开发）
     - **示例**：
[examples/add_saturating.uya](./examples/add_saturating.uya)
     - **行为说明**：
       - 如果运算结果在类型范围内，返回计算结果
       - 如果运算结果上溢（超过最大值），返回类型的最大值
       - 如果运算结果下溢（小于最小值），返回类型的最小值
       - 总是返回有效数值，无需错误处理
   - **包装运算符**（`+%`, `-%`, `*%`）：返回包装值，溢出时返回包装后的值
     - **功能**：执行包装算术，溢出时返回包装后的值（模运算），而不是错误或极值
     - **返回类型**：`T`（普通类型），不会返回错误，总是返回有效数值
     - **使用场景**：需要明确的溢出行为（加密算法、循环计数器、哈希函数）
     - **示例**：
[examples/add_wrapping.uya](./examples/add_wrapping.uya)
     - **行为说明**：
       - 如果运算结果在类型范围内，返回计算结果
       - 如果运算结果溢出，返回包装后的值（模 2^n，n 为类型位数）
       - 总是返回有效数值，无需错误处理
   - **三种方式的对比**：
     | 方式 | 溢出行为 | 返回类型 | 使用场景 |
     |------|----------|----------|----------|
     | `try` 关键字 | 返回错误 | `!T` | 需要明确处理溢出错误（输入验证、关键计算） |
     | 饱和运算符（`+|`, `-|`, `*|`） | 返回极值 | `T` | 需要限制结果范围（信号处理、图形处理） |
     | 包装运算符（`+%`, `-%`, `*%`） | 返回包装值 | `T` | 需要明确的溢出行为（加密算法、循环计数器） |
     
     **选择建议**：
     - 需要错误处理时 → 使用 `try` 关键字（如 `try a + b`）
     - 需要限制范围时 → 使用饱和运算符（如 `a +| b`）
     - 需要包装行为时 → 使用包装运算符（如 `a +% b`）
   
   - **编译期展开示例**：
[examples/example_104.uya](./examples/example_104.uya)
   
   - **优势**：
     - 代码简洁：一行代码替代多行溢出检查
     - 编译期展开，与手写代码性能相同
     - 类型安全：编译器自动推断类型
     - 统一接口：所有整数类型使用相同的函数名
     - 语义清晰：函数名直接表达溢出处理方式

3. **`sizeof(T) i32`**
   - **功能**：`sizeof(T)` 返回类型 `T` 的字节大小
   - **位置**：编译器内置函数，无需导入
   - **签名**：
[examples/sizeof.uya](./examples/sizeof.uya)
   - **使用**：
[examples/vec3_1.uya](./examples/vec3_1.uya)
   - **支持类型**：
     | 类别 | 示例 | 说明 |
     |------|------|------|
     | 基础整数 | `i8` … `i64`, `u8` … `u64` | 大小对齐 = 自身宽度 |
     | 浮点 | `f32`, `f64` | 4 B / 8 B |
     | 布尔 | `bool` | 1 B |
     | 指针 | `&T`, `*T`（FFI指针，如 `*byte`） | 平台字长（4 B 或 8 B） |
     | 数组 | `[T: N]` | 大小 = `N * sizeof(T)`，对齐 = `alignof(T)` |
     | 结构体 | `struct S{...}` | 大小 = 各字段按 C 规则布局，对齐 = 最大字段对齐 |
     | 原子 | `atomic T` | 与 `T` 完全相同 |
   - **常量表达式**：结果可在**任何需要编译期常量**的位置使用
[examples/file_5.uya](./examples/file_5.uya)
   - **零运行时保证**：
     - 前端遇到 `sizeof(T)` **直接折叠**成常数，**不生成函数调用**
     - 失败路径（类型未定义、含泛型参数）→ **编译错误**，不生成代码
   - **常见示例**：
[examples/packet.uya](./examples/packet.uya)
   - **限制**：
     - `T` 必须是**完全已知类型**（无待填泛型参数）
     - 不支持表达式级 `sizeof(expr)`——仅对 **类型** 求值
     - 返回类型固定为 `i32`；超大结构体大小若超过 `i32` 上限 → 编译错误
   - **一句话总结**：
     > `sizeof` 是**编译器内置函数**，编译期折叠成常数；  
     > 零关键字、编译期证明，单页纸用完。

4. **`alignof(T) i32`**
   - **功能**：`alignof(T)` 返回类型 `T` 的对齐字节数
   - **位置**：标准库 `std/mem.uya`，需要导入使用
   - **签名**：
[examples/sizeof.uya](./examples/sizeof.uya)
   - **使用**：
     - 需要导入：`use std.mem.alignof;` 或 `use std.mem.{alignof};`
[examples/vec3_1.uya](./examples/vec3_1.uya)
   - **支持类型**：
     | 类别 | 示例 | 说明 |
     |------|------|------|
     | 基础整数 | `i8` … `i64`, `u8` … `u64` | 大小对齐 = 自身宽度 |
     | 浮点 | `f32`, `f64` | 4 B / 8 B |
     | 布尔 | `bool` | 1 B |
     | 指针 | `&T`, `*T`（FFI指针，如 `*byte`） | 平台字长（4 B 或 8 B） |
     | 数组 | `[T: N]` | 对齐 = `alignof(T)` |
     | 结构体 | `struct S{...}` | 对齐 = 最大字段对齐 |
     | 原子 | `atomic T` | 与 `T` 完全相同 |
   - **常量表达式**：结果可在**任何需要编译期常量**的位置使用
   - **零运行时保证**：
     - 前端遇到 `alignof(T)` **直接折叠**成常数，**不生成函数调用**
     - 失败路径（类型未定义、含泛型参数）→ **编译错误**，不生成代码
   - **限制**：
     - `T` 必须是**完全已知类型**（无待填泛型参数）
     - 返回类型固定为 `i32`

> 更多函数通过 `extern` 直接调用 C 库即可。

---

## 17 字符串与格式化

### 17.1 设计目标
- 支持 `"hex=${x:#06x}"`、`"pi=${pi:.2f}"` 等常用格式；  
- 仍保持「编译期展开 + 定长栈数组」；  
- 无运行时解析开销，无堆分配；  
- 语法一眼看完。

### 17.2 语法

> **BNF 语法规范**：详见 [grammar_formal.md](./grammar_formal.md#13-字符串插值)

字符串插值语法：
- 基本形式：`"text${expr}text"`
- 格式化形式：`"text${expr:format}text"`
- 格式说明符与 C printf 保持一致

- 整体格式 **与 C printf 保持一致**，减少学习成本。  
- `width` / `precision` 必须为**编译期数字**（`*` 暂不支持）。  
- 结果类型仍为 `[i8: N]`，宽度由「格式字符串最大可能长度」常量求值得出。

### 17.3 宽度常量表

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
| `%e` `%E` (f64) | 24 B | 双精度科学计数法（如 `3.14e+00`） |
| `%.2e` (f64) | 24 B | 双精度科学计数法，保留 2 位小数（宽度不变） |
| `%e` `%E` (f32) | 16 B | 单精度科学计数法（如 `3.14e+00`） |
| `%.2e` (f32) | 16 B | 单精度科学计数法，保留 2 位小数（宽度不变） |
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

### 17.4 完整示例

```uya
extern printf(fmt: *byte, ...) i32;

fn main() i32 {
  const x: u32 = 255;
  const pi: f64 = 3.1415926;
  const large: f64 = 123456789.0;

  // 定点格式
  const msg1: [i8: 64] = "hex=${x:#06x}, pi=${pi:.2f}\n";
  printf(&msg1[0]);
  
  // 科学计数法格式
  const msg2: [i8: 64] = "pi=${pi:.2e}, large=${large:.3E}\n";
  printf(&msg2[0]);
  
  return 0;
}
[examples/example_114.txt](./examples/example_114.txt)

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

[examples/example_115.txt](./examples/example_115.txt)

**重要说明：编译期优化 vs 运行时执行**：

字符串插值采用**编译期优化 + 运行时格式化**的混合策略：

**编译期完成的工作**（零运行时开销）：
- ✅ 计算缓冲区大小（`[i8: N]` 中的 `N`）
- ✅ 识别文本段和插值段
- ✅ 生成格式字符串常量（如 `"%#06x"`、`"%.2f"`）
- ✅ 生成文本段的 `memcpy` 调用
- ✅ 零运行时解析开销：格式字符串在编译期确定，无需运行时解析

**运行时执行的工作**（必要的格式化操作）：
- ⚠️ 调用 `sprintf` 进行实际的格式化（将数值转换为字符串）
- ⚠️ 这是必要的，因为数值是运行时变量

**性能保证**：
- **零堆、零 GC**：缓冲区在栈上分配（`alloca`），无需堆分配
- **零解析开销**：格式字符串在编译期确定，无需运行时解析
- **性能等同**：与手写 C 代码使用 `sprintf` 的性能相同，无额外开销

**总结**：字符串插值不是"完全编译期展开"，而是"编译期优化 + 运行时格式化"。编译期完成所有可以静态确定的工作，运行时只执行必要的格式化操作。

### 17.5 后端实现要点

1. **词法** → 识别 `':' spec` 并解析为 `(flag, width, precision, type)` 四元组。  
2. **常量求值** → 根据「类型 + 格式」查表得最大字节数。  
3. **代码生成** →  
   - 文本段 = `memcpy`；  
   - 插值段 = `sprintf(buf+offset, "格式化串", 值)`；  
   - 格式串本身 = 编译期常量。  

### 17.6 限制（保持简单）

| 限制 | 说明 |
|---|---|
| `width/precision` | 必须为**编译期数字**；`*` 暂不支持 |
| 类型不匹配 | `%.2f` 但表达式是 `i32` → 编译错误 |
| 嵌套字符串 | `${"abc"}` → ❌ 表达式内不能再有字符串字面量 |
| 动态宽度 | `"%*d"` → 未来支持 |

### 17.7 字符串切片

字符串数组 `[i8: N]` 可以使用切片语法 `&text[start:len]` 创建切片视图：

```uya
type str = &[i8];  // 字符串切片别名（可选）

const text: [i8: 12] = "Hello world";
const hello: &[i8] = &text[0:5];  // "Hello" 的切片视图

// 使用字符串切片
for hello |byte| {
    printf("%c", byte);
}
```

**字符串切片特性**：
- 字符串数组 `[i8: N]` 可以使用切片语法 `&text[start:len]` 创建切片视图
- 字符串切片类型为 `&[i8]`，可以定义类型别名 `type str = &[i8]` 简化使用
- 字符串切片支持所有切片操作：for循环迭代、索引访问等
- 字符串切片是原字符串的视图，修改原字符串会影响切片
- 字符串切片的生命周期绑定到原字符串，遵循切片生命周期规则

### 17.8 一句话总结

> Uya 字符串插值 `"a=${x:#06x}"` → **编译期展开成定长栈数组**，格式与 C printf 100% 对应，**零运行时解析、零堆、零 GC**，性能 = 手写 `sprintf`。

---

## 29 未实现/将来

### 29.1 核心特性（计划中）
- **官方包管理器**：`uyapm`
  - 依赖管理和包分发系统
  - 支持版本管理和依赖解析

### 29.2 drop 机制增强
- **drop 标记**：`#[no_drop]` 用于无需清理的类型
  - 标记纯数据类型，编译器跳过 drop 调用
  - 进一步优化性能

### 29.3 类型系统增强
- **类型推断增强**：局部类型推断
  - 函数内支持类型推断，函数签名仍需显式类型
  - 提高代码简洁性，保持可读性
  - 示例：`const x = 10;` 自动推断为 `i32`（注意：当前不支持类型推断，需要显式类型注解）
- **指针下标访问语法糖**：`ptr[i]` 是 `*(ptr + i)` 的语法糖
  - **语法**：`ptr[i]` 展开为 `*(ptr + i)`，与 C 语言一致
  - **边界检查**：与指针算术相同，需要证明 `i >= 0 && i < len`
  - **编译期展开**：编译期展开，无额外开销
  - **示例**：
[examples/example_142.uya](./examples/example_142.uya)
- **结构体方法语法糖**：`obj.method()` 语法糖
  - 允许使用 `obj.method()` 语法调用结构体相关的静态函数
  - 编译期展开为 `method(obj, ...)` 静态函数调用
  - 所有方法都是静态绑定，编译期确定，不涉及动态派发
  - **定义方式**：支持两种方式定义方法
    - **方式1：结构体内部定义**：方法定义在结构体花括号内，与字段定义并列
      - 语法：`struct StructName { field: Type, fn method(self: *Self) ReturnType { ... } }`
    - **方式2：结构体外部定义**：使用块语法在结构体定义后添加方法
      - 语法：`StructName { fn method(self: *Self) ReturnType { ... } }`
      - 可以在结构体定义之后的任何位置添加方法
    - `self` 参数必须显式声明，使用指针：`self: *Self` 或 `self: *StructName`
    - **推荐使用 `Self` 占位符**：`self: *Self` 更简洁、与接口实现语法一致，符合 Uya 的"显式控制"设计原则
      - `self: *Self`：使用 `Self` 占位符，编译期替换为具体类型（如 `self: *Point`），与接口实现语法一致（推荐）
      - `self: *StructName`：使用具体类型，语义清晰一致（也可用）
      - **不允许按值传递**：不支持 `self: StructName`，避免语义歧义（签名说按值但调用时用引用）
    - **方法调用与移动语义**：
      - 方法签名必须是 `fn method(self: *Self)` 或 `fn method(self: *StructName)`，调用时传递指针（`&obj`），不触发移动
      - 方法调用后，原对象仍然可以使用，符合常见的方法调用语义
    - 编译期将方法展开为普通函数：`Self` 占位符会被替换为具体类型，如 `fn StructName_method(self: *StructName) ReturnType { ... }`
    - 调用 `obj.method()` 展开为 `StructName_method(&obj)`（传递指针，不移动）
  - **接口方法作为结构体方法**：
    - 结构体在定义时声明接口：`struct StructName : InterfaceName { ... }`
    - 接口方法作为结构体方法定义，可以在结构体内部或外部方法块中定义
    - 结构体方法（包括接口方法）都使用相同的语法：`StructName { fn method(self: *Self) ReturnType { ... } }`
    - 方法签名使用 `Self` 占位符（如 `self: *Self`），编译期替换为具体类型
    - 接口方法会生成 vtable，支持动态派发
    - 普通结构体方法编译期展开为静态函数
  - **完整示例**：
[examples/point_1.uya](./examples/point_1.uya)
  - **与接口实现共存示例**（展示两者可以同时使用，无冲突）：
[examples/point_2.uya](./examples/point_2.uya)
  - **编译期展开规则**：
    - `struct A { fn method(self: *Self) void { ... } }` → `fn A_method(self: *A) void { ... }`（`Self` 替换为 `A`）
    - `A { fn method(self: *Self) void { ... } }` → `fn A_method(self: *A) void { ... }`（`Self` 替换为 `A`）
    - `obj.method()` → `A_method(&obj)`（传递指针，不移动 `obj`）
    - `obj.method(arg)` → `A_method(&obj, arg)`（传递指针，不移动 `obj`）
    - **推荐使用指针和 Self**：`self: *Self` 更简洁，符合 Uya 的"显式控制"原则
    - `Self` 是编译期占位符，会被替换为具体的结构体类型（如 `Point`）
    - 方法仍然是普通函数，可以像普通函数一样调用：`A_method(&obj)` 或 `A_method(obj)`（如果明确需要移动）
    - 如果需要移动对象，必须显式调用：`A_method(obj)`（直接传递值，会移动）
    - 接口方法作为结构体方法定义，编译器会生成 vtable 支持动态派发
- **结构体字段访问**：通过接口值访问结构体字段
  - 允许通过接口值访问底层结构体的字段（如 `interface_value.field`）
  - 需要运行时类型信息或编译期类型擦除支持
  - 示例：`const writer: IWriter = console; const fd: i32 = writer.fd;`（访问底层 Console 的 fd 字段）
- **接口组合**：接口可以组合其他接口
  - 支持接口组合语法，一个接口可以包含其他接口的方法
  - **语法**：在接口体中直接列出被组合的接口名，用分号分隔（如 `IReader; IWriter;`）
  - **编译期验证**：编译器在编译期检查结构体是否实现了所有组合接口的方法，验证失败即编译错误
  - 实现接口组合的结构体需要实现所有组合接口的方法，编译器在结构体定义时声明接口时验证
  - **vtable 生成**：组合接口的 vtable 包含所有被组合接口的方法，编译期生成
  - **编译期处理**：接口组合完全在编译期处理，运行时与普通接口相同
  - 示例：
[examples/file_6.uya](./examples/file_6.uya)

### 29.4 AI 友好性增强
- **标准库文档字符串**：注释式或结构化文档
  - 帮助 AI 理解函数用途、参数、返回值
  - 提高代码生成准确性
- **更丰富的错误信息**：详细的错误描述和修复建议
  - 类型错误、作用域错误、语法错误的详细说明
  - 提供修复建议，帮助 AI 和用户快速定位问题

### 29.5 已实现特性
以下特性已实现，详见对应章节：
- ✅ **模块系统**：第 1.5 章 - 模块系统
- ✅ **泛型**：第 24 章 - Uya 泛型增量文档
- ✅ **显式宏**：第 25 章 - Uya 显式宏（可选增量）
- ✅ **sizeof**：第 16 章 - 标准库（内置函数）
- ✅ **alignof**：第 16 章 - 标准库
- ✅ **类型别名**：第 24 章 6.2 节 - 类型别名实现
- ✅ **for 循环**：第 8 章 - for 循环迭代（简化语法：`for obj |v| {}`、`for 0..10 |v| {}`、`for obj |&v| {}`）
- ✅ **运算符简化**：第 10 章 - `try` 关键字用于溢出检查，饱和运算符（`+|`, `-|`, `*|`），包装运算符（`+%`, `-%`, `*%`）
- ✅ **测试单元**：第 28 章 - Uya 测试单元（Test Block）

---

## 附录 A. 完整示例

本附录包含各种语言特性的完整示例代码，这些示例展示了 Uya 语言在实际使用中的常见模式和最佳实践。

### A.1 结构体 + 栈数组 + FFI

[examples/a1_struct_array_ffi.uya](./examples/a1_struct_array_ffi.uya)

编译运行示例：[examples/example_146.txt](./examples/example_146.txt)

---

### A.2 错误处理 + defer/errdefer

[examples/a2_error_handling.uya](./examples/a2_error_handling.uya)

---

### A.3 默认安全并发

[examples/a3_concurrent_safe.uya](./examples/a3_concurrent_safe.uya)

---

### A.4-A.6 其他示例

for循环、切片语法、多维数组的完整示例请参考对应章节。

---

## 附录 B. 未实现/将来

## 术语表

### 核心概念

- **UB (Undefined Behavior)**：未定义行为。在 Uya 语言中，所有 UB 必须被编译期证明为安全，否则编译错误。

- **RAII (Resource Acquisition Is Initialization)**：资源获取即初始化。Uya 语言通过 `drop` 机制实现 RAII，资源在作用域结束时自动释放。

- **FFI (Foreign Function Interface)**：外部函数接口。Uya 语言通过 `extern` 关键字声明和调用 C 函数，实现与 C 代码的互操作。

- **vtable (Virtual Table)**：虚函数表。接口系统使用 vtable 实现动态派发，所有 vtable 在编译期生成，零运行时注册。

### 类型系统

- **错误联合类型 (`!T`)**：表示 `T | Error` 的联合类型，用于函数错误返回。`!i32` 表示返回 `i32` 或 `Error`。

- **原子类型 (`atomic T`)**：语言级原子类型，所有读/写/复合赋值操作自动生成原子指令，零运行时锁。

- **接口值**：16 字节结构体（64位平台），包含 vtable 指针(8B) 和数据指针(8B)，用于动态派发。

- **`usize`**：平台相关的无符号整数类型，用于表示内存地址、数组索引和大小。32位平台为 `u32`（4字节），64位平台为 `u64`（8字节）。

### 编译相关

- **编译期证明**：编译器在编译期验证代码的安全性，证明超时则自动插入运行时检查，确保程序安全。

- **路径敏感分析**：编译器跟踪所有代码路径，分析变量状态和条件分支，建立约束条件。

- **常量折叠**：编译期常量直接求值，溢出/越界立即报错。

- **单态化**：泛型函数/结构体在调用时根据具体类型生成对应的代码，零运行时派发。

### 内存管理

- **栈式数组**：使用 `var buf: [T: N] = [];` 在栈上分配数组，零 GC，生命周期由作用域决定。

- **drop**：资源清理函数，在作用域结束时自动调用，实现 RAII 模式。

- **defer/errdefer**：延迟执行语句，在作用域结束时（或错误返回时）执行清理代码。

### 错误处理

- **`try` 关键字**：错误传播和溢出检查关键字。用于传播错误联合类型的错误，或对算术运算进行溢出检查（溢出时返回 `error.Overflow`）。

- **`catch` 语法**：错误捕获语法，用于处理错误联合类型的返回值。语法形式：`expr catch |err| { statements }` 或 `expr catch { statements }`。

- **预定义错误**：使用 `error ErrorName;` 在顶层声明的错误类型，属于全局命名空间，可在多个模块间共享。

- **运行时错误**：使用 `error.ErrorName` 语法直接创建的错误，无需预先声明，编译器在编译期自动收集。

### 并发

- **原子操作**：硬件级原子指令，保证操作的原子性，无需锁。

- **数据竞争**：多个线程同时访问同一内存位置，且至少有一个是写操作。Uya 语言通过 `atomic T` 消除数据竞争。

### 其他

- **`Self`**：接口方法签名和结构体方法签名中的特殊占位符，代表当前结构体类型。在接口定义和结构体方法的方法签名中使用。

- **`max/min` 关键字**：访问整数类型极值的语言关键字。编译器从上下文类型自动推断极值类型，这些是编译期常量。例如：`const MAX: i32 = max;`（`max` 从类型注解 `i32` 推断为 i32 的最大值）。

- **饱和运算符**：`+|`（饱和加法）、`-|`（饱和减法）、`*|`（饱和乘法）。溢出时返回类型的最大值或最小值（上溢返回最大值，下溢返回最小值），而不是返回错误。

- **编译期展开**：某些操作在编译期完成。例如字符串插值的缓冲区大小计算、`try` 关键字的溢出检查展开。

- **编译期证明**：编译器在当前函数内验证安全性，证明超时则自动插入运行时检查。常量错误仍然直接报错。

---

