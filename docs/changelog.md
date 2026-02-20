# Uya 语言版本变更日志

本文档记录 Uya 语言的所有版本变更历史。

---

## 0.6x 版本变更（规划中）

**发布日期：** 待定

### v0.6.0 - 标准库重构（规划中）

本版本将重构标准库架构，使用 Uya 现代特性。

#### 主要变更

1. **std 使用现代特性**
   - `!T` 错误处理替代裸指针返回
   - `union Option<T>` 类型安全
   - `interface` 定义抽象（Writer, Reader, Clone, Eq）
   - 泛型容器（Vec<T>, StringBuf）

2. **libc 薄封装**
   - 保持 C99 标准库签名兼容
   - 内部调用 std 实现，零重复代码
   - 更安全的 API（边界检查、空指针防护）

3. **分层架构**
   ```
   libc/  →  std/  →  syscall/
   (C ABI)  (Uya)    (底层)
   ```

#### Sprint 规划

| Sprint | 内容 | 说明 |
|--------|------|------|
| 6 | std.core | Error, Option<T>, traits |
| 7 | std.io | Writer/Reader 接口，File 实现 |
| 8 | std.string | 安全字符串操作（!T） |
| 9 | std.collections | Vec<T>, StringBuf 泛型容器 |
| 10 | libc 薄封装 | 调用 std，保持 C ABI |

#### 详细设计

参见 [`docs/std_refactor_design.md`](./std_refactor_design.md)

---

## 0.55 版本变更（相对于 0.50）

**发布日期：** 2026年2月19日

### v0.5.9 - --outlibc 生成独立 libc

本版本实现 `--outlibc` 功能，可生成零外部依赖的 libuya.c 和 libuya.h。

#### 主要变更

1. **--outlibc 命令**
   - `uya --outlibc <目录>` 生成独立 C 库
   - 生成 `libuya.h`（头文件）：类型定义、函数声明
   - 生成 `libuya.c`（实现文件）：所有函数实现

2. **零依赖类型定义**
   - int8_t, uint8_t, int16_t, uint16_t, int32_t, uint32_t
   - int64_t, uint64_t, size_t, ssize_t

3. **包含的模块**
   - syscall: uya_syscall0-6（x86-64 内联汇编）
   - string: strlen, strcmp, strncmp, strcpy, strncpy, strcat, strchr, strrchr
   - mem: memcpy, memmove, memset, memcmp, memchr
   - stdio: putchar, puts
   - stdlib: exit, atoi, atol
   - unistd: write, read, close

#### 使用方法

```bash
# 生成 libuya 库
uya --outlibc /tmp/libuya

# 编译库
gcc -c libuya.c -o libuya.o

# freestanding 模式使用
gcc -nostdlib -ffreestanding your_program.c libuya.o -o your_program -lgcc
```

#### 测试状态

- 自举验证：✓ 通过
- 单元测试：399/399 通过
- Freestanding 测试：✓ 通过

### v0.5.8 - 编译器零依赖构建 & 约束证明增强

本版本实现编译器完全静态链接（零外部依赖），并增强约束证明系统。

#### 主要变更

1. **编译器 -nostdlib 构建（Sprint 4）**
   - 编译器现在可以完全静态链接，零外部依赖
   - `ldd bin/uya`: 不是动态可执行文件
   - `nm bin/uya | grep ' U '`: 无未定义符号
   - 使用 C 内联汇编实现 `_start` 启动代码
   - 清理编译器中的 C 标准库依赖，全部使用纯 Uya 实现的标准库

2. **约束证明系统增强**
   - **交换律支持**: `10 > i` 等价于 `i < 10`
   - **线性表达式支持**: `i + offset < n` 转换为 `i < n - offset`
   - **const 变量识别**: `if i < N { }` 其中 N 是 const 变量
   - **错误去重**: 同一 (变量名, 数组大小) 只报告一次安全证明错误

3. **Makefile 更新**
   - `make uya` 默认静态链接，零外部依赖
   - 新增 `make uya-std` 目标（标准库链接，用于调试）

#### 测试状态

- 自举验证：✓ 通过
- 单元测试：399/399 通过
- 新增 5 个约束证明测试用例

### v0.5.7 - 调试打印内置函数

本版本新增 `@print` 和 `@println` 内置函数，用于调试输出。

#### 主要变更

1. **新增 @print/@println 内置函数**
   - `@print(expr)` - 打印表达式值（不换行）
   - `@println(expr)` - 打印表达式值并换行
   - 返回 `i32` 类型（printf 返回值）

2. **支持的类型**
   - 整数类型：`i8`、`i16`、`i32`、`i64`、`u8`、`u16`、`u32`、`u64`、`usize`
   - 浮点类型：`f32`、`f64`
   - 布尔类型：`bool`
   - 字符串：`&[i8]`、`*i8`、`[i8: N]`
   - 字符串插值：`"text${expr}text"`

3. **插值格式支持**
   - 十六进制：`${num:#x}`、`${num:#X}`
   - 八进制：`${num:#o}`
   - 浮点精度：`${f:.2f}`、`${f:.4f}`

#### 使用示例

```uya
fn main() i32 {
    // 基础用法
    @println(42);              // 输出: 42
    @println("Hello");         // 输出: Hello
    @println(3.14);            // 输出: 3.14
    @println(true);            // 输出: 1

    // 字符串插值
    const name: &byte = "Uya";
    @println("Hello, ${name}!");  // 输出: Hello, Uya!

    // 格式化输出
    const x: i32 = 255;
    @println("hex = ${x:#x}");    // 输出: hex = ff

    return 0;
}
```

#### 测试状态

- 自举验证：✓ 通过
- 单元测试：399/399 通过

### v0.5.6 - 编译选项可配置化

本版本将硬编码的编译选项改为可通过环境变量配置。

#### 主要变更

1. **CFLAGS/LDFLAGS 环境变量支持**
   - 新增 `CFLAGS` 环境变量控制编译选项
   - 新增 `LDFLAGS` 环境变量控制链接选项
   - 默认使用调试模式：`-std=c99 -O0 -g -fno-builtin`

