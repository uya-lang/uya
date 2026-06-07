# Build Compiler Seed 设计

**状态**: build-only driver implemented, seed restore / backup refresh / dispatcher deadlock guard / clean bootstrap / fast blob restore verified
**更新日期**: 2026-06-07
**范围**: Phase 8 `cmd/build` seed 瘦身，避免 dispatcher-only `bin/uya` 与真实编译器互相等待。

## 1. 目标

Phase 8 的 build seed 只负责恢复一个能继续构建仓库的真实编译器入口：

```text
backup/cmd-build.c -> bin/cmd/build
```

`bin/uya` 目标态只做 launcher/dispatcher；它不能再承担“第一份编译器”的职责。因此最小 build compiler root 必须是 `cmd/build`，而不是 `src/main.uya`。
`backup/cmd-build*.c` 是新增 build seed；`backup/cmd-build-<host>-<arch>-blob.c` 是精确 host/arch
快速恢复 seed。现有 `backup/uya.c`、`backup/uya-hosted.c` 及 host/arch C99 fallback seed 仍保留，
用于差分、旧路径恢复和发布回退。

## 2. 最小 Root

目标 root：

```text
src/cmd/build/main.uya
```

目标 root 的第一层依赖应收敛为：

```text
src/cmd/build/main.uya
  -> src/build_compiler_driver.uya
      -> arena / ast / lexer / parser
      -> semantic / typed / checker_build
      -> driver.modules / driver.toolchain
      -> codegen.c99_build
      -> libc + std runtime entry
```

`src/build_compiler_driver.uya` 已落地为 build-only driver。它只解析 build 所需参数、收集模块、执行 parse/check/C99 codegen、调用 host toolchain/linker，并返回 CLI 退出码。Phase 8 同时引入 `checker_build` 与 `codegen.c99_build`，用于在 seed 中裁掉 microapp/container-only 的诊断字符串、bridge/MMU helper 文本和 image/payload 相关静态池；完整编译器仍使用原 `checker` 与 `codegen.c99`。

## 3. 必须包含

- `arena`、`ast`、`lexer`、`parser`：源码解析与 AST。
- `semantic`、`typed`、`checker_build`：名称解析、类型检查、安全证明所需前端，去掉 build seed 不会启用的 container-only 诊断。
- `driver.modules`、`driver.toolchain`：模块发现、project root、host C toolchain 调用。
- `codegen.c99_build`：Phase 8 仍以 C99 seed 作为恢复路径，去掉 microapp bridge/MMU helper 静态字符串池。
- 最小 `libc` / `std.runtime.entry`：进程入口、文件 IO、内存、字符串、进程执行所需绑定。
- `CompileStats` 与现有 benchmark 需要的输出字段，包括 `output_bytes`、arena 峰值和 C99 输出缓冲峰值。
  `bench-compiler-1s` 的 `output_bytes` 必须纳入 build seed artifacts：`backup/cmd-build*.c`、生成期的
  `src/build/cmd-build.c` / `src/build/cmd/build.c`、host/arch blob seed，以及恢复出的 `bin/cmd/build`。

## 4. 源码边界

`cmd/build` seed 的允许边界：

| 类别 | 源码边界 |
|------|----------|
| root | `src/cmd/build/main.uya` |
| build driver | `src/build_compiler_driver.uya` 或等价 build-only driver |
| frontend 基础 | `src/arena.uya`、`src/ast.uya`、`src/lexer.uya`、`src/extern_decls.uya`、`src/str_utils.uya`、`src/std_cfg.uya` |
| parser | `src/parser/*.uya` |
| semantic / typed | `src/semantic/*.uya`、`src/typed/*.uya` |
| checker | `src/checker_build/*.uya`，仅保留 build/check 所需诊断、安全证明和类型系统路径 |
| driver | `src/driver/modules.uya`、`src/driver/toolchain.uya` |
| C99 backend | `src/codegen/c99_build/*.uya` 与必要 lower helper |
| runtime / libc | `lib/libc/*.uya`、`lib/std/runtime/*.uya`、`lib/std/platform.uya`、`lib/std/io/file.uya`、`lib/std/string/string.uya`、`lib/std/mem/mem.uya` |

