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
