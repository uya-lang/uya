# 标准脚本运行时 TODO

> **核对头（2026-10-19）**：本 TODO 的"用 Uya 脚本替换仓库 shell"目标**尚未开始迁移**（`.ush` 文件数仍为 **0**），但**标准库侧 Phase 2/3/4.1 的实际实现已远超本文档的勾选状态**——上一轮只核对了 `.sh`/`.ush` 计数，没有回填已完成条目。本轮逐条按代码补正：
>
> | 原文标注 | 2026-10-19 实际状态 | 证据 |
> |---|---|---|
> | Phase 2.2 `std.env` 全部未勾 | **已完成** | `lib/std/env.uya`：`get`（`:112`）、`has`（`:135`）、`env_key_valid`（`:22`）；`EnvBlockBuilder`（`:154`）含 `inherit_current`（`:166`）、`inherit_from`（`:180`）、`with`（`:194`）、`without`（`:217`）、`build`（`:466`）、`envp`（`:497`）、`len`（`:506`）、`drop`（`:515`） |
> | Phase 2.1 `std.path` | **已完成** | `lib/std/path.uya`：`is_abs`（`:259`）、`normalize`（`:267`）、`basename`（`:391`）、`stem`（`:418`）、`extension`（`:446`）、`dirname`（`:474`）、`join`（`:516`）、`find_executable`（`:588`）、`path_list_separator`（`:242`）、`executable_suffix`（`:251`）；回归 `tests/test_std_path_module.uya` |
> | Phase 2.3 `std.fs` 全部未勾 | **仍未做** | 仓库**没有** `lib/std/fs.uya`；`grep` 无 `fs_exists`/`fs_mkdir_all`/`fs_read_text` 等高层 API。只有底层原语：`lib/std/io/file.uya`（`file_open` `:115` 等）与 `lib/libc/syscall.uya`（`sys_mkdir` `:983`、`sys_rmdir` `:987`、`sys_unlink` `:978`、`sys_rename` `:1115`、`sys_stat` `:1015`、`sys_getdents64` `:1081`） |
> | Phase 3 `std.process` 全部未勾 | **已用另一种模型完成**（**不是** `Command/Child/ExitStatus/Output`） | `lib/std/process.uya` 的 `export opaque struct Pipeline`（`:2609`）+ `PipelineStageStatus`（`:125`）+ `PipelineResult`（`:136`）+ `PipelineCaptureResult`（`:148`）；能力对应：argv 构造 `cmd_argv`（`:3053`）/ `cmd_path_argv`（`:3065`）、cwd `cwd`（`:3102`）、env overlay `env`（`:3113`）/ `unset_env`（`:3121`）、stdin/stdout/stderr 重定向 `stdin_file`（`:3152`）/`stdout_file`（`:3160`）/`stderr_file`（`:3168`）、捕获 `stdout_capture`（`:3176`）/`stderr_capture`（`:3184`）/`stderr_to_stdout`（`:3192`）、检查 `check` / `check_into` / `status_into` / `capture_into` / `capture_limit_into`（`lib/std/script/file.uya` 导出 20 个 facade 入口）。退出码语义由 `PipelineStageStatusKind`（`:101`：`exited` / `signaled` / `spawn_failed` / `cancelled` / `stage_failed`…）+ `PipelineSpawnFailureKind`（`:112`）+ `platform_code` 表达 |
> | Phase 4.1 `std.script` facade | **部分完成** | 模块是 `lib/std/script/file.uya`（不是 `lib/std/script.uya`），**只重导出 process-only typed pipeline API**；4.1 里列的 `run_checked` / `capture_text` / `assert_exit_code` / `require_tool` / `project_root` / `workspace_temp_dir` / `fail` / `log_info` / `log_warn` **一个都没有** |
> | Phase 4.2 / 4.3 / 5 / 6 / 7 全部未勾 | **仍未做** | `.ush` 实测 **0** 个；`src/main.uya` 无 `COMMAND_SCRIPT`（`uya script` 子命令不存在）；`lib/std/process.uya` 的 `tos_windows` 只用于路径校验（`:858`/`:879`），`grep -rln "CreateProcessW\|CreateJobObject"` 无命中 |
>
> 仓库脚本规模（2026-10-19 实测）：`find . -name '*.sh' -not -path './.git/*' | wc -l` → **198**；`find tests -maxdepth 1 -name '*.sh'` → **184**；`find . -name '*.ush'` → **0**（上一版 inventory 记的是 183，期间新增 15 个 `.sh`）。
>
> 已归档的部分见 `todo_std_script_completed.md`；下方未勾选条目即为真实剩余工作。

