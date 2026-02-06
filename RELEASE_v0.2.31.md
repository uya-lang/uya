# Uya v0.2.31 版本说明

**发布日期**：2026-02-06

本版本主要实现了**源代码位置和函数名内置函数**（`@src_name`、`@src_path`、`@src_line`、`@src_col`、`@func_name`），为调试、日志和断言等功能提供编译期零开销的代码位置信息支持。同时新增了**类型别名**（`type` 关键字）和**结构体字段默认值**支持，并完成了**完整的内置函数使用文档**。

---

## 核心亮点

### 1. 源代码位置内置函数

- **五个新内置函数**：`@src_name`、`@src_path`、`@src_line`、`@src_col`、`@func_name`
- **编译期展开**：所有函数在编译期求值，零运行时开销
- **类型安全**：文件名和函数名返回 `&[i8]`（字节切片），行号列号返回 `i32`
- **上下文限制**：`@func_name` 仅能在函数体内使用，编译器会检测并报错
- **字符串常量优化**：自动去重相同的字符串常量，避免重复生成
- **自举同步**：C 实现与 uya-src 自举编译器完全同步

```uya
extern printf(fmt: *byte, ...) i32;

fn log(level: *byte, msg: *byte) void {
    printf("[%s] %s:%d in %s(): %s\n" as *byte,
           level,
           @src_name,    // 源文件名（不含路径）
           @src_line,    // 当前行号
           @func_name,   // 当前函数名
           msg);
}

fn main() i32 {
    log("INFO" as *byte, "Application started" as *byte);
    // 输出：[INFO] main.uya:15 in main(): Application started
    
    const file: &[i8] = @src_path;  // 完整文件路径
    const col: i32 = @src_col;       // 当前列号
    
    return 0;
}
```

**应用场景**：
- **调试信息**：精确定位代码执行位置
- **日志系统**：自动记录文件名、行号、函数名
- **断言实现**：提供详细的断言失败信息
- **错误追踪**：构建调用栈信息

### 2. 类型别名（type 关键字）

- **别名定义**：使用 `type` 关键字为类型创建别名
- **完全等价**：别名与原类型完全等价，可互换使用
- **改善可读性**：为复杂类型提供有意义的名称
- **编译期解析**：零运行时开销

```uya
// 基础类型别名
type Int = i32;
type Byte = u8;

// 指针类型别名
type IntPtr = &i32;

// 数组类型别名
type Buffer = [u8: 1024];

// 结构体类型别名
struct Point { x: i32, y: i32 }
type Position = Point;

fn process(data: Buffer) void {
    const size: Int = 10;
    // ...
}
```

### 3. 结构体字段默认值

- **默认值语法**：在结构体定义中使用 `= value` 指定字段默认值
- **部分初始化**：初始化时可以省略有默认值的字段
- **编译期常量**：默认值必须是编译期可求值的常量
- **零运行时开销**：编译期展开，无性能损失

```uya
struct Config {
    port: i32 = 8080,           // 默认端口
    max_conn: i32 = 100,        // 默认最大连接数
    timeout: i32 = 30,          // 默认超时（秒）
    enabled: bool = true,       // 默认启用
}

fn main() i32 {
    // 使用所有默认值
    const cfg1: Config = Config{};
    
    // 只覆盖部分字段
    const cfg2: Config = Config{
        port: 9000,
        max_conn: 200,
    };  // timeout 和 enabled 使用默认值
    
    return 0;
}
```

### 4. 内置函数完整文档

新增 `docs/builtin_functions.md`（972 行，22KB），包含：
- **18 个内置函数**的详细说明（已实现 12 个，语法解析 6 个）
- **每个函数包含**：函数签名、功能描述、参数说明、返回值、使用示例、注意事项
- **分类总结表**：按编译期/运行时、实现状态分类
- **命名惯例**：单一概念短形式（`@len`），复合概念 snake_case（`@size_of`）
- **性能保证**：零成本抽象原则说明
- **常见使用模式**：调试日志、断言实现、泛型容器等实用示例

---

## 模块变更

### C 实现（src）

