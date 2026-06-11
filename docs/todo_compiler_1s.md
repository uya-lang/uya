# Uya 编译器 1 秒冷构建 TODO

**状态**: executable TODO, implementation pending
**更新日期**: 2026-06-12
**配套设计**: `docs/compiler_1s_architecture_design.md`
**配套评估**: `docs/compiler_1s_speed_assessment.md`
**MIR-C99 TODO**: `docs/todo_mir_c99_backend.md`

---

## 当前基线

当前 Linux x86_64 本机、`bin/uya` 默认 `-O2` 产物下：

- 直接 C99 生成 `src/main.uya` 约 20 秒。
- `make uya` 真实落地约 30 秒。
- 自动依赖共 86 个文件，AST 合并后约 3828 个声明。
- C99 codegen 的 `body_ms` 是第一热点，约占 codegen 83%。
- perf self time 前列集中在全程序声明扫描和字符串比较。

本 TODO 的硬目标是：

```bash
make clean
make uya
```

冷构建 `bin/uya` 三次中位数小于 1 秒。该目标按纯源码重编口径执行，不允许用对象缓存、IR 缓存、平台二进制或 daemon 状态达标。

同一目标下还必须把内存打下来：

- Phase 0 记录 `peak_rss_kb`、arena 峰值、输出字节数和中间产物字节数。
- Phase 3 前，直接 C99 路径 peak RSS 相比 Phase 0 至少下降 25%。
- Phase 9 前，MIR-C99 build compiler 路径 peak RSS 相比 Phase 0 至少下降 50%。
- 任一阶段如果 wall time 下降但 peak RSS / arena 峰值明显上升，不能勾选性能达标。
- 所有编译器表必须动态扩容；凡是 table/index/cache/list/mapping 角色，都不能有写死容量、固定最大项数或静默截断。

---

## 执行原则

- 每个阶段先补 benchmark / regression，再改实现。
- 不改语言语法、BNF 或内建函数。
- 不删除 C99 fallback；C99 是差分 oracle。
- 不用大表预分配或长期常驻 IR 换取表面速度；内存指标必须和时间一起报告。
- 不新增 `C99_MAX_*`、`CHECKER_*_SIZE` 或魔法容量作为编译器表的语义上限。
- 不用 `git add -A` 提交生成物或无关 WIP。
- 修改编译器行为前先读 `docs/uya_ai_prompt.md`、本设计文档、相邻源码和测试。
- 验证前先重建可信 compiler；不要用陈旧 `bin/uya` 判断修复结果。
- TODO 勾选必须有对应命令、测试或 benchmark 证据。

---

## Phase 0: Benchmark 可信化

- [x] 修正 `scripts/bench_compile_stats.sh`，避免覆盖正式 `bin/uya`。
- [x] `make bench-compile-stats` 默认先重建当前 `bin/uya`。
- [x] 增加 `tests/verify_bench_compile_stats.sh`。
- [x] 新增 `scripts/bench_compiler_1s.sh`，专门测 `make clean && make uya` 冷构建。
- [x] 新增 `make bench-compiler-1s`。
- [x] 新增 `make bench-compiler-1s-check`。
- [x] benchmark 输出 commit、branch、OS、arch、CPU 核数、`CFLAGS`、`CC_DRIVER`、是否启用 MIR-C99/C99。
- [x] benchmark 主动清理 `bin/`、`src/build/`、`src/.uyacache/`。
- [x] benchmark 明确拒绝 daemon、object cache、IR cache 参与硬 KPI。
- [x] benchmark 通过 `/proc/<pid>/status` 或 `/proc/<pid>/smaps_rollup` 采样 `peak_rss_kb`。
- [x] benchmark 在缺少 `/proc` 的平台打印“RSS 未测量”，不能把该运行计入内存达标。
- [x] 编译器内部新增 arena 峰值统计输出字段。
- [x] benchmark 记录生成文件总字节数：
  - [x] C99 单文件大小。
  - [x] split-C 目录总大小。
  - [x] MIR-C99 输出总大小。
  - [x] 临时目录总大小。
- [x] benchmark 输出内存趋势：当前值、baseline、变化百分比。
- [x] benchmark 输出所有编译器动态表摘要或按表明细：`table_count`、`table_capacity`、`table_bytes`、`table_realloc_count`。
- [x] benchmark 检查表容量不是一次性巨大预分配；若 `capacity/count` 比例异常，报告 warning。
- [x] benchmark TSV 输出字段：

```text
run	mode	seed_ms	parse_ms	bind_ms	check_ms	lower_ms	emit_ms	link_ms	total_ms	peak_rss_kb	arena_peak_bytes	output_bytes	c99_output_buffer_peak_bytes	table_count	table_capacity	table_bytes	table_capacity_bytes	table_realloc_count
```

- [x] 用当前实现跑 3 次冷构建，记录时间 baseline 到 `docs/compiler_1s_speed_assessment.md`。
- [x] 用当前实现跑 3 次冷构建，记录内存 baseline 到 `docs/compiler_1s_speed_assessment.md`。
- [x] 用当前实现扫描固定容量表和直接映射缓存，记录所有需要迁移的 `MAX_*` / magic capacity 清单。
- [x] 新增 `tests/verify_no_fixed_compiler_tables.sh`，检查新增编译器表不得使用固定容量。
- [x] `tests/verify_no_fixed_compiler_tables.sh` 必须区分“允许的小缓冲”和“禁止的 table/index/cache/list/mapping”。
- [x] 固定容量扫描至少覆盖 `src/main.uya`、`src/checker/`、`src/codegen/c99/`、`src/exec/`。

验证：

```bash
git diff --check
make bench-compile-stats-check
make bench-compiler-1s-check
bash tests/verify_no_fixed_compiler_tables.sh
```

---

## Phase 0A: 固定表迁移门禁

- [x] 建立固定表审计清单，至少包含：
  - [x] `src/codegen/c99/internal.uya` 的 `C99_MAX_*` codegen state 表。
  - [x] `src/codegen/c99/global.uya` / `types.uya` / `utils.uya` 的直接映射 cache。
  - [x] `src/checker/lookup.uya` 的 checker lookup cache。
  - [x] `src/checker/types.uya` / `generics.uya` / `symbols.uya` 的 mono/reachability/function table。
  - [x] `src/exec/lower.uya` / `builder.uya` / `frame.uya` 的 locals/globals/bytecode/frame 表。
  - [x] `src/main.uya` 的 input/resolved/processed files 和 program list。
- [x] 为审计清单中的每类表标注迁移目标：dynamic vector、dynamic hash、range builder、worklist 或 bounded small buffer。
- 所有 `count >= MAX` 后静默截断、静默跳过或继续成功的路径改为明确 diagnostic，拆分为：
  - [x] 扫描 `count >= MAX` 静默路径，记录 codegen/checker/exec/main 修复清单。
  - [x] 修复 `src/main.uya` input/resolved/processed files 相关静默跳过，改为明确 diagnostic。
  - 修复 C99 codegen 固定表 `count >= C99_MAX_*` 静默截断/跳过，改为明确 diagnostic，拆分为：
    - [x] 修复 C99 mono/reachable/test worklist 上限静默跳过，改为明确 diagnostic。
    - [x] 修复 C99 registry/emitted metadata 上限静默返回或截断，改为明确 diagnostic。
    - [x] 修复 C99 locals/defer/drop 上限静默跳过，改为明确 diagnostic。
  - [x] 修复 checker 固定表 `count >= MAX_*` / `*_SIZE` 静默截断/跳过，改为明确 diagnostic。
  - [x] 修复 exec 固定表 `count >= EXEC_MAX_*` 静默截断/跳过，改为明确 diagnostic。
- [x] 所有旧固定表如需临时保留，必须标注为 oracle/fallback，不允许计入 1 秒硬路径成功。
- [x] 动态表基础设施完成前，不得新增新的编译器表固定容量。

验证：

```bash
bash tests/verify_fixed_table_retention_labels.sh
bash tests/verify_fixed_table_freeze_policy.sh
bash tests/verify_no_fixed_compiler_tables.sh --self-test
bash tests/verify_no_fixed_compiler_tables.sh
git diff --check
```

---

## Phase 1: SemanticDb 基础

- [x] 新建 `src/semantic/` 目录。
- [x] 新建 `src/semantic/ids.uya`，定义：

```text
FileId
ModuleId
InternedNameId
DeclId
SymbolId
ScopeId
TypeId
ExprId
FunctionId
MonoInstanceId
```

- [x] 新建 `src/semantic/table.uya` 或等价基础设施，提供动态 vector/hash/range builder。
- [x] 动态表 API 必须包含 `reserve`、`ensure_capacity`、`append/insert`、`reset`、`free/release`。
- [x] 动态表必须记录 `count`、`capacity`、`bytes`、`realloc_count`。
- [x] 动态表增长必须检查整数溢出和 allocation failure。
- [x] 新建 `src/semantic/intern.uya`，实现字符串 intern 表。
- [x] intern 表按负载因子动态扩容，不允许固定 4096/8192 槽作为语义上限。
- [x] 新建 `src/semantic/db.uya`，定义 `SemanticDb`。
- [x] 新建 `src/semantic/build.uya`，从 merged AST 构建 `SemanticDb`。
- [x] `SemanticDb` 内部使用紧凑数组/range，不为每个名字单独堆分配链表节点。
- [x] `SemanticDb` 所有数组、range、hash bucket、collision list 都随数据增长动态扩容。
- [x] `SemanticDb` 记录自身估算字节数。
- [x] 为顶层声明建立 `DeclId -> ASTNode` 映射。
- [x] 为文件和模块建立 `FileId` / `ModuleId`。
- [x] 将 `use` 语句和 module export 登记为 `ImportBinding`。
- [x] 增加 `semantic_db_reset()`，用于同进程多次编译。
- [x] 在 `checker_init()` 或等价入口纳入 semantic cache reset。
- [x] 增加 debug dump 开关 `UYA_DUMP_SEMANTIC_DB=1`。
- [x] debug dump 默认关闭，打开时不计入性能/内存 KPI。

测试：

