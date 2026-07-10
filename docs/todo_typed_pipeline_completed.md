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

## 阶段 0：规格锁定

- [x] 锁定 `cmd` 的 PATH-searching 语义，并提供 exact-path API `cmd_path`。
  验证（2026-07-10）：复核 `docs/typed_pipeline_design.md` L141-L180 已定义 `cmd(input, program)` 执行 PATH lookup，`cmd_path(input, path)` 执行 exact-path 执行；无隐式路径分隔符处理，路径执行必须通过 `cmd_path`。当前阶段未产生 `.uya` 实现，规格层面已锁定。

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

---

## 类型化管道 TODO / 阶段 0：规格锁定

- [x] 锁定 checked/observing sink 分层：
  - [x] `capture_into(statuses, stdout_buf, stderr_buf, result)` / `capture_limit_into(max_bytes, statuses, stdout_buf, stderr_buf, result)`：观察型，结果中包含完整 `PipelineResult`
    验证（2026-07-10）：
    - `sed -n '218,222p' docs/typed_pipeline_design.md` 确认 `capture_into` / `capture_limit_into` 签名接收 `statuses`、`stdout_buf`、`stderr_buf` 与 `result: &PipelineCaptureResult`。
    - `sed -n '318,332p' docs/typed_pipeline_design.md` 确认 `PipelineCaptureResult` 内嵌完整 `PipelineResult { stage_count: usize }` 与两路 `CaptureStreamResult`。
    - 已新增锁定标记：`grep -n 'capture_into.*observing' docs/typed_pipeline_design.md` 命中 L230-L231，明确其为观察型 sink 且返回内嵌 `PipelineResult`。
    - 本轮未产生代码/测试变更；仅锁定设计规格。

## 类型化管道 TODO / 阶段 0：规格锁定 / 锁定 capture sink 语义

- [x] `capture_into()` 隐式捕获 terminal stdout

验证：
- 命令：`grep -n "阶段 0 已锁定.*capture_into" docs/typed_pipeline_design.md`
- 结果：匹配到 `docs/typed_pipeline_design.md:274` 的锁定段落，确认 `capture_into()` / `capture_limit_into()` 隐式要求 terminal stdout 为 capture，且与显式 stdout file/inherit 冲突时返回 `error.InvalidPipeline`。

## 类型化管道 TODO / 阶段 0：规格锁定

- [ ] 锁定 capture sink 语义：
  - [x] `capture_into()` 隐式捕获 terminal stdout

**归档时间**：2026-07-10  
**验证说明**：归档清理轮，无新增验证命令；该条目在上一轮已标记完成并验证。

---

## 阶段 0：规格锁定

- [x] 锁定 capture sink 语义：
  - [x] stderr 只有显式 `stderr_capture()` 或 `stderr_to_stdout()` 后才进入返回值
    验证：复核 `docs/typed_pipeline_design.md` L274 已明确 capture sink 不会隐式捕获 stderr；L346 规定非 capture 路径（含 inherit、file、merge_stdout 等）`CaptureStreamResult.captured=false`、`byte_count=0`、`complete=false`；L364 说明未启用 stderr capture 时 `stderr_buf` 可为空且 executor 不得写入；L470 明确 `capture_into()` / `capture_limit_into()` 对 unset stderr 默认使用 inherit。语义已锁定，无需代码改动。


---

## 阶段 0：规格锁定

锁定 capture sink 语义：
  - [x] stderr 只有显式 `stderr_capture()` 或 `stderr_to_stdout()` 后才进入返回值
  验证：已在主 todo 中标记为完成，本轮归档清理移入。原始完成状态无需额外验证命令。

---

## 阶段 0：规格锁定

- [~] 锁定 capture sink 语义：
  - [x] 显式 stdout file/inherit 后调用 `capture_into()` / `capture_limit_into()` 报 `InvalidPipeline`

验证（2026-07-10）：
- `sed -n '274p' docs/typed_pipeline_design.md` 确认阶段 0 已锁定：`capture_into()` / `capture_limit_into()` 隐式要求 terminal stdout 为 capture；若调用方已显式配置 terminal stdout 为 file 或 inherit，再调用 capture sink 必须返回 `error.InvalidPipeline`。
- `sed -n '458,467p' docs/typed_pipeline_design.md` 确认冲突策略表新增 `inherit_stdio + capture sink => error.InvalidPipeline`，与已有的 `stdout_file + capture sink => error.InvalidPipeline` 并列。
- `sed -n '470p' docs/typed_pipeline_design.md` 确认 `capture_into()` / `capture_limit_into()` 对 unset stdout 默认使用 capture，且显式 `stdout_capture()` / `stderr_capture()` 要求最终 sink 必须是 capture sink。
- `git diff --check` 无空白错误。
- 本轮未修改生产代码或测试，仅完成规格锁定与文档标记。

---

## 阶段 0：规格锁定

- [x] 锁定 capture sink 语义：
  - [x] capture policy 与 `check` / `check_into` / `status_into` 组合报 `InvalidPipeline`

验证（2026-07-10）：
- `sed -n '458,475p' docs/typed_pipeline_design.md` 确认冲突策略表新增：
  - `stdout_capture + check => error.InvalidPipeline`
  - `stdout_capture + check_into => error.InvalidPipeline`
  - `stdout_capture + status_into => error.InvalidPipeline`
  - `stderr_capture + check => error.InvalidPipeline`
  - `stderr_capture + check_into => error.InvalidPipeline`
  - `stderr_capture + status_into => error.InvalidPipeline`
- `sed -n '473p' docs/typed_pipeline_design.md` 确认显式 `stdout_capture()` / `stderr_capture()` 将对应终端流策略设为 capture，这类 capture policy 只能与 `capture_into()` / `capture_limit_into()` 组合；在已设置 capture policy 的 pipeline 上使用 `check()` / `check_into()` / `status_into()` 必须报 `error.InvalidPipeline`。
- `git diff --check` 无空白错误。
- 本轮未修改生产代码或测试，仅完成规格锁定与文档标记。

## 阶段 0：规格锁定

- [x] 锁定 `CaptureLimitExceeded`：超限后 POSIX 同时终止 process group 与全部直接 PID，Windows 终止 Job Object；取消路径关闭 capture 读端、不得无限 drain 或等待逃离后代持有的 pipe EOF，完成直接 stage 的 reap 后重置输出 result 为空摘要并返回普通 Uya error。
  - 验证：
    - `grep -n "阶段 0 已锁定.*CaptureLimitExceeded" docs/typed_pipeline_design.md` 命中行 436-438
    - 确认新增段落覆盖：POSIX 先 `SIGKILL` process group 再对每个尚未 reap 的直接 PID 补发 `SIGKILL`；Windows 使用 `TerminateJobObject` 并对尚未入 Job 的直接进程单独 `TerminateProcess` 并等待；取消路径关闭 capture 读端、不得无限 drain、不得等待逃离后代 EOF；完成直接 stage reap 后重置输出 result 为空摘要并返回 `error.CaptureLimitExceeded`
  - 相关改动：`docs/typed_pipeline_design.md` 在行 436-438 追加两条“阶段 0 已锁定”声明

