---
name: ASTNode 内存优化
overview: ASTNode 当前使用 flat struct（约 1432 字节），而 C 版本使用 union（约 72 字节），大小比约 20x。本计划使用 Uya 原生 union 类型重构 ASTNode，将内存占用降低到接近 C 版本水平。
todos: []
isProject: false
---

# ASTNode 内存优化计划

## 验证结果（2026-02-15）

### ✅ Uya 支持 union

经测试验证，Uya 语言规范 §4.5 的 union 完全可用：

```uya
union IntOrFloat {
    i: i32,
    f: f64
}

// 创建
const v: IntOrFloat = IntOrFloat.i(42);

// 访问（match）
match v {
    .i(x) => printf("int: %d\n", x),
    .f(x) => printf("float: %f\n", x)
}
```

### ✅ Union 可以包含指针类型

```uya
union ValuePtr {
    int_val: i32,
    float_val: f64,
    point: &Point,       // 指针变体
    other: &IntOrFloat   // 嵌套 union（通过指针）
}
```

### ⚠️ 限制：Union 嵌套结构体有代码生成 bug

当 union 直接包含结构体（非指针）时，C 代码生成的顺序有问题：

```uya
union Value {
    point: Point,  // 结构体（非指针）
}
// 生成 C 时，union Value 在 struct Point 之前定义 → 编译错误
```

**解决方案**：使用指针变体，或修复代码生成顺序。

---

## 问题分析

### 当前状态

| 指标 | C 编译器 | 自举编译器 | 倍数 |
|------|----------|------------|------|
| ASTNode 大小 | ~72 字节 | ~1432 字节 | **~20x** |
| 核心原因 | 使用 `union` 复用内存 | flat struct 包含所有字段 |

### 根因分析

**C 版本（union）**：
```c
typedef struct ASTNode {
    int type;
    int line;
    int column;
    const char *filename;
    union {
        struct { /* binary expr */ } binary;
        struct { /* function call */ } call;
        struct { /* if stmt */ } if_stmt;
        // ... 每种节点类型
    } data;
} ASTNode;
```

**当前 Uya 版本（flat struct）**：
```uya
// ast.uya 注释错误：Uya 实际上有 union！
struct ASTNode {
    type: ASTNodeType,
    line: i32,
    column: i32,
    filename: &byte,
    // 所有节点类型的字段平铺 → 约 150 个字段！
}
```

### 内存影响估算

| 阶段 | 节点数（估算） | C 版本内存 | 当前 Uya 内存 |
|------|---------------|------------|---------------|
| 单文件解析 | ~50,000 | ~3.5 MB | ~70 MB |
| 32 文件自举 | ~1,600,000 | ~110 MB | ~2.2 GB |

---

## 优化策略：使用 Uya 原生 union

**关键发现**：Uya 语言规范 §4.5 支持编译期类型安全的联合体（union）：

```uya
union IntOrFloat {
    i: i32,
    f: f64
}
```

这是 **tagged union**，与 C union 内存布局兼容，可以完美解决 ASTNode 问题！

### 设计方案

