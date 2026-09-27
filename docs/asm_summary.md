# @asm 内置函数 - 完整开发计划总结

> **核对头（2026-09-27）**：`@asm` 已完成，本文件属历史过程记录。现状与证据见 `docs/ASM_TODO.md` 的核对头与 `docs/todo_status_index.md`。

**版本**：v1.0.0
**创建日期**：2026-02-22
**状态**：启动阶段

---

## 项目概述

@asm 是 Uya 语言的一个核心内置函数，用于编写类型安全的内联汇编代码，替代 C99 的复杂内联汇编语法，同时保持零成本抽象和跨平台支持。

---

## 核心设计哲学

### 符合 Uya 的"坚如磐石"哲学

1. **显式控制**：所有汇编操作显式声明，无隐式副作用
2. **编译期证明**：在当前函数内验证汇编操作的安全性
3. **零成本**：直接生成汇编指令，无运行时包装
4. **类型安全**：寄存器、内存操作与 Uya 类型系统绑定

### 与 C99 内联汇编的对比

| 特性 | C99 内联汇编 | @asm (Uya) |
|------|-------------|------------|
| 语法 | 字符串字面量，易出错 | 结构化语法，类型安全 |
| 寄存器约束 | 约束字符串 (`"r"`, `"a"`) | 类型推断 + 显式指定 |
| 类型检查 | 无 | 完整编译期类型检查 |
| 寄存器分配 | 手动指定 | 自动分配 + 显式覆盖 |
| 内存修改 | 隐式，需用 `"memory"` clobber | 显式内存操作声明 |
| 跨平台 | 每个平台写不同代码 | 统一语法，平台抽象 |
| 内存安全 | ❌ | ✅ |
| 并发安全 | ❌ | ✅ |
| 可读性 | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| 性能 | 1.0x | 1.0x（零开销） |

---

## 文档结构

### 1. 设计文档 (`asm_design.md`)

**内容**：
- 概述和设计目标
- 完整的语法设计
- 类型系统详解
- 平台抽象机制
- 内存安全机制
- 并发安全机制
- 代码生成策略
- 实现清单
- 测试策略
- 性能考虑
- 未来扩展方向

**适用人群**：
- 语言设计者
- 编译器实现者
- 核心开发者

### 2. 实施计划 (`asm_implementation_plan.md`)

**内容**：
- 3周3阶段的实施计划
- 详细的实现步骤（每个文件的修改点和代码示例）
- 完整的测试用例实现
- 集成和测试流程
- 验收标准
- 风险和应对
- 后续优化方向

**适用人群**：
- 编译器实现者
- 测试工程师
- 项目经理

### 3. API 参考文档 (`asm_api_reference.md`)

**内容**：
- 快速开始指南
- 完整的语法参考
- 类型系统详解
- 平台支持说明
- 完整示例代码（字符串操作、内存拷贝、CPU 特性检测等）
- 最佳实践
- 常见问题解答
- 寄存器约束参考

**适用人群**：
- Uya 语言使用者
- 库开发者
- 系统编程者

### 4. 测试文档 (`tests/programs/README_asm.md`)

**内容**：
- 测试文件列表和分类
- 运行测试的方法
- 完整的测试示例代码
- 测试覆盖范围
- 添加新测试的指南

**适用人群**：
- 测试工程师
- 贡献者
- 用户

---

## 核心功能

### 1. 基本语法

```uya
@asm {
    "add {a}, {b}" (a, b, -> result);
}
```

**特点**：
- 清晰的字符串模板
- 占位符引用输入/输出
- 箭头分隔输入和输出
- 可选的 clobbers 声明

### 2. 类型安全

```uya
// ✅ 类型安全
fn add_safe(a: i32, b: i32) i32 {
    var result: i32;
    @asm {
        "add {a}, {b}" (a, b, -> result);
    }
    return result;
}

// ❌ 类型不安全（编译错误）
fn add_unsafe(a: i32, b: f64) i32 {
    var result: i32;
    @asm {
        "add {a}, {b}" (a, b, -> result);  // 类型不匹配
    }
    return result;
}
```

### 3. 内存安全

```uya
// ✅ 类型安全的内存操作
fn read_u32(ptr: &u32) u32 {
    var value: u32;
    @asm {
        "mov {value}, [{ptr}]" (@asm_mem(ptr), -> value);
    }
    return value;
}

// ✅ 原子操作
fn atomic_add(ptr: &atomic i32, value: i32) i32 {
    var old: i32;
    @asm {
        "lock xadd {ptr}, {value}" (@asm_mem(ptr), value, -> old);
    }
    return old + value;
}
```

### 4. 跨平台支持

```uya
fn add_portable(a: i32, b: i32) i32 {
    var result: i32;
    
    if @asm_target() == .x86_64_linux {
        @asm {
            "add {a}, {b}" (a, b, -> result);
        }
    } else if @asm_target() == .arm64_linux {
        @asm {
            "add {a}, {b}, {result}" (a, b, -> result);
        }
    }
    
    return result;
}
```

