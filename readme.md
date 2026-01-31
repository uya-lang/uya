# Uya 编程语言

> 零GC · 默认高级安全 · 单页纸可读完  
> 无lifetime符号 · 无隐式控制 · 编译期证明（本函数内）

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 简介

Uya 是一个系统编程语言，专注于**内存安全**、**并发安全**和**零运行时开销**。设计目标是提供高级别的安全性，同时保持高性能和简洁性。

## 核心特性

### 语言特性

- **泛型语法**：使用括号 `()` 代替尖括号 `<>`（`Vec(T)`、`HashMap(K, V)`、`Result(T, E)`）
- **extern struct 完全解放**：C 兼容结构体可以有方法、drop、实现接口，同时保持 100% C 兼容性
- **内存安全强制**：所有 UB 必须被编译期证明为安全，失败即编译错误
- **并发安全强制**：`atomic T` 关键字，自动原子指令，零数据竞争，零运行时锁
- **错误处理**：显式错误联合类型 `!T`，支持预定义和运行时错误
- **接口系统**：鸭子类型接口，零注册，编译期生成
- **模块系统**：目录级模块、显式导出、路径导入，编译期解析
- **字符串插值**：支持 `"a${x}"` 和 `"pi=${pi:.2f}"` 两种形式
- **切片语法**：支持 `&arr[start:len]` 返回切片视图，包括负数索引，for循环支持值/引用/索引迭代
- **安全指针算术**：支持 `ptr +/- offset`，必须通过编译期证明安全
- **类型大小和对齐**：`@sizeof(T)` 和 `@alignof(T)` 等内置函数（均以 `@` 开头，编译期常量，无需导入）

### 设计原则

- ✅ **零新符号**：泛型用 `()`，不是 `<>`；复用已有语法，不发明新符号
- ✅ **单页纸可读完**：语法简单到可以记在脑子里，概念最少但能力完整
- ✅ **编译期证明**：编译器在当前函数内验证安全性，无法证明则编译错误
- ✅ **编译期证明**：所有内存安全在编译期验证，零运行时不确定性

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
extern printf(fmt: *byte, ...) i32;

// extern struct 完全解放：C 兼容结构体获得 Uya 超能力
extern struct File {
  fd: i32
  fn read(self: *Self, buf: *byte, len: i32) !i32 { /* ... */ }
  fn drop(self: *Self) void { close(self.fd); }
}

// 泛型（使用括号，不是尖括号）
struct Vec(T) {
  data: [T: 10],
  len: i32
}
fn create_vec() Vec(i32) {
  return Vec(i32){ data: [0: 10], len: 0 };
}

// 显式宏（可选特性）
mc twice(n: i32) expr { n + n }

// 模块系统
// project/main.uya (main 模块)
export fn helper_func() i32 {
    return 42;
}

// project/std/io/file.uya (std.io 模块)
use main.helper_func;  // 导入 main 模块的函数

export struct File {
    fd: i32
}

export fn open_file(path: *byte) !File {
    let value: i32 = helper_func();  // 使用导入的函数
    return File{ fd: 1 };
}

// 切片语法：&arr[start:len] 返回切片视图，支持负数索引
var arr: [i32: 10] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
const slice: &[i32] = &arr[2:5];      // 动态长度切片
const exact_slice: &[i32: 3] = &arr[2:3]; // 已知长度切片
const tail: &[i32] = &arr[-3:3];      // 负数索引，等价于 &arr[7:3]

// for循环支持切片迭代
for slice |value| { }        // 值迭代（只读）
for slice |&ptr| { }         // 引用迭代（可修改）
for slice |i| { }            // 索引迭代

// 安全指针算术：ptr +/- offset，编译器验证边界安全
const ptr: &i32 = &arr[0];
const offset_ptr: &i32 = ptr + 5;  // 编译器证明安全