2. **Makefile 更新**
   - 所有编译命令使用 `$(CFLAGS)` 和 `$(LDFLAGS)`
   - `make release` 使用固定 `-O3 -DNDEBUG` 优化选项

3. **compile.sh 更新**
   - 支持从环境变量读取 `CFLAGS` 和 `LDFLAGS`
   - 所有 gcc 命令统一使用变量

#### 使用示例

```bash
# 默认调试模式构建
make from-c

# 使用自定义优化级别
CFLAGS='-std=c99 -O2' make uya

# 构建发布版本（自动 -O3 优化 + strip）
make release
```

### v0.5.5 - 代码规范化与编译优化

本版本进行了代码规范化工作，并优化了编译选项。

#### 主要变更

1. **代码规范化**
   - 将代码中的魔法数字替换为命名常量，提高代码可读性和可维护性
   - 新增常量：
     - `C99_MAX_ERROR_IDS: i32 = 256`
     - `C99_GENERIC_NAME_BUF_SIZE: i32 = 128`
     - `C99_MAX_INTERFACE_METHODS: i32 = 128`
     - `C99_TYPE_ARG_BUF_SIZE: i32 = 256`
     - `C99_TYPE_ARG_BUF_LIMIT: i32 = 250`
     - `C99_OUTPUT_FILENAME_BUF_SIZE: i32 = 100`
     - `C99_STRING_INTERP_BUF_SIZE: i32 = 2048`
     - `C99_STRING_INTERP_LIMIT: i32 = 2046`
     - `C99_SUFFIX_BUF_SIZE: i32 = 512`
     - `MAX_MONO_NAME_LEN: i32 = 256`
     - `MAX_MONO_NAME_LIMIT: i32 = 250`
     - `MAX_GENERIC_NAME_BUF: i32 = 512`

2. **编译选项优化**
   - 移除 `-fwrapv` 编译选项
   - 当前编译选项：`gcc -std=c99 -O3 -fno-builtin`

3. **Bug 修复**
   - 修复 `stmt.uya` 中变量赋值错误 (`j2 = j + 1` -> `j2 = j2 + 1`)

#### 测试状态

- 自举验证：✓ 通过
- 单元测试：393/393 通过
- Valgrind 验证：✓ 无内存泄漏，无内存错误

### v0.5.4 - 代码规范化

将代码中的魔法数字替换为命名常量，提高代码可读性和可维护性。

### v0.5.3-O3 - 编译选项统一

统一使用 `-O3 -fwrapv` 编译选项：
- 更新所有 gcc 命令使用一致的优化选项
- `-O3` 最高优化级别，`-fwrapv` 确保有符号整数溢出行为确定

### v0.5.2 - 编译问题排查

排查 `gcc -O2` 编译导致的段错误问题。

---

## 0.51 版本变更（相对于 0.50）

**发布日期：** 2026年2月17日

### 0.51 内存安全证明增强

本版本增强了内存安全证明系统的类型支持和表达式分析能力。

#### 新增功能

1. **无符号类型约束支持**
   - 新增 `is_unsigned_type()` 函数判断无符号整数类型
   - 自动为 `usize`, `u8`, `u16`, `u32`, `u64`, `byte` 类型变量添加 `>= 0` 约束
   - 类型转换表达式支持：`extract_linear_expr` 和 `checker_eval_const_expr` 现在支持 `as` 类型转换

2. **区间算术（Interval Arithmetic）**
   - 新增 `Interval` 结构表示值范围 `[min, max]`
   - 实现区间运算函数：`interval_add`, `interval_sub`, `interval_mul`, `interval_div`, `interval_shl`, `interval_shr`
   - 支持从约束系统推导变量区间：`get_var_interval()`
   - 表达式区间求值：`eval_expr_interval()`
   - 区间边界验证：`verify_expr_bounds_interval()`

3. **非线性表达式边界检查**
   - 支持乘法表达式边界检查：`arr[i * 2]`
   - 支持除法表达式边界检查：`arr[i / 2]`
   - 支持移位表达式边界检查：`arr[i << 1]`, `arr[i >> 1]`

#### 使用示例

```uya
// 非线性表达式边界检查
fn test_mul() void {
    var arr: [i32: 20] = [...];
    var i: i32 = 3;

    if i == 3 {
        arr[i * 2] = 42;  // i * 2 == 6 < 20, 安全
    }
}

// 移位运算边界检查
fn test_shift() void {
    var arr: [i32: 100] = [...];
    var i: i32 = 5;

    if i == 5 {
        arr[i << 1] = 42;  // i << 1 == 10 < 100, 安全
    }
}

// usize 类型自动约束
fn test_usize() void {
    var arr: [i32: 10] = [...];
    var i: usize = get_index();

    if i < 10 {
        arr[i] = 42;  // usize 天然满足 i >= 0，只需检查上界
    }
}
```

#### 新增测试

- `test_usize_constraints.uya`：usize 类型约束测试
- `test_nonlinear_bounds.uya`：非线性表达式边界检查测试

#### 技术细节

- Token 类型名称修正：`TOKEN_ASTERISK`（乘法）、`TOKEN_LSHIFT`（左移）、`TOKEN_RSHIFT`（右移）
- 区间乘法需要考虑所有极值组合
- 区间除法需要处理除以零情况

---

## 0.50 版本变更（相对于 0.48）

**发布日期：** 2026年2月17日（农历春节）

### 0.50 内存安全证明系统（里程碑版本）

本版本实现了完整的编译期内存安全证明系统，使 Uya 成为具有形式化安全保证的系统编程语言。

#### 核心功能

1. **常量折叠增强（阶段1）**
   - 整数溢出检测：编译期检测算术运算溢出
   - 数组越界检测：常量索引编译期验证
   - 除零检测：编译期检测除法和取模的除零错误

2. **路径敏感分析框架（阶段2）**
   - 约束系统：收集和传播变量约束（`>=`, `<=`, `<`, `>`, `==`, `!=`）
   - 作用域隔离：每个函数独立约束环境，避免污染
   - 指针非空状态跟踪：记录指针是否可能为空

