# Uya 语言规范 1.6（完整版 · 2025-12-31）

> 零GC · 默认高级安全 · 单页纸可读完 · 通过路径零指令  
> 无lifetime符号 · 无隐式控制

---

## 目录

- [1.6 核心特性](#16-核心特性)
- [设计哲学](#设计哲学)
- [1. 文件与词法](#1-文件与词法)
- [1.5 模块系统（v1.4）](#15-模块系统v14)
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
- [13. 原子操作（0.15 终极简洁）](#13-原子操作015-终极简洁)
- [14. 内存安全（0.15 强制）](#14-内存安全015-强制)
- [15. 并发安全（0.15 强制）](#15-并发安全015-强制)
- [16. 标准库（0.15 最小集）](#16-标准库015-最小集)
- [17. 完整示例：结构体 + 栈数组 + FFI](#17-完整示例结构体--栈数组--ffi)
- [18. 完整示例：错误处理 + defer/errdefer](#18-完整示例错误处理--defererrdefer)
- [19. 完整示例：默认安全并发](#19-完整示例默认安全并发)
- [20. 完整示例：for循环迭代](#20-完整示例for循环迭代)
- [21. 完整示例：切片语法](#21-完整示例切片语法)
- [22. 完整示例：多维数组](#22-完整示例多维数组)
- [23. 字符串与格式化（1.6）](#23-字符串与格式化16)
- [24. Uya 1.6 泛型增量文档（可选特性）](#24-uya-16-泛型增量文档向后-100-兼容零新关键字)
- [25. Uya 1.6 显式宏（可选增量）](#25-uya-16-显式宏可选增量)
- [26. 一句话总结](#26-一句话总结)
- [27. 指针算术（1.6 版本新增）](#27-指针算术16-版本新增)
- [28. Uya 1.6 测试单元（Test Block）](#28-uya-16-测试单元test-block)
- [29. 未实现/将来](#29-未实现将来)
- [术语表](#术语表)

---

## 1.6 核心特性

- **原子类型**（第 13 章）：`atomic T` 关键字，自动原子指令，零运行时锁
- **内存安全强制**（第 14 章）：所有 UB 必须被编译期证明为安全，失败即编译错误
- **并发安全强制**（第 15 章）：零数据竞争，通过路径零指令
- **字符串插值**（第 23 章）：支持 `"a${x}"` 和 `"pi=${pi:.2f}"` 两种形式
- **安全指针算术**（第 27 章）：支持 `ptr +/- offset`，必须通过编译期证明安全
- **模块系统**（第 1.5 章）：目录级模块、显式导出、路径导入，编译期解析，零运行时开销
- **简化 for 循环语法**（第 8 章）：支持 `for obj |v| {}`、`for 0..10 |v| {}`、`for obj |&v| {}` 等简化语法
- **运算符简化**（第 10 章）：`try` 关键字用于溢出检查，`+|`/`-|`/`*|` 用于饱和运算，`+%`/`-%`/`*%` 用于包装运算

---

## 1.6 版本变更（相对于 1.5）

### 1.5 新增特性（保留历史记录）
- **sizeof 和 alignof**：标准库函数，用于获取类型大小和对齐，编译期常量，零运行时开销
  - 位置：`std/mem.uya`
  - 使用：`use std.mem.{sizeof, alignof};`
  - 支持所有基础类型、数组、结构体、原子类型等

### 语法简化
- **for 循环语法简化**：
  - 移除 `iter()` 和 `range()` 函数，直接支持 `for obj |v| {}` 和 `for 0..10 |v| {}`
  - 新增可修改迭代语法：`for obj |&v| {}`（用于修改数组元素）
  - 支持丢弃元素语法：`for obj {}` 和 `for 0..N {}`（只循环次数，不绑定变量）

- **运算符简化**：
  - 移除 `checked_*` 函数，使用 `try` 关键字进行溢出检查（如 `try a + b`）
  - 移除 `saturating_*` 函数，使用饱和运算符（`+|`, `-|`, `*|`）
  - 移除 `wrapping_*` 函数，使用包装运算符（`+%`, `-%`, `*%`）

### 向后兼容性
- 所有 0.13 代码保持兼容（语法变更不影响现有代码）
- 新语法完全可选，可以继续使用原有方式

---

## 设计哲学

### 核心思想：坚如磐石

Uya语言的设计哲学是**坚如磐石**（绝对可靠、不可动摇），将所有运行时不确定性转化为编译期的确定性结果：要么证明绝对安全，要么返回显式错误。

**核心机制**：
- 程序员提供**显式证明**，编译器验证证明的正确性
- 编译器在编译期完成所有安全验证，无法证明安全即编译错误
- 每个操作都有明确的**数学证明**，消除任何运行时不确定性
- 零运行时未定义行为，程序行为完全可预测

**示例**：

```uya
// Uya：程序员提供证明，编译器验证证明
const arr: [i32; 10] = [0; 10];
const i: i32 = get_index();
if i < 0 || i >= 10 {
    return error.OutOfBounds;  // 显式检查，返回错误
}
const x: i32 = arr[i];  // 编译器证明 i >= 0 && i < 10，安全
```

> **注**：如需了解 Uya 与其他语言的对比，请参阅 [COMPARISON.md](./COMPARISON.md)

### 结果与收益

Uya的"坚如磐石"设计哲学带来以下不可动摇的收益：

1. **绝对的安全性**：通过数学证明彻底消除缓冲区溢出、空指针解引用等内存安全漏洞
2. **完全的可预测性**：程序行为在编译期完全确定，无任何运行时未定义行为
3. **最优的性能**：开发者编写显式安全检查，编译器在编译期验证其充分性，通过路径消除所有运行时安全检查，仅保留必要的错误处理逻辑
4. **明确的错误处理**：可能失败的操作返回错误联合类型`!T`，强制显式错误处理
5. **长期的可维护性**：代码行为清晰可预测，减少调试和维护成本

**性能保证**：

```uya
// Uya：开发者编写显式检查，编译器验证，通过路径零运行时开销
fn safe_access(arr: [i32; 10], i: i32) !i32 {
    if i < 0 || i >= 10 {
        return error.OutOfBounds;  // 显式错误处理
    }
    // 编译器证明：当执行到这里时，i >= 0 && i < 10 必然成立
    return arr[i];  // 直接访问，无运行时边界检查
}
// 生成的代码：
//   cmp   rdi, 0                 // 运行时错误检查
//   jl    .error_out_of_bounds
//   cmp   rdi, 10                // 运行时错误检查
//   jge   .error_out_of_bounds
//   mov   eax, [rsi + rdi*4]     // 直接访问，无额外运行时检查
//   ret
// .error_out_of_bounds:
//   mov   rax, error.OutOfBounds
//   ret
```

**关键说明**：
- 错误路径保留显式检查，确保安全
- 通过路径（正常执行路径）无任何安全检查，实现成功路径零开销
- 编译器自动消除冗余检查，只保留必要的错误处理逻辑


### 一句话总结

> **Uya 的设计哲学 = 坚如磐石 = 程序员提供证明，编译器验证证明，运行时绝对安全**；  
> **将运行时的不确定性转化为编译期的确定性，成功路径零运行时开销，失败路径显式处理。**

---

## 1 文件与词法

- 文件编码 UTF-8，Unix 换行 `\n`。
- **模块系统**：每个目录自动成为一个模块，详见[第 1.5 章](#15-模块系统v14)。
  - 项目根目录（包含 `main` 函数的目录）是 `main` 模块
  - 子目录路径映射到模块路径（如 `std/io/` → `std.io`）
  - 目录下的所有 `.uya` 文件都属于同一个模块
- 关键字保留：
  ```
  struct const var fn return extern true false if while break continue
  defer errdefer try catch error null interface impl atomic max min
  export use
  ```
- 标识符 `[A-Za-z_][A-Za-z0-9_]*`，区分大小写。
- 数值字面量：
  - 整数字面量：`123`（默认类型 `i32`，除非上下文需要其他整数类型）
  - 浮点字面量：`123.456`（默认类型 `f64`，除非上下文需要 `f32`）
- 布尔字面量：`true`、`false`，类型为 `bool`
- 空指针字面量：`null`，类型为 `byte*`
  - 用于与 `byte*` 类型比较，表示空指针：`if ptr == null { ... }`
  - 可以作为 FFI 函数参数（如果函数接受 `byte*`）：`some_function(null);`
  - 0.13 不支持将 `null` 赋值给 `byte*` 类型的变量（后续版本可能支持）
- 字符串字面量：
  - **普通字符串字面量**：`"..."`，类型为 `byte*`（FFI 专用类型，不是普通指针）
    - **重要说明**：`byte*` 是专门用于 FFI（外部函数接口）的特殊类型，表示 C 字符串指针（null 终止）
    - `byte*` 与普通指针类型 `&T` 不同：`byte*` 仅用于 FFI 上下文，不能进行指针运算或解引用
    - 支持转义序列：`\n` 换行、`\t` 制表符、`\\` 反斜杠、`\"` 双引号、`\0` null 字符
    - 0.13 不支持 `\xHH` 或 `\uXXXX`（后续版本支持）
    - 字符串字面量在 FFI 调用时自动添加 null 终止符
    - **字符串字面量的使用规则**：
      - ✅ 可以作为 FFI 函数调用的参数：`printf("hello\n");`
      - ✅ 可以作为 FFI 函数声明的参数类型示例：`extern i32 printf(byte* fmt, ...);`
      - ✅ 可以与 `null` 比较（如果函数返回 `byte*`）：`if ptr == null { ... }`
      - ❌ 不能赋值给变量：`const s: byte* = "hello";`（编译错误）
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
    - 格式说明符 `spec` 与 C printf 保持一致，[详见第 23 章](#23-字符串与格式化012)
    - 编译期展开为定长栈数组，零运行时解析开销，零堆分配
    - 示例：`const msg: [i8; 64] = "hex=${x:#06x}, pi=${pi:.2f}\n";`
- 数组字面量：
  - 列表式：`[expr1, expr2, ..., exprN]`（元素数量必须等于数组大小）
  - 重复式：`[value; N]`（value 重复 N 次，N 为编译期常量）
  - 数组字面量的所有元素类型必须完全一致
  - 元素类型必须与数组声明类型匹配（0.13 不支持类型推断）
  - 示例：`const arr: [f32; 4] = [1.0, 2.0, 3.0, 4.0];`（元素类型 `f32` 必须与数组元素类型 `f32` 完全匹配）
- 注释 `// 到行尾` 或 `/* 块 */`（可嵌套）。

---

## 1.5 模块系统（v1.4）

### 1.5.1 设计目标

- **目录级模块系统**：每个目录自动成为一个模块
- **显式导出机制**：使用 `export` 关键字标记可导出的项
- **路径式导入**：使用 `use` 关键字和路径语法导入模块
- **编译期解析，成功路径零运行时开销**：所有模块解析在编译期完成

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
- **v1.4 限制**：不支持 `mod` 关键字（块级模块），仅支持目录级模块，符合零新关键字哲学

### 1.5.3 导出机制

- 使用 `export` 关键字标记可导出的项
- 语法：`export fn`, `export struct`, `export interface`, `export const`, `export error`
- **FFI 导出**：
  - `export extern` 用于导出 C FFI 函数：`export extern i32 printf(byte* fmt, ...);`
  - `export extern` 用于导出 C 结构体（如果支持）：`export extern struct CStruct { ... };`
  - **FFI 结构体类型限制**：
    - FFI 导出的结构体字段类型必须为 C 兼容类型（`i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`, `f32`, `f64`, `bool`, `byte*`）
    - 不支持嵌套结构体、接口、错误联合类型等非 C 兼容类型
    - 确保运行时/ABI 兼容性
  - 导出后，其他模块可以通过 `use` 导入并使用这些 FFI 函数/结构体
- 未标记 `export` 的项仅在模块内可见
- **为什么使用 `export` 而不是 `pub`**：
  - `export` 语义更明确，专门用于模块导出
  - `pub` 通常表示"公开可见性"（public vs private），概念更通用
  - Uya 选择 `export` 以强调模块间的导出关系，语义更清晰

### 1.5.4 导入机制

- 使用 `use` 关键字导入模块
- 路径语法：`use math.utils;` 或 `use math.utils.add;`
- 支持别名：`use math.utils as math_utils;`
- **v1.4 限制**：不支持通配符导入（`use math.*;`），避免命名污染和可读性下降
- **模块间引用规则**：
  - 根目录模块（main）可以引用子目录模块：`use std.io;`
  - 子目录模块可以引用其他子目录模块：`use std.io;`
  - **子目录引用 main 模块的处理方式**（参考 Zig 的设计）：
    - **允许但检测循环依赖**（推荐，类似 Zig）：
      - 允许子目录模块引用 main 模块：`use main.helper;`
      - 编译器在编译期检测循环依赖并报错
      - 程序员需要手动打破循环（将共享功能提取到独立模块）
      - 示例：如果 `main.uya` 引用 `std.io`，`std.io` 引用 `main.helper`，编译器检测到循环并报错
- 所有模块引用都是显式的，需要通过 `use` 导入
- **导入后的使用方式**：
  - **导入整个模块**：`use main;` 或 `use std.io;`
    - 使用模块中的导出项时，需要加上模块名前缀：`main.helper_func()` 或 `std.io.read_file()`
    - 示例：
      ```uya
      use main;
      use std.io;
      
      fn example() void {
          main.helper_func();      // 调用 main 模块的函数
          const file: std.io.File = std.io.open_file("test.txt");  // 使用 std.io 模块的结构体
      }
      ```
  - **导入特定项**：`use main.helper_func;` 或 `use std.io.read_file;`
    - 导入后可以直接使用，无需模块名前缀
    - 示例：
      ```uya
      use main.helper_func;
      use std.io.read_file;
      use std.io.File;
      
      fn example() void {
          helper_func();           // 直接调用，无需 main. 前缀
          const file: File = read_file("test.txt");  // 直接使用，无需 std.io. 前缀
      }
      ```
  - **导入结构体/接口**：`use std.io.File;` 或 `use std.io.IWriter;`
    - 导入后可以直接使用类型名，无需模块名前缀
    - 示例：
      ```uya
      use std.io.File;
      use std.io.IWriter;
      
      fn example() void {
          const f: File = File{ fd: 1 };  // 直接使用 File 类型
          const w: IWriter = ...;         // 直接使用 IWriter 接口
      }
      ```
  - **使用别名导入**：`use std.io as io;`
    - 使用别名时，需要用别名作为前缀
    - 示例：
      ```uya
      use std.io as io;
      
      fn example() void {
          io.read_file("test.txt");     // 使用别名 io 作为前缀
          const f: io.File = io.File{ fd: 1 };
      }
      ```
  - **混合使用**：可以同时导入整个模块和特定项
    - 示例：
      ```uya
      use main;                    // 导入整个 main 模块
      use main.helper_func;       // 同时导入特定函数（可以直接使用）
      
      fn example() void {
          helper_func();           // 直接使用（来自特定导入）
          main.other_func();       // 使用模块前缀（来自整体导入）
      }
      ```

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
- **v1.4 限制**：不支持显式指定项目根目录（如通过 `-root` 编译选项），未来版本可能支持
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
  ```
  project/                 (项目根目录，包含 main 函数)
    main.uya               (main 模块，包含 fn main() i32)
    helper.uya             (main 模块)
    std/
      io/
        file.uya           (std.io 模块)
    math/
      utils/
        calc.uya           (math.utils 模块)
  ```

### 1.5.7 限制和说明

- **循环依赖处理**（参考 Zig 的设计）：
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
  - **v1.4 明确不支持模块初始化**（如 `init` 函数）
  - 保持"零运行时开销"承诺，所有模块解析在编译期完成
- **编译期解析规则**：
  - 所有模块路径在编译期解析，零运行时开销
  - 模块依赖关系在编译期构建，用于循环依赖检测
- 与现有特性的兼容性
- 模块路径必须相对于项目根目录（包含 main 函数的目录）

### 1.5.8 完整示例

#### 示例 1：基础模块定义和导出

```uya
// project/main.uya (main 模块)
export fn helper_func() i32 {
    return 42;
}

fn private_func() i32 {
    return 0;  // 未 export，仅在 main 模块内可见
}

// project/std/io/file.uya (std.io 模块)
use main.helper_func;  // 导入 main 模块的函数

export struct File {
    fd: i32
}

export fn open_file(path: byte*) !File {
    // 使用导入的函数
    const value: i32 = helper_func();
    return File{ fd: 1 };
}
```

#### 示例 2：多文件同模块

```uya
// project/std/io/file.uya (std.io 模块)
export struct File {
    fd: i32
}

export fn open_file(path: byte*) !File {
    return File{ fd: 1 };
}

// project/std/io/print.uya (std.io 模块，同一模块)
use std.io.File;  // 可以使用同模块的其他文件导出的项

export fn print_file_info(f: File) void {
    printf("File fd: %d\n", f.fd);
}
```

#### 示例 3：FFI 导出和导入

```uya
// project/std/io/stdio.uya (std.io 模块)
export extern i32 printf(byte* fmt, ...);

// project/main.uya (main 模块)
use std.io.printf;

fn main() i32 {
    printf("Hello from main module\n");
    return 0;
}
```

#### 示例 4：避免循环依赖

```uya
// project/common/helper.uya (common 模块)
export fn helper_func() i32 {
    return 42;
}

// project/main.uya (main 模块)
use common.helper_func;
use std.io;

fn main() i32 {
    const value: i32 = helper_func();
    return 0;
}

// project/std/io/file.uya (std.io 模块)
use common.helper_func;  // 使用 common 模块，而不是 main 模块

export fn read_file() i32 {
    return helper_func();
}
```

#### 示例 5：使用别名导入

```uya
// project/main.uya
use std.io as io;

fn main() i32 {
    const file: io.File = io.open_file("test.txt");
    return 0;
}
```

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
| `byte*`         | 4/8 B（平台相关） | 用于 FFI 函数参数和返回值，指向 C 字符串；32位平台=4B，64位平台=8B；可与 `null` 比较（空指针）|
| `&T`            | 8 B       | 无 lifetime 符号，见下方说明 |
| `&atomic T`  | 8 B       | 原子指针，关键字驱动，[见第 13 章](#13-原子操作012-终极简洁) |
| `atomic T`      | sizeof(T) | 语言级原子类型，[见第 13 章](#13-原子操作012-终极简洁) |
| `[T; N]`        | N·sizeof(T) | N 为编译期正整数，对齐 = T 的对齐 |
| `[[T; N]; M]`   | M·N·sizeof(T) | 多维数组，M 和 N 为编译期正整数，对齐 = T 的对齐 |
| `struct S { }`  | 字段顺序布局 | 对齐 = 最大字段对齐，见下方说明 |
| `interface I { }` | 16 B (64位) | vtable 指针(8B) + 数据指针(8B)，[见第 6 章接口](#6-接口interface) |
| `extern` 函数   | C 函数声明    | -         | 0.13 不支持函数指针类型，`extern` 仅用于声明外部 C 函数，[见 5.2](#52-外部-c-函数ffi) |
| `!T`            | 错误联合类型  | max(sizeof(T), sizeof(错误标记)) + 对齐填充 | `T | Error`，见下方说明 |

- 无隐式转换；支持安全指针算术（见第 27 章）；无 lifetime 符号。

**多维数组类型说明**：
- **声明语法**：`[[T; N]; M]` 表示 M 行 N 列的二维数组，类型为 `T`
  - `T` 是元素类型（如 `i32`, `f32` 等）
  - `N` 是列数（内层维度），必须是编译期正整数
  - `M` 是行数（外层维度），必须是编译期正整数
  - 更高维度的数组可以继续嵌套：`[[[T; N]; M]; K]` 表示三维数组
- **内存布局**：多维数组在内存中按行优先顺序存储（row-major order），与 C 语言一致
  - 二维数组 `[[T; N]; M]` 的内存布局：`[row0_col0, row0_col1, ..., row0_colN-1, row1_col0, ..., rowM-1_colN-1]`
  - 大小计算：`M * N * sizeof(T)` 字节
  - 对齐规则：对齐值 = `T` 的对齐值
- **访问语法**：使用多个索引访问多维数组元素
  - 二维数组：`arr[i][j]` 访问第 i 行第 j 列的元素
  - 三维数组：`arr[i][j][k]` 访问第 i 层第 j 行第 k 列的元素
- **边界检查**：所有维度的索引都需要编译期证明安全
  - 对于 `arr[i][j]`，必须证明 `i >= 0 && i < M && j >= 0 && j < N`
  - 证明失败 → 编译错误
- **示例**：
  ```uya
  // 声明 3x4 的 i32 二维数组
  const matrix: [[i32; 4]; 3] = [[0; 4]; 3];
  
  // 使用数组字面量初始化
  const matrix2: [[i32; 4]; 3] = [
      [1, 2, 3, 4],
      [5, 6, 7, 8],
      [9, 10, 11, 12]
  ];
  
  // 访问元素（需要边界检查证明）
  const value: i32 = matrix2[0][1];  // 访问第0行第1列，值为 2
  ```

**类型相关的极值常量**：
- 整数类型（`i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`）支持通过 `max` 和 `min` 关键字访问极值
- 语法：`max` 和 `min`（编译器从上下文类型推断）
- 编译器根据上下文类型自动推断极值类型，这些是编译期常量，零运行时开销
- 示例：
  ```uya
  const MAX: i32 = max;  // 2147483647（从类型注解 i32 推断）
  const MIN: i32 = min;  // -2147483648（从类型注解 i32 推断）
  
  // 在溢出检查中使用（从变量类型推断）
  const a: i32 = ...;
  const b: i32 = ...;
  if a > 0 && b > 0 && a > max - b {  // 从 a 和 b 的类型 i32 推断
      return error.Overflow;
  }
  ```

**指针类型说明**：
- `byte*`：专门用于 FFI，表示 C 字符串指针（null 终止），只能用于：
  - FFI 函数参数和返回值类型声明
  - 与 `null` 比较（空指针检查）
  - 字符串字面量在 FFI 调用时自动转换为 `byte*`
  - 0.13 不支持将 `byte*` 赋值给变量或进行其他操作
- `&T`：普通指针类型，8 字节（64位平台），无 lifetime 符号
  - 用于指向类型 `T` 的值
  - 空指针检查：`if ptr == null { ... }`（需要显式检查，编译期证明失败即编译错误）
  - 0.13 支持安全指针算术（见第 27 章）
- `&atomic T`：原子指针类型，8 字节，关键字驱动
  - 用于指向原子类型 `atomic T` 的指针
  - [见第 13 章原子操作](#13-原子操作012-终极简洁)
- `*T`：仅用于接口方法签名，表示指针参数，不能用于普通变量声明或 FFI 函数声明
  - **语法规则**：
    - `*T` 语法仅在接口定义和 `impl` 块的方法签名中使用
    - `*T` 表示指向类型 `T` 的指针参数（按引用传递，但语法使用 `*` 前缀）
    - 与 `&T` 的区别：`&T` 用于普通变量和函数参数，`*T` 仅用于接口方法签名
  - **示例**：接口方法 `fn write(self: *Self, buf: *byte, len: i32)` 中：
    - `*Self` 表示指向实现接口的结构体类型的指针（`Self` 是占位符，编译期替换为具体类型）
    - `*byte` 表示指向 `byte` 类型的指针参数
  - **FFI 调用规则**：接口方法内部调用 FFI 函数时，参数类型应使用 `byte*`（FFI 语法），而不是 `*byte`（接口语法）
  - 0.13 仅支持 `*T` 语法（不支持 `T*`）
  - 接口方法调用时，`self` 参数自动传递（无需显式传递）

**错误类型和错误联合类型**：

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

---

## 3 变量与作用域

```uya
const x: i32 = 10;        // 函数内局部变量，不可变
var i: i32 = 0;     // 可变变量，可重新赋值
const arr: [f32; 4] = [1.0, 2.0, 3.0, 4.0];
i = i + 1;              // 只有 var 变量可赋值
```

- 初始化表达式类型必须与声明完全一致。
- `const` 声明的变量**不可变**；使用 `var` 声明可变变量。
- 可变变量可重新赋值；不可变变量赋值会编译错误。
- **常量变量**：使用 `const NAME: Type = value;` 声明编译期常量
  - 常量必须在编译期求值
  - 常量可在编译期常量表达式中使用（如数组大小 `[T; SIZE]`）
  - 常量不可重新赋值
  - `const` 常量可以在顶层或函数内声明
  - `const` 常量可以作为数组大小：`const N: i32 = 10; const arr: [i32; N] = ...;`
- **编译期常量表达式**：
  - 字面量：整数、浮点、布尔、字符串
  - 常量变量：`const NAME`
  - 算术运算：`+`, `-`, `*`, `/`, `%`（如果操作数都是常量）
  - 位运算：`&`, `|`, `^`, `~`, `<<`, `>>`（如果操作数都是常量）
  - 比较运算：`==`, `!=`, `<`, `>`, `<=`, `>=`（如果操作数都是常量）
  - 逻辑运算：`&&`, `||`, `!`（如果操作数都是常量）
  - 不支持：函数调用、变量引用（非常量）、数组/结构体字面量（0.13）
- **类型推断**：0.13 不支持类型推断，所有变量必须显式类型注解
- **变量遮蔽**：
  - 同一作用域内不能有同名变量
  - 内层作用域可以声明与外层作用域同名的变量（遮蔽外层变量）
  - 离开内层作用域后，外层变量重新可见
- 作用域 = 最近 `{ }`；离开作用域按字段逆序调用 `drop(T)`（RAII）。

---

## 4 结构体

```uya
struct Vec3 {
  x: f32,
  y: f32,
  z: f32
}

const v: Vec3 = Vec3{ x: 1.0, y: 2.0, z: 3.0 };
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
- **多维数组字段**：结构体字段可以是多维数组
  - 声明示例：`struct Matrix { data: [[f32; 4]; 4] }`（4x4 矩阵）
  - 访问语法：`struct_var.array_field[i][j]`（如果字段是多维数组）
  - 所有维度的索引都需要边界检查证明
  - 示例：
    ```uya
    struct Mat3x4 {
        data: [[f32; 4]; 3]  // 3行4列的矩阵
    }
    
    const mat: Mat3x4 = Mat3x4{
        data: [
            [1.0, 2.0, 3.0, 4.0],
            [5.0, 6.0, 7.0, 8.0],
            [9.0, 10.0, 11.0, 12.0]
        ]
    };
    
    // 访问多维数组字段（需要边界检查证明）
    if i >= 0 && i < 3 && j >= 0 && j < 4 {
        const value: f32 = mat.data[i][j];  // 编译器证明安全
    }
    ```
- 访问链可以任意嵌套：`struct_var.field1.array_field[i].subfield`
- **数组边界检查**（适用于所有数组访问）：0.13 强制编译期证明
  - 常量索引越界 → **编译错误**
  - 变量索引 → 必须证明 `i >= 0 && i < len`，证明失败 → **编译错误**
  - 零运行时检查，通过路径零指令
- **切片语法**（新增）：支持切片语法 `arr[start:len]`
  - **操作符语法**：`arr[start:len]` 返回从索引 `start` 开始，长度为 `len` 的元素组成的数组切片
  - **负数索引**：支持负数索引，`-1` 表示最后一个元素，`-n` 表示倒数第 n 个元素
    - 例如：`arr[-3:3]` 表示从倒数第3个元素开始，长度为3的切片
    - 例如：`arr[-5:2]` 表示从倒数第5个元素开始，长度为2的切片
  - **切片边界检查**：编译期或运行时证明 `start >= -len(arr) && start < len(arr) && len >= 0 && start + len <= len(arr)`
    - 如果使用负数索引，编译器会自动转换为正数索引：`-n` 转换为 `len(arr) - n`
    - 例如：`arr[-3:3]` 对于长度为10的数组，-3转换为7，验证 `7 >= 0 && 7 < 10 && 3 >= 0 && 7 + 3 <= 10`
  - **切片结果类型**：切片操作返回一个新的数组，类型为 `[T; M]`，其中 M = len（切片长度）
  - **零运行时开销**：切片操作在编译期验证安全，运行时直接访问内存，无额外开销
- **字段可变性**：只有 `var` 结构体变量才能修改其字段
  - `const s: S = ...` 时，`s.field = value` 会编译错误
  - `var s: S = ...` 时，可以修改 `s.field`
  - 字段可变性由外层变量决定，不支持字段级可变性标记
  - **嵌套结构体示例**：
    ```uya
    struct Inner { x: i32 }
    struct Outer { inner: Inner }
    
    // ✅ 可以修改的情况
    var outer: Outer = Outer{ inner: Inner{ x: 10 } };
    outer.inner.x = 20;  // ✅ 可以修改，因为 outer 是 var
    
    // ❌ 不能修改的情况
    const outer: Outer = Outer{ inner: Inner{ x: 10 } };
    outer.inner.x = 20;  // ❌ 编译错误：outer 不是 var，无法修改字段
    ```
- **结构体初始化**：必须提供所有字段的值，不支持部分初始化或默认值

---

## 5 函数

### 5.1 普通函数

```uya
fn add(a: i32, b: i32) i32 {
  return a + b;
}

fn print_hello() void {
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
- **函数指针**：0.13 不支持函数指针类型，函数名不能作为值传递或存储，仅支持直接函数调用
- **变参函数调用**：参数数量必须与 C 函数声明匹配（编译期检查有限）
- **程序入口点**：必须定义 `fn main() i32`（程序退出码）
  - 0.13 不支持命令行参数（后续版本支持 `main(argc: i32, argv: byte**)`）
- **`return` 语句**：
  - `return expr;` 用于有返回值的函数
  - `return;` 用于 `void` 函数（可省略）
  - `return error.ErrorName;` 用于返回错误（错误联合类型函数）
  - `return` 语句后的代码不可达
  - 函数末尾的 `return` 可以省略（如果返回类型是 `void`）

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
      ```uya
      const result: i32 = divide(10, 0) catch |err| {
          printf("Error: %d\n", err);
          0  // 返回默认值，result = 0
      };
      // result 的类型是 i32（不是 !i32），值为 0
      ```
    
    **方式 2：使用 `return` 提前返回函数**（catch 块直接退出函数）
    - catch 块中使用 `return` 会**立即返回函数**（不是返回 catch 块的值）
    - 跳过后续所有 defer 和 drop
    - 示例：
      ```uya
      fn main() i32 {
          const result: i32 = read_file("test.txt") catch |err| {
              printf("Failed to read file\n");
              return 1;  // 直接退出 main 函数，返回 1（跳过后续所有代码）
          };
          // 如果 read_file 成功，继续执行这里
          printf("Read %d bytes\n", result);
          return 0;
      }
      ```
    
    **重要区别**：
    - 表达式返回值：catch 块返回一个值，程序继续执行
    - `return` 语句：catch 块直接退出函数，程序不继续执行
- **错误处理**（0.13）：
  - 0.13 支持**错误联合类型** `!T` 和 **try/catch** 语法，用于函数错误返回
  - 函数可以返回错误联合类型：`fn foo() !i32` 表示返回 `i32` 或 `Error`
  - 使用 `try` 关键字传播错误：`const result: i32 = try divide(10, 2);`
  - 使用 `catch` 语法捕获错误：`const result: i32 = divide(10, 0) catch |err| { ... };`
  - **无运行时 panic 路径**：所有 UB 必须被编译期证明为安全，失败即编译错误
  - **灵活错误定义**：支持预定义错误（`error ErrorName;`）和运行时错误（`error.ErrorName`），无需预先声明
- **错误类型的操作**：
  - 错误类型支持相等性比较：`if err == error.FileNotFound { ... }` 或 `if err == error.SomeRuntimeError { ... }`
  - 错误类型不支持不等性比较（0.13 仅支持 `==`）
  - catch 块中可以判断错误类型并做不同处理
  - 错误类型不能直接打印，需要通过模式匹配处理
  - 支持预定义错误和运行时错误的混合比较：`if err == error.PredefinedError || err == error.RuntimeError { ... }`
  
**错误处理设计哲学**（0.13）：
- **零开销抽象**：错误处理是编译期检查，零运行时开销（非错误路径）
- **显式错误**：错误是类型系统的一部分，必须显式处理
- **编译期检查**：编译器确保所有错误都被处理
- **无 panic、无断言**：所有 UB 必须被编译期证明为安全，失败即编译错误

**错误处理与内存安全的关系**（0.13）：
- **`try`/`catch` 只用于函数错误返回**，不用于捕获 UB
- **所有 UB 必须被编译期证明为安全**，失败即编译错误，不生成代码
- 错误处理用于处理可预测的、显式的错误情况（如文件不存在、网络错误等）

**示例：错误处理**：
```uya
// ✅ 使用错误联合类型处理可预测错误
fn safe_divide(a: i32, b: i32) !i32 {
    if b == 0 {
        return error.DivisionByZero;  // 显式检查，返回预定义错误
    }
    return a / b;
}

// ✅ 使用运行时错误（无需预定义）
fn safe_divide_runtime(a: i32, b: i32) !i32 {
    if b == 0 {
        return error.DivisionByZero;  // 仍可使用预定义错误
    }
    if a < 0 {
        return error.NegativeInput;   // 运行时错误，无需预定义
    }
    return a / b;
}

// ✅ 使用 catch 捕获错误
fn main() i32 {
    const result: i32 = safe_divide(10, 0) catch |err| {
        if err == error.DivisionByZero {
            printf("Division by zero\n");
        }
        return 1;  // 提前返回函数
    };
    printf("Result: %d\n", result);

    // 使用运行时错误
    const result2: i32 = safe_divide_runtime(-5, 2) catch |err| {
        if err == error.NegativeInput {
            printf("Negative input not allowed\n");
        }
        return 1;
    };
    printf("Result2: %d\n", result2);

    return 0;
}
```

### 5.2 外部 C 函数（FFI）

**步骤 1：顶层声明**  
```uya
extern i32 printf(byte* fmt, ...);   // 变参
extern f64 sin(f64);
```

**步骤 2：正常调用**  
```uya
const pi: f64 = 3.1415926;
printf("sin(pi/2)=%f\n", sin(pi / 2.0));
```

- 声明必须出现在**顶层**；不可与调用混写在一行。
- 调用生成原生 `call rel32` 或 `call *rax`，**无包装函数**（零开销）。
- 返回后按 C 调用约定清理参数。
- **调用约定**：与目标平台的 C 调用约定一致（如 x86-64 System V ABI 或 Microsoft x64 calling convention），具体由后端实现决定

**重要说明**：
- FFI 函数调用的格式字符串（如 `printf` 的 `"%f"`）是 C 函数的特性，不是 Uya 语言本身的特性
- Uya 语言仅提供 FFI 机制来调用 C 函数，格式字符串的语法和语义遵循 C 标准
- 字符串插值（第 23 章）是 Uya 语言本身的特性，编译期展开，与 FFI 的格式字符串不同

---

## 6 接口（interface）

### 6.1 设计目标

- **鸭子类型 + 动态派发**体验；  
- **零注册表 + 编译期生成**；  
- **标准内存布局 + 单条 call 指令**；  
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
   ```uya
   // ❌ 编译错误：s 的生命周期不足以支撑返回的接口值
   fn example() IWriter {
       const s: Console = Console{ fd: 1 };
       return s;  // 编译错误：s 的生命周期不足
   }
   
   // ✅ 编译通过：返回具体类型，调用者装箱
   fn example() Console {
       return Console{ fd: 1 };
   }
   ```

2. **赋值给外部变量**：
   ```uya
   // ❌ 编译错误：s 的生命周期不足以支撑外部接口值
   fn example() void {
       const s: Console = Console{ fd: 1 };
       var external: IWriter = s;  // 如果 external 生命周期更长，编译错误
   }
   
   // ✅ 编译通过：局部装箱，生命周期匹配
   fn example() void {
       const s: Console = Console{ fd: 1 };
       const local: IWriter = s;  // 局部变量，生命周期匹配
       // 使用 local...
   }
   ```

3. **传递参数**：
   ```uya
   // ✅ 编译通过：参数传递，生命周期由调用者保证
   fn use_writer(w: IWriter) void {
       // 使用 w...
   }
   
   fn example() void {
       const s: Console = Console{ fd: 1 };
       use_writer(s);  // 编译通过：参数传递
   }
   ```

**编译器检查算法**（简化版，0.13 实现）：

Uya 0.13 采用**简化版生命周期检查**，基于作用域层级：

1. **作用域层级定义**（从长到短）：
   - 函数参数作用域（最长）
   - 函数局部变量作用域
   - 内层块变量作用域（最短）

2. **检查规则**：
   - 对于每个接口值赋值/返回/传参操作：
     - 获取底层数据的作用域层级 `S_data`
     - 获取目标位置的作用域层级 `S_target`
     - 如果 `S_data < S_target`（数据作用域更短），则报告编译错误
     - 否则编译通过

3. **检查时机**：
   - 接口值赋值：`const iface: I = concrete;`
   - 接口值返回：`return concrete;`（返回接口类型）
   - 接口值传参：`fn_call(concrete);`（参数类型是接口）

4. **示例分析**：
   ```uya
   fn example() IWriter {
       const s: Console = Console{ fd: 1 };  // s 是局部变量，作用域层级 = 2
       return s;  // 返回接口值，目标作用域层级 = 1（函数参数级别）
       // 检查：2 < 1？是 → 编译错误
   }
   ```

5. **限制说明**（0.13 版本）：
   - 这是简化版检查，不进行复杂的借用分析
   - 主要防止明显的生命周期错误
   - 后续版本会增强检查能力，支持更复杂的场景

### 6.6 接口方法调用

- 接口方法调用语法：`interface_value.method_name(arg1, arg2, ...)`
- `self` 参数自动传递，无需显式传递
- 示例：`w.write(&msg[0], 5);` 中，`w` 是接口值，`write` 方法会自动接收 `self` 参数

### 6.7 完整示例

```uya
// ① 定义接口
interface IWriter {
  fn write(self: *Self, buf: *byte, len: i32) i32;
}

// ② 具体实现
struct Console {
  fd: i32
}

impl Console : IWriter {
  fn write(self: *Self, buf: *byte, len: i32) i32 {
    extern i32 write(i32 fd, byte* buf, i32 len);
    return write(self.fd, buf, len);
  }
}

// ③ 使用接口
fn echo(w: IWriter) void {
  const msg: [byte; 6] = "hello\n";
  w.write(&msg[0], 5);
}

fn main() i32 {
  const cons: Console = Console{ fd: 1 };   // stdout
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
| 无字段接口 | `struct S { w: IWriter }` → ❌ 编译错误（0.13 限制） |
| 无数组/切片接口 | `const arr: [IWriter; 3]` → ❌ |
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
   - 局部：`const iface: I = concrete;`  
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
- 通过接口机制支持 for 循环迭代
- 零运行时开销，编译期生成vtable
- 支持所有实现了迭代器接口的类型

**迭代器接口定义**：

由于 Uya 0.13 没有泛型，迭代器接口需要针对具体元素类型定义。以下以 `i32` 类型为例：

```uya
// 迭代器结束错误（预定义，可选）
error IterEnd;
// 迭代器状态错误（用于value()方法的边界检查，预定义，可选）
error InvalidIteratorState;

// i32数组迭代器接口
interface IIteratorI32 {
    // 移动到下一个元素，返回错误表示迭代结束
    fn next(self: *Self) !void;
    // 获取当前元素值（只读），可能返回错误
    fn value(self: *Self) !i32;
    // 获取指向当前元素的指针（可修改），可能返回错误
    fn ptr(self: *Self) !&i32;
}

// 带索引的i32数组迭代器接口
interface IIteratorI32WithIndex {
    fn next(self: *Self) !void;
    fn value(self: *Self) !i32;  // 可能返回错误
    fn index(self: *Self) i32;
}
```

**数组迭代器实现示例**：

```uya
// i32数组迭代器结构体
struct ArrayIteratorI32 {
    arr: *[i32; N],  // 指向数组的指针
    current: i32,    // 当前索引（从0开始，指向下一个要访问的元素）
    len: i32         // 数组长度
}

impl ArrayIteratorI32 : IIteratorI32 {
    fn next(self: *Self) !void {
        if self.current >= self.len {
            return error.IterEnd;  // 迭代结束
        }
        self.current = self.current + 1;
    }
    
    fn value(self: *Self) !i32 {
        // 编译期证明说明：
        // 1. next() 成功返回意味着：self.current > 0 && self.current <= self.len
        // 2. 因此 idx = current - 1 满足：idx >= 0 && idx < len
        // 3. 编译器通过路径敏感分析可以证明数组访问安全
        const idx: i32 = self.current - 1;
        // 注意：如果编译器能够通过路径敏感分析证明 idx 在有效范围内，
        // 则可以直接访问数组，无需显式检查
        // 如果编译器无法证明（0.13 版本限制），则需要显式检查：
        if idx < 0 || idx >= self.len {
            // 这个检查帮助编译器完成证明
            // 虽然根据 next() 的语义，这个分支理论上不会执行，
            // 但显式检查可以让编译器验证数组访问的安全性
            return error.InvalidIteratorState;
        }
        return (*self.arr)[idx];
    }
    
    fn ptr(self: *Self) !&i32 {
        // 编译期证明说明：同 value() 方法
        const idx: i32 = self.current - 1;
        if idx < 0 || idx >= self.len {
            return error.InvalidIteratorState;
        }
        return &(*self.arr)[idx];  // 返回指向当前元素的指针（可修改）
    }
}

// 带索引的数组迭代器实现
impl ArrayIteratorI32 : IIteratorI32WithIndex {
    fn next(self: *Self) !void {
        if self.current >= self.len {
            return error.IterEnd;
        }
        self.current = self.current + 1;
    }
    
    fn value(self: *Self) !i32 {
        // 编译期证明说明：同 IIteratorI32 接口的 value() 方法
        const idx: i32 = self.current - 1;
        // 显式检查帮助编译器完成证明（见上方说明）
        if idx < 0 || idx >= self.len {
            return error.InvalidIteratorState;
        }
        return (*self.arr)[idx];
    }
    
    fn index(self: *Self) i32 {
        return self.current - 1;  // 返回当前索引（从0开始）
    }
}
```

**使用示例**：

```uya
fn create_iterator(arr: *[i32; 10]) ArrayIteratorI32 {
    return ArrayIteratorI32{
        arr: arr,
        current: 0,
        len: 10
    };
}

fn iterate_example() void {
    const arr: [i32; 5] = [1, 2, 3, 4, 5];
    const iter: IIteratorI32 = create_iterator(&arr);  // 自动装箱为接口
    
    // 手动迭代（for循环会自动展开为类似代码）
    while true {
        const result: void = iter.next() catch |err| {
            if err == error.IterEnd {
                break;  // 迭代结束
            }
            // 其他错误处理...
        };
        const value: i32 = iter.value() catch |err| {
            return;  // 传播错误（如果函数返回错误联合类型）
        };
        // 使用value...
    }
}
```

**设计说明**：
- 迭代器接口遵循 Uya 接口的设计原则：编译期生成vtable，零运行时开销
- 使用错误联合类型 `!void` 表示迭代结束，符合 Uya 的错误处理机制
- 需要为每种元素类型定义对应的迭代器接口（0.13 限制，泛型功能在 0.13 中提供）
- for循环语法会自动使用这些接口进行迭代（[见第8章](#8-控制流)）

### 6.13 一句话总结

> **Uya 接口 = 鸭子派发 + 零注册 + 标准内存布局**；  
> **语法零新增、生命周期零符号、调用零开销**；  
> **今天就能用，明天可放开字段限制**。

---

## 7 栈式数组（零 GC）

```uya
const buf: [f32; 64] = [];   // 64 个 f32 在当前栈帧
```

- **栈数组语法**：使用 `[]` 表示未初始化的栈数组，类型由左侧变量的类型注解确定。
- `[]` 不能独立使用，必须与类型注解一起使用：`var buf: [T; N] = [];`
- **数组初始化**：`[]` 返回的数组**未初始化**（包含未定义值），用户必须在使用前初始化数组元素
  - 初始化示例：
    ```uya
    var buf: [f32; 64] = [];
    // 手动初始化数组元素
    var i: i32 = 0;
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
  - 不支持函数调用（除非是 `const fn`，0.13 暂不支持）
- **语法规则**：
  - `[]` 表示栈分配的未初始化数组
  - 数组大小由类型注解 `[T; N]` 中的 `N` 指定
  - 示例：`var buf: [f32; 64] = [];` 表示分配 64 个 `f32` 的栈数组
- **多维数组初始化**：
  - **未初始化多维数组**：使用嵌套的 `[]` 语法
    ```uya
    // 声明 3x4 的未初始化 i32 二维数组
    var matrix: [[i32; 4]; 3] = [];
    
    // 手动初始化每个元素
    var i: i32 = 0;
    while i < 3 {
        var j: i32 = 0;
        while j < 4 {
            matrix[i][j] = i * 4 + j;  // 需要边界检查证明
            j = j + 1;
        }
        i = i + 1;
    }
    ```
  - **多维数组字面量**：使用嵌套的数组字面量
    ```uya
    // 使用重复式初始化（所有元素相同）
    const matrix1: [[i32; 4]; 3] = [[0; 4]; 3];  // 3x4 的零矩阵
    
    // 使用列表式初始化（指定每个元素）
    const matrix2: [[i32; 4]; 3] = [
        [1, 2, 3, 4],
        [5, 6, 7, 8],
        [9, 10, 11, 12]
    ];
    
    // 混合使用（部分行使用重复式，部分行使用列表式）
    const matrix3: [[i32; 4]; 3] = [
        [1, 2, 3, 4],
        [0; 4],  // 第二行全为0
        [9, 10, 11, 12]
    ];
    ```
  - **多维数组边界检查**：所有维度的索引都需要编译期证明
    - 对于 `matrix[i][j]`，必须证明 `i >= 0 && i < 3 && j >= 0 && j < 4`
    - 常量索引越界 → 编译错误
    - 变量索引无证明 → 编译错误
- 生命周期 = 所在 `{}` 块；返回上层即编译错误（逃逸检测）。
- 后端映射为 `alloca` 或机器栈数组，**零开销**。
- **逃逸检测规则**：`[]` 分配的对象不能：
  - 被函数返回
  - 被赋值给生命周期更长的变量
  - 被传递给可能存储引用的函数

---

## 8 控制流

```uya
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
  - 0.13 不支持 `break label` 或 `continue label`（后续版本支持）
  - `break` 和 `continue` 只能在循环体内使用

- **`for` 循环**：迭代循环，支持可迭代对象和整数范围
  - **语法形式**：
    ```
    for_stmt = 'for' expr '|' ID '|' block          // 有元素变量（只读）
             | 'for' expr '|' '&' ID '|' block       // 有元素变量（可修改）
             | 'for' range_expr '|' ID '|' block     // 整数范围，有元素变量
             | 'for' expr block                      // 丢弃元素，只循环次数
             | 'for' range_expr block                // 整数范围，丢弃元素
    
    range_expr = expr '..' [expr]                     // start..end 或 start..
    ```
    - `range_expr`：整数范围表达式
      - `start..end`：从 `start` 到 `end-1` 的范围（左闭右开区间 `[start, end)`）
      - `start..`：从 `start` 开始的无限范围，由迭代器结束条件终止
  - **基本形式（有元素变量，只读）**：`for obj |v| { statements }`
    - `obj` 必须是实现了迭代器接口的类型（如数组、迭代器）
    - `v` 是循环变量，类型由迭代器的 `value()` 方法返回类型决定
    - `v` 是只读的，不能修改
    - 自动调用迭代器的 `next()` 方法，返回 `error.IterEnd` 时循环结束
  - **基本形式（有元素变量，可修改）**：`for obj |&v| { statements }`
    - `obj` 必须是实现了迭代器接口的类型（如数组、迭代器）
    - `&v` 是循环变量，类型是指向元素的指针（`&T`），可以修改元素
    - 在循环体中可以通过 `*v` 访问元素值，通过 `*v = value` 修改元素
    - 自动调用迭代器的 `next()` 方法，返回 `error.IterEnd` 时循环结束
    - 注意：只有可变数组（`var arr`）才能使用此形式
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
    - 整数范围直接展开为整数循环，零运行时开销
    - 零运行时开销，编译期生成vtable
  - **示例**：
    ```uya
    // 基本迭代（有元素变量，只读）
    const arr: [i32; 5] = [1, 2, 3, 4, 5];
    for arr |item| {
        printf("%d\n", item);
    }
    
    // 基本迭代（有元素变量，可修改）
    var arr2: [i32; 5] = [1, 2, 3, 4, 5];
    for arr2 |&item| {
        *item = *item * 2;  // 修改每个元素，乘以2
        printf("%d\n", *item);
    }
    
    // 整数范围（有元素变量）
    for 0..10 |i| {
        printf("%d\n", i);  // 输出 0 到 9
    }
    
    // 无限范围（有元素变量）
    for 0.. |i| {
        if i >= 10 {
            break;  // 手动终止
        }
        printf("%d\n", i);
    }
    
    // 丢弃元素，只循环次数
    for arr {
        printf("loop\n");  // 执行 5 次
    }
    
    // 整数范围，丢弃元素
    for 0..N {
        printf("loop\n");  // 执行 N 次
    }
    ```
  - **展开规则**：for循环在编译期展开为while循环
    - **可迭代对象展开（有元素变量，只读）**：
      ```uya
      // 原始代码
      for obj |item| {
          // body
      }
      
      // 展开为
      {
          var iter: IIteratorT = obj;  // 自动装箱为接口（T为元素类型）
          while true {
              const result: void = iter.next() catch |err| {
                  if err == error.IterEnd {
                      break;  // 迭代结束，跳出循环
                  }
                  return err;  // 其他错误传播（如果函数返回错误联合类型）
              };
              const item: T = iter.value() catch |err| {
                  return err;  // 传播错误（如果函数返回错误联合类型）
              };  // 获取当前元素（只读）
              // body（可以使用item）
          }
      }
      ```
    - **可迭代对象展开（有元素变量，可修改）**：
      ```uya
      // 原始代码
      for obj |&item| {
          // body（可以修改 *item）
      }
      
      // 展开为
      {
          var iter: IIteratorT = obj;  // 自动装箱为接口（T为元素类型）
          while true {
              const result: void = iter.next() catch |err| {
                  if err == error.IterEnd {
                      break;  // 迭代结束，跳出循环
                  }
                  return err;  // 其他错误传播（如果函数返回错误联合类型）
              };
              const item: &T = iter.ptr() catch |err| {
                  return err;  // 传播错误（如果函数返回错误联合类型）
              };  // 获取指向当前元素的指针（可修改）
              // body（可以使用 *item 访问和修改元素）
              // 例如：*item = new_value; 或 const val: T = *item;
          }
      }
      ```
      - 注意：
        - 迭代器接口需要提供 `ptr()` 方法返回指向当前元素的指针（类型 `&T`）
        - `item` 是指针类型，需要通过 `*item` 访问和修改元素值
        - 只有可变数组（`var arr`）才能使用此形式，常量数组（`const arr`）使用此形式会编译错误
    - **可迭代对象展开（丢弃元素）**：
      ```uya
      // 原始代码
      for obj {
          // body
      }
      
      // 展开为
      {
          var iter: IIteratorT = obj;  // 自动装箱为接口
          while true {
              const result: void = iter.next() catch |err| {
                  if err == error.IterEnd {
                      break;
                  }
                  return err;
              };
              // 不获取元素值，直接执行 body
              // body
          }
      }
      ```
    - **整数范围展开（有元素变量）**：
      ```uya
      // 原始代码
      for 0..10 |i| {
          // body
      }
      
      // 展开为
      {
          var i: i32 = 0;
          while i < 10 {
              // body（可以使用i）
              i = i + 1;
          }
      }
      ```
    - **整数范围展开（丢弃元素）**：
      ```uya
      // 原始代码
      for 0..N {
          // body
      }
      
      // 展开为
      {
          var i: i32 = 0;
          while i < N {
              // body（不绑定变量）
              i = i + 1;
          }
      }
      ```
    - **无限范围展开**：
      ```uya
      // 原始代码
      for 0.. |i| {
          // body
      }
      
      // 展开为
      {
          var i: i32 = 0;
          while true {
              // body（可以使用i）
              i = i + 1;
          }
      }
      ```
    - **展开说明**：
      - 编译器自动识别可迭代类型，并选择合适的迭代器接口
      - 数组类型自动创建对应的数组迭代器（编译器自动生成）
      - 整数范围直接展开为整数循环，零运行时开销
      - 展开后的代码遵循 Uya 的内存安全规则，所有数组访问都有编译期证明
      - 零运行时开销：接口调用是单条call指令，与手写while循环性能相同

- **`match` 表达式/语句**：模式匹配
  - **语法形式**：`match expr { pattern1 => expr, pattern2 => expr, else => expr }`
  - **作为表达式**：match 可以作为表达式使用，所有分支返回类型必须一致
    ```uya
    const result: i32 = match x {
        0 => 10,
        1 => 20,
        else => 30,
    };
    ```
  - **作为语句**：如果所有分支返回 `void`，match 可以作为语句使用
    ```uya
    match status {
        0 => printf("OK\n"),
        1 => printf("Error\n"),
        else => printf("Unknown\n"),
    }
    ```
  - **支持的模式类型**：
    1. **常量模式**：整数、布尔、错误类型常量
       ```uya
       match x {
           0 => expr1,
           1 => expr2,
           true => expr3,
           error.FileNotFound => expr4,
           else => expr5,
       }
       ```
    2. **变量绑定模式**：捕获匹配的值
       ```uya
       match x {
           0 => expr1,
           y => expr2,  // y 绑定到 x 的值
           else => expr3,
       }
       ```
    3. **结构体解构**：匹配并解构结构体字段
       ```uya
       match point {
           Point{ x: 0, y: 0 } => expr1,
           Point{ x: x_val, y: y_val } => expr2,  // 绑定字段
           else => expr3,
       }
       ```
    4. **错误类型匹配**：匹配错误联合类型（支持预定义和运行时错误）
       ```uya
       match result {
           error.FileNotFound => expr1,      // 预定义错误
           error.PermissionDenied => expr2,  // 预定义错误
           error.OutOfMemory => expr3,      // 运行时错误，无需预定义
           value => expr4,  // 成功值绑定
           else => expr5,
       }
       ```
    5. **字符串数组匹配**：匹配 `[i8; N]` 数组（字符串插值的结果）
       ```uya
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
    - 零运行时开销：编译期常量匹配直接展开，无运行时模式匹配引擎
    - 路径零指令：未匹配路径不生成代码
    - 字符串比较：运行时字符串比较使用标准库函数（如 `strcmp` 的等价实现）
  - **完整示例**：
    ```uya
    // 示例 1：整数常量匹配（表达式形式）
    fn classify_score(score: i32) i32 {
        const grade: i32 = match score {
            90 => 5,
            80 => 4,
            70 => 3,
            60 => 2,
            else => 1,  // 其他分数
        };
        return grade;
    }
    
    // 示例 2：错误类型匹配
    fn handle_result(result: !i32) i32 {
        const value: i32 = match result {
            error.FileNotFound => -1,      // 预定义错误
            error.PermissionDenied => -2,  // 预定义错误
            error.OutOfMemory => -3,      // 运行时错误，无需预定义
            x => x,  // 成功值（绑定到 result 中的 i32 值）
        };
        return value;
    }
    
    // 示例 3：结构体解构匹配
    struct Point {
        x: i32,
        y: i32
    }
    
    fn classify_point(p: Point) i32 {
        const quadrant: i32 = match p {
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
    fn print_greeting(msg: [i8; 6]) void {
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
```uya
defer statement;
defer { statements }
```

**语义**：
- 在当前作用域结束时执行（正常返回或错误返回）
- 执行顺序：LIFO（后声明的先执行）
- 可以出现在函数内的任何位置
- 支持单语句和语句块

**示例**：
```uya
fn example() void {
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
```uya
errdefer statement;
errdefer { statements }
```

**语义**：
- 仅在函数返回错误时执行
- 执行顺序：LIFO（后声明的先执行）
- 必须在可能返回错误的函数中使用（返回类型为 `!T`）
- 用于错误情况下的资源清理

**示例**：
```uya
fn example() !i32 {
    defer {
        printf("Always cleanup\n");  // 总是执行
    }
    errdefer {
        printf("Error cleanup\n");  // 仅错误时执行
    }
    
    const result: i32 = try some_operation();
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
```uya
fn example() !void {
    const file: File = try open_file("test.txt");
    
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
```uya
fn process_file(path: byte*) !i32 {
    const file: File = try open_file(path);
    
    defer {
        printf("File processing finished\n");  // 总是记录完成
    }
    errdefer {
        printf("Error during file processing\n");  // 错误时记录错误
        rollback_transaction();  // 错误时回滚事务
    }
    
    // 处理文件...
    const result: i32 = try process(file);
    
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
```uya
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
    ```uya
    const max: i32 = max;  // 2147483647
    const min: i32 = min;  // -2147483648
    
    const a: i32 = max +| 1;   // 结果 = 2147483647（上溢饱和）
    const b: i32 = min -| 1;   // 结果 = -2147483648（下溢饱和）
    const c: i32 = 100 +| 200; // 结果 = 300（正常情况）
    ```
- **包装运算符**：
  - `+%`：包装加法，溢出时返回包装后的值（模运算）
  - `-%`：包装减法，溢出时返回包装后的值（模运算）
  - `*%`：包装乘法，溢出时返回包装后的值（模运算）
  - 操作数必须是整数类型（`i8`, `i16`, `i32`, `i64`），结果类型与操作数相同
  - 包装运算符的操作数类型必须完全一致
  - 示例：
    ```uya
    const max: i32 = max;  // 2147483647
    const min: i32 = min;  // -2147483648
    
    const a: i32 = max +% 1;   // 结果 = -2147483648（上溢包装）
    const b: i32 = min -% 1;   // 结果 = 2147483647（下溢包装）
    const c: i32 = 100 +% 200; // 结果 = 300（正常情况）
    ```
- **位运算符**：
  - `&`：按位与，两个操作数都必须是整数类型（`i8`, `i16`, `i32`, `i64`），结果类型与操作数相同
  - `|`：按位或，两个操作数都必须是整数类型，结果类型与操作数相同
  - `^`：按位异或，两个操作数都必须是整数类型，结果类型与操作数相同
  - `~`：按位取反（一元），操作数必须是整数类型，结果类型与操作数相同
  - `<<`：左移，左操作数必须是整数类型，右操作数必须是 `i32`，结果类型与左操作数相同
  - `>>`：右移（算术右移，对于有符号数保留符号位），左操作数必须是整数类型，右操作数必须是 `i32`，结果类型与左操作数相同
  - 位运算符的操作数类型必须完全一致（移位运算符的右操作数除外，必须是 `i32`）
  - 示例：
    ```uya
    const a: i32 = 0b1010;        // 10
    const b: i32 = 0b1100;        // 12
    const c: i32 = a & b;         // 0b1000 = 8
    const d: i32 = a | b;         // 0b1110 = 14
    const e: i32 = a ^ b;         // 0b0110 = 6
    const f: i32 = ~a;            // 按位取反
    const g: i32 = a << 2;        // 左移 2 位 = 40
    const h: i32 = a >> 1;        // 右移 1 位 = 5
    ```
- **不支持的运算符**（0.13）：
  - 自增/自减：`++`, `--`（必须使用 `i = i + 1;` 形式）
  - 复合赋值：`+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`（必须使用完整形式）
  - 三元运算符：`?:`（必须使用 `if-else` 语句）
- **类型比较规则**：
  - 基础类型（整数、浮点、布尔）支持 `==` 和 `!=` 比较
  - 浮点数比较使用 IEEE 754 标准，进行精确比较（可能受浮点精度影响）
  - 错误类型支持 `==` 比较（0.13）
  - 0.13 不支持结构体的 `==` 和 `!=` 比较（后续版本支持）
  - 0.13 不支持数组的 `==` 和 `!=` 比较（后续版本支持）
- **表达式求值顺序**：从左到右（left-to-right）
  - 函数参数求值顺序：从左到右
  - 数组字面量元素表达式求值顺序：从左到右
  - 结构体字面量字段表达式求值顺序：从左到右（按字面量中的顺序）
  - 副作用（赋值）立即生效
- **逻辑运算符短路求值**：
  - `expr1 && expr2`：如果 `expr1` 为 `false`，不计算 `expr2`
  - `expr1 || expr2`：如果 `expr1` 为 `true`，不计算 `expr2`
- **整数溢出和除零**（0.13 强制编译期证明）：
  - **整数溢出**：
  - 常量运算溢出 → **编译错误**（编译期直接检查）
  - 变量运算 → 必须显式检查溢出条件，或编译器能够证明无溢出
  - 无法证明无溢出 → **编译错误**
  - 成功路径零运行时检查，通过路径零指令
  - **除零错误**：
    - 常量除零 → **编译错误**
    - 变量 → 必须证明 `y != 0`，证明失败 → **编译错误**
    - 零运行时检查，通过路径零指令
  
  **溢出检查示例**：
  ```uya
  // ✅ 编译通过：常量运算无溢出
  const x: i32 = 100 + 200;  // 编译期证明：300 < 2147483647
  
  // ❌ 编译错误：常量溢出
  const y: i32 = 2147483647 + 1;  // 编译错误
  
  // ✅ 编译通过：显式溢出检查，返回错误
  fn add_safe(a: i32, b: i32) !i32 {
      if a > 0 && b > 0 && a > 2147483647 - b {
          return error.Overflow;  // 返回错误
      }
      return a + b;  // 编译器证明：经过检查后无溢出
  }
  
  // ✅ 编译通过：显式溢出检查，返回饱和值（有效数值）
  fn add_saturating(a: i32, b: i32) i32 {
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
  fn add_wrapping(a: i32, b: i32) i32 {
      // 显式检查溢出，如果溢出则返回包装后的值
      if a > 0 && b > 0 && a > 2147483647 - b {
          // 包装算术：溢出时返回 (a + b) % 2^32，但需要显式计算
          // 实际实现可能需要使用更大的类型进行计算
          const sum: i64 = (a as i64) + (b as i64);
          return (sum as! i32);  // 显式截断到 i32 范围
      }
      if a < 0 && b < 0 && a < -2147483648 - b {
          const sum: i64 = (a as i64) + (b as i64);
          return (sum as! i32);  // 显式截断到 i32 范围
      }
      return a + b;  // 编译器证明：经过检查后无溢出
  }
  
  // ❌ 编译错误：无法证明无溢出
  fn add_unsafe(a: i32, b: i32) i32 {
      return a + b;  // 编译错误
  }
  ```

**0.13 内存安全强制**：

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

**0.13 安全策略**：
- **编译期证明**：所有 UB 必须被编译器证明为安全
- **失败即错误**：证明失败 → 编译错误，不生成代码
- **成功路径零运行时开销**：通过路径零指令，失败路径显式处理
- **无 panic、无 catch、无断言**：所有检查在编译期完成
- **优先级示例**：
  ```uya
  var x: i32 = 1 + 2 * 3;        // = 7，不是 9（* 优先级高于 +）
  var y: bool = true && false || true;  // = true（&& 优先级高于 ||）
  var z: i32 = 0;
  z = z + 1;                          // 先计算 z + 1，再赋值（= 优先级最低）
  var a: i32 = 0b1010;
  var b: i32 = a << 2 & 0xFF;    // = (a << 2) & 0xFF（<< 优先级高于 &）
  var c: i32 = a & b | 0x10;     // = (a & b) | 0x10（& 优先级高于 |）
  ```

---

## 11 类型转换

### 11.1 转换语法

Uya 提供两种类型转换语法：

1. **安全转换 `as`**：只允许无精度损失的转换，编译期检查
2. **强转 `as!`**：允许所有转换，包括可能有精度损失的，返回错误联合类型 `!T`

### 11.2 安全转换（as）

安全转换只允许无精度损失的转换，可能损失精度的转换会编译错误：

```uya
// ✅ 允许的转换（无精度损失）
const x: f32 = 1.5;
const y: f64 = x as f64;  // f32 -> f64，扩展精度，无损失

const i: i32 = 42;
const f: f64 = i as f64;  // i32 -> f64，无损失

const small: i8 = 100;
const f32_val: f32 = small as f32;  // i8 -> f32，小整数，无损失

// ❌ 编译错误（可能有精度损失）
const x: f64 = 3.141592653589793;
const y: f32 = x as f32;  // 编译错误：f64 -> f32 可能有精度损失

const large: i32 = 100000000;
const f: f32 = large as f32;  // 编译错误：i32 -> f32 可能损失精度

const pi: f64 = 3.14;
const n: i32 = pi as i32;  // 编译错误：f64 -> i32 截断转换
```

### 11.3 强转（as!）

当确实需要进行可能有精度损失的转换时，使用 `as!` 强转语法。`as!` 返回错误联合类型 `!T`，需要使用 `try` 或 `catch` 处理可能的错误：

```uya
// ✅ 强转返回错误联合类型，需要错误处理
const x: f64 = 3.141592653589793;
const y: !f32 = x as! f32;  // 返回 !f32，可能包含精度损失错误
const y_value: f32 = try y;  // 使用 try 传播错误

// ✅ 使用 catch 处理可能的错误
const large: i32 = 100000000;
const f: f32 = large as! f32 catch |err| {
    // 处理精度损失错误，这里使用默认值
    0.0
};

const pi: f64 = 3.14;
const n: i32 = try pi as! i32;  // f64 -> i32，截断为 3（无错误）

const i64_val: i64 = 9007199254740992;  // 超过 f64 精度范围
const result: !f64 = i64_val as! f64;  // 返回错误联合类型，可能包含精度损失错误
```

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

```uya
// 编译期常量转换，成功路径零运行时开销
const PI_F64: f64 = 3.141592653589793;
const PI_F32: f32 = PI_F64 as! f32;  // 编译期求值，使用强转

const MAX_I32: i32 = 2147483647;
const MAX_F64: f64 = MAX_I32 as f64;  // 编译期求值，安全转换

// 编译后直接是常量，无运行时转换（成功路径零开销）
```

### 11.6 错误信息示例

```uya
// 源代码
const x: f64 = 3.14;
const y: f32 = x as f32;

// 编译错误信息
error: 类型转换可能有精度损失
  --> example.uya:2:18
   |
 2 | const y: f32 = x as f32;
   |                ^^^^^^^^
   |
   = note: f64 -> f32 转换可能损失精度
   = help: 如果确实需要此转换，请使用 'as!' 强转语法
   = help: 例如: const y: f32 = x as! f32;
```

### 11.7 设计哲学

- **默认安全**：普通 `as` 转换只允许无精度损失的转换，防止意外精度损失
- **显式强转**：`as!` 语法明确表示程序员知道可能有精度损失，意图清晰
- **安全强转**：`as!` 返回错误联合类型 `!T`，强制程序员处理可能的转换错误
- **成功路径零运行时开销**：对于编译期可证明安全的转换，生成单条机器指令，无错误检查（成功路径零开销，错误路径保留必要检查）
- **编译期检查**：转换安全性在编译期验证，失败即编译错误；可能有损失的转换在运行时检查

### 11.8 代码生成

#### 编译期可证明安全的转换（成功路径零运行时开销）
```uya
// 源代码
const x: f64 = 3.14;  // 编译期常量
const y: !f32 = x as! f32;
const y_value: f32 = try y;

// x86-64 生成的代码（伪代码）
//   movss  [y_value], 0x4048f5c3  ; 直接存储编译期计算的 f32 值
// 成功路径零运行时开销，无错误检查
```

#### 需要运行时检查的转换
```uya
// 源代码
fn convert(x: f64) !f32 {
    return x as! f32;
}

// x86-64 生成的代码（伪代码）
//   movsd  xmm0, [x]                ; 加载 f64
//   cvtsd2ss xmm1, xmm0             ; 转换为 f32
//   cvtss2sd xmm1, xmm1             ; 转换回 f64 进行检查
//   ucomisd xmm0, xmm1              ; 比较原始值和转换后的值
//   jne    .error_precision_loss    ; 如果不相等，跳转到错误处理
//   movss  xmm0, xmm1               ; 转换成功，设置返回值
//   mov    rax, 0                   ; 错误标记：无错误
//   ret
// .error_precision_loss:
//   mov    rax, error.PrecisionLoss  ; 设置错误代码
//   ret
// 包含运行时精度检查，确保转换安全性
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
5. **用户自定义 drop**：`fn drop(self: T) void { ... }`
   - 允许用户为自定义类型定义清理逻辑
   - 实现真正的 RAII 模式（文件自动关闭、内存自动释放等）
   - 每个类型只能有一个 drop 函数
   - 参数必须是 `self: T`（按值传递），返回类型必须是 `void`
   - 递归调用：结构体的 drop 会先调用字段的 drop，再调用自身的 drop

**drop 使用示例**：

```uya
struct Point {
  x: f32,
  y: f32
}

fn example() void {
  const p: Point = Point{ x: 1.0, y: 2.0 };
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

fn nested_example() void {
  const line: Line = Line{
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

```uya
// 示例 1：文件句柄自动关闭
extern i32 open(byte* path, i32 flags);
extern i32 close(i32 fd);

struct File {
    fd: i32
}

fn drop(self: File) void {
    if self.fd >= 0 {
        close(self.fd);
    }
}

fn example1() void {
    const f: File = File{ fd: open("file.txt", 0) };
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

fn drop(self: HeapBuffer) void {
    if self.data != null {
        free(self.data);
    }
}

fn example2() void {
    const buf: HeapBuffer = HeapBuffer{
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

fn example3() void {
    const reader: FileReader = FileReader{
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

```uya
// 基本类型：drop 是空函数
fn example_basic() void {
  const x: i32 = 10;
  const y: f64 = 3.14;
  // 离开作用域时，编译器会插入：
  // drop(y);  // 空函数，无操作
  // drop(x);  // 空函数，无操作
}

// 数组：元素按索引逆序 drop
fn example_array() void {
  const arr: [f32; 4] = [1.0, 2.0, 3.0, 4.0];
  // 离开作用域时，编译器会插入：
  // drop(arr[3]);  // 逆序 drop 元素
  // drop(arr[2]);
  // drop(arr[1]);
  // drop(arr[0]);
  // drop(arr);
}

// 作用域嵌套：变量在各自作用域结束时 drop
fn example_scope() void {
  const outer: i32 = 10;
  {
    const inner: i32 = 20;
    // inner 在这里 drop（离开内层作用域）
  }
  // outer 在这里 drop（离开外层作用域）
}

// 函数参数：按值传递，函数返回时会 drop
fn process(data: Point) void {
  // data 在这里 drop（函数返回时）
}

// 函数返回值：被调用者接收，在调用者作用域中 drop
fn create_point() Point {
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

## 13 原子操作（0.15 终极简洁）

### 13.1 设计目标

- **关键字 `atomic T`** → 语言层原子类型
- **读/写/复合赋值 = 自动原子指令** → 零运行时锁
- **通过路径 = 零指令**
- **失败 = 类型非 `atomic T` → 编译错误**

### 13.2 语法

```uya
struct Counter {
  value: atomic i32
}

fn increment(counter: *Counter) void {
  counter.value += 1;  // 自动原子 fetch_add
  const v: i32 = counter.value;  // 自动原子 load
  counter.value = 10;  // 自动原子 store
}
```

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
  - 与 C++ `std::memory_order_seq_cst` 语义一致
- **0.13 限制**：不支持自定义内存序（如 acquire、release、relaxed）
  - 后续版本可能支持显式内存序参数
- **性能考虑**：seq_cst 可能比 relaxed 内存序有更高的性能开销，但提供最强的安全性保证

### 13.5 限制

- **类型必须是 `atomic T`**：非原子类型进行原子操作 → 编译错误
- **零新符号**：无需额外的语法标记
- **通过路径零指令**：所有原子操作直接生成硬件原子指令

### 13.6 一句话总结

> **Uya 1.6 原子操作 = `atomic T` 关键字 + 自动原子指令**；  
> **读/写/复合赋值自动原子化，零运行时锁，通过路径零指令。**

---

## 14 内存安全（1.6 强制）

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

Uya 语言的编译期证明机制采用**分层验证策略**：

1. **常量折叠**（最简单）：
   - 编译期常量直接检查，溢出/越界立即报错
   - 示例：`const x: i32 = 2147483647 + 1;` → 编译错误

2. **路径敏感分析**（中等复杂度）：
   - 编译器跟踪所有代码路径，分析变量状态
   - 通过条件分支建立约束条件
   - 示例：`if i < 0 || i >= 10 { return error; }` 后，编译器知道 `i >= 0 && i < 10`

3. **符号执行**（复杂场景）：
   - 对于复杂表达式，编译器使用符号执行技术
   - 建立约束系统，验证数学关系
   - 示例：`if a > 0 && b > 0 && a > max - b { return error; }` 后，证明 `a + b <= max`

4. **失败处理**：
   - 无法证明安全 → **编译错误**，不生成代码
   - 提供清晰的错误信息，指出无法证明的原因
   - 建议使用 `try` 关键字、饱和运算符（`+|`, `-|`, `*|`）或包装运算符（`+%`, `-%`, `*%`）简化证明

**实现说明**（0.13 版本）：
- 0.13 版本优先实现**常量折叠**和**路径敏感分析**
- 复杂符号执行可能无法覆盖所有场景，此时需要程序员提供显式检查
- 后续版本会增强证明能力，减少显式检查的需求

### 14.4 示例

```uya
// ✅ 编译通过：常量索引在范围内
const arr: [i32; 10] = [0; 10];
const x: i32 = arr[5];  // 5 < 10，编译期证明安全

// ❌ 编译错误：常量索引越界
const y: i32 = arr[10];  // 10 >= 10，编译错误

// ✅ 编译通过：变量索引有证明
fn safe_access(arr: [i32; 10], i: i32) i32 {
  if i < 0 || i >= 10 {
    return error.OutOfBounds;
  }
  return arr[i];  // 编译器证明 i >= 0 && i < 10，在范围内
}

// ❌ 编译错误：变量索引无证明
fn unsafe_access(arr: [i32; 10], i: i32) i32 {
  return arr[i];  // 无法证明 i >= 0 && i < 10，编译错误
}
```

**整数溢出处理示例**：

```uya
// ✅ 编译通过：常量运算，编译器可以证明无溢出
// 使用 max/min 关键字访问极值（推荐）
const x: i32 = 100 + 200;  // 编译期常量折叠，证明无溢出（300 < max）

// 也可以用于常量定义（类型推断）
const MAX_I32: i32 = max;  // 从类型注解 i32 推断出是 i32 的最大值
const MIN_I32: i32 = min;  // 从类型注解 i32 推断出是 i32 的最小值

// ❌ 编译错误：常量溢出
const y: i32 = 2147483647 + 1;  // 编译错误：常量溢出
const z: i32 = -2147483648 - 1;  // 编译错误：常量下溢

// ✅ 编译通过：变量运算有显式溢出检查

// 方式1：返回错误（错误联合类型）
// 使用 try 关键字（推荐）
fn add_safe(a: i32, b: i32) !i32 {
    return try a + b;  // 自动检查溢出，溢出返回 error.Overflow
}

// 方式1（备选）：手动检查（如果需要自定义逻辑）
fn add_safe_manual(a: i32, b: i32) !i32 {
    // 显式检查上溢：a > 0 && b > 0 && a + b > MAX
    // 编译器从 a 和 b 的类型 i32 推断 max 和 min 的类型
    if a > 0 && b > 0 && a > max - b {
        return error.Overflow;  // 返回错误，无需预定义
    }
    // 显式检查下溢：a < 0 && b < 0 && a + b < MIN
    if a < 0 && b < 0 && a < min - b {
        return error.Overflow;  // 返回错误，无需预定义
    }
    // 编译器证明：经过检查后，a + b 不会溢出
    return a + b;
}

// 方式2：返回饱和值（有效数值）
// 使用饱和运算符（推荐）
fn add_saturating(a: i32, b: i32) i32 {
    return a +| b;  // 自动饱和，溢出返回极值
}

// 方式2（备选）：手动检查（如果需要自定义逻辑）
fn add_saturating_manual(a: i32, b: i32) i32 {
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
// 使用包装运算符（推荐）
fn add_wrapping(a: i32, b: i32) i32 {
    return a +% b;  // 自动包装，溢出返回包装值
}

// 方式3（备选）：手动检查（如果需要自定义逻辑）
fn add_wrapping_manual(a: i32, b: i32) i32 {
    // 包装算术的实现：使用更大的类型进行计算，然后截断
    // 这样即使溢出，也会自动包装回类型的另一端
    const sum: i64 = (a as i64) + (b as i64);
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
// 使用 try 关键字（推荐）
fn mul_safe(a: i32, b: i32) !i32 {
    return try a * b;  // 自动检查溢出，溢出返回 error.Overflow
}

// 方式（备选）：手动检查（如果需要自定义逻辑）
fn mul_safe_manual(a: i32, b: i32) !i32 {
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
fn add_unsafe(a: i32, b: i32) i32 {
    return a + b;  // 编译错误：无法证明 a + b 不会溢出
}

// ❌ 编译错误：无法证明无溢出
fn mul_unsafe(a: i32, b: i32) i32 {
    return a * b;  // 编译错误：无法证明 a * b 不会溢出
}

// ✅ 编译通过：已知范围的变量
fn add_known_range(a: i32, b: i32) i32 {
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
// 使用 max/min 关键字访问极值（推荐）
const x64: i64 = 1000000000 + 2000000000;  // 编译期常量折叠，证明无溢出

// ❌ 编译错误：i64 常量溢出
const y64: i64 = max + 1;  // 编译错误：常量溢出（从类型注解 i64 推断）
const z64: i64 = min - 1;  // 编译错误：常量下溢（从类型注解 i64 推断）

// ✅ 编译通过：i64 变量运算有显式溢出检查
// 使用 try 关键字（推荐）
fn add_safe_i64(a: i64, b: i64) !i64 {
    return try a + b;  // 自动检查溢出，溢出返回 error.Overflow
}

// 方式（备选）：手动检查（如果需要自定义逻辑）
fn add_safe_i64_manual(a: i64, b: i64) !i64 {
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
// 使用 try 关键字（推荐）
fn mul_safe_i64(a: i64, b: i64) !i64 {
    return try a * b;  // 自动检查溢出，溢出返回 error.Overflow
}

// 方式（备选）：手动检查（如果需要自定义逻辑）
fn mul_safe_i64_manual(a: i64, b: i64) !i64 {
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
fn add_unsafe_i64(a: i64, b: i64) i64 {
    return a + b;  // 编译错误：无法证明 a + b 不会溢出
}

// ✅ 编译通过：i64 已知范围的变量
fn add_known_range_i64(a: i64, b: i64) !i64 {
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
     - `const x: i32 = 2147483647 + 1;` → 编译错误（i32 溢出）
     - `const y: i64 = 9223372036854775807 + 1;` → 编译错误（i64 溢出）

2. **`try` 关键字和饱和运算符（最推荐）**：
   - 使用 `try` 关键字进行溢出检查，或使用饱和运算符 `+|`, `-|`, `*|` 进行溢出处理
   - 一行代码替代多行溢出检查，代码简洁
   - 编译期展开，零运行时开销，与手写代码性能相同
   - 示例：
     ```uya
     // try 关键字：返回错误联合类型
     fn add_safe(a: i32, b: i32) !i32 {
         return try a + b;  // 自动检查溢出，返回 error.Overflow 如果溢出
     }

     // 饱和运算符：返回饱和值
     fn add_saturating(a: i32, b: i32) i32 {
         return a +| b;  // 自动饱和
     }

     // 包装运算符：返回包装值
     fn add_wrapping(a: i32, b: i32) i32 {
         return a +% b;  // 自动包装
     }
     ```
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
   - **编译期展开**：`try` 关键字和饱和运算符在编译期展开为相应的溢出检查代码，零运行时开销

3. **max/min 关键字（备选方式）**：
   - 使用 `max` 和 `min` 关键字访问类型的极值常量
   - `max` 和 `min` 是语言关键字，编译器从上下文类型自动推断极值类型
   - 适用于需要自定义溢出检查逻辑的场景
   - 示例：
     ```uya
     // 使用 max/min 关键字访问极值（类型推断）
     const a: i32 = ...;
     const b: i32 = ...;
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

> **Uya 1.6 内存安全 = 所有 UB 必须被编译期证明为安全 → 失败即编译错误**；  
> **零运行时检查，通过路径零指令，失败路径不存在。**

---

## 15 并发安全（1.6 强制）

### 15.1 设计目标

- **原子类型 `atomic T`** → 语言层原子
- **读/写/复合赋值 = 自动原子指令** → **零运行时锁**
- **数据竞争 = 零**（所有原子操作自动序列化）
- **零新符号**：无需额外的语法标记

### 15.2 并发安全机制

| 特性 | 0.13 实现 | 说明 |
|---|---|---|
| 原子类型 | `atomic T` 关键字 | 语言层原子类型 |
| 原子操作 | 自动生成原子指令 | 读/写/复合赋值自动原子化 |
| 数据竞争 | 零（编译期保证） | 所有原子操作自动序列化 |
| 运行时锁 | 零 | 无锁编程，直接硬件原子指令 |

### 15.3 示例

```uya
struct Counter {
  value: atomic i32
}

impl Counter : IIncrement {
  fn inc(self: *Self) i32 {
    self.value += 1;  // 自动原子 fetch_add
    return self.value;  // 自动原子 load
  }
}

fn main() i32 {
  const counter: Counter = Counter{ value: 0 };
  // 多线程并发递增，零数据竞争
  // 所有操作自动原子化，无需锁
  return 0;
}
```

### 15.4 限制

- **只靠原子类型**：并发安全只靠 `atomic T` + 自动原子指令

### 15.5 一句话总结

> **Uya 1.6 并发安全 = 原子类型 + 自动原子指令**；  
> **零数据竞争，零运行时锁，通过路径零指令。**

---

## 16 标准库（1.6 最小集）

| 函数 | 签名 | 说明 |
|------|------|------|
| `len` | `fn len(a: [T; N]) i32` | 返回数组元素个数 `N`（编译期常量） |
| `sizeof` | `fn sizeof(T) i32` | 返回类型 `T` 的字节大小（编译期常量，需导入 `std.mem`） |
| `alignof` | `fn alignof(T) i32` | 返回类型 `T` 的对齐字节数（编译期常量，需导入 `std.mem`） |

**说明**：
- `len` 函数是编译器内置的，编译期展开，零运行时开销，自动可用，无需导入或声明
- `sizeof` 和 `alignof` 是标准库函数（位于 `std/mem.uya`），需要导入使用，编译期折叠为常数，零运行时开销

**函数详细说明**：

1. **`len(a: [T; N]) i32`**
   - 功能：返回数组的元素个数
   - 参数：`a` 是任意类型 `T` 的数组，大小为 `N`
   - 返回值：`i32` 类型，值为 `N`（编译期常量）
   - 注意：由于 `N` 是编译期常量，此函数在编译期求值，零运行时开销
   - 示例：
     ```uya
     const arr: [i32; 10] = [0; 10];
     const size: i32 = len(arr);  // size = 10（编译期常量）
     ```

2. **`try` 关键字、饱和运算符**（`+|`, `-|`, `*|`）**和包装运算符**（`+%`, `-%`, `*%`）
   - 功能：提供简洁的溢出检查和处理方式，避免重复编写溢出检查代码
   - 支持的类型：`i8`, `i16`, `i32`, `i64`
   - 编译期展开：`try` 关键字和饱和运算符在编译期展开为相应的溢出检查代码，零运行时开销
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
       ```uya
       // 溢出检查
       fn add_safe(a: i32, b: i32) !i32 {
           return try a + b;  // 自动检查溢出，溢出返回 error.Overflow
       }

      // 使用示例：处理溢出错误
      const result: i32 = try x + y catch |err| {
          if err == error.Overflow {
              printf("Overflow occurred\n");
              // 处理溢出情况，如返回默认值或报告错误
          }
          return 0;  // 提供默认值
      };

      // 使用示例：传播错误
      fn calculate(a: i32, b: i32, c: i32) !i32 {
          const sum: i32 = try a + b;  // 溢出时向上传播 error.Overflow
          return try sum + c;  // 继续检查，可能抛出 error.Overflow
      }
      
      // 使用示例：减法溢出检查
      fn sub_safe(a: i32, b: i32) !i32 {
          return try a - b;  // 自动检查减法溢出，可能抛出 error.Overflow
      }
      
      // 使用示例：乘法溢出检查
      fn mul_safe(a: i32, b: i32) !i32 {
          return try a * b;  // 自动检查乘法溢出，可能抛出 error.Overflow
      }
       ```
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
       ```uya
       // 饱和算术
       fn add_saturating(a: i32, b: i32) i32 {
           return a +| b;  // 自动饱和，溢出返回极值
       }
       
      // 使用示例：限制结果范围
      const result: i32 = x +| y;  // 溢出时自动返回 max 或 min
      
      // 数值示例（i32 类型）
      const max: i32 = max;  // 2147483647
      const min: i32 = min;  // -2147483648
      
      // 上溢饱和：超过最大值时返回最大值
      const result1: i32 = max +| 1;  // 结果 = 2147483647（保持最大值）
      
      // 下溢饱和：小于最小值时返回最小值
      const result2: i32 = min -| 1;  // 结果 = -2147483648（保持最小值）
      
      // 正常情况：不溢出时行为与普通加法相同
      const result3: i32 = 100 +| 200;  // 结果 = 300
      
      // 饱和乘法
      const result4: i32 = max *| 2;  // 结果 = 2147483647（上溢饱和）
       ```
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
       ```uya
       // 包装算术
       fn add_wrapping(a: i32, b: i32) i32 {
           return a +% b;  // 自动包装，溢出返回包装值
       }
       
      // 使用示例
      const result: i32 = x +% y;  // 溢出时自动包装
      
      // 数值示例（i32 类型）
      const max: i32 = max;  // 2147483647
      const min: i32 = min;  // -2147483648
      
      // 上溢包装：超过最大值时包装到最小值
      const result1: i32 = max +% 1;  // 结果 = -2147483648（包装）
      
      // 下溢包装：小于最小值时包装到最大值
      const result2: i32 = min -% 1;  // 结果 = 2147483647（包装）
      
      // 正常情况：不溢出时行为与普通加法相同
      const result3: i32 = 100 +% 200;  // 结果 = 300
      
      // 包装乘法
      const result4: i32 = max *% 2;  // 结果 = -2（包装）
       ```
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
     ```uya
    // 源代码
    const result: i32 = try a + b;
     
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

3. **`sizeof(T) i32` 和 `alignof(T) i32`**
   - **功能**：`sizeof(T)` 返回类型 `T` 的字节大小，`alignof(T)` 返回类型 `T` 的对齐字节数
   - **位置**：标准库 `std/mem.uya`
   - **签名**：
     ```uya
     export fn sizeof(T) i32  = @size_of(T);   // 仅编译器可见的折叠记号
     export fn alignof(T) i32 = @align_of(T);
     ```
   - **使用**：
     ```uya
     use std.mem.{sizeof, alignof};

     const N: i32 = sizeof(struct Vec3{});      // 12
     const A: i32 = alignof(struct Vec3{});     // 4
     ```
   - **支持类型**：
     | 类别 | 示例 | 说明 |
     |------|------|------|
     | 基础整数 | `i8` … `i64`, `u8` … `u64` | 大小对齐 = 自身宽度 |
     | 浮点 | `f32`, `f64` | 4 B / 8 B |
     | 布尔 | `bool` | 1 B |
     | 指针 | `&T`, `byte*` | 平台字长（4 B 或 8 B） |
     | 数组 | `[T; N]` | 大小 = `N * sizeof(T)`，对齐 = `alignof(T)` |
     | 结构体 | `struct S{...}` | 大小 = 各字段按 C 规则布局，对齐 = 最大字段对齐 |
     | 原子 | `atomic T` | 与 `T` 完全相同 |
   - **常量表达式**：结果可在**任何需要编译期常量**的位置使用
     ```uya
     const BUF: [byte; sizeof(struct File)] = [];          // 定长缓冲区
     const ALIGN_MASK: i32 = alignof(struct Page) - 1;     // 对齐掩码
     ```
   - **零运行时保证**：
     - 前端遇到 `sizeof(T)` / `alignof(T)` **直接折叠**成常数，**不生成函数调用**
     - 失败路径（类型未定义、含泛型参数）→ **编译错误**，不生成代码
   - **常见示例**：
     ```uya
     // 1. FFI 分配
     extern void* malloc(i32 size);
     const ptr: byte* = malloc(sizeof(struct Packet));

     // 2. 对齐检查
     if alignof(struct Header) != 64 {
         return error.BadAlign;
     }

     // 3. 零拷贝序列化
     const MSG: [byte; sizeof(struct Msg)] = [];
     ```
   - **限制**：
     - `T` 必须是**完全已知类型**（无待填泛型参数）
     - 不支持表达式级 `sizeof(expr)`——仅对 **类型** 求值
     - 返回类型固定为 `i32`；超大结构体大小若超过 `i32` 上限 → 编译错误
   - **一句话总结**：
     > `sizeof` / `alignof` 就是**普通标准库函数**，内部被编译器折叠成常数；  
     > 零关键字、零开销、零运行时，单页纸用完。

> 更多函数通过 `extern` 直接调用 C 库即可。

---

## 17 完整示例：结构体 + 栈数组 + FFI

```uya
struct Mat4 {
  m: [f32; 16]
}

extern i32 printf(byte* fmt, ...);

fn print_mat(mat: Mat4) void {
  var i: i32 = 0;
  while i < 16 {
    printf("%f ", mat.m[i]);
    i = i + 1;
    if (i % 4) == 0 { printf("\n"); }
  }
}

fn main() i32 {
  var m: Mat4 = Mat4{ m: [0.0; 16] };
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
$ uyac demo.uya && ./demo
1.000000 0.000000 0.000000 0.000000
0.000000 1.000000 0.000000 0.000000
0.000000 0.000000 1.000000 0.000000
0.000000 0.000000 0.000000 1.000000
```

---

## 18 完整示例：错误处理 + defer/errdefer

```uya
// 预定义错误（可选）
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
    const fd: i32 = open(path, 0);  // 0 是只读标志（简化示例）
    if fd < 0 {
        return error.FileError;  // 使用预定义错误
    }
    return File{ fd: fd };
}

fn read_file_runtime(path: byte*) !i32 {
    const fd: i32 = open(path, 0);
    if fd < 0 {
        return error.FileNotFound;  // 运行时错误，无需预定义
    }
    return fd;
}

fn drop(self: File) void {
    if self.fd >= 0 {
        close(self.fd);
    }
}

fn read_file(path: byte*) !i32 {
    const file: File = try open_file(path);
    defer {
        printf("File operation completed\n");
    }
    errdefer {
        printf("Error occurred, cleaning up\n");
    }
    
    var buf: [byte; 1024] = [];
    const n: i32 = read(file.fd, buf, 1024);
    if n < 0 {
        return error.FileError;
    }
    
    return n;
}

fn main() i32 {
    const result: i32 = read_file("test.txt") catch |err| {
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

```uya
struct Counter {
  value: atomic i32
}

interface IIncrement {
  fn inc(self: *Self) i32;
}

impl Counter : IIncrement {
  fn inc(self: *Self) i32 {
    self.value += 1;                           // 自动原子 fetch_add
    return self.value;                         // 自动原子 load
  }
}

fn main() i32 {
  const counter: Counter = Counter{ value: 0 };
  // 多线程并发递增，零数据竞争
  // 所有操作自动原子化，无需锁
  return 0;
}
```

---

## 20 完整示例：for循环迭代

```uya
extern i32 printf(byte* fmt, ...);

// 迭代器结束错误
error IterEnd;
// 迭代器状态错误（用于value()方法的边界检查）
error InvalidIteratorState;

// i32数组迭代器接口
interface IIteratorI32 {
    fn next(self: *Self) !void;
    fn value(self: *Self) !i32;  // 可能返回错误
    fn ptr(self: *Self) !&i32;  // 获取指向当前元素的指针（可修改），可能返回错误
}

// 带索引的i32数组迭代器接口
interface IIteratorI32WithIndex {
    fn next(self: *Self) !void;
    fn value(self: *Self) !i32;  // 可能返回错误
    fn index(self: *Self) i32;
}

// i32数组迭代器结构体
struct ArrayIteratorI32 {
    arr: *[i32; N],
    current: i32,
    len: i32
}

impl ArrayIteratorI32 : IIteratorI32 {
    fn next(self: *Self) !void {
        if self.current >= self.len {
            return error.IterEnd;
        }
        self.current = self.current + 1;
    }
    
    fn value(self: *Self) !i32 {
        const idx: i32 = self.current - 1;
        // 编译期证明：由于 next() 成功返回，idx 在有效范围内
        if idx < 0 || idx >= self.len {
            return error.InvalidIteratorState;  // 根据设计，这种情况不应该发生
        }
        return (*self.arr)[idx];
    }
    
    fn ptr(self: *Self) !&i32 {
        const idx: i32 = self.current - 1;
        // 编译期证明：由于 next() 成功返回，idx 在有效范围内
        if idx < 0 || idx >= self.len {
            return error.InvalidIteratorState;
        }
        return &(*self.arr)[idx];  // 返回指向当前元素的指针（可修改）
    }
}

impl ArrayIteratorI32 : IIteratorI32WithIndex {
    fn next(self: *Self) !void {
        if self.current >= self.len {
            return error.IterEnd;
        }
        self.current = self.current + 1;
    }
    
    fn value(self: *Self) !i32 {
        const idx: i32 = self.current - 1;
        // 编译期证明：由于 next() 成功返回，idx 在有效范围内
        if idx < 0 || idx >= self.len {
            return error.InvalidIteratorState;  // 根据设计，这种情况不应该发生
        }
        return (*self.arr)[idx];
    }
    
    fn index(self: *Self) i32 {
        return self.current - 1;
    }
}

fn main() i32 {
    const arr: [i32; 5] = [10, 20, 30, 40, 50];
    
    // 示例1：基本迭代（只获取元素值，只读）
    printf("Basic iteration:\n");
    for arr |item| {
        printf("  value: %d\n", item);
    }
    
    // 示例2：可修改迭代
    var arr2: [i32; 5] = [10, 20, 30, 40, 50];
    printf("\nMutable iteration:\n");
    for arr2 |&item| {
        *item = *item * 2;  // 修改每个元素，乘以2
        printf("  value: %d\n", *item);
    }
    
    // 示例3：整数范围迭代
    printf("\nInteger range iteration:\n");
    for 0..10 |i| {
        printf("  i: %d\n", i);  // 输出 0 到 9
    }
    
    // 示例4：计算数组元素之和
    var sum: i32 = 0;
    for arr |item| {
        sum = sum + item;
    }
    printf("\nSum of array elements: %d\n", sum);
    
    // 示例5：丢弃元素，只循环次数
    printf("\nLoop count only:\n");
    var count: i32 = 0;
    for arr {
        count = count + 1;
    }
    printf("Array length: %d\n", count);
    
    // 示例6：整数范围，丢弃元素
    printf("\nInteger range, discard element:\n");
    var loop_count: i32 = 0;
    for 0..10 {
        loop_count = loop_count + 1;
    }
    printf("Loop count: %d\n", loop_count);
    
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

Mutable iteration:
  value: 20
  value: 40
  value: 60
  value: 80
  value: 100

Integer range iteration:
  i: 0
  i: 1
  i: 2
  i: 3
  i: 4
  i: 5
  i: 6
  i: 7
  i: 8
  i: 9

Sum of array elements: 150

Loop count only:
Array length: 5

Integer range, discard element:
Loop count: 10
```

**说明**：
- for循环自动为数组创建迭代器（编译器自动生成）
- 整数范围直接展开为整数循环，零运行时开销
- 迭代器自动装箱为接口类型，使用动态派发
- 零运行时开销，编译期展开为while循环
- 支持可迭代对象和整数范围两种形式
- 支持有元素变量和丢弃元素两种模式

---

## 21 完整示例：切片语法

```uya
extern i32 printf(byte* fmt, ...);

fn main() i32 {
    const arr: [i32; 10] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

    // 基本切片语法
    // arr[2:3] 表示从索引2开始，长度为3
    const slice1: [i32; 3] = arr[2:3];  // [2, 3, 4]
    printf("arr[2:3]: ");
    for slice1 |item| {
        printf("%d ", item);
    }
    printf("\n");

    // 使用负数索引的切片
    // arr[-3:3] 表示从倒数第3个元素开始，长度为3
    const slice2: [i32; 3] = arr[-3:3];  // [7, 8, 9]
    printf("arr[-3:3]: ");
    for slice2 |item| {
        printf("%d ", item);
    }
    printf("\n");

    // 从某个索引到末尾
    // arr[7:3] 表示从索引7开始，长度为3（到末尾）
    const slice3: [i32; 3] = arr[7:3];  // [7, 8, 9]
    printf("arr[7:3]: ");
    for slice3 |item| {
        printf("%d ", item);
    }
    printf("\n");

    // 从开头开始
    // arr[0:3] 表示从索引0开始，长度为3
    const slice4: [i32; 3] = arr[0:3];  // [0, 1, 2]
    printf("arr[0:3]: ");
    for slice4 |item| {
        printf("%d ", item);
    }
    printf("\n");

    // 从开头到倒数第1个元素
    // arr[0:9] 表示从索引0开始，长度为9（不包含最后一个）
    const slice5: [i32; 9] = arr[0:9];  // [0, 1, 2, 3, 4, 5, 6, 7, 8]
    printf("arr[0:9]: ");
    for slice5 |item| {
        printf("%d ", item);
    }
    printf("\n");

    // 使用负数索引的范围
    // arr[-5:3] 表示从倒数第5个开始，长度为3
    const slice6: [i32; 3] = arr[-5:3];  // [5, 6, 7]
    printf("arr[-5:3]: ");
    for slice6 |item| {
        printf("%d ", item);
    }
    printf("\n");

    // 空切片情况
    const slice7: [i32; 0] = arr[5:0];  // 空数组 []
    printf("arr[5:0]: (empty slice)\n");

    // 单元素切片
    const slice8: [i32; 1] = arr[4:1];  // [4]
    printf("arr[4:1]: %d\n", slice8[0]);

    return 0;
}
```

**编译运行结果**：
```
arr[2:3]: 2 3 4
arr[-3:3]: 7 8 9
arr[7:3]: 7 8 9
arr[0:3]: 0 1 2
arr[0:9]: 0 1 2 3 4 5 6 7 8
arr[-5:3]: 5 6 7
arr[5:0]: (empty slice)
arr[4:1]: 4
```

**说明**：
- 切片使用 `arr[start:len]` 语法
- `start`：起始索引，**支持负数索引**（`-1` 表示最后一个元素，`-2` 表示倒数第二个元素，以此类推）
  - 负数索引从数组末尾开始计算：`-n` 转换为 `len(arr) - n`
  - 例如：对于长度为10的数组，`arr[-3:3]` 等价于 `arr[7:3]`
- `len`：切片长度（必须为正数），表示要提取的元素个数
- `arr[start:len]` 返回从索引 `start` 开始，长度为 `len` 的元素组成的新数组
- **负数索引示例**：
  - `arr[-1:1]`：从最后一个元素开始，长度为1
  - `arr[-3:3]`：从倒数第3个元素开始，长度为3
  - `arr[-5:2]`：从倒数第5个元素开始，长度为2
- 所有切片操作都经过编译期或运行时边界检查，确保内存安全
- 零运行时开销，通过路径零指令

---

## 22 完整示例：多维数组

```uya
extern i32 printf(byte* fmt, ...);

fn main() i32 {
    // 示例1：声明和初始化二维数组
    // 3x4 的 i32 矩阵
    const matrix: [[i32; 4]; 3] = [
        [1, 2, 3, 4],
        [5, 6, 7, 8],
        [9, 10, 11, 12]
    ];
    
    printf("Matrix (3x4):\n");
    var i: i32 = 0;
    while i < 3 {
        var j: i32 = 0;
        while j < 4 {
            printf("%d ", matrix[i][j]);  // 需要边界检查证明
            j = j + 1;
        }
        printf("\n");
        i = i + 1;
    }
    
    // 示例2：未初始化的多维数组
    var matrix2: [[f32; 4]; 3] = [];
    // 手动初始化
    var i: i32 = 0;
    while i < 3 {
        var j: i32 = 0;
        while j < 4 {
            const idx: i32 = i * 4 + j;
            matrix2[i][j] = (idx as f32) * 0.5;  // 需要边界检查证明
            j = j + 1;
        }
        i = i + 1;
    }
    
    printf("\nMatrix2 (3x4, float):\n");
    var i: i32 = 0;
    while i < 3 {
        var j: i32 = 0;
        while j < 4 {
            printf("%.1f ", matrix2[i][j]);
            j = j + 1;
        }
        printf("\n");
        i = i + 1;
    }
    
    // 示例3：结构体中的多维数组字段
    struct Mat3x3 {
        data: [[f32; 3]; 3]
    }
    
    const mat: Mat3x3 = Mat3x3{
        data: [
            [1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 0.0, 1.0]
        ]
    };
    
    printf("\nIdentity Matrix (3x3):\n");
    var i: i32 = 0;
    while i < 3 {
        var j: i32 = 0;
        while j < 3 {
            printf("%.1f ", mat.data[i][j]);  // 访问结构体中的多维数组字段
            j = j + 1;
        }
        printf("\n");
        i = i + 1;
    }
    
    // 示例4：三维数组
    var cube: [[[i32; 3]; 3]; 3] = [];
    var i: i32 = 0;
    while i < 3 {
        var j: i32 = 0;
        while j < 3 {
            var k: i32 = 0;
            while k < 3 {
                cube[i][j][k] = i * 9 + j * 3 + k;  // 需要边界检查证明
                k = k + 1;
            }
            j = j + 1;
        }
        i = i + 1;
    }
    
    printf("\nCube[0][1][2] = %d\n", cube[0][1][2]);  // 应该输出 5
    
    // 示例5：使用重复式初始化
    const zero_matrix: [[i32; 4]; 3] = [[0; 4]; 3];  // 3x4 的零矩阵
    printf("\nZero Matrix (3x4):\n");
    var i: i32 = 0;
    while i < 3 {
        var j: i32 = 0;
        while j < 4 {
            printf("%d ", zero_matrix[i][j]);
            j = j + 1;
        }
        printf("\n");
        i = i + 1;
    }
    
    return 0;
}
```

**编译运行结果**：
```
Matrix (3x4):
1 2 3 4 
5 6 7 8 
9 10 11 12 

Matrix2 (3x4, float):
0.0 0.5 1.0 1.5 
2.0 2.5 3.0 3.5 
4.0 4.5 5.0 5.5 

Identity Matrix (3x3):
1.0 0.0 0.0 
0.0 1.0 0.0 
0.0 0.0 1.0 

Cube[0][1][2] = 5

Zero Matrix (3x4):
0 0 0 0 
0 0 0 0 
0 0 0 0 
```

**说明**：
- 多维数组使用嵌套的 `[[T; N]; M]` 语法声明，M 和 N 必须是编译期常量
- 支持使用嵌套的数组字面量初始化，或使用 `[]` 声明未初始化数组
- 所有维度的索引访问都需要边界检查证明：`i >= 0 && i < M && j >= 0 && j < N`
- 多维数组在内存中按行优先顺序存储（row-major order），与 C 语言一致
- 支持在结构体字段中使用多维数组
- 支持三维及更高维度的数组（继续嵌套）
- 零运行时开销，所有边界检查在编译期完成

---

## 23 字符串与格式化（0.15）

### 23.1 设计目标
- 支持 `"hex=${x:#06x}"`、`"pi=${pi:.2f}"` 等常用格式；  
- 仍保持「编译期展开 + 定长栈数组」；  
- 无运行时解析开销，无堆分配；  
- 语法一眼看完。

### 23.2 语法（单页纸）

```
segment = TEXT | '${' expr [':' spec] '}'
spec    = flag* width? precision? type
flag    = '#' | '0' | '-' | ' ' | '+'
width   = NUM | '*'  // '*' 为未来特性，0.13 不支持
precision = '.' NUM | '.*'  // '.*' 为未来特性，0.13 不支持
type    = 'd' | 'u' | 'x' | 'X' | 'f' | 'F' | 'g' | 'G' | 'c' | 'p'
```

- 整体格式 **与 C printf 保持一致**，减少学习成本。  
- `width` / `precision` 必须为**编译期数字**（`*` 暂不支持）。  
- 结果类型仍为 `[i8; N]`，宽度由「格式字符串最大可能长度」常量求值得出。

### 23.3 宽度常量表（0.13）

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

### 23.4 完整示例

```uya
extern i32 printf(byte* fmt, ...);

fn main() i32 {
  const x: u32 = 255;
  const pi: f64 = 3.1415926;

  const msg: [i8; 64] = "hex=${x:#06x}, pi=${pi:.2f}\n";
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

**重要说明：编译期优化 vs 运行时执行**：

字符串插值采用**编译期优化 + 运行时格式化**的混合策略：

**编译期完成的工作**（零运行时开销）：
- ✅ 计算缓冲区大小（`[i8; N]` 中的 `N`）
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

### 23.5 后端实现要点

1. **词法** → 识别 `':' spec` 并解析为 `(flag, width, precision, type)` 四元组。  
2. **常量求值** → 根据「类型 + 格式」查表得最大字节数。  
3. **代码生成** →  
   - 文本段 = `memcpy`；  
   - 插值段 = `sprintf(buf+offset, "格式化串", 值)`；  
   - 格式串本身 = 编译期常量。  

### 23.6 限制（保持简单）

| 限制 | 说明 |
|---|---|
| `width/precision` | 必须为**编译期数字**；`*` 暂不支持 |
| 类型不匹配 | `%.2f` 但表达式是 `i32` → 编译错误 |
| 嵌套字符串 | `${"abc"}` → ❌ 表达式内不能再有字符串字面量 |
| 动态宽度 | `"%*d"` → 后续版本支持 |

### 23.7 零开销保证

- **宽度编译期常数** → 不占用寄存器；  
- **无运行时解析** → 无 `vsnprintf` 扫描；  
- **无堆分配** → 仍是 `alloca [N x i8]`；  
- **单条 `sprintf` 调用** → 与手写 C 同速。

### 23.8 一句话总结

> Uya 自定义格式 `"a=${x:#06x}"` → **编译期展开成定长栈数组**，格式与 C printf 100% 对应，**零运行时解析、零堆、零 GC**，性能 = 手写 `sprintf`。

---

## 24 Uya 0.13 泛型增量文档（向后 100% 兼容，零新关键字）

> **注意**：本章描述的是 0.13 版本的可选特性，作为增量文档提供。  
> — 单页纸，直接附在 0.13 规范末尾 —

------------------------------------------------
1. 核心规则（仅 3 行）
------------------------------------------------
1. 在 interface / struct / fn 签名里首次出现**未事先声明**的类型标识符 ⇒ 自动视为该定义的**泛型参数**（按出现顺序排）。  
2. impl / 调用时把**具体类型**写进括号 `(T1, T2, …)` 即完成单态化；找不到对应参数 ⇒ 编译错误。  
3. 单态化后走原有 0.13 全部流程（UB 证明、drop、atomic、接口检查等）。

------------------------------------------------
2. 语法影子（用户侧 0 新符号）
------------------------------------------------
| 场景 | 0.13 旧写法 | 0.13 泛型写法 | 备注 |
|---|---|---|---|
| 泛型接口 | `interface I { fn f(x: i32); }` | `interface I { fn f(x: T); }` | 裸名 `T` 自动成参 |
| 泛型结构体 | `struct S { x: i32; }` | `struct S { x: T; }` | 裸名 `T` 自动成参 |
| 泛型函数 | 无 | `fn id(x: T) T { return x; }` | 裸名 `T` 自动成参 |
| 实例化 | `impl S : I { … }` | `impl S : I(i32) { … }` | 括号内给实参 |
| 多参数 | 无 | `fn swap(x: A, y: B) (B, A) {…}` | 未声明裸名均成参 |

> 括号 `()` 已存在于函数调用/元组，**不算新符号**。

------------------------------------------------
3. 实例化规则
------------------------------------------------
- 顺序对应：按裸名首次出现顺序一一替换。  
- 可写多行：`impl Vec { T = i32; }` 或一行 `impl Vec { T = i32; }`。  
- 未用完/多给均报错，防止错位。

------------------------------------------------
4. 约束：靠"接口位置"表达上界
------------------------------------------------
```uya
interface Add {
    fn add(self: *Self, rhs: R) R;   // R 自动成参
}

impl Num : Add(i32) {   // 把 R 换成 i32
    fn add(self: *Self, rhs: i32) i32 {
        return self.x + rhs;
    }
}
```
单态化时编译器查找 `impl 具体类型 : Add(i32)`，找不到即报错——与 0.13 接口检查**同一套逻辑**。

------------------------------------------------
5. 函数级实例化：第一次调用即生成
------------------------------------------------
```uya
fn id(x: T) T { return x; }

const n: i32 = 42;
const m: i32 = id(n);   // 第一次调用 → 生成 id_i32
const p: f64 = id(3.14); // 第二次调用 → 生成 id_f64
```
后续再遇到 `id(i32)` 直接复用已生成代码，**无运行时派发**。

------------------------------------------------
6. 完整小例子
------------------------------------------------
```uya
interface Add {
    fn add(self: *Self, rhs: R) R;   // R 自动成参
}

struct Num { x: i32; }

impl Num : Add(i32) {   // 把 R 换成 i32
    fn add(self: *Self, rhs: i32) i32 {
        return self.x + rhs;
    }
}

fn sum(a: T, b: T) T {        // T 自动成参
    return a.add(b);             // 要求 T 实现 Add(i32)
}

fn main() i32 {
    const n1 = Num{ x: 1 };
    const n2 = Num{ x: 2 };
    const n3: Num = sum(n1, n2);   // T = Num
    return n3.x;                 // 3
}
```

------------------------------------------------
6.1 struct 泛型示例
------------------------------------------------
```uya
// 泛型结构体：T 自动成为泛型参数
struct Vec {
    data: [T; 10],   // T 自动成参
    len: i32
}

// 实例化：使用具体类型
fn create_i32_vec() Vec(i32) {   // 括号内指定 T = i32
    return Vec(i32){
        data: [0; 10],
        len: 0
    };
}

fn create_f64_vec() Vec(f64) {   // 括号内指定 T = f64
    return Vec(f64){
        data: [0.0; 10],
        len: 0
    };
}

// 泛型方法
fn push(self: *Vec(T), item: T) void {   // T 自动成参
    if self.len >= 10 {
        return;  // 简化示例，实际应返回错误
    }
    self.data[self.len] = item;
    self.len = self.len + 1;
}

fn main() i32 {
    var v1: Vec(i32) = create_i32_vec();
    push(&v1, 42);   // T = i32，自动推断
    
    var v2: Vec(f64) = create_f64_vec();
    push(&v2, 3.14);   // T = f64，自动推断
    
    return 0;
}
```

------------------------------------------------
6.2 类型别名实现
------------------------------------------------
使用 `type =` 语法实现类型别名，**可以别名任意类型**，零运行时开销，语义清晰：

```uya
// 基础类型别名
type UserId = i32;
type Distance = f64;
type Flag = bool;

// 数组类型别名
type Name = [i8; 64];           // 字符串数组
type Buffer = [byte; 1024];     // 字节缓冲区
type Matrix = [f32; 16];        // 4x4 矩阵

// 结构体类型别名
struct Point { x: f32, y: f32 }
type Position = Point;          // 结构体别名
type Location = Point;           // 同一结构体的不同语义别名

// 接口类型别名
interface IWriter {
    fn write(self: *Self, buf: *byte, len: i32) i32;
}
type Output = IWriter;          // 接口别名

// 指针类型别名
type StringPtr = byte*;          // FFI 字符串指针
type DataPtr = &[i32; 10];      // 数组指针

// 错误联合类型别名
error FileError;
type FileResult = !i32;          // 错误联合类型别名
type ParseResult = !void;        // 错误联合类型别名

// 泛型类型别名
struct Vec { data: [T; 10], len: i32 }
type IntVec = Vec(i32);          // 泛型实例化别名
type FloatVec = Vec(f64);        // 泛型实例化别名

// 嵌套类型别名
type PointArray = [Point; 10];   // 结构体数组
type WriterPtr = &IWriter;       // 接口指针（如果支持）

// 使用示例
fn create_user() UserId {
    return 1001;
}

fn calculate_distance(x: Distance, y: Distance) Distance {
    return x + y;
}

fn process_name(name: Name) void {
    // 处理名称
}

fn create_point() Position {
    return Position{ x: 1.0, y: 2.0 };
}

fn open_file() FileResult {
    // 返回文件结果
    return 0;
}

fn main() i32 {
    const uid: UserId = create_user();
    const d1: Distance = 10.5;
    const d2: Distance = 20.3;
    const total: Distance = calculate_distance(d1, d2);
    
    const name: Name = "hello";
    const pos: Position = create_point();
    const result: FileResult = open_file();
    
    var vec: IntVec = Vec(i32){ data: [0; 10], len: 0 };
    
    return 0;
}
```

**特性**：
- **可以别名任意类型**：基础类型、数组、结构体、接口、指针、错误联合类型、泛型等
- **零运行时开销**：类型别名在编译期展开，与底层类型完全相同
- **语义清晰**：类型名称直接表达语义意图，提高代码可读性
- **零新关键字**：`type` 关键字（如果尚未使用）或复用现有语法
- **编译期展开**：所有类型别名在编译期展开为底层类型，零运行时成本

**注意**：类型别名在类型系统中被视为与底层类型相同，主要用于提高代码可读性和语义表达。

------------------------------------------------
7. 零新增清单
------------------------------------------------
- 新关键字：0  
- 新标点：0  
- 新语法：复用已有 `interface` / `struct` / `fn` / `impl` / `()`  
- 编译器增量：≈ 200 行（裸名收集 + 单例替换）

------------------------------------------------
8. 向后兼容
------------------------------------------------
- 所有 1.6 源码**零修改**直接编译；  
- 只有出现"未声明类型名"时才触发泛型分支；  
- 单态化后仍走原有**零运行时、零 GC、编译期 UB 证明**全套流程。

------------------------------------------------
9. 一句话总结
------------------------------------------------
Uya 1.6 泛型 = **"签名里写个没声明的类型名"** + `impl` 时括号里给实参；零关键字、零符号、零运行时成本，单页纸读完，1.6 代码无缝继续用。

---

## 25 Uya 1.6 显式宏（可选增量）
——用 `mc` 区分宏与函数，零新关键字——

> **注意**：本章描述的是 0.13 版本的可选特性，作为增量文档提供。  
> — 单页纸，直接附在 0.13 规范末尾 —

------------------------------------------------
1. 语法增量（仅 1 个内置空结构体名）
------------------------------------------------
```uya
mc 名字(参数列表) 返回标签 { 宏体 }
```
| 位置 | 作用 |
|---|---|
| `mc` | 内置空结构体名，**非关键字** |
| 返回标签 | `expr` / `stmt` / `struct` / `type` （同隐式宏） |

------------------------------------------------
2. 示例：一眼分清宏与函数
------------------------------------------------
**对比展示**（注意：实际使用中不能同时存在同名）：

```uya
// ① 显式宏版本：参数全常量 ⇒ 编译期宏展开
mc twice(n: i32) expr { n + n }

// ② 普通函数版本：运行时函数调用
fn twice(n: i32) i32 { n + n }
```

**使用示例**（以宏版本为例）：

```uya
mc twice(n: i32) expr { n + n }

fn main() i32 {
    const a: i32 = twice(5);     // 宏展开为 5+5，零运行时
    var x: i32 = 10;
    const b: i32 = twice(x);     // 如果参数非常量，编译器根据宏定义处理
    return a + b;
}
```

> **重要**：同一作用域内 `mc twice` 与 `fn twice` **不能重名**（见第6节冲突规则）。  
> 如果需要同时提供宏和函数版本，请使用不同名称：`mc twice_mc` / `fn twice_fn`

------------------------------------------------
3. 优势：副作用归零
------------------------------------------------
| 问题 | 隐式宏 | 显式 mc |
|---|---|---|
| 语义双态 | 同一函数两种行为 | **静态分离**，无歧义 |
| 调试困惑 | 需看 `note:` 区分 | 符号表直接标 `mc` |
| 性能差异 | 靠日志暴露 | **一眼识别** |

------------------------------------------------
4. 零新增清单
------------------------------------------------
- 新关键字：0（`mc` 是内置空结构体名）  
- 新标点：0  
- 向后兼容：旧代码**零修改**继续编译；新增 `mc` 完全可选。

------------------------------------------------
5. 一句话总结
------------------------------------------------
**想零概念**→ 用隐式宏；**想零歧义**→ 写 `mc`。  
两字母，单页纸，今天就能定稿。

------------------------------------------------
6. 重名冲突规则（1 句话）
------------------------------------------------
同一作用域里，**符号名 + 种类标签** 必须唯一；  
`mc twice` 与 `fn twice` 属于**不同种类**，但**共享同一命名空间**，因此：

```uya
mc twice(n: i32) expr { n + n }   // ✅
fn twice(n: i32) i32  { n + n }   // ❌ 编译错误：名字 'twice' 已存在
```

------------------------------------------------
7. 为什么必须冲突
------------------------------------------------
- 如果允许重名，调用处又出现  
  ```uya
  const x: i32 = twice(5);
  ```
  编译器无法**静态决定**走宏路径还是函数路径，**语义双态**死灰复燃。  
- 把决策推迟到"是否全常量"⇒ 又回到**隐式宏**的老路。

------------------------------------------------
8. 缓解办法（已够用）
------------------------------------------------
| 方法 | 示例 |
|---|---|
| 改名 | `mc twice_mc` / `fn twice_fn` |
| 包级命名空间 | 后续版本 `mod` 打开后自然隔离 |
| 重载式命名 | `mc twice_int` / `fn twice_any` |

------------------------------------------------
9. 一句话总结
------------------------------------------------
用 `mc` 就得接受**"一名一义"**：同一作用域内 `mc` 与 `fn` 不能重名——**这是消除歧义的唯一代价，也是最后一道防线**。

---

## 26 一句话总结

> **Uya 1.6 = 默认即高级内存安全 + 并发安全 + 显式错误处理 + 测试单元**；
> **只加 1 个关键字 `atomic T`，其余零新符号**；
> **所有 UB 必须被编译期证明为安全 → 失败即编译错误**；
> **通过路径零指令，失败路径不存在，不降级、不插运行时锁。**

---

## 27 指针算术（1.6 版本新增）

### 27.1 设计目标
- **安全指针算术**：支持 `ptr +/- offset`，但必须通过编译期证明安全
- **零运行时开销**：所有边界检查在编译期完成
- **符合语言哲学**：所有指针操作必须被编译期证明为安全，失败即编译错误
- **程序员责任**：程序员必须提供边界检查，帮助编译器完成证明
- **编译器验证**：编译器验证这些证明，无法证明安全即编译错误

### 27.2 语法
```
ptr + offset    // 指针向后偏移
ptr - offset    // 指针向前偏移
ptr += offset   // 指针向后偏移并赋值
ptr -= offset   // 指针向前偏移并赋值
ptr1 - ptr2     // 指针间距离计算（返回usize）
```

**类型说明**：
- `offset` 的类型为 `usize`（平台相关的无符号整数类型）
- 指针间距离计算 `ptr1 - ptr2` 返回 `usize` 类型
- `usize` 在 32 位平台为 `u32`（4 字节），在 64 位平台为 `u64`（8 字节）
- `usize` 用于表示内存地址、数组索引和大小，保证能够表示平台上任意对象的大小

### 27.3 安全保证机制

#### 27.3.1 边界检查
- 每个指针算术操作必须有边界信息
- 编译器要求程序员提供边界证明
- 无法证明安全 → 编译错误

#### 27.3.2 指针来源追踪
- 指针必须来源于安全的内存区域（栈数组、堆分配、或已验证的指针）
- 编译器追踪指针的生命周期和边界信息

#### 27.3.3 指针算术示例
```uya
// 安全的指针算术示例
const arr: [i32; 10] = [0; 10];
const ptr: &i32 = &arr[0];  // 指向数组首元素的指针

// 指针算术，编译器可以证明安全性
const offset_ptr: &i32 = ptr + 5;  // 指向第6个元素
if offset_ptr < &arr[10] {       // 边界检查
    const val: i32 = *offset_ptr;   // 安全解引用
}

// 或者使用显式边界检查
fn safe_ptr_arith(arr: &[i32; 10], offset: usize) !&i32 {
    if offset >= 10 {
        return error.OutOfBounds;
    }
    return &arr[0] + offset;  // 编译器证明 offset < 10，安全
}
```

### 27.4 实现细节

#### 27.4.1 指针类型扩展
- `&T` - 普通指针，支持算术操作但需要边界证明
- `&[T]` - 指向数组的指针，携带长度信息
- `SliceT` - 切片类型，包含指针和长度信息

#### 27.4.2 边界信息
- 每个指针携带其有效范围信息
- 指针算术操作必须在有效范围内
- 超出范围 → 编译错误

#### 27.4.3 指针解引用
- 解引用前必须证明指针有效
- 空指针检查：`if ptr != null { ... }`
- 边界检查：`if ptr >= start && ptr < end { ... }`

### 27.5 语法示例

```uya
// 基本指针算术
const arr: [i32; 10] = [0; 10];
var ptr: &i32 = &arr[0];

// 安全的指针算术
for i: usize = 0; i < 10; i += 1 {
    const val: i32 = *(ptr + i);  // 编译器证明 i < 10，安全
    printf("arr[%d] = %d\n", i, val);
}

// 指针比较
const ptr1: &i32 = &arr[2];
const ptr2: &i32 = &arr[5];
const diff: usize = ptr2 - ptr1;  // 结果为 3

// 边界检查的指针操作
fn process_range(start: &i32, end: &i32) void {
    var current: &i32 = start;
    while current < end {
        printf("%d ", *current);
        current = current + 1;  // 编译器证明不会越界
    }
}
```

### 27.6 编译期验证

1. **常量偏移**：编译期直接验证
2. **变量偏移**：需要程序员提供边界证明
3. **指针有效性**：编译器追踪指针来源和生命周期

### 27.7 错误处理

- 指针算术无法证明安全 → 编译错误
- 提供清晰的错误信息和修复建议
- 支持 `!&T` 错误联合类型返回

---

## 28 Uya 1.6 测试单元（Test Block）

——单页纸，零新关键字，独立 `./uyac test` 入口——

> 本章作为 1.6 规范的**可选增量**，附于原规范末尾；老代码**零修改**继续编译。

------------------------------------------------
### 28.1 设计目标
------------------------------------------------
- **唯一入口**：`./uyac test` 专用于运行测试；  
- **零副作用**：不改动用户 `main`，不注入测试 runner；  
- **行为一致**：  
  - 扫描**所有 `.uya`**，执行 `test "..." { }`；  
  - 成功静默，失败打印详情并返回码 `1`；  
  - 支持 `return error.TestFailed;` 标记失败；  
- **单页纸**：语法、命令、实现要点一页放完。

------------------------------------------------
### 28.2 语法（复用已有符号）
------------------------------------------------
```uya
test "说明文字" {
    // 任意函数体语句
}
```
- 可写在**任意文件、任意作用域**（顶层/函数内/嵌套块）；  
- 编译器在**测试模式**下将其视为**无参、返回 `!void`** 的隐藏函数：  
  ```uya
  fn @test$<hash>() !void { ... }
  ```

------------------------------------------------
### 28.3 命令行约定
------------------------------------------------
| 模式 | 命令 | 行为 |
|---|---|---|
| 生产模式 | `uyac main.uya` / `uyac .` | 无视 `test` 块，生成原 `main` 可执行文件； |
| 测试模式 | `uyac test` | 仅扫描并运行所有 `test` 块，**不生成 main 可执行文件**； |

> 编译器新增 `-test` 内部标志，CLI 检测到 `test` 子命令即置位。

------------------------------------------------
### 28.4 运行流程（编译期完成）
------------------------------------------------
1. 前端扫描全部 `.uya`，收集 `test "..." { }`；  
2. 为每个测试生成隐藏函数 `@test$<hash>()`；  
3. 生成**临时 `main`**（仅测试模式可见）：  
   ```uya
   fn main() i32 {
       run_all_tests();   // 依次调用 @test$<hash>() catch ...
       return 0;          // 全部通过
   }
   ```
4. 链接并执行该临时可执行文件；  
5. 测试失败 → 打印失败信息 + 进程返回码 `1`；  
6. 测试通过 → 静默，返回码 `0`。

------------------------------------------------
### 28.5 预定义错误（可选）
------------------------------------------------
```uya
error TestFailed;   // 手动失败时返回
```
也可直接 `return error.TestFailed;` 而无需预定义。

------------------------------------------------
### 28.6 完整示例
------------------------------------------------
```bash
$ tree
.
├── main.uya
└── math.uya
```

```uya
// math.uya
fn add(a: i32, b: i32) i32 { return a + b; }

test "add overflow" {
    const x: i32 = max;
    const y: i32 = try x + 1 catch |err| {
        if err == error.Overflow { return; }
        return error.TestFailed;
    };
    return error.TestFailed;   // 未溢出则失败
}
```

```uya
// main.uya
extern i32 printf(byte* fmt, ...);

test "hello" {
    printf("hello test\n");
}

fn main() i32 {        // 用户 main 完全不受影响
    printf("user main\n");
    return 0;
}
```

**运行对比**
```bash
# 生产模式
$ uyac . && ./main
user main
$ echo $?
0

# 测试模式
$ uyac test
running 2 tests...
ok   add overflow
ok   hello
test result: ok. 2 passed; 0 failed.
$ echo $?
0

# 若测试返回 error.TestFailed
$ uyac test
running 2 tests...
ok   add overflow
FAIL hello
test result: FAILED. 1 passed; 1 failed.
$ echo $?
1
```

------------------------------------------------
### 28.7 进阶能力
------------------------------------------------
- **访问私有项**：测试块与源码同模块，可直接使用未 `export` 的 `struct` / `fn`；  
- **并发测试**：  
  ```uya
  test "atomic counter" {
      const c: Counter = Counter{ value: atomic i32 = 0; };
      // 多线程递增，最后断言
  }
  ```  
  享受 1.6 默认并发安全保证；  
- **泛型测试**：  
  ```uya
  test "Vec(i32) push" {
      var v: Vec(i32) = Vec(i32){ ... };
      // ...
  }
  ```

------------------------------------------------
### 28.8 零新增清单
------------------------------------------------
- 新关键字：0  
- 新标点：0  
- 新子命令：1 个（`test`）  
- 编译器增量：≈ 120 行（扫描 + 临时 main 生成）

------------------------------------------------
### 28.9 一句话总结
------------------------------------------------
**`uyac test`** 扫描全部 `test "..." { }` → 独立生成测试可执行文件 → 成功静默/失败返回 1；**不改用户 main、零关键字、单页纸，今天就能用**。

---

## 29 未实现/将来

### 29.1 核心特性（计划中）
- **官方包管理器**：`uyapm`
  - 依赖管理和包分发系统
  - 支持版本管理和依赖解析

### 29.2 drop 机制增强（后续版本）
- **移动语义优化**：避免不必要的拷贝
  - 赋值、函数参数、返回值自动使用移动语义
  - 零开销的所有权转移，提高性能
  - 详见未来版本文档
- **drop 标记**：`#[no_drop]` 用于无需清理的类型
  - 标记纯数据类型，编译器跳过 drop 调用
  - 进一步优化性能，零运行时开销

### 29.3 类型系统增强（后续版本）
- **类型推断增强**：局部类型推断
  - 函数内支持类型推断，函数签名仍需显式类型
  - 提高代码简洁性，保持可读性
  - 示例：`const x = 10;` 自动推断为 `i32`（注意：0.13 不支持类型推断，需要显式类型注解）

### 29.4 AI 友好性增强（后续版本）
- **标准库文档字符串**：注释式或结构化文档
  - 帮助 AI 理解函数用途、参数、返回值
  - 提高代码生成准确性
- **更丰富的错误信息**：详细的错误描述和修复建议
  - 类型错误、作用域错误、语法错误的详细说明
  - 提供修复建议，帮助 AI 和用户快速定位问题

### 29.5 已实现特性（0.15 版本）
以下特性已在 0.15 版本中实现，详见对应章节：
- ✅ **模块系统**（v1.4）：第 1.5 章 - 模块系统（v1.4）
- ✅ **泛型**：第 24 章 - Uya 1.6 泛型增量文档
- ✅ **显式宏**：第 25 章 - Uya 1.6 显式宏（可选增量）
- ✅ **sizeof 和 alignof**：第 16 章 - 标准库（1.6 最小集）
- ✅ **类型别名**：第 24 章 6.2 节 - 类型别名实现
- ✅ **for 循环**：第 8 章 - for 循环迭代（简化语法：`for obj |v| {}`、`for 0..10 |v| {}`、`for obj |&v| {}`）
- ✅ **运算符简化**：第 10 章 - `try` 关键字用于溢出检查，饱和运算符（`+|`, `-|`, `*|`），包装运算符（`+%`, `-%`, `*%`）
- ✅ **测试单元**：第 28 章 - Uya 0.15 测试单元（Test Block）

---

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

- **编译期证明**：编译器在编译期验证代码的安全性，无法证明安全即编译错误，不生成代码。

- **路径敏感分析**：编译器跟踪所有代码路径，分析变量状态和条件分支，建立约束条件。

- **常量折叠**：编译期常量直接求值，溢出/越界立即报错。

- **单态化**：泛型函数/结构体在调用时根据具体类型生成对应的代码，零运行时派发。

### 内存管理

- **栈式数组**：使用 `var buf: [T; N] = [];` 在栈上分配数组，零 GC，生命周期由作用域决定。

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

- **`Self`**：接口方法签名中的特殊占位符，代表实现该接口的具体结构体类型。仅在接口定义和 `impl` 块中使用。

- **`max/min` 关键字**：访问整数类型极值的语言关键字。编译器从上下文类型自动推断极值类型，这些是编译期常量。例如：`const MAX: i32 = max;`（`max` 从类型注解 `i32` 推断为 i32 的最大值）。

- **饱和运算符**：`+|`（饱和加法）、`-|`（饱和减法）、`*|`（饱和乘法）。溢出时返回类型的最大值或最小值（上溢返回最大值，下溢返回最小值），而不是返回错误。

- **编译期展开**：某些操作在编译期完成，零运行时开销。例如字符串插值的缓冲区大小计算、`try` 关键字的溢出检查展开。

- **零运行时开销**：通过路径零指令，失败路径不存在，不生成额外的运行时检查代码。所有安全检查在编译期完成。

---