- [x] 新增 `tests/verify_semantic_db_smoke.sh`。
- [x] 覆盖同名函数 body/stub。
- [x] 覆盖 `libc` / `std` family 上下文。
- [x] 覆盖 file-local alias。
- [x] 覆盖 whole-module import export。
- [x] 新增 `tests/verify_dynamic_table_growth.sh`。
- [x] 覆盖超过旧固定容量的声明数、函数数、局部变量数、泛型实例数。
- [x] 覆盖 intern/hash 高负载和高冲突增长。
- [x] 覆盖 growth failure 模拟，必须得到明确 diagnostic。

验证：

```bash
bash tests/verify_semantic_ids.sh
bash tests/verify_semantic_table.sh
bash tests/verify_semantic_table_api.sh
bash tests/verify_semantic_table_stats.sh
bash tests/verify_semantic_table_growth_failures.sh
bash tests/verify_dynamic_table_growth.sh
bash tests/verify_semantic_intern.sh
bash tests/verify_semantic_intern_growth.sh
bash tests/verify_semantic_db_definition.sh
bash tests/verify_semantic_db_compact_storage.sh
bash tests/verify_semantic_db_dynamic_growth.sh
bash tests/verify_semantic_db_estimated_bytes.sh
bash tests/verify_semantic_db_decl_ast_mapping.sh
bash tests/verify_semantic_db_file_module_ids.sh
bash tests/verify_semantic_db_import_bindings.sh
bash tests/verify_semantic_db_reset.sh
bash tests/verify_checker_semantic_cache_reset.sh
bash tests/verify_semantic_db_debug_dump.sh
make bench-compiler-1s-check
bash tests/verify_semantic_db_smoke.sh
make tests-uya
```

---

## Phase 2: 声明与模块索引替换

- [x] 建 `decls_by_name: InternedNameId -> DeclRange`。
- [x] 建 `functions_by_name: InternedNameId -> FunctionOverloadRange`。
- [x] 建 `types_by_name: InternedNameId -> TypeDeclRange`。
- [x] 建 `enum_variants_by_name: InternedNameId -> EnumVariantRange`。
- [x] 建 `exports_by_module_name: (ModuleId, InternedNameId) -> SymbolId`。
- [x] 建 `aliases_by_file_name: (FileId, InternedNameId) -> DeclId`。
- [x] 建 `use_items_by_file_name: (FileId, InternedNameId) -> ImportBinding`。
- [x] 上述索引全部使用动态 hash/range builder，禁止固定 bucket 数作为容量上限。
- [x] range builder 增长后保持 `DeclId` / `SymbolId` 稳定。
- [x] 索引构建完成后输出 count/capacity/load factor 摘要。
- [x] 将 `find_type_alias_from_program` 改为读 `SemanticDb`。
- [x] 将 `find_struct_decl_from_program` 改为读 `SemanticDb`。
- [x] 将 `find_union_decl_from_program` 改为读 `SemanticDb`。
- [x] 将 `find_interface_decl_from_program` 改为读 `SemanticDb`。
- [x] 将 `find_enum_decl_from_program` 改为读 `SemanticDb`。
- [x] 将 `is_enum_variant_name_in_program` 改为读 `SemanticDb`。
- [x] 保留旧扫描函数作为临时 oracle，新增 debug 比对模式。
- [x] 每个迁移点先跑新旧 lookup 对照，确认返回同一 AST 节点或同一诊断。

测试：

- [x] 新增 `tests/test_semantic_lookup_alias_context.uya`。
- [x] 新增 `tests/test_semantic_lookup_enum_variant.uya`。
- [x] 新增 `tests/test_semantic_lookup_function_family.uya`。
- [x] 新增 `tests/verify_semantic_lookup_oracle.sh`。
- [x] `tests/verify_dynamic_table_growth.sh` 覆盖 Phase 2 索引超过旧容量仍能查询正确。
- [x] `tests/verify_dynamic_table_growth.sh` 覆盖 hash 高冲突时不会回退全程序线性扫描。

验证：

```bash
bash tests/verify_semantic_lookup_oracle.sh
make check
```

阶段 KPI：

- [x] `perf` 前 20 中 `find_type_alias_from_program` 不再是第一热点。
- [x] 直接 C99 `check + codegen` 不回退出新错误。
- [x] SemanticDb 引入后 peak RSS 不得高于 Phase 0 baseline；若上升，必须先压缩表结构再继续。
- [x] 主要索引 `capacity/count` 比例在正常数据下保持可解释，不能靠超大预分配压低 rehash 次数。

---

## Phase 3: 函数与局部作用域索引

- [x] 新建 `FunctionScopeIndex`。
- [x] `FunctionScopeIndex` 的 params、locals、captures、async bindings 全部动态增长。
- [x] 函数进入时一次性登记 params。
- [x] block 进入/退出时维护 local generation。
- [x] async bind / async local 进入同一作用域查询模型。
- [x] 全局变量可见性由 `SemanticDb` 提供。
- [x] 将 `c99_find_identifier_type_node` 改为读 typed/scope 表。
- [x] 将 `lookup_identifier_type_c_impl` 改为读 typed/scope 表。
- [x] 删除或禁用按 `local_variable_count` 拼 hash 的热点缓存。
- [x] 泛型/async 场景恢复安全缓存 key：

```text
(template DeclId, mono signature id, local generation, async frame id)
```

测试：

- [x] 新增局部 shadowing 测试。
- [x] 新增泛型同模板多实例变量类型测试。
- [x] 新增 async bind 名称冲突测试。
- [x] 新增 block depth 退出后不可见测试。
- [x] `tests/verify_dynamic_table_growth.sh` 覆盖大量 locals、深 block、async locals 的动态增长。

验证：

```bash
make tests-uya
make check
```

阶段 KPI：

- [x] `c99_find_identifier_type_node` 不再进入 perf 前 20。
- [x] codegen `body_ms` 较 Phase 0 降低至少 20%。

---

## Phase 4: TypedProgram 合同

- [x] 新建 `src/typed/` 目录。
- [x] 定义 `TypedProgram`。
- [x] `TypedProgram` 只存整数 ID 和紧凑表，不复制 AST 子树。
- [x] `TypedProgram` 内所有 `ExprId -> *`、roots、proof results 表动态增长。
- [x] `TypedProgram` 提供 reserve/append 查询统计，不允许表达式数量固定上限。
- [x] `TypedProgram` 记录自身估算字节数。
- [x] 输出 `expr_types: ExprId -> TypeId`。
- [x] 输出 `identifier_bindings: ExprId -> SymbolId`。
- [x] 输出 `call_targets: ExprId -> CallTarget`。
- [x] 输出 `method_dispatch: ExprId -> MethodDispatch`。
- [x] 输出 `field_access: ExprId -> FieldId`。
- [x] 输出 `global_init_order: GlobalId[]`。
- [x] 输出 `reachable_roots: FunctionId[]`。
- [x] 输出 `proof_results: ProofResult[]`。
- [x] 给 AST 节点分配稳定 `ExprId`。
- [x] 将 C99 后端的常规 `checker_infer_type` 调用替换为 `TypedProgram` 查询。
- [x] 增加后端重进 checker 计数器。
- [x] `UYA_STRICT_TYPED_BACKEND=1` 时，后端常规重进 checker 直接报错。

测试：

- [x] 新增 `tests/verify_typed_program_backend_contract.sh`。
- [x] 覆盖普通调用、方法调用、泛型调用、field access、global init。
- [x] `tests/verify_dynamic_table_growth.sh` 覆盖大量表达式、调用目标和 proof result。

验证：

```bash
UYA_STRICT_TYPED_BACKEND=1 ./bin/uya src/main.uya -o /tmp/uya_strict_typed.c --c99 --nostdlib --safety-proof
make check
```

阶段 KPI：

- [x] codegen `body_ms < 7000ms`。
- [x] TypedProgram 常驻峰值可测量，且与 AST/LoweredProgram 生命周期分离。

---

## Phase 5: LoweredProgram 闭包收敛

- [x] 新建 `src/lower/core.uya`。
- [x] 新增 `docs/coreir_lowered_program_whitepaper.md`，作为 `TypedProgram -> LoweredProgram/CoreIR`
  的详细合同；这只表示设计合同已完成，不表示 `CoreBody` / CoreIR verifier 已实现。
- [x] 定义 `LoweredProgram`。
- [x] `LoweredProgram` 使用独立 arena。
- [x] `LoweredProgram` 的 functions、globals、types、interfaces、err_unions、async_frames、helpers 全部动态增长。
- [x] lowering worklist 动态增长，不允许泛型实例、err_union、runtime helper 有固定最大数量。
- [x] `LoweredProgram` 记录自身估算字节数。
- [x] 定义 `ConcreteFunction`。
- [x] 定义 `ConcreteType`。
- [x] 定义 `RuntimeHelper`。
- [x] 定义 `ErrorUnionLayout`。
- [x] 定义 `AsyncFramePlan`。
- [x] 实现 worklist roots 初始化。
- [x] 实现泛型函数实例闭包。
- [x] 实现泛型方法实例闭包。
- [x] 实现泛型结构体实例闭包。
- [x] 实现 err_union 类型闭包。
- [x] 实现 async frame 元数据闭包。
- [x] 实现 drop/defer plan 闭包。
- [x] 实现 runtime helper 需求闭包。
- [x] 输出稳定排序。
- [x] `UYA_DUMP_LOWERED_PROGRAM=1` 输出摘要。

测试：

- [x] 新增 `tests/verify_lowered_program_closure.sh`。
- [x] 覆盖 nested generic call。
- [x] 覆盖 method generic call。
- [x] 覆盖 `try/catch` 嵌套 err_union。
- [x] 覆盖 async frame descriptor。
- [x] 覆盖 vtable/interface method。
- [x] `tests/verify_dynamic_table_growth.sh` 覆盖大量 mono instances、err_union layouts、async frames、helpers。

验证：

```bash
bash tests/verify_lowered_program_closure.sh
make check
```

阶段 KPI：

- [x] C99 emitter 开始前，mono/err_union/async frame 数量已稳定。
- [x] C99 emitter 中不得新增 mono instance。
- [x] C99 emitter 中不得新增 err_union body。
- [x] peak RSS 相比 Phase 0 baseline 下降至少 25%。

---

## Phase 5A: 内存生命周期收口