3. **符号执行引擎（阶段3）**
   - 线性表达式提取：识别 `var + offset` 形式的索引表达式
   - 边界验证：自动验证 `while i < @len(arr)` 循环中的数组访问
   - `@len()` 编译时求值：支持 `@len()` 作为约束边界

4. **证明超时机制（阶段4）**
   - 步数限制：默认 1000 步上限，防止无限证明循环
   - 超时报告：清晰的超时错误消息和优化建议

5. **未初始化变量检测（阶段5）**
   - 初始化状态跟踪：检测未初始化变量的使用
   - 路径敏感分析：区分不同控制流路径的初始化状态

6. **空指针解引用检测（阶段6）**
   - 空值状态跟踪：记录指针初始化和检查状态
   - 解引用验证：验证指针解引用前是否通过空检查

7. **证明失败错误报告（阶段7）**
   - 详细错误消息：包含变量名、数组大小、安全建议
   - 修复建议：自动生成边界检查代码模板

#### 新增命令行参数

```bash
uya --safety-proof -c source.uya -o output.c
```

#### 使用示例

```uya
// 循环边界自动推断
fn sum(arr: [i32: 10]) i32 {
    var total: i32 = 0;
    var i: i32 = 0;
    while i < @len(arr) {  // 自动建立约束: i >= 0 && i < 10
        total = total + arr[i];  // 安全：约束已满足
        i = i + 1;
    }
    return total;
}

// 边界检查验证
fn process(arr: [i32: 10], i: i32) i32 {
    if i >= 0 && i < 10 {  // 边界检查
        return arr[i];
    }
    return -1;
}

// 空指针检查验证
fn deref(ptr: &i32) i32 {
    if ptr != null {  // 空检查
        return *ptr;
    }
    return 0;
}
```

#### 技术改进

- 函数间约束隔离，避免跨函数污染
- 循环变量递增后上界约束保留
- 支持 `i32` 类型约束（`usize` 需转换）

#### 修复的问题

| 问题 | 修复 |
|------|------|
| `while i < @len(arr)` 约束失效 | 支持 `@len()` 编译时求值 |
| 循环变量递增后上界丢失 | 循环内保留上界约束 |
| 函数间约束污染 | 函数开始时重置约束系统 |
| `usize` 类型不支持约束 | 文档说明使用 `i32` |

---

## 0.48 版本变更（相对于 0.47）

### 0.48 内存安全证明机制变更

- **证明失败处理变更**：
  - 之前：证明超时 → 自动插入运行时检查
  - 现在：证明失败 → 编译错误并给出修改建议
  - 更符合"坚如磐石"设计哲学：所有安全问题必须在编译期解决

- **编译器友好错误提示**：
  - 编译器无法完成证明时，报编译错误
  - 给出友好的修改建议（如：建议添加边界检查 `if i >= 0 && i < len { ... }`）
  - 不存在运行时才发现的安全问题

- **证明场景分类**（新增文档章节 14.5）：
  - **需要显式 `if` 判断**：变量数组索引、指针解引用、变量除法、变量运算溢出
  - **不需要显式 `if` 判断**：常量数组索引、循环变量范围推导、饱和/包装运算符、`try` 关键字

- **编译器优化规则**：
  - 证明条件为真 → 消除 `if`，直接执行 then 块
  - 证明条件为假 → 消除 then 块（死代码）
  - 无法证明 → 保留 `if` 运行时检查

- **约束系统实现**（memory-safety-proof 分支）：
  - 新增路径敏感分析框架
  - 支持从 if 条件提取约束（`i >= 0 && i < len`）
  - 支持约束验证数组边界
  - 嵌套 if 条件约束传播

---

## 0.47 版本变更（相对于 0.46）

### 0.47 泛型方法支持

- **泛型方法定义**：
  - 结构体/联合体方法支持独立的泛型参数：`fn method<T>(self: &Self) ReturnType`
  - 方法类型参数与结构体类型参数分离，形成二级查找
  - `Self` 类型在方法内自动替换为当前结构体的单态化类型

- **泛型方法调用**：
  - 方法调用支持显式类型参数：`obj.method<ConcreteType>()`
  - 单态化生成专门函数，零运行时开销
  - 示例：
    ```uya
    struct Container<T> {
        value: T,
        fn as_type<U>(self: &Self) U {
            return self.value as U;
        }
    }
    const c: Container<i32> = Container<i32>{ value: 42 };
    const v: i64 = c.as_type<i64>();  // 显式指定 U = i64
    ```

- **用途**：
  - 简化 Union 类型安全访问
  - 实现类型转换方法
  - 支持泛型工厂方法

---

## 0.45 版本变更（相对于 0.44）

### 0.45 extern 变量/常量支持

- **导入 C 全局变量**：
  - `extern const name: type;` - 导入只读 C 变量，生成 `extern const type name;`
  - `extern var name: type;` - 导入可变 C 变量，生成 `extern type name;`
  - 用途：访问 C 标准库全局变量（如 `errno`, `stdout`）

- **导出 Uya 全局变量给 C**：
  - `export const name: type = value;` - 导出只读常量，生成 `const type name = value;`
  - `export var name: type = value;` - 导出可变变量，生成 `type name = value;`
  - 用途：导出 Uya 全局状态给 C

- **`export extern "libc" fn` 语法**：
  - 支持用 Uya 实现替代 C 标准库函数
  - 生成裸函数名（无模块前缀），与 C 标准库链接

### 0.45 Scheme C 双入口架构

- **`export fn main()`**：生成 `main_main()`（应用入口）
- **`export extern fn main(argc, argv)`**：生成 `main()`（C 入口）
- **`fn main()`**：生成 `uya_main()`（旧架构兼容）
- 新增 `lib/std/runtime/entry/` 模块

---

## 0.44 版本变更（相对于 0.43）

### 0.44 @va_start / @va_end / @va_arg 内置函数

- **新增 `@va_start` / `@va_end` 内置函数**：
  - **语法**：`@va_start(ap, last)`、`@va_end(ap)`
  - **用途**：在可变参数函数内初始化/结束 va_list，用于将可变参数传递给 vprintf/vfprintf 等 C 函数
  - **约束**：仅可在形参含 `...` 的可变参数函数内使用；`@va_start` 与 `@va_end` 必须成对调用
  - **实现**：编译时展开为 C 的 `va_start`/`va_end` 宏
  - **设计目的**：支持纯 Uya 实现 libc.stdarg，无需依赖 extern "libc"

