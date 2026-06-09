# Native `cmd/build` 子集清单

**状态**: Phase 10 feature inventory，PortableMIR 前冻结
**更新日期**: 2026-06-09
**范围**: 统计把 `src/cmd/build/main.uya` 变成 freestanding native build-seed compiler 所需的语言、运行时和宿主能力。

## Evidence Snapshot

当前实测依赖数: 88

测量命令:

```bash
UYA_ROOT="$PWD" ./bin/uya build src/cmd/build/main.uya \
  -o /tmp/cmd-build --no-split-c --project-root "$PWD/src/"
```

当前 root:

- `src/cmd/build/main.uya`
- `src/build_compiler_driver.uya`
- `src/checker_build/*.uya`
- `src/codegen/c99_build/*.uya`

当前 build-only root 明确不包含 `exec`、`uya microapp build/pack/inspect/verify/run`、`fmt`、`upm`、kernel packaging 和完整
`checker` / `codegen.c99` 路径。Phase 10 的 native 子集只面向 freestanding `cmd/build` seed，不定义完整
native 后端主线；完整语言 native parity 转由 `PortableMIR` + hosted native 路线承接。

## Feature Inventory

| ID | 类别 | `cmd/build` 需要的 feature | 主要证据 |
|----|------|----------------------------|----------|
| F01 | CLI / process entry | `argc/argv` 读取、`build` 子命令兼容、`-o`、`--project-root`、`--no-split-c`、`--nostdlib`、环境变量读取、退出码 | `src/cmd/build/main.uya`、`parse_build_args`、`get_argc/get_argv/getenv` |
| F02 | Source / module IO | 读取源码文件、目录输入、模块依赖收集、路径拼接、去重、entry 自动注入、`@c_import` sidecar 路径 | `compile_files`、`collect_module_dependencies`、`dedupe_paths_in_place`、`CImportPlan` |
| F03 | Lexer / parser / AST | 编译器源码需要的声明、表达式、语句、类型、宏、属性、AST merge | `src/lexer.uya`、`src/parser/*.uya`、`src/ast.uya` |
| F04 | Semantic / typed program | 名称解析、模块绑定、导出查找、类型记录、typed program 生命周期、SemanticDb 动态索引 | `src/semantic/*.uya`、`src/typed/*.uya`、`compile_stats_record_and_release_typed_program` |
| F05 | Checker / safety proof | build-only checker、函数/方法调用检查、类型布局、bounds/proof、diagnostic 延迟格式化 | `src/checker_build/*.uya` |
| F06 | 复合类型 | struct、enum、union、error union、数组、slice、指针、函数类型、接口字段 | parser/checker/codegen build 源码和 `checker_build/type_layout.uya` |
| F07 | 控制流和错误处理 | `if`、`while`、`for`、提前返回、`try`、`catch`、`defer`、`errdefer`、错误传播 | compiler driver、checker、C99 backend 主路径 |
| F08 | 泛型 / 方法 / 接口 | 泛型实例、方法块、接口/vtable 相关类型检查、标准库泛型容器用法 | `checker_build/generics.uya`、`typed/program.uya`、`lib/std/*` |
| F09 | 动态表 | reserve/append/grow/reset/release、item pointer、capacity/bytes/realloc 统计 | `SemanticVector`、`semantic_table_agg_*`、TypedProgram tables |
| F10 | intern / hash / string | interned names、字符串比较、前缀/后缀、路径字符串、符号名稳定化 | `src/semantic/ids.uya`、`src/str_utils.uya`、`lib/libc/string.uya` |
| F11 | 内存管理 | `CompilerArena` 动态 chunk、heap fallback、`malloc/free`、`memcpy/memset`、指针对齐 | `src/arena.uya`、`lib/libc/heap.uya`、`lib/libc/mem.uya` |
| F12 | diagnostics / formatting | `fprintf`、`snprintf`、`printf` 风格格式化、stderr 输出、源码位置、profile 计数 | `compiler_print_diagnostic_profile`、parser/checker diagnostics |
| F13 | C99 build backend | C99 类型/表达式/语句/函数/全局/struct emission、split-C、输出缓冲峰值、host C 输出 | `src/codegen/c99_build/*.uya` |
| F14 | Host toolchain / filesystem | 临时路径、打开/写入/关闭文件、目录创建、调用 host C compiler/linker、shell 命令 | `src/driver/toolchain.uya`、`lib/libc/stdio.uya`、`lib/libc/unistd.uya` |
| F15 | Metrics / benchmark | `output_bytes`、arena peak、typed program peak/release、table stats、C99 output buffer peak | `CompileStats`、`scripts/bench_compiler_1s.sh` |
| F16 | 显式非需求 | VM/exec backend、`uya microapp build/pack/inspect/verify/run`、fmt/upm、kernel packaging、完整 interactive CLI | build seed boundary、`docs/build_compiler_seed_design.md` |