- [x] 为 parser AST、SemanticDb、TypedProgram、LoweredProgram、Emitter 分配独立 arena。
- [x] 明确每个 arena 的创建点、最后使用点和释放点。
- [x] `make bench-compiler-1s` 输出每个 arena 的 peak bytes。
- [x] `make bench-compiler-1s` 输出所有编译器动态表的 count/capacity/realloc/bytes。
- [x] 新增动态表预算检查：不得通过启动时预分配超大容量降低增长次数。
- [x] C99 输出从“全局状态 + 边生成边补发”收口为 unit 流式写。
- [x] 后端输出不生成 debug info，不保留全量临时副本。
- [x] diagnostic 默认延迟格式化；无错误时不构造长诊断字符串。
- [x] `UYA_DUMP_*` 相关 dump 输出不计入性能达标，并在 benchmark 中标记。
- [x] 新增内存回归脚本 `tests/verify_compiler_memory_budget.sh`。

测试：

- [x] `tests/verify_compiler_memory_budget.sh` 检查 benchmark TSV 含内存字段。
- [x] `tests/verify_compiler_memory_budget.sh` 检查缺少 RSS 采样时不会误报达标。
- [x] `tests/verify_compiler_memory_budget.sh` 检查 arena 字段存在且为非负整数。
- [x] `tests/verify_compiler_memory_budget.sh` 检查动态表字段存在且为非负整数。
- [x] 后端 streaming 输出策略已纳入内存预算和动态表门禁记录。

验证：

```bash
bash tests/verify_compiler_memory_budget.sh
bash tests/verify_dynamic_table_budget.sh
make bench-compiler-1s-check
```

阶段 KPI：

- [x] 内存字段进入所有 1 秒 benchmark 输出。
- [x] AST / TypedProgram / LoweredProgram 不再无界同时常驻。

---

## Phase 5B: CoreIR / CoreBody 合同实现

本阶段把 Phase 5 的闭包清单推进为 PortableMIR 可消费的 Core-level 函数体合同。Phase 9A 的
PortableMIR 实现必须以本阶段通过为硬门槛；如果 MIR lowering 需要新的语义事实，先补
`LoweredProgram` / `CoreBody` 合同，不能把 `TypedProgram` 当成语义查询旁路。

- [x] 定义 `CoreBody`，作为 concrete function 的结构化函数体表示。
- [x] 定义 `CoreStmt` / `CoreExpr` / `CorePlace` / `CoreCleanupEdge` 等 Core-level 节点。
- [x] `CoreBody` 保存 PortableMIR 所需的 resolved call target、method dispatch、field id、type id、
  proof result、source span、drop/defer/errdefer 和 capability metadata。
- [x] Core lowering 从 `TypedProgram` 一次性冻结所需语义事实；完成后 MIR lowering 不再常规查询
  `TypedProgram`。
- [x] 现有 `LoweredBodyOp` 只保留为过渡兼容输入，不再新增 `RETURN_*`、`LOCAL_CALL_*`、
  `IF_LOCAL_*` 等 one-off opcode。
- [x] 新增 `UYA_DUMP_COREIR=1`，输出稳定的 CoreIR / CoreBody 文本摘要。
- [x] 新增 CoreIR verifier，检查 concrete function 是否有合法 `CoreBody`、节点 type/call/field/proof
  是否已冻结、cleanup path 是否完整、capability metadata 是否只描述能力需求而不改变语言语义。
- [x] 明确语言语义与 target capability 边界：`@c_import`、filesystem、pthread、syscall、
  `@asm`、未来 PTX device subset 等限制只能产生 capability diagnostic，不能变成 Uya 方言。
- [x] CoreIR 冻结 `@naked_fn` 函数属性，并在 verifier 中拒绝非 asm-only naked body、普通局部栈槽、
  cleanup、drop、async、error propagation 和隐式 return。
- [x] 明确 CoreLower 并行边界：冻结前的 discovery 必须稳定归并，冻结后的 per-function CoreBody
  materialization 不得改变 ID、dump 或 diagnostics 顺序。
- [x] C99 可继续直接消费 `LoweredProgram` 作为 oracle，但新增的完整函数体语义必须首先能在
  `CoreBody` 中 dump 和验证。

测试：

- [x] 新增 `tests/verify_coreir_dump_golden.sh`。
- [x] 新增 `tests/verify_coreir_verifier.sh`。
- [x] 新增 `tests/verify_coreir_closure_contract.sh`。
- [x] 新增 `tests/verify_coreir_naked_fn_contract.sh`。
- [x] 新增 `tests/verify_coreir_parallel_determinism.sh`。
- [x] CoreIR dump 覆盖多文件、泛型函数、泛型方法、interface dispatch、field/index/slice、
  atomic、SIMD vector/mask、error/defer/drop 和 `compile_files(...)` 调用形状。
- [x] CoreIR verifier 负例覆盖缺失 call target、缺失 field id、类型不匹配、cleanup edge 不完整、
  target capability 混入语言语义。
- [x] CoreIR verifier 负例覆盖 `@naked_fn` 中出现普通 statement、局部栈槽、defer/drop/async/error path。
- [x] CoreIR deterministic 测试覆盖并行 request merge 与串行输出一致。

验证：

```bash
git diff --check
bash tests/verify_coreir_dump_golden.sh
bash tests/verify_coreir_verifier.sh
bash tests/verify_coreir_closure_contract.sh
bash tests/verify_coreir_naked_fn_contract.sh
bash tests/verify_coreir_parallel_determinism.sh
bash tests/verify_portable_mir_core_input_contract.sh
```

阶段 KPI：

- [x] PortableMIR lowering 可以只从 frozen `LoweredProgram + CoreBody` 获得语义信息。
- [x] `compile_files(...)` 16 参数调用在 CoreIR dump 中以 resolved call target 和 typed arguments
  稳定出现。
- [x] CoreIR verifier 能阻止 MIR 实现绕过 CoreIR 回查 checker / TypedProgram。
- [x] `@naked_fn` 在 CoreIR dump 中有稳定 flags/capability，且非法 body 先在 CoreIR verifier 被拒绝。
- [x] CoreIR 并行开关不改变 IDs、dump 或 diagnostics。

---

## Phase 6: C99 Planner / Emitter 分层

- [x] 新建 `src/codegen/c99/plan.uya`。
- [x] 定义 `C99Plan`。
- [x] 定义 `C99UnitPlan`。
- [x] `C99Plan` / `C99UnitPlan` 的 includes、typedefs、prototypes、globals、functions、helpers、deps 全部动态增长。
- [x] split-C unit 列表动态增长，不允许固定最大 unit 数。
- [x] 将 include/header/prelude 规划迁入 planner。
- [x] 将 function prototype 规划迁入 planner。
- [x] 将 type definitions 规划迁入 planner。
- [x] 将 helper emission 需求迁入 planner。
- [x] 将 split-C unit 分配迁入 planner。
- [x] 将 `c99_codegen_generate` 改为：

```text
c99_plan_build(lowered)
c99_emit_plan(plan)
c99_write_split_makefile(plan)
```

- [x] `C99Emitter` 不允许查 AST 声明。
- [x] `C99Emitter` 不允许调用 checker。
- [x] `C99Emitter` 不允许写 `LoweredProgram`。
- [x] 增加 `UYA_STRICT_C99_EMITTER=1` 断言。

测试：

- [x] 新增 `tests/verify_c99_plan_stability.sh`。
- [x] 新增 split-C plan dependency regression。
- [x] `tests/verify_dynamic_table_growth.sh` 覆盖大量 C99 units、prototypes、helpers、deps。
- [x] 新增 `tests/verify_c99_emitter_streaming.sh`：`UYA_STRICT_C99_EMITTER=1` emitter-start 全待输出表稳定门禁；代表性输入（含 `src/main.uya`）零漂移 + 故障注入证明门禁非空转。
- [x] 复跑现有 C99 regression：
  - [x] async frame descriptors
  - [x] imported `main`
  - [x] private function name collision
  - [x] VP8 short payload codegen
  - [x] split-C Makefile dependencies

验证：

```bash
UYA_STRICT_C99_EMITTER=1 ./bin/uya src/main.uya -o /tmp/uya_c99_plan.c --c99 --nostdlib --safety-proof
bash tests/verify_c99_emitter_streaming.sh
make check
```

阶段 KPI：

- [x] `UYA_PROFILE_CODEGEN` 下 `body_ms < 4000ms`。
- [x] 直接 C99 total `< 8000ms`。
- [x] C99 输出缓冲 peak bytes 可测量且不随输出文本大小线性常驻。

---

## Phase 7: 入口瘦身与命令外置

- [x] 阅读 `docs/cmd_subcommand_split_design.md`。
- [x] 更新其中过期的 8400 行基线为当前实际基线。
- [x] 提取 `src/compiler_driver.uya`。
- [x] 新建 `src/cmd/build/main.uya`。
- [x] 新建 `src/cmd/check/main.uya`。
- [x] 新建 `src/cmd/run/main.uya`。
- [x] 新建 `src/cmd/test/main.uya`。
- [x] 新建 `src/cmd/fmt/main.uya`。
- [x] 将 `upm` 保持外置。
- [x] `bin/uya` 增加 argv 原样 dispatch。
- [x] `make cmds` 生成所有命令。
- [x] `make clean` 清理 `bin/cmd/`。
- [x] 保留隐式入口直到 `cmd/build` seed 稳定。

测试：

- [x] 新增或更新 `tests/test_cmd_dispatch.sh`。
- [x] 覆盖 `bin/uya build` 与 `bin/cmd/build` 等价。
- [x] 覆盖 `run -- args` 参数原样传递。
- [x] 覆盖缺失 `bin/cmd/build` 的错误信息。

验证：

```bash
make cmds
bash tests/test_cmd_dispatch.sh
make check
```

阶段 KPI：

- [x] `bin/uya` launcher 直接 C99 构建 `< 1000ms`。
- [x] `src/main.uya` 不再静态带入 C99/exec/microapp/upm/fmt 全量业务。

---

## Phase 7A: Microapp 命名空间外置

目标：microapp / microcontainer 不重新塞回 `bin/uya` 或 `cmd/build` seed，而是作为完整工具链的独立
子命令命名空间恢复 CLI 能力。

目标公开命令：

```text
uya microapp build ...
uya microapp pack ...
uya microapp inspect ...
uya microapp verify ...
uya microapp run ...
```

