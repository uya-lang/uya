# MIR-C99 Backend Failed Archive

**来源**: `docs/todo_mir_c99_backend.md`
**整理日期**: 2026-06-13
**说明**: 本文件保存从主 TODO 移出的 `[f]` 失败项及其阻塞原因、复现命令和后续重开条件；待办 `[ ]`、进行中 `[~]` 和完成 `[x]` 项不放在这里。

---

## 任务清单失败项

暂无。

### 2026-06-14
#### 4.16 Self Build
父级任务路径：`MIR-C99-BACKEND-SELF-BUILD-CANDIDATE`：生成真实 MIR-C99 compiler candidate。
  - [f] MIR-C99-built compiler 复跑 `cmd/build` self-build。
    - 日期：2026-06-14
    - 阻塞命令（沿用主 todo 当前基线；本轮归档清理未重跑）：`bash tests/verify_mir_c99_self_build_convergence_audit.sh`；`bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`
    - 关键阻塞：当前基线仍固定 `self_build_convergence_status=real_compiler_candidate`、`host_compiler_binary_candidate_role=compiler_binary`、`blocked_category_count=4`；`cmd/build --help` smoke 只证明仓库跟踪的 `backup/cmd-build.c` 过渡 candidate 可运行，尚未证明 MIR-C99 backend 独立生成的 compiler candidate 能完成真实 `cmd/build` self-build。
    - 重开条件：让 MIR-C99 backend 独立生成等价 compiler candidate C，并使 `blocked_category_*` 继续收敛下降，或直接以 MIR-C99 生成候选通过 `cmd/build` compiler smoke / self-build。