```uya
// 声明节点联合体（声明类节点）
union ASTDeclData {
    program: ASTProgramDecl,
    enum_decl: ASTEnumDecl,
    error_decl: ASTErrorDecl,
    interface_decl: ASTInterfaceDecl,
    struct_decl: ASTStructDecl,
    union_decl: ASTUnionDeclDecl,
    method_block: ASTMethodBlock,
    fn_decl: ASTFnDecl,
    macro_decl: ASTMacroDecl,
    type_alias: ASTTypeAlias,
    var_decl: ASTVarDecl,
    extern_var_decl: ASTExternVarDecl,
    destructure_decl: ASTDestructureDecl,
    use_stmt: ASTUseStmt,
}

// 表达式节点联合体
union ASTExprData {
    binary: ASTBinaryExpr,
    unary: ASTUnaryExpr,
    call: ASTCallExpr,
    member_access: ASTMemberAccess,
    array_access: ASTArrayAccess,
    slice: ASTSliceExpr,
    struct_init: ASTStructInit,
    array_literal: ASTArrayLiteral,
    tuple_literal: ASTTupleLiteral,
    cast: ASTCastExpr,
    identifier: ASTIdentifier,
    number: ASTNumber,
    float_literal: ASTFloatLiteral,
    bool_literal: ASTBoolLiteral,
    string_literal: ASTStringLiteral,
    string_interp: ASTStringInterp,
    try_expr: ASTTryExpr,
    catch_expr: ASTCatchExpr,
    error_value: ASTErrorValue,
    match_expr: ASTMatchExpr,
    await_expr: ASTAwaitExpr,
    // ... 其他表达式
}

// 语句节点联合体
union ASTStmtData {
    if_stmt: ASTIfStmt,
    while_stmt: ASTWhileStmt,
    for_stmt: ASTForStmt,
    break_stmt: ASTBreakStmt,
    continue_stmt: ASTContinueStmt,
    return_stmt: ASTReturnStmt,
    defer_stmt: ASTDeferStmt,
    errdefer_stmt: ASTErrdeferStmt,
    test_stmt: ASTTestStmt,
    assign: ASTAssign,
    block: ASTBlock,
    expr_stmt: ASTExprStmt,
}

// 类型节点联合体
union ASTTypeData {
    named: ASTTypeNamed,
    pointer: ASTTypePointer,
    array: ASTTypeArray,
    slice: ASTTypeSlice,
    tuple: ASTTypeTuple,
    error_union: ASTTypeErrorUnion,
    atomic: ASTTypeAtomic,
}

// 内置函数联合体
union ASTBuiltinData {
    sizeof_expr: ASTSizeofExpr,
    len_expr: ASTLenExpr,
    alignof_expr: ASTAlignofExpr,
    syscall: ASTSyscall,
    va_start: ASTVaStart,
    va_end: ASTVaEnd,
    va_arg: ASTVaArg,
    mc_eval: ASTMcEval,
    mc_code: ASTMcCode,
    mc_ast: ASTMcAst,
    mc_error: ASTMcError,
    mc_interp: ASTMcInterp,
    mc_type: ASTMcType,
    src_info: ASTSrcInfo,
    ptr_conv: ASTPtrConv,
}

// 顶层节点联合体
union ASTNodeData {
    decl: ASTDeclData,
    expr: ASTExprData,
    stmt: ASTStmtData,
    type_node: ASTTypeData,
    builtin: ASTBuiltinData,
}

// 最终 ASTNode 结构
struct ASTNode {
    type: ASTNodeType,
    line: i32,
    column: i32,
    filename: &byte,
    data: ASTNodeData,  // union，大小 = 最大变体大小
}
```

### 内存对比

| 方面 | 当前 flat struct | 使用 union 后 | 减少 |
|------|------------------|---------------|------|
| ASTNode 大小 | ~1432 字节 | ~72 字节 | **95%** |
| 单文件内存 | ~70 MB | ~3.5 MB | **95%** |
| 自举内存 | ~2.2 GB | ~110 MB | **95%** |
| arena_buffer | 256 MB | ~32 MB | **87%** |

### 预期效果

- **内存减少 95%**：与 C 版本持平
- **arena_buffer**：可从 256 MB 降到 32 MB
- **总内存**：320 MB → ~64 MB（与 C 版本一致）
- **编译速度**：更快（缓存友好）

---

## 实现方案

### 方案 A：扁平 union（推荐，简单可行）

由于 union 嵌套结构体有代码生成 bug，采用扁平设计：

