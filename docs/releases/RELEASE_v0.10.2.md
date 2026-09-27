# Uya v0.10.2 发布说明

> **类型**：**v0.10.x 发行线上的补丁版本**（patch）
> **发布日期**：2026-09-27

在 **v0.10.1** 完成 async runtime 动态资源与 UPM/package 工作流收口之后，**v0.10.2** 用三个月（2026-06-28 → 2026-09-27，337 个提交）把两条新主线推到端到端可发布口径：`std.process` 进程/流水线运行时，以及 typed pipeline 的 parser → checker → lowering → codegen 全链路；同时修掉若干会导致"偶发红"的运行时与发布闸门问题。

---

## 核心变更

### 1. `std.process`：进程与流水线运行时收口

本版本最大的单一工作面（80 个提交）集中在进程与流水线抽象：

- 抽出 stage stream 抽象与 owned erased stage 生命周期，明确 stage 之间的所有权与析构顺序；
- 新增 exec worker 上的 Uya stage 执行路径与实验性 fork-backed stage 闸门，保留 Uya 侧错误信息而不被 exec 边界吞掉；
- child broker 隔离、信号 disposition 保留与子进程信号状态清理，覆盖中断信号路由与停止作业取消；
- 终端作业控制（前台所有权、停止作业）与 stdio remap 加固，内部 fd 保持在 stdio 之上；
- capture 策略与取消语义收敛：拒绝 status sink 上的 capture 策略、限制取消后的 capture 完成、区分终端 capture 成因；
- spawn 失败分类与结构化启动诊断，覆盖稳定的失败类别与父进程 fd 所有权前置断言。

### 2. typed pipeline 端到端落地

- checker 诊断补全：首个形参不是 `Pipeline`、非 `Pipeline` 左值参与管道、sink-after-chain、实例方法接收者与合成左值冲突等；
- lowering 收口：成功路径转移所有权、错误路径清理输入计划、`try` 前向传播，并支持嵌套 transformer；
- C99 codegen 补齐，新增 `std.script` process facade；
- 新增 `tests/verify_typed_pipeline_lowering_dump.sh` 等 lowering 快照 / 诊断验证，纳入常规闸门。

### 3. `std.path`、检查器与编译器回归

- `std.path` 平台条件（Linux / macOS / Windows）与目录模块别名统一，新增 `tests/verify_std_path_platform_targets.sh` 做交叉目标验证；
- 边界证明器修掉两个同源缺陷：范围事实不跨 `as usize` 传递（漏判越界），以及有符号源 `as usize` 下标被判为天然非负（静默越界读）；同时修复其暴露出的成员访问约束名悬垂指针（负哈希跳过池化 → 证明结果随变量名变化），配套正向回归 `tests/test_bounds_prover_as_usize_cast.uya` 与负例 `tests/error_array_bounds_signed_cast_lower_bound.uya`；
- 编译器修复 hosted stdio（调用点/声明点/文本发射统一到模块前缀符号，`stdin/stdout/stderr` 绑回 uya 流对象）、模块作用域下同名函数查找、macOS 交叉目标宿主绑定与微应用 payload / 宿主辅助符号泄漏；
- split-C 缓存锁与陈旧锁处理补齐验证脚本。

### 4. 偶发红与发布闸门

本版本把"看起来偶发"的问题逐一定位到具体机制：

- **pthread join 早释放线程栈导致的偶发 SIGSEGV（#139）**：子线程还在内核返回路径上时 join 侧就 `free(stack)`/`munmap(desc)`，栈被后续 mmap 复用清零后子线程取到 0 返回地址（use-after-unmap）。修复方式是 `clear_child_tid`(`set_tid_address`) + 共享 `FUTEX_WAIT` 退出确认，并新增回归 `tests/test_pthread_join_stack_reuse.uya`；
- **自举种子冷启动链接失败**：跟踪的种子陈旧导致 `make release` 冷启动报 `uya_pipeline_worker_dispatch` 未定义，已按流程刷新 `backup/*.c` 种子；
- **fd 上限的环境依赖**：`test_async_event_dynamic_growth` 需要同时持有 2050+ 个 fd 才能跨过 `LinuxEpoll` 默认 1024 slot 边界，在默认软上限 1024 的登录终端里会拿到 `EMFILE` 并以"测试失败"收场，让 `make release` 只挂这一项。现在测试脚本启动时会把 `RLIMIT_NOFILE` 软上限提升到硬上限，用例自身也会先抬够并在环境确实不足时明确报 `skip:`，不再把环境限制记成回归；
- **UPM 版本号对齐**：`UYA_UPM_RUNTIME_VERSION` 长期停在 `0.10.0`（`upm --version` 与 `uya_min_version` 门控都按旧版本号比较），本版本对齐到 `0.10.2`，并把 min_version 失败用例改成用一个当前发行线达不到的版本号做断言，不再与发布版本号耦合。

---

## 升级指南

从 `v0.10.1` 升级到 `v0.10.2`：

```bash
git pull
git checkout v0.10.2

make clean && make release
```

在默认 `RLIMIT_NOFILE` 软上限较低（1024）的终端里，如需 fd 密集用例完整覆盖而非跳过，可先抬高软上限：

```bash
ulimit -S -n 65536      # 只抬软上限；注意不带 -S 的 ulimit -n 会同时改硬上限
```

---

## 统计与验证

| 项目 | 说明 |
|------|------|
| 相对 `v0.10.1` | 337 个提交（2026-06-28 → 2026-09-27，不含本次发布收口提交），`src/` + `lib/` + `tests/` 113 个文件、+10771/-924 行 |
| 最终 release | `make release` 通过（2026-09-27；1110/1110 测试通过，44 线程） |
| 自举一致性 | `make release` 内部自举对比通过（主编译器与自举编译器生成的可执行文件 `cmp` 字节相同） |
| 验证闸门 | 证明优化、默认顶层函数发射、UPM 套件、exec vm（含 compiler regression）、microapp 套件、SIMD select C、切片形参 C99、macOS hosted seed extern、`std.path` 平台条件、http_bench C99 全部通过 |
| 交叉验证 | Linux AArch64 / ARM32 `@syscall`、ARM NEON SIMD 片段交叉编译通过 |
| 发布产物 | `bin/uya` 使用 `-O3 -fno-builtin -DNDEBUG` 构建并 strip（nostdlib 种子：crti.o + uya.o + crtn.o） |
| 上一标签 | `v0.10.1` |

---

## 致谢

感谢所有为本版本 `std.process` / typed pipeline / 检查器边界证明、运行时偶发崩溃定位与发布闸门稳定性贡献的参与者。

---

**标签**：`v0.10.2`
**下载 / 发行页**：[GitHub Releases](https://github.com/uya-lang/uya/releases/tag/v0.10.2)
**完整变更日志**：[CHANGELOG.md](../../CHANGELOG.md)