**状态**：executable TODO, planning
**更新日期**：2026-06-29（正文）；2026-10-19 回填已完成项
**配套设计**：[`std_script_design.md`](std_script_design.md)

---

## 当前定位

本 TODO 的第一目标不是做“bash 兼容层”，而是让 Uya 能逐步替换仓库中的 `xxx.sh`：

- `tests/*.sh`
- 部分构建/验证辅助脚本
- 后续再考虑更复杂的 `src/compile.sh`

执行原则：

- 先把脚本替换目标分批
- 先补结构化标准库，再补 `uya script` UX
- 先 hosted Linux / macOS，再补 Windows hosted backend
- 先替仓库脚本，再谈通用 shell 能力

### 脚本文件后缀约定

- Uya 脚本统一使用 `.ush` 后缀。
- `.uya` 保留为普通 Uya 源文件后缀；即使带 shebang 的 `.uya` 仍可被当前 lexer 兼容解析，也不作为标准脚本后缀。
- 从 `.sh` 迁移脚本时，新文件命名应从 `xxx.sh` 对应到 `xxx.ush`，初期与旧 `.sh` 并存。

---

## 总览表

| Phase | 阶段 | 状态 | 目标 |
|-------|------|------|------|
| 0 | 盘点与基线 | 计划中 | 给现有 `.sh` 建复杂度分层与行为 oracle |
| 1 | 运行时基础缺口 | 计划中 | 补 env、pipe、host bridge 等基础缺口 |
| 2 | `std.path` / `std.env` / `std.fs` MVP | 计划中 | 替掉常见文件/路径/环境变量 shell 片段 |
| 3 | `std.process` MVP | 计划中 | 结构化进程执行、捕获、重定向、退出码 |
| 4 | `std.script` facade + 第一批迁移 | 计划中 | 替换一批简单脚本 |
| 5 | `uya script` 与 shebang | 计划中 | 补脚本入口 UX |
| 6 | Windows hosted backend | 计划中 | 让脚本跨平台承诺真正成立 |
| 7 | 扩批迁移与性能收口 | 计划中 | 替更多 `.sh`，接入 `--exec` 优化 |

---

## Phase 1：运行时基础缺口

### 1.2 管道与重定向基础

### 1.3 hosted backend 缺口

### 1.4 shebang 预研


---

## Phase 2：`std.path` / `std.env` / `std.fs` MVP

### 2.1 `std.path`

- [x] 新建 `lib/std/path.uya` 或等价模块。（2026-10-19：`lib/std/path.uya` 已存在，回归 `tests/test_std_path_module.uya`）
- [x] `is_abs`（`:259`）、`normalize`（`:267`）、`basename`（`:391`）、`stem`（`:418`）、`extension`（`:446`）、`dirname`（`:474`）、`join`（`:516`）、`find_executable`（`:588`）
- [x] 平台相关：`path_list_separator`（`:242`）、`executable_suffix`（`:251`）

### 2.2 `std.env`

- [x] 新建 `lib/std/env.uya` 或等价模块。（2026-10-19：`lib/std/env.uya` 已存在）
- [x] 提供：
  - [x] `get`（`lib/std/env.uya:112`）
  - [x] `has`（`:135`）
  - [x] `inherit_current`（`EnvBlockBuilder.inherit_current`，`:166`；另有 `inherit_from` `:180`）
  - [x] env overlay builder（`export struct EnvBlockBuilder`，`:154`）
  - [x] child-only `with/remove`（`with` `:194`、`without` `:217`；`build()` `:466` 产出 null 结尾 envp、`envp()` `:497` 取用）
- [x] 明确哪些 API 是“读当前环境”，哪些 API 是“构造子进程环境”。（读：`get`/`has`；构造子进程：`EnvBlockBuilder.*` + `build`/`envp`）
- [~] 为空值、缺失值、重复键、覆盖顺序补测试。（2026-10-19：`EnvBlockBuilder` 内含 `last_op_index_for_key` `:229`、`key_seen_in_ops_before` `:258`、`final_set_op_for_key` `:272`、`visible_entry_count` `:295` 等去重/覆盖逻辑，但**未找到 env 专项测试文件**）

### 2.3 `std.fs`

- [ ] 新建 `lib/std/fs.uya` 或等价模块。
- [ ] MVP 提供：
  - [ ] `exists`
  - [ ] `is_file`
  - [ ] `is_dir`
  - [ ] `mkdir`
  - [ ] `mkdir_all`
  - [ ] `remove_file`
  - [ ] `remove_dir`
  - [ ] `remove_dir_all`
  - [ ] `rename`
  - [ ] `read_text`
  - [ ] `write_text`
  - [ ] `read_bytes`
  - [ ] `write_bytes`
  - [ ] `read_dir`
  - [ ] `temp_dir`
  - [ ] `create_temp_dir`
