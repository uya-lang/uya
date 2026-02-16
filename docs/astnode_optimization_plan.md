# ASTNode 内存优化方案

## 当前状态
- ASTNode 大小: 1416 字节
- 目标: 100-150 字节
- 优化方式: 使用 union 按节点类型分组
- 验证结果: OptimizedASTNode 测试通过，80 字节
- **当前阶段**: 第二阶段进行中

## 已完成的准备工作
1. ✅ 编译器 bug 修复：union 值类型结构体变体代码生成顺序（拓扑排序）
2. ✅ 编译器 bug 修复：union 变体依赖结构体数组大小限制（64→128）
3. ✅ 编译器 bug 修复：match 表达式类型推断中的符号表问题
4. ✅ 测试文件 test_optimized_astnode.uya 验证通过
5. ✅ 测试文件 test_union_nested_deps.uya 验证嵌套依赖
6. ✅ **第一阶段完成**：数据结构定义验证通过
7. ✅ **第二阶段进行中**：辅助函数测试通过（13种节点类型）

## 第二阶段进展
- ✅ 测试文件 `test_ast_helpers.uya` 完成
- ✅ 覆盖 13 种节点类型：identifier, number, string, bool, binary_expr, unary_expr, call_expr, member_access, var_decl, fn_decl, if_stmt, while_stmt, block
- ✅ 验证构造函数、访问函数、设置函数模式
- ✅ 在 `src/ast.uya` 中添加简化版数据结构和辅助函数（渐进式迁移）
- ✅ **扩展数据结构定义**：已定义 34 种节点类型（原 14 种 → 34 种）
  - 新增语句：return_stmt, assign, for_stmt, defer_stmt
  - 新增表达式：array_access, slice_expr, cast_expr, struct_init, array_literal, tuple_literal, match_expr, try_expr, catch_expr, error_value
  - 新增声明：program, enum_decl, struct_decl, union_decl, interface_decl
- ⏳ 待办：继续扩展剩余节点类型
- ⏳ 待办：为每种新类型添加辅助函数

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
1. ~~所有 `&ASTNode` 需改为 `*ASTNode`（FFI 指针）~~ **已验证：编译器支持 union 变体包含 `&T`，无需使用 FFI 指针**
2. 字段访问从 `node.field` 改为 `node.data.variant.field`

## 当前进度（2026-02-16）

### 已完成
- ✅ 第一阶段：数据结构定义（使用 `&T` 而非 `*T`）
- ✅ 第二阶段：辅助函数（60+ getter/setter，16 个创建函数）
- ✅ 关键发现：编译器已支持 union 变体包含引用类型 `&T`

### 待完成
- ⏳ 第三阶段：Parser 迁移
- ⏳ 第四阶段：Checker 迁移
- ⏳ 第五阶段：Codegen 迁移
- ⏳ 第六阶段：清理与验证
3. match 表达式用于访问 union 变体
4. 保持向后兼容，逐步迁移

## 进度记录

### 2026-02-16 (下午)
- ✅ 在 `src/ast.uya` 中添加优化数据结构定义和辅助函数
  - 添加 13 种节点类型的 `*DataNew` 结构体
  - 添加 `ASTNodeDataNew` union
  - 添加 `OptimizedASTNode` 结构体
  - 添加 6 个辅助函数示例
- ✅ 使用 main 分支编译器构建成功（360/360 测试通过）
- ✅ 更新 `bin/uya-c` 为 main 分支最新稳定版
- ⚠️ 注意：astnode_size 分支需要用 main 分支的编译器构建
  - 命令：`/home/winger/uya-main/bin/uya src/main.uya ... -o bin/uya.c --c99`

### 2026-02-16
- ✅ 修复编译器 bug：match 表达式类型推断中的符号表问题
  - 问题：`checker_infer_type` 处理 match 时未为分支变量创建符号表条目
  - 解决：推断类型前进入作用域并创建符号表条目
- ✅ 第二阶段进展：扩展 `test_ast_helpers.uya` 测试覆盖
  - 添加 13 种节点类型的构造/访问/设置函数测试
  - 验证 OptimizedASTNode 大小为 80 字节
- ✅ 测试通过：360/360
- ✅ 自举验证通过

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

3. **问题**: match 表达式中字段访问类型推断失败
   **解决**: 在 `checker_infer_type` 中为 match 分支变量创建符号表条目

4. **问题**: FFI 指针不能作为函数参数或返回类型
   **解决**: 辅助函数避免使用 `*byte` 等类型，改用 i32 或 void