```uya
// 所有变体字段平铺到单一 union
union ASTNodeData {
    // 声明类字段
    program_decls: &&ASTNode,
    program_decl_count: i32,
    enum_decl_name: &byte,
    enum_decl_variants: &EnumVariant,
    // ... 所有字段平铺
    // 但使用 union 共享内存
}

struct ASTNode {
    type: ASTNodeType,
    line: i32,
    column: i32,
    filename: &byte,
    data: ASTNodeData,  // union
}
```

**优点**：改动最小，不依赖嵌套 union
**缺点**：union 仍然较大（所有字段的并集）

### 方案 B：指针变体（推荐，最优内存）

使用指针变体，避免嵌套结构体问题：

```uya
// 每种节点类型的独立结构体
struct ASTProgramDecl {
    decls: &&ASTNode,
    decl_count: i32,
}

struct ASTBinaryExpr {
    left: &ASTNode,
    op: i32,
    right: &ASTNode,
}

// union 包含指针
union ASTNodeData {
    program: &ASTProgramDecl,
    binary: &ASTBinaryExpr,
    call: &ASTCallExpr,
    // ... 所有变体都是指针
}

struct ASTNode {
    type: ASTNodeType,
    line: i32,
    column: i32,
    filename: &byte,
    data: ASTNodeData,  // union（指针大小）
}
```

**优点**：ASTNode 大小最小（~32 字节）
**缺点**：需要额外内存分配变体数据

### 方案 C：修复代码生成（长期）

修复 union 嵌套结构体的代码生成顺序问题，然后使用完整的嵌套 union 设计。

---

## 实现计划（方案 B）

### 阶段 1：设计变体结构体（1-2 天）

1. **定义每种节点类型的结构体**
   ```uya
   struct ASTProgramDecl { decls: &&ASTNode, decl_count: i32 }
   struct ASTBinaryExpr { left: &ASTNode, op: i32, right: &ASTNode }
   struct ASTCallExpr { callee: &ASTNode, args: &&ASTNode, arg_count: i32, ... }
   // ... 约 60 种节点类型
   ```

2. **定义 union**
   ```uya
   union ASTNodeData {
       program: &ASTProgramDecl,
       binary: &ASTBinaryExpr,
       call: &ASTCallExpr,
       // ... 所有变体
   }
   ```

### 阶段 2：迁移 Parser（3-4 天）

1. **修改节点创建**
   ```uya
   // 原来
   node.binary_expr_left = left;
   node.binary_expr_op = op;
   node.binary_expr_right = right;

   // 改为
   var data: &ASTBinaryExpr = arena_alloc(arena, sizeof(ASTBinaryExpr));
   data.left = left;
   data.op = op;
   data.right = right;
   node.data.binary = data;
   ```

### 阶段 3：迁移 Checker/Codegen（4-5 天）

1. **修改节点访问**
   ```uya
   // 原来
   if node.type == AST_BINARY_EXPR {
       left = node.binary_expr_left;
   }

   // 改为
   if node.type == AST_BINARY_EXPR {
       left = node.data.binary.left;
   }
   ```

### 阶段 4：验证与调优（1-2 天）

1. 验证 `make b` 通过
2. 验证 `make tests-uya` 通过
3. 缩减 arena_buffer

---

## 关键文件

| 文件 | 改动量 | 说明 |
|------|--------|------|
| `src/ast.uya` | 大 | 定义 union 和所有变体结构体 |
| `src/parser.uya` | 大 | 修改所有 parse_* 函数 |
| `src/checker.uya` | 大 | 修改所有节点访问 |
| `src/codegen/*.uya` | 大 | 修改所有节点访问 |
| `src/main.uya` | 小 | 缩减 ARENA_BUFFER_SIZE |

---

## 风险与缓解

### 风险 1：代码生成顺序 bug

**问题**：union 嵌套结构体时，C 代码生成顺序错误

**缓解**：
- 使用方案 B（指针变体）
- 或修复代码生成顺序

### 风险 2：match 表达式复杂度

**问题**：使用 match 访问节点可能导致代码冗长

**缓解**：
- 创建辅助函数简化常见访问
- 如 `get_binary_left(node)` 等

