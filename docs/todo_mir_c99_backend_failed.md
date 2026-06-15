# MIR-C99 Backend Failed Archive

**来源**: `docs/todo_mir_c99_backend.md`
**整理日期**: 2026-06-13
**说明**: 本文件保存从主 TODO 移出的 `[f]` 失败项及其阻塞原因、复现命令和后续重开条件；待办 `[ ]`、进行中 `[~]` 和完成 `[x]` 项不放在这里。

---

## 当前未重开的失败项

- 当前无未重开的主 TODO `[f]` 叶子；`docs/todo_mir_c99_backend.md` 当前没有 active leaf。完整语言后端 hard parity 已复验通过，不能由更早的 HelloWorld CLI 或 frontier smoke 记录反向覆盖。

## 已修复的外部门禁记录

- 2026-06-15：`bash tests/verify_full_language_backend_parity.sh` 曾失败，关键错误为 `error: hello native reject missing reason=native_hosted_portable_mir_lowering_missing`。已修复：gate 现在接受当前 fail-closed 诊断 `native_hosted_portable_mir_preflight_failed`，并要求 `native_hosted_preflight: status=-1` 与 `native_hosted_portable_mir_frontier:` 证据；复验默认模式通过，当前输出 `OK: full language backend parity: 18 cases (parity=18, reject=0)`。硬收口模式 `UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh` 已通过，当前输出同为 `OK: full language backend parity: 18 cases (parity=18, reject=0)`；覆盖 hello、multi-file use、generic、method、interface、error union / catch、defer、errdefer、struct/union/enum、slice/array、pointer、atomic、vector/mask、c_import、builtins、stdlib entry 和 print pair 的 native executable parity。
