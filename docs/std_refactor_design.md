# 标准库重构设计文档 v0.6.0

## 概述

本设计文档描述 Uya 标准库的重构计划，核心目标是：

1. **std 使用 Uya 现代特性**：`!T`, `interface`, 泛型, `union`, `mc`
2. **libc 是 std 的薄封装**：保持 C99 ABI 兼容，内部调用 std
3. **分层架构**：libc → std → syscall

## 设计原则

### 1. std 层：Uya 原生风格

使用 Uya 的类型安全特性：

```uya
// 错误处理：使用 !T（错误联合类型）
// !T = { error_id: u32, value: T }
// error_id == 0 表示成功，非0表示错误
fn parse_int(s: &const byte) !i32 {
    // 成功返回值，失败返回 error.ParseError
}

// 可选值：Option<T> 表示"有值或无值"（非错误语义）
// 用于查找、可选参数、可能缺失的数据
union Option<T> {
    some: T,
    none
}

// 接口抽象：使用 interface 定义行为
interface Writer {
    fn write(self: &Self, data: &[u8]) !usize;
    fn flush(self: &Self) !void;
}

// 泛型容器：类型安全的集合
struct Vec<T> {
    data: &T,
    len: usize,
    cap: usize,
}
```

**错误处理设计原则**：

| 类型 | 语义 | 用途 | 示例 |
|------|------|------|------|
| `!T` | 成功/失败 | 可能失败的操作 | `fn open(path) !File` |
| `Option<T>` | 有值/无值 | 查找、可选数据 | `fn find(arr, val) Option<usize>` |
| `Error` | 错误上下文 | 携带额外错误信息 | 用于需要详细错误信息的场景 |

> **设计决策**：不引入 `Result<T, E>`。`!T` 已提供灵活的错误处理（支持任意 `error.ErrorName`），`Result<T, E>` 会造成概念重叠。

### 错误处理模式

Uya 提供两种错误处理方式：`try` 传播、`catch` 捕获。

#### 1. `try` 错误传播

```uya
// 错误自动向上传播，当前函数立即返回错误
fn read_config(path: &const byte) !Config {
    const file: File = try File.open(path);  // 失败时返回 error
    const content: &[u8] = try file.read_all();  // 失败时返回 error
    return try parse_config(content);
}

// 溢出检查（自动检测算术溢出）
fn safe_add(a: i32, b: i32) !i32 {
    return try a + b;  // 溢出时返回 error.Overflow
}
```

#### 2. `catch` 错误捕获

```uya
// 方式 1：提供默认值
const value: i32 = parse_int(input) catch 0;

// 方式 2：错误变量绑定
const result: File = File.open(path) catch |err| {
    if err == error.FileNotFound {
        @print("文件不存在\n");
    }
    return error.ConfigError;  // 转换错误类型
};

// 方式 3：复杂错误处理
const data: &[u8] = fetch_data() catch |err| {
    log_error("获取数据失败", err);
    return error.NetworkError;
};
```

#### 推荐使用场景

| 场景 | 推荐方式 | 原因 |
|------|----------|------|
| 错误直接向上传播 | `try` | 简洁，无额外处理 |
| 需要默认值 | `catch default` | 一行代码处理 |
| 需要转换错误类型 | `catch \|err\| { ... }` | 灵活处理 |
| 需要日志/复杂处理 | `catch \|err\| { ... }` | 完全控制 |

### 2. libc 层：C99 兼容

薄封装，保持 C 签名：

```uya
// C 签名，内部调用 std 实现
export extern fn strlen(s: *const byte) usize {
    return std.strlen(s as &const byte);
}

export extern fn fopen(path: *const byte, mode: *const byte) *FILE {
    // 转换并调用 std.io.File.open
}
```

## 架构设计

