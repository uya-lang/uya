# Uya Mini 规范扩展 TODO 文档（符合完整 Uya 规范）

本文档记录为支持使用 Uya Mini 重构 compiler-mini 而需要添加的语言特性。**所有特性必须符合完整 Uya 语言规范**（参考 `uya_ai_prompt.md`）。

**创建日期**：2026-01-11  
**最后更新**：2026-01-11  
**目的**：记录需要添加到 Uya Mini 规范中的特性，以支持 compiler-mini 的自举重构，所有语法必须符合完整 Uya 语言规范。

---

## 优先级说明

- **P0（必需）**：阻塞性特性，没有这些特性无法重构 compiler-mini
- **P1（强烈建议）**：显著改善代码质量和可读性
- **P2（可选）**：优化体验，可用替代方案

---

## 重要说明：Uya Mini 与完整 Uya 的关系

Uya Mini 是 Uya 语言的最小子集。扩展特性时，应参考完整 Uya 语言规范（`uya_ai_prompt.md`），确保语法和语义一致。关键区别：

- **指针类型**：完整 Uya 使用 `&T` 作为普通指针，`*T` 仅用于 FFI
- **数组语法**：完整 Uya 使用 `[T: N]` 语法
- **sizeof**：完整 Uya 中 `sizeof(T)` 是标准库函数（`use std.mem;`），Uya Mini 中作为内置函数（无需导入）
- **枚举**：完整 Uya 已支持枚举，默认底层类型 `i32`

---

## P0 优先级特性（必需）

### 1. 指针类型 (`&T` 和 `*T`)

**状态**：未实现  
**优先级**：P0（必需）

**规范说明**（参考完整 Uya）：
- `&T` - 普通指针（无lifetime符号），8字节，用于普通变量和函数参数
- `*T` - FFI 指针类型，仅用于 FFI 函数声明/调用，不能用于普通变量声明
- 取地址操作符：`&expr`
- 解引用：通过 `.` 访问字段，或使用 `*expr` 操作符

**使用场景**：
- 结构体指针传递（`&ASTNode`, `&Arena`） - 使用 `&T`
- 数组指针（`&[ASTNode: N]`） - 使用 `&[T: N]`
- FFI 函数参数（`*byte`, `*void`, `*FILE`） - 使用 `*T`
- C 标准库和 LLVM C API 调用 - 使用 `*T`

**参考代码**：
- `compiler-mini/src/ast.h` - ASTNode 结构体定义
- `compiler-mini/src/arena.h` - Arena 结构体定义
- `compiler-mini/src/main.c:23-29` - 文件 I/O（FFI）
- `compiler-mini/src/codegen.c` - LLVM C API 调用（FFI）

**语法规范建议**（符合完整 Uya 规范）：
```uya
// 普通指针（&T）- 用于普通变量和函数参数
struct Node {
    value: i32;
}

fn process(node: &Node) i32 {
    return node.value;  // 通过指针访问字段
}

var n: Node = Node{ value: 10 };
var p: &Node = &n;  // 取地址
var v: i32 = p.value;  // 通过指针访问字段

// FFI 指针类型（*T）- 仅用于 extern 函数声明/调用
extern fn fopen(filename: *byte, mode: *byte) *FILE;
extern fn fread(buffer: *void, size: i32, count: i32, file: *FILE) i32;
extern fn strcmp(s1: *byte, s2: *byte) i32;

// LLVM C API（FFI）
extern fn LLVMContextCreate() *LLVMContext;
extern fn LLVMModuleCreateWithNameInContext(name: *byte, context: *LLVMContext) *LLVMModule;
```

**实现要点**：
- 普通指针类型：`&Type`
- FFI 指针类型：`*Type`（仅用于 extern 函数）
- 取地址：`&expr`
- 解引用：`.field` 或 `*expr`
- 指针类型检查：指针类型必须匹配
- NULL 指针处理：`null` 常量（如果支持）

**与完整 Uya 的对应关系**：
- `&T` 对应完整 Uya 的普通指针（无lifetime符号）
- `*T` 对应完整 Uya 的 FFI 指针类型（仅用于 FFI）

---

### 2. 固定大小数组 (`[T: N]`)

**状态**：未实现  
**优先级**：P0（必需）

**规范说明**（参考完整 Uya）：
- 数组语法：`[Type: Size]`
- Size 必须是编译期常量
- 多维数组：`[[Type: N]: M]`
- 数组大小查询：`sizeof(arr)` 或 `len(arr)`

**使用场景**：
- 符号表槽位数组（`[&Symbol: 256]`）
- 词法分析器缓冲区（`[i8: 1024*1024]`）
- AST 节点数组（`&[ASTNode: N]`）

