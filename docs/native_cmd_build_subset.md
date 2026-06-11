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
| F13 | partial | NativeEmitter 的历史 `LoweredProgram -> MachineModule` 窄子集仍只作为 freestanding build-seed 回归边界；hosted native 主线已经转到 CoreBody/PortableMIR preflight。`tests/verify_native_build_minimal_program.sh` 继续验证无参/最多两个 `i32` 参数、单/双 out-param、`get_argc()`、`get_argv(1)[0]`、条件返回/赋值、`set_process_stack_limit_bytes(...)` syscall 和 `parse_like(...)` 11 参数写回等旧窄 executable 子集不回归；`tests/verify_native_cmd_build_compiler_regressions.sh` 用 `bin/cmd/build --native --nostdlib` 覆盖泛型 identity、local array out-param、stack-limit call 和 compiler-like parse out-param regression 组；`tests/verify_native_cmd_build_c99_output_parity.sh` 用 `bin/cmd/build` 生成 C99 output，并与 C99-built `bin/uya` oracle 做归一化输出和运行结果比对。当前 `src/cmd/build/main.uya --native` self-build 门禁不再使用 `--nostdlib` 或 `compile_files(...)` one-off 形状，而是以 hosted 路径解析/检查 91 个依赖后进入 verifier-clean CoreIR/PortableMIR preflight；实测 frontier 为 `native_hosted_entry_frontier: wrapper_covered=1 first_pending_callee=build_compiler_driver_run first_pending_callee_prefix=1 first_pending_callee_prefix_stmts=39 first_pending_callee_next_stmt=-1 first_pending_callee_next_kind=<none>`，已覆盖 `build_compiler_driver_run` 的顶层入口前缀至末尾 `return 0`，包括 `parse_build_args(...)`、输出路径选择、`compile_files(...)` result、native 成功返回、C 输出检测分支入口、链接输出分支入口和最终返回；链接输出分支内部 nested frontier 为 `native_hosted_entry_child_frontier: first_pending_callee=build_compiler_driver_run parent_stmt=37 child_prefix=1 child_prefix_stmts=7 child_next_stmt=-1 child_next_kind=<none>`，已覆盖 `const c_file: &byte = artifacts.generated_c_path`、`var output: &byte = "a.out" as *byte`、`if user_output_path != null` 条件入口、`const link_result: i32 = link_with_toolchain(...)` 初始化、`if link_result != 0` 错误分支条件入口、链接输出分支内部成功 `fprintf(...)` 和 `return 0`，链接输出子块内部已无下一条 child frontier。entry complete 后的下一层 reachable body coverage 已推进到 `native_hosted_reachable_body_complete: function=parse_build_args prefix_stmts=28 reason=body_complete`，证明 `parse_build_args(...)` root body 已覆盖到 tail return；`set_process_stack_limit_bytes(...)` 首切片已迁入 verifier-clean CoreBody/PortableMIR，当前不再报告该 pending callee，计数推进为 `core_bodies=6`、`mir_body_functions=5`。handoff 现在固定为 `native_hosted_handoff_frontier: reason=pending_core_bodies ... entry_callee_coverage=complete entry_child_coverage=complete`，继续输出 `native_hosted_emitter_handoff: status=rejected reason=pending_core_bodies request_verified=1 backend=machine link_plan=complete ... entry_child_coverage=complete`，并通过 `native_hosted_emitter_import_preflight: status=ready imported_functions=483 imported_blocks=40 imported_insts=56 ...` 和 `native_hosted_emitter_output_preflight: status=ready output_matches_request=1 output_kind=machine_module machine_functions=483 ...` 证明 verified partial MIR 已进入 `NativeMirEmitter` import preflight 和 `MirTargetBackendOutput` payload；最终仍后接 `native_hosted_portable_mir_lowering_missing`，且不生成伪 native 输出、不回落 C99。 | hosted PortableMIR body lowering 接入真实 emitter/handoff 后，再生成 native `bin/cmd/build` |
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
  `native_hosted_reachable_body_complete: function=parse_build_args prefix_stmts=28 reason=body_complete`、
  stack-limit helper 首切片已进入 verifier-clean CoreBody/PortableMIR，因此不再报告
  `set_process_stack_limit_bytes` pending callee；`compile_stats_record_and_release_typed_program(...)`
  SemanticDb aggregate 切片迁入后，当前计数为 `core_bodies=7`、`mir_body_functions=6`、
  本轮 stderr 输出的 reachable body frontier 是 compile-stats partial body-prefix，未输出新的
  `native_hosted_reachable_callee_frontier` / loop body-prefix frontier、
  `native_hosted_handoff_frontier: reason=pending_core_bodies ... entry_callee_coverage=complete entry_child_coverage=complete`、
  `native_hosted_emitter_handoff: status=rejected reason=pending_core_bodies request_verified=1 backend=machine link_plan=complete ... entry_child_coverage=complete`、
  `native_hosted_emitter_import_preflight: status=ready imported_functions=484 imported_blocks=41 imported_insts=66 ...`、
  `native_hosted_emitter_output_preflight: status=ready output_matches_request=1 output_kind=machine_module machine_functions=484 ...` 和
  `native_hosted_portable_mir_lowering_missing`。
  不再把 `compile_files(...)` 16 参数缺口固定为 `--nostdlib` freestanding one-off shape。
- `compile_stats_record_and_release_typed_program(...)` SemanticDb aggregate 切片已接入 verifier-clean CoreBody/PortableMIR：
  `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=9 next_stmt=9 next_kind=AST_CALL_EXPR reason=partial_core_body`。
  当前 whole-body pending frontier 已推进到
  `native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=180 function_id=5 body_stmts=4 reason=pending_core_body`；
  后续若继续处理 compile-stats，必须按同 helper 的真实下一 body-prefix 推进，不得从静态候选列表猜
  `compile_files(...)` 或其它 helper。
- native `bin/cmd/build` 仍是 freestanding build-seed 里程碑，不是 hosted native 完整语言 parity 的前置条件。

## `parse_build_args(...)` PortableMIR Surface Audit

`parse_build_args(...)` 已按源码顺序迁入到 body complete。当前 self-build reachable callee frontier 是
`build_compiler_driver_run` 第 17 条语句调用到的
`set_process_stack_limit_bytes(...)`。`parse_build_args(...)` 的迁移不能用摘要、专用
`LoweredBodyOp`、手写 native helper 或 C99 fallback 跳过函数体。

按 `src/build_compiler_driver.uya` 中的 body 顺序，`parse_build_args(...)` 需要覆盖以下 surface：

1. 入口 argv/argc 和 early return：`get_argc()`、`get_argv(0)`、`argc < 2`、
   `program_name != null`、`print_usage(program_name as &byte)`、`return -1`，
   以及 `input_file_capacity <= 0` 时的 `fprintf(libc.stderr, ...)`。
2. 默认 out-param 写入和全局状态初始化：`input_file_count[0]`、`output_file_index[0]`、
   `backend_type[0]`、`emit_line_directives[0]`、`enable_safety_proof[0]`、`opt_level[0]`、
   `is_nostdlib[0]`、`stack_size[0]`、`async_frame_heap_fallback[0]`，以及
   `g_split_c_dir_active`、`g_split_c_dir[0]`、`g_split_c_disabled_cli`、
   `g_module_root_override_active`、`g_module_root_override[0]` 的全局写入。
3. 首参数命令处理：`get_argv(1)`、`first_arg != null`、`strcmp` 的 `--help` / `-h`、
   `--version` / `-v` 和 `build` 子命令分支，含 stdout/stderr 输出和 return `2`。
4. 主 option loop 骨架：`var start_idx`、`var i`、`while i < argc`、`get_argv(i)`、
   null 参数 diagnostic、loop 尾部 `i = i + 1`，以及 `else if` 链的稳定控制流。
5. 基础 flag / scalar option：`-o` 缺参与 `output_file_index[0] = i + 1`、`i = i + 1`，
   `--c99` / `--native` backend enum 写入，line-directives、safety-proof、
   `--opt=0..3` / `-O0..3` 和 `--nostdlib`。
6. `--project-root`：缺参、空参数、`root_arg[0]` byte index、`strlen(root_arg)`、
   `PATH_MAX` 比较、`strcpy(&g_module_root_override[0] as *byte, root_arg)` 和
   `g_module_root_override_active = 1`。
7. build-seed 明确拒绝选项：`--manifest-path`、exec/vm/dump/trace、microapp profile /
   `strncmp("--microapp-profile=", 19)`、`--outlibc`，都必须保留现有 diagnostic 和
   `return -1`。
8. `--stack-size` 数字扫描：`get_argv(i + 1)`、`size_str[j]` byte index、
   `while size_str[j] >= 48 && size_str[j] <= 57`、`size_val = size_val * 10 + (size_str[j] - 48)`、
   `j = j + 1`、`stack_size[0] = size_val`、无效 warning、缺参 error。
9. split-C CLI：`--async-frame-heap=on`、`--no-split-c`、`strncmp("--split-c-dir=", 14)`、
   `arg + 14` pointer arithmetic、`strlen`、`PATH_MAX - 1`、`strcpy`、忽略 warning、
   `--split-c-dir <dir>` 的可选参数跳过和 `split_c_set_default_dir()` 调用。