- **新增 `@va_arg` 内置函数**：
  - **语法**：`@va_arg(ap, Type)`，如 `@va_arg(ap, i32)`、`@va_arg(ap, *byte)`
  - **用途**：从 va_list 按类型提取下一个参数，用于遍历可变参数
  - **支持类型**：i32、i64、*byte、*void、f64 等
  - **实现**：编译时展开为 C 的 `va_arg(ap, type)` 宏
  - **设计目的**：支持纯 Uya 实现 vprintf 等格式化函数

---

## 0.43 版本变更（相对于 0.42）

### 0.43 extern "libc" 语法支持

- **新增字符字面量**（0.43 新增）：
  - **语法**：`'a'`、`'x'`、`'\n'`、`'\t'`
  - **类型**：`byte`（对应 C 的 char）
  - **支持转义序列**：`\n`（换行）、`\t`（制表）、`\\`（反斜杠）、`\'`（单引号）、`\0`（空字符）
  - **用途**：表示单个字符的 ASCII 码值

- **byte 类型映射简化**（0.43 变更）：
  - `byte` 现在直接对应 C 的 `char`（之前是 `uint8_t`）
  - 这简化了 FFI，使 `byte` 与 C 字符串完全兼容

- **新增 `extern "libc" fn` 语法**：
  - **语法**：`extern "libc" fn name(...) type;` 或 `export extern "libc" fn name(...) type { }`
  - **用途**：显式声明 C 标准库函数，或用 Uya 实现替代 C 标准库函数
  - **设计目的**：使 FFI 代码意图更清晰，支持无 libc 依赖的编译
  - **byte 映射**：在 `extern "libc"` 上下文中，`byte` 映射为 C 的 `char`

- **新增 `extern` 变量支持**：
  - **导入 C 全局变量**：
    - `extern const name: type;` - 导入只读 C 变量，生成 `extern const type name;`
    - `extern var name: type;` - 导入可变 C 变量，生成 `extern type name;`
  - **导出 Uya 变量给 C**：
    - `export const name: type = value;` - 导出只读常量，生成 `const type name = value;`
    - `export var name: type = value;` - 导出可变变量，生成 `type name = value;`
    - `export extern const name: type;` - 链接到 C 库定义，不生成代码
  - **用途**：访问 C 标准库全局变量（如 `errno`, `stdout`），或导出 Uya 全局状态给 C
  - **类型限制**：仅支持 C 兼容类型（基本类型、指针、extern struct）

- **编译器修改**：
  - AST 新增 `fn_decl_extern_lib_name` 字段
  - Parser 支持解析 `extern "libc" fn` 和 `extern const/var` 语法
  - Checker 允许 `extern "libc" fn` 使用 FFI 指针类型
  - Codegen 为 `extern "libc" fn` 生成裸函数名（无模块前缀）

---

## 0.42 版本变更（相对于 0.41）

### 0.42 只读指针类型和函数导出规则

- **引入只读指针类型 `&const T` 和 `*const T`**：
  - **语法**：新增 `&const T` (Uya 内部只读引用) 和 `*const T` (FFI 只读指针) 语法
  - **语义**：在类型系统中明确区分可变和只读指针，提升类型安全和 C 互操作性
  - **C 映射**：`&const T` 和 `*const T` 均映射为 `const T*`
  - **字符串字面量**：`"..."` 的类型现在为 `&const byte`
  - **FFI 函数签名**：C 标准库中接受 `const char *` 的函数，在 `extern` 声明中应使用 `*const byte`
  - **类型转换规则**：
    - `&T` 可以隐式转换为 `&const T`（放宽约束，安全）
    - `&const T` 不能隐式转换为 `&T`（收紧约束，需要显式转换）
    - `&T` 可以通过 `as *const T` 显式转换为 `*const T`
    - `&const T` 可以通过 `as *const T` 显式转换为 `*const T`
  - **设计目的**：减少 `-Wdiscarded-qualifiers` 警告，提升 C 互操作性，在语言层面表达只读指针语义

- **函数导出规则完善**：
  - **函数可见性规则**：
    - `fn foo() void` → `static void foo(void)`（内部函数，不导出，带 `uya_` 前缀）
    - `export fn foo() void` → `void module_prefix_foo(void)`（导出函数，供其他模块使用，带模块前缀）
      - 模块前缀规则：
        - **同目录文件合并规则**：同一目录下的所有 `.uya` 文件都属于同一个模块（模块路径由目录路径决定，不包含文件名）
        - `lib/std/io/file.uya` 和 `lib/std/io/stream.uya` 都属于 `std.io` 模块 → 模块前缀 `std_io`
        - `lib/std/io/file.uya` 中的 `export fn fopen(...)` → `std_io_fopen(...)`
        - `lib/std/io/stream.uya` 中的 `export fn fgetc(...)` → `std_io_fgetc(...)`
        - `lib/std/mem/mem.uya` 属于 `std.mem` 模块 → 模块前缀 `std_mem`
        - `lib/std/mem/mem.uya` 中的 `export fn mem_copy(...)` → `std_mem_mem_copy(...)`
        - 主模块 `main.uya` 中的 `export fn my_func(...)` → `main_my_func(...)`
    - `extern fn foo() void` → `extern void foo(void);`（外部 C 函数声明，裸名）
    - `extern fn foo() void { ... }` → `void foo(void) { ... }`（Uya 实现，以裸函数名导出）
    - `export extern fn foo() void;`（无函数体）→ 不生成代码，链接到 C 标准库（裸名）
    - `export extern fn foo() void { ... }`（有函数体）→ `void foo(void) { ... }`（Uya 实现，以裸函数名导出）
  - **设计目的**：
    - 明确函数可见性：内部函数使用 `static`，避免符号冲突
    - 模块前缀避免不同模块的同名函数冲突
    - extern 函数使用裸名，便于与 C 标准库互操作
    - 符合 C 语言惯例：只有导出的函数才在全局命名空间
    - 支持标准库实现：Uya 标准库中的函数可以以裸 C 名称导出

