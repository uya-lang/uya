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

### 2026-06-23 - Full Language Parity / Generic CoreBody Lowering

- [f] `MIR-C99-FULL-SUPPORT-GENERIC-COREBODY-LOWERING`: 将 full-language 主路径从
  `native_build_hosted_decl_can_materialize_*` / 固定函数名 / 固定 body shape 迁到通用
  `TypedProgram -> LoweredProgram/CoreBody -> PortableMIR` lowering。
  - 覆盖范围：所有 reachable concrete functions、monomorphized functions、methods、
    interface thunks、runtime helpers、extern declarations 和 test harness 入口。
  - 禁止：为了让单个 case 变绿继续新增 helper 名、statement count 或源码字符串识别的
    one-off materializer。
  - 验收：`./bin/uya build --mir-c99 src/main.uya -o <tmp>/main.c` 不再报
    `PortableMIR lowering 尚未覆盖当前程序`；生成文件包含
    `generated by MIR-C99 unit output writer`，不含 legacy C99 banner。
  - [f] `MIR-C99-FULL-SUPPORT-GENERIC-COREBODY-CLI-ENTRY`: 将真实 `--mir-c99`
    CLI 入口改为消费 frozen `LoweredProgram/CoreBody -> PortableMIR` 的通用 module
    lowering 结果，保留 unsupported capability fail-closed。
    - 最小验证：HelloWorld CLI 仍输出 MIR-C99 unit banner；`src/main.uya` 的失败原因
      前移到具体 capability/category diagnostic，而不是新增 one-off materializer 成功。
    - 完成条件：入口路径没有新增固定函数名/body shape materializer，且 no-new-one-off guard
      继续通过。
    - 失败原因：本轮硬约束要求所有 Uya 验证、构建、测试、运行都使用项目根目录相对路径 `../uya/bin/uya`，但该路径不存在；无法运行 HelloWorld CLI、`src/main.uya` fail-closed 诊断或 no-new-one-off guard 的完整验收。未修改生产代码。
    - 阻塞命令：`../uya/bin/uya --version`
    - 关键错误：`/bin/bash: line 1: ../uya/bin/uya: No such file or directory`；`ls ../uya/bin` -> `No such file or directory`。
    - 后续重开条件：在仓库根目录相对路径提供可执行 `../uya/bin/uya` 后，重开此任务，从真实 CLI 入口 TDD 和最小验证继续。

### 2026-06-23 - Full Language Parity / Statement CFG

父级任务路径：`MIR-C99-FULL-SUPPORT-STATEMENT-CFG`

  - [f] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-BASELINE`: 在固定编译器路径
    `../uya/bin/uya` 下建立真实 `--mir-c99` statement/CFG shard 基线，覆盖
    local decl、assign、if、while、loop backedge 和 return，不允许走 legacy fallback。
    - 最小验证：`test -x ../uya/bin/uya`；
      `PARALLEL_JOBS=8 CFLAGS='-std=c99 -O2 -fno-builtin -Werror' LDFLAGS='' ./tests/run_programs_parallel.sh --uya --mir-c99 --hide-pass tests/test_mir_c99_statement_cfg.uya`
    - 完成条件：固定路径编译器存在，statement/CFG shard 由真实 `--mir-c99`
      生成 `.c`，经 host C99 compiler 编译运行通过，并能从日志确认未走 legacy fallback。
    - 失败原因：本轮硬约束要求所有 Uya 验证、构建、测试、运行都使用项目根目录相对路径
      `../uya/bin/uya`，但该路径当前不存在；不能用本仓库 `bin/uya`、PATH 上的
      `uya` 或环境变量覆盖替代，因此无法进入 statement/CFG shard 的真实 `--mir-c99`
      TDD 验证。
    - 阻塞命令：`../uya/bin/uya --version`
    - 关键错误：`/bin/bash: line 1: ../uya/bin/uya: No such file or directory`
    - 已运行检查：`python3 ./.agents/skills/goal-task-runner/scripts/check_todo.py docs/todo_mir_c99_backend.md`
      在拆分后通过；`test -x ../uya/bin/uya` 返回 1。
    - 后续重开条件：在当前仓库根目录相对路径提供可执行 `../uya/bin/uya` 后，重开此
      baseline 子任务，先新增/运行 statement/CFG shard 的 failing test，再实现真实
      `--mir-c99` CFG lowering。

### 4.15 Full Language Parity

父级任务路径：`MIR-C99-FULL-SUPPORT-STATEMENT-CFG`: 补齐 CoreStmt/AST statement 到 MIR 的通用 CFG lowering。

  - [f] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-AST-ENTRY`: 接通 AST 层
    `for` / `match` / `test` driver 入口到通用 statement CFG lowering。
    - 最小验证：新增或更新 for/match/test driver shard，并通过真实 `--mir-c99`
      host-C parity。
    - 完成条件：AST 入口映射不再绕过 PortableMIR statement CFG。
    - 失败原因：固定验证路径 `../uya/bin/uya` 尚未恢复到真实 MIR-C99 路由；在 `--mir-c99` 构建 `for` / `match` / `test` 探针时命令返回 0，但日志仍显示 `后端类型: C99`，未出现 `[MIR-C99]`，生成文件是 legacy C99 输出，无法作为真实 MIR-C99 host-C parity 证据。
    - 阻塞命令：`UYA_ROOT="$PWD" ../uya/bin/uya build --mir-c99 /tmp/uya-mir-c99-ast-entry-probe.YnA6yt/for_entry.uya -o /tmp/uya-mir-c99-ast-entry-probe.YnA6yt/for.c`；同目录 `match_entry.uya` 与 `test_entry.uya` 探针结果相同。
    - 关键结果：`for_status=0` / `match_status=0` / `test_status=0`，但三份日志均打印 `后端类型: C99` 和 `代码生成完成: .../*.c`，没有 MIR-C99 unit writer 标记。
    - 后续重开条件：先恢复 `../uya/bin/uya build --mir-c99 <case> -o <out.c>` 到真实 MIR-C99 路由，要求构建日志包含 `[MIR-C99]`、输出 C 包含 `generated by MIR-C99 unit output writer` 且拒绝 `C99 代码由 Uya Mini 编译器生成`；随后再新增 for/match/test driver shard 并跑 host C parity。