10. 位置输入文件收集：`arg[0]` byte index、`c != 45`、容量检查、
    `input_file_indices[idx] = i`、`input_file_count[0] = idx + 1`，以及当前未知 dash
    option 被忽略的既有行为。
11. 收尾输出路径检查：`input_file_count[0] == 0`、未指定输入 diagnostic、可选
    `print_usage`、`out_idx >= 0`、`get_argv(out_idx)` null error、`strrchr(out_path, 46)`、
    `.c` 后缀推断 C99、`is_c_output(out_path as &byte)` 和 `--native` 输出 `.c` 的明确拒绝。

迁移顺序应先补对应 CoreBody/PortableMIR golden/verifier surface，再逐段扩大 self-build body 覆盖。
每个切片完成后，`tests/verify_native_cmd_build_no_silent_c99.sh` 必须继续证明 self-build verifier-clean、
no-output、no-silent-C99，并把 reachable callee/body frontier 推进到真实的下一处未迁 body。

## `set_process_stack_limit_bytes(...)` PortableMIR Surface Audit

当前 self-build frontier 是 `build_compiler_driver_run` 第 17 条语句的
`set_process_stack_limit_bytes(eff_compiler_stack_kb as u64 * 1024)` 调用，目标函数定义在
`lib/std/runtime/entry/entry.uya`。该 helper 必须按真实 runtime body 迁入，不得跳到
`compile_files(...)` 或恢复 freestanding `LoweredProgram` stack-limit helper。

按源码顺序，`set_process_stack_limit_bytes(...)` 需要覆盖以下 surface：

1. 函数签名与输入：`export fn set_process_stack_limit_bytes(limit_bytes: u64) void`，
   hosted self-build caller 已在 `build_compiler_driver_run` 中冻结 `i32 -> u64` cast 和 `* 1024`
   调用参数。
2. 运行时结构体与常量：`EntryRLimit { rlim_cur: u64, rlim_max: u64 }`、
   `ENTRY_RLIMIT_STACK = 3`，以及局部 `var rlim` 两个字段都由 `limit_bytes` 初始化。
3. target gating：外层 `std.cfg(std.target_os == .tos_linux, ...)`；非 Linux / unknown / Web target
   保持 no-op，不引入宿主 syscall。
4. Linux arch 分流：`ta_x86_64` 使用 syscall 号 `160`，`ta_arm64` 使用 `164`，
   `ta_arm` 使用 `75`，`ta_riscv64` 使用 `164`；其它 Linux arch 继续 no-op。
5. syscall expression：每个已支持 arch 都构造
   `@syscall(SYS_setrlimit_*, ENTRY_RLIMIT_STACK as i64, &rlim as i64)`，结果类型为 `!i64`。
6. error-union cleanup：每个 `setrlimit_result_* catch { 0i64; };` 都必须保留“失败忽略”的现有语义，
   不输出 diagnostic，不改变函数 `void` 返回。
7. capability 边界：该 helper 只允许通过 PortableMIR 表达 target-gated `@syscall` / error-union
   surface；hosted native 不得调用 libc `setrlimit`、不得把它当作已完成 executable writer 条件，
   也不得静默回落 C99。

## `set_process_stack_limit_bytes(...)` First Slice Contract

Linux x86_64 首切片只冻结 `set_process_stack_limit_bytes(...)` 中最小可验证路径：
`EntryRLimit` 局部初始化、`SYS_setrlimit_x86_64 = 160`、
`@syscall(SYS_setrlimit_x86_64, ENTRY_RLIMIT_STACK as i64, &rlim as i64)` 和
`setrlimit_result_x86_64 catch { 0i64; };`。该合同不代表 helper body complete，也不允许提前跳到
`compile_files(...)`。

CoreBody/PortableMIR 合同：

1. CoreIR body 必须以 source body 记录 `EntryRLimit` 局部结构初始化；局部声明使用
   `CORE_STMT_KIND_LOCAL_DECL`，字段来源必须仍是 `limit_bytes`，不得压成不透明 helper。
2. x86_64 `@syscall` 必须作为 `CORE_EXPR_KIND_CALL` 或等价 syscall-call surface 进入 CoreIR，
   并附带 `CORE_SEMANTIC_FACT_CAPABILITY`，表示 target-gated syscall capability。
3. `ENTRY_RLIMIT_STACK` 的值必须保持 `3`，`SYS_setrlimit_x86_64` 的值必须保持 `160`；
   `&rlim as i64` 必须保留地址语义，不能替换成 libc `setrlimit`。
4. PortableMIR 必须用 `MIR_INST_OP_CALL` 或后续正式 syscall inst 表达该调用；当前首切片先用
   hosted verifier-clean call surface 记录 syscall number/capability，正式 syscall inst 或
   `MIR_CALL_ABI_PROFILE_FREESTANDING_SYSCALL` 下沉留给后续 target profile / writer 解锁切片。
5. `MirCapabilityReq` / `runtime_capability_mask` 必须让 `MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY`
   在不支持 syscall 的 target profile 下可触发；不能让 backend 到发射阶段才发现能力缺口。
6. `catch { 0i64; }` 必须作为 error-union cleanup/fallback 语义保留：失败被忽略、不输出 diagnostic、
   函数保持 `void` 返回。
7. 首切片实现后，hosted self-build 不得继续报告
   `native_hosted_reachable_callee_frontier: parent=build_compiler_driver_run stmt=17 first_unresolved_callee=set_process_stack_limit_bytes reason=pending_core_body`；
   当前实测推进为 `native_hosted_coreir_preflight: status=0 verifier_error=0 functions=3639 core_bodies=6 pending_bodies=3156`
   和 `native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=478 mir_body_functions=5 ...`。
   writer 仍必须保持 `native_hosted_portable_mir_lowering_missing`、no-output 和 no-silent-C99，直到后续
   pending CoreBody 队列继续收敛。

## `compile_stats_record_and_release_typed_program(...)` PortableMIR Surface Audit

当前 handoff-only pending body frontier 固定为：

```text
native_hosted_pending_body_frontier: function=compile_stats_record_and_release_typed_program decl=159 function_id=4 body_stmts=18 reason=pending_core_body
```

该 helper 定义在 `src/build_compiler_driver.uya`，负责在 checker 生命周期收尾时记录
`TypedProgram` 常驻/峰值/释放后字节数，聚合 `SemanticDb` 和 `TypedProgram` 动态表统计，并释放
checker 持有的 typed/lifetime 表。迁移时必须按真实 body surface 表达，不能用摘要统计 helper、
C99 fallback 或直接跳到 `compile_files(...)`。

按源码顺序，`compile_stats_record_and_release_typed_program(...)` 需要覆盖以下 surface：

1. 函数签名与参数：`fn compile_stats_record_and_release_typed_program(stats: &CompileStats, checker: &TypeChecker) void`。
   `stats` 是输出统计结构体指针，`checker` 是已完成类型检查后的 `TypeChecker` 指针。
2. `stats == null` early return：参数无效时必须直接 `return`，不写任何 `CompileStats` 字段，
   不读取 `checker`，也不触发 release。
3. TypedProgram 统计字段清零：非空 `stats` 先写
   `typed_program_bytes = 0usize`、`typed_program_peak_bytes = 0usize`、
   `typed_program_released_bytes = 0usize`。该清零发生在 `checker == null` 判断之前。
4. `checker == null` early return：checker 为空时只保留上一步三个 typed-program 字段为零，
   不写 `table_items` / `table_capacity` / `table_used_bytes` / `table_capacity_bytes` /
   `table_realloc_count`，也不释放 `typed_program` 或 `typed_type_records`。
5. TypedProgram pre-release bytes：非空 checker 下，按顺序读取
   `typed_program_current_bytes(&checker.typed_program)` 和
   `typed_program_peak_bytes(&checker.typed_program)`，分别写入
   `stats.typed_program_bytes` 与 `stats.typed_program_peak_bytes`。
6. 动态表聚合局部：声明 `var table_agg: SemanticTableAgg = semantic_table_agg_init()`。
   `SemanticTableAgg` 包含 `table_count`、`items`、`capacity`、`used_bytes`、
   `capacity_bytes` 和 `realloc_count`，初始化值全部为零。
7. SemanticDb 表统计：调用
   `semantic_db_accumulate_table_stats(&checker.semantic_db, &table_agg)`，覆盖 name intern
   entries/string pool、全部 SemanticDb vector，以及 `name_range_index`、`decls_by_name`、
   `functions_by_name`、`types_by_name`、`global_vars_by_name`、`enum_variants_by_name`、
   `exports_by_module_name`、`aliases_by_file_name`、`use_items_by_file_name` 等 hash 表。
8. TypedProgram 表统计：调用
   `typed_program_accumulate_table_stats(&checker.typed_program, &table_agg)`，覆盖
   `expr_types`、`identifier_bindings`、`call_targets`、`method_dispatch`、`field_access`、
   `global_init_order`、`reachable_roots`、`proof_results` 八张动态 vector。
