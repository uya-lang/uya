# Uya 编译器使用指南

## 安装

### 从源码构建

#### 系统要求

- GCC (支持 C99)
- Make
- Bash

#### 构建步骤

```bash
# 克隆仓库
git clone https://github.com/your-repo/uya.git
cd uya

# 从备份恢复并构建（首次构建）
make from-c

# 或者使用自举构建（需要已有编译器）
make uya
```

### 验证安装

```bash
# 验证编译器工作正常
make check

# 查看版本
./bin/uya --version
```

---

## 编译 Uya 程序

### 基本用法

```bash
# 编译 Uya 源文件生成 C 代码
./bin/uya source.uya -o output.c

# 编译并直接链接为可执行文件
./bin/uya source.uya -o output.c --link

# 使用优化级别（v0.7.3 新增）
./bin/uya -O2 source.uya -o output.c
```

### 命令行参数

| 参数 | 说明 |
|------|------|
| `-c <file>` | 指定输入源文件 |
| `-o <file>` | 指定输出文件名 |
| `--link` | 编译后自动链接为可执行文件 |
| `--safety-proof` | 启用内存安全证明 |
| `--no-safety-proof` | 禁用内存安全证明 |
| `--opt=<0-3>` | 设置优化级别（v0.7.3 新增） |
| `-O0` | 禁用优化（调试模式） |
| `-O1` | 常量折叠 + 死代码消除（默认） |
| `-O2` | + 证明优化 |
| `-O3` | + 内联 + 循环展开（未来支持） |
| `--help` | 显示帮助信息 |
| `--verbose` | 显示详细编译日志 |
| `-v`, `--version` | 显示版本信息 |

### 编译流程

```
Uya 源文件 (.uya)
       ↓
  词法/语法分析
       ↓
    AST 构建
       ↓
    类型检查
       ↓
   优化分析 (v0.7.3+)
       ↓
   代码生成 (C99)
       ↓
   C 源文件 (.c)
       ↓
    GCC 编译
       ↓
   可执行文件
```

---

## 项目结构

```
uya/
├── bin/                    # 编译器二进制文件
│   ├── uya                 # 可执行文件
│   └── uya.c               # 自举 C 源码（种子文件）
├── src/                    # 编译器源代码
│   ├── main.uya            # 入口
│   ├── lexer.uya           # 词法分析器
│   ├── parser.uya          # 语法分析器
│   ├── checker/            # 类型检查器（v0.7.0 拆分为多文件）
│   ├── codegen/            # 代码生成器
│   └── ...
├── lib/                    # 标准库
│   ├── std/                # Uya 标准库
│   └── libc/               # C 标准库绑定
├── tests/                  # 测试文件
├── examples/               # 示例代码
└── docs/                   # 文档
```

---

## Make 命令速查

### 编译选项

可通过环境变量覆盖默认编译选项：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `CFLAGS` | `-std=c99 -O0 -g -fno-builtin` | C 编译选项（默认调试模式） |
| `LDFLAGS` | （空） | 链接选项 |

```bash
# 使用自定义编译选项
CFLAGS='-std=c99 -O2' make from-c

# 构建发布版本（自动使用 -O3 优化）
make release
```

### 常用命令

| 命令 | 说明 |
|------|------|
| `make check` | 验证（自举 + 测试）**推荐** |
| `make uya` | 构建自举编译器 |
| `make b` | 自举验证 |
| `make tests-uya` | 运行测试 |
| `make tests-emcc` | 运行独立 emcc/unknown target smoke（需 `emcc` 与 `node`；不默认包含在 `make check` / `make release-dirty` 中） |
| `make from-c` | 从备份恢复并构建 |
| `make backup` | 验证 + 备份 |
| `make release` | 构建发布版本（-O3 优化）；Linux 走 nostdlib 主线，非 Linux 走 hosted 主线 |
| `make release-dirty` | 在当前工作树强行执行完整 release；会先 `clean`，再按平台运行 nostdlib 或 hosted 验证、刷新对应 seed 并执行 `release-build`，只适合本地调试 |
| `make release-clean` | 在 Git HEAD 干净快照里执行 `make release`，会忽略未提交修改，更接近 CI |
| `make clean` | 清理构建产物 |

---

## 内存安全证明

