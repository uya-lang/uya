# extern 变量/常量编译器实现计划

> **核对头（2026-09-27）**：本计划的任务清单指向**已退役的 `compiler-c/` 路线**（`compiler-c/src/ast.h`、`parser.c` 等），按 `AGENTS.md` 不再维护该路线。
> 新树现状：`@extern_var` 已在 `src/` 落地（`src/ast.uya` 的 `AST_EXTERN_VAR_DECL`、`src/checker/check_expr*.uya`/`check_stmt.uya`、`src/codegen/c99/global.uya` 的 `gen_extern_var_decl`）。
> 本文件仅作历史设计参考；如需补新语义（例如新的 ABI 约束），请基于 `src/` 重新开条目。

## 概述

在 C 编译器（`compiler-c/`）和自举编译器（`src/`）中同时实现 `extern` 变量/常量支持。

## 新增语法

| 语法 | 用途 | C 代码生成 |
|------|------|-----------|
| `extern const name: type;` | 导入只读 C 变量 | `extern const type name;` |
| `extern var name: type;` | 导入可变 C 变量 | `extern type name;` |
| `export const name: type = val;` | 导出只读常量 | `const type name = val;` |
| `export var name: type = val;` | 导出可变变量 | `type name = val;` |
| `export extern const name: type;` | 链接到 C 库定义 | 不生成，链接到 C 库 |
| `export extern var name: type;` | 链接到 C 库定义 | 不生成，链接到 C 库 |

## 实现计划

### 阶段 1：AST 修改

#### 1.1 C 编译器 (`compiler-c/src/ast.h`)

```c
// 新增节点类型
typedef enum {
    // ... 现有类型 ...
    AST_EXTERN_VAR_DECL,    // extern 变量声明（顶层）
} ASTNodeType;

// 扩展 ASTNode 联合体
typedef struct ASTNode {
    // ... 现有字段 ...
    
    // extern 变量声明（顶层：extern const/var name: type; 或 export const/var name: type = val;）
    struct {
        const char *name;           // 变量名
        struct ASTNode *var_type;   // 类型节点
        struct ASTNode *init_expr;  // 初始化表达式（可为 NULL）
        int is_const;               // 1 = const, 0 = var
        int is_extern;              // 1 = extern 声明（无初始化），0 = 有初始化
        int is_export;              // 1 = export，0 = 私有
        const char *extern_lib_name; // extern "libc" 的库名（可为 NULL）
    } extern_var_decl;
} ASTNode;
```

#### 1.2 Uya 编译器 (`src/ast.uya`)

```uya
// ASTNodeType 枚举新增
AST_EXTERN_VAR_DECL,    // extern 变量声明

// ASTNode 结构体新增字段
// extern_var_decl（顶层：extern const/var name: type; 或 export const/var name: type = val;）
extern_var_decl_name: &byte,           // 变量名
extern_var_decl_var_type: &ASTNode,    // 类型节点
extern_var_decl_init_expr: &ASTNode,   // 初始化表达式（可为 null）
extern_var_decl_is_const: i32,         // 1 = const, 0 = var
extern_var_decl_is_extern: i32,        // 1 = extern 声明，0 = 有初始化
extern_var_decl_is_export: i32,        // 1 = export，0 = 私有
extern_var_decl_extern_lib_name: &byte, // extern "libc" 的库名
```

**文件修改清单**：
- [ ] `compiler-c/src/ast.h`：添加 `AST_EXTERN_VAR_DECL` 和字段
- [ ] `src/ast.uya`：添加对应枚举和字段

---

### 阶段 2：Parser 修改

#### 2.1 C 编译器 (`compiler-c/src/parser.c`)

**新增函数**：
```c
// 解析 extern 变量声明：extern const/var name: type;
ASTNode* parser_parse_extern_var_decl(Parser *parser, const char *extern_lib_name);

// 解析顶层 const/var 声明（可能是 export）
ASTNode* parser_parse_top_level_var_decl(Parser *parser, int is_export, const char *extern_lib_name);
```

**修改函数**：
```c
// parser_parse_declaration - 添加 AST_EXTERN_VAR_DECL 处理
// parser_parse_export_decl - 添加 export const/var 处理
// parser_parse_extern_decl - 添加 extern const/var 处理
```

**解析流程**：
```
extern [STRING] (const|var) ID : type ;
    ↓
1. 消费 extern
2. [可选] 消费字符串字面量（extern_lib_name）
3. 消费 const 或 var
4. 消费 ID
5. 消费 :
6. 解析类型
7. 消费 ;

export (const|var) ID : type = expr ;
    ↓
1. 消费 export
2. 消费 const 或 var
3. 消费 ID
4. 消费 :
5. 解析类型
6. 消费 =
7. 解析表达式
8. 消费 ;

export extern [STRING] (const|var) ID : type ;
    ↓
1. 消费 export
2. 消费 extern
3. [可选] 消费字符串字面量
4. 消费 const 或 var
5. 消费 ID
6. 消费 :
7. 解析类型
8. 消费 ;
```

#### 2.2 Uya 编译器 (`src/parser.uya`)

**新增函数**：
```uya
fn parser_parse_extern_var_decl(parser: &Parser, extern_lib_name: &byte) &ASTNode;
fn parser_parse_top_level_var_decl(parser: &Parser, is_export: i32, extern_lib_name: &byte) &ASTNode;
```

**文件修改清单**：
- [ ] `compiler-c/src/parser.c`：添加解析函数
- [ ] `compiler-c/src/parser.h`：添加函数声明
- [ ] `src/parser.uya`：添加对应函数

---

### 阶段 3：Checker 修改

#### 3.1 C 编译器 (`compiler-c/src/checker.c`)

