# Uya 编程语言

> 零GC · 默认高级安全 · 单页纸可读完 · 通过路径零指令  
> 无lifetime符号 · 无隐式控制

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 简介

Uya 是一个系统编程语言，专注于**内存安全**、**并发安全**和**零运行时开销**。设计目标是提供高级别的安全性，同时保持高性能和简洁性。

## 核心特性

### 0.13 版本核心特性

- **模块系统**（v1.4）：目录级模块、显式导出、路径导入，编译期解析，零运行时开销
- **原子类型**：`atomic T` 关键字，自动原子指令，零运行时锁
- **内存安全强制**：所有 UB 必须被编译期证明为安全，失败即编译错误
- **并发安全强制**：零数据竞争，通过路径零指令
- **字符串插值**：支持 `"a${x}"` 和 `"pi=${pi:.2f}"` 两种形式
- **灵活错误处理**：支持预定义错误和运行时错误（无需预定义）
- **切片语法**：支持切片语法 `slice(arr, start, len)` 和 `arr[start:len]`，包括负数索引
- **安全指针算术**：支持 `ptr +/- offset` 操作，必须通过编译期证明安全
- **中间表示（IR）**：C语言友好的中间表示，支持切片操作的零运行时开销实现
- **类型检查器**：编译期类型和内存安全验证，确保所有UB被证明安全

### 设计亮点

- ✅ **零 GC**：栈式数组，无垃圾回收
- ✅ **编译期证明**：所有内存安全在编译期验证
- ✅ **零运行时开销**：通过路径零指令，失败路径不存在
- ✅ **简洁语法**：无 lifetime 符号，无隐式控制
- ✅ **RAII 支持**：自动资源管理
- ✅ **错误处理**：显式错误联合类型 `!T` 和 `try/catch`，支持预定义错误和运行时错误（无需预定义）
- ✅ **接口系统**：鸭子类型接口，零注册，编译期生成
- ✅ **FFI 支持**：无缝调用外部函数
- ✅ **模块系统**：目录级模块、显式导出、路径导入，编译期解析
- ✅ **泛型支持**：零新关键字，向后 100% 兼容
- ✅ **显式宏**：使用 `mc` 区分宏与函数，零歧义
- ✅ **切片操作**：支持切片语法 `slice(arr, start, len)` 和 `arr[start:len]`，包括负数索引
- ✅ **安全指针算术**：支持指针算术操作，通过编译期证明保证安全
- ✅ **IR支持**：C语言友好的中间表示，便于代码生成和优化
- ✅ **类型检查**：编译期类型和内存安全验证，确保零运行时错误

## 快速开始

### 示例代码

