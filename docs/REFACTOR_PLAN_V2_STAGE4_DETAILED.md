# 阶段四：Union 数据结构重构详细方案

> **核对头（2026-09-27）**：本文件属 2026-02/03 重构计划的历史记录，**不要再按其中的勾选/百分比判断进度**。
> 现状：目录化拆分（阶段 1–3）已完成；"Union 数据结构重构"因子语言没有 union 特性而不适用（见 `src/ast.uya` 顶部注释）。总体口径见 `docs/REFACTOR_TODO.md` 核对头与 `docs/todo_status_index.md`。

**风险评估**：高 → 中（通过增量式迁移降低风险）
**预估工期**：15-20 天（原 45-65 天）

---

## 一、核心策略：增量式迁移

### 1.1 风险控制原则

| 原则 | 实施方法 |
|------|----------|
| **小步提交** | 每个子任务完成后立即验证 |
| **向后兼容** | 保留旧字段，添加新 union 字段 |
| **访问器封装** | 通过函数访问，渐进迁移 |
| **模块隔离** | 按模块迁移，避免全局改动 |

### 1.2 迁移阶段

```
阶段 4.1：Type 结构体 Union 化（5-7 天）
├── Step 1: 添加 TypeData union + 辅助函数（1 天）
├── Step 2: 迁移高访问字段（2 天）
├── Step 3: 迁移中访问字段（1 天）
├── Step 4: 迁移低访问字段（1 天）
└── Step 5: 移除旧字段 + 验证（1-2 天）

阶段 4.2：ASTNode 结构体 Union 化（10-13 天）
├── Step 1: 添加 ASTNodeData union + 辅助函数（2 天）
├── Step 2: 迁移声明节点（3 天）
├── Step 3: 迁移表达式节点（3 天）
├── Step 4: 迁移语句节点（2 天）
└── Step 5: 移除旧字段 + 验证（2-3 天）
```

---

## 二、阶段 4.1：Type 结构体 Union 化

### 2.1 字段访问频率分析

| 分组 | 字段 | 访问次数 | 迁移优先级 |
|------|------|----------|------------|
| **高频** | `struct_name` | 52 | P0 |
| **高频** | `pointer_to` | 47 | P0 |
| **高频** | `element_type` | 35 | P0 |
| **高频** | `slice_element_type` | 23 | P0 |
| **高频** | `struct_type_args` | 23 | P0 |
| **高频** | `error_union_payload_type` | 21 | P0 |
| **高频** | `enum_name` | 21 | P0 |
| **中频** | `struct_type_arg_count` | 19 | P1 |
| **中频** | `array_size` | 12 | P1 |
| **中频** | `tuple_element_types` | 14 | P1 |
| **中频** | `tuple_count` | 11 | P1 |
| **中频** | `atomic_inner_type` | 11 | P1 |
| **中频** | `generic_param_name` | 11 | P1 |
| **低频** | `union_name` | 8 | P2 |
| **低频** | `is_ffi_pointer` | 8 | P2 |
| **低频** | `interface_name` | 8 | P2 |
| **低频** | `slice_len` | 3 | P2 |
| **低频** | `error_error_id` | 3 | P2 |
| **总计** | | **319** | |

### 2.2 新 Type 结构体设计