- [ ] 为 “替换 `mkdir -p` / `rm -rf` / `test -f` / `cat > file`” 的高频场景补回归。

---

## Phase 3：`std.process` MVP

> 2026-10-19 核对：Phase 3 的**目标能力**已实现，但**数据模型与本文设想不同**——落地的是 process-only typed pipeline（`Pipeline` capability + executor），不是 `Command/Child/ExitStatus/Output`。下列条目按"能力是否具备"勾选，模型名不一致处已注明。

- [x] 新建 `lib/std/process.uya` 或等价模块。（`export opaque struct Pipeline` `:2609`）
- [~] 设计 `Command` / `Child` / `ExitStatus` / `Output` 数据模型。（**改为** `Pipeline`（`:2609`）+ `PipelineStageStatus`（`:125`）+ `PipelineResult`（`:136`）+ `PipelineCaptureResult`（`:148`）+ `CaptureStreamResult`（`:141`）；`Pipeline` 是 move-only 不透明 capability，`drop` 见 `:2613`）
- [x] 实现主路径：
  - [x] `spawn`（pipeline executor 内的 fork/exec 阶段；`PipelineStageStatusKind.spawn_failed` 与 `PipelineSpawnFailureKind` 覆盖失败分类，`:101`/`:112`）
  - [x] `status`（`status_into`，`lib/std/script/file.uya:147` 转发到 `std.process`）
  - [x] `output`（`stdout_capture` `:3176` / `stderr_capture` `:3184` + `capture_into` / `capture_limit_into`）
  - [x] `check`（`check` / `check_into`，`lib/std/script/file.uya:133/140`）
- [x] `Command` 支持（对应 `Pipeline` 构造器）：
  - [x] argv 构造（`cmd_argv` `:3053`、`cmd_path_argv` `:3065`）
  - [x] cwd override（`cwd` `:3102`）
  - [x] env overlay（`env` `:3113`、`unset_env` `:3121`）
  - [x] stdin 重定向（`stdin_file` `:3152`）
  - [x] stdout 重定向（`stdout_file` `:3160`）
  - [x] stderr 重定向（`stderr_file` `:3168`、`stderr_to_stdout` `:3192`）
- [x] 默认不经过 shell。（`Pipeline` 只有 argv 形式入口；无 `system_string` 类 API）
- [x] 若保留 shell fallback：（未保留 shell fallback，本条自动满足）
  - [x] 明确区分 POSIX shell 与 Windows shell
  - [x] 不允许单一 `system_string(...)` API 模糊两者差异
- [x] 统一退出码语义：
  - [x] 正常退出（`PipelineStageStatusKind.exited` + `exit_code`）
  - [x] 被信号终止（`PipelineStageStatusKind.signaled` + `signal`）
  - [x] platform-specific terminate reason（`platform_code` + `PipelineSpawnFailureKind.platform_error`）
- [x] 为 PATH 搜索、缺失命令、非 0 退出、stdout/stderr 捕获补测试。（回归：`tests/test_typed_pipeline_cmd_argv.uya`、`test_typed_pipeline_executor_single.uya`、`test_typed_pipeline_capability.uya`、`test_std_script_pipeline_facade.uya`、`test_std_path_module.uya`；负向 `tests/error_typed_pipeline_*.uya` 共 10 个）

---

## Phase 4：`std.script` facade 与第一批脚本迁移

### 4.1 `std.script` facade

- [x] 新建 `lib/std/script.uya` 或等价模块。（2026-10-19：实际路径是 `lib/std/script/file.uya`，20 个 `export fn`，全部转发到 `std.process`）
- [~] 只放脚本高频帮助函数，不复制底层所有 API。（**当前是反过来的**：`file.uya` 是 1:1 转发 process-only typed pipeline API 的薄层，`pipeline` / `clone` / `cmd_argv` / `cmd_path_argv` / `cwd` / `env` / `unset_env` / `stdin_file` / `stdout_file` / `stderr_file` / `stdout_capture` / `stderr_capture` / `stderr_to_stdout` / `inherit_stdio` / `check` / `check_into` / `status_into` / `capture_into` / `capture_limit_into` / `stage_count`）
- [ ] MVP 提供：（2026-10-19 复核：下列 9 个高频帮助函数**一个都还没有**，`grep -rn "run_checked\|capture_text\|assert_exit_code\|require_tool\|project_root\|workspace_temp_dir\|log_info\|log_warn" lib/std/script/` 无命中）
  - [ ] `run_checked`
  - [ ] `capture_text`
  - [ ] `assert_exit_code`
  - [ ] `require_tool`
  - [ ] `project_root`
  - [ ] `workspace_temp_dir`
  - [ ] `fail`
  - [ ] `log_info`
  - [ ] `log_warn`