fn main() i32 {
  printf("Hello, Uya!\n");
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

### 核心创新（0.33 版本）

#### 1. 泛型用括号 `()`，不是尖括号 `<>`

```uya
// 其他语言：Vec<T>、HashMap<K, V>
// Uya：Vec(T)、HashMap(K, V)
// 更清晰，更一致，零新符号
```

#### 2. extern struct 完全解放

```uya
extern struct File {
    fd: i32
    fn read(self: *Self, buf: *byte, len: i32) !i32 { /* ... */ }
    fn drop(self: *Self) void { close(self.fd); }
}

File : IReadable { /* ... */ }
```

**最酷的部分**：同一个结构体，两面性：
- **C 代码看到**：纯数据，标准布局，100% C 兼容
- **Uya 代码看到**：完整对象，有方法、接口、RAII，100% Uya 能力

> **注**：如需了解 Uya 与其他语言的详细对比，请参阅 [comparison.md](./comparison.md)

### 核心收益

- **数学证明的确定性**：每个数组访问都有明确的数学证明（`i >= 0 && i < len`）
- **消除整类安全漏洞**：彻底消除缓冲区溢出等内存安全漏洞
- **编译期证明**：所有检查在编译期完成（在当前函数内），无法证明则编译错误
- **失败路径不存在**：无法证明安全的代码不生成，运行时不会出现未定义行为

## 类型系统

| Uya 类型 | 大小/对齐 | 备注 |
|---------|-----------|------|
| `i8` `i16` `i32` `i64` | 1 2 4 8 B | 对齐 = 类型大小；支持 `@max`/`@min` 内置函数访问极值 |
| `u8` `u16` `u32` `u64` | 1 2 4 8 B | 对齐 = 类型大小；无符号整数类型 |
| `f32` `f64` | 4/8 B | 对齐 = 类型大小 |
| `bool` | 1 B | 0/1，对齐 1 B |
| `byte` | 1 B | 无符号字节，对齐 1 B，用于字节数组 |
| `void` | 0 B | 仅用于函数返回类型 |
| `*byte` | 4/8 B（平台相关） | FFI 指针类型 `*T` 的一个实例（T=byte），用于 FFI 函数参数和返回值，指向 C 字符串；32位平台=4B，64位平台=8B；可与 `null` 比较（空指针）；FFI 指针类型 `*T` 支持所有 C 兼容类型（见 uya.md 第 5.2 章）|
| `&T` | 4/8 B（平台相关） | 普通指针类型，无 lifetime 符号；32位平台=4B，64位平台=8B |
| `&atomic T` | 4/8 B（平台相关） | 原子指针，关键字驱动；32位平台=4B，64位平台=8B |
| `atomic T` | sizeof(T) | 语言级原子类型 |
| `[T: N]` | N·sizeof(T) | N 为编译期正整数，对齐 = T 的对齐 |
| `&[T]` | 8/16 B（平台相关） | 切片引用（动态长度），指针(4/8B) + 长度(4/8B)；32位平台=8B，64位平台=16B |
| `&[T: N]` | 8/16 B（平台相关） | 切片引用（编译期已知长度），指针(4/8B) + 长度(4/8B)；32位平台=8B，64位平台=16B |
| `struct S { }` | 字段顺序布局 | 对齐 = 最大字段对齐 |
| `interface I { }` | 8/16 B（平台相关） | vtable 指针(4/8B) + 数据指针(4/8B)；32位平台=8B，64位平台=16B |
| `enum E { }` | sizeof(底层类型) | 枚举类型，默认底层类型为 i32 |
| `(T1, T2, ...)` | 字段顺序布局 | 元组类型，对齐 = 最大字段对齐 |
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
- **编译期证明**：编译器在当前函数内验证安全性，无法证明则编译错误
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

## 当前状态（v0.1.0）

- **Uya Mini 编译器**：已实现 Uya 语言最小可自举子集，支持 LLVM 与 C99 双后端；**自举已达成**（编译器能编译自身，且与 C 编译器生成的 C 输出一致）。详见 [RELEASE_v0.1.0.md](./RELEASE_v0.1.0.md)。
- **语言规范**：完整版见 [uya.md](./uya.md)；当前编译器仅实现 Uya Mini 子集。

## 文档

- **[uya.md](./uya.md)** - 完整语言规范（Markdown）
- **[index.html](./index.html)** - 语言介绍与规范（HTML）
- **[RELEASE_v0.1.0.md](./RELEASE_v0.1.0.md)** - v0.1.0 版本说明
- **[comparison.md](./comparison.md)** - 与其他语言的对比
- **[compiler-mini/](./compiler-mini/)** - Uya Mini 编译器（最小子集，已自举）
- **[changelog.md](./changelog.md)** - 语言规范变更历史

## 一句话总结

> **Uya = 默认即高级内存安全 + 并发安全 + 显式错误处理 + 切片语法 + 安全指针算术 + @sizeof/@alignof**；  
> **泛型用 `()` 不是 `<>`，extern struct 完全解放，C 结构体获得 Uya 超能力**；  
> **只加 1 个关键字 `atomic T`，其余零新符号**；  
> **所有 UB 必须被编译期证明为安全 → 失败即编译错误**；  
> **编译期证明（本函数内），无法证明则编译错误，不降级、不插运行时锁。**

## 贡献

欢迎贡献代码、报告问题或提出建议！

---

**注意**：语言规范为完整版（0.33）；**v0.1.0** 发布的是 Uya Mini 编译器（最小子集，已自举）。完整特性与未来计划见 [uya.md](./uya.md)。

**许可证**：本项目采用 [MIT 许可证](./LICENSE)。Copyright (c) 2025 Uya 语言项目