```uya
// 新设计：使用 union 封装变体数据
struct Type {
    kind: TypeKind,
    data: TypeData,  // 新增：union 类型
    // === 以下为过渡期保留的旧字段（迁移完成后移除）===
    // @deprecated: 使用 data 访问
    enum_name: &byte,
    interface_name: &byte,
    struct_name: &byte,
    union_name: &byte,
    pointer_to: &Type,
    is_ffi_pointer: i32,
    element_type: &Type,
    array_size: i32,
    slice_element_type: &Type,
    slice_len: i32,
    tuple_element_types: &Type,
    tuple_count: i32,
    error_union_payload_type: &Type,
    error_error_id: u32,
    atomic_inner_type: &Type,
    generic_param_name: &byte,
    struct_type_args: &Type,
    struct_type_arg_count: i32,
}

// 类型数据联合体
union TypeData {
    void_unit: void,              // TYPE_VOID
    primitive: i32,               // TYPE_I8-I64, TYPE_BOOL, TYPE_F64 等
    named: &byte,                 // TYPE_ENUM, TYPE_STRUCT, TYPE_UNION, TYPE_INTERFACE 的名称
    pointer: PointerData,         // TYPE_POINTER
    array: ArrayData,             // TYPE_ARRAY
    slice: SliceData,             // TYPE_SLICE
    tuple: TupleData,             // TYPE_TUPLE
    error_union: ErrorUnionData,  // TYPE_ERROR_UNION
    atomic: AtomicData,           // TYPE_ATOMIC
    generic_param: GenericParamData, // TYPE_GENERIC_PARAM
    struct_generic: StructGenericData, // TYPE_STRUCT 带泛型参数
}

// 指针数据
struct PointerData {
    pointee: &Type,
    is_ffi: i32,
}

// 数组数据
struct ArrayData {
    element: &Type,
    size: i32,
}

// 切片数据
struct SliceData {
    element: &Type,
    len: i32,
}

// 元组数据
struct TupleData {
    elements: &Type,
    count: i32,
}

// 错误联合数据
struct ErrorUnionData {
    payload: &Type,
    error_id: u32,
}

// 原子类型数据
struct AtomicData {
    inner: &Type,
}

// 泛型参数数据
struct GenericParamData {
    name: &byte,
}

// 结构体泛型数据
struct StructGenericData {
    name: &byte,
    type_args: &Type,
    type_arg_count: i32,
}
```

### 2.3 访问器函数设计

```uya
// ===== 类型名称访问器 =====

// 获取命名类型的名称（enum/struct/union/interface）
fn type_get_name(t: &Type) &byte {
    match t.kind {
        TypeKind.TYPE_ENUM => {
            match t.data {
                .named(name) => return name,
                else => return null,
            }
        },
        TypeKind.TYPE_STRUCT => {
            match t.data {
                .named(name) => return name,
                .struct_generic(sg) => return sg.name,
                else => return null,
            }
        },
        TypeKind.TYPE_UNION => {
            match t.data {
                .named(name) => return name,
                else => return null,
            }
        },
        TypeKind.TYPE_INTERFACE => {
            match t.data {
                .named(name) => return name,
                else => return null,
            }
        },
        else => return null,
    }
}

// ===== 指针类型访问器 =====

fn type_get_pointer_to(t: &Type) &Type {
    if t.kind != TypeKind.TYPE_POINTER { return null; }
    match t.data {
        .pointer(p) => return p.pointee,
        else => return null,
    }
}

fn type_is_ffi_pointer(t: &Type) i32 {
    if t.kind != TypeKind.TYPE_POINTER { return 0; }
    match t.data {
        .pointer(p) => return p.is_ffi,
        else => return 0,
    }
}

// ===== 数组类型访问器 =====

fn type_get_array_element(t: &Type) &Type {
    if t.kind != TypeKind.TYPE_ARRAY { return null; }
    match t.data {
        .array(a) => return a.element,
        else => return null,
    }
}

fn type_get_array_size(t: &Type) i32 {
    if t.kind != TypeKind.TYPE_ARRAY { return 0; }
    match t.data {
        .array(a) => return a.size,
        else => return 0,
    }
}

// ===== 切片类型访问器 =====

fn type_get_slice_element(t: &Type) &Type {
    if t.kind != TypeKind.TYPE_SLICE { return null; }
    match t.data {
        .slice(s) => return s.element,
        else => return null,
    }
}

fn type_get_slice_len(t: &Type) i32 {
    if t.kind != TypeKind.TYPE_SLICE { return 0; }
    match t.data {
        .slice(s) => return s.len,
        else => return 0,
    }
}

// ===== 元组类型访问器 =====

fn type_get_tuple_elements(t: &Type) &Type {
    if t.kind != TypeKind.TYPE_TUPLE { return null; }
    match t.data {
        .tuple(tu) => return tu.elements,
        else => return null,
    }
}

fn type_get_tuple_count(t: &Type) i32 {
    if t.kind != TypeKind.TYPE_TUPLE { return 0; }
    match t.data {
        .tuple(tu) => return tu.count,
        else => return 0,
    }
}

// ===== 错误联合类型访问器 =====

fn type_get_error_payload(t: &Type) &Type {
    if t.kind != TypeKind.TYPE_ERROR_UNION { return null; }
    match t.data {
        .error_union(eu) => return eu.payload,
        else => return null,
    }
}

fn type_get_error_id(t: &Type) u32 {
    if t.kind != TypeKind.TYPE_ERROR_UNION { return 0; }
    match t.data {
        .error_union(eu) => return eu.error_id,
        else => return 0,
    }
}

// ===== 原子类型访问器 =====

fn type_get_atomic_inner(t: &Type) &Type {
    if t.kind != TypeKind.TYPE_ATOMIC { return null; }
    match t.data {
        .atomic(a) => return a.inner,
        else => return null,
    }
}

// ===== 泛型参数访问器 =====

fn type_get_generic_param_name(t: &Type) &byte {
    if t.kind != TypeKind.TYPE_GENERIC_PARAM { return null; }
    match t.data {
        .generic_param(gp) => return gp.name,
        else => return null,
    }
}

// ===== 结构体泛型访问器 =====

fn type_get_struct_type_args(t: &Type) &Type {
    match t.data {
        .struct_generic(sg) => return sg.type_args,
        else => return null,
    }
}

fn type_get_struct_type_arg_count(t: &Type) i32 {
    match t.data {
        .struct_generic(sg) => return sg.type_arg_count,
        else => return 0,
    }
}

// ===== 构造函数 =====

fn make_pointer_type(pointee: &Type, is_ffi: i32, arena: &Arena) Type {
    var t: Type;
    t.kind = TypeKind.TYPE_POINTER;
    // 同时设置新旧字段（过渡期）
    t.pointer_to = pointee;
    t.is_ffi_pointer = is_ffi;
    // 设置新 union 字段
    var pd: PointerData;
    pd.pointee = pointee;
    pd.is_ffi = is_ffi;
    t.data = TypeData.pointer(pd);
    return t;
}

fn make_array_type(element: &Type, size: i32, arena: &Arena) Type {
    var t: Type;
    t.kind = TypeKind.TYPE_ARRAY;
    // 同时设置新旧字段（过渡期）
    t.element_type = element;
    t.array_size = size;
    // 设置新 union 字段
    var ad: ArrayData;
    ad.element = element;
    ad.size = size;
    t.data = TypeData.array(ad);
    return t;
}

// ... 其他构造函数类似
```

