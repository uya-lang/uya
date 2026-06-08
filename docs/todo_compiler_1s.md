# Uya 编译器 1 秒冷构建 TODO

**状态**: executable TODO, implementation pending
**更新日期**: 2026-06-07
**配套设计**: `docs/compiler_1s_architecture_design.md`
**配套评估**: `docs/compiler_1s_speed_assessment.md`

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
- Phase 9 前，native build compiler 路径 peak RSS 相比 Phase 0 至少下降 50%。
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
- [x] benchmark 输出 commit、branch、OS、arch、CPU 核数、`CFLAGS`、`CC_DRIVER`、是否启用 native/C99。
- [x] benchmark 主动清理 `bin/`、`src/build/`、`src/.uyacache/`。
- [x] benchmark 明确拒绝 daemon、object cache、IR cache 参与硬 KPI。
- [x] benchmark 通过 `/proc/<pid>/status` 或 `/proc/<pid>/smaps_rollup` 采样 `peak_rss_kb`。
- [x] benchmark 在缺少 `/proc` 的平台打印“RSS 未测量”，不能把该运行计入内存达标。
- [x] 编译器内部新增 arena 峰值统计输出字段。
- [x] benchmark 记录生成文件总字节数：
  - [x] C99 单文件大小。
  - [x] split-C 目录总大小。
  - [x] native executable / object 总大小。
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
- [x] native 输出不生成 debug info，不保留全量机器码临时副本。
- [x] diagnostic 默认延迟格式化；无错误时不构造长诊断字符串。
- [x] `UYA_DUMP_*` 相关 dump 输出不计入性能达标，并在 benchmark 中标记。
- [x] 新增内存回归脚本 `tests/verify_compiler_memory_budget.sh`。

测试：

- [x] `tests/verify_compiler_memory_budget.sh` 检查 benchmark TSV 含内存字段。
- [x] `tests/verify_compiler_memory_budget.sh` 检查缺少 RSS 采样时不会误报达标。
- [x] `tests/verify_compiler_memory_budget.sh` 检查 arena 字段存在且为非负整数。
- [x] `tests/verify_compiler_memory_budget.sh` 检查动态表字段存在且为非负整数。
- [x] `tests/verify_native_output_policy.sh` 检查 native ELF streaming 输出不生成 debug section，且临时缓冲不随机器码长度增长。

验证：