### 风险 3：自举对比失败

**问题**：节点字段顺序变化可能影响 C 输出

**缓解**：
- 保持字段名称不变
- 输出 C 时按字段名排序
- 每批迁移后验证 `make b`

---

## 预期收益

| 指标 | 优化前 | 优化后 | 改善 |
|------|--------|--------|------|
| ASTNode 大小 | 1432 字节 | ~72 字节 | **95%** |
| arena_buffer | 256 MB | ~32 MB | **87%** |
| temp_arena_buffer | 64 MB | ~32 MB | **50%** |
| **总内存** | **320 MB** | **~64 MB** | **80%** |
| 编译速度 | 基准 | 更快 | 缓存友好 |

---

## 时间估算

| 阶段 | 时间 |
|------|------|
| 阶段 1：设计变体结构体 | 1-2 天 |
| 阶段 2：迁移 Parser | 3-4 天 |
| 阶段 3：迁移 Checker/Codegen | 4-5 天 |
| 阶段 4：验证与调优 | 1-2 天 |
| **总计** | **9-13 天** |

---

## 验证完成

- [x] Uya 支持 union 类型
- [x] Union 可以包含指针类型
- [x] Union 可以嵌套（通过指针）
- [x] Union 嵌套结构体的代码生成 bug（已修复）
  - 添加 `emit_struct_deps_for_union` 函数
  - 在生成 union 前先生成其依赖的结构体

## 新发现问题（2026-02-15）

### Union 变体类型限制

根据语言规范 §4.5.12：
> 变体类型限制：变体类型不能包含引用（`&T`）或切片（`&[T]`），防止生命周期问题

这意味着方案 B（指针变体）不可行！Union 变体不能是指针类型。

### 验证结果

✅ **Union match 表达式工作正常**：
- 当 union 变体是结构体类型时，match 绑定变量的类型推断正确
- 字段访问 `pt.x` 的类型推断正确
- 通配符 `_` 处理正确

✅ **Union 嵌套结构体的代码生成已修复**：
- `emit_struct_deps_for_union` 函数确保结构体在 union 之前生成

### 实施方案更新

由于 union 变体不能是指针，需要采用**方案 A：扁平 union**：

```uya
// 所有变体字段平铺到单一 union
union ASTNodeData {
    // 声明类字段
    program_decls: &&ASTNode,
    enum_decl_name: &byte,
    // ... 所有字段平铺
}

struct ASTNode {
    type: ASTNodeType,
    line: i32,
    column: i32,
    filename: &byte,
    data: ASTNodeData,  // union 共享内存
}
```

**优点**：
- 改动相对较小
- 不涉及指针变体的限制
- Union 大小 = 最大字段大小（而不是所有字段之和）

**缺点**：
- Union 仍然较大（所有字段的并集）
- 需要仔细处理每个字段类型

### 下一步

1. 分析当前 ASTNode 中哪些字段可以放入 union
2. 注意：`&&ASTNode`、`&byte` 等指针类型可以作为 union 变体（因为是指针，不是引用）
3. 创建测试验证 union 大小优化效果

## 验证完成（2026-02-15 续）

### ✅ Union 支持指针类型和混合类型

测试文件 `tests/programs/test_union_fields.uya` 验证：

```uya
// union 包含指针和整数（混合类型）
union MixedUnion {
    ptr_val: &i32,   // 8 字节
    int_val: i32,    // 4 字节
}
```

编译通过，测试运行正常。

### 方案 A 实施分析

**问题**：方案 A 将每个字段作为独立 union 变体，但 ASTNode 节点需要同时访问多个字段。

例如 `AST_PROGRAM` 节点需要：
- `program_decls: &&ASTNode`
- `program_decl_count: i32`

这两个字段必须同时存在，不能共享 union 内存。

**解决方案**：需要按节点类型分组字段，而不是简单平铺。

### 方案 A'（修订版）：按类型分组