9. 聚合结果写回 `CompileStats`：按源码顺序把 `table_agg.items`、`capacity`、`used_bytes`、
   `capacity_bytes`、`realloc_count` 写入 `stats.table_items`、`stats.table_capacity`、
   `stats.table_used_bytes`、`stats.table_capacity_bytes` 和 `stats.table_realloc_count`。
   当前 body 不写 `table_count` 到 `CompileStats`。
10. release 顺序：先调用 `typed_program_release(&checker.typed_program)`，再调用
    `semantic_vector_release(&checker.typed_type_records)`。该顺序保证 table 聚合和 pre-release
    bytes 已经读取，且 release 只发生在 checker 非空路径。
11. release 后 bytes：最后再次调用
    `typed_program_current_bytes(&checker.typed_program)`，写入
    `stats.typed_program_released_bytes`。`typed_program_release(...)` 会清空 typed counts、
    释放内部 vector，并把生命周期状态置为 released，因此该字段应反映释放后的常驻估算字节数。
12. capability 边界：该 helper 需要 PortableMIR 支持指针空值比较、struct field load/store、
    field 取址（`&checker.typed_program` / `&checker.semantic_db` /
    `&checker.typed_type_records`）、`usize` 立即数与统计字段写入、局部 struct 初始化、
    顺序函数调用和无值 early return。函数本身无 diagnostics、无 IO、无环境读取、无全局写入；
    可能的 arena/table lifetime 影响只来自被调用的聚合与 release helper。

下一步合同应先冻结上述 body 的最小前缀，尤其是 `stats == null` return、typed-program 三字段清零、
`checker == null` return，以及首个 `typed_program_current_bytes(&checker.typed_program)` 调用的
field-address surface。只有该 helper body complete 后，才能重新运行 self-build frontier 并接受真实诊断中的
下一个 pending body/helper 名称。

## `compile_stats_record_and_release_typed_program(...)` First Slice Contract

首个最小切片只冻结 `compile_stats_record_and_release_typed_program(...)` 的入口防护和第一处
`TypedProgram` 字节统计读取：`stats == null` return、三个 typed-program 统计字段清零、
`checker == null` return，以及
`typed_program_current_bytes(&checker.typed_program)` 的 field-address call surface。该合同不代表
helper body complete，也不覆盖 `SemanticTableAgg` 聚合、release 调用或 release 后 bytes。

CoreBody/PortableMIR 合同：

1. `stats == null` 必须进入 CoreIR 条件分支，并在 true 分支用 `CORE_STMT_KIND_RETURN`
   表达无值 early return。该路径不得读取 `checker`，不得写任何 `CompileStats` 字段。
2. 三个清零写入必须保持源码顺序：`typed_program_bytes = 0usize`、
   `typed_program_peak_bytes = 0usize`、`typed_program_released_bytes = 0usize`。
   CoreIR 使用 `CORE_STMT_KIND_ASSIGN` 表达字段 store，目标 place 必须是
   `CORE_PLACE_KIND_FIELD`，并带 `CORE_SEMANTIC_FACT_FIELD_ID` 冻结字段身份，不能把这些写入压成
   summary metrics helper。
3. `checker == null` 必须在三个清零写入之后进入第二个 early return。该 true 分支同样使用
   `CORE_STMT_KIND_RETURN`，并且不能写 `table_*` 字段或调用 release helper。
4. 首个 bytes 调用必须保留 `&checker.typed_program` 的 field-address surface。CoreIR 中该字段取址
   至少需要 field place/fact 记录；PortableMIR 必须通过 `MIR_INST_OP_FIELD_ADDR` 或后续等价
   field-address inst 表达 `checker.typed_program` 地址，再用 `MIR_INST_OP_CALL` 调用
   `typed_program_current_bytes(...)`。
5. 三个清零写入在 PortableMIR 中必须进入 verifier-clean store surface，使用 `MIR_INST_OP_STORE`；
   early return 使用 `MIR_TERMINATOR_KIND_RETURN`，不能依赖 C99 fallback 或生产统计摘要。
6. 该切片需要 `usize` 常量 `0usize`、指针 null 比较、struct field load/store、field-address、
   顺序 call 和无值 return。函数本身仍无 diagnostics、无 IO、无环境读取、无全局写入。
7. 首切片实现后，self-build frontier 不得继续只报告该 helper 完全 pending；若 helper 尚未
   body complete，必须报告同一 helper 的下一条 body-prefix，或者在 helper complete 后转向真实的下一个
   pending body/helper。

## `compile_stats_record_and_release_typed_program(...)` Peak Bytes Slice Contract

首切片迁入后的真实 reachable body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=6 next_stmt=6 next_kind=AST_ASSIGN reason=partial_core_body
```

下一条源码语句是
`stats.typed_program_peak_bytes = typed_program_peak_bytes(&checker.typed_program);`。
该切片只允许在已覆盖的 current-bytes call 之后追加 peak-bytes call，不得提前进入
`SemanticTableAgg` 聚合、table stats 写回、release 调用或 release 后 bytes。

CoreBody/PortableMIR 合同：

1. `typed_program_peak_bytes(&checker.typed_program)` 必须保留和 current-bytes 相同的
   `&checker.typed_program` field-address surface；CoreIR 记录 field place/fact，PortableMIR
   通过 `MIR_INST_OP_FIELD_ADDR` 加 `MIR_INST_OP_CALL` 表达。
2. 写回 `stats.typed_program_peak_bytes` 必须是独立 `CORE_STMT_KIND_ASSIGN` surface，
   PortableMIR 侧必须追加独立 `MIR_INST_OP_FIELD_ADDR` / `MIR_INST_OP_CALL` surface；
   不能复用 current-bytes 的目标字段，也不能把 current/peak 两个统计合并为摘要 helper。
3. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=7 next_stmt=7 next_kind=AST_VAR_DECL reason=partial_core_body`。
   下一步才能审计并迁入 `var table_agg: SemanticTableAgg = semantic_table_agg_init()`。

## `compile_stats_record_and_release_typed_program(...)` Table Agg Init Slice Contract

peak-bytes 切片迁入后的真实 reachable body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=7 next_stmt=7 next_kind=AST_VAR_DECL reason=partial_core_body
```

下一条源码语句是
`var table_agg: SemanticTableAgg = semantic_table_agg_init();`。该切片只允许追加
`SemanticTableAgg` 局部 stack slot 和 `semantic_table_agg_init()` 零参数 call initializer，
不得提前迁入 `semantic_db_accumulate_table_stats(...)`、`typed_program_accumulate_table_stats(...)`
或任何 `stats.table_*` 写回。

CoreBody/PortableMIR 合同：

1. `table_agg` 必须以 `CORE_STMT_KIND_LOCAL_DECL` / `CORE_PLACE_KIND_LOCAL` 表达，
   并带 stack-slot flag，不能把后续 table 聚合压缩为匿名摘要值。
2. `semantic_table_agg_init()` 必须作为零参数 `CORE_EXPR_KIND_CALL` 进入 CoreIR，并带
   `CORE_SEMANTIC_FACT_RESOLVED_CALL` 记录真实 callee；PortableMIR 侧追加独立
   `MIR_INST_OP_CALL` surface。
3. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=8 next_stmt=8 next_kind=AST_CALL_EXPR reason=partial_core_body`。
   下一步才能迁入 `semantic_db_accumulate_table_stats(&checker.semantic_db, &table_agg)`。

## `compile_stats_record_and_release_typed_program(...)` SemanticDb Agg Slice Contract

table-agg init 切片迁入后的真实 reachable body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=8 next_stmt=8 next_kind=AST_CALL_EXPR reason=partial_core_body
```

下一条源码语句是
`semantic_db_accumulate_table_stats(&checker.semantic_db, &table_agg);`。该切片只允许追加
SemanticDb aggregate call，不得提前迁入 `typed_program_accumulate_table_stats(...)` 或任何
`stats.table_*` 写回。

CoreBody/PortableMIR 合同：

1. 该调用必须作为 `CORE_STMT_KIND_EXPR` / `CORE_EXPR_KIND_CALL` 表达，并带
   `CORE_SEMANTIC_FACT_RESOLVED_CALL` 记录 `semantic_db_accumulate_table_stats` 的真实 callee 和
   `arg_count=2`。
2. 第一个参数 `&checker.semantic_db` 必须保留 checker field-address surface，CoreIR 记录
   `CORE_PLACE_KIND_FIELD` / `CORE_SEMANTIC_FACT_FIELD_ID`，PortableMIR 追加独立
   `MIR_INST_OP_FIELD_ADDR` surface。
3. 第二个参数 `&table_agg` 必须引用上一切片创建的 local stack slot，CoreIR 记录
   `CORE_PLACE_KIND_LOCAL`，PortableMIR 追加独立 local/address operand surface。
4. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=9 next_stmt=9 next_kind=AST_CALL_EXPR reason=partial_core_body`。
   下一步才能迁入 `typed_program_accumulate_table_stats(&checker.typed_program, &table_agg)`。

## `compile_stats_record_and_release_typed_program(...)` TypedProgram Agg Slice Contract