seed 生成时应把实际依赖列表写入 benchmark 或验证日志；如果新增源码越过上述边界，必须在同一变更中解释为什么它属于 build-only compiler。

当前实测依赖列表为 80 个文件，低于原 `src/main.uya` 路径的 86 个文件；验证脚本会继续检查该路径不包含 exec / microapp image / upm / fmt / kernel packaging，也不会回退导入完整 `checker` / `codegen.c99`。

## 5. 禁止包含

build seed 不能静态导入以下大型非 build 子系统：

- `exec` backend。
- `microapp` image / payload / ELF / Mach-O 打包逻辑。
- `cmd.upm.upm_lib`。
- `fmt`。
- `kernel.image`、`kernel.payload`、`kernel.rv32_scan` 等 kernel packaging。
- 非 build CLI 分支，如 `run`、`test`、`fmt`、`upm`、`microapp build`、`microapp pack`、
  `microapp inspect`、`microapp verify`、`microapp run`。

如果 `cmd/build` 仍需要某个通用 helper，应把 helper 提到 build-safe 模块，而不是从上述子系统反向导入。

## 6. Bootstrap 顺序

冷启动目标顺序：

```text
make clean
make from-c
  1. 从 backup/uya.c 恢复最小 dispatcher bin/uya，或从现有 fallback seed 恢复兼容编译器。
  2. 优先从 `backup/cmd-build-<host>-<arch>-blob.c` 快速恢复 `bin/cmd/build`；缺失或平台不匹配时，
     回退到 `backup/cmd-build-<host>-<arch>.c` 或 `backup/cmd-build.c`。
  3. 请求 `make cmd-build` 时，如果 `bin/cmd/build` 不存在，先从 C seed 恢复并结束；已有 `bin/cmd/build` 且需要从源码重建时，过渡期仍用完整 `bin/uya`。
  4. 过渡期 `make cmds` 仍用完整 `bin/uya` 构建 check/run/test/fmt/upm；等 build-only compiler 支持完整自举和子命令依赖图后，再切到 `bin/cmd/build`。
```

在 Phase D 之前，`src/main.uya` 的隐式入口仍保留，作为过渡期安全网。当前 `make from-c`
和 `make from-c-native` 已会从 `cmd/build` seed 恢复 `bin/cmd/build`，`backup-all-seed`
也会刷新 `backup/cmd-build.c`、host/arch 变体和 host/arch blob 快速 seed。`cmd-build` 目标在缺少 `bin/cmd/build`
时会先走 seed restore 并结束，而不是调用 `bin/uya build`，因此不会和 dispatcher-only
`bin/uya` 互相等待。当前 build-only `cmd/build` 还不能链接自身生成的 C 输出，完整自举能力
留到后续阶段；只有清理后 bootstrap 验证通过，才能把 `bin/uya` 收敛为纯 dispatcher。

## 7. 验收

最小 root 设计落地后必须满足：

```bash
make clean
make from-c
test -x bin/uya
test -x bin/cmd/build
bin/cmd/build tests/test_errno.uya -o /tmp/uya_seed_errno --no-split-c
/tmp/uya_seed_errno
make cmd-build
make cmds
```

并且静态依赖检查必须确认 `cmd/build` seed 的 C 输出不包含 `exec`、microapp bridge/MMU、`upm`、`fmt` 和 kernel packaging 的符号或大字符串池。`--microapp-profile` 等拒绝用 CLI 文案可以保留，因为它们证明 seed 明确拒绝该路径，不属于 image/payload 静态池；拒绝文案应指向 `uya microapp build ...`，不要把旧顶层 `pack-image` / `inspect-image` / `verify-image` 当作目标主入口。

当前边界验证：

```bash
bash tests/verify_build_seed_boundary.sh
bash tests/verify_build_seed_restore_time.sh
```

`verify_build_seed_restore_time.sh` 要求当前 host/arch blob seed 存在，验证 `restore-cmd-build-seed`
确实走快速 blob 路径并在 3000ms 内恢复可用的 `bin/cmd/build`。普通 `backup/cmd-build*.c`
仍作为可审计 C99 fallback 保留。
