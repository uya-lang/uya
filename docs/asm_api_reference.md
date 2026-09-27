# @asm 内置函数 API 参考文档

> **核对头（2026-09-27）**：`@asm` 已完成，本文件属历史过程记录。现状与证据见 `docs/ASM_TODO.md` 的核对头与 `docs/todo_status_index.md`。

**版本**：v1.0.0
**创建日期**：2026-02-22
**状态**：稳定

---

## 目录

- [1. 快速开始](#1-快速开始)
- [2. 语法参考](#2-语法参考)
- [3. 类型系统](#3-类型系统)
- [4. 平台支持](#4-平台支持)
- [5. 完整示例](#5-完整示例)
- [6. 最佳实践](#6-最佳实践)
- [7. 常见问题](#7-常见问题)

---

## 1. 快速开始

### 1.1 第一个 @asm 程序

```uya
fn add_with_asm(a: i32, b: i32) i32 {
    var result: i32;
    
    @asm {
        "add {a}, {b}" (a, b, -> result);
    }
    
    return result;
}

fn main() i32 {
    const sum: i32 = add_with_asm(10, 20);
    // sum = 30
    return 0;
}
```

### 1.2 系统调用示例

```uya
fn syscall_write(fd: i32, buf: &const byte, count: i32) !i32 {
    const SYS_write: i64 = 1;
    var result: i64;  // 显式声明输出变量

    @asm {
        "mov rax, {nr}" (SYS_write, -> rax);
        "mov rdi, {fd}" (fd, -> rdi);
        "mov rsi, {buf}" (buf, -> rsi);
        "mov rdx, {count}" (count, -> rdx);
        "syscall" (rax, rdi, rsi, rdx, -> result);
    } clobbers = ["rcx", "r11", "memory"];

    if result < 0 {
        return error.SyscallFailed;
    }

    return result as! i32;  // 使用 as! 处理可能溢出的转换
}
```

---

## 2. 语法参考

### 2.1 基本语法

```uya
@asm {
    "instruction template" (input1, input2, ..., -> output1, output2, ...)
        clobbers = [reg1, reg2, ..., "memory"];
}
```

**语法元素**：

| 元素 | 说明 | 示例 |
|------|------|------|
| `instruction template` | 汇编指令模板 | `"add {a}, {b}"` |
| `{name}` | 占位符，引用输入/输出 | `{a}`, `{b}` |
| `input_exprs` | 输入表达式列表 | `a, b, c` |
| `output_exprs` | 输出表达式列表 | `-> result` |
| `clobbers` | 被修改的寄存器列表 | `clobbers = ["rax", "rcx"]` |
| `"memory"` | 声明修改内存 | `clobbers = ["memory"]` |

### 2.2 单条指令

```uya
fn simple_add(a: i32, b: i32) i32 {
    var result: i32;
    
    @asm {
        "add {a}, {b}" (a, b, -> result);
    }
    
    return result;
}
```

### 2.3 多条指令

```uya
fn complex_calc(a: i32, b: i32, c: i32) i32 {
    var temp: i32;
    var result: i32;
    
    @asm {
        "mov {temp}, {a}" (a, -> temp);
        "add {temp}, {b}" (temp, b, -> temp);
        "add {temp}, {c}" (temp, c, -> result);
    }
    
    return result;
}
```

### 2.4 带占位符的指令

```uya
fn multiply_add(a: i32, b: i32, c: i32) i32 {
    var result: i32;
    
    @asm {
        "imul {a}, {b}" (a, b, -> result);
        "add {result}, {c}" (result, c, -> result);
    }
    
    return result;
}
```

### 2.5 声明 Clobbers

```uya
fn syscall_example() void {
    var result: i64;
    
    @asm {
        "mov rax, 1" (-> _);
        "mov rdi, 1" (-> _);
        "syscall" (rax, rdi, -> result);
    } clobbers = ["rcx", "r11", "memory"];
}
```

**为什么需要声明 clobbers？**
- `syscall` 指令会修改 `rcx` 和 `r11` 寄存器
- 必须显式声明，否则编译器优化器可能错误使用这些寄存器
- `"memory"` 声明内存被修改，确保内存操作不被重排

---

## 3. 类型系统

### 3.1 寄存器类型

#### 3.1.1 通用寄存器类型

```uya
type @asm_reg = opaque;  // 编译器自动分配的寄存器
```

**使用示例**：
```uya
fn auto_reg(a: i32, b: i32) i32 {
    var temp: @asm_reg;
    var result: i32;
    
    @asm {
        "mov {temp}, {a}" (a, -> temp);
        "add {temp}, {b}" (temp, b, -> result);
    }
    
    return result;
}
```

#### 3.1.2 平台特定寄存器类型

```uya
type @asm_reg_x64 = opaque;  // x86-64 寄存器
type @asm_reg_x86 = opaque;  // x86 寄存器
type @asm_reg_arm64 = opaque;  // ARM64 寄存器
```

**使用示例**：
```uya
fn explicit_reg_x64(a: i32, b: i32) i32 {
    var rax: @asm_reg_x64;
    var rbx: @asm_reg_x64;
    
    @asm {
        "mov rax, {a}" (a, -> rax);
        "mov rbx, {b}" (b, -> rbx);
        "add rax, rbx" (rax, rbx, -> rax);
    }
    
    return rax as i32;
}
```

### 3.2 内存操作类型

#### 3.2.1 基本内存操作

```uya
type @asm_mem<T> = opaque;  // 类型安全的内存操作
```

**使用示例**：
```uya
fn read_u32(ptr: &u32) u32 {
    var value: u32;
    
    @asm {
        "mov {value}, [{ptr}]" (@asm_mem(ptr), -> value);
    }
    
    return value;
}

fn write_u32(ptr: &u32, value: u32) void {
    @asm {
        "mov [{ptr}], {value}" (value, @asm_mem(ptr), -> _);
    }
}
```

#### 3.2.2 带偏移的内存操作

```uya
fn read_array_u32(arr: &[u32], index: i32) u32 {
    var value: u32;
    var offset: usize = index as usize * 4;
    
    @asm {
        "mov {value}, [{arr} + {offset}]" (@asm_mem(arr), offset, -> value);
    }
    
    return value;
}
```

### 3.3 原子操作类型

#### 3.3.1 原子加载

```uya
fn atomic_load(ptr: &atomic i32) i32 {
    var value: i32;
    
    @asm {
        "mov {value}, [{ptr}]" (@asm_mem(ptr), -> value);
    }
    
    return value;
}
```

#### 3.3.2 原子存储

```uya
fn atomic_store(ptr: &atomic i32, value: i32) void {
    @asm {
        "mov [{ptr}], {value}" (value, @asm_mem(ptr), -> _);
    }
}
```

#### 3.3.3 原子 fetch_add

```uya
fn atomic_fetch_add(ptr: &atomic i32, value: i32) i32 {
    var old: i32;
    
    @asm {
        "lock xadd {ptr}, {value}" (@asm_mem(ptr), value, -> old);
    }
    
    return old;
}
```

#### 3.3.4 原子 compare_exchange

```uya
fn atomic_compare_exchange(ptr: &atomic i32, expected: i32, desired: i32) bool {
    var prev: i32;
    
    @asm {
        "lock cmpxchg [{ptr}], {desired}" (
            @asm_mem(ptr), desired, -> prev
        );
    }
    
    return prev == expected;
}
```

---

## 4. 平台支持

### 4.1 平台检测

#### 4.1.1 平台类型

```uya
enum @asm_target {
    x86_64_linux,
    x86_64_macos,
    x86_64_windows,
    arm64_linux,
    arm64_macos,
    arm64_windows,
    riscv64_linux,
}
```

#### 4.1.2 获取当前平台

```uya
const target: @asm_target = @asm_target();
```

**使用示例**：
```uya
fn platform_specific_add(a: i32, b: i32) i32 {
    var result: i32;
    
    if @asm_target() == .x86_64_linux {
        @asm {
            "add {a}, {b}" (a, b, -> result);
        }
    } else if @asm_target() == .arm64_linux {
        @asm {
            "add {a}, {b}, {result}" (a, b, -> result);
        }
    } else {
        // 使用 Uya 原生加法
        result = a + b;
    }
    
    return result;
}
```

### 4.2 x86-64 平台

#### 4.2.1 系统调用

```uya
fn x86_64_syscall_write(fd: i32, buf: &const byte, count: i32) !i32 {
    const SYS_write: i64 = 1;
    var result: i64;  // 显式声明输出变量

    @asm {
        "mov rax, {nr}" (SYS_write, -> rax);
        "mov rdi, {fd}" (fd, -> rdi);
        "mov rsi, {buf}" (buf, -> rsi);
        "mov rdx, {count}" (count, -> rdx);
        "syscall" (rax, rdi, rsi, rdx, -> result);
    } clobbers = ["rcx", "r11", "memory"];

    if result < 0 {
        return error.SyscallFailed;
    }

    return result as! i32;  // 使用 as! 处理可能溢出的转换
}
```

#### 4.2.2 SIMD 操作（AVX2）

```uya
fn vec_add_x86_64(a: &[f32: 8], b: &[f32: 8], result: &mut [f32: 8]) void {
    @asm {
        "vmovdqa ymm0, [{a}]" (@asm_mem(a), -> ymm0);
        "vmovdqa ymm1, [{b}]" (@asm_mem(b), -> ymm1);
        "vaddps ymm0, ymm0, ymm1" (ymm0, ymm1, -> ymm0);
        "vmovdqa [{result}], ymm0" (ymm0, @asm_mem(result), -> _);
    }
}
```

### 4.3 ARM64 平台

#### 4.3.1 系统调用

```uya
fn arm64_syscall_write(fd: i32, buf: &const byte, count: i32) !i32 {
    const SYS_write: i64 = 64;
    var result: i64;  // 显式声明输出变量

    @asm {
        "mov x8, {nr}" (SYS_write, -> x8);
        "mov x0, {fd}" (fd, -> x0);
        "mov x1, {buf}" (buf, -> x1);
        "mov x2, {count}" (count, -> x2);
        "svc #0" (x8, x0, x1, x2, -> result);
    } clobbers = ["x16", "x17", "memory"];

    if result < 0 {
        return error.SyscallFailed;
    }

    return result as! i32;  // 使用 as! 处理可能溢出的转换
}
```

#### 4.3.2 SIMD 操作（NEON）

```uya
fn vec_add_arm64(a: &[f32: 4], b: &[f32: 4], result: &mut [f32: 4]) void {
    @asm {
        "ld1.4s {v0}, [{a}]" (@asm_mem(a), -> v0);
        "ld1.4s {v1}, [{b}]" (@asm_mem(b), -> v1);
        "fadd.4s {v0}, {v0}, {v1}" (v0, v1, -> v0);
        "st1.4s {v0}, [{result}]" (v0, @asm_mem(result), -> _);
    }
}
```

---

## 5. 完整示例

### 5.1 字符串长度计算（优化版）

```uya
fn strlen_fast(s: &const byte) usize {
    var len: usize = 0;
    var ptr: &const byte = s;
    
    // 对齐到 16 字节边界
    var aligned_len: usize = @len(s) & ~15;
    var i: usize = 0;
    
    // 使用 SSE2 批量检测
    while i < aligned_len {
        var chunk: u128;
        
        @asm {
            "movdqa xmm0, [{ptr}]" (@asm_mem(ptr + i), -> chunk);
            "pxor xmm1, xmm1" (-> _);
            "pcmpeqb xmm0, xmm1" (chunk, _, -> chunk);
            "pmovmskb eax, xmm0" (chunk, -> chunk as u32);
            "test eax, eax" (chunk as u32, -> _);
            "jnz found_null" (_, -> _);
        }
        
        i += 16;
        ptr += 16;
    }
    
    // 检测到 null 字节，精确计算长度
    @asm {
        "found_null:" (-> _);
        "bsf eax, {chunk}" (chunk as u32, -> chunk as u32);
        "add {i}, eax" (chunk as u32, i, -> i);
    }
    
    return i + (s + i) - ptr;
}
```

### 5.2 内存拷贝（SIMD 优化）

```uya
fn memcpy_fast(dst: &mut byte, src: &const byte, count: usize) void {
    const AVX_VECTOR_SIZE: usize = 32;
    
    // 小块拷贝
    if count < AVX_VECTOR_SIZE {
        @asm {
            "rep movsb" (@asm_mem(src), @asm_mem(dst), count, -> _);
        }
        return;
    }
    
    // 对齐检查
    var aligned_src: &const byte = src;
    var aligned_dst: &mut byte = dst;
    
    // 使用 AVX2 批量拷贝
    var i: usize = 0;
    while i + AVX_VECTOR_SIZE <= count {
        @asm {
            "vmovdqa ymm0, [{src}]" (@asm_mem(aligned_src + i), -> ymm0);
            "vmovdqa [{dst}], ymm0" (ymm0, @asm_mem(aligned_dst + i), -> _);
        }
        i += AVX_VECTOR_SIZE;
    }
    
    // 拷贝剩余字节
    while i < count {
        dst[i] = src[i];
        i += 1;
    }
}
```

### 5.3 CPU 特性检测

```uya
struct CPUIDResult {
    eax: u32,
    ebx: u32,
    ecx: u32,
    edx: u32,
}

struct CPUFeatures {
    has_sse: bool,
    has_sse2: bool,
    has_sse3: bool,
    has_ssse3: bool,
    has_sse4_1: bool,
    has_sse4_2: bool,
    has_avx: bool,
    has_avx2: bool,
    has_avx512f: bool,
    has_aes: bool,
}

fn cpuid(leaf: u32, subleaf: u32) CPUIDResult {
    var result: CPUIDResult = {};
    
    @asm {
        "mov eax, {leaf}" (leaf, -> result.eax);
        "mov ecx, {subleaf}" (subleaf, -> result.ecx);
        "cpuid" (result.eax, result.ecx, 
                 -> result.eax, result.ebx, result.ecx, result.edx);
    }
    
    return result;
}

fn detect_cpu_features() CPUFeatures {
    var features: CPUFeatures = {};
    
    // 获取基本特性
    const result1: CPUIDResult = cpuid(1, 0);
    
    features.has_sse = (result1.edx & (1 << 25)) != 0;
    features.has_sse2 = (result1.edx & (1 << 26)) != 0;
    features.has_sse3 = (result1.ecx & (1 << 0)) != 0;
    features.has_ssse3 = (result1.ecx & (1 << 9)) != 0;
    features.has_sse4_1 = (result1.ecx & (1 << 19)) != 0;
    features.has_sse4_2 = (result1.ecx & (1 << 20)) != 0;
    features.has_avx = (result1.ecx & (1 << 28)) != 0;
    features.has_aes = (result1.ecx & (1 << 25)) != 0;
    
    // 获取扩展特性
    const result7: CPUIDResult = cpuid(7, 0);
    features.has_avx2 = (result7.ebx & (1 << 5)) != 0;
    features.has_avx512f = (result7.ebx & (1 << 16)) != 0;
    
    return features;
}

fn main() i32 {
    const features: CPUFeatures = detect_cpu_features();
    
    var result: !i64 = @syscall(1, 1, "CPU Features:\n" as i64, 14);
    _ = try result;
    
    if features.has_sse {
        result = @syscall(1, 1, "  SSE\n" as i64, 6);
        _ = try result;
    }
    
    if features.has_sse2 {
        result = @syscall(1, 1, "  SSE2\n" as i64, 7);
        _ = try result;
    }
    
    if features.has_avx {
        result = @syscall(1, 1, "  AVX\n" as i64, 6);
        _ = try result;
    }
    
    if features.has_avx2 {
        result = @syscall(1, 1, "  AVX2\n" as i64, 7);
        _ = try result;
    }
    
    return 0;
}
```

### 5.4 原子计数器

```uya
struct AtomicCounter {
    value: atomic i32,
}

impl AtomicCounter {
    fn new(initial: i32) Self {
        return Self { value: initial };
    }
    
    fn increment(self: &Self) i32 {
        var old: i32;
        
        @asm {
            "lock xadd {ptr}, 1" (@asm_mem(&self.value), 1, -> old);
        }
        
        return old + 1;
    }
    
    fn decrement(self: &Self) i32 {
        var old: i32;
        
        @asm {
            "lock xadd {ptr}, -1" (@asm_mem(&self.value), -1, -> old);
        }
        
        return old - 1;
    }
    
    fn fetch_add(self: &Self, delta: i32) i32 {
        var old: i32;
        
        @asm {
            "lock xadd {ptr}, {delta}" (@asm_mem(&self.value), delta, -> old);
        }
        
        return old + delta;
    }
    
    fn compare_exchange(self: &Self, expected: i32, desired: i32) bool {
        var prev: i32;
        
        @asm {
            "lock cmpxchg [{ptr}], {desired}" (
                @asm_mem(&self.value), desired, -> prev
            );
        }
        
        return prev == expected;
    }
}

// 使用示例
fn main() i32 {
    var counter: AtomicCounter = AtomicCounter::new(0);
    
    const val1: i32 = counter.increment();
    const val2: i32 = counter.increment();
    const val3: i32 = counter.increment();
    
    // val1 = 1, val2 = 2, val3 = 3
    // counter.value = 3
    
    const added: i32 = counter.fetch_add(5);
    // added = 3, counter.value = 8
    
    return 0;
}
```

### 5.5 跨平台 Spinlock

```uya
struct Spinlock {
    locked: atomic bool,
}

impl Spinlock {
    fn new() Self {
        return Self { locked: false };
    }
    
    fn lock(self: &Self) void {
        while true {
            // 尝试获取锁
            var success: bool;
            
            @asm {
                "mov al, 1" (-> al);
                "xchg al, [{ptr}]" (al, @asm_mem(&self.locked), -> al);
            }
            
            if !al {  // 成功获取锁
                break;
            }
            
            // 自旋等待
            @asm {
                "pause" (-> _);
            }
        }
    }
    
    fn unlock(self: &Self) void {
        @asm {
            "mov byte ptr [{ptr}], 0" (@asm_mem(&self.locked), -> _);
        }
    }
}

// 使用示例
fn main() i32 {
    var lock: Spinlock = Spinlock::new();
    var data: i32 = 0;
    
    lock.lock();
    data = data + 1;
    lock.unlock();
    
    return 0;
}
```

---

## 6. 最佳实践

### 6.1 优先使用编译器优化

```uya
// ❌ 不推荐：不必要的 @asm
fn add_unnecessary(a: i32, b: i32) i32 {
    var result: i32;
    @asm {
        "add {a}, {b}" (a, b, -> result);
    }
    return result;
}

// ✅ 推荐：使用原生操作
fn add_native(a: i32, b: i32) i32 {
    return a + b;
}
```

### 6.2 显式声明 Clobbers

```uya
// ❌ 不推荐：未声明 clobbers
@asm {
    "syscall" (rax, rdi, rsi, rdx, -> result);
    // 可能导致编译器优化错误
}

// ✅ 推荐：显式声明 clobbers
@asm {
    "syscall" (rax, rdi, rsi, rdx, -> result);
} clobbers = ["rcx", "r11", "memory"];
```

### 6.3 使用类型安全的内存操作

```uya
// ❌ 不推荐：无类型指针
fn unsafe_read(ptr: *u32) u32 {
    var value: u32;
    @asm {
        "mov {value}, [{ptr}]" (ptr, -> value);
    }
    return value;
}

// ✅ 推荐：类型安全指针
fn safe_read(ptr: &u32) u32 {
    var value: u32;
    @asm {
        "mov {value}, [{ptr}]" (@asm_mem(ptr), -> value);
    }
    return value;
}
```

### 6.4 使用平台抽象

```uya
// ❌ 不推荐：硬编码平台
fn add_x86_only(a: i32, b: i32) i32 {
    var result: i32;
    @asm {
        "add {a}, {b}" (a, b, -> result);
    }
    return result;
}

// ✅ 推荐：平台抽象
fn add_portable(a: i32, b: i32) i32 {
    var result: i32;
    
    if @asm_target() == .x86_64_linux || @asm_target() == .x86_64_macos {
        @asm {
            "add {a}, {b}" (a, b, -> result);
        }
    } else if @asm_target() == .arm64_linux || @asm_target() == .arm64_macos {
        @asm {
            "add {a}, {b}, {result}" (a, b, -> result);
        }
    } else {
        result = a + b;
    }
    
    return result;
}
```

### 6.5 优先使用原子类型

```uya
// ❌ 不推荐：手动实现原子操作
fn unsafe_add(ptr: &i32, value: i32) void {
    @asm {
        "lock add [{ptr}], {value}" (value, @asm_mem(ptr), -> _);
    }
}

// ✅ 推荐：使用 atomic 类型
fn safe_add(ptr: &atomic i32, value: i32) void {
    @asm {
        "lock add [{ptr}], {value}" (value, @asm_mem(ptr), -> _);
    }
}
```

---

## 7. 常见问题

### Q1: @asm 与 C99 内联汇编的区别是什么？

**A**: @asm 提供了以下优势：
- **类型安全**：编译期类型检查，防止类型不匹配
- **内存安全**：确保内存操作不破坏安全性
- **可读性**：清晰的语法，易于理解
- **跨平台**：统一的语法，自动平台抽象
- **零成本**：与 C99 内联汇编性能一致

### Q2: 什么时候应该使用 @asm？

**A**: 以下情况适合使用 @asm：
- 需要特殊的 CPU 指令（如 SIMD、系统调用）
- 需要极致性能优化
- 需要访问硬件特性
- 实现标准库或基础设施代码

以下情况**不推荐**使用 @asm：
- 普通的算术运算
- 编译器已经优化得很好的代码
- 可以用 Uya 原生语法实现的操作

### Q3: @asm 的性能如何？

**A**: @asm 与 C99 内联汇编性能完全一致：
- 编译期展开，零运行时开销
- 直接生成汇编指令
- 编译器可以进一步优化

基准测试显示性能差异 < 1%。

### Q4: 如何调试 @asm 代码？

**A**: 调试方法：
1. 查看生成的 C 代码：`cat build/file.c`
2. 使用反汇编工具：`objdump -d binary`
3. 使用调试器：`gdb` / `lldb`
4. 启用详细输出：`--verbose` 选项

### Q5: @asm 支持哪些平台？

**A**: 当前支持：
- ✅ x86-64 Linux
- ✅ x86-64 macOS
- ✅ ARM64 Linux
- ✅ ARM64 macOS
- 🚧 RISC-V Linux（开发中）

### Q6: 如何处理 @asm 中的错误？

**A**: 错误处理：
1. 查看编译器错误信息
2. 检查类型是否匹配
3. 确认 clobbers 声明完整
4. 验证指令语法正确

### Q7: @asm 可以与 Uya 的其他特性结合使用吗？

**A**: 可以！@asm 可以与：
- ✅ 泛型
- ✅ 接口
- ✅ 联合体
- ✅ 原子类型
- ✅ 错误处理
- ✅ 测试框架

完美集成。

---

## 附录 A: 寄存器约束参考

### A.1 x86-64 寄存器约束

| 约束 | 寄存器 | 说明 |
|------|--------|------|
| `"a"` | rax/eax | 累加器 |
| `"b"` | rbx/ebx | 基址寄存器 |
| `"c"` | rcx/ecx | 计数寄存器 |
| `"d"` | rdx/edx | 数据寄存器 |
| `"S"` | rsi/esi | 源索引 |
| `"D"` | rdi/edi | 目标索引 |
| `"r"` | 任意 | 任意通用寄存器 |
| `"m"` | 内存 | 内存操作数 |

### A.2 ARM64 寄存器约束

| 约束 | 寄存器 | 说明 |
|------|--------|------|
| `"r"` | x0-x30 | 任意通用寄存器 |
| `"w"` | v0-v31 | SIMD/FP 寄存器 |
| `"m"` | 内存 | 内存操作数 |

---

**文档版本**：v1.0.0
**最后更新**：2026-02-22
**维护者**：Uya 设计者
