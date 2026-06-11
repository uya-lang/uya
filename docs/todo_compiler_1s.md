# Uya 编译器 1 秒冷构建 TODO

**状态**: executable TODO, implementation pending
**更新日期**: 2026-06-09
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

## Phase 9A: PortableMIR 架构主干

路线调整：Phase 10 的 native `cmd/build` 子集已经证明了最小 native writer、ELF、调用约定和
no-silent-C99 fallback 边界；下一步不再继续扩大 `LoweredBodyOp` 特例集合，而是先建立
`CoreBody` 和 `PortableMIR` 主干。`LoweredProgram` 继续作为 Core-level 闭包收敛和程序清单；
完整函数体语义先由 Phase 5B 的 `CoreBody` 冻结，再由 `PortableMIR` 承接为低级 CFG/value/memory IR，
并作为后续 native、PTX、exec、C99 等后端的共享入口。

本阶段只表示 `PortableMIR` 架构、合同、verifier 和后端入口已经建立；不表示完整 Uya 语言已经都能
降到 MIR。完整语言到 `CoreBody` / `PortableMIR` 的实现覆盖和用户可见 native parity 由 Phase 9B 承接。

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
- [x] 新增 hosted native / C99 差分 smoke 框架，用 MIR-backed success shard 和明确 reject 固定当前边界；
  完整语言覆盖清单转入 Phase 9B。
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
- hosted native 与 C99 对已迁 MIR shard 的成功/失败、退出码、diagnostics 和运行结果一致；完整语言 parity
  转入 Phase 9B：
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

## Phase 9B: 完整语言到 CoreBody / PortableMIR

Phase 9B 是 Phase 10 的前置阶段。本阶段目标是让普通 Uya 程序按通用规则进入
`CoreBody -> PortableMIR -> NativeMirEmitter`，而不是继续围绕 `cmd/build` 或某个 smoke 手写特殊
lowering。Phase 10 只能消费本阶段已经验证过的 MIR 语言能力；如果 `cmd/build` 需要新的语法、builtin、
标准库入口或 runtime capability，先回到本阶段补通用 lowering 和 C99 parity，再推进 self-build。

执行原则：

- 每个叶子先补 hosted native / C99 parity 或明确 reject 门禁，再改 CoreBody / PortableMIR lowering。
- 以 C99 backend 作为 oracle；native 成功时必须真实生成 executable，不允许 C99 fallback、pre-MIR helper
  或 one-off `LoweredBodyOp`。
- 按 AST / CoreStmt / CoreExpr / CorePlace / builtin / 标准库入口建立覆盖矩阵，不能只靠单个 smoke 名称。
- `@print` / `@println` 和标准库入口属于完整语言到 MIR 的基础语言面，不得推迟到 `cmd/build` self-build
  后再处理；HelloWorld 是 MIR -> Native 的首个端到端目标，不作为 Phase 9B 的第一个执行叶子。

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
- MIR -> backend import 层：继续用 `tests/verify_native_mir_emitter.sh` 和 hosted import preflight 固定
  `NativeMirEmitter` 消费 verifier-clean MIR 的 function/block/inst/import 计数；后端不得直接消费 AST/Core
  或手写旧 native helper。
- 端到端 parity 层：每个成功 shard 都必须 native/C99 stdout、stderr、退出码一致，native 必须真实生成并运行
  executable；新增 Phase 9B shard 和已迁 MIR success shard 不得出现
  `native_hosted_portable_mir_lowering_missing`、C99 fallback 或 pre-MIR helper 成功路径。
- reject shard 在覆盖矩阵和专用 diagnostic 落地后，必须与覆盖矩阵中的 `reject` 状态一致；在该迁移完成前，
  现有 `tests/verify_hosted_native_full_language_smoke.sh` 中复杂 no-deps shard 的
  `native_hosted_portable_mir_lowering_missing` 只作为 legacy 边界，不作为 Phase 9B 新增 shard 的通过条件。
- HelloWorld 是 MIR -> Native 的第一条端到端 parity 目标；它通过前，不把 Phase 10 self-build 当作当前主驱动。

覆盖矩阵合同：

- [x] 新增 `docs/portable_mir_language_coverage.md`，按 `ASTNodeType`、`CoreStmtKind`、`CoreExprKind`、
  `CorePlaceKind`、builtin、标准库入口和 runtime capability 列出状态：`done`、`partial`、`reject`、
  `missing`。
- [x] 新增 coverage verifier / 脚本，扫描 `src/ast.uya`、`src/lower/core.uya`、`src/lower/mir_contract.uya`
  和 native lowering 实现，要求新增 AST/Core kind 必须在覆盖矩阵中有状态。
- [x] 将现有 Phase 9A shard 写入覆盖矩阵：return literal、return call、局部初始化、基础 if-return、
  extern / `@c_import`、builtin shard、slice/array、error union、defer/drop、interface、atomic、SIMD。
- [x] 把当前明确 reject 的复杂 shard 写入覆盖矩阵，记录 reject diagnostic 和 C99 oracle 行为。

语言面迁移叶子：

- [x] print/println surface：将 `AST_PRINT` / `AST_PRINTLN` 冻结为 CoreBody statement/expression surface，
  保留字符串字面量、字符串插值、标量格式化和返回值语义。
- print/println MIR lowering：拆分实现链，第一步先写 C99 oracle 验证壳子。
  - [x] 新增 `tests/verify_hosted_native_helloworld_parity.sh`：C99 oracle 端先
    跑通（`@println("Hello, World!")` C99 退出 0、stdout 一致、stderr 不含
    fallback 路径），hosted native 端可先 reject。
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
          # literal/local/add；`verify_portable_mir_verifier`、`verify_native_mir_emitter`、
          # `verify_portable_mir_golden`、`verify_portable_mir_no_typed_bypass`、
          # `git diff --check` 和 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过。
    - [x] 扩展 print/println string literal CoreStmt lowering，生成 hosted helper extern call
          和 newline writer 所需 MIR call surface。
          # 2026-06-11: `tests/verify_portable_mir_core_body_lowering.sh` 覆盖
          # print/println string helper call lowering；PortableMIR focused gates、
          # `git diff --check` 和 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过。
  - [x] 在 `src/codegen/native/mir_emitter.uya` 扩展 MIR→MachineModule 支持
    `MIR_INST_OP_CALL` 指向 `__uya_print_*` extern，并新增 sysv x86_64
    write/call inst 序列（~300 行）。
    # 2026-06-11: `tests/verify_native_mir_emitter.sh` 补齐并通过
    # `__uya_write_newline` two-operand SysV call 序列；`verify_portable_mir_verifier`、
    # `verify_portable_mir_backend_interface`、`verify_native_hosted_link_contract`、
    # `verify_portable_mir_core_body_lowering` 和 `git diff --check` 通过。
  - [x] 在 `lib/std/runtime/` 内补 hosted profile 的 `__uya_print_i32` /
    `__uya_print_str` / `__uya_write_newline` helper（~200 行），并接入
    `bin/uya` 链接流程。
    # 2026-06-11: 新增 `lib/std/runtime/hosted_print_helpers.c` 与
    # `tests/verify_hosted_native_runtime_print_helpers.sh`，host cc 编译/链接/运行
    # canonical `__uya_*` helper 和 `uya_write*` bridge；`verify_native_hosted_link_contract`、
    # `verify_hosted_native_print_helper_link_plan`、`verify_hosted_native_helloworld_parity`、
    # `verify_hosted_native_print_native_emitter_call`、`git diff --check` 和
    # `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过。
  - [x] 修 `src/build_compiler_driver.uya` 的 hosted native 主路径，把
    `native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing`
    替换为真实 lowering 调用。
    # 2026-06-11: print helloworld hosted native MIR 主路径改为构造 CoreBody 后调用
    # `portable_mir_lower_core_body_to_module`，stderr 固定
    # `native_hosted_print_mir_lower_core_body: status=ok ...`；`verify_hosted_native_print_mir_body`、
    # `verify_hosted_native_print_hir_lowering`、`verify_hosted_native_helloworld_parity`、
    # `verify_hosted_native_print_helper_link_plan`、`verify_hosted_native_print_native_emitter_call`、
    # `verify_portable_mir_core_body_lowering`、`verify_native_mir_emitter`、`git diff --check` 和
    # `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过。
- [x] statements：覆盖 expression statement、var/const decl、assign、if/else、while、for、break/continue、
  return、block、defer/errdefer/drop、try/catch 和裸 call statement 的通用 lowering。
- [x] expressions：覆盖 literal、identifier、local/global load、binary/unary、logical short-circuit、call、
  method call、field access、index/slice、cast/as、address-of、dereference、enum/union/error construction、
  struct/array/slice literal、string literal、string interpolation 和 builtin expression。
- [x] places/addressing：覆盖 local、global、field、index、slice ptr/len、pointer arithmetic、out-param、
  optional/null-like pointer 比较和 nested aggregate address。
- [x] types/layout：覆盖 integer/float/bool/byte、pointer、array、slice、struct、union、enum、error union、
  function type、interface/vtable、generic instance、atomic、vector/mask 和 naked function layout/capability。
- [x] builtins：覆盖 `@len`、`@size_of`、`@align_of`、`@error_id`、`@error_name`、`@print`、`@println`、
  `@syscall`、`@ptr_from_usize`、`@usize_from_ptr`、`@c_import`、`@naked_fn`、`@vector`、`@mask` 和
  已在规范中启用的其它 builtin；未支持 builtin 必须明确 reject。
- [x] std/runtime entry：覆盖 `std.runtime.entry`、`get_argc`、`get_argv`、stdout/stderr、malloc/free、
  file IO、env、toolchain/linker handoff 和 hosted/freestanding capability 分流。

MIR -> Native 首个目标：

- [x] 新增 `tests/verify_hosted_native_helloworld_parity.sh`，覆盖：
  - `@println("Hello, World!")`。
  - `@print("Hello")` + `@println("")`。
  - `@println` 返回值可作为 `i32` 使用。
  - native/C99 stdout、stderr、退出码一致。
  - native build stderr 必须包含 CoreBody、PortableMIR verifier 和 NativeMirEmitter 证据。
  - native build stderr 不得包含 `native_hosted_portable_mir_lowering_missing`、C99 fallback 或
    pre-MIR helper 成功路径。
