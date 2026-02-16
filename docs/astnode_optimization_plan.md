# ASTNode 内存优化方案

## 当前状态
- ASTNode 大小: 1416 字节
- 目标: 80-100 字节
- 优化方式: 使用 union 按节点类型分组
- 验证结果: OptimizedASTNode 测试通过，80 字节
- **当前阶段**: 第三阶段进行中

## 已完成
1. ✅ **第一阶段**：数据结构定义（77 个结构体 + 1 个 union）
2. ✅ **第二阶段**：辅助函数（77 个 `ast_new_*_optimized` 创建函数）
3. ✅ **第三阶段 Step 3.1**：访问函数层（106 个 `ast_get/set_*_compat` 函数）
4. ✅ **第三阶段 Step 3.2**：确认字段访问分类

## 字段访问分类

经过分析，发现字段访问分为两类：

| 类型 | 结构体 | 是否需要 compat | 说明 |
|------|--------|----------------|------|
| ASTNode 字段 | `ASTNode` | ✅ 需要 | 优化目标 |
| Type 字段 | `Type` | ❌ 不需要 | 不在优化范围内 |

常见混淆字段：
- `.struct_name` → `Type` 结构体字段
- `.pointer_to` → `Type` 结构体字段
- `.element_type` → `Type` 结构体字段
- `.error_union_payload_type` → `Type` 结构体字段

ASTNode 中对应字段：
- `.struct_decl_name` → ASTNode 字段
- `.type_pointer_pointed_type` → ASTNode 字段
- `.type_array_element_type` → ASTNode 字段
- `.type_error_union_payload_type` → ASTNode 字段

## 待完成
- ⏳ **第三阶段 Step 3.3**：修改 ASTNode 结构体定义（需要进一步研究）
- ⏳ **第四阶段**：修复编译错误
- ⏳ **第五阶段**：测试验证
- ⏳ **第六阶段**：清理与验证

## 发现的问题

### Uya 类型别名机制

**验证结果**：类型别名机制正常工作。

**测试**：
```uya
struct Point { x: i32, y: i32 }
type Pt = Point;
// 生成: typedef struct Point Pt;
```

**ASTNode 类型别名问题**：
- `ASTStringInterpSegment` 在 `ASTNode` 定义前引用 `&ASTNode`
- 前向引用可能导致类型别名无法正确解析
- 编译器内部大量使用 `ASTNode`，类型别名可能影响代码生成

### 迁移障碍

| 问题 | 影响 | 解决方案 |
|------|------|----------|
| 类型别名不生效 | 无法通过别名切换实现 | 直接修改结构体 |
| 6000+ 字段访问 | 修改工作量大 | 渐进式迁移 |
| 编译器内部依赖 | 风险高 | 充分测试 |

### 可选方案

1. **方案 A**：修改编译器支持类型别名代码生成
2. **方案 B**：直接修改所有字段访问
3. **方案 C**：分阶段迁移（当前选择）

## 访问函数覆盖情况

已添加访问函数的节点类型：
- ✅ identifier, number, string, bool
- ✅ binary_expr, unary_expr
- ✅ var_decl, fn_decl
- ✅ program, call_expr
- ✅ type_named, pointer, array/slice
- ✅ member_access
- ✅ struct_decl, union_decl, enum_decl
- ✅ error_union
- ✅ if_stmt, while_stmt, for_stmt, block
- ✅ return_stmt, assign
- ✅ match_expr

---

## 详细实施计划

### 第一阶段：数据结构定义 ✅ 已完成

**已完成内容**：
- `src/ast_data.uya`: 77 个 `AST*DataNew` 结构体
- `src/ast_data.uya`: `ASTNodeDataNew` union（77 个变体）
- `src/ast_data.uya`: `OptimizedASTNode` 结构体（80 字节）

**关键发现**：
- 编译器支持 union 变体包含引用类型 `&T`（无需使用 FFI 指针）

---

### 第二阶段：辅助函数 ✅ 已完成

**已完成内容**：
- `src/ast.uya`: 77 个 `ast_new_*_optimized` 创建函数
- `src/ast.uya`: `ast_new_optimized_base` 基础函数

**函数列表**（按类别）：