### 2.4 迁移步骤详解

#### Step 1: 添加 TypeData union + 辅助函数（1 天）

**目标**：添加新的 union 类型和访问器函数，保持向后兼容

**任务清单**：
- [ ] 在 `src/checker/types.uya` 添加 `TypeData` union 和辅助结构体
- [ ] 在 `Type` 结构体中添加 `data: TypeData` 字段
- [ ] 创建 `src/checker/type_accessors.uya` 文件，实现所有访问器函数
- [ ] 创建 `src/checker/type_constructors.uya` 文件，实现所有构造函数
- [ ] 修改现有构造函数，同时设置新旧字段
- [ ] 运行 `make check` 验证

**验证标准**：
- `make check` 通过
- 所有现有代码继续工作
- 新字段与新类型匹配

#### Step 2: 迁移高访问字段（2 天）

**目标**：将高频字段访问替换为访问器函数

**高频字段**（按访问次数排序）：
1. `struct_name` (52 次) → `type_get_name()`
2. `pointer_to` (47 次) → `type_get_pointer_to()`
3. `element_type` (35 次) → `type_get_array_element()`
4. `slice_element_type` (23 次) → `type_get_slice_element()`
5. `struct_type_args` (23 次) → `type_get_struct_type_args()`
6. `error_union_payload_type` (21 次) → `type_get_error_payload()`
7. `enum_name` (21 次) → `type_get_name()`

**迁移策略**：
```uya
// 迁移前
if t.kind == TypeKind.TYPE_STRUCT {
    process(t.struct_name);
}

// 迁移后
if t.kind == TypeKind.TYPE_STRUCT {
    process(type_get_name(&t));
}
```