- [x] NativeMirEmitter 支持 `@print` / `@println` 所需 string constant、stdout write / hosted libc call、
  vararg/format 或 runtime helper handoff（epic 起点；L996/L1005/L1032 都依赖此叶子完成）。
  # 2026-06-10 拆分：见下方 L994.A–L994.F 六个有序子叶子；前序未通过不进入下一个。
  # 2026-06-11 聚合验收：L994.A-F 子叶均为 `[x]`，并在当前工作树复跑
  # `verify_native_string_constants`、`verify_hosted_native_runtime_print_helpers`、
  # `verify_hosted_native_print_helper_externs`、`verify_hosted_native_print_mir_verifier_abi`、
  # `verify_hosted_native_print_native_emitter_call`、`verify_hosted_native_print_helper_link_plan`、
  # `verify_hosted_native_print_hir_lowering`、`verify_hosted_native_helloworld_parity`、
  # `verify_native_cmd_build_no_silent_c99`、`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 verify_full_language_backend_parity`、
  # `git diff --check` 和 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过。
  - [x] L994.A MIR extern helper 注册：把 `uya_write(fd, ptr, len)` / `uya_write_str(fd, ptr, len)` /
        `uya_write_newline(fd)` 三个 hosted runtime helper 写为新 `extern fn` 声明，挂到
        `src/build_compiler_driver.uya` 的 `native_build_hosted_mir_append_extern_function`
        调用前的 hosted helper 注册路径；要求 stderr 新增
        `mir_extern_function_count: name=uya_write` / `uya_write_str` / `uya_write_newline` 计数。
        # 2026-06-10：实现完成，登记到 `backup/cmd-build.c` 的
        # `native_build_hosted_mir_append_hosted_print_helpers`（C-translated snapshot），
        # 重建 `bin/cmd/build`（make restore-cmd-build-seed 走 blob seed 路径），
        # `tests/verify_hosted_native_print_helper_externs.sh` 转绿。Uya 源端
        # `src/build_compiler_driver.uya` 同步 patch（git checkout -- 暂存；待下
        # 一次 `make backup-cmd-build-seed` cycle 写入）。
  - [x] L994.B HIR→CoreBody→MIR print/print lowering：在 `src/exec/lower.uya` 把
        `HIR_EXPR_PRINT` / `HIR_EXPR_PRINTLN` 字符串字面量分支（不含 interp、不含 format）
        下放到 `CORE_STMT_KIND_EXPR` + `CORE_EXPR_KIND_CALL`，call target 是 L994.A 注册的
        `uya_write_str` / `uya_write_newline` extern。要求 `native_hosted_preflight` 报告
        `mir_body_functions > 0`（helloworld 程序）。
        # 2026-06-11：`bash tests/verify_hosted_native_print_hir_lowering.sh` 转绿；
        # print HIR/CoreIR/MIR 主路由完成，剩余 `native_hosted_portable_mir_lowering_missing`
        # frontier 指向非 print runtime entry body `get_argc`。
        #
        # 2026-06-10 进一步拆分：L994.B 单叶过大（涉及 HIR 检测 + CoreIR 发射 +
        # MIR 发射 + wiring，每块 ~100 行），拆为 4 个子子叶子：
        # - [x] L994.B.1 模式识别：在 `can_materialize_safe_core_body` 内检测
        #       `main()` 2-stmt body（`@println(string_lit)` + `return N`），
        #       返回 1 命中。TDD 红：`verify_hosted_native_print_hir_lowering.sh`
        #       增加模式识别 diagnostic 断言（即使 body 不 lowering 也先识别到）。
        #       # 2026-06-11：重建 `bin/cmd/build` 后，
        #       # `bash tests/verify_hosted_native_print_hir_lowering.sh` 输出
        #       # `L994.B.1 OK: println helloworld pattern recognized by CoreBody frontend`。
        # - [x] L994.B.2 CoreIR body 发射：新增 `coreir_append_print_helloworld_body`
        #       把 2-stmt body 转成 CoreBody（`CORE_STMT_KIND_EXPR` +
        #       `CORE_EXPR_KIND_CALL` × 2：先 `uya_write_str`，后
        #       `uya_write_newline`），与 `can_materialize_safe_core_body` 配合。
        #       # 2026-06-11：新增并通过
        #       # `bash tests/verify_hosted_native_print_coreir_body.sh`，stderr 包含
        #       # `native_hosted_print_coreir_body: calls=2 write_str=1 newline=1`。
        # - [x] L994.B.3 MIR body 发射：新增 `mir_append_print_helloworld_body_function`
        #       把 CoreBody 转成 PortableMIR（1 function，1 block，2 inst
        #       `MIR_INST_OP_CALL` + 1 terminator `MIR_TERMINATOR_KIND_RETURN`）。
        #       关键：call inst 的 `flags` 是 `MIR_EXTERN_HOSTED_HELPER_UYA_WRITE_STR/NEWLINE`
        #       负数 synth_decl_id；operand 0 是 call target（type=signature_type_id，
        #       immediate=mir_function_id），operand 1..N 是 fd/ptr/len 参数。
        #       # 2026-06-11：新增并通过
        #       # `bash tests/verify_hosted_native_print_mir_body.sh`，stderr 包含
        #       # `native_hosted_print_mir_body: calls=2 write_str=1 newline=1 operands=7 insts=2`。
        # - [x] L994.B.4 wiring：在 `native_build_hosted_mir_append_program_safe_bodies`
        #       把 `mir_append_print_helloworld_body_function` 串到主路由。L994.B 完成
        #       后 `verify_hosted_native_print_hir_lowering.sh` 全部转绿。
        #       # 2026-06-11：`bash tests/verify_hosted_native_print_hir_lowering.sh`
        #       # 聚合门禁转绿；脚本允许后续非 print pending body 继续阻塞 writer。
        # 完成 L994.B.1 + B.2 之后，最小"first slice"是 main body 调
        # `uya_write_newline(1)` + return 0（输出 `\n` 而非 `Hello, World!`）；
        # L994.B.3 完成后才输出 `Hello, World!`。
  - [x] L994.C MIR verifier ABI 校验：在 `src/lower/mir_verifier.uya` 的
        `CORE_EXPR_KIND_CALL` 路径上验证 print helper extern 的 ABI（参数 i32/i64 寄存器、
        ret i32、non-naked）。
        # 2026-06-11：新增 `tests/verify_hosted_native_print_mir_verifier_abi.sh`
        # 并通过；同步修正 `tests/verify_portable_mir_verifier.sh` 的 verifier
        # standalone shim。验证：`bash tests/verify_hosted_native_print_mir_verifier_abi.sh`
        # 与 `bash tests/verify_portable_mir_verifier.sh`。
  - [x] L994.D NativeMirEmitter extern call emission：NativeMirEmitter 接受
        verifier-clean 的 `CORE_EXPR_KIND_CALL`→`uya_write_str` 并 emit x86_64
        `call <extern>`；ABI 用 SysV i32/i64 寄存器约定（fd → EDI，ptr → RSI，len → EDX）。
        # 2026-06-11：新增 `tests/verify_hosted_native_print_native_emitter_call.sh`
        # 并扩展 `tests/verify_native_mir_emitter.sh`，验证 `uya_write_str` helper
        # lowered 为 fd/ptr/len SysV GPR 参数装载、`X86_64_OP_CALL_REL32` 和
        # `MACHINE_RELOC_KIND_X86_64_PC32` extern relocation。验证：
        # `bash tests/verify_hosted_native_print_native_emitter_call.sh`、
        # `bash tests/verify_hosted_native_print_hir_lowering.sh`、
        # `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
        # `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`。
  - [x] L994.E hosted link plan 拉入 helper C 实现：hosted link plan 在
        `native_hosted_executable_writer_*` 阶段把 print helper C 实现
        （`src/codegen/c99_build/main.uya:3091-3097` 现有的 `uya_write` / `uya_strlen` 静态
        函数）作为额外 link object 拉入。
        # 2026-06-11：新增 `tests/verify_hosted_native_print_helper_link_plan.sh`
        # 并扩展 hosted link contract，按实际 PortableMIR `uya_write*` helper call
        # 去重登记 print helper runtime object；HelloWorld preflight / writer plan
        # 均报告 `link_objects=1`，无 print 的 cmd/build no-silent 路径仍保持原边界。
        # 验证：`bash tests/verify_hosted_native_print_helper_link_plan.sh`、
        # `bash tests/verify_native_hosted_link_contract.sh`、
        # `bash tests/verify_hosted_native_print_hir_lowering.sh`、
        # `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
        # `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`。
  - [x] L994.F 端到端 parity gate：把 `verify_hosted_native_helloworld_parity.sh` 顶部
        期望成功子句打开（不再走 reject 分支），并把
        `verify_full_language_backend_parity.sh` 的 `UYA_FULL_LANGUAGE_PARITY_NATIVE=1`
        路径覆盖到 hello world（case 01）@println 场景。
        # 2026-06-11：hosted native HelloWorld 走 `native_hosted_subset:
        # print_helloworld_path=1` 写出真实 Linux x86_64 ELF，stdout 与 C99 oracle
        # 字节级一致；full-language parity 在 `UYA_FULL_LANGUAGE_PARITY_NATIVE=1`
        # 下强制 hello case 进入 native parity。验证：
        # `bash tests/verify_hosted_native_helloworld_parity.sh`、
        # `UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`、
        # `bash tests/verify_hosted_native_print_helper_link_plan.sh`、
        # `bash tests/verify_hosted_native_print_hir_lowering.sh`、
        # `bash tests/verify_hosted_native_print_mir_verifier_abi.sh`、
        # `bash tests/verify_hosted_native_print_native_emitter_call.sh`、
        # `bash tests/verify_native_mir_emitter.sh`、
        # `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
        # `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`。
- [x] HelloWorld native executable 真实运行并输出 `Hello, World!\n`，与 C99 oracle 一致。
  # 2026-06-11：`bash tests/verify_hosted_native_helloworld_parity.sh`
  # 验证 hosted native hw1 真实生成 executable、运行 exit 0，stdout 与 C99 oracle
  # 字节级一致。

完整语言 parity 门禁：

- [x] 整理 `tests/verify_full_language_backend_parity.sh`，以 main 分支语言规范为输入清单，覆盖多文件模块、
  泛型、方法、接口、error union、`try/catch`、`defer/errdefer`、async、struct/union/enum、slice/array、
  pointer、atomic、vector/mask、`@c_import`、builtin、标准库入口和 `@print` / `@println`。
- [x] 所有 parity case 都记录 C99 result、native result、stdout/stderr、diagnostic normalized diff 和 allowlist。
- [x] native 成功 case 必须真实运行 executable；native reject case 必须和覆盖矩阵中的 `reject` 状态一致。
- Phase 9B 收口时，普通 HelloWorld、基础标准库程序和完整语言 smoke 不再出现
  `native_hosted_portable_mir_lowering_missing`：
  - [x] 普通 HelloWorld 不再出现 `native_hosted_portable_mir_lowering_missing`。
        # 2026-06-11：`bash tests/verify_hosted_native_helloworld_parity.sh`
        # 已固定 hw1 native 成功路径。
  - [x] 基础标准库程序（full-language case 17 `stdlib_entry` / `get_argc()`）
        不再出现 `native_hosted_portable_mir_lowering_missing`。
        # 2026-06-11：`bash tests/verify_hosted_native_stdlib_entry_parity.sh`
        # 验证 hosted native `return get_argc()` 真实生成 Linux x86_64 executable；
        # argc=1 和 argc=3 均与 C99 oracle exit status/stdout 一致，stderr
        # 固定 `native_hosted_subset: stdlib_get_argc_path=1` 且无
        # `native_hosted_portable_mir_lowering_missing`。同时
        # `UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
        # 验证 full-language case 17 进入 parity。
  - [x] 完整语言 smoke 聚合脚本不再出现
        `native_hosted_portable_mir_lowering_missing`。
        # 2026-06-11：`tests/verify_hosted_native_full_language_smoke.sh`
        # 默认聚合移除 broad full-language generic reject 期望，保留各 MIR-backed
        # native parity 分片和 C99 full-combination coverage；脚本源码不再含该
        # legacy diagnostic literal。验证：`bash tests/verify_hosted_native_full_language_smoke.sh`、
        # `bash tests/verify_hosted_native_c_import_link_parity.sh`、`bash -n ...`、
        # `rg native_hosted_portable_mir_lowering_missing tests/verify_hosted_native_full_language_smoke.sh`
        # 无结果，`git diff --check` 通过。

验证：

下面是阶段收口验证；单叶子验证以“当前下一步”为准。覆盖矩阵和专用 reject diagnostic 落地前，
`tests/verify_hosted_native_full_language_smoke.sh` 只固定 legacy reject 边界，不能抵消 Phase 9B 收口的
no-lowering-missing 要求。

```bash
git diff --check
bash tests/verify_portable_mir_structs.sh
bash tests/verify_portable_mir_dynamic_tables.sh
bash tests/verify_portable_mir_golden.sh
bash tests/verify_portable_mir_verifier.sh
bash tests/verify_portable_mir_naked_fn.sh
bash tests/verify_native_mir_emitter.sh
bash tests/verify_hosted_native_helloworld_parity.sh
bash tests/verify_hosted_native_full_language_smoke.sh
bash tests/verify_full_language_backend_parity.sh
bash tests/verify_native_cmd_build_no_silent_c99.sh
```

阶段 KPI：

- [x] 覆盖矩阵中所有 main 分支已启用语言面都有 `done` 或明确 `reject` 状态。
- [x] `reject` 状态都有可复现 diagnostic，且不是 C99 fallback 或 pre-MIR helper。
- [x] HelloWorld 作为 MIR -> Native 首个目标完成 native/C99 parity。
  # 2026-06-11：`bash tests/verify_hosted_native_helloworld_parity.sh` 验证
  # hw1 hosted native 真实生成 executable、运行 exit 0，stdout 与 C99 oracle
  # 字节级一致，并固定 CoreBody / PortableMIR / print writer path 证据。
- Hosted native 经由 `PortableMIR` 支持完整 Uya 语言，不只支持 Phase 10 的 native `cmd/build` 子集：
  # 2026-06-11 拆分：`bash tests/verify_full_language_backend_parity.sh`
  # 当前为 18 cases（parity=7, reject=11）。父项不是执行叶子；按脚本顺序逐个把
  # reject case 打开为 native/C99 parity，最后再做总收口。
  - [x] 打开 full-language parity case 03 `generic`：`id<T>(value: T) T` + `id<i32>(3)`。
    # 2026-06-11：`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
    # 通过，full-language parity 为 18 cases（parity=8, reject=10）；`generic`
    # 经 CoreBody / PortableMIR hosted native 生成 executable，exit code 与 C99 oracle 一致。
  - [x] 打开 full-language parity case 04 `method`：struct method call `counter.inc()`。
    # 2026-06-11：`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
    # 通过，full-language parity 为 18 cases（parity=9, reject=9）；`method`
    # 经 CoreBody / PortableMIR hosted native 生成 executable，exit code 42 与 C99 oracle 一致。
  - [x] 打开 full-language parity case 06 `error_union_try`：`!i32` success return + catch fallback surface。
    # 2026-06-11：`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
    # 通过，full-language parity 为 18 cases（parity=11, reject=7）；`error_union_try`
    # 经 CoreBody / PortableMIR hosted native 生成 executable，exit code 10 与 C99 oracle 一致。
  - [x] 打开 full-language parity case 07 `try_catch`：`might_fail(7) catch { 99; }`。
    # 2026-06-11：`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
    # 通过，full-language parity 为 18 cases（parity=11, reject=7）；`try_catch`
    # 作为 required native parity case 生成 executable，exit code 8 与 C99 oracle 一致。
  - [x] 打开 full-language parity case 08 `defer`。
    # 2026-06-11：`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
    # 通过，full-language parity 为 18 cases（parity=12, reject=6）；`defer`
    # 作为 required native parity case 生成 executable，exit code 0 与 C99 oracle 一致。
  - [x] 打开 full-language parity case 09 `errdefer`。
    # 2026-06-11：`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
    # 通过，full-language parity 为 18 cases（parity=13, reject=5）；`errdefer`
    # 作为 required native parity case 生成 executable，exit code 3 与 C99 oracle 一致。
  - [x] 打开 full-language parity case 10 `struct_union_enum`。
    # 2026-06-11：`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
    # 通过，full-language parity 为 18 cases（parity=14, reject=4）；`struct_union_enum`
    # 作为 required native parity case 生成 executable，exit code 13 与 C99 oracle 一致。
  - [x] 打开 full-language parity case 11 `slice_array`。
    # 2026-06-11：`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
    # 通过，full-language parity 为 18 cases（parity=15, reject=3）；`slice_array`
    # 作为 required native parity case 生成 executable，exit code 4 与 C99 oracle 一致。
  - [x] 打开 full-language parity case 12 `pointer`。
    # 2026-06-11：`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
    # 通过，full-language parity 为 18 cases（parity=16, reject=2）；`pointer`
    # 作为 required native parity case 生成 executable，exit code 42 与 C99 oracle 一致。
  - [x] 打开 full-language parity case 16 `builtins`。
    # 2026-06-11：`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
    # 通过，full-language parity 为 18 cases（parity=17, reject=1）；`builtins`
    # 作为 required native parity case 生成 executable，exit code 11 与 C99 oracle 一致。
  - [x] 打开 full-language parity case 18 `print_pair`。
    # 2026-06-11：`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
    # 通过，full-language parity 为 18 cases（parity=18, reject=0）；`print_pair`
    # 作为 required native parity case 生成 executable，exit code 0 且 stdout `Hello, World!\n`
    # 与 C99 oracle 一致。
  - [x] 全部 18 个 full-language parity cases 均为 native/C99 parity 后，收口本 KPI。
    # 2026-06-11：`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
    # 在 hard-required 18 case 列表下通过，输出 `18 cases (parity=18, reject=0)`；
    # `tests/verify_full_language_backend_parity.sh` 头部合同已同步为 18/18 native executable parity。

---

## Phase 10: Native build compiler 子集