**参考代码**：
- `compiler-mini/src/checker.h:48` - SymbolTable slots[256]
- `compiler-mini/src/lexer.h:77` - Lexer buffer[1024*1024]
- `compiler-mini/src/codegen.h:25` - struct_types[64]

**语法规范建议**（符合完整 Uya 规范）：
```uya
struct SymbolTable {
    slots: [&Symbol: 256];  // 固定大小数组，元素类型为指针
    count: i32;
}

struct Lexer {
    buffer: [i8: 1024*1024];  // 1MB 缓冲区
    position: i32;
}

struct CodeGenerator {
    struct_types: [StructTypeMap: 64];
    var_map: [VarMap: 256];
}

// 数组访问
fn access_array(arr: [i32: 10], index: i32) i32 {
    if index >= 0 && index < 10 {
        return arr[index];  // 数组访问（需要边界检查证明）
    }
    return 0;
}

// 数组大小
const buffer: [i8: 1024] = [];
const size: i32 = sizeof(buffer);  // 数组总大小（字节）
const len: i32 = len(buffer);  // 数组元素个数（1024）
```

**实现要点**：
- 数组声明语法：`[Type: Size]`
- Size 必须是编译期常量（`const` 或字面量）
- 数组访问语法：`arr[index]`
- 数组作为函数参数：按值传递（复制整个数组）或按指针传递 `&[T: N]`
- 数组大小查询：`sizeof(arr)` 返回数组总大小（字节），`len(arr)` 返回元素个数

**与完整 Uya 的对应关系**：
- 语法与完整 Uya 完全一致：`[T: N]`

---

### 3. `sizeof` 内置函数

**状态**：未实现  
**优先级**：P0（必需）

**规范说明**：
- `sizeof(T)` 是内置函数（无需导入，直接使用）
- 返回类型大小（编译期常量）
- **设计决定**：Uya Mini 作为最小子集，不依赖模块系统，因此 `sizeof` 作为内置函数而非标准库函数

**使用场景**：
- Arena 分配器内存分配（`arena_alloc(arena, sizeof(ASTNode))`）
- 数组大小计算（`sizeof(&ASTNode) * capacity`）
- 结构体初始化（`memset(codegen, 0, sizeof(CodeGenerator))`）
- 缓冲区大小检查

**参考代码**：
- `compiler-mini/src/ast.c:14` - `arena_alloc(arena, sizeof(ASTNode))`
- `compiler-mini/src/parser.c:220` - `sizeof(ASTNode *) * new_capacity`
- `compiler-mini/src/codegen.c:18` - `memset(codegen, 0, sizeof(CodeGenerator))`

**语法规范建议**：
```uya
// 内置函数（无需导入，直接使用）
const node_size: i32 = sizeof(ASTNode);
const token_size: i32 = sizeof(Token);

// 表达式大小查询
var codegen: CodeGenerator = ...;
const codegen_size: i32 = sizeof(codegen);  // 或 sizeof(CodeGenerator)

// 数组大小计算
const ptr_size: i32 = sizeof(&ASTNode);  // 指针类型大小
const array_size: i32 = sizeof(&ASTNode) * capacity;

// 数组总大小
var buffer: [i8: 1024] = [];
const buffer_size: i32 = sizeof(buffer);  // 返回 1024（字节）
```

**实现要点**：
- `sizeof(Type)` - 获取类型的大小（编译时计算）
- `sizeof(expr)` - 获取表达式结果类型的大小（编译时计算）
- `sizeof(array)` - 获取整个数组的总大小（字节数）
- `sizeof(&T)` - 获取指针类型的大小（通常 8 字节）
- 返回值类型：`i32`（字节数）
- 必须是编译时常量
- **设计决定**：Uya Mini 作为最小子集，不依赖模块系统，因此 `sizeof` 作为内置函数

**与完整 Uya 的对应关系**：
- 完整 Uya 中 `sizeof(T)` 是标准库函数（`use std.mem;`）
- Uya Mini 中 `sizeof(T)` 是内置函数（无需导入），这是 Uya Mini 最小子集设计的简化

---

### 4. `extern` 函数指针参数支持（扩展）

**状态**：部分支持（当前仅支持基础类型参数）  
**优先级**：P0（必需）

**规范说明**（参考完整 Uya）：
- `extern` 函数声明支持 FFI 指针类型参数（`*T`）
- `*T` 类型仅用于 FFI 函数声明/调用
- 支持所有 C 兼容类型：`*i8` `*i16` `*i32` `*i64` `*u8` `*u16` `*u32` `*u64` `*f32` `*f64` `*bool` `*byte` `*void` `*CStruct`