- [x] 新建 `src/cmd/microapp/main.uya`。
- [x] 新建或整理 `microapp_cli_main()`，只承载 microapp 子命令解析和调度。
- [x] `uya microapp build ...` 支持 microapp payload / `.pobj` / `.uapp` 构建流程。
- [x] `uya microapp pack ...` 替代旧顶层 `pack-image`。
- [x] `uya microapp inspect ...` 替代旧顶层 `inspect-image`。
- [x] `uya microapp verify ...` 替代旧顶层 `verify-image`。
- [x] `uya microapp run ...` 支持已接线 profile 的 loader 运行路径。
- [x] `bin/uya` launcher 将 `microapp` 分发到 `bin/cmd/microapp`。
- [x] `make cmds` / `make install` 纳入 `bin/cmd/microapp`。
- [x] 旧顶层 `pack-image` / `inspect-image` / `verify-image` 若保留，只作为兼容诊断或转发到
  `uya microapp pack|inspect|verify`，不得重新导入 microapp 大逻辑到 `src/main.uya`。
- [x] `cmd/build` seed 继续拒绝 `--app microapp` 与 image/payload 相关参数，并提示使用
  `uya microapp build ...`。
- [x] 更新 microapp 文档、示例和测试脚本中的旧命令形态。

测试：

- [x] 新增 `tests/test_cmd_microapp_dispatch.sh`。
- [x] 覆盖 `bin/uya microapp pack` 与 `bin/cmd/microapp pack` argv 等价。
- [x] 覆盖 `bin/uya microapp inspect` / `verify` 分发。
- [x] 覆盖旧顶层 `pack-image` / `inspect-image` / `verify-image` 的兼容诊断或转发行为。
- [x] 覆盖 `cmd/build` 对 microapp image/payload 的拒绝文案。
- [x] 复跑 `make microapp-check`。

验证：

```bash
make cmds
bash tests/test_cmd_microapp_dispatch.sh
make microapp-check
make check
```

阶段 KPI：

- [x] `bin/uya` launcher 不静态导入 microapp。
- [x] `bin/cmd/build` seed 不静态导入 microapp image/payload。
- [x] microapp CLI 能力通过 `uya microapp ...` 完整恢复。

---

## Phase 8: Build seed 瘦身

- [x] 设计最小 build compiler root。
- [x] 明确 `cmd/build` seed 的源码边界。
- [x] 从 seed 中移除 exec backend。
- [x] 从 seed 中移除 microapp image/payload。
- [x] 从 seed 中移除 upm lib。
- [x] 从 seed 中移除 fmt。
- [x] 从 seed 中移除 kernel packaging。
- [x] seed 不保留大型非 build 子系统的静态表或字符串池。
- [x] seed 产物大小纳入 benchmark `output_bytes`。
- [x] 更新 `make from-c`，能恢复：

```text
bin/uya
bin/cmd/build
```

- [x] 更新 `backup-all-seed`，生成 build seed。
- [x] 保留 C99 fallback seed。
- [x] 防止 dispatcher-only `bin/uya` 与 `cmd/build` 互相等待。
- [x] seed 对 microapp 参数的错误信息指向 `uya microapp build ...`，而不是旧顶层
  `pack-image` / `inspect-image` / `verify-image`。

测试：

- [x] 新增 `tests/verify_build_seed_bootstrap.sh`。
- [x] 清理后验证 `make from-c` 可恢复 `bin/cmd/build`。

验证：

```bash
make clean
make from-c
test -x bin/uya
test -x bin/cmd/build
make cmds
make check
```

阶段 KPI：

- [x] build seed 恢复时间 `< 3000ms`。
- [x] seed 源文件依赖数显著少于当前 86 个文件。
- [x] seed restore peak RSS 低于 Phase 0 baseline 50%。

---

## Phase 9A: PortableMIR 架构主干

路线调整：下一步不再扩大旧 `LoweredBodyOp` 特例集合，而是先建立 `CoreBody` 和 `PortableMIR` 主干。
`LoweredProgram` 继续作为 Core-level 闭包收敛和程序清单；完整函数体语义先由 Phase 5B 的
`CoreBody` 冻结，再由 `PortableMIR` 承接为低级 CFG/value/memory IR，并作为 MIR-C99、PTX、exec
等后端的共享入口。

本阶段只表示 `PortableMIR` 架构、合同、verifier 和后端入口已经建立；不表示完整 Uya 语言已经都能
降到 MIR。完整语言到 `CoreBody` / `PortableMIR` 的实现覆盖和 MIR-C99 parity 由 Phase 9B 承接。

- [x] 新增 `docs/portable_mir_whitepaper.md`，作为 Phase 9A 实现前的详细 MIR 合同。
- [x] Phase 5B 的 `CoreBody`、CoreIR dump、CoreIR verifier 和 CoreIR closure contract 门禁全部通过。
- [x] 定义 `PortableMIR` 顶层 module / function / block / value / type / local / inst / terminator 结构。
- [x] `PortableMIR` 所有表动态增长，不引入函数、block、inst、value、local 或 type 的固定语义上限。
- [x] 明确 `LoweredProgram` 的职责边界：functions、globals、types、interfaces、err_unions、async_frames、
  drop_defer_plans、helpers、worklist 和稳定符号顺序；不把 `LoweredBodyOp` 扩成完整语言 IR。
- [x] 定义 `LoweredProgram + CoreBody` 到 `PortableMIR` 的 lowering 合同和 feature mask，作为表达式、
  语句、控制流、load/store/address、atomic、SIMD vector/mask、call/return/branch、
  field/index/slice 地址计算、copy/move/drop 和 cleanup path 的实现覆盖依据。
- [x] MIR lowering 默认不查询 `TypedProgram`；若确实缺少 source/proof/capability metadata，先回补
  CoreIR 合同。
- [x] `PortableMIR` 显式记录 target-neutral layout metadata、calling convention 需求、runtime capability
  和 address space 预留字段。
- [x] `PortableMIR` 显式记录 `MirFunction.flags.naked` / asm-only naked body，禁止 naked 函数走普通
  prologue/epilogue、stack slot、cleanup、drop、async 或隐式 return lowering。
- [x] 实现 MIR verifier，线性检查 block 终结、value 定义/使用、类型匹配、地址/布局、atomic / vector /
  mask 规则、cleanup path 和 target capability。
- [x] 明确 PortableMIR 并行构造合同：worker 只消费 frozen `LoweredProgram + CoreBody`，按 stable
  function order 归并 MIR functions、diagnostics、dump 和 backend fragments。
- [x] 新增 target backend 接口：后端只消费 `PortableMIR`，再映射到 `MirC99Plan`、`PtxModule`
  或 exec bytecode。
- [x] C99 backend 第一阶段继续作为独立 oracle；暂不强制迁移到 MIR。

测试：

- [x] 新增 `tests/verify_portable_mir_golden.sh`，覆盖 block、value、load/store、aggregate、branch、call
  和 cleanup path。
- [x] MIR dump / golden 覆盖 `atomic T`、`@vector(T, N)` 和 `@mask(N)`。
- [x] 新增 MIR verifier 负例测试，覆盖未终结 block、类型不匹配、非法地址、错误 cleanup、unsupported
  target capability。
- [x] 新增 `tests/verify_portable_mir_verifier.sh`。
- [x] 新增 MIR `@naked_fn` golden / verifier 负例，覆盖 asm-only body、unsupported target、禁止普通 local /
  cleanup / implicit return。
- [x] 新增 `tests/verify_portable_mir_naked_fn.sh`。
- [x] 新增 MIR parallel determinism 测试，覆盖并行构造开关下 dump、diagnostics、IDs 和 symbol order 不变。
- [x] 新增 `tests/verify_portable_mir_parallel_determinism.sh`。
- [x] 新增现有 C99 oracle 边界检查；完整语言覆盖清单转入 Phase 9B。

验证：

```bash
git diff --check
# CoreIR 门禁必须先过；目标脚本名可按实现调整。
bash tests/verify_coreir_dump_golden.sh
bash tests/verify_coreir_verifier.sh
bash tests/verify_coreir_closure_contract.sh
bash tests/verify_coreir_naked_fn_contract.sh
bash tests/verify_coreir_parallel_determinism.sh
bash tests/verify_lowered_program_responsibility_boundary.sh
bash tests/verify_portable_mir_structs.sh
bash tests/verify_portable_mir_dynamic_tables.sh
bash tests/verify_portable_mir_lowering_contract.sh
bash tests/verify_portable_mir_no_typed_bypass.sh
bash tests/verify_portable_mir_target_metadata.sh
bash tests/verify_portable_mir_golden.sh
bash tests/verify_portable_mir_verifier.sh
bash tests/verify_portable_mir_naked_fn.sh
bash tests/verify_portable_mir_parallel_contract.sh
bash tests/verify_portable_mir_backend_interface.sh
bash tests/verify_portable_mir_c99_oracle_boundary.sh
bash tests/verify_portable_mir_parallel_determinism.sh
```

阶段 KPI：

- [x] `compile_files(...)` 16 参数调用缺口不再通过新增 one-off `LoweredBodyOp` 解决，而是成为 MIR lowering
  和 MIR-C99 call ABI 的验收样本。
- [x] 后端新增语言能力时，语言 lowering 只需改 `PortableMIR`，不在每个 target backend 重复实现。
- [x] `@naked_fn` 通过 CoreIR/MIR verifier，不走普通函数体 lowering。
- [x] MIR 并行构造不改变 dump、diagnostics、IDs 或 symbol order。
- [x] 已迁 MIR shard 只作为 Core/PortableMIR 样本；完整语言 MIR-C99 parity 转入 Phase 9B。

---

## Phase 9B: 完整语言到 CoreBody / PortableMIR

Phase 9B 是所有后端的通用语言基础。本阶段目标是让普通 Uya 程序按通用规则进入
`CoreBody -> PortableMIR`，再由 target backend 消费；第一优先级改为独立
`PortableMIR -> minimal C99`。self-build 只能消费本阶段
已经验证过的 MIR 语言能力；如果 `cmd/build` 需要新的语法、builtin、标准库入口或 runtime capability，
先回到本阶段补通用 lowering 和 MIR-C99 / 现有 C99 oracle parity，再复验 self-build。

状态校准（2026-06-12）：

- 当前目标不是继续扩大旧 shape/smoke，而是让独立 MIR-C99 后端完整支持 Uya 语法、通过
  `tests/` 并能自举。
