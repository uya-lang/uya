# 标准脚本运行时 TODO

**状态**：executable TODO, planning
**更新日期**：2026-06-29
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

- [ ] 盘点 Darwin hosted 下脚本运行时仍缺的 bridge。
- [ ] 明确 Windows hosted 所需最小 bridge 列表：
  - [ ] process spawn/wait
  - [ ] cwd
  - [ ] env
  - [ ] stat/remove/rename
  - [ ] dir traversal
  - [ ] pipe/stdio redirection

### 1.4 shebang 预研

- [ ] 明确 shebang 不阻塞第一批脚本迁移。

---

## Phase 2：`std.path` / `std.env` / `std.fs` MVP

### 2.1 `std.path`

- [ ] 新建 `lib/std/path.uya` 或等价模块。
- [ ] 提供：
  - [ ] `join`
  - [ ] `dirname`
  - [ ] `basename`
  - [ ] `stem`
  - [ ] `extension`
  - [ ] `is_abs`
  - [ ] `normalize`
  - [ ] `path_list_separator`
  - [ ] `executable_suffix`
- [ ] 补 Linux / macOS / Windows 语义测试（至少先写平台条件测试）。

### 2.2 `std.env`

- [ ] 新建 `lib/std/env.uya` 或等价模块。
- [ ] 提供：
  - [ ] `get`
  - [ ] `has`
  - [ ] `inherit_current`
  - [ ] env overlay builder
  - [ ] child-only `with/remove`
- [ ] 明确哪些 API 是“读当前环境”，哪些 API 是“构造子进程环境”。
- [ ] 为空值、缺失值、重复键、覆盖顺序补测试。

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

- [ ] 新建 `lib/std/process.uya` 或等价模块。
- [ ] 设计 `Command` / `Child` / `ExitStatus` / `Output` 数据模型。
- [ ] 实现主路径：
  - [ ] `spawn`
  - [ ] `status`
  - [ ] `output`
  - [ ] `check`
- [ ] `Command` 支持：
  - [ ] argv 构造
  - [ ] cwd override
  - [ ] env overlay
  - [ ] stdin 重定向
  - [ ] stdout 重定向
  - [ ] stderr 重定向
- [ ] 默认不经过 shell。
- [ ] 若保留 shell fallback：
  - [ ] 明确区分 POSIX shell 与 Windows shell
  - [ ] 不允许单一 `system_string(...)` API 模糊两者差异
- [ ] 统一退出码语义：
  - [ ] 正常退出
  - [ ] 被信号终止
  - [ ] platform-specific terminate reason
- [ ] 为 PATH 搜索、缺失命令、非 0 退出、stdout/stderr 捕获补测试。

---

## Phase 4：`std.script` facade 与第一批脚本迁移

### 4.1 `std.script` facade

- [ ] 新建 `lib/std/script.uya` 或等价模块。
- [ ] 只放脚本高频帮助函数，不复制底层所有 API。
- [ ] MVP 提供：
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
