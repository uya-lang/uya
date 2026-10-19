# 类型化管道 TODO

> **核对头（2026-10-19）**：Linux/POSIX 侧已端到端落地（见 `docs/releases/RELEASE_v0.10.2.md` 与 `docs/todo_typed_pipeline_completed.md` 归档）。本轮把"验收标准"按测试逐条回填，并重新确认剩余项：
>
> **已确认完成的阶段**（每条给出证据，详见下方条目内的行内注）：
> - 阶段 0 / 3 / 7（facade）：解析在 `src/parser/expressions.uya:842`（`parser_parse_pipeline_expr`，`pipeline_expr = or_expr { '|>' postfix_expr }`），checker 在 `src/checker/check_expr_extra.uya`（`checker_check_pipeline_expr_impl` 等），`Pipeline` 为 `lib/std/process.uya:2609` 的 `export opaque struct`，facade 为 `lib/std/script/file.uya`（20 导出）。
> - 阶段 9 的**文档部分**已完成：`|>` 的 BNF 在 `docs/grammar_formal.md:275-276`；用户文档与示例在 `docs/uya.md` §10.1（`|>` 运算符表 `:3970`、类型规则 7 条、正例/反例）。
>
> **仍未完成（真实剩余项）**：
> 1. **阶段 8：Windows hosted 后端**——`CreateProcessW`、Job Object 取消、handle allowlist、capture、UTF-8/UTF-16 bridge、Windows smoke 等，全部未实现（`grep -rln "CreateProcessW\|CreateJobObject\|AssignProcessToJobObject" lib/ src/` 无命中；`lib/std/process.uya` 的 `tos_windows` 只出现在路径校验 `:858`/`:879`）。
> 2. **阶段 9 剩余**：迁移说明（用 typed pipeline 替代 `system("a | b")`）仍散落在 `typed_pipeline_design.md` 的非目标/原则段，没有独立迁移章节；**已知限制章节未写**（无 shell globbing / 无命令替换 / `cmd` vs `cmd_path` 差异 / capture 限制 / 平台后端状态这 5 条目前分散在 `typed_pipeline_design.md:61-63`、`:268`、`:399-410`）。
> 3. **阶段 7 剩余**：`.ush` 迁移脚本仍为 0（`docs/todo_std_script.md` 核对头），因此"把一个简单 `.ush` 验证脚本从 `system("... | ...")` 迁移出去"与"添加与旧 shell 命令并列的行为 oracle"无从开始。
>
> 伸缩口径：Windows 后端是独立大项，应先确认 Windows 运行时层（`std/os` 级）是否在路线图上，再决定是否启动。

**状态**：可执行 TODO，规划中
**更新日期**：2026-07-10
**配套设计**：[`typed_pipeline_design.md`](typed_pipeline_design.md)
**相关设计**：[`std_script_design.md`](std_script_design.md)

## 定位

类型化管道为 `.ush` 脚本提供 shell 管道之外的结构化替代方案。它应建立在 `std.process` 和宿主抽象工作之上，而不是变成另一套 shell 实现。

实现应按小阶段推进。第一个可用里程碑应能在没有 shell 字符串的情况下运行简单 argv 管道；自定义 Uya 流 stage 可以在 process-only 管道稳定后再跟进。

## 阶段 0：规格锁定

## 阶段 3：Lowering

## 阶段 7：Script Facade 集成

- [x] 在脚本文档中添加示例。（2026-10-19：`docs/uya.md` §10.1 已有正例/反例；`docs/typed_pipeline_design.md` 有完整 transformer/sink 示例）
- [ ] 将一个简单 `.ush` 验证脚本从 `system("... | ...")` 迁移出去。（**阻塞**：仓库 `.ush` 文件数为 0）
- [ ] 添加与旧 shell 命令并列的行为 oracle。（同上，无 `.ush` 可对照）
- [x] 保持显式 shell fallback API 独立且命名清晰。（实现未提供任何 shell fallback：`Pipeline` 只有 argv 入口 `cmd_argv` / `cmd_path_argv`，无 `system_string` 类 API）

## 阶段 8：Windows Hosted 后端