将每种 AST 节点类型的字段作为一个变体结构体：

```uya
// 每种节点类型的数据结构体
struct ASTProgramData {
    decls: &&ASTNode,
    decl_count: i32,
}

struct ASTBinaryExprData {
    left: &ASTNode,
    op: i32,
    right: &ASTNode,
}

// Union 变体是结构体（值类型）
union ASTNodeData {
    program: ASTProgramData,
    binary_expr: ASTBinaryExprData,
    // ...
}
```

**问题**：Union 变体不能包含引用 `&T`，但可以包含结构体（结构体可以包含指针）。

### 下一步：验证 union 嵌套结构体

需要验证 union 变体是否可以包含内嵌结构体类型（之前已修复代码生成 bug）。

## 验证完成（2026-02-15 续）

### ✅ Union 支持结构体变体

测试文件 `tests/programs/test_union_struct_variant.uya` 验证：

```uya
struct Point { x: i32, y: i32 }
struct Size { width: i32, height: i32 }

union Shape {
    point: Point,
    size: Size,
}
```

编译通过，测试运行正常。这验证了方案 A' 的可行性。

### 方案 A' 设计

将每种 AST 节点类型的数据字段封装为独立结构体：

```uya
// 每种节点类型的数据结构体
struct ASTProgramData {
    decls: &&ASTNode,
    decl_count: i32,
}

struct ASTBinaryExprData {
    left: &ASTNode,
    op: i32,
    right: &ASTNode,
}

// ... 约 60 种节点数据结构体

// Union 变体是结构体
union ASTNodeData {
    program: ASTProgramData,
    binary_expr: ASTBinaryExprData,
    call_expr: ASTCallExprData,
    // ... 所有节点类型
}

// 最终 ASTNode
struct ASTNode {
    type: ASTNodeType,
    line: i32,
    column: i32,
    filename: &byte,
    data: ASTNodeData,  // union，大小 = 最大结构体大小
}
```

### 内存效果预估

| 指标 | 当前 flat struct | 方案 A' 后 |
|------|------------------|-----------|
| ASTNode 大小 | ~1432 字节 | ~200 字节（估计） |
| 减少比例 | - | ~86% |

### 实施步骤

1. **定义数据结构体**：为每种 ASTNodeType 定义对应的数据结构体
2. **定义 ASTNodeData union**：包含所有数据结构体变体
3. **修改 ASTNode**：将所有字段移入 union
4. **迁移访问代码**：`node.field` → `node.data.variant.field`
5. **验证**：`make b` + `make tests-uya`

---

## 实施进度（2026-02-15）

### 已完成

- [x] 验证 union 支持指针类型
- [x] 验证 union 支持混合类型
- [x] 验证 union 支持结构体变体
- [x] 修复 union 嵌套结构体代码生成 bug
- [x] 设计数据结构体（约 60 个）

### 数据结构体设计

已设计的数据结构体（见下方列表），每个结构体对应一种 ASTNodeType：

**声明类（14 个）**：
- ASTProgramData, ASTEnumDeclData, ASTErrorDeclData, ASTInterfaceDeclData
- ASTStructDeclData, ASTUnionDeclData, ASTMethodBlockData, ASTFnDeclData
- ASTMacroDeclData, ASTTypeAliasData, ASTVarDeclData, ASTExternVarDeclData
- ASTDestructureDeclData, ASTUseStmtData

**表达式类（22 个）**：
- ASTBinaryExprData, ASTUnaryExprData, ASTCallExprData, ASTMemberAccessData
- ASTArrayAccessData, ASTSliceExprData, ASTStructInitData, ASTArrayLiteralData
- ASTTupleLiteralData, ASTCastExprData, ASTIdentifierData, ASTNumberData
- ASTFloatData, ASTBoolData, ASTIntLimitData, ASTStringData
- ASTStringInterpData, ASTTryExprData, ASTCatchExprData, ASTAwaitExprData
- ASTErrorValueData, ASTMatchExprData