Uya 支持编译期内存安全证明，在编译时验证数组访问安全。

### 启用安全证明

```bash
./bin/uya --safety-proof source.uya -o output.c
```

### 安全证明示例

```uya
// 安全：编译器可以证明
fn safe_access() void {
    var arr: [i32: 10] = [...];
    var i: i32 = 5;
    
    if i >= 0 && i < 10 {
        arr[i] = 42;  // 安全：已验证边界
    }
}

// 不安全：编译错误
fn unsafe_access() void {
    var arr: [i32: 10] = [...];
    var i: i32 = get_value();  // 未知值
    
    arr[i] = 42;  // 编译错误：无法证明安全
}
```

### 安全证明规则

1. **边界检查**：数组索引必须在编译期可验证范围内
2. **空指针检查**：指针解引用前必须通过空检查
3. **未初始化检测**：变量使用前必须初始化

### 越界访问检测（v0.7.4 新增）

编译器现在支持更强大的越界访问检测：

```uya
// 编译期常量检测
const arr: [i32: 10] = [0: 10];
const val = arr[5];   // SAFE: 编译期验证 5 < 10
// const err = arr[15]; // ERROR: 编译期检测到越界

// 变量索引区间分析
fn safe_index(arr: &[i32], i: i32) i32 {
    if i >= 0 && i < @len(arr) {
        return arr[i];  // SAFE: 已证明边界安全
    }
    return 0;
}
```

**检测级别**：
- `SAFE`：编译期可证明安全，无需运行时检查
- `WARNING`：需要运行时边界检查
- `ERROR`：编译期可证明越界，编译错误

---

## 编译期优化（v0.7.3 新增）

### 优化级别控制

Uya 编译器支持多种优化级别，通过命令行参数控制：

```bash
# 禁用优化（调试模式）
./bin/uya -O0 source.uya -o output.c

# 默认优化级别（常量折叠 + 死代码消除）
./bin/uya -O1 source.uya -o output.c

# 启用证明优化
./bin/uya -O2 source.uya -o output.c

# 最高优化级别（未来支持内联和循环展开）
./bin/uya -O3 source.uya -o output.c

# 使用长选项形式
./bin/uya --opt=2 source.uya -o output.c
```

### 优化级别说明

| 级别 | 功能 | 编译时间 | 代码体积 | 性能 |
|------|------|---------|---------|------|
| -O0 | 无优化 | 最快 | 最大 | 最慢 |
| -O1 | 常量折叠 + 死代码消除 | 快 | 较小 | 较快 |
| -O2 | + 证明优化 | 中等 | 小 | 快 |
| -O3 | + 内联 + 循环展开 | 较慢 | 最小 | 最快 |

### 常量折叠示例

```uya
const x: i32 = 10 + 20;  // 编译期计算为 30
const y: i32 = x * 2;    // 编译期计算为 60
const z: i32 = 100 / 5;  // 编译期计算为 20

// 生成的 C 代码直接使用计算结果
// int x = 30;
// int y = 60;
// int z = 20;
```

### 死代码消除示例

```uya
fn example() void {
    const x: i32 = 42;
    if false {
        // 死代码：编译期消除
        const y: i32 = unreachable_function();
    }
    // 只生成有效代码
}
```

### 指令融合优化（v0.7.4 新增）

编译器可以检测并融合连续的算术指令：

```asm
# 优化前
mul r0, r1, r2
add r0, r0, r3

# 优化后（乘加融合）
madd r0, r1, r2, r3
```

**支持的融合模式**：
- 乘加融合（MAC）：`mul` + `add` → `madd`
- 更多模式正在开发中

### 冗余指令消除（v0.7.4 新增）

自动检测并消除冗余指令：

```asm
# 消除 nop 指令
nop  # 被消除

# 消除自移动
mov r0, r0  # 被消除
```

**检测类型**：
- `nop` 等无副作用指令
- 自移动指令（如 `mov r0, r0`）
- 死寄存器写入

### 优化效果

| 优化类型 | 代码体积减少 | 性能提升 | 编译时间影响 |
|---------|-------------|---------|------------|
| 常量折叠 | - | 显著 | < 1% |
| 死代码消除 | 5-15% | 小 | < 2% |
| 证明优化 | 3-8% | 中等 | < 5% |
| 指令融合 | 5-10% | 2-5x | < 3% |
| 冗余消除 | 3-5% | 1-2% | < 1% |