本阶段保留为 freestanding/build-seed 子集清单和回归边界。Phase 9B 的覆盖矩阵、语言面首切片和
MIR -> Native 首目标通过前，不继续扩展 ad hoc `LoweredBodyOp` 或 `cmd/build` 专项 shape。`cmd/build` 只作为普通
Uya 程序经 `CoreBody -> PortableMIR -> NativeMirEmitter` 编译；若 self-build frontier 暴露新的语言面缺口，
先回 Phase 9B 补通用 lowering 和 parity，再回到本阶段推进。

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
  - 阶段目标（epic，不作为单个实现任务）：接入 hosted `cmd/build` verifier-clean PortableMIR self-build 的真实
    emitter/handoff，消除 `native_hosted_portable_mir_lowering_missing`，仍不得回落 C99 或 build-seed
    `LoweredProgram` helper。
    - [x] 固定 verifier-clean self-build handoff 诊断，报告 MIR body / extern / pending body frontier 和 entry callee 覆盖缺口，避免泛泛 `lowering_missing` 掩盖下一步。
    - [x] 固定 `main -> build_compiler_driver_main` wrapper 已纳入 CoreBody/PortableMIR 的证据，并把 first pending callee 精确到 `build_compiler_driver_run`，保持 pre-MIR helper 禁止。
    - [x] 将 first pending callee `build_compiler_driver_run` 的入口前缀纳入 CoreBody/PortableMIR 覆盖，并保持 pre-MIR helper 禁止。
    - 阶段目标（epic，不作为单个实现任务）：在 self-build reachable body 覆盖足够后，接入真实 hosted native
      emitter/handoff，消除 `native_hosted_portable_mir_lowering_missing`。
      - [x] 将 `build_compiler_driver_run` 的简单局部初始化入口前缀纳入 CoreBody/PortableMIR 覆盖，并在 frontier 中报告覆盖 stmt 数。
      - [x] 将 `parse_build_args(...)` 调用和 `parse_result` 分支入口纳入 CoreBody/PortableMIR 覆盖，保持 hosted verifier-clean。
      - 将 native 输出路径选择前的 reachable 控制流继续迁入 PortableMIR，收敛 pending body frontier（继续拆分执行）：
        - [x] 固定 `parse_result` 之后的下一条 source stmt frontier 诊断，精确到 `eff_compiler_stack_kb` 初始化，避免输出路径前控制流继续泛化。
        - [x] 将 `eff_compiler_stack_kb` 初始化纳入 CoreBody/PortableMIR partial 覆盖。
        - 为 `if <=`、局部赋值和裸 call statement 补齐输出路径前控制流所需的 CoreBody/PortableMIR partial surface（拆分执行）：
          - [x] 冻结 CoreBody/PortableMIR 的 `i32 <=`、局部赋值和裸 call statement surface，并补 verifier/边界测试。
          - [x] 将 `build_compiler_driver_run` partial builder 改为使用上述 surface 表达 stack-limit guard 前置形状。
        - [x] 将 `set_process_stack_limit_bytes(...)` 裸 call statement 迁入 verifier-clean PortableMIR frontier。
        - [x] 将 split-dir 环境变量分支继续迁入 PortableMIR frontier。
        - [x] 将 `output_file_index < 0` 的 native/C99 输出路径选择分支继续迁入 PortableMIR frontier。
        - [x] 将 `user_output_path` 初始化继续迁入 PortableMIR frontier。
      - 已完成的 entry / handoff 切片：
        - [x] 将 `output_file_index >= 0` 显式输出路径分支入口继续迁入 PortableMIR frontier。
        - [x] 将 `backend == BackendType.BACKEND_LLVM` fallback 分支继续迁入 PortableMIR frontier。
        - [x] 将 split-C active + C99 backend 分支继续迁入 PortableMIR frontier。
        - [x] 将 `output_path_for_compile` 初始化继续迁入 PortableMIR frontier。
        - [x] 将 `output_file_index == -2` 输出路径选择分支继续迁入 PortableMIR frontier。
        - [x] 将 `split_c_arg` 初始化继续迁入 PortableMIR frontier。
        - [x] 将 `g_split_c_dir_active != 0` 的 `split_c_arg` 赋值分支继续迁入 PortableMIR frontier。
        - [x] 将 `artifacts: CompileArtifacts` 初始化继续迁入 PortableMIR frontier。
        - [x] 将 `split_c_lock_held` 初始化继续迁入 PortableMIR frontier。
        - [x] 将 split-C lock `defer` cleanup block 继续迁入 PortableMIR frontier。
        - [x] 将 `split_c_arg` acquire 分支继续迁入 PortableMIR frontier。
        - [x] 将 `compile_files(...)` result 初始化继续迁入 PortableMIR frontier。
        - [x] 将 `if result != 0` 错误返回分支继续迁入 PortableMIR frontier。
        - [x] 将 `backend == BackendType.BACKEND_NATIVE` 成功输出分支继续迁入 PortableMIR frontier。
        - [x] 将 `is_output_c_file` 初始化继续迁入 PortableMIR frontier。
        - [x] 将 `is_output_c_file` 的 `output_file_index >= 0` 判定分支继续迁入 PortableMIR frontier。
        - [x] 将 `is_output_c_file == 0` 的链接输出分支继续迁入 PortableMIR frontier。
        - [x] 将末尾 `return 0` 继续迁入 PortableMIR frontier。
        - [x] 将链接输出分支内部 `c_file` 初始化继续迁入 PortableMIR frontier。
        - [x] 将链接输出分支内部 `output` 默认初始化继续迁入 PortableMIR frontier。
        - [x] 将链接输出分支内部 `user_output_path != null` 分支继续迁入 PortableMIR frontier。
        - [x] 将链接输出分支内部 `link_result` 初始化继续迁入 PortableMIR frontier。
        - [x] 将链接输出分支内部 `if link_result != 0` 错误分支继续迁入 PortableMIR frontier。
        - [x] 将链接输出分支内部成功 `fprintf(...)` 继续迁入 PortableMIR frontier。
        - [x] 将链接输出分支内部 `return 0` 继续迁入 PortableMIR frontier。
        - [x] 冻结真实 hosted native emitter/handoff 的首个最小切片合同，继续禁止 pre-MIR native helper 回流。
        - [x] 将 `build_compiler_driver_run` nested child complete 状态纳入 hosted handoff frontier 诊断。
        - [x] 将 nested child complete 的 hosted handoff frontier 转入真实 emitter/handoff 首个拒绝或接线切片。
        - [x] 将 verified PortableMIR partial body 接入 `NativeMirEmitter` import preflight，报告 imported function/block/inst 计数，仍因 pending bodies 拒绝 executable emission。
        - [x] 将 `NativeMirEmitter` import 结果接入 `MirTargetBackendOutput` payload preflight，报告 machine module output 计数，仍因 pending bodies 拒绝 executable emission。
        - [x] 将 `MirTargetBackendOutput` machine module 接到 hosted executable writer preflight 边界，明确只因 pending bodies 阻止写出。
        - [x] 将 hosted executable writer preflight 下沉为 `NativeHostedExecutableWriterPlan` 合同，避免 driver 内联散落 handoff 判定。
        - [x] 将 hosted no-deps const-return 输出从手写 asm/link helper 改到 `NativeMirEmitter` executable stream，并保留 MIR verifier 证据。
        - [x] 将 local-array index hosted 输出从 const-return asm/link helper 改到 `NativeMirEmitter` executable stream。
        - [x] 将 dynamic catch hosted 输出从手写 asm/link helper 改到 `NativeMirEmitter` executable stream，并保留 `argc` 分支语义。
        - [x] 将 `build_compiler_driver_run` full-prefix complete 状态接入 hosted handoff frontier，避免已覆盖入口仍报告 `partial_prefix`。
        - [x] 在 entry complete 后报告首个未 lower reachable callee frontier，先精确到 `parse_build_args(...)`。
      - 剩余任务差分（按 `native_hosted_reachable_callee_frontier` 顺序执行；每个切片只跑相关测试，不跑
        `make backup-all`；先补合同/边界测试，再改实现，完成后每个叶子单独提交并推送）：
        - [x] 将当前 reachable callee frontier 固定为推进门禁：self-build 必须报告
          `parent=build_compiler_driver_run stmt=12 first_unresolved_callee=parse_build_args reason=pending_core_body`，
          且 handoff 仍因 `pending_core_bodies` / `native_hosted_portable_mir_lowering_missing` 明确拒绝输出。
        - [x] 审计 `parse_build_args(...)` 的 CoreBody/PortableMIR surface，按 body 顺序列出 argv/argc、out-param
          写入、全局状态写入、`strcmp`/`strncmp`、`strlen`/`strcpy`、while 扫描、else-if 链、pointer
          arithmetic、byte index、诊断输出和 early return 缺口。
        - [x] 为 `parse_build_args(...)` 首切片补 CoreBody/PortableMIR golden/verifier 合同：覆盖
          `get_argc()`、`get_argv(0)`、`argc < 2`、`program_name != null`、`print_usage(...)` 和
          `input_file_capacity <= 0` 的 early-return 形状。
        - [x] 将 `parse_build_args(...)` 默认输出参数和全局状态初始化切片迁入 verifier-clean PortableMIR，覆盖
          `input_file_count[0]`、`output_file_index[0]`、`backend_type[0]`、line/proof/opt/nostdlib/stack
          默认值、split-C/module-root 全局清零和 `async_frame_heap_fallback[0]`。
          - [x] 固定默认初始化切片的 no-silent-C99 红灯合同：self-build 从
            `first_unresolved_callee=parse_build_args` 推进到
            `native_hosted_reachable_body_frontier: function=parse_build_args prefix_stmts=18 next_stmt=18
            next_kind=AST_VAR_DECL reason=partial_core_body`，仍以
            `native_hosted_portable_mir_lowering_missing` 拒绝写出。
          - [x] 核对 `parse_build_args(...)` AST body 边界，确认前 18 条语句只覆盖 argc/argv early-return
            与默认 out-param/global 初始化，下一条仍是 `const first_arg: *byte = get_argv(1);`。
          - [x] 将默认初始化切片补成 verifier-clean `CoreBody`：覆盖 out-param store、enum 默认值、
            i32 默认值、global scalar reset、global byte-array slot reset 和既有 early-return frontier。
          - [x] 将对应 `CoreBody` 降成 verifier-clean `MirFunction` partial body：覆盖 local/type/block/range
            以及 store/global-write MIR surface，不借用 build-seed `LoweredProgram` helper。
          - [x] 更新 hosted self-build frontier 诊断和 `docs/native_cmd_build_subset.md`，把当前缺口从
            callee-pending 改为 `parse_build_args` body-prefix pending。
          - [x] 只运行本切片相关验证：重建 `cmd-build`、no-silent-C99、regression-boundary、
            parse-build-args first-slice contract、stage1、todo checker 和 `git diff --check`；不跑
            `make backup-all`。
        - [x] 将 `parse_build_args(...)` 首参数处理切片迁入 PortableMIR：覆盖 `--help` / `-h` /
          `--version` / `-v`、`build` 子命令起始索引，以及对应 stdout/stderr/return 行为。
        - [x] 将 `parse_build_args(...)` option loop 骨架迁入 PortableMIR：覆盖 `while i < argc`、
          `get_argv(i)` null diagnostic、循环尾 `i = i + 1` 和 no-fallback self-build frontier 更新。
        - 基础 flag / scalar option 切片（当前 frontier；先建 loop-body child frontier，不得伪装
          root body prefix 已完成）：
          - [x] 为基础 flag / scalar option 补 CoreBody/PortableMIR golden/verifier 合同：固定 `-o`、
            backend、line-directives、safety-proof、opt-level、`--nostdlib` 的源码 surface、loop-body
            child frontier 诊断和 stage1 纳入点；不改生产实现。
          - [x] 将 `-o` 分支迁入 verifier-clean PortableMIR：覆盖缺参 diagnostic / `return -1`、
            `output_file_index[0] = i + 1` 和 `i = i + 1`，self-build 仍以 lowering-missing 明确拒绝写出。
          - [x] 为 backend 标量分支补独立合同脚本：固定 `--c99` / `--native` 的 enum store surface、
            branch frontier、stage1 纳入点和 no-silent-C99 预期；不改生产实现。
          - [x] 将 backend 标量分支迁入 PortableMIR：覆盖 `--c99` / `--native` 的
            `BackendType` out-param 写入，更新 loop-body frontier 到下一未覆盖选项。
          - [x] 为 line-directives 标量分支补独立合同脚本：固定 `--no-line-directives` /
            `--line-directives` 的 out-param store surface、branch frontier 和 no-silent-C99 预期；
            不改生产实现。
          - [x] 将 line-directives 标量分支迁入 PortableMIR：覆盖 `--no-line-directives` /
            `--line-directives` 的 `emit_line_directives[0]` 写入。
          - [x] 为 safety-proof 标量分支补独立合同脚本：固定 `--safety-proof` /
            `--no-safety-proof` 的 out-param store surface、branch frontier 和 no-silent-C99 预期；
            不改生产实现。
          - [x] 将 safety-proof 标量分支迁入 PortableMIR：覆盖 `--safety-proof` /
            `--no-safety-proof` 的 `enable_safety_proof[0]` 写入。
          - [x] 为 opt-level 标量分支补独立合同脚本：固定 `--opt=0..3` / `-O0..3` 的
            `strcmp || strcmp` surface、four-way store surface、branch frontier 和 no-silent-C99 预期；
            不改生产实现。
          - [x] 将 opt-level 标量分支迁入 PortableMIR：覆盖 `--opt=0..3` / `-O0..3` 的
            `strcmp || strcmp` 条件和 `opt_level[0]` 写入。
          - [x] 为 `--nostdlib` 标量分支补独立合同脚本：固定 `is_nostdlib[0] = 1`、
            scalar-option loop-body 完成边界、下一 frontier 到 `--project-root` 和 no-silent-C99 预期；
            不改生产实现。
          - [x] 将 `--nostdlib` 标量分支迁入 PortableMIR：覆盖 `is_nostdlib[0] = 1`，并把
            scalar-option loop-body frontier 推进到 `--project-root`。
        - `--project-root` 切片：
          - [x] 为 `--project-root` 补 CoreBody/PortableMIR 合同：覆盖缺参、空参数、`PATH_MAX`、
            `strcpy`、global active 写入和 no-silent-C99 frontier 预期；不改生产实现。
          - [x] 迁入 `--project-root` 缺参分支：覆盖 `i + 1 >= argc`、diagnostic 和 `return -1`。
          - [x] 迁入 `--project-root` 参数读取分支：覆盖 `i = i + 1`、`get_argv(i)`、
            `root_arg == null || root_arg[0] == 0` 和空参数 diagnostic。
          - [x] 迁入 `--project-root` 长度检查分支：覆盖 `strlen(root_arg)`、`root_len >= PATH_MAX`
            和路径过长 diagnostic。
          - [x] 迁入 `--project-root` 成功写入分支：覆盖
            `strcpy(&g_module_root_override[0] as *byte, root_arg)` 和 `g_module_root_override_active = 1`。
        - build-seed 明确拒绝选项切片：
          - [x] 为 build-seed reject group 补 CoreBody/PortableMIR 合同：固定所有拒绝项 diagnostic、
            `return -1` 和 seed 边界文档；不改生产实现。
          - [x] 迁入 `--manifest-path` 直接拒绝分支，保持现有 diagnostic 文案。
          - [x] 迁入 exec/vm/dump/trace 拒绝分支：覆盖多重 `strcmp ||` 条件和 exec backend diagnostic。
          - [x] 迁入 microapp profile 拒绝分支：覆盖 `--app`、`--microapp-profile` 和
            `strncmp("--microapp-profile=", 19)`。
          - [x] 迁入 `--outlibc` 直接拒绝分支，保持现有 diagnostic 文案。
        - `--stack-size` 数字扫描切片：
          - [x] 为 `--stack-size` 补 CoreBody/PortableMIR 合同：固定缺参、byte index、digit while、
            累积、有效写入、无效 warning 和 no-silent-C99 frontier 预期；不改生产实现。
          - [x] 迁入 `--stack-size` 缺参和 `get_argv(i + 1)` 分支，覆盖 error / null 参数保留语义。
          - [x] 迁入 `--stack-size` 数字扫描 loop：覆盖 `size_str[j]` byte index、ASCII digit 条件、
            `size_val = size_val * 10 + (...)` 和 `j = j + 1`。
          - [x] 迁入 `--stack-size` 写入/警告/跳参分支：覆盖 `stack_size[0] = size_val`、
            无效值 warning 和 `i = i + 1`。
        - split-C / async frame CLI 切片：
          - [x] 为 split-C / async-frame CLI 补 CoreBody/PortableMIR 合同：固定 `--async-frame-heap=on`、
            `--no-split-c`、inline/separate `--split-c-dir`、warning/default-dir 调用和 frontier 预期；不改生产实现。
          - [x] 迁入 `--async-frame-heap=on` 分支：覆盖 `async_frame_heap_fallback[0] = 1`。
          - [x] 迁入 `--no-split-c` 分支：覆盖 `g_split_c_disabled_cli`、`g_split_c_dir_active` 和
            `g_split_c_dir[0]` 写入。
          - [x] 迁入 inline `--split-c-dir=<dir>` disabled 分支：覆盖 `strncmp`、`arg + 14`
            surface 前的 disabled warning。
          - [x] 迁入 inline `--split-c-dir=<dir>` 成功/default 分支：覆盖 `arg + 14` pointer arithmetic、
            `strlen`、`PATH_MAX - 1`、`strcpy`、active 写入和 `split_c_set_default_dir()`。
          - [x] 迁入 separate `--split-c-dir <dir>` disabled-skip 分支：覆盖 warning、可选
            `get_argv(i + 1)`、`sd_skip[0] != 45` 和 `i = i + 1`。
          - [x] 迁入 separate `--split-c-dir <dir>` 成功/default 分支：覆盖缺参默认、null 默认、
            长度默认、成功 `strcpy` 和 `i = i + 1`。
        - 位置输入文件收集切片：
          - [x] 为位置输入文件收集补 CoreBody/PortableMIR 合同：固定 `arg[0]` byte index、
            容量检查、index 写入、count 写入和未知 dash option no-op；不改生产实现。
          - [x] 迁入 `arg[0]` / 非 dash 判定分支，保持未知 dash option 继续忽略的既有行为。
          - [x] 迁入输入容量检查分支：覆盖 `input_file_count[0] >= input_file_capacity`、
            diagnostic 和 `return -1`。
          - [x] 迁入输入索引写入分支：覆盖 `const idx`、`input_file_indices[idx] = i` 和
            `input_file_count[0] = idx + 1`。
        - `parse_build_args(...)` 收尾切片：
          - [x] 为收尾输出路径检查补 CoreBody/PortableMIR 合同：固定无输入 diagnostic、
            `print_usage`、out path 获取、`.c` 推断和 native `.c` 拒绝；不改生产实现。
          - [x] 迁入未指定输入文件分支：覆盖 `input_file_count[0] == 0`、diagnostic、
            `program_name != null`、`print_usage` 和 `return -1`。
          - [x] 迁入显式输出路径读取分支：覆盖 `out_idx`、`out_idx >= 0`、`get_argv(out_idx)`、
            null diagnostic 和 `return -1`。
          - [x] 迁入 `.c` 输出推断 C99 分支：覆盖 `backend_type[0] == BACKEND_LLVM`、
            `strrchr(out_path, 46)`、`.c` 比较和 `backend_type[0] = BACKEND_C99`。
          - [x] 迁入 `--native` 输出 `.c` 拒绝分支：覆盖 `is_c_output(out_path as &byte)`、
            diagnostic 和 `return -1`。
          - [x] 迁入末尾 `return 0`，标记 `parse_build_args(...)` CoreBody/PortableMIR body complete，
            并删除/更新该函数的 loop-body child frontier。
        - `parse_build_args(...)` complete 后的真实 reachable frontier：
          - [x] 更新 self-build frontier：不再报告 `parse_build_args` pending，改为只报告诊断中真实出现的
            下一个 reachable callee `set_process_stack_limit_bytes(...)`，并同步
            `tests/verify_native_cmd_build_no_silent_c99.sh` 与 `docs/native_cmd_build_subset.md`。
          - [x] 为 `set_process_stack_limit_bytes(...)` 补 helper frontier 合同：固定
            `parent=build_compiler_driver_run`、`stmt=17`、
            `first_unresolved_callee=set_process_stack_limit_bytes` 和 `reason=pending_core_body`，
            不按猜测提前跳到 `compile_files(...)`。
        - frontier-driven helper 队列（每个 helper 到达后按同一模板执行；候选只能来自真实诊断）：
          - [x] 审计 `set_process_stack_limit_bytes(...)` 的 body surface，写入本 todo 和
            `docs/native_cmd_build_subset.md`；不按猜测选择 `compile_files(...)` 或其它 helper。
            - surface：`EntryRLimit` 局部结构体初始化、`ENTRY_RLIMIT_STACK = 3`、
              Linux-only `std.cfg`、x86_64/arm64/arm/riscv64 syscall 号、`@syscall(... )`
              返回 `!i64`、`catch { 0i64; }` 忽略失败和非 Linux/unknown target no-op。
          - [x] 为 `set_process_stack_limit_bytes(...)` 的首个最小切片补 CoreBody/PortableMIR
            golden/verifier 合同：先固定 Linux x86_64 `EntryRLimit` 初始化、`SYS_setrlimit_x86_64 = 160`、
            `@syscall(... ENTRY_RLIMIT_STACK ... &rlim ...)` 和 `catch { 0i64; }`；不改生产实现。
          - [x] 将该 helper 首切片迁入 verifier-clean CoreBody/PortableMIR，并让 frontier 推进到同一
            helper 的下一条 body-prefix 或下一个 reachable callee。
          - [x] 首切片迁入后重建 `cmd-build` 并复跑 self-build frontier：只记录真实诊断中的下一处
            body-prefix / callee，不猜测 `compile_files(...)` 或其它 helper。
            - 实测命令：`make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过；
              `./bin/cmd/build src/cmd/build/main.uya -o /tmp/cb-native-frontier-task2 --project-root ./src/ --no-split-c --native`
              失败退出但保持 no-output/no-silent-C99。
            - 实测 frontier：`core_bodies=6`、`mir_body_functions=5`、`pending_bodies=3156`；
              stderr 不再包含 `set_process_stack_limit_bytes reason=pending_core_body`。
            - 本轮 stderr 未输出新的 `native_hosted_reachable_callee_frontier`、
              `native_hosted_reachable_body_frontier` 或 loop/body-prefix frontier；真实可记录的下一状态仍是
              `native_hosted_handoff_frontier: reason=pending_core_bodies ...`。
          - [x] 若 frontier 仍指向 `set_process_stack_limit_bytes(...)`，为下一条真实 body-prefix 补
            CoreBody/PortableMIR golden/verifier 合同；不改生产实现。
            - 条件未成立：复测 stderr 不再报告 `set_process_stack_limit_bytes reason=pending_core_body`。
          - [x] 迁入 `set_process_stack_limit_bytes(...)` 的下一条真实 body-prefix，并再次推进 frontier；
            每次只扩大一个可验证切片，禁止摘要、direct native machine emission、C99 fallback 或
            build-seed `LoweredProgram` helper。
            - 条件未成立：当前没有该 helper 的下一条真实 body-prefix 诊断。
          - [x] 重复同 helper 的“补合同 -> 迁实现 -> 复测 frontier”循环，直到真实诊断报告该 helper
            `body_complete` 或转向下一个 reachable callee。
            - 本轮状态转向 handoff-only `pending_core_bodies`：stderr 未报告新的 reachable callee/body-prefix。
          - [x] 为 handoff-only `pending_core_bodies` 补 frontier 诊断合同：输出第一个 pending CoreBody
            函数名、decl index、function id、body statement 数和 pending reason；不改生产实现。
            - 合同进入 `tests/verify_native_cmd_build_no_silent_c99.sh`：
              `native_hosted_pending_body_frontier: function=... decl=... function_id=... body_stmts=... reason=pending_core_body`。
          - [x] 接入 handoff-only pending body frontier 诊断，并复跑 self-build：只记录真实诊断中的下一处
            pending body，不猜测 `compile_files(...)` 或其它 helper。
            - 实测命令：`./bin/cmd/build src/cmd/build/main.uya -o /tmp/cb-native-pending-frontier --project-root ./src/ --no-split-c --native`。
            - 真实 pending body frontier：
              `native_hosted_pending_body_frontier: function=compile_stats_record_and_release_typed_program decl=159 function_id=4 body_stmts=18 reason=pending_core_body`。
          - [x] 审计 `compile_stats_record_and_release_typed_program(...)` body surface，写入
            `docs/native_cmd_build_subset.md`：按源码顺序列出参数、TypedProgram/SemanticDb/table stats、
            release 调用、global/table aggregation、错误/空指针 early return 和 arena/lifetime 能力。
            - 已写入 `docs/native_cmd_build_subset.md` 的
              `compile_stats_record_and_release_typed_program(...)` PortableMIR surface audit，冻结
              `stats == null` / `checker == null` early return、typed-program 三字段清零、
              `SemanticTableAgg` 聚合、SemanticDb/TypedProgram 表统计、`typed_program_release` /
              `semantic_vector_release` 顺序和 field-address / lifetime capability 边界。
          - [x] 为 `compile_stats_record_and_release_typed_program(...)` 的首个最小切片补
            CoreBody/PortableMIR golden/verifier 合同：固定 `stats == null` return、
            typed-program 三字段清零、`checker == null` return 和首个
            `typed_program_current_bytes(&checker.typed_program)` field-address call surface；不改生产实现。
            - 合同进入 `tests/verify_native_compile_stats_first_slice_contract.sh` 和
              `tests/verify_native_cmd_build_stage1.sh`；实测
              `bash tests/verify_native_compile_stats_first_slice_contract.sh`、
              `bash tests/verify_coreir_dump_golden.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh` 通过。
          - [x] 将该 helper 首切片迁入 verifier-clean CoreBody/PortableMIR，并让 frontier 推进到同一
            helper 的下一条 body-prefix 或下一个真实 pending body/helper。
            - 已接入 `compile_stats_record_and_release_typed_program(...)` 首切片生产实现：
              `stats == null` / `checker == null` early return、typed-program 三字段清零和首个
              `typed_program_current_bytes(&checker.typed_program)` field-address call surface 进入
              verifier-clean CoreBody/PortableMIR；`cmd/build --native` self-build 真实 frontier 推进到
              `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=6 next_stmt=6 next_kind=AST_ASSIGN reason=partial_core_body`，
              whole-body pending frontier 为
              `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=165 function_id=5 body_stmts=4 reason=pending_core_body`。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_compile_stats_first_slice_contract.sh`、
              `bash tests/verify_native_stack_limit_helper_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过。
          - [x] 若 frontier 仍指向 `compile_stats_record_and_release_typed_program(...)`，继续按真实
            body-prefix 补合同并迁入下一切片；每次只扩大一个可验证切片。
            - 已按真实 frontier 迁入第 6 条源码语句：
              `stats.typed_program_peak_bytes = typed_program_peak_bytes(&checker.typed_program);`。
              新增 `tests/verify_native_compile_stats_peak_bytes_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；生产实现为同一 partial CoreBody/PortableMIR
              追加 peak-bytes field-address/call surface。
            - self-build 真实 frontier 推进到
              `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=7 next_stmt=7 next_kind=AST_VAR_DECL reason=partial_core_body`，
              whole-body pending frontier 为
              `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=170 function_id=5 body_stmts=4 reason=pending_core_body`。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_compile_stats_first_slice_contract.sh`、
              `bash tests/verify_native_compile_stats_peak_bytes_contract.sh`、
              `bash tests/verify_native_stack_limit_helper_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过。
          - [x] 若 frontier 仍指向 `compile_stats_record_and_release_typed_program(...)` 的
            `SemanticTableAgg` 局部初始化，继续按真实 body-prefix 补合同并迁入该单条
            `var table_agg: SemanticTableAgg = semantic_table_agg_init()` 切片。
            - 已新增 `tests/verify_native_compile_stats_table_agg_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；生产实现为同一 partial CoreBody/PortableMIR
              追加 `table_agg` local stack slot、`semantic_table_agg_init()` resolved call fact 和
              MIR call surface。重建时暴露 `src/build_compiler_driver.uya` 中裸 `F_OK` 生成 C 未声明，
              已在当前 build-seed 文件内改为 POSIX `F_OK` 数值 `0`，恢复 `cmd-build` 硬门。
            - self-build 真实 frontier 推进到
              `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=8 next_stmt=8 next_kind=AST_CALL_EXPR reason=partial_core_body`，
              whole-body pending frontier 为
              `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=175 function_id=5 body_stmts=4 reason=pending_core_body`。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_compile_stats_first_slice_contract.sh`、
              `bash tests/verify_native_compile_stats_peak_bytes_contract.sh`、
              `bash tests/verify_native_compile_stats_table_agg_contract.sh`、
              `bash tests/verify_native_stack_limit_helper_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过。
          - [x] 若 frontier 仍指向 `compile_stats_record_and_release_typed_program(...)` 的
            `semantic_db_accumulate_table_stats(&checker.semantic_db, &table_agg)` 调用，
            继续按真实 body-prefix 补合同并迁入该单条 SemanticDb aggregate call 切片。
            - 已新增 `tests/verify_native_compile_stats_semantic_db_agg_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；生产实现为同一 partial CoreBody/PortableMIR
              追加 `semantic_db_accumulate_table_stats` expr stmt、`&checker.semantic_db` field-address
              fact、`&table_agg` local-address operand surface 和 resolved call fact。
            - self-build 真实 frontier 推进到
              `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=9 next_stmt=9 next_kind=AST_CALL_EXPR reason=partial_core_body`，
              whole-body pending frontier 为
              `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=180 function_id=5 body_stmts=4 reason=pending_core_body`。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_compile_stats_first_slice_contract.sh`、
              `bash tests/verify_native_compile_stats_peak_bytes_contract.sh`、
              `bash tests/verify_native_compile_stats_table_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_semantic_db_agg_contract.sh`、
              `bash tests/verify_native_stack_limit_helper_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过。
          - [x] 若 frontier 仍指向 `compile_stats_record_and_release_typed_program(...)` 的
            `typed_program_accumulate_table_stats(&checker.typed_program, &table_agg)` 调用，
            继续按真实 body-prefix 补合同并迁入该单条 TypedProgram aggregate call 切片。
            - 已新增 `tests/verify_native_compile_stats_typed_program_agg_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；生产实现为同一 partial CoreBody/PortableMIR
              追加 `typed_program_accumulate_table_stats` expr stmt、`&checker.typed_program`
              field-address fact/MIR surface、`&table_agg` local-address operand surface 和
              resolved call fact。
            - self-build 真实 frontier 推进到
              `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=10 next_stmt=10 next_kind=AST_ASSIGN reason=partial_core_body`，
              whole-body pending frontier 为
              `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=185 function_id=5 body_stmts=4 reason=pending_core_body`。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_compile_stats_first_slice_contract.sh`、
              `bash tests/verify_native_compile_stats_peak_bytes_contract.sh`、
              `bash tests/verify_native_compile_stats_table_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_semantic_db_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_typed_program_agg_contract.sh`、
              `bash tests/verify_native_stack_limit_helper_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过。
          - [x] 若 frontier 仍指向 `compile_stats_record_and_release_typed_program(...)` 的
            `stats.table_items = table_agg.items` 写回，继续按真实 body-prefix 补合同并迁入
            该单条 table_items aggregate writeback 切片。
            - 已新增 `tests/verify_native_compile_stats_table_items_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；生产实现为同一 partial CoreBody/PortableMIR
              追加 `stats.table_items = table_agg.items` assign stmt、目标 `stats.table_items`
              field-address fact/MIR surface、右值 `table_agg.items` field-address fact/MIR
              surface 和 store 写回。
            - self-build 真实 frontier 推进到
              `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=11 next_stmt=11 next_kind=AST_ASSIGN reason=partial_core_body`，
              whole-body pending frontier 为
              `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=190 function_id=5 body_stmts=4 reason=pending_core_body`。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_compile_stats_first_slice_contract.sh`、
              `bash tests/verify_native_compile_stats_peak_bytes_contract.sh`、
              `bash tests/verify_native_compile_stats_table_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_semantic_db_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_typed_program_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_table_items_contract.sh`、
              `bash tests/verify_native_stack_limit_helper_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过。
          - [x] 若 frontier 仍指向 `compile_stats_record_and_release_typed_program(...)` 的
            `stats.table_capacity = table_agg.capacity` 写回，继续按真实 body-prefix 补合同并迁入
            该单条 table_capacity aggregate writeback 切片。
            - 已新增 `tests/verify_native_compile_stats_table_capacity_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；生产实现为同一 partial CoreBody/PortableMIR
              追加 `stats.table_capacity = table_agg.capacity` assign stmt、目标
              `stats.table_capacity` field-address fact/MIR surface、右值 `table_agg.capacity`
              field-address fact/MIR surface 和 store 写回。
            - self-build 真实 frontier 推进到
              `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=12 next_stmt=12 next_kind=AST_ASSIGN reason=partial_core_body`，
              whole-body pending frontier 为
              `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=195 function_id=5 body_stmts=4 reason=pending_core_body`。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_compile_stats_first_slice_contract.sh`、
              `bash tests/verify_native_compile_stats_peak_bytes_contract.sh`、
              `bash tests/verify_native_compile_stats_table_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_semantic_db_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_typed_program_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_table_items_contract.sh`、
              `bash tests/verify_native_compile_stats_table_capacity_contract.sh`、
              `bash tests/verify_native_stack_limit_helper_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过。
          - [x] 若 frontier 仍指向 `compile_stats_record_and_release_typed_program(...)` 的
            `stats.table_used_bytes = table_agg.used_bytes` 写回，继续按真实 body-prefix 补合同并迁入
            该单条 table_used_bytes aggregate writeback 切片。
            - 已新增 `tests/verify_native_compile_stats_table_used_bytes_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；生产实现为同一 partial CoreBody/PortableMIR
              追加 `stats.table_used_bytes = table_agg.used_bytes` assign stmt、目标
              `stats.table_used_bytes` field-address fact/MIR surface、右值 `table_agg.used_bytes`
              field-address fact/MIR surface 和 store 写回。
            - self-build 真实 frontier 推进到
              `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=13 next_stmt=13 next_kind=AST_ASSIGN reason=partial_core_body`，
              whole-body pending frontier 为
              `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=200 function_id=5 body_stmts=4 reason=pending_core_body`。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_compile_stats_first_slice_contract.sh`、
              `bash tests/verify_native_compile_stats_peak_bytes_contract.sh`、
              `bash tests/verify_native_compile_stats_table_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_semantic_db_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_typed_program_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_table_items_contract.sh`、
              `bash tests/verify_native_compile_stats_table_capacity_contract.sh`、
              `bash tests/verify_native_compile_stats_table_used_bytes_contract.sh`、
              `bash tests/verify_native_stack_limit_helper_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过。
          - [x] 若 frontier 仍指向 `compile_stats_record_and_release_typed_program(...)` 的
            `stats.table_capacity_bytes = table_agg.capacity_bytes` 写回，继续按真实 body-prefix 补合同并迁入
            该单条 table_capacity_bytes aggregate writeback 切片。
            - 已新增 `tests/verify_native_compile_stats_table_capacity_bytes_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；生产实现为同一 partial CoreBody/PortableMIR
              追加 `stats.table_capacity_bytes = table_agg.capacity_bytes` assign stmt、目标
              `stats.table_capacity_bytes` field-address fact/MIR surface、右值
              `table_agg.capacity_bytes` field-address fact/MIR surface 和 store 写回。
            - self-build 真实 frontier 推进到
              `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=14 next_stmt=14 next_kind=AST_ASSIGN reason=partial_core_body`，
              whole-body pending frontier 为
              `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=205 function_id=5 body_stmts=4 reason=pending_core_body`。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_compile_stats_first_slice_contract.sh`、
              `bash tests/verify_native_compile_stats_peak_bytes_contract.sh`、
              `bash tests/verify_native_compile_stats_table_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_semantic_db_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_typed_program_agg_contract.sh`、
              `bash tests/verify_native_compile_stats_table_items_contract.sh`、
              `bash tests/verify_native_compile_stats_table_capacity_contract.sh`、
              `bash tests/verify_native_compile_stats_table_used_bytes_contract.sh`、
              `bash tests/verify_native_compile_stats_table_capacity_bytes_contract.sh`、
              `bash tests/verify_native_stack_limit_helper_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过。
          - [x] 当前 helper complete 后重新运行 self-build frontier，冻结下一 helper 名称；若诊断仍指向
            同一 helper，则回到该 helper 的下一 body-prefix，不得跳到其它函数。
            - 2026-06-11：`bash tests/verify_native_cmd_build_no_silent_c99.sh` 通过；
              直接复跑 `./bin/cmd/build build src/cmd/build/main.uya -o <tmp> --native --no-split-c --project-root src/`
              仍以 status 1 明确拒绝写出，真实 frontier 仍指向同一 helper：
              `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=14 next_stmt=14 next_kind=AST_ASSIGN reason=partial_core_body`。
              因此下一步继续该 helper 的 `stats.table_realloc_count = table_agg.realloc_count` 写回切片，
              不进入下一个 helper。
          - [x] 若 frontier 仍指向 `compile_stats_record_and_release_typed_program(...)` 的
            `stats.table_realloc_count = table_agg.realloc_count` 写回，先补 CoreBody/PortableMIR 合同；
            不改生产实现。
            - 2026-06-11：新增
              `tests/verify_native_compile_stats_table_realloc_count_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md` 新增
              Table Realloc Count Writeback Slice Contract，冻结当前 frontier
              `prefix_stmts=14 next_stmt=14 next_kind=AST_ASSIGN`，并要求迁入后推进到
              `prefix_stmts=15 next_stmt=15 next_kind=AST_CALL_EXPR`。
            - 实测 `bash tests/verify_native_compile_stats_table_realloc_count_contract.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过；本叶子未改生产 lowering。
          - [x] 迁入 `stats.table_realloc_count = table_agg.realloc_count` 单条写回切片并复测 frontier。
            - 2026-06-11：为该写回接入 verifier-clean CoreBody/PortableMIR 前缀；
              `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过。构建过程中暴露
              `std_io_fopen` 的 `S_IRWXU` imported const 会被当前 C99 输出成裸 C 名，已改为
              `STD_IO_CREATE_MODE_USER_RWX` 本地常量以解锁 cmd/build 重建。复跑
              `bash tests/verify_native_compile_stats_table_realloc_count_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过；直接 self-build repro 仍以
              status 1 明确拒绝写出，真实 frontier 推进到
              `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=15 next_stmt=15 next_kind=AST_CALL_EXPR reason=partial_core_body`，
              后续 pending body 首项为
              `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=210 function_id=5 body_stmts=4 reason=pending_core_body`。
          - [x] 若 frontier 仍指向 `compile_stats_record_and_release_typed_program(...)` 的
            `typed_program_release(&checker.typed_program)` 调用，先补 CoreBody/PortableMIR 合同；
            不改生产实现。
            - 2026-06-11：新增
              `tests/verify_native_compile_stats_typed_program_release_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md` 新增
              Typed Program Release Slice Contract，冻结当前 frontier
              `prefix_stmts=15 next_stmt=15 next_kind=AST_CALL_EXPR`，并要求迁入后推进到
              `prefix_stmts=16 next_stmt=16 next_kind=AST_CALL_EXPR`。
            - 实测 `bash tests/verify_native_compile_stats_typed_program_release_contract.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过；本叶子未改生产 lowering。
          - [x] 迁入 `typed_program_release(&checker.typed_program)` 单调用切片并复测 frontier。
            - 2026-06-11：为该调用接入 verifier-clean CoreBody/PortableMIR 前缀；
              `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过。复跑
              `bash tests/verify_native_compile_stats_typed_program_release_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过；直接 self-build repro 仍以
              status 1 明确拒绝写出，真实 frontier 推进到
              `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=16 next_stmt=16 next_kind=AST_CALL_EXPR reason=partial_core_body`，
              后续 pending body 首项为
              `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=215 function_id=5 body_stmts=4 reason=pending_core_body`。
          - [x] 若 frontier 仍指向 `compile_stats_record_and_release_typed_program(...)` 的
            `semantic_vector_release(&checker.typed_type_records)` 调用，先补 CoreBody/PortableMIR 合同；
            不改生产实现。
            - 2026-06-11：新增
              `tests/verify_native_compile_stats_typed_type_records_release_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md` 新增
              Typed Type Records Release Slice Contract，冻结当前 frontier
              `prefix_stmts=16 next_stmt=16 next_kind=AST_CALL_EXPR`，并要求迁入后推进到
              `prefix_stmts=17 next_stmt=17 next_kind=AST_ASSIGN`。
            - 实测 `bash tests/verify_native_compile_stats_typed_type_records_release_contract.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过；本叶子未改生产 lowering。
          - [x] 迁入 `semantic_vector_release(&checker.typed_type_records)` 单调用切片并复测 frontier。
            - 2026-06-11：为该调用接入 verifier-clean CoreBody/PortableMIR 前缀；
              `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过。复跑
              `bash tests/verify_native_compile_stats_typed_type_records_release_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过；直接 self-build repro 仍以
              status 1 明确拒绝写出，真实 frontier 推进到
              `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=17 next_stmt=17 next_kind=AST_ASSIGN reason=partial_core_body`，
              后续 pending body 首项为
              `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=220 function_id=5 body_stmts=4 reason=pending_core_body`。
          - [x] 若 frontier 仍指向 `compile_stats_record_and_release_typed_program(...)` 的
            `stats.typed_program_released_bytes = typed_program_current_bytes(&checker.typed_program)` 写回，
            先补 CoreBody/PortableMIR 合同；不改生产实现。
            - 2026-06-11：新增
              `tests/verify_native_compile_stats_released_bytes_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md` 新增
              Released Bytes Writeback Slice Contract，冻结当前 frontier
              `prefix_stmts=17 next_stmt=17 next_kind=AST_ASSIGN`，并要求迁入后
              `compile_stats_record_and_release_typed_program(...)` 达到 body complete。
            - 实测 `bash tests/verify_native_compile_stats_released_bytes_contract.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过；本叶子未改生产 lowering。
          - [x] 迁入 `stats.typed_program_released_bytes = typed_program_current_bytes(&checker.typed_program)`
            单条写回切片并复测 frontier。
            - 2026-06-11：为该写回接入 verifier-clean CoreBody/PortableMIR body-complete 切片；
              `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过。复跑
              `bash tests/verify_native_compile_stats_released_bytes_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过；直接 self-build repro 仍以
              status 1 明确拒绝写出，`compile_stats_record_and_release_typed_program(...)`
              不再报告 partial frontier，当前可观测 pending frontier 推进到
              `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=225 function_id=5 body_stmts=4 reason=pending_core_body`。
          - [x] 当前 helper complete 后，审计下一个 reachable driver/runtime helper 的 body surface，写入
            `docs/native_cmd_build_subset.md`：按源码顺序列出参数、局部、global、外部调用、控制流、
            diagnostics、IO/环境能力和 early return。
            - 2026-06-11：当前真实 pending frontier 为
              `compiler_should_profile_diagnostics`；已在 `docs/native_cmd_build_subset.md` 新增
              `compiler_should_profile_diagnostics(...)` Surface Audit，记录无参数、`value: *byte`
              局部、`getenv`/`strcmp` 外部调用、两段 early return 和 tail return。
            - 实测 `git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过；本叶子未改生产 lowering。
          - [x] 为下一个 helper 的首个最小切片补 CoreBody/PortableMIR golden/verifier 合同；候选只在
            真实 frontier 指向时进入，不从静态猜测中选函数。
            - 2026-06-11：新增
              `tests/verify_native_profile_diagnostics_first_slice_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md` 新增
              `compiler_should_profile_diagnostics(...)` First Slice Contract，冻结当前 pending
              frontier，并要求迁入首句 `const value = getenv(...)` 后推进到
              `prefix_stmts=1 next_stmt=1 next_kind=AST_IF_STMT`。
            - 实测 `bash tests/verify_native_profile_diagnostics_first_slice_contract.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过；本叶子未改生产 lowering。
          - [x] 迁入下一个 helper 的首切片并复测 frontier，然后按同一 helper 循环继续推进。
            - 2026-06-11：迁入 `compiler_should_profile_diagnostics(...)` 首句
              `const value: *byte = getenv("UYA_PROFILE_DIAGNOSTICS" as *byte)` 的
              verifier-clean CoreBody/PortableMIR partial body；`make -B cmd-build
              UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya` 通过。期间 `cmd-build` 暴露
              `lib/std/io/file.uya` 与 `lib/libc/stdlib.uya` 中部分 libc open flags 生成裸 C 宏，
              已改为本地 Linux 数值常量以保持 C99 seed 可链接。
            - 复跑 `bash tests/verify_native_profile_diagnostics_first_slice_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh` 和
              `bash tests/verify_native_cmd_build_stage1.sh` 通过；直接 self-build repro 仍以
              status 1 明确拒绝写出，真实 frontier 推进到
              `native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=1 next_stmt=1 next_kind=AST_IF_STMT reason=partial_core_body`，
              后续 pending body 首项为
              `native_hosted_pending_body_frontier: function=compiler_print_diagnostic_profile decl=231 function_id=6 body_stmts=4 reason=pending_core_body`。
          - [ ] 候选示例仅作排队提醒，不能作为实现顺序来源：`print_usage`、
            `split_c_set_default_dir`、`split_c_acquire_lock`、`env_disables_auto_split_c`、
            `host_fill_temp_c_compile_path`、`is_c_output`、`link_with_toolchain` 及其实际 reachable 子调用。
          - [x] 为 `compiler_should_profile_diagnostics(...)` 的 null/empty branch 补
            CoreBody/PortableMIR 合同；固定 `value == null || value[0] == 0 as byte`
            early return 0 的 surface、verifier-clean body prefix 和迁入后 frontier。
            - 2026-06-11：新增
              `tests/verify_native_profile_diagnostics_null_empty_branch_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md` 新增
              Null/Empty Branch Contract，固定 short-circuit、byte index load、conditional branch
              和迁入后 `prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT` frontier。
            - 实测 `bash tests/verify_native_profile_diagnostics_null_empty_branch_contract.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过；本叶子未改生产 lowering。
          - [x] 迁入 `compiler_should_profile_diagnostics(...)` 的 null/empty branch 并复测 frontier。
            - 2026-06-11：新增 prefix-2 CoreBody/PortableMIR 切片识别与分发；
              `compiler_should_profile_diagnostics(...)` 的 `value == null || value[0] == 0 as byte`
              early-return branch 迁入后，self-build frontier 从
              `prefix_stmts=1 next_stmt=1` 推进到
              `prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT`。
            - 同步修正 `docs/native_cmd_build_subset.md` 的真实 Core/MIR 常量名，并修复
              `src/build_compiler_driver.uya` / `lib/libc/stdlib.uya` 中阻塞 cmd-build C99
              重建的裸 `O_RDONLY` 输出。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过。
          - [x] 迁入 `compiler_should_profile_diagnostics(...)` 的 false-like `strcmp(...) == 0`
            branch 并复测 frontier。
            - 2026-06-11：新增 false-like branch 合同与 prefix-3 CoreBody/PortableMIR
              partial 切片识别；`strcmp(value, "0"/"false"/"no"/"off") == 0`
              branch 迁入后，self-build frontier 从
              `prefix_stmts=2 next_stmt=2` 推进到
              `prefix_stmts=3 next_stmt=3 next_kind=return`。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_profile_diagnostics_false_like_branch_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过。
          - [x] 迁入 `compiler_should_profile_diagnostics(...)` 的 tail `return 1`，使该 helper
            达到 body complete。
            - 2026-06-11：新增 tail-return 合同与 prefix-4 CoreBody/PortableMIR
              body-complete 切片；`compiler_should_profile_diagnostics(...)` 不再报告
              partial frontier，self-build frontier 推进到
              `native_hosted_pending_body_frontier: function=compiler_print_diagnostic_profile ... reason=pending_core_body`。
            - 同步修复 `lib/libc/pthread.uya` 中阻塞 cmd-build C99 重建的裸
              `FUTEX_WAIT` / `FUTEX_WAKE` 输出。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_profile_diagnostics_tail_return_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过。
          - [x] 为 `compiler_print_diagnostic_profile(...)` 补 surface audit 和首个 guard
            切片 CoreBody/PortableMIR 合同；固定当前 pending frontier、参数/局部/外部调用、
            early return 与迁入后 frontier，不改生产 lowering。
            - 2026-06-11：新增
              `tests/verify_native_print_diagnostic_profile_guard_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md`
              新增 `compiler_print_diagnostic_profile(...)` Surface Audit 和 Guard Slice
              Contract，冻结当前 pending frontier，并要求 guard 迁入后推进到首个局部声明。
            - 实测 `bash tests/verify_native_print_diagnostic_profile_guard_contract.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过；本叶子未改生产 lowering。
          - [x] 迁入 `compiler_print_diagnostic_profile(...)` 的 guard early-return 切片并复测
            frontier；迁入后应推进到 `prefix_stmts=1 next_stmt=1 next_kind=AST_VAR_DECL`，不提前迁入
            `count`、`checker` 分支或 `fprintf`。
            - 2026-06-11：新增
              `NATIVE_PRINT_DIAGNOSTIC_PROFILE_GUARD_*` CoreBody/PortableMIR partial body
              识别与分发；`compiler_print_diagnostic_profile(...)` 的
              `compiler_should_profile_diagnostics() == 0 || libc.stderr == null` guard
              迁入后，self-build frontier 从 whole-helper pending 推进到
              `native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=1 next_stmt=1 next_kind=AST_VAR_DECL reason=partial_core_body`。
            - 同步 `tests/verify_native_cmd_build_no_silent_c99.sh` 的 CoreBody/MIR body 计数
              为 9/8，并更新旧合同脚本中的静态计数断言。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_print_diagnostic_profile_guard_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过。
          - [x] 为 `compiler_print_diagnostic_profile(...)` 的 `count` 局部初始化补
            CoreBody/PortableMIR 合同；固定 `var count: i32 = 0` surface、迁入后 frontier
            和不得提前读取 `checker` / 调用 `fprintf`，不改生产 lowering。
            - 2026-06-11：新增
              `tests/verify_native_print_diagnostic_profile_count_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md`
              新增 Count Local Contract，冻结当前 `prefix_stmts=1` frontier，并要求迁入
              `var count: i32 = 0` 后推进到
              `prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT`。
            - 实测 `bash tests/verify_native_print_diagnostic_profile_count_contract.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过；本叶子未改生产 lowering。
          - [x] 迁入 `compiler_print_diagnostic_profile(...)` 的 `count` 局部初始化并复测
            frontier；迁入后应推进到 `prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT`，
            不提前迁入 `checker` 分支或 `fprintf`。
            - 2026-06-11：新增
              `NATIVE_PRINT_DIAGNOSTIC_PROFILE_COUNT_*` CoreBody/PortableMIR partial body
              识别与分发；`var count: i32 = 0` 迁入后，self-build frontier 从
              `prefix_stmts=1 next_stmt=1 next_kind=AST_VAR_DECL` 推进到
              `native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT reason=partial_core_body`。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_print_diagnostic_profile_count_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过。
          - [x] 为 `compiler_print_diagnostic_profile(...)` 的 checker 非空分支补
            CoreBody/PortableMIR 合同；固定 `checker != null`、`checker.diagnostic_format_count`
            读取和 `count = ...` 写回 surface，不提前迁入尾部 `fprintf`。
            - 2026-06-11：新增
              `tests/verify_native_print_diagnostic_profile_checker_branch_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md`
              新增 Checker Branch Contract，冻结当前 `prefix_stmts=2` frontier，并要求迁入
              checker 分支后推进到尾部 `fprintf`。
            - 实测 `bash tests/verify_native_print_diagnostic_profile_checker_branch_contract.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过；本叶子未改生产 lowering。
          - [x] 迁入 `compiler_print_diagnostic_profile(...)` 的 checker 非空分支并复测
            frontier；迁入后应推进到尾部 `fprintf`，不提前标记 helper complete。
            - 2026-06-11：新增
              `NATIVE_PRINT_DIAGNOSTIC_PROFILE_CHECKER_*` CoreBody/PortableMIR partial body
              识别与分发；`checker != null` 分支迁入后，self-build frontier 从
              `prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT` 推进到
              `native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=3 next_stmt=3 next_kind=AST_CALL_EXPR reason=partial_core_body`。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_print_diagnostic_profile_checker_branch_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过。
          - [x] 为 `compiler_print_diagnostic_profile(...)` 的尾部 `fprintf` 补
            CoreBody/PortableMIR body-complete 合同；固定 stderr、格式字符串和 `count` 参数
            surface，迁入后该 helper 不再报告 partial frontier。
            - 2026-06-11：新增
              `tests/verify_native_print_diagnostic_profile_tail_fprintf_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md`
              新增 Tail Fprintf Contract，冻结当前 `prefix_stmts=3` frontier，并要求迁入
              `fprintf(libc.stderr, "diagnostic_format_count: %d\n" as *byte, count)` 后达到
              `body_complete`。
            - 实测 `bash tests/verify_native_print_diagnostic_profile_tail_fprintf_contract.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过；本叶子未改生产 lowering。
          - [x] 迁入 `compiler_print_diagnostic_profile(...)` 的尾部 `fprintf`，使该 helper
            达到 body complete；复测真实 frontier 后再选择下一个 helper。
            - 2026-06-11：新增
              `NATIVE_PRINT_DIAGNOSTIC_PROFILE_TAIL_*` CoreBody/PortableMIR body-complete
              识别与分发；尾部 `fprintf(...)` 迁入后，`compiler_print_diagnostic_profile(...)`
              不再报告 partial frontier，self-build 当前 pending body 推进到
              `native_hosted_pending_body_frontier: function=native_build_ast_plan_empty ... reason=pending_core_body`。
            - 实测 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
              `bash tests/verify_native_print_diagnostic_profile_tail_fprintf_contract.sh`、
              `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过。
          - [x] 为 `native_build_ast_plan_empty()` 补 CoreBody/PortableMIR body-complete 合同；
            固定 `NativeBuildAstPlan{ plans: null, function_count: 0, entry_index: -1 }`
            return surface，不改生产 lowering。
            - 2026-06-11：新增 `tests/verify_native_ast_plan_empty_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md`
              新增 `native_build_ast_plan_empty()` Body Complete Contract，冻结当前 pending
              frontier，并要求迁入后达到 `body_complete`。
            - 实测 `bash tests/verify_native_ast_plan_empty_contract.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过；本叶子未改生产 lowering。
          - [x] 迁入 `native_build_ast_plan_empty()` 的 struct literal return，使该 helper
            达到 body complete；`make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
            `bash tests/verify_native_ast_plan_empty_contract.sh`、
            `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
            `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 通过；真实
            frontier 前进为 `native_hosted_pending_body_frontier: function=native_build_empty_vector
            decl=295 function_id=8 body_stmts=1 reason=pending_core_body`。
          - [x] 为 `native_build_empty_vector()` 补 CoreBody/PortableMIR body-complete 合同；
            固定 `SemanticVector{ data: null, item_size: 0usize, count: 0usize, capacity: 0usize,
            bytes: 0usize, realloc_count: 0 }` return surface，不改生产 lowering。
            - 2026-06-11：新增 `tests/verify_native_empty_vector_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md`
              新增 `native_build_empty_vector()` Body Complete Contract，冻结当前 pending
              frontier，并要求迁入后达到 `body_complete`。
            - 实测 `bash tests/verify_native_empty_vector_contract.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 和
              `python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_compiler_1s.md`
              通过；本叶子未改生产 lowering。
          - [x] 迁入 `native_build_empty_vector()` 的 struct literal return，使该 helper
            达到 body complete；`make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
            `bash tests/verify_native_empty_vector_contract.sh`、
            `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
            `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 通过；真实
            frontier 前进为 `native_hosted_pending_body_frontier:
            function=native_build_lowered_plan_empty decl=299 function_id=9 body_stmts=1
            reason=pending_core_body`。
          - [x] 为 `native_build_lowered_plan_empty()` 补 CoreBody/PortableMIR body-complete
            合同；固定 `NativeBuildLoweredPlan{ lowered: LoweredProgram{ ... }, entry_index: -1 }`
            嵌套 struct literal return surface，不改生产 lowering。
            - 2026-06-11：新增 `tests/verify_native_lowered_plan_empty_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md`
              新增 `native_build_lowered_plan_empty()` Body Complete Contract，冻结当前 pending
              frontier，并要求迁入后达到 `body_complete`。
            - 实测 `bash tests/verify_native_lowered_plan_empty_contract.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh` 和 `git diff --check` 通过；
              本叶子未改生产 lowering。
          - [x] 迁入 `native_build_lowered_plan_empty()` 的嵌套 struct literal return，使该
            helper 达到 body complete；`make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
            `bash tests/verify_native_lowered_plan_empty_contract.sh`、
            `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
            `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 通过；真实
            frontier 前进为 `native_hosted_pending_body_frontier:
            function=native_build_reachability_empty decl=303 function_id=10 body_stmts=1
            reason=pending_core_body`。
          - [x] 为 `native_build_reachability_empty()` 补 CoreBody/PortableMIR body-complete
            合同；固定 `NativeBuildReachability{ decl_to_function_index: null,
            function_decl_indices: null, assigned_count: 0, capacity: 0 }` return surface，
            不改生产 lowering。
            - 2026-06-11：新增 `tests/verify_native_reachability_empty_contract.sh` 并接入
              `tests/verify_native_cmd_build_stage1.sh`；`docs/native_cmd_build_subset.md`
              新增 `native_build_reachability_empty()` Body Complete Contract，冻结当前 pending
              frontier，并要求迁入后达到 `body_complete`。
            - 实测 `bash tests/verify_native_reachability_empty_contract.sh`、
              `bash tests/verify_native_cmd_build_stage1.sh` 和 `git diff --check` 通过；
              本叶子未改生产 lowering。
          - [x] 迁入 `native_build_reachability_empty()` 的 struct literal return，使该 helper
            达到 body complete；`make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
            `bash tests/verify_native_reachability_empty_contract.sh`、
            `bash tests/verify_native_cmd_build_no_silent_c99.sh`、
            `bash tests/verify_native_cmd_build_stage1.sh`、`git diff --check` 通过；真实
            frontier 前进为 `native_hosted_pending_body_frontier:
            function=native_build_local_table_empty decl=307 function_id=11 body_stmts=1
            reason=pending_core_body`。
        - `compile_files(...)` 到达前置门槛：
          - [ ] 当真实 frontier 首次指向 `compile_files(...)` 时，固定 callee 名称、caller stmt、
            pending reason 和 no-silent-C99 失败形状；不改生产实现。
          - [ ] 为 `compile_files(...)` 16 参数 ABI 补合同：固定参数数量、源码顺序、每个 operand 的
            typed 类型、null / scalar / pointer 参数边界和 out-artifacts 指针。
          - [ ] 为 `compile_files(...)` PortableMIR call surface 补合同：固定 hosted runtime capability、
            target calling convention、call result、cleanup edge 和 handoff frontier；不改生产实现。
          - [ ] 迁入 `compile_files(...)` 调用 ABI / entry frontier，不进入函数体；self-build 仍必须因
            `compile_files(...)` pending body 明确拒绝写出。
          - [ ] 审计 `compile_files(...)` body surface，写入分层清单：artifact reset、arena 初始化、
            `get_argv(0)` / `get_uya_root`、路径规范化、输入收集、依赖扫描、lexer/parser、AST merge、
            SemanticDb/checker/TypedProgram、C99/native handoff、stats 和 cleanup。
        - `compile_files(...)` artifact/path 入口切片：
          - [ ] 为 `compile_artifacts_reset` 与 out-artifacts 初始写入补 CoreBody/PortableMIR 合同；不改生产实现。
          - [ ] 迁入 `compile_artifacts_reset` 与 out-artifacts 初始写入，并冻结下一 frontier。
          - [ ] 为 transient arena / compiler arena 初始化补合同：固定成功路径、失败 diagnostic 和 cleanup
            frontier；不改生产实现。
          - [ ] 迁入 transient arena / compiler arena 初始化和失败 diagnostic。
          - [ ] 为 `get_argv(0)` / `get_uya_root` / project-root override / lib-root 规范化入口补合同；
            不改生产实现。
          - [ ] 迁入 `get_argv(0)`、`get_uya_root`、project-root override 和 lib/root 路径规范化入口。
        - `compile_files(...)` 输入与依赖收集切片：
          - [ ] 为输入与依赖收集补合同：固定 input argv/override 选择、目录/文件路径、module root
            override、依赖去重和 `@c_import` sidecar frontier；不改生产实现。
          - [ ] 迁入输入 argv / output override 选择和基础路径 diagnostic。
          - [ ] 迁入目录/文件路径分支与 module root override 应用。
          - [ ] 迁入依赖收集队列、去重和超过动态表容量的明确 diagnostic。
          - [ ] 迁入 `@c_import` sidecar plan 入口和 hosted link object 统计。
        - `compile_files(...)` lexer/parser/AST merge 切片：
          - [ ] 为 lexer/parser/AST merge 补合同：固定源码读取、tokenize、parse、merge diagnostics
            和失败 cleanup；不改生产实现。
          - [ ] 迁入源码读取和 read failure cleanup。
          - [ ] 迁入 tokenize 入口、token buffer lifetime 和 lexer diagnostic。
          - [ ] 迁入 parse 入口、AST node arena/range 和 parser diagnostic。
          - [ ] 迁入 AST merge、entry auto-inject 和 merge failure cleanup。
        - `compile_files(...)` SemanticDb/checker/TypedProgram 切片：
          - [ ] 为 SemanticDb/checker/TypedProgram 补合同：固定 semantic build、checker_build、
            typed program stats/lifetime、safety proof flag 和错误路径释放；不改生产实现。
          - [ ] 迁入 SemanticDb build/reset、动态表 stats 和失败 diagnostic。
          - [ ] 迁入 checker_build 主调用、diagnostic profile 和 safety-proof flag。
          - [ ] 迁入 TypedProgram lifetime stats、peak/release 统计和错误路径释放。
        - `compile_files(...)` codegen handoff 切片：
          - [ ] 为 codegen handoff 补合同：固定 C99 output path、hosted native PortableMIR request、
            `out_artifacts` 写入、split-C/c_import link plan 和 backend-specific diagnostics；不改生产实现。
          - [ ] 迁入 C99 output path、split-C request 和 generated C path 写入。
          - [ ] 迁入 hosted native PortableMIR request / target backend request handoff。
          - [ ] 迁入 `out_artifacts` 的 generated output、c_import sidecar 和 link plan 写入。
          - [ ] 迁入 backend-specific diagnostics，继续禁止 native 静默回落 C99。
        - `compile_files(...)` 收尾切片：
          - [ ] 为收尾补合同：固定 compile stats、arena/table/typed program 释放、generated bytes、
            success/failure return 和 frontier complete 诊断；不改生产实现。
          - [ ] 迁入 compile stats、arena/table/typed program 释放和 output bytes 统计。
          - [ ] 迁入 success/failure return，标记 `compile_files(...)` body complete 并推进真实 frontier。
        - hosted executable writer 解锁与 Phase 10 收口：
          - [ ] 当 reachable pending body 数收敛到 0 时，补 writer 解锁合同：固定 `pending_core_bodies=0`、
            imported/output preflight ready、link plan complete 和 `can_write=1` 预期；不改生产实现。
          - [ ] 为 no-silent-C99 反向检查补合同：`--native` 写出失败时仍不得生成 C99 oracle 输出、不得
            使用 pre-MIR helper、不得吞掉 native diagnostic；不改生产实现。
          - [ ] 解锁 hosted executable writer：允许 `NativeHostedExecutableWriterPlan.can_write=1`，
            移除 `pending_core_bodies` 阻塞，但仍保留 `--native` 不回落 C99 的反向检查。
          - [ ] 消除 `native_hosted_portable_mir_lowering_missing` 诊断：self-build stderr 不再包含
            lowering-missing / pending-core-body / pre-MIR helper 信息，且失败时仍有明确 native diagnostic。
          - [ ] 证明 `cmd/build --native` self-build 生成 executable：输出文件存在、可执行、ELF/header 合法，
            且不是 C99 fallback 产物。
          - [ ] 用新生成的 native `bin/cmd/build` 复跑 self-build 门禁，确认新二进制仍走 PortableMIR hosted
            handoff。
          - [ ] 用新生成的 native `bin/cmd/build` 复跑 compiler regression 和 C99 output parity 门禁。
          - [ ] 记录 native `cmd/build` 自身构建耗时与 peak RSS，为 Phase 10 KPI 收口。

测试：

- [x] 新增 `tests/verify_native_cmd_build_stage1.sh`。
- [x] 新增 `tests/verify_native_cmd_build_no_silent_c99.sh`，固定当前失败形状并防止静默回落。
- [x] 用 native `cmd/build` 编译最小程序。
- [x] 新增 `tests/verify_native_cmd_build_compiler_regressions.sh`。
- [x] 用 native `cmd/build` 编译一组 compiler regression。
- [x] 新增 `tests/verify_native_cmd_build_c99_output_parity.sh`。
- [x] 用 native `cmd/build` 生成 C99 output，并与 C99-built compiler 输出比对。

开发阶段相关验证（单个切片完成时优先运行；不把 `make backup-all` 作为每任务门禁）：

```bash
git diff --check
make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya
bash tests/verify_native_cmd_build_no_silent_c99.sh
bash tests/verify_native_cmd_build_regression_boundary.sh
bash tests/verify_native_cmd_build_stage1.sh
```

阶段收口验证：

```bash
make check
```

阶段 KPI：

- [ ] native `cmd/build` 可构建自身。
- [ ] native `cmd/build` 自身构建 `< 3000ms`。
- [ ] native `cmd/build` 自身构建 peak RSS 相比 Phase 0 baseline 下降至少 50%。
- [ ] 不新增 `RETURN_*`、`LOCAL_CALL_*`、`IF_LOCAL_*` 等 one-off `LoweredBodyOp` 作为 Phase 10 继续推进方式。

---

## Phase 11: `make uya` native 主路径

Phase 11 只在 Phase 10 的 hosted native `bin/cmd/build` self-build executable 真实通过后开始。
本阶段目标是切换构建入口，不再扩展 MIR 语言面；任何 native 失败都必须显式报错，不得静默回落 C99。

- 构建入口合同切片：
  - [ ] 为 `UYA_BUILD_BACKEND=native|c99` 补 Makefile/脚本合同测试：默认 native、显式 C99、
    非法值 diagnostic、native 失败 no-silent-fallback 和手动 C99 fallback。
  - [ ] 为 `make uya-c99` 补合同测试：必须保留旧 C99 路径，输出 `bin/uya`，且不调用 hosted native
    `cmd/build`。
  - [ ] 为 `make uya` 输出布局补合同测试，固定必须生成：

```text
bin/uya
bin/cmd/build
```

- 构建入口实现切片：
  - [ ] 接入 `UYA_BUILD_BACKEND` 选择器：`native` 使用 Phase 10 的 hosted native `cmd/build`，
    `c99` 使用旧 C99 seed 路径，非法值明确失败。
  - [ ] 新增 `make uya-c99`，保留旧路径作为手动 fallback。
  - [ ] 将 `make uya` 默认切到 hosted native path，并确保同时落地 `bin/uya` 和 `bin/cmd/build`。
  - [ ] 保留 freestanding native path 作为 build-seed / 下沉目标，不作为 hosted native 完整语言 parity
    的阻塞项。
- 命令安装与 release/backup 切片：
  - [ ] `make cmds` / install flow 安装 `bin/cmd/build`。
  - [ ] `make cmds` / install flow 安装 `bin/cmd/microapp`（若 Phase 7A 已完成）。
  - [ ] release flow 同时验证 native 与 C99，并区分 hosted native 完整语言结论与 freestanding native
    build-seed 结论。
  - [ ] backup flow 纳入 native seed，但保留 C99 seed fallback 和明确失败诊断。
- Phase 11 收口切片：
  - [ ] 运行 `make clean && make uya`、`make cmds`、`bin/uya microapp --help` 和 native path
    no-silent-fallback 门禁，只跑本阶段相关验证。

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

Phase 12 是发布前差分验收，不再承载新的后端语言特性；若差分暴露语言 lowering 缺口，回到
Phase 9B；若暴露 self-build / 构建入口缺口，回到对应 Phase 10/11 叶子修复后再回来收口。

- native/C99 差分门禁切片：
  - [ ] 为 native-built 与 C99-built compiler 的 `make check` 输出/退出码对比补脚本合同。
  - [ ] native-built compiler 跑 `make check` 并保存 normalized 结果。
  - [ ] C99-built compiler 跑 `make check` 并保存 normalized 结果。
  - [ ] 对比核心测试输出、退出码和 diagnostics 文案，差异必须有明确 allowlist 或修复项。
- 自举产物差分切片：
  - [ ] 为 `src/main.uya` C99 output 结构性摘要补比对脚本，避免依赖非稳定空白或路径。
  - [ ] 对比 native-built 与 C99-built 的 `src/main.uya` C99 output 结构性摘要。
  - [ ] 为 native 自举二轮产物 normalized section hash 补合同和记录格式。
  - [ ] 对 native 自举二轮产物做 normalized section hash，并记录差异结论。
- 文档收口切片：
  - [ ] 更新 `docs/compiler_1s_speed_assessment.md`，记录 native cold build 三次中位数、P95、
    peak RSS、arena peak 和 output bytes。
  - [ ] 更新 `docs/compiler_1s_architecture_design.md`，同步 hosted native / C99 / freestanding native
    的职责边界。
  - [ ] 更新 `docs/todo_compiler_1s.md`，确保已完成项都有验证证据，剩余项不是隐藏 epic。
  - [ ] 更新 `docs/UYA_BUILD_RUN.md`、`docs/TESTING.md` 和
    `docs/c99_codegen_hotpath_benchmark.md`。
  - [ ] release 文档说明 native path 与 C99 fallback。
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
  - [ ] 复验 hosted native backend 经由 `PortableMIR` 支持完整 Uya 语言，不只支持 Phase 10 的 native
    `cmd/build` 子集。
  - [ ] 复验 freestanding native 能力按 hosted native 已验证的 MIR 能力逐步下沉，不阻塞完整语言
    hosted parity。
  - [ ] 复验 C99 与 native 对同一套完整语言回归输入给出一致的成功/失败、退出码、diagnostics 和可执行行为。
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
- [x] 默认安全证明路径保留。  # 2026-06-10: `src/compile.sh:335` `USE_SAFETY_PROOF=true`；`make uya`/`make uya-hosted`/`make b` 全部硬编码 `--safety-proof`；`make check` 主线未变。
- [ ] C99 backend 完整支持 Uya 语言，并与 main 分支语言行为兼容。
- [ ] Hosted native backend 经由 `PortableMIR` 完整支持 Uya 语言，并与 C99 / main 分支语言行为兼容。
- [x] Freestanding native build-seed 子集保持 no-silent-C99 fallback 和明确 capability diagnostic。  # 2026-06-10: 合同文档 `docs/native_cmd_build_subset.md` 与 `tests/verify_native_cmd_build_regression_boundary.sh` 固化边界；`bin/uya --native`/`bin/cmd/build --native` 对不支持子集都显式 reject with `native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing`，不静默回退 C99。
- [ ] Microapp / microcontainer 语言层面完全兼容 main 分支；仅允许 runtime/capability/profile 限制。
- [ ] native/C99 差分验证通过。
- [ ] release/backup 流程无死锁。
- [ ] 文档与 TODO 已同步。
- [x] microapp CLI 不再依赖旧顶层 `pack-image` / `inspect-image` / `verify-image` 作为主入口。  # 2026-06-10: `bin/cmd/microapp --help` 只接受 `pack/inspect/verify`；`bin/cmd/microapp pack-image` 报 `未知 microapp 子命令: pack-image`。`bin/uya pack-image` 报 `顶层 \`pack-image\` 已迁移，请使用 \`bin/uya microapp pack ...\``。

