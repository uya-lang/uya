# Uya 编程语言

> 零GC · 默认高级安全 · 单页纸可读完  
> 无lifetime符号 · 无隐式控制 · 编译期证明（本函数内）

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 简介

Uya 是一个系统编程语言，专注于**内存安全**、**并发安全**和**零运行时开销**。设计目标是提供高级别的安全性，同时保持高性能和简洁性。

## 核心特性

### 语言特性

- **联合体（union）**：编译期标签跟踪，与 C union 100% 互操作，零运行时开销
- **泛型语法**：使用尖括号 `<T>`，约束紧邻参数 `<T: Ord>`，多约束连接 `<T: Ord + Clone + Default>`（`Vec<i32>`、`HashMap<K, V>`）
- **数字字面量增强**：支持多进制（十六进制 `0xFF`、八进制 `0o755`、二进制 `0b1010`）和下划线分隔符（`1_000_000`、`0xFF_00_AA`）
- **extern struct 完全解放**：C 兼容结构体可以有方法、drop、实现接口，同时保持 100% C 兼容性
- **内存安全强制**：所有 UB 必须被编译期证明为安全，失败即编译错误
- **并发安全强制**：`atomic T` 关键字，自动原子指令，零数据竞争，零运行时锁
- **错误处理**：显式错误联合类型 `!T`，支持预定义和运行时错误
- **接口系统**：鸭子类型接口，零注册，编译期生成
- **模块系统**：目录级模块、显式导出、路径导入，编译期解析
- **字符串插值**：支持 `"a${x}"` 和 `"pi=${pi:.2f}"` 两种形式
- **切片语法**：支持 `&arr[start:len]` 返回切片视图，包括负数索引，for循环支持值/引用/索引迭代
- **安全指针算术**：支持 `ptr +/- offset`，必须通过编译期证明安全
- **类型大小和对齐**：`@size_of(T)` 和 `@align_of(T)` 等内置函数（均以 `@` 开头，编译期常量，无需导入）
- **SIMD 向量内建**：支持 `@vector(T, N)`、`@mask(N)`、`@vector.splat`、`@vector.any`、`@vector.all` 的语言级规范

### 设计原则

- ✅ **泛型语法**：使用尖括号 `<T>`，约束紧邻参数 `<T: Ord>`，多约束连接 `<T: Ord + Clone + Default>`
- ✅ **单页纸可读完**：语法简单到可以记在脑子里，概念最少但能力完整
- ✅ **编译期证明**：编译器在当前函数内验证安全性，无法证明则编译错误
- ✅ **无隐式捕获闭包**：1.0 明确不提供捕获闭包（与"无 lifetime 符号 / 零 GC"冲突）；回调用**函数指针 + 显式 context**，详见 [uya.md §5.2.3](docs/uya.md)

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
  fn write(self: &Self, buf: *byte, len: i32) i32;
}

// FFI 调用
extern printf(fmt: *byte, ...) i32;

// extern struct 完全解放：C 兼容结构体获得 Uya 超能力
extern struct File {
  fd: i32
  fn read(self: &Self, buf: *byte, len: i32) !i32 { /* ... */ }
  fn drop(self: &Self) void { close(self.fd); }
}

