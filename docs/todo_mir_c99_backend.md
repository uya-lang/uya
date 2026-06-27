# MIR-C99 Backend TODO

**状态**: executable TODO, full-language gaps reopened, no active leaf
**更新日期**: 2026-06-23
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

- `src/codegen/mir_c99/` 已存在，并已建立 `MirC99Plan` / `MirC99Unit` / `MirC99Emitter`
  / driver / unit output 等独立后端结构；它仍是 partial，不能等同于完整语言 emitter 完成。
- `src/lower/mir_backend.uya` 已保留 `MIR_TARGET_BACKEND_C99` 和
  `MIR_BACKEND_OUTPUT_MIR_C99_PLAN` 接线；`--mir-c99` CLI 已能走真实
  `PortableMIR -> MirC99Plan -> mir_c99_unit_output` 子集路径。
- 当前 full-language 口径下仍是 partial：`examples/HelloWorld.uya` 可端到端通过；
  `src/main.uya` 仍 fail-closed 于 `MIR-C99 PortableMIR lowering 尚未覆盖当前程序`；
  `tests/extern_function.uya` 当前失败于 `MIR-C99 unit output 写出失败`。
- `tests/verify_full_language_backend_parity.sh` / `UYA_FULL_LANGUAGE_PARITY_NATIVE=1`
  的 18 case 通过只证明 hosted native / PortableMIR parity，不是 `--mir-c99` 全语言完成证据。
- `tests/mir_c99_generate.sh` 中的 fixture/parser-style generator 只能作为 staged subset
  或 self-build smoke 证据，不得替代真实 `--mir-c99` CLI 全语言 lowering。

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
- `verify_full_language_backend_parity.sh` 的 hosted native 成功，除非同一 case 还通过
  `--mir-c99` 生成 `.c`、host C99 compiler 编译运行并与 oracle 对齐。
- `tests/mir_c99_generate.sh` 里按源码字符串/fixture 名识别出的 smoke 成功。

---

## 3. 执行规则