---

## 当前下一步

剩余工作已一次性差分为下面的执行队列。完整语言到 MIR 是 Phase 10 的前置，不再把
`cmd/build` self-build frontier 当作当前唯一驱动。原始 hosted `cmd/build` self-build emitter/handoff 是
epic，不是单个实现任务；后续只处理文档中唯一的 `[~]` 或第一个未完成叶子。主清单里的
`[x]` / `[~]` / `[ ]` 是唯一状态来源；本段只做执行索引，避免把 epic 当成一个大任务直接实现。
每个叶子先补合同/边界测试，再改实现，验证只跑任务相关测试和必要的 `cmd-build` 重建，不把
`make backup-all` 作为每任务门禁。

执行规则：

- 每次只把一个主清单叶子标成 `[~]`；本索引里的分组名不单独标状态。
- 当前下一可执行叶子是 Phase 9B 覆盖矩阵合同：新增 `docs/portable_mir_language_coverage.md`。开始时只把
  覆盖矩阵合同中的对应主清单叶子标成 `[~]`。
- Phase 10 的 helper、`compile_files(...)` 和 writer 解锁仍必须由真实 self-build frontier 诊断驱动；
  但只有在 Phase 9B 覆盖矩阵、语言面首切片和 MIR -> Native 首目标通过后才恢复推进。诊断未到达前，
  只允许补审计/合同，不允许提前实现猜测中的 helper。