```uya
// 结构体定义
struct Vec3 {
  x: f32,
  y: f32,
  z: f32
}

// 函数定义
fn add(a: i32, b: i32) i32 {
  return a + b;
}

// 错误处理（支持预定义和运行时错误）
error DivisionByZero;  // 预定义错误（可选）

fn safe_divide(a: i32, b: i32) !i32 {
    if b == 0 {
        return error.DivisionByZero;  // 预定义错误
    }
    if a < 0 {
        return error.NegativeInput;   // 运行时错误，无需预定义
    }
    return a / b;
}

// 原子操作
struct Counter {
  value: atomic i32
}

fn increment(counter: *Counter) void {
  counter.value += 1;  // 自动原子 fetch_add
}

// 接口
interface IWriter {
  fn write(self: *Self, buf: *byte, len: i32) i32;
}

// FFI 调用
extern i32 printf(byte* fmt, ...);

// 泛型函数（可选特性）
fn id(x: T) T {
  return x;
}

// 显式宏（可选特性）
mc twice(n: i32) expr { n + n }

// 模块系统（v1.4）
// project/main.uya (main 模块)
export fn helper_func() i32 {
    return 42;
}

// project/std/io/file.uya (std.io 模块)
use main.helper_func;  // 导入 main 模块的函数

export struct File {
    fd: i32
}

export fn open_file(path: byte*) !File {
    let value: i32 = helper_func();  // 使用导入的函数
    return File{ fd: 1 };
}

// 数组切片操作
fn slice_example() void {
  const arr: [i32; 10] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

  // 基本切片：slice(arr, start, len) 返回从索引start开始，长度为len的元素
  const slice1: [i32; 3] = slice(arr, 2, 3);  // [2, 3, 4]

  // 操作符语法：arr[start:len] 等价于 slice(arr, start, len)
  const slice1b: [i32; 3] = arr[2:3];  // [2, 3, 4]，从索引2开始，长度为3

  // start 支持负数索引：-1表示最后一个元素，-2表示倒数第二个元素，以此类推
  // 负数索引从数组末尾开始计算：-n 转换为 len(arr) - n
  const slice2: [i32; 3] = slice(arr, -3, 3);  // [7, 8, 9]，从倒数第3个开始，长度为3
  const slice2b: [i32; 1] = slice(arr, -1, 1);  // [9]，从最后一个元素开始，长度为1

  // 操作符语法的负数索引
  const slice2c: [i32; 3] = arr[-3:3];  // [7, 8, 9]，从倒数第3个开始，长度为3

  // 从某个索引开始
  const slice3: [i32; 3] = slice(arr, 7, 3);   // [7, 8, 9]

  // 从开头开始
  const slice4: [i32; 3] = slice(arr, 0, 3);    // [0, 1, 2]
}

// 安全指针算术操作
fn pointer_arith_example() void {
  const arr: [i32; 10] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  const ptr: &i32 = &arr[0];  // 指向数组首元素的指针

  // 指针算术：ptr + offset，编译器验证边界安全
  const offset_ptr: &i32 = ptr + 5;  // 指向第6个元素
  if offset_ptr < &arr[10] {       // 边界检查
    const val: i32 = *offset_ptr;    // 安全解引用
    printf("Value at offset 5: %d\n", val);
  }

  // 循环中的指针算术
  for i: i32 = 0; i < 10; i += 1 {
    const current_ptr: &i32 = ptr + i;  // 编译器证明 i < 10，安全
    printf("arr[%d] = %d\n", i, *current_ptr);
  }
}

fn main() i32 {
  printf("Hello, Uya!\n");

  // 使用泛型
  const x: i32 = id(42);

  // 使用宏
  const y: i32 = twice(5);  // 编译期展开为 5 + 5

  // 使用切片
  slice_example();

  // 使用指针算术
  pointer_arith_example();

  return 0;
}
```

## 设计哲学

### 核心思想

将运行时的"可能越界"转化为编译期的"要么证明安全，要么返回显式错误"。

**核心机制**：
- 程序员必须提供**显式边界检查**，帮助编译器完成证明
- 编译器在编译期验证这些证明，无法证明安全即编译错误
- 每个数组访问都有明确的**数学证明**，消除运行时不确定性

### 责任转移

Uya 采用**程序员提供证明，编译器验证证明**的设计哲学。程序员必须提供显式边界检查，编译器在编译期验证这些证明，无法证明安全即编译错误。

> **注**：如需了解 Uya 与其他语言的详细对比，请参阅 [COMPARISON.md](./COMPARISON.md)

### 结果与收益

1. **数学证明的确定性**：每个数组访问都有明确的数学证明（`i >= 0 && i < len`）
2. **消除整类安全漏洞**：彻底消除缓冲区溢出等内存安全漏洞
3. **零运行时开销**：所有检查在编译期完成，通过路径零指令
4. **失败路径不存在**：无法证明安全的代码不生成，运行时不会出现未定义行为

## 类型系统

