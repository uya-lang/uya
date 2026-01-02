# Uya 与其他语言的对比

本文档提供 Uya 语言与其他编程语言的对比，帮助理解 Uya 的设计理念和特点。

---

## 设计哲学对比

### 核心思想

Uya 将运行时的"可能越界"转化为编译期的"要么证明安全，要么返回显式错误"。

**核心机制**：
- 程序员必须提供**显式边界检查**，帮助编译器完成证明
- 编译器在编译期验证这些证明，无法证明安全即编译错误
- 每个数组访问都有明确的**数学证明**，消除运行时不确定性

### 示例对比

**C/C++ 示例**：
```c
// C/C++：程序员负责，编译器不检查
int arr[10];
int i = get_index();  // 可能越界
int x = arr[i];       // 运行时可能崩溃，编译器不警告
```

**Rust 示例**：
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

**Uya 示例**：
```uya
// Uya：程序员提供证明，编译器验证证明
const arr: [i32; 10] = [0; 10];
const i: i32 = get_index();
if i < 0 || i >= 10 {
    return error.OutOfBounds;  // 显式检查，返回错误
}
const x: i32 = arr[i];  // 编译器证明 i >= 0 && i < 10，安全
```

### 责任转移的哲学

这不是语言限制，而是**责任转移**：

| 语言 | 安全责任 | 编译器角色 |
|------|---------|-----------|
| **C/C++** | 程序员负责安全 | 编译器不帮忙，只生成代码 |
| **Rust** | 编译器通过借用检查器帮忙 | 编译器主动检查所有权和生命周期 |
| **Uya** | 程序员必须提供证明，编译器验证证明 | 编译器验证数学证明，失败即编译错误 |

**哲学差异**：

- **C/C++**：信任程序员，但错误代价高昂（缓冲区溢出、空指针解引用等）
- **Rust**：编译器主动介入，通过所有权系统自动管理，但需要学习借用规则
- **Uya**：程序员显式证明，编译器验证证明，**零运行时开销，失败路径不存在**

### 性能对比

**Uya 的编译期证明**：
```uya
// Uya：编译期证明，零运行时检查
fn safe_access(arr: [i32; 10], i: i32) !i32 {
    if i < 0 || i >= 10 {
        return error.OutOfBounds;  // 显式错误返回
    }
    return arr[i];  // 编译器证明安全，直接访问，零运行时检查
}
```

---

## 类型系统对比

### 与 C 的类型对应关系

| Uya 类型        | C 对应        | 大小/对齐 | 备注                     |
|-----------------|---------------|-----------|--------------------------|
| `i8` `i16` `i32` `i64` | 同宽 signed | 1 2 4 8 B | 对齐 = 类型大小；支持 `max/min` 关键字访问极值 |
| `u8` `u16` `u32` `u64` | 同宽 unsigned | 1 2 4 8 B | 对齐 = 类型大小；无符号整数类型，用于与 C 互操作和格式化 |
| `f32` `f64`     | float/double  | 4/8 B     | 对齐 = 类型大小          |
| `bool`          | uint8_t       | 1 B       | 0/1，对齐 1 B            |
| `byte`          | uint8_t       | 1 B       | 无符号字节，对齐 1 B，用于字节数组 |
| `void`          | void          | 0 B       | 仅用于函数返回类型       |
| `byte*`         | char*         | 4/8 B（平台相关） | 用于 FFI 函数参数和返回值，指向 C 字符串；32位平台=4B，64位平台=8B；可与 `null` 比较（空指针）|
| `&T`            | 普通指针      | 8 B       | 无 lifetime 符号 |
| `&atomic T`  | 原子指针      | 8 B       | 关键字驱动 |
| `atomic T`      | 原子类型      | sizeof(T) | 语言级原子类型 |
| `[T; N]`        | T[N]          | N·sizeof(T) | N 为编译期正整数，对齐 = T 的对齐 |
| `[[T; N]; M]`   | T[N][M]       | M·N·sizeof(T) | 多维数组，M 和 N 为编译期正整数，对齐 = T 的对齐 |
| `struct S { }`  | struct S      | 字段顺序布局 | 对齐 = 最大字段对齐 |
| `interface I { }` | -         | 16 B (64位) | vtable 指针(8B) + 数据指针(8B) |

---

## 接口系统对比

### 设计理念

Uya 的接口系统结合了多种语言的优点：

- **Go 的鸭子类型 + 动态派发**体验
- **Zig 的零注册表 + 编译期生成**
- **C 的内存布局 + 单条 call 指令**
- **无 lifetime 符号、无 new 关键字、无运行时锁**

**总结**：
> **Uya 接口 = Go 的鸭子派发 + Zig 的零注册 + C 的内存布局**；  
> **语法零新增、生命周期零符号、调用零开销**

---

## 错误处理对比

### 与 Zig 的相似性

Uya 的错误处理语法类似 Zig：

```uya
// 语法：`return error.ErrorMessage;`（类似 Zig 语法）
fn open_file() !File {
    if file_not_found {
        return error.FileNotFound;
    }
    return file;
}
```

---

## 切片语法对比

### 与 Python 的相似性

Uya 支持类似 Python 的切片语法：

```uya
// 支持类似 Python 的切片语法 `arr[start:len]`
const arr: [i32; 10] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
const slice1: [i32; 3] = arr[2:3];  // [2, 3, 4]
const slice2: [i32; 3] = arr[-3:3];  // [7, 8, 9]，支持负数索引
```

---

## for 循环对比

### 与 Zig 的相似性

Uya 支持 Zig 风格的 for 循环迭代：

```uya
// Zig 风格的 for 循环迭代
const arr: [i32; 5] = [1, 2, 3, 4, 5];
for arr |item, index| {
    printf("%d: %d\n", index, item);
}
```

---

## 模块系统对比

### 与 Zig 的相似性

Uya 的模块系统参考了 Zig 的设计：

**Zig 示例**：
```zig
// Zig：使用 @import("root") 引用根模块
const root = @import("root");
const value = root.helper_func();
```

**Uya 示例**：
```uya
// Uya：使用 use main.helper_func 引用根模块
use main.helper_func;

fn example() void {
    let value: i32 = helper_func();  // 直接使用，无需前缀
}
```

**相似点**：
- 都允许子包引用根模块
- 都通过编译期检测循环依赖
- 都要求程序员手动打破循环依赖

**差异点**：
- Uya 使用 `export` 关键字显式导出（Zig 使用 `pub`）
- Uya 使用 `use` 关键字导入（Zig 使用 `@import`）
- Uya 使用点号路径（`std.io`），Zig 使用字符串路径（`"std.io"`）
- Uya 是目录级模块（每个目录一个模块），Zig 是文件级模块（每个文件一个模块）

---

## 总结

Uya 语言的设计理念：

> **Uya = 默认即 Rust 级内存安全 + 并发安全 + Zig 风格错误处理 + Zig 风格模块系统 + Python 风格切片 + 安全指针算术 + 简化语法 + sizeof/alignof + 测试单元**

Uya 从多种语言中汲取灵感，但形成了自己独特的设计哲学：**程序员提供证明，编译器验证证明**。

