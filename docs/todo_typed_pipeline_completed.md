# 类型化管道 TODO — 完成归档

> 本文件记录已完成并验证的任务，从 `docs/todo_typed_pipeline.md` 移入。

---

## 阶段 0：规格锁定

- [x] 按当前 Uya grammar 和接口语法复核 `typed_pipeline_design.md`。
  验证：已在归档前完成并验证。

---

- [x] 在 `std_script_design.md` 中添加一个短章节链接到本设计。
  验证：已在归档前完成并验证。

---

## 阶段 9：文档与稳定性门禁

- [x] 更新 `std_script_design.md`。
  验证：已在归档前完成并验证。

---

## 阶段 0：规格锁定

- [x] 确定最终名称：
  - [x] `pipeline`（空管道构造器最终名称为 `pipeline()`，`empty_pipeline` 废弃）
    验证：复核 `docs/typed_pipeline_design.md` L126-L131、L196，以及 `docs/std_script_design.md` L238 均使用 `pipeline()`；无 `.uya` 实现引用任一候选名。

## 类型化管道 TODO / 阶段 0：规格锁定

- [ ] 确定最终名称：
  - [x] `pipeline`（空管道构造器最终名称为 `pipeline()`，`empty_pipeline` 废弃）
    验证：复核 `docs/typed_pipeline_design.md` L126-L131、L196，以及 `docs/std_script_design.md` L238 均使用 `pipeline()`；无 `.uya` 实现引用任一候选名。
    归档验证（2026-07-10）：
    - `sed -n '126,131p' docs/typed_pipeline_design.md` 确认使用 `pipeline()`
    - `sed -n '196p' docs/typed_pipeline_design.md` 确认 `fn pipeline() Pipeline;`
    - `sed -n '238p' docs/std_script_design.md` 确认引用 typed_pipeline_design.md 的 pipeline 语义
    - `grep -R -n -E '(empty_pipeline|pipeline\s*\()' --include='*.uya' .` 未发现 `empty_pipeline`；`pipeline(` 仅在 `examples/example_152.uya` 中作为用户自定义函数名出现，非 typed pipeline 构造器。

---

## 阶段 0：规格锁定

- [x] 确定最终名称：
  - [x] `cmd_argv` / `cmd_path_argv`，以及后续 `cmd` / `cmd_path` facade
    验证（2026-07-10）：
    - `sed -n '190,210p' docs/typed_pipeline_design.md` 确认 API 列表已使用 `cmd_argv`、`cmd_path_argv`、`cmd`、`cmd_path`
    - `grep -cE 'cmd_argv|cmd_path_argv|fn cmd\(|fn cmd_path\(' docs/typed_pipeline_design.md` 返回 21 处引用
    - `grep -nE '\b(exec_argv|run_argv|spawn_argv|exec_path_argv|run_path_argv|spawn_path_argv|process_argv|process_path_argv|pipeline_cmd_argv|pipe_cmd_argv|command_argv|command_path_argv)\b' docs/typed_pipeline_design.md docs/std_script_design.md` 未发现竞争候选名
    - 已在 `typed_pipeline_design.md` API 列表标题处添加"名称已锁定为最终公共名"说明，并在 `cmd` / `cmd_path` 注释处补充"名称同样锁定"

---

## 阶段 0：规格锁定

- [ ] 确定最终名称：
  - [x] `stage`
    验证：`docs/typed_pipeline_design.md` L449 已声明“名称锁定”；L459-L463 将 transformer 标记为“最终 transformer（名称已锁定）”并使用 `fn stage<T: PipelineStage>(input: Pipeline, stage: T) !Pipeline;`；未决问题 L741 已更新为“`stage` 已锁定为最终名称；`filter` 是否应保留为 `stage` 的公共别名（由 TODO L21 单独决定）”。`python3 scripts/todo_progress.py summary docs/todo_typed_pipeline.md` 确认 L17 已更新。

---

## 阶段 0：规格锁定

- [ ] 确定最终名称：
  - [x] `stage`
    验证（2026-07-10）：
    - `sed -n '449p' docs/typed_pipeline_design.md` 确认“名称锁定：自定义 Uya pipeline stage 的 transformer 最终名称为 `stage`”。
    - `sed -n '462p' docs/typed_pipeline_design.md` 确认 `fn stage<T: PipelineStage>(input: Pipeline, stage: T) !Pipeline;`。
    - `sed -n '741p' docs/typed_pipeline_design.md` 确认未决问题中写明“`stage` 已锁定为最终名称；`filter` 是否应保留为 `stage` 的公共别名（由 TODO L21 单独决定）”。
    - `grep -nE '\b(filter|step|node)\b.*stage|stage.*\b(filter|step|node)\b' docs/typed_pipeline_design.md` 未发现将 `filter`/`step`/`node` 作为 transformer 最终名的声明。

