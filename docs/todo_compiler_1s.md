# Uya 编译器 1 秒冷构建 TODO

**状态**: executable TODO, implementation pending
**更新日期**: 2026-06-04
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
- 所有随程序规模增长的表必须动态扩容，不能有写死容量、固定最大项数或静默截断。

---

## 执行原则

- 每个阶段先补 benchmark / regression，再改实现。
- 不改语言语法、BNF 或内建函数。
- 不删除 C99 fallback；C99 是差分 oracle。
- 不用大表预分配或长期常驻 IR 换取表面速度；内存指标必须和时间一起报告。
- 不新增 `C99_MAX_*`、`CHECKER_*_SIZE` 或魔法容量作为程序规模相关表的语义上限。
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
- [ ] benchmark 通过 `/proc/<pid>/status` 或 `/proc/<pid>/smaps_rollup` 采样 `peak_rss_kb`。
- [ ] benchmark 在缺少 `/proc` 的平台打印“RSS 未测量”，不能把该运行计入内存达标。
- [ ] 编译器内部新增 arena 峰值统计输出字段。
- [ ] benchmark 记录生成文件总字节数：
  - [ ] C99 单文件大小。
  - [ ] split-C 目录总大小。
  - [ ] native executable / object 总大小。
  - [ ] 临时目录总大小。
- [ ] benchmark 输出内存趋势：当前值、baseline、变化百分比。
- [ ] benchmark 输出主要动态表摘要：`table_count`、`table_capacity`、`table_bytes`、`table_realloc_count`。
- [ ] benchmark 检查表容量不是一次性巨大预分配；若 `capacity/count` 比例异常，报告 warning。
- [ ] benchmark TSV 输出字段：

```text
run	mode	seed_ms	parse_ms	bind_ms	check_ms	lower_ms	emit_ms	link_ms	total_ms	peak_rss_kb	arena_peak_bytes	output_bytes	table_count	table_capacity	table_bytes	table_capacity_bytes	table_realloc_count
```

- [ ] 用当前实现跑 3 次冷构建，记录时间 baseline 到 `docs/compiler_1s_speed_assessment.md`。
- [ ] 用当前实现跑 3 次冷构建，记录内存 baseline 到 `docs/compiler_1s_speed_assessment.md`。
- [ ] 用当前实现扫描固定容量表和直接映射缓存，记录需要迁移的 `MAX_*` / magic capacity 清单。

验证：

```bash
git diff --check
make bench-compile-stats-check
make bench-compiler-1s-check
```

---

## Phase 1: SemanticDb 基础

- [ ] 新建 `src/semantic/` 目录。
- [ ] 新建 `src/semantic/ids.uya`，定义：

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

- [ ] 新建 `src/semantic/table.uya` 或等价基础设施，提供动态 vector/hash/range builder。
- [ ] 动态表 API 必须包含 `reserve`、`ensure_capacity`、`append/insert`、`reset`、`free/release`。
- [ ] 动态表必须记录 `count`、`capacity`、`bytes`、`realloc_count`。
- [ ] 动态表增长必须检查整数溢出和 allocation failure。
- [ ] 新建 `src/semantic/intern.uya`，实现字符串 intern 表。
- [ ] intern 表按负载因子动态扩容，不允许固定 4096/8192 槽作为语义上限。
- [ ] 新建 `src/semantic/db.uya`，定义 `SemanticDb`。
- [ ] 新建 `src/semantic/build.uya`，从 merged AST 构建 `SemanticDb`。
- [ ] `SemanticDb` 内部使用紧凑数组/range，不为每个名字单独堆分配链表节点。
- [ ] `SemanticDb` 所有数组、range、hash bucket、collision list 都随数据增长动态扩容。
- [ ] `SemanticDb` 记录自身估算字节数。
- [ ] 为顶层声明建立 `DeclId -> ASTNode` 映射。
- [ ] 为文件和模块建立 `FileId` / `ModuleId`。
- [ ] 将 `use` 语句和 module export 登记为 `ImportBinding`。
- [ ] 增加 `semantic_db_reset()`，用于同进程多次编译。
- [ ] 在 `checker_init()` 或等价入口纳入 semantic cache reset。
- [ ] 增加 debug dump 开关 `UYA_DUMP_SEMANTIC_DB=1`。
- [ ] debug dump 默认关闭，打开时不计入性能/内存 KPI。