**当前限制**：
- Uya Mini 规范中 `extern` 仅支持基础类型参数，不支持指针类型参数

**使用场景**：
- 调用 C 标准库函数（`fopen`, `fread`, `strcmp` 等）
- 调用 LLVM C API（大部分函数需要指针参数）

**参考代码**：
- `compiler-mini/src/main.c:23-29` - 文件 I/O
- `compiler-mini/src/codegen.c` - LLVM C API 调用

**语法规范建议**（符合完整 Uya 规范）：
```uya
// C 标准库函数声明
extern fn fopen(filename: *byte, mode: *byte) *FILE;
extern fn fread(buffer: *void, size: i32, count: i32, file: *FILE) i32;
extern fn fclose(file: *FILE) i32;
extern fn strcmp(s1: *byte, s2: *byte) i32;
extern fn strlen(s: *byte) i32;
extern fn memcpy(dest: *void, src: *void, n: i32) *void;
extern fn memset(s: *void, c: i32, n: i32) *void;

// LLVM C API 函数声明
extern fn LLVMContextCreate() *LLVMContext;
extern fn LLVMModuleCreateWithNameInContext(name: *byte, context: *LLVMContext) *LLVMModule;
extern fn LLVMInt32Type() *LLVMType;
extern fn LLVMBuildAlloca(builder: *LLVMBuilder, ty: *LLVMType, name: *byte) *LLVMValue;
```

**实现要点**：
- 扩展 `extern` 函数声明语法，支持 FFI 指针类型参数和返回值
- 类型映射：`*byte` → `char*`, `*void` → `void*`, `*i32` → `int*` 等
- 调用约定：与 C 兼容
- 注意：`*T` 仅用于 FFI，普通函数参数使用 `&T`

**与完整 Uya 的对应关系**：
- 与完整 Uya 的 FFI 规范完全一致

---

## P1 优先级特性（强烈建议）

### 5. 枚举类型 (`enum`) ✅ 完整 Uya 已支持

**状态**：完整 Uya 已支持，Uya Mini 需添加  
**优先级**：P1（强烈建议）

**规范说明**（参考完整 Uya）：
- 枚举默认底层类型为 `i32`
- 支持显式指定底层类型（`u8`, `u16`, `u32`, `i8`, `i16`, `i32`, `i64`）
- 枚举变体可以显式赋值
- 枚举值使用 `EnumName.Variant` 语法
- 类型安全：枚举值只能与相同枚举类型比较
- 与 C 枚举完全兼容

**使用场景**：
- TokenType 枚举（`TOKEN_EOF`, `TOKEN_IDENTIFIER` 等）
- ASTNodeType 枚举（`AST_PROGRAM`, `AST_FN_DECL` 等）
- TypeKind 枚举（`TYPE_I32`, `TYPE_BOOL` 等）

**参考代码**：
- `compiler-mini/src/lexer.h:16` - TokenType 枚举
- `compiler-mini/src/ast.h:9` - ASTNodeType 枚举
- `compiler-mini/src/checker.h:9` - TypeKind 枚举

**语法规范建议**（符合完整 Uya 规范）：
```uya
// 基本枚举（默认底层类型 i32）
enum TokenType {
    TOKEN_EOF,
    TOKEN_IDENTIFIER,
    TOKEN_NUMBER,
    TOKEN_STRUCT,
    // ...
}

enum ASTNodeType {
    AST_PROGRAM,
    AST_FN_DECL,
    AST_STRUCT_DECL,
    // ...
}

// 显式赋值
enum TypeKind {
    TYPE_I32 = 0,
    TYPE_BOOL = 1,
    TYPE_VOID = 2,
    TYPE_STRUCT = 3
}

// 使用
const token: TokenType = TokenType.TOKEN_IDENTIFIER;
const node_type: ASTNodeType = ASTNodeType.AST_PROGRAM;

fn get_token_type() TokenType {
    return TokenType.TOKEN_IDENTIFIER;
}
```

**实现要点**：
- 枚举值默认从 0 开始递增
- 枚举值可以显式赋值
- 类型安全：枚举类型不能隐式转换为整数（或在需要时支持转换）
- 可以与整数比较（如果需要 C 兼容性）
- 底层表示：`i32`（默认）或指定的底层类型

**与完整 Uya 的对应关系**：
- 语法与完整 Uya 完全一致

---

### 6. 字符串字面量（增强支持）

**状态**：部分支持（规范中提到"仅支持用于打印调试"）  
**优先级**：P1（强烈建议）

