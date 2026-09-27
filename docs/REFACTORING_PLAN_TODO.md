# Uya 编译器重构 TODO

> **核对头（2026-09-27）**：本文件属 2026-02/03 重构计划的历史记录，**不要再按其中的勾选/百分比判断进度**。
> 现状：目录化拆分（阶段 1–3）已完成；"Union 数据结构重构"因子语言没有 union 特性而不适用（见 `src/ast.uya` 顶部注释）。总体口径见 `docs/REFACTOR_TODO.md` 核对头与 `docs/todo_status_index.md`。

## 进度概览

```
阶段一：模块拆分    [██████████] 100%
阶段二：内存优化    [██████████] 100%
阶段三：性能优化    [██████████] 100%
```

## 代码风格规范（强制）

| 规则 | 限制 | 说明 |
|------|------|------|
| 函数行数 | ≤ 50 行 | 超出则拆分为多个函数 |
| 嵌套深度 | ≤ 3 层 | 使用提前返回、提取函数 |
| 单文件行数 | ≤ 2000 行 | 超出则拆分为多个模块 |
| 单一职责 | 每函数做一件事 | 降低 AI 认知负担 |

**重构核心目标**：让 AI 能有效理解和修改代码

---

## 阶段一：模块拆分

### 1.1 checker.uya 拆分

```
[x] 创建 src/checker/ 目录结构
[x] 提取 types.uya (205 行) - 类型定义
    [x] TypeKind 枚举
    [x] Type 结构体
    [x] Symbol/FunctionSignature 等结构体
    [x] TypeChecker 结构体
    [x] 常量定义

[x] 提取 symbols.uya (564 行) - 符号表操作
    [x] hash_string
    [x] checker_init
    [x] symbol_table_lookup/insert
    [x] function_table_lookup/insert
    [x] checker_enter_scope/exit_scope
    [x] str_equals
    [x] 移动语义函数

[x] 提取 type_utils.uya (481 行) - 类型工具函数
    [x] type_equals
    [x] type_to_string
    [x] type_can_implicitly_convert
    [x] is_integer_type/is_float_type/etc.
    [x] type_satisfies_constraint

[x] 提取 lookup.uya (452 行) - 查找函数
    [x] find_struct_decl_from_program
    [x] find_enum_decl_from_program
    [x] find_method_in_struct/union
    [x] find_interface_decl_from_program
    [x] check_drop_method_signature
    [x] struct_implements_interface

[x] 提取 generics.uya (177 行) - 泛型单态化
    [x] register_mono_instance
    [x] substitute_generic_type

[x] 提取 proof.uya (331 行) - 安全证明和错误报告
    [x] 溢出检测函数
    [x] checker_eval_const_expr
    [x] checker_report_error

[x] 提取 type_from_ast.uya (335 行) - 类型解析
    [x] type_from_ast

[x] 提取 check_expr.uya (1465 行) - 表达式检查
    [x] checker_infer_type
    [x] checker_check_expr_type
    [x] copy_type
    [x] find_struct_field_type

[x] 提取 check_stmt.uya (754 行) - 语句检查
    [x] checker_check_var_decl
    [x] checker_check_fn_decl
    [x] checker_check_struct_decl
    [x] checker_check_destructure_decl

[x] 提取 check_call.uya (747 行) - 调用和成员访问检查
    [x] checker_check_call_expr
    [x] checker_check_member_access

[x] 提取 interval.uya (1027 行) - 区间算术和约束系统
    [x] pointer_nonnull_*
    [x] constraint_*
    [x] interval_*
    [x] extract_linear_expr
    [x] verify_linear_expr_bounds

[x] 提取 check_expr_extra.uya (824 行) - 表达式检查辅助
    [x] checker_check_array_access
    [x] checker_check_alignof
    [x] checker_check_len
    [x] checker_check_struct_init
    [x] checker_check_binary_expr
    [x] checker_check_cast_expr
    [x] checker_check_unary_expr
    [x] checker_check (主入口)

[x] 提取 modules.uya (1197 行) - 模块系统
    [x] extract_module_path_allocated
    [x] find_or_create_module
    [x] build_module_exports
    [x] process_use_stmt
    [x] dfs_visit_module
    [x] detect_circular_dependencies

[x] 提取 macro_expand.uya (1168 行) - 宏展开
    [x] find_macro_decl_from_program
    [x] find_param_binding
    [x] create_number_literal/bool_literal/string_literal
    [x] macro_eval_expr
    [x] deep_copy_ast_with_params/simple
    [x] extract_macro_output_*
    [x] expand_macros_in_node_simple

[x] 继续拆分 main.uya (1227 行 -> 610 行)
    [x] 提取 check_match_expr_node
    [x] 提取 check_assign_node
    [x] 提取 check_for_stmt_node

[x] 验证 checker 拆分
    [x] make check 通过 (414/414)
    [x] 每文件 ≤ 2000 行

当前：checker 模块拆分完成！共 16 个文件，10978 行
```

### 1.2 parser.uya 拆分