**任务清单**：
- [ ] 迁移 `src/checker/check_expr.uya` 中的高频字段访问
- [ ] 迁移 `src/checker/check_call.uya` 中的高频字段访问
- [ ] 迁移 `src/checker/type_utils.uya` 中的高频字段访问
- [ ] 迁移 `src/codegen/c99/` 中的高频字段访问
- [ ] 运行 `make check` 验证每个文件

#### Step 3: 迁移中访问字段（1 天）

**中频字段**：
- `struct_type_arg_count` (19 次)
- `array_size` (12 次)
- `tuple_element_types` (14 次)
- `tuple_count` (11 次)
- `atomic_inner_type` (11 次)
- `generic_param_name` (11 次)

**任务清单**：
- [ ] 迁移所有中频字段访问
- [ ] 运行 `make check` 验证

#### Step 4: 迁移低访问字段（1 天）

**低频字段**：
- `union_name` (8 次)
- `is_ffi_pointer` (8 次)
- `interface_name` (8 次)
- `slice_len` (3 次)
- `error_error_id` (3 次)

**任务清单**：
- [ ] 迁移所有低频字段访问
- [ ] 运行 `make check` 验证

#### Step 5: 移除旧字段 + 验证（1-2 天）

**目标**：完成迁移，移除旧字段

**任务清单**：
- [ ] 确认所有字段访问都已迁移到访问器
- [ ] 移除 `Type` 结构体中的旧字段
- [ ] 移除构造函数中的旧字段设置
- [ ] 运行 `make check` 完整验证
- [ ] 运行 `make backup` 备份

**验证标准**：
- `make check` 通过
- `make backup` 成功
- 自举编译器体积无明显增加

---

## 三、阶段 4.2：ASTNode 结构体 Union 化

### 3.1 字段组访问频率分析

| 分组 | 字段组 | 访问次数 | 迁移优先级 |
|------|--------|----------|------------|
| **高频** | `fn_decl_*` | 416 | P0 |
| **高频** | `var_decl_*` | 332 | P0 |
| **高频** | `program_*` | 251 | P0 |
| **高频** | `struct_decl_*` | 219 | P0 |
| **高频** | `identifier_*` | 178 | P0 |
| **中频** | `block_*` | 156 | P1 |
| **中频** | `call_expr_*` | 152 | P1 |
| **中频** | `cast_expr_*` | 147 | P1 |
| **中频** | `union_decl_*` | 126 | P1 |
| **中频** | `type_named_*` | 122 | P1 |
| **中频** | `for_stmt_*` | 109 | P1 |
| **中频** | `match_expr_*` | 104 | P1 |
| **中频** | `member_access_*` | 97 | P1 |
| **中频** | `binary_expr_*` | 88 | P1 |
| **中频** | `interface_decl_*` | 88 | P1 |
| **低频** | `struct_init_*` | 84 | P2 |
| **低频** | `array_literal_*` | 81 | P2 |
| **低频** | `method_block_*` | 73 | P2 |
| **低频** | `assign_*` | 62 | P2 |
| **低频** | `string_literal_*` | 60 | P2 |
| **低频** | `if_stmt_*` | 58 | P2 |
| **低频** | `type_pointer_*` | 58 | P2 |
| **低频** | `type_array_*` | 58 | P2 |
| **低频** | `return_stmt_*` | 52 | P2 |
| **低频** | `enum_decl_*` | 45 | P2 |
| **低频** | `while_stmt_*` | 45 | P2 |
| **极低** | 其他字段组 | < 50 | P3 |

### 3.2 新 ASTNode 结构体设计