**规范说明**（参考完整 Uya）：
- 字符串字面量类型：`*byte`（指向字符数组的指针）
- 字符串字面量存储：编译器在只读数据段中存储
- 可以作为 FFI 函数参数
- 可以与 `null` 比较（如果函数返回 `*byte`）

**使用场景**：
- 字符串比较（`strcmp("i32", type_name)`）
- 错误消息
- 标识符字符串存储

**参考代码**：
- `compiler-mini/src/codegen.c:112-116` - 字符串比较

**语法规范建议**（符合完整 Uya 规范）：
```uya
extern fn strcmp(s1: *byte, s2: *byte) i32;

// 字符串字面量作为 FFI 函数参数
fn compare_string(s: *byte) bool {
    return strcmp(s, "i32") == 0;  // 字符串字面量 "i32" 类型为 *byte
}

// 字符串字面量用于比较
// 注意：字符串字面量不能直接赋值给变量（仅用于 FFI 函数参数）
```

**实现要点**：
- 字符串字面量类型：`*byte`（FFI 指针类型）
- 字符串字面量存储：编译器在只读数据段中存储
- 字符串比较：需要通过 `extern` 函数（如 `strcmp`）
- 注意：Uya Mini 不提供内置字符串操作，需要通过 `extern` 调用 C 函数

**与完整 Uya 的对应关系**：
- 与完整 Uya 的字符串字面量规则一致（仅用于 FFI）

---

## P2 优先级特性（可选）

### 7. 联合体 (`union`) - 可选

**状态**：未实现  
**优先级**：P2（可选）

**规范说明**：
- 完整 Uya 规范中未明确提到 union
- 可以用结构体 + 类型标签（tagged union）替代

**使用场景**：
- ASTNode 的 union 设计（节省内存，当前使用 union 存储不同类型节点数据）

**参考代码**：
- `compiler-mini/src/ast.h:45-159` - ASTNode 使用 union

**替代方案**：
使用结构体 + 类型标签（tagged union），但占用更多空间：
```uya
struct ASTNode {
    node_type: ASTNodeType;
    data: ASTNodeData;  // 包含所有可能的字段（浪费空间但可行）
}
```

**实现建议**：
- 如果 Uya Mini 需要严格的最小化，可以不实现 union
- 使用 tagged union 替代方案（结构体 + 类型标签）

---

## 实现路线图

### 阶段1：核心特性（P0）

1. **实现指针类型** (`&T` 和 `*T`)
   - 普通指针 `&T`：语法分析器、类型检查器、代码生成器扩展
   - FFI 指针 `*T`：仅用于 extern 函数声明
   - 取地址和解引用操作符

2. **实现固定大小数组** (`[T: N]`)
   - 语法分析器扩展
   - 类型检查器扩展（编译期常量大小检查）
   - 代码生成器扩展（LLVM IR 生成）

3. **实现 `sizeof` 内置函数**
   - 语法分析器扩展（作为内置函数处理）
   - 类型检查器扩展（编译时计算）
   - 代码生成器扩展（生成常量）

4. **扩展 `extern` 函数声明**
   - 语法分析器扩展（支持 FFI 指针类型参数）
   - 类型检查器扩展（指针类型检查）
   - 代码生成器扩展（FFI 调用）

### 阶段2：增强特性（P1）

5. **实现枚举类型** (`enum`)
   - 语法分析器扩展
   - 类型检查器扩展
   - 代码生成器扩展

6. **增强字符串字面量支持**
   - 确保字符串字面量可以作为 FFI 函数参数
   - 字符串字面量的存储和类型

### 阶段3：优化特性（P2）

7. **实现联合体** (`union`)（可选）
   - 或使用 tagged union 替代方案

---

## 参考文档

- `uya_ai_prompt.md` - **完整 Uya 语言规范（必须参考）**
- `spec/UYA_MINI_SPEC.md` - Uya Mini 语言规范（需要更新）
- `CODE_REVIEW.md` - 可行性评估报告
- `compiler-mini/src/` - compiler-mini 源代码（参考实现）

---

## 测试策略

每个特性实现后需要：

1. **语法测试**：验证语法解析正确
2. **类型检查测试**：验证类型检查正确
3. **代码生成测试**：验证生成的代码正确
4. **集成测试**：在 compiler-mini 重构中使用新特性

---

## 更新规范文档

实现每个特性后，需要更新：

- `spec/UYA_MINI_SPEC.md` - 添加新特性的语法规范和语义规则
- `spec/grammar_formal.md` - 更新 BNF 语法（如果存在）
- 相关示例代码

**重要**：所有语法必须与完整 Uya 语言规范（`uya_ai_prompt.md`）保持一致。