```
lib/
├── std/                          # Uya 风格标准库
│   ├── core/                     # 核心类型（Sprint 6）
│   │   ├── error.uya             # 错误类型（携带上下文）
│   │   ├── option.uya            # Option<T> 可选值
│   │   └── traits.uya            # Clone, Eq, Ord, Hash, Display
│   │
│   ├── io/                       # I/O 抽象（Sprint 7）
│   │   ├── writer.uya            # interface Writer
│   │   ├── reader.uya            # interface Reader
│   │   └── file.uya              # struct File : Writer, Reader
│   │
│   ├── string/                   # 字符串操作（Sprint 8）
│   │   └── string.uya            # 安全字符串函数
│   │
│   ├── mem/                      # 内存操作（Sprint 6）
│   │   ├── mem.uya               # copy, set, cmp
│   │   ├── allocator.uya         # IAllocator 接口
│   │   ├── heap.uya              # HeapAllocator
│   │   ├── arena.uya             # ArenaAllocator
│   │   └── fixed_buf.uya         # FixedBufferAllocator
│   │
│   ├── collections/              # 泛型容器（Sprint 9）
│   │   ├── vec.uya               # Vec<T>
│   │   └── string_buf.uya        # StringBuf
│   │
│   ├── syscall/                  # 系统调用
│   │   └── linux.uya             # Linux syscall 封装
│   │
│   ├── fmt/                      # 格式化
│   │   └── fmt.uya               # format<T: Display>
│   │
│   └── runtime/                  # 运行时
│       └── runtime.uya           # panic, entry
│
└── libc/                         # C 兼容层（Sprint 10）
    ├── syscall.uya               # syscall 封装
    ├── string.uya                # strlen, strcmp, strcpy...
    ├── stdio.uya                 # printf, fopen, fclose...
    ├── stdlib.uya                # malloc, free, atoi...
    ├── mem.uya                   # memcpy, memset...
    └── unistd.uya                # read, write, close...
```

## Sprint 6: std.core 核心类型

### 6.1 std.core.error

**设计目的**：`!T` 只携带 `error_id`（32位），`Error` 类型用于需要额外错误上下文的场景。

```uya
// 错误类型定义 - 携带丰富错误信息
union Error {
    none,                        // 无错误
    message: *byte,             // 错误消息（FFI 指针）
    code: i32,                  // 应用错误码
    system: i32                 // 系统错误码（errno）
}

// 错误函数
export fn error_none() Error;
export fn error_message(msg: *byte) Error;
export fn error_code(code: i32) Error;
export fn error_from_errno(errno: i32) Error;
export fn error_to_string(e: &Error) &[i8];
export fn error_is_none(e: &Error) bool;
```

**使用场景**：
```uya
// 简单错误：直接使用 !T 和 error.ErrorName
fn divide(a: i32, b: i32) !i32 {
    if b == 0 { return error.DivisionByZero; }
    return a / b;
}

// 使用 try 传播错误
fn calculate(x: i32, y: i32) !i32 {
    const a: i32 = try divide(x, y);  // 错误自动传播
    const b: i32 = try divide(a, 2);  // 错误自动传播
    return b;
}

// 使用 catch 处理错误
fn safe_divide(a: i32, b: i32) i32 {
    return divide(a, b) catch 0;  // 失败返回默认值
}

// 使用 catch 处理错误并继续执行
fn check_divide(a: i32, b: i32) void {
    const result: i32 = divide(a, b) catch {
        @print("除法失败\n");
        return;
    };
    @print("结果: ");
    @println(result);
}
```

### 6.2 std.core.option

**设计目的**：表示"有值或无值"，**非错误语义**。用于查找、可选参数等场景。

```uya
// Option<T> - 可选值
union Option<T> {
    some: T,
    none
}

// 方法
fn option_some<T>(value: T) Option<T>;
fn option_none<T>() Option<T>;
fn option_is_some<T>(self: &Option<T>) bool;
fn option_is_none<T>(self: &Option<T>) bool;
fn option_unwrap<T>(self: &Option<T>) !T;      // none 时返回错误
fn option_unwrap_or<T>(self: &Option<T>, default: T) T;
fn option_map<T, U>(self: &Option<T>, f: fn(T) U) Option<U>;
fn option_and_then<T, U>(self: &Option<T>, f: fn(T) Option<U>) Option<U>;
```

