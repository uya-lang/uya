# ASTNode 内存优化方案

## 当前状态
- ASTNode 大小: 1416 字节
- 目标: 100-150 字节
- 优化方式: 使用 union 按节点类型分组
- 验证结果: OptimizedASTNode 测试通过，112 字节
- **当前阶段**: 第一阶段完成，开始第二阶段

## 已完成的准备工作
1. ✅ 编译器 bug 修复：union 值类型结构体变体代码生成顺序（拓扑排序）
2. ✅ 编译器 bug 修复：union 变体依赖结构体数组大小限制（64→128）
3. ✅ 测试文件 test_optimized_astnode.uya 验证通过
4. ✅ 测试文件 test_union_nested_deps.uya 验证嵌套依赖
5. ✅ **第一阶段完成**：`src/ast_data.uya` 定义了 67 个 `AST*Data` 结构体和 `ASTNodeData` union

## 技术限制
- Union 变体不能包含引用类型 `&T`，必须使用 FFI 指针 `*T`
- 字段访问需要使用 match 表达式

## 新结构设计

```uya
// 公共字段
struct ASTNode {
    type: ASTNodeType,
    line: i32,
    column: i32,
    filename: *byte,          // 改为 FFI 指针（可在 union 中使用）
    data: ASTNodeData,        // union
}

// 各节点类型的数据结构（使用 *ASTNode 而非 &ASTNode）
struct ProgramData {
    decls: **ASTNode,
    decl_count: i32,
}

struct EnumDeclData {
    name: *byte,
    variants: *EnumVariant,
    variant_count: i32,
    is_export: i32,
}

struct StructDeclData {
    name: *byte,
    type_params: *TypeParam,
    type_param_count: i32,
    interface_names: **byte,
    interface_count: i32,
    fields: **ASTNode,
    field_count: i32,
    methods: **ASTNode,
    method_count: i32,
    is_export: i32,
}

struct FnDeclData {
    name: *byte,
    type_params: *TypeParam,
    type_param_count: i32,
    params: **ASTNode,
    param_count: i32,
    return_type: *ASTNode,
    body: *ASTNode,
    is_varargs: i32,
    is_export: i32,
    is_extern: i32,
    is_async: i32,
    extern_lib_name: *byte,
}

struct VarDeclData {
    name: *byte,
    var_type: *ASTNode,
    init: *ASTNode,
    is_const: i32,
    was_moved: i32,
    is_export: i32,
}

struct BinaryExprData {
    left: *ASTNode,
    op: i32,
    right: *ASTNode,
}

struct CallExprData {
    callee: *ASTNode,
    args: **ASTNode,
    arg_count: i32,
    has_ellipsis_forward: i32,
    type_args: **ASTNode,
    type_arg_count: i32,
}

struct IdentifierData {
    name: *byte,
}

struct NumberData {
    value: i32,
}

// ... 其他节点类型 ...

// Union 组合所有数据结构
union ASTNodeData {
    program: ProgramData,
    enum_decl: EnumDeclData,
    struct_decl: StructDeclData,
    fn_decl: FnDeclData,
    var_decl: VarDeclData,
    binary_expr: BinaryExprData,
    call_expr: CallExprData,
    identifier: IdentifierData,
    number: NumberData,
    // ... 其他变体 ...
}
```

## 实施步骤

### 第一阶段：数据结构定义 ✅ 已完成
1. ✅ 在 `src/ast_data.uya` 中添加了所有 67 个 `AST*Data` 结构体定义
2. ✅ 定义了 `ASTNodeData` union（包含 67 个变体）
3. ✅ 修复了编译器 bug（union 变体依赖结构体数组大小限制）
4. ✅ 测试验证：编译通过，结构体大小测量正常

**下一步**: 将 `ast_data.uya` 中的定义集成到 `ast.uya` 中

### 第二阶段：辅助函数（预计 1 天）
1. 创建 `ast_get_*` 访问函数
2. 创建 `ast_set_*` 设置函数
3. 创建 `ast_new_*` 构造函数
4. 创建测试验证辅助函数正确性

### 第三阶段：Parser 迁移（预计 2-3 天）
1. 修改 `ast_new_node` 使用新结构
2. 修改所有节点创建代码
3. 验证解析正确性

### 第四阶段：Checker 迁移（预计 2-3 天）
1. 修改所有字段访问代码
2. 验证类型检查正确性

### 第五阶段：Codegen 迁移（预计 2-3 天）
1. 修改所有字段访问代码
2. 验证代码生成正确性

### 第六阶段：清理与验证（预计 1 天）
1. 移除旧的扁平字段
2. 运行所有测试
3. 验证自举
4. 性能测试

## 风险与缓解
1. **风险**：大规模修改可能引入 bug
   **缓解**：分阶段实施，每阶段验证测试
   
2. **风险**：FFI 指针与引用语义不同
   **缓解**：创建辅助函数封装访问

3. **风险**：性能可能受影响
   **缓解**：完成后进行性能对比测试

## 注意事项
1. 所有 `&ASTNode` 需改为 `*ASTNode`（FFI 指针）
2. 字段访问从 `node.field` 改为 `node.data.variant.field`
3. match 表达式用于访问 union 变体
4. 保持向后兼容，逐步迁移

## 进度记录

### 2026-02-15
- ✅ 修复编译器 bug：`emit_struct_deps_for_union` 数组大小限制（64→128）
- ✅ 完成 `src/ast_data.uya` 数据结构定义（67 个结构体 + 1 个 union）
- ✅ uya-main 分支修复验证通过（357/357 测试）
- ✅ astnode_size 分支同步验证通过（357/357 测试）
- ✅ 自举验证通过，备份完成

### 发现的问题与解决方案
1. **问题**: union 变体超过 64 个时，依赖结构体收集不完整
   **解决**: 将 `struct_names` 数组大小从 64 增加到 128

2. **问题**: union 变体中的结构体定义顺序错误
   **解决**: 之前已修复 `collect_value_struct_deps_from_type` 的拓扑排序问题
