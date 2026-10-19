# va_list 原生支持设计文档

> **实现状态（2026-10-19 核对，编译器 v0.10.4）**：本文的主线已落地，正文保留原设计文本。
> - `va_list` 已是 checker 认识的类型名（`src/checker/type_from_ast.uya:635-636` → `TypeKind.TYPE_VA_LIST`，`src/checker/types.uya:94`），C99 侧发射为 `typedef __builtin_va_list va_list;`（`src/codegen/c99/main.uya:2298`、`2400`）。
> - §3.2「新规则」已实现：`@va_arg` 在"可变参数函数"**或**"形参里带 `va_list` 的函数"内都可用（`src/checker/check_expr.uya:1714-1753`，报错文案 `@va_arg 只能在可变参数函数或接收 va_list 参数的函数内使用`）；`@va_copy` 同样放宽（`src/checker/check_expr.uya:1762-1792`）。
> - 因此 §1.1 里"❌ 当前无法实现 `vprintf` 系列"**已过时**：`fn vf(fmt: &byte, ap: va_list) i32 { const v: i32 = @va_arg(ap, i32); ... }` 现在可以编译（已用 `bin/uya --c99` 实测）。
> - `@va_start` / `@va_end` 仍要求处于可变参数函数内（`src/checker/check_expr.uya:1695-1712`）。

## 1. 概述

### 1.1 背景

当前 Uya 的 `@va_arg` 内置函数限制只能在包含 `...` 的可变参数函数中使用，导致无法实现 C 标准库的 `vprintf` 系列函数：

```uya
// ❌ 当前无法实现
fn vprintf(format: &byte, ap: va_list) i32 {
    const c: i32 = @va_arg(ap, i32);  // 错误：不在可变参数函数中
}
```

### 1.2 目标

1. **C ABI 兼容**：`va_list` 必须与目标平台的 C `va_list` 布局一致
2. **跨函数传递**：`va_list` 可以作为函数参数传递
3. **跨平台支持**：支持 x86-64、ARM64、x86 等主流架构
4. **零开销**：直接映射到 C 的 `va_list`，无运行时开销

### 1.3 影响范围

| 组件 | 改动 |
|------|------|
| 编译器类型系统 | 新增 `va_list` 内置类型 |
| 类型检查器 | 放宽 `@va_arg` 使用位置限制 |
| C99 代码生成 | `va_list` 类型映射和参数传递 |
| libc | 实现 vprintf 系列函数 |

---

## 2. va_list 类型设计

### 2.1 作为内置类型

`va_list` 不再是用户定义的结构体，而是**编译器内置类型**：

```uya
// va_list 是内置类型，不需要用户定义
fn vprintf(format: &const byte, ap: va_list) i32;

// 可以取指针
fn process(ap: &va_list) void;

// 可以作为结构体成员
struct FormatContext {
    ap: va_list,
    format: &const byte,
}
```

### 2.2 类型属性

| 属性 | 说明 |
|------|------|
| 大小 | 平台相关（见第 5 节） |
| 对齐 | 平台相关 |
| 可复制 | ✅ 支持赋值和传值 |
| 可取地址 | ✅ 支持取指针 |
| 可比较 | ❌ 不支持 == 或 != |

### 2.3 类型检查规则

```uya
// ✅ 允许：作为函数参数
fn foo(ap: va_list) void;

// ✅ 允许：作为函数返回值（通过指针）
fn get_ap(out: &va_list) void;

// ✅ 允许：作为结构体成员
struct Context { ap: va_list }

// ✅ 允许：取指针
fn bar(ap: &va_list) void;

// ❌ 禁止：比较
if ap1 == ap2 { }  // 编译错误

// ❌ 禁止：算术运算
ap + 1  // 编译错误
```

---

## 3. @va_arg 使用规则变更

### 3.1 当前规则（限制）

```
@va_arg(ap, Type) 只能在包含 ... 的可变参数函数中使用
```

### 3.2 新规则

```
@va_arg(ap, Type) 可以在以下两种上下文中使用：

1. 可变参数函数内（与 @va_start 配合）
   fn printf(format: &byte, ...) i32 {
       var ap: va_list = va_list{};
       @va_start(&ap, format);
       const x: i32 = @va_arg(ap, i32);  // ✅
       @va_end(&ap);
   }

2. 接收 va_list 参数的函数内
   fn vprintf(format: &byte, ap: va_list) i32 {
       const x: i32 = @va_arg(ap, i32);  // ✅
   }
```