```uya
// 新设计：使用 union 封装节点数据
struct ASTNode {
    type: ASTNodeType,
    line: i32,
    column: i32,
    filename: &byte,
    data: ASTNodeData,  // 新增：union 类型
    // === 以下为过渡期保留的旧字段（迁移完成后移除）===
    // @deprecated: 使用 data 访问
    // ... 保留所有现有字段 ...
}

// AST 节点数据联合体
union ASTNodeData {
    // 声明节点
    program: ProgramData,
    enum_decl: EnumDeclData,
    error_decl: ErrorDeclData,
    interface_decl: InterfaceDeclData,
    struct_decl: StructDeclData,
    union_decl: UnionDeclData,
    method_block: MethodBlockData,
    fn_decl: FnDeclData,
    macro_decl: MacroDeclData,
    type_alias: TypeAliasData,
    
    // 语句节点
    var_decl: VarDeclData,
    extern_var_decl: ExternVarDeclData,
    destructure_decl: DestructureDeclData,
    use_stmt: UseStmtData,
    if_stmt: IfStmtData,
    while_stmt: WhileStmtData,
    for_stmt: ForStmtData,
    return_stmt: ReturnStmtData,
    defer_stmt: DeferStmtData,
    errdefer_stmt: ErrdeferStmtData,
    test_stmt: TestStmtData,
    assign: AssignData,
    block: BlockData,
    
    // 表达式节点
    binary_expr: BinaryExprData,
    unary_expr: UnaryExprData,
    try_expr: TryExprData,
    catch_expr: CatchExprData,
    await_expr: AwaitExprData,
    error_value: ErrorValueData,
    match_expr: MatchExprData,
    call_expr: CallExprData,
    member_access: MemberAccessData,
    array_access: ArrayAccessData,
    slice_expr: SliceExprData,
    struct_init: StructInitData,
    array_literal: ArrayLiteralData,
    tuple_literal: TupleLiteralData,
    sizeof_expr: SizeofExprData,
    len_expr: LenExprData,
    alignof_expr: AlignofExprData,
    cast_expr: CastExprData,
    
    // 字面量节点
    identifier: IdentifierData,
    number: NumberData,
    float_literal: FloatLiteralData,
    bool_literal: BoolLiteralData,
    int_limit: IntLimitData,
    string_literal: StringLiteralData,
    string_interp: StringInterpData,
    
    // 类型节点
    type_named: TypeNamedData,
    type_pointer: TypePointerData,
    type_array: TypeArrayData,
    type_slice: TypeSliceData,
    type_tuple: TypeTupleData,
    type_error_union: TypeErrorUnionData,
    type_atomic: TypeAtomicData,
    
    // 内建函数节点
    mc_eval: McEvalData,
    mc_code: McCodeData,
    mc_ast: McAstData,
    mc_error: McErrorData,
    mc_interp: McInterpData,
    mc_type: McTypeData,
    syscall: SyscallData,
    ptr_from_usize: PtrFromUsizeData,
    usize_from_ptr: UsizeFromPtrData,
    va_start: VaStartData,
    va_end: VaEndData,
    va_arg: VaArgData,
    print: PrintData,
}

// ===== 数据结构体定义 =====

struct ProgramData {
    decls: & & ASTNode,
    count: i32,
}

struct EnumDeclData {
    name: &byte,
    variants: &EnumVariant,
    variant_count: i32,
    is_export: i32,
}

struct FnDeclData {
    name: &byte,
    type_params: &TypeParam,
    type_param_count: i32,
    params: & & ASTNode,
    param_count: i32,
    return_type: &ASTNode,
    body: &ASTNode,
    is_varargs: i32,
    is_export: i32,
    is_extern: i32,
    is_async: i32,
    extern_lib_name: &byte,
}

struct VarDeclData {
    name: &byte,
    var_type: &ASTNode,
    init: &ASTNode,
    is_const: i32,
    was_moved: i32,
    is_export: i32,
}

struct IdentifierData {
    name: &byte,
}

struct BinaryExprData {
    left: &ASTNode,
    op: i32,
    right: &ASTNode,
}

// ... 其他数据结构体类似 ...
```

### 3.3 访问器函数设计

