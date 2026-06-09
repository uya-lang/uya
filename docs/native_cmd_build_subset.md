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
| F13 | partial | NativeEmitter 的历史 `LoweredProgram -> MachineModule` 窄子集仍只作为 freestanding build-seed 回归边界；hosted native 主线已经转到 CoreBody/PortableMIR preflight。`tests/verify_native_build_minimal_program.sh` 继续验证无参/最多两个 `i32` 参数、单/双 out-param、`get_argc()`、`get_argv(1)[0]`、条件返回/赋值、`set_process_stack_limit_bytes(...)` syscall 和 `parse_like(...)` 11 参数写回等旧窄 executable 子集不回归；`tests/verify_native_cmd_build_compiler_regressions.sh` 用 `bin/cmd/build --native --nostdlib` 覆盖泛型 identity、local array out-param、stack-limit call 和 compiler-like parse out-param regression 组；`tests/verify_native_cmd_build_c99_output_parity.sh` 用 `bin/cmd/build` 生成 C99 output，并与 C99-built `bin/uya` oracle 做归一化输出和运行结果比对。当前 `src/cmd/build/main.uya --native` self-build 门禁不再使用 `--nostdlib` 或 `compile_files(...)` one-off 形状，而是以 hosted 路径解析/检查 91 个依赖后进入 verifier-clean CoreIR/PortableMIR preflight；实测 frontier 为 `native_hosted_entry_frontier: wrapper_covered=1 first_pending_callee=build_compiler_driver_run first_pending_callee_prefix=1 first_pending_callee_prefix_stmts=39 first_pending_callee_next_stmt=-1 first_pending_callee_next_kind=<none>`，已覆盖 `build_compiler_driver_run` 的顶层入口前缀至末尾 `return 0`，包括 `parse_build_args(...)`、输出路径选择、`compile_files(...)` result、native 成功返回、C 输出检测分支入口、链接输出分支入口和最终返回；链接输出分支内部 nested frontier 为 `native_hosted_entry_child_frontier: first_pending_callee=build_compiler_driver_run parent_stmt=37 child_prefix=1 child_prefix_stmts=7 child_next_stmt=-1 child_next_kind=<none>`，已覆盖 `const c_file: &byte = artifacts.generated_c_path`、`var output: &byte = "a.out" as *byte`、`if user_output_path != null` 条件入口、`const link_result: i32 = link_with_toolchain(...)` 初始化、`if link_result != 0` 错误分支条件入口、链接输出分支内部成功 `fprintf(...)` 和 `return 0`，链接输出子块内部已无下一条 child frontier。entry complete 后的下一层 reachable body frontier 固定为 `native_hosted_reachable_body_frontier: function=parse_build_args prefix_stmts=24 next_stmt=24 next_kind=AST_IF_STMT reason=partial_core_body`，证明 `parse_build_args(...)` 已覆盖到 option loop 骨架、`get_argv(i)` null diagnostic 和循环尾递增，下一步从基础 flag/scalar option 分支继续。handoff 现在固定为 `native_hosted_handoff_frontier: reason=pending_core_bodies ... entry_callee_coverage=complete entry_child_coverage=complete`，继续输出 `native_hosted_emitter_handoff: status=rejected reason=pending_core_bodies request_verified=1 backend=machine link_plan=complete ... entry_child_coverage=complete`，并通过 `native_hosted_emitter_import_preflight: status=ready imported_functions=482 imported_blocks=39 imported_insts=55 ...` 和 `native_hosted_emitter_output_preflight: status=ready output_matches_request=1 output_kind=machine_module machine_functions=482 ...` 证明 verified partial MIR 已进入 `NativeMirEmitter` import preflight 和 `MirTargetBackendOutput` payload；最终仍后接 `native_hosted_portable_mir_lowering_missing`，且不生成伪 native 输出、不回落 C99。 | hosted PortableMIR body lowering 接入真实 emitter/handoff 后，再生成 native `bin/cmd/build` |
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
  `native_hosted_reachable_body_frontier: function=parse_build_args prefix_stmts=27 next_stmt=27 next_kind=return reason=partial_core_body`、
  `native_hosted_handoff_frontier: reason=pending_core_bodies ... entry_callee_coverage=complete entry_child_coverage=complete`、
  `native_hosted_emitter_handoff: status=rejected reason=pending_core_bodies request_verified=1 backend=machine link_plan=complete ... entry_child_coverage=complete`、
  `native_hosted_emitter_import_preflight: status=ready imported_functions=482 imported_blocks=39 imported_insts=55 ...`、
  `native_hosted_emitter_output_preflight: status=ready output_matches_request=1 output_kind=machine_module machine_functions=482 ...` 和
  `native_hosted_portable_mir_lowering_missing`。
  不再把 `compile_files(...)` 16 参数缺口固定为 `--nostdlib` freestanding one-off shape。
- native `bin/cmd/build` 仍是 freestanding build-seed 里程碑，不是 hosted native 完整语言 parity 的前置条件。

## `parse_build_args(...)` PortableMIR Surface Audit

当前 reachable body frontier 是 `build_compiler_driver_run` 第 12 条语句调用到的
`parse_build_args(...)`。该函数必须按源码顺序迁入 CoreBody/PortableMIR；不能用摘要、专用
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

## `parse_build_args(...)` Scalar Option Frontier Contract

当前 root body frontier 已推进到收尾输出路径读取入口：

```text
native_hosted_reachable_body_frontier: function=parse_build_args prefix_stmts=27 next_stmt=27 next_kind=return reason=partial_core_body
```

这表示 root body 已覆盖到 option loop 和无输入文件分支的 partial stub；它不能被当成
整个 tail body 已完成。早期基础 flag / scalar option 迁入时使用过 loop-body child frontier，
后续 tail 分支必须继续按源码顺序推进：

```text
native_hosted_reachable_loop_body_frontier: function=parse_build_args parent_stmt=23 loop_body_prefix_stmts=2 loop_body_next_stmt=2 loop_body_next_kind=AST_IF_STMT reason=partial_loop_body
```

其中 `parent_stmt=23` 是 `while i < argc`，`loop_body_prefix_stmts=2` 只表示已覆盖
`const arg: *byte = get_argv(i)` 和 `if arg == null`，下一处真实缺口仍是基础 flag / scalar option
的 `else if` 链。后续 `-o`、backend、line-directives、safety-proof、opt-level 和 `--nostdlib`
每个切片都必须推进这个 child frontier 或更深的 branch frontier；直到整个 while body 完整前，
不得借 root body prefix 宣称 `parse_build_args(...)` complete。

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

显式输出路径读取实现后，当前 frontier 固定在末尾 `return 0`，后续实现叶子必须继续完成 `out_idx`
分支内部的 `.c` 输出推断和 native `.c` 拒绝：

```text
native_hosted_reachable_body_frontier: function=parse_build_args prefix_stmts=27 next_stmt=27 next_kind=return reason=partial_core_body
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