SemanticDb aggregate 切片迁入后的真实 reachable body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=9 next_stmt=9 next_kind=AST_CALL_EXPR reason=partial_core_body
```

下一条源码语句是
`typed_program_accumulate_table_stats(&checker.typed_program, &table_agg);`。该切片只允许追加
TypedProgram aggregate call，不得提前迁入任何 `stats.table_*` 写回。

CoreBody/PortableMIR 合同：

1. 该调用必须作为 `CORE_STMT_KIND_EXPR` / `CORE_EXPR_KIND_CALL` 表达，并带
   `CORE_SEMANTIC_FACT_RESOLVED_CALL` 记录 `typed_program_accumulate_table_stats` 的真实 callee 和
   `arg_count=2`。
2. 第一个参数 `&checker.typed_program` 必须保留 checker field-address surface，CoreIR 记录
   `CORE_PLACE_KIND_FIELD` / `CORE_SEMANTIC_FACT_FIELD_ID`，PortableMIR 追加独立
   `MIR_INST_OP_FIELD_ADDR` surface。
3. 第二个参数 `&table_agg` 必须复用 table_agg local stack slot，不能新造匿名 aggregate。
4. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=10 next_stmt=10 next_kind=AST_ASSIGN reason=partial_core_body`。
   下一步才能迁入 `stats.table_items = table_agg.items` 写回。

## `compile_stats_record_and_release_typed_program(...)` Table Items Writeback Slice Contract

TypedProgram aggregate 切片迁入后的真实 reachable body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=10 next_stmt=10 next_kind=AST_ASSIGN reason=partial_core_body
```

下一条源码语句是 `stats.table_items = table_agg.items;`。该切片只允许追加
`table_items` 单个 aggregate writeback，不得提前迁入 `table_capacity` 或后续统计字段写回。

CoreBody/PortableMIR 合同：

1. 该赋值必须作为 `CORE_STMT_KIND_ASSIGN`，目标 place 为 `stats.table_items` 的
   `CORE_PLACE_KIND_FIELD` / `CORE_SEMANTIC_FACT_FIELD_ID`。
2. 右值 `table_agg.items` 必须保留 source field surface，CoreIR 记录独立
   `CORE_PLACE_KIND_FIELD` / `CORE_EXPR_KIND_LOCAL_REF`，PortableMIR 追加独立
   `MIR_INST_OP_FIELD_ADDR` surface。
3. PortableMIR 必须追加该写回对应的 `MIR_INST_OP_STORE`，不能把 table aggregate
   结果折叠为常量或匿名临时。
4. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=11 next_stmt=11 next_kind=AST_ASSIGN reason=partial_core_body`。
   下一步才能迁入 `stats.table_capacity = table_agg.capacity` 写回。

## `compile_stats_record_and_release_typed_program(...)` Table Capacity Writeback Slice Contract

Table items writeback 切片迁入后的真实 reachable body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=11 next_stmt=11 next_kind=AST_ASSIGN reason=partial_core_body
```

下一条源码语句是 `stats.table_capacity = table_agg.capacity;`。该切片只允许追加
`table_capacity` 单个 aggregate writeback，不得提前迁入 `table_used_bytes` 或后续统计字段写回。

CoreBody/PortableMIR 合同：

1. 该赋值必须作为 `CORE_STMT_KIND_ASSIGN`，目标 place 为 `stats.table_capacity` 的
   `CORE_PLACE_KIND_FIELD` / `CORE_SEMANTIC_FACT_FIELD_ID`。
2. 右值 `table_agg.capacity` 必须保留 source field surface，CoreIR 记录独立
   `CORE_PLACE_KIND_FIELD` / `CORE_EXPR_KIND_LOCAL_REF`，PortableMIR 追加独立
   `MIR_INST_OP_FIELD_ADDR` surface。
3. PortableMIR 必须追加该写回对应的 `MIR_INST_OP_STORE`，不能把 table aggregate
   结果折叠为常量或匿名临时。
4. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=12 next_stmt=12 next_kind=AST_ASSIGN reason=partial_core_body`。
   下一步才能迁入 `stats.table_used_bytes = table_agg.used_bytes` 写回。

## `compile_stats_record_and_release_typed_program(...)` Table Used Bytes Writeback Slice Contract

Table capacity writeback 切片迁入后的真实 reachable body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=12 next_stmt=12 next_kind=AST_ASSIGN reason=partial_core_body
```

下一条源码语句是 `stats.table_used_bytes = table_agg.used_bytes;`。该切片只允许追加
`table_used_bytes` 单个 aggregate writeback，不得提前迁入 `table_capacity_bytes` 或后续统计字段写回。

CoreBody/PortableMIR 合同：

1. 该赋值必须作为 `CORE_STMT_KIND_ASSIGN`，目标 place 为 `stats.table_used_bytes` 的
   `CORE_PLACE_KIND_FIELD` / `CORE_SEMANTIC_FACT_FIELD_ID`。
2. 右值 `table_agg.used_bytes` 必须保留 source field surface，CoreIR 记录独立
   `CORE_PLACE_KIND_FIELD` / `CORE_EXPR_KIND_LOCAL_REF`，PortableMIR 追加独立
   `MIR_INST_OP_FIELD_ADDR` surface。
3. PortableMIR 必须追加该写回对应的 `MIR_INST_OP_STORE`，不能把 table aggregate
   结果折叠为常量或匿名临时。
4. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=13 next_stmt=13 next_kind=AST_ASSIGN reason=partial_core_body`。
   下一步才能迁入 `stats.table_capacity_bytes = table_agg.capacity_bytes` 写回。

## `compile_stats_record_and_release_typed_program(...)` Table Capacity Bytes Writeback Slice Contract

Table used bytes writeback 切片迁入后的真实 reachable body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=13 next_stmt=13 next_kind=AST_ASSIGN reason=partial_core_body
```

下一条源码语句是 `stats.table_capacity_bytes = table_agg.capacity_bytes;`。该切片只允许追加
`table_capacity_bytes` 单个 aggregate writeback，不得提前迁入 `table_realloc_count` 或后续统计字段写回。

CoreBody/PortableMIR 合同：

1. 该赋值必须作为 `CORE_STMT_KIND_ASSIGN`，目标 place 为 `stats.table_capacity_bytes` 的
   `CORE_PLACE_KIND_FIELD` / `CORE_SEMANTIC_FACT_FIELD_ID`。
2. 右值 `table_agg.capacity_bytes` 必须保留 source field surface，CoreIR 记录独立
   `CORE_PLACE_KIND_FIELD` / `CORE_EXPR_KIND_LOCAL_REF`，PortableMIR 追加独立
   `MIR_INST_OP_FIELD_ADDR` surface。
3. PortableMIR 必须追加该写回对应的 `MIR_INST_OP_STORE`，不能把 table aggregate
   结果折叠为常量或匿名临时。
4. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=14 next_stmt=14 next_kind=AST_ASSIGN reason=partial_core_body`。
   下一步才能迁入 `stats.table_realloc_count = table_agg.realloc_count` 写回。

## `compile_stats_record_and_release_typed_program(...)` Table Realloc Count Writeback Slice Contract

Table capacity bytes writeback 切片迁入后的真实 reachable body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=14 next_stmt=14 next_kind=AST_ASSIGN reason=partial_core_body
```

下一条源码语句是 `stats.table_realloc_count = table_agg.realloc_count;`。该切片只允许追加
`table_realloc_count` 单个 aggregate writeback，不得提前迁入 `typed_program_release(...)` 或后续释放路径。

CoreBody/PortableMIR 合同：

1. 该赋值必须作为 `CORE_STMT_KIND_ASSIGN`，目标 place 为 `stats.table_realloc_count` 的
   `CORE_PLACE_KIND_FIELD` / `CORE_SEMANTIC_FACT_FIELD_ID`。
2. 右值 `table_agg.realloc_count` 必须保留 source field surface，CoreIR 记录独立
   `CORE_PLACE_KIND_FIELD` / `CORE_EXPR_KIND_LOCAL_REF`，PortableMIR 追加独立
   `MIR_INST_OP_FIELD_ADDR` surface。
3. PortableMIR 必须追加该写回对应的 `MIR_INST_OP_STORE`，不能把 table aggregate
   结果折叠为常量或匿名临时。
4. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=15 next_stmt=15 next_kind=AST_CALL_EXPR reason=partial_core_body`。
   下一步才能迁入 `typed_program_release(&checker.typed_program)` 调用。

## `compile_stats_record_and_release_typed_program(...)` Typed Program Release Slice Contract

Table realloc count writeback 切片迁入后的真实 reachable body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=15 next_stmt=15 next_kind=AST_CALL_EXPR reason=partial_core_body
```

下一条源码语句是 `typed_program_release(&checker.typed_program);`。该切片只允许追加
TypedProgram release 单个调用，不得提前迁入 `semantic_vector_release(...)` 或后续 released-bytes
统计写回。

CoreBody/PortableMIR 合同：

1. 该调用必须作为 `CORE_STMT_KIND_EXPR` 或等价 call statement surface，callee 保持
   `typed_program_release` 的 resolved target。
2. 参数必须保留 `&checker.typed_program` 的 address-of/member-access surface；CoreIR 记录
   `checker.typed_program` 独立 field place，PortableMIR 追加独立 address/field/call surface。
3. PortableMIR 必须追加该释放调用对应的 `MIR_INST_OP_CALL`，不能把 release 折叠为 noop。
4. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=16 next_stmt=16 next_kind=AST_CALL_EXPR reason=partial_core_body`。
   下一步才能迁入 `semantic_vector_release(&checker.typed_type_records)` 调用。