测试：

- [ ] 新增 `tests/verify_semantic_db_smoke.sh`。
- [ ] 覆盖同名函数 body/stub。
- [ ] 覆盖 `libc` / `std` family 上下文。
- [ ] 覆盖 file-local alias。
- [ ] 覆盖 whole-module import export。
- [ ] 新增 `tests/verify_dynamic_table_growth.sh`。
- [ ] 覆盖超过旧固定容量的声明数、函数数、局部变量数、泛型实例数。
- [ ] 覆盖 intern/hash 高负载和高冲突增长。
- [ ] 覆盖 growth failure 模拟，必须得到明确 diagnostic。

验证：

```bash
bash tests/verify_semantic_db_smoke.sh
make tests-uya
```

---

## Phase 2: 声明与模块索引替换

- [ ] 建 `decls_by_name: InternedNameId -> DeclRange`。
- [ ] 建 `functions_by_name: InternedNameId -> FunctionOverloadRange`。
- [ ] 建 `types_by_name: InternedNameId -> TypeDeclRange`。
- [ ] 建 `enum_variants_by_name: InternedNameId -> EnumVariantRange`。
- [ ] 建 `exports_by_module_name: (ModuleId, InternedNameId) -> SymbolId`。
- [ ] 建 `aliases_by_file_name: (FileId, InternedNameId) -> DeclId`。
- [ ] 建 `use_items_by_file_name: (FileId, InternedNameId) -> ImportBinding`。
- [ ] 上述索引全部使用动态 hash/range builder，禁止固定 bucket 数作为容量上限。
- [ ] range builder 增长后保持 `DeclId` / `SymbolId` 稳定。
- [ ] 索引构建完成后输出 count/capacity/load factor 摘要。
- [ ] 将 `find_type_alias_from_program` 改为读 `SemanticDb`。
- [ ] 将 `find_struct_decl_from_program` 改为读 `SemanticDb`。
- [ ] 将 `find_union_decl_from_program` 改为读 `SemanticDb`。
- [ ] 将 `find_interface_decl_from_program` 改为读 `SemanticDb`。
- [ ] 将 `find_enum_decl_from_program` 改为读 `SemanticDb`。
- [ ] 将 `is_enum_variant_name_in_program` 改为读 `SemanticDb`。
- [ ] 保留旧扫描函数作为临时 oracle，新增 debug 比对模式。
- [ ] 每个迁移点先跑新旧 lookup 对照，确认返回同一 AST 节点或同一诊断。

测试：

- [ ] 新增 `tests/test_semantic_lookup_alias_context.uya`。
- [ ] 新增 `tests/test_semantic_lookup_enum_variant.uya`。
- [ ] 新增 `tests/test_semantic_lookup_function_family.uya`。
- [ ] 新增 `tests/verify_semantic_lookup_oracle.sh`。
- [ ] `tests/verify_dynamic_table_growth.sh` 覆盖 Phase 2 索引超过旧容量仍能查询正确。
- [ ] `tests/verify_dynamic_table_growth.sh` 覆盖 hash 高冲突时不会回退全程序线性扫描。

验证：

```bash
bash tests/verify_semantic_lookup_oracle.sh
make check
```

阶段 KPI：

- [ ] `perf` 前 20 中 `find_type_alias_from_program` 不再是第一热点。
- [ ] 直接 C99 `check + codegen` 不回退出新错误。
- [ ] SemanticDb 引入后 peak RSS 不得高于 Phase 0 baseline；若上升，必须先压缩表结构再继续。
- [ ] 主要索引 `capacity/count` 比例在正常数据下保持可解释，不能靠超大预分配压低 rehash 次数。

---

## Phase 3: 函数与局部作用域索引

- [ ] 新建 `FunctionScopeIndex`。
- [ ] `FunctionScopeIndex` 的 params、locals、captures、async bindings 全部动态增长。
- [ ] 函数进入时一次性登记 params。
- [ ] block 进入/退出时维护 local generation。
- [ ] async bind / async local 进入同一作用域查询模型。
- [ ] 全局变量可见性由 `SemanticDb` 提供。
- [ ] 将 `c99_find_identifier_type_node` 改为读 typed/scope 表。
- [ ] 将 `lookup_identifier_type_c_impl` 改为读 typed/scope 表。
- [ ] 删除或禁用按 `local_variable_count` 拼 hash 的热点缓存。
- [ ] 泛型/async 场景恢复安全缓存 key：

