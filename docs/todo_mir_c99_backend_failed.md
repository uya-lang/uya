# MIR-C99 Backend Failed Archive

**来源**: `docs/todo_mir_c99_backend.md`
**整理日期**: 2026-06-13
**说明**: 本文件保存从主 TODO 移出的 `[f]` 失败项及其阻塞原因、复现命令和后续重开条件；待办 `[ ]`、进行中 `[~]` 和完成 `[x]` 项不放在这里。

---

## 当前未重开的失败项

- 当前无未重开的主 TODO `[f]` 叶子；`docs/todo_mir_c99_backend.md` 当前没有 active leaf。完整语言后端 hard parity 已复验通过，不能由更早的 HelloWorld CLI 或 frontier smoke 记录反向覆盖。

## 已修复的外部门禁记录

- 2026-06-15：`bash tests/verify_full_language_backend_parity.sh` 曾失败，关键错误为 `error: hello native reject missing reason=native_hosted_portable_mir_lowering_missing`。已修复：gate 现在接受当前 fail-closed 诊断 `native_hosted_portable_mir_preflight_failed`，并要求 `native_hosted_preflight: status=-1` 与 `native_hosted_portable_mir_frontier:` 证据；复验默认模式通过，当前输出 `OK: full language backend parity: 18 cases (parity=18, reject=0)`。硬收口模式 `UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh` 已通过，当前输出同为 `OK: full language backend parity: 18 cases (parity=18, reject=0)`；覆盖 hello、multi-file use、generic、method、interface、error union / catch、defer、errdefer、struct/union/enum、slice/array、pointer、atomic、vector/mask、c_import、builtins、stdlib entry 和 print pair 的 native executable parity。

### 4.15 Full Language Parity

父级路径：无父级 checkbox

- [f] `MIR-C99-FULL-SUPPORT-BASELINE-TRUTH`: 重新固定 full-language 口径下的真实基线，不把
  HelloWorld、hosted native parity、fixture generator 或 fixed-shape smoke 记为完成。
  当前证据（2026-06-23）：`bash tests/verify_mir_c99_cli_helloworld.sh` 通过；
  `bash tests/verify_mir_c99_cli_distinct_outputs.sh` 失败在 `src/main.uya` 的
  `MIR-C99 PortableMIR lowering 尚未覆盖当前程序`；
  `./bin/uya build --mir-c99 tests/extern_function.uya -o <tmp>.c` 失败于
  `MIR-C99 unit output 写出失败`；`bash tests/verify_portable_mir_language_coverage.sh`
  通过；`UYA_FULL_LANGUAGE_PARITY_NATIVE=1 bash tests/verify_full_language_backend_parity.sh`
  通过但只算 native 证据。
  - 验收：新增或更新一个 fail-closed 基线门禁，显式区分 `--mir-c99`、hosted native、
    fixture generator 和 legacy C99；该门禁必须能复现上述当前失败，不允许静默成功。
  - 失败原因（2026-06-23）：已新增 `tests/verify_mir_c99_full_language_baseline_truth.sh` 并接入 Makefile optional/required MIR-C99 release gate；但本轮真实门禁运行被固定编译器路径缺失阻塞，无法复现目标中列出的 `src/main.uya` 和 `tests/extern_function.uya` 当前失败。
  - 阻塞命令：`bash tests/verify_mir_c99_full_language_baseline_truth.sh`
  - 关键错误：`error: missing fixed compiler path ../uya/bin/uya; this gate refuses PATH, UYA_BIN, --uya-bin, and local bin/uya fallback`
  - 已验证命令：
    - `bash tests/verify_mir_c99_release_gate_contract.sh`：通过，确认 Makefile 已接入 `verify_mir_c99_full_language_baseline_truth.sh`。
    - `bash -n tests/verify_mir_c99_full_language_baseline_truth.sh`：通过。
    - `bash tests/verify_mir_c99_full_language_baseline_truth.sh`：失败于固定编译器路径缺失。
  - 后续重开条件：提供可执行的 `../uya/bin/uya` 后，重跑 `bash tests/verify_mir_c99_full_language_baseline_truth.sh`；若输出 `baseline_mir_c99_src_main=fail_closed:portable_mir_lowering_missing`、`baseline_mir_c99_extern_function=fail_closed:unit_output_write_failed` 且最终 OK，再将该基线门禁任务从失败归档重开为完成。
### 2026-06-23 - Full Language Parity / Generic CoreBody Lowering

父级路径：`MIR-C99-FULL-SUPPORT-GENERIC-COREBODY-LOWERING`

  - [f] `MIR-C99-FULL-SUPPORT-GENERIC-COREBODY-FUNCTION-INVENTORY`: 从真实
    `../uya/bin/uya build --mir-c99 src/main.uya -o <tmp>/main.c` 失败日志和现有
    convergence audit 中生成按通用能力分类的 CoreBody/function 缺口清单，不再绑定具体
    helper frontier。
    - 最小验证：baseline truth gate 和 self-build convergence audit 仍 fail-closed/记录
      blocked categories；新增清单不引用 legacy C99 成功作为 MIR-C99 证据。
    - 完成条件：缺口清单按 CFG、place/memory、call ABI、runtime helper、
      emitter/output、link/absence 等能力分类，并指向后续叶子的真实验证 gate。
    - 失败原因（2026-06-23）：本轮硬约束要求所有 Uya 验证、构建、测试和运行都必须使用
      `../uya/bin/uya`，但该固定编译器路径当前不存在，无法采集真实 `src/main.uya --mir-c99`
      失败日志，也无法运行 baseline truth gate。
    - 阻塞命令：
      - `../uya/bin/uya build --mir-c99 src/main.uya -o "$tmp_dir/main.c"` -> exit 127，
        关键错误：`/bin/bash: line 2: ../uya/bin/uya: No such file or directory`。
      - `bash tests/verify_mir_c99_full_language_baseline_truth.sh` -> exit 1，
        关键错误：`error: missing fixed compiler path ../uya/bin/uya; this gate refuses PATH, UYA_BIN, --uya-bin, and local bin/uya fallback`。
    - 已运行但不足以完成：`bash tests/verify_mir_c99_self_build_convergence_audit.sh` -> pass，
      输出 `OK: MIR-C99 self-build convergence audit records real compiler candidate status and grouped blockers`。
    - 后续重开条件：恢复可执行的 `../uya/bin/uya` 后，重新运行真实
      `../uya/bin/uya build --mir-c99 src/main.uya -o <tmp>/main.c`、
      `bash tests/verify_mir_c99_full_language_baseline_truth.sh` 和
      `bash tests/verify_mir_c99_self_build_convergence_audit.sh`，再生成按 CFG、place/memory、
      call ABI、runtime helper、emitter/output、link/absence 分类的缺口清单。