## 阶段 0：规格锁定

- [ ] 确定最终名称：
  - [x] `stdout_file`：锁定为最终公共名 `fn stdout_file(input: Pipeline, path: &const byte) !Pipeline;`；验证命令 `grep -n "stdout_file" docs/typed_pipeline_design.md` 命中 9 处，包括 API 列表 L213、示例 L30/L48/L501、语义说明 L266/L268、冲突策略 L423/L424/L426。

---

## 阶段 0：规格锁定

- [ ] 确定最终名称：
  - [x] `capture_into` / `capture_limit_into`
    验证（2026-07-10）：
    - `sed -n '193,222p' docs/typed_pipeline_design.md` 确认 API 列表标题写明“名称已锁定为最终公共名”，并声明 `fn capture_into(input: Pipeline, statuses: &[PipelineStageStatus], stdout_buf: &[byte], stderr_buf: &[byte], result: &PipelineCaptureResult) !void;` 和 `fn capture_limit_into(input: Pipeline, max_bytes: usize, statuses: &[PipelineStageStatus], stdout_buf: &[byte], stderr_buf: &[byte], result: &PipelineCaptureResult) !void;`
    - `grep -cE 'capture_into|capture_limit_into' docs/typed_pipeline_design.md` 返回 15 处引用
    - `grep -nE '\b(capture_output|output_of|read_into|collect_into|get_output|exec_capture|run_capture|spawn_capture|capture_stdout|capture_stderr|capture_all)\b' docs/typed_pipeline_design.md docs/std_script_design.md docs/todo_typed_pipeline.md` 未发现竞争候选名

## 阶段 0：规格锁定

- [ ] 确定最终名称：
  - [x] `capture_into` / `capture_limit_into`

验证命令：
```bash
grep -n "capture_into\|capture_limit_into" docs/typed_pipeline_design.md
```

验证结果：在设计文档中发现多处使用 `capture_into()` / `capture_limit_into()` 命名，包括 API 声明（L221-L222）、sink 说明（L268、L270、L332、L338、L371、L381、L383、L397、L429、L431）和约束条款（L672、L695）。名称已锁定。

## 阶段 0：规格锁定

- [x] 确定最终名称：
  - [x] `status_into`
    验证（2026-07-10）：
    - `sed -n '193,222p' docs/typed_pipeline_design.md` 确认 API 列表在“名称已锁定为最终公共名”标题下列出 `fn status_into(input: Pipeline, statuses: &[PipelineStageStatus], result: &PipelineResult) !void;`
    - `grep -cE 'status_into' docs/typed_pipeline_design.md` 返回 9 处引用
    - `grep -nE '\b(status_of|exit_status_into|result_into|statuses_into|get_status|pipe_status|wait_status|run_status|exec_status|process_status|pipeline_status|exit_into|wait_into|observe_status)\b' docs/typed_pipeline_design.md docs/std_script_design.md docs/todo_typed_pipeline.md` 未发现竞争候选名

## 阶段 0：规格锁定

- [x] 决定 `filter` 是公共别名，还是仅作为文档术语。
  决策：`filter` 不作为公共 API 别名，仅作为文档/概念术语使用；自定义 Uya pipeline stage 的唯一公共 transformer 名称保持为 `stage`。
  验证（2026-07-10）：
  - `sed -n '449p' docs/typed_pipeline_design.md` 确认“名称锁定：自定义 Uya pipeline stage 的 transformer 最终名称为 `stage`”。
  - `sed -n '505p' docs/typed_pipeline_design.md` 确认“`filter` 不作为公共 API 别名……”。
  - `sed -n '741p' docs/typed_pipeline_design.md` 确认未决问题中写明“`filter` 仅作为文档术语，不暴露为公共别名”。
  - `grep -nE '\bfn\s+filter\b|\bfilter\s*\(' docs/typed_pipeline_design.md docs/std_script_design.md docs/todo_typed_pipeline.md` 未发现公共 `filter` API 声明。


## 阶段 0：规格锁定

### 决定精确错误名