```text
(template DeclId, mono signature id, local generation, async frame id)
```

测试：

- [ ] 新增局部 shadowing 测试。
- [ ] 新增泛型同模板多实例变量类型测试。
- [ ] 新增 async bind 名称冲突测试。
- [ ] 新增 block depth 退出后不可见测试。
- [ ] `tests/verify_dynamic_table_growth.sh` 覆盖大量 locals、深 block、async locals 的动态增长。

验证：

```bash
make tests-uya
make check
```

阶段 KPI：

- [ ] `c99_find_identifier_type_node` 不再进入 perf 前 20。
- [ ] codegen `body_ms` 较 Phase 0 降低至少 20%。

---

## Phase 4: TypedProgram 合同

- [ ] 新建 `src/typed/` 目录。
- [ ] 定义 `TypedProgram`。
- [ ] `TypedProgram` 只存整数 ID 和紧凑表，不复制 AST 子树。
- [ ] `TypedProgram` 内所有 `ExprId -> *`、roots、proof results 表动态增长。
- [ ] `TypedProgram` 提供 reserve/append 查询统计，不允许表达式数量固定上限。
- [ ] `TypedProgram` 记录自身估算字节数。
- [ ] 输出 `expr_types: ExprId -> TypeId`。
- [ ] 输出 `identifier_bindings: ExprId -> SymbolId`。
- [ ] 输出 `call_targets: ExprId -> CallTarget`。
- [ ] 输出 `method_dispatch: ExprId -> MethodDispatch`。
- [ ] 输出 `field_access: ExprId -> FieldId`。
- [ ] 输出 `global_init_order: GlobalId[]`。
- [ ] 输出 `reachable_roots: FunctionId[]`。
- [ ] 输出 `proof_results: ProofResult[]`。
- [ ] 给 AST 节点分配稳定 `ExprId`。
- [ ] 将 C99 后端的常规 `checker_infer_type` 调用替换为 `TypedProgram` 查询。
- [ ] 增加后端重进 checker 计数器。
- [ ] `UYA_STRICT_TYPED_BACKEND=1` 时，后端常规重进 checker 直接报错。

测试：

- [ ] 新增 `tests/verify_typed_program_backend_contract.sh`。
- [ ] 覆盖普通调用、方法调用、泛型调用、field access、global init。
- [ ] `tests/verify_dynamic_table_growth.sh` 覆盖大量表达式、调用目标和 proof result。

验证：

```bash
UYA_STRICT_TYPED_BACKEND=1 ./bin/uya src/main.uya -o /tmp/uya_strict_typed.c --c99 --nostdlib --safety-proof
make check
```

阶段 KPI：

- [ ] codegen `body_ms < 7000ms`。
- [ ] TypedProgram 常驻峰值可测量，且与 AST/LoweredProgram 生命周期分离。

---

## Phase 5: LoweredProgram 闭包收敛

- [ ] 新建 `src/lower/core.uya`。
- [ ] 定义 `LoweredProgram`。
- [ ] `LoweredProgram` 使用独立 arena。
- [ ] `LoweredProgram` 的 functions、globals、types、interfaces、err_unions、async_frames、helpers 全部动态增长。
- [ ] lowering worklist 动态增长，不允许泛型实例、err_union、runtime helper 有固定最大数量。
- [ ] `LoweredProgram` 记录自身估算字节数。
- [ ] 定义 `ConcreteFunction`。
- [ ] 定义 `ConcreteType`。
- [ ] 定义 `RuntimeHelper`。
- [ ] 定义 `ErrorUnionLayout`。
- [ ] 定义 `AsyncFramePlan`。
- [ ] 实现 worklist roots 初始化。
- [ ] 实现泛型函数实例闭包。
- [ ] 实现泛型方法实例闭包。
- [ ] 实现泛型结构体实例闭包。
- [ ] 实现 err_union 类型闭包。
- [ ] 实现 async frame 元数据闭包。
- [ ] 实现 drop/defer plan 闭包。
- [ ] 实现 runtime helper 需求闭包。
- [ ] 输出稳定排序。
- [ ] `UYA_DUMP_LOWERED_PROGRAM=1` 输出摘要。