**参考文档**：
- [uya.md](uya.md) §0.42 - 规范变更说明
- [uya.md](uya.md) §2.1.1 - 指针类型说明
- [uya.md](uya.md) §5.1 - 函数定义语法
- [uya.md](uya.md) §5.2 - 外部 C 函数（FFI）

---

## 0.41 版本变更（相对于 0.40）

### 0.41 宏系统规范细化（新增第 25 章）

- **宏定义语法**：`mc ID(param_list) return_tag { statements }`
  - 参数类型：`expr`（表达式）、`stmt`（语句）、`type`（类型）、`pattern`（模式）
  - 返回标签：`expr`（表达式）、`stmt`（语句）、`struct`（结构体成员）、`type`（类型标识符）
- **编译时内置函数**：
  - `@mc_eval(expr)`：编译时求值
  - `@mc_type(expr)`：编译时类型反射，返回 `TypeInfo` 结构体
  - `@mc_ast(expr)`：代码转抽象语法树
  - `@mc_code(ast)`：抽象语法树转代码
  - `@mc_error(msg)`：编译时错误报告
  - `@mc_get_env(name)`：编译时环境变量读取
- **缓存机制**：相同宏调用自动缓存，提升编译性能
- **安全限制**：递归深度、展开次数、嵌套层数限制
- **完整示例**：编译时断言、类型驱动代码生成、配置系统等

---

## 0.40 版本变更（相对于 0.39）

### 0.40.1 内置函数命名统一

- **`@sizeof(T)` → `@size_of(T)`**：复合概念使用 snake_case
- **`@alignof(T)` → `@align_of(T)`**：复合概念使用 snake_case
- **命名惯例确立**：
  - 单一概念：`@len`, `@max`, `@min`（短形式）
  - 复合概念：`@size_of`, `@align_of`, `@async_fn`（下划线分隔）

### 0.40.2 泛型语法确定

- 使用尖括号：`<T>`
- 约束紧邻参数：`<T: Ord>`
- 多约束连接：`<T: Ord + Clone + Default>`
- 示例：`fn max<T: Ord>(a: T, b: T) T { ... }`，`struct Vec<T: Default> { ... }`

### 0.40.3 结构体默认值语法

- 支持在结构体定义中为字段指定默认值：`field: Type = default_value`
- 初始化时可以使用 `Struct{}` 使用所有默认值，或 `Struct{ field: value }` 部分使用默认值（有默认值的字段可以忽略）
- 默认值必须是编译期常量，零运行时开销
- 与移动语义、RAII、接口实现完全兼容

### 0.40.4 异步编程基础设施（新增第 18 章）

- **语言核心**（编译器实现）：
  - `@async_fn`：函数属性，触发 CPS 变换生成显式状态机
  - `@await`：唯一显式挂起点
  - `union Poll<T>`：异步计算结果类型
  - `interface Future<T>`：异步计算抽象
- **函数签名约束**：必须返回 `!Future<T>`（显式异步，无隐式包装）
- **标准库实现**（基于核心类型）：
  - `std.async`：`Task<T>`, `Waker`
  - `std.channel`：`Channel<T>`, `MpscChannel<T>`
  - `std.runtime`：`Scheduler`
  - `std.thread`：`ThreadPool`, `async_compute<T>`
- **设计哲学**：
  - 显式控制：所有挂起必须 `try @await`，取消必须显式检查 `is_cancelled()`
  - 零成本：状态机栈分配，无运行时堆分配，无隐式锁
  - 编译期证明：状态机安全性、Send/Sync 推导、跨线程验证编译期完成
  - 类型安全：`Poll<T>` 使用 `union`（编译期标签跟踪），非 `enum`

---

## 0.39 版本变更（相对于 0.38）

### 0.39 方法 self 统一为 &T，*T 仅用于 FFI（破坏性变更）

- **方法首个参数统一为 `self: &T`**：
  - 接口：`interface I { fn method(self: &Self, ...) Ret; ... }`
  - 结构体方法：`S { fn method(self: &Self, ...) Ret { ... } }`
  - 替换原有的 `self: *Self` / `self: *StructName`
- **`*T` 仅用于 FFI**：`extern fn foo(buf: *byte, ...) i32`，作为 extern 函数的参数与返回值
- **`&T as *T` 转换**：调用 FFI 函数时，可使用 `expr as *T` 将 Uya 普通指针转为 FFI 指针
- **向后兼容性**：破坏性变更，需将现有 `self: *Self` 改为 `self: &Self`

---

## 0.38 版本变更（相对于 0.36）

### 0.38 指针类型 *T 用途澄清（已由 0.39 修订）

- 此前补充了 `*T` 在方法签名中的用法；0.39 将其统一为 `self: &T`，`*T` 仅用于 FFI。

---

## 0.36 版本变更（相对于 0.35）

### 0.36 drop 定义位置（规范澄清）

- **drop 只能在结构体/联合体内部或方法块中定义**：
  - 禁止顶层 `fn drop(self: T) void`，与「不引入函数重载」的设计一致。
  - 结构体：`struct S { fn drop(self: S) void { ... } }` 或 `S { fn drop(self: S) void { ... } }`。
  - 联合体同理：在联合体内部或方法块中定义 drop。
- **规范与实现**：uya.md §12、§4.1、§4.5.10 已更新；compiler-mini 已实现禁止顶层 drop 的检查。

---

## 0.35 版本变更（相对于 0.34）

### 0.35.1 error_id 分配与稳定性（规范补充）

- **error_id 分配**：`error_id = hash(error_name)`（djb2 算法），相同错误名在任意编译中映射到相同 `error_id`
- **hash 冲突**：不同错误名 hash 冲突时，编译器报错并提示冲突的两个名称，开发者需重命名其一
- **规范更新**：uya.md、grammar_formal.md、grammar_quick.md、uya_ai_prompt.md 已同步

### 0.35 联合体（union）支持