// 泛型
struct Vec<T: Default> {
  data: &T,
  len: i32,
  cap: i32
}
fn create_vec() Vec<i32> {
  return Vec<i32>{ data: ..., len: 0, cap: 0 };
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

## 标准库 HTTP（实验性）

`lib/std/http/` 当前提供：

- 阻塞式解析、路由与最小服务器原语（`types` / `parse` / `router` / `server`）
- 实验性 Gin 风格异步框架 `std.http.uyagin`
- HTTP/1.1 chunked request 原地解码、显式 chunked response
- 响应 `writev` 聚合写，以及 Linux x86_64 文件响应 `sendfile` 优先路径
- 通过 `tls.https` 适配的最小 HTTPS -> UyaGin 服务端桥接

示例见根目录 [`examples/http_server.uya`](examples/http_server.uya)；UyaGin 路线图见 [`docs/uyagin_todo.md`](docs/uyagin_todo.md)。

开发与回归要求：

- 新用例按 **TDD**：先写 `tests/test_http_*.uya`（`test "..." {}` 风格），再改实现。
- 合并前跑通 **`make check`**（自举 + 全量测试）。
- HTTP 相关程序/测试须同时通过 **`./tests/run_programs_parallel.sh --c99`** 与 **`--uya --c99`**（与仓库内其他 `std` 测试一致）。

详细路线图见 [`docs/todo_http.md`](docs/todo_http.md)、[`docs/http_framework_design.md`](docs/http_framework_design.md)。

## 标准库 Crypto

`lib/std/crypto/` 当前提供一组纯 Uya 的摘要、MAC 与校验能力：

- `use std.crypto.blake2b.blake2b_digest;`
- `use std.crypto.blake2s.blake2s_digest;`
- `use std.crypto.blake3.blake3_digest;`
- `use std.crypto.sha256.sha256_digest;`
- `use std.crypto.hmac_sha256.hmac_sha256;`
- `use std.crypto.md5.md5_digest;`
- `use std.crypto.crc32.crc32_compute;`

最小示例：

```uya
use std.crypto.md5.md5_digest;
use std.crypto.crc32.crc32_compute;

var digest: [byte: 16] = [];
md5_digest(&"abc"[0: 3], digest[0: 16]);

const checksum: u32 = crc32_compute(&"123456789"[0: 9]);
```

## 标准库 SQL（实验性）

`lib/std/sql/` 当前提供一层参考 Go `database/sql` 设计的通用抽象，包含：

- `std.sql.types`：`Value`、`NamedArg`、`ColumnInfo`
- `std.sql.driver`：`Driver`、`Conn`、`Stmt`、`Rows`、`Tx`、`Result`
- `std.sql.db`：高层 `DB` / `Row` 包装与 `db_open`

当前仓库已包含：

- 首版抽象实现：`lib/std/sql/`
- 回归测试：`tests/test_std_sql.uya`

当前状态：

- 已跑通 fake driver 端到端链路
- 接口形状已稳定到当前 C99 backend 可接受的实现方式
- SQLite / MySQL 等真实驱动尚未并入仓库主线

如果你要接 SQLite、MySQL 或 MariaDB，推荐先实现一个具体驱动模块，再通过 `db_open(driver, dsn)` 暴露给业务代码。详细说明见 [`docs/std_sql.md`](docs/std_sql.md)。

## 设计哲学

### 核心思想

将运行时的"可能越界"转化为编译期的"要么证明安全，要么返回显式错误"。

**核心机制**：
- 程序员必须提供**显式边界检查**，帮助编译器完成证明
- 编译器在编译期验证这些证明，无法证明安全即编译错误
- 每个数组访问都有明确的**数学证明**，消除运行时不确定性

### 责任转移

Uya 采用**程序员提供证明，编译器验证证明**的设计哲学。程序员必须提供显式边界检查，编译器在编译期验证这些证明，无法证明安全即编译错误。

### 核心创新（0.38 版本）

#### 1. 泛型语法确定（使用尖括号 `<T>`）

```uya
// 函数泛型：fn max<T: Ord>(a: T, b: T) T { ... }
// 结构体泛型：struct Vec<T: Default> { ... }
// 接口泛型：interface Iterator<T> { ... }
// 类型参数使用：Vec<i32>、Iterator<String>
// 约束语法：<T: Ord>、<T: Ord + Clone + Default>
```

#### 2. extern struct 完全解放

```uya
extern struct File {
    fd: i32
    fn read(self: &Self, buf: *byte, len: i32) !i32 { /* ... */ }
    fn drop(self: &Self) void { close(self.fd); }
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
| `@vector(T, N)` | N·sizeof(T) | SIMD 向量类型，元素 `T`、通道 `N`；第一阶段语义允许标量回退 lowering |
| `@mask(N)` | N 通道 | SIMD 掩码类型；向量比较结果类型，不隐式转换为 `bool` |
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

## 当前状态（v0.10.1）

- **自举编译器**：已完成自举，所有测试通过。编译器能编译自身，输出 C99 代码（默认多文件至 `.uyacache`，可用 `--no-split-c` 单文件）。
- **开发模式**：仅维护 `src/` 目录的自举编译器。
- **快速构建**：`gcc -std=c99 -O3 -fno-builtin bin/uya.c -o bin/uya` 即可从 C99 代码构建编译器。
- **内存验证**：Valgrind 验证通过，无内存泄漏，无内存错误。
- **语言规范**：完整版见 [docs/uya.md](./docs/uya.md)。
- **最新特性**：在 **v0.10.0** 的 `fmt` CLI/API、if expression 与 C99 主线稳定性基础上，当前 **v0.10.1** 继续收口 async runtime 动态资源、UPM/package 工作流、malloc / HTTP benchmark、UyaGin 热路径与 Linux/macOS hosted release 种子稳定性。

## 文档

- **[docs/usage_guide.md](./docs/usage_guide.md)** - 编译器使用指南
- **[docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md)** - 开发指导说明
- **[docs/TESTING.md](./docs/TESTING.md)** - 回归测试说明
- **[buglist.md](./buglist.md)** - 当前已知问题与优先级清单，便于后续自动收集
- **[docs/uya.md](./docs/uya.md)** - 完整语言规范（Markdown）
- **[docs/changelog.md](./docs/changelog.md)** - 语言规范变更历史
- **[docs/std_sql.md](./docs/std_sql.md)** - `std.sql` 模块与 SQLite/MySQL 驱动接入说明
- **[docs/comparison.md](./docs/comparison.md)** - 与其他语言的对比
- **[src/](./src/)** - 自举编译器源代码（唯一维护源）
- **[bin/uya.c](./bin/uya.c)** - 自举编译器输出的 C99 代码（已提交，作为构建种子）

## 一句话总结

> **Uya = 默认即高级内存安全 + 并发安全 + 显式错误处理 + 切片语法 + 安全指针算术 + @size_of/@align_of**；  
> **泛型语法：使用尖括号 `<T>`，约束紧邻参数 `<T: Ord>`，多约束连接 `<T: Ord + Clone + Default>`**；  
> **宏系统：编译时元编程 + 类型反射 + 智能缓存 + 环境集成，零运行时开销**；  
> **extern struct 完全解放，C 结构体获得 Uya 超能力**；  
> **只加 1 个关键字 `atomic T`，其余零新符号**；  
> **所有 UB 必须被编译期证明为安全 → 失败即编译错误**；  
> **编译期证明（本函数内），无法证明则编译错误，不降级、不插运行时锁。**

## 贡献

欢迎贡献代码、报告问题或提出建议！

---

**注意**：语言规范为完整版（0.72）；当前 **补丁发行**为 **v0.10.1**，说明见 [docs/releases/RELEASE_v0.10.1.md](./docs/releases/RELEASE_v0.10.1.md)；上一里程碑总览见 [docs/releases/RELEASE_v0.10.0.md](./docs/releases/RELEASE_v0.10.0.md) 与 [docs/uya.md](./docs/uya.md)。

**许可证**：本项目采用 [MIT 许可证](./LICENSE)。Copyright (c) 2025-2026 Uya 语言项目