测试：

- [ ] 新增 `tests/verify_lowered_program_closure.sh`。
- [ ] 覆盖 nested generic call。
- [ ] 覆盖 method generic call。
- [ ] 覆盖 `try/catch` 嵌套 err_union。
- [ ] 覆盖 async frame descriptor。
- [ ] 覆盖 vtable/interface method。
- [ ] `tests/verify_dynamic_table_growth.sh` 覆盖大量 mono instances、err_union layouts、async frames、helpers。

验证：

```bash
bash tests/verify_lowered_program_closure.sh
make check
```

阶段 KPI：

- [ ] C99 emitter 开始前，mono/err_union/async frame 数量已稳定。
- [ ] C99 emitter 中不得新增 mono instance。
- [ ] C99 emitter 中不得新增 err_union body。
- [ ] peak RSS 相比 Phase 0 baseline 下降至少 25%。

---

## Phase 5A: 内存生命周期收口

- [ ] 为 parser AST、SemanticDb、TypedProgram、LoweredProgram、Emitter 分配独立 arena。
- [ ] 明确每个 arena 的创建点、最后使用点和释放点。
- [ ] `make bench-compiler-1s` 输出每个 arena 的 peak bytes。
- [ ] `make bench-compiler-1s` 输出主要动态表的 count/capacity/realloc/bytes。
- [ ] 新增动态表预算检查：不得通过启动时预分配超大容量降低增长次数。
- [ ] C99 输出从“全局状态 + 边生成边补发”收口为 unit 流式写。
- [ ] native 输出不生成 debug info，不保留全量机器码临时副本。
- [ ] diagnostic 默认延迟格式化；无错误时不构造长诊断字符串。
- [ ] `UYA_DUMP_*` 相关 dump 输出不计入性能达标，并在 benchmark 中标记。
- [ ] 新增内存回归脚本 `tests/verify_compiler_memory_budget.sh`。

测试：

- [ ] `tests/verify_compiler_memory_budget.sh` 检查 benchmark TSV 含内存字段。
- [ ] `tests/verify_compiler_memory_budget.sh` 检查缺少 RSS 采样时不会误报达标。
- [ ] `tests/verify_compiler_memory_budget.sh` 检查 arena 字段存在且为非负整数。
- [ ] `tests/verify_compiler_memory_budget.sh` 检查动态表字段存在且为非负整数。

验证：

```bash
bash tests/verify_compiler_memory_budget.sh
make bench-compiler-1s-check
```

阶段 KPI：

- [ ] 内存字段进入所有 1 秒 benchmark 输出。
- [ ] AST / TypedProgram / LoweredProgram 不再无界同时常驻。

---

## Phase 6: C99 Planner / Emitter 分层

- [ ] 新建 `src/codegen/c99/plan.uya`。
- [ ] 定义 `C99Plan`。
- [ ] 定义 `C99UnitPlan`。
- [ ] `C99Plan` / `C99UnitPlan` 的 includes、typedefs、prototypes、globals、functions、helpers、deps 全部动态增长。
- [ ] split-C unit 列表动态增长，不允许固定最大 unit 数。
- [ ] 将 include/header/prelude 规划迁入 planner。
- [ ] 将 function prototype 规划迁入 planner。
- [ ] 将 type definitions 规划迁入 planner。
- [ ] 将 helper emission 需求迁入 planner。
- [ ] 将 split-C unit 分配迁入 planner。
- [ ] 将 `c99_codegen_generate` 改为：

```text
c99_plan_build(lowered)
c99_emit_plan(plan)
c99_write_split_makefile(plan)
```

- [ ] `C99Emitter` 不允许查 AST 声明。
- [ ] `C99Emitter` 不允许调用 checker。
- [ ] `C99Emitter` 不允许写 `LoweredProgram`。
- [ ] 增加 `UYA_STRICT_C99_EMITTER=1` 断言。

测试：

- [ ] 新增 `tests/verify_c99_plan_stability.sh`。
- [ ] 新增 split-C plan dependency regression。
- [ ] `tests/verify_dynamic_table_growth.sh` 覆盖大量 C99 units、prototypes、helpers、deps。
- [ ] 复跑现有 C99 regression：
  - [ ] async frame descriptors
  - [ ] imported `main`
  - [ ] private function name collision
  - [ ] VP8 short payload codegen
  - [ ] split-C Makefile dependencies

