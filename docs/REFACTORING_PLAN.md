# Uya 编译器重构计划

> **核对头（2026-09-27）**：本计划的"拆大文件 + 降内存 + 提速"三目标已由后续工作覆盖：
> 拆分已完成（`src/checker`、`src/parser`、`src/codegen/c99` 目录化）；内存方面编译器不再使用固定大块预分配，改用 `src/arena.uya` 的 1MB 动态 chunk（`ARENA_CHUNK_SIZE`）；
> 下方验收清单（<128MB / <32MB / <5s）未按本文件的测量方式重新出数，**不要按本文件的复选框判断当前进度**。

## 背景

当前自举编译器存在以下问题：
1. **单文件过大**：checker.uya (11,126行) 和 parser.uya (7,212行) 远超 AI 上下文窗口，无法有效修改
2. **内存占用高**：320MB 固定分配，即使编译小程序也占用相同内存
3. **编译变慢**：自举编译约 10 秒，有优化空间
4. **AI 改不动**：代码量超出 AI 有效处理范围

## 现状分析

| 指标 | 当前值 | 目标值 |
|------|--------|--------|
| 总代码量 | 35,227 行 | 不变 |
| checker.uya | 11,126 行 (488KB) | 拆分为 7 个文件，每个 < 2000 行 |
| parser.uya | 7,212 行 (292KB) | 拆分为 5 个文件，每个 < 2000 行 |
| 内存占用 | 320MB 固定 | < 128MB 动态 |
| 编译时间 | ~10 秒 | < 5 秒 |
| 生成 C 代码 | 39,453 行 (2.4MB) | 不变 |

## 重构阶段

### 阶段一：模块拆分（优先级：高）

**目标**：将大文件拆分为 < 2000 行的小模块，使 AI 能够处理

#### 1.1 checker.uya 拆分

当前文件结构：
```
src/checker.uya (11,126 行)
```

目标文件结构：
```
src/checker/
├── types.uya        (~1500 行) - Type/TypeKind 定义、类型操作函数
│                      - TypeKind 枚举
│                      - Type 结构体
│                      - copy_type, type_equals, type_to_string
│                      - is_integer_type, is_float_type, is_numeric_type
│                      - type_can_implicitly_convert
│
├── symbols.uya      (~1000 行) - 符号表和作用域管理
│                      - Symbol 结构体
│                      - SymbolTable 结构体
│                      - FunctionTable 结构体
│                      - symbol_table_lookup, symbol_table_insert
│                      - function_table_lookup, function_table_insert
│                      - checker_enter_scope, checker_exit_scope
│
├── expressions.uya  (~2000 行) - 表达式类型检查
│                      - check_expression (主入口)
│                      - check_binary_expr, check_unary_expr
│                      - check_call_expr, check_member_expr
│                      - check_identifier, check_literal
│                      - check_array_expr, check_struct_init
│
├── statements.uya   (~1500 行) - 语句类型检查
│                      - check_statement (主入口)
│                      - check_var_decl, check_const_decl
│                      - check_if_stmt, check_while_stmt
│                      - check_for_stmt, check_return_stmt
│                      - check_block
│
├── declarations.uya (~1500 行) - 声明类型检查
│                      - check_declaration (主入口)
│                      - check_function_decl
│                      - check_struct_decl
│                      - check_enum_decl
│                      - check_union_decl
│                      - check_interface_decl
│
├── generics.uya     (~1500 行) - 泛型单态化、约束检查
│                      - MonoInstance 结构体
│                      - instantiate_generic_function
│                      - instantiate_generic_struct
│                      - check_type_param_constraints
│                      - type_satisfies_constraint
│
├── interfaces.uya   (~1000 行) - 接口实现检查
│                      - check_interface_impl
│                      - collect_interface_methods
│                      - verify_method_signatures
│
├── errors.uya       (~800 行)  - 错误处理
│                      - ErrorReport 结构体
│                      - checker_report_error
│                      - get_or_add_error_id
│
└── main.uya         (~1000 行) - 检查器入口、协调逻辑
                       - TypeChecker 结构体
                       - checker_init, checker_check_program
                       - 模块导入导出处理
```

#### 1.2 parser.uya 拆分

当前文件结构：
```
src/parser.uya (7,212 行)
```

目标文件结构：
```
src/parser/
├── types.uya        (~1000 行) - 类型解析
│                      - parser_parse_type
│                      - parse_array_type
│                      - parse_pointer_type
│                      - parse_generic_type
│
├── expressions.uya  (~2500 行) - 表达式解析（最大模块）
│                      - parser_parse_expression (主入口)
│                      - parser_parse_primary_expr
│                      - parser_parse_unary_expr
│                      - parser_parse_binary_expr (各优先级)
│                      - parser_parse_call_expr
│                      - parser_parse_member_expr
│                      - parser_parse_cast_expr
│                      - parse_integer_literal, parse_float_literal
│
├── statements.uya   (~1500 行) - 语句解析
│                      - parser_parse_statement (主入口)
│                      - parser_parse_block
│                      - parser_parse_if_stmt
│                      - parser_parse_while_stmt
│                      - parser_parse_for_stmt
│                      - parser_parse_return_stmt
│                      - parser_parse_var_decl
│
├── declarations.uya (~1500 行) - 声明解析
│                      - parser_parse_declaration (主入口)
│                      - parser_parse_function
│                      - parser_parse_struct
│                      - parser_parse_enum
│                      - parser_parse_union
│                      - parser_parse_interface
│                      - parser_parse_use_stmt
│                      - parser_parse_extern_decl
│
└── main.uya         (~700 行)  - 解析器入口
                       - Parser 结构体
                       - ParserContext 枚举
                       - parser_init, parser_parse, parser_parse_program
                       - parser_match, parser_consume, parser_expect
```