## `compile_stats_record_and_release_typed_program(...)` Typed Type Records Release Slice Contract

TypedProgram release 切片迁入后的真实 reachable body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=16 next_stmt=16 next_kind=AST_CALL_EXPR reason=partial_core_body
```

下一条源码语句是 `semantic_vector_release(&checker.typed_type_records);`。该切片只允许追加
typed type records release 单个调用，不得提前迁入 released-bytes 统计写回。

CoreBody/PortableMIR 合同：

1. 该调用必须作为 `CORE_STMT_KIND_EXPR` 或等价 call statement surface，callee 保持
   `semantic_vector_release` 的 resolved target。
2. 参数必须保留 `&checker.typed_type_records` 的 address-of/member-access surface；CoreIR 记录
   `checker.typed_type_records` 独立 field place，PortableMIR 追加独立 address/field/call surface。
3. PortableMIR 必须追加该释放调用对应的 `MIR_INST_OP_CALL`，不能把 release 折叠为 noop。
4. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=17 next_stmt=17 next_kind=AST_ASSIGN reason=partial_core_body`。
   下一步才能迁入 `stats.typed_program_released_bytes = typed_program_current_bytes(&checker.typed_program)` 写回。

## `compile_stats_record_and_release_typed_program(...)` Released Bytes Writeback Slice Contract

Typed type records release 切片迁入后的真实 reachable body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=17 next_stmt=17 next_kind=AST_ASSIGN reason=partial_core_body
```

下一条源码语句是
`stats.typed_program_released_bytes = typed_program_current_bytes(&checker.typed_program);`。
该切片只允许追加 released-bytes 单条写回；迁入后该 helper 应达到 body complete，不得提前选择
后续 helper。

CoreBody/PortableMIR 合同：

1. 该写回必须保持 `stats.typed_program_released_bytes` destination field surface。
2. RHS 必须保持 `typed_program_current_bytes(&checker.typed_program)` 的 field-address call
   surface，不能复用释放前的 `typed_program_bytes` 结果。
3. PortableMIR 必须追加 RHS field address、call 和 destination store surface。
4. 该切片迁入后 self-build frontier 必须推进到 helper 完成：
   `native_hosted_reachable_body_complete: function=compile_stats_record_and_release_typed_program prefix_stmts=18 reason=body_complete`。
   下一步才能审计真实 frontier 指向的下一个 reachable helper。

## `compiler_should_profile_diagnostics(...)` Surface Audit

`compile_stats_record_and_release_typed_program(...)` 达到 body complete 后，当前 self-build
pending frontier 推进到：

```text
native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=225 function_id=5 body_stmts=4 reason=pending_core_body
```

函数源码：

```text
fn compiler_should_profile_diagnostics() i32 {
    const value: *byte = getenv("UYA_PROFILE_DIAGNOSTICS" as *byte);
    if value == null || value[0] == 0 as byte {
        return 0;
    }
    if strcmp(value, "0" as *byte) == 0 ||
       strcmp(value, "false" as *byte) == 0 ||
       strcmp(value, "no" as *byte) == 0 ||
       strcmp(value, "off" as *byte) == 0 {
        return 0;
    }
    return 1;
}
```

Surface 审计：

1. 参数：无参数；返回 `i32`。
2. 局部：`value: *byte`，由 `getenv("UYA_PROFILE_DIAGNOSTICS" as *byte)` 初始化。
3. Global / 外部调用：读取进程环境变量 `UYA_PROFILE_DIAGNOSTICS`；调用 libc `getenv` 和
   `strcmp`。无文件、网络、进程启动或 stderr/stdout 输出。
4. 控制流：4 条顶层语句。先声明 `value`；若 `value == null` 或首字节为 0，early return 0；
   若值等于 `"0"`、`"false"`、`"no"` 或 `"off"`，early return 0；否则 return 1。
5. diagnostics：该 helper 本身不打印 diagnostic；它只控制后续 diagnostics profiling 是否启用。
6. lowering 顺序：首个最小切片应先迁入 `const value = getenv(...)` 声明和对应 hosted libc call
   surface；后续再按真实 frontier 迁入空值/空串 branch、false-like branch 和 tail return。

## `compiler_should_profile_diagnostics(...)` First Slice Contract

当前真实 pending frontier 是：

```text
native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics decl=225 function_id=5 body_stmts=4 reason=pending_core_body
```

首个最小切片只覆盖第 0 条顶层语句：

```text
const value: *byte = getenv("UYA_PROFILE_DIAGNOSTICS" as *byte);
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须生成 `CORE_STMT_KIND_LOCAL_DECL`，声明名为 `value`，类型保持 `*byte`。
2. 初始化表达式必须保持 `CORE_EXPR_KIND_CALL`，callee resolved target 为 libc `getenv`，参数为
   `"UYA_PROFILE_DIAGNOSTICS" as *byte` 字符串字面量 surface。
3. PortableMIR 必须追加 `MIR_INST_OP_CALL`，runtime capability 覆盖 hosted libc / C extern，不得把
   `getenv` 折叠为常量或 noop。
4. 该首切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=1 next_stmt=1 next_kind=AST_IF_STMT reason=partial_core_body`。
   下一步才能迁入 `value == null || value[0] == 0 as byte` early-return branch。

## `compiler_should_profile_diagnostics(...)` Null/Empty Branch Contract

首切片迁入后，当前真实 body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=1 next_stmt=1 next_kind=AST_IF_STMT reason=partial_core_body
```

本合同只冻结第 1 条顶层语句：

```text
if value == null || value[0] == 0 as byte {
    return 0;
}
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须保留 `AST_IF_STMT` 对应的条件和 then-return surface，不得把整个 branch
   折叠为 noop，也不得把环境变量值常量化。
2. `value == null` 必须以现有 Core 条件表达式 surface 表示指针 null 比较；`value[0] == 0 as byte`
   必须通过 `CORE_PLACE_KIND_INDEX` / byte load surface 表示，再以 `CORE_EXPR_KIND_I32_NE`
   表示 byte 等值比较。
3. `||` 必须保持 short-circuit 语义：null 分支命中时不能读取 `value[0]`。
4. PortableMIR 必须生成 `MIR_TERMINATOR_KIND_COND_BR` 形状，至少包含 null-test block、
   byte-load/test block、early-return-0 block 和 fallthrough block；then block 返回 i32 0。
5. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT reason=partial_core_body`。
6. 实现叶子应新增 `NATIVE_PROFILE_DIAGNOSTICS_NULL_EMPTY_BRANCH_PREFIX_STMT_COUNT = 2`，
   并使用独立 shape/support/builder 命名，避免复用首切片函数掩盖 branch 语义。
7. 实现叶子应同步 `tests/verify_native_cmd_build_no_silent_c99.sh`：要求迁入后出现
   `prefix_stmts=2` frontier，并反向拒绝继续报告 `prefix_stmts=1`。

## `compiler_should_profile_diagnostics(...)` False-Like Branch Contract

null/empty branch 迁入后，当前真实 body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT reason=partial_core_body
```

本合同冻结第 2 条顶层语句：

```text
if strcmp(value, "0" as *byte) == 0 ||
   strcmp(value, "false" as *byte) == 0 ||
   strcmp(value, "no" as *byte) == 0 ||
   strcmp(value, "off" as *byte) == 0 {
    return 0;
}
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须保留 `CORE_STMT_KIND_IF` 和 then `CORE_STMT_KIND_RETURN` surface。
2. 每个 `strcmp(...) == 0` 项必须以 `CORE_EXPR_KIND_CALL` 表示 libc call surface；
   参数顺序保持 `value` 在前、字符串字面量在后，不能折叠为常量或跳过。
3. `||` 必须保持 short-circuit 语义；实现可以先以 partial CoreBody 标记该 branch，
   但不得把 false-like branch 标为 body complete。
4. PortableMIR 必须保留 `MIR_INST_OP_CALL` surface 和 hosted libc runtime capability。
5. 该切片迁入后 self-build frontier 必须推进到 tail return：
   `native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=3 next_stmt=3 next_kind=return reason=partial_core_body`。
6. 实现叶子应新增 `NATIVE_PROFILE_DIAGNOSTICS_FALSE_LIKE_BRANCH_PREFIX_STMT_COUNT = 3`，
   并同步 `tests/verify_native_cmd_build_no_silent_c99.sh` 反向拒绝继续报告 `prefix_stmts=2`。

## `compiler_should_profile_diagnostics(...)` Tail Return Contract

false-like branch 迁入后，当前真实 body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=3 next_stmt=3 next_kind=return reason=partial_core_body
```

本合同冻结第 3 条顶层语句：

```text
return 1;
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须追加 `CORE_STMT_KIND_RETURN`，返回表达式为 `CORE_EXPR_KIND_INT_LITERAL`
   且值为 `1`。
