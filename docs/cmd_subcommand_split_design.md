# Uya 编译器入口瘦身设计：`src/main.uya` 拆分与职责外置

**状态**: design draft, implementation pending
**更新日期**: 2026-05-03
**范围**: `src/main.uya` 物理拆分，`build`/`check`/`run`/`test`/`fmt`/`upm` 真实独立

> **当前问题**: 当前仓库中 `src/main.uya` 仍约 8400 行，`parse_args()` 和 `main()` 仍直接处理 `build`/`check`/`run`/`test`/`fmt` 等业务参数；`src/cmd/` 入口、`make cmds`、`dispatch_external_cmd` 和 `bin/cmd/*` 尚未落地。本设计目标是先把业务逻辑物理拆出 `src/main.uya`，再引入真实独立子命令，而不是增加一层回调 `src/main.uya` 的代理壳。

---

## 1. 背景

当前 `src/main.uya` 同时承担：

- 编译器核心（参数解析、依赖收集、AST 合并、C99/LLVM 生成、工具链链接）
- Microapp 全链路（ELF64/Mach-O 解析、重定位、构建、打包/检查/验证 image）
- 命令分发和命令业务（`build`/`check`/`run`/`test`/`fmt` 的参数解析与执行）
- 辅助命令（`pack-image`/`inspect-image`/`verify-image`/`--outlibc`）
- 隐式编译入口（`uya file.uya -o out`，自举兼容）

`src/main.uya` 当前约 **8400 行**，其中：

| 区域 | 大约行数 | 说明 |
|------|---------|------|
| Microapp 逻辑 | ~3250 | ELF/Mach-O 提取、重定位、打包、检查、验证 |
| 参数解析 `parse_args` | ~1400 | 所有命令行选项与校验 |
| 编译主流程 `compile_files` | ~700 | 依赖收集、AST 合并、代码生成 |
| 工具链/链接 | ~500 | `link_with_toolchain`、`compile_c_source_to_object`、C import 处理 |
| 通用工具 | ~1000 | 路径处理、模块查找、`detect_main`、`collect_module_dependencies` |
| 主入口与帮助信息 | ~1000 | `main()` 命令分支、输出路径处理、帮助信息 |

当前尚未完成的基础设施：

- `src/main.uya` 尚未实现 `dispatch_external_cmd`，公开子命令还没有通过 `execve` 转发到 `bin/cmd/xxx`。
- `Makefile` 尚未提供 `cmds`/`cmd-build`/`cmd-run`/`cmd-test`/`cmd-fmt`/`cmd-upm` 目标。
- `src/cmd/build`/`check`/`run`/`test`/`fmt`/`upm` 入口源码尚未创建。
- `tests/test_cmd_upm_direct.sh` 尚未落地。

这导致 `src/main.uya` 的源码行数、编译产物体积和职责边界都没有实质改善。

---

## 2. 目标

### 2.1 源码瘦身

- `src/main.uya` 最终压到 **~1500 行以内**，只保留：
  - 子命令发现与外置调度（`dispatch_external_cmd`）
  - 全局帮助、版本信息
  - 隐式编译入口（过渡期内 thin wrapper，调用 `compiler_driver` 模块）
- 编译器核心逻辑集中到 **`src/compiler_driver.uya`**。
- Microapp 全链路逻辑集中到 **`src/microapp.uya`**（或 `lib/microapp/driver.uya`）。

### 2.2 真实独立子命令

- `src/cmd/build/main.uya` 是真实的编译器入口，不是 `execve` wrapper。
- `src/cmd/check/main.uya` 是真实的前端检查入口，停在 checker。
- `src/cmd/run/main.uya` / `test/main.uya` 调用 compiler driver，并由 driver 完成编译、链接、执行和退出码映射。
- `src/cmd/fmt/main.uya` 直接调用 `src/fmt.uya` 中的 `uyafmt_main()`，不绕回 `bin/uya`。
- `bin/cmd/xxx` 的体积和职责与 `bin/uya` 解耦；`bin/uya` 最终可缩小为纯调度器。

### 2.3 自举安全

