# Native `cmd/build` 子集清单

**状态**: Phase 10 feature inventory  
**更新日期**: 2026-06-07  
**范围**: 统计把 `src/cmd/build/main.uya` 变成 native-built compiler 所需的语言、运行时和宿主能力。

## Evidence Snapshot

当前实测依赖数: 83

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
`checker` / `codegen.c99` 路径。Phase 10 的 native 子集只面向 `cmd/build`，不是完整 `bin/uya` launcher
和全部子命令。

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
| F13 | partial | NativeEmitter 已能读取 LoweredProgram 函数/全局名册，并把 `LoweredBodyOp` body range 导入 MachineModule 的 MachineBlock/MachineInst 动态表；build-only driver 已有 `BACKEND_NATIVE` 入口并保持到代码生成阶段，最小成功子集先降低为 `LoweredBodyOp`，再导入轻量 `MachineModule`，最后由 native build writer 输出 ELF；`tests/verify_native_build_minimal_program.sh` 验证无参/最多两个 `i32` 参数、单 `&i32` / `&array[0]` out-param、两个 `&i32` out-param，以及 `get_argc()` / `get_argv(1)[0]` 函数子集可生成并运行最小 native executable：`return 0..255` 生成常量退出码，`return param;` 经过 `mov eax, edi` 返回第 0 个 SysV 参数，`return param0 + param1;` 经过 `mov eax, edi` 和 `add eax, esi` 消费前两个 SysV 参数寄存器，`return get_argc();` / `const argc = get_argc(); return argc;` 从 Linux 初始栈读取 argc 并以带两个运行参数的退出码 `3` 验证，`const arg = get_argv(1); return arg[0] as i32;` 从 Linux 初始栈 argv 基址读取运行参数 `Zed` 首字节并以退出码 `90` 验证，`return callee()` 经过真实 `call rel32`/`ret` 后退出码匹配，`return lhs() + rhs()` 经过两次 direct call、栈保存和 `add` 后退出码匹配；mini-lowering 已支持多语句扫描、无副作用局部 `var/const` 占位、`const local = zero_arg_call(); return local;` 的 `LOCAL_CALL_I32` / `RETURN_LOCAL_I32` 两步 LoweredProgram，`const local = one_i32_arg_call(imm32); return local;` 的 `LOCAL_CALL_CONST1_I32` 参数寄存器路径，`const local = two_i32_arg_call(imm32, imm32); return local;` 的 `LOCAL_CALL_CONST2_I32` 双参数寄存器路径，以及 `var local: i32 = imm; const status = out_call(&local); return local;` / `var slots: [i32: 1] = []; const status = out_call(&slots[0]); return slots[0];` / `var left/right; const status = out_call(&left, &right); return right;` / `out[0] = imm; return status;` / 双 out-param 写回的 `LOCAL_I32_CONST` / `LOCAL_CALL_ADDR1_I32` / `LOCAL_CALL_ADDR2_I32` / `STORE_PARAM0_CONST_I32` / `STORE_PARAMS01_CONST_I32` 最小写回路径，并检查 `native_machine_function_count` / `native_machine_inst_count`；当前 `src/cmd/build/main.uya --native` 已从 merged AST 以 `main` 为根做 reachable lowering，不再卡在顶层 `use` 或 runtime entry extern；`build_compiler_driver_run` 已越过前 12 个局部声明，首个真实缺口固定为 `const parse_result = parse_build_args(...)` 这种带 11 个参数、多数组/局部 out-param 和多项写回副作用的局部初始化；`tests/verify_native_cmd_build_no_silent_c99.sh` 继续验证不会静默回落 C99，并固定该失败形状 | native emitter 可生成 `bin/cmd/build` |
| F14 | missing | host toolchain/file system bridge 未 native 化；只有最小 syscall encoding | native file IO 和 host C toolchain 调用路径可用 |
| F15 | partial | `tests/test_native_arena_peak_stats.uya` 覆盖 native arena peak snapshot，保留 `arena_peak_bytes` / `ast_arena_peak_bytes` / `check_arena_peak_bytes` / `emit_arena_peak_bytes` 同名字段；table/output/typed program metrics 尚未接入 native-built compiler | native-built compiler 继续输出全部同名 metrics |
| F16 | done | build seed boundary 已排除 VM/exec、`uya microapp build/pack/inspect/verify/run`、fmt/upm、kernel packaging | 后续保持边界验证，避免重新引入非需求 |

## Release Acceptance Boundary

本文件只定义 Phase 10 native `cmd/build` 子集，不定义最终语言完备性。发布验收仍必须满足：

- C99 backend 支持完整 Uya 语言，并与 main 分支语言行为兼容。
- Native backend 支持完整 Uya 语言，并与 C99 / main 分支语言行为兼容。
- Microapp / microcontainer 在语言层面完全兼容 main 分支；限制只能来自 runtime、capability、profile、
  ABI 或镜像格式层，不能变成独立 Uya 方言。

## Next Step

下一项继续按缺口补 native `cmd/build` 子集能力：当前只有 build CLI 的极小函数输出路径；`cmd/build` 自身已经进入 reachable lowering，并已支持无副作用局部声明占位、zero-arg / one-i32-constant-arg / two-i32-constant-arg direct call 局部初始化、`get_argc()` 读取、`get_argv(1)[0]` 首字节读取、`&local` / `&array[0]` out-param 写回、两个 `&i32` out-param 写回和 `return local` / `return array[0]`。下一道真实门槛是支持 `parse_build_args(...)` 这种 11 参数调用、完整 `get_argv` 字符串比较、更多 out-param 写回、条件分支和后续 CLI 控制流。完成这些之前，不能声明已经生成 native `bin/cmd/build`。