- 独立 MIR-C99 后端尚未实现：`src/codegen/mir_c99/` 不存在，`MIR_TARGET_BACKEND_C99` / `c99_plan`
  只是 target backend 接口占位。
- 现有 C99 后端仍是 oracle/fallback/release 兜底；任何 MIR-C99 成功证据都必须来自
  `CoreBody -> PortableMIR -> MirC99Plan -> MirC99Emitter`，不能调用现有 AST/LoweredProgram
  `src/codegen/c99*` 生产 emitter。
- 既有 full-language smoke 记录只作为历史样本和差分输入清单；它们不能证明 MIR-C99 full support，
  也不能把固定函数名、固定 statement count 或固定 AST/body shape 计入完成。
- 本阶段后续执行以“当前下一步”中的 MIR-C99 详细任务列表为可执行状态来源；本节中宽泛语言面条目若未
  明确连接到 MIR-C99 parity 和 self-build，均按待完成处理。

执行原则：

- 每个叶子先补 MIR-C99 / 现有 C99 oracle parity 或明确 reject 门禁，再改 CoreBody / PortableMIR lowering。
- 现有 AST/LoweredProgram C99 backend 只作为 oracle、fallback 和 release 兜底；新的 MIR-C99 后端必须独立，
  不得混用现有 `src/codegen/c99*` 的 AST planner/emitter 成功路径，也不得把 AST/LoweredProgram 回查当成
  MIR lowering 的一部分。
- 按 AST / CoreStmt / CoreExpr / CorePlace / builtin / 标准库入口建立覆盖矩阵，不能只靠单个 smoke 名称。
- `@print` / `@println` 和标准库入口属于完整语言到 MIR 的基础语言面，不得推迟到 `cmd/build` self-build
  后再处理；HelloWorld 先作为 MIR -> minimal C99 的端到端目标。

MIR 测试分层（阶段门禁说明，不作为当前执行叶子；当前执行叶子从“覆盖矩阵合同”开始）：

- 结构层：继续用 `tests/verify_portable_mir_structs.sh` 和
  `tests/verify_portable_mir_dynamic_tables.sh` 固定 module/function/block/value/type/local/inst 表、
  动态增长、stable id 和释放路径。
- Dump/golden 层：继续用 `tests/verify_portable_mir_golden.sh` 和
  `tests/verify_portable_mir_naked_fn.sh` 固定 MIR 文本格式、函数体 CFG、naked fn 边界和跨平台稳定性。
- Verifier 层：继续用 `tests/verify_portable_mir_verifier.sh` 覆盖正例和负例；负例至少覆盖未终结
  block、value 定义/使用错误、类型不匹配、非法地址、cleanup edge、atomic/vector/mask/capability 错误。
- CoreBody -> MIR lowering 层：每迁入一个 AST/Core/builtin 叶子，先补最小 source shard，检查
  CoreBody surface、PortableMIR dump、verifier clean 和 diagnostic；禁止 lowering 过程回查 `TypedProgram`、
  走 C99 fallback、pre-MIR helper 或 one-off `LoweredBodyOp`。
- MIR -> backend import 层：先新增独立 MIR-C99 后端的 import/preflight gate，固定 verifier-clean MIR 的
  function/block/inst/import 计数和最小 C99 text 生成证据。任一后端都不得直接消费 AST/Core 或手写 helper。
- 端到端 parity 层：每个成功 shard 都必须 MIR-C99 / 现有 C99 oracle 的 stdout、stderr、退出码一致；
  MIR-C99 必须真实生成可由 host C99 compiler 编译、链接、运行的产物。新增 Phase 9B shard 和已迁 MIR success
  shard 不得出现现有 C99 backend 混用、C99 fallback 或 pre-MIR helper 成功路径。
- reject shard 在覆盖矩阵和专用 diagnostic 落地后，必须与覆盖矩阵中的 `reject` 状态一致。
- HelloWorld 是 MIR -> minimal C99 的第一条端到端 parity 目标；它通过前，不把 self-build 当作当前主驱动。

覆盖矩阵合同：

- [x] 新增 `docs/portable_mir_language_coverage.md`，按 `ASTNodeType`、`CoreStmtKind`、`CoreExprKind`、
  `CorePlaceKind`、builtin、标准库入口和 runtime capability 列出状态：`done`、`partial`、`reject`、
  `missing`。
- [x] 新增 coverage verifier / 脚本，扫描 `src/ast.uya`、`src/lower/core.uya`、`src/lower/mir_contract.uya`
  和 MIR-C99 lowering 实现，要求新增 AST/Core kind 必须在覆盖矩阵中有状态。
- [x] 将现有 Phase 9A shard 写入覆盖矩阵：return literal、return call、局部初始化、基础 if-return、
  extern / `@c_import`、builtin shard、slice/array、error union、defer/drop、interface、atomic、SIMD。
- [x] 把当前明确 reject 的复杂 shard 写入覆盖矩阵，记录 reject diagnostic 和 C99 oracle 行为。

语言面迁移叶子：

- [x] print/println surface：将 `AST_PRINT` / `AST_PRINTLN` 冻结为 CoreBody statement/expression surface，
  保留字符串字面量、字符串插值、标量格式化和返回值语义。
- print/println MIR-C99 lowering：拆分实现链，第一步先写 C99 oracle 验证壳子。
  - [x] C99 oracle 端先跑通 `@println("Hello, World!")`，确认退出码、stdout 和 fallback 诊断边界。
  - 在 `src/lower/mir.uya` 中新增 `portable_mir_lower_core_body_to_module`：
    把 `LoweredProgram.core_stmts` + `core_exprs` + `core_places` 序列落成
    `PortableMirModule` 的 function/block/inst/terminator（~500 行），分片推进：
    - [x] 最小 `CORE_STMT_KIND_RETURN` + `CORE_EXPR_KIND_INT_LITERAL` lowering，
          生成 verifier-clean 的单函数/单 block/i32 return PortableMIR。
          # 2026-06-11: `tests/verify_portable_mir_core_body_lowering.sh`、
          # PortableMIR focused gates、`git diff --check` 和
          # `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过。
    - [x] 扩展 return/local/binary i32 CoreExpr lowering，覆盖 value/use operand 和
          `MIR_INST_OP_I32_ADD`。
          # 2026-06-11: `tests/verify_portable_mir_core_body_lowering.sh` 覆盖
          # literal/local/add；`verify_portable_mir_verifier`、`verify_portable_mir_golden`、
          # `verify_portable_mir_no_typed_bypass`、
          # `git diff --check` 和 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过。
    - [x] 扩展 print/println string literal CoreStmt lowering，生成 runtime helper extern call
          和 newline writer 所需 MIR call surface。
          # 2026-06-11: `tests/verify_portable_mir_core_body_lowering.sh` 覆盖
          # print/println string helper call lowering；PortableMIR focused gates、
          # `git diff --check` 和 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过。
  - [ ] 新增独立 `MirC99Emitter` print/println path，输出 minimal C99 helper call。
  - [ ] HelloWorld 经 MIR-C99 生成 `.c`，host C99 compiler 编译运行，stdout/exit 与现有 C99 oracle 一致。
- [ ] statements：覆盖 expression statement、var/const decl、assign、if/else、while、for、break/continue、
  return、block、defer/errdefer/drop、try/catch 和裸 call statement 的通用 lowering，并由 MIR-C99 / 现有
  C99 oracle parity 验证。
- [ ] expressions：覆盖 literal、identifier、local/global load、binary/unary、logical short-circuit、call、
  method call、field access、index/slice、cast/as、address-of、dereference、enum/union/error construction、
  struct/array/slice literal、string literal、string interpolation 和 builtin expression，并由 MIR-C99 / 现有
  C99 oracle parity 验证。
- [ ] places/addressing：覆盖 local、global、field、index、slice ptr/len、pointer arithmetic、out-param、
  optional/null-like pointer 比较和 nested aggregate address，并由 MIR-C99 / 现有 C99 oracle parity 验证。
- [ ] types/layout：覆盖 integer/float/bool/byte、pointer、array、slice、struct、union、enum、error union、
  function type、interface/vtable、generic instance、atomic、vector/mask 和 naked function layout/capability，并由
  MIR-C99 / 现有 C99 oracle parity 验证。
- [ ] builtins：覆盖 `@len`、`@size_of`、`@align_of`、`@error_id`、`@error_name`、`@print`、`@println`、
  `@syscall`、`@ptr_from_usize`、`@usize_from_ptr`、`@c_import`、`@naked_fn`、`@vector`、`@mask` 和
  已在规范中启用的其它 builtin；未支持 builtin 必须明确 reject，并由 MIR-C99 / 现有 C99 oracle parity
  验证。
- [ ] std/runtime entry：覆盖 `std.runtime.entry`、`get_argc`、`get_argv`、stdout/stderr、malloc/free、
  file IO、env、toolchain/linker handoff 和 capability 分流，并由 MIR-C99 / 现有 C99
  oracle parity 验证。

MIR-C99 首个目标：

- [ ] 新增 MIR-C99 HelloWorld parity harness，覆盖：
  - `@println("Hello, World!")`。
  - `@print("Hello")` + `@println("")`。
  - `@println` 返回值可作为 `i32` 使用。
  - MIR-C99 / 现有 C99 oracle 的 stdout、stderr、退出码一致。
  - MIR-C99 build stderr 必须包含 CoreBody、PortableMIR verifier 和 MirC99Emitter 证据。
  - MIR-C99 build stderr 不得包含现有 C99 fallback 或 pre-MIR helper 成功路径。
- [ ] MirC99Emitter 支持 `@print` / `@println` 所需 string constant、stdout helper call 和 newline helper。
- [ ] HelloWorld MIR-C99 产物真实编译运行并输出 `Hello, World!\n`，与现有 C99 oracle 一致。

完整语言 parity 门禁：

- [x] 整理 `tests/verify_full_language_backend_parity.sh`，以 main 分支语言规范为输入清单，覆盖多文件模块、
  泛型、方法、接口、error union、`try/catch`、`defer/errdefer`、async、struct/union/enum、slice/array、
  pointer、atomic、vector/mask、`@c_import`、builtin、标准库入口和 `@print` / `@println`。
- [ ] 所有 parity case 都记录现有 C99 oracle result、MIR-C99 result、stdout/stderr、
  diagnostic normalized diff 和 allowlist。