| 模块 | 变更 |
|------|------|
| ast.h/ast.c | 新增 5 个 AST 节点类型（`AST_SRC_NAME`、`AST_SRC_PATH`、`AST_SRC_LINE`、`AST_SRC_COL`、`AST_FUNC_NAME`）；新增类型别名和结构体默认值支持 |
| lexer.c | 识别新的内置函数标识符；识别 `type` 关键字 |
| parser.c | 解析无参数的内置函数调用；解析类型别名定义；解析结构体字段默认值；+277 行 |
| checker.c | 类型推断：`@src_name/@src_path/@func_name` → `&[i8]`，`@src_line/@src_col` → `i32`；`@func_name` 上下文检查；类型别名解析；+100 行 |
| codegen/c99/expr.c | 生成字符串常量或整数常量；提取文件名/路径；+137 行 |
| codegen/c99/utils.c | 新增 `find_string_constant` 函数避免重复；字符串常量收集时设置 `current_function_decl`；+67 行 |
| codegen/c99/main.c | 类型别名代码生成；+38 行 |
| codegen/c99/stmt.c | 结构体默认值代码生成；+29 行 |

### 自举实现（uya-src）

| 模块 | 变更 |
|------|------|
| ast.uya | 新增 5 个 AST 节点类型；类型别名和默认值字段；+13 行 |
| lexer.uya | 识别新内置函数；识别 `type` 关键字；+9 行 |
| parser.uya | 解析内置函数调用；解析类型别名；解析默认值；+296 行 |
| checker.uya | 类型推断和上下文检查；类型别名解析；+78 行 |
| codegen/c99/expr.uya | 生成字符串/整数常量；`find_string_constant` 查找；+150 行 |
| codegen/c99/utils.uya | 新增 `find_string_constant` 函数；字符串常量收集优化；+60 行 |
| codegen/c99/main.uya | 类型别名代码生成；+45 行 |
| codegen/c99/stmt.uya | 结构体默认值代码生成；+31 行 |

### 测试用例

新增 4 个测试用例：
- `test_src_location.uya` - 源代码位置和函数名综合测试（65 行）
- `test_func_name_simple.uya` - `@func_name` 简单测试（9 行）
- `test_type_alias.uya` - 类型别名功能测试（170 行）
- `test_struct_default.uya` - 结构体默认值测试（80 行）

### 文档

新增文档：
- `docs/builtin_functions.md` - 内置函数完整使用文档（972 行，22KB）
- `README.md` - 添加内置函数文档链接

---

## 测试验证

- **C 版编译器（`--c99`）**：310 个测试全部通过（新增 4 个）
- **自举版编译器（`--uya --c99`）**：310 个测试全部通过
- **自举对比**：C 编译器与自举编译器生成的 C 文件完全一致（`./compile.sh --c99 -b`）

```bash
# 测试验证命令
make build
./tests/run_programs.sh --c99                    # C 版：310/310 通过
cd uya-src && ./compile.sh --c99 -e              # 构建自举编译器
./tests/run_programs.sh --uya --c99              # 自举版：310/310 通过
cd uya-src && ./compile.sh --c99 -b              # 自举对比：一致 ✓
```

---

## 文件变更统计（自 v0.2.30 以来）

**统计**：26 个文件变更，约 2522 行新增，148 行删除

**主要变更**：
- `compiler-mini/src/parser.c` — +277 行（类型别名、默认值、内置函数解析）
- `compiler-mini/src/codegen/c99/expr.c` — +137 行（源代码位置生成）
- `compiler-mini/src/checker.c` — +100 行（类型推断、上下文检查）
- `compiler-mini/src/codegen/c99/utils.c` — +67 行（字符串常量优化）
- `compiler-mini/uya-src/parser.uya` — +296 行（自举版解析功能）
- `compiler-mini/uya-src/codegen/c99/expr.uya` — +150 行（自举版代码生成）
- `compiler-mini/uya-src/checker.uya` — +78 行（自举版类型检查）
- `compiler-mini/docs/builtin_functions.md` — +972 行（新增文档）
- `compiler-mini/tests/programs/` — 4 个新测试用例（324 行）

---

## 技术细节

### 源代码位置函数实现

#### 1. AST 节点设计

每个 AST 节点都包含位置信息：
```c
struct ASTNode {
    ASTNodeType type;
    int line;        // 行号
    int column;      // 列号
    const char *filename;  // 文件路径
    // ...
};
```

#### 2. 编译期展开

内置函数在代码生成阶段展开为常量：

```c
// Uya 代码
const name: &[i8] = @src_name;
const line: i32 = @src_line;

// 生成的 C 代码
uint8_t * const name = str0;  // str0 = "main.uya"
int32_t const line = 42;      // 当前行号
```

