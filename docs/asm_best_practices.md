# @asm 内联汇编最佳实践

> **核对头（2026-09-27）**：`@asm` 已完成，本文件属历史过程记录。现状与证据见 `docs/ASM_TODO.md` 的核对头与 `docs/todo_status_index.md`。

**版本**: v1.0.0  
**创建日期**: 2026-02-24  
**适用对象**: Uya 语言高级开发者

---

## 目录

- [1. 设计原则](#1-设计原则)
- [2. 性能优化](#2-性能优化)
- [3. 安全性建议](#3-安全性建议)
- [4. 可移植性建议](#4-可移植性建议)
- [5. 代码组织](#5-代码组织)
- [6. 测试策略](#6-测试策略)
- [7. 实战案例](#7-实战案例)

---

## 1. 设计原则

### 1.1 何时使用 @asm

**✅ 应该使用 @asm 的场景**：

1. **系统调用** - 直接访问操作系统服务
   ```uya
   fn syscall_write(fd: i32, buf: &const byte, count: i32) !i32 {
       // 系统调用实现
   }
   ```

2. **底层硬件操作** - 直接访问硬件寄存器
   ```uya
   fn read_cpu_features() u64 {
       // 读取 CPU 特性
   }
   ```

3. **性能关键路径** - 需要极致性能的代码
   ```uya
   fn fast_memcpy(dest: &byte, src: &const byte, n: usize) void {
       // SIMD 优化内存复制
   }
   ```

4. **原子操作** - 实现自定义原子操作
   ```uya
   fn atomic_compare_and_swap(ptr: &atomic i32, expected: i32, new: i32) bool {
       // CAS 操作
   }
   ```

**❌ 不应该使用 @asm 的场景**：

1. **普通业务逻辑** - 使用普通 Uya 代码
2. **可移植性要求高** - 避免平台相关代码
3. **可读性优先** - 保持代码清晰易懂
4. **维护性重要** - 团队协作项目

### 1.2 设计哲学

#### 最小权限原则

只请求必要的寄存器，只声明必要的 clobbers：

```uya
// ❌ 过度请求
@asm {
    "nop" (a, -> result);
} clobbers = ["rax", "rbx", "rcx", "rdx", "rsi", "rdi", "r8", "r9"];

// ✅ 最小权限
@asm {
    "nop" (a, -> result);
} clobbers = ["rax"];
```

#### 显式优于隐式

所有输入输出必须显式声明：

```uya
// ❌ 隐式依赖外部状态
var global: i32 = 0;
@asm {
    "nop" (-> result);  // 隐式依赖 global
}

// ✅ 显式声明
@asm {
    "nop" (global, -> result);  // 显式输入
}
```

#### 安全第一

编译期检查所有可能的问题：

```uya
// ❌ 运行时可能崩溃
var ptr: &i32 = get_pointer();  // 可能为 null
@asm {
    "nop" (ptr);
}

// ✅ 编译期验证
if ptr != null {
    @asm {
        "nop" (ptr);
    }
}
```

---

## 2. 性能优化

### 2.1 寄存器优化

#### 减少 Clobbers

只声明实际修改的寄存器：

```uya
// ❌ 过度声明
@asm {
    "nop" (a, -> result);
} clobbers = ["rax", "rbx", "rcx"];

// ✅ 精确声明
@asm {
    "nop" (a, -> result);
} clobbers = ["rax"];
```

**影响**: 减少编译器保存/恢复寄存器的开销

#### 重用寄存器

尽可能重用寄存器：

```uya
// ❌ 使用多个寄存器
@asm {
    "nop" (a, -> r1);
    "nop" (b, -> r2);
    "nop" (c, -> r3);
}

// ✅ 重用寄存器
@asm {
    "nop" (a, -> result);
    "nop" (b, -> result);
    "nop" (c, -> result);
}
```

### 2.2 批量操作

#### 批量处理数据

一次处理多个数据项：

```uya
// ❌ 单个处理
fn add_one_by_one(arr: &i32, n: usize) void {
    var i: usize = 0;
    while i < n {
        @asm {
            "nop" (arr, i);
        }
        i = i + 1;
    }
}

// ✅ 批量处理（一次 4 个）
fn add_batch(arr: &i32, n: usize) void {
    var i: usize = 0;
    while i + 4 <= n {
        @asm {
            "nop" (arr, i, i+1, i+2, i+3);  // 一次处理 4 个
        }
        i = i + 4;
    }
    // 处理剩余元素
}
```

#### 循环展开

手动展开循环以提高性能：

```uya
// ❌ 紧凑循环
var i: usize = 0;
while i < 100 {
    @asm {
        "nop" (arr, i);
    }
    i = i + 1;
}

// ✅ 循环展开（4 倍）
i = 0;
while i < 100 {
    @asm {
        "nop" (arr, i);
        "nop" (arr, i+1);
        "nop" (arr, i+2);
        "nop" (arr, i+3);
    }
    i = i + 4;
}
```

### 2.3 内存访问优化

#### 对齐访问

确保内存访问对齐：

```uya
// ❌ 未对齐访问
var arr: [byte: 100] = [];
var ptr: &u64 = &arr[1] as &u64;  // 未对齐

// ✅ 对齐访问
var aligned_arr: [u64: 10] = [];
var ptr: &u64 = &aligned_arr[0];  // 对齐
```

#### 减少内存访问

使用寄存器保存中间结果：

```uya
// ❌ 频繁内存访问
@asm {
    "nop" (arr[0]);
    "nop" (arr[1]);
    "nop" (arr[2]);
}

// ✅ 减少内存访问
var v0: i32 = arr[0];
var v1: i32 = arr[1];
var v2: i32 = arr[2];
@asm {
    "nop" (v0, v1, v2, -> result);
}
```

### 2.4 类型选择

#### 使用合适的类型大小

选择最适合的类型：

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

#### 使用无符号类型

在适当场景使用无符号类型：

```uya
// ❌ 有符号类型（需要符号扩展）
var idx: i32 = 0;

// ✅ 无符号类型（零扩展，更快）
var idx: usize = 0;
```

---

## 3. 安全性建议

### 3.1 内存安全

#### 边界检查

始终进行边界检查：

```uya
// ❌ 缺少边界检查
var arr: [i32: 10] = [];
var idx: i32 = get_index();
var ptr: &i32 = &arr[idx];  // 编译错误

// ✅ 有边界检查
if idx >= 0 && idx < 10 {
    var ptr: &i32 = &arr[idx];
    @asm {
        "nop" (ptr);
    }
}
```

#### 空指针检查

检查指针是否为 null：

```uya
// ❌ 未检查 null
var ptr: &i32 = get_pointer();
@asm {
    "nop" (ptr);  // 可能崩溃
}

// ✅ 检查 null
var ptr: &i32 = get_pointer();
if ptr != null {
    @asm {
        "nop" (ptr);
    }
}
```

#### 内存 Clobber 声明

修改内存时必须声明：

```uya
// ❌ 缺少 memory clobber
@asm {
    "nop" (ptr, value);  // 修改了内存
}

// ✅ 声明 memory clobber
@asm {
    "nop" (ptr, value);
} clobbers = ["memory"];
```

### 3.2 类型安全

#### 类型匹配

确保类型匹配：

```uya
// ❌ 类型不匹配
var f: f64 = 3.14;
@asm {
    "nop" (f);  // 编译错误
}

// ✅ 类型匹配
var i: i32 = 3;
@asm {
    "nop" (i);
}
```

#### 类型转换

使用正确的类型转换：

```uya
// ❌ 不安全的转换
var i: i64 = large_value;
var small: i32 = i as i32;  // 可能溢出

// ✅ 安全的转换
var i: i64 = large_value;
var small: i32 = try i as! i32;  // 检查溢出
```

### 3.3 并发安全

#### 原子操作

使用 `atomic T` 类型：

```uya
// ❌ 非原子操作
var counter: i32 = 0;
counter = counter + 1;  // 数据竞争

// ✅ 原子操作
var counter: atomic i32 = 0;
@asm {
    "nop" (&counter);
} clobbers = ["memory"];
```

#### 内存屏障

在需要的地方插入内存屏障：

```uya
// 写入数据
data = 42;

// 内存屏障，确保写入可见
@asm {
    "nop" ();
} clobbers = ["memory"];

// 设置标志
ready = true;
```

---

## 4. 可移植性建议

### 4.1 平台检测

使用 `@asm_target()` 检测平台：

```uya
fn platform_memcpy(dest: &byte, src: &const byte, n: usize) void {
    const target: i32 = @asm_target();
    
    if target == 0 {
        // x86-64 实现
        @asm {
            "nop" (dest, src, n);
        } clobbers = ["memory"];
    } else {
        if target == 1 {
            // ARM64 实现
            @asm {
                "nop" (dest, src, n);
            } clobbers = ["memory"];
        } else {
            // 回退到 C 实现
            // ...
        }
    }
}
```

### 4.2 抽象层

为平台相关代码创建抽象层：

```uya
// platform.uya
const TARGET: i32 = @asm_target();

fn is_x86_64() bool {
    return TARGET == 0;
}

fn is_arm64() bool {
    return TARGET == 1;
}

// 使用
if is_x86_64() {
    // x86-64 特定代码
}
```

### 4.3 寄存器抽象

避免硬编码寄存器名称：

```uya
// ❌ 硬编码寄存器
@asm {
    "mov rax, {x}" (x, -> result);
}

// ✅ 使用占位符（让编译器分配）
@asm {
    "mov {dst}, {src}" (x, -> result);
}
```

---

## 5. 代码组织

### 5.1 模块化

将 @asm 代码组织到独立模块：

```
std/
  asm/
    x86_64.uya    # x86-64 实现
    arm64.uya     # ARM64 实现
    atomic.uya    # 原子操作
    memory.uya    # 内存操作
```

### 5.2 函数封装

封装 @asm 代码为函数：

```uya
// ❌ 直接使用 @asm
fn process() void {
    var x: i32 = 0;
    @asm {
        "nop" (-> x);
    }
    // ...
}

// ✅ 封装为函数
fn asm_operation() i32 {
    var result: i32 = 0;
    @asm {
        "nop" (-> result);
    }
    return result;
}

fn process() void {
    const x: i32 = asm_operation();
    // ...
}
```

### 5.3 文档注释

为 @asm 代码添加详细注释：

```uya
// 原子递增操作
// 参数:
//   ptr - 指向 atomic i32 的指针
// 返回: 递增后的值
// 副作用: 修改内存，需要 memory clobber
fn atomic_increment(ptr: &atomic i32) i32 {
    var result: i32 = 0;
    @asm {
        "nop" (ptr, -> result);
    } clobbers = ["memory"];
    return result;
}
```

---

## 6. 测试策略

### 6.1 单元测试

为每个 @asm 函数编写单元测试：

```uya
test "atomic_increment" {
    var counter: atomic i32 = 0;
    const result: i32 = atomic_increment(&counter);
    try assert_eq_i32(result, 1, "increment should return 1");
    try assert_eq_i32(counter, 1, "counter should be 1");
}
```

### 6.2 边界测试

测试边界情况：

```uya
test "atomic_increment overflow" {
    var counter: atomic i32 = 2147483647;  // INT_MAX
    const result: i32 = atomic_increment(&counter);
    // 测试溢出行为
}
```

### 6.3 并发测试

测试并发场景：

```uya
test "atomic_increment concurrent" {
    var counter: atomic i32 = 0;
    // 创建多个线程并发递增
    // 验证最终结果正确
}
```

### 6.4 性能测试

基准测试：

```uya
test "bench atomic_increment" {
    var counter: atomic i32 = 0;
    const iterations: usize = 10000;
    
    const start: i64 = clock();
    var i: usize = 0;
    while i < iterations {
        const result: i32 = atomic_increment(&counter);
        i = i + 1;
    }
    const end: i64 = clock();
    
    printf("Time: %ld ticks\n", end - start);
}
```

---

## 7. 实战案例

### 7.1 高性能内存复制

```uya
// 使用 SIMD 指令优化内存复制
fn fast_memcpy(dest: &byte, src: &const byte, n: usize) void {
    var d: &byte = dest;
    var s: &const byte = src;
    var remaining: usize = n;
    
    // 批量复制（一次 32 字节）
    while remaining >= 32 {
        @asm {
            "nop" (d, s);  // 使用 SIMD 指令
        } clobbers = ["memory"];
        
        d = d + 32;
        s = s + 32;
        remaining = remaining - 32;
    }
    
    // 复制剩余字节
    while remaining > 0 {
        d[0] = s[0];
        d = d + 1;
        s = s + 1;
        remaining = remaining - 1;
    }
}
```

### 7.2 原子比较并交换

```uya
// 实现 CAS 操作
fn atomic_cas(ptr: &atomic i32, expected: i32, new: i32) bool {
    var result: bool = false;
    
    @asm {
        "nop" (ptr, expected, new, -> result);
    } clobbers = ["memory"];
    
    return result;
}
```

### 7.3 自旋锁

```uya
struct SpinLock {
    locked: atomic bool
}

fn spin_lock(lock: &SpinLock) void {
    var expected: bool = false;
    
    // 自旋等待
    while !atomic_cas(&lock.locked, expected, true) {
        expected = false;
        // 短暂暂停
        @asm {
            "nop" ();
        }
    }
}

fn spin_unlock(lock: &SpinLock) void {
    lock.locked = false;
    @asm {
        "nop" ();
    } clobbers = ["memory"];
}
```

### 7.4 无锁队列

```uya
struct Node {
    value: i32,
    next: &atomic Node
}

struct LockFreeQueue {
    head: &atomic Node,
    tail: &atomic Node
}

fn enqueue(queue: &LockFreeQueue, node: &Node) void {
    node.next = null;
    
    var tail: &atomic Node = queue.tail;
    var next: &atomic Node = null;
    
    while true {
        // 尝试 CAS 更新 tail->next
        if atomic_cas(&tail.next, next, node as &atomic Node) {
            // 成功，尝试更新 tail
            atomic_cas(&queue.tail, tail, node as &atomic Node);
            return;
        } else {
            // 失败，tail 已被其他线程更新
            tail = queue.tail;
        }
    }
}
```

---

## 8. LTO / GC-sections 陷阱

当项目开启 **`-flto -Wl,--gc-sections -ffunction-sections -fdata-sections`**（如 microapp 默认优化链路）时，需特别注意 `@asm` 中通过**硬编码字符串**引用的符号。

### 问题描述

链接器无法解析 `@asm` 字符串里的符号依赖。如果 `@asm` 通过 `call some_helper` 或 `mov some_global(%rip), %rdi` 引用了一个 `static` 函数或全局变量，而该符号在常规调用图中没有显式被调用，则 `--gc-sections` 会将其视为死代码并丢弃，导致：

```
undefined reference to `some_helper'
undefined reference to `some_global'
```

### 实际案例

`lib/libc/pthread.uya` 中的 `pthread_create` 使用 `@asm` 内联汇编直接调用 `_pthread_call_start` 和 `_pthread_thread_exit`：

```uya
@asm {
    "...\n\tcall _pthread_call_start\n\t...\n\tcall _pthread_thread_exit\n\t..."
} clobbers = ["rax", "rdi", "rsi", ... , "memory"];
```

在 LTO + `--gc-sections` 下，这些内部辅助符号会被回收，导致 microapp 链接失败。

### 解决方案

编译器后端已将所有内部 `static` 函数和全局变量统一标记为 `__attribute__((used))`，强制链接器保留。若你在手写 C 封装或自定义后端中遇到类似问题，可手动添加该属性：

```c
// 函数
static __attribute__((used)) void helper(void) { ... }

// 全局变量
__attribute__((used)) static int global_state = 0;
```

### 最佳实践

1. **优先通过输入/输出约束传递符号地址**：如果编译器支持，把函数指针或变量地址作为 `@asm` 的显式输入，而不是在汇编字符串里写死符号名。这样编译器会在输入约束中建立真实的数据依赖。
2. **若必须硬编码符号名**：确保对应的后端会为这些符号生成 `__attribute__((used))` 或等价的保留指令。
3. **microapp 开发者无需额外操作**：当前 Uya C99 后端已自动处理，但如果你在宿主 C 代码中手写 `__asm__` 并混合 `--gc-sections`，需自行留意此问题。

---

## 9. 总结

### 8.1 核心原则

1. **最小权限** - 只请求必要的资源
2. **显式声明** - 所有输入输出必须声明
3. **安全第一** - 编译期验证所有问题
4. **性能优化** - 批量操作，减少开销
5. **可移植性** - 平台检测，抽象层

### 8.2 检查清单

**使用前检查**：
- [ ] 是否真的需要 @asm？
- [ ] 是否有更简单的替代方案？
- [ ] 是否考虑了可移植性？
- [ ] 是否考虑了维护性？

**实现时检查**：
- [ ] 类型是否匹配？
- [ ] 边界检查是否完整？
- [ ] clobbers 声明是否准确？
- [ ] 内存安全是否保证？

**测试时检查**：
- [ ] 单元测试是否完整？
- [ ] 边界情况是否测试？
- [ ] 并发场景是否测试？
- [ ] 性能是否达标？

---

**版本**: v1.0.0  
**最后更新**: 2026-02-24  
**维护者**: Uya 开发团队