```bash
bash tests/verify_compiler_memory_budget.sh
bash tests/verify_dynamic_table_budget.sh
bash tests/verify_native_output_policy.sh
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
- [x] 更新 `make from-c` / `make from-c-native`，能恢复：

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
- [x] 清理后验证 `make from-c-native` 可恢复 `bin/cmd/build`。

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

## Phase 9: Native backend v1

- [x] 新建 `src/codegen/native/`。
- [x] 新建 `src/codegen/native/abi.uya`。
- [x] 新建 `src/codegen/native/machine.uya`。
- [x] 新建 `src/codegen/native/x86_64.uya`。
- [x] 新建 `src/codegen/native/elf64.uya`。
- [x] 新建 `src/codegen/native/main.uya`。
- [x] 定义 `MachineFunction`。
- [x] 定义 `MachineBlock`。
- [x] 定义 `MachineInst`。
- [x] 实现 Linux x86_64 SysV 调用约定。
- [x] 实现栈帧布局。
- [x] 实现线性扫描或保守寄存器分配。
- [x] 实现整数/指针基本指令。
- [x] 实现函数调用。
- [x] 实现全局数据段。
- [x] 实现字符串常量。
- [x] 实现 reloc / symbol table 最小集合。
- [x] 实现 ELF64 executable writer。
- [x] reloc / symbol table / string table / section table 全部动态增长。
- [x] 实现 nostdlib `_start`。
- [x] 实现 syscall bridge。
- [x] 实现 `NativeEmitter` 读取 `LoweredProgram`。
- [x] Native emitter 输出采用 streaming writer，不保留完整 ELF 镜像副本后再写盘。
- [x] relocation / symbol table 使用紧凑数组。
- [x] Native emitter 不允许写死最大函数数、block 数、指令数、reloc 数或 symbol 数。

首批 native 测试：

- [x] `tests/verify_native_abi_contract.sh`
- [x] `tests/verify_native_x86_64_encoding.sh`
- [x] `tests/verify_native_main_facade.sh`
- [x] `tests/verify_native_sysv_calling_convention.sh`
- [x] `tests/verify_native_stack_frame_layout.sh`
- [x] `tests/verify_native_conservative_regalloc.sh`
- [x] `tests/verify_native_x86_64_int_ptr_instructions.sh`
- [x] `tests/verify_native_x86_64_call_instructions.sh`
- [x] `tests/verify_native_global_data_segment.sh`
- [x] `tests/verify_native_string_constants.sh`
- [x] `tests/verify_native_reloc_symbol_table.sh`
- [x] `tests/verify_native_nostdlib_start.sh`
- [x] `tests/verify_native_syscall_bridge.sh`
- [x] `tests/verify_native_emitter_lowered_program.sh`
- [x] `tests/verify_native_emitter_streaming_output.sh`
- [x] `tests/test_native_main_only.uya`
- [x] `tests/test_native_int_ops.uya`
- [x] `tests/test_native_function_call.uya`
- [x] `tests/test_native_struct_field.uya`
- [x] `tests/test_native_error_union.uya`
- [x] `tests/test_native_global_init.uya`
- [x] `tests/verify_native_backend_smoke.sh`
- [x] `tests/verify_dynamic_table_growth.sh` 覆盖 native 大量 symbols、relocs、strings、sections。

验证：

```bash
bash tests/verify_native_abi_contract.sh
bash tests/verify_native_x86_64_encoding.sh
bash tests/verify_native_main_facade.sh
bash tests/verify_native_sysv_calling_convention.sh
bash tests/verify_native_stack_frame_layout.sh
bash tests/verify_native_conservative_regalloc.sh
bash tests/verify_native_x86_64_int_ptr_instructions.sh
bash tests/verify_native_x86_64_call_instructions.sh
bash tests/verify_native_global_data_segment.sh
bash tests/verify_native_string_constants.sh
bash tests/verify_native_reloc_symbol_table.sh
bash tests/verify_native_nostdlib_start.sh
bash tests/verify_native_syscall_bridge.sh
bash tests/verify_native_emitter_lowered_program.sh
bash tests/verify_native_emitter_streaming_output.sh
bash tests/verify_native_backend_smoke.sh
make tests-uya
```

阶段 KPI：

- [x] native emitter 生成最小可执行文件 `< 100ms`。
- [x] native smoke 全部与 C99 输出/退出码一致。
- [x] native smoke peak RSS 不高于 C99 smoke。

---

## Phase 9A: PortableMIR 完整语言主干

路线调整：Phase 10 的 native `cmd/build` 子集已经证明了最小 native writer、ELF、调用约定和
no-silent-C99 fallback 边界；下一步不再继续扩大 `LoweredBodyOp` 特例集合，而是先建立
`CoreBody` 和 `PortableMIR` 主干。`LoweredProgram` 继续作为 Core-level 闭包收敛和程序清单；
完整函数体语义先由 Phase 5B 的 `CoreBody` 冻结，再由 `PortableMIR` 承接为低级 CFG/value/memory IR，
并作为后续 native、PTX、exec、C99 等后端的共享入口。

- [x] 新增 `docs/portable_mir_whitepaper.md`，作为 Phase 9A 实现前的详细 MIR 合同。
- [x] Phase 5B 的 `CoreBody`、CoreIR dump、CoreIR verifier 和 CoreIR closure contract 门禁全部通过。
- [x] 定义 `PortableMIR` 顶层 module / function / block / value / type / local / inst / terminator 结构。
- [x] `PortableMIR` 所有表动态增长，不引入函数、block、inst、value、local 或 type 的固定语义上限。
- [x] 明确 `LoweredProgram` 的职责边界：functions、globals、types、interfaces、err_unions、async_frames、
  drop_defer_plans、helpers、worklist 和稳定符号顺序；不把 `LoweredBodyOp` 扩成完整语言 IR。
- [x] 实现 `LoweredProgram + CoreBody` 到 `PortableMIR` 的 lowering 合同，覆盖表达式、语句、控制流、
  load/store/address、atomic、SIMD vector/mask、call/return/branch、field/index/slice 地址计算、
  copy/move/drop 和 cleanup path。
- [x] MIR lowering 默认不查询 `TypedProgram`；若确实缺少 source/proof/capability metadata，先回补
  CoreIR 合同。
- [x] `PortableMIR` 显式记录 target-neutral layout metadata、calling convention 需求、hosted/freestanding
  runtime capability、address space 预留字段。
- [x] `PortableMIR` 显式记录 `MirFunction.flags.naked` / asm-only naked body，禁止 naked 函数走普通
  prologue/epilogue、stack slot、cleanup、drop、async 或隐式 return lowering。
- [x] 实现 MIR verifier，线性检查 block 终结、value 定义/使用、类型匹配、地址/布局、atomic / vector /
  mask 规则、cleanup path 和 target capability。
- [x] 明确 PortableMIR 并行构造合同：worker 只消费 frozen `LoweredProgram + CoreBody`，按 stable
  function order 归并 MIR functions、diagnostics、dump 和 backend fragments。
- [x] 新增 target backend 接口：后端只消费 `PortableMIR`，再映射到 `MachineModule`、`PtxModule`、
  exec bytecode 或 C99 plan。
- [x] native backend 主路径改为 `PortableMIR -> MachineModule -> object/executable`。
- [x] hosted native 第一阶段通过宿主 ABI / linker 承接 libc、pthread、filesystem、env、malloc、extern
  和 `@c_import` 链接需求。
- [x] freestanding native `cmd/build` 子集保留为回归边界，后续从已经通过 MIR 的能力逐步下沉，不阻塞
  hosted native 完整语言 parity。
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
- [x] 新增 hosted native / C99 完整语言差分 smoke，先覆盖多文件、泛型、方法、interface、error/defer/drop、
  slice/array/struct/union/enum、atomic、SIMD vector/mask、builtin、extern 和 `@c_import`。
- [x] 新增 `tests/verify_hosted_native_full_language_smoke.sh`。
- [x] 新增 `tests/verify_hosted_native_c_import_link_parity.sh`，覆盖最小 extern C object hosted linker handoff parity。
- [x] 保留 `tests/verify_native_cmd_build_no_silent_c99.sh`，确保 native 失败不会静默回落 C99。

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
bash tests/verify_native_mir_emitter.sh
bash tests/verify_native_hosted_link_contract.sh
bash tests/verify_native_cmd_build_regression_boundary.sh
bash tests/verify_portable_mir_c99_oracle_boundary.sh
bash tests/verify_portable_mir_parallel_determinism.sh
bash tests/verify_hosted_native_c_import_link_parity.sh
bash tests/verify_hosted_native_full_language_smoke.sh
bash tests/verify_native_cmd_build_no_silent_c99.sh
```