**使用示例**：
```uya
// 查找元素：找不到不是错误，只是"无值"
fn find(arr: &[i32], val: i32) Option<usize> {
    var i: usize = 0;
    while i < arr.len {
        if arr[i] == val { return option_some(i); }
        i += 1;
    }
    return option_none();
}

// 模式匹配处理 Option
fn process_option(arr: &[i32]) void {
    const idx: Option<usize> = find(arr, 42);
    match idx {
        some: i => {
            @print("找到，索引: ");
            @println(i);
        },
        none => {
            @print("未找到\n");
        }
    }
}

// unwrap_or 提供默认值
const idx: usize = option_unwrap_or(&find(arr, 42), 0);

// unwrap 配合 try 使用（失败返回 error）
fn must_find(arr: &[i32], val: i32) !usize {
    const idx: Option<usize> = find(arr, val);
    return try option_unwrap(&idx);  // none 时返回 error
}
```

### 6.3 std.core.traits

```uya
// Clone - 克隆接口
interface Clone {
    fn clone(self: &Self) Self;
}

// Eq - 相等比较
interface Eq {
    fn eq(self: &Self, other: &Self) bool;
    // ne 可通过 !eq 实现，无需单独定义
}

// Ord - 有序比较
interface Ord {
    fn cmp(self: &Self, other: &Self) i32;  // -1, 0, 1
    fn lt(self: &Self, other: &Self) bool;
    fn le(self: &Self, other: &Self) bool;
    fn gt(self: &Self, other: &Self) bool;
    fn ge(self: &Self, other: &Self) bool;
}

// Hash - 哈希
interface Hash {
    fn hash(self: &Self) u64;
}

// Display - 格式化显示
interface Display {
    fn fmt(self: &Self, writer: &Writer) !void;
}
```

> **注意**：Uya 接口当前不支持默认实现，所有方法必须由实现类型显式定义。

### 6.5 std.mem.allocator - Zig 风格 IAllocator ⭐⭐⭐⭐⭐

**设计理念**：借鉴 Zig 的分配器设计，提供可插拔、类型安全的内存分配接口。

**核心原则**：
1. **显式传递分配器**：避免全局状态，分配器作为参数传递
2. **错误联合返回**：使用 `!T` 处理分配失败
3. **多种分配器实现**：支持不同场景（堆、Arena、固定缓冲区）
4. **零抽象开销**：接口编译为直接调用，无虚表开销

```uya
// std/mem/allocator.uya

/// 分配错误类型
union AllocError {
    none,
    out_of_memory,           // 内存不足
    invalid_alignment,       // 无效对齐要求
    invalid_pointer,         // 无效指针（释放/调整大小时）
}

/// Zig 风格分配器接口
interface IAllocator {
    /// 分配 size 字节内存，失败返回错误
    fn alloc(self: &Self, size: usize) !&void;
    
    /// 分配并清零
    fn alloc_zeroed(self: &Self, size: usize) !&void;
    
    /// 释放内存
    fn free(self: &Self, ptr: &void) void;
    
    /// 调整内存大小（可选实现）
    fn resize(self: &Self, ptr: &void, old_size: usize, new_size: usize) !&void;
    
    /// 创建单个对象
    fn create<T>(self: &Self) !&T;
    
    /// 销毁单个对象
    fn destroy<T>(self: &Self, ptr: &T) void;
}
```

### 6.6 std.mem.heap - HeapAllocator

