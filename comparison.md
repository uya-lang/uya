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
| `i8` `i16` `i32` `i64` | 同宽 signed | 1 2 4 8 B | 对齐 = 类型大小；支持 `@max`/`@min` 内置函数访问极值 |
| `u8` `u16` `u32` `u64` | 同宽 unsigned | 1 2 4 8 B | 对齐 = 类型大小；无符号整数类型，用于与 C 互操作和格式化 |
| `f32` `f64`     | float/double  | 4/8 B     | 对齐 = 类型大小          |
| `bool`          | uint8_t       | 1 B       | 0/1，对齐 1 B            |
| `byte`          | uint8_t       | 1 B       | 无符号字节，对齐 1 B，用于字节数组 |
| `void`          | void          | 0 B       | 仅用于函数返回类型       |
| `*byte`         | char*         | 4/8 B（平台相关） | FFI 指针类型 `*T` 的一个实例（T=byte），用于 FFI 函数参数和返回值，指向 C 字符串；32位平台=4B，64位平台=8B；可与 `null` 比较（空指针）；FFI 指针类型 `*T` 支持所有 C 兼容类型（见 uya.md 第 5.2 章）|
| `&T`            | 普通指针      | 4/8 B（平台相关） | 无 lifetime 符号；32位平台=4B，64位平台=8B |
| `&atomic T`  | 原子指针      | 4/8 B（平台相关） | 关键字驱动；32位平台=4B，64位平台=8B |
| `atomic T`      | 原子类型      | sizeof(T) | 语言级原子类型 |
| `[T; N]`        | T[N]          | N·sizeof(T) | N 为编译期正整数，对齐 = T 的对齐 |
| `[[T; N]; M]`   | T[N][M]       | M·N·sizeof(T) | 多维数组，M 和 N 为编译期正整数，对齐 = T 的对齐 |
| `struct S { }`  | struct S      | 字段顺序布局 | 对齐 = 最大字段对齐 |
| `interface I { }` | -         | 8/16 B（平台相关） | vtable 指针(4/8B) + 数据指针(4/8B)；32位平台=8B，64位平台=16B |
| `enum E { }` | enum E        | sizeof(底层类型) | 枚举类型，默认底层类型为 i32，与 C 枚举兼容 |
| `(T1, T2, ...)` | -         | 字段顺序布局 | 元组类型，对齐 = 最大字段对齐 |

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
> **语法零新增、生命周期零符号、编译期证明**

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

Uya 支持类似 Python 的切片语法，但返回切片视图（引用）而不是新数组：

```uya
// 支持类似 Python 的切片语法 `&arr[start:len]`，返回切片视图
var arr: [i32; 10] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
const slice: &[i32] = &arr[2:5];      // 动态长度切片视图
const exact_slice: &[i32; 3] = &arr[2:3]; // 已知长度切片视图
const tail: &[i32] = &arr[-3:3];      // 负数索引，等价于 &arr[7:3]

// 切片是原数据的视图，修改原数组会影响切片
arr[3] = 99;
// slice 现在反映 arr[3] 的变化

// for循环支持切片迭代
for slice |value| { }        // 值迭代（只读）
for slice |&ptr| { }         // 引用迭代（可修改）
for slice |i| { }            // 索引迭代
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

## 泛型语法对比

### 与其他语言的差异

**其他语言（C++、Rust、Go）**：
```cpp
// C++/Rust：使用尖括号
Vec<T>
HashMap<K, V>
Result<T, E>
```

**Uya（0.31 版本）**：
```uya
// Uya：使用括号，更清晰，更一致
Vec(T)
HashMap(K, V)
Result(T, E)
```

**设计理念**：
- **零新符号**：括号 `()` 已存在于函数调用/元组，不算新符号
- **更清晰**：与函数调用语法一致，减少认知负担
- **更一致**：定义和实例化完全对称：`struct Vec(T)` 和 `Vec(i32)`

---

## extern struct 对比

### 与其他语言的差异

**传统 FFI 结构体（C、Rust FFI）**：
```c
// C：纯数据结构，无方法
struct timeval {
    long tv_sec;
    long tv_usec;
};
```

```rust
// Rust FFI：只能声明字段，不能有方法
#[repr(C)]
struct timeval {
    tv_sec: i64,
    tv_usec: i64,
}
```

**Uya（0.31 版本）**：
```uya
// Uya：extern struct 完全解放
extern struct timeval {
    tv_sec: i64,
    tv_usec: i64
    
    // ✅ 可以有方法
    fn to_millis(self: *Self) i64 {
        return self.tv_sec * 1000 + self.tv_usec / 1000;
    }
    
    // ✅ 可以有 drop
    fn drop(self: *Self) void {
        // 清理资源
    }
}

// ✅ 可以实现接口
interface ITime {
    fn to_millis(self: *Self) i64;
}

timeval : ITime {
    fn to_millis(self: *Self) i64 {
        return self.to_millis();
    }
}
```

**最酷的部分**：
- **C 代码看到**：纯数据，标准布局，100% C 兼容
- **Uya 代码看到**：完整对象，有方法、接口、RAII，100% Uya 能力
- **从 C 结构体到高级抽象无缝过渡**

---

## 总结

Uya 从多种语言中汲取灵感，但形成了自己独特的设计哲学：**程序员提供证明，编译器验证证明**。

**核心创新（0.31 版本）**：
1. **泛型用 `()` 不是 `<>`**：更清晰，更一致，零新符号
2. **extern struct 完全解放**：C 兼容结构体获得 Uya 超能力，可以有方法、drop、实现接口
3. **切片类型系统**：`&[T]` 和 `&[T; N]` 切片视图，零分配，生命周期自动绑定
4. **零新符号**：复用已有语法，不发明新符号
5. **单页纸可读完**：语法简单到可以记在脑子里，概念最少但能力完整