---

## 阶段 0：规格锁定

- [x] 锁定空 result 摘要的字段值：`PipelineResult.stage_count=0`；`PipelineCaptureResult` 还需把 stdout/stderr 置为 `captured=false`、`byte_count=0`、`complete=false`。
  验证：复核 `docs/typed_pipeline_design.md` L368、L372 已明确定义：
  - 接收 result 指针的 sink 在返回普通 Uya error、`error.Interrupted` 或 `error.CaptureLimitExceeded` 前，必须把输出 result 重置为空摘要；
  - 空 `PipelineResult` 摘要定义为 `stage_count=0`；
  - 空 `PipelineCaptureResult` 摘要定义为内嵌 `result.stage_count=0`，且 stdout/stderr 的 `captured=false`、`byte_count=0`、`complete=false`。

## 阶段 0：规格锁定

- [x] 锁定正常完成只等待直接 stage：全部直接 stage reap 后做有界非阻塞 capture 收尾并关闭读端，不等待/终止非直接后代；只有 EOF 设置 `complete=true`，EAGAIN/预算 cutoff 必须返回 `complete=false`。
  - 验证：在 `docs/typed_pipeline_design.md` 必要不变量区追加 “阶段 0 已锁定” 标注，措辞与 TODO 对齐；`git diff --check` 无空白错误。

---

## 阶段 0：规格锁定

- [x] 锁定 caller-provided `statuses` / stdout / stderr / result writable region 必须两两不重叠；重叠在任何文件打开或 stage 启动前返回 `InvalidPipeline`。
  验证：已在 `docs/typed_pipeline_design.md` 中锁定该规格。L362 明确 `statuses`、启用 capture 的 `stdout_buf` / `stderr_buf`、以及 `result` 指向的固定大小对象必须两两不重叠，零长度 region 不参与重叠判断；L360 与 L727 要求缓冲区容量、重叠预检和所有流策略验证必须在打开文件或启动 stage 前完成，发现重叠时返回 `error.InvalidPipeline`、消费计划并保持空 result，不得产生外部副作用。未改动 `.uya` 生产代码；本条目为纯规格锁定。

---

## 阶段 0：规格锁定

- [x] 锁定 caller-provided `statuses` / stdout / stderr / result writable region 必须两两不重叠；重叠在任何文件打开或 stage 启动前返回 `InvalidPipeline`。

验证记录：
- 核对设计文档 `docs/typed_pipeline_design.md` L362，caller-provided writable region（`statuses`、`stdout_buf`、`stderr_buf`、`result`）两两不重叠规则已写入，明确重叠时返回 `error.InvalidPipeline`，且不得打开文件或启动 stage。
- 本轮为归档清理，任务已在主 todo 中标记完成。

## 阶段 0：规格锁定

- [x] 锁定 capture exact-fit 探测：达到有效上限但尚未 EOF 时使用独立一字节 scratch；EOF 成功、读到额外字节返回 `CaptureLimitExceeded`，不得停止 drain 后等待 child。
  - 验证：检查 `docs/typed_pipeline_design.md` 已新增“阶段 0 已锁定”引用块，明确 exact-fit overflow probe 的一字节 scratch 行为、EOF/额外字节/`EAGAIN` 三种结果，以及不得停止 drain 后直接等待 child 的约束。
  - 验证命令：`grep -n "阶段 0 已锁定" docs/typed_pipeline_design.md | head -n 1 && sed -n '366,367p' docs/typed_pipeline_design.md`
  - 验证结果：设计文档第 366 行起已包含锁定段落，内容覆盖 scratch probe、`complete=true`、`CaptureLimitExceeded` 与 `complete=false` 分支。

## 阶段 0：规格锁定

- [x] 锁定 `capture_into()` 使用调用方缓冲区容量作为上限，`capture_limit_into()` 在缓冲区容量之外额外施加 `max_bytes`，不引入隐藏默认上限常量。
  - 验证：读取 `docs/typed_pipeline_design.md` 确认规格已写入。
  - 关键锁定点：
    - `capture_into` 的有效 capture 上限来自调用方提供的 stdout/stderr 缓冲区容量（`buffer.len`）。
    - `capture_limit_into` 使用 `min(max_bytes, buffer.len)` 作为每个 captured stream 的有效上限。
    - 第一版不提供隐藏默认 capture limit 常量。
  - 引用位置：
    - L364: `capture_into` 的有效 capture 上限来自调用方提供的 stdout/stderr 缓冲区容量；`capture_limit_into` 使用 `min(max_bytes, buffer.len)` 作为每个 captured stream 的有效上限。
    - L442: `capture_into()` 以调用方缓冲区容量为限制，`capture_limit_into(max_bytes, ...)` 以 `min(max_bytes, buffer.len)` 为限制。
    - L481: `capture_into(...)` 使用调用方提供的 capture 缓冲区容量作为有效上限；`capture_limit_into(max_bytes, ...)` 在缓冲区容量之外额外施加 `max_bytes` 上限；第一版不提供隐藏默认 capture limit 常量。
  - 验证命令：`grep -n "capture_into\|capture_limit_into" docs/typed_pipeline_design.md | head -n 20`
  - 验证结果：成功匹配到 L221、L230、L272、L274、L337、L358、L364、L366、L407、L422、L442、L481 等锁定段落，规格一致且无隐藏默认上限。
# 类型化管道 TODO — 完成归档

## 阶段 0：规格锁定

- [x] 锁定 `capture_into()` 使用调用方缓冲区容量作为上限，`capture_limit_into()` 在缓冲区容量之外额外施加 `max_bytes`，不引入隐藏默认上限常量。
  - 验证：规格条目经 review 后写入 `typed_pipeline_design.md`；本轮仅做规格锁定，未引入生产代码或测试。


## 阶段 0：规格锁定

- [x] 锁定 `stdout_file` / `stderr_file` 为 stream policy transformer，不作为 sink。
  - 验证：读取 `docs/typed_pipeline_design.md` L268-277，确认已添加"阶段 0 已锁定"引用块，明确 `stdout_file(input, path)` / `stderr_file(input, path)` 是 stream policy transformer，不是 sink；transformer 阶段仅复制并保存 `path`，不启动子进程或打开文件。
  - 验证：检查本轮未创建任何生产模块、API 骨架或代码测试。