```uya
// std/mem/heap.uya

/// 全局堆分配器 - 基于 mmap/munmap 系统调用
struct HeapAllocator : IAllocator {
    fn alloc(self: &Self, size: usize) !&void {
        // 调用 syscall.mmap
        const ptr: !&void = syscall.mmap(
            null,                           // addr: 让内核选择
            size + @size_of(usize),         // 额外存储大小
            syscall.PROT_READ | syscall.PROT_WRITE,
            syscall.MAP_PRIVATE | syscall.MAP_ANONYMOUS,
            -1,                             // fd
            0                               // offset
        );

        // 使用 catch 转换错误类型
        const p: &void = syscall.mmap(...) catch { return error.OutOfMemory; };

        // 在块头存储大小（用于 free）
        const header: &usize = ptr as &usize;
        *header = size + @size_of(usize);
        return (ptr as &usize + 1) as &void;  // 跳过头部
    }
    
    fn free(self: &Self, ptr: &void) void {
        // 从头部获取实际起始地址和大小
        const header: &usize = (ptr as &usize - 1) as &usize;
        const actual_size: usize = *header;
        syscall.munmap(header as &void, actual_size);
    }
    
    fn create<T>(self: &Self) !&T {
        const ptr: &void = try self.alloc(@size_of(T));
        return ptr as &T;
    }
    
    fn destroy<T>(self: &Self, ptr: &T) void {
        self.free(ptr as &void);
    }
}

/// 全局堆分配器实例
const heap_allocator: HeapAllocator = HeapAllocator{};

/// 便捷函数（使用全局堆分配器）
export fn alloc(size: usize) !&void { return heap_allocator.alloc(size); }
export fn alloc_zeroed(size: usize) !&void { return heap_allocator.alloc_zeroed(size); }
export fn free(ptr: &void) void { heap_allocator.free(ptr); }
export fn create<T>() !&T { return heap_allocator.create<T>(); }
export fn destroy<T>(ptr: &T) void { heap_allocator.destroy<T>(ptr); }
```

### 6.7 std.mem.arena - ArenaAllocator

```uya
// std/mem/arena.uya

/// Arena 分配器 - 线性分配，批量释放
/// 适用于：临时计算、解析器、编译器中间数据
struct ArenaAllocator : IAllocator {
    buffer: &[u8],
    offset: usize,
    
    fn init(buf: &[u8]) ArenaAllocator {
        return ArenaAllocator{ buffer: buf, offset: 0 };
    }
    
    fn alloc(self: &Self, size: usize) !&void {
        // 对齐到 8 字节
        const aligned_size: usize = (size + 7) & ~7;
        
        if self.offset + aligned_size > self.buffer.len {
            return AllocError.out_of_memory;
        }
        
        const ptr: &void = &self.buffer[self.offset] as &void;
        self.offset += aligned_size;
        return ptr;
    }
    
    fn alloc_zeroed(self: &Self, size: usize) !&void {
        const ptr: &void = try self.alloc(size);
        std.mem.set(ptr as &byte, 0, size);
        return ptr;
    }
    
    fn free(self: &Self, ptr: &void) void {
        // Arena 不支持单独释放 - 使用 reset 批量释放
    }
    
    /// 重置 arena（释放所有分配）
    fn reset(self: &Self) void {
        self.offset = 0;
    }
    
    /// 获取已使用字节数
    fn used(self: &Self) usize {
        return self.offset;
    }
    
    /// 获取剩余字节数
    fn remaining(self: &Self) usize {
        return self.buffer.len - self.offset;
    }
}
```

### 6.8 std.mem.fixed_buf - FixedBufferAllocator

```uya
// std/mem/fixed_buf.uya

/// 固定缓冲区分配器 - 栈上分配，零堆开销
/// 适用于：嵌入式系统、实时系统、避免动态分配
struct FixedBufferAllocator : IAllocator {
    buffer: &[u8],
    offset: usize,
    
    fn init(buf: &[u8]) FixedBufferAllocator {
        return FixedBufferAllocator{ buffer: buf, offset: 0 };
    }
    
    fn alloc(self: &Self, size: usize) !&void {
        const aligned_size: usize = (size + 7) & ~7;
        
        if self.offset + aligned_size > self.buffer.len {
            return AllocError.out_of_memory;
        }
        
        const ptr: &void = &self.buffer[self.offset] as &void;
        self.offset += aligned_size;
        return ptr;
    }
    
    fn free(self: &Self, ptr: &void) void {
        // 固定缓冲区不支持单独释放
    }
    
    /// 重置缓冲区
    fn reset(self: &Self) void {
        self.offset = 0;
    }
}

/// 栈上分配示例
fn stack_example() void {
    var buf: [4096]u8;
    var arena: ArenaAllocator = ArenaAllocator.init(buf[0..]);
    
    // 使用 arena 分配临时数据
    const temp: !&byte = arena.alloc(100);
    
    // ... 使用 temp ...
    
    // 函数返回时 buf 在栈上自动释放，无需手动 free
}
```