```uya
// ===== 声明节点访问器 =====

// 函数声明访问器
fn node_get_fn_decl_name(node: &ASTNode) &byte {
    if node.type != ASTNodeType.AST_FN_DECL { return null; }
    match node.data {
        .fn_decl(fd) => return fd.name,
        else => return null,
    }
}

fn node_get_fn_decl_params(node: &ASTNode) & & ASTNode {
    if node.type != ASTNodeType.AST_FN_DECL { return null; }
    match node.data {
        .fn_decl(fd) => return fd.params,
        else => return null,
    }
}

fn node_get_fn_decl_param_count(node: &ASTNode) i32 {
    if node.type != ASTNodeType.AST_FN_DECL { return 0; }
    match node.data {
        .fn_decl(fd) => return fd.param_count,
        else => return 0,
    }
}

fn node_get_fn_decl_return_type(node: &ASTNode) &ASTNode {
    if node.type != ASTNodeType.AST_FN_DECL { return null; }
    match node.data {
        .fn_decl(fd) => return fd.return_type,
        else => return null,
    }
}

fn node_get_fn_decl_body(node: &ASTNode) &ASTNode {
    if node.type != ASTNodeType.AST_FN_DECL { return null; }
    match node.data {
        .fn_decl(fd) => return fd.body,
        else => return null,
    }
}

// 变量声明访问器
fn node_get_var_decl_name(node: &ASTNode) &byte {
    if node.type != ASTNodeType.AST_VAR_DECL { return null; }
    match node.data {
        .var_decl(vd) => return vd.name,
        else => return null,
    }
}

fn node_get_var_decl_type(node: &ASTNode) &ASTNode {
    if node.type != ASTNodeType.AST_VAR_DECL { return null; }
    match node.data {
        .var_decl(vd) => return vd.var_type,
        else => return null,
    }
}

fn node_get_var_decl_init(node: &ASTNode) &ASTNode {
    if node.type != ASTNodeType.AST_VAR_DECL { return null; }
    match node.data {
        .var_decl(vd) => return vd.init,
        else => return null,
    }
}

// ===== 表达式节点访问器 =====

// 标识符访问器
fn node_get_identifier_name(node: &ASTNode) &byte {
    if node.type != ASTNodeType.AST_IDENTIFIER { return null; }
    match node.data {
        .identifier(id) => return id.name,
        else => return null,
    }
}

// 二元表达式访问器
fn node_get_binary_left(node: &ASTNode) &ASTNode {
    if node.type != ASTNodeType.AST_BINARY_EXPR { return null; }
    match node.data {
        .binary_expr(be) => return be.left,
        else => return null,
    }
}

fn node_get_binary_op(node: &ASTNode) i32 {
    if node.type != ASTNodeType.AST_BINARY_EXPR { return 0; }
    match node.data {
        .binary_expr(be) => return be.op,
        else => return 0,
    }
}

fn node_get_binary_right(node: &ASTNode) &ASTNode {
    if node.type != ASTNodeType.AST_BINARY_EXPR { return null; }
    match node.data {
        .binary_expr(be) => return be.right,
        else => return null,
    }
}

// ... 其他访问器类似 ...
```

### 3.4 迁移步骤详解

#### Step 1: 添加 ASTNodeData union + 辅助函数（2 天）

**目标**：添加新的 union 类型、数据结构体和访问器函数

**任务清单**：
- [ ] 在 `src/ast.uya` 添加 `ASTNodeData` union 和所有数据结构体
- [ ] 在 `ASTNode` 结构体中添加 `data: ASTNodeData` 字段
- [ ] 创建 `src/ast_accessors.uya` 文件，实现所有访问器函数
- [ ] 创建 `src/ast_constructors.uya` 文件，实现所有构造函数
- [ ] 修改 `ast_new_node` 函数，初始化 data 字段
- [ ] 运行 `make check` 验证

#### Step 2: 迁移声明节点（3 天）

**高频声明节点**：
- `fn_decl_*` (416 次)
- `var_decl_*` (332 次)
- `program_*` (251 次)
- `struct_decl_*` (219 次)

**任务清单**：
- [ ] 迁移 `fn_decl_*` 字段访问（416 次）
- [ ] 迁移 `var_decl_*` 字段访问（332 次）
- [ ] 迁移 `program_*` 字段访问（251 次）
- [ ] 迁移 `struct_decl_*` 字段访问（219 次）
- [ ] 迁移 `identifier_*` 字段访问（178 次）
- [ ] 运行 `make check` 验证每个节点组

#### Step 3: 迁移表达式节点（3 天）

