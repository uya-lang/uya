# Uya v0.9.8 发布说明

> **类型**：**v0.9.x 发行线上的补丁版本**（patch）  
> **发布日期**：2026-05-29

在 **v0.9.7** 完成 lowering / `drop` 语义与主线文档收口之后，**v0.9.8** 把最近两周已经落到主线的工具链扩展与发布线加固正式收进发行版：包管理 MVP、字节码 exec / VM 第一阶段、unknown hosted runtime smoke、`std.http.websocket`、`std.crypto.blake3`，以及一批 release/bootstrap、C99 codegen、线程与种子稳定性修复。

---

## 核心变更

### 1. `uya upm` 包管理 MVP 落地

- `src/cmd/upm/main.uya`
- `src/cmd/upm/upm_lib/main.uya`
- `src/checker/modules.uya`
- `src/driver/modules.uya`
- `docs/package_management.md`
- `tests/verify_upm_suite.sh`
- `tests/fixtures/upm/*`
- `examples/package_example/*`

本版本正式加入 package mode / manifest 工作流：

- 新增 `uya.toml` / `uya.lock` 语义；
- 支持 `path` 与 `git` 依赖；
- 明确 `package root` / `source root` / `module root`；
- 提供 `upm init` / `install` / `update` / `build`；
- `uya build/check/run/test` 已能在 package mode 下按依赖图工作。

同时新增 repo-local `cmd/upm` 验证入口，并补齐离线 git fixture、alias 冲突、缺失 manifest / lockfile、source-dir 布局等回归测试。

### 2. `uya check` 与字节码 exec / VM 第一阶段

- `src/exec/*`
- `src/main.uya`
- `docs/bytecode_exec_design.md`
- `docs/todo_bytecode_exec.md`
- `tests/verify_exec_vm_*.sh`
- `tests/test_exec_vm_*.uya`

本版本把 `uya check` 子命令与第一阶段 exec backend 一起收入口径：

- `uya check <file>` 可只做词法 / 语法 / 类型检查，不进入代码生成；
- 新增 bytecode builder + VM 主链，覆盖 globals、match、error union、defer/errdefer、aggregate、interface/union dispatch、部分 `extern/libc` bridge 等路径；
- `--vm` / `--exec` 的 unsupported reason、staged smoke 与编译器本体拉伸 smoke 已同步补齐。

这仍不是“exec backend 已完全替代 C99 后端”的宣告，但已经形成稳定的第一阶段回归面。

### 3. hosted/runtime 与标准库能力继续扩面

- `lib/libc/syscall.uya`
- `tests/emcc_unknown_runtime_smoke.uya`
- `tests/verify_emcc_unknown_runtime.sh`
- `lib/std/http/websocket_*.uya`
- `lib/std/http/uyagin_websocket.uya`
- `tests/test_http_websocket_*.uya`
- `lib/std/crypto/blake3.uya`
- `tests/test_crypto_blake3.uya`
- `lib/std/microapp/io.uya`

本版本继续把“主线能跑到哪里”往前推：

- unknown target / Web hosted 路线补入受限 `libc.sys_*` bridge，并新增 `make tests-emcc` smoke；
- `std.http.websocket` 协议层、async 会话核心与 `uyagin` upgrade bridge 已落地；
- 新增纯 Uya 的 `std.crypto.blake3`；
- microapp `.uapp required_caps` 可自动推断 I/O 需求，减少 capability 漏配。

同时语言侧补入 `@error_name(err)`，让错误名字符串获取进入公开内建函数集合。

### 4. 发布链路、seed 与 C99/线程稳定性加固

- `Makefile`
- `backup/uya*.c`
- `src/codegen/c99/*`
- `src/checker/type_layout.uya`
- `src/parser/main.uya`
- `lib/std/thread.uya`

围绕“能不能稳定发布”本身也做了一轮收口：

- `make release` 现有更严格的 preflight / clean-snapshot / dirty 调试分流；
- release/bootstrap 与 backup seed 流程已按当前主线刷新；
- 修复了 `!void` return 副作用保留、generic `async_compute` wrapper lowering、C99 `catch/sizeof/len` 与 method helper reachability、多模块导出符号命名、split-C cache 锁等回归；
- hosted 线程 worker 改为走 `pthread`，并补齐 macOS hosted seed extern 声明兼容。

---

## 升级指南

从 `v0.9.7` 升级到 `v0.9.8`：

```bash
git pull
git checkout v0.9.8

make clean && make release
make upm-check
```

如果本机安装了 `emcc` 与 `node`，建议额外执行：

```bash
make tests-emcc
```

---

## 统计与验证

| 项目 | 说明 |
|------|------|
| 相对 `v0.9.7` | 见 `git log v0.9.7..HEAD` |
| 当前工作树发布流水线 | `make release-dirty` 通过（2026-05-29） |
| 包管理专项验证 | `make upm-check` 通过（2026-05-29） |
| unknown hosted smoke | `make tests-emcc` 通过（2026-05-29；前提：本机已安装 `emcc` 与 `node`） |
| 最终 clean-tree release | 发布提交落库后执行 `make release-clean` 作为最终干净树复核 |
| 上一标签 | `v0.9.7` |

---

## 致谢

感谢所有为本版本贡献工具链、运行时、测试与发布验证的参与者。

---

**标签**：`v0.9.8`  
**下载 / 发行页**：[GitHub Releases](https://github.com/uya-lang/uya/releases/tag/v0.9.8)  
**完整变更日志**：[changelog.md](../changelog.md)