### 6.9 std.mem.logging - LoggingAllocator

```uya
// std/mem/logging.uya

/// 日志分配器 - 包装器，记录所有分配操作（调试用）
struct LoggingAllocator : IAllocator {
    child: &IAllocator,
    name: &const byte,
    alloc_count: usize,
    free_count: usize,
    total_bytes: usize,
    
    fn init(child: &IAllocator, name: &const byte) LoggingAllocator {
        return LoggingAllocator{
            child: child,
            name: name,
            alloc_count: 0,
            free_count: 0,
            total_bytes: 0
        };
    }
    
    fn alloc(self: &Self, size: usize) !&void {
        @print("[");
        @print(self.name);
        @print("] alloc ");
        @println(size);

        const ptr: &void = self.child.alloc(size) catch |err| {
            return err;  // 传播错误
        };
        self.alloc_count += 1;
        self.total_bytes += size;
        return ptr;
    }
    
    fn free(self: &Self, ptr: &void) void {
        @print("[");
        @print(self.name);
        @print("] free\n");
        
        self.free_count += 1;
        self.child.free(ptr);
    }
    
    /// 打印统计信息
    fn print_stats(self: &Self) void {
        @print("[");
        @print(self.name);
        @print("] stats: allocs=");
        @print(self.alloc_count);
        @print(" frees=");
        @print(self.free_count);
        @print(" bytes=");
        @println(self.total_bytes);
    }
}
```

### 6.10 分配器使用模式

```uya
// 1. 显式传递分配器（推荐）- 使用 try 传播错误
fn Vec<T>.with_capacity(alloc: &IAllocator, cap: usize) !Vec<T> {
    const data: &T = try alloc.alloc(cap * @size_of(T)) as &T;
    return Vec<T>{
        data: data,
        len: 0,
        cap: cap,
        allocator: alloc
    };
}

// 2. 使用 arena 进行临时分配 - 使用 try 传播
fn parse_expression(arena: &ArenaAllocator, tokens: &[Token]) !Expr {
    // 所有临时数据都在 arena 上分配
    const temp: &byte = try arena.alloc(1024);
    // ...
    // 不需要手动释放，调用者会 reset arena
}

// 3. 混合使用多个分配器 - try/catch 组合
fn process_file(path: &const byte) !void {
    // 临时数据用 arena
    var arena_buf: [65536]u8;
    var arena: ArenaAllocator = ArenaAllocator.init(arena_buf[0..]);

    // 长期数据用堆 - try 传播错误
    const output: &OutputData = try heap_allocator.create<OutputData>();

    // 处理...
    parse_with_arena(&arena, path);

    // arena 自动释放，output 需要手动释放
    heap_allocator.destroy(output);
}

// 4. 嵌入式系统（无堆）- catch 提供回退
fn embedded_main() void {
    // 只使用固定缓冲区，无动态分配
    var buf: [8192]u8;
    var alloc: FixedBufferAllocator = FixedBufferAllocator.init(buf[0..]);

    const data: &Config = alloc.create<Config>() catch {
        @print("内存不足，使用默认配置\n");
        return;
    };
    // ...
}

// 5. 带错误转换的模式
fn load_config(alloc: &IAllocator, path: &const byte) !Config {
    const data: &u8 = alloc.alloc(CONFIG_SIZE) catch |err| {
        // 转换错误类型
        @print("分配内存失败\n");
        return error.ConfigLoadFailed;
    };
    // ...
}
```

## Sprint 7: std.io I/O 抽象

### 7.1 std.io.writer