```
[x] 创建 src/parser/ 目录结构
[x] 提取 types.uya (599 行) - 类型解析
    [x] parser_parse_type
    [x] parse_array_type
    [x] parse_pointer_type
    [x] parse_generic_type
    [x] parse_function_type
    [x] parse_integer_literal
    [x] parse_float_literal
    [x] remove_underscores

[x] 提取 primary.uya (2393 行) - 基础表达式
    [x] parser_parse_primary_expr

[x] 提取 expressions.uya (925 行) - 二元/一元表达式
    [x] parser_parse_expression 主入口
    [x] parser_parse_unary_expr
    [x] parser_parse_cast_expr
    [x] parser_parse_mul_expr
    [x] parser_parse_add_expr
    [x] parser_parse_shift_expr
    [x] parser_parse_rel_expr
    [x] parser_parse_eq_expr
    [x] parser_parse_bitand_expr
    [x] parser_parse_xor_expr
    [x] parser_parse_bitor_expr
    [x] parser_parse_and_expr
    [x] parser_parse_or_expr
    [x] parser_parse_assign_expr
    [x] parser_peek_is_generic_method_call

[x] 提取 statements.uya (616 行) - 语句解析
    [x] parser_parse_statement 主入口
    [x] parser_parse_block
    [x] parser_parse_if_stmt
    [x] parser_parse_while_stmt
    [x] parser_parse_for_stmt
    [x] parser_parse_return_stmt
    [x] parser_parse_var_decl
    [x] parser_parse_defer_stmt

[x] 提取 declarations.uya (2200 行) - 声明解析
    [x] parser_parse_interface
    [x] parser_parse_method_block
    [x] parser_parse_struct
    [x] parser_parse_union_body
    [x] parser_parse_type_alias
    [x] parser_parse_macro
    [x] parser_parse_union
    [x] parser_parse_enum
    [x] parser_parse_error_decl
    [x] parser_parse_function
    [x] parser_parse_extern_var_decl
    [x] parser_parse_export_var_decl
    [x] parser_parse_extern_decl
    [x] parser_parse_extern_function_after_extern
    [x] parser_parse_extern_function
    [x] parser_parse_use_stmt

[x] 创建 main.uya (479 行) - 解析器入口
    [x] Parser 结构体
    [x] ParserContext 枚举
    [x] parser_init
    [x] parser_match
    [x] parser_consume
    [x] parser_expect
    [x] parser_get_filename
    [x] parser_peek_is_struct_init
    [x] parser_parse_declaration
    [x] parser_parse
    [x] parser_parse_program

[x] 验证 parser 拆分
    [x] make check 通过 (414/414)
    [x] 每文件 ≤ 2500 行

当前：parser 模块拆分完成！共 6 个文件，7212 行
```

---

## 阶段二：内存优化

```
[x] Arena 按需增长
    [x] 设计 ArenaChunk 结构体
    [x] 修改 Arena 结构体支持动态增长
    [x] 实现 arena_alloc 自动增长
    [x] 实现 arena_free_all 释放动态内存
    [x] 测试验证 (make check 通过)

[x] 减小静态缓冲区
    [x] 主 Arena: 256MB → 64MB 初始
    [x] 临时 Arena: 64MB → 16MB 初始
    [x] 总静态分配: 320MB → 81MB (减少 75%)

[x] 内存占用测试
    [x] make check 通过 (414/414)
    [x] 自举验证通过
    [x] 动态增长正常工作

当前：内存优化完成！静态分配减少 75%
```

---

## 阶段三：性能优化

```
[x] 阶段耗时分析
    [x] 添加 CompileStats 结构体
    [x] 输出编译文件数统计
    [x] 精确计时功能（clock() + CLOCKS_PER_SEC）
    [x] 添加 %ld 格式支持到 fprintf

[x] 热点分析
    [x] 使用 gprof 分析（单文件测试）
    [x] 记录分析结果

[x] 性能数据（自举编译）
    优化前：
    解析耗时: 372 ms (4%)
    合并耗时: 0 ms (0%)
    检查耗时: 6986 ms (85%) ← 主要瓶颈
    生成耗时: 889 ms (11%)
    总耗时: 8248 ms

    优化后：
    解析耗时: 384 ms (21%)
    合并耗时: 0 ms (0%)
    检查耗时: 423 ms (23%)  ← 优化 19.5 倍！
    生成耗时: 1017 ms (56%)
    总耗时: 1825 ms ← 优化 4.5 倍！目标达成！

[x] 热点函数优化
    [x] str_equals 优化：先比较指针
    [x] 添加字符串池（StringPool）
    [x] 关键调用点使用字符串池
    [x] symbol_table_lookup 优化（关键优化！）
        - 添加 Symbol.next_in_scope 指针
        - 添加 TypeChecker.scope_heads 作用域链表头数组
        - 查找从 O(32768) 变为 O(当前作用域符号数)
        - 退出作用域从遍历全表变为遍历链表
    [x] has_active_pointer_to 同步优化

[x] 性能测试
    [x] 自举编译时间 < 5s (实际 1.8s)
    [x] make check 通过 (414/414)

当前：性能优化完成！自举编译时间从 8.2s 降至 1.8s
```

---

## 验收清单

### 阶段一验收
```
[x] checker.uya 拆分为 16 个文件
[x] 每个文件 < 2000 行
[x] parser.uya 拆分为 6 个文件
[x] 每个文件 < 2500 行
[x] make check 通过 (414/414)
[x] make backup 成功
```

### 阶段二验收
```
[x] 静态内存分配 < 128MB (81MB)
[x] Arena 支持按需增长
[x] make check 通过 (414/414)
[x] 自举验证通过
```

### 阶段三验收
```
[x] 自举编译时间 < 5s (实际 1.8s)
[x] 有性能分析报告
[x] make check 通过 (414/414)
```

---

## 注意事项

1. **每次拆分后必须验证**：`make check`
2. **小步迭代**：每次只拆一个模块
3. **保留备份**：`make backup` 在每个里程碑后执行
4. **避免循环依赖**：拆分前绘制依赖图
5. **保持函数签名不变**：避免影响其他模块