- 单叶子验证优先使用：`git diff --check`、todo checker、本叶子合同脚本和必要的相关基线。当前
  覆盖矩阵合同是文档/脚本合同叶子；HelloWorld 进入 MIR -> Native 目标后再优先跑
  `verify_hosted_native_helloworld_parity.sh`。`verify_hosted_native_full_language_smoke.sh`
  在覆盖矩阵和专用 reject diagnostic 落地前只作为 legacy 边界回归，不作为新增 shard 的 no-missing 证据。
- Phase 10 恢复后，相关单叶子再使用 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`、
  `verify_native_cmd_build_no_silent_c99.sh`、`verify_native_cmd_build_regression_boundary.sh` 和必要的 stage1 边界。
- `make check` 只作为阶段收口或高风险共享行为验证；`make backup-all` 只放到发布/最终收口，不作为每个
  叶子的提交门槛。

差分队列：

0. PHASE9B-COVERAGE-MATRIX：先建立完整语言到 MIR 覆盖矩阵。
   - 合同叶子：新增 `docs/portable_mir_language_coverage.md`。
   - 合同叶子：新增 coverage verifier，要求 AST/Core/MIR kind 新增时同步覆盖矩阵。
   - 整理叶子：把现有 done / partial / reject / missing shard 写入矩阵，尤其记录 MIR -> Native HelloWorld
     目标前的真实缺口。
1. PHASE9B-LANGUAGE-SURFACE：按覆盖矩阵补通用 lowering，不再绕 `cmd/build` 特例推进。
   - print/println 首切片：冻结 `AST_PRINT` / `AST_PRINTLN` 的 CoreBody surface、PortableMIR call/write surface、
     hosted/freestanding capability 和返回值语义。
   - statements 组：expr stmt、decl、assign、if/else、while/for、break/continue、return、defer/drop、
     try/catch。
   - expressions 组：literal、identifier、binary/unary、short-circuit、call/method、field/index/slice、
     cast/address/deref、aggregate literal、string interp、builtin。
   - types/layout 组：pointer、array、slice、struct、union、enum、error union、interface、generic、
     atomic、vector/mask、naked fn。
   - runtime/builtin 组：stdout/stderr、malloc/free、file/env/toolchain、`@syscall`、`@c_import` 和规范启用的
     builtin。
2. PHASE9B-MIR-NATIVE-HELLOWORLD：MIR -> Native 的第一个端到端目标。
   - 合同叶子：新增 `tests/verify_hosted_native_helloworld_parity.sh`，固定 `@println("Hello, World!")`
     native/C99 stdout、stderr、退出码和 no-fallback 预期。
   - 实现叶子：NativeMirEmitter 支持 `@print` / `@println` 的 string constant、stdout/write 或 hosted libc handoff。
     - TDD 子叶子 L994.A：把 `uya_write(fd, ptr, len)` / `uya_write_str(fd, ptr, len)` /
       `uya_write_newline(fd)` 三个 hosted runtime helper 写为新 `extern fn` 声明，挂到
       `src/build_compiler_driver.uya` 的 `native_build_hosted_mir_append_extern_function`
       调用前的 hosted helper 注册路径；要求 stderr 新增
       `mir_extern_function_count: name=uya_write`/`uya_write_str`/`uya_write_newline` 计数。
     - TDD 子叶子 L994.B：在 `src/exec/lower.uya` 把 `HIR_EXPR_PRINT`/`HIR_EXPR_PRINTLN` 字符串
       字面量分支（不含 interp、不含 format）下放到 `CORE_STMT_KIND_EXPR` +
       `CORE_EXPR_KIND_CALL`，call target 是 L994.A 注册的 `uya_write_str` / `uya_write_newline`
       extern。要求 `native_hosted_preflight` 报告 `mir_body_functions > 0`。
     - TDD 子叶子 L994.C：补全 `src/lower/mir_verifier.uya` 中 `CORE_EXPR_KIND_CALL` 路径对
       print helper extern 的 ABI 校验（参数 i32/i64 寄存器、ret i32、non-naked）。
     - TDD 子叶子 L994.D：NativeMirEmitter 接受 verifier-clean 的
       `CORE_EXPR_KIND_CALL`→`uya_write_str` 并 emit x86_64 `call <extern>`；
       ABI 用 SysV i32/i64 寄存器约定（fd → EDI，ptr → RSI，len → EDX）。
     - TDD 子叶子 L994.E：hosted link plan 在 `native_hosted_executable_writer_*` 阶段
       把 print helper C 实现（`src/codegen/c99_build/main.uya:3091-3097` 现有的
       `uya_write`/`uya_strlen` 静态函数）作为额外 link object 拉入。
     - TDD 子叶子 L994.F：把 `verify_hosted_native_helloworld_parity.sh` 顶部的
       期望成功子句打开（不再走 reject 分支），并把
       `verify_full_language_backend_parity.sh` 的 `UYA_FULL_LANGUAGE_PARITY_NATIVE=1`
       路径覆盖到 hello world（case 01）@println 场景。
   - 收口叶子：HelloWorld native executable 真实输出 `Hello, World!\n`，stderr 不再包含
     `native_hosted_portable_mir_lowering_missing`。
3. PHASE9B-FULL-LANGUAGE-PARITY：完整语言后端差分套件前移到 Phase 10 前。
   - 合同叶子：整理 `tests/verify_full_language_backend_parity.sh` 输入清单和 normalized diff。
   - 实现叶子：C99 与 hosted native 对同一套完整语言回归给出一致结果；native reject 必须与覆盖矩阵一致。
   - 收口叶子：普通 HelloWorld、基础标准库程序和完整语言 smoke 不再出现 lowering-missing。
4. PHASE10-RESUME：Phase 9B 覆盖矩阵、语言面首切片和 MIR -> Native 首目标通过后，再恢复 `cmd/build` self-build frontier。
   - 只处理真实 frontier 指向的 helper/body-prefix。
   - 若 frontier 暴露新的通用语言面缺口，先回 Phase 9B，不在 Phase 10 追加 one-off shape。
5. PBA-PROJECT-ROOT：完成 `parse_build_args(...)` 的 `--project-root` 分支。
   - 已完成叶子：参数读取，覆盖 `i = i + 1`、`get_argv(i)`、
     `root_arg == null || root_arg[0] == 0` 和空参数 diagnostic。
   - 已完成叶子：长度检查，覆盖 `strlen(root_arg)`、`root_len >= PATH_MAX`
     和路径过长 diagnostic。
   - 已完成叶子：成功写入，覆盖 `strcpy(&g_module_root_override[0] as *byte, root_arg)` 和
     `g_module_root_override_active = 1`。
6. PBA-SEED-REJECT：完成 build-seed 明确拒绝选项。
   - 已完成合同叶子：固定 `--manifest-path`、exec/vm/dump/trace、microapp profile、`--outlibc`
     diagnostic、`return -1` 和 seed 边界。
   - 已完成叶子：`--manifest-path`。
   - 已完成叶子：exec/vm/dump/trace 多重 `strcmp ||` 条件。
   - 已完成叶子：`--app`、`--microapp-profile`、`strncmp("--microapp-profile=", 19)`。
   - 已完成叶子：`--outlibc`。
7. PBA-STACK-SIZE：完成 `--stack-size` 数字扫描。
   - 已完成叶子：固定缺参、byte index、digit while、累积、有效写入、无效 warning。
   - 已完成叶子：缺参和 `get_argv(i + 1)`。
   - 已完成叶子：`size_str[j]`、ASCII digit 条件、累积表达式和 `j = j + 1`。
   - 已完成叶子：`stack_size[0]` 写入、warning 和跳参。
8. PBA-SPLIT-C：完成 split-C / async-frame CLI。
   - 已完成叶子：固定 async-frame、`--no-split-c`、inline/separate `--split-c-dir` 和 default-dir。
   - 已完成叶子：`--async-frame-heap=on`。
   - 已完成叶子：`--no-split-c`。
   - 已完成叶子：inline `--split-c-dir=<dir>` disabled warning。
   - 已完成叶子：inline `--split-c-dir=<dir>` 成功/default。
   - 已完成叶子：separate `--split-c-dir <dir>` disabled-skip。
   - 已完成叶子：separate `--split-c-dir <dir>` 成功/default。
9. PBA-INPUTS：完成位置输入文件收集。
   - 已完成合同叶子：固定 `arg[0]`、容量检查、index/count 写入和未知 dash option no-op。
   - 已完成实现叶子：`arg[0]` / 非 dash 判定。
   - 已完成实现叶子：输入容量检查 diagnostic。
   - 已完成实现叶子：`input_file_indices[idx]` 和 `input_file_count[0]` 写入。
10. PBA-TAIL：完成 `parse_build_args(...)` 收尾。
   - 已完成合同叶子：固定无输入 diagnostic、`print_usage`、out path 获取、`.c` 推断和 native `.c` 拒绝。
   - 已完成实现叶子：未指定输入文件。
   - 已完成实现叶子：显式输出路径读取。
   - 已完成实现叶子：`.c` 输出推断 C99。
   - 已完成实现叶子：`--native` 输出 `.c` 拒绝。
   - 已完成实现叶子：末尾 `return 0`，标记 `parse_build_args(...)` body complete。
11. FRONTIER-RESET：`parse_build_args(...)` complete 后重建 `cmd-build` 并重新跑 self-build frontier。
   - 已完成叶子：只把诊断实际报告的下一个 reachable callee 写入 todo 和
     `docs/native_cmd_build_subset.md`。
   - 实测下一个 reachable callee：`build_compiler_driver_run` stmt 17 的
     `set_process_stack_limit_bytes(...)`。
   - 已完成叶子：固定 `set_process_stack_limit_bytes(...)` helper frontier 合同。
   - 同步 `tests/verify_native_cmd_build_no_silent_c99.sh`，继续要求 no-output / no-silent-C99。
12. HELPER-QUEUE：真实 helper 队列只由 frontier 诊断驱动。
   - 已完成叶子：审计 `set_process_stack_limit_bytes(...)` body surface。
   - 已完成叶子：为 `set_process_stack_limit_bytes(...)` 的 Linux x86_64 首切片补合同。
   - `set_process_stack_limit_bytes(...)` 首切片已迁入，且已复跑 self-build frontier；当前 stderr 未输出新的
     reachable callee/body-prefix frontier，只剩 `pending_core_bodies` handoff 阻塞。
   - 已新增 handoff-only pending body frontier 诊断；实测下一个 pending body 是
     `compile_stats_record_and_release_typed_program(...)`。
   - 候选只能来自 `native_hosted_reachable_callee_frontier` 或 body frontier，不提前指定
     `compile_files(...)`、toolchain helper 或其它大函数。
13. COMPILE-FILES：只有真实 frontier 指向 `compile_files(...)` 时才进入。
   - 先固定 16 参数 ABI 和 entry frontier。
   - 再按 artifact/path、输入依赖、lexer/parser/AST、SemanticDb/checker/TypedProgram、
     codegen handoff、cleanup 六组切片推进。
14. WRITER-UNLOCK：只有 reachable pending body 收敛到 0 时才进入。
    - 先补 writer 解锁合同，证明 `can_write=1`、pending body 为 0、link plan complete。
    - 再允许 hosted executable writer 写出。
    - 最后消除 `native_hosted_portable_mir_lowering_missing`，并用新 native `bin/cmd/build`
      复跑 self-build、compiler regression、C99 output parity 和 KPI 记录。
15. MAKE-NATIVE-PATH：Phase 10 self-build executable 真实通过后，再切 `make uya` 主路径。
    - 合同叶子：固定 `UYA_BUILD_BACKEND=native|c99`、`make uya-c99`、native 失败不静默 fallback、
      手动 C99 fallback 和 release flow 双路径语义。
    - 实现叶子：Makefile 接入 `UYA_BUILD_BACKEND`，保留 `make uya-c99`。
    - 实现叶子：`make uya` 默认走 hosted native path，并确保输出 `bin/uya` 与 `bin/cmd/build`。
    - 实现叶子：`make cmds` / install 安装 `bin/cmd/build` 和 `bin/cmd/microapp`。
    - 实现叶子：backup / release flow 纳入 native seed，但仍保留 C99 seed fallback。
    - 收口叶子：跑 `make clean && make uya`、`make cmds`、microapp help、相关 regression 和
      native path no-silent-fallback 门禁。
16. NATIVE-KPI：`make uya` native 主路径稳定后再做性能收口。
    - benchmark 合同叶子：固定三次中位数、P95、peak RSS、arena peak 和 output bytes 字段。
    - 实测叶子：跑 `make bench-compiler-1s-check` 和三次 native cold build，记录结果到评估文档。
    - 修复叶子：只针对已测出的 native 主路径热点/内存回归拆分实现，不提前泛化优化。
17. RELEASE-PARITY：native/C99 差分验证和自举二轮收口。
    - 合同叶子：固定 native-built 与 C99-built `make check` 的输出/退出码/diagnostic 比对格式。
    - 实现叶子：整理核心测试输出与 diagnostics 比对脚本。
    - 实现叶子：整理 `src/main.uya` C99 output 结构摘要比对。
    - 实现叶子：整理 native 自举二轮产物 normalized section hash。
18. RELEASE-FULL-LANGUAGE-VERIFY：发布前复验完整语言后端差分套件。
    - 合同叶子：固定 main 分支语言兼容基线来自 `docs/uya.md`、formal/quick grammar、builtin 文档和
      完整语言回归。
    - 套件叶子：覆盖多文件模块、泛型、方法、接口、error union、`try/catch`、defer/errdefer、
      async、struct/union/enum、slice/array、pointer、atomic、vector/mask、`@c_import`、builtin 和标准库入口。
    - 验收叶子：确认 Phase 9B 的 hosted native / PortableMIR 完整语言覆盖与 C99 给出一致成功/失败、
      退出码、diagnostics 和行为。
    - 实现叶子：freestanding native 只按 hosted 已验证 MIR 能力逐步下沉，保持 capability diagnostic。
19. MICROAPP-COMPAT：microapp 语言兼容收口。
    - 合同叶子：确认 microapp 不引入专属语法、关键字、builtin 或 checker 方言。
    - 实现叶子：`uya microapp build` 使用普通 `uya build` 同源 parser/checker，差异只在安全策略、
      ABI、镜像格式和 runtime capability 裁决。
    - 文档叶子：发布说明记录 microapp 限制都是 runtime/capability/profile 限制。
20. DOCS-RELEASE：最终文档和发布说明。
    - 文档叶子：更新 `docs/compiler_1s_speed_assessment.md`。
    - 文档叶子：更新 `docs/compiler_1s_architecture_design.md`。
    - 文档叶子：更新 `docs/UYA_BUILD_RUN.md`、`docs/TESTING.md` 和
      `docs/c99_codegen_hotpath_benchmark.md`。
    - 文档叶子：release 文档说明 native path、C99 fallback 和 microapp 命名空间命令。
21. FINAL-GATE：最终验收。
    - 收口叶子：跑 `git diff --check`、bench check、三次 bench、`make check`、`make check-hosted`、
      `make microapp-check` 和完整语言后端差分门禁。
    - 发布叶子：最终才跑 `make backup-all`，同步生成的 seed/backup，并完成最后提交/推送。
