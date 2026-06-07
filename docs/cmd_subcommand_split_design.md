# Uya 编译器入口瘦身设计：`src/main.uya` 拆分与职责外置

**状态**: design draft, implementation in progress
**更新日期**: 2026-06-07
**范围**: `src/main.uya` 物理拆分，`build`/`check`/`run`/`test`/`fmt`/`upm` 真实独立

> **当前问题**: `src/compiler_driver.uya` 已从原 `src/main.uya` 提取，`src/main.uya`
> 现在是过渡期 launcher（约 12 行），隐式编译入口仍调用同一份 driver 保持自举兼容。
> `src/cmd/build`/`check`/`run`/`test`/`fmt`/`upm` 入口已创建并能由 `make cmds`
> 生成到 `bin/cmd/*`；公开子命令会通过 `execve` 去掉子命令名后原样转发 argv。
> `cmd/build` 已切到 `src/build_compiler_driver.uya`，作为 build-only seed 根，不再静态导入
> exec / microapp image / upm / fmt / kernel packaging。`from-c` / `from-c-native`
> 已能从 `backup/cmd-build*-blob.c` 快速恢复 `bin/cmd/build`，缺失或平台不匹配时仍回退到
> `backup/cmd-build*.c`；`backup-all-seed` 也会刷新 build seed。当前剩余风险集中在更完整的
> 清理后 bootstrap / 调度回归。Microapp / microcontainer 逻辑仍保留，但目标 CLI 改为
> `uya microapp build|pack|inspect|verify|run`，通过独立 `bin/cmd/microapp` 接回，
> 不再作为 `src/main.uya` 的顶层 `pack-image` / `inspect-image` / `verify-image` 分支。
> 本设计目标是继续把过渡期 launcher 收敛为真实独立子命令体系，而不是增加一层回调 `src/main.uya` 的代理壳。

---

## 1. 背景

Phase 7 提取前，`src/main.uya` 同时承担：

- 编译器核心（参数解析、依赖收集、AST 合并、C99/LLVM 生成、工具链链接）
- Microapp 全链路（ELF64/Mach-O 解析、重定位、构建、打包/检查/验证 image）
- 命令分发和命令业务（`build`/`check`/`run`/`test`/`fmt` 的参数解析与执行）
- 辅助命令（旧顶层 `pack-image`/`inspect-image`/`verify-image`/`--outlibc`）
- 隐式编译入口（`uya file.uya -o out`，自举兼容）

提取前 `src/main.uya` 约 **3859 行**（2026-06-06 实测），其中：

| 区域 | 大约行数 | 说明 |
|------|---------|------|
| 编译主流程 `compile_files` | ~810 | 依赖收集、AST 合并、代码生成、工具链链接编排 |
| 主入口 `main` + 帮助 `print_usage` | ~690 | `main()` 命令分支、输出路径处理、帮助信息 |
| 参数解析 `parse_args` | ~380 | 所有命令行选项与校验 |
| `--outlibc` `generate_libc` | ~344 | 导出 libc 源码 |
| 其余（路径/模块查找/锁/`detect_main`/全局状态/microapp 参数桥接） | ~1600 | 通用工具与 microapp CLI 参数（核心 microapp 逻辑已外置） |

> 注：早期设计（2026-05-03）记录的 ~8400 行基线已过期。Microapp 的 ELF/Mach-O 提取、重定位、打包、检查、验证等核心逻辑已物理外置到独立 `microapp` 模块。2026-06-07 起，编译器 CLI 业务进一步移入 `src/compiler_driver.uya`，`src/main.uya` 仅保留 `use compiler_driver;` 与 `compiler_driver_main()` 调用。

当前已落地的基础设施：

- `src/compiler_driver.uya` 承载过渡期完整 CLI 业务，`src/main.uya` 保留 thin launcher。
- `src/build_compiler_driver.uya` 承载 build-only C99 编译/link 路径，供 `cmd/build` seed 使用。
- `src/cmd/build` 调用 build-only driver；`src/cmd/check`/`run`/`test` 复用完整 driver 的专用入口函数。
- `src/cmd/fmt` 直接调用 formatter CLI，`src/cmd/upm` 保持外置包管理入口。
- `src/cmd/microapp` 尚待补齐；目标是承载 `microapp build/pack/inspect/verify/run`。
- `Makefile` 已提供 `cmds` 和 `cmd-build`/`cmd-check`/`cmd-run`/`cmd-test`/`cmd-fmt`/`cmd-upm` 目标。
- `bin/uya` 已实现 `execve` 外部分发，并对公开子命令原样转发剩余 argv。