### 3.3 检查算法

```
function check_va_arg_usage(func, va_list_param):
    // 情况1：在可变参数函数中使用 @va_start 初始化的 va_list
    if func.is_variadic && va_list_param.is_initialized_by_va_start:
        return OK
    
    // 情况2：va_list 是函数参数
    if va_list_param.is_function_parameter:
        return OK
    
    // 情况3：va_list 是结构体成员，且结构体是通过参数传入的
    if va_list_param.is_struct_member && struct.is_function_parameter:
        return OK
    
    // 情况4：通过解引用访问（&va_list -> va_list）
    if va_list_param.is_dereference_of_pointer_to_va_list:
        return OK
    
    // 其他情况：禁止
    return ERROR
```

**限制说明**：
- 通过函数返回的指针访问 va_list 是**未定义行为**（因为调用者无法保证 va_list 仍有效）
- 在非上述上下文中声明的局部 va_list 变量，必须通过 `@va_start` 或 `@va_copy` 初始化后才能使用

---

## 4. 语法设计

### 4.1 va_list 类型语法

```uya
// 类型名
va_list

// 指针类型
&va_list
*va_list  // C 兼容写法

// 数组（不常见，但支持）
[va_list: N]
```

### 4.2 相关内置函数

```uya
// @va_start - 初始化 va_list（仅在可变参数函数中）
// 第二参数必须是最后一个命名参数的变量名
@va_start(ap: &va_list, last_named_param)

// @va_end - 结束 va_list 访问
@va_end(ap: &va_list)

// @va_arg - 获取下一个参数
// 统一使用 va_list 类型（编译器自动处理平台差异）
@va_arg(ap: va_list, Type) T

// @va_copy - 复制 va_list（新增）
// 注意：dest 需要 &，src 不需要（与 C 保持一致的语义）
@va_copy(dest: &va_list, src: va_list)
```

### 4.3 使用示例

```uya
// 示例1：可变参数函数
fn printf(format: &const byte, ...) i32 {
    var ap: va_list = va_list{};
    @va_start(&ap, format);
    
    const result: i32 = vfprintf(stdout, format, ap);
    
    @va_end(&ap);
    return result;
}

// 示例2：接收 va_list 的函数
fn vfprintf(stream: &FILE, format: &const byte, ap: va_list) i32 {
    while format[i] != 0 {
        if format[i] == 37 {  // '%'
            const spec: byte = format[i + 1];
            if spec == 100 {  // 'd'
                const val: i32 = @va_arg(ap, i32);
                print_i32(val);
            } else if spec == 115 {  // 's'
                const s: &const byte = @va_arg(ap, &const byte);
                fputs(s, stream);
            }
            // ...
        }
        i = i + 1;
    }
    return 0;
}

// 示例3：va_copy
fn my_vprintf(format: &const byte, ap: va_list) i32 {
    var ap2: va_list = va_list{};
    @va_copy(&ap2, ap);
    
    // 使用 ap2...
    const len: i32 = vsnprintf(null, 0, format, ap2);
    
    @va_end(&ap2);
    return len;
}
```

---

## 5. 跨平台实现

### 5.1 平台差异

不同平台的 `va_list` 大小和布局完全不同：

#### 5.1.1 x86-64 (System V AMD64 ABI)

```c
// Linux/macOS x86-64
typedef struct {
    unsigned int gp_offset;    // 4 bytes: GPR 保存区的偏移
    unsigned int fp_offset;    // 4 bytes: FPR 保存区的偏移
    void *overflow_arg_area;   // 8 bytes: 溢出参数区指针
    void *reg_save_area;       // 8 bytes: 寄存器保存区指针
} va_list[1];                  // 总大小: 24 字节

// 或者简化为：
// typedef __builtin_va_list va_list;
```

**参数传递规则**：
- 前 6 个整数参数：rdi, rsi, rdx, rcx, r8, r9
- 前 8 个浮点参数：xmm0-xmm7
- 超出的参数：通过栈传递

#### 5.1.2 x86-64 (Windows)

```c
// Windows x86-64 (Microsoft ABI)
typedef char* va_list;  // 就是一个指针！
// 大小: 8 字节
```

**参数传递规则**：
- 前 4 个参数：rcx, rdx, r8, r9（整数/指针）
- 浮点参数：xmm0-xmm3
- 所有可变参数通过栈传递