## 阶段 0：规格锁定

- [x] 锁定空 pipeline 传给任何 sink 返回 `error.InvalidPipeline`。
  - 验证：读取 `docs/typed_pipeline_design.md` 错误分类表与必要不变量，确认已写入“空 pipeline 传给任何 sink 必须返回 `error.InvalidPipeline`”并覆盖 `check()` / `check_into()` / `status_into()` / `capture_into()` / `capture_limit_into()` 及所有未来 sink。
  - 验证命令：`grep -n "空 pipeline 传给 sink" docs/typed_pipeline_design.md` 与 `grep -n "error.InvalidPipeline" docs/typed_pipeline_design.md`
  - 结果：L384、L728 均已包含该规格；L380 已添加“阶段 0 已锁定”标记。

---

## 阶段 0：规格锁定

- [x] 锁定空 pipeline 传给任何 sink 返回 `error.InvalidPipeline`。
  验证（2026-07-10）：
  - `sed -n '380p' docs/typed_pipeline_design.md` 确认 > **阶段 0 已锁定**：空 pipeline 传给任何 sink 必须返回 `error.InvalidPipeline`。此规则覆盖 `check()` / `check_into()` / `status_into()` / `capture_into()` / `capture_limit_into()` 及所有未来新增 sink；执行器不得在没有任何可执行 stage 时启动子进程、打开文件或产生其他外部副作用。
  - `sed -n '386p' docs/typed_pipeline_design.md` 确认错误分类表：`空 pipeline 传给 sink => error.InvalidPipeline`。
  - `sed -n '730p' docs/typed_pipeline_design.md` 确认必要不变量：`sink 要求至少有一个可执行 stage；空 pipeline 传给任何 sink 必须返回 error.InvalidPipeline`。
  - 规格不涉及 `.uya` 实现代码，无需编译器/运行期验证；归档时主 todo 中对应条目为 `[x]`。

## 阶段 0：规格锁定

- [x] 锁定 `inherit_stdio` 是显式策略而不是 reset，和已有 terminal policy 冲突。
  验证（2026-07-10）：
  - 读取 `docs/typed_pipeline_design.md` L466-491，确认冲突策略表已包含 `stdout_file + inherit_stdio`、`stderr_file + inherit_stdio`、`stdout_capture + inherit_stdio`、`stderr_capture + inherit_stdio`、`stdout_file + capture sink`、`inherit_stdio + capture sink`。
  - 确认 L491 已添加“阶段 0 已锁定”引用块：`inherit_stdio(input)` 是显式策略，不是 reset；要求 stdin/stdout/stderr 均处于 `unset` 才能设为 `inherit`，否则返回 `error.InvalidPipeline`；后续 file/capture 同样冲突。
  - 验证命令：`sed -n '466,491p' docs/typed_pipeline_design.md` 与 `grep -n "inherit_stdio" docs/typed_pipeline_design.md`
  - 验证结果：设计文档已锁定该规格，本轮仅修改规格文档，未创建生产模块或测试。

---

## 阶段 0：规格锁定

- [x] 锁定所有 sink 对 unset stdin 默认使用 inherit。
  验证：在 `docs/typed_pipeline_design.md` L489 添加 `> **阶段 0 已锁定**：所有 sink 对 unset stdin 默认使用 inherit` 并附带 stdout/stderr 默认策略说明；`grep` 确认该 callout 存在。

---

## 阶段 0：规格锁定

- [x] 锁定 `cwd` / `env` / `unset_env` 作用于最近追加的 process stage。
  验证（2026-07-10）：
  - 读取 `docs/typed_pipeline_design.md` L257-270，确认已添加"阶段 0 已锁定"引用块，明确 `cwd`、`env`、`unset_env` 是 stage-local transformer，作用于最近追加的 process stage；若当前计划尚无 process stage，或最近 stage 是 Uya stage，必须返回 `error.InvalidPipeline`。
  - 验证命令：`sed -n '257,270p' docs/typed_pipeline_design.md` 与 `grep -n "stage-local transformer" docs/typed_pipeline_design.md`
  - 验证结果：设计文档已锁定该规格，本轮仅修改规格文档，未创建生产模块或测试。

---

## 阶段 0：规格锁定

- [x] 锁定 `cwd` / `env` / `unset_env` 作用于最近追加的 process stage。
  验证（2026-07-10）：
  - 读取 `docs/typed_pipeline_design.md` L257-270，确认已添加"阶段 0 已锁定"引用块，明确 `cwd`、`env`、`unset_env` 是 stage-local transformer，作用于最近追加的 process stage；若当前计划尚无 process stage，或最近 stage 是 Uya stage，必须返回 `error.InvalidPipeline`。
  - 验证命令：`sed -n '257,270p' docs/typed_pipeline_design.md` 与 `grep -n "stage-local transformer" docs/typed_pipeline_design.md`
  - 验证结果：设计文档已锁定该规格，本轮仅修改规格文档，未创建生产模块或测试。

---

# 类型化管道 TODO
## 阶段 0：规格锁定

- [x] 锁定所有 stage 使用同一个 sink-time canonical base-env 快照；overlay 按调用顺序决议，PATH 查找与 spawn 使用同一最终 env block。
  - 验证：文档审查 `docs/typed_pipeline_design.md` L252-L256 的阶段 0 已锁定段落。
  - 确认内容：
    - 所有 process stage 在 sink 开始执行时共享同一个 canonical base-env 快照，来源为 `std.env` 的当前进程环境视图；
    - 每个 stage 在该快照上按 transformer 调用顺序应用自己的 `env` / `unset_env`，后一次覆盖前一次，最终 child env 中同一 key 最多出现一次；
    - PATH 解析与最终 spawn 必须使用同一份已完成 overlay 的不可变 env block，避免查找时环境与 exec 时环境不一致。
  - 无运行命令，纯规格锁定确认。

---

## 阶段 0：规格锁定

- [x] 锁定所有 stage 使用同一个 sink-time canonical base-env 快照；overlay 按调用顺序决议，PATH 查找与 spawn 使用同一最终 env block。
  验证：已在归档前完成并验证。

---

## 阶段 0：规格锁定

- [x] 锁定 POSIX env key 按 byte 区分、Windows env key 按 ordinal case-insensitive 合并且最终 UTF-16 block 使用同一比较规则排序；大小写变体不能重复传给 child。
  验证（2026-07-10）：
  - `sed -n '253p' docs/typed_pipeline_design.md` 确认已写入：
    - POSIX key 比较按 byte 精确匹配；
    - Windows key 比较使用平台 ordinal case-insensitive 规则；
    - 最终 child env 中同一个 key 最多出现一次；
    - Windows bridge 必须把最终 UTF-16 environment block 按同一 case-insensitive 顺序排序并以双 `\0` 结束；
    - 不能把多个大小写变体传给 child。