因此当前剩余问题不再是 `src/main.uya` 物理体积，也不是子命令二进制生成，
而是 `cmd/build` seed 尚未进入冷启动链条，以及调度回归还需要从 smoke 脚本扩展到完整套件。

---

## 2. 目标

### 2.1 源码瘦身

- `src/main.uya` 最终压到 **~1500 行以内**，只保留：
  - 子命令发现与外置调度（`dispatch_external_cmd`）
  - 全局帮助、版本信息
  - 隐式编译入口（过渡期内 thin wrapper，调用 `compiler_driver` 模块）
- 过渡期完整 CLI 逻辑集中到 **`src/compiler_driver.uya`**；build seed 逻辑集中到 **`src/build_compiler_driver.uya`**。
- Microapp 全链路逻辑集中到 **`src/microapp.uya`**（或 `lib/microapp/driver.uya`）。

### 2.2 真实独立子命令

- `src/cmd/build/main.uya` 是真实的编译器入口，不是 `execve` wrapper。
- `src/cmd/check/main.uya` 是真实的前端检查入口，停在 checker。
- `src/cmd/run/main.uya` / `test/main.uya` 调用 compiler driver，并由 driver 完成编译、链接、执行和退出码映射。
- `src/cmd/fmt/main.uya` 直接调用 `src/fmt.uya` 中的 `uyafmt_main()`，不绕回 `bin/uya`。
- `src/cmd/microapp/main.uya` 承载 microcontainer 工具链命名空间，不绕回 `bin/uya`。
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
  compiler_driver.uya       # 过渡期完整 CLI driver
  build_compiler_driver.uya # build-only C99 编译/link seed driver
  microapp/                 # ELF/Mach-O, microapp build/pack/inspect/verify/run
  fmt.uya                   # 格式化（已有独立入口 uyafmt_main）
  cmd/
    build/main.uya          # 真实编译器入口：use build_compiler_driver; build_compiler_driver_main()
    check/main.uya          # 前端检查入口：use compiler_driver; compiler_driver_check_main()
    run/main.uya            # 真实运行入口：use compiler_driver; compiler_driver_run_main()
    test/main.uya           # 真实测试入口：use compiler_driver; compiler_driver_test_main()
    fmt/main.uya            # 真实格式化入口：use fmt; uyafmt_main()
    upm/main.uya            # 包管理骨架
    microapp/main.uya       # microapp build/pack/inspect/verify/run

bin/
  uya                       # 过渡期：调度器 + 隐式入口；目标态：纯调度器
  cmd/
    build                   # build-only C99 编译器 seed 入口
    check                   # 前端检查器
    run                     # 编译+运行前端
    test                    # 编译+测试前端
    fmt                     # 格式化前端
    upm                     # 包管理前端
    microapp                # microcontainer 工具链前端