## Dependency Shape

当前 83 个依赖文件落在这些边界内：

- build entry / driver: `src/cmd/build/main.uya`、`src/build_compiler_driver.uya`
- frontend: `arena`、`ast`、`lexer`、`parser`、`extern_decls`、`str_utils`、`std_cfg`
- semantic / typed / checker: `src/semantic/*.uya`、`src/typed/*.uya`、`src/checker_build/*.uya`
- backend: `src/codegen/c99_build/*.uya`、`src/codegen/native_build/main.uya`、`src/codegen/native/machine.uya`
- driver/runtime/libc: `src/driver/*.uya`、`lib/libc/*.uya`、`lib/std/runtime/*.uya`、`lib/std/platform.uya`

## Native Support Status

状态含义：

- `done`: Phase 9 native v1 已有可执行验证，且满足该 feature 对 `cmd/build` 的最低需求。
- `partial`: 已有底层编码、布局或 smoke，但还不足以支撑 native-built `cmd/build`。
- `missing`: 仍缺少 native lowering/runtime 能力，不能用于 native-built `cmd/build`。
- `not_required`: `cmd/build` native 子集明确不需要。

| ID | native 状态 | 依据 | 后续门槛 |
|----|-------------|------|----------|
| F01 | partial | 已有 nostdlib `_start`、syscall bridge 和最小 executable；build-only native writer 已从 Linux 初始栈读取 `argc` 和 `argv` 基址，支持 `get_argc()` 与 `get_argv(1)[0]` 最小 lowering；仍缺完整 `argv` 字符串操作、环境变量和完整 CLI runtime 接入 | native 程序入口传递 argv/env，并接入 build 参数解析 |
| F02 | partial | `tests/test_native_file_io.uya` 覆盖基于 `sys_open/sys_read/sys_close` 的 growable read-all buffer；尚无目录/stat/module dependency runtime | 将最小读取接入 parser 输入，并补齐路径、stat 与模块依赖收集 |
| F03 | missing | parser/lexer/AST 源码仍只能经 C99-built compiler 运行 | native lowering 能执行 lexer/parser/AST merge |
| F04 | missing | SemanticDb/TypedProgram 仍无 native-lowered 执行路径 | native lowering 支持 SemanticDb 和 typed tables |
| F05 | missing | `checker_build` 仍无 native-lowered 执行路径 | native lowering 支持 checker/proof 主路径 |
| F06 | partial | 已有 struct field、error union、global init smoke；`tests/test_native_struct_array_slice_ops.uya` 覆盖 parser/checker 常用 struct field、array element、slice ptr/len 和 x86_64 indexed addressing | 把这些 aggregate 操作接入 native-lowered compiler path，并继续补 enum/union/interface 复合类型 |
| F07 | partial | 已有 function call 和 error union smoke；`tests/test_native_error_defer_control.uya` 覆盖 success/error 退出路径下 defer/errdefer 的动态 cleanup plan 与 LIFO 展开；分支、循环和完整 statement lowering 仍未接入 | 控制流、错误传播和 defer lowering 可跑 compiler 子集 |
| F08 | partial | `tests/test_native_generic_instances.uya` 覆盖泛型函数/结构/方法实例 registry、动态 worklist、稳定实例符号名、类型参数绑定替换和超过旧 512 mono 实例容量的增长；方法/接口/vtable lowering 仍未接入 | 方法/接口调用和 vtable 生成可跑 compiler 子集 |
| F09 | partial | native IR/data/reloc/string 动态表已验证；`tests/test_native_dynamic_table_ops.uya` 覆盖 reserve/append/grow/reset/release 和 >1024 项增长；compiler 运行时 `SemanticVector` 尚未接入 native-lowered path | reserve/append/grow/free 在 native-built compiler 下可用，并与 SemanticVector/TypedProgram 表接线 |
| F10 | partial | `tests/test_native_hash_intern_memory_ops.uya` 覆盖 i64 hash entry、intern entry、FNV hash、byte compare 和开放寻址 probe/update；`tests/test_native_memory_string_primitives.uya` 覆盖 `strlen`/`strcmp` 最小 native primitive；完整字符串/libc bridge 仍未 native 化 | 把 hash/intern 操作和字符串 primitive 接入 native-lowered compiler path，并补齐剩余字符串运行时 bridge |
| F11 | partial | `tests/test_native_malloc_arena.uya` 覆盖 malloc/realloc/free facade、静态 buffer arena、动态 chunk 增长、reset/release；`tests/test_native_memory_string_primitives.uya` 覆盖 `memcpy`/`memset` 最小 native primitive | native malloc/arena/memory primitives 接入 compiler tables，并补齐剩余 libc memory primitives |
| F12 | partial | `tests/test_native_diagnostic_output.uya` 覆盖 diagnostics growable byte buffer；`tests/test_native_format_minimal.uya` 覆盖 `%s/%d/%u/%ld/%zu/%%` 最小 `snprintf` 替代与截断语义；完整 `fprintf`/stderr bridge 仍未 native 化 | 将 buffer/formatter 接入 parser/checker diagnostic path，并补齐 stderr/file 输出 bridge |
| F13 | partial | NativeEmitter 的历史 `LoweredProgram -> MachineModule` 窄子集仍只作为 freestanding build-seed 回归边界；hosted native 主线已经转到 CoreBody/PortableMIR preflight。`tests/verify_native_build_minimal_program.sh` 继续验证无参/最多两个 `i32` 参数、单/双 out-param、`get_argc()`、`get_argv(1)[0]`、条件返回/赋值、`set_process_stack_limit_bytes(...)` syscall 和 `parse_like(...)` 11 参数写回等旧窄 executable 子集不回归；`tests/verify_native_cmd_build_compiler_regressions.sh` 用 `bin/cmd/build --native --nostdlib` 覆盖泛型 identity、local array out-param、stack-limit call 和 compiler-like parse out-param regression 组；`tests/verify_native_cmd_build_c99_output_parity.sh` 用 `bin/cmd/build` 生成 C99 output，并与 C99-built `bin/uya` oracle 做归一化输出和运行结果比对。当前 `src/cmd/build/main.uya --native` self-build 门禁不再使用 `--nostdlib` 或 `compile_files(...)` one-off 形状，而是以 hosted 路径解析/检查 89 个依赖后进入 verifier-clean CoreIR/PortableMIR preflight；实测 frontier 为 `native_hosted_entry_frontier: wrapper_covered=1 first_pending_callee=build_compiler_driver_run first_pending_callee_prefix=1 first_pending_callee_prefix_stmts=39 first_pending_callee_next_stmt=-1 first_pending_callee_next_kind=<none>`，已覆盖 `build_compiler_driver_run` 的顶层入口前缀至末尾 `return 0`，包括 `parse_build_args(...)`、输出路径选择、`compile_files(...)` result、native 成功返回、C 输出检测分支入口、链接输出分支入口和最终返回；链接输出分支内部 nested frontier 为 `native_hosted_entry_child_frontier: first_pending_callee=build_compiler_driver_run parent_stmt=37 child_prefix=1 child_prefix_stmts=7 child_next_stmt=-1 child_next_kind=<none>`，已覆盖 `const c_file: &byte = artifacts.generated_c_path`、`var output: &byte = "a.out" as *byte`、`if user_output_path != null` 条件入口、`const link_result: i32 = link_with_toolchain(...)` 初始化、`if link_result != 0` 错误分支条件入口、链接输出分支内部成功 `fprintf(...)` 和 `return 0`，链接输出子块内部已无下一条 child frontier。handoff 现在固定为 `native_hosted_handoff_frontier: reason=pending_core_bodies ... entry_callee_coverage=partial_prefix entry_child_coverage=complete`，继续输出 `native_hosted_emitter_handoff: status=rejected reason=pending_core_bodies request_verified=1 backend=machine link_plan=complete ... entry_child_coverage=complete`，并通过 `native_hosted_emitter_import_preflight: status=ready imported_functions=481 imported_blocks=38 imported_insts=55 ...` 和 `native_hosted_emitter_output_preflight: status=ready output_matches_request=1 output_kind=machine_module machine_functions=481 ...` 证明 verified partial MIR 已进入 `NativeMirEmitter` import preflight 和 `MirTargetBackendOutput` payload；最终仍后接 `native_hosted_portable_mir_lowering_missing`，且不生成伪 native 输出、不回落 C99。 | hosted PortableMIR body lowering 接入真实 emitter/handoff 后，再生成 native `bin/cmd/build` |
| F14 | missing | host toolchain/file system bridge 未 native 化；只有最小 syscall encoding | native file IO 和 host C toolchain 调用路径可用 |
| F15 | partial | `tests/test_native_arena_peak_stats.uya` 覆盖 native arena peak snapshot，保留 `arena_peak_bytes` / `ast_arena_peak_bytes` / `check_arena_peak_bytes` / `emit_arena_peak_bytes` 同名字段；table/output/typed program metrics 尚未接入 native-built compiler | native-built compiler 继续输出全部同名 metrics |
| F16 | done | build seed boundary 已排除 VM/exec、`uya microapp build/pack/inspect/verify/run`、fmt/upm、kernel packaging | 后续保持边界验证，避免重新引入非需求 |

