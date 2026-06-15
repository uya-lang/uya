# MIR-C99 Backend Failed Archive

**来源**: `docs/todo_mir_c99_backend.md`
**整理日期**: 2026-06-13
**说明**: 本文件保存从主 TODO 移出的 `[f]` 失败项及其阻塞原因、复现命令和后续重开条件；待办 `[ ]`、进行中 `[~]` 和完成 `[x]` 项不放在这里。

---

## 当前未重开的失败项

- MIR-C99-built compiler 复跑 compiler regression、C99 output parity 和 full-language backend parity：仍需真实 MIR-C99-built compiler 复跑完整 regression/parity；当前 `mir_c99_unit_output` 只推进到 return-literal C99 output parity smoke、generic identity regression smoke、local array out-param regression smoke、stack-limit helper call smoke、parse-like 多 out-param smoke 和 local array index read smoke，不能证明完整 parity。

### 2026-06-14
#### 4.16 Self Build
父级任务路径：`MIR-C99-BACKEND-SELF-BUILD-CANDIDATE`：生成真实 MIR-C99 compiler candidate。

已重开历史项：MIR-C99-built compiler 复跑 `cmd/build` self-build。

- 日期：2026-06-14
- 原阻塞命令：`bash tests/verify_mir_c99_self_build_convergence_audit.sh`；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`
- 原关键阻塞：当前基线仍固定 `self_build_convergence_status=real_compiler_candidate`、`host_compiler_binary_candidate_role=compiler_binary`、`blocked_category_count=4`；`cmd/build --help` smoke 只证明仓库跟踪的 `backup/cmd-build.c` 过渡 candidate 可运行，尚未证明 MIR-C99 backend 独立生成的 compiler candidate 能完成真实 `cmd/build` self-build。
- 重开位置：`docs/todo_mir_c99_backend.md` 4.16 `去除 tracked_cmd_build_seed 过渡源`。
- 重开验证：`bash tests/verify_mir_c99_self_build_true_candidate_reopen.sh` 确认失败归档无待执行 `[f]` 残留、主 TODO 存在去 seed 化叶子，并保留 `MIR_C99_COMPILER_SOURCE_BACKEND=tracked_cmd_build_seed` 为当前阻塞证据。

## 2026-06-15 本轮（goal-task-runner）

父级路径：MIR-C99-BACKEND-SELF-BUILD-CANDIDATE：生成真实 MIR-C99 compiler candidate。 -> MIR-C99-built compiler 复跑 compiler regression、C99 output parity 和 full-language backend parity。

- [f] MIR-C99-built compiler 复跑 compiler regression、C99 output parity 和 full-language backend parity：本轮硬约束强制只能使用 `../uya/bin/uya` 作为编译器；当时 `mir_c99_generate.sh` 对 `src/cmd/build/main.uya` 的 generator 仍固定 `MIR_C99_COMPILER_SOURCE_BACKEND=tracked_cmd_build_seed`，候选 C 实际来自仓库跟踪的 `backup/cmd-build.c` seed + stdio 符号补丁，**不是 MIR-C99 backend 独立产出的 C**。因此既不存在可用的"MIR-C99-built compiler"，本叶子要求的"复跑 compiler regression / C99 output parity / full-language backend parity"在缺失真实 candidate 的前提下无法被验证。
  - 阻塞命令：`UYA_ROOT=$PWD ../uya/bin/uya build src/cmd/build/main.uya -o /tmp/cmd-build-probe.out --project-root src/ --no-split-c`（cwd=uya-1.0 根）。
  - 关键错误：`错误: 收集模块依赖失败: src/cmd/build/main.uya`。
  - 关键证据：`bash tests/verify_mir_c99_self_build_convergence_audit.sh` + `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 复测仍固定 `self_build_convergence_status=real_compiler_candidate`、`host_compiler_binary_candidate_role=compiler_binary`、`blocked_category_count=4`；`MIR_C99_COMPILER_SOURCE_BACKEND=tracked_cmd_build_seed` 仍为默认 generator 当前 source；`../uya/bin/uya` mtime=2026-06-12 13:47（对应 sibling `uya/src/` 源码树），1.0 当前 `src/build_compiler_driver.uya` / `src/cmd/build/main.uya` / `src/cmd/build_bootstrap/main.uya` mtime=2026-06-15 08:55（比 sibling 编译产物晚 3 天），sibling 源码树 `grep build_compiler_driver` 无任何匹配，模块名解析在 mandated 路径下必然失败。
  - 当前基线：`bash tests/verify_mir_c99_self_build_convergence_audit.sh` 通过；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 通过；`bash tests/verify_mir_c99_self_build_true_candidate_reopen.sh` 通过；`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 通过（验证 default generator 仍固定 `compiler_source_backend=tracked_cmd_build_seed` 的过渡状态）。
  - 重开条件：必须先在硬约束"只能使用 `../uya/bin/uya`"放宽，或在 sibling `uya/` 仓库落地 1.0 当前 `src/build_compiler_driver.uya` / `src/cmd/build/main.uya` / `src/cmd/build_bootstrap/main.uya` 等价模块并重新编译 `bin/uya`，且父级 `去除 tracked_cmd_build_seed 过渡源` 子任务真正通过、`MIR_C99_COMPILER_SOURCE_BACKEND` 不再为 `tracked_cmd_build_seed` 之后，才能用真实 MIR-C99-built compiler 推进 compiler regression / C99 output parity / full-language backend parity。

已部分重开进展（2026-06-15）：`tracked_cmd_build_seed` 已去除，`bash tests/verify_mir_c99_cmd_build_parity_frontier_gate.sh` 通过，证明 candidate 能接受最小 build smoke、解析 literal return、generic identity 常量返回、local array out-param 写回、stack-limit helper call smoke、parse-like 多 out-param 写回和 local array index read，并与现有 C99 oracle 的 stdout/stderr/exit code 对齐；但 log/summary 仍记录 `full_language_backend_parity_status=not_yet_run`，所以本失败项不能移入 completed。