阶段 KPI：

- [x] `compile_files(...)` 16 参数调用缺口不再通过新增 one-off `LoweredBodyOp` 解决，而是成为 MIR lowering
  和 hosted native call ABI 的验收样本。
- [x] native 后端新增语言能力时，语言 lowering 只需改 `PortableMIR`，不在每个 target backend 重复实现。
- [x] `@naked_fn` 通过 CoreIR/MIR verifier 和 native 专用 path，不走普通函数栈帧。
- [x] MIR 并行构造不改变 dump、diagnostics、IDs 或 symbol order。
- hosted native 与 C99 对完整语言 smoke 的成功/失败、退出码、diagnostics 和运行结果一致（拆分执行；原始目标保留）：
  - [x] 接入 no-deps hosted native basic parity smoke：非 `--nostdlib` 的 `--native` 对无外部依赖基础程序真实生成 executable，并与 C99 退出码 / stdout / stderr 一致。
  - 用 `CoreBody -> PortableMIR` 函数体 lowering 覆盖 full-language smoke 的 main/helper 函数，不再依赖 build-seed `LoweredBodyOp` 特例：
    - [x] 将 hosted preflight 的 `return <int literal>` CoreBody 降成 PortableMIR body function，带 return operand/value，使 `helper_value() i32 { return 3; }` 与 `void` body 一起计入 MIR body 覆盖。
    - [x] 将 `return callee()` / 简单调用返回形状降成 PortableMIR call + return，覆盖 main/helper 的调用骨架。
    - 将 main 函数局部 const/var 初始化、基础 if-return 骨架迁入 CoreBody/MIR，不再依赖 build-seed `LoweredBodyOp` 特例：
      - [x] 在 CoreIR/PortableMIR 中冻结并验证最小 main local-call 初始化 + if-return preflight smoke，先覆盖 `const v: i32 = callee(); if v != 3 { return 1; } return 0;`。
      - [x] 将 full-language smoke 的 main 前置 i32 call locals 与基础 if-return 骨架接入 CoreBody/MIR，复杂类型/接口/drop 等仍保持 pending。
  - 接入 hosted native `@c_import` / extern linker handoff，确保 native link 对象与 C99 oracle 运行结果一致（拆分执行）：
    - [x] 新增最小 extern C 对象 hosted native/C99 parity smoke，要求 `--native` 真实生成 executable 并链接 sidecar object。
    - [x] 将 `@c_import` sidecar object 纳入 hosted native link plan，preflight dump 必须记录 object 数量和 extern symbol。
    - [x] 将最小 `extern fn add_i32(...)` call body 经 CoreBody/PortableMIR 降到 hosted native executable，并与 C99 oracle 退出码一致。
    - [x] 把 full-language smoke 中的 extern / `@c_import` 片段从明确 pending 推进为 parity 覆盖。
  - 覆盖 interface、drop/defer、error union、slice/array、atomic、SIMD vector/mask 和 builtin 的 C99 行为、已迁 MIR shard 的 hosted native/C99 parity，以及未迁 MIR shard 的明确拒绝语义（拆分执行）：
    - [x] `@size_of` / `@align_of` 标量 builtin shard 已迁入 CoreBody/PortableMIR hosted native/C99 parity，要求 CoreIR/MIR body preflight、真实 executable、退出码/stdout/stderr 一致，且不走 reject 或 C99 fallback。
    - slice/array + `@len` hosted native shard（拆分执行）：
      - [x] 数组字面量 `@len([1, 2, 3, 4])` shard 已迁入 CoreBody/PortableMIR hosted native/C99 parity，要求真实 executable、退出码/stdout/stderr 一致，且不走 reject 或 C99 fallback。
      - [x] slice 构造/索引 shard 已迁入 CoreBody/PortableMIR hosted native/C99 parity，要求真实 executable、退出码/stdout/stderr 一致，且不走 reject 或 C99 fallback。
    - error union `catch` + `@error_id` shard（拆分执行）：
      - [x] `@error_id(error.SmokeError)` shard 已迁入 CoreBody/PortableMIR hosted native/C99 parity，要求真实 executable、退出码/stdout/stderr 一致，且不走 reject 或 C99 fallback。
      - error union `catch` shard（拆分执行）：
        - [x] 常量输入 `maybe_value(const) catch { const; }` success/fallback shard 已迁入 CoreBody/PortableMIR hosted native/C99 parity，要求真实 executable、退出码/stdout/stderr 一致，且不走 reject 或 C99 fallback。
        - [x] 动态 error union `catch` shard 已迁入 CoreBody/PortableMIR hosted native/C99 parity，要求 fallback/success 运行路径一致，且不走 reject 或 C99 fallback。
    - drop/defer shard（拆分执行）：
      - [x] 最小 `defer { local = const; }` shard 已迁入 CoreBody/PortableMIR hosted native/C99 parity，要求 return-value 冻结和 cleanup edge/fact 通过 verifier，且不走 reject 或 C99 fallback。
      - [x] 最小 lexical drop shard 已迁入 CoreBody/PortableMIR hosted native/C99 parity，要求 `DROP` statement、return cleanup edge/fact 通过 verifier，且不走 reject 或 C99 fallback。
    - [x] interface/method dispatch shard 已迁入 CoreBody/PortableMIR hosted native/C99 parity，要求 method-dispatch semantic fact 通过 verifier，且不走 reject 或 C99 fallback。
    - [x] atomic i32 shard 已迁入 CoreBody/PortableMIR hosted native/C99 parity，要求 `CORE_EXPR_KIND_ATOMIC` init/write/read 通过 verifier，且不走 reject 或 C99 fallback。
    - [x] SIMD vector/mask shard 已迁入 CoreBody/PortableMIR hosted native/C99 parity，要求 `CORE_EXPR_KIND_VECTOR` / `CORE_EXPR_KIND_MASK` 通过 verifier，且不走 reject 或 C99 fallback。
  - [x] full-language smoke 默认只允许 MIR-backed successes 通过；未迁 MIR 的复杂 no-deps shard 必须明确拒绝，不再计入 parity 成功。