## 阶段 0：规格锁定

- [x] 锁定 `env` / `unset_env` 复用 `std.env` 的 key/value 校验并在 transformer 阶段复制数据。
  - 验证：读取 `lib/std/env.uya` 的 `env_key_valid`、`with`、`without` 校验规则，确认 `typed_pipeline_design.md` 已对应锁定 `error.EnvInvalidName` / `error.EnvInvalidValue` 返回路径、stage-local 作用域以及 transformer 阶段复制 key/value 到计划私有存储。

---

## 阶段 0：规格锁定

- [x] 锁定相对 `cmd_path` 按该 stage 最终 cwd 解释，而不是按 transformer 调用时的父进程 cwd 解释。
  验证：在 `docs/typed_pipeline_design.md` L242 添加 `> **阶段 0 已锁定**：` 标记；复核 L240-L243 明确相对路径按 stage 最终 cwd 解释、绝对路径按原样执行、实现不得在 transformer 调用时绑定父进程 cwd、且无 `cmd_path` 相对路径按 transformer 调用时 cwd 解释的描述。`docs/typed_pipeline_design.md` L728 不变量列表同步保持该语义。

---

## 阶段 0：规格锁定

- [x] 锁定 Windows drive-relative path（例如 `C:foo`）对 `cmd_path`、`cwd` 和 file redirection 均为 `InvalidPipeline`；只接受明确 absolute 或普通 relative 形式。
  验证（2026-07-10）：
  - `sed -n '242p' docs/typed_pipeline_design.md` 确认已以 `> **阶段 0 已锁定**：` 写入：
    - Windows drive-relative 形式（例如 `C:tool.exe`）依赖进程级 per-drive cwd，无法由本设计的单一 cwd 快照稳定解释；
    - `cmd_path`、`cwd` 和 file-redirection path 都必须在外部副作用前以 `error.InvalidPipeline` 拒绝这种形式；
    - `C:\tool.exe`、UNC/namespace absolute path 和不带 drive prefix 的普通相对路径仍按各自规则处理。
  - `sed -n '729p' docs/typed_pipeline_design.md` 不变量列表同步包含该规则。

---

## 阶段 0：规格锁定

- [x] 锁定 Windows drive-relative path（例如 `C:foo`）对 `cmd_path`、`cwd` 和 file redirection 均为 `InvalidPipeline`；只接受明确 absolute 或普通 relative 形式。
  验证（2026-07-10）：
  - `sed -n '242p' docs/typed_pipeline_design.md` 确认已以 `> **阶段 0 已锁定**：` 写入：
    - Windows drive-relative 形式（例如 `C:tool.exe`）依赖进程级 per-drive cwd，无法由本设计的单一 cwd 快照稳定解释；
    - `cmd_path`、`cwd` 和 file-redirection path 都必须在外部副作用前以 `error.InvalidPipeline` 拒绝这种形式；
    - `C:\tool.exe`、UNC/namespace absolute path 和不带 drive prefix 的普通相对路径仍按各自规则处理。
  - `sed -n '729p' docs/typed_pipeline_design.md` 不变量列表同步包含该规则。

---

- [x] 锁定 sink 开始时捕获宿主 cwd 快照；相对 stage cwd 与 stdin/stdout/stderr file path 都按该快照解释，file path 不跟随 stage-local cwd。
  验证：在 `docs/typed_pipeline_design.md` Stdio 策略部分新增“阶段 0 已锁定”块，明确 sink-time cwd 快照是解释相对 stage cwd 与 file stream path 的唯一基准，file path 不跟随 stage-local cwd。通过 `sed -n '498,500p' docs/typed_pipeline_design.md` 验证文本已落地。

---

## 阶段 0：规格锁定

- [x] 锁定同一 stage 多次 `cwd()` 时最后一次覆盖前一次，不做相对前值的链式拼接。
  验证：在 `docs/typed_pipeline_design.md` 中加入明确「阶段 0 已锁定」段落。
  命令：`grep -n "同一 process stage 多次调用" docs/typed_pipeline_design.md`
  结果：
  ```
  497:> **阶段 0 已锁定**：同一 process stage 多次调用 `cwd(path)` 时，最后一次覆盖前一次；`path` 始终按 sink-time 宿主进程 cwd 快照解释，不相对任何前一次 `cwd` 做链式拼接。例如 `cmd("git") |> cwd("a") |> cwd("b")` 等价于 `cmd("git") |> cwd("b")`，而不是 `cwd("a/b")`。
  ```

---

## 阶段 0：规格锁定

- [x] 锁定 terminal stdout/stderr 策略与 inter-stage pipe 的边界。
  验证（2026-07-10）：
  - `sed -n '272p' docs/typed_pipeline_design.md` 确认已写入：
    > **阶段 0 已锁定**：`stdin_file` 配置第一段 stage 的 stdin。`stdout_file`、`stdout_capture` 配置最后一段 stage 的 stdout。`stderr_file`、`stderr_capture`、`stderr_to_stdout` 配置整条 pipeline 的 stderr 收集策略；第一版不提供 per-stage stderr redirect。
  - `sed -n '505p' docs/typed_pipeline_design.md` 确认已写入：
    > **阶段 0 已锁定**：Inter-stage stdout pipe 是执行拓扑的一部分，不受 `stdout_file` 等终端 stdout 策略影响：stage `i` 的 stdout 连接到 stage `i + 1` 的 stdin；只有最后一个 stage 的 stdout 进入终端 stdout 策略。stderr 默认不参与 stage 间数据流。整条 pipeline 的 stderr 策略等价于 shell group 级重定向，例如 `{ a | b; } 2>file` 或 `{ a | b; } 2>&1`，不是 `a 2>&1 | b` 这种 per-stage 数据流。

## 阶段 0：规格锁定

- [x] 锁定整条 pipeline stderr 策略是 shell group 级语义，不是 per-stage stderr 数据流。
  - 验证：人工复核 `docs/typed_pipeline_design.md` 中以下规格段落：
    - `stderr_file`、`stderr_capture`、`stderr_to_stdout` 被明确定义为配置整条 pipeline 的 stderr 收集策略；第一版不提供 per-stage stderr redirect。
    - 整条 pipeline 的 stderr 策略等价于 shell group 级重定向 `{ a | b; } 2>file` / `{ a | b; } 2>&1`，不是 `a 2>&1 | b` 这种 per-stage 数据流。
    - 多个 stage 同时写入同一个 stderr file/capture pipe 时，只保证 byte stream 不被 executor 主动重排，不保证跨进程日志行顺序稳定。
  - 结论：stderr 策略已在设计文档中锁定为 group-level 语义，任务完成。

