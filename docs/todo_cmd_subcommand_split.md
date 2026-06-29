# Uya 编译器入口瘦身 TODO

**状态**: executable TODO, implementation pending
**更新日期**: 2026-05-03
**配套设计**: `docs/cmd_subcommand_split_design.md`

---

## 当前基线

当前仓库仍处于设计待实现状态：

- `src/main.uya` 仍约 8400 行，`parse_args()` 与 `main()` 仍直接处理 `build`/`check`/`run`/`test`/`fmt` 等业务。
- `src/cmd/*/main.uya` 尚未创建。
- `Makefile` 尚未提供 `make cmds` 与 `cmd-*` 目标。
- `src/main.uya` 尚未实现 `dispatch_external_cmd`。
- `tests/test_cmd_upm_direct.sh` 尚未创建。

---

## 执行原则

- 先读 `docs/cmd_subcommand_split_design.md`、`docs/uya_ai_prompt.md` 和相邻测试。
- 不臆造 Uya 语法；不确定时先搜索 `src/`、`lib/`、`tests/` 的既有写法。
- 按 TDD 推进：先加相关测试，再做最小实现。
- 保留 `uya <file.uya> ...` 隐式编译入口，直到 `cmd/build` seed 或等价 bootstrap 编译器来源稳定。
- 最终目标是 `src/main.uya` 只负责命令分发；编译器业务归属 `cmd/build` 和共享 compiler driver。
- 公开 `uya build/check/run/test/fmt/upm` 完成外置化后必须走 `cmd/xxx`，不要静默回退内部实现。
- `cmd/run` 与 `cmd/test` 由 compiler driver 完成编译、链接、执行和退出码映射，不在 wrapper 里另写一套执行逻辑。

---

## Phase 0：基线确认

- [ ] 查看工作树，确认没有未预期改动：`git status --short`。
- [ ] 阅读当前入口：`src/main.uya` 的 `CommandType`、`print_usage()`、`parse_args()`、`export fn main()`。
- [ ] 阅读 fmt 独立入口：`src/fmt.uya` 的 `fmt_main()` 与 `uyafmt_main()`。
- [ ] 阅读构建脚本：`Makefile` 的 `uya`、`from-c`、`from-c-native`、`install`、`clean` 目标，以及 `src/compile.sh` 的主文件选择逻辑。
- [ ] 跑最小基线，记录当前行为：

```bash
./bin/uya --version || true
./bin/uya check tests/check_cli_no_main.uya
./bin/uya build tests/test_errno.uya -o /tmp/uya_baseline_errno --no-split-c
./bin/uya test tests/test_errno.uya
./bin/uya fmt tests/test_errno.uya >/tmp/uya_baseline_fmt.out
./bin/uya tests/test_errno.uya -o /tmp/uya_baseline_implicit --no-split-c
```

---

## Phase A：提取 Compiler Driver

- [ ] 新建 `src/compiler_driver.uya`，作为编译器 CLI 业务的唯一共享实现。
- [ ] 将 `parse_args()` 改造成可指定默认命令和起始参数的 driver 解析函数，例如：

```text
compiler_driver_parse_args(default_command, argv_start, allow_optional_subcommand, args_out)
```

- [ ] 将当前 `export fn main()` 中 `build/check/run/test` 共享流程提取到 driver，例如：

```text
compiler_driver_main(command, argv_start) -> exit_code
compiler_driver_compile(command, argv_start, result_out) -> exit_code
```

- [ ] 明确 driver 语义：
  - [ ] `COMMAND_BUILD` 完成完整 build CLI 语义并返回退出码。
  - [ ] `COMMAND_CHECK` 完成 lexer/parser/checker 流程并返回退出码，不执行代码生成。
  - [ ] `COMMAND_RUN` 完成编译、链接、执行目标程序和退出码映射。
  - [ ] `COMMAND_TEST` 完成测试编译、执行、摘要输出和退出码映射。
- [ ] 将链接工具链函数移入 driver：`link_with_toolchain`、`compile_c_source_to_object`、`link_split_with_make` 等。
- [ ] 将 C import 处理移入 driver：`collect_c_import_plan`、`write_c_import_sidecar` 等。
- [ ] 将通用编译工具移入 driver：路径处理、模块查找、`detect_main`、依赖收集排序等。
- [ ] `src/main.uya` 过渡期 `use compiler_driver;`，隐式入口改为调用 `compiler_driver_main(COMMAND_BUILD, 1)`。
- [ ] 保持 `build`、`run`、`test` 原有语义：默认 C99 后端、`run/test` 单文件 C、`run -- <args>`、test 默认栈、microapp 特殊路径、`@c_import` 链接计划。
- [ ] 暂不移动 `pack-image`、`inspect-image`、`verify-image`、`--outlibc`。
- [ ] 所有新增公共 `export fn` 前写 `///` 注释，说明功能、参数和返回值。
- [ ] 提取后验证隐式入口仍能工作：

```bash
./bin/uya tests/test_errno.uya -o /tmp/uya_implicit_errno --no-split-c
./tests/run_programs_parallel.sh
make tests-uya
```