**新增检查**：
```c
// 检查 extern 变量类型是否为 C 兼容类型
int checker_check_extern_var_type(Checker *checker, ASTNode *node);

// 规则：
// 1. 基本类型：i8, i16, i32, i64, u8, u16, u32, u64, f32, f64, bool, byte, usize
// 2. 指针类型：*T, *const T, &T, &const T
// 3. extern struct 类型
// 4. 不支持：切片、接口、错误联合、原子类型等 Uya 特有类型
```

**修改函数**：
```c
// checker_check_program - 添加 AST_EXTERN_VAR_DECL 处理
// checker_check_declaration - 添加分支
```

#### 3.2 Uya 编译器 (`src/checker.uya`)

**文件修改清单**：
- [ ] `compiler-c/src/checker.c`：添加类型检查
- [ ] `compiler-c/src/checker.h`：添加函数声明
- [ ] `src/checker.uya`：添加对应检查

---

### 阶段 4：Codegen 修改

#### 4.1 C 编译器 (`compiler-c/src/codegen/c99/`)

**新增文件或函数**：
```c
// codegen/c99/extern_var.c 或在现有文件中添加

// 生成 extern 变量声明
void gen_extern_var_decl(C99CodeGenerator *codegen, ASTNode *node);

// 代码生成规则：
// extern const errno: i32;           → extern const int errno;
// extern var optind: i32;            → extern int optind;
// export const VERSION: &byte = "1.0.0"; → const char *VERSION = "1.0.0";
// export var debug_mode: i32 = 0;    → int debug_mode = 0;
// export extern const ENOENT: i32;   → (不生成，链接到 C 库)
```

**修改函数**：
```c
// gen_program - 添加 AST_EXTERN_VAR_DECL 处理
// gen_declaration - 添加分支
```

#### 4.2 Uya 编译器 (`src/codegen/c99/`)

**文件修改清单**：
- [ ] `compiler-c/src/codegen/c99/extern_var.c`：新建或添加函数
- [ ] `compiler-c/src/codegen/c99/codegen.c`：添加调用
- [ ] `src/codegen/c99/extern_var.uya`：新建或添加函数
- [ ] `src/codegen/c99/codegen.uya`：添加调用

---

### 阶段 5：符号表修改

#### 5.1 C 编译器 (`compiler-c/src/symbol_table.c`)

**新增/修改**：
```c
// 在符号表中注册 extern 变量
// 允许后续代码引用该变量名
int symbol_table_add_extern_var(SymbolTable *table, ASTNode *node);
```

#### 5.2 Uya 编译器 (`src/symbol_table.uya`)

**文件修改清单**：
- [ ] `compiler-c/src/symbol_table.c`：添加符号注册
- [ ] `compiler-c/src/symbol_table.h`：添加函数声明
- [ ] `src/symbol_table.uya`：添加对应函数

---

## 文件修改总览

| 文件 | 修改内容 | 状态 |
|------|----------|------|
| `compiler-c/src/ast.h` | AST 节点类型和字段 | ✅ |
| `compiler-c/src/ast.c` | 节点初始化 | ✅ |
| `compiler-c/src/parser.c` | 解析逻辑 | ✅ |
| `compiler-c/src/checker.c` | 类型检查 | ✅ |
| `compiler-c/src/codegen/c99/global.c` | 代码生成 | ✅ |
| `compiler-c/src/codegen/c99/internal.h` | 函数声明 | ✅ |
| `compiler-c/src/codegen/c99/main.c` | 集成调用 | ✅ |
| `src/ast.uya` | AST 节点类型和字段 | ✅ |
| `src/parser.uya` | 解析逻辑 | ✅ |
| `src/checker.uya` | 类型检查 | ✅ |
| `src/codegen/c99/global.uya` | 代码生成 | ✅ |
| `src/codegen/c99/main.uya` | 集成调用 | ✅ |

---

## 测试计划

### 单元测试

```uya
// tests/extern_var_test.uya

// 测试 1：导入只读 C 变量
extern const errno: i32;

// 测试 2：导入可变 C 变量
extern var optind: i32;

// 测试 3：导出常量
export const VERSION: &byte = "1.0.0";

// 测试 4：导出变量
export var debug_mode: i32 = 0;

// 测试 5：链接到 C 库定义
export extern const ENOENT: i32;

// 测试 6：extern "libc" 变量
extern "libc" const stdout: *void;

fn main() i32 {
    // 读取外部变量
    const err: i32 = errno;
    
    // 写入外部变量（仅 var）
    optind = 1;
    
    // 读取导出变量
    const v: &byte = VERSION;
    
    return 0;
}
```

### 集成测试

- [x] 编译生成 C 代码，验证语法正确
- [x] 使用 GCC 编译生成的 C 代码
- [x] 运行可执行文件验证功能

---

## 实现顺序

```
1. AST 修改（C 版本）
   ↓
2. Parser 修改（C 版本）
   ↓
3. Checker 修改（C 版本）
   ↓
4. Codegen 修改（C 版本）
   ↓
5. 测试 C 版本
   ↓
6. AST 修改（Uya 版本）
   ↓
7. Parser 修改（Uya 版本）
   ↓
8. Checker 修改（Uya 版本）
   ↓
9. Codegen 修改（Uya 版本）
   ↓
10. 测试 Uya 版本
   ↓
11. 自举验证
```

---

## 预计工作量

| 阶段 | 预计代码行数 | 复杂度 |
|------|-------------|--------|
| AST | ~50 行 | 低 |
| Parser | ~200 行 | 中 |
| Checker | ~100 行 | 中 |
| Codegen | ~100 行 | 低 |
| 符号表 | ~50 行 | 低 |
| 测试 | ~100 行 | 低 |
| **总计** | ~600 行 | - |

---

*创建时间：2026-02-14*