---

## Phase 10: Native build compiler 子集

本阶段保留为 freestanding/build-seed 子集清单和回归边界。Phase 9A 完成前，不继续扩展 ad hoc
`LoweredBodyOp` 来追 `cmd/build` 的下一个特殊形状；当前 `compile_files(...)` 缺口改为
PortableMIR/native hosted parity 的验收输入。

- [x] 统计 `cmd/build` 所需 language/runtime feature。
- [x] 为每类 feature 标注 native 支持状态。
- [x] 支持 parser/checker 必需 struct/array/slice 操作。
- [x] 支持 hash/intern table 必需内存操作。
- [x] 支持动态表 reserve/append/grow/free 必需内存操作。
- [x] 支持 diagnostics 必需字符串输出。
- [x] 支持 file IO 最小读取。
- [x] 支持 `snprintf` 等格式化需求的最小替代或 native bridge。
- [x] 支持 `malloc`/arena 需求。
- [x] 支持 arena peak 统计在 native-built compiler 下继续工作。
- [x] 支持 `memcpy`/`memset`/`strcmp`/`strlen`。
- [x] 支持 compiler build 所需 error union / defer。
- [x] 支持 compiler build 所需泛型实例。
- [ ] 通过 `PortableMIR` 路径生成 native `bin/cmd/build`。
  - [x] 修复 `-o ... --native` 被错误覆盖回 C99，保证 `uya build` / `cmd/build build` 的最小 native 成功子集真实进入 Native backend。
  - [x] 清理 2026-06-08 pre-MIR native self-build WIP：撤掉 `compile_files` / `parse_build_args` 专项摘要、loop/array access one-off `LoweredBodyOp` 扩展，以及 `native_build` direct machine-inst emission WIP。
  - [x] `bash tests/verify_native_cmd_build_stage1.sh` 只作为 freestanding build-seed 回归边界复验；若失败，仅修边界或迁 MIR，不新增 one-off `LoweredBodyOp`。
  - [x] 用 PortableMIR verifier/native MIR emitter 固定 `compile_files(...)` 16 参数调用 ABI 样本，要求 call inst 保留 16 个 operand、hosted runtime capability 和 target calling convention，不经 pre-MIR `LoweredBodyOp` 摘要。
  - [x] 用 CoreBody/PortableMIR 覆盖局部数组索引读取，先以 hosted native/C99 parity shard 固定运行结果。
  - [x] 明确 hosted/freestanding call ABI profile 在 PortableMIR 中的分流和 verifier 门禁，再迁入 `cmd/build` 所需调用形状。
  - [x] 清理 hosted no-deps 的 pre-MIR `LoweredProgram` helper 成功路径，改为只从 verifier-clean PortableMIR 求出 `return <int>` / `return callee()` 退出码；复杂 no-deps shard 保持明确 reject。
  - [x] 将 builtin、slice/error/defer/drop/interface/atomic/SIMD 等复杂 no-deps shard 逐项迁入 CoreBody/PortableMIR 后，再恢复真正 hosted native/C99 parity。
    - [x] 将 `@size_of` / `@align_of` 标量 builtin shard 迁入 CoreBody/PortableMIR hosted native/C99 parity，禁止 pre-MIR helper 成功路径。
    - [x] 将数组字面量 `@len([1, 2, 3, 4])` shard 迁入 CoreBody/PortableMIR hosted native/C99 parity。
    - [x] 将 slice 构造/索引 shard 迁入 CoreBody/PortableMIR hosted native/C99 parity。
    - [x] 将 `@error_id(error.SmokeError)` shard 迁入 CoreBody/PortableMIR hosted native/C99 parity。
    - [x] 将常量输入 error union `catch` success/fallback shard 迁入 CoreBody/PortableMIR hosted native/C99 parity。
    - [x] 将动态 error union `catch` shard 迁入 CoreBody/PortableMIR hosted native/C99 parity。
    - [x] 将最小 `defer { local = const; }` shard 迁入 CoreBody/PortableMIR hosted native/C99 parity。
    - [x] 将最小 lexical drop shard 迁入 CoreBody/PortableMIR hosted native/C99 parity。
    - [x] 将 interface/method dispatch shard 迁入 CoreBody/PortableMIR hosted native/C99 parity。
    - [x] 将 atomic i32 shard 迁入 CoreBody/PortableMIR hosted native/C99 parity。
    - [x] 将 SIMD vector/mask shard 迁入 CoreBody/PortableMIR hosted native/C99 parity。
  - [x] 上述 MIR/CoreBody 覆盖通过后，恢复 native `cmd/build` 生成门禁并开始真实 self-build 验证。
  - [x] 修复 hosted `cmd/build` self-build CoreIR preflight 的 `COREIR_VERIFY_ERR_INVALID_BODY_RANGE` frontier，使 `native_hosted_coreir_preflight` 达到 verifier-clean，并继续保留 pending bodies 统计。
  - 接入 hosted `cmd/build` verifier-clean PortableMIR self-build 的真实 emitter/handoff，消除 `native_hosted_portable_mir_lowering_missing`，仍不得回落 C99 或 build-seed `LoweredProgram` helper（拆分执行）：
    - [x] 固定 verifier-clean self-build handoff 诊断，报告 MIR body / extern / pending body frontier 和 entry callee 覆盖缺口，避免泛泛 `lowering_missing` 掩盖下一步。
    - [x] 固定 `main -> build_compiler_driver_main` wrapper 已纳入 CoreBody/PortableMIR 的证据，并把 first pending callee 精确到 `build_compiler_driver_run`，保持 pre-MIR helper 禁止。
    - [x] 将 first pending callee `build_compiler_driver_run` 的入口前缀纳入 CoreBody/PortableMIR 覆盖，并保持 pre-MIR helper 禁止。
    - 在 self-build reachable body 覆盖足够后，接入真实 hosted native emitter/handoff，消除 `native_hosted_portable_mir_lowering_missing`（继续拆分执行）：
      - [x] 将 `build_compiler_driver_run` 的简单局部初始化入口前缀纳入 CoreBody/PortableMIR 覆盖，并在 frontier 中报告覆盖 stmt 数。
      - [x] 将 `parse_build_args(...)` 调用和 `parse_result` 分支入口纳入 CoreBody/PortableMIR 覆盖，保持 hosted verifier-clean。
      - [ ] 将 native 输出路径选择前的 reachable 控制流继续迁入 PortableMIR，收敛 pending body frontier。
      - [ ] reachable body 覆盖足够后，接入真实 hosted native emitter/handoff，消除 `native_hosted_portable_mir_lowering_missing`。