#### 5.1.3 ARM64 (AArch64)

```c
// ARM64
typedef struct {
    void *__stack;         // 8 bytes: 下一个栈参数
    void *__gr_top;        // 8 bytes: 通用寄存器保存区顶部
    void *__vr_top;        // 8 bytes: 向量寄存器保存区顶部
    int __gr_offs;         // 4 bytes: GPR 偏移
    int __vr_offs;         // 4 bytes: VR 偏移
} va_list;
// 总大小: 32 字节
```

**参数传递规则**：
- 前 8 个整数参数：x0-x7
- 前 8 个浮点参数：v0-v7
- 超出的参数：通过栈传递

#### 5.1.4 x86 (32-bit)

```c
// x86 (32-bit)
typedef char* va_list;  // 就是一个指针
// 大小: 4 字节
```

**参数传递规则**：
- 所有参数通过栈传递

### 5.2 平台差异汇总

| 平台 | va_list 大小 | va_list 类型 | 对齐 |
|------|-------------|--------------|------|
| x86-64 (System V) | 24 字节 | 结构体 | 8 |
| x86-64 (Windows) | 8 字节 | 指针 | 8 |
| ARM64 | 32 字节 | 结构体 | 8 |
| x86 | 4 字节 | 指针 | 4 |
| RISC-V | 32 字节 | 结构体 | 8 |

### 5.3 编译器处理策略

#### 5.3.1 类型系统

```uya
// 编译器内部表示
struct VaListType {
    size: usize,           // 平台相关大小
    alignment: usize,      // 平台相关对齐
    platform: Platform,    // 目标平台
}
```

#### 5.3.2 目标平台检测

```bash
# 编译时确定目标平台
--target x86_64-linux     # System V ABI
--target x86_64-windows   # Windows ABI
--target aarch64-linux    # ARM64 Linux
--target i686-linux       # x86 32-bit
```

#### 5.3.3 C99 后端代码生成

```c
// 生成的 C 代码必须包含正确的头文件
#include <stdarg.h>

// x86-64 System V: va_list 是结构体
// 直接使用 va_list 类型

// ARM64: va_list 是结构体
// 直接使用 va_list 类型

// x86 / Windows x64: va_list 是指针
// 直接使用 va_list 类型

// 结论：C99 后端直接使用 C 的 va_list，无需特殊处理！
```

### 5.4 C99 后端实现

C99 后端的优势：**直接映射到 C 的 va_list**

```uya
// Uya 源码
fn vprintf(format: &const byte, ap: va_list) i32 {
    const c: i32 = @va_arg(ap, i32);
    return c;
}
```

```c
// 生成的 C 代码
#include <stdarg.h>

int32_t vprintf(const uint8_t* format, va_list ap) {
    int32_t c = va_arg(ap, int32_t);
    return c;
}
```

**关键点**：
1. C 的 `va_list` 已经处理了平台差异
2. Uya 只需将 `va_list` 映射为 C 的 `va_list`
3. `@va_arg(ap, i32)` 映射为 `va_arg(ap, int32_t)`

### 5.5 LLVM 后端实现（未来）

如果将来支持 LLVM 后端：

```llvm
; va_list 的 LLVM IR 表示
%va_list = type <{ i32, i32, i8*, i8* }>  ; x86-64

; va_arg 的 LLVM IR
%val = va_arg %va_list, i32
```

---

## 6. 代码生成策略

### 6.1 类型映射

| Uya 类型 | C 类型 (所有平台) |
|----------|------------------|
| `va_list` | `va_list` |
| `&va_list` | `va_list*` |
| `*va_list` | `va_list*` |

### 6.2 内置函数展开

```uya
// Uya
@va_start(&ap, format)

// C
va_start(ap, format)  // 注意：C 的 va_start 不需要 &
```

```uya
// Uya
@va_arg(ap, i32)

// C
va_arg(ap, int32_t)
```

```uya
// Uya
@va_end(&ap)

// C
va_end(ap)
```

```uya
// Uya
@va_copy(&dest, src)

// C
va_copy(dest, src)
```

### 6.3 函数签名生成

```uya
// Uya
export fn vfprintf(stream: &FILE, format: &const byte, ap: va_list) i32

// C
int32_t vfprintf(FILE* stream, const uint8_t* format, va_list ap)
```

---

## 7. libc 接口设计

### 7.1 stddef.uya

