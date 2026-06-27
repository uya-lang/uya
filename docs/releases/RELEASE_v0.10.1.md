# Uya v0.10.1 发布说明

> **类型**：**v0.10.x 发行线上的补丁版本**（patch）
> **发布日期**：2026-06-28

在 **v0.10.0** 完成 `fmt` CLI/API、if expression 与 C99 主线稳定性收口之后，**v0.10.1** 聚焦发布线稳定化：继续推进 async runtime 动态资源、UPM/package 工作流、malloc 与 HTTP benchmark 性能验证、UyaGin 热路径，以及 Linux / hosted seed 与 macOS hosted release 路径。

---

## 核心变更

### 1. async runtime 动态资源与网络组合路径

本版本将 async 主线从固定容量样板继续推进到更适合真实负载的动态资源模型：

- async frame meta table、await descriptor、scheduler、event、epoll、task queue 与 thread pool 相关容量改为动态或可配置路径；
- `async_compute`、async fd、DNS、HTTP1、WebSocket、UyaGin 等组合层继续迁移到统一 async substrate；
- 补齐 cancellation、timeout、frame release、eventfd / fd leak、shared runtime semantics 与业务边界回归；
- 修复 nested async、catch/try/await、generic async method、future interface monomorphization 等 C99 lowering / codegen 回归。

相关验证继续纳入 `make release` 主线，包括 async language matrix、shared runtime、TLS/DNS/HTTP/UyaGin 组合路径与 frame pool 动态资源用例。

### 2. UPM / package 工作流与 release 稳定性

UPM 从单点命令继续拆分为可维护的 package 工作流：

- 模块化 package manager 核心，覆盖 manifest、lockfile、resolver、fetcher、registry、workspace、publish 与 diagnostics；
- 支持 path / git / registry / proxy / workspace 后端、module identity、minimum version、add/remove、checksum mismatch 与 graph plan 回归；
- 修复 package mode、module alias C99 codegen、cmd build、release-dirty、hosted seed 与 macOS hosted release flow 相关问题；
- 刷新 Linux nostdlib seed 与 hosted seed，保持 C99 种子与当前自举源码一致。

### 3. malloc、HTTP benchmark 与 UyaGin 热路径

本版本补齐了一批性能与稳定性工作：

- libc heap 增加 size-segregated bins、large allocation direct mmap、adjacent coalescing、realloc in-place growth、per-thread tcache 与相关诊断；
- HTTP benchmark 继续稳定化，新增 nginx、Zap、go-gnet、UyaGin 对照，并统一 `/plaintext` 主路由；
- 强化 benchmark 结果解析、边界检查、nostdlib mode 与 release-dirty 验证；
- 优化 UyaGin hot path metrics，并补齐 async boundary / socket handling 回归。

### 4. C99 后端、跨平台与测试闸门

本版本继续把发布闸门做厚：

- 修复 generic null type args、C99 generic array monomorph emission、async try `@await` binding、private generated symbol 稳定性等问题；
- 增加 macOS hosted seed extern 声明、Linux AArch64 / ARM32 `@syscall` 交叉编译、ARM NEON SIMD 片段交叉编译验证；
- 强化 `make check`、`upm-check`、exec VM、microapp、SIMD、slice ABI 与 benchmark C99 验证在 release 流程中的覆盖。

---

## 升级指南

从 `v0.10.0` 升级到 `v0.10.1`：

```bash
git pull
git checkout v0.10.1

make clean && make release
```

在高并发 Linux 构建机上，如果大量大体积 HTTP / WebSocket 测试同时链接导致 300s timeout，可以显式降低发布测试并发：

```bash
make release UYA_TEST_JOBS=8
```

---

## 统计与验证

| 项目 | 说明 |
|------|------|
| 相对 `v0.10.0` | 见 `git log v0.10.0..HEAD` |
| 最终 release | `make release UYA_TEST_JOBS=8` 通过（2026-06-28；1071/1071 测试通过） |
| 自举一致性 | `make release` 内部自举对比通过，主编译器与自举编译器生成的可执行文件字节一致 |
| UPM 套件 | `make upm-check` 通过（由 release 闸门调用） |
| microapp 聚合套件 | `make microapp-check` 通过（由 release 闸门调用） |
| 交叉验证 | Linux AArch64 / ARM32 `@syscall`、ARM NEON SIMD 片段交叉编译通过 |
| 发布产物 | `bin/uya` 使用 `-O3 -fno-builtin -DNDEBUG` 构建并 strip |
| 上一标签 | `v0.10.0` |

---

## 致谢

感谢所有为本版本贡献 async runtime、UPM/package、性能优化、跨平台 release 与测试验证的参与者。

---

**标签**：`v0.10.1`
**下载 / 发行页**：[GitHub Releases](https://github.com/uya-lang/uya/releases/tag/v0.10.1)
**完整变更日志**：[CHANGELOG.md](../../CHANGELOG.md)