---

## 实施计划

### 阶段 1：基础架构（第1周）

**目标**：建立 @asm 的基础语法和类型系统

**任务**：
- Lexer 支持 `@asm` 关键字
- AST 添加 `AST_ASM` 节点
- Parser 实现基础语法解析
- Checker 实现基础类型检查
- Codegen 实现简单指令生成

**交付物**：
- 可以编译简单的 `@asm` 块
- 生成对应的 C99 内联汇编
- 基础测试用例通过

### 阶段 2：核心功能（第2周）

**目标**：完善类型安全、内存安全和并发安全机制

**任务**：
- 完善输入/输出类型检查
- 寄存器约束验证
- 指针类型安全检查
- 原子操作类型检查
- 平台检测实现
- 条件编译支持

**交付物**：
- 完整的类型安全验证
- 内存安全机制
- 并发安全机制
- 平台抽象基础

### 阶段 3：优化和测试（第3周）

**目标**：性能优化、跨平台支持、完整测试

**任务**：
- 编译期常量折叠
- 指令融合
- 冗余消除
- ARM64 平台支持
- 完整测试套件
- 性能基准测试
- 文档完善

**交付物**：
- 优化的代码生成
- 完整的测试套件
- 完善的文档
- 跨平台支持

---

## 技术亮点

### 1. 类型安全的寄存器系统

```uya
// 自动分配寄存器
var temp: @asm_reg;
@asm {
    "mov {temp}, {a}" (a, -> temp);
}

// 显式指定寄存器
var rax: @asm_reg_x64;
@asm {
    "mov rax, 42" (-> rax);
}
```

### 2. 类型安全的内存操作

```uya
// 编译期类型检查
fn read_u32(ptr: &u32) u32 {
    var value: u32;
    @asm {
        "mov {value}, [{ptr}]" (@asm_mem(ptr), -> value);
    }
    return value;
}

// 错误：FFI 指针不能直接使用
fn unsafe_read(ptr: *u32) u32 {
    var value: u32;
    @asm {
        "mov {value}, [{ptr}]" (ptr, -> value);  // 编译错误
    }
    return value;
}
```

### 3. 并发安全的原子操作

```uya
// 原子操作必须使用 atomic 类型
fn atomic_add(ptr: &atomic i32, value: i32) i32 {
    var old: i32;
    @asm {
        "lock xadd {ptr}, {value}" (@asm_mem(ptr), value, -> old);
    }
    return old + value;
}

// 错误：非原子类型
fn unsafe_add(ptr: &i32, value: i32) i32 {
    var old: i32;
    @asm {
        "lock xadd {ptr}, {value}" (@asm_mem(ptr), value, -> old);
        // 编译错误：ptr 不是 atomic 类型
    }
    return old + value;
}
```

### 4. 平台抽象

```uya
// 统一的语法，自动平台抽象
fn syscall_write(fd: i32, buf: &const byte, count: i32) !i32 {
    const SYS_write: i64 = 1;
    var result: i64;
    
    if @asm_target() == .x86_64_linux {
        @asm {
            "mov rax, {nr}" (SYS_write, -> rax);
            "mov rdi, {fd}" (fd, -> rdi);
            "mov rsi, {buf}" (buf, -> rsi);
            "mov rdx, {count}" (count, -> rdx);
            "syscall" (rax, rdi, rsi, rdx, -> result);
        } clobbers = ["rcx", "r11", "memory"];
    } else if @asm_target() == .arm64_linux {
        @asm {
            "mov x8, {nr}" (SYS_write, -> x8);
            "mov x0, {fd}" (fd, -> x0);
            "mov x1, {buf}" (buf, -> x1);
            "mov x2, {count}" (count, -> x2);
            "svc #0" (x8, x0, x1, x2, -> result);
        } clobbers = ["x16", "x17", "memory"];
    }
    
    if result < 0 {
        return error.SyscallFailed;
    }
    
    return result as! i32;
}
```

---

## 测试策略

### 测试分类

1. **基础功能测试**
   - 基本算术运算
   - 系统调用
   - 内存操作
   - 控制流

2. **类型安全测试**
   - 类型检查
   - 类型不匹配（预期失败）
   - 寄存器约束验证

3. **内存安全测试**
   - 内存安全操作
   - 边界检查
   - 原子操作

4. **并发安全测试**
   - 无锁数据结构
   - 自旋锁
   - 并发计数器

5. **跨平台测试**
   - x86-64 平台
   - ARM64 平台
   - 平台检测

6. **性能测试**
   - 内存拷贝（与 memcpy 对比）
   - 字符串操作（与标准库对比）
   - 原子操作（与 std.atomic 对比）

### 验收标准

