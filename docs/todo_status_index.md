# Uya 任务文档状态总表（todo status index）

**核对日期：** 2026-10-19（对应版本 v0.10.4，提交 `415545a4`）
**用途：** 仓库里有 40 多份 TODO / 计划 / 路线图文档，历史惯例是"完成项搬到 `*_completed.md`，原文不回填"，
导致**原文里的未勾选条目经常不代表未完成**。本表用于把"真实剩余工作"和"已过期文档"分开，避免下一轮误判。
**核对方法：** 以当前工作树、测试与实测命令为准（`git log` 看文档最后更新、`grep` 找实现、跑验证脚本），不以文档自述状态为准。

> 本轮（2026-10-19）是文档同步：逐条回代码核对**实现是否存在**，未重新执行全量 `make check`；
> D 节保留最近一次实测结论并标注日期，引用前请按当前工作树复跑。

---

## A. 真实剩余工作（已核对，需要继续做）

| 工作流 | 剩余内容 | 证据与位置 | 规模 |
|---|---|---|---|
| **macOS / Windows 平台层** | macOS：kqueue async 后端与 Darwin `@syscall` / libc bridge 已落地，但 `tests/run_programs_parallel.sh` 在 macOS 上仍默认跳过 `test_async_*` / `test_std_async_*` / `test_pthread*` 及一批 Linux-centric 用例（`SKIP_DARWIN_DEFAULT`），真机全量闭环未完成。Windows：v0.10.4 已用 zig cc 打通交叉自举（Winsock / 控制台代码页 / LLP64），但 Windows async 后端（IOCP）与 Windows hosted typed pipeline 仍未实现 | `lib/std/async_event.uya`（kqueue 常量与后端）、`tests/run_programs_parallel.sh` 的 macOS SKIP 列表、提交 `53deabe3` / `90d854a7` / `b6abecd9` / `a5dec366` | 中 |
| **async 协议层尾巴** | 已落地：kqueue、多 interest `Waker`、HTTP/1 客户端连接池 + keep-alive、TLS 1.2 会话复用、HTTP/1 请求/响应头按需增长（不再固定 8 KiB）。仍未实现：IOCP 后端、HTTP/3 / QUIC、RFC 8441 extended CONNECT stream adapter | `lib/std/async.uya`（多槽 Waker）、`lib/std/http/http1_async.uya`（`HTTP1_ASYNC_REQUEST_HEADER_INLINE_CAP` / `HTTP1_ASYNC_RESPONSE_HEADER_MAX_CAP`）、提交 `2bfeb487` / `9bb39dee` / `56b5b153` | 中 |
| **UyaGin P7 验收 / P8 文档** | P7 正式口径（5 场景 × 5 run + syscall/CPU probe + 原始报告）仍未产出：`build/uyagin_http_bench/*/report.json` 全部 `runs=1`、场景数 ≤ 2（最近 `20260627_084906`）。P8 的 API 文档 / 迁移指南 / 示例 / 压测报告未开始 | `docs/uyagin_todo.md`；`build/uyagin_http_bench/` 实测；运行时门禁 `tests/verify_uyagin_http_bench_runtime.sh` 存在 | 中 |
| **编译器入口瘦身** | `src/main.uya`（3912 行）中的 `CommandType` / `parse_args` / `print_usage` / build-run-test 共享流程尚未提取；已落地 `src/cmd/{build,upm}`、`src/driver/{modules,path_list,toolchain}.uya` | `src/main.uya:96`、`:1067`、`:1679`；`docs/todo_cmd_subcommand_split.md` | 中 |
| **exec / bytecode 后端补齐** | async / `@await` 明确不支持（`src/exec/lower.uya:5633` 返回 `EXEC_UNSUPPORTED_ASYNC`），`@frame`、`@c_import` 直接接入、SIMD、inline asm、非 hosted 目标、native JIT 仍未做；`docs/todo_bytecode_exec.md` 12 项未勾 | `src/exec/`（9 个文件）、`docs/todo_bytecode_exec.md` | 大 |
| **std.script 替换仓库 shell** | 仓库现有 `.sh` **198** 个、`.ush` **0** 个（2026-10-19 `find` 实测），迁移未开始 | `docs/todo_std_script.md`、`docs/std_script_shell_inventory.md` | 大 |
| **typed pipeline：Windows hosted 后端 + 文档** | `docs/todo_typed_pipeline.md` 仍有 61 项未勾：阶段 8（`CreateProcessW` / Job Object / handle allowlist / capture / UTF-8 bridge / Windows smoke）与阶段 9 文档（示例、迁移说明、已知限制）未完成；Linux 侧已端到端 | `docs/todo_typed_pipeline.md`；Linux 侧见 `RELEASE_v0.10.2`、`src/parser/expressions.uya:842`、`tests/test_typed_pipeline_*.uya` | 大 |
| **microcontainer 共享库** | 共享库（`.so` / dylib）产出路径与测试完全未实现（124 项未勾），`Makefile` 无相关目标 | `docs/microcontainer/shared_library_todo.md`；`Makefile` 无 shared 目标 | 大 |
| **microcontainer 可移植 native** | 部分落地（`make microapp-*` 与 macOS CI 有 aarch64 / macOS 运行时检查），剩余 27 项未勾，未逐条回填 | `docs/microcontainer/portable_native_todo.md` | 中 |
| **HTTP/3 与 HTTP/2 WebSocket transport** | QUIC/HTTP/3 未实现；`lib/std/http/websocket_http2_h3_route.uya` 只是路由占位；RFC 8441 extended CONNECT 的 stream adapter 未落地（HTTP/2 frame/stream/HPACK 基础栈已在） | `lib/std/http/websocket_http2_h3_route.uya`、`docs/std_http_websocket_http2_http3_route.md`、`docs/todo_http_websocket.md` | 大 |
| **1.0 语法锁定** | `docs/goal_v1_lockdown.md` 多数条目未勾：T2（`try`/`catch` 语义收敛）、T4（闭包"不做"契约）、T5（canonical Future、`@await`+`catch` 多语句 lowering）、T6（stdlib 手写状态机收编）仍未完成；三个指定测试 `tests/error_try_catch_combined.uya`、`tests/test_catch_multistmt_block.uya`、`tests/test_async_await_catch_multistmt.uya` 均不存在。T3 宏卫生：代码已实现（`src/checker/macro_expand.uya` 的 `macro_ctx_has_hygiene`），`docs/uya.md` §25.2.2 已写，`tests/test_macro_hygiene.uya` 存在 | `docs/goal_v1_lockdown.md`；`src/checker/macro_expand.uya:957`；`docs/uya.md:5919` | 中 |
| **可选优化尾巴** | `todo_json`（`@vector`/`@asm` 快路径与基准）、`todo_yaml`（基准、错误位置）、`todo_protobuf`（泛型 `decode<T>`/宏）、`tls_https_todo`（清理临时占位）、`tls_todo`（README 说明）、`libc_todo`（性能基准、POSIX 层、Windows）、`fmt_phase4`（stdin 与 `-s/-r` 组合不支持）、`tflm_uya_todo`（TFLite 对比测试等可选项） | 各文件未勾选条目 | 小 |