- [ ] 将 process stage 映射到 `CreateProcessW`。
- [ ] 每次执行先创建用于显式取消的 Job Object；默认 direct-stage 模式不设置 `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`，避免正常关闭 handle 隐式终止非直接后代。
- [ ] 在首个 CreateProcess 前完成 pipe、每个 file-redirection policy 的单次 parent-side `CreateFileW` 和严格 handle allowlist；group stderr handle 由全部 stage 共享，最后一个继承者创建后关闭 parent 副本。
- [ ] child 使用 `CREATE_SUSPENDED` 创建，成功 `AssignProcessToJobObject` 后才允许恢复执行；全部 child 入 job、parent 关闭所有 child-only/capture-writer handle 后逐个恢复所有 primary thread，成功 resume 是 Windows 执行释放边界。
- [ ] 分别跟踪 `created_unassigned`、`assigned_suspended`、`resumed`；创建、assignment 或 resume 失败时对未入 Job child 调用 `TerminateProcess`，对已入 Job child 调用 `TerminateJobObject`，等待全部 direct process 后再关闭 handle；未 resume stage 为 `not_started`，已 resume 但被终止的 stage 为 `cancelled`。
- [ ] 为 pipe 实现 handle 继承/复制，并通过 `PROC_THREAD_ATTRIBUTE_HANDLE_LIST` 或等价严格 allowlist 防止无关 child 继承多余 pipe 端。
- [ ] capture 超限和部分启动失败使用 `TerminateJobObject` 或等价整组终止；宿主 job policy 不允许 assignment 时必须在 child 恢复前稳定失败。
- [ ] console-control callback 只通知 runtime broker；正常 executor 路径终止 Job、清理并返回 `error.Interrupted`。
- [ ] Windows console broker 对并发 sink 使用安全订阅表并广播 process-directed cancellation，注销后 callback 不得访问已释放 execution state。
- [ ] Windows wait 结果把完整 `GetExitCodeProcess` `DWORD` 保存为公共 `u32 exit_code`，覆盖高位为 1 的退出码。
- [ ] 在不假设 POSIX fd 的情况下实现 stdout/stderr capture。
- [ ] 使用 UTF-8 公共 API 和 UTF-16 bridge 实现 cwd/env 转换。
- [ ] Windows env overlay 以 ordinal case-insensitive key 规则去重，最后 spelling/value 获胜，最终 UTF-16 environment block 同序排序并双 null 结尾。
- [ ] 明确 argv 到 Windows command line 的 quoting 规则，且不隐式调用 `cmd.exe`。
- [ ] 决定自定义 Uya stage 在 Windows 上如何运行：
  - [ ] 复用阶段 6 已证明满足强制终止门槛的 runtime task 或隔离 worker process
  - [ ] 不假设 fork 语义
- [ ] 添加 Windows hosted smoke 测试：
  - [ ] 两阶段 pipeline
  - [ ] stdout 文件 sink
  - [ ] stderr capture
  - [ ] 非零 stage 结果
  - [ ] `AssignProcessToJobObject` 失败不会遗留 suspended child，且 `CloseHandle` 不被误当作终止操作
  - [ ] 高位 Windows exit code（例如 `0xffffffff`）按 `u32` bit pattern 无损返回

## 阶段 9：文档与稳定性门禁

- [x] 如果本工作成为标准脚本路线图的一部分，更新 `todo_std_script.md`。（`todo_std_script.md` 已把 `typed_pipeline_design.md` 列为相关设计，并把 `std.script` facade 指向本工作的实现；2026-10-19 又补了 Phase 3 的回填）
- [x] 为 `|>` 更新 grammar 文档。（`docs/grammar_formal.md:275-276`：`pipeline_expr = or_expr { '|>' postfix_expr }  # 左结合`）
- [x] 向用户文档添加示例。（`docs/uya.md` §10.1，含 `|>` 优先级表 `:3970`、7 条类型规则、正例 `tests/test_typed_pipeline_parser_positive.uya` / 反例）
- [~] 添加迁移说明：使用类型化管道替代 `system("a | b")`。（**部分**：`typed_pipeline_design.md` 的概述/非目标（`:10`、`:61-63`）说明了"不把命令字符串交给 `/bin/sh`"，但没有独立的迁移章节/对照表）
- [ ] 添加已知限制章节：（**未写**——5 条内容目前分散在 `typed_pipeline_design.md:61-63`（无 glob/命令替换）、`:268`（`cmd` 与 `cmd_path` 的 PATH 语义）、`:399-410`（capture 语义与 `CaptureLimitExceeded`），没有集中章节）
  - [ ] 无 shell globbing
  - [ ] 无命令替换
  - [ ] `cmd` 只做显式 PATH-searching；`cmd_path` 不查 PATH；两者都不做 shell 展开
  - [ ] capture 限制
  - [ ] 平台后端状态