```uya
// Writer 接口
interface Writer {
    fn write(self: &Self, data: &[u8]) !usize;
    fn write_str(self: &Self, s: &const byte) !usize;
    fn flush(self: &Self) !void;
}

// 辅助函数
export fn write_all(w: &Writer, data: &[u8]) !void;
export fn write_byte(w: &Writer, b: u8) !void;
export fn write_u8(w: &Writer, v: u8) !void;
export fn write_u16_le(w: &Writer, v: u16) !void;
export fn write_u32_le(w: &Writer, v: u32) !void;
export fn write_u64_le(w: &Writer, v: u64) !void;
```

### 7.2 std.io.reader

```uya
// Reader 接口
interface Reader {
    fn read(self: &Self, buf: &[u8]) !usize;
    fn read_exact(self: &Self, buf: &[u8]) !void;
}

// 辅助函数
export fn read_to_end(r: &Reader, buf: &Vec<u8>) !usize;
export fn read_line(r: &Reader, line: &[u8]) !usize;
export fn read_u8(r: &Reader) !u8;
export fn read_u16_le(r: &Reader) !u16;
export fn read_u32_le(r: &Reader) !u32;
```

### 7.3 std.io.file

```uya
// 文件结构体
struct File : Writer, Reader {
    fd: i32,
    owns_fd: bool,              // 是否拥有 fd（close 时需要）

    // 构造函数
    fn open(path: &const byte, flags: i32, mode: i32) !File;
    fn create(path: &const byte, mode: i32) !File;

    // Writer 接口
    fn write(self: &Self, data: &[u8]) !usize;
    fn write_str(self: &Self, s: &const byte) !usize;
    fn flush(self: &Self) !void;

    // Reader 接口
    fn read(self: &Self, buf: &[u8]) !usize;
    fn read_exact(self: &Self, buf: &[u8]) !void;

    // 其他操作
    fn seek(self: &Self, offset: i64, whence: i32) !i64;
    fn close(self: &Self) !void;
    fn drop(self: &Self);       // RAII: 自动关闭
}

// 标准流
export const stdin: File = File{ fd: 0, owns_fd: false };
export const stdout: File = File{ fd: 1, owns_fd: false };
export const stderr: File = File{ fd: 2, owns_fd: false };
```

**I/O 错误处理示例**：
```uya
// 使用 try 传播错误
fn read_file_content(path: &const byte) !StringBuf {
    var file: File = try File.open(path, O_RDONLY, 0);
    defer file.close();

    var buf: StringBuf = try StringBuf.with_capacity(4096);
    var temp: [1024]u8;

    loop {
        const n: usize = try file.read(temp[0..]);
        if n == 0 { break; }  // EOF
        try buf.push_slice(temp[0..n]);
    }

    return buf;
}

// 使用 catch 处理错误
fn safe_write(file: &File, data: &[u8]) bool {
    const n: usize = file.write(data) catch {
        @print("写入失败\n");
        return false;
    };
    return n == data.len;
}

// 错误类型匹配
fn handle_file_error(path: &const byte) void {
    const file: File = File.open(path, O_RDONLY, 0) catch {
        @print("无法打开文件: ");
        @println(path);
        return;
    };
    file.close();
}
```

## Sprint 8: std.string 安全字符串操作

```uya
// 基本字符串函数（无错误返回）
export fn strlen(s: &const byte) usize;
export fn strcmp(s1: &const byte, s2: &const byte) i32;
export fn strncmp(s1: &const byte, s2: &const byte, n: usize) i32;

// 安全复制（带边界检查）
export fn copy_safe(dst: &byte, dst_len: usize, src: &const byte) !void;
export fn cat_safe(dst: &byte, dst_len: usize, src: &const byte) !void;

// 解析函数（返回 !T）
export fn parse_i8(s: &const byte) !i8;
export fn parse_i16(s: &const byte) !i16;
export fn parse_i32(s: &const byte) !i32;
export fn parse_i64(s: &const byte) !i64;
export fn parse_u8(s: &const byte) !u8;
export fn parse_u16(s: &const byte) !u16;
export fn parse_u32(s: &const byte) !u32;
export fn parse_u64(s: &const byte) !u64;
export fn parse_f32(s: &const byte) !f32;
export fn parse_f64(s: &const byte) !f64;

// 字符串操作（返回 Option）
export fn find(s: &const byte, c: byte) Option<usize>;
export fn rfind(s: &const byte, c: byte) Option<usize>;
export fn split_first(s: &const byte, delim: byte) Option<(&const byte, &const byte)>;
```