| 类别 | 节点类型 | 创建函数 |
|------|----------|----------|
| 字面量 | identifier, number, float, bool, string, int_limit | `ast_new_*_optimized` |
| 表达式 | binary, unary, call, member_access, array_access, slice, cast, struct_init, array_literal, tuple_literal, match, try, catch, error_value, await, sizeof, len, alignof | `ast_new_*_optimized` |
| 语句 | if, while, for, return, break, continue, defer, test, assign, expr_stmt, block | `ast_new_*_optimized` |
| 声明 | program, enum_decl, struct_decl, union_decl, interface_decl, fn_decl, var_decl, type_alias, method_block, macro_decl | `ast_new_*_optimized` |
| 类型 | type_named, type_pointer, type_array, type_slice, type_tuple, type_error_union, type_atomic | `ast_new_*_optimized` |
| 内置 | syscall, ptr_from_usize, usize_from_ptr, va_start, va_end, va_arg, mc_* | `ast_new_*_optimized` |

---

### 第三阶段：Parser 迁移（详细计划）

#### 3.1 迁移策略分析

**当前状态**：
- Parser 使用 `ast_new_node()` 创建节点
- 创建后直接设置扁平字段：`node.identifier_name = name`
- 字段访问使用前缀命名：`identifier_name`, `binary_expr_left`

**目标状态**：
- 使用 `ast_new_*_optimized()` 创建节点
- 创建时传入所有参数，无需后续设置
- 返回类型为 `&OptimizedASTNode`

**挑战**：
1. 字段名映射（旧名 vs 新名）
2. 返回类型变化（`&ASTNode` → `&OptimizedASTNode`）
3. 代码量大（parser.uya 266KB）

#### 3.2 字段名映射表

| 节点类型 | 旧字段名 | 新字段名（union 结构体内） |
|----------|----------|---------------------------|
| identifier | `identifier_name` | `data.identifier.name` |
| number | `number_value` | `data.number.value` |
| binary_expr | `binary_expr_left/op/right` | `data.binary_expr.left/op/right` |
| call_expr | `call_expr_callee/args/...` | `data.call_expr.callee/args/...` |
| fn_decl | `fn_decl_name/params/...` | `data.fn_decl.name/params/...` |
| var_decl | `var_decl_name/type/init/...` | `data.var_decl.name/type/init/...` |

#### 3.3 迁移方案选择

**方案 A：渐进式迁移（推荐）**
1. 保持 `ASTNode` 扁平结构不变
2. 添加访问函数层
3. 逐步迁移各模块

**方案 B：一次性替换**
1. 直接修改 `ASTNode` 为 union 结构
2. 批量替换所有字段访问
3. 风险高，不推荐

#### 3.4 渐进式迁移步骤

**Step 3.1**: 添加访问函数层

```uya
// getter 函数示例
fn ast_get_identifier_name(node: &ASTNode) &byte {
    return node.identifier_name;  // 暂时直接访问
}

// setter 函数示例
fn ast_set_identifier_name(node: &ASTNode, name: &byte) void {
    node.identifier_name = name;
}
```

**Step 3.2**: 为每种节点类型添加访问函数

| 访问函数 | 参数 | 返回值 |
|----------|------|--------|
| `ast_get_identifier_name` | `node: &ASTNode` | `&byte` |
| `ast_get_number_value` | `node: &ASTNode` | `i32` |
| `ast_get_binary_left` | `node: &ASTNode` | `&ASTNode` |
| `ast_get_fn_decl_name` | `node: &ASTNode` | `&byte` |
| ... | ... | ... |

**Step 3.3**: 修改 Parser 使用访问函数

```uya
// 旧代码
const node: &ASTNode = ast_new_node(ASTNodeType.AST_IDENTIFIER, line, column, arena, filename);
node.identifier_name = name;

// 新代码（渐进式）
const node: &ASTNode = ast_new_node(ASTNodeType.AST_IDENTIFIER, line, column, arena, filename);
ast_set_identifier_name(node, name);

// 最终代码
const node: &ASTNode = ast_new_identifier_optimized(name, line, column, filename, arena);
```

#### 3.5 迁移工作量估算

| 模块 | 文件大小 | 字段访问数 | 预计工时 |
|------|----------|------------|----------|
| Parser | 266KB | ~500 | 1天 |
| Checker | 409KB | ~1500 | 2天 |
| Codegen | ~200KB | ~800 | 1天 |
| **总计** | ~875KB | ~2800 | 4天 |

---

### 第四阶段：Checker 迁移

#### 4.1 迁移步骤

**Step 4.1**: 添加访问函数调用

将所有直接字段访问改为函数调用：
```uya
// 旧代码
if node.type == ASTNodeType.AST_IDENTIFIER {
    name = node.identifier_name;
}

// 新代码
if node.type == ASTNodeType.AST_IDENTIFIER {
    name = ast_get_identifier_name(node);
}
```