**中频表达式节点**：
- `call_expr_*` (152 次)
- `cast_expr_*` (147 次)
- `match_expr_*` (104 次)
- `member_access_*` (97 次)
- `binary_expr_*` (88 次)

**任务清单**：
- [ ] 迁移 `call_expr_*` 字段访问
- [ ] 迁移 `cast_expr_*` 字段访问
- [ ] 迁移 `match_expr_*` 字段访问
- [ ] 迁移 `member_access_*` 字段访问
- [ ] 迁移 `binary_expr_*` 字段访问
- [ ] 迁移其他表达式节点
- [ ] 运行 `make check` 验证

#### Step 4: 迁移语句节点（2 天）

**任务清单**：
- [ ] 迁移 `block_*` 字段访问（156 次）
- [ ] 迁移 `for_stmt_*` 字段访问（109 次）
- [ ] 迁移 `if_stmt_*` 字段访问（58 次）
- [ ] 迁移 `return_stmt_*` 字段访问（52 次）
- [ ] 迁移其他语句节点
- [ ] 运行 `make check` 验证

#### Step 5: 移除旧字段 + 验证（2-3 天）

**任务清单**：
- [ ] 确认所有字段访问都已迁移到访问器
- [ ] 移除 `ASTNode` 结构体中的旧字段
- [ ] 移除 `ast_new_node` 中的旧字段初始化
- [ ] 运行 `make check` 完整验证
- [ ] 运行 `make backup` 备份

---

## 四、验证与回滚策略

### 4.1 每步验证

每个迁移步骤完成后，必须执行：

```bash
# 完整验证
make check

# 如果失败，回滚到上一个提交
git checkout -- .

# 或者保留当前更改，继续调试
make b  # 仅自举验证
make tests  # 仅测试验证
```

### 4.2 增量提交

```bash
# 每完成一个文件或一个节点组，提交一次
git add src/checker/type_accessors.uya
git commit -m "refactor(type): 添加 Type 访问器函数"

git add src/checker/check_expr.uya
git commit -m "refactor(checker): 迁移 check_expr 中的 Type 字段访问"
```

### 4.3 问题排查

如果 `make check` 失败：

1. **自举失败**：检查构造函数是否同时设置新旧字段
2. **测试失败**：检查访问器函数返回值是否正确
3. **编译错误**：检查类型匹配和 match 完备性

---

## 五、风险评估与缓解

### 5.1 已识别风险

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|----------|
| 访问器函数遗漏字段 | 中 | 高 | 使用搜索工具确保所有字段都有对应访问器 |
| 构造函数未设置新字段 | 中 | 高 | 每个构造函数添加断言验证 |
| match 分支不完整 | 低 | 高 | 编译器会检查 match 完备性 |
| 性能回归 | 低 | 中 | 访问器函数内联，无运行时开销 |

### 5.2 回滚点

每个 Step 完成后创建标签：

```bash
git tag stage4.1.step1
git tag stage4.1.step2
# ...
```

---

## 六、预期收益

### 6.1 内存节省

| 结构体 | 当前大小 | 重构后大小 | 节省 |
|--------|----------|------------|------|
| Type | ~144 字节 | ~72 字节 | 50% |
| ASTNode | ~800 字节 | ~200 字节 | 75% |

### 6.2 代码质量

- **类型安全**：编译器检查字段访问合法性
- **match 完备性**：所有变体分支必须处理
- **代码简洁**：消除大量 `if kind == XXX` 条件判断

### 6.3 维护性

- **新字段添加**：只需修改对应数据结构体
- **重构影响面**：访问器函数隔离变更
- **调试便利**：数据结构更清晰

---

## 七、时间估算

| 阶段 | 任务 | 预估时间 |
|------|------|----------|
| 4.1 | Type 结构体 Union 化 | 5-7 天 |
| 4.2 | ASTNode 结构体 Union 化 | 10-13 天 |
| **总计** | | **15-20 天** |

对比原估算：
- **原估算**：45-65 天（风险极高）
- **新估算**：15-20 天（风险可控）

**时间节省原因**：
1. 增量式迁移，每步都可独立验证
2. 访问器函数封装，减少直接字段访问
3. 分优先级迁移，高频字段优先处理