---

## 阶段 0：规格锁定

- [x] 锁定整条 pipeline stderr 策略是 shell group 级语义，不是 per-stage stderr 数据流。
  验证（2026-07-10）：
  - `sed -n '272p' docs/typed_pipeline_design.md` 确认 "配置整条 pipeline 的 stderr 收集策略；第一版不提供 per-stage stderr redirect"
  - `sed -n '278p' docs/typed_pipeline_design.md` 确认 "stderr 不会被 capture sink 隐式捕获"
  - `sed -n '505p' docs/typed_pipeline_design.md` 确认 "整条 pipeline 的 stderr 策略等价于 shell group 级重定向 ... 不是 ... per-stage 数据流"

---

## 类型化管道 TODO — 阶段 0：规格锁定

- [x] 锁定 `cmd` 的 PATH-searching 语义，并提供 exact-path API `cmd_path`。
  - 交付：在 `docs/typed_pipeline_design.md` 中为 `cmd_argv` / `cmd` 的 PATH-searching 语义、`cmd_path_argv` / `cmd_path` 的 exact-path 语义以及 `process_resolve_path` 等价 PATH helper 的规则添加“阶段 0 已锁定”标记。
  - 验证命令：`git diff --check docs/todo_typed_pipeline.md docs/typed_pipeline_design.md`
  - 验证结果：通过，无空白/格式错误。

---

## 阶段 0：规格锁定

- [x] 锁定 `cmd` 只接受不含路径分隔符的命令名；路径执行必须使用 `cmd_path`。
  验证（2026-07-10）：
  - `sed -n '240p' docs/typed_pipeline_design.md` 确认阶段 0 已锁定：`cmd_argv` / `cmd` 是 PATH-searching API，只接受平台定义的 bare command name；POSIX bare name 不得包含 `/`；Windows bare name 不得包含 `/`、`\`、drive/namespace 前缀或 `:`；若调用方要传绝对路径、相对路径或已解析出的可执行文件，必须使用 `cmd_path_argv` / `cmd_path`。
  - `sed -n '242p' docs/typed_pipeline_design.md` 确认阶段 0 已锁定：`cmd_path_argv` / `cmd_path` 是 exact-path API，路径中不做 PATH 查找。
  - `sed -n '387p' docs/typed_pipeline_design.md` 确认错误分类表：`cmd 命令名为空、cmd 名称含路径分隔符 => error.InvalidPipeline`。
  - `git diff --check docs/todo_typed_pipeline.md docs/typed_pipeline_design.md` 无空白/格式错误。
  - 本轮未修改生产代码或测试，仅完成规格锁定与归档。

## 阶段 0：规格锁定

- [x] 锁定 `cmd` PATH 查找复用 `std.process` / `std.path` 平台 helper，不在 executor 内重复实现。
  验证：
  - `docs/typed_pipeline_design.md` L246-L251 已锁定 PATH 查找属于 `std.process` / `std.path` 平台敏感逻辑，由 `process_resolve_path(program, env, cwd)` 或等价 helper 执行，pipeline executor 不得另写一套。
  - `docs/std_script_design.md` L277-L279 已补充说明：PATH 查找语义由 `std.process` 内部复用 `std.path` 的平台 helper 实现，pipeline executor 只消费解析后的绝对 `exec_path`。
  - `git diff --check` 通过，无空白错误。


## 阶段 0：规格锁定

- [x] 先定义可由 pipeline 复用的 PATH helper，例如 `process_resolve_path(program, env, cwd)` 或等价接口。
  - 交付：在 `docs/typed_pipeline_design.md` 新增 `### PATH helper 接口` 小节，定义 `process_resolve_path(program, env, cwd)` 的函数签名、参数语义（`program`、`env`、`cwd`）与 `ProcessResolvePathResult` 结果分类；在 `docs/std_script_design.md` 同步引用该 helper 名称与规则文档。
  - 验证：
    - `git diff --check` 通过，无空白错误。
    - `sed -n '238,280p' docs/typed_pipeline_design.md` 确认新增接口小节及规则归属正确。
    - `git diff docs/typed_pipeline_design.md docs/std_script_design.md` 确认仅涉及规格文档的 PATH helper 定义与引用更新。

## 阶段 0：规格锁定

- [x] 锁定 PATH 缺失、空/相对 component、Windows `.exe` fallback、无隐式 PATHEXT/`cmd.exe` 和 lookup/spawn 失败分类。
  - 验证：更新 `docs/typed_pipeline_design.md` §"PATH helper 接口"，明确写入以下内容：
    - PATH 缺失返回 `path_not_found`，不注入默认搜索目录（L278）。
    - POSIX 用 `:`、Windows 用 `;` 分隔；空 component 与 relative component 均以 stage 最终 cwd 为基准，不隐式把当前目录插入搜索序列（L279）。
    - Windows 对每个 component 先尝试原 bare name，无扩展名时再尝试追加 `.exe`（扩展名比较不区分大小写）；MVP 不把 `.bat`/`.cmd` 当可执行映像，也不为了 PATHEXT 隐式调用 `cmd.exe`（L280）。
    - lookup 阶段只返回 `path_not_found` / `permission_denied` / `platform_error`；`cwd_unavailable`、`process_create_failed`、`execution_domain_failed`、`stdio_setup_failed`、`exec_failed` 属于 spawn 阶段；TOCTOU 失败统一由 spawn 报告（L268-L274）。
  - 文件校验：`grep -n "阶段 0 已锁定" docs/typed_pipeline_design.md | head -n 5` 显示新增锁定段落已落地。

---

## 阶段 0：规格锁定

- [x] 锁定 PATH 缺失、空/相对 component、Windows `.exe` fallback、无隐式 PATHEXT/`cmd.exe` 和 lookup/spawn 失败分类。
  验证（2026-07-10，归档清理轮）：
  - `sed -n '260,290p' docs/typed_pipeline_design.md` 确认 `process_resolve_path` 的 lookup 阶段失败分类（`path_not_found` / `permission_denied` / `platform_error`）与 spawn 阶段失败分类已分离，TOCTOU 失败统一归入 spawn 阶段报告。
  - `sed -n '276,280p' docs/typed_pipeline_design.md` 确认搜索规则已锁定：PATH 缺失返回 `path_not_found`；POSIX 用 `:`、Windows 用 `;` 分隔；空 component 与 relative component 以 stage 最终 cwd 为基准；Windows 先尝试原 bare name，无扩展名时追加 `.exe`；MVP 不把 `.bat`/`.cmd` 当可执行映像，也不为了 PATHEXT 隐式调用 `cmd.exe`。
  - `grep -n "阶段 0 已锁定" docs/typed_pipeline_design.md | head -n 10` 命中 L268、L276、L287 等锁定段落。
  - `git diff --check docs/todo_typed_pipeline.md docs/typed_pipeline_design.md docs/todo_typed_pipeline_completed.md` 通过，无空白/格式错误。
  - 本轮为归档清理，已将主 todo 中残留的 `[x]` 条目移除并移入完成归档；未修改生产代码或测试。