测试：

- [x] 新增 `tests/verify_native_cmd_build_stage1.sh`。
- [x] 新增 `tests/verify_native_cmd_build_no_silent_c99.sh`，固定当前失败形状并防止静默回落。
- [ ] 用 native `cmd/build` 编译最小程序。
- [ ] 用 native `cmd/build` 编译一组 compiler regression。
- [ ] 用 native `cmd/build` 生成 C99 output，并与 C99-built compiler 输出比对。

验证：

```bash
bash tests/verify_native_cmd_build_stage1.sh
make check
```

阶段 KPI：

- [ ] native `cmd/build` 可构建自身。
- [ ] native `cmd/build` 自身构建 `< 3000ms`。
- [ ] native `cmd/build` 自身构建 peak RSS 相比 Phase 0 baseline 下降至少 50%。
- [ ] 不新增 `RETURN_*`、`LOCAL_CALL_*`、`IF_LOCAL_*` 等 one-off `LoweredBodyOp` 作为 Phase 10 继续推进方式。

---

## Phase 11: `make uya` native 主路径

- [ ] 增加 `UYA_BUILD_BACKEND=native|c99`。
- [ ] 新增 `make uya-c99` 保留旧路径。
- [ ] `make uya` 默认走 hosted native path。
- [ ] freestanding native path 保留为 build-seed / 下沉目标，不作为 hosted native 完整语言 parity 的阻塞项。
- [ ] `make uya` 输出：