验证：

```bash
UYA_STRICT_C99_EMITTER=1 ./bin/uya src/main.uya -o /tmp/uya_c99_plan.c --c99 --nostdlib --safety-proof
make check
```

阶段 KPI：

- [ ] `UYA_PROFILE_CODEGEN` 下 `body_ms < 4000ms`。
- [ ] 直接 C99 total `< 8000ms`。
- [ ] C99 输出缓冲 peak bytes 可测量且不随输出文本大小线性常驻。

---

## Phase 7: 入口瘦身与命令外置

- [ ] 阅读 `docs/cmd_subcommand_split_design.md`。
- [ ] 更新其中过期的 8400 行基线为当前实际基线。
- [ ] 提取 `src/compiler_driver.uya`。
- [ ] 新建 `src/cmd/build/main.uya`。
- [ ] 新建 `src/cmd/check/main.uya`。
- [ ] 新建 `src/cmd/run/main.uya`。
- [ ] 新建 `src/cmd/test/main.uya`。
- [ ] 新建 `src/cmd/fmt/main.uya`。
- [ ] 将 `upm` 保持外置。
- [ ] `bin/uya` 增加 argv 原样 dispatch。
- [ ] `make cmds` 生成所有命令。
- [ ] `make clean` 清理 `bin/cmd/`。
- [ ] 保留隐式入口直到 `cmd/build` seed 稳定。

测试：

- [ ] 新增或更新 `tests/test_cmd_dispatch.sh`。
- [ ] 覆盖 `bin/uya build` 与 `bin/cmd/build` 等价。
- [ ] 覆盖 `run -- args` 参数原样传递。
- [ ] 覆盖缺失 `bin/cmd/build` 的错误信息。

验证：

```bash
make cmds
bash tests/test_cmd_dispatch.sh
make check
```

阶段 KPI：

- [ ] `bin/uya` launcher 直接 C99 构建 `< 1000ms`。
- [ ] `src/main.uya` 不再静态带入 C99/exec/microapp/upm/fmt 全量业务。

---

## Phase 8: Build seed 瘦身

- [ ] 设计最小 build compiler root。
- [ ] 明确 `cmd/build` seed 的源码边界。
- [ ] 从 seed 中移除 exec backend。
- [ ] 从 seed 中移除 microapp image/payload。
- [ ] 从 seed 中移除 upm lib。
- [ ] 从 seed 中移除 fmt。
- [ ] 从 seed 中移除 kernel packaging。
- [ ] seed 不保留大型非 build 子系统的静态表或字符串池。
- [ ] seed 产物大小纳入 benchmark `output_bytes`。
- [ ] 更新 `make from-c` / `make from-c-native`，能恢复：

```text
bin/uya
bin/cmd/build
```

- [ ] 更新 `backup-all-seed`，生成 build seed。
- [ ] 保留 C99 fallback seed。
- [ ] 防止 dispatcher-only `bin/uya` 与 `cmd/build` 互相等待。

测试：

- [ ] 新增 `tests/verify_build_seed_bootstrap.sh`。
- [ ] 清理后验证 `make from-c` 可恢复 `bin/cmd/build`。
- [ ] 清理后验证 `make from-c-native` 可恢复 `bin/cmd/build`。

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

- [ ] build seed 恢复时间 `< 3000ms`。
- [ ] seed 源文件依赖数显著少于当前 86 个文件。
- [ ] seed restore peak RSS 低于 Phase 0 baseline 50%。

---

## Phase 9: Native backend v1

- [ ] 新建 `src/codegen/native/`。
- [ ] 新建 `src/codegen/native/abi.uya`。
- [ ] 新建 `src/codegen/native/machine.uya`。
- [ ] 新建 `src/codegen/native/x86_64.uya`。
- [ ] 新建 `src/codegen/native/elf64.uya`。
- [ ] 新建 `src/codegen/native/main.uya`。
- [ ] 定义 `MachineFunction`。
- [ ] 定义 `MachineBlock`。
- [ ] 定义 `MachineInst`。
- [ ] 实现 Linux x86_64 SysV 调用约定。
- [ ] 实现栈帧布局。
- [ ] 实现线性扫描或保守寄存器分配。
- [ ] 实现整数/指针基本指令。
- [ ] 实现函数调用。
- [ ] 实现全局数据段。
- [ ] 实现字符串常量。
- [ ] 实现 reloc / symbol table 最小集合。
- [ ] 实现 ELF64 executable writer。
- [ ] reloc / symbol table / string table / section table 全部动态增长。
- [ ] 实现 nostdlib `_start`。
- [ ] 实现 syscall bridge。
- [ ] 实现 `NativeEmitter` 读取 `LoweredProgram`。
- [ ] Native emitter 输出采用 streaming writer，不保留完整 ELF 镜像副本后再写盘。
- [ ] relocation / symbol table 使用紧凑数组。
- [ ] Native emitter 不允许写死最大函数数、block 数、指令数、reloc 数或 symbol 数。