```

### 3.1 `src/main.uya` 职责（目标态）

1. `argc < 2`：打印主帮助。
2. `argv[1]` 是 `build/check/run/test/fmt/upm/microapp`：调用 `dispatch_external_cmd(...)`，不解析业务选项。
3. `argv[1]` 是 `--version`/`-v`：直接处理。
4. 旧顶层 `pack-image`/`inspect-image`/`verify-image` 不再作为目标主入口；若过渡期保留，只打印迁移提示或转发到
   `microapp pack` / `microapp inspect` / `microapp verify`，不得重新静态导入 microapp 大逻辑。
5. **过渡期保留**：隐式编译入口 `uya <file.uya> ...` 调用 `compiler_driver` 模块中的函数，用于自举和 `src/compile.sh` 兼容。
6. **过渡期后**：隐式入口移除，`src/main.uya` 只剩纯调度器。

### 3.2 `src/compiler_driver.uya` 与 `src/build_compiler_driver.uya` 职责

包含以下导出入口：

```text
compiler_driver_main() -> exit_code
compiler_driver_build_main() -> exit_code
compiler_driver_check_main() -> exit_code
compiler_driver_run_main() -> exit_code
compiler_driver_test_main() -> exit_code
```

完整 driver 语义边界：

- `compiler_driver_main()`：过渡期 `bin/uya` 入口，允许显式子命令和隐式编译入口。
- `compiler_driver_build_main()`：完成 build 的完整 CLI 语义并返回退出码。
- `compiler_driver_check_main()`：完成 lexer / parser / checker 流程并返回退出码，不执行代码生成。
- `compiler_driver_run_main()`：完成编译、链接、执行目标程序、映射子进程退出码，并返回最终退出码。
- `compiler_driver_test_main()`：完成测试编译、执行、测试摘要输出、退出码映射，并返回最终退出码。

build-only driver 语义边界：

```text
build_compiler_driver_main() -> exit_code
```

- `build_compiler_driver_main()`：只支持 build 所需参数、模块收集、checker、C99 codegen 和 host toolchain/link。
- 不导入 `exec` backend、`microapp` image/payload、`cmd.upm.upm_lib`、`fmt` 或 kernel packaging。

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

### 3.3 `src/microapp/` 与 `src/cmd/microapp/main.uya` 职责

包含所有 microapp 相关函数：

- `build_microapp_text_from_c`
- `pack_microapp_pobj_to_uapp`
- `inspect_microapp_image` / `inspect_microapp_pobj` / `inspect_microapp_uapp`
- `verify_microapp_image` / `verify_microapp_pobj`
- 全部 ELF64/Mach-O 解析、提取、重定位辅助函数

目标 CLI 入口集中在 `src/cmd/microapp/main.uya`：

```text
uya microapp build ...
uya microapp pack ...
uya microapp inspect ...
uya microapp verify ...
uya microapp run ...
```

`microapp build` 负责 microapp payload / `.pobj` / `.uapp` 构建；`microapp pack` / `inspect` /
`verify` 取代旧顶层 image 命令；`microapp run` 负责已接线 profile 的 loader 运行路径。
`src/main.uya` 不再直接 `use microapp`。

### 3.4 `src/cmd/build/main.uya` 与 `src/cmd/check/main.uya`（真实入口）

```uya
use build_compiler_driver;

export fn main() i32 {
    return build_compiler_driver_main();
}
```

```uya
use compiler_driver;

