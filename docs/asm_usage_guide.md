# @asm 内联汇编使用指南

> **核对头（2026-09-27）**：`@asm` 已完成，本文件属历史过程记录。现状与证据见 `docs/ASM_TODO.md` 的核对头与 `docs/todo_status_index.md`。

**版本**: v1.0.0  
**创建日期**: 2026-02-24  
**适用对象**: Uya 语言开发者

---

## 目录

- [1. 快速入门](#1-快速入门)
- [2. 基本概念](#2-基本概念)
- [3. 详细语法](#3-详细语法)
- [4. 类型系统](#4-类型系统)
- [5. 内存安全](#5-内存安全)
- [6. 并发安全](#6-并发安全)
- [7. 平台支持](#7-平台支持)
- [8. 实际示例](#8-实际示例)
- [9. 常见陷阱](#9-常见陷阱)
- [10. 性能优化](#10-性能优化)

---

## 1. 快速入门

### 1.1 第一个 @asm 程序

```uya
fn add_with_asm(a: i32, b: i32) i32 {
    var result: i32 = 0;
    
    @asm {
        "nop" (a, b, -> result);
    }
    
    return result;
}

fn main() i32 {
    const sum: i32 = add_with_asm(10, 20);
    return 0;
}
```

### 1.2 关键要点

1. **输出变量必须在外部声明**: `var result: i32;` 必须在 `@asm` 块之前
2. **类型必须匹配**: 输入/输出的类型必须在支持列表中
3. **clobbers 声明重要**: 修改的寄存器必须声明

---

## 2. 基本概念

### 2.1 @asm 是什么？

`@asm` 是 Uya 的内置函数，用于在代码中嵌入类型安全的内联汇编。

**特点**：
- ✅ 编译期类型检查
- ✅ 内存安全保证
- ✅ 跨平台支持
- ✅ 零成本抽象

### 2.2 适用场景

**适合使用 @asm**：
- 系统调用
- 底层硬件操作
- 性能关键路径
- 原子操作
- SIMD 优化

**不适合使用 @asm**：
- 普通业务逻辑
- 可移植性要求高的代码
- 维护性优先的代码

### 2.3 设计哲学

`@asm` 的设计遵循以下原则：

1. **显式优于隐式**: 所有输入/输出必须显式声明
2. **安全第一**: 编译器验证类型和内存安全
3. **零成本**: 不引入运行时开销
4. **可读性**: 清晰的语法，易于理解

---

## 3. 详细语法

### 3.1 基本结构

```uya
@asm {
    "指令模板" (输入列表, -> 输出列表)
        clobbers = [寄存器列表];
}
```

### 3.2 指令模板

指令模板是汇编指令的字符串表示，使用 `{name}` 作为占位符。

**示例**：
```uya
// 单个占位符
"mov {dst}, {src}"

// 多个占位符
"add {result}, {a}, {b}"

// 无占位符
"nop"
```

### 3.3 输入列表

输入表达式列表，用逗号分隔。

**规则**：
- 最多 16 个输入
- 类型必须在支持列表中
- 可以是变量、常量或表达式

**示例**：
```uya
// 单个输入
@asm {
    "nop" (x);
}

// 多个输入
@asm {
    "nop" (a, b, c);
}
```

### 3.4 输出列表

输出表达式列表，使用 `->` 分隔。

**规则**：
- 最多 16 个输出
- 必须是左值（可寻址）
- 必须在外部声明

**示例**：
```uya
// 单个输出
var result: i32;
@asm {
    "nop" (a, b, -> result);
}

// 多个输出
var x: i32;
var y: i32;
@asm {
    "nop" (-> x, y);
}

// 无输出
@asm {
    "nop" (a, b);
}
```

### 3.5 Clobbers 声明

声明被修改的寄存器和内存。

**语法**：
```uya
@asm {
    "指令" (...)
} clobbers = ["寄存器1", "寄存器2", "memory"];
```

**示例**：
```uya
// 单个寄存器
@asm {
    "nop" (-> x);
} clobbers = ["rax"];

// 多个寄存器
@asm {
    "nop" (-> x, y);
} clobbers = ["rax", "rbx", "rcx"];

// 内存
@asm {
    "nop" (ptr);
} clobbers = ["memory"];

// 混合
@asm {
    "nop" (ptr, -> x);
} clobbers = ["rax", "memory"];
```

---

## 4. 类型系统

### 4.1 支持的类型

**整数类型**：
- `i8`, `i16`, `i32`, `i64`
- `u8`, `u16`, `u32`, `u64`
- `usize`

**指针类型**：
- `&T` - 可变指针
- `&const T` - 只读指针
- `&atomic T` - 原子指针

### 4.2 不支持的类型

**不支持的类型**：
- `f32`, `f64` - 浮点数（未来支持）
- `void` - 空类型
- 结构体类型
- 数组类型
- 切片类型
- FFI 指针 `*T`

### 4.3 类型检查

编译器会进行严格的类型检查：

```uya
// ✅ 正确
var x: i32 = 10;
@asm {
    "nop" (x, -> x);
}

// ❌ 错误：类型不支持
var f: f64 = 3.14;
@asm {
    "nop" (f);  // 编译错误：f64 不支持
}

// ❌ 错误：输出必须是左值
@asm {
    "nop" (-> 42);  // 编译错误：常量不能作为输出
}
```

---

## 5. 内存安全

### 5.1 指针类型转换

FFI 指针不能直接使用，必须转换为 Uya 指针：

```uya
// ❌ 错误：FFI 指针不能直接使用
extern malloc(size: usize) *void;
var ptr: *void = malloc(100);
@asm {
    "nop" (ptr);  // 编译错误
}

// ✅ 正确：转换为 Uya 指针
var buffer: [byte: 100] = [];
var ptr: &byte = &buffer[0];
@asm {
    "nop" (ptr);
}
```

### 5.2 内存操作声明

修改内存的指令必须声明 `"memory"` clobber：

```uya
// ✅ 正确
@asm {
    "nop" (ptr, value);
} clobbers = ["memory"];
```

### 5.3 边界检查

数组访问需要边界检查证明：

```uya
var arr: [i32: 10] = [];
var idx: i32 = 5;

// ✅ 正确：有边界检查
if idx >= 0 && idx < 10 {
    var ptr: &i32 = &arr[idx];
    @asm {
        "nop" (ptr);
    }
}

// ❌ 错误：缺少边界检查
var ptr: &i32 = &arr[idx];  // 编译错误
```

---

## 6. 并发安全

### 6.1 原子类型

使用 `atomic T` 类型进行原子操作：

```uya
var counter: atomic i32 = 0;

@asm {
    "nop" (&counter);
} clobbers = ["memory"];
```

### 6.2 内存屏障

内存屏障指令需要声明 `"memory"` clobber：

```uya
@asm {
    "nop" ();
} clobbers = ["memory"];
```

---

## 7. 平台支持

### 7.1 平台检测

使用 `@asm_target()` 检测当前平台：

```uya
const target: i32 = @asm_target();

if target == 0 {
    // x86-64 Linux
} else {
    if target == 1 {
        // ARM64 Linux
    }
}
```

### 7.2 条件编译

根据平台执行不同代码：

```uya
fn platform_specific() i32 {
    const target: i32 = @asm_target();
    var result: i32 = 0;
    
    if target == 0 {
        @asm {
            "nop" (-> result);
        }
    } else {
        if target == 1 {
            @asm {
                "nop" (-> result);
            }
        }
    }
    
    return result;
}
```

### 7.3 寄存器约束

不同平台有不同的寄存器：

**x86-64**：
- 通用寄存器：`rax`, `rbx`, `rcx`, `rdx`, `rsi`, `rdi`, `r8`-`r15`
- 特殊寄存器：`rsp`, `rbp`, `rip`

**ARM64**：
- 通用寄存器：`x0`-`x30`
- 特殊寄存器：`sp`, `lr`, `pc`

---

## 8. 实际示例

### 8.1 系统调用

```uya
fn syscall_write(fd: i32, buf: &const byte, count: i32) !i32 {
    const SYS_write: i64 = 1;
    var result: i64;
    
    @asm {
        "nop" (SYS_write, fd, buf, count, -> result);
    } clobbers = ["rcx", "r11", "memory"];
    
    if result < 0 {
        return error.SyscallFailed;
    }
    
    return result as! i32;
}
```

### 8.2 内存复制

```uya
fn my_memcpy(dest: &byte, src: &const byte, n: usize) void {
    var i: usize = 0;
    while i < n {
        @asm {
            "nop" (dest, src, i);
        } clobbers = ["memory"];
        i = i + 1;
    }
}
```

### 8.3 原子计数器

```uya
struct Counter {
    value: atomic i32
}

fn increment(counter: &Counter) void {
    @asm {
        "nop" (&counter.value);
    } clobbers = ["memory"];
}
```

---

## 9. 常见陷阱

### 9.1 输出变量未声明

```uya
// ❌ 错误
@asm {
    "nop" (a, b, -> result);  // result 未声明
}

// ✅ 正确
var result: i32 = 0;
@asm {
    "nop" (a, b, -> result);
}
```

### 9.2 忘记 clobbers 声明

```uya
// ❌ 错误：可能导致编译器优化错误
@asm {
    "nop" (ptr);  // 修改了内存但未声明
}

// ✅ 正确
@asm {
    "nop" (ptr);
} clobbers = ["memory"];
```

### 9.3 类型不匹配

```uya
// ❌ 错误
var f: f64 = 3.14;
@asm {
    "nop" (f);  // f64 不支持
}

// ✅ 正确：使用整数
var i: i32 = 3;
@asm {
    "nop" (i);
}
```

### 9.4 FFI 指针直接使用

```uya
// ❌ 错误
extern malloc(size: usize) *void;
var ptr: *void = malloc(100);
@asm {
    "nop" (ptr);  // FFI 指针不能直接使用
}

// ✅ 正确：使用 Uya 指针
var buffer: [byte: 100] = [];
var ptr: &byte = &buffer[0];
@asm {
    "nop" (ptr);
}
```

### 9.5 LTO / `--gc-sections` 下符号被优化掉

在开启 **`-flto -Wl,--gc-sections -ffunction-sections -fdata-sections`** 的编译链路（如 microapp 默认优化）中，如果 `@asm` 通过**硬编码字符串**引用内部 `static` 函数或全局变量，链接器可能因无法识别汇编字符串中的依赖而将其丢弃，导致 `undefined reference`。

```uya
// ⚠️ 危险：LTO 下 helper 可能被 --gc-sections 回收
fn helper() void { ... }

@asm {
    "call helper" ();  // 链接器看不到这个依赖
}
```

**✅ 当前 Uya C99 后端已自动处理**：所有 `static` 内部函数和全局变量都会生成 `__attribute__((used))`，强制保留。若你在手写 C 封装中遇到类似问题，可手动添加：

```c
static __attribute__((used)) void helper(void) { ... }
__attribute__((used)) static int global_state = 0;
```

---

## 10. 性能优化

### 10.1 减少 Clobbers

只声明实际修改的寄存器：

```uya
// ❌ 过度声明
@asm {
    "nop" (-> x);
} clobbers = ["rax", "rbx", "rcx", "rdx"];  // 太多

// ✅ 精确声明
@asm {
    "nop" (-> x);
} clobbers = ["rax"];
```

### 10.2 批量操作

一次处理多个数据：

```uya
// ❌ 单个操作
var i: usize = 0;
while i < n {
    @asm {
        "nop" (ptr, i);
    }
    i = i + 1;
}

// ✅ 批量操作
var j: usize = 0;
while j < n {
    @asm {
        "nop" (ptr, j, j+1, j+2, j+3);  // 一次处理 4 个
    }
    j = j + 4;
}
```

### 10.3 使用正确的类型

使用最适合的类型：

```uya
// ❌ 使用过大的类型
var x: i64 = 0;
@asm {
    "nop" (-> x);  // 64 位操作
}

// ✅ 使用合适的类型
var x: i32 = 0;
@asm {
    "nop" (-> x);  // 32 位操作，更快
}
```

---

## 11. 调试技巧

### 11.1 查看生成的 C 代码

```bash
bin/uya --c99 test.uya > test.c
cat test.c
```

### 11.2 使用调试输出

```uya
var x: i32 = 0;
@asm {
    "nop" (-> x);
}
printf("x = %d\n", x);  // 调试输出
```

### 11.3 逐步验证

将复杂的 @asm 块分解为简单步骤：

```uya
// 分步调试
@asm {
    "nop" (a, -> temp1);
}
printf("temp1 = %d\n", temp1);

@asm {
    "nop" (temp1, b, -> temp2);
}
printf("temp2 = %d\n", temp2);
```

---

## 12. 总结

### 12.1 核心原则

1. **安全第一**: 类型检查、内存安全、并发安全
2. **显式声明**: 输出变量、clobbers 必须显式声明
3. **平台感知**: 使用 `@asm_target()` 进行平台检测
4. **性能优化**: 精确声明 clobbers，批量操作

### 12.2 最佳实践

- ✅ 使用 Uya 指针类型
- ✅ 声明所有修改的寄存器和内存
- ✅ 进行边界检查
- ✅ 使用原子类型进行并发操作
- ✅ 根据平台编写不同代码

### 12.3 避免的做法

- ❌ 直接使用 FFI 指针
- ❌ 忘记 clobbers 声明
- ❌ 使用不支持的类型
- ❌ 忽略边界检查

---

**版本**: v1.0.0  
**最后更新**: 2026-02-24  
**维护者**: Uya 开发团队