- [x] `InvalidPipeline`
  - 决策：采用 `error.InvalidPipeline` 作为类型化管道的通用“无效 / 不可执行 pipeline”错误名。
  - 语义锁定（详见 `docs/typed_pipeline_design.md`）：
    - 已消费或已 drop 的 capability 再次使用；
    - 空 pipeline 传给 sink；
    - `cmd` 命令名为空或含路径分隔符；
    - `cmd_path` 使用 Windows drive-relative 路径（如 `C:tool.exe`）；
    - stream policy 冲突或错误的 transformer 位置；
    - `cwd` / `env` / `unset_env` 作用于非 process stage 或空计划；
    - capture sink 与 file / inherit 策略冲突；
    - `clone` 遇到不可克隆的 erased stage；
    - caller-provided statuses / 缓冲区容量不足或重叠；
    - `stage_count(&Pipeline)` 查询到无效 / 过期 capability。
  - 验证：人工复核 `docs/typed_pipeline_design.md` 中所有 `InvalidPipeline` 出现位置，语义一致且无同名歧义。无代码实现，无需编译/运行验证。

## 类型化管道 TODO / 阶段 0：规格锁定

- [ ] 决定精确错误名：
  - [x] `InvalidPipeline` — 锁定为 `error.InvalidPipeline`：表示 pipeline 处于不可执行或不可转换状态（已消费/过期 capability、空 pipeline、策略冲突、参数无效、不可克隆 stage、caller 缓冲区问题等）。已复核 `typed_pipeline_design.md` 中全部出现位置，语义一致。

验证：
- 已人工复核 `docs/typed_pipeline_design.md` 中所有 `InvalidPipeline` 出现位置，语义一致。
- 归档时间：2026-07-10。

## 阶段 0：规格锁定

- [ ] 决定精确错误名：
  - [x] `ProcessFailed`
    验证（2026-07-10）：
    - `sed -n '375,380p' docs/typed_pipeline_design.md` 确认 `check()` / `check_into()` 使用 `error.ProcessFailed` 表示任一 process stage 非零退出或 signal 终止。
    - `sed -n '695p' docs/typed_pipeline_design.md` 确认“需要失败详情时不能依赖 `error.ProcessFailed` 携带 payload，必须使用 `check_into` / `status_into` / `capture_into` / `capture_limit_into`”。
    - `grep -cE 'error\.ProcessFailed' docs/typed_pipeline_design.md` 返回 5 处引用；语义一致，无竞争候选名。
    - 决策：采用 `error.ProcessFailed` 作为 checked sink 的 process stage 非零退出 / signal 终止错误名；优先级低于 `error.PipelineSpawnFailed` 与 `error.PipelineStageFailed`。

## 阶段 0：规格锁定

- [ ] 决定精确错误名：
  - [x] `CaptureLimitExceeded`
    验证（2026-07-10）：
    - `sed -n '338p' docs/typed_pipeline_design.md` 确认超过 capture limit 时返回 `error.CaptureLimitExceeded`，并通过独立一字节 scratch overflow probe 区分 exact-fit 与 overflow。
    - `sed -n '342p' docs/typed_pipeline_design.md` 确认返回 `error.CaptureLimitExceeded` 前必须把输出 `PipelineCaptureResult` 重置为空摘要，不通过 `CaptureStreamResult` 表示截断。
    - `sed -n '397p' docs/typed_pipeline_design.md` 确认任一 captured stream 超过有效限制时进入强制取消路径，终止所有直接 stage、reap 后重置输出 result 为空摘要并返回 `error.CaptureLimitExceeded`。
    - `grep -cE 'error\.CaptureLimitExceeded|CaptureLimitExceeded' docs/typed_pipeline_design.md` 返回 6 处匹配行；语义一致，无竞争候选名。
    - 决策：采用 `error.CaptureLimitExceeded` 作为 capture sink 输出超过有效上限时的稳定 Uya error 名。


## 2026-07-10 完成归档

### 阶段 0：规格锁定

- [x] 决定精确错误名：
  - [x] `Interrupted`
    - **验证**：`docs/typed_pipeline_design.md` 已将 `error.Interrupted` 作为稳定错误名使用：
      - L360：executor 收到未被忽略的终止/取消信号 => `error.Interrupted`
      - L361：直接 stage 进入 stopped 状态 => `error.Interrupted`
      - L385/L545/L547/L549/L609/L687：取消/中断路径统一返回 `error.Interrupted`
    - `docs/std_refactor_design.md` L183 已声明 `error Interrupted;`，名称一致。
    - **结论**：`Interrupted` 锁定为 pipeline executor 在自身收到未忽略取消信号、等待 terminal lease 被中断、以及 stopped child 强制收敛时的精确 Uya error 名。

## 阶段 0：规格锁定

- [ ] 决定精确错误名：
  - [x] `Interrupted`

验证：
- 命令：`grep -n "error.Interrupted" docs/typed_pipeline_design.md`
- 结果：设计文档中稳定使用 `error.Interrupted` 表示 executor/同步 sink 收到未忽略终止信号、直接 stage stopped、前台终端 lease 中断等场景（如 L360-L361、L385、L395、L549、L609 等）。命名已锁定。