---

## Phase B：提取 Microapp 逻辑

- [ ] 新建 `src/microapp.uya`（或按设计选择 `lib/microapp/driver.uya`，但本轮推荐 `src/microapp.uya`）。
- [ ] 将 `build_microapp_text_from_c` 移入 microapp 模块。
- [ ] 将 `pack_microapp_pobj_to_uapp` 移入 microapp 模块。
- [ ] 将 `inspect_microapp_image` / `inspect_microapp_pobj` / `inspect_microapp_uapp` 移入 microapp 模块。
- [ ] 将 `verify_microapp_image` / `verify_microapp_pobj` 移入 microapp 模块。
- [ ] 将 ELF64/Mach-O 解析、提取、重定位辅助函数移入 microapp 模块。
- [ ] `src/main.uya` 过渡期 `use microapp;`，`pack-image`/`inspect-image`/`verify-image` 改为调用 `microapp_*` 导出函数。
- [ ] `src/compiler_driver.uya` 若仍需 `--app microapp` 编译流程，也 `use microapp;`。
- [ ] 验证 microapp 与 hosted 路线：

```bash
make microapp-check
make check-hosted
```

---

## Phase C：独立子命令与调度器

### C1：先补调度测试

- [ ] 新增 `tests/test_cmd_upm_direct.sh`，脚本开头使用 `set -euo pipefail`。
- [ ] 测试开始时确认 `bin/uya` 存在；若 `bin/cmd/*` 不存在，提示先运行 `make cmds`。
- [ ] 覆盖 `uya build` 与直调 `cmd/build`：

```bash
./bin/uya build tests/test_errno.uya -o /tmp/uya_cmd_build --no-split-c
./bin/cmd/build tests/test_errno.uya -o /tmp/uya_cmd_build_direct --no-split-c
```

- [ ] 覆盖 `uya run ... -- ...` 的运行时参数 argv 原样保留。
- [ ] 覆盖 `uya test` 与直调 `cmd/test` 摘要和退出码一致。
- [ ] 覆盖 `uya fmt` 与直调 `cmd/fmt` 输出一致。
- [ ] 覆盖 `uya upm --help` 与直调 `cmd/upm --help` 均退出 0。
- [ ] 覆盖缺失命令的错误路径：临时重命名 `bin/cmd/build`，确认 `./bin/uya build ...` 返回非 0，错误信息包含 `cmd/build` 和 `make cmds`。

### C2：新增 `src/cmd/*` 入口

- [ ] 创建 `src/cmd/build/main.uya`，入口调用 `compiler_driver_main(COMMAND_BUILD, 1)`。
- [ ] 创建 `src/cmd/run/main.uya`，入口调用 `compiler_driver_main(COMMAND_RUN, 1)`，由 driver 完成编译、链接和执行。
- [ ] 创建 `src/cmd/test/main.uya`，入口调用 `compiler_driver_main(COMMAND_TEST, 1)`，由 driver 完成测试执行和摘要输出。
- [ ] 三个命令入口都支持可选重复子命令名，例如 `cmd/build build file.uya`。
- [ ] 创建 `src/cmd/fmt/main.uya`：
  - [ ] 默认调用 `uyafmt_main()`。
  - [ ] 若 `argv[1] == "fmt"`，跳过该参数或调用兼容入口。
- [ ] 创建 `src/cmd/upm/main.uya`：
  - [ ] `--help` / `-h` 打印用法并退出 0。
  - [ ] `--version` / `-v` 打印版本并退出 0；`--verbose` 保留为编译详细日志开关。
  - [ ] 未实现命令打印提示并退出 2。
- [ ] 每个公开入口前写 `///` 注释，符合仓库 Uya 代码风格。

### C3：改造 Makefile 生成 `bin/cmd/*`

- [ ] 在 `Makefile` 增加 `UYA_CMD_NAMES := build run test fmt upm`。
- [ ] 增加 `cmds`、`cmd-build`、`cmd-run`、`cmd-test`、`cmd-fmt`、`cmd-upm` 目标。
- [ ] 过渡期用 `UYA_CMD_BOOTSTRAP_COMPILER ?= ./bin/uya` 构建命令程序。
- [ ] `bin/cmd/%` 规则包含 `--project-root src/`：

```make
bin/cmd/%: src/cmd/%/main.uya $(UYA_CMD_BOOTSTRAP_COMPILER)
	@mkdir -p bin/cmd
	$(UYA_CMD_BOOTSTRAP_COMPILER) $< -o $@ --c99 --no-split-c --project-root src/
```

- [ ] `make cmds` 生成：

```text
bin/cmd/build
bin/cmd/run
bin/cmd/test
bin/cmd/fmt
bin/cmd/upm
```

- [ ] `make clean` 清理 `bin/cmd/` 和 `src/build/cmd/`，但不清理 `src/cmd/*` 源码。
- [ ] `make install` 依赖或检查 `cmds`，并复制 `bin/cmd/*` 到 `$(INSTALL_BINDIR)/cmd/`。
- [ ] `make help` 增加 `make cmds` 和安装布局说明。

