# Uya 任务文档状态总表（todo status index）

**核对日期：** 2026-09-27（对应版本 v0.10.2，提交 `5c20c437`）
**用途：** 仓库里有 40 多份 TODO / 计划 / 路线图文档，历史惯例是"完成项搬到 `*_completed.md`，原文不回填"，
导致**原文里的未勾选条目经常不代表未完成**。本表用于把"真实剩余工作"和"已过期文档"分开，避免下一轮误判。
**核对方法：** 以当前工作树、测试与实测命令为准（`git log` 看文档最后更新、`grep` 找实现、跑验证脚本），不以文档自述状态为准。

---

## A. 真实剩余工作（已核对，需要继续做）

| 工作流 | 剩余内容 | 证据与位置 | 规模 |
|---|---|---|---|
| **macOS / Windows 平台层** | macOS 的 async / syscall / pthread 运行时对等；Windows 运行时层（当前只有交叉编译 flag） | `tests/run_programs_parallel.sh:1019` 起 macOS 默认跳过 `test_async_*`/`test_std_async_*`/`test_pthread*` 及约 40 个 Linux-centric 用例；`lib/std/async_event.uya` 无 kqueue；仓库无 `std/os` 级 Windows 层 | 大 |
| **async 跨平台与协议层** | ① kqueue/IOCP 后端 ② 多 interest `Waker`（`lib/std/async.uya` 的 `Waker` 仍单 `_io_fd`/`_io_interest`）③ HTTP 客户端连接池 / keep-alive 复用 ④ TLS 会话复用 + `https_handshake_async` pending/ready 回归 ⑤ HTTP/1 请求头 inline 容量（`lib/std/http/http1_async.uya:35`） | `docs/todo_async_full_language_dynamic_resources.md` 核对头；`docs/async_status_matrix.md` 剩余 P2；`docs/async_production_todo.md` P2 | 大 |
| **UyaGin P7 验收 / P8 文档** | P7 正式口径（5 场景 × 5 run + syscall/CPU probe + 原始报告）从未产出；P8 的 API 文档 / 迁移指南 / 示例 / 压测报告未开始 | `docs/uyagin_todo.md`；唯一带 Gin 对照的 smoke 是 `build/uyagin_http_bench/20260627_063210`（runs=1、单场景、ratio 2.17）；运行时门禁 `tests/verify_uyagin_http_bench_runtime.sh` 现已通过 | 中 |
| **编译器入口瘦身** | `src/main.uya`（3902 行）中的 `CommandType`/`parse_args`/`print_usage`/build-run-test 共享流程尚未提取到 `src/compiler_driver.uya`（不存在） | `docs/todo_cmd_subcommand_split.md`；已落地部分：`src/cmd/build`、`src/cmd/upm`、`src/driver/{modules,toolchain}.uya` | 中 |
| **exec / bytecode 后端补齐** | async/`@await`、`@frame`、`@c_import` 接入、SIMD、inline asm、非 hosted 目标、native JIT，以及 `uya run --exec` 稳定性与提速目标 | `docs/todo_bytecode_exec.md`；已落地 `src/exec/*`（vm/hir/lower/builder/frame/value/debug） | 大 |
| **std.script 替换仓库 shell** | 183 个 `.sh`、132 个 B 类候选，仓库现有 `.ush` 文件 **0** 个，迁移未开始 | `docs/todo_std_script.md`、`docs/std_script_shell_inventory.md` | 大 |
| **typed pipeline：Windows hosted 后端 + 文档** | 阶段 8 全部（`CreateProcessW`/Job Object/handle allowlist/capture/UTF-8 bridge/Windows smoke）；阶段 9 文档（grammar、示例、迁移说明、已知限制） | `docs/todo_typed_pipeline.md` 核对头；Linux 侧已端到端（`RELEASE_v0.10.2`） | 大 |
| **microcontainer 共享库** | 共享库（`.so`/dylib）产出路径与测试完全未实现（124 项未勾） | `docs/microcontainer/shared_library_todo.md` 核对头；`src/`、`lib/`、`Makefile` 无相关目标 | 大 |
| **microcontainer 可移植 native** | M1/M2 已部分落地（`make microapp-*` 与 macOS CI 有 aarch64/macOS 运行时检查），剩余项见清单（27 项未勾，未逐条回填） | `docs/microcontainer/portable_native_todo.md` 核对头 | 中 |
| **HTTP/3 与 HTTP/2 WebSocket transport** | QUIC/HTTP/3 未实现；RFC 8441 extended CONNECT 的 stream adapter 未落地（HTTP/2 frame/stream/HPACK 基础栈已在） | `docs/std_http_websocket_http2_http3_route.md`、`docs/todo_http_websocket.md` 核对头 | 大 |
| **1.0 语法锁定** | T2（`try`/`catch` 语义收敛 + 三个指定负例/正例测试缺失）、T4（闭包"不做"契约写入 `uya.md`/`readme.md`）、T5（canonical Future 形式、`@await`+`catch` 多语句 lowering）、T6（stdlib 手写状态机收编）；T3 宏卫生**代码已完成**、`uya.md` §25.2.2 已写，仅剩 `grammar_formal.md` 引用与文档状态回填 | `docs/goal_v1_lockdown.md`（6 项仅 1 项已勾，自述"未全部完成不得收口"）；`tests/error_try_catch_combined.uya`、`tests/test_catch_multistmt_block.uya`、`tests/test_async_await_catch_multistmt.uya` 均不存在 | 中 |
| **可选优化尾巴** | `todo_json`（`@vector`/`@asm` 快路径选路与基准）、`todo_yaml`（基准、错误位置）、`todo_protobuf`（泛型 `decode<T>`/宏，文档自称延后）、`tls_https_todo`（清理临时占位）、`tls_todo`（README 说明）、`libc_todo`（性能基准、POSIX 层、Windows）、`fmt_phase4`（stdin 与 `-s/-r` 组合不支持）、`tflm_uya_todo`（TFLite 对比测试等 3 项可选） | 各文件未勾选条目 | 小 |