---

## 阶段 0：规格锁定

- [ ] 决定精确错误名：
  - [x] `PipelineSpawnFailed`
    验证：`grep -n 'error.PipelineSpawnFailed' docs/typed_pipeline_design.md` 命中 L378、L379；设计文档已将 checked sink 的 spawn 失败路径统一命名为 `error.PipelineSpawnFailed`，与 `PipelineStageStatusKind.spawn_failed` 状态对应。

---

## 阶段 0：规格锁定

- [ ] 决定精确错误名：
  - [x] `PipelineStageFailed`
    验证（2026-07-10）：
    - `sed -n '378p' docs/typed_pipeline_design.md` 确认 `check()` 在 Uya stage 返回错误时使用 `error.PipelineStageFailed`。
    - `sed -n '379p' docs/typed_pipeline_design.md` 确认 `check_into()` 在 Uya stage 返回错误时返回 `error.PipelineStageFailed` 并保留完整摘要。
    - `sed -n '342p' docs/typed_pipeline_design.md` 确认 `check_into()` 返回 `error.PipelineStageFailed` 时必须保留已写入 statuses 的完整 stage 摘要。
    - `grep -cE 'error\.PipelineStageFailed' docs/typed_pipeline_design.md` 返回 3 处引用；语义一致，无竞争候选名。
    - 决策：采用 `error.PipelineStageFailed` 作为 checked sink 遇到 `PipelineStageStatusKind.stage_failed` 时返回的精确 Uya error 名；优先级低于 `error.PipelineSpawnFailed`，高于 `error.ProcessFailed`。

## 阶段 0：规格锁定

- [x] 定义 checked sink 在非零退出时是否默认返回 `error.ProcessFailed`。
  决策：是。`check()` / `check_into()` 使用固定 all-stage/pipefail；任一 process stage 非零退出或 signal 终止默认返回 `error.ProcessFailed`。`spawn_failed` / `not_started` 链路优先返回 `error.PipelineSpawnFailed`，Uya stage 错误优先返回 `error.PipelineStageFailed`。`check_into()` 在返回上述错误前必须先写入完整 `PipelineResult`。
  验证（2026-07-10）：
  - `sed -n '373,379p' docs/typed_pipeline_design.md` 确认 `check()` 固定 all-stage/pipefail，非零退出或 signal 终止默认返回 `error.ProcessFailed`，`spawn_failed`/`not_started` 链路优先返回 `error.PipelineSpawnFailed`，Uya stage 错误优先返回 `error.PipelineStageFailed`。
  - `sed -n '382,383p' docs/typed_pipeline_design.md` 确认 `check_into()` 与 `check()` 语义相同，且返回错误前必须先写入完整 stage 状态。

---

## 阶段 0：规格锁定

- [x] 定义失败详情通过 `check_into`、`status_into`、`capture_into`、`capture_limit_into` 返回，不依赖 Uya error payload。
  验证（2026-07-10）：
  - `sed -n '373,379p' docs/typed_pipeline_design.md` 确认新增“失败详情返回路径”章节已明确该原则。
  - `sed -n '391p' docs/typed_pipeline_design.md` 确认“需要失败详情时，调用方必须使用 `check_into`/`status_into`/`capture_into`/`capture_limit_into`”。
  - `sed -n '703p' docs/typed_pipeline_design.md` 确认检查表再次强调该原则。
  - `grep -cE 'check_into|status_into|capture_into|capture_limit_into' docs/typed_pipeline_design.md` 返回多处 API 声明与语义说明，所有失败详情写入调用方提供的 `statuses`/`result`/`stdout_buf`/`stderr_buf`。

# 类型化管道 TODO
## 阶段 0：规格锁定
- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] per-stage `not_started`
    - 验证：`grep -n "not_started" docs/typed_pipeline_design.md` 命中 10 处；`PipelineStageStatusKind` 枚举已包含 `not_started`（L278），语义定义为“因更早预检、启动失败或执行器取消而未越过执行释放边界”（L326），POSIX/Windows 边界（L551、L615）、预检失败场景（L348、L561）与字段约束（L328）均一致。

---

# 类型化管道 TODO
## 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] per-stage `spawn_failed`
    - 验证：已确认 `docs/typed_pipeline_design.md` 中 `PipelineStageStatusKind` 定义了 `spawn_failed`，`PipelineStageStatus` 包含 `spawn_failure: PipelineSpawnFailureKind` 与 `platform_code: u32`，文档 L326-L369 明确语义、执行释放边界、`not_started` 区别、平台错误码映射及 `check()`/`status_into()`/`capture_into()` 的处理规则。

---