## 阶段 0：规格锁定

- [x] 锁定错误分类：API 误用返回 `InvalidPipeline`；stage 启动链路失败和 Uya stage 错误进入 `PipelineResult`；文件重定向、pipe、内存、编码转换等执行器资源失败返回普通 Uya error；executor 自身收到未忽略的取消信号返回 `Interrupted`。
  - 交付物：`docs/typed_pipeline_design.md` 新增「错误分类（阶段 0 已锁定）」章节，明确四类错误边界与对应示例表。
  - 验证：`git diff --check docs/typed_pipeline_design.md docs/todo_typed_pipeline.md docs/todo_typed_pipeline_completed.md` 通过，无尾随空格或冲突标记。

## 阶段 0：规格锁定

- [x] 锁定错误分类：API 误用返回 `InvalidPipeline`；stage 启动链路失败和 Uya stage 错误进入 `PipelineResult`；文件重定向、pipe、内存、编码转换等执行器资源失败返回普通 Uya error；executor 自身收到未忽略的取消信号返回 `Interrupted`。

  验证：
  - 错误分类已写入 `docs/typed_pipeline_design.md` 第 418-421、424-434 行，明确区分四类返回路径。
  - 检查命令：`grep -n "API 误用返回\|Stage 启动链路失败\|文件重定向、pipe\|Executor 自身收到" docs/typed_pipeline_design.md`
  - 输出命中 4 条规则说明，对应 `error.InvalidPipeline`、`PipelineResult`、普通 Uya error、`error.Interrupted`。


---

## 阶段 0：规格锁定

- [x] 决定 `cmd` 使用 Uya 裸变参 `...` 加 `@params` 校验，还是使用基于 slice 的 `cmd_argv` API。
  - 决策：process-only MVP 使用基于 slice 的 `cmd_argv` / `cmd_path_argv` 基础 API；裸变参 `cmd` / `cmd_path` 在编译器支持 typed varargs materialization 后仅作为 facade。
  - 依据：
    - `docs/typed_pipeline_design.md` L20-L21 明确 MVP 示例使用 slice 形式，避免依赖尚未完成的 typed varargs 反射能力。
    - L42-L50 说明 `cmd(...)` 只有在编译器补齐 typed varargs materialization 后才能作为 slice API 的人体工学 facade。
    - L236-L238 说明 Uya 裸尾随 `...` 当前不能当作可枚举、可类型检查、可保存生命周期的 argv 列表；第一版必须先实现 `cmd_argv` / `cmd_path_argv`。
  - 验证命令与结果：
    - `grep -n "cmd_argv\|cmd_path_argv" docs/typed_pipeline_design.md | head -n 10` 命中 L200-L205、L236-L240、L244 等，确认 slice API 已作为基础 API 锁定，裸变参 `cmd` / `cmd_path` 仅标注为后续 facade。
    - `sed -n '20,50p' docs/typed_pipeline_design.md` 确认 MVP 示例使用 `cmd_argv` / `cmd_path_argv` slice 形式。
    - `sed -n '236,238p' docs/typed_pipeline_design.md` 确认裸变参 `...` 不能直接读取 `@params`，第一版必须先实现 slice 形式 API。
    - `git diff --check docs/todo_typed_pipeline.md docs/typed_pipeline_design.md docs/todo_typed_pipeline_completed.md` 通过，无空白错误。

---

## 阶段 0：规格锁定

- [x] 若开放裸变参 `cmd(input, program, ...)`，明确 `@params` 包含固定参数，必须跳过 `input` / `program` 后校验剩余 argv。
  验证（2026-07-10）：在 `docs/typed_pipeline_design.md` L240 新增“阶段 0 已锁定”规格块，明确 `@params` 包含 `input`（索引 0）和 `program` / `path`（索引 1）两个固定参数；materialization 时必须从索引 2 开始枚举剩余实参并逐项校验类型为 `&const byte`，不得把整个 `@params` 当作 argv 列表，也不能假设 `@params[0]` / `@params[1]` 是可变参的一部分。复核文档 L236-L240 语义一致；当前阶段无 `.uya` 实现，规格层面已锁定。

---

## 阶段 0：规格锁定

- [x] MVP 优先考虑 `cmd_argv` / `cmd_path_argv` 基础 API，裸变参只作为 facade。

验证：
- 在 `docs/typed_pipeline_design.md` “推荐的基础 API” 章节顶部追加阶段 0 锁定声明，明确 `cmd_argv` / `cmd_path_argv` 为 process-only MVP 先实现的基础 API，裸变参 `cmd` / `cmd_path` 仅在 typed varargs materialization 完备后作为 facade 开放。
- 在 `docs/std_script_design.md` `std.process` 1.1 语义要求中追加同义锁定条目，确保分层文档一致。
- 运行 `git diff --check` 无空白错误。
# 类型化管道 TODO — 完成归档

## 阶段 0：规格锁定

- [x] 锁定公开 `Pipeline` 必须依赖真正 opaque / non-copyable 类型能力；导出普通 struct/raw pointer handle 不得作为稳定 API。
  - 验证：审查 `docs/typed_pipeline_design.md` 的 `Pipeline 类型` 章节，确认已追加 `**阶段 0 已锁定**：公开 Pipeline 必须依赖真正 opaque / non-copyable 类型能力；普通 export struct 或 raw pointer handle 不得作为稳定 API。` 的明确声明。

# 类型化管道 TODO 完成归档

## 阶段 0：规格锁定

- [x] 若内部 bring-up 使用 capability handle，必须使用 generation 校验与私有注册表，并拒绝伪造、过期和重复消费；公开 API 仍等待 opaque 类型。
  - 验证：已在 `docs/typed_pipeline_design.md` 的 `## Pipeline 类型` 下追加独立的阶段 0 锁定块，明确要求 capability = 整数索引 + monotonic generation、私有注册表、拒绝伪造/过期/重复消费、防御层定位、公开 API 不透明以及并发安全。
  - 验证命令：`grep -n '阶段 0 已锁定：若内部 bring-up 使用 capability handle' docs/typed_pipeline_design.md`
  - 实际验证：
    - `grep -n 'Capability 形式' docs/typed_pipeline_design.md` -> 149:> 1. **Capability 形式**：...
    - `grep -c '拒绝伪造\|拒绝过期\|拒绝重复消费\|私有注册表' docs/typed_pipeline_design.md` -> 8