```text
bin/uya
bin/cmd/build
```

- [ ] native path 失败时不静默 fallback；必须显式报错。
- [ ] `make uya-c99` 可作为手动 fallback。
- [ ] release flow 同时验证 native 与 C99。
- [ ] release flow 区分 hosted native 完整语言结论与 freestanding native build-seed 结论。
- [ ] backup flow 纳入 native seed。
- [ ] install flow 安装 `bin/cmd/build`。
- [ ] install flow 安装 `bin/cmd/microapp`（若 Phase 7A 已完成）。

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
- [ ] `make clean && make uya` peak RSS 不高于 native `cmd/build` 阶段值。
- [ ] arena 峰值和输出字节数没有回归。

---

## Phase 12: 差分与发布收口

- [ ] native-built compiler 跑 `make check`。
- [ ] C99-built compiler 跑 `make check`。
- [ ] 对比核心测试输出与退出码。
- [ ] 对比 diagnostics 文案。
- [ ] 对比 `src/main.uya` C99 output 的结构性摘要。
- [ ] 对 native 自举二轮产物做 normalized section hash。
- [ ] 文档更新：
  - [ ] `docs/compiler_1s_speed_assessment.md`
  - [ ] `docs/compiler_1s_architecture_design.md`
  - [ ] `docs/todo_compiler_1s.md`
  - [ ] `docs/UYA_BUILD_RUN.md`
  - [ ] `docs/TESTING.md`
  - [ ] `docs/c99_codegen_hotpath_benchmark.md`