- **联合体类型**（规范 0.35，第 4.5 章）：
  - 添加 `union` 关键字定义标签联合体
  - 语法：`union UnionName { variant1: Type1, variant2: Type2, ... }`
  - 创建：`UnionName.variant(expr)`，如 `IntOrFloat.i(42)`
  - 访问：必须通过 `match` 模式匹配（处理所有变体）或编译器可证明的已知标签直接访问
- **编译期标签跟踪**：标签仅在编译期使用，不占用运行时内存，零运行时开销
- **C 互操作**：与 C union 100% 内存布局兼容，支持 `extern union`
- **完整能力**：支持联合体方法、接口实现、移动语义、drop 机制
- **向后兼容性**：非破坏性变更，纯新增特性

---

## 0.34 版本变更（相对于 0.33）

### 0.34 参数列表即元组、可变参数、字符串插值与 printf

- **参数列表即元组**（规范 0.34）：
  - 当函数使用 **`@params` 内置变量**时，编译器将整个参数列表视为一个元组。
  - 对于**所有函数**（无论是否可变参数），`@params` 都包含所有参数，提供统一、类型安全的访问方式（`.0`/`.1` 或解构）。
  - 参数的类型序列与元组类型等价；命名访问与按位置元组访问两种视图并存。
- **可变参数（C 语法兼容 + 类型安全元组访问）**：
  - **声明语法**：沿用 C 的 `...` 语法，如 `fn printf(fmt: *byte, ...) i32;`
  - **统一访问**：函数体内使用 `@params` 访问所有参数作为元组
  - **编译器智能优化**：使用 `@params` 时生成元组打包代码；未使用时直接转发参数，零开销
  - **ABI 兼容**：与 C variadic 约定兼容；C 可直接调用 Uya 导出的可变参数函数
  - **格式串推断**：对 printf 风格 API，可由格式串推断可变参数元组类型
- **字符串插值与 printf 结合**：
  - 当插值结果仅作为 printf/print 的格式参数时，允许脱糖为单次 `printf(fmt, ...)`，无需中间缓冲区。
- **向后兼容性**：非破坏性变更；均为新增或可选优化。

---

## 0.33 版本变更（相对于 0.32）

### 0.33 数组字面量重复形式与类型语法统一为冒号

- **重复数组字面量**（第 1 章、第 7 章）：
  - 语法由 `[value; N]` 改为 **`[value: N]`**，与数组类型 `[T: N]` 一致，统一使用冒号表示「内容 : 长度」
  - N 须为编译期常量（字面量或顶层 const）
- **类型与字面量一致性**：数组类型 `[T: N]` 与重复字面量 `[value: N]` 均使用 `:`，便于记忆、减少符号种类
- **向后兼容性**：破坏性变更，现有使用 `[value; N]` 的代码需改为 `[value: N]`

---

## 0.32 版本变更（相对于 0.31）

### 0.32 内置函数统一以 @ 开头

- **所有内置函数以 `@` 开头**（第 1 章、第 16 章）：
  - `sizeof` → `@sizeof(T)`：类型大小查询
  - `alignof` → `@alignof(T)`：类型对齐查询
  - `len` → `@len(a)`：数组长度查询
  - `max` → `@max`：整数类型最大值（类型从上下文推断，原为关键字）
  - `min` → `@min`：整数类型最小值（类型从上下文推断，原为关键字）
- **关键字变更**：`max`、`min` 从关键字中移除，改为内置函数标识（以 `@` 开头）
- **语法**：内置函数调用形式为 `@sizeof(T)`、`@alignof(T)`、`@len(expr)`；极值形式为 `@max`、`@min`（无参数，类型由上下文推断）
- **向后兼容性**：破坏性变更，现有使用 `sizeof`、`alignof`、`len`、`max`、`min` 的代码需改为 `@sizeof`、`@alignof`、`@len`、`@max`、`@min`

---

## 0.30 版本变更（相对于 0.29）

### 0.30 alignof 改为内置函数

- **alignof 改为内置函数**（第 16 章）：
  - `alignof` 从标准库函数改为编译器内置函数，无需导入即可使用
  - 不再需要 `use std.mem.alignof;`，可以直接使用 `alignof(T)`
  - 编译期折叠为常数，零运行时开销
  - 与 `sizeof` 和 `len` 函数一致，都是编译器内置的，自动可用
- **向后兼容性**：
  - 这是破坏性变更，现有使用 `use std.mem.alignof;` 的代码需要移除导入语句

### 0.30 Uya 指针到 FFI 指针的显式转换

- **指针类型转换支持**（第 5.2 章、第 11 章）：
  - ✅ **Uya 普通指针 `&T` 可以通过 `as` 显式转换为 FFI 指针类型 `*T`**
  - 使用 `as` 进行安全转换：`&T as *T`（无精度损失，编译期检查）
  - 仅在 FFI 函数调用时使用，符合 Uya "显式控制"的设计哲学
  - 示例：`extern write(fd: i32, buf: *byte, count: i32) i32;` 调用时使用 `write(1, &buffer[0] as *byte, 10);`
- **类型转换规则更新**（第 11.4 章）：
  - 在转换规则表中添加指针类型转换：
    - `&T` → `*T`：✅ 支持 `as`（安全转换）
    - `*T` → `&T`：❌ 不支持 `as`，✅ 支持 `as!`（强转）
- **设计哲学一致性**：
  - 保持"零隐式转换"原则，通过显式 `as` 转换
  - 编译期验证，无运行时开销
  - 类型安全，防止误用
- **向后兼容性**：
  - 这是新增功能，不影响现有代码
  - 现有代码可以继续使用，新代码可以使用显式转换更方便地与 C 函数互操作

---

## 0.29 版本变更（相对于 0.28）

### 0.29 文档增强和规范细化

- **结构体内存布局详细规则**（第 4.2 章）：
  - 新增详细章节，完整说明结构体字段对齐、填充、嵌套结构体布局规则
  - 明确字段偏移计算公式：`offset(field_n) = align_up(offset(field_n-1) + sizeof(field_n-1), alignof(field_n))`
  - 明确填充字节内容为 0（零填充），确保结构体布局的可预测性
  - 详细说明嵌套结构体、数组字段、特殊类型字段（切片、接口、错误联合类型）的布局规则
  - 提供结构体大小和对齐的完整计算规则
  - 说明不同平台（32位/64位）的结构体布局差异
  - 明确空结构体的特殊规则（大小 = 1 字节，对齐 = 1 字节）