**字符串错误处理示例**：
```uya
// 使用 try 传播解析错误
fn parse_port(s: &const byte) !u16 {
    const port: u16 = try parse_u16(s);
    if port == 0 { return error.InvalidPort; }
    return port;
}

// 使用 catch 提供默认值
fn parse_timeout(s: &const byte) u32 {
    return parse_u32(s) catch 30;  // 默认 30 秒
}

// 使用 Option 处理查找结果
fn get_extension(filename: &const byte) Option<&const byte> {
    const dot_pos: Option<usize> = rfind(filename, '.');
    if option_is_none(&dot_pos) { return option_none(); }

    const idx: usize = option_unwrap(&dot_pos);
    return option_some(&filename[idx + 1]);
}
```

// 大小写转换
export fn to_lower_inplace(s: &byte) void;
export fn to_upper_inplace(s: &byte) void;

// 检查函数
export fn starts_with(s: &const byte, prefix: &const byte) bool;
export fn ends_with(s: &const byte, suffix: &const byte) bool;
export fn is_whitespace(s: &const byte) bool;
export fn is_digit(s: &const byte) bool;
```

## Sprint 9: std.collections 泛型容器

### 9.1 std.collections.vec

```uya
// 动态数组
struct Vec<T> {
    data: &T,
    len: usize,
    cap: usize,
    
    // 构造函数
    fn new() Vec<T>;
    fn with_capacity(cap: usize) !Vec<T>;
    fn from_slice(slice: &[T]) !Vec<T> where T: Clone;
    
    // 访问
    fn len(self: &Self) usize;
    fn is_empty(self: &Self) bool;
    fn capacity(self: &Self) usize;
    fn get(self: &Self, i: usize) !&T;           // 边界检查
    fn get_unchecked(self: &Self, i: usize) &T;  // 无检查
    fn first(self: &Self) Option<&T>;
    fn last(self: &Self) Option<&T>;
    fn as_slice(self: &Self) &[T];
    
    // 修改
    fn push(self: &Self, value: T) !void;
    fn pop(self: &Self) Option<T>;
    fn insert(self: &Self, i: usize, value: T) !void;
    fn remove(self: &Self, i: usize) !T;
    fn clear(self: &Self) void;
    fn truncate(self: &Self, new_len: usize) void;
    fn reserve(self: &Self, additional: usize) !void;
    
    // 迭代
    fn iter(self: &Self) Iterator<T>;
    
    // RAII
    fn drop(self: &Self) void;
}
```

### 9.2 std.collections.string_buf

```uya
// 字符串缓冲区
struct StringBuf {
    buf: Vec<u8>,
    
    // 构造函数
    fn new() StringBuf;
    fn with_capacity(cap: usize) !StringBuf;
    fn from(s: &const byte) !StringBuf;
    
    // 访问
    fn len(self: &Self) usize;
    fn is_empty(self: &Self) bool;
    fn as_str(self: &Self) &[i8];
    fn as_bytes(self: &Self) &[u8];
    
    // 修改
    fn push(self: &Self, c: byte) !void;
    fn push_str(self: &Self, s: &const byte) !void;
    fn push_slice(self: &Self, s: &[u8]) !void;
    fn clear(self: &Self) void;
    fn truncate(self: &Self, new_len: usize) void;
    
    // 格式化
    fn format<T: Display>(self: &Self, value: T) !void;
    
    // RAII
    fn drop(self: &Self) void;
}
```

## Sprint 10: libc 薄封装

### 10.1 设计原则

libc 是 std 的薄封装层：

1. **保持 C 签名**：函数名、参数类型、返回值完全兼容 C99
2. **调用 std 实现**：不重复实现逻辑
3. **错误转换**：std 的 `!T` 转换为 C 的返回码/null
4. **安全增强**：添加边界检查、空指针防护

### 10.2 libc.string

```uya
use std.string;
use std.mem;