## 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] per-stage `spawn_failed`
    - 验证：已确认 `docs/typed_pipeline_design.md` 中 `PipelineStageStatusKind` 定义了 `spawn_failed`，`PipelineStageStatus` 包含 `spawn_failure: PipelineSpawnFailureKind` 与 `platform_code: u32`，文档 L326-L369 明确语义、执行释放边界、`not_started` 区别、平台错误码映射及 `check()`/`status_into()`/`capture_into()` 的处理规则。

## 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] per-stage `cancelled`

验证：`typed_pipeline_design.md` 已锁定 per-stage `cancelled`：
- `PipelineStageStatusKind` 枚举包含 `cancelled`（L277–285）。
- 结果模型明确 `cancelled` 表示已越过执行释放边界、但在自然完成前被 executor 强制终止；自然完成状态不得覆盖为 `cancelled`（L326–330）。
- POSIX 执行释放边界以成功消费 `RUN` 为准，已释放但未自然完成的 stage 记为 `cancelled`（L551）。
- Windows 执行释放边界以 `ResumeThread` 成功为准，已恢复但被终止的 stage 记为 `cancelled`（L613）。
- 必要不变量重申 `cancelled` 与 `not_started` 的区分（L701）。

完成时间：2026-07-10

---

## 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] per-stage `cancelled`

  验证：`typed_pipeline_design.md` 已锁定 per-stage `cancelled`：
  - `PipelineStageStatusKind` 枚举包含 `cancelled`（L277–285）。
  - 结果模型明确 `cancelled` 表示已越过执行释放边界、但在自然完成前被 executor 强制终止；自然完成状态不得覆盖为 `cancelled`（L326–330）。
  - POSIX 执行释放边界以成功消费 `RUN` 为准，已释放但未自然完成的 stage 记为 `cancelled`（L551）。
  - Windows 执行释放边界以 `ResumeThread` 成功为准，已恢复但被终止的 stage 记为 `cancelled`（L613）。
  - 必要不变量重申 `cancelled` 与 `not_started` 的区分（L701）。

  完成时间：2026-07-10

## 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] per-stage `exited(exit_code: u32)`；POSIX 0..255 扩宽，Windows `DWORD` 原样保存
    验证（2026-07-10）：
    - `sed -n '277,285p' docs/typed_pipeline_design.md` 确认 `PipelineStageStatusKind` 枚举包含 `exited`。
    - `sed -n '299,307p' docs/typed_pipeline_design.md` 确认 `PipelineStageStatus` 结构体包含 `exit_code: u32`。
    - `sed -n '328p' docs/typed_pipeline_design.md` 确认 `exit_code` 使用 `u32`：POSIX 的正常退出值以 0..255 扩宽保存，Windows 必须原样保存 `GetExitCodeProcess` 返回的完整 `DWORD` bit pattern；跨平台成功判断统一为 `exit_code == 0u32`。
    - 决策：per-stage `exited` 状态的 `exit_code` 字段类型锁定为 `u32`；POSIX 将 0..255 零扩宽保存，Windows 原样保存 `DWORD`。

## 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] per-stage `signaled(signal)`

验证命令：
```
grep -n "signal: i32" docs/typed_pipeline_design.md
grep -n "POSIX 上为实际导致子进程终止的正 signal number" docs/typed_pipeline_design.md
grep -n "非 \`signaled\` 状态的 \`signal\` 字段必须为 0" docs/typed_pipeline_design.md
```

验证结果：全部命中。`PipelineStageStatus.signal` 类型为 `i32`；POSIX 使用正 signal number；Windows process-only MVP 默认走 `exited` + `exit_code`，只有显式映射时才允许 `signaled`；非 `signaled` 状态 `signal` 必须为 0。

---

## 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] process `spawn_failed` 保存稳定的 `PipelineSpawnFailureKind` 与可选平台错误码
    验证（2026-07-10）：
    - `sed -n '287,305p' docs/typed_pipeline_design.md` 确认 `PipelineSpawnFailureKind` 枚举已定义，且 `PipelineStageStatus` 包含 `spawn_failure: PipelineSpawnFailureKind` 与 `platform_code: u32`。
    - `sed -n '326,330p' docs/typed_pipeline_design.md` 确认 `spawn_failed` 的 `spawn_failure` 保存稳定跨平台类别，`platform_code` 保存 POSIX errno 或 Windows `GetLastError()`，无适用平台码时为 0。
    - `sed -n '369p' docs/typed_pipeline_design.md` 确认 `spawn_failed` 到 `PipelineSpawnFailureKind` 的稳定映射规则（PATH/cwd/权限/process create/执行域/stdio/exec/platform error）。
    - `grep -n "阶段 0 已锁定" docs/typed_pipeline_design.md` 确认已在 `PipelineSpawnFailureKind` 定义后追加锁定声明。
    决策：`process spawn_failed` 状态保存稳定的 `PipelineSpawnFailureKind` 类别与可选 `u32` 平台错误码；跨平台控制流只能依赖 `spawn_failure`。