- [ ] MIR-C99 成功 case 必须真实生成 `.c`、经 host C99 compiler 编译运行；MIR-C99 reject case
  必须和覆盖矩阵中的 `reject` 状态一致。
- [ ] Phase 9B 收口时，普通 HelloWorld、基础标准库程序和完整语言 smoke 均走 MIR-C99 / 现有 C99 oracle parity。

验证：

下面是阶段收口验证；单叶子验证以“当前下一步”为准。覆盖矩阵和专用 MIR-C99 reject diagnostic
落地前，现有 C99 oracle 只能作为行为对照，不能抵消 Phase 9B 收口的 MIR-C99 parity 要求。

```bash
git diff --check
bash tests/verify_portable_mir_structs.sh
bash tests/verify_portable_mir_dynamic_tables.sh
bash tests/verify_portable_mir_golden.sh
bash tests/verify_portable_mir_verifier.sh
bash tests/verify_portable_mir_naked_fn.sh
bash tests/verify_full_language_backend_parity.sh
```

阶段 KPI：

- [ ] 覆盖矩阵区分 C99 oracle、Core/PortableMIR surface 和 MIR-C99 三类状态；
  不能把 C99-only 或 fixed-shape smoke 记为 MIR-C99 done。
- [ ] MIR-C99 HelloWorld：`@println("Hello, World!")` 经
  `CoreBody -> PortableMIR -> MirC99Plan -> MirC99Emitter -> host cc` 真实编译运行，stdout/exit 与现有
  C99 oracle 一致，且不调用现有 AST/LoweredProgram C99 emitter。
- [ ] MIR-C99 full-language parity：`tests/verify_full_language_backend_parity.sh` 的 18 个语言面 case
  以及 `make check` 覆盖的主语言面均能经 MIR-C99 / 现有 C99 oracle 对齐。
- [ ] MIR-C99 self-build：MIR-C99-built compiler 能复跑 `cmd/build` self-build、compiler regression 和
  C99 output parity。
---

## Phase 11: `make uya` MIR-C99 主路径

Phase 11 只在 MIR-C99-built `bin/cmd/build` self-build 真实通过后开始。
本阶段目标是切换构建入口，不再扩展 MIR 语言面；任何 MIR-C99 失败都必须显式报错，不得静默回落现有 C99。

- 构建入口合同切片：
  - [ ] 为 `UYA_BUILD_BACKEND=mir-c99|c99` 补 Makefile/脚本合同测试：默认 MIR-C99、显式 C99、
    非法值 diagnostic、MIR-C99 失败 no-silent-fallback 和手动 C99 fallback。
  - [ ] 为 `make uya-c99` 补合同测试：必须保留旧 C99 路径，输出 `bin/uya`，且不调用 MIR-C99
    `cmd/build` 成功路径。
  - [ ] 为 `make uya` 输出布局补合同测试，固定必须生成：

```text
bin/uya
bin/cmd/build
```

- 构建入口实现切片：
  - [ ] 接入 `UYA_BUILD_BACKEND` 选择器：`mir-c99` 使用 MIR-C99 `cmd/build`，
    `c99` 使用旧 C99 seed 路径，非法值明确失败。
  - [ ] 新增 `make uya-c99`，保留旧路径作为手动 fallback。
  - [ ] 将 `make uya` 默认切到 MIR-C99 path，并确保同时落地 `bin/uya` 和 `bin/cmd/build`。
- 命令安装与 release/backup 切片：
  - [ ] `make cmds` / install flow 安装 `bin/cmd/build`。
  - [ ] `make cmds` / install flow 安装 `bin/cmd/microapp`（若 Phase 7A 已完成）。
  - [ ] release flow 同时验证 MIR-C99 与现有 C99 oracle。
  - [ ] backup flow 纳入 MIR-C99 seed，但保留 C99 seed fallback 和明确失败诊断。
- Phase 11 收口切片：
  - [ ] 运行 `make clean && make uya`、`make cmds`、`bin/uya microapp --help` 和 MIR-C99 no-silent-fallback
    门禁，只跑本阶段相关验证。

验证：

```bash
make clean
make uya
make cmds
bin/uya microapp --help
make check
make backup-all
```

阶段 KPI：

- [ ] `make clean && make uya` 三次中位数 `< 1000ms`。
- [ ] P95 `< 1200ms`。
- [ ] `make clean && make uya` peak RSS 不高于 MIR-C99 `cmd/build` 阶段值。
- [ ] arena 峰值和输出字节数没有回归。

---

## Phase 12: 差分与发布收口

Phase 12 是发布前差分验收，不再承载新的后端语言特性；若差分暴露语言 lowering 缺口，回到
Phase 9B；若暴露 self-build / 构建入口缺口，回到对应 self-build / 构建入口叶子修复后再回来收口。

- MIR-C99/C99 差分门禁切片：
  - [ ] 为 MIR-C99-built 与 C99-built compiler 的 `make check` 输出/退出码对比补脚本合同。
  - [ ] MIR-C99-built compiler 跑 `make check` 并保存 normalized 结果。
  - [ ] C99-built compiler 跑 `make check` 并保存 normalized 结果。
  - [ ] 对比核心测试输出、退出码和 diagnostics 文案，差异必须有明确 allowlist 或修复项。
- 自举产物差分切片：
  - [ ] 为 `src/main.uya` C99 output 结构性摘要补比对脚本，避免依赖非稳定空白或路径。
  - [ ] 对比 MIR-C99-built 与 C99-built 的 `src/main.uya` C99 output 结构性摘要。
  - [ ] 为 MIR-C99 自举二轮产物 normalized output hash 补合同和记录格式。
  - [ ] 对 MIR-C99 自举二轮产物做 normalized output hash，并记录差异结论。
- 文档收口切片：
  - [ ] 更新 `docs/compiler_1s_speed_assessment.md`，记录 MIR-C99 cold build 三次中位数、P95、
    peak RSS、arena peak 和 output bytes。
  - [ ] 更新 `docs/compiler_1s_architecture_design.md`，同步 MIR-C99 / 现有 C99 oracle 的职责边界。
  - [ ] 更新 `docs/todo_compiler_1s.md`，确保已完成项都有验证证据，剩余项不是隐藏 epic。
  - [ ] 更新 `docs/UYA_BUILD_RUN.md`、`docs/TESTING.md` 和
    `docs/c99_codegen_hotpath_benchmark.md`。
  - [ ] release 文档说明 MIR-C99 path 与 C99 fallback。
  - [ ] release 文档说明 microapp 命名空间命令：
  `uya microapp build|pack|inspect|verify|run`。

语言兼容与后端完备性发布复验：

Phase 12 只复验 Phase 9B 已落地的完整语言到 MIR 产物，不承载新的完整语言 lowering 合同或实现叶子。

- 完整语言基线复验切片：
  - [ ] 复验 Phase 9B 已明确 main 分支语言兼容基线：以 main 分支的 `docs/uya.md`、
    `docs/grammar_formal.md`、`docs/grammar_quick.md`、`docs/builtin_functions.md` 和完整语言回归测试为准。
  - [ ] 复验 Phase 9B 已固定完整语言后端差分套件的输入清单、normalized 输出格式和 allowlist 规则。
- 完整语言后端差分复验切片：
  - [ ] 复验 C99 backend 支持完整 Uya 语言，不只支持 launcher / `cmd/build` / build seed 子集。
  - [ ] 复验 MIR-C99 backend 经由 `PortableMIR` 支持完整 Uya 语言，不只支持 launcher /
    `cmd/build` / build seed 子集。
  - [ ] 复验 C99 与 MIR-C99 对同一套完整语言回归输入给出一致的成功/失败、退出码、diagnostics 和运行行为。
  - [ ] 复验 Phase 9B 已整理的完整语言后端差分套件覆盖 parser/checker/codegen 主语言面：多文件模块、泛型、
    方法、接口、error union、`try/catch`、`defer/errdefer`、async、结构体/union/enum、slice/数组、指针、
    `atomic T`、`@vector(T, N)`、`@mask(N)`、`@c_import`、内建函数和标准库入口。
- microapp 兼容切片：
  - [ ] 确认 microapp / microcontainer 在语言层面完全兼容 main 分支，不引入 microapp 专属语法、
    关键字、内建函数或 checker 方言。
  - [ ] 确认 microapp 的限制只来自 capability / runtime / profile / host API 层；对不支持能力的拒绝必须是
    明确 diagnostic，不能表现为语言语义与 main 分支不兼容。
  - [ ] 确认 `uya microapp build` 使用与普通 `uya build` 同源的 parser/checker 语言语义；差异只允许发生在
    microapp 安全策略、ABI、镜像格式和运行时能力裁决层。
  - [ ] 发布说明记录 C99、MIR-C99、microapp 三条路径相对 main 分支的语言兼容结论和已知非语言限制。

最终验收：

```bash
git diff --check
make bench-compiler-1s-check
make bench-compiler-1s ARGS="--runs 3"
make check
make check-hosted
make microapp-check
# 目标脚本名可按实现调整，但 release 前必须有完整语言后端差分门禁。
bash tests/verify_full_language_backend_parity.sh
make backup-all
```

成功标准：

- [ ] 冷构建 KPI 达标。
- [ ] 内存 KPI 达标。
- [x] 默认安全证明路径保留。  # 2026-06-10: `src/compile.sh:335` `USE_SAFETY_PROOF=true`；`make uya`/`make uya-hosted`/`make b` 全部硬编码 `--safety-proof`；`make check` 主线未变。
- [ ] C99 backend 完整支持 Uya 语言，并与 main 分支语言行为兼容。
- [ ] 独立 MIR-C99 backend 经由 `PortableMIR` 完整支持 Uya 语言，并与现有 C99 oracle 行为兼容；该后端只能输出
  最小低级 C99，不得混用现有 AST/LoweredProgram C99 planner/emitter 成功路径。
- [ ] Microapp / microcontainer 语言层面完全兼容 main 分支；仅允许 runtime/capability/profile 限制。
- [ ] MIR-C99/C99 差分验证通过。
- [ ] release/backup 流程无死锁。
- [ ] 文档与 TODO 已同步。
- [x] microapp CLI 不再依赖旧顶层 `pack-image` / `inspect-image` / `verify-image` 作为主入口。  # 2026-06-10: `bin/cmd/microapp --help` 只接受 `pack/inspect/verify`；`bin/cmd/microapp pack-image` 报 `未知 microapp 子命令: pack-image`。`bin/uya pack-image` 报 `顶层 \`pack-image\` 已迁移，请使用 \`bin/uya microapp pack ...\``。

