# 阶段2：AST 数据结构

## 概述

翻译 AST（抽象语法树）数据结构定义，Parser、Checker、CodeGen 都依赖它。

**优先级**：P0

**工作量估算**：2-3 小时

**依赖**：阶段1（Arena）

**原因**：Parser、Checker、CodeGen 都依赖 AST 定义。

---

## 任务列表

### 任务 2.1：阅读和理解 C99 代码

- [ ] 阅读 `src/ast.h` - 理解 AST 接口和数据结构
- [ ] 阅读 `src/ast.c` - 理解 AST 实现
- [ ] 理解 AST 节点类型：
  - [ ] 表达式节点（`Expr`）
  - [ ] 语句节点（`Stmt`）
  - [ ] 类型节点（`Type`）
  - [ ] 声明节点（`Decl`）
- [ ] 理解 AST 节点的内存分配方式（使用 Arena）

**参考**：代码量中等（409行），主要是数据结构定义

---

### 任务 2.2：翻译 AST 枚举类型

**文件**：`uya-src/ast.uya`

- [ ] 翻译所有枚举类型：
  - [ ] `ExprKind` - 表达式类型枚举
  - [ ] `StmtKind` - 语句类型枚举
  - [ ] `TypeKind` - 类型类型枚举
  - [ ] `DeclKind` - 声明类型枚举
  - [ ] 其他枚举类型

**注意**：
- 使用枚举类型，不能用字面量代替枚举
- 保持枚举值顺序和数值与 C99 版本一致

---

### 任务 2.3：翻译 AST 结构体定义

- [ ] 翻译 `Type` 结构体：
  - [ ] 基础类型字段
  - [ ] 复合类型字段（结构体、数组、指针等）
  - [ ] 使用联合体或标记联合体（根据 Uya Mini 支持情况）
- [ ] 翻译 `Expr` 结构体：
  - [ ] 表达式类型字段
  - [ ] 表达式数据字段（使用联合体或标记联合体）
- [ ] 翻译 `Stmt` 结构体：
  - [ ] 语句类型字段
  - [ ] 语句数据字段
- [ ] 翻译 `Decl` 结构体：
  - [ ] 声明类型字段
  - [ ] 声明数据字段
- [ ] 翻译其他辅助结构体

**类型映射**：
- `Type *` → `&Type`
- `Expr *` → `&Expr`
- `Stmt *` → `&Stmt`
- `char *` → `&byte` 或 `*byte`（如果是 extern 函数参数）
- `int` → `i32`
- `size_t` → `i32`

---

### 任务 2.4：翻译 AST 构造函数

- [ ] 翻译所有 AST 节点构造函数：
  - [ ] `new_type_*` 函数系列
  - [ ] `new_expr_*` 函数系列
  - [ ] `new_stmt_*` 函数系列
  - [ ] `new_decl_*` 函数系列
- [ ] 确保所有构造函数使用 Arena 分配器
- [ ] 保持函数签名和功能与 C99 版本一致

**注意**：
- 使用 `arena_alloc` 分配内存
- 使用指针类型（`&T`）返回新分配的节点
- 初始化所有字段

---

### 任务 2.5：添加中文注释

- [ ] 为所有枚举类型添加中文注释
- [ ] 为所有结构体添加中文注释
- [ ] 为所有函数添加中文注释
- [ ] 为关键字段添加中文注释

---

### 任务 2.6：验证功能

- [ ] 创建简单的测试程序（`uya-src/test_ast.uya`）：
  - [ ] 测试创建各种类型的 AST 节点
  - [ ] 测试 AST 节点的字段访问
  - [ ] 测试 AST 节点的内存分配
- [ ] 使用 C99 编译器编译测试程序
- [ ] 运行测试程序验证功能正确性

**参考**：`tests/test_ast.c` - 现有的 C99 测试程序

---

## 完成标准

- [ ] `ast.uya` 已创建，包含完整的 AST 定义
- [ ] 所有枚举类型已翻译
- [ ] 所有结构体已翻译
- [ ] 所有构造函数已翻译
- [ ] 所有代码使用中文注释
- [ ] 功能与 C99 版本完全一致
- [ ] 测试程序通过
- [ ] 已更新 `PROGRESS.md`，标记阶段2为完成

---

## 参考文档

- `src/ast.h` - C99 版本的 AST 接口
- `src/ast.c` - C99 版本的 AST 实现
- `tests/test_ast.c` - AST 测试程序
- `spec/UYA_MINI_SPEC.md` - Uya Mini 语言规范，确认结构体和枚举语法
- `BOOTSTRAP_PLAN.md` - 类型映射规则

---

## 注意事项

1. **联合体处理**：Uya Mini 可能不支持 C 风格的联合体，需要使用标记联合体或其他方式
2. **递归类型**：AST 节点可能包含递归引用，确保类型定义正确
3. **内存对齐**：结构体字段对齐可能与 C99 不同，需要验证
4. **枚举值**：保持枚举值顺序和数值与 C99 版本一致，确保兼容性

---

## C99 → Uya Mini 映射示例

```c
// C99
typedef enum {
    EXPR_INT,
    EXPR_IDENT,
    // ...
} ExprKind;

typedef struct Expr {
    ExprKind kind;
    union {
        int int_value;
        char *ident_name;
        // ...
    } data;
} Expr;

Expr *new_expr_int(Arena *arena, int value) {
    Expr *expr = arena_alloc(arena, sizeof(Expr));
    expr->kind = EXPR_INT;
    expr->data.int_value = value;
    return expr;
}

// Uya Mini
enum ExprKind {
    EXPR_INT,
    EXPR_IDENT,
    // ...
}

struct Expr {
    kind: ExprKind;
    // 使用标记联合体或其他方式表示 data
}

fn new_expr_int(arena: &Arena, value: i32) &Expr {
    const expr: &Expr = arena_alloc(arena, sizeof(Expr)) as &Expr;
    expr.kind = EXPR_INT;
    // 设置 data 字段
    return expr;
}
```

