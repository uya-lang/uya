# Uya fmt Phase 4 TodoList

> **核对头（2026-09-27）**：本 phase 文档的 "Not started" 勾选状态已过时——对应能力已在 `src/fmt.uya` + `tests/test_fmt_*.uya` 落地（`uya fmt` 命令见 `src/main.uya` 的 `COMMAND_FMT`）。
> 保留本文件作为任务分解记录；唯一仍明确未支持的是 `fmt_phase4_cli_tasks.md` 里的"stdin 与 `-s/-r` 组合"。

> 基于 `docs/fmt_development_plan.md` 的方案 B，Phase 4 聚焦 `uya fmt` 命令、输出模式与工程集成。

**Goal**: 提供接近 `gofmt` 工作流的命令行体验，并能接入项目开发流程。

---

## Status

- [ ] Not started
- [x] Done

---

## Phase 4 Goals

- [x] 提供 `uya fmt` 命令
- [x] 支持 stdout / write-back / list / diff
- [x] 支持 simplify 与 rewrite 的 CLI 选项
- [x] 支持文件、目录、stdin 输入
- [x] 备注：stdin 模式当前仅支持基础格式化，不支持 `-w/-l/-d/-s/-r` 组合
- [x] 集成到 Makefile / CI 工作流

---

## Main Pipeline

- [x] 打通 `cli args -> collect inputs -> read source -> format_with_options -> compare original/formatted -> stdout | write back | list | diff`

---

## File Tasks

### `tools/fmt.uya`

- [x] 实现最小参数解析
- [x] 实现单文件输入
- [x] 实现 stdout 输出路径
- [x] 实现 `-w` 写回路径
- [x] 实现错误码返回
- [x] 实现目录遍历
- [x] 实现 stdin 输入
- [x] 实现 `-d` 显示差异
- [x] 实现 `-l` 列出未格式化文件
- [x] 实现 `-r "rule"` 应用 rewrite 规则
- [x] 实现 `-s` 应用 simplify
- [x] 验证单文件格式化运行时可用
- [x] 验证多文件输入可用
- [x] 验证无参数时支持 stdin

### `lib/std/fmt/fmt.uya`

- [x] 暴露适合 CLI 的统一入口
- [x] 新增 `format_ptr_len(arena, ptr, len)`，绕过工具层 slice 构造问题
- [x] 保持 `format(source)` 可用
- [x] 保持 `format_with_options(source, options)` 可用
- [x] 保持 `is_formatted(source)` 可用
- [x] 返回格式化结果与是否变更的信息

### `Makefile`

- [x] 增加 `make fmt`
- [x] 增加 `make check-fmt`
- [x] 验证可批量格式化仓库源码
- [x] 验证可在 CI 中检查格式化状态

---

## Runtime Blocker（历史记录）

### 阶段内阻塞结论

- [x] `tools/fmt.uya` 已可编译链接
- [x] Phase 4 曾一度从 CLI 逻辑收敛为底层 runtime 问题
- [x] 当时已确认：`arena_alloc(...)` 返回的内存在运行时写入即可能触发 segfault
- [x] 运行级阻塞已解除，CLI 可完成单文件/目录/stdin 验收

### 最小复现文件

- [x] `tools/fmt_smoke.uya`
- [x] `tools/fmt_tokenize_smoke.uya`
- [x] `tools/arena_struct_array_smoke.uya`
- [x] `tools/arena_byte_smoke.uya`
- [x] `tools/arena_scalar_smoke.uya`
- [x] `tools/arena_struct_single_smoke.uya`
- [x] `tools/arena_struct_array_index_smoke.uya`

### 当前定位结果

- [x] CLI 编译问题已解决（slice 构造通过 `format_ptr_len` 绕过）
- [x] fmt AST 类型名冲突已解决（`File` -> `FmtFile`）
- [x] 运行时 segfault 可在不依赖 fmt 的 arena smoke 中复现
- [x] 当前阻塞不再属于 fmt 业务逻辑，而属于 arena/runtime 层
- [x] 当前 CLI 已通过运行级验证，可继续后续库层收尾优化

---

## Tests

### `tests/test_fmt_api.uya`
- [ ] 验证 CLI 依赖的 API 行为稳定
- [ ] 验证选项组合不冲突

### CLI 集成测试
- [x] 验证 `uya fmt file.uya`
- [x] 验证 `uya fmt -w file.uya`
- [x] 验证 `uya fmt -l file.uya`
- [x] 验证 `uya fmt -d file.uya`
- [x] 验证 `uya fmt -s file.uya`
- [x] 验证 `uya fmt -r "foo.bar -> bar" file.uya`
- [x] 验证 `cat file.uya | uya fmt`
- [ ] 验证 stdin 与 `-s/-r` 组合（当前未支持）

### 工程级验证
- [x] 验证 `make fmt` 可执行
- [x] 验证 `make check-fmt` 可报告未格式化文件

---

## Definition of Done

- [x] `uya fmt` 可处理单文件、目录、stdin
- [x] `-w/-d/-l/-r/-s` 全部可用
- [x] CLI 返回码符合预期
- [x] `make fmt` / `make check-fmt` 可用
- [x] CLI 行为与库层 API 保持一致

---

## Notes

- 当前 Phase 4 已完成。
- `tools/fmt.uya` 已能成功编译链接并通过运行级验证。
- CLI 阻塞已解除，后续剩余事项主要是库层 API 和测试覆盖增强。