## Regression Boundary Contract

Phase 10 的 freestanding native `cmd/build` seed 只记录 build-seed 回归边界，不定义完整语言 native
主线，也不能成为 hosted native 完整语言 parity 的前置条件。

- 只有当同一语言能力已经通过 `CoreBody` / `PortableMIR` lowering、MIR verifier 和 hosted native / C99
  oracle smoke 后，才允许把该能力下沉到 freestanding build-seed。
- 历史 `LoweredProgram -> MachineModule` build-seed helper 只能保持已有成功子集和失败诊断，不再为 `compile_files(...)`
  或其它 compiler 形状新增 one-off `LoweredBodyOp`。
- hosted `build --native` 入口必须先进入 CoreIR function inventory，再进入 `PortableMIR` /
  `MirTargetBackendRequest` / `NativeHostedLinkPlan` handoff；当前已把 AST function 清单、安全 void body
  和整数字面量 return body 子集作为 verifier-clean `LoweredProgram` 预检，把 AST extern function 作为 verified `PortableMIR` extern
  function stub，把安全 void `CoreBody` 降成 verifier-clean `MirFunction` / `MirBlock` / return `MirTerminator`，并固定
  Machine backend request 和 `NativeHostedLinkPlan` preflight，同时把 AST 中的 extern
  function symbol 与 `@c_import` object 计入 hosted link plan。真正的缺口是
  `native_hosted_portable_mir_lowering_missing`，不能借用 freestanding build-seed helper。