---

## 调试输出

Uya 提供 `@print` 和 `@println` 内置函数用于调试输出，无需导入任何模块。

### 基本用法

```uya
fn main() i32 {
    // 打印整数
    @println(42);           // 输出: 42

    // 打印字符串
    @println("Hello");      // 输出: Hello

    // 打印变量
    const x: i32 = 100;
    @println(x);            // 输出: 100

    // 打印表达式
    @println(x + 50);       // 输出: 150

    // 打印浮点数
    @println(3.14159);      // 输出: 3.14159

    // 打印布尔值
    @println(true);         // 输出: 1

    return 0;
}
```

### @print 与 @println

- `@print(expr)` - 打印但不换行
- `@println(expr)` - 打印并换行

```uya
fn main() i32 {
    @print("Name: ");
    @print("Uya");
    @println("");           // 手动换行
    // 输出: Name: Uya

    @println("One line");   // 自动换行
    return 0;
}
```

### 字符串插值

支持在字符串中嵌入表达式：

```uya
fn main() i32 {
    const name: &byte = "World";
    const count: i32 = 42;

    @println("Hello, ${name}!");       // 输出: Hello, World!
    @println("Count: ${count}");       // 输出: Count: 42
    @println("Sum: ${count + 8}");     // 输出: Sum: 50
    return 0;
}
```

### 格式化输出

支持十六进制、八进制和浮点精度格式：

```uya
fn main() i32 {
    const num: i32 = 255;
    const pi: f64 = 3.14159;

    // 十六进制
    @println("hex: ${num:#x}");        // 输出: hex: ff
    @println("HEX: ${num:#X}");        // 输出: HEX: FF

    // 八进制
    @println("octal: ${num:#o}");      // 输出: octal: 377

    // 浮点精度
    @println("pi: ${pi:.2f}");         // 输出: pi: 3.14
    @println("pi: ${pi:.4f}");         // 输出: pi: 3.1416

    return 0;
}
```

### 返回值

`@print` 和 `@println` 返回 `i32` 类型（printf 的返回值），可用于检测输出错误：

```uya
fn main() i32 {
    const result: i32 = @println("Hello");
    if result < 0 {
        // 输出错误
        return 1;
    }
    return 0;
}
```

### 不支持的类型

自定义结构体和联合体不能直接打印：

```uya
struct Point { x: i32, y: i32 }

fn main() i32 {
    const p: Point = Point { x: 1, y: 2 };
    // @println(p);  // ❌ 编译错误：该类型不支持 @print/@println

    // 手动打印字段
    @println("Point(${p.x}, ${p.y})");  // ✓ 正确
    return 0;
}
```

---

## 开发流程

### TDD 开发流程

```bash
# 1. 先写测试
vim tests/programs/test_new_feature.uya

# 2. 运行测试，确认失败
make tests-uya

# 3. 编写代码
vim src/related_module.uya

# 4. 验证
make check
```

### 自举验证

自举验证确保编译器能正确编译自身：

```bash
# 构建编译器
make uya

# 自举验证
make b
```

---

## 常见问题

### 编译段错误

如果编译时出现段错误，可能是栈空间不足：

```bash
# 增大栈限制
ulimit -s 65536

# 然后重新编译
make check
```

### 找不到编译器

```bash
# 从备份恢复
make from-c
```

### 测试失败

```bash
# 运行单个测试
./bin/uya build tests/programs/test_xxx.uya -o /tmp/test.c
gcc /tmp/test.c -o /tmp/test && /tmp/test
```

### 先做语法 / checker 检查

如果你怀疑问题出在语法、模块解析或类型检查阶段，可以先运行：

```bash
./bin/uya check your_file.uya
```

这会只执行到 checker，不进入代码生成与宿主 C 编译器，便于更快定位前端问题。

---

## 更多资源

- [语法快速参考](grammar_quick.md)
- [语法正式规范](grammar_formal.md)
- [内置函数](builtin_functions.md)
- [测试指南](testing_guide.md)
- [变更日志](changelog.md)
- [@asm API 参考](asm_api_reference.md)
- [编译期优化状态](compile_time_optimization_status.md)