- **函数调用约定详细说明**（第 5.1.2 章）：
  - 新增详细章节，完整说明函数调用约定（ABI）规则
  - 详细说明 x86-64 System V ABI（Linux、macOS、BSD）的参数传递、返回值传递、寄存器使用规则
  - 详细说明 x86-64 Microsoft x64 Calling Convention（Windows）的调用约定
  - 详细说明 ARM64 ABI（AArch64）的调用约定
  - 详细说明 32位 x86 平台的 cdecl 调用约定
  - 明确错误联合类型 `!T` 的返回值处理规则（与普通结构体相同）
  - 提供调用约定总结表，对比不同平台的规则差异
  - 强调所有调用约定都与 C ABI 完全兼容，编译器自动选择正确的调用约定
- **文档优化**：
  - 优化文档结构和章节组织
  - 增强技术细节的完整性和准确性
  - 为编译器实现提供更详细的参考规范

---

## 0.28 版本变更（相对于 0.27）

### 0.28 sizeof 改为内置函数

- **sizeof 改为内置函数**（第 16 章）：
  - `sizeof` 从标准库函数改为编译器内置函数，无需导入即可使用
  - 不再需要 `use std.mem.{sizeof, alignof};`，可以直接使用 `sizeof(T)`
  - 编译期折叠为常数，零运行时开销
  - 与 `len` 函数一致，都是编译器内置的，自动可用
- **向后兼容性**：
  - 这是破坏性变更，现有使用 `use std.mem.{sizeof, alignof};` 的代码需要移除导入语句
  - `alignof` 仍然保留为标准库函数，需要导入使用

---

## 0.25 版本变更（相对于 0.24）

### 0.25 函数指针类型和导出函数支持

- **函数指针类型**（第 5 章）：
  - 新增函数指针类型语法：`fn(param_types) return_type`
  - 支持类型别名：`type ComparFunc = fn(*void, *void) i32;`
  - `&function_name` 的类型是函数指针类型（不是 `*void`）
  - 仅在 FFI 上下文中使用，用于与 C 函数指针互操作
- **导出函数给 C**（第 5.2 章）：
  - `extern fn name(...) type { ... }` - 导出 Uya 函数为 C 函数（导出，供 C 调用）
  - 导出的函数可以使用 `&name` 获取函数指针，传递给需要函数指针的 C 函数
  - 函数参数和返回值必须使用 C 兼容的类型
- **类型系统更新**：
  - 在类型系统中添加函数指针类型：`fn(...) type`
  - 函数指针类型大小：4/8 B（平台相关，与普通指针相同）

---

## 0.24 版本变更（相对于 0.23）

### 0.24 接口实现语法简化

- **移除接口实现块语法**（第 6 章）：
  - 删除了 `StructName : InterfaceName { ... }` 这种单独的接口实现块语法
  - 结构体在定义时声明接口：`struct StructName : InterfaceName { ... }`
  - 接口方法作为结构体方法定义，可以在结构体内部（与字段一起）或外部方法块中定义
  - 语法更简洁，接口方法就是结构体方法，无需区分
- **接口实现语法简化**（第 6 章）：
  - 移除了 `impl` 关键字，接口实现语法从 `impl StructName : InterfaceName {}` 简化为 `StructName : InterfaceName {}`
  - 语法更简洁，与结构体方法定义更对称（结构体方法：`StructName {}`，接口实现：`StructName : InterfaceName {}`）
  - `:` 符号语义清晰，表示"实现"关系，与类型标注的 `:` 一致
- **接口组合语法优化**（第 6 章）：
  - 接口组合语法保持不变，在接口体中直接列出被组合的接口名
  - 推荐使用分号分隔组合接口名（如 `IReader; IWriter;`），与方法签名格式一致，更清晰
  - 接口组合和方法签名可以混合使用
- **关键字列表更新**：
  - 从关键字列表中移除 `impl`，不再是保留关键字
- **向后兼容性**：
  - 这是破坏性变更，需要迁移现有代码中的 `impl` 语法
  - 建议作为版本升级的一部分

---

## 0.23 版本变更（相对于 0.22）

### 0.23 统一结构体标准

- **统一结构体标准**（第 4 章）：
  - 所有 `struct` 统一使用 C 内存布局，无需 `extern` 关键字
  - 移除了 `extern struct` 的特殊语法，统一为标准 `struct`
  - 所有结构体都可以直接与 C 代码互操作，编译器自动生成对应的 C 兼容布局
- **支持所有类型**（第 4 章）：
  - 结构体可以包含所有类型（基础类型、数组、切片、接口、错误联合类型、原子类型等）
  - 不再限制结构体字段类型，支持完整的 Uya 类型系统
- **完整 Uya 能力**（第 4 章）：
  - 所有结构体都可以有方法（结构体内部或外部定义）
  - 所有结构体都可以有 drop 函数（实现 RAII 自动资源管理）
  - 所有结构体都可以实现接口（支持动态派发）
  - 同一个结构体，两面性：C 代码看到纯数据，Uya 代码看到完整对象
- **C 内存布局定义**（第 4.1 章）：
  - 定义了切片类型 `&[T]` 在 C 中的表示：`{ void* ptr; size_t len; }`
  - 定义了接口类型 `InterfaceName` 在 C 中的表示：`{ void* vtable; void* data; }`
  - 定义了错误联合类型 `!T` 在 C 中的表示：`{ uint32_t error_id; T value; }`（error_id == 0 表示成功）
- **文档优化**：
  - 优化了 `grammar.md` 和 `uya.md` 的一致性和清晰度
  - 添加了结构体方法的完整语法定义
  - 添加了文档间的交叉引用
  - 统一了术语表述

---

## 0.22 版本变更（相对于 0.21）

### 0.22 切片类型重构
- **切片类型系统**（第 2 章）：
  - 新增切片类型 `&[T]`（动态长度切片引用）和 `&[T: N]`（已知长度切片引用）
  - 切片是胖指针（指针+长度），大小 16 字节，零堆分配