- 任何阶段都不能让 `make from-c` → `make uya` → `make cmds` 链条断裂。
- 隐式编译入口 `uya file.uya -o out` 在过渡期内必须保留，直到自举种子能直接生成 `bin/cmd/build`。
- Phase D 之前必须先补齐 `cmd/build` 的 seed 或等价 bootstrap 编译器来源；不能让纯调度器 `bin/uya` 承担编译 `bin/cmd/build` 的职责。

---

## 3. 目标架构

```text
src/
  main.uya                  # launcher/dispatcher + 隐式入口 thin wrapper (~1500 行)
  compiler_driver.uya       # parse_args, compile_files, 链接, C import 处理 (~2600 行)
  microapp.uya              # ELF/Mach-O, pack/inspect/verify (~3250 行)
  fmt.uya                   # 格式化（已有独立入口 uyafmt_main）
  cmd/
    build/main.uya          # 真实编译器入口：use compiler_driver; compiler_driver_main(COMMAND_BUILD, ...)
    check/main.uya          # 前端检查入口：use compiler_driver; compiler_driver_main(COMMAND_CHECK, ...)
    run/main.uya            # 真实运行入口：use compiler_driver; compiler_driver_main(COMMAND_RUN, ...)
    test/main.uya           # 真实测试入口：use compiler_driver; compiler_driver_main(COMMAND_TEST, ...)
    fmt/main.uya            # 真实格式化入口：use fmt; uyafmt_main()
    upm/main.uya            # 包管理骨架

bin/
  uya                       # 过渡期：调度器 + 隐式入口；目标态：纯调度器
  cmd/
    build                   # 真实编译器（含 compiler_driver + microapp）
    check                   # 前端检查器
    run                     # 编译+运行前端
    test                    # 编译+测试前端
    fmt                     # 格式化前端
    upm                     # 包管理前端
```

### 3.1 `src/main.uya` 职责（目标态）

1. `argc < 2`：打印主帮助。
2. `argv[1]` 是 `build/check/run/test/fmt/upm`：调用 `dispatch_external_cmd(...)`，不解析业务选项。
3. `argv[1]` 是 `--version`/`-v`：直接处理；`--verbose` 保留为编译详细日志开关。
4. `argv[1]` 是 `pack-image`/`inspect-image`/`verify-image`：可继续由 `src/main.uya` 直接处理（因为 microapp 逻辑仍通过 `use microapp` 可用），或后续再外置。
5. **过渡期保留**：隐式编译入口 `uya <file.uya> ...` 调用 `compiler_driver` 模块中的函数，用于自举和 `src/compile.sh` 兼容。
6. **过渡期后**：隐式入口移除，`src/main.uya` 只剩纯调度器。

### 3.2 `src/compiler_driver.uya` 职责

包含以下概念性导出接口（具体签名以实现时能通过现有编译器为准）：

```text
compiler_driver_main(command, argv_start) -> exit_code
compiler_driver_compile(command, argv_start, result_out) -> exit_code
compiler_driver_parse_args(command, argv_start, args_out) -> exit_code
```

语义边界：

- `compiler_driver_main(COMMAND_BUILD, 1)`：完成 build 的完整 CLI 语义并返回退出码。
- `compiler_driver_main(COMMAND_CHECK, 1)`：完成 lexer / parser / checker 流程并返回退出码，不执行代码生成。
- `compiler_driver_main(COMMAND_RUN, 1)`：完成编译、链接、执行目标程序、映射子进程退出码，并返回最终退出码。
- `compiler_driver_main(COMMAND_TEST, 1)`：完成测试编译、执行、测试摘要输出、退出码映射，并返回最终退出码。
- `compiler_driver_compile(...)`：仅供需要“只编译但不执行”的内部场景使用，输出路径等信息写入 `result_out`。

内部聚合：

- `parse_args` 的全部逻辑
- `compile_files` 的全部逻辑
- `link_with_toolchain`、`compile_c_source_to_object`、`link_split_with_make`
- C import 处理（`collect_c_import_plan`、`write_c_import_sidecar` 等）
- 通用编译工具（路径处理、模块查找、`detect_main`、依赖收集排序等）

导入：

```uya
use arena;
use ast;
use lexer;
use parser;
use checker;
use codegen.c99;
use std;
use libc;
use fmt;
```

### 3.3 `src/microapp.uya` 职责

包含所有 microapp 相关函数：

