# MIR-C99 Backend TODO

**状态**: executable TODO, implementation pending
**更新日期**: 2026-06-14
**上层目标**: `docs/todo_compiler_1s.md`
**覆盖矩阵**: `docs/portable_mir_language_coverage.md`
**架构设计**: `docs/compiler_1s_architecture_design.md`
**完成归档**: `docs/todo_mir_c99_backend_completed.md`
**失败归档**: `docs/todo_mir_c99_backend_failed.md`

---

## 1. 目标

MIR-C99 后端必须让普通 Uya 程序按同一套语言规则走：

```text
CoreBody -> PortableMIR -> MirC99Plan -> MirC99Emitter -> host C99 compiler
```

验收目标：

- 支持完整 Uya 语法和当前 `tests/` 覆盖的主语言面。
- 与现有 AST/LoweredProgram C99 backend 的 stdout、stderr、exit code 和 diagnostics 语义对齐。
- MIR-C99-built compiler 能复跑 `cmd/build` self-build、compiler regression、C99 output parity 和完整语言后端 parity。
- 不调用现有 `src/codegen/c99*` 生产 emitter；现有 C99 只能作为 oracle、fallback 和 release 兜底。

当前状态：

- `src/codegen/mir_c99/` 尚不存在。
- `src/lower/mir_backend.uya` 只有 `MIR_TARGET_BACKEND_C99` 和 `c99_plan: &void` 占位。
- `docs/portable_mir_language_coverage.md` 已记录 MIR-C99 全局状态为 `missing` / `partial`。

---

## 2. 完成定义

`done` 只能由以下证据之一支撑：

- 专用 MIR-C99 harness 生成 `.c`，由 host C99 compiler 编译、链接、运行，并与现有 C99 oracle 对齐。
- MIR-C99-built compiler 复跑指定 self-build / regression / parity 套件通过。
- 对不支持能力给出明确 MIR-C99 capability diagnostic，并在覆盖矩阵中登记为 `reject`。

不能作为 `done` 证据：

- 现有 AST/LoweredProgram C99 emitter 成功。
- 固定函数名、固定 statement count、固定 AST/body shape 的成功路径。
- 回查 AST body 或 `LoweredProgram` body 来补 MIR-C99 语义。
- 只通过 dump/verifier，没有端到端 host C99 compiler 运行结果。

---

## 3. 执行规则

