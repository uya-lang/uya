# MIR-C99 Backend TODO

**状态**: executable TODO, implementation pending
**更新日期**: 2026-06-13
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

- [ ] MIR-C99-BACKEND-SELF-BUILD：编译器自举走 MIR-C99。
  - [ ] host C compiler 编译 MIR-C99 产物得到 compiler binary。
    - [ ] 逐步清空 `pending_core_bodies` frontier，直到默认 MIR-C99 generator 对 `cmd/build` root 输出真实 compiler candidate C。
      - [ ] 将 `build_driver_run` split_c_default frontier 纳入 CoreBody -> PortableMIR lowering，并复验 cmd/build summary frontier 前移。
    - [ ] host C compiler 编译真实 MIR-C99 compiler candidate，并运行最小 `cmd/build --help` / smoke 证明它是 compiler binary 而非 summary executable。
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

- 当前第一叶子是 `MIR-C99-BACKEND-CONTRACTS`，不是 HelloWorld 实现。
- HelloWorld 是第一个端到端 parity 目标，但必须在独立边界、最小 C99 子集和 oracle harness 落地后执行。
- async frame 属于完整 Uya 语法支持范围，不能作为 MIR-C99 首版长期 reject。
- 任何以现有 C99 emitter 成功、fixed-shape smoke 成功或 self-build helper 成功为证据的条目都不得标成 `[x]`。
- `docs/todo_compiler_1s.md` 只保留上层里程碑；本文件是 MIR-C99 后端的细粒度状态来源。
