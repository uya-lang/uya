# 类型化管道 TODO

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

- [ ] 如合适，通过 `std.script` 重新导出常用 API。
- [ ] 在脚本文档中添加示例。
- [ ] 将一个简单 `.ush` 验证脚本从 `system("... | ...")` 迁移出去。
- [ ] 添加与旧 shell 命令并列的行为 oracle。
- [ ] 保持显式 shell fallback API 独立且命名清晰。

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

- [ ] 如果本工作成为标准脚本路线图的一部分，更新 `todo_std_script.md`。
- [ ] 为 `|>` 更新 grammar 文档。
- [ ] 向用户文档添加示例。
- [ ] 添加迁移说明：使用类型化管道替代 `system("a | b")`。
- [ ] 添加已知限制章节：
  - [ ] 无 shell globbing
  - [ ] 无命令替换
  - [ ] `cmd` 只做显式 PATH-searching；`cmd_path` 不查 PATH；两者都不做 shell 展开
  - [ ] capture 限制
  - [ ] 平台后端状态

## 验收标准

- [ ] `|>` 只适用于 `Pipeline` / `!Pipeline` 左侧。
- [ ] 仅进程 pipeline 可在没有 shell 字符串的情况下运行。
- [ ] Checked sink 使用固定的安全 all-stage/pipefail 语义，并且 `check_into` 可保留 process 与 Uya stage 失败状态详情。
- [ ] `status_into()` 可以观察非零退出、signal、启动失败、`cancelled` 和 Uya stage 错误且不失败；executor interruption 仍返回 `error.Interrupted`。
- [ ] `capture_into()` 可以观察非零退出、signal、启动失败、`cancelled` 和 Uya stage 错误且不失败，把输出/状态写入 caller buffers，并返回长度与完整性摘要；executor interruption 仍返回 `error.Interrupted`。
- [ ] stdout/stderr capture 和文件重定向都有测试覆盖，文件重定向作为 transformer 与 `check` / `status_into` 组合。
- [ ] 大输出 pipeline 不会死锁。
- [ ] caller-provided writable regions 重叠会在外部副作用前被拒绝；capture exact-fit/overflow 使用 scratch probe 正确区分且不会在满缓冲区后停止 drain。
- [ ] observing capture 的 preflight spawn failure 和部分启动取消具有稳定的 `captured` / `complete` 语义。
- [ ] `stage_count(&Pipeline) !usize` 能让动态构造的 pipeline 在 sink 前精确分配 status 缓冲区，并拒绝无效 capability。
- [ ] capture 超限不会因 stage 忽略 broken-pipe、直接 stage 逃离 process group 或后代持有 pipe 写端而无限等待。
- [ ] POSIX executor 仅在自身当前拥有 controlling terminal 前台权时让 pipeline 获得并归还前台 PGID，后台 executor 不抢占终端，信号不会遗留后台 stage。
- [ ] 并发 POSIX sink 通过 runtime broker 订阅和 per-terminal foreground lease 避免覆盖 signal disposition 或竞态切换前台 PGID，等待 lease 本身可被中断。
- [ ] POSIX startup report 能区分 setpgid/chdir/dup2/execve，launch EOF 不会执行用户映像。
- [ ] POSIX startup report 能额外区分 child `signal_setup` 失败，child 不继承 runtime broker 状态。
- [ ] POSIX READY/EOF 检测不会被 parent 或兄弟 child 多持有 startup/launch/data fd 阻塞，launch 写入不受默认 `SIGPIPE` 杀死，全部内部 source fd 与 0/1/2 不冲突。
- [ ] POSIX stopped child 不会让同步 sink 或 controlling terminal 永久挂起。
- [ ] capture 成功结果通过 `complete` 明确区分 EOF 完整输出和 normal cutoff 前缀。
- [ ] 文件重定向 flags、固定打开顺序及非事务 create/truncate 副作用有跨平台测试和文档覆盖。
- [ ] process `exit_code: u32` 无损覆盖 POSIX 正常退出值和 Windows 完整 `DWORD`。
- [ ] Windows child 在执行释放前已进入 Job Object，且只继承 allowlist 中的 handles；resume 边界正确区分 `not_started` / `cancelled`，正常关闭不杀非直接后代，取消显式终止 Job，assignment 失败的未入 Job child 也会被单独终止并等待。
- [ ] 阶段 6 完成后，自定义 Uya stage 可以处理流数据并传递给下游；只有满足强制终止门槛的后端才能宣称有限取消。
- [ ] 文档解释为什么 `input: Pipeline` 和 `stage: T` 使用基于移动语义的设计。