- 每次只把一个叶子标成 `[~]`；完成后补验证命令和结果，再标 `[x]`。
- 每个实现叶子先补合同或 parity/reject 测试，再改 generic lowering 或 MIR-C99 backend。
- 新增语言面必须先更新覆盖矩阵或 MIR-C99 per-kind 状态，不能只加单个 smoke。
- self-build frontier 必须归因到通用语言结构：CFG、place/memory、call ABI、cleanup/error、runtime capability 或 MIR instruction coverage。
- self-build stage gate 只能检查 no-silent-fallback 和通用能力类别，不得把下一轮绑定到具体 helper 名、固定 body shape 或“下一处 pending body”。
- `make backup-all` 只放到阶段收口或发布前；普通叶子优先跑 focused gate、coverage verifier、`git diff --check`。
- `./bin/uya test` 默认仍走现有 AST/LoweredProgram C99 后端，只能作为 legacy/oracle 回归信号；MIR-C99 `done` 必须使用 `tests/verify_mir_c99_*` parity gate 或配置了 `MIR_C99_GENERATE_CMD` 的 oracle parity harness，并由 host C compiler 编译运行生成的 MIR-C99 `.c`。
- `bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 必须随 MIR-C99 TODO 状态更新一起运行，防止把 legacy C99 测试误记为 MIR-C99 验收证据。
- 自动循环执行时优先使用 `loop.py` 提供的目标行号、父级 checkbox 和小范围摘录；只在需要确认上下文时读取附近行，避免打印整份历史 todo 或 `loop.log`。
- 新增完成记录保持短证据：写清真实命令、通过/失败结论和必要关键错误即可；长日志、重复的 pre-commit 失败和临时路径只保留最小复现信息，避免把完整输出粘贴进本文件。
- 失败项必须保留可恢复线索：日期、阻塞命令、关键错误和后续重开条件；但不把无关构建噪声作为长期上下文。

---

## 4. 任务清单

已完成 `[x]` 项已移至 `docs/todo_mir_c99_backend_completed.md`；失败 `[f]` 项已移至 `docs/todo_mir_c99_backend_failed.md`；本文件只保留待办 `[ ]`、进行中 `[~]` 和执行规则。

归档索引仅用于定位历史能力，完整验证证据以归档文件为准：

- PortableMIR type/layout metadata；标量 type kind；array / slice type kind；struct / union / enum field layout metadata；error union layout metadata；function type / function pointer type metadata。
- 整数一元、逻辑、非 i32 算术/比较 opcode；bool 组合 opcode；conversion opcode；f32/f64 算术、比较、常量和 return/call value verifier 规则。
- local/global/param address opcode；field address / load / store opcode；array index address / load / store opcode；slice ptr / len / index address opcode；pointer offset opcode；aggregate copy / move opcode。
- direct call、extern call、method/monomorphized call、function pointer call；global scalar / aggregate initializer、string constants、dedupe id 和 section/linkage metadata；extern globals、C import object/link inputs、symbol visibility 和 target profile metadata；split-C 多 unit 所需的 cross-unit symbol/export/import/ref metadata。
- cleanup edge、drop opcode 和 unwind/error path metadata；error union success/failure CFG；async frame metadata：state tag、result slot、await child slot、captured locals、poll/resume edge、frame allocation/free capability；async frame struct layout、state tag、result slot、await child slot 和 captured locals；poll/resume state machine 的低级 C label/goto；await bind direct await loop await；async frame pool 和 `--async-frame-heap=on` fallback；async error union return、cleanup edge、defer/errdefer 与 frame release。
- SIMD vector/mask load/store/splat/select opcode；SIMD 首版 reject；atomic init/load/store/RMW/CMPXCHG opcode；atomic 首版 reject；host C compiler oracle parity；tests/test_async_*.uya。
- basic async full-language parity；control-flow async parity；frame/pool async parity；scheduler/channel/IO/compute async parity；async cleanup/resource full-language parity。

### 4.15 Full Language Parity

失败项已移至 `docs/todo_mir_c99_backend_failed.md`；完整语言 parity 当前没有可执行的未归档叶子任务。

### 4.16 Self Build

路线复盘（2026-06-14）：

- 当前 `cmd/build` MIR-C99 仍是 summary-only：host C compiler 可以编译 summary C，但候选执行仍以 exit 70 报告 `compiler_binary_status=not_yet_generated`，不是 compiler binary。
- 继续逐个 `pending_core_bodies` / `native_build_*` helper 做 body-complete 会持续前移 summary frontier，却不能证明 `MirC99Plan`、真实 C emitter、runtime capability、call ABI、link/output 和 absence gate 在收敛。
- 冻结当前 frontier 样本：`native_build_type_named_equals` / `generic_corebody_type_named_equals_body_lowering` 只保留为诊断上下文，不再作为 active leaf。
- 4.16 后续禁止新增只按 helper 名、固定 statement count、固定 body shape 或“下一处 pending body”推进的任务；每个 self-build 叶子必须绑定到通用能力类别、可量化收敛指标和端到端 host C 证据。

helper-frontier 历史回归边界（2026-06-14，非 4.16 active path）：

- 归档样本固定为 `native_build_type_named_equals` / `generic_corebody_type_named_equals_body_lowering`；它们只用于保留“summary frontier 曾阻塞在 helper lowering”这一历史事实，不再定义下一轮任务顺序。
- stage gate 只允许检查两类事实：`cmd/build` MIR-C99 路线没有静默 fallback/静默成功，以及当前阻塞 helper 能被归入 CFG、place/memory、call ABI、aggregate/layout、cleanup/error、runtime helper、emitter/output、link/absence 等通用能力类别。
- stage gate 不得要求继续完成 `native_build_type_named_equals`、枚举下一个 `pending_core_bodies` helper，或用 helper 名、body shape、statement count 变化来定义进展。

- [ ] MIR-C99-BACKEND-SELF-BUILD-RESET：重整 self-build 路线为能力收敛。
  - [ ] 根据 audit 重建 capability backlog：CFG、place/memory、call ABI、aggregate/layout、cleanup/error、runtime helper、emitter/output、link/absence；每个 backlog 叶子必须有失败优先的 parity/reject gate 和 host C 编译运行证据。
    - [ ] runtime helper：audit=`blocked_category_runtime_helper=candidate_runtime_capability_missing`；gate=`bash tests/verify_mir_c99_memory_string_runtime_parity.sh` + `bash tests/verify_mir_c99_helloworld_runtime_parity.sh` + `bash tests/verify_mir_c99_file_io_runtime_parity.sh`；host C 证据=上述 gate 编译并运行，且 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 继续记录 runtime helper blocker。
    - [ ] emitter/output：audit=`blocked_category_emitter_output=native_hosted_emitter_handoff:status=rejected,reason=pending_core_bodies,backend=machine,link_plan=complete`；gate=`bash tests/verify_mir_c99_emitter_unit_output.sh` + `bash tests/verify_mir_c99_split_build_parity.sh`；host C 证据=`bash tests/verify_mir_c99_split_build_parity.sh` 的 multi-file case 与 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 的 candidate 编译运行。
    - [ ] link/absence：audit=`blocked_category_link_absence=native_hosted_executable_writer_preflight:status=blocked,reason=pending_core_bodies,output_kind=machine_module,link_plan=complete`；gate=`bash tests/verify_mir_c99_global_import_parity.sh` + `bash tests/verify_mir_c99_independent_boundary.sh`；host C 证据=`bash tests/verify_mir_c99_global_import_parity.sh` 与 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`，并要求 absence 边界始终无 legacy C99 引用。
  - [ ] 收敛指标固定为“summary executable -> real compiler candidate”的状态变化、blocked category 减少和可运行 compiler smoke；不得以单个 helper body-complete 或 frontier 名变化作为完成定义。