---

## B. 已归档 / 已过期（文档未回填，不要再按原文判断进度）

| 文档族 | 现状 | 证据 |
|---|---|---|
| `docs/ASM_*`（14 份） | `@asm` 全链路已完成 | `src/parser/primary.uya`、`src/checker/check_expr.uya`、`src/codegen/c99/*`；20+ 个 `tests/error_asm_*.uya`、`tests/bench_asm_*.uya`、`tests/run_asm_tests.sh`；`ASM_TODO.md` 头部自述"项目完成" |
| `docs/REFACTOR_*`（6 份） | 阶段 1–3 已完成（目录化拆分）；**阶段 4 Union 化不适用**（Uya 无 union 特性，字段扁平化即设计） | `src/checker/`（20 文件）、`src/parser/`、`src/codegen/c99/`；`src/ast.uya` 顶部注释 |
| `docs/todo_c_import.md` | 已实现 | lexer 白名单、`src/parser/declarations.uya`、`src/checker/*`、提交 `fba37b65`、8 个 `tests/*c_import*` + 2 个 verify 脚本 |
| `docs/todo_static_method.md` | 主线已完成（文件自述 + 9 个测试） | `tests/*static_method*.uya` |
| `docs/todo_function_reachability.md` | 重构已落地 | `src/checker/check_call.uya`（`checker_record_reachable_call`）、`src/codegen/c99/main.uya`（`should_emit_top_level_function_decl`） |
| `docs/extern_var_impl_plan.md` | 任务清单指向已退役的 `compiler-c/` | `@extern_var` 已在 `src/` 落地；`AGENTS.md` 禁止回到 `compiler-c/` |
| `docs/libc_progress.md` | 多项"待办"已落地 | `lib/std/core/option.uya`、`io/writer.uya`、`collections/vec.uya`、`mem/heap.uya`；`lib/libc/pthread.uya` 的 `CLONE_FLAGS`/`set_tid_address` |
| `docs/pthread_nptl_todo.md` | 89 项未勾多为书写形式，能力已推进 | 同上；`tests/stress_pthread.sh` 现已通过（本轮修复 hosted `ETIMEDOUT` 宏冲突后） |
| `docs/todo_mini_to_full.md` | 2026-05 历史路线图，多项已落地 | `uya build/run/test`、原子类型、nostdlib、`std.*` 模块、`test "name" {}` 格式 |
| `docs/todo_multiplatform_migration.md` | 所列三条"当前事实"已过时 | `src/driver/toolchain.uya`、`make uya-hosted`/`b-hosted`、`.github/workflows/macos-ci.yml`、`tests/verify_std_path_platform_targets.sh` |
| `docs/fmt_development_plan.md` + `fmt_phase1..4` | `uya fmt` 已落地，phase 文档 "Not started" 过时 | `src/main.uya` 的 `COMMAND_FMT`、`src/fmt.uya`（1100+ 行）、十余个 `tests/test_fmt_*.uya` |
| 已全部勾完（0 项未勾） | `todo_embed`、`todo_package_management`、`upm_todolist`、`macos_porting_todo`、`mvp_scenarios`、`todo_async_loop_await`、`todo_async_frame_allocation`、`plan_async_coroutine_transform`、`naked_function_design`、`todo_platform_shared_foundation` | 文件内勾选状态 |
| `docs/releases/TODO_v0.9.5.md` | 对应 0.9.5 发版收口的临时清单，当前主线已到 0.10.2 | 文件头部日期 2026-04-23 |

---

## C. 尚未逐条核对（引用前请自行核对）

以下文档含未勾选条目，但本轮没有逐条回代码验证，**不要直接当作待办清单**：

- `docs/todo_https_client_stdlib.md`（204 项，已有 `_completed.md` 归档）
- `docs/std_net_dns_todo.md`（25 项）
- `docs/upm_todolist_by_file.md`（22 项）
- `docs/todo_malloc_perf.md`（3 项，已有 `_completed.md` 与 `_failed.md`）
- `docs/todo_std_refactor.md`、`docs/syscall_design.md`、`docs/cmd_subcommand_split_design.md`
- `docs/CHANGELOG_v0.5.x.md`、`docs/number_literals_enhancement.md` 等历史文档中的复选框

---

## D. 验证闸门实测状态（2026-09-27，本轮）

| 命令 | 结果 |
|---|---|
| `tests/verify_async_shared_runtime_matrix.sh` | ✅ 通过 |
| `tests/verify_async_production_smoke.sh` | ✅ 通过（full-language + shared runtime + nested future + cancel cleanup） |
| `tests/verify_uyagin_http_bench_runtime.sh` | ✅ 通过（`threads=4`，2026-04 的 multi-shard SIGSEGV 不复现） |
| `tests/verify_async_full_dynamic_resources_gate.sh unit-scan` | ✅ 通过 |
| `tests/stress_pthread.sh 1` | ✅ 通过（本轮修复 hosted `ETIMEDOUT` 宏名冲突后由必挂转为通过） |
| `tests/verify_async_full_dynamic_resources_gate.sh all` | ⚠️ `c99-stress` 段含长压测（默认 100 轮 / 1800s HTTP），未在本轮跑完整口径 |

> 维护约定：修改本表或给 TODO 文档加状态时，请注明核对日期与证据（文件:行号 / 提交 / 实测命令），
> 并把已完成部分迁入对应的 `*_completed.md`，避免原文复选框与现状再次脱节。