## 验收标准

- [x] `|>` 只适用于 `Pipeline` / `!Pipeline` 左侧。（`src/checker/check_expr_extra.uya` 的 `checker_check_pipeline_expr_impl`；回归 `tests/test_typed_pipeline_checker_positive.uya`，负向 `tests/error_typed_pipeline_checker_left.uya`、`error_typed_pipeline_non_pipeline_error_union.uya`、`error_typed_pipeline_checker_right.uya`）
- [x] 仅进程 pipeline 可在没有 shell 字符串的情况下运行。（回归 `tests/test_typed_pipeline_executor_single.uya` 的 `pipeline_single_exact_path_check_executes`、`pipeline_two_stage_printf_wc_executes_with_pipe_eof`、`pipeline_three_stage_process_chain_completes`）
- [x] Checked sink 使用固定的安全 all-stage/pipefail 语义，并且 `check_into` 可保留 process 与 Uya stage 失败状态详情。（回归 `pipeline_checked_sink_uses_all_stage_pipefail`、`pipeline_checked_sink_returns_pipeline_stage_failed`、`pipeline_checked_sink_reports_last_stage_nonzero_exit`）
- [x] `status_into()` 可以观察非零退出、signal、启动失败、`cancelled` 和 Uya stage 错误且不失败；executor interruption 仍返回 `error.Interrupted`。（回归 `pipeline_single_observing_status_reports_nonzero_exit`、`pipeline_status_sink_observes_signal_without_error`、`pipeline_status_sink_observes_spawn_failure_without_error`、`pipeline_stage_error_is_preserved_by_observing_sink`）
- [x] `capture_into()` 可以观察非零退出、signal、启动失败、`cancelled` 和 Uya stage 错误且不失败，把输出/状态写入 caller buffers，并返回长度与完整性摘要；executor interruption 仍返回 `error.Interrupted`。（回归 `pipeline_capture_sink_observes_spawn_failure_without_error`、`pipeline_capture_partial_startup_cancel_is_incomplete_without_observed_eof`、`pipeline_capture_probe_distinguishes_zero_exact_and_overflow`、`tests/test_typed_pipeline_caller_buffers.uya` 的 `pipeline_writes_caller_status_and_capture_buffers`）
- [x] stdout/stderr capture 和文件重定向都有测试覆盖，文件重定向作为 transformer 与 `check` / `status_into` 组合。（`pipeline_stdout_file_is_opened_once_before_spawn`、`pipeline_stderr_capture_drains_separate_stream`、`pipeline_stderr_to_stdout_merge_uses_stdout_policy`、`pipeline_file_stream_transformers_store_owned_paths`）
- [x] 大输出 pipeline 不会死锁。（`pipeline_capture_drains_output_larger_than_pipe_buffer`、`pipeline_capture_does_not_wait_for_descendant_writer_eof`）
- [x] caller-provided writable regions 重叠会在外部副作用前被拒绝；capture exact-fit/overflow 使用 scratch probe 正确区分且不会在满缓冲区后停止 drain。（`tests/test_typed_pipeline_caller_buffers.uya` 的 `pipeline_rejects_overlapping_writable_regions`、`pipeline_rejects_short_status_buffer_before_write`；`pipeline_capture_rejects_overlapping_output_regions_before_start`、`pipeline_capture_probe_distinguishes_zero_exact_and_overflow`）
- [x] observing capture 的 preflight spawn failure 和部分启动取消具有稳定的 `captured` / `complete` 语义。（`pipeline_path_preflight_failure_starts_no_child`、`pipeline_cwd_preflight_failure_starts_no_child`、`pipeline_capture_partial_startup_cancel_is_incomplete_without_observed_eof`）
- [x] `stage_count(&Pipeline) !usize` 能让动态构造的 pipeline 在 sink 前精确分配 status 缓冲区，并拒绝无效 capability。（`tests/test_typed_pipeline_capability.uya` 的 `pipeline_stage_count_empty_is_read_only`、`pipeline_capability_generation_registry`；facade 入口 `lib/std/script/file.uya:170`）
- [x] capture 超限不会因 stage 忽略 broken-pipe、直接 stage 逃离 process group 或后代持有 pipe 写端而无限等待。（`pipeline_capture_limit_kills_writer_that_ignores_sigpipe`、`pipeline_capture_limit_kills_direct_stage_after_setsid_escape`、`pipeline_capture_cancel_does_not_wait_for_escaped_descendant_writer`）
- [x] POSIX executor 仅在自身当前拥有 controlling terminal 前台权时让 pipeline 获得并归还前台 PGID，后台 executor 不抢占终端，信号不会遗留后台 stage。（`pipeline_terminal_inherit_self_test`、`pipeline_terminal_background_self_test`、`pipeline_terminal_stopped_self_test`（`lib/std/process.uya:2839/2890/2967`），以及 `pipeline_runtime_broker_interrupts_and_cancels_process_group`）
- [ ] 并发 POSIX sink 通过 runtime broker 订阅和 per-terminal foreground lease 避免覆盖 signal disposition 或竞态切换前台 PGID，等待 lease 本身可被中断。（2026-10-19：只有 `pipeline_broker_lifecycle_self_test`（`lib/std/process.uya:2738`）覆盖 broker 生命周期，**没有并发 sink 的 lease 竞态回归**，故不勾）
- [x] POSIX startup report 能区分 setpgid/chdir/dup2/execve，launch EOF 不会执行用户映像。（`pipeline_child_exec_failure_reports_phase_and_platform_code`、`pipeline_path_permission_failure_has_stable_classification`、`pipeline_process_create_failure_has_stable_classification`）
- [x] POSIX startup report 能额外区分 child `signal_setup` 失败，child 不继承 runtime broker 状态。（`pipeline_child_signal_setup_self_test`，`lib/std/process.uya:2779`）
- [ ] POSIX READY/EOF 检测不会被 parent 或兄弟 child 多持有 startup/launch/data fd 阻塞，launch 写入不受默认 `SIGPIPE` 杀死，全部内部 source fd 与 0/1/2 不冲突。（2026-10-19：无对口回归，保持未勾）
- [x] POSIX stopped child 不会让同步 sink 或 controlling terminal 永久挂起。（`pipeline_stopped_child_is_cancelled_without_hanging`、`pipeline_terminal_stopped_self_test`）
- [x] capture 成功结果通过 `complete` 明确区分 EOF 完整输出和 normal cutoff 前缀。（`pipeline_capture_partial_startup_cancel_is_incomplete_without_observed_eof`；语义锁定见 `typed_pipeline_design.md:401`）
- [x] 文件重定向 flags、固定打开顺序及非事务 create/truncate 副作用有跨平台测试和文档覆盖。（POSIX 侧：`pipeline_redirect_open_order_has_nontransactional_side_effects`、`pipeline_stdout_file_conflicts_with_capture_sink_before_start`、`pipeline_stderr_capture_conflicts_with_status_sink_before_start`、`pipeline_file_open_failure_is_infrastructure_error`；**跨平台部分仅有 POSIX**，Windows 侧随阶段 8 未做）
- [~] process `exit_code: u32` 无损覆盖 POSIX 正常退出值和 Windows 完整 `DWORD`。（`PipelineStageStatus.exit_code` 已是 `u32`，`tests/test_typed_pipeline_result_types.uya` 的 `pipeline_result_status_shapes` 覆盖形状；**Windows `DWORD` 高位路径未验证**）
- [ ] Windows child 在执行释放前已进入 Job Object，且只继承 allowlist 中的 handles；resume 边界正确区分 `not_started` / `cancelled`，正常关闭不杀非直接后代，取消显式终止 Job，assignment 失败的未入 Job child 也会被单独终止并等待。
- [x] 阶段 6 完成后，自定义 Uya stage 可以处理流数据并传递给下游；只有满足强制终止门槛的后端才能宣称有限取消。（`pipeline_stage_transformer_owns_erased_stage_in_plan`、`pipeline_stage_transformer_rejects_borrowed_fields`、`pipeline_stage_executes_in_pipeline_topology`、`pipeline_exec_worker_stage_is_enabled_by_default`）
- [x] 文档解释为什么 `input: Pipeline` 和 `stage: T` 使用基于移动语义的设计。（`docs/typed_pipeline_design.md` §Pipeline 类型 `:171-203` 的 move-only 理由与 `clone` 约定）