- [x] process `spawn_failed` 保存稳定的 `PipelineSpawnFailureKind` 与可选平台错误码
  父级路径：`锁定 PipelineResult / PipelineCaptureResult 的结构`
  验证：已在归档前完成并验证。
## 类型化管道 TODO / 阶段 0：规格锁定

- [x] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] Uya stage `completed`

验证：读取 `docs/typed_pipeline_design.md` L277-286 与 L330-332，确认 `PipelineStageStatusKind.completed` 已定义为“Uya stage 正常返回”，无额外 payload；并已在 L286 添加“阶段 0 已锁定”标记。

---


---

## 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] Uya stage `stage_failed(error_name)`
    - 验证：设计文档审查。`PipelineStageStatusKind` 已包含 `stage_failed`；`PipelineStageStatus` 已包含 `error_name: &const byte`；L334-L335 明确 `stage_failed` 表示 Uya stage 返回 Uya error，`error_name` 必须指向程序期静态/驻留字符串；新增“阶段 0 已锁定”标记冻结该语义。
    - 命令：`grep -n "stage_failed\\|error_name" docs/typed_pipeline_design.md`
    - 结果：匹配到枚举定义、结构体字段、详细语义段及阶段 0 锁定声明。

## 类型化管道 TODO / 阶段 0：规格锁定

- [x] `stage_count` 与 statuses 覆盖完整可执行 stage 列表，`stage_index` 不因混合 stage 压缩

验证：
- `docs/typed_pipeline_design.md` 在 `PipelineCaptureResult` 结构定义后添加阶段 0 已锁定标记，明确 `PipelineResult.stage_count` 与调用方 `statuses` 覆盖完整可执行 stage 列表，`PipelineStageStatus.stage_index` 使用完整 stage 列表零基索引且混合 process/Uya stage 时不压缩编号。
- 设计文档已写明：调用方提供的 `statuses` 长度必须至少覆盖全部可执行 stage 数量，`PipelineResult.stage_count` 等于该数量；`stage_index` 是完整 pipeline stage 列表中的零基索引，混合 process/Uya stage 时不得重新压缩编号。
- 验证命令：`sed -n '333,341p' docs/typed_pipeline_design.md` 可看到锁定标记与对应段落。
- 本轮未修改生产代码，仅完成规格锁定与文档标记。

---

## 类型化管道 TODO / 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] `stage_count` 与 statuses 覆盖完整可执行 stage 列表，`stage_index` 不因混合 stage 压缩
    验证（2026-07-10）：
    - `sed -n '197p' docs/typed_pipeline_design.md` 确认 `fn stage_count(input: &Pipeline) !usize;`
    - `sed -n '306,309p' docs/typed_pipeline_design.md` 确认 `PipelineStageStatus.stage_index` 字段存在
    - `sed -n '316,318p' docs/typed_pipeline_design.md` 确认 `PipelineResult.stage_count` 字段存在
    - `sed -n '333p' docs/typed_pipeline_design.md` 确认阶段 0 已锁定声明
    - `sed -n '341,343p' docs/typed_pipeline_design.md` 确认 `PipelineResult.stage_count`、调用方 `statuses` 缓冲区覆盖完整可执行 stage 列表，`stage_index` 使用完整 stage 列表零基索引，混合 process/Uya stage 时不得重新压缩编号

---

## 类型化管道 TODO / 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] `PipelineResult` 只保存 `stage_count` 摘要，不保存指向调用方 status 缓冲区的 slice/pointer

验证（2026-07-10）：
- `sed -n '316,330p' docs/typed_pipeline_design.md` 确认 `struct PipelineResult { stage_count: usize }`，无指向调用方缓冲区的 slice/pointer 字段。
- `sed -n '333p' docs/typed_pipeline_design.md` 已追加“阶段 0 已锁定”说明，明确 `PipelineResult` 只保存 `stage_count` 摘要，不保存指向调用方 `statuses` 缓冲区的 slice、指针或其他借用。
- `grep -n "PipelineResult" docs/typed_pipeline_design.md` 确认 L316-L318 定义、L341-L344 段落进一步解释 caller-provided buffer 方案与无借用语义。

---

## 类型化管道 TODO / 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] `stage_count(&Pipeline) !usize` 在 sink 前提供不消费、不执行的精确容量查询，无效 capability 返回 `InvalidPipeline`