- `cmd/build` 当前失败卡点必须继续由 `tests/verify_native_cmd_build_no_silent_c99.sh` 固定；失败时必须保留
  native backend diagnostic，不能生成伪 native 输出，也不能静默回落 C99。self-build 门禁现在走 hosted
  `CoreBody` / `PortableMIR` preflight，并要求 CoreIR 与 PortableMIR verifier-clean；当前 frontier 固定为
  `native_hosted_entry_frontier: wrapper_covered=1 first_pending_callee=build_compiler_driver_run first_pending_callee_prefix=1 first_pending_callee_prefix_stmts=39 first_pending_callee_next_stmt=-1 first_pending_callee_next_kind=<none>`、
  `native_hosted_entry_child_frontier: first_pending_callee=build_compiler_driver_run parent_stmt=37 child_prefix=1 child_prefix_stmts=7 child_next_stmt=-1 child_next_kind=<none>`、
  `native_hosted_handoff_frontier: reason=pending_core_bodies ... entry_callee_coverage=partial_prefix entry_child_coverage=complete`、
  `native_hosted_emitter_handoff: status=rejected reason=pending_core_bodies request_verified=1 backend=machine link_plan=complete ... entry_child_coverage=complete`、
  `native_hosted_emitter_import_preflight: status=ready imported_functions=481 imported_blocks=38 imported_insts=55 ...`、
  `native_hosted_emitter_output_preflight: status=ready output_matches_request=1 output_kind=machine_module machine_functions=481 ...` 和
  `native_hosted_portable_mir_lowering_missing`。
  不再把 `compile_files(...)` 16 参数缺口固定为 `--nostdlib` freestanding one-off shape。