- [ ] release 文档说明 native path 与 C99 fallback。
- [ ] release 文档说明 microapp 命名空间命令：
  `uya microapp build|pack|inspect|verify|run`。

语言兼容与后端完备性验收：

- [ ] 明确 main 分支语言兼容基线：以 main 分支的 `docs/uya.md`、`docs/grammar_formal.md`、
  `docs/grammar_quick.md`、`docs/builtin_functions.md` 和完整语言回归测试为准。
- [ ] C99 backend 支持完整 Uya 语言，不只支持 launcher / `cmd/build` / build seed 子集。
- [ ] Hosted native backend 经由 `PortableMIR` 支持完整 Uya 语言，不只支持 Phase 10 的 native `cmd/build` 子集。
- [ ] Freestanding native 能力按 hosted native 已验证的 MIR 能力逐步下沉，不阻塞完整语言 hosted parity。
- [ ] C99 与 native 对同一套完整语言回归输入给出一致的成功/失败、退出码、diagnostics 和可执行行为。
- [ ] 新增或整理完整语言后端差分套件，覆盖 parser/checker/codegen 主语言面：多文件模块、泛型、方法、
  接口、error union、`try/catch`、`defer/errdefer`、async、结构体/union/enum、slice/数组、指针、
  `atomic T`、`@vector(T, N)`、`@mask(N)`、`@c_import`、内建函数和标准库入口。
- [ ] Microapp / microcontainer 在语言层面完全兼容 main 分支，不引入 microapp 专属语法、关键字、
  内建函数或 checker 方言。
- [ ] Microapp 的限制只能是 capability / runtime / profile / host API 层面的限制；对不支持能力的拒绝必须是
  明确 diagnostic，不能表现为语言语义与 main 分支不兼容。
- [ ] `uya microapp build` 使用与普通 `uya build` 同源的 parser/checker 语言语义；差异只允许发生在
  microapp 安全策略、ABI、镜像格式和运行时能力裁决层。
- [ ] 发布说明记录 C99、native、microapp 三条路径相对 main 分支的语言兼容结论和已知非语言限制。

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
- [ ] 默认安全证明路径保留。
- [ ] C99 backend 完整支持 Uya 语言，并与 main 分支语言行为兼容。
- [ ] Hosted native backend 经由 `PortableMIR` 完整支持 Uya 语言，并与 C99 / main 分支语言行为兼容。
- [ ] Freestanding native build-seed 子集保持 no-silent-C99 fallback 和明确 capability diagnostic。
- [ ] Microapp / microcontainer 语言层面完全兼容 main 分支；仅允许 runtime/capability/profile 限制。
- [ ] native/C99 差分验证通过。
- [ ] release/backup 流程无死锁。
- [ ] 文档与 TODO 已同步。
- [ ] microapp CLI 不再依赖旧顶层 `pack-image` / `inspect-image` / `verify-image` 作为主入口。

---

## 当前下一步

建议下一次实施从 Phase 5B 开始：

1. 定义 `CoreBody` / `CoreStmt` / `CoreExpr`，并从 `TypedProgram` 冻结 resolved call target、field id、
   type id、proof 和 cleanup metadata。
2. 新增 CoreIR dump / verifier / closure contract 门禁。
3. 补 `@naked_fn` CoreIR 合同和并行 CoreLower deterministic merge 门禁。
4. 把当前 native subset 的简单函数体从 ad hoc `LoweredBodyOp` 迁到 `CoreBody`。
5. 在 CoreIR 门禁通过后新增 `PortableMIR` 基础数据结构和动态表生命周期。
6. 让 native backend 从 `PortableMIR` 导入 `MachineModule`。
7. 将 `compile_files(...)` 16 参数调用固定为 CoreIR、MIR lowering、hosted native call ABI 和
   target capability verifier 的首个真实验收样本。