- `build_microapp_text_from_c`
- `pack_microapp_pobj_to_uapp`
- `inspect_microapp_image` / `inspect_microapp_pobj` / `inspect_microapp_uapp`
- `verify_microapp_image` / `verify_microapp_pobj`
- 全部 ELF64/Mach-O 解析、提取、重定位辅助函数

`src/main.uya` 在过渡期内仍 `use microapp;`，以支持 `pack-image`/`inspect-image`/`verify-image` 命令。

### 3.4 `src/cmd/build/main.uya` 与 `src/cmd/check/main.uya`（真实入口）

```uya
use compiler_driver;

export fn main() i32 {
    return compiler_driver_main(CommandType.COMMAND_BUILD, 1);
}
```

```uya
use compiler_driver;

export fn main() i32 {
    return compiler_driver_main(CommandType.COMMAND_CHECK, 1);
}
```

过渡期构建命令：

```bash
./bin/uya src/cmd/build/main.uya -o bin/cmd/build --c99 --no-split-c --project-root src/
```

`--project-root src/` 确保 `use compiler_driver;` 能正确解析到 `src/compiler_driver.uya`。Phase D 后不能再依赖这条命令生成第一份 `bin/cmd/build`，必须改由 `cmd/build` seed 或 bootstrap 编译器生成。

---

## 4. 非目标

- 不重新设计 Uya 语言语法、BNF 或内建函数。
- 不在本轮重做包管理器完整功能；`upm` 保持最小骨架。
- 不要求第一阶段就删除 `src/main.uya` 的隐式编译入口。
- 不新增公开 `compile` 子命令。

---

## 5. 关键约束

### 5.1 自举不能死锁

如果 `bin/uya` 变成纯调度器后失去了编译能力，而构建 `bin/cmd/build` 又依赖 `bin/uya`，则链条断裂。

**解决方案**：

| 阶段 | `src/main.uya` 状态 | `bin/uya` 能力 | `bin/cmd/build` 来源 |
|------|-------------------|---------------|---------------------|
| Phase A-B | `use compiler_driver;` 保留隐式入口 | 仍能编译 `.uya` | `./bin/uya src/cmd/build/main.uya ...` |
| Phase C | 同上 | 同上 | 真实独立入口，不再绕回 `bin/uya` |
| Phase D 准备 | 同上 | 同上 | 新增并验证 `backup/cmd-build.c` 或等价 bootstrap 编译器 seed |
| Phase D | 移除隐式入口，纯调度器 | 只调度 | `make from-c` 先由 seed 生成 `bin/cmd/build`，再由 `bin/cmd/build` 重建其它命令 |

**关键规则**：在 `cmd/build` 的自举 seed 尚未纳入 `make from-c` / `make from-c-native` / `make backup-all` 之前，`src/main.uya` 的隐式编译入口不能删除。

### 5.2 模块解析需要项目根

`src/cmd/build/main.uya` 位于 `src/cmd/build/`，默认模块查找根可能不是 `src/`。必须通过 `--project-root src/` 让 `use compiler_driver;` 正确映射到 `src/compiler_driver.uya`。

同样，`src/compiler_driver.uya` 中的 `use arena;` 等需要相对于 `src/` 解析，这要求 `src/compiler_driver.uya` 本身也在 `src/` 下（推荐），或通过 `--project-root` 统一控制。

### 5.3 参数必须原样传递

调度器层必须使用 `execve` 或等价 argv API 转发参数，不使用 `system("cmd ...")` 拼接命令。`bin/cmd/build` 直接运行时接收的 argv 形式：

```text
bin/cmd/build main.uya -o app
bin/cmd/build build main.uya -o app   # 兼容但不推荐
```

公开调度器推荐传递第一种形式，即去掉 `uya` 后面的子命令名。

### 5.4 不要复制代码

`src/main.uya` 的隐式入口与 `src/cmd/build/main.uya` 必须共用同一份 `src/compiler_driver.uya` 源码，不能 fork 出两份实现。

---

## 6. 分阶段实施路线

### Phase A：提取 Compiler Driver（~2600 行）

1. 新建 `src/compiler_driver.uya`。
2. 把 `parse_args()`、`compile_files()`、链接工具链函数、C import 处理、通用编译工具函数移入。
3. `src/main.uya` 中 `use compiler_driver;`，隐式入口改为调用 `compiler_driver_main()`。
4. 运行 `./tests/run_programs_parallel.sh` 和 `make tests-uya` 验证。