---

## 当前下一步

剩余工作按通用语言结构和独立 MIR-C99 主路径推进；
`cmd/build` 只作为普通合法 Uya 程序的验收输入；
文档不再设置单独的 helper 子集阶段。主清单仍是总体状态来源；本段中的 MIR-C99 详细任务列表是当前
独立 C99 后端切片的历史摘要；细粒度执行状态以 `docs/todo_mir_c99_backend.md` 为准，其它分组名只做执行索引。

路线裁定（2026-06-11）：

- `MIR` 是语言的内部指令集；MIR-C99 后端必须消费通用 MIR，而不是消费“编译器源码的某些函数形状”。
- 所有 parser/checker 认为合法的 Uya 程序，最终都应该能按同一套语言规则编译到 MIR-C99。
- 编译器自举只是一个合法 Uya 程序；它不能拥有独立语法、独立 lowering、函数名白名单或 body-shape
  白名单。
- 旧 P10 / build-seed / helper frontier 文档只作为历史边界和反例保留；后续不得新增按函数名、
  固定 statement count 或固定 AST/body shape 命中的生产成功路径。
- 如果 `cmd/build` 暴露缺口，缺口必须归类到通用语言结构（CFG、place/memory、call ABI、
  cleanup/error、runtime capability、MIR 指令覆盖等），先补通用覆盖，再复验自举。
- `MIR -> C99` 是当前主路径：新 C99 后端把 C99 当 portable assembly，只要求 host C99 compiler
  能编译、链接、运行，不追求可读性、源码结构还原或原始变量名。
- 新 C99 后端必须独立于现有 AST/LoweredProgram C99 后端；现有 C99 只能作为 oracle/fallback/release 兜底，
  不能作为 MIR-C99 的内部实现、成功路径或语义补丁来源。
- MIR-C99 阶段验收必须满足：旧 helper-specific 成功路径已删除或不可达，合法程序可经
  `CoreBody -> PortableMIR -> minimal C99` 生成 host C99 compiler 可编译运行的产物，MIR-C99-built
  compiler 能复跑自举/回归，并且相关 `tests/` 通过。
执行规则：

- 每次只把一个主清单叶子或 MIR-C99 详细任务叶子标成 `[~]`；除 MIR-C99 详细任务列表外，本索引里的
  分组名不单独标状态。
- 每个实现叶子都先补通用合同和差分测试，再改 generic lowering / MIR-C99 后端。
- 可以运行 self-build 来收集 frontier，但 frontier 必须归因到通用语言结构；不能按 helper 名称、
  固定 statement count 或 `cmd/build` 特定 body shape 生成成功路径。
- 单叶子验证优先使用：`git diff --check`、coverage verifier、PortableMIR focused gate、full-language
  parity shard 和 no-silent-C99；`make check` 只作为阶段收口或高风险共享行为验证。
- `make backup-all` 只放到发布/最终收口，不作为每个叶子的提交门槛。

差分队列：

完整 MIR-C99 叶子清单见 `docs/todo_mir_c99_backend.md`。本节只保留上层索引，避免主 1s TODO 与
MIR-C99 专项 TODO 产生状态漂移。

0. MIR-C99-INDEPENDENT-BACKEND：新增独立 `PortableMIR -> minimal C99` target，作为当前第一主路径。
   - 合同叶子：定义 `MirC99Plan` / `MirC99Unit` / `MirC99Emitter` 的最小结构，命名上与现有 `C99Plan`
     区分；明确禁止调用现有 AST/LoweredProgram C99 planner/emitter 来通过 MIR-C99 测试。
   - 合同叶子：固定最小 C99 子集：function、prototype、extern、global、local temp、assignment、label、
     `goto`、`if (...) goto`、`return`、helper call、pointer load/store、field/index address。
   - 合同叶子：新增 absence gate，扫描 MIR-C99 后端不得依赖 AST body、`LoweredProgram` body、
     `src/codegen/c99*` 生产 emitter 或 helper-specific 成功路径。
   - 实现叶子：先输出单个 `.c` unit 跑通 return literal / call / local / branch HelloWorld parity；之后再扩到
     `MirC99Unit[]` 和 split-C，不能把单文件写成架构上限。

   详细任务列表：

   - [ ] MIR-C99-BACKEND-CONTRACTS：冻结独立 MIR-C99 合同。
     - [ ] 新增 `docs/mir_c99_backend.md`：说明 C99 是 portable assembly，列出禁止可读性/源码结构还原作为目标。
     - [ ] 在 `docs/portable_mir_language_coverage.md` 增加 MIR-C99 列：`missing` / `partial` / `done` / `reject`。
     - [ ] 新增 `tests/verify_mir_c99_independent_boundary.sh`：扫描 MIR-C99 源码不得 `use codegen.c99`、
       `use codegen.c99_build`，不得调用 `c99_codegen_generate`、`C99CodeGenerator`、现有 `C99Plan` 生产 emitter，
       不得读取 AST body / `LoweredProgram` body 作为成功路径。
     - [ ] 新增 `tests/verify_mir_c99_minimal_subset_contract.sh`：固定允许的低级 C99 语法子集和禁用项。
     - [ ] 新增 `tests/verify_mir_c99_oracle_parity_harness.sh`：统一生成 MIR-C99、现有 C99 oracle、host C compiler
       编译运行、stdout/stderr/exit diff 和 no-fallback 检查。

   - [ ] MIR-C99-BACKEND-SKELETON：建立独立后端文件和 CLI/backend 接线。
     - [ ] 新增 `src/codegen/mir_c99/plan.uya`：定义 `MirC99Plan`、`MirC99Unit`、prototype/global/function/helper
       引用表，全部动态增长。
     - [ ] 新增 `src/codegen/mir_c99/emitter.uya`：只消费 `MirTargetBackendRequest` / verifier-clean `PortableMirModule`
       和 `MirC99Plan`，输出 C bytes。
     - [ ] 新增 `src/codegen/mir_c99/types.uya`：只从 MIR type/layout metadata 生成 C typedef，不查 AST/checker。
     - [ ] 新增 `src/codegen/mir_c99/names.uya`：生成稳定 symbol/temp/block 名，不复用现有 C99 safe-name cache。
     - [ ] 新增 `src/codegen/mir_c99/driver.uya`：从 `MIR_TARGET_BACKEND_C99` request 生成 `MirC99Plan` 和 output。
     - [ ] 明确 `MIR_BACKEND_OUTPUT_C99_PLAN` 当前为 legacy 名称或迁移为 `MIR_BACKEND_OUTPUT_MIR_C99_PLAN`；
       迁移时同步 backend interface tests。

   - [ ] MIR-C99-BACKEND-UNIT-OUTPUT：先实现单 unit，保留多 unit 扩展点。
     - [ ] 支持单 `.c` 输出：include、typedef、extern prototype、function prototype、global、function body。
     - [ ] 支持 `MirC99Unit[]` 数据结构和 unit fingerprint，即使首版只生成一个 unit。
     - [ ] 支持 `.c` 输出编译命令和临时文件生命周期，不接入现有 split-C makefile writer。
     - [ ] 新增 smoke：return literal 经 MIR-C99 生成 `.c`，host C compiler 编译运行，exit 与现有 C99 oracle 一致。

   - [ ] MIR-C99-BACKEND-CFG：把 MIR CFG 映射到低级 C99。
     - [ ] MIR function -> C function。
     - [ ] MIR block -> C label。
     - [ ] MIR unconditional branch -> `goto bbN;`。
     - [ ] MIR conditional branch -> `if (cond) goto bbT; goto bbF;`。
     - [ ] MIR return -> `return expr;` / `return;`。
     - [ ] 支持 unreachable/trap diagnostic：MIR verifier 未通过时拒绝，不生成 C。
     - [ ] parity shard：local init + if return / nested branch / loop backedge。

   - [ ] MIR-C99-BACKEND-VALUES：把 MIR value/local 映射到 C temp。
     - [ ] 整数、bool、byte、usize/isize、f32/float、f64/double scalar temp。
     - [ ] 常量 literal、zero/null。
     - [ ] 一元/二元算术、比较、逻辑。
     - [ ] cast、sign/zero extend、truncate，以及 int/float/double 之间的显式转换。
     - [ ] float/double literal、comparison、arithmetic、return 和 local store/load。
     - [ ] value def/use 顺序检查：未定义或跨 block 非法 use 必须由 verifier 阻止。
     - [ ] parity shard：integer arithmetic/comparison/boolean combination。
     - [ ] parity shard：float/double arithmetic、comparison、cast 和 return。

   - [ ] MIR-C99-BACKEND-PLACE-MEMORY：把 MIR place/load/store 映射到 C 地址和赋值。
     - [ ] local slot address、load、store。
     - [ ] pointer deref load/store。
     - [ ] field address / load / store。
     - [ ] array index address / load / store。
     - [ ] slice ptr/len load。
     - [ ] aggregate copy / move 的最小 `memcpy` helper。
     - [ ] parity shard：struct field、array index、slice index、out-param writeback。

   - [ ] MIR-C99-BACKEND-TYPES-LAYOUT：用 MIR/layout metadata 生成最小 C 类型。
     - [ ] scalar typedef 映射：`i8/u8/i16/u16/i32/u32/i64/u64/usize/isize/bool/byte/f32/f64`，其中
       `f32` 映射 C99 `float`，`f64` 映射 C99 `double`。
     - [ ] pointer、array、slice struct。
     - [ ] struct / union / enum layout，字段顺序和 size/align 与现有 C99 oracle 对齐。
     - [ ] float/double 在 struct、array、slice、return value 和参数中的 size/align 与现有 C99 oracle 对齐。
     - [ ] error union layout。
     - [ ] function type / function pointer。
     - [ ] layout compile-time check 只能使用可移植 C99 形式（如 typedef-array assert），不依赖 C11
       `_Static_assert` 或 GCC-only 语义。
     - [ ] parity shard：`@size_of` / `@align_of` / struct-array-slice layout。

   - [ ] MIR-C99-BACKEND-CALLS：实现 MIR call 到 C call。
     - [ ] Uya direct call。
     - [ ] extern function call。
     - [ ] method call / monomorphized concrete call symbol。
     - [ ] function pointer call。
     - [ ] float/double 参数和返回值按 host C ABI 表达；缺少 ABI metadata 时明确 reject。
     - [ ] return value / out-param / aggregate return lowering。
     - [ ] call ABI metadata 缺失时明确 reject。
     - [ ] parity shard：multi-arg call、extern object call、method dispatch、generic instance call。
     - [ ] parity shard：float/double 参数、返回值、extern call。

   - [ ] MIR-C99-BACKEND-RUNTIME-HELPERS：只接入 MIR 显式要求的 helper。
     - [ ] `memcpy` / `memset` / `memcmp` / string primitive helper。
     - [ ] print/println 最小 stdout helper。
     - [ ] malloc/free/env/file IO runtime capability helper。
     - [ ] async frame runtime helper：poll、resume、await bind、frame allocation/free 和 async-frame-heap fallback。
     - [ ] `@syscall` capability：按 target profile 明确分流，不静默 fallback。
     - [ ] helper registry 由 MIR capability/helper refs 驱动，不做 AST helper discovery。
     - [ ] parity shard：HelloWorld、format minimal、memory/string primitive、file IO、async runtime smoke。

   - [ ] MIR-C99-BACKEND-ATOMICS：显式处理 `atomic T`，不把 C99 当作隐式原子语义提供者。
     - [ ] MIR atomic init/read/write 必须落到明确 runtime helper 或 target capability，不能用普通 C 赋值伪装原子。
     - [ ] 若当前 target 没有 portable helper，MIR-C99 必须给 capability diagnostic，并与现有 C99 oracle 的预期
       成功/失败策略记录到覆盖矩阵。
     - [ ] parity/reject shard：atomic i32 init/write/read；支持前可明确 reject，支持后必须与 oracle 行为一致。

   - [ ] MIR-C99-BACKEND-CLEANUP-ERROR：消费 MIR cleanup CFG。
     - [ ] `try` / `catch` 已展开到 MIR 后，C99 只输出对应 CFG。
     - [ ] `defer` / `errdefer` / lexical drop 只按 MIR cleanup edge 输出，不重新理解 AST。
     - [ ] error union success/fallback return。
     - [ ] parity shard：dynamic catch、defer local assign、lexical drop。

   - [ ] MIR-C99-BACKEND-ASYNC-FRAME：支持 async frame，不允许以首版 reject 代替。
     - [ ] 从 MIR/Core capability metadata 生成 async frame struct layout、state tag、result slot、await child slot 和 captured locals。
     - [ ] 生成 poll/resume state machine 的低级 C label/goto 形态，不回查 AST async body。
     - [ ] 支持 `await` / bind / direct await / loop await 的 frame 状态保存与恢复。
     - [ ] 支持 async error union return、cleanup edge、defer/errdefer 与 frame release。
     - [ ] 支持 async frame pool 和 `--async-frame-heap=on` fallback，行为与现有 C99 oracle 对齐。
     - [ ] parity shard：`tests/test_async_*.uya` 中当前 make check 覆盖的 async 用例必须 MIR-C99 / 现有 C99 oracle 一致。

   - [ ] MIR-C99-BACKEND-GLOBALS-IMPORTS：全局和链接输入。
     - [ ] global scalar / aggregate initializer。
     - [ ] string constants 和 dedupe。
     - [ ] extern globals。
     - [ ] `@c_import` sidecar object / cflags / ldflags 进入 MirC99 link plan，不复用现有 C99 sidecar 脚本作为内部实现。
     - [ ] parity shard：global aggregate、extern global、最小 `@c_import`。

   - [ ] MIR-C99-BACKEND-SPLIT-C：在单 unit 稳定后扩到多 unit。
     - [ ] `MirC99Unit[]` 按 module/source/function group 分配。
     - [ ] 生成独立 header / prototypes / deps。
     - [ ] 生成 MIR-C99 专用 Makefile 或 build manifest，不调用现有 split-C writer。
     - [ ] unit fingerprint 稳定，空白和路径差异不影响结构性摘要。
     - [ ] parity shard：多文件模块、parallel make、cache lock/stale lock 策略复验。

   - [ ] MIR-C99-BACKEND-PARITY-MATRIX：把完整语言样本逐项迁为 MIR-C99 / 现有 C99 oracle parity。
     - [ ] return/local/binary/branch/loop。
     - [ ] float/double literal、arithmetic、comparison、cast、call ABI。
     - [ ] multi-file module/use/import alias。
     - [ ] struct/union/enum/tuple。
     - [ ] array/slice/pointer。
     - [ ] generic function / generic struct / method instance。
     - [ ] interface/vtable。
     - [ ] error union / try / catch。
     - [ ] defer / errdefer / drop。
     - [ ] atomic。
     - [ ] SIMD vector/mask，target 不支持时明确 reject。
     - [ ] async frame / await / async error union / async cleanup；这些必须支持，不能作为首版 reject。

   - [ ] MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。
     - [ ] `cmd/build` / compiler source 经 parser/checker/CoreBody/PortableMIR 生成 minimal C99。
     - [ ] host C compiler 编译 MIR-C99 产物得到 compiler binary。
     - [ ] MIR-C99-built compiler 复跑 `cmd/build` self-build。
     - [ ] MIR-C99-built compiler 复跑 compiler regression、C99 output parity 和 full-language backend parity。
     - [ ] absence gate 确认整个自举过程中未调用现有 AST C99 backend 作为 MIR-C99 成功路径。

   - [ ] MIR-C99-BACKEND-RELEASE-GATES：收口和文档同步。
     - [ ] `make check` / `make check-hosted` 增加 MIR-C99 可选或必选门禁，按阶段切换。
     - [ ] release flow 区分现有 C99 oracle、MIR-C99 backend 和 microapp profile 结论。
     - [ ] backup flow 保留现有 C99 seed，新增 MIR-C99 seed 只在自举稳定后进入。
     - [ ] 文档同步：`docs/compiler_1s_architecture_design.md`、`docs/portable_mir_whitepaper.md`、
       `docs/coreir_lowered_program_whitepaper.md`、`docs/portable_mir_language_coverage.md`。