2. PortableMIR 必须保留 `MIR_TERMINATOR_KIND_RETURN` surface，返回 i32 1。
3. 该切片迁入后 `compiler_should_profile_diagnostics(...)` 不得继续报告 partial frontier；
   self-build frontier 必须推进到下一个真实 pending body：
   `native_hosted_pending_body_frontier: function=compiler_print_diagnostic_profile ... reason=pending_core_body`。
4. 迁入后 self-build 仍必须因后续 pending bodies 拒绝写出，且下一个可观测 pending body
   继续由真实 reachable/pending frontier 诊断驱动。

## `compiler_print_diagnostic_profile(...)` Surface Audit

`compiler_should_profile_diagnostics(...)` 达到 body complete 后，当前 self-build pending frontier
推进到：

```text
native_hosted_pending_body_frontier: function=compiler_print_diagnostic_profile decl=246 function_id=6 body_stmts=4 reason=pending_core_body
```

函数源码：

```text
fn compiler_print_diagnostic_profile(checker: &TypeChecker) void {
    if compiler_should_profile_diagnostics() == 0 || libc.stderr == null {
        return;
    }
    var count: i32 = 0;
    if checker != null {
        count = checker.diagnostic_format_count;
    }
    fprintf(libc.stderr, "diagnostic_format_count: %d\n" as *byte, count);
}
```

Surface 审计：

1. 参数：`checker: &TypeChecker`；返回 `void`。
2. 局部：`count: i32`，初始值为 0；当 `checker != null` 时读取
   `checker.diagnostic_format_count` 写回 `count`。
3. Global / 外部调用：读取 `libc.stderr`；调用
   `compiler_should_profile_diagnostics()`；尾部调用 `fprintf` 向 stderr 输出
   `diagnostic_format_count: %d\n`。
4. 控制流：4 条顶层语句。先执行 guard；当 profile 未启用或 stderr 为空时 early return；
   再初始化 `count`；非空 checker 分支读取计数；最后 fprintf 输出。
5. diagnostics / IO：该 helper 是 diagnostics profile 的实际 stderr 输出点；首个 guard
   切片必须保持 `compiler_should_profile_diagnostics()` 和 `libc.stderr` 的短路判断，不能提前
   执行 `fprintf` 或读取 `checker`。
6. lowering 顺序：首个最小切片只迁入第 0 条 guard early-return；后续再按真实 frontier
   迁入 `count` 局部、`checker != null` 分支和尾部 `fprintf`。

## `compiler_print_diagnostic_profile(...)` Guard Slice Contract

当前真实 pending frontier 是：

```text
native_hosted_pending_body_frontier: function=compiler_print_diagnostic_profile decl=246 function_id=6 body_stmts=4 reason=pending_core_body
```

首个最小切片只覆盖第 0 条顶层语句：

```text
if compiler_should_profile_diagnostics() == 0 || libc.stderr == null {
    return;
}
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须生成 `CORE_STMT_KIND_IF`，条件保留
   `compiler_should_profile_diagnostics() == 0 || libc.stderr == null` 的源码顺序。
2. `compiler_should_profile_diagnostics()` 必须保持 resolved local call surface；`libc.stderr`
   必须保持 global/field 读取 surface，不得常量化为非空或折叠整个 guard。
3. `||` 必须保持 short-circuit 语义：当 profile helper 返回 0 时不能读取或使用后续输出路径。
4. then body 必须只执行 `return;`，不得提前初始化 `count`、读取 `checker` 或调用 `fprintf`。
5. PortableMIR 必须保留 conditional branch 和 void return terminator surface。
6. 该 guard 切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=1 next_stmt=1 next_kind=AST_VAR_DECL reason=partial_core_body`。
   下一步才能迁入 `var count: i32 = 0`。

## `compiler_print_diagnostic_profile(...)` Count Local Contract

guard 切片迁入后，当前真实 body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=1 next_stmt=1 next_kind=AST_VAR_DECL reason=partial_core_body
```

本合同只冻结第 1 条顶层语句：

```text
var count: i32 = 0;
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须在 guard if/return 之后追加 `CORE_STMT_KIND_LOCAL_DECL`，声明名为 `count`，
   类型保持 `i32`。
2. 初始化表达式必须保持 `CORE_EXPR_KIND_INT_LITERAL`，值为 0；不得从 `checker` 推导初值，
   也不得把后续 `checker != null` 分支合并进本切片。
3. PortableMIR 必须为 `count` 建立 i32 local/stack slot 和常量 0 写入 surface；该 partial body
   的 fallthrough 仍必须停在下一条源码语句。
4. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT reason=partial_core_body`。
   下一步才能迁入 `if checker != null { count = checker.diagnostic_format_count; }`。

## `compiler_print_diagnostic_profile(...)` Checker Branch Contract

count local 切片迁入后，当前真实 body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT reason=partial_core_body
```

本合同只冻结第 2 条顶层语句：

```text
if checker != null {
    count = checker.diagnostic_format_count;
}
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须追加 `CORE_STMT_KIND_IF`，条件保持 `checker != null` 的 pointer null compare
   surface。
2. then body 必须只包含 `count = checker.diagnostic_format_count` 写回；`checker.diagnostic_format_count`
   必须保持 field read surface，destination 必须保持 `count` local place。
3. PortableMIR 必须保留 conditional branch、field read 和 local write surface；不得把
   null branch 或 field 值常量化。
4. 该切片迁入后 self-build frontier 必须推进到下一条真实源码语句：
   `native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=3 next_stmt=3 next_kind=AST_CALL_EXPR reason=partial_core_body`。
   下一步才能迁入尾部 `fprintf(libc.stderr, ...)`。

## `compiler_print_diagnostic_profile(...)` Tail Fprintf Contract

checker branch 切片迁入后，当前真实 body frontier 是：

```text
native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=3 next_stmt=3 next_kind=AST_CALL_EXPR reason=partial_core_body
```

本合同冻结第 3 条顶层语句：

```text
fprintf(libc.stderr, "diagnostic_format_count: %d\n" as *byte, count);
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须追加 `CORE_STMT_KIND_EXPR`，表达式保持 `fprintf` resolved call surface。
2. 第 0 个参数必须保持 `libc.stderr` field read surface；第 1 个参数必须保持
   `"diagnostic_format_count: %d\n" as *byte` 字符串 surface；第 2 个参数必须保持 `count`
   local read surface。
3. PortableMIR 必须追加 hosted libc call surface，runtime capability 覆盖 hosted libc，不得折叠
   为 noop，也不得提前把 helper 标记完成但丢失 stderr 输出。
4. 该切片迁入后 `compiler_print_diagnostic_profile(...)` 必须达到 body complete：
   `native_hosted_reachable_body_complete: function=compiler_print_diagnostic_profile prefix_stmts=4 reason=body_complete`。
   下一步必须重新读取真实 self-build frontier，再选择后续 helper。

## `native_build_ast_plan_empty()` Body Complete Contract

`compiler_print_diagnostic_profile(...)` body complete 后，当前真实 pending frontier 是：

```text
native_hosted_pending_body_frontier: function=native_build_ast_plan_empty decl=291 function_id=7 body_stmts=1 reason=pending_core_body
```

函数源码：

```text
fn native_build_ast_plan_empty() NativeBuildAstPlan {
    return NativeBuildAstPlan{
        plans: null,
        function_count: 0,
        entry_index: -1,
    };
}
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须生成单条 `CORE_STMT_KIND_RETURN`，返回表达式保持 `NativeBuildAstPlan` struct literal
   surface。
2. struct literal 的字段必须保持源码顺序和语义：`plans = null`、`function_count = 0`、
   `entry_index = -1`；不得把 `entry_index` 改成 0 或省略 null 指针字段。
3. PortableMIR 必须保留 aggregate return surface，返回类型为 `NativeBuildAstPlan`，不得把该 helper
   降成 noop 或 pending body。
4. 该切片迁入后 `native_build_ast_plan_empty()` 必须达到 body complete：
   `native_hosted_reachable_body_complete: function=native_build_ast_plan_empty prefix_stmts=1 reason=body_complete`。
   下一步必须重新读取真实 self-build frontier。

## `native_build_empty_vector()` Body Complete Contract

`native_build_ast_plan_empty()` body complete 后，当前真实 pending frontier 是：

```text
native_hosted_pending_body_frontier: function=native_build_empty_vector decl=295 function_id=8 body_stmts=1 reason=pending_core_body
```

函数源码：

```text
fn native_build_empty_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须生成单条 `CORE_STMT_KIND_RETURN`，返回表达式保持 `SemanticVector` struct literal
   surface。
2. struct literal 的字段必须保持源码顺序和语义：`data = null`、`item_size = 0usize`、
   `count = 0usize`、`capacity = 0usize`、`bytes = 0usize`、`realloc_count = 0`；不得省略
   null 指针字段，也不得把 usize 字段改写成带符号 i32 语义。
3. PortableMIR 必须保留 aggregate return surface，返回类型为 `SemanticVector`，不得把该 helper
   降成 noop 或 pending body。
4. 该切片迁入后 `native_build_empty_vector()` 必须达到 body complete：
   `native_hosted_reachable_body_complete: function=native_build_empty_vector prefix_stmts=1 reason=body_complete`。
   下一步必须重新读取真实 self-build frontier。