```uya
// lib/std/stddef.uya

// va_list 是编译器内置类型，无需导入或定义
// 在任何作用域中可以直接使用 va_list 类型名

// 如果需要显式导入（可选，仅用于文档目的）：
// pub type va_list = builtin.va_list;  // 未来可能支持
```

### 7.2 stdarg.uya

```uya
// lib/libc/stdarg.uya

// va_list 是编译器内置类型，无需定义

// 所有操作通过编译器内置函数完成：
// - @va_start(ap: &va_list, last_named_param) - 初始化
// - @va_end(ap: &va_list) - 结束
// - @va_arg(ap: va_list, Type) T - 获取参数
// - @va_copy(dest: &va_list, src: va_list) - 复制

// 本文件可以保持空或仅包含文档注释
```

### 7.3 stdio.uya

```uya
// lib/libc/stdio.uya

// vfprintf - 格式化输出到流
export fn vfprintf(stream: &FILE, format: &const byte, ap: va_list) i32 {
    var buf: [byte: 4096] = [];
    var buf_pos: usize = 0;
    var format_pos: usize = 0;
    const format_len: usize = strlen(format);
    
    while format_pos < format_len {
        const c: byte = format[format_pos];
        if c == 37 {  // '%'
            format_pos = format_pos + 1;
            const spec: byte = format[format_pos];
            
            // 根据格式说明符获取参数并输出
            if spec == 115 {  // %s
                const s: &const byte = @va_arg(ap, &const byte);
                if s != null {
                    const len: usize = strlen(s);
                    var i: usize = 0;
                    while i < len {
                        buf[buf_pos] = s[i];
                        buf_pos = buf_pos + 1;
                        i = i + 1;
                    }
                }
            } else if spec == 100 {  // %d
                const d: i32 = @va_arg(ap, i32);
                buf_pos = _fmt_i32_to_buf(&buf[0], buf_pos, 4096, d);
            } else if spec == 120 {  // %x
                const x: u32 = @va_arg(ap, u32);
                buf_pos = _fmt_u32_hex_to_buf(&buf[0], buf_pos, 4096, x, 0);
            } else if spec == 88 {  // %X
                const x: u32 = @va_arg(ap, u32);
                buf_pos = _fmt_u32_hex_to_buf(&buf[0], buf_pos, 4096, x, 1);
            } else if spec == 99 {  // %c
                const ch: i32 = @va_arg(ap, i32);
                buf[buf_pos] = ch as byte;
                buf_pos = buf_pos + 1;
            } else if spec == 112 {  // %p
                const ptr: usize = @va_arg(ap, usize);
                buf_pos = _fmt_ptr_to_buf(&buf[0], buf_pos, 4096, ptr);
            }
            // ... 其他格式说明符：%f, %e, %g, %ld, %lld 等
            } else {
                // 未知格式说明符，原样输出
                buf[buf_pos] = 37;  // '%'
                buf_pos = buf_pos + 1;
                if buf_pos < 4096 {
                    buf[buf_pos] = spec;
                    buf_pos = buf_pos + 1;
                }
            }
        } else {
            buf[buf_pos] = c;
            buf_pos = buf_pos + 1;
        }
        
        // 缓冲区溢出检查
        if buf_pos >= 4096 {
            // 刷新缓冲区
            write_to_buffer(stream, &buf[0], buf_pos);
            buf_pos = 0;
        }
        
        format_pos = format_pos + 1;
    }
    
    // 处理 format 末尾是 '%' 的边界情况
    // （在循环中已经处理）
    
    // 刷新剩余数据
    if buf_pos > 0 {
        write_to_buffer(stream, &buf[0], buf_pos);
    }
    return buf_pos as i32;
}

// vprintf - 格式化输出到 stdout
export fn vprintf(format: &const byte, ap: va_list) i32 {
    return vfprintf(stdout, format, ap);
}

// vsprintf - 格式化到字符串
export fn vsprintf(buf: &byte, format: &const byte, ap: va_list) i32 {
    // 使用内存缓冲区代替流
    var ctx: _BufContext = _BufContext{ .buf = buf, .pos = 0, .max = 0 - 1 };
    return _vfprintf_impl(&ctx, format, ap);
}

// vsnprintf - 格式化到字符串（带长度限制）
export fn vsnprintf(buf: &byte, n: usize, format: &const byte, ap: va_list) i32 {
    var ctx: _BufContext = _BufContext{ .buf = buf, .pos = 0, .max = n };
    return _vfprintf_impl(&ctx, format, ap);
}
```