- native `bin/cmd/build` 仍是 freestanding build-seed 里程碑，不是 hosted native 完整语言 parity 的前置条件。

## Hosted Native Handoff First Slice Contract

首个真实 handoff 切片只接受 verifier-clean `CoreBody` / `PortableMIR` body 作为输入，不得调用历史 `LoweredProgram -> MachineModule` build-seed helper，也不得从 hosted `build --native` 静默回落到 C99。

这个切片的边界是 `NativeHostedLinkPlan` / `MirTargetBackendRequest` handoff：在 `CoreBody` 和
`PortableMIR` verifier-clean 之后，把已覆盖的 hosted body、extern function symbol、`@c_import`
object 和目标 backend request 交给真实 native emitter。未实现真实 emitter 前必须继续返回 `native_hosted_portable_mir_lowering_missing`，并保留 no-output / no-silent-C99 失败语义。

## Release Acceptance Boundary

本文件只定义 Phase 10 freestanding native `cmd/build` 子集，不定义最终语言完备性或长期 native 后端主线。
发布验收仍必须满足：

- C99 backend 支持完整 Uya 语言，并与 main 分支语言行为兼容。
- Hosted native backend 经由 `PortableMIR` 支持完整 Uya 语言，并与 C99 / main 分支语言行为兼容。
- Freestanding native build-seed 子集保持 no-silent-C99 fallback 和明确 capability diagnostic。
- Microapp / microcontainer 在语言层面完全兼容 main 分支；限制只能来自 runtime、capability、profile、
  ABI 或镜像格式层，不能变成独立 Uya 方言。

## Next Step

冻结当前 native subset 特例增长，先补齐 `CoreBody` / CoreIR verifier，再转向 `PortableMIR`；CoreIR 合同见
`docs/coreir_lowered_program_whitepaper.md`，详细 MIR 合同见 `docs/portable_mir_whitepaper.md`。
当前只有 build CLI 的极小 freestanding 输出路径；hosted `cmd/build` self-build 已恢复真实门禁：它会解析并
类型检查 build seed 的完整 88 文件依赖图，然后进入 verifier-clean CoreBody/PortableMIR preflight。当前下一道
nested frontier 是链接输出分支内部的 `if link_result != 0` 错误分支；更大的真实门槛仍是把 `mir_body_functions=3`
的 self-build MIR 覆盖接入真实 native emitter/handoff，并继续把 pending bodies 逐步纳入 CoreBody / PortableMIR。
`compile_files(...)` 16 参数 parser/checker/native-codegen
主调用仍是大型验收样本，但只能通过 CoreBody dump/verifier、PortableMIR function body lowering、hosted native
call ABI 和 target capability verifier 到达；不能再通过新增 `RETURN_*`、`LOCAL_CALL_*`、`IF_LOCAL_*`
等 one-off `LoweredBodyOp` 解决。在这之前，不能声明已经生成 native `bin/cmd/build`。
`tests/verify_native_cmd_build_no_silent_c99.sh` 必须继续固定该 lowering frontier，确保 native 失败不会静默回落 C99。