**语句类（10 个）**：
- ASTIfStmtData, ASTWhileStmtData, ASTForStmtData, ASTReturnStmtData
- ASTDeferStmtData, ASTErrdeferStmtData, ASTTestStmtData, ASTAssignData
- ASTBlockData

**类型类（7 个）**：
- ASTTypeNamedData, ASTTypePointerData, ASTTypeArrayData, ASTTypeSliceData
- ASTTypeTupleData, ASTTypeErrorUnionData, ASTTypeAtomicData

**内置函数类（15 个）**：
- ASTSizeofData, ASTLenData, ASTAlignofData, ASTSyscallData
- ASTPtrFromUsizeData, ASTUsizeFromPtrData, ASTVaStartData, ASTVaEndData
- ASTVaArgData, ASTMcEvalData, ASTMcCodeData, ASTMcAstData
- ASTMcErrorData, ASTMcInterpData, ASTMcTypeData

### 待实施

- [ ] 在 ast.uya 中添加数据结构体定义
- [ ] 定义 ASTNodeData union
- [ ] 修改 ASTNode 结构
- [ ] 迁移 parser.uya 节点创建代码
- [ ] 迁移 checker.uya 节点访问代码
- [ ] 迁移 codegen/*.uya 节点访问代码
- [ ] 验证自举和测试

### 遇到的问题（2026-02-15 实施）

#### 代码生成顺序问题

当添加 `ASTNodeData` union 和 `AST*Data` 结构体后，C 代码生成顺序出错：
- Union 定义在第 1551 行
- 结构体定义在第 1719 行

这导致 C 编译错误：`field 'program' has incomplete type`

#### 解决方案尝试

1. 修改 `emit_struct_deps_for_union` 函数添加特殊处理 ❌
2. 在 main.uya 第六步 c 添加特殊处理 ❌
3. 使用字符比较代替 `strncmp` ❌

#### 根本原因

Uya 编译器代码生成器的输出顺序问题：
- 第六步 c 生成 union 定义时，会直接输出到当前文件位置
- 但特殊处理代码是运行时代码，不会在编译期执行
- 需要在代码生成器中确保结构体定义在 union 定义之前

#### 建议

这是一个需要深入理解代码生成器的问题。建议：
1. 分析 `c99_generate` 函数的输出顺序
2. 确保在生成 union 定义之前，先检查并生成依赖的结构体
3. 或者在第四步（收集结构体）时，将 `AST*Data` 结构体标记为需要在 union 之前生成

### 解决方案（2026-02-15）

#### 问题根因

`collect_struct_types_in_union` 函数只收集 union 变体的直接类型，**没有递归处理嵌套依赖**。

例如：
```uya
struct Location { line: i32, column: i32 }
struct ProgramData { location: Location, ... }
union NodeData { program: ProgramData }
```

旧代码只收集 `ProgramData`，但 `ProgramData` 包含 `Location` 字段，导致：
- `ProgramData` 定义在 `Location` 之前
- C 编译错误：`field 'location' has incomplete type`

#### 实施修复

修改 `src/codegen/c99/structs.uya`：

1. 新增 `is_primitive_type_name` - 检查类型名是否是基本类型
2. 新增 `collect_struct_field_deps_recursive` - 递归收集结构体字段的值类型依赖
3. 新增 `collect_value_struct_deps_from_type` - 从类型节点收集值类型结构体依赖
4. 重构 `collect_struct_types_in_union` - 使用上述函数递归收集

关键逻辑：**拓扑排序** - 被依赖的结构体先输出

```
Location (被依赖) → ProgramData (依赖 Location) → NodeData (依赖 ProgramData)
```

#### 验证结果

- 测试文件：`tests/programs/test_union_nested_deps.uya`
- 生成的 C 代码顺序正确：`Location` → `ProgramData` → `NodeData`
- 352 个测试全部通过
- 自举验证通过

---

## 方案验证（2026-02-15 续）

### ✅ ASTNode Union 方案可行

测试文件 `tests/programs/test_astnode_union.uya` 验证了核心结构：

```uya
// 数据结构体
struct MockProgramData { decls: &i32, decl_count: i32 }
struct MockBinaryExprData { left: &i32, right: &i32, op: i32 }
struct MockNumberData { value: i32 }

// Union
union MockASTData {
    program: MockProgramData,
    binary_expr: MockBinaryExprData,
    number: MockNumberData,
}

// 最终结构
struct MockASTNode {
    type_id: MockASTType,
    line: i32,
    column: i32,
    data: MockASTData,
}
```

**验证结果**：
- C 代码生成顺序正确
- 353 个测试全部通过
- 通过 match 表达式访问 union 变体

### 下一步：渐进式迁移

1. **定义所有数据结构体**：约 60 个 AST*Data 结构体
2. **定义 ASTNodeData union**
3. **修改 ASTNode**：保留旧字段作为兼容层，添加 union
4. **逐步迁移**：按模块迁移访问代码

### 注意事项

1. **循环依赖**：数据结构体依赖 ASTNode，不能放在单独文件
2. **编译顺序**：需要在 ast.uya 中定义数据结构体，然后定义 union，最后更新 ASTNode
3. **渐进迁移**：可以先保留旧的 flat struct，逐步迁移到 union
4. **代码生成顺序**：需要修改代码生成器确保结构体在 union 之前定义

---

## 实施方案细化（2026-02-15）

### 已完成准备工作

- [x] 定义所有 AST*Data 结构体（src/ast_data.uya，共 60 个）
- [x] 定义 ASTNodeData union
- [x] 验证方案可行性（test_astnode_union.uya 通过）

### 循环依赖问题

**问题**：AST*Data 结构体包含 `&ASTNode` 字段，而 ASTNode 将包含 `ASTNodeData` union。

**解决方案**：
1. 将所有 AST*Data 结构体定义直接放在 ast.uya 中
2. 定义顺序：结构体 → union → ASTNode
3. 保留旧的 flat struct 字段，逐步迁移

### 实施步骤

#### 阶段 1：添加 union 字段（保持兼容）

1. 在 ast.uya 中添加 AST*Data 结构体定义
2. 添加 ASTNodeData union 定义
3. 在 ASTNode 中添加 `data: ASTNodeData` 字段
4. **保留所有旧字段**，确保现有代码继续工作
5. 验证 `make tests-uya` 通过

#### 阶段 2：创建辅助函数

为每种节点类型创建访问辅助函数：
```uya
// 获取 program 节点的 decls
fn ast_program_get_decls(node: &ASTNode) & & ASTNode {
    return node.data.program.decls;
}

// 设置 program 节点的 decls
fn ast_program_set_decls(node: &ASTNode, decls: & & ASTNode) void {
    node.data.program.decls = decls;
}
```

#### 阶段 3：渐进迁移

按模块迁移访问代码：
1. parser.uya - 节点创建
2. checker.uya - 节点访问
3. codegen/*.uya - 节点访问

每次迁移一个函数，验证测试通过。

#### 阶段 4：移除旧字段

所有访问代码迁移完成后，移除 ASTNode 中的旧字段。

### 预计工作量

| 阶段 | 时间 | 改动量 |
|------|------|--------|
| 阶段 1 | 0.5 天 | ast.uya |
| 阶段 2 | 0.5 天 | ast.uya |
| 阶段 3 | 5-7 天 | parser/checker/codegen |
| 阶段 4 | 0.5 天 | ast.uya |
| **总计** | **6-8 天** | |

### 风险

1. **循环依赖**：需要确保定义顺序正确
2. **自举对比失败**：节点字段顺序变化可能影响 C 输出
3. **遗漏访问点**：可能有隐藏的访问代码遗漏