---

### 阶段二：内存优化（优先级：中）

**目标**：将固定内存占用从 320MB 降至 < 128MB

#### 2.1 Arena 按需增长

当前实现：
```uya
// main.uya
const ARENA_BUFFER_SIZE: i32 = 256 * 1024 * 1024;  // 256MB
var arena_buffer: [byte: ARENA_BUFFER_SIZE] = [];
```

目标实现：
```uya
// arena.uya
struct Arena {
    buffer: &byte,        // 当前缓冲区
    capacity: usize,      // 当前容量
    used: usize,          // 已使用
    next_chunk: &ArenaChunk,  // 下一块（链表）
}

// 初始分配 16MB，按需增长
fn arena_grow(arena: &Arena, needed: usize) i32;
```

#### 2.2 临时 Arena 优化

当前实现：
```uya
var temp_arena_buffer: [byte: 64 * 1024 * 1024] = [];  // 64MB
```

目标实现：
```uya
// 使用栈分配或复用主 Arena 的空闲区域
fn with_temp_arena<T>(f: fn(&Arena) T) T;
```

#### 2.3 大数组动态化

当前实现：
```uya
var main_file_paths_global: [[byte: PATH_MAX]: MAX_INPUT_FILES] = [];  // 262KB
var resolved_files_global: [&byte: MAX_INPUT_FILES] = [];
```

目标实现：
```uya
// 动态分配
var main_file_paths: &&byte = null;  // 按需分配
fn ensure_file_paths_capacity(capacity: i32) void;
```

---

### 阶段三：性能优化（优先级：低）

**目标**：编译时间从 10s 降至 < 5s

#### 3.1 阶段耗时分析

添加计时日志到各编译阶段：
```uya
// main.uya
struct CompileStats {
    parse_time_ms: i32,
    merge_time_ms: i32,
    check_time_ms: i32,
    codegen_time_ms: i32,
}
```

#### 3.2 热点函数优化

已知热点函数（待验证）：
- `type_equals` - 类型比较，高频调用
- `symbol_table_lookup` - 符号查找，线性搜索 → 可考虑哈希优化
- `checker_arena_strdup` - 字符串复制

优化方案：
1. `type_equals`: 缓存比较结果
2. `symbol_table_lookup`: 使用更高效的哈希函数
3. `checker_arena_strdup`: 避免重复复制相同字符串

#### 3.3 增量编译支持（长期）

```
├── .uya-cache/
│   ├── ast/           # 序列化的 AST
│   ├── deps.json      # 依赖关系图
│   └── timestamps.json # 文件修改时间
```

---

## 实施计划

### Week 1: checker.uya 拆分

| Day | 任务 | 验证 |
|-----|------|------|
| 1 | 创建 src/checker/ 目录，提取 types.uya | `make check` |
| 2 | 提取 symbols.uya | `make check` |
| 3 | 提取 expressions.uya | `make check` |
| 4 | 提取 statements.uya | `make check` |
| 5 | 提取剩余模块，验证自举 | `make check && make backup` |

### Week 2: parser.uya 拆分

| Day | 任务 | 验证 |
|-----|------|------|
| 1 | 创建 src/parser/ 目录，提取 types.uya | `make check` |
| 2 | 提取 expressions.uya | `make check` |
| 3 | 提取 statements.uya | `make check` |
| 4 | 提取 declarations.uya | `make check` |
| 5 | 验证自举和测试 | `make check && make backup` |

### Week 3: 内存优化

| Day | 任务 | 验证 |
|-----|------|------|
| 1 | 实现 Arena 按需增长 | `make check` |
| 2 | 优化临时 Arena | `make check` |
| 3 | 动态化大数组 | `make check` |
| 4-5 | 性能测试，内存占用测试 | 基准测试 |

### Week 4: 性能优化和清理

| Day | 任务 | 验证 |
|-----|------|------|
| 1 | 添加编译阶段计时 | 功能测试 |
| 2 | 分析热点函数 | 性能分析 |
| 3-4 | 优化热点函数 | `make check` |
| 5 | 更新文档，清理代码 | `make backup` |

---

## 风险和缓解措施

### 风险 1：循环依赖

**描述**：拆分后模块间可能出现循环引用

**缓解**：
- 拆分前绘制依赖图
- 保持单向依赖关系
- 必要时提取公共模块

### 风险 2：自举失败

**描述**：拆分后无法通过自举验证

**缓解**：
- 每次拆分后立即验证 `make check`
- 小步迭代，每次只拆一个模块
- 保留备份，可随时回滚

### 风险 3：性能回归

**描述**：拆分后编译速度变慢

**缓解**：
- 拆分前后进行性能对比
- 保持函数内联（必要时使用宏）
- 避免过多的模块边界开销

---

## 验收标准

### 阶段一验收标准

- [ ] checker.uya 拆分为 7-8 个文件，每个 < 2000 行
- [ ] parser.uya 拆分为 5 个文件，每个 < 2000 行
- [ ] `make check` 通过（自举 + 测试）
- [ ] 生成的 C 代码与拆分前一致（或差异可解释）

### 阶段二验收标准

- [ ] 内存占用 < 128MB
- [ ] 小程序编译内存占用 < 32MB
- [ ] `make check` 通过

### 阶段三验收标准

- [ ] 自举编译时间 < 5 秒
- [ ] 有性能分析数据支撑优化
- [ ] `make check` 通过

---

## 参考资料

- [Uya 语言规范](docs/uya_ai_prompt.md)
- [Uya 开发技能](.codebuddy/skills/uya-development.md)
- [版本发布说明](docs/releases/RELEASE_v0.1.0.md)