export fn main() i32 {
    return compiler_driver_check_main();
}
```

过渡期构建命令：

```bash
./bin/uya src/cmd/build/main.uya -o bin/cmd/build --no-split-c --project-root src/
```

`--project-root src/` 确保 `use build_compiler_driver;` 能正确解析到 `src/build_compiler_driver.uya`。Phase D 后不能再依赖这条命令生成第一份 `bin/cmd/build`，必须改由 `cmd/build` seed 或 bootstrap 编译器生成。

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

`src/cmd/build/main.uya` 位于 `src/cmd/build/`，默认模块查找根可能不是 `src/`。必须通过 `--project-root src/` 让 `use build_compiler_driver;` 正确映射到 `src/build_compiler_driver.uya`。

同样，`src/build_compiler_driver.uya` 和 `src/compiler_driver.uya` 中的 `use arena;` 等需要相对于 `src/` 解析，这要求 driver 本身也在 `src/` 下，或通过 `--project-root` 统一控制。

### 5.3 参数必须原样传递

调度器层必须使用 `execve` 或等价 argv API 转发参数，不使用 `system("cmd ...")` 拼接命令。`bin/cmd/build` 直接运行时接收的 argv 形式：

```text
bin/cmd/build main.uya -o app
bin/cmd/build build main.uya -o app   # 兼容但不推荐
```

公开调度器推荐传递第一种形式，即去掉 `uya` 后面的子命令名。

### 5.4 build seed 不反向导入完整 driver

`src/main.uya` 的隐式入口继续使用完整 `src/compiler_driver.uya`，保持过渡期兼容。
`src/cmd/build/main.uya` 使用 `src/build_compiler_driver.uya`，只保留 build 所需路径。
如果 build seed 需要通用 helper，应提到 build-safe 模块，而不是从完整 driver 或非 build 子系统反向导入。

---

## 6. 分阶段实施路线

### Phase A：提取 Compiler Driver（基础提取已落地）

1. 新建 `src/compiler_driver.uya`。
2. 把 `parse_args()`、`compile_files()`、链接工具链函数、C import 处理、通用编译工具函数移入。
3. `src/main.uya` 中 `use compiler_driver;`，隐式入口改为调用 `compiler_driver_main()`。
4. 运行 `./tests/run_programs_parallel.sh` 和 `make tests-uya` 验证。

**当前效果（2026-06-07）**：`src/main.uya` 约 12 行，`src/compiler_driver.uya` 约 3979 行；
`compiler_driver_main()` 承载原 CLI 业务，`src/main.uya` 作为过渡 launcher 保留隐式编译入口。

### Phase B：提取 Microapp 逻辑（已完成）

> **状态（2026-06-06）**：核心逻辑已外置为独立 `microapp` 模块。本节保留为历史记录；
> 旧顶层 image 命令不再是目标形态，后续通过 `cmd/microapp` 命名空间接回。

1. 新建 `src/microapp.uya`。
2. 把所有 microapp 相关函数移入。
3. 旧过渡方案曾让 `src/main.uya` 中 `use microapp;`，由 `pack-image`/`inspect-image`/`verify-image`
   命令调用 `microapp_*` 函数；目标方案改为 `src/cmd/microapp/main.uya`。
4. `src/compiler_driver.uya` 若需要 microapp 支持（如 `--app microapp` 编译流程），也 `use microapp;`。
5. 运行 `make microapp-check` 和 `make check-hosted` 验证。

**预期效果**：`src/main.uya` 从 ~6000 → ~2500 行。

### Phase C：独立 `cmd/build`/`check`/`run`/`test` 入口

1. 新建 `src/cmd/build/main.uya`：调用 `build_compiler_driver_main()`。
2. 新建 `src/cmd/check/main.uya`：调用 `compiler_driver_check_main()`，由 driver 完成 lexer / parser / checker 流程并返回退出码。
3. 新建 `src/cmd/run/main.uya`：调用 `compiler_driver_run_main()`，由 driver 完成编译、链接和执行。
4. 新建 `src/cmd/test/main.uya`：调用 `compiler_driver_test_main()`，由 driver 完成测试执行和摘要输出。
5. 新建 `src/cmd/fmt/main.uya`：直接调用 `uyafmt_main()`，不绕回 `bin/uya`。
6. 新建 `src/cmd/upm/main.uya`：提供最小 `--help`/`--version` 骨架。
7. 新建 `src/cmd/microapp/main.uya`：提供 `build/pack/inspect/verify/run` 命名空间。
8. Makefile 中新增 `cmds` 和 `bin/cmd/%` 规则，过渡期用 `bin/uya` 隐式入口构建。
9. `src/main.uya` 新增 `dispatch_external_cmd`，公开子命令转发到 `bin/cmd/xxx`。
10. 运行 `make cmds`、`./tests/test_cmd_dispatch.sh`、`make microapp-check`、`make check` 验证。

**当前效果（2026-06-07）**：`bin/cmd/build` 成为 build-only C99 编译器入口；
其 seed 源边界走 `src/build_compiler_driver.uya`、`src/checker_build/` 与
`src/codegen/c99_build/`，避免重新静态带入 exec / microapp image / upm / fmt /
kernel packaging 的大字符串池。Microapp CLI 仍待通过 `src/cmd/microapp/main.uya` 外置接回。
`src/main.uya` 仍为过渡期 launcher（含隐式入口）。

### Phase D：移除隐式入口，`src/main.uya` 纯调度器

`cmd/build` seed 的最小 root 与依赖边界见 [`build_compiler_seed_design.md`](build_compiler_seed_design.md)。

1. `cmd/build` 自举 seed 已接入 `make from-c` / `make from-c-native`，可从 host/arch blob 快速 seed 恢复 `bin/cmd/build`，并在缺失或平台不匹配时回退到 `backup/cmd-build.c` 或 host/arch C seed。
2. `backup-all-seed` 已会刷新 `backup/cmd-build.c`、host/arch C seed 与 host/arch blob seed。
3. 当前 Makefile 已把 `bin/cmd/build` 自身改成 seed-first 路径，避免纯调度器 `bin/uya` 与 `cmd/build` 互相等待。
4. 后续目标态再修改 `make cmds`：优先用 `bin/cmd/build` 构建 `bin/cmd/*`；仅过渡期允许回退到 `bin/uya` 隐式入口。
5. 当 seed 路线稳定后，移除 `src/main.uya` 中的隐式编译入口。
6. `src/main.uya` 中删除 `use compiler_driver;`；microapp 主入口必须已经外置为 `bin/cmd/microapp`。
7. 更新 `src/compile.sh`：自举编译器自身时，明确入口和编译器路径，不再假设 `bin/uya` 具备隐式编译能力。
8. 运行完整验证：`make clean`、`make from-c-native`、`make uya`、`make cmds`、`make check`、`make backup-all`。

**预期效果**：`src/main.uya` 最终 ~1500 行；`bin/uya` 大幅缩小。

---

## 7. 构建系统变更

### 7.1 Makefile

过渡期规则：

```make
UYA_CMD_NAMES := build check run test fmt upm microapp
UYA_CMD_BINS := $(patsubst %,bin/cmd/%,$(UYA_CMD_NAMES))

.PHONY: cmds cmd-build cmd-check cmd-run cmd-test cmd-fmt cmd-upm uya-upm-stage2
cmds: $(UYA_CMD_BINS) bin/uya-upm-stage2

UYA_CMD_BOOTSTRAP_COMPILER ?= ./bin/uya

bin/cmd/build: src/cmd/build/main.uya
	@if [ ! -x "$@" ]; then \
		$(MAKE) --no-print-directory restore-cmd-build-seed; \
	else \
		$(UYA_CMD_BOOTSTRAP_COMPILER) $< -o $@.tmp --no-split-c --project-root src/; \
		mv $@.tmp $@; \
	fi

bin/cmd/%: src/cmd/%/main.uya $(UYA_CMD_BOOTSTRAP_COMPILER)
	@mkdir -p bin/cmd
	$(UYA_CMD_BOOTSTRAP_COMPILER) $< -o $@ --no-split-c --project-root src/
	@echo "✓ 子命令已生成: $@"
```

`bin/cmd/build` 是特例：当它不存在时先从 C seed 恢复并结束。这样即使 `bin/uya`
已经变成 dispatcher-only，`make cmd-build` 也不会调度回还不存在的编译器入口。
已有 `bin/cmd/build` 且需要从源码重建时，过渡期仍默认使用完整 `./bin/uya`；其他子命令也
仍默认使用完整 `./bin/uya`，直到 build-only compiler 支持完整自举和子命令依赖图。

目标态规则：

```make
UYA_CMD_BOOTSTRAP_COMPILER ?= ./bin/cmd/build

bin/cmd/%: src/cmd/%/main.uya $(UYA_CMD_BOOTSTRAP_COMPILER)
	@mkdir -p bin/cmd
	$(UYA_CMD_BOOTSTRAP_COMPILER) $< -o $@ --no-split-c --project-root src/
	@echo "✓ 子命令已生成: $@"
```

`--project-root src/` 是关键：让 `src/cmd/build/main.uya` 中的 `use build_compiler_driver;` 能解析到 `src/build_compiler_driver.uya`。目标态下 `./bin/cmd/build` 必须已由 seed 生成，不能依赖纯调度器 `./bin/uya`。

### 7.2 `src/compile.sh`

编译 `src/cmd/xxx/main.uya` 时，默认传入 `--project-root src/`。编译 `src/main.uya` 时不传（或传入 `src/` 作为自身项目根）。Phase D 后，脚本必须显式区分“正在构建调度器 `bin/uya`”与“正在用 `bin/cmd/build` 编译普通入口”。

### 7.3 `make clean`

当前 `make clean` 通过清理整个 `bin/` 覆盖外置命令产物：

- `bin/cmd/`
- `bin/uya-upm-stage2`

后续如果 `clean` 改成保留 `bin/uya` 或部分 seed，仍必须显式清理：

- `bin/cmd/*`
- `src/build/cmd/`
- `src/build/compiler_driver.c` 等生成物

不要清理源码文件：

- `src/compiler_driver.uya`
- `src/microapp/`
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

新增 `tests/test_cmd_dispatch.sh`，并覆盖：

```bash
make cmds
./tests/test_cmd_dispatch.sh
./tests/verify_implicit_entry_until_cmd_build_seed.sh
bin/cmd/build tests/test_errno.uya -o /tmp/uya_cmd_build --no-split-c
bin/cmd/test tests/test_errno.uya
bin/cmd/fmt tests/test_errno.uya
bin/cmd/microapp --help
```

至少验证：

- `bin/uya build ...` 与 `bin/cmd/build ...` 语义和退出码一致。
- `bin/uya run ... -- ...` 的运行时参数通过 argv 原样保留。
- `bin/uya test ...` 与 `bin/cmd/test ...` 测试摘要和退出码一致。
- `bin/uya fmt ...` 与 `bin/cmd/fmt ...` 输出一致。
- `bin/uya microapp pack/inspect/verify ...` 与 `bin/cmd/microapp pack/inspect/verify ...` argv 分发一致。
- 临时隐藏 `bin/cmd/build` 时，`bin/uya build ...` 返回非 0，并提示 `cmd/build` 与 `make cmds`。
- `cmd/build` seed 稳定前，临时隐藏 `bin/cmd/` 时 `bin/uya file.uya ...` 隐式编译入口仍可用。

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
- `make install` 安装 `bin/uya` 与 `bin/cmd/*`，安装后的
  `uya build/check/run/test/fmt/upm/microapp` 可用。

---

## 9. 完成定义（本轮更新后）

- [ ] Phase A 完成：`src/compiler_driver.uya` 已创建，`parse_args`/`compile_files`/链接/C import 已移入，`src/main.uya` 调用其导出函数，回归测试通过。
- [ ] Phase B 完成：`src/microapp/` 或等价模块已创建，全部 microapp 函数已移入，`make microapp-check` 通过。
- [ ] Phase C 完成：`src/cmd/build/check/run/test/fmt/upm/main.uya` 为真实独立入口，`make cmds` 生成真实二进制，`dispatch_external_cmd` 测试通过。
- [ ] Phase C2 完成：`src/cmd/microapp/main.uya` 为真实独立入口，`uya microapp build|pack|inspect|verify|run` 取代旧顶层 image 命令，`make microapp-check` 通过。
- [ ] Phase D 准备完成：`cmd/build` seed 已纳入 `make from-c` / `make from-c-native` / `make backup-all`，清理后冷启动可生成 `bin/cmd/build`。
- [ ] Phase D 完成：`src/main.uya` 隐式编译入口已移除，变为纯调度器，自举种子已更新，`make backup-all` 通过。

**当前进度（2026-06-07）**：Phase B（microapp 外置）已完成；Phase A 的基础 driver
提取已完成，`src/main.uya` 变为 thin launcher，`src/compiler_driver.uya` 承载 `parse_args()`、
`compile_files()` 和原 CLI 编排；`src/cmd/build/main.uya` 已创建并可直接编译/执行 build；
`src/cmd/check/main.uya`、`src/cmd/run/main.uya` 与 `src/cmd/test/main.uya` 已创建并分别默认执行
check/run/test；`src/cmd/fmt/main.uya` 已创建并直接调用 formatter CLI；既有 `src/cmd/upm/main.uya`
继续作为外置包管理入口，`bin/uya upm` 仍调度到 `bin/cmd/upm`。
`src/cmd/microapp/main.uya` 尚未接线；microapp 目标 CLI 为
`uya microapp build|pack|inspect|verify|run`。
`bin/uya` 兼容 launcher 已具备基于 `execve` 的 `dispatch_external_cmd`，会去掉公开子命令名后原样转发
剩余 argv。
`make cmds` 已覆盖 build/check/run/test/fmt/upm 六个外置子命令，并使用隐式入口构建子命令，
避免 `bin/uya build` 调度回尚未存在的 `bin/cmd/build`。
`tests/verify_implicit_entry_until_cmd_build_seed.sh` 已固化 seed 稳定前必须保留隐式入口的保护。
Phase C 的剩余工作为调度测试尚未落地。