**Step 4.2**: 验证类型检查正确性

运行所有测试确保语义正确：
```bash
make tests-uya  # 应全部通过
```

**Step 4.3**: 性能测试

对比迁移前后的编译速度。

---

### 第五阶段：Codegen 迁移

#### 5.1 迁移步骤

与第四阶段类似，修改 `src/codegen/` 目录下的所有文件。

**关键文件**：
- `codegen/c99/main.uya`
- `codegen/c99/expr.uya`
- `codegen/c99/stmt.uya`
- `codegen/c99/function.uya`
- `codegen/c99/structs.uya`

---

### 第六阶段：清理与验证

#### 6.1 移除旧结构

1. 删除 `ASTNode` 扁平结构中的冗余字段
2. 将 `OptimizedASTNode` 重命名为 `ASTNode`
3. 删除 `ast_new_node` 旧函数

#### 6.2 验证步骤

```bash
# 1. 构建新编译器
make uya

# 2. 自举验证
make b

# 3. 运行所有测试
make tests-uya

# 4. 备份
make backup
```

#### 6.3 性能对比

| 指标 | 迁移前 | 迁移后 | 变化 |
|------|--------|--------|------|
| ASTNode 大小 | 1416 字节 | 80 字节 | -94% |
| 编译器内存占用 | 待测 | 待测 | - |
| 编译速度 | 待测 | 待测 | - |

---

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 大规模修改引入 bug | 高 | 分阶段实施，每阶段验证测试 |
| 访问函数性能开销 | 中 | 内联优化，性能测试对比 |
| 迁移不完整 | 高 | 逐步迁移，保持兼容性 |
| 自举失败 | 高 | 每次修改后立即验证 |

---

## 进度记录

### 2026-02-16 (晚上)
- ✅ 完成 77 个 `ast_new_*_optimized` 创建函数
- ✅ 细化迁移计划文档
- ✅ 添加访问函数层（106 个 `ast_get/set_*_compat` 函数）
  - identifier, number, string, bool 节点
  - binary_expr, unary_expr 节点
  - var_decl, fn_decl 节点
  - program, call_expr 节点
  - type_named, pointer, array/slice 节点
  - member_access 节点
  - struct_decl, union_decl, enum_decl 节点
  - if_stmt, while_stmt, for_stmt, block 节点
  - return_stmt, assign, match_expr 节点
- ✅ 修复字段名错误（enum_decl, union_decl, struct_decl, type_* 等）
- ✅ 编译验证通过（364/364 测试）
- ✅ 自举验证通过，备份完成
- ⏳ 下一步：在关键模块中使用访问函数

### 2026-02-16 (下午)
- ✅ 在 `src/ast.uya` 中添加优化数据结构定义和辅助函数
- ✅ 使用 main 分支编译器构建成功（363/363 测试通过）

### 2026-02-15
- ✅ 完成 `src/ast_data.uya` 数据结构定义（77 个结构体 + 1 个 union）
- ✅ 修复编译器 bug：union 变体依赖结构体数组大小限制
- ✅ 修复编译器 bug：match 表达式类型推断

---

## 附录：技术细节

### A. Union 访问语法

```uya
// 创建 union 数据
const data: ASTNodeDataNew = ASTNodeDataNew.number(ASTNumberDataNew { value: 42 });

// 使用 match 访问
const value: i32 = match data {
    .number(d) => d.value as i32,
    else => 0 as i32,
};
```

### B. 节点创建函数签名

```uya
// 简单节点
fn ast_new_identifier_optimized(name: &byte, line: i32, column: i32, filename: &byte, arena: &Arena) &OptimizedASTNode;

// 复杂节点
fn ast_new_fn_decl_optimized(
    name: &byte,
    type_params: &TypeParam,
    type_param_count: i32,
    params: &&ASTNode,
    param_count: i32,
    return_type: &ASTNode,
    body: &ASTNode,
    is_varargs: i32,
    is_export: i32,
    is_extern: i32,
    is_async: i32,
    extern_lib_name: &byte,
    line: i32,
    column: i32,
    filename: &byte,
    arena: &Arena
) &OptimizedASTNode;
```

### C. 测试验证

```bash
# 运行单个测试
./tests/run_programs_parallel.sh tests/programs/test_ast_access_functions.uya --uya

# 运行所有测试
make tests-uya

# 自举验证
make b

# 完整验证 + 备份
make backup
```