---

## 阶段 0：规格锁定

- [x] 锁定 transformer/sink 在所有返回路径上消费 input，失败路径释放计划；未进入 sink 的 live pipeline 离开作用域时自动 drop。

完成说明：在 `docs/typed_pipeline_design.md` 的“资源生命周期锁定”段落追加“阶段 0 已锁定”块，明确 transformer/sink 在所有返回路径上消费 input、失败路径释放输入计划及本次调用已分配资源、未进入 sink 的 live pipeline 离开作用域时自动 drop 释放 argv/env/stream policy/stage 存储。

验证：
```bash
grep -n "阶段 0 已锁定" docs/typed_pipeline_design.md | head -n 5
sed -n '/资源生命周期锁定/,/已消费或已 drop/p' docs/typed_pipeline_design.md
```
验证结果：确认设计文档中已出现覆盖上述三条规则的锁定声明，且上下文保留 pipeline() 返回 live 计划、transformer/sink 消费规则、自动 drop 与 capability 重复消费防御等完整约束。

---

## 阶段 0：规格锁定

- [x] 锁定 transformer/sink 在所有返回路径上消费 input，失败路径释放计划；未进入 sink 的 live pipeline 离开作用域时自动 drop。
  验证：已在归档前完成并验证。

---

## 阶段 0：规格锁定

- [x] 决定 `_` pipeline 占位符语法糖是延期，还是作为显式 parser/checker 工作实现。
  决定：延期实现。process-only MVP 使用显式 `pipeline()` 作为空管道起点；`_` 不在 parser/checker 中作为 pipeline 占位符特殊处理。原因：`_` 已在 discard assignment、模式、部分实参位置有特殊语义，若要在 pipeline 第一个 `Pipeline` 实参位置引入新语义，需要独立的 parser/checker 设计与冲突分析，不属于 process-only MVP 必需功能，可在 pipeline 核心稳定后再作为显式语法糖追加。相关设计文档已同步标记为“阶段 0 已锁定：延期”。
  验证（2026-07-10）：
  - `sed -n '122,135p' docs/typed_pipeline_design.md` 确认 `_` 延期决定与 `pipeline()` 显式构造已写入设计文档。
  - `grep -n 'parser MVP 保持空 pipeline 构造显式；暂不特殊处理' docs/todo_typed_pipeline.md` 确认 parser MVP 仍保持“暂不特殊处理 `_`”。

---

## 阶段 0：规格锁定

- [x] 明确 process-only MVP 不包含自定义 Uya stage；Uya stage 需等待 owned-data 与满足取消/终止门槛的 execution domain 方案。
  验证（2026-07-10）：
  - `sed -n '18,29p' docs/typed_pipeline_design.md` 确认已追加“阶段 0 已锁定”块，明确 process-only MVP 只包含外部进程 stage，不实现/暴露/测试自定义 Uya 流 stage，并列出 `PipelineStage` / `StreamReader` / `StreamWriter` / `stage<T>()` 等名称锁定为未来扩展但不属于 MVP。
  - `sed -n '20,24p' docs/typed_pipeline_design.md` 确认 Uya stage 开放的两个前置条件：owned-data 规则确定；execution domain 满足强制取消/终止门槛（内存安全强制 task 终止或隔离 worker process）。
  - `sed -n '238p' docs/std_script_design.md` 确认 `std.process` 语义要求已同步加入同义说明。
  - `git diff --check docs/todo_typed_pipeline.md docs/typed_pipeline_design.md docs/std_script_design.md` 通过，无空白/格式错误。
  - 本轮未创建生产模块、API 骨架或代码测试，仅完成规格锁定与文档同步。

---

## 阶段 0：规格锁定

- [x] 锁定 POSIX process group 通过 parent/child 双侧 `setpgid`、per-child startup-report/launch pipe 与显式 `RUN`/`ABORT` protocol 建立；EOF 必须 abort，不能释放 child；不得用无法识别 token 接收者的共享 launch pipe。
  验证（2026-07-10）：在 `docs/typed_pipeline_design.md` L809 添加 `> **阶段 0 已锁定**` 引用，明确：
  - group leader 由首个 child 调用 `setpgid(0, 0)` 建立，后续 child 与 parent 双侧调用 `setpgid(0, leader_pid)` / `setpgid(child_pid, leader_pid)` 并验证；
  - 每个 child 使用独立 launch pipe 与 close-on-exec startup-report pipe，禁止共享无法识别接收者的 launch pipe；
  - 只有显式 `RUN` token 可释放 child 进入 chdir/dup2/exec，`ABORT`、EOF、短读或未知 token 必须关闭 fds 并 `_exit`；
  - parent 必须 poll 全部 report pipe，收到每个 child `READY` 且完成 parent-side `setpgid` 验证前不得写 `RUN`；
  - 失败路径向未释放 child 写 `ABORT` 后强制取消并 reap。
  验证命令：
  - `grep -n "阶段 0 已锁定.*POSIX process group" docs/typed_pipeline_design.md` → 命中 L809；
  - `sed -n '809p' docs/typed_pipeline_design.md` → 显示完整锁定引用。

---

## 阶段 0：规格锁定

- [x] 锁定每个 POSIX child 在 READY 前关闭所有无关控制/数据/runtime-broker fd，parent 在最后一个继承者 fork 后立即关闭对应 child-only fd，发送 RUN 前不再持有 capture writer。
  验证（2026-07-10）：在 `docs/typed_pipeline_design.md` L811 添加 `> **阶段 0 已锁定**` 引用，明确：
  - 每个 POSIX child 在 READY 前必须关闭所有与本 stage 无关的控制 fd、数据 fd 和 runtime-broker fd；
  - parent 在每次 fork 成功后立即关闭该 child 的 launch-read/report-write 端，并在某个 data/file fd 的最后一个预期继承者 fork 成功后立即关闭 parent 副本；
  - 全部 child READY 后、发送任何 `RUN` token 前，parent 不得再持有任何 child-only control/data fd 或 capture writer。
  同时把原 L811 混合的 signal mask/disposition 内容拆入独立列表项（L24 后续锁定），把 fd 避开 0/1/2 内容保留为独立列表项（L18 后续锁定），避免提前锁定相邻条目。
  验证命令：
  - `grep -n "阶段 0 已锁定.*POSIX child 在 READY 前" docs/typed_pipeline_design.md` → 命中 L811；
  - `sed -n '811p' docs/typed_pipeline_design.md` → 显示完整锁定引用。