#### 3. 字符串常量优化

编译器分两阶段处理字符串常量：

**阶段 1：收集**（`collect_string_constants`）
- 遍历 AST，收集所有字符串
- 自动去重相同的字符串
- 为每个字符串分配名称（`str0`, `str1`, ...）

**阶段 2：生成**（代码生成阶段）
- 使用 `find_string_constant` 查找已存在的常量
- 避免在代码生成时重复添加

```c
// 字符串常量定义（文件开头）
static const char str0[] = "main.uya";
static const char str1[] = "/path/to/main.uya";
static const char str2[] = "main";

// 代码中引用
uint8_t * const name = str0;  // 重用 str0
uint8_t * const func = str2;  // 重用 str2
```

#### 4. 函数名获取

在字符串常量收集阶段，编译器维护 `current_function_decl`：

```c
// 收集函数体中的字符串常量时
void collect_string_constants_from_decl(CodeGen *codegen, ASTNode *decl) {
    if (decl->type == AST_FN_DECL) {
        // 保存并设置当前函数上下文
        ASTNode *saved = codegen->current_function_decl;
        codegen->current_function_decl = decl;
        
        collect_string_constants_from_stmt(codegen, decl->data.fn_decl.body);
        
        // 恢复上下文
        codegen->current_function_decl = saved;
    }
}
```

### 类型别名实现

类型别名在类型检查阶段解析为原始类型：

```c
// Parser 阶段：记录别名定义
ASTNode *alias = ast_new_node(AST_TYPE_ALIAS);
alias->data.type_alias.name = "IntPtr";
alias->data.type_alias.target_type = parse_type();  // &i32

// Checker 阶段：解析别名
Type *resolve_type_alias(Checker *checker, const char *name) {
    // 查找别名定义
    ASTNode *alias = find_type_alias(checker, name);
    if (alias) {
        return checker_resolve_type(checker, alias->data.type_alias.target_type);
    }
    return NULL;
}
```

### 结构体默认值实现

默认值在编译期求值并内联到初始化代码：

```c
// Parser 阶段：解析默认值
struct_field->default_value = parse_expr();

// Codegen 阶段：生成初始化代码
void gen_struct_init(CodeGen *codegen, ASTNode *init) {
    for (each field) {
        if (field_not_in_init && field->default_value) {
            // 使用默认值
            gen_expr(codegen, field->default_value);
        } else {
            // 使用用户提供的值
            gen_expr(codegen, user_value);
        }
    }
}
```

---

## 版本对比

### v0.2.30 → v0.2.31 变更

- **新增功能**：
  - ✅ 源代码位置内置函数（5 个）：`@src_name`、`@src_path`、`@src_line`、`@src_col`、`@func_name`
  - ✅ 类型别名（`type` 关键字）
  - ✅ 结构体字段默认值
  - ✅ 内置函数完整文档（972 行）

- **编译器优化**：
  - ✅ 字符串常量自动去重
  - ✅ `find_string_constant` 函数避免重复添加
  - ✅ 函数上下文管理优化

- **测试改进**：
  - ✅ 新增 4 个测试用例（324 行）
  - ✅ 测试覆盖率提升：310 个测试全部通过

- **文档改进**：
  - ✅ 新增内置函数使用文档（22KB）
  - ✅ README 添加文档链接

- **非破坏性**：向后兼容，现有代码行为不变

---

## 性能保证

### 编译期零开销

所有新增的内置函数都在编译期求值，零运行时开销：

| 函数 | 编译期 | 运行时 | 开销 |
|------|--------|--------|------|
| `@src_name` | ✓ | - | 零开销（常量字符串） |
| `@src_path` | ✓ | - | 零开销（常量字符串） |
| `@src_line` | ✓ | - | 零开销（整数字面量） |
| `@src_col` | ✓ | - | 零开销（整数字面量） |
| `@func_name` | ✓ | - | 零开销（常量字符串） |

### 字符串常量优化

编译器自动去重相同的字符串常量：

```uya
// 源代码
fn foo() void {
    const name1: &[i8] = @src_name;  // str0 = "main.uya"
    const name2: &[i8] = @src_name;  // 重用 str0
}

fn bar() void {
    const name3: &[i8] = @src_name;  // 重用 str0
}
```

生成的 C 代码只包含一个字符串常量定义：
```c
static const char str0[] = "main.uya";  // 只定义一次
```