**预期效果**：`src/main.uya` 从约 8400 → ~6000 行。

### Phase B：提取 Microapp 逻辑（~3250 行）

1. 新建 `src/microapp.uya`。
2. 把所有 microapp 相关函数移入。
3. `src/main.uya` 中 `use microapp;`，`pack-image`/`inspect-image`/`verify-image` 命令调用 `microapp_*` 函数。
4. `src/compiler_driver.uya` 若需要 microapp 支持（如 `--app microapp` 编译流程），也 `use microapp;`。
5. 运行 `make microapp-check` 和 `make check-hosted` 验证。

**预期效果**：`src/main.uya` 从 ~6000 → ~2500 行。

### Phase C：独立 `cmd/build`/`check`/`run`/`test` 入口

1. 新建 `src/cmd/build/main.uya`：调用 `compiler_driver_main(COMMAND_BUILD, 1)`。
2. 新建 `src/cmd/check/main.uya`：调用 `compiler_driver_main(COMMAND_CHECK, 1)`，由 driver 完成 lexer / parser / checker 流程并返回退出码。
3. 新建 `src/cmd/run/main.uya`：调用 `compiler_driver_main(COMMAND_RUN, 1)`，由 driver 完成编译、链接和执行。
4. 新建 `src/cmd/test/main.uya`：调用 `compiler_driver_main(COMMAND_TEST, 1)`，由 driver 完成测试执行和摘要输出。
5. 新建 `src/cmd/fmt/main.uya`：直接调用 `uyafmt_main()`，不绕回 `bin/uya`。
6. 新建 `src/cmd/upm/main.uya`：提供最小 `--help`/`--version` 骨架。
7. Makefile 中新增 `cmds` 和 `bin/cmd/%` 规则，过渡期用 `bin/uya` 隐式入口构建。
8. `src/main.uya` 新增 `dispatch_external_cmd`，公开子命令转发到 `bin/cmd/xxx`。
9. 运行 `make cmds`、`./tests/test_cmd_upm_direct.sh`、`make check` 验证。

**预期效果**：`bin/cmd/build` 成为真实编译器；`src/main.uya` 仍为 ~2500 行（含隐式入口）。

### Phase D：移除隐式入口，`src/main.uya` 纯调度器

1. 新增 `cmd/build` 自举 seed（例如 `backup/cmd-build.c` 及必要 host/arch 变体），并让 `make from-c` / `make from-c-native` 先生成 `bin/cmd/build`。
2. 修改 `make cmds`：目标态优先用 `bin/cmd/build` 构建 `bin/cmd/*`；仅过渡期允许回退到 `bin/uya` 隐式入口。
3. 当 seed 路线稳定后，移除 `src/main.uya` 中的隐式编译入口。
4. `src/main.uya` 中删除 `use compiler_driver;` 和 `use microapp;`（如果 `pack-image` 等也已外置）。
5. 更新 `src/compile.sh`：自举编译器自身时，明确入口和编译器路径，不再假设 `bin/uya` 具备隐式编译能力。
6. 运行完整验证：`make clean`、`make from-c-native`、`make uya`、`make cmds`、`make check`、`make backup-all`。

**预期效果**：`src/main.uya` 最终 ~1500 行；`bin/uya` 大幅缩小。

---

## 7. 构建系统变更

### 7.1 Makefile

过渡期规则：

```make
UYA_CMD_NAMES := build run test fmt upm
UYA_CMD_BINS := $(patsubst %,bin/cmd/%,$(UYA_CMD_NAMES))

.PHONY: cmds cmd-build cmd-run cmd-test cmd-fmt cmd-upm
cmds: $(UYA_CMD_BINS)

UYA_CMD_BOOTSTRAP_COMPILER ?= ./bin/uya

bin/cmd/%: src/cmd/%/main.uya $(UYA_CMD_BOOTSTRAP_COMPILER)
	@mkdir -p bin/cmd
	$(UYA_CMD_BOOTSTRAP_COMPILER) $< -o $@ --c99 --no-split-c --project-root src/
	@echo "✓ 子命令已生成: $@"
```

目标态规则：