验证（2026-07-10）：
- `sed -n '197p' docs/typed_pipeline_design.md` 确认公开 API 已声明 `fn stage_count(input: &Pipeline) !usize;`
- `sed -n '230p' docs/typed_pipeline_design.md` 确认已追加“阶段 0 已锁定”标记，明确 `stage_count(input: &Pipeline) !usize` 在 sink 前提供不消费、不执行的精确容量查询，空计划返回 0，无效 / 过期 / 伪造 capability 返回 `error.InvalidPipeline`
- `sed -n '232p' docs/typed_pipeline_design.md` 确认详细语义：查询不得缓存 execution-time 状态，不得改变后续 sink 结果，必须保留 `!usize` 错误通道，不能用 0 混淆“合法空计划”和“无效 capability”
- 本轮未修改生产代码，仅完成规格锁定与文档标记。

---

## 类型化管道 TODO / 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] `stage_count(&Pipeline) !usize` 在 sink 前提供不消费、不执行的精确容量查询，无效 capability 返回 `InvalidPipeline`
    验证（2026-07-10）：
    - `sed -n '196,198p' docs/typed_pipeline_design.md` 确认 API 签名为 `fn stage_count(input: &Pipeline) !usize;`
    - `sed -n '230,232p' docs/typed_pipeline_design.md` 确认锁定说明包含“不消费、不执行”“空计划返回 0”“无效 / 过期 / 伪造 capability 返回 `error.InvalidPipeline`”
    - `sed -n '681p' docs/typed_pipeline_design.md` 确认不变式列表重申该语义
    - 阶段 0 规格锁定任务，无 `.uya` 实现变更。

---

## 类型化管道 TODO / 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] `CaptureStreamResult.captured`
    验证（2026-07-10）：
    - `sed -n '322,345p' docs/typed_pipeline_design.md` 确认 `CaptureStreamResult` 定义及新增 `captured` 字段语义锁定说明。
    - 说明明确 `captured` 由 stream policy 决定；false 时 `byte_count=0` 且 `complete=false`；true 时即使无数据也保持 true。
    - 阶段 0 规格锁定任务，无 `.uya` 实现变更。

---

## 类型化管道 TODO / 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] `CaptureStreamResult.byte_count`
    验证：已在归档前完成并验证。
    归档验证（2026-07-10）：
    - `sed -n '322,326p' docs/typed_pipeline_design.md` 确认 `CaptureStreamResult` 包含 `byte_count: usize`
    - `sed -n '335p' docs/typed_pipeline_design.md` 确认阶段 0 已锁定标注
    - `sed -n '337,342p' docs/typed_pipeline_design.md` 确认 `byte_count` 语义覆盖 capture/non-capture/空摘要/预检失败等路径
## 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] `CaptureStreamResult.complete`，只有观察到 EOF 才为 true，normal cutoff 必须显式为 false
    - 验证：已查阅 `docs/typed_pipeline_design.md` L322-L341、L352-L353、L358-L364、L553、L706、L708，并新增 L335-L338 的“阶段 0 已锁定”显式声明：`CaptureStreamResult.complete` 只有在 executor 确实观察到对应 stream 的 EOF 时才为 `true`；正常 direct-stage cutoff（`EAGAIN`、drain budget 耗尽或 capture limit 触发的 `CaptureLimitExceeded` 路径）必须显式为 `false`。
    - 命令：`sed -n '322,341p;352,353p;358,364p;553p;706,708p' docs/typed_pipeline_design.md`
    - 结果：设计文档已明确包含上述语义，且新增独立锁定语句。

---

## 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] `CaptureStreamResult.complete`，只有观察到 EOF 才为 true，normal cutoff 必须显式为 false
    验证：规格已写入 `docs/typed_pipeline_design.md`。
    - `CaptureStreamResult.complete` 只有 executor 确实观察到对应 stream 的 EOF 时才为 `true`（L337、L341、L354、L565）。
    - 正常 direct-stage cutoff（`EAGAIN`、drain budget 耗尽或 capture limit 触发的 `CaptureLimitExceeded` 路径）必须显式为 `false`，不得因数据已填满缓冲区或未等待到 EOF 而静默声称完整（L337、L364、L565、L710）。
    - 空摘要路径下 `complete=false`（L368）。

---

## 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] capture result 只记录 stdout/stderr 已写入长度，调用方通过自己的缓冲区和长度取得有效前缀，不建立跨参数借用
    验证：已在 `docs/typed_pipeline_design.md` L335-L342 增加阶段 0 已锁定声明，明确 `PipelineCaptureResult` 仅保存长度/状态摘要，不保存指向 `stdout_buf` / `stderr_buf` 或调用方其他缓冲区的 slice、指针或借用；调用方通过自己持有的缓冲区和 `result.stdout.byte_count` / `result.stderr.byte_count` 取得有效前缀。无代码实现变更。