| Uya 类型 | 大小/对齐 | 备注 |
|---------|-----------|------|
| `i8` `i16` `i32` `i64` | 1 2 4 8 B | 对齐 = 类型大小；支持 `max/min` 关键字访问极值 |
| `u8` `u16` `u32` `u64` | 1 2 4 8 B | 对齐 = 类型大小；无符号整数类型 |
| `f32` `f64` | 4/8 B | 对齐 = 类型大小 |
| `bool` | 1 B | 0/1，对齐 1 B |
| `byte` | 1 B | 无符号字节，对齐 1 B，用于字节数组 |
| `void` | 0 B | 仅用于函数返回类型 |
| `byte*` | 4/8 B（平台相关） | 用于 FFI，指向字符串；32位平台=4B，64位平台=8B；可与 `null` 比较 |
| `&T` | 8 B | 普通指针类型，无 lifetime 符号 |
| `&atomic T` | 8 B | 原子指针，关键字驱动 |
| `atomic T` | sizeof(T) | 语言级原子类型 |
| `[T; N]` | N·sizeof(T) | N 为编译期正整数，对齐 = T 的对齐 |
| `struct S { }` | 字段顺序布局 | 对齐 = 最大字段对齐 |
| `interface I { }` | 16 B (64位) | vtable 指针(8B) + 数据指针(8B) |
| `!T` | 错误联合类型 | max(sizeof(T), sizeof(错误标记)) + 对齐填充 | `T \| Error` |

## 内存安全

### 强制规则

所有 UB 场景必须被编译期证明为安全，失败即编译错误：

1. **数组越界访问**：常量索引越界 → 编译错误；变量索引 → 必须证明 `i >= 0 && i < len`
2. **整数溢出**：必须证明无溢出，证明失败 → 编译错误
3. **除零错误**：常量除零 → 编译错误；变量 → 必须证明 `y != 0`
4. **使用未初始化内存**：必须证明「首次使用前已赋值」
5. **空指针解引用**：必须证明 `ptr != null` 或前序有检查

### 安全策略

- **编译期证明**：所有 UB 必须被编译器证明为安全
- **失败即错误**：证明失败 → 编译错误，不生成代码
- **零运行时开销**：通过路径零指令，失败路径不存在
- **无 panic、无 catch、无断言**：所有检查在编译期完成

## 并发安全

### 机制

- **原子类型 `atomic T`** → 语言层原子
- **读/写/复合赋值 = 自动原子指令** → **零运行时锁**
- **数据竞争 = 零**（所有原子操作自动序列化）
- **零新符号**：无需额外的语法标记

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

## 文档

完整的语言规范请参阅：
- **[uya.md](./uya.md)** - Markdown 格式的完整语言规范
- **[index.html](./index.html)** - HTML 格式（深色主题）的完整语言规范，适合在线浏览和打印

文档包含：
- 完整的语法规范
- 类型系统详解
- 模块系统（v1.4）
- 内存模型和 RAII
- 错误处理机制
- 接口系统
- 原子操作
- 泛型系统（可选特性）
- 显式宏系统（可选特性）
- 完整示例代码

## 许可证

本项目采用 [MIT 许可证](./LICENSE)。

Copyright (c) 2025 zigger

## 一句话总结

> **Uya 0.13 = 默认即高级内存安全 + 并发安全 + 显式错误处理 + 切片语法 + 安全指针算术**；
> **只加 1 个关键字 `atomic T`，其余零新符号**；
> **所有 UB 必须被编译期证明为安全 → 失败即编译错误**；
> **通过路径零指令，失败路径不存在，不降级、不插运行时锁。**

## 贡献

欢迎贡献代码、报告问题或提出建议！

### 新增功能
- **模块系统**（v1.4）：目录级模块、显式导出、路径导入，编译期解析，零运行时开销
- **切片语法**：支持切片操作 `slice(arr, start, len)`，包括负数索引支持
- **安全指针算术**：支持 `ptr +/- offset` 操作，通过编译期证明保证内存安全

## 相关链接

- [语言规范文档（Markdown）](./uya.md)
- [语言规范文档（HTML，深色主题）](./index.html)
- [许可证](./LICENSE)

---

**注意**：Uya 语言目前处于开发阶段（**0.13 版本**），部分特性可能尚未完全实现。请参考 [uya.md](./uya.md) 了解当前版本的限制和未来计划。