- 每次只把一个叶子标成 `[~]`；完成后补验证命令和结果，再标 `[x]`。
- 每个实现叶子先补合同或 parity/reject 测试，再改 generic lowering 或 MIR-C99 backend。
- 新增语言面必须先更新覆盖矩阵或 MIR-C99 per-kind 状态，不能只加单个 smoke。
- self-build frontier 必须归因到通用语言结构：CFG、place/memory、call ABI、cleanup/error、runtime capability 或 MIR instruction coverage。
- self-build stage gate 只能检查 no-silent-fallback 和通用能力类别，不得把下一轮绑定到具体 helper 名、固定 body shape 或“下一处 pending body”。
- `make backup-all` 只放到阶段收口或发布前；普通叶子优先跑 focused gate、coverage verifier、`git diff --check`。
- backup flow 保留现有 C99 seed，新增 MIR-C99 seed 只在自举稳定后进入。
- `./bin/uya test` 默认仍走现有 AST/LoweredProgram C99 后端，只能作为 legacy/oracle 回归信号；MIR-C99 `done` 必须使用 `tests/verify_mir_c99_*` parity gate 或配置了 `MIR_C99_GENERATE_CMD` 的 oracle parity harness，并由 host C compiler 编译运行生成的 MIR-C99 `.c`。
- `bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 必须随 MIR-C99 TODO 状态更新一起运行，防止把 legacy C99 测试误记为 MIR-C99 验收证据。
- 自动循环执行时优先使用 `loop.py` 提供的目标行号、父级 checkbox 和小范围摘录；只在需要确认上下文时读取附近行，避免打印整份历史 todo 或 `loop.log`。
- 新增完成记录保持短证据：写清真实命令、通过/失败结论和必要关键错误即可；长日志、重复的 pre-commit 失败和临时路径只保留最小复现信息，避免把完整输出粘贴进本文件。
- 失败项必须保留可恢复线索：日期、阻塞命令、关键错误和后续重开条件；但不把无关构建噪声作为长期上下文。

---

## 4. 任务清单

已完成 `[x]` 项已移至 `docs/todo_mir_c99_backend_completed.md`；失败 `[f]` 项已移至
`docs/todo_mir_c99_backend_failed.md`；本文件只保留 full-language 口径下仍未完成的待办 `[ ]`、
进行中 `[~]` 和执行规则。当前只重开待办，不标 active leaf。

归档索引仅用于定位历史能力，完整验证证据以归档文件为准：

- PortableMIR type/layout metadata；标量 type kind；array / slice type kind；struct / union / enum field layout metadata；error union layout metadata；function type / function pointer type metadata。
- 整数一元、逻辑、非 i32 算术/比较 opcode；bool 组合 opcode；conversion opcode；f32/f64 算术、比较、常量和 return/call value verifier 规则。
- local/global/param address opcode；field address / load / store opcode；array index address / load / store opcode；slice ptr / len / index address opcode；pointer offset opcode；aggregate copy / move opcode。
- direct call、extern call、method/monomorphized call、function pointer call；global scalar / aggregate initializer、string constants、dedupe id 和 section/linkage metadata；extern globals、C import object/link inputs、symbol visibility 和 target profile metadata；split-C 多 unit 所需的 cross-unit symbol/export/import/ref metadata。
- cleanup edge、drop opcode 和 unwind/error path metadata；error union success/failure CFG；async frame metadata：state tag、result slot、await child slot、captured locals、poll/resume edge、frame allocation/free capability；async frame struct layout、state tag、result slot、await child slot 和 captured locals；poll/resume state machine 的低级 C label/goto；await bind direct await loop await；async frame pool 和 `--async-frame-heap=on` fallback；async error union return、cleanup edge、defer/errdefer 与 frame release。
- SIMD vector/mask load/store/splat/select opcode；SIMD 首版 reject；atomic init/load/store/RMW/CMPXCHG opcode；atomic 首版 reject；host C compiler oracle parity；tests/test_async_*.uya。
- basic async full-language parity；control-flow async parity；frame/pool async parity；scheduler/channel/IO/compute async parity；async cleanup/resource full-language parity。

### 4.15 Full Language Parity

- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE`: 让真实 `--mir-c99` CLI 在主语言测试集上收敛。
  - 当前基线（2026-06-24）：将当前仓库现成 full `bin/cmd/build` 同步到 sibling
    `../uya/bin/cmd/build` 后，fixed `../uya/bin/uya -> build_bootstrap -> current-source
    cmd/build` 的真实 build CLI 入口已恢复；`examples/HelloWorld.uya --mir-c99` 当前已显示
    `[MIR-C99]` 和 `generated by MIR-C99 unit output writer`。本轮真实 blocker 改为：
    mandated `../uya/bin/uya` / `build_bootstrap` / `make -B cmd-build
    UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya` 目前都无法成功重建 current-source
    `cmd/build` 并同步回 sibling `../uya/bin/cmd/build`，详见失败归档中的
    `MIR-C99-FULL-SUPPORT-CLI-SUITE-SRC-MAIN-DISTINCT-OUTPUTS`。
  - [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`: 让主语言面 `--mir-c99` 回归收敛，
    失败项只剩具体 capability diagnostic，并逐项归零。
    - 当前基线（2026-06-24，本轮）：`tests/run_programs_parallel.sh` 已修复相对
      `UYA_COMPILER` 路径解析；`UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8
      CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS=''
      ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass` 现已进入真实 MIR-C99
      失败面，不再停在 `line 497: ../uya/bin/uya: No such file or directory`。
    - 当前自动化备注（2026-06-24，本轮）：若 stdout 非 TTY，需设
      `UYA_TEST_STDOUT_LINEBUF=1`，否则 `tests/run_programs_parallel.sh` 会自包装
      `stdbuf`，把真实 MIR-C99 失败面打成空输出 `编译失败(退出码:139)`；下列
      failure matrix 以关闭该包装后的结果为准。
    - 本轮真实重计数（2026-06-24，本轮最终复核）：`1024` 项中 `155` 通过、`869` 失败。
    - 顶层失败项口径下，`859` 个编译失败中已有 `849` 个显式收敛为具体 `kind/reason`
      capability diagnostic，仅剩 `7` 个
      `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序` 与 `3` 个
      `PortableMIR verifier 失败`；generic `错误: MIR-C99 extern lowering 失败`
      已清零。
    - 其余 `10` 个为非编译失败：`2` 个链接失败、`6` 个单文件运行失败、`2` 个
      `multifile/cross_deps` 聚合失败；其中聚合子用例仍保留 `4` 个 generic lowering
      和 `1` 个 `unit output 写出失败`，尚未计入顶层 `859` 个编译失败。
    - 已出现的具体 capability diagnostic（共 `849` 个）：`589` 个
      `AST_FN_DECL / extern_signature_requires_i32_scalars`、`142` 个
      `AST_TEST_STMT / test_driver_not_lowered`、`48` 个
      `AST_TYPE_VECTOR / vector_type_requires_target_helper_capability`、`15` 个
      `AST_ASM / inline_asm_requires_target_capability`、`9` 个
      `AST_MC_SOURCE / mc_source_requires_compile_time_macro_capability`、`7` 个
      `AST_MATCH_EXPR / match_expr_requires_expr_value_place`、`7` 个
      `AST_FN_DECL / extern_varargs_requires_c_variadic_capability`、`7` 个
      `AST_CATCH_EXPR / catch_return_not_lowered`、`5` 个
      `AST_MC_CODE / mc_code_requires_compile_time_macro_capability`、`4` 个
      `AST_STRING_INTERP / string_interp_requires_expr_value_place`、`4` 个
      `AST_MC_TYPE / mc_type_requires_compile_time_macro_capability`、`2` 个
      `AST_USIZE_FROM_PTR / usize_from_ptr_requires_target_capability`、`2` 个
      `AST_PARAMS / params_tuple_requires_expr_value_place`、`2` 个
      `AST_MC_INTERP / mc_interp_requires_compile_time_macro_capability`、`1` 个
      `AST_SYSCALL / syscall_requires_target_capability`、`1` 个
      `AST_PTR_FROM_USIZE / ptr_from_usize_requires_target_capability`、`1` 个
      `AST_INT_LIMIT / int_limit_requires_expr_value_place`、`1` 个
      `AST_FOR_STMT / for_driver_not_lowered`、`1` 个
      `AST_EMBED / embed_requires_compile_time_embed_capability`、`1` 个
      `AST_ASM_TARGET / asm_target_requires_target_capability`。
    - 进展（2026-06-24，本轮收口）：`tests/test_asm_const_output.uya` 已从
      `AST_TEST_STMT / test_driver_not_lowered` 收敛到
      `AST_ASM / inline_asm_requires_target_capability`。
    - 进展（2026-06-24，本轮收口）：`tests/test_simd_c99_select_emit_u32x2_and_u32x4.uya`
      已从 generic `PortableMIR lowering 尚未覆盖当前程序` 收敛到
      `AST_TYPE_VECTOR / vector_type_requires_target_helper_capability`
      （`line=2`），focused gate=
      `bash tests/verify_mir_c99_full_language_simd_select_first_bucket.sh`。
    - 进展（2026-06-24，本轮收口）：`tests/test_https_google.uya` 已从 generic
      `extern lowering 失败` 收敛到
      `AST_FN_DECL / extern_signature_requires_i32_scalars`
      （`lib/libc/errno.uya:145`），focused gate=
      `bash tests/verify_mir_c99_full_language_extern_signature_capability_reject.sh`。
    - 进展（2026-06-24，本轮收口）：顶层 `7` 个 generic
      `PortableMIR lowering 尚未覆盖当前程序` 已全部收敛为具体 capability
      diagnostic：`tests/test_cfg_target.uya` /
      `tests/test_exec_vm_const_pool.uya` -> `AST_BINARY_EXPR /
      binary_expr_requires_general_expr_lowering`；
      `tests/test_exec_vm_defer.uya` /
      `tests/test_exec_vm_hir_scope.uya` /
      `tests/test_exec_vm_local_load_store.uya` -> `AST_CALL_EXPR /
      call_expr_requires_call_lowering`；
      `tests/test_exec_vm_drop_local.uya` -> `AST_ASSIGN /
      assign_dest_requires_local_i32_binding`；
      `tests/test_struct_array_field_typed_empty_init.uya` ->
      `AST_VAR_DECL / local_decl_requires_i32_scalar_storage`。顶层剩余 block
      现仅为 `3` 个 `PortableMIR verifier 失败`；generic block 仍仅见于
      `multifile/cross_deps` 聚合子用例。
    - 验收：
      - `UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror'
        LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass` 主语言面通过。
      - 失败项必须归档为具体 language kind / capability diagnostic。
    - 本轮拆分（2026-06-24）：
      - 进展（2026-06-24，本轮）：`make -B cmd-build
        UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya` 已成功重建 current-source
        `bin/cmd/build`，并同步 sibling `../uya/bin/cmd/build`；`tests/test_mem_allocator.uya`、
        `tests/test_ffi_cast.uya`、`tests/extern_ffi_no_struct.uya` 已不再命中
        `extern_signature_requires_i32_scalars`。
      - 进展（2026-06-24，本轮）：`tests/test_mem_allocator.uya` 现前移到
        `AST_TEST_STMT / test_driver_not_lowered`；`tests/test_ffi_cast.uya` 与
        `tests/extern_ffi_no_struct.uya` 现前移到 `PortableMIR verifier 失败: code=16`；
        `tests/test_simple_fn.uya` 也已不再卡在 `lib/std/runtime/entry/entry.uya:79` 的
        extern-signature 旧边界。
      - 进展（2026-06-24，本轮）：`tests/test_async_return_value.uya`、
        `tests/test_syscall_time.uya`、`tests/test_https_google.uya` 已不再卡在
        `lib/libc/pthread.uya:1018` (`pthread_self() -> pthread_t`) 或
        `lib/libc/syscall.uya` 的 `!i32/!i64` extern-signature 旧边界，real CLI
        现统一前移到 `lib/libc/stdio.uya:882` 的
        `extern_varargs_requires_c_variadic_capability`。
      - 进展（2026-06-24，本轮）：`tests/test_simple_fn.uya` 现从 generic
        `PortableMIR verifier 失败: code=16` 收敛到
        `AST_FN_DECL / entry_extern_main_requires_runtime_bridge`
        （`lib/std/runtime/entry/entry.uya:79`），focused gate=
        `bash tests/verify_mir_c99_full_language_entry_extern_body_boundary.sh`。
      - 进展（2026-06-24，本轮收口）：real CLI 主语言面 matrix
        `总计: 1024 / 通过: 156 / 失败: 868`；按 summary failure 重计后，
        `extern_signature_requires_i32_scalars` 已下降到 `2`
        （`tests/test_extern_union.uya:10`、
        `tests/test_slice_param_c99_emit.uya:5`），新 top buckets 为
        `entry_extern_main_requires_runtime_bridge=365`、
        `extern_varargs_requires_c_variadic_capability=209`、
        `test_driver_not_lowered=149`、
        `vector_type_requires_target_helper_capability=48`、
        `inline_asm_requires_target_capability=15`。
      - 本轮拆分（2026-06-24，本轮续做）：
        - 进展（2026-06-24，本轮）：`MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-EXTERN-SIGNATURE-UNION-SLICE-TAIL`
          已完成并归档；`tests/test_extern_union.uya` 已从 generic
          `extern_signature_requires_i32_scalars` 前移到
          `错误: MIR-C99 PortableMIR verifier 失败: code=16`，`tests/test_slice_param_c99_emit.uya`
          已前移到
          `mir_c99_capability_diagnostic: kind=AST_TEST_STMT reason=test_driver_not_lowered file=tests/test_slice_param_c99_emit.uya line=19`。
      - 进展（2026-06-28，本轮）：`MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-VARARGS-CAPABILITY-BASELINE`
        已完成并归档；未 materialize 的 libc variadic extern 声明不再抢占全程序 MIR-C99
        frontier。该轮 `src/main.uya --mir-c99` 前移到
        `AST_USIZE_FROM_PTR / usize_from_ptr_requires_target_capability`，
        `tests/test_https_google.uya --mir-c99` 前移到
        `AST_CATCH_EXPR / catch_return_not_lowered`。
      - 当前前沿（2026-06-28，本轮）：`src/main.uya --mir-c99` 已前移到
        `AST_CALL_EXPR / call_expr_requires_call_lowering`（`src/main.uya:218`）；
        direct `@usize_from_ptr` 仍由
        `bash tests/verify_mir_c99_full_language_direct_builtin_capability_reject.sh`
        保持 fail-closed。
  - [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE-HYGIENE-GATES`: 保持 TODO/oracle 证据约束和
    generator 前提 gate 与真实 CLI 结论一致。
    - 验收：
      - `bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 通过。
      - `bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过。
  - 验收：
    - `bash tests/verify_mir_c99_cli_helloworld.sh` 通过。
    - `bash tests/verify_mir_c99_cli_distinct_outputs.sh` 通过，且 `src/main.uya` 输出不是
      legacy C99，也不是 HelloWorld-like 固定输出。
    - `UYA_COMPILER=../uya/bin/uya PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror'
      LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass` 主语言面通过；
      失败项必须归档为具体 language kind / capability diagnostic。
    - `bash tests/verify_mir_c99_todo_no_legacy_test_evidence.sh` 和
      `bash tests/verify_mir_c99_oracle_parity_requires_generators.sh` 通过。

### 4.16 Self Build

路线复盘（2026-06-14）：

- 当前 `cmd/build` MIR-C99 preflight 已切到 real compiler candidate：默认 generator 对该 root 走 `mir_c99_unit_output`，写出带 `generated by MIR-C99 unit output writer` 标记和 `uya_mir_func_` 符号的候选 C，并经 host C compiler 编译后通过 `cmd/build --help` smoke；它仍是最小 smoke 候选，不代表 MIR-C99-built compiler 已能完成真实 self-build / regression / parity。
- 当前 parity frontier（2026-06-15）：candidate 已从 `--help` smoke 前进到 `return_literal_c99_output_parity` + `generic_identity_outparam_stack_parse_array_smoke` + `branch_loop_array_slice_struct_tuple_enum_union_generic_gfunction_method_interface_icomposition_ginterface_float_error_binding_defer_errdefer_try_pointer_multifile_smoke`，可接受最小 `build <input.uya> -o <output>`，解析 literal return、generic identity 常量返回、local array out-param 写回、stack-limit helper call smoke、parse-like 多 out-param 写回、local array index read、full-language branch/loop smoke、full-language array write/default smoke、full-language slice len/index smoke、full-language struct field smoke、full-language tuple member smoke、full-language enum match/cast smoke、full-language union match/tagged payload smoke、full-language generic struct instance smoke、full-language generic function instance smoke、full-language generic method instance smoke、full-language interface dispatch smoke、full-language interface composition/field/global init smoke、full-language generic interface instance smoke、full-language float/double value smoke、full-language error catch success/error smoke、full-language catch error binding/error-id smoke、full-language defer normal-scope return-order smoke、full-language errdefer success/error cleanup smoke、full-language try propagation success/error smoke、full-language pointer load/store/address smoke 和 full-language multi-file use/alias use smoke，产出可运行程序，并与现有 C99 oracle 的 stdout/stderr/exit code 对齐；不得作为完整 parity 完成证据。
- 继续逐个 `pending_core_bodies` / `native_build_*` helper 做 body-complete 会持续前移 handoff frontier，却不能证明 `MirC99Plan`、真实 C emitter、runtime capability、call ABI、link/output 和 absence gate 在收敛；下一步必须转向 MIR-C99-built compiler self-build、compiler regression / parity，以及 absence gate。
- 冻结当前 frontier 样本：`native_build_type_named_equals` / `generic_corebody_type_named_equals_body_lowering` 只保留为诊断上下文，不再作为 active leaf。
- 4.16 后续禁止新增只按 helper 名、固定 statement count、固定 body shape 或“下一处 pending body”推进的任务；每个 self-build 叶子必须绑定到通用能力类别、可量化收敛指标和端到端 host C 证据。

helper-frontier 历史回归边界（2026-06-14，非 4.16 active path）：

- 归档样本固定为 `native_build_type_named_equals` / `generic_corebody_type_named_equals_body_lowering`；它们只用于保留“summary frontier 曾阻塞在 helper lowering”这一历史事实，不再定义下一轮任务顺序。
- stage gate 只允许检查两类事实：`cmd/build` MIR-C99 路线没有静默 fallback/静默成功，以及当前阻塞 helper 能被归入 CFG、place/memory、call ABI、aggregate/layout、cleanup/error、runtime helper、emitter/output、link/absence 等通用能力类别。
- stage gate 不得要求继续完成 `native_build_type_named_equals`、枚举下一个 `pending_core_bodies` helper，或用 helper 名、body shape、statement count 变化来定义进展。
- 当前基线：`bash tests/verify_mir_c99_self_build_convergence_audit.sh` + `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 固定 `self_build_convergence_status=real_compiler_candidate`、`host_compiler_binary_candidate_role=compiler_binary`、`blocked_category_count=4`；后续只允许围绕这些指标下降或 MIR-C99 backend 替代 tracked cmd/build seed 过渡源推进。

- [ ] `MIR-C99-FULL-SUPPORT-SELF-BUILD-REAL-COMPILER`: 将当前 `cmd/build --help` smoke 和
  fixture parser-style candidate 提升为真实 MIR-C99-built compiler 自举证据。
  - 验收：MIR-C99-built `cmd/build` 能编译指定 Uya 输入并产出可运行程序；随后逐步复跑
    compiler regression、C99 output parity 和 full-language backend parity。不得用
    `tests/mir_c99_generate.sh` 的源码字符串解析器替代真实 compiler。

- [ ] `MIR-C99-FULL-SUPPORT-SELF-BUILD-ABSENCE-GATE`: 建立 absence gate，证明 self-build
  不再依赖 legacy C99 emitter、fixed-shape summary executable 或 helper-frontier smoke。
  - 验收：self-build 日志中无 legacy C99 banner，无 `writer_status=pending` /
    summary-only candidate；`blocked_category_count` 收敛到 0，或剩余项全部是明确
    capability/release-gate reject。


### 4.17 Release Gates

当前 release gate、文档同步和 HelloWorld CLI 证据已移至
`docs/todo_mir_c99_backend_completed.md`；但按 full-language 口径仍需重新打开以下 release
叶子。

- [ ] `MIR-C99-FULL-SUPPORT-RELEASE-GATES`: 在真实 CLI 全语言通过后，把 MIR-C99 纳入
  release 级门禁。
  - 验收：`make check` / `make check-hosted` 增加 MIR-C99 可选或必选门禁，按阶段切换；
    release 报告分别记录现有 C99 oracle、MIR-C99 backend、microapp profile 的结论，不互相折算。

- [ ] `MIR-C99-FULL-SUPPORT-DOC-SYNC`: 同步覆盖矩阵和 TODO/archive，消除 partial/done
  口径漂移。
  - 验收：`docs/portable_mir_language_coverage.md` 的 MIR-C99 状态列不再把 native parity
    或 generator-only smoke 写成 full-language done；`docs/todo_mir_c99_backend_failed.md`
    明确 `verify_full_language_backend_parity.sh` 是 hosted native 证据；`git diff --check`
    和 `bash tests/verify_portable_mir_language_coverage.sh` 通过。



---

## 5. 评审结论

本 TODO 按当前目标评审后，固定以下裁定：

- `MIR-C99-BACKEND-CONTRACTS` 已归档；当前第一叶子是 `MIR-C99-BACKEND-SELF-BUILD-RESET` 的 convergence audit，不是继续 helper frontier 或直接做 HelloWorld。
- `native_build_type_named_equals` frontier contract 已降级为历史回归边界；它只能用于 no-silent-fallback 观察和通用能力归类，不能再作为 stage gate 或下一轮 helper 指针。
- HelloWorld 是第一个端到端 parity 目标，但必须在独立边界、最小 C99 子集和 oracle harness 落地后执行。
- async frame 属于完整 Uya 语法支持范围，不能作为 MIR-C99 首版长期 reject。
- 任何以现有 C99 emitter 成功、fixed-shape smoke 成功或 self-build helper 成功为证据的条目都不得标成 `[x]`。
- generic CoreBody / PortableMIR 迁移期间禁止新增 one-off materializer。
  禁止：为了让单个 case 变绿继续新增 helper 名；应优先把缺口建模为通用
  CoreStmt/CoreExpr/CorePlace lowering、verifier 或 emitter 能力。
- 按 full-language 口径，`docs/todo_mir_c99_backend.md` 当前重新打开的主线不是
  “继续追加更多 fixture smoke”，而是让真实 `--mir-c99` CLI 覆盖普通 Uya 程序、测试
  harness、self-build 和 release gate。
- `docs/todo_compiler_1s.md` 只保留上层里程碑；本文件是 MIR-C99 后端的细粒度状态来源。