---

## 阶段 0：规格锁定

- [x] 锁定所有 POSIX 内部 control/data/file source fd 避开 0/1/2，或实现循环安全 remap 与 `source == target` 的 `FD_CLOEXEC` 清理；不能假设宿主标准 fd 已打开。

**验证记录**：
- 更新 `docs/typed_pipeline_design.md`：在 POSIX 后端执行章节新增/升级“阶段 0 已锁定”段落，明确所有内部 control/data/file source fd 必须 >2 或等价循环安全 remap，并显式处理 `source == target` 时清除 `FD_CLOEXEC`。
- 同步更新设计文档末尾 checklist 中对应条目为“阶段 0 已锁定”引用。
- 规格验证命令：
  ```bash
  git diff --check docs/typed_pipeline_design.md docs/todo_typed_pipeline.md
  ```
- 结果：无空白错误，diff 仅含设计文档与 TODO 状态变更。

---

## 阶段 0：规格锁定

- [x] 锁定 controlling terminal 只有在 executor 当前就是前台 process group 时才转交/恢复 PGID；后台 executor 不得抢占终端，终止信号仍需转发。
  验证（2026-07-10）：已在 `docs/typed_pipeline_design.md` L676 添加 `> **阶段 0 已锁定**：` 标记，明确只有 `tcgetpgrp(tty_fd) == getpgrp()` 时才允许 `tcsetpgrp` 转交前台 PGID；后台 executor 不得抢占终端，所有转交路径必须恢复保存的前台 PGID，从未转交不得恢复；并发 sink 按 terminal identity 持有独占 foreground lease，先恢复终端再释放 lease，终止信号仍必须转发。同文档 L818 内部计划草图对应项也已标记为阶段 0 已锁定。复核 `git diff -- docs/typed_pipeline_design.md` 确认只新增锁定标记与必要措辞调整，无实现代码改动。

## 阶段 0：规格锁定

- [x] 锁定 controlling terminal 只有在 executor 当前就是前台 process group 时才转交/恢复 PGID；后台 executor 不得抢占终端，终止信号仍需转发。
  - 验证：规格已写入 `docs/typed_pipeline_design.md`。
  - 相关位置：
    - L676: > **阶段 0 已锁定**：controlling terminal 的前台 PGID 只有在 executor 自身当前就是前台 process group 时才允许转交给 pipeline group，并且只在确实发生过转交时才恢复。
    - L818: > **阶段 0 已锁定**：只有 executor 自身当前拥有 controlling terminal 前台权时才能把前台 PGID 转交给 pipeline，并且只在确实转交后恢复；并发 sink 必须按 terminal identity 持有独占 foreground lease，先恢复终端再释放 lease，其他终止信号仍必须转发。
  - 验证命令：`grep -n "阶段 0 已锁定" docs/typed_pipeline_design.md`
  - 验证结果：命中 L676、L818，规格文本存在且与 TODO 条目一致。

## 阶段 0：规格锁定

- [x] 锁定 Windows child 必须 suspended 创建、加入 Job Object 后才能恢复，并使用严格 handle allowlist；默认 direct-stage 模式不使用 kill-on-close，取消显式终止 Job。
  - 验证：在 `docs/typed_pipeline_design.md` 的 `### Windows 后端` 下新增阶段 0 已锁定块，覆盖 suspended 创建、先加入 Job 后恢复、严格 handle allowlist、默认不使用 kill-on-close、取消时显式终止 Job、执行释放边界、不静默降级七点。
  - 验证命令：`grep -n "阶段 0 已锁定" docs/typed_pipeline_design.md` 显示 Windows 后端锁定块存在；`grep -n "CREATE_SUSPENDED\|AssignProcessToJobObject\|PROC_THREAD_ATTRIBUTE_HANDLE_LIST\|JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE\|TerminateJobObject" docs/typed_pipeline_design.md` 显示相关关键词覆盖完整。

## 阶段 0：规格锁定

- [x] 锁定平台中立执行释放边界：POSIX 为消费 RUN，Windows 为 primary thread 成功 resume，未来 Uya stage 为开始调用 `run`；未越过为 `not_started`，已释放后被 executor 强制终止为 `cancelled`，不声称用户指令已经实际运行。
  - 验证：确认 `docs/typed_pipeline_design.md` 已在“结果模型”与“POSIX 后端”两处添加 `> **阶段 0 已锁定**` 标记，且边界定义覆盖 POSIX `RUN`、Windows `ResumeThread`、未来 Uya `run`、`not_started` 与 `cancelled`。
  - 验证命令：`grep -n "阶段 0 已锁定.*执行释放边界" docs/typed_pipeline_design.md`
  - 结果：匹配到 2 行（结果模型段与 POSIX 后端段），且 `git diff --check` 无空白错误。

---

## 阶段 0：规格锁定

- [x] 锁定信号/console cancellation 由 runtime broker 唤醒正常 executor 路径，去重转发、有限取消、清理后返回 `error.Interrupted`；异步 handler/callback 不执行复杂清理。
  验证（2026-07-10）：在 `docs/typed_pipeline_design.md` L497-L507 与 L834 追加“阶段 0 已锁定”标记；复核 `error.Interrupted` 返回路径、broker 唤醒正常 poll/wait 路径、去重转发与 bounded grace period 后强制终止、异步 handler 不执行复杂清理均已写入设计。当前阶段未产生 `.uya` 实现，规格层面已锁定。`git diff --check` 无错误。

---

## 阶段 0：规格锁定

- [x] 锁定 runtime broker 用订阅/引用计数协调并发 sink；进程定向信号通知全部活跃 sink，最后一个订阅者只能在仍拥有 disposition 时恢复原 handler，等待 terminal lease 前必须先完成订阅。
  验证（2026-07-10）：
  - `sed -n '497,501p' docs/typed_pipeline_design.md` 确认 broker 集中拥有 handler、通过引用计数/订阅表管理并发 sink、保存并恢复 disposition、进程定向信号通知全部活跃 sink、最后一个订阅者仅在自己仍拥有 disposition 时恢复 handler 的规格已写入并标记为"阶段 0 已锁定"
  - `sed -n '648,649p' docs/typed_pipeline_design.md` 确认 sink 执行顺序：先 subscribe broker，再 acquire terminal lease
  - `sed -n '833p' docs/typed_pipeline_design.md` 确认"等待 terminal lease 前先注册，注销后 handler/callback 不得访问 execution state"已标记为"阶段 0 已锁定"
  - `git diff --check` 通过，无空白错误