### C4：实现主程序调度器

- [ ] 在 `src/main.uya` 新增 `is_external_cmd(name)`，识别 `build/check/run/test/fmt/upm`。
- [ ] 新增 `build_external_cmd_path(cmd_name, out, out_cap)`，基于 `get_compiler_dir(get_argv(0), ...)` 生成 `cmd/<name>` 路径，Windows 目标补 `.exe`。
- [ ] 新增 `dispatch_external_cmd(cmd_name, strip_subcommand)`：
  - [ ] 构造新的 argv 数组，`argv[0]` 为 `cmd_path`。
  - [ ] `strip_subcommand != 0` 时从原 `argv[2]` 开始复制参数。
  - [ ] 保留 `--` 及其后的所有参数原样。
  - [ ] argv 末尾写入 `null`。
  - [ ] 使用 `execve(cmd_path, argv, saved_envp)` 或同等 argv API。
  - [ ] `execve` 失败时根据 errno 打印 `cmd_path`、原因和 `make cmds` 提示。
- [ ] 在 `export fn main()` 开头做分流：
  - [ ] `argv[1]` 是外置命令：立即 `dispatch_external_cmd(argv[1], 1)`，不再进入 `parse_args()`。
  - [ ] `argv[1]` 是 `--version` / `-v`：保持当前版本输出；`--verbose` 不作为版本别名。
  - [ ] `pack-image` / `inspect-image` / `verify-image` 继续走过渡期内部路径。
  - [ ] 非命令参数继续走隐式编译入口。
- [ ] 不要使用 `system()` 拼接公开子命令调用。
- [ ] 验证 Phase C：

```bash
make cmds
./tests/test_cmd_upm_direct.sh
make check
```

---

## Phase D 准备：补齐 `cmd/build` 自举来源

- [ ] 设计 `cmd/build` seed 布局，例如 `backup/cmd-build.c` 及必要 host/arch 变体。
- [ ] 更新 `make backup-all` / `backup-all-seed`，确保 `cmd/build` seed 与编译器 seed 同步更新。
- [ ] 更新 `make from-c` / `make from-c-native`，先由 seed 生成 `bin/uya` 与 `bin/cmd/build`。
- [ ] 修改 `make cmds` 目标态默认编译器为 `UYA_CMD_BOOTSTRAP_COMPILER ?= ./bin/cmd/build`。
- [ ] 保留过渡期逃生口：仅在 Phase D 前允许显式覆盖 `UYA_CMD_BOOTSTRAP_COMPILER=./bin/uya`。
- [ ] 验证清理后冷启动：

```bash
make clean
make from-c-native
ls -l bin/uya bin/cmd/build
make cmds
```

---

## Phase D：移除隐式入口，纯调度器收口

- [ ] 确认 Phase D 准备已完成，`make clean && make from-c` 可生成 `bin/uya` 和 `bin/cmd/build`。
- [ ] 移除 `src/main.uya` 中的隐式编译入口，非命令 `.uya` 输入应提示使用 `uya build`。
- [ ] 如果 `pack-image` / `inspect-image` / `verify-image` 已外置，删除 `src/main.uya` 中的 `use compiler_driver;` 和 `use microapp;`。
- [ ] 更新 `src/compile.sh`，显式区分“构建调度器 `bin/uya`”与“使用 `bin/cmd/build` 编译普通入口”。
- [ ] 验证隐式入口已移除：

```bash
bin/uya tests/test_errno.uya -o /tmp/implicit_should_fail
```

- [ ] 完整验证：

```bash
make clean
make from-c-native
make uya
make cmds
make check
make backup-all
```

---

## 文档同步

- [ ] 更新 `docs/UYA_BUILD_RUN.md`：说明 `uya build/check/run/test` 由 `cmd/build`、`cmd/check`、`cmd/run`、`cmd/test` 执行。
- [ ] 更新 `docs/TESTING.md`：加入 `make cmds` 和 `tests/test_cmd_upm_direct.sh`。
- [ ] 如 `upm` 帮助文字采用 `upm` 而不是 `uyapm`，在相关文档中说明二者关系或保留为后续 TODO。
- [ ] 如果没有改变语言语法、BNF 或内建函数，不需要升级 `docs/uya.md` 规范版本。

---

## 回滚策略

- [ ] 如果 driver 提取失败，回退到 `src/main.uya` 内部路径，但保留已新增测试。
- [ ] 如果 `cmd/xxx` 构建失败，先保持 `src/main.uya` 的隐式编译入口可用，不要破坏 `make uya`。
- [ ] 如果公开调度失败，可临时只让 `fmt/upm` 外置，`build/run/test` 保持内部，但测试中标记未完成项。
- [ ] 不要复制旧逻辑；先抽成共享 driver，再由主程序和命令入口共用。
- [ ] 不要提交 `bin/cmd/*` 生成物，除非仓库策略后来明确要求跟踪这些产物。
