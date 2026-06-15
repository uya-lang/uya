# MIR-C99 Backend Failed Archive

**来源**: `docs/todo_mir_c99_backend.md`
**整理日期**: 2026-06-13
**说明**: 本文件保存从主 TODO 移出的 `[f]` 失败项及其阻塞原因、复现命令和后续重开条件；待办 `[ ]`、进行中 `[~]` 和完成 `[x]` 项不放在这里。

---

## 当前未重开的失败项

暂无。

### 2026-06-14
#### 4.16 Self Build
父级任务路径：`MIR-C99-BACKEND-SELF-BUILD-CANDIDATE`：生成真实 MIR-C99 compiler candidate。

已重开历史项：MIR-C99-built compiler 复跑 `cmd/build` self-build。

- 日期：2026-06-14
- 原阻塞命令：`bash tests/verify_mir_c99_self_build_convergence_audit.sh`；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`
- 原关键阻塞：当前基线仍固定 `self_build_convergence_status=real_compiler_candidate`、`host_compiler_binary_candidate_role=compiler_binary`、`blocked_category_count=4`；`cmd/build --help` smoke 只证明仓库跟踪的 `backup/cmd-build.c` 过渡 candidate 可运行，尚未证明 MIR-C99 backend 独立生成的 compiler candidate 能完成真实 `cmd/build` self-build。
- 重开位置：`docs/todo_mir_c99_backend.md` 4.16 `去除 tracked_cmd_build_seed 过渡源`。
- 重开验证：`bash tests/verify_mir_c99_self_build_true_candidate_reopen.sh` 确认失败归档无待执行 `[f]` 残留、主 TODO 存在去 seed 化叶子，并保留 `MIR_C99_COMPILER_SOURCE_BACKEND=tracked_cmd_build_seed` 为当前阻塞证据。

## 2026-06-14 21:14:08 +0800

父级路径：MIR-C99-BACKEND-SELF-BUILD-CANDIDATE：生成真实 MIR-C99 compiler candidate。 -> 去除 `tracked_cmd_build_seed` 过渡源：默认 generator 对 `src/cmd/build/main.uya` 必须由 source-to-PortableMIR + `mir_c99_driver_run` + `MirC99Emitter` 生成 candidate C；完成前 `MIR_C99_COMPILER_SOURCE_BACKEND=tracked_cmd_build_seed` 只作为阻塞证据，host `cmd/build --help` seed smoke 不得作为本叶完成。

- [f] 补上真实 MIR-C99 writer hook：为 `../uya/bin/uya build ... --c99 --no-split-c` 增加受环境变量控制的真实 writer 分支，把普通 `.uya` root 经 source-to-PortableMIR + `mir_c99_driver_run` + `MirC99Emitter` 写成 unit-output C 文件；最小验证=`bash tests/verify_mir_c99_true_writer_smoke.sh`；完成条件=输出 `.c` 来自真实 MIR-C99 unit output，不再复制 tracked seed，且 host C compiler 至少能 `-c` 编译该 smoke 输出。
  - 失败原因：按本轮硬约束，所有 Uya 构建/验证必须使用 `../uya/bin/uya`。为让 smoke 真正覆盖当前仓库改动，先后尝试直接构建 `src/cmd/build/main.uya` 与构建基于当前仓库 `build_compiler_driver` 的薄 wrapper，但都在 mandated compiler 的依赖收集阶段失败，无法产出承载当前改动的临时 build CLI，因此无法继续验证 true writer hook。
  - 阻塞命令：`../uya/bin/uya build src/cmd/build/main.uya -o /tmp/cmd-build.XXXXXX --project-root src/ --no-split-c`。
  - 阻塞命令：`UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build/main.uya -o /tmp/cmd-build.XXXXXX --project-root src/ --no-split-c`。
  - 阻塞命令：`../uya/bin/uya build ./src/cmd/build/main.uya -o /tmp/cmd-build.XXXXXX --project-root src/ --no-split-c`。
  - 阻塞命令：`../uya/bin/uya build ./src/cmd/build -o /tmp/cmd-build.XXXXXX --project-root src/ --no-split-c`。
  - 阻塞命令：`UYA_ROOT="$PWD" ../uya/bin/uya build src/mir_c99_writer_build_driver_main.uya -o /tmp/cmd-build.XXXXXX --project-root src/ --no-split-c`。
  - 关键错误：`错误: 收集模块依赖失败: src/cmd/build/main.uya`。
  - 关键错误：`错误: 收集模块依赖失败: src/mir_c99_writer_build_driver_main.uya`。
  - 重开条件：先找到一条在不使用 `bin/cmd/build` / 本地 `bin/uya` 的前提下，能让 `../uya/bin/uya` 构建当前仓库 `build_compiler_driver` 入口的命令或等价入口；只有拿到承载当前改动的临时 build CLI，后续 true writer smoke 与 generator 切换才有可验证基础。

## 2026-06-15 归档清理轮

父级路径：MIR-C99-BACKEND-SELF-BUILD-CANDIDATE：生成真实 MIR-C99 compiler candidate。 -> 去除 `tracked_cmd_build_seed` 过渡源：默认 generator 对 `src/cmd/build/main.uya` 必须由 source-to-PortableMIR + `mir_c99_driver_run` + `MirC99Emitter` 生成 candidate C；完成前 `MIR_C99_COMPILER_SOURCE_BACKEND=tracked_cmd_build_seed` 只作为阻塞证据，host `cmd/build --help` seed smoke 不得作为本叶完成。

- [f] 切换默认 generator 的 `cmd/build` 路径到真实 writer hook：`tests/mir_c99_generate.sh` 对 `src/cmd/build/main.uya` 不再复制 `backup/cmd-build*.c`，而是调用真实 MIR-C99 writer 生成 candidate C；最小验证=`bash tests/verify_mir_c99_cmd_build_true_writer_gate.sh`；完成条件=log/summary 不再出现 `MIR_C99_COMPILER_SOURCE_BACKEND='tracked_cmd_build_seed'`，且 gate 证明 source backend 为真实 MIR-C99 writer。
  - 失败原因：本轮为归档清理轮，按硬约束不启动/不继续/不拆分任何 `[ ]`/`[~]` 任务；上一轮（2026-06-14 21:14:08）已在 `补上真实 MIR-C99 writer hook` 子任务中记录相同失败链路（`../uya/bin/uya` 构建 `src/cmd/build/main.uya` / 临时 wrapper 时，依赖收集阶段报 `错误: 收集模块依赖失败: src/cmd/build/main.uya`），根因是 mandated compiler 路径下没有可承载当前改动的 build CLI，过渡源未真正去除。
  - 阻塞命令：`../uya/bin/uya build src/cmd/build/main.uya -o /tmp/cmd-build.XXXXXX --project-root src/ --no-split-c`。
  - 关键错误：`错误: 收集模块依赖失败: src/cmd/build/main.uya`。
  - 关键证据：`bash tests/verify_mir_c99_self_build_convergence_audit.sh` + `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 仍固定 `self_build_convergence_status=real_compiler_candidate`、`host_compiler_binary_candidate_role=compiler_binary`、`blocked_category_count=4`；`MIR_C99_COMPILER_SOURCE_BACKEND=tracked_cmd_build_seed` 仍为默认 generator 的当前 source。
  - 重开条件：先在 mandated `../uya/bin/uya` 路径下找到一条能构建当前仓库 `build_compiler_driver` 入口的命令或等价入口，产出承载当前改动的临时 build CLI；再以该 CLI 跑 `bash tests/verify_mir_c99_cmd_build_true_writer_gate.sh`，直到 log/summary 中 `MIR_C99_COMPILER_SOURCE_BACKEND` 不再为 `tracked_cmd_build_seed`、且 gate 证明 source backend 为真实 MIR-C99 writer，方可重开。