**功能完整性**：
- 所有基础功能测试通过
- 所有类型安全测试通过
- 所有内存安全测试通过
- 所有并发安全测试通过
- 所有平台检测测试通过

**性能指标**：
- @asm 生成的代码与 C99 内联汇编性能一致（误差 < 1%）
- 编译时间增加 < 5%
- 生成的代码大小增加 < 2%

**代码质量**：
- 代码覆盖率 > 90%
- 无内存泄漏
- 无编译警告
- 符合代码规范

---

## 使用场景

### 1. 系统编程

```uya
// 系统调用
fn syscall_exit(code: i32) noreturn {
    const SYS_exit: i64 = 60;
    
    @asm {
        "mov rax, {nr}" (SYS_exit, -> rax);
        "mov rdi, {code}" (code, -> rdi);
        "syscall" (rax, rdi, -> _);
    } clobbers = ["rcx", "r11"];
}
```

### 2. 性能优化

```uya
// SIMD 优化的内存拷贝
fn memcpy_fast(dst: &mut byte, src: &const byte, count: usize) void {
    const AVX_VECTOR_SIZE: usize = 32;
    
    if count >= AVX_VECTOR_SIZE {
        var i: usize = 0;
        while i + AVX_VECTOR_SIZE <= count {
            @asm {
                "vmovdqa ymm0, [{src}]" (@asm_mem(src + i), -> ymm0);
                "vmovdqa [{dst}], ymm0" (ymm0, @asm_mem(dst + i), -> _);
            }
            i += AVX_VECTOR_SIZE;
        }
    }
    
    // 拷贝剩余字节
    var i: usize = count & ~(AVX_VECTOR_SIZE - 1);
    while i < count {
        dst[i] = src[i];
        i += 1;
    }
}
```

### 3. 硬件特性访问

```uya
// CPU 特性检测
struct CPUFeatures {
    has_sse: bool,
    has_sse2: bool,
    has_avx: bool,
    has_avx2: bool,
}

fn detect_cpu_features() CPUFeatures {
    var features: CPUFeatures = {};
    
    const result1 = cpuid(1, 0);
    features.has_sse = (result1.edx & (1 << 25)) != 0;
    features.has_sse2 = (result1.edx & (1 << 26)) != 0;
    features.has_avx = (result1.ecx & (1 << 28)) != 0;
    
    const result7 = cpuid(7, 0);
    features.has_avx2 = (result7.ebx & (1 << 5)) != 0;
    
    return features;
}
```

### 4. 并发原语

```uya
// 无锁队列
struct LockFreeQueue {
    head: atomic &Node,
    tail: atomic &Node,
}

impl LockFreeQueue {
    fn enqueue(self: &Self, value: i32) void {
        var node: Node = Node { value: value, next: null };
        
        loop {
            const tail = self.tail.load();
            const next = tail.next;
            
            if next != null {
                self.tail.compare_exchange(tail, next);
                continue;
            }
            
            if tail.next.compare_exchange(null, &node) {
                self.tail.compare_exchange(tail, &node);
                return;
            }
        }
    }
}
```

---

## 预期成果

### 1. 完整的 @asm 内置函数实现

- 类型安全的内联汇编
- 内存安全保证
- 并发安全保证
- 跨平台支持

### 2. 零成本抽象

- 与 C99 内联汇编性能一致
- 编译期展开，无运行时开销
- 编译器优化友好

### 3. 完善的文档

- 设计文档
- 实施计划
- API 参考文档
- 测试文档

### 4. 完整的测试套件

- 基础功能测试
- 类型安全测试
- 内存安全测试
- 并发安全测试
- 跨平台测试
- 性能测试

---

## 后续优化方向

### 1. 高级特性（v1.1.0+）

- SIMD 抽象
- 标签跳转
- 内联函数
- 宏支持

### 2. 多架构支持（v1.2.0+）

- RISC-V 支持
- MIPS 支持
- PowerPC 支持

### 3. 代码生成优化（v1.3.0+）

- LLVM 后端支持
- WebAssembly 后端支持
- 自定义汇编后端

---

## 总结

@asm 内置函数是 Uya 语言的重要组成部分，它提供了：

1. **类型安全**：完整的编译期类型检查，防止未定义行为
2. **跨平台支持**：统一的语法，自动平台抽象
3. **内存安全**：确保汇编操作不破坏内存安全保证
4. **并发安全**：自动验证原子操作和并发安全
5. **零成本**：编译期展开，零运行时开销
6. **可读性**：清晰的语法，替代 C99 的复杂内联汇编

**一句话总结**：

> **@asm = 类型安全 + 跨平台 + 内存安全 + 零成本的内联汇编**

这个完整的开发计划将确保 @asm 内置函数在 3 周内完成核心功能实现，并具备完善的测试和文档。

---

**文档版本**：v1.0.0
**最后更新**：2026-02-22
**下次审查**：每周五