---

## 实际应用示例

### 1. 日志系统实现

```uya
extern printf(fmt: *byte, ...) i32;

// 日志级别
const LOG_DEBUG: i32 = 0;
const LOG_INFO: i32 = 1;
const LOG_WARN: i32 = 2;
const LOG_ERROR: i32 = 3;

fn log_impl(level: i32, file: &[i8], line: i32, func: &[i8], msg: *byte) void {
    const levels: [*byte: 4] = [
        "DEBUG" as *byte,
        "INFO " as *byte,
        "WARN " as *byte,
        "ERROR" as *byte,
    ];
    printf("[%s] %s:%d %s(): %s\n" as *byte, 
           levels[level], file, line, func, msg);
}

// 宏式日志（实际使用需要宏系统）
fn main() i32 {
    log_impl(LOG_INFO, @src_name, @src_line, @func_name, 
             "Application started" as *byte);
    // 输出：[INFO ] main.uya:23 main(): Application started
    
    log_impl(LOG_WARN, @src_name, @src_line, @func_name,
             "Low memory warning" as *byte);
    // 输出：[WARN ] main.uya:27 main(): Low memory warning
    
    return 0;
}
```

### 2. 断言实现

```uya
extern printf(fmt: *byte, ...) i32;
extern exit(code: i32) void;

fn assert_impl(condition: bool, expr: *byte, file: &[i8], 
               line: i32, func: &[i8]) void {
    if !condition {
        printf("Assertion failed: %s\n" as *byte, expr);
        printf("  at %s:%d in %s()\n" as *byte, file, line, func);
        exit(1);
    }
}

fn divide(a: i32, b: i32) i32 {
    // 断言 b != 0
    if !(b != 0) {
        assert_impl(false, "b != 0" as *byte, @src_name, @src_line, @func_name);
    }
    return a / b;
}
```

### 3. 性能分析器

```uya
extern clock() i64;
extern printf(fmt: *byte, ...) i32;

fn profile_start(name: &[i8], file: &[i8], line: i32) i64 {
    const start: i64 = clock();
    printf("[PROFILE] Start %s at %s:%d\n" as *byte, name, file, line);
    return start;
}

fn profile_end(name: &[i8], start_time: i64) void {
    const end: i64 = clock();
    const elapsed: i64 = end - start_time;
    printf("[PROFILE] End %s, elapsed: %lld cycles\n" as *byte, name, elapsed);
}

fn heavy_computation() i32 {
    const start: i64 = profile_start(@func_name, @src_name, @src_line);
    
    // 执行计算...
    var sum: i32 = 0;
    var i: i32 = 0;
    while i < 1000000 {
        sum = sum + i;
        i = i + 1;
    }
    
    profile_end(@func_name, start);
    return sum;
}
```

---

## 下一步计划

根据 `todo_mini_to_full.md`：

### 短期计划（v0.2.32）
- **标准库基础设施**：实现 `std` 模块系统
- **`@print/@println` 内置函数**：配合标准库实现格式化输出

### 中期计划
- **内存安全证明**：数组越界、空指针、未初始化、溢出检查
- **异步编程完善**：CPS 变换、状态机生成、运行时支持

### 长期计划
- **并发安全**：基于原子类型的并发安全保证
- **完整标准库**：字符串处理、集合、I/O、网络等

---

## 相关资源

- **语言规范**：`uya.md` §16 - 标准库（内置函数）
- **内置函数文档**：`compiler-mini/docs/builtin_functions.md` - 完整使用文档
- **实现规范**：`compiler-mini/spec/UYA_MINI_SPEC.md`
- **待办事项**：`compiler-mini/todo_mini_to_full.md` - 内置与标准库补充
- **测试用例**：
  - `compiler-mini/tests/programs/test_src_location.uya` - 源代码位置测试
  - `compiler-mini/tests/programs/test_type_alias.uya` - 类型别名测试
  - `compiler-mini/tests/programs/test_struct_default.uya` - 结构体默认值测试

---

**本版本实现了五个源代码位置和函数名内置函数，为调试、日志和断言提供编译期零开销的位置信息支持。同时新增了类型别名和结构体字段默认值功能，并完成了 22KB 的内置函数完整使用文档。C 实现与 uya-src 自举编译器已完全同步，所有 310 个测试用例全部通过，自举对比一致。编译器功能持续增强，向完整 Uya 规范迈进。**