---

## 8. 测试计划

### 8.1 单元测试

```uya
// tests/test_va_list.uya

test "va_list_basic" {
    // 测试 va_list 类型存在
    var ap: va_list = va_list{};
    // va_list 可以声明
}

test "va_arg_in_variadic" {
    // 测试在可变参数函数中使用 @va_arg
    const result: i32 = _test_variadic_sum(3, 1, 2, 3);
    try assert_eq_i32(result, 6);
}

fn _test_variadic_sum(count: i32, ...) i32 {
    var ap: va_list = va_list{};
    @va_start(&ap, count);
    
    var sum: i32 = 0;
    var i: i32 = 0;
    while i < count {
        sum = sum + @va_arg(ap, i32);
        i = i + 1;
    }
    
    @va_end(&ap);
    return sum;
}

test "vprintf_basic" {
    // 测试 vprintf 需要通过包装函数，因为 @va_start 需要命名参数
    const result: i32 = _test_vprintf_wrapper("test %d", 42);
    try assert_eq_i32(result, 9);  // "test 42" 长度为 8，但 vfprintf 返回写入字符数
}

fn _test_vprintf_wrapper(format: &const byte, ...) i32 {
    var ap: va_list = va_list{};
    @va_start(&ap, format);  // format 是最后一个命名参数
    
    const result: i32 = vfprintf(stdout, format, ap);
    
    @va_end(&ap);
    return result;
}

test "va_copy" {
    // 测试 @va_copy 需要通过包装函数
    const result: i32 = _test_va_copy_wrapper(42, 100);
    try assert_eq_i32(result, 42);  // 两个 ap 应该读取相同的值
}

fn _test_va_copy_wrapper(first: i32, ...) i32 {
    var ap1: va_list = va_list{};
    @va_start(&ap1, first);  // first 是最后一个命名参数
    
    var ap2: va_list = va_list{};
    @va_copy(&ap2, ap1);
    
    const v1: i32 = @va_arg(ap1, i32);
    const v2: i32 = @va_arg(ap2, i32);
    
    @va_end(&ap1);
    @va_end(&ap2);
    
    return v2;  // 返回第二个读取的值（应该是相同的参数）
}
```

### 8.2 跨平台测试

```bash
# 在不同平台运行测试
make test TARGET=x86_64-linux
make test TARGET=x86_64-windows
make test TARGET=aarch64-linux
make test TARGET=i686-linux
```

### 8.3 C 互操作性测试

```uya
// tests/test_va_list_ffi.uya

// 使用 export extern "libc" 声明 C 标准库函数
export extern "libc" fn vprintf(format: &const byte, ap: va_list) i32;

test "va_list_ffi" {
    // 从 Uya 传递 va_list 给 C 函数
    // 需要在可变参数函数中初始化 va_list
    const result: i32 = _test_ffi_wrapper("Hello %s, count=%d\n", "world", 42);
}

fn _test_ffi_wrapper(format: &const byte, ...) i32 {
    var ap: va_list = va_list{};
    @va_start(&ap, format);
    
    const result: i32 = vprintf(format, ap);
    
    @va_end(&ap);
    return result;
}
```

---

## 9. 迁移指南

### 9.1 当前状态

当前 `lib/libc/stdarg.uya` 将 `va_list` 定义为自定义结构体：

```uya
// 当前实现（将被废弃）
export struct va_list {
    args: [u64: 16],      // 参数存储（最多 16 个参数）
    count: usize,         // 参数数量
    index: usize,         // 当前参数索引
    reg_count: usize,     // 已使用的寄存器参数数量
    stack_args: &u64,     // 栈上参数指针
    stack_index: usize,   // 栈上参数索引
}
```

这种实现有以下限制：
- 无法真正访问可变参数（需要编译器内置支持）
- 无法与 C 代码直接互操作
- 性能低下（需要手动复制参数）

### 9.2 迁移步骤

#### Step 1: 删除结构体定义

```diff
- export struct va_list {
-     args: [u64: 16],
-     count: usize,
-     index: usize,
-     reg_count: usize,
-     stack_args: &u64,
-     stack_index: usize,
- }
+ // va_list 现在是编译器内置类型，无需定义
```

#### Step 2: 更新 stdarg.uya