1. GENERIC-LANGUAGE-MIR：继续补齐合法 Uya 程序到 `CoreBody -> PortableMIR` 的通用路径。
   - 合同叶子：覆盖矩阵区分 sample parity、partial 和 generic done。
   - 合同叶子：新增/更新 absence gate，禁止 helper-specific 成功路径作为 MIR-C99 parity 证据。
   - 实现叶子：修通用 AST/Core/MIR lowering，不新增按函数名或固定 body shape 命中的生产路径。
2. GENERIC-CFG-MIR：通用控制流 lowering。
   - 合同叶子：固定 CoreBody block/if/while/for/break/continue/return 到 PortableMIR CFG 的 dump/verifier。
   - 实现叶子：`portable_mir_lower_core_body_to_module(...)` 支持多 block、branch、backedge、exit edge。
3. GENERIC-MEMORY-PLACE：通用 place/memory lowering。
   - 合同叶子：固定 local slot、field、index、slice ptr/len、pointer address、load/store 和 aggregate literal。
   - 实现叶子：PortableMIR 生成地址计算、load/store、copy/move/drop 所需 op。
4. GENERIC-CALL-RUNTIME：通用调用和 runtime capability。
   - 合同叶子：固定 Uya call、extern call、method call、runtime helper、`@c_import` object 和 `@syscall` capability。
   - 实现叶子：MIR-C99 用 C call ABI 表达参数、返回值和 extern/link plan。
5. GENERIC-CLEANUP-ERROR：通用 cleanup / error lowering。
   - 合同叶子：固定 `try`、`catch`、error union、`defer`、`errdefer`、lexical drop 和 cleanup edge。
   - 实现叶子：PortableMIR verifier 和 MIR-C99 backend 消费 cleanup CFG，不依赖 helper shape。
6. DIFFERENTIAL-PROGRAMS：合法程序组合差分。
   - 合同叶子：生成/维护嵌套控制流、循环、aggregate、call chain、cleanup、runtime 组合用例。
   - 验收叶子：所有 parser/checker 通过的用例都必须 MIR-C99 / 现有 C99 oracle 行为一致。
7. SCAFFOLD-RETIREMENT：清理 helper-specific 脚手架。
   - 合同叶子：所有 helper-specific 代码只能作为明确 reject/diagnostic 或待删除遗留；不能作为 successful
     MIR-C99 output 的依据。
   - 实现叶子：被 generic lowering 覆盖后，删除或禁用对应 helper-specific 成功路径。
   - 验收叶子：新增测试防止按函数名或固定 body shape 成功编译。
8. SELF-BUILD-C99-ACCEPTANCE：generic lowering 覆盖后先执行 MIR-C99 自举验收。
   - 验收叶子：编译器源码作为普通合法程序经 `CoreBody -> PortableMIR -> minimal C99` 生成 C99，可由 host C
     compiler 编译出 compiler binary。
   - 验收叶子：MIR-C99-built compiler 复跑 self-build、compiler regression 和现有 C99 output parity。
9. MAKE-MIR-C99-PATH：self-build 真实通过后，再切 `make uya` 主路径。
   - 合同叶子：固定 `UYA_BUILD_BACKEND=mir-c99|c99`、`make uya-c99`、MIR-C99 失败不静默 fallback、
     手动 C99 fallback 和 release flow 双路径语义。
   - 实现叶子：Makefile 接入 `UYA_BUILD_BACKEND`，保留 `make uya-c99`。
   - 实现叶子：`make uya` 默认走 MIR-C99 path，并确保输出 `bin/uya` 与 `bin/cmd/build`。
   - 实现叶子：`make cmds` / install 安装 `bin/cmd/build` 和 `bin/cmd/microapp`。
   - 实现叶子：backup / release flow 纳入 MIR-C99 seed，但仍保留 C99 seed fallback。
   - 收口叶子：跑 `make clean && make uya`、`make cmds`、microapp help、相关 regression 和
     MIR-C99 path no-silent-fallback 门禁。
10. MIR-C99-KPI：`make uya` MIR-C99 主路径稳定后再做性能收口。
    - benchmark 合同叶子：固定三次中位数、P95、peak RSS、arena peak 和 output bytes 字段。
    - 实测叶子：跑 `make bench-compiler-1s-check` 和三次 MIR-C99 cold build，记录结果到评估文档。