// strlen - 调用 std 实现
export extern fn strlen(s: *const byte) usize {
    return std.strlen(s as &const byte);
}

// strcmp - 调用 std 实现
export extern fn strcmp(s1: *const byte, s2: *const byte) i32 {
    return std.strcmp(s1 as &const byte, s2 as &const byte);
}

// strcpy - 安全增强
export extern fn strcpy(dst: *byte, src: *const byte) *byte {
    if dst == null || src == null { return dst; }
    const len: usize = std.strlen(src as &const byte);
    std.mem.copy(dst as &byte, src as &const byte, len + 1);
    return dst;
}

// strcat - 安全增强
export extern fn strcat(dst: *byte, src: *const byte) *byte {
    if dst == null || src == null { return dst; }
    const dst_len: usize = std.strlen(dst as &const byte);
    const src_len: usize = std.strlen(src as &const byte);
    std.mem.copy((dst as usize + dst_len) as &byte, src as &const byte, src_len + 1);
    return dst;
}
```

### 10.3 libc.stdio

```uya
use std.io;
use std.mem;

// FILE 类型定义（与 C 兼容）
struct FILE {
    fd: i32,
    flags: i32,
    buffer: &[u8],
    buf_len: usize,
}

// fopen - 调用 std.io.File.open
export extern fn fopen(path: *const byte, mode: *const byte) *FILE {
    if path == null || mode == null { return null; }

    const flags: i32 = parse_mode(mode as &const byte);
    const file: std.io.File = std.io.File.open(path as &const byte, flags, 0o644) catch {
        return null;
    };

    // 分配 FILE 结构
    const f: *FILE = std.mem.alloc(@size_of(FILE)) as *FILE;
    if f == null { return null; }

    f.fd = file.fd;
    f.flags = flags;
    f.buffer = null;
    f.buf_len = 0;

    return f;
}

// fclose - 调用 std.io.File.close
export extern fn fclose(fp: *FILE) i32 {
    if fp == null { return -1; }

    var f: std.io.File = std.io.File{ fd: fp.fd, owns_fd: true };
    f.close() catch {
        std.mem.free(fp as &void);
        return -1;
    };

    std.mem.free(fp as &void);
    return 0;
}

// fwrite - 调用 std.io.Writer.write
export extern fn fwrite(ptr: *const void, size: usize, nmemb: usize, fp: *FILE) usize {
    if ptr == null || fp == null { return 0; }
    const total: usize = size * nmemb;
    var f: std.io.File = std.io.File{ fd: fp.fd, owns_fd: false };
    const n: usize = f.write(ptr as &[u8], total) catch { return 0; };
    return n / size;
}
```

## 迁移计划

### 阶段 1：核心类型（Sprint 6）

1. 实现 `std.core.error`
2. 实现 `std.core.option`
3. 实现 `std.core.traits`

### 阶段 2：I/O 抽象（Sprint 7）

1. 定义 `interface Writer`
2. 定义 `interface Reader`
3. 重构 `std.io.File` 实现 Writer/Reader

### 阶段 3：字符串操作（Sprint 8）

1. 重构 `std.string` 使用 `!T`
2. 添加安全版本函数
3. 添加解析函数

### 阶段 4：泛型容器（Sprint 9）

1. 实现 `Vec<T>`
2. 实现 `StringBuf`
3. 添加迭代器支持

### 阶段 5：libc 封装（Sprint 10）

1. 重构 `libc.string` 调用 std
2. 重构 `libc.stdio` 调用 std
3. 重构 `libc.stdlib` 调用 std

## 验证标准

每个 Sprint 完成后需验证：

1. **编译通过**：`make check` 通过
2. **测试覆盖**：新增测试用例全部通过
3. **自举验证**：编译器能使用新 std 编译自身
4. **libc 兼容**：`--outlibc` 生成的库能与 C 代码链接