```make
UYA_CMD_BOOTSTRAP_COMPILER ?= ./bin/cmd/build

bin/cmd/%: src/cmd/%/main.uya $(UYA_CMD_BOOTSTRAP_COMPILER)
	@mkdir -p bin/cmd
	$(UYA_CMD_BOOTSTRAP_COMPILER) $< -o $@ --c99 --no-split-c --project-root src/
	@echo "✓ 子命令已生成: $@"
```

`--project-root src/` 是关键：让 `src/cmd/build/main.uya` 中的 `use compiler_driver;` 能解析到 `src/compiler_driver.uya`。目标态下 `./bin/cmd/build` 必须已由 seed 生成，不能依赖纯调度器 `./bin/uya`。

### 7.2 `src/compile.sh`

编译 `src/cmd/xxx/main.uya` 时，默认传入 `--project-root src/`。编译 `src/main.uya` 时不传（或传入 `src/` 作为自身项目根）。Phase D 后，脚本必须显式区分“正在构建调度器 `bin/uya`”与“正在用 `bin/cmd/build` 编译普通入口”。

### 7.3 `make clean`

增加清理：

- `bin/cmd/`
- `src/build/cmd/`
- `src/build/compiler_driver.c` 等生成物

不要清理源码文件：

- `src/compiler_driver.uya`
- `src/microapp.uya`
- `src/cmd/*/main.uya`

---

## 8. 测试策略

### 8.1 Phase A/B 回归测试

每移动一批函数后运行：

```bash
./tests/run_programs_parallel.sh          # 快速程序回归
make tests-uya                             # 自举编译器测试
make check-hosted                          # hosted 路线
make microapp-check                        # microapp 路线
```

### 8.2 Phase C 调度测试

新增 `tests/test_cmd_upm_direct.sh`，并覆盖：

```bash
make cmds
./tests/test_cmd_upm_direct.sh
bin/cmd/build tests/test_errno.uya -o /tmp/uya_cmd_build --no-split-c
bin/cmd/test tests/test_errno.uya
bin/cmd/fmt tests/test_errno.uya
```

至少验证：

- `bin/uya build ...` 与 `bin/cmd/build ...` 语义和退出码一致。
- `bin/uya run ... -- ...` 的运行时参数通过 argv 原样保留。
- `bin/uya test ...` 与 `bin/cmd/test ...` 测试摘要和退出码一致。
- `bin/uya fmt ...` 与 `bin/cmd/fmt ...` 输出一致。
- 临时隐藏 `bin/cmd/build` 时，`bin/uya build ...` 返回非 0，并提示 `cmd/build` 与 `make cmds`。

### 8.3 Phase D 自举测试

```bash
make clean
make from-c-native
make uya
make cmds
make check
make backup-all
```

额外验证：

- `make clean && make from-c` 后能得到可运行的 `bin/uya` 和 `bin/cmd/build`。
- `bin/uya tests/test_errno.uya -o /tmp/implicit` 在 Phase D 后应失败并提示使用 `uya build`，避免隐式入口残留。
- `make install` 安装 `bin/uya` 与 `bin/cmd/*`，安装后的 `uya build/check/run/test/fmt/upm` 可用。

---

## 9. 完成定义（本轮更新后）

- [ ] Phase A 完成：`src/compiler_driver.uya` 已创建，`parse_args`/`compile_files`/链接/C import 已移入，`src/main.uya` 调用其导出函数，回归测试通过。
- [ ] Phase B 完成：`src/microapp.uya` 已创建，全部 microapp 函数已移入，`src/main.uya` 调用其导出函数，`make microapp-check` 通过。
- [ ] Phase C 完成：`src/cmd/build/check/run/test/fmt/upm/main.uya` 为真实独立入口，`make cmds` 生成真实二进制，`dispatch_external_cmd` 测试通过。
- [ ] Phase D 准备完成：`cmd/build` seed 已纳入 `make from-c` / `make from-c-native` / `make backup-all`，清理后冷启动可生成 `bin/cmd/build`。
- [ ] Phase D 完成：`src/main.uya` 隐式编译入口已移除，变为纯调度器，自举种子已更新，`make backup-all` 通过。

**当前进度**：Phase A 尚未开始；调度器、`src/cmd/*`、`make cmds` 和调度测试均尚未落地。`src/main.uya` 仍约 8400 行，业务逻辑尚未拆分。