## `native_build_lowered_plan_empty()` Body Complete Contract

`native_build_empty_vector()` body complete 后，当前真实 pending frontier 是：

```text
native_hosted_pending_body_frontier: function=native_build_lowered_plan_empty decl=299 function_id=9 body_stmts=1 reason=pending_core_body
```

函数源码返回嵌套 `NativeBuildLoweredPlan`：

```text
fn native_build_lowered_plan_empty() NativeBuildLoweredPlan {
    return NativeBuildLoweredPlan{
        lowered: LoweredProgram{
            arena: null,
            function_count: 0usize,
            global_count: 0usize,
            ...
            functions: native_build_empty_vector(),
            body_ops: native_build_empty_vector(),
            ...
            worklist: native_build_empty_vector(),
        },
        entry_index: -1,
    };
}
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须生成单条 `CORE_STMT_KIND_RETURN`，返回表达式保持 `NativeBuildLoweredPlan`
   struct literal surface，且 `lowered` 字段保持嵌套 `LoweredProgram` struct literal。
2. `LoweredProgram` 的 scalar 字段必须保持空值语义：`arena = null`、所有 count/bytes 字段为
   `0usize`、`lifecycle_state = LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED`。
3. 所有 vector 字段必须保持 `native_build_empty_vector()` call surface，不得提前内联成不完整
   placeholder，也不得丢失字段顺序：`functions`、`body_ops`、`core_bodies`、`core_stmts`、
   `core_exprs`、`core_places`、`core_cleanup_edges`、`core_semantic_facts`、`globals`、`types`、
   `interfaces`、`err_unions`、`async_frames`、`drop_defer_plans`、`helpers`、`worklist`。
4. 外层 `entry_index` 必须保持 `-1`，不得改成 `0`。
5. 该切片迁入后 `native_build_lowered_plan_empty()` 必须达到 body complete：
   `native_hosted_reachable_body_complete: function=native_build_lowered_plan_empty prefix_stmts=1 reason=body_complete`。
   下一步必须重新读取真实 self-build frontier。

## `native_build_reachability_empty()` Body Complete Contract

`native_build_lowered_plan_empty()` body complete 后，当前真实 pending frontier 是：

```text
native_hosted_pending_body_frontier: function=native_build_reachability_empty decl=303 function_id=10 body_stmts=1 reason=pending_core_body
```

函数源码：

```text
fn native_build_reachability_empty() NativeBuildReachability {
    return NativeBuildReachability{
        decl_to_function_index: null,
        function_decl_indices: null,
        assigned_count: 0,
        capacity: 0,
    };
}
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须生成单条 `CORE_STMT_KIND_RETURN`，返回表达式保持 `NativeBuildReachability`
   struct literal surface。
2. struct literal 的字段必须保持源码顺序和语义：`decl_to_function_index = null`、
   `function_decl_indices = null`、`assigned_count = 0`、`capacity = 0`；不得省略任一 null
   指针字段，也不得把两个计数字段改成非零。
3. PortableMIR 必须保留 aggregate return surface，返回类型为 `NativeBuildReachability`，不得把
   该 helper 降成 noop 或 pending body。
4. 该切片迁入后 `native_build_reachability_empty()` 必须达到 body complete：
   `native_hosted_reachable_body_complete: function=native_build_reachability_empty prefix_stmts=1 reason=body_complete`。
   下一步必须重新读取真实 self-build frontier。

## `native_build_local_table_empty()` Body Complete Contract

`native_build_reachability_empty()` body complete 后，当前真实 pending frontier 是：

```text
native_hosted_pending_body_frontier: function=native_build_local_table_empty decl=307 function_id=11 body_stmts=1 reason=pending_core_body
```

函数源码：