---

## 阶段 0：规格锁定

- [ ] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] capture result 只记录 stdout/stderr 已写入长度，调用方通过自己的缓冲区和长度取得有效前缀，不建立跨参数借用
    验证：已复核 `docs/typed_pipeline_design.md`，相关锁定文本存在。
    - L335：`CaptureStreamResult.byte_count` 为 `usize`，表示已写入调用方缓冲区的字节数；调用方通过 `stdout_buf[0:result.stdout.byte_count]` 与 `stderr_buf[0:result.stderr.byte_count]` 取得有效前缀；result 不保存指向缓冲区的借用。
    - L339：`PipelineCaptureResult` 仅保存内嵌 `PipelineResult` 与两路 `CaptureStreamResult` 的长度/状态摘要，不保存指向 `stdout_buf` / `stderr_buf` 或调用方任何其他缓冲区的 slice、指针或其他借用。
    - L356：`PipelineResult` / `PipelineCaptureResult` 只保存可复制的长度与状态摘要，不保存指向调用方缓冲区的 slice、指针或其他借用；result 可独立复制或保留，不会延长缓冲区生命周期，也不会形成函数签名无法表达的跨参数借用关系。
    命令：`grep -n "byte_count" docs/typed_pipeline_design.md && grep -n "不保存指向" docs/typed_pipeline_design.md && grep -n "跨参数借用" docs/typed_pipeline_design.md`
    结果：均命中上述行号与文本，规格已锁定并归档。


## 阶段 0：规格锁定

- [x] 锁定 `PipelineResult` / `PipelineCaptureResult` 的结构：
  - [x] 后续按值 facade 使用独立的 `OwnedPipelineResult` / `OwnedPipelineCaptureResult` 或不透明 handle，不复用仅含长度的摘要类型
    验证：在 `docs/typed_pipeline_design.md` 的“结果模型”段增加“阶段 0 已锁定”说明，明确 `status()` / `capture()` / `capture_limit()` 必须返回独立的 `OwnedPipelineResult` / `OwnedPipelineCaptureResult`（或等价不透明 handle），不得复用 `PipelineResult` / `PipelineCaptureResult` 摘要类型，并补充所有权转移 / drop / clone 规则。

## 阶段 0：规格锁定

- [ ] 锁定 checked/observing sink 分层：
  - [x] `check()`：pipefail，非零返回 `error.ProcessFailed`
    - 验证：读取 `docs/typed_pipeline_design.md` L405-415，确认已添加“阶段 0 已锁定”标记；`check()` 使用固定 all-stage/pipefail，任一 process stage 非零退出或 signal 终止返回 `error.ProcessFailed`；`spawn_failed` / `not_started` 链路优先返回 `error.PipelineSpawnFailed`；Uya stage 错误返回 `error.PipelineStageFailed`；MVP 不开放关闭 pipefail 的入口。

---

## 类型化管道 TODO

### 阶段 0：规格锁定

- [x] `check()`：启动失败返回 `error.PipelineSpawnFailed`

验证：
- 已核对 `docs/typed_pipeline_design.md` L409-412，`check()` 的启动失败链路已被锁定为优先返回 `error.PipelineSpawnFailed`；非零退出/信号终止返回 `error.ProcessFailed`；Uya stage 错误返回 `error.PipelineStageFailed`。
- 验证命令：`grep -n "PipelineSpawnFailed" docs/typed_pipeline_design.md` 命中 L409、L412。

## 阶段 0：规格锁定

- [ ] 锁定 checked/observing sink 分层：
  - [x] `check_into(statuses, result)`：固定 all-stage/pipefail，返回 `ProcessFailed` / `PipelineSpawnFailed` / `PipelineStageFailed` 前写入完整 `PipelineResult`
    - 验证：已审阅 `typed_pipeline_design.md` L405-L415 与 L397-L403，为 `check_into` 添加明确的“阶段 0 已锁定”标注；规格已覆盖 all-stage/pipefail、错误返回顺序与返回前必须写入完整 `PipelineResult` 的要求。

---

---

## 阶段 0：规格锁定

父路径：阶段 0：规格锁定 > 锁定 checked/observing sink 分层

- [x] `status_into(statuses, result)`：观察型，非零、signal、启动失败和 Uya stage 错误不作为 sink 自身的 Uya error
  验证：
  - `grep -n '阶段 0 已锁定.*status_into' docs/typed_pipeline_design.md` 命中 L416。
  - `git diff --check` 无空白错误。