### 4.2 第一批迁移

- [ ] 为每个 `.sh` 迁移目标创建同目录 `.ush` 版本，初期并存。
- [ ] 第一批脚本建议：
  - [ ] `tests/verify_check_cli.ush`
  - [ ] `tests/verify_exec_vm_compiler_regressions.ush`
  - [ ] `tests/verify_split_build_output.ush`
  - [ ] `tests/verify_project_root_embedded_uya_resolution.ush`
- [ ] 迁移时遵循：
  - [ ] 旧 `.sh` 作为行为 oracle
  - [ ] `.ush` 与 `.sh` 的退出码一致
  - [ ] 关键日志与断言点一致
  - [ ] 关键产物文件一致

### 4.3 双跑验证

- [ ] 为迁移脚本增加双跑入口：
  - [ ] 先跑旧 `.sh`
  - [ ] 再跑新 `.ush`
  - [ ] 比对退出码与关键输出
- [ ] 至少在一段过渡周期内保留双跑。

---

## Phase 5：`uya script` 与 shebang

### 5.1 `uya script`

- [ ] 为 CLI 增加 `uya script file.ush -- ...` 子命令或等价入口。
- [ ] 明确 `script` 与 `run` 的关系：
  - [ ] `run` 偏编译器现有语义
  - [ ] `script` 偏自动化任务与脚本 UX
- [ ] 设计 `script` 默认 backend 策略：
  - [ ] 默认 C99 hosted
  - [ ] 或优先 `--exec`，失败回退
- [ ] 为 `script` 增加最小使用文档和示例。

### 5.2 shebang

- [ ] `uya script` 落地后同步最终建议写法：
  - [ ] `#!/usr/bin/env -S uya script`
  - [ ] 或提供 `uya-script` wrapper 后再定最终形式
- [ ] 明确 Windows 不依赖 shebang，而依赖 `uya script` 或文件关联。

---

## Phase 6：Windows hosted backend

- [ ] 为脚本运行时补 Windows hosted C bridge。
- [ ] 最小能力集合：
  - [ ] spawn process
  - [ ] wait process
  - [ ] kill/terminate
  - [ ] cwd
  - [ ] env
  - [ ] stat / exists
  - [ ] mkdir / remove / rename
  - [ ] read_dir
  - [ ] pipe / stdio redirection
- [ ] 统一路径语义：
  - [ ] UTF-8 public API
  - [ ] UTF-16 bridge 内部转换
  - [ ] `.exe` suffix 处理
  - [ ] PATH 分隔符处理
- [ ] 加入 Windows hosted 脚本 smoke：
  - [ ] PATH lookup
  - [ ] temp dir
  - [ ] file write/read
  - [ ] stdout/stderr capture
  - [ ] exit code propagation

---

## Phase 7：扩批迁移与性能收口

### 7.1 第二批脚本迁移

- [ ] 迁移 `tests/verify_exec_vm_smoke.sh`
- [ ] 迁移 `tests/verify_exec_backend_progress.sh`
- [ ] 迁移 `tests/run_programs_parallel.sh`

### 7.2 高复杂度脚本评估

- [ ] 评估 `tests/run_cross_platform_tests.sh` 是否拆成多个 Uya 脚本更合适。
- [ ] 评估 `src/compile.sh` 是否拆成：
  - [ ] 编译驱动
  - [ ] toolchain helper
  - [ ] release/backup helper

### 7.3 exec backend 性能路径

- [ ] 为 `uya script` 增加可选 `--exec` 路径。
- [ ] 对纯 Uya 脚本做启动耗时基线：
  - [ ] `run`
  - [ ] `script`
  - [ ] `script --exec`
- [ ] 明确回退策略与日志，避免脚本作者困惑。

### 7.4 CI 切换

- [ ] 当 `.ush` 脚本在主要 hosted 平台稳定后，逐步把 CI 默认入口从 `.sh` 切换为 `.ush`。
- [ ] 旧 `.sh` 保留一段兼容期后再删除。

---

## 验证要求

每个 Phase 收口前至少满足：

- [ ] 相关单元测试已补
- [ ] 相关集成脚本已有 oracle 对照
- [ ] Linux hosted 跑通
- [ ] 若涉及 Darwin/Windows 语义，至少有对应 smoke 或明确阻塞说明
- [ ] 文档同步更新：
  - [ ] `std_script_design.md`
  - [ ] 相关 `docs/TESTING.md`
  - [ ] 必要时更新 `docs/UYA_BUILD_RUN.md`