```text
fn native_build_local_table_empty() NativeBuildLocalTable {
    return NativeBuildLocalTable{
        names: null,
        call_targets: null,
        kinds: null,
        init_values: null,
        static_knowns: null,
        lengths: null,
        count: 0,
        capacity: 0,
    };
}
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须生成单条 `CORE_STMT_KIND_RETURN`，返回表达式保持 `NativeBuildLocalTable`
   struct literal surface。
2. struct literal 的字段必须保持源码顺序和语义：`names = null`、`call_targets = null`、
   `kinds = null`、`init_values = null`、`static_knowns = null`、`lengths = null`、
   `count = 0`、`capacity = 0`；不得省略任一 null 指针字段，也不得把两个计数字段改成非零。
3. PortableMIR 必须保留 aggregate return surface，返回类型为 `NativeBuildLocalTable`，不得把该
   helper 降成 noop 或 pending body。
4. 该切片迁入后 `native_build_local_table_empty()` 必须达到 body complete：
   `native_hosted_reachable_body_complete: function=native_build_local_table_empty prefix_stmts=1 reason=body_complete`。
   下一步必须重新读取真实 self-build frontier。

## `native_build_const_slice_sum_shape_empty()` Body Complete Contract

`native_build_local_table_empty()` body complete 后，当前真实 pending frontier 是：

```text
native_hosted_pending_body_frontier: function=native_build_const_slice_sum_shape_empty decl=311 function_id=12 body_stmts=1 reason=pending_core_body
```

函数源码：

```text
fn native_build_const_slice_sum_shape_empty() NativeBuildConstSliceSumShape {
    return NativeBuildConstSliceSumShape{
        array_decl: null,
        slice_decl: null,
        return_stmt: null,
        add_expr: null,
        left_access: null,
        right_access: null,
        slice_start: 0,
        slice_len: 0,
        left_value: 0,
        right_value: 0,
        sum_value: 0,
    };
}
```

CoreBody/PortableMIR 合同：

1. CoreIR 必须生成单条 `CORE_STMT_KIND_RETURN`，返回表达式保持
   `NativeBuildConstSliceSumShape` struct literal surface。
2. struct literal 的字段必须保持源码顺序和语义：`array_decl = null`、`slice_decl = null`、
   `return_stmt = null`、`add_expr = null`、`left_access = null`、`right_access = null`、
   `slice_start = 0`、`slice_len = 0`、`left_value = 0`、`right_value = 0`、`sum_value = 0`；
   不得省略任一 AST 指针字段，也不得把任一 i32 字段改成非零。
3. PortableMIR 必须保留 aggregate return surface，返回类型为
   `NativeBuildConstSliceSumShape`，不得把该 helper 降成 noop 或 pending body。
4. 该切片迁入后 `native_build_const_slice_sum_shape_empty()` 必须达到 body complete：
   `native_hosted_reachable_body_complete: function=native_build_const_slice_sum_shape_empty prefix_stmts=1 reason=body_complete`。
   下一步必须重新读取真实 self-build frontier。

## `parse_build_args(...)` Scalar Option Frontier Contract

`parse_build_args(...)` root body 已推进到 body complete：

```text
native_hosted_reachable_body_complete: function=parse_build_args prefix_stmts=28 reason=body_complete
```

这表示 root body 已覆盖 option loop、位置输入文件收集和 tail return。早期基础 flag /
scalar option 迁入时使用过 loop-body child frontier；这些历史 frontier 只能作为迁移背景，
不能再作为当前 no-silent-C99 期望：

```text
native_hosted_reachable_loop_body_frontier: function=parse_build_args parent_stmt=23 loop_body_prefix_stmts=2 loop_body_next_stmt=2 loop_body_next_kind=AST_IF_STMT reason=partial_loop_body
```

其中 `parent_stmt=23` 是 `while i < argc`，`loop_body_prefix_stmts=2` 只表示已覆盖
`const arg: *byte = get_argv(i)` 和 `if arg == null`，下一处真实缺口仍是基础 flag / scalar option
的 `else if` 链。当前这些分支已经按切片迁入；`parse_build_args(...)` complete 后，下一步必须
重新运行 self-build frontier，只接受诊断实际报告的下一个 reachable callee 或 body frontier。

`-o` 分支完成后必须报告更深一层的 branch frontier，证明缺参 diagnostic / `return -1`、
`output_file_index[0] = i + 1` 和 `i = i + 1` 已纳入 verifier-clean partial body，下一处缺口
推进到 backend scalar option：

```text
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=2 covered_branch=-o next_branch=--c99 next_kind=AST_IF_STMT reason=partial_else_if_chain
```

backend 标量分支完成后必须继续报告 branch frontier，证明 `--c99` / `--native`
两个 enum out-param 写入已纳入 verifier-clean partial body，下一处缺口推进到
line-directives scalar option：

```text
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=3 covered_branch=backend next_branch=--no-line-directives next_kind=AST_IF_STMT reason=partial_else_if_chain
```

line-directives 标量分支完成后必须继续报告 branch frontier，证明 `--no-line-directives` /
`--line-directives` 的 out-param 写入已纳入 verifier-clean partial body，下一处缺口推进到
safety-proof scalar option：

```text
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=4 covered_branch=line-directives next_branch=--safety-proof next_kind=AST_IF_STMT reason=partial_else_if_chain
```

safety-proof 标量分支完成后必须继续报告 branch frontier，证明 `--safety-proof` /
`--no-safety-proof` 的 out-param 写入已纳入 verifier-clean partial body，下一处缺口推进到
opt-level scalar option：

```text
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=5 covered_branch=safety-proof next_branch=--opt=0 next_kind=AST_IF_STMT reason=partial_else_if_chain
```

opt-level 标量分支完成后必须继续报告 branch frontier，证明 `--opt=0..3` / `-O0..3`
四组 OR 条件和 `opt_level[0]` 写入已纳入 verifier-clean partial body，下一处缺口推进到
`--nostdlib`：

```text
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=6 covered_branch=opt-level next_branch=--nostdlib next_kind=AST_IF_STMT reason=partial_else_if_chain
```

nostdlib 标量分支完成后必须继续报告 branch frontier，证明 `--nostdlib` 的
`is_nostdlib[0] = 1` 写入已纳入 verifier-clean partial body，下一处缺口推进到
`--project-root`：

```text
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=7 covered_branch=--nostdlib next_branch=--project-root next_kind=AST_IF_STMT reason=partial_else_if_chain
```

project-root 缺参子切片完成后必须继续报告 branch frontier，证明 `--project-root`
条件、`i + 1 >= argc`、缺参 diagnostic 和 `return -1` 已纳入 verifier-clean partial
body；此时仍不得把后续参数读取、空参数检查、长度检查或全局写入伪装成完成：

```text
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=8 covered_branch=--project-root-missing-arg next_branch=--project-root-arg-read next_kind=AST_ASSIGN reason=partial_else_if_chain
```

project-root 参数读取子切片完成后必须继续报告 branch frontier，证明 `i = i + 1`、
`const root_arg: *byte = get_argv(i)`、`root_arg == null || root_arg[0] == 0 as byte`、
空参数 diagnostic 和 `return -1` 已纳入 verifier-clean partial body；此时仍不得把
后续 `strlen(root_arg)` / `PATH_MAX` 长度检查或全局写入伪装成完成：

```text
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=8 covered_branch=--project-root-arg-read next_branch=--project-root-length next_kind=AST_VAR_DECL reason=partial_else_if_chain
```

project-root 长度检查子切片完成后必须继续报告 branch frontier，证明
`const root_len: usize = strlen(root_arg)`、`root_len >= PATH_MAX`、路径过长
diagnostic 和 `return -1` 已纳入 verifier-clean partial body；此时仍不得把后续
`strcpy(&g_module_root_override[0] as *byte, root_arg)` 或全局 active 写入伪装成完成：

```text
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=8 covered_branch=--project-root-length next_branch=--project-root-success next_kind=AST_CALL_EXPR reason=partial_else_if_chain
```

project-root 分支完成后必须继续报告 branch frontier，证明 `--project-root` 的缺参
diagnostic、`get_argv(i)` 参数读取、空参数检查、`strlen(root_arg)` / `PATH_MAX`
长度检查、`strcpy(&g_module_root_override[0] as *byte, root_arg)` 和
`g_module_root_override_active = 1` 已纳入 verifier-clean partial body，下一处缺口
推进到 build-seed reject group 的 `--manifest-path`：

```text
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=8 covered_branch=--project-root next_branch=--manifest-path next_kind=AST_IF_STMT reason=partial_else_if_chain
```

build-seed reject group 合同固定 source-order frontier，所有分支都必须保留现有
diagnostic 和 `return -1`，且不得把 seed 拒绝项伪装成 native backend 能力：

1. `--manifest-path`：拒绝并提示通过 `upm build` 解析包 manifest。
2. exec/vm/dump/trace group：`--exec`、`--vm`、`--dump-exec-hir`、`--dump-bytecode`、
   `--trace-vm` 都拒绝并提示 seed 不包含 exec backend。
3. microapp profile group：`--app`、`--microapp-profile`、
   `strncmp("--microapp-profile=", 19)` 都拒绝并提示使用 `uya microapp build ...`。
4. `--outlibc`：拒绝并提示 seed 不包含 `--outlibc` 生成器。

```text
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=9 covered_branch=--manifest-path next_branch=exec-reject next_kind=AST_IF_STMT reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=10 covered_branch=exec-reject next_branch=microapp-reject next_kind=AST_IF_STMT reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=11 covered_branch=microapp-reject next_branch=--outlibc next_kind=AST_IF_STMT reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=12 covered_branch=--outlibc next_branch=--stack-size next_kind=AST_IF_STMT reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=13 covered_branch=--stack-size-arg-read next_branch=--stack-size-digit-loop next_kind=AST_VAR_DECL reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=13 covered_branch=--stack-size-digit-loop next_branch=--stack-size-write next_kind=AST_IF_STMT reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=13 covered_branch=--stack-size next_branch=--async-frame-heap=on next_kind=AST_IF_STMT reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=14 covered_branch=--async-frame-heap=on next_branch=--no-split-c next_kind=AST_IF_STMT reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=15 covered_branch=--no-split-c next_branch=--split-c-dir-inline-disabled next_kind=AST_IF_STMT reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=16 covered_branch=--split-c-dir-inline-disabled next_branch=--split-c-dir-inline-success next_kind=AST_VAR_DECL reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=16 covered_branch=--split-c-dir-inline next_branch=--split-c-dir-separate-disabled next_kind=AST_IF_STMT reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=17 covered_branch=--split-c-dir-separate-disabled next_branch=--split-c-dir-separate-success next_kind=AST_IF_STMT reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=17 covered_branch=--split-c-dir next_branch=positional-input next_kind=AST_VAR_DECL reason=partial_else_if_chain
```

位置输入文件收集合同固定 source-order surface，后续实现切片必须继续保持未知 dash option no-op
的既有语义：只有 `arg[0]` 不是 `45`（`'-'`）时才把该 argv 位置登记为输入文件；未知 dash option
当前保持忽略，不在本合同叶子中改成 error。

1. `arg[0]` / 非 dash 判定：`const c: byte = arg[0]` 和 `c != 45`。
2. 容量检查：`input_file_count[0] >= input_file_capacity`，失败时保留现有
   `错误: 输入文件数量超过最大限制 (%d)` diagnostic 和 `return -1`。
3. index/count 写入：`const idx: i32 = input_file_count[0]`、
   `input_file_indices[idx] = i`、`input_file_count[0] = idx + 1`。

```text
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=18 covered_branch=positional-input-arg next_branch=positional-input-capacity next_kind=AST_IF_STMT reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=18 covered_branch=positional-input-capacity next_branch=positional-input-store next_kind=AST_VAR_DECL reason=partial_else_if_chain
native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=18 covered_branch=positional-input next_branch=parse-tail-input-count next_kind=AST_IF_STMT reason=partial_else_if_chain
```

## `parse_build_args(...)` Tail Output Contract

收尾输出路径检查合同固定 source-order surface，后续实现切片必须继续保持当前 native hosted
self-build 的 no-output / no-silent-C99 语义：在这些 tail 分支全部迁入 CoreBody/PortableMIR
之前，`cmd/build --native` self-build 仍只能以
`native_hosted_portable_mir_lowering_missing` 明确拒绝写出 executable。

1. 无输入文件分支：`input_file_count[0] == 0`、`错误: 未指定输入文件\n` diagnostic、
   `program_name != null`、`print_usage(program_name as &byte)` 和 `return -1`。
2. 显式输出路径读取：`const out_idx: i32 = output_file_index[0]`、`out_idx >= 0`、
   `get_argv(out_idx)`、null 输出路径 diagnostic 和 `return -1`。
3. `.c` 输出推断 C99：`backend_type[0] == BackendType.BACKEND_LLVM`、`strrchr(out_path, 46)`、
   `ext != null && strcmp(ext, ".c" as *byte) == 0` 和 `backend_type[0] = BackendType.BACKEND_C99`。
4. `--native` 输出 `.c` 拒绝：`backend_type[0] == BackendType.BACKEND_NATIVE`、
   `is_c_output(out_path as &byte) != 0`、`错误: --native 不能输出 .c 文件；C 输出请使用 --c99`
   diagnostic 和 `return -1`。
5. 收尾成功：上述检查完成后保留末尾 `return 0`。

末尾 `return 0` 实现后，`parse_build_args(...)` 的 source-order root body 已覆盖 28 条语句并标记
body complete；后续任务必须重跑 self-build frontier，只接受诊断实际报告的下一个 reachable callee：

```text
native_hosted_reachable_body_complete: function=parse_build_args prefix_stmts=28 reason=body_complete
```

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

下一步从 `parse_build_args(...)` 的基础 flag / scalar option frontier 开始。先按上面的 surface audit 补
CoreBody/PortableMIR golden/verifier 合同，再逐段迁入函数体。`compile_files(...)` 16 参数
parser/checker/native-codegen 主调用仍是大型验收样本，但只能在真实 reachable frontier 指向它时进入；它必须通过
CoreBody dump/verifier、PortableMIR function body lowering、hosted native call ABI 和 target capability verifier
到达，不能再通过新增 `RETURN_*`、`LOCAL_CALL_*`、`IF_LOCAL_*` 等 one-off `LoweredBodyOp`
解决。在这之前，不能声明已经生成 native `bin/cmd/build`。`tests/verify_native_cmd_build_no_silent_c99.sh`
必须继续固定该 lowering frontier，确保 native 失败不会静默回落 C99。