- [ ] MIR-C99-BACKEND-SELF-BUILD-CANDIDATE：生成真实 MIR-C99 compiler candidate。
  - [ ] 默认 generator 对 `cmd/build` root 写出真实 candidate C，而不是 summary-only C；host C compiler 编译通过，并运行最小 `cmd/build --help` / smoke 证明它是 compiler binary。
  - [ ] MIR-C99-built compiler 复跑 `cmd/build` self-build。
  - [ ] MIR-C99-built compiler 复跑 compiler regression、C99 output parity 和 full-language backend parity。
  - [ ] absence gate 确认整个自举过程中未调用现有 AST C99 backend 作为 MIR-C99 成功路径。

### 4.17 Release Gates

- [ ] MIR-C99-BACKEND-RELEASE-GATES：收口和文档同步。
  - [ ] `make check` / `make check-hosted` 增加 MIR-C99 可选或必选门禁，按阶段切换。
  - [ ] release flow 区分现有 C99 oracle、MIR-C99 backend 和 microapp profile 结论。
  - [ ] backup flow 保留现有 C99 seed，新增 MIR-C99 seed 只在自举稳定后进入。
  - [ ] 文档同步：`docs/compiler_1s_architecture_design.md`、`docs/portable_mir_whitepaper.md`、`docs/coreir_lowered_program_whitepaper.md`、`docs/portable_mir_language_coverage.md`。

---

## 5. 评审结论

本 TODO 按当前目标评审后，固定以下裁定：

- `MIR-C99-BACKEND-CONTRACTS` 已归档；当前第一叶子是 `MIR-C99-BACKEND-SELF-BUILD-RESET` 的 convergence audit，不是继续 helper frontier 或直接做 HelloWorld。
- `native_build_type_named_equals` frontier contract 已降级为历史回归边界；它只能用于 no-silent-fallback 观察和通用能力归类，不能再作为 stage gate 或下一轮 helper 指针。
- HelloWorld 是第一个端到端 parity 目标，但必须在独立边界、最小 C99 子集和 oracle harness 落地后执行。
- async frame 属于完整 Uya 语法支持范围，不能作为 MIR-C99 首版长期 reject。
- 任何以现有 C99 emitter 成功、fixed-shape smoke 成功或 self-build helper 成功为证据的条目都不得标成 `[x]`。
- `docs/todo_compiler_1s.md` 只保留上层里程碑；本文件是 MIR-C99 后端的细粒度状态来源。