- **切片语法更新**（第 4 章）：
  - 废弃旧语法 `arr[start:len]`（返回新数组）
  - 新语法 `&arr[start:len]`（返回切片视图）
  - 支持负数索引：`&arr[-3:3]` 等价于 `&arr[7:3]`（对于长度为 10 的数组）
- **for循环支持切片**（第 8 章）：
  - 值迭代：`for slice |value| { }`（只读）
  - 引用迭代：`for slice |&ptr| { }`（可修改）
  - 索引迭代：`for slice |i| { }`（只获取索引）
  - 索引和值：`for slice |i, value| { }` 或 `for slice |i, &ptr| { }`
- **切片生命周期规则**（第 6.5 章）：
  - 切片生命周期 ≤ 原数据生命周期
  - 编译器自动验证切片不会超过原数据的生命周期
  - 切片是原数据的视图，修改原数组会影响切片
- **字符串切片**（第 17 章）：
  - 字符串数组 `[i8: N]` 支持切片操作：`&text[start:len]`
  - 字符串切片类型为 `&[i8]`，可定义类型别名 `type str = &[i8]`
- **性能保证**：
  - 零分配：切片是胖指针，无堆分配
  - 编译期展开：for循环编译期展开
  - 编译期验证：边界检查在编译期完成
  - 内存安全：生命周期自动绑定，防止悬垂引用

---

## 0.20 版本变更（相对于 0.19）

### 0.20 泛型语法优化
- **泛型定义语法优化**：定义使用括号 `struct S(T)` / `interface I(T)`，与实例化 `S(i32)` / `I(i32)` 完全对称，参数顺序明确
- **函数自动推断**：泛型函数保持自动推断，无需显式指定类型参数，更简洁
- **新增泛型容器库示例**：完整的 `ArrayList(T)`、`Collection(T)` 接口和实现示例（第 20 章 6.3 节）

---

## 0.19 版本变更（相对于 0.18）

### 0.19 文档更新
- **FFI 指针类型支持扩展**（第 2 章、第 5.2 章、第 5.3 章）：
  - 明确 FFI 指针 `*T` 支持所有 C 兼容类型，包括 `*i8`, `*i16`, `*i32`, `*i64`, `*u8`, `*u16`, `*u32`, `*u64`, `*f32`, `*f64`, `*bool`, `*byte`, `*void`, `*CStruct`
  - 统一指针语法：将所有 `byte*` 替换为 `*byte`（即 `*T` 形式，T=byte），统一使用 `*T` 语法
  - 添加统一指针语法规则说明，明确区分三种指针类型：
    - `&T`：Uya 内部安全指针，支持所有 Uya 类型
    - `*T`：FFI 专用指针，仅用于 C 语言互操作，支持所有 C 兼容类型
    - `&[T]`：参数语法糖，表示指针+长度的组合
  - FFI 指针使用规则：
    - ✅ 仅用于 FFI 函数声明/调用和 extern struct 字段
    - ✅ 支持下标访问 `ptr[i]`，但必须提供长度约束证明
    - ❌ 不能用于普通变量声明（编译错误）
    - ❌ 不能进行普通指针算术（只能用于 FFI 上下文）
  - 添加 `*u16` 等类型的完整使用示例和禁止用法示例
  - 强调设计哲学一致性：显式区分、安全强化、编译期验证、零隐式转换、C 兼容性

---

## 0.17 版本变更（相对于 0.16）

### 0.17 新增特性
- **移动语义**（第 12.5 章）：结构体赋值时转移所有权，避免不必要的拷贝
  - 自动移动场景：赋值、函数参数传递、返回值、结构体字段初始化、数组元素赋值
  - 严格检查机制：存在活跃指针时禁止移动，防止悬垂指针
  - 与 RAII 完美配合：移动后只有目标对象调用 drop，防止 double free
- **结构体方法语法糖**（第 29.3 章）：`obj.method()` 语法糖，编译期展开为静态函数调用
  - 支持 `Self` 占位符：`fn method(self: *Self) ReturnType`，与接口实现语法一致
  - 必须使用指针：`self: *Self` 或 `self: *StructName`，不允许按值传递，避免语义歧义
  - 方法调用不触发移动：调用时自动传递指针（`&obj`），确保方法调用后原对象仍然可用
  - 编译期展开：编译期展开为静态函数，所有方法都是静态绑定
- **Self 类型扩展**：`Self` 占位符现在可以在结构体方法中使用，与接口实现保持一致
- ***T 语法扩展**：`*T` 语法现在可以在结构体方法的方法签名中使用

---

## 0.16 版本变更（相对于 0.15）

### 0.16 新增特性
- **字符串插值**（第 23 章）：支持 `"a${x}"` 和 `"pi=${pi:.2f}"` 两种形式
- **安全指针算术**（第 27 章）：支持 `ptr +/- offset`，必须通过编译期证明安全
- **测试单元**（第 28 章）：`test` 块用于单元测试

---

## 0.15 版本变更（相对于 0.14）

### 0.15 新增特性
- **sizeof 和 alignof**：标准库函数，用于获取类型大小和对齐，编译期常量
  - 位置：`std/mem.uya`
  - 使用：`use std.mem.{sizeof, alignof};`
  - 支持所有基础类型、数组、结构体、原子类型等

---

## 语法简化（跨版本）

### for 循环语法简化
- 移除 `iter()` 和 `range()` 函数，直接支持 `for obj |v| {}` 和 `for 0..10 |v| {}`
- 新增可修改迭代语法：`for obj |&v| {}`（用于修改数组元素）
- 支持丢弃元素语法：`for obj {}` 和 `for 0..N {}`（只循环次数，不绑定变量）

### 运算符简化
- 移除 `checked_*` 函数，使用 `try` 关键字进行溢出检查（如 `try a + b`）
- 移除 `saturating_*` 函数，使用饱和运算符（`+|`, `-|`, `*|`）
- 移除 `wrapping_*` 函数，使用包装运算符（`+%`, `-%`, `*%`）

---

## 向后兼容性

- 所有 0.13 代码保持兼容（语法变更不影响现有代码）
- 新语法完全可选，可以继续使用原有方式