```uya
// lib/libc/stdarg.uya

// va_list 是编译器内置类型，无需定义

// 所有操作通过编译器内置函数完成：
// - @va_start(ap: &va_list, last_named_param) - 初始化
// - @va_end(ap: &va_list) - 结束
// - @va_arg(ap: va_list, Type) T - 获取参数
// - @va_copy(dest: &va_list, src: va_list) - 复制

// 本文件可以保持空或仅包含文档注释
```

#### Step 3: 更新使用代码

```uya
// 迁移前（当前实现使用函数）
fn foo(format: &const byte, ...) i32 {
    var ap: va_list = va_list{};  // 结构体需要初始化
    va_start_uya(&ap, format);    // 函数调用
    // ...
}

// 迁移后（使用内置类型和内置函数）
fn foo(format: &const byte, ...) i32 {
    var ap: va_list = va_list{};  // 使用空初始化语法
    @va_start(&ap, format);       // 内置函数初始化 va_list
    // ...
}
```

### 9.3 兼容性检查清单

| 检查项 | 说明 |
|--------|------|
| `sizeof(va_list)` | 现在是平台相关常量，不再是固定 24 |
| `&va_list` 指针操作 | 继续有效 |
| 结构体成员访问 | **不再支持**（如 `ap.gp_offset`） |
| 跨函数传递 | 继续有效 |
| C FFI 互操作 | 现在直接兼容 |

### 9.4 可能的破坏性变更

1. **直接访问结构体成员**：
   ```uya
   // ❌ 迁移后不再有效
   const offset = ap.gp_offset;
   ```
   解决方案：使用标准 API（`@va_arg`、`@va_copy`）

2. **sizeof(va_list) 硬编码**：
   ```uya
   // ❌ 迁移后可能失效
   const buf: [byte: 24] = ...;  // 假设 va_list 大小
   ```
   解决方案：使用 `@size_of(va_list)`

---

## 10. 实现计划

### 10.1 Phase 1: 编译器基础支持

```
优先级：高
工作量：中等

任务：
1. 类型系统中添加 va_list 内置类型
2. 类型检查器添加 va_list 相关规则
3. 放宽 @va_arg 使用位置限制
4. 添加 @va_copy 内置函数
```

### 10.2 Phase 2: C99 后端

```
优先级：高
工作量：低

任务：
1. va_list 类型映射为 C 的 va_list
2. @va_start/@va_end/@va_arg/@va_copy 展开
3. 生成正确的 #include <stdarg.h>
```

### 10.3 Phase 3: libc 实现

```
优先级：中
工作量：中

任务：
1. 实现 vfprintf
2. 实现 vprintf
3. 实现 vsprintf
4. 实现 vsnprintf
5. 更新 libc_todo.md
```

### 10.4 Phase 4: 测试和文档

```
优先级：中
工作量：低

任务：
1. 编写单元测试
2. 编写跨平台测试
3. 更新语言文档
4. 更新 CHANGELOG
```

---

## 11. 风险和缓解

### 11.1 风险列表

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 平台 ABI 差异导致不兼容 | 高 | C99 后端直接使用 C 的 va_list，自动处理平台差异 |
| 破坏现有代码 | 中 | va_list 从结构体改为内置类型，需要更新 stdarg.uya |
| 类型检查复杂度增加 | 低 | 新增检查规则，但逻辑清晰 |

### 11.2 回退方案

如果实现遇到问题，可以：
1. 保持 `va_list` 作为结构体类型
2. 仅在 C99 后端中使用 `typedef` 映射到 C 的 `va_list`
3. 手动实现参数复制（性能较低但可用）

---

## 12. 附录

### 12.1 参考资料

- [System V AMD64 ABI](https://refspecs.linuxbase.org/elf/x86_64-abi-0.99.pdf)
- [Microsoft x64 Calling Convention](https://learn.microsoft.com/en-us/cpp/build/x64-calling-convention)
- [ARM64 Procedure Call Standard](https://developer.arm.com/documentation/ihi0055/latest/)
- [C11 Standard §7.16](https://en.cppreference.com/w/c/variadic)

### 12.2 相关文件

| 文件 | 说明 |
|------|------|
| `src/checker/typeck.uya` | 类型检查规则 |
| `src/codegen/c99/type.uya` | C99 类型映射 |
| `src/codegen/c99/expr.uya` | 表达式代码生成 |
| `lib/libc/stdarg.uya` | va_list 辅助函数 |
| `lib/libc/stdio.uya` | vprintf 实现 |