---

## B. 已归档 / 已过期（文档未回填，不要再按原文判断进度）

| 文档族 | 现状 | 证据 |
|---|---|---|
| `docs/ASM_*`（14 份） | `@asm` 全链路已完成 | `src/parser/primary.uya`、`src/checker/check_expr.uya`、`src/codegen/c99/*`；`tests/error_asm_*.uya`、`tests/bench_asm_*.uya`、`tests/run_asm_tests.sh`；`ASM_TODO.md` 头部自述"项目完成" |
| `docs/REFACTOR_*`（6 份） | 阶段 1–3 已完成（目录化拆分）；阶段 4 Union 化未执行（属重构取舍，与语言是否支持 union 无关——Uya 已有 `union`，见 `docs/uya.md` §4.5） | `src/checker/`、`src/parser/`、`src/codegen/c99/`；`src/ast.uya` 顶部注释 |
| `docs/todo_c_import.md` | 已实现 | lexer 白名单、`src/parser/declarations.uya`、`src/checker/*`、8 个 `tests/*c_import*` + 2 个 verify 脚本 |
| `docs/todo_static_method.md` | 主线已完成 | 文件自述 + 9 个 `tests/*static_method*.uya` |
| `docs/todo_function_reachability.md` | 重构已落地 | `src/checker/check_call.uya`（`checker_record_reachable_call`）、`src/codegen/c99/main.uya`（`should_emit_top_level_function_decl`） |
| `docs/extern_var_impl_plan.md` | 任务清单指向已退役的 `compiler-c/`；`@extern_var` 已在 `src/` 落地 | `src/` 实现；`AGENTS.md` 禁止回到 `compiler-c/` |
| `docs/libc_progress.md` | 多项"待办"已落地 | `lib/std/core/option.uya`、`io/writer.uya`、`collections/vec.uya`、`mem/heap.uya`；`lib/libc/pthread.uya` 的 `CLONE_FLAGS` / `set_tid_address` |
| `docs/pthread_nptl_todo.md` | 89 项未勾多为书写形式，能力已推进；另修了 `pthread_join` 早释放线程栈导致的 SIGSEGV（`d8201b4a`） | 同上；`tests/stress_pthread.sh` |
| `docs/todo_mini_to_full.md` | 2026-05 历史路线图，多项已落地 | `uya build/run/test`、原子类型、nostdlib、`std.*` 模块、`test "name" {}` 格式 |
| `docs/todo_multiplatform_migration.md` | 所列"当前事实"已过时（Windows 目标已打通、macOS 有 CI 与种子） | `src/driver/toolchain.uya`、`make uya-hosted` / `b-hosted`、`.github/workflows/macos-ci.yml`、`tests/verify_std_path_platform_targets.sh` |
| `docs/fmt_development_plan.md` + `fmt_phase1..4` | `uya fmt` 已落地，phase 文档 "Not started" 过时 | `src/main.uya` 的 `COMMAND_FMT`、`src/fmt.uya`、`tests/test_fmt_*.uya` |
| 已全部勾完（0 项未勾） | `todo_embed`、`todo_package_management`、`upm_todolist`、`mvp_scenarios`、`todo_async_loop_await`、`todo_async_frame_allocation`、`plan_async_coroutine_transform`、`naked_function_design`、`todo_platform_shared_foundation` | 文件内勾选状态 |
| `docs/macos_porting_todo.md` | 19 项复选框**全部未勾**，但其中 macOS 自举入口（`make from-c-native`）、hosted 种子家族（`backup/uya-hosted-macos*.c`）、macOS CI 与 kqueue 后端均已落地；`stat` bridge 仍走 `uya_macos_native_stat_call` mirror，与本清单原设想的「直接使用系统 `struct stat`」不同。引用时按实现而非复选框判断 | `backup/uya-hosted-macos*.c`、`.github/workflows/macos-ci.yml`、`lib/std/async_event.uya`、`src/codegen/c99/main.uya:2945-3136` |
| `docs/releases/TODO_v0.9.5.md` | 对应 0.9.5 发版收口的临时清单，主线已到 0.10.4 | 文件头部日期 2026-04-23 |

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

## D. 验证闸门实测状态（最近一次：2026-09-27，v0.10.2；本轮文档同步未复跑）

| 命令 | 结果 |
|---|---|
| `tests/verify_async_shared_runtime_matrix.sh` | ✅ 通过 |
| `tests/verify_async_production_smoke.sh` | ✅ 通过（full-language + shared runtime + nested future + cancel cleanup） |
| `tests/verify_uyagin_http_bench_runtime.sh` | ✅ 通过（`threads=4`） |
| `tests/verify_async_full_dynamic_resources_gate.sh unit-scan` | ✅ 通过 |
| `tests/stress_pthread.sh 1` | ✅ 通过 |
| `tests/verify_async_full_dynamic_resources_gate.sh all` | ⚠️ `c99-stress` 段含长压测（默认 100 轮 / 1800s HTTP），未跑完整口径 |

> 维护约定：修改本表或给 TODO 文档加状态时，请注明核对日期与证据（文件:行号 / 提交 / 实测命令），
> 并把已完成部分迁入对应的 `*_completed.md`，避免原文复选框与现状再次脱节。