首批 native 测试：

- [ ] `tests/test_native_main_only.uya`
- [ ] `tests/test_native_int_ops.uya`
- [ ] `tests/test_native_function_call.uya`
- [ ] `tests/test_native_struct_field.uya`
- [ ] `tests/test_native_error_union.uya`
- [ ] `tests/test_native_global_init.uya`
- [ ] `tests/verify_native_backend_smoke.sh`
- [ ] `tests/verify_dynamic_table_growth.sh` 覆盖 native 大量 symbols、relocs、strings、sections。

验证：

```bash
bash tests/verify_native_backend_smoke.sh
make tests-uya
```

阶段 KPI：

- [ ] native emitter 生成最小可执行文件 `< 100ms`。
- [ ] native smoke 全部与 C99 输出/退出码一致。
- [ ] native smoke peak RSS 不高于 C99 smoke。

---

## Phase 10: Native build compiler 子集

- [ ] 统计 `cmd/build` 所需 language/runtime feature。
- [ ] 为每类 feature 标注 native 支持状态。
- [ ] 支持 parser/checker 必需 struct/array/slice 操作。
- [ ] 支持 hash/intern table 必需内存操作。
- [ ] 支持动态表 reserve/append/grow/free 必需内存操作。
- [ ] 支持 diagnostics 必需字符串输出。
- [ ] 支持 file IO 最小读取。
- [ ] 支持 `snprintf` 等格式化需求的最小替代或 native bridge。
- [ ] 支持 `malloc`/arena 需求。
- [ ] 支持 arena peak 统计在 native-built compiler 下继续工作。
- [ ] 支持 `memcpy`/`memset`/`strcmp`/`strlen`。
- [ ] 支持 compiler build 所需 error union / defer。
- [ ] 支持 compiler build 所需泛型实例。
- [ ] 生成 native `bin/cmd/build`.

测试：

- [ ] 新增 `tests/verify_native_cmd_build_stage1.sh`。
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

---

## Phase 11: `make uya` native 主路径

- [ ] 增加 `UYA_BUILD_BACKEND=native|c99`。
- [ ] 新增 `make uya-c99` 保留旧路径。
- [ ] `make uya` 默认走 native path。
- [ ] `make uya` 输出：

```text
bin/uya
bin/cmd/build
```

- [ ] native path 失败时不静默 fallback；必须显式报错。
- [ ] `make uya-c99` 可作为手动 fallback。
- [ ] release flow 同时验证 native 与 C99。
- [ ] backup flow 纳入 native seed。
- [ ] install flow 安装 `bin/cmd/build`。

验证：

```bash
make clean
make uya
make cmds
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

最终验收：

```bash
git diff --check
make bench-compiler-1s-check
make bench-compiler-1s ARGS="--runs 3"
make check
make check-hosted
make microapp-check
make backup-all
```

成功标准：

- [ ] 冷构建 KPI 达标。
- [ ] 内存 KPI 达标。
- [ ] 默认安全证明路径保留。
- [ ] native/C99 差分验证通过。
- [ ] release/backup 流程无死锁。
- [ ] 文档与 TODO 已同步。

---

## 当前下一步

建议下一次实施从 Phase 0 开始：

1. 新增 `scripts/bench_compiler_1s.sh`。
2. 新增 `make bench-compiler-1s` 与 `make bench-compiler-1s-check`。
3. 记录当前 `make clean && make uya` 的三次冷构建时间 baseline。
4. 记录当前 `make clean && make uya` 的 `peak_rss_kb`、arena 和输出字节数 baseline。
5. 再进入 Phase 1 的 `SemanticDb` 基础建设。
