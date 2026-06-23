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

### 2026-06-23 归档清理

### 2026-06-23 - Full Language Parity / Expr Value Place

父级任务路径：`MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE`: 补齐表达式、value、place 和常量模型。

  - [f] `MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE-AGGREGATE-MEMBER-INIT`: 让 struct / array /
    tuple / union initializer、member/field、aggregate copy/move 进入真实 CLI 证据面。
    - 最小验证：真实 `--mir-c99` aggregate/member parity 脚本覆盖 struct/tuple/union/array
      基本初始化与读写。
    - 失败原因：当前固定验证入口 `../uya/bin/uya build --mir-c99` 仍未恢复到 aggregate/value
      所需的真实 MIR-C99 路由。上游 `[f]` 叶子
      `MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE-BASIC-PLACE-REAL-CLI` 仍显示 pointer/array/slice
      probe 会静默落回 legacy C99；本轮继续追加 struct/tuple/union/aggregate copy probe 后，
      `array` / `tuple` 依旧返回 0 但日志打印 `后端类型: C99`、输出文件带
      `C99 代码由 Uya Mini 编译器生成`，`struct` copy case 先在 checker 触发
      `变量 'p1' 已被移动，不能再次使用`，`union` known-tag direct access case 先报
      `联合体只能通过 match 访问变体，或调用方法`。在真实 CLI basic-place 仍未站稳前继续把
      generator-only、legacy C99 或 checker 前置失败包装成 aggregate/member real-CLI
      证据不诚实。
    - 阻塞命令：`bash tests/verify_mir_c99_full_language_basic_place_real_cli.sh`
    - 关键错误：`error: pointer did not enter the real --mir-c99 route`；新增 aggregate probe
      的核心结果为：`array` / `tuple` 成功返回但仍是 legacy C99 banner，`struct`
      报 `变量 'p1' 已被移动，不能再次使用`，`union` 报
      `联合体只能通过 match 访问变体，或调用方法`。
    - 已验证命令：
      - `bash tests/verify_mir_c99_cli_helloworld.sh`：通过，确认固定路径 `../uya/bin/uya`
        仍能对 HelloWorld 输出真实 MIR-C99 unit writer。
      - `bash tests/verify_mir_c99_full_language_basic_place_real_cli.sh`：失败，`pointer`
        case 未进入真实 MIR-C99 路由，日志打印 `后端类型: C99`。
      - `../uya/bin/uya build --mir-c99 <tmp>/array_case.uya -o <tmp>/array_case.c`：
        返回 0，但输出首行仍是 `// C99 代码由 Uya Mini 编译器生成`。
      - `../uya/bin/uya build --mir-c99 <tmp>/tuple_case.uya -o <tmp>/tuple_case.c`：
        返回 0，但输出首行仍是 `// C99 代码由 Uya Mini 编译器生成`。
      - `../uya/bin/uya build --mir-c99 <tmp>/struct_case.uya -o <tmp>/struct_case.c`：
        失败，关键错误 `变量 'p1' 已被移动，不能再次使用`。
      - `../uya/bin/uya build --mir-c99 <tmp>/union_case.uya -o <tmp>/union_case.c`：
        失败，关键错误 `联合体只能通过 match 访问变体，或调用方法`。
    - 后续重开条件：先恢复 `../uya/bin/uya build --mir-c99 <pointer|array|slice>.uya -o <out.c>`
      到真实 MIR-C99 路由，要求构建日志包含 `[MIR-C99]`、输出 C 包含
      `generated by MIR-C99 unit output writer` 且拒绝 `C99 代码由 Uya Mini 编译器生成`；
      随后再新增 focused real-CLI aggregate/member gate，覆盖 struct/tuple/union/array
      initializer、member/field 和 aggregate copy/move，并决定是支持 union known-tag
      direct access / struct copy 使用方式，还是先把相应 checker/frontier blocker 单独拆叶。

来源：`docs/todo_mir_c99_backend.md`

标题上下文：`### 4.15 Full Language Parity`

父级任务路径：`MIR-C99-FULL-SUPPORT-STATEMENT-CFG`

  - [f] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-CORE-STRUCTURED`: 补齐
    `LOCAL_DECL`、`ASSIGN`、`EXPR`、`RETURN`、`IF`、`WHILE` 与 block 的通用
    CoreStmt 到 PortableMIR/MIR-C99 lowering。
    - 最小验证：return/local/assign/expr/branch/loop focused shard 走真实 `--mir-c99`
      生成、编译、运行。
    - 完成条件：覆盖矩阵相关 statement kind 至少为 MIR-C99 `partial`，且无 legacy fallback 证据。
    - 归档说明：主 todo 当前仅保留遗留 `[f]` 状态与任务描述，未附失败原因、阻塞命令、
      关键错误或后续重开条件；本轮按归档清理规则原样迁移，待后续执行轮补充真实失败证据。

### 2026-06-23 - Full Language Parity / Statement CFG

父级任务路径：`MIR-C99-FULL-SUPPORT-STATEMENT-CFG`

  - [f] `MIR-C99-FULL-SUPPORT-STATEMENT-CFG-CLEANUP-ERROR`: 补齐 `DEFER`、
    `ERRDEFER`、`DROP` 与 `ERROR_PROPAGATION` 的 cleanup/error CFG lowering。
    - 最小验证：cleanup/error statement focused shard 走真实 `--mir-c99` 生成、编译、运行。
    - 完成条件：defer/errdefer/drop/error propagation 的成功和错误路径均与 C99 oracle 对齐。
    - 失败原因：本轮已把 `tests/verify_mir_c99_cleanup_error_statement_parity.sh` 切到真实 current-source candidate 路径：先用 `../uya/bin/uya build --mir-c99 src/cmd/build/main.uya -o <tmp>/cmd_build_candidate.c` 生成 MIR-C99 `cmd/build` candidate，再让 candidate 对 cleanup/error case 执行 `build --mir-c99`。但第一步仍失败于 `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`，说明当前源码的 real CLI candidate 尚未到达能执行此 focused shard 的 frontier；继续在本叶子内补 case-specific 校验或回退到 generator 证据都不诚实。
    - 阻塞命令：`bash tests/verify_mir_c99_cleanup_error_statement_parity.sh`
    - 关键错误：`error: MIR-C99 cleanup/error real CLI candidate build failed before case parity`；候选构建日志核心错误：`../uya/bin/uya build --mir-c99 src/cmd/build/main.uya -o <tmp>/cmd_build_candidate.c` -> `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`。
    - 已验证命令：
      - `bash tests/verify_mir_c99_cleanup_error_statement_parity.sh`：失败，且输出上述 current-source candidate blocker。
      - `../uya/bin/uya build --mir-c99 src/cmd/build/main.uya -o <tmp>/cmd_build_candidate.c`：失败，关键错误同上。
    - 后续重开条件：先让真实 `../uya/bin/uya build --mir-c99 src/cmd/build/main.uya -o <tmp>/cmd_build_candidate.c` 能生成 `generated by MIR-C99 unit output writer` 的 candidate C，并经 host C compiler 编译运行成可执行 `cmd/build` candidate；随后重跑 `bash tests/verify_mir_c99_cleanup_error_statement_parity.sh`，要求 candidate 能对 success/error probe 生成 MIR-C99 `.c`、host C 编译运行并与 `../uya/bin/uya build --no-split-c` oracle 对齐。

### 2026-06-23 - Full Language Parity / Expr Value Place

父级任务路径：`MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE`: 补齐表达式、value、place 和常量模型。

  - [f] `MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE-BASIC-PLACE-REAL-CLI`: 让基础 address /
    deref / field / index / slice ptr-len-index 走真实 `--mir-c99` CLI，而不是
    generator-only shard。
    - 最小验证：真实 `../uya/bin/uya build --mir-c99` + host C compiler parity/reject 脚本，
      至少覆盖 pointer、array、slice 三类 fixture。
    - 失败原因：本轮已将 `tests/verify_mir_c99_full_language_basic_place_real_cli.sh`
      改为只使用固定路径 `../uya/bin/uya` 的真实 real-CLI gate；但 `pointer`、`array`、
      `slice` 三个 probe 在 `--mir-c99` 下都返回 0 且产出 `.c`，日志却仍显示
      `后端类型: C99`，没有 `[MIR-C99]`，生成文件也带 `C99 代码由 Uya Mini 编译器生成`
      的 legacy banner。当前阻塞不是 parity 细节，而是固定验证入口仍静默走 legacy C99，
      继续把 generator-only 或 legacy C99 结果包装成 full-language real-CLI 证据不诚实。
    - 阻塞命令：`bash tests/verify_mir_c99_full_language_basic_place_real_cli.sh`
    - 关键错误：`error: pointer did not enter the real --mir-c99 route`；对应日志核心输出：
      `后端类型: C99`、`代码生成完成: .../pointer.mir.c`。补充探针结果：
      `array status=0 mir_tag=no legacy_banner=yes`、`slice status=0 mir_tag=no legacy_banner=yes`。
    - 已验证命令：
      - `bash -n tests/verify_mir_c99_full_language_basic_place_real_cli.sh`：通过。
      - `bash tests/verify_mir_c99_full_language_basic_place_real_cli.sh`：失败，`pointer`
        case 未进入真实 MIR-C99 路由，日志打印 `后端类型: C99`。
      - `../uya/bin/uya build --mir-c99 <tmp>/array.uya -o <tmp>/array.c --project-root <tmp>`：
        返回 0，但 `mir_tag=no legacy_banner=yes`。
      - `../uya/bin/uya build --mir-c99 <tmp>/slice.uya -o <tmp>/slice.c --project-root <tmp>`：
        返回 0，但 `mir_tag=no legacy_banner=yes`。
    - 后续重开条件：先恢复 `../uya/bin/uya build --mir-c99 <pointer|array|slice>.uya -o <out.c>`
      到真实 MIR-C99 路由，要求构建日志包含 `[MIR-C99]`、输出 C 包含
      `generated by MIR-C99 unit output writer` 且拒绝 `C99 代码由 Uya Mini 编译器生成`；
      随后重跑 `bash tests/verify_mir_c99_full_language_basic_place_real_cli.sh`，再决定是否把
      field/member 扩展证据并入后续 aggregate 叶子。

### 4.15 Full Language Parity

- 父级任务路径：`MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE` 补齐表达式、value、place 和常量模型。
  - [f] `MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE-FLOAT-CONSTANT-MODEL`: 收敛 float/double、
    char、string、null 和非零 float payload 的常量模型，避免 generator-only value smoke。
    - 最小验证：真实 `--mir-c99` const/value parity 或明确 reject 脚本覆盖 f32/f64、char、
      string、null、`i32.max`/`i32.min` 等样例。
- 归档说明：主 todo 遗留的是孤立 `[f]` 叶子；原条目未附失败原因、阻塞命令、关键错误和重开条件。

### 4.15 Full Language Parity

- [ ] `MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE`: 补齐表达式、value、place 和常量模型。
  - 覆盖范围：整数/布尔/浮点/字符串/char/int-limit/null 常量，非零 f32/f64 payload，
    一元/二元/逻辑/转换，call result，member/field，array/slice index，slice ptr/len，
    address-of/deref/pointer offset，struct/array/tuple/union initializer，aggregate
    copy/move，match payload，error-union value 和 `@error_id` / `@error_name`。
  - 验收：覆盖矩阵中仍为 MIR-C99 `missing` 的普通值/表达式项转成 `partial`/`done`
    或明确 `reject`；对应 `tests/verify_mir_c99_full_language_*_parity.sh` 走真实
    `--mir-c99` CLI 或明确注明 generator-only 时不得标 full-language done。
  - [f] `MIR-C99-FULL-SUPPORT-EXPR-VALUE-PLACE-MATCH-ERROR-METADATA`: 收敛 match payload、
    error-union value、`@error_id` / `@error_name` 的真实 CLI lowering 或稳定 reject。
    - 最小验证：真实 `--mir-c99` case 覆盖 match/error-union/error metadata；若暂不能支持，
      则输出稳定 capability diagnostic 并在 coverage matrix 登记 `reject`。
    - 失败原因：本轮严格要求所有 Uya 验证走 `../uya/bin/uya`。直接对 `tests/fixtures/mir_c99_cmd_build_full_language_union.uya`、`tests/fixtures/mir_c99_cmd_build_full_language_error_catch_success.uya`、`tests/fixtures/mir_c99_cmd_build_full_language_error_id_binding_success.uya` 运行 `../uya/bin/uya build --mir-c99 ...` 时，固定 sibling 编译器仍静默输出 legacy C99，不产生 `[MIR-C99]`/unit-output 证据；尝试先用同一 fixed compiler 构建 current-source CLI（`src/main.uya`）再跑真实 `--mir-c99`，又被 fixed compiler 自身的 split-C `clock()` 原型冲突阻塞，当前仓库内无法完成真实 CLI parity/reject 收敛。
    - 阻塞命令：`UYA_ROOT=/home/winger/uya/uya-1.0/lib/ ../uya/bin/uya build src/main.uya -o <tmp>/uya-current-source --project-root .`
    - 关键错误：`home/winger/uya/uya-1.0/lib/std/platform.c:17:17: error: conflicting types for 'clock'; have 'uint64_t(void)'`；`./uya_part1_types.h:179:16: note: previous declaration of 'clock' with type 'int64_t(void)'`。
    - 额外证据：`../uya/bin/uya build --mir-c99 tests/fixtures/mir_c99_cmd_build_full_language_union.uya -o <tmp>/union.c --project-root .` 返回 0，但输出头为 `// C99 代码由 Uya Mini 编译器生成`，不是 MIR-C99 unit output。
    - 重开条件：先在 `../uya/bin/uya` 所在 sibling 仓库修复 current repo split-C build 的 `clock()` 原型冲突，并让真实 `--mir-c99` 对上述 fixture 不再静默回落 legacy C99；之后再把现有 generator-only shard 改成真实 CLI parity/reject。
### 4.15 Full Language Parity

- [f] `MIR-C99-FULL-SUPPORT-CALL-ABI-RUNTIME`: 补齐真实调用 ABI 和 runtime/capability
  handoff。
  - [ ] `MIR-C99-CALL-ABI-RUNTIME-EXTERN-SYMBOL-AND-UNIT-OUTPUT`: 补齐 extern symbol/prototype
    metadata 与 unit output call/prototype 写出，让 `tests/extern_function.uya` 不再失败于
    unit output write。
    - 覆盖范围：extern function C symbol/prototype metadata、extern call expression emission、
      `tests/extern_function.uya` 的 real `--mir-c99` unit output。
    - 验收：`../uya/bin/uya build --mir-c99 tests/extern_function.uya -o <tmp>/extern_function.c`
      进入真实 `[MIR-C99]` 路由；host C99 compiler 可编译并与 C99 oracle 对齐。
  - [ ] `MIR-C99-CALL-ABI-RUNTIME-FULL-CALL-SURFACE`: 在 extern 路径打通后补齐 direct call、
    method/monomorphized call、interface vtable dispatch、generic interface dispatch、
    function pointer call、aggregate return/out-param、error-union return、float/double ABI、
    global initializer、extern globals、`@c_import` object/library/search path、stdout/stderr、
    env/file/heap/string helper、`@print` / `@println`、source-location builtins、`@params`。
    - 验收：对应 shard 与 real `--mir-c99` CLI parity/diagnostic gate 全部转绿，父任务验收
      仍以 extern/c-import host C99 parity 为最终收口口径。

归档说明：本轮归档清理仅移动失败 handoff，未开始子任务已在主 todo 中保留为独立 `[ ]` 任务。

### 4.15 Full Language Parity

任务路径：`MIR-C99-CALL-ABI-RUNTIME-EXTERN-SYMBOL-AND-UNIT-OUTPUT`

- [f] `MIR-C99-CALL-ABI-RUNTIME-EXTERN-SYMBOL-AND-UNIT-OUTPUT`: 补齐 extern symbol/prototype
  metadata 与 unit output call/prototype 写出，让 `tests/extern_function.uya` 不再失败于
  unit output write。
  - 覆盖范围：extern function C symbol/prototype metadata、extern call expression emission、
    `tests/extern_function.uya` 的 real `--mir-c99` unit output。
  - 验收：`../uya/bin/uya build --mir-c99 tests/extern_function.uya -o <tmp>/extern_function.c`
    进入真实 `[MIR-C99]` 路由；host C99 compiler 可编译并与 C99 oracle 对齐。
  - 失败原因（2026-06-24）：当前 fixed `../uya/bin/uya` 直跑
    `tests/extern_function.uya --mir-c99` 仍落到 legacy C99；继续按当前仓库 bootstrap
    设计改走 `../uya/bin/uya -> src/cmd/build_bootstrap/main.uya -> src/cmd/build/main.uya`
    的 current-source build CLI 链路后，bootstrap 生成的 `cmd/build` 仍在 host C 编译阶段失败，
    未能产出可继续验证 extern MIR-C99 真路由的 current-source build CLI。
  - 阻塞命令：
    `UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build_bootstrap/main.uya -o /tmp/build-bootstrap --project-root "$PWD/src/" --no-split-c`
    通过；
    `UYA_ROOT="$PWD" /tmp/build-bootstrap build src/cmd/build/main.uya -o /tmp/cmd-build --project-root "$PWD/src/" --no-split-c`
    失败。
  - 关键错误：bootstrap 生成的 `/tmp/uya_output_*.c` 在 host C 编译阶段出现
    `O_RDONLY` / `S_IRWXU` 与成批 `SYS_*` / `EPOLL_*` / socket syscall 名未声明；同一生成 C
    中同时存在 `const int64_t libc_O_RDONLY = 0;`、`const int64_t libc_SYS_writev = 20;`
    等前缀常量，说明当前真实 blocker 是 legacy C99 bootstrap 对 current-source build-only
    driver 的未限定常量名输出。
  - 已验证现状：`bash tests/verify_mir_c99_cmd_build_self_preflight.sh` 在切换
    `src/cmd/build/main.uya -> build_compiler_driver` 时可通过 source/generator preflight，
    但真实 mandated bootstrap 仍无法把 current-source `cmd/build` 编译成可执行 build CLI，
    因而 `tests/extern_function.uya` 的 real current-source `--mir-c99` 路径无法继续复现。
  - 重开条件：先完成主 todo 新增前置叶子
    `MIR-C99-CALL-ABI-RUNTIME-CURRENT-SOURCE-CMD-BUILD-BOOTSTRAP`，让 mandated compiler
    + bootstrap 链稳定产出 current-source `cmd/build`，再重试本 extern leaf。

### 4.15 Full Language Parity

- [f] `MIR-C99-CALL-ABI-RUNTIME-EXTERN-SYMBOL-AND-UNIT-OUTPUT`: 补齐 extern symbol/prototype
  metadata 与 unit output call/prototype 写出，让 `tests/extern_function.uya` 不再失败于
  unit output write。
  - 覆盖范围：extern function C symbol/prototype metadata、extern call expression emission、
    `tests/extern_function.uya` 的 real `--mir-c99` unit output。
  - 验收：`../uya/bin/uya build --mir-c99 tests/extern_function.uya -o <tmp>/extern_function.c`
    进入真实 `[MIR-C99]` 路由；host C99 compiler 可编译并与 C99 oracle 对齐。
  - 本轮进展（2026-06-24）：`src/build_compiler_driver.uya` 继续保留并消费 extern i32 signature metadata，新增 `native_build_mir_c99_bind_extern_symbol_names` 将 AST `fn_decl_name` 绑定到 MIR-C99 CFG plan；`src/codegen/mir_c99/cfg.uya` 新增 `extern_symbol_name` 字段与 `mir_c99_cfg_bind_extern_symbol_name`；`src/codegen/mir_c99/unit_output.uya` 新增 extern prototype 写出、extern call 写出，以及 `MIR_INST_OP_I32_EQ` 的最小 unit output 支持。
  - 已验证（2026-06-24）：`bash tests/verify_mir_c99_extern_unit_output_contract.sh` 通过；`bash tests/verify_mir_c99_extern_i32_signature_metadata.sh` 通过；`bash tests/verify_mir_c99_independent_boundary.sh` 通过；`git diff --check` 通过。
  - 阻塞命令（2026-06-24）：`UYA_ROOT="$REPO_ROOT/lib/" ../uya/bin/uya build --mir-c99 tests/extern_function.uya -o "$tmp_dir/extern_function.c" --no-split-c`
  - 失败原因（2026-06-24）：按本轮硬约束执行真实验收命令时，fixed compiler 仍返回 0 但日志明确显示 `后端类型: C99`，既没有 `[MIR-C99]`，输出文件也仍以 `// C99 代码由 Uya Mini 编译器生成` 开头，而不是 `generated by MIR-C99 unit output writer`；因此当前仓库内虽已补上源码侧 extern symbol/prototype/call 写出合同，仍无法把 `../uya/bin/uya --mir-c99 tests/extern_function.uya` 证明为真实 MIR-C99 路由。
  - 关键证据（2026-06-24）：同一命令产物 stderr/stdout 显示 `后端类型: C99`、`代码生成完成: .../extern_function.c`，生成文件头为 legacy C99 banner；额外尝试用 fixed compiler 直接构建 `build_compiler_driver_main()` current-source probe root 也失败于 `错误: 收集模块依赖失败: src/build_compiler_driver_entry.uya`，因此本轮没有可靠的 current-source real-CLI 替代验收链。
  - 后续重开条件：先恢复 fixed `../uya/bin/uya build --mir-c99 ...` 到真实 `[MIR-C99]` 路由，或提供可被 fixed compiler 构建的稳定 current-source build-only root；随后重跑上述验收命令，要求构建日志包含 `[MIR-C99]`、输出 C 包含 `generated by MIR-C99 unit output writer` 且拒绝 `C99 代码由 Uya Mini 编译器生成`，再继续对 host C compiler / C99 oracle 做真实对齐验证。

### 4.15 Full Language Parity

父级路径：`MIR-C99-CALL-ABI-RUNTIME-FULL-CALL-SURFACE`

- [f] `MIR-C99-CALL-ABI-RUNTIME-REAL-EXTERN-CLI-ROUTE`: 先恢复 fixed
  `../uya/bin/uya build --mir-c99 tests/extern_function.uya` 的真实 `[MIR-C99]`
  路由，拒绝 legacy C99 假成功。
  - 最小验证：`UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/extern_function.uya -o <tmp>/extern_function.c --no-split-c`
  - 完成条件：stdout/stderr 或 build log 含 `[MIR-C99]`，输出 C 含
    `generated by MIR-C99 unit output writer`，且拒绝 `后端类型: C99` /
    `C99 代码由 Uya Mini 编译器生成`。
  - 已验证（2026-06-24）：`bash tests/verify_mir_c99_extern_unit_output_contract.sh`
    通过；`bash tests/verify_mir_c99_extern_i32_signature_metadata.sh` 通过。
  - 阻塞命令（2026-06-24）：`UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/extern_function.uya -o "$tmp_dir/extern_function.c" --no-split-c`
  - 失败原因（2026-06-24）：fixed compiler 仍把 `tests/extern_function.uya --mir-c99`
    静默落到 legacy C99；当前仓库内已补齐的 extern unit-output/source contract
    不能改变 sibling fixed compiler 的实际路由，因此在本轮硬约束下无法继续推进后续
    real-CLI call surface 子任务。
  - 关键证据（2026-06-24）：命令退出码为 `0`，但 stdout/stderr 显示 `后端类型: C99`、
    `代码生成完成: .../extern_function.c`，输出文件头为 `// C99 代码由 Uya Mini 编译器生成`，
    没有 `[MIR-C99]` 或 `generated by MIR-C99 unit output writer`。
  - 后续重开条件：先恢复 fixed
    `../uya/bin/uya build --mir-c99 tests/extern_function.uya ...` 到真实 `[MIR-C99]`
    路由；随后用同一固定路径重跑 focused extern case，并在 route 真实后再继续
    推进后续 real-CLI call surface 子任务。

- [f] `MIR-C99-CALL-ABI-RUNTIME-REAL-CLI-CALL-ABI-SHARDS`: 补齐 direct call、
  method/monomorphized call、function pointer call、aggregate return/out-param、
  error-union return、float/double ABI。
  - 最小验证：新增并运行 `bash tests/verify_mir_c99_call_surface_real_cli.sh`，要求
    fixed `../uya/bin/uya` 对 focused call ABI case 走真实 `[MIR-C99]`，host C99
    compiler 编译运行，并与 `--c99` oracle 对齐。
  - 完成条件：focused call ABI case 全部转绿，且日志/产物拒绝 legacy C99 fallback。
  - 阻塞命令（2026-06-24）：`UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/extern_function.uya -o /tmp/uya_mir_c99_extern_probe.c --no-split-c`
  - 失败原因（2026-06-24）：该叶子依赖父级前置条件“fixed
    `../uya/bin/uya build --mir-c99 tests/extern_function.uya` 能进入真实 `[MIR-C99]`
    路由”后才能继续；但本轮按硬约束重跑后，fixed compiler 仍静默落到 legacy C99，
    因此 focused call ABI shards 既无法进入真实 real-CLI TDD，也不能对 host C
    compiler 与 `--c99` oracle 做可信对齐验证。
  - 关键证据（2026-06-24）：阻塞命令 exit 0，但 stdout/stderr 明确显示
    `后端类型: C99`、`代码生成完成: /tmp/uya_mir_c99_extern_probe.c`；生成文件头为
    `// C99 代码由 Uya Mini 编译器生成`，没有 `[MIR-C99]` 或
    `generated by MIR-C99 unit output writer`。
  - 已验证命令（2026-06-24）：
    - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/extern_function.uya -o /tmp/uya_mir_c99_extern_probe.c --no-split-c`：失败，静默回落到 legacy C99。
    - `sed -n '1,5p' /tmp/uya_mir_c99_extern_probe.c`：输出 legacy C99 文件头 `// C99 代码由 Uya Mini 编译器生成`。
  - 后续重开条件：先恢复 failed archive 中
    `MIR-C99-CALL-ABI-RUNTIME-REAL-EXTERN-CLI-ROUTE` 的 fixed real-CLI 前置条件；
    随后再新增并运行 `bash tests/verify_mir_c99_call_surface_real_cli.sh`，要求构建日志含
    `[MIR-C99]`、产物含 `generated by MIR-C99 unit output writer`，并与 `--c99`
    oracle 对齐。
## 2026-06-24

路径上下文：
- `MIR-C99 Backend TODO`
- `4.15 Full Language Parity`
- `MIR-C99-CALL-ABI-RUNTIME-FULL-CALL-SURFACE`

- [f] `MIR-C99-CALL-ABI-RUNTIME-REAL-CLI-INTERFACE-DISPATCH-SHARDS`: 补齐 interface
  vtable dispatch、generic interface dispatch。
  - 最小验证：新增并运行
    `bash tests/verify_mir_c99_interface_call_surface_real_cli.sh`，要求 fixed
    `../uya/bin/uya` 对基础/泛型 interface case 走真实 `[MIR-C99]`，host C99
    compiler 编译运行，并与 `--c99` oracle 对齐。
  - 失败原因：fixed `../uya/bin/uya` 的 real `--mir-c99` 前置未恢复；新增 gate
    首个 `interface_dispatch` case 即停在 `后端类型: C99`，日志没有 `[MIR-C99]`。
  - 阻塞命令：`../uya/bin/uya build --mir-c99 tests/extern_function.uya`
    - 结果：走普通 `C99` 路由，并在链接阶段报
      `undefined reference to 'add'`。
  - 验证命令：`bash tests/verify_mir_c99_interface_call_surface_real_cli.sh`
    - 结果：`error: interface_dispatch did not enter the real --mir-c99 route`，
      日志显示 `后端类型: C99`。
  - 交叉校验：`bash tests/verify_mir_c99_full_language_basic_place_real_cli.sh`
    - 结果：仓库内现有 real-CLI gate 也同样停在 `后端类型: C99`，证明不是本轮新脚本的假阴性。
  - 本轮产物：新增 `tests/verify_mir_c99_interface_call_surface_real_cli.sh`，用于基础/泛型 interface dispatch 的 real-CLI parity gate。
  - 后续重开条件：先修复 fixed `../uya/bin/uya build --mir-c99 ...` 真实进入
    `[MIR-C99]` 且拒绝 legacy C99 fallback，再重跑本 gate。

## 2026-06-24

路径上下文：
- `MIR-C99 Backend TODO`
- `4.15 Full Language Parity`
- `MIR-C99-CALL-ABI-RUNTIME-FULL-CALL-SURFACE`

- [f] `MIR-C99-CALL-ABI-RUNTIME-REAL-CLI-GLOBAL-IMPORT-LINK-SHARDS`: 补齐 global
  initializer、extern globals、`@c_import` object/library/search path。
  - 最小验证：新增并运行 `bash tests/verify_mir_c99_global_import_link_real_cli.sh`，
    要求 fixed `../uya/bin/uya` 对 globals/import focused case 走真实 `[MIR-C99]`，
    host C99 compiler 编译运行，并与 `--c99` oracle 对齐。
  - 失败原因：本轮已新增 real-CLI gate
    `tests/verify_mir_c99_global_import_link_real_cli.sh`，并按父级前置先用 fixed
    `../uya/bin/uya build --mir-c99 tests/extern_function.uya` 做 preflight；但该命令当前返回 0
    后仍静默回落到 `后端类型: C99`，输出文件头也是
    `// C99 代码由 Uya Mini 编译器生成`。交叉校验中，
    `bash tests/verify_mir_c99_full_language_baseline_truth.sh` 现在更早就失败在
    `examples/HelloWorld.uya`，同样缺少 `[MIR-C99]` 并打印 `后端类型: C99`。在 fixed
    compiler 连 HelloWorld / extern_function 基线都不能进入真实 real-CLI 的前提下，
    当前叶子无法对 global initializer、extern globals、`@c_import`
    object/library/search path 做诚实的 focused parity 收口。
  - 阻塞命令：`bash tests/verify_mir_c99_global_import_link_real_cli.sh`
    - 结果：`error: fixed compiler preflight did not enter the real --mir-c99 route for tests/extern_function.uya`；
      日志显示 `后端类型: C99`，没有 `[MIR-C99]`。
  - 交叉校验：`bash tests/verify_mir_c99_full_language_baseline_truth.sh`
    - 结果：`error: missing full-language MIR-C99 baseline evidence: HelloWorld build entered the --mir-c99 route`；
      `examples/HelloWorld.uya` 日志同样显示 `后端类型: C99`。
  - 已验证命令：
    - `bash -n tests/verify_mir_c99_global_import_link_real_cli.sh`：通过。
    - `bash tests/verify_mir_c99_global_import_link_real_cli.sh`：失败，停在
      `tests/extern_function.uya` preflight 的 legacy C99 回落。
    - `../uya/bin/uya build --mir-c99 tests/extern_function.uya -o /tmp/uya_mir_extern_baseline.c`：
      返回 0，但日志打印 `后端类型: C99`。
    - `bash tests/verify_mir_c99_full_language_baseline_truth.sh`：失败，HelloWorld 基线也未进入真实
      `[MIR-C99]` 路由。
  - 本轮产物：新增 `tests/verify_mir_c99_global_import_link_real_cli.sh`，覆盖
    `tests/extern_function.uya` preflight、global initializer、extern global，以及
    `@c_import` object/library/search path 的 real-CLI parity gate；脚本已通过 `bash -n`
    语法检查。
  - 后续重开条件：先恢复 fixed `../uya/bin/uya build --mir-c99 tests/extern_function.uya`
    与 `../uya/bin/uya build --mir-c99 examples/HelloWorld.uya` 都真实进入 `[MIR-C99]`，
    要求日志含 `[MIR-C99]`、产物含 `generated by MIR-C99 unit output writer` 且拒绝
    legacy C99 banner；随后重跑
    `bash tests/verify_mir_c99_global_import_link_real_cli.sh`，要求 focused
    globals/import/link case 全部转绿并与 `--c99` oracle 对齐。

## 4. 任务清单
### 4.15 Full Language Parity

调用 ABI / runtime/capability 的失败 handoff 已归档；后续待办继续保留为独立叶子任务：

- [f] `MIR-C99-CALL-ABI-RUNTIME-FULL-CALL-SURFACE`: 在 fixed `../uya/bin/uya` 的 real
  `--mir-c99` 路由恢复后，按 focused real-CLI shard 收口 direct/method/function
  pointer、interface dispatch、globals/imports 和 runtime helper 调用面。
  - 前置说明：`MIR-C99-CALL-ABI-RUNTIME-REAL-EXTERN-CLI-ROUTE` 已转入 failed archive；
    其余子任务必须在 fixed `../uya/bin/uya build --mir-c99 tests/extern_function.uya`
    能进入真实 `[MIR-C99]` 路由后再继续。
  - [f] `MIR-C99-CALL-ABI-RUNTIME-REAL-CLI-RUNTIME-HELPER-PRINT-PARAMS-SHARDS`: 补齐
    stdout/stderr、env/file/heap/string helper、`@print` / `@println`、
    source-location builtins、`@params`。
    - 最小验证：新增并运行
      `bash tests/verify_mir_c99_runtime_helper_call_surface_real_cli.sh`，要求 fixed
      `../uya/bin/uya` 对 runtime helper / print / params focused case 走真实
      `[MIR-C99]`，host C99 compiler 编译运行，并与 `--c99` oracle 对齐。
    - 完成条件：focused runtime helper / print / params case 全部转绿，且日志/产物
      拒绝 legacy C99 fallback。
    - 失败原因：fixed `../uya/bin/uya` 的 real `--mir-c99` 路由前置条件未恢复；本轮新增
      `tests/verify_mir_c99_runtime_helper_call_surface_real_cli.sh` 后，gate 在 preflight
      `tests/extern_function.uya` 即 fail-closed，无法进入 focused runtime helper cases。
    - 阻塞命令：`../uya/bin/uya build --mir-c99 tests/extern_function.uya -o /tmp/uya-extern-preflight.c`
    - 关键错误：日志显示 `后端类型: C99` 且缺少真实 `[MIR-C99]`；产物头部为
      `// C99 代码由 Uya Mini 编译器生成`，说明仍在 legacy C99 route。
    - 额外证据：精确前置命令 `../uya/bin/uya build --mir-c99 tests/extern_function.uya`
      同样打印 `后端类型: C99`，随后在 legacy C99 链接阶段报
      `undefined reference to 'add'`。
    - 重开条件：fixed `../uya/bin/uya build --mir-c99 tests/extern_function.uya`
      日志出现真实 `[MIR-C99]`，且 `-o` 产物拒绝 legacy C99 banner 后，再重跑
      `bash tests/verify_mir_c99_runtime_helper_call_surface_real_cli.sh`。
  - 父任务验收：对应 shard 与 real `--mir-c99` CLI parity/diagnostic gate 全部转绿，
    仍以 extern/c-import host C99 parity 为最终收口口径。

### 4.15 Full Language Parity

父任务路径：
- `MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI`: 将 async 相关 completed-archive/generator parity 提升为真实 `--mir-c99` CLI 语言面证据。
  - 覆盖范围：`@async_fn`、`@await`、async error union、frame allocation/free、async frame pool、heap fallback、scheduler/channel/fd/io/multi-fd/async_compute、defer/errdefer/resource cleanup。
  - 验收：当前 `tests/test_async_*.uya` 对应 MIR-C99 gate 不只引用 subset generator；真实 `--mir-c99` 输出经 host C99 compiler 编译运行，并与现有 C99 oracle 对齐。

- [f] `MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI-BASELINE-ROUTE`: 确认按本轮硬约束必须使用的固定 `../uya/bin/uya build --mir-c99` 已进入真实 MIR-C99 CLI 路由，再继续 async real-CLI shard 切换。
  - 验证：`tmp_dir=$(mktemp -d /tmp/uya-mir-c99-hello-probe.XXXXXX); cd /media/winger/_dde_home/winger/uya/uya-1.0; UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 examples/HelloWorld.uya -o "$tmp_dir/hello.c" --no-split-c --project-root "$PWD"`
    - 结果：`$tmp_dir/hello.c` 头部仍为 `// C99 代码由 Uya Mini 编译器生成`，构建日志显示 `后端类型: C99`，未见 `[MIR-C99]` 或 `generated by MIR-C99 unit output writer`。
  - 验证：在临时目录写入与 `tests/verify_mir_c99_async_runtime_basic_parity.sh` 中
    `async_fn_basic` 等价的源码后，执行
    `cd /media/winger/_dde_home/winger/uya/uya-1.0; UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 "$case_file" -o "$tmp_dir/async_fn_basic.c" --no-split-c --project-root "$tmp_dir"`
    - 结果：基础 `@async_fn`/`block_on` case 同样生成 legacy C99 banner，说明 blocker 早于 async shard 自身。
  - 验证：在临时目录写入与 `tests/verify_mir_c99_async_runtime_basic_parity.sh` 中
    `async_direct_await_err_union` 等价的源码后，执行
    `cd /media/winger/_dde_home/winger/uya/uya-1.0; UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 "$case_file" -o "$tmp_dir/async_direct_await_err_union.c" --no-split-c --project-root "$tmp_dir"`
    - 结果：direct `@await` + async error union case 仍生成 legacy C99 banner。
  - 失败原因：本轮强约束要求所有 Uya 验证都必须使用 `../uya/bin/uya`；该固定编译器当前 `--mir-c99` 仍走 legacy C99 输出，无法为 async basic/control-flow/frame/scheduler/cleanup shard 提供真实 CLI 证据。
  - 重开条件：固定 `../uya/bin/uya build --mir-c99` 至少对 `examples/HelloWorld.uya` 和基础 async case 输出 `[MIR-C99]` 与 `generated by MIR-C99 unit output writer`，再继续后续 async real-CLI parity 子任务。
### 4.15 Full Language Parity

父级任务路径：
`MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI`: 将 async 相关 completed-archive/generator parity 提升为真实 `--mir-c99` CLI 语言面证据。

- [f] `MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI-BASIC-RUNTIME`: 将 ready/block_on、
  `@async_fn` direct return、direct `@await`、async error union return 从 generator
  parity 切到固定 `../uya/bin/uya build --mir-c99` 真路由。
  - 最小验证：`bash tests/verify_mir_c99_full_language_async_basic_parity.sh`
  - 完成条件：脚本必须验证 `[MIR-C99]` 与
    `generated by MIR-C99 unit output writer`，并经 host C99 compiler 编译运行后与
    C99 oracle 对齐。
  - 验证：`bash tests/verify_mir_c99_full_language_async_basic_parity.sh`
    - 结果：退出码 1。当前脚本仍通过 `tests/verify_mir_c99_async_runtime_basic_parity.sh`
      走 generator parity，host C 编译 `oracle.c` 时报多处 `error: invalid initializer`，
      并在 `_uya_async_frame_descriptors` 初始化处报
      `struct AsyncFrameDescriptorTable` 无 `count` 成员。
  - 验证：在临时目录写入 `async_fn_basic` focused case 后执行
    `../uya/bin/uya build --mir-c99 "$tmp_dir/async_fn_basic.uya" -o "$tmp_dir/async_fn_basic.c" --no-split-c --project-root "$tmp_dir"`
    - 结果：退出码 0，但 build log 明确显示 `后端类型: C99`，输出 C 头部仍为
      `// C99 代码由 Uya Mini 编译器生成`，未出现 `[MIR-C99]` 或
      `generated by MIR-C99 unit output writer`。
  - 验证：在临时目录写入 direct `@await` + async error union focused case 后执行
    `../uya/bin/uya build --mir-c99 "$tmp_dir/async_direct_await_err_union.uya" -o "$tmp_dir/async_direct_await_err_union.c" --no-split-c --project-root "$tmp_dir"`
    - 结果：退出码 0，但 build log 仍是 `后端类型: C99`，输出 C 仍是 legacy C99
      banner。
  - 失败原因（2026-06-24）：本轮硬约束要求所有 Uya 验证都使用固定
    `../uya/bin/uya`。当前该 fixed compiler 对本叶子覆盖的 `block_on` /
    `@async_fn` direct return / direct `@await` / async error union focused case
    仍未进入真实 MIR-C99 CLI 路由；同时现有 generator-based basic parity gate 也未形成
    可 passing 的 host C 基线，因此无法在本仓库内把该 shard 诚实标记为完成。
  - 后续重开条件：先恢复 fixed `../uya/bin/uya build --mir-c99` 对
    `async_fn_basic` 与 `async_direct_await_err_union` focused case 输出真实
    `[MIR-C99]`，并让产物包含 `generated by MIR-C99 unit output writer` 且拒绝
    legacy C99 banner；随后将
    `bash tests/verify_mir_c99_full_language_async_basic_parity.sh` 切到 real-CLI
    host-C parity 并跑通，再重开本叶子任务。
### 4.15 Full Language Parity

父级任务路径：
`MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI`: 将 async 相关 completed-archive/generator parity 提升为真实 `--mir-c99` CLI 语言面证据。

- [f] `MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI-CONTROL-FLOW`: 将 if/else-if、while、for、
  nested block、multiple await、compound try-await parity 切到固定
  `../uya/bin/uya build --mir-c99` 真路由。
  - 最小验证：`bash tests/verify_mir_c99_full_language_async_control_flow_parity.sh`
  - 验证：`bash tests/verify_mir_c99_full_language_async_control_flow_parity.sh`
    - 结果：退出码 1。当前脚本仍通过 `bash "$REPO_ROOT/tests/verify_mir_c99_async_control_flow_parity.sh"` 走 generator parity，`tests/mir_c99_generate.sh` 命中 `mir_c99_async_control_flow_case` 后只输出 `/* generated by MIR-C99 async control-flow subset writer */`；同时 host C 编译 `oracle.c` 失败于多处 `error: invalid initializer`，并在 `_uya_async_frame_descriptors` 初始化附近报 `struct AsyncFrameDescriptorTable` 无 `count` 成员。
  - 验证：在临时目录写入与 control-flow focused case 等价源码后执行 `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 "$case_file" -o "$out_c" --no-split-c --project-root "$tmp_dir"`
    - 结果：退出码 0，但 build log 明确显示 `后端类型: C99`，输出 C 头部仍为 `// C99 代码由 Uya Mini 编译器生成`，未出现 `[MIR-C99]` 或 `generated by MIR-C99 unit output writer`。
  - 失败原因（2026-06-24）：本轮硬约束要求所有 Uya 验证都使用固定 `../uya/bin/uya`。当前该 fixed compiler 对 if/else-if、while、for、nested block、multiple await、compound try-await focused case 仍未进入真实 MIR-C99 CLI 路由；同时现有 full-language control-flow gate 仍停留在 `tests/mir_c99_generate.sh` 手写 subset writer，且 generator parity 自身又因 `oracle.c` 既有编译错误未形成可 passing 的 host C 基线，因此无法在本仓库内把该 shard 诚实标记为完成。
  - 后续重开条件：先恢复 fixed `../uya/bin/uya build --mir-c99` 对 focused control-flow async case 输出 `[MIR-C99]` 与 `generated by MIR-C99 unit output writer` 并拒绝 legacy C99 banner；随后将 `bash tests/verify_mir_c99_full_language_async_control_flow_parity.sh` 改为真实 real-CLI gate，要求 host C 编译运行 MIR-C99 输出并与 `../uya/bin/uya build --c99` oracle 对齐后再重开。

### 4.15 Full Language Parity

父级任务路径：
`MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI`: 将 async 相关 completed-archive/generator parity 提升为真实 `--mir-c99` CLI 语言面证据。

- [f] `MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI-FRAME-POOL-FALLBACK`: 将 frame
  allocation/free、async frame pool 与 `--async-frame-heap=on` fallback parity
  切到固定 `../uya/bin/uya build --mir-c99` 真路由。
  - 最小验证：`bash tests/verify_mir_c99_full_language_async_frame_pool_parity.sh`
  - 验证：`bash tests/verify_mir_c99_full_language_async_frame_pool_parity.sh`
    - 结果：退出码 1。当前脚本仍通过 `tests/verify_mir_c99_async_frame_pool_parity.sh` /
      `tests/verify_mir_c99_async_frame_pool_fallback_parity.sh` 走
      `tests/mir_c99_generate.sh` fake generator parity，host C compiler 在 `oracle.c`
      上报 `error: invalid initializer`，尚未切到固定 `../uya/bin/uya build --mir-c99`
      真路由。
  - 验证：`tmp_dir=$(mktemp -d /tmp/uya-mir-c99-probe.XXXXXX); cd /media/winger/_dde_home/winger/uya/uya-1.0; UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 examples/HelloWorld.uya -o "$tmp_dir/hello.c" --no-split-c --project-root "$PWD"`
    - 结果：退出码 0，但 `"$tmp_dir/hello.c"` 头部仍为 `// C99 代码由 Uya Mini 编译器生成`，
      build log 明确显示 `后端类型: C99`，未出现 `[MIR-C99]` 或
      `generated by MIR-C99 unit output writer`。
  - 失败原因（2026-06-24）：本轮硬约束要求 frame/pool shard 必须切到固定
    `../uya/bin/uya build --mir-c99` 真路由。当前该 fixed compiler 对 HelloWorld 仍走
    legacy C99 输出；同时现有 frame/pool gate 还停留在 `tests/mir_c99_generate.sh`
    fake generator parity，无法为 frame allocation/free、async frame pool 和
    `--async-frame-heap=on` fallback 提供真实 CLI 证据，因此不能在本仓库内诚实标记完成。
  - 后续重开条件：先恢复 fixed `../uya/bin/uya build --mir-c99` 对
    `examples/HelloWorld.uya` 输出 `[MIR-C99]` 与
    `generated by MIR-C99 unit output writer` 并拒绝 legacy C99 banner；随后将
    `bash tests/verify_mir_c99_full_language_async_frame_pool_parity.sh` 改成真实 real-CLI
    host-C parity gate 并跑通，再重开本叶子任务。
## 2026-06-24 归档清理

上下文：
- `# MIR-C99 Backend TODO`
- `## 4. 任务清单`
- `### 4.15 Full Language Parity`
- 父级任务：`MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI`

- [f] `MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI-SCHEDULER-IO-COMPUTE`: 将
  scheduler/channel/fd/io/multi-fd/async_compute parity 切到固定
  `../uya/bin/uya build --mir-c99` 真路由。
  - 最小验证：`bash tests/verify_mir_c99_full_language_async_scheduler_compute_parity.sh`
  - 失败原因：父级 blocker 未解除，固定 `../uya/bin/uya build --mir-c99` real-CLI baseline 尚未成立；本轮按归档清理规则不重试实现，沿用主 todo 已记录失败结论。
  - 阻塞命令：`bash tests/verify_mir_c99_full_language_async_scheduler_compute_parity.sh`
  - 关键错误：当前 async scheduler/channel/fd/io/multi-fd/async_compute parity 仍无法切到固定 `../uya/bin/uya build --mir-c99` 真路由。
  - 重开条件：先完成并验证 `MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI-BASELINE-ROUTE`，确认固定 `../uya/bin/uya build --mir-c99` 已进入真实 MIR-C99 CLI 路由后，再重新执行该 parity 切换。

### 4.15 Full Language Parity

- [f] `MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI`: 将 async 相关 completed-archive/generator
  parity 提升为真实 `--mir-c99` CLI 语言面证据。
  - 覆盖范围：`@async_fn`、`@await`、async error union、frame allocation/free、
    async frame pool、heap fallback、scheduler/channel/fd/io/multi-fd/async_compute、
    defer/errdefer/resource cleanup。
  - 验收：当前 `tests/test_async_*.uya` 对应 MIR-C99 gate 不只引用 subset generator；
    真实 `--mir-c99` 输出经 host C99 compiler 编译运行，并与现有 C99 oracle 对齐。
  - 当前 blocker：固定 `../uya/bin/uya build --mir-c99` real-CLI baseline 尚未成立；此前失败证据已归档为
    `MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI-BASELINE-ROUTE`，本轮 cleanup/resource focused real-CLI gate 复核后仍未解除。
  - 失败原因（2026-06-24）：basic/control-flow/frame-pool/scheduler 与本轮 cleanup/resource
    shard 都要求固定 `../uya/bin/uya build --mir-c99` 进入真实 MIR-C99 CLI 路由；当前该
    fixed compiler 对 focused async cleanup/resource case 仍显示 `后端类型: C99`，未出现
    `[MIR-C99]` 或 `generated by MIR-C99 unit output writer`，因此父级子任务现阶段全部处于同一
    baseline blocker 下，主 todo 不再保留空父项。
  - 后续重开条件：先完成并验证 `MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI-BASELINE-ROUTE`，
    至少让固定 `../uya/bin/uya build --mir-c99` 对 `examples/HelloWorld.uya` 与 async cleanup/resource
    focused case 输出 `[MIR-C99]` 和 `generated by MIR-C99 unit output writer`，再逐个重开 async real-CLI shards。
  - [f] `MIR-C99-FULL-SUPPORT-ASYNC-REAL-CLI-CLEANUP-RESOURCE`: 将 defer/errdefer、
    cleanup edge、resource release parity 切到固定 `../uya/bin/uya build --mir-c99`
    真路由，并覆盖 `tests/test_async_*.uya` manifest。
    - 最小验证：`bash tests/verify_mir_c99_full_language_async_cleanup_resource_parity.sh`
    - 验证：`bash tests/verify_mir_c99_async_cleanup_resource_parity.sh`
      - 结果：退出码 1。focused `async_cleanup_resource` case 已切到固定
        `../uya/bin/uya build --mir-c99` 真路由探针，但 build log 仍显示 `后端类型: C99`，
        未出现 `[MIR-C99]`；输出仍落到 legacy C99 路由。
    - 验证：`bash tests/verify_mir_c99_async_cleanup_release_plan.sh`
      - 结果：退出码 0。当前 PortableMIR cleanup/release plan 相关 source evidence 仍在。
    - 验证：`bash tests/verify_mir_c99_async_make_check_manifest.sh`
      - 结果：退出码 0。manifest 仍覆盖 57 个 `tests/test_async_*.uya` 文件。
    - 验证：`bash tests/verify_mir_c99_full_language_async_cleanup_resource_parity.sh`
      - 结果：退出码 1。脚本在第一个 focused case 即报
        `async_cleanup_resource did not enter the real --mir-c99 route`，并打印 fixed compiler
        仍为 `后端类型: C99` 的 build log。
    - 失败原因（2026-06-24）：本轮已把 cleanup/resource focused parity gate 改成固定
      `../uya/bin/uya build --mir-c99` real-CLI harness，并保留 cleanup/release plan 与
      `tests/test_async_*.uya` manifest 收口检查；但 fixed compiler 仍未进入真实 MIR-C99 CLI
      路由，无法产出 `[MIR-C99]` 或 `generated by MIR-C99 unit output writer`，因此该叶子不能诚实标记完成。
    - 后续重开条件：先恢复 fixed `../uya/bin/uya build --mir-c99` 对 focused
      `async_cleanup_resource` / `async_frame_release_resource` cases 输出真实 `[MIR-C99]`
      与 `generated by MIR-C99 unit output writer` 并拒绝 legacy C99 banner；随后重新执行
      `bash tests/verify_mir_c99_full_language_async_cleanup_resource_parity.sh`。

### 2026-06-24

路径：`# MIR-C99 Backend TODO > 4.15 Full Language Parity`

- [f] `MIR-C99-FULL-SUPPORT-TEST-HARNESS-AND-NO-MAIN`: 修复 test 文件、无 main 文件和
  helper-only 文件的 MIR-C99 入口策略，消除 no-main false positive。
  - 覆盖范围：`test "..."` blocks、`std.testing` helper、test main wrapper、无 main
    library/module、extern-only 或 declaration-heavy module。
  - 验收：`tests/test_array_bounds.uya`、`tests/test_block_comment.uya` 等 test shard
    不再靠伪 `int main(void) { return uya_mir_fn_N(); }` 成功；无 main 输入要么生成正确
    test harness，要么给出稳定 diagnostic。
  - 失败原因（2026-06-24）：新增 focused gate
    `bash tests/verify_mir_c99_test_harness_and_no_main_real_cli.sh`，它先用固定
    `../uya/bin/uya` 构建 current-source `cmd/build` candidate，再对 HelloWorld、
    test-only、helper-only、extern-only 和 declaration-only case 做 real-CLI 检查。
    当前 candidate 在第一步就暴露前置 blocker：`examples/HelloWorld.uya` 仍走 legacy
    C99，构建日志缺少 `[MIR-C99]`，输出头还是 `// C99 代码由 Uya Mini 编译器生成`，
    因此本轮无法诚实进入 test/no-main false-positive 验收。为确认不是 gate 本身问题，
    曾临时把 `src/cmd/build/main.uya` 切回 `build_compiler_driver_main()` 重试；但
    current-source candidate 随即在 host C 编译阶段失败，核心错误是 bare
    `O_RDONLY` / `O_RDWR` / `S_IRWXU`、`SYS_*` / `EPOLL_*` 常量未命名空间化，以及
    `MIR_INST_OP_I32_EQ` 未定义。为避免提交未验证的生产代码，源码尝试已回退，只保留
    诊断 gate。
  - 阻塞命令：`bash tests/verify_mir_c99_test_harness_and_no_main_real_cli.sh`
  - 关键错误：`error: HelloWorld real CLI log is missing [MIR-C99] evidence`
  - 额外证据：临时 wrapper 切换后，
    `UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build_bootstrap/main.uya -o <tmp>/build-bootstrap --project-root "$PWD/src/" --no-split-c && UYA_ROOT="$PWD" <tmp>/build-bootstrap build src/cmd/build/main.uya -o <tmp>/cmd-build --project-root "$PWD/src/" --no-split-c`
    失败；host C 编译核心错误包括 `O_RDONLY undeclared`、`SYS_writev undeclared`、
    `MIR_INST_OP_I32_EQ undeclared`。
  - 后续重开条件：先恢复 current-source `cmd/build` candidate 的真实 MIR-C99 build
    path，要求 `bash tests/verify_mir_c99_test_harness_and_no_main_real_cli.sh` 至少让
    HelloWorld case 出现 `[MIR-C99]` 和 `generated by MIR-C99 unit output writer`，并且
    `src/cmd/build/main.uya` 能在 fixed compiler / bootstrapped candidate 链上稳定构建；
    随后再继续 test-only 和 no-main 的 fail-closed / harness 收口。

路径：`# MIR-C99 Backend TODO > 4.15 Full Language Parity`

- [f] `MIR-C99-FULL-SUPPORT-CLI-SUITE-HELLOWORLD-REAL-ROUTE`: 让 HelloWorld CLI 真实进入
  MIR-C99 route，并经 host C 编译运行。
  - 验收：`bash tests/verify_mir_c99_cli_helloworld.sh` 通过。
  - 失败原因（2026-06-24）：固定路径 `../uya/bin/uya build --mir-c99` 当前仍打印 legacy
    C99 形态日志并输出 legacy C99 banner；先后尝试用当前源码重建 local `bin/cmd/build`、
    同步 `../uya/bin/cmd/build`，以及用 `tests/mir_c99_generate.sh` 产出的
    `cmd/build` real compiler candidate 刷新固定路径，HelloWorld case 仍未出现
    `[MIR-C99]` 或 `generated by MIR-C99 unit output writer`。进一步临时把
    `src/cmd/build/main.uya` 切回 `build_compiler_driver_main()` 重试，会让
    `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya` 暴露更深前置 blocker：
    host C 编译阶段出现 `O_RDONLY` / `O_RDWR` / `S_IRWXU`、大量 `SYS_*` 常量未声明，
    同时 `src/codegen/mir_c99/unit_output.uya` 引用了当前 `src/lower/mir.uya` 尚未定义的
    `MIR_INST_OP_I32_EQ`。另外，`tests/mir_c99_generate.sh` 产出的 `cmd/build`
    candidate 只支持 `--help` 和 minimal build smoke，直接执行
    `build --mir-c99 examples/HelloWorld.uya` 会报
    `error: cannot read MIR-C99 build smoke input: --mir-c99`，不能替代真实 CLI。
  - 阻塞命令：
    - `bash tests/verify_mir_c99_cli_helloworld.sh`
    - `bash tests/verify_mir_c99_full_language_baseline_truth.sh`
    - `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya`
    - `UYA_ROOT="$PWD" /tmp/uya-fixed-cmd-build-install.QVEdM8/build build --mir-c99 "$PWD/examples/HelloWorld.uya" -o /tmp/uya-fixed-cmd-build-install.QVEdM8/hello.c --project-root "$PWD" --no-split-c`
  - 关键错误：
    - `error: HelloWorld CLI did not enter the real --mir-c99 route`
    - `error: missing full-language MIR-C99 baseline evidence: HelloWorld build entered the --mir-c99 route`
    - host C compile errors: `O_RDONLY undeclared`、`SYS_writev undeclared`、`MIR_INST_OP_I32_EQ undeclared`
    - candidate error: `error: cannot read MIR-C99 build smoke input: --mir-c99`
    - candidate contract: `error: MIR-C99 unit output candidate currently supports --help and minimal build smoke only`
  - 后续重开条件：先恢复 `cmd/build` current-source build entry 的可链接状态，至少解决
    `libc` 常量命名空间与 `MIR_INST_OP_I32_EQ` contract 缺口，并让 fixed
    `../uya/bin/uya build --mir-c99 examples/HelloWorld.uya -o <tmp>.c` 的日志出现
    `[MIR-C99]`、输出含 `generated by MIR-C99 unit output writer`；随后再重开本叶子。

### 4.15 Full Language Parity

父级路径：`MIR-C99-FULL-SUPPORT-CLI-SUITE`：让真实 `--mir-c99` CLI 在主语言测试集上收敛。

- [f] `MIR-C99-FULL-SUPPORT-CLI-SUITE-BUILD-ENTRY-RECOVERY`: 先恢复 fixed/current-source
  `cmd/build` 的 `--mir-c99` 真实入口，消除 `build_compiler_driver_main()` 路径的 host C
  compile blockers（`O_RDONLY` / `SYS_*` 常量命名空间、`MIR_INST_OP_I32_EQ` contract 缺口），
  再回到 HelloWorld / distinct-output 验收。
  - 失败原因（2026-06-24）：当前硬约束要求所有 Uya build/test/run 都必须走固定
    `../uya/bin/uya`；但该路径只是 launcher，真正执行 `build` 的是 repo 外的
    sibling `../uya/bin/cmd/build` 二进制。实测它当前只有 21KB，仍是 minimal
    MIR-C99 candidate，默认会在 `build` 子命令上先失败为
    `error: MIR-C99 unit output candidate currently supports --help and minimal build smoke only`。
    为了确认不是 gate 误报，本轮临时将当前仓库现成的 full `bin/cmd/build`（3.1MB）
    覆盖到 sibling `../uya/bin/cmd/build` 后重试，`make -B cmd-build
    UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya` 终于推进到本叶描述的更深 blocker：
    host C 编译阶段稳定报裸 `O_RDONLY` / `SYS_*` 常量与
    `MIR_INST_OP_I32_EQ` 缺口。问题在于这些修复只能落在当前源码里，但在当前硬约束下，
    无法使用 current-source `bin/uya` / `bin/cmd/build` 重新生成并同步 fixed
    compiler binary，所以当前源码补丁无法真正喂回 `../uya/bin/uya` 路径完成验收。
  - 本轮进展（2026-06-24）：
    - 将 [src/cmd/build/main.uya](/media/winger/_dde_home/winger/uya/uya-1.0/src/cmd/build/main.uya)
      切到 `build_compiler_driver_main()`，去掉旧的 `compiler_driver_build_main()` wrapper。
    - 收紧 [tests/verify_cmd_build_entry.sh](/media/winger/_dde_home/winger/uya/uya-1.0/tests/verify_cmd_build_entry.sh)
      到本轮真实约束：固定 `../uya/bin/uya` 构建，且入口必须导入
      `build_compiler_driver`。
    - 收紧 [tests/verify_mandated_build_compiler_driver_entry.sh](/media/winger/_dde_home/winger/uya/uya-1.0/tests/verify_mandated_build_compiler_driver_entry.sh)
      ，新增 `MIR_INST_OP_I32_EQ` host-C compile reject 断言。
    - 在 [src/codegen/c99_build/global.uya](/media/winger/_dde_home/winger/uya/uya-1.0/src/codegen/c99_build/global.uya)
      增加导入常量/语义索引回退解析，在
      [src/lower/mir.uya](/media/winger/_dde_home/winger/uya/uya-1.0/src/lower/mir.uya)
      补入 `MIR_INST_OP_I32_EQ` 常量与整数比较分类；但这些改动在当前硬约束下无法进入
      fixed compiler binary，只能作为下一轮重开时的源码准备。
    - 为避免留下 repo 外状态，本轮对 sibling `../uya/bin/cmd/build` 的临时覆盖已恢复回
      `/tmp/uya-fixed-cmd-build.backup.1782245438` 的原始 21KB minimal candidate。
  - 阻塞命令：
    - `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya`
    - `bash tests/verify_mandated_build_compiler_driver_entry.sh`
    - `bash tests/verify_cmd_build_entry.sh`
    - `../uya/bin/uya build --mir-c99 examples/HelloWorld.uya -o /tmp/uya-loop-hello-restored.c`
  - 关键错误：
    - 默认 fixed path：`error: MIR-C99 unit output candidate currently supports --help and minimal build smoke only`
    - 临时同步 full `cmd/build` 后的 deeper blocker：`O_RDONLY undeclared`、
      `SYS_writev undeclared`、`MIR_INST_OP_I32_EQ undeclared`
    - 即便临时同步 full `cmd/build`，`../uya/bin/uya build --mir-c99 examples/HelloWorld.uya`
      仍输出 legacy banner `// C99 代码由 Uya Mini 编译器生成`，日志没有 `[MIR-C99]`
  - 后续重开条件：允许一次性使用 current-source `bin/uya` / `bin/cmd/build` 重建并同步
    fixed `../uya/bin/cmd/build`，或由外层约束明确放开这一步的编译器来源；随后重新执行
    `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya`、
    `bash tests/verify_mandated_build_compiler_driver_entry.sh`、
    `bash tests/verify_cmd_build_entry.sh`，并在同步后的 fixed path 上重新验证
    `../uya/bin/uya build --mir-c99 examples/HelloWorld.uya -o <tmp>.c` 是否出现 `[MIR-C99]`
    与 `generated by MIR-C99 unit output writer`。
### 4.15 Full Language Parity

父级路径：`MIR-C99-FULL-SUPPORT-CLI-SUITE`：让真实 `--mir-c99` CLI 在主语言测试集上收敛。

- [f] `MIR-C99-FULL-SUPPORT-CLI-SUITE-DISTINCT-OUTPUTS`: 让 `src/main.uya` 输出进入
  MIR-C99 route，且不是 legacy C99，也不是 HelloWorld-like 固定输出。
  - 失败原因（2026-06-24）：本叶实际同时依赖 fixed/current-source `cmd/build`
    build-entry 恢复、HelloWorld real-route 切换和 `src/main.uya` distinct-output 三个
    交付物，单叶粒度过大；在当前硬约束下，固定 `../uya/bin/uya` 默认仍先委托 sibling
    `../uya/bin/cmd/build` 的 minimal candidate，直接失败为
    `error: MIR-C99 unit output candidate currently supports --help and minimal build smoke only`。
    为排除 fixed path 漂移，本轮临时备份并同步当前仓库现成 full `bin/cmd/build`
    到 sibling fixed path 后复测，HelloWorld `--mir-c99` 仍未进入 real route，
    `src/cmd/build/main.uya` current-source candidate host C compile 继续稳定报裸
    `O_RDONLY` / `SYS_*` 常量；在不放开 current-source `bin/uya` / `bin/cmd/build`
    作为编译器来源的前提下，当前源码修复无法喂回 fixed compiler path 完成本叶验收。
  - 本轮处理（2026-06-24）：
    - 红灯：`bash tests/verify_mir_c99_cli_distinct_outputs.sh` 返回 `70`，HelloWorld /
      `src/main.uya` 均报
      `error: MIR-C99 unit output candidate currently supports --help and minimal build smoke only`。
    - 红灯：`bash tests/verify_mir_c99_test_harness_and_no_main_real_cli.sh` 失败为
      `error: failed to build bootstrap cmd/build helper`，同样卡 minimal candidate。
    - 临时同步 full `bin/cmd/build` 到 sibling fixed path 后：
      - `bash tests/verify_mir_c99_cli_distinct_outputs.sh` 失败为
        `error: HelloWorld CLI did not enter the real --mir-c99 route`；日志只出现
        `输出: ...` / `后端类型: C99`，缺少 `[MIR-C99]`。
      - `bash tests/verify_mir_c99_test_harness_and_no_main_real_cli.sh` 在 current-source
        `cmd/build` candidate host C compile 阶段稳定报
        `O_RDONLY undeclared`、`S_IRWXU undeclared`、`SYS_writev undeclared`、
        `SYS_getppid undeclared` 等。
  - 阻塞命令：
    - `bash tests/verify_mir_c99_cli_distinct_outputs.sh`
    - `bash tests/verify_mir_c99_test_harness_and_no_main_real_cli.sh`
    - `bash tests/verify_mandated_build_compiler_driver_entry.sh`
    - `bash tests/verify_cmd_build_entry.sh`
  - 关键错误：
    - 默认 fixed path：`error: MIR-C99 unit output candidate currently supports --help and minimal build smoke only`
    - 临时同步 full `cmd/build` 后：`error: HelloWorld CLI did not enter the real --mir-c99 route`
    - current-source candidate host C compile：`O_RDONLY undeclared`、
      `S_IRWXU undeclared`、`SYS_writev undeclared`、`SYS_getppid undeclared`
  - 后续重开条件：
    - 先让拆分后的 `MIR-C99-FULL-SUPPORT-CLI-SUITE-BUILD-ENTRY-RECOVERY` 收敛，并允许把
      修复后的 build CLI 真正同步回 fixed `../uya/bin/cmd/build` 路径；
    - 之后先让 `bash tests/verify_mir_c99_cli_helloworld.sh` 出现 `[MIR-C99]` +
      `generated by MIR-C99 unit output writer`，再回到
      `bash tests/verify_mir_c99_cli_distinct_outputs.sh`。
## 4.15 Full Language Parity

Parent: `MIR-C99-FULL-SUPPORT-CLI-SUITE`

- [f] `MIR-C99-FULL-SUPPORT-CLI-SUITE-SRC-MAIN-DISTINCT-OUTPUTS`: 让 `src/main.uya`
  输出进入 MIR-C99 route，且不是 legacy C99，也不是 HelloWorld-like 固定输出。
  - 验收：`bash tests/verify_mir_c99_cli_distinct_outputs.sh` 通过。
  - 失败原因：本轮真实 `fixed ../uya/bin/uya` 路径下，`examples/HelloWorld.uya --mir-c99`
    已显示 `[MIR-C99]` 和 `generated by MIR-C99 unit output writer`，但
    `src/main.uya` 仍停在 `错误: MIR-C99 extern lowering 失败`。为让 fixed path
    吃到 current-source `src/build_compiler_driver.uya`，本轮继续尝试 mandated 编译器刷新
    current-source `cmd/build`，但 `../uya/bin/uya` 直编、`build_bootstrap` 两段式和
    `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya` 都失败于既有 current-source
    C99/host compile 问题，无法生成 fresh `cmd/build` 并同步到 sibling
    `../uya/bin/cmd/build`。在 fixed path 无法刷新前，任何 `src/build_compiler_driver.uya`
    代码改动都无法用本轮硬约束要求的真实入口诚实验证，因此本轮不保留未验证生产代码改动。
  - 阻塞命令：
    - `bash tests/verify_mir_c99_cli_distinct_outputs.sh`：失败；`HelloWorld` 已通过真实
      `[MIR-C99]` 路由，`src/main.uya` 卡在 `错误: MIR-C99 extern lowering 失败`。
    - `UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build/main.uya -o /tmp/uya-refresh-cmd-build.Lqu3yn/cmd-build --no-split-c --project-root "$PWD/src/"`：失败；host C compile
      阶段报 `codegen_mir_c99_*` / `lower_mir_backend_*` / `std_runtime_saved_envp`
      等未声明错误，未生成 fresh `cmd/build`。
    - `UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build_bootstrap/main.uya -o /tmp/uya-bootstrap-refresh.yJLWhy/build-bootstrap --project-root "$PWD/src/" --no-split-c`：失败；host C compile
      阶段报 `std_runtime_saved_envp` / `typed_program_TYPED_PROGRAM_INVALID_ID` /
      `codegen_c99_plan_*` 等未声明错误，`build-bootstrap` 未生成。
    - `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya`：失败；生成
      `/tmp/uya_output_1056703.c` 后宿主 `cc` 报 `lower_core_*` / `lower_mir_*` /
      `codegen_mir_c99_*` 常量未声明，`bin/cmd/build.tmp` 未生成。
  - 关键错误：
    - `错误: MIR-C99 extern lowering 失败`
    - `std_runtime_saved_envp`、`typed_program_TYPED_PROGRAM_INVALID_ID`、
      `codegen_mir_c99_plan_MIR_C99_PLAN_LIFECYCLE_UNINITIALIZED`、
      `lower_mir_MIR_*`、`lower_core_*` 等在 mandated current-source build path
      下未声明，导致 fixed CLI 无法刷新。
  - 后续重开条件：先恢复至少一条 mandated fresh-path 成功产出 current-source
    `cmd/build` 并同步到 sibling `../uya/bin/cmd/build`：
    `../uya/bin/uya build src/cmd/build/main.uya ...`、
    `../uya/bin/uya build src/cmd/build_bootstrap/main.uya ... && <tmp>/build-bootstrap build src/cmd/build/main.uya ...`
    或 `make -B cmd-build UYA_CMD_BOOTSTRAP_COMPILER=../uya/bin/uya`。随后重跑
    `bash tests/verify_mir_c99_cli_distinct_outputs.sh`，再继续定位 `src/main.uya`
    的真实 MIR-C99 blocker。

## 4.15 Full Language Parity
父级路径：
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE`
- [ ] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE`

- [f] `MIR-C99-FULL-SUPPORT-CLI-SUITE-MAIN-LANGUAGE-PORTABLEMIR-FIRST-BUCKET`:
  让首个 generic `PortableMIR lowering 尚未覆盖当前程序` 用例收敛为具体
  capability diagnostic 或真实支持，不再停在通用报错。
  - 验收：
    - `UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_asm_const_output.uya -o /tmp/uya-mir-c99-main-language-portablemir.c`
      不再输出 `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`。
  - 失败原因（2026-06-24，本轮）：
    - 固定 `../uya/bin/uya` 当前无法重建 current-source `cmd/build`，所以无法让验收入口命中本轮需要修改的 build driver 行为。
    - 阻塞命令：`UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build/main.uya -o /tmp/uya-cmd-build-portablemir-first-bucket --no-split-c --project-root src/`
    - 关键错误：`lower_core_LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED undeclared`、`lower_mir_PORTABLE_MIR_LIFECYCLE_UNINITIALIZED undeclared`、`typed_program_TYPED_PROGRAM_INVALID_ID undeclared`。
    - 次级阻塞命令：`UYA_ROOT="$PWD" ../uya/bin/uya build src/cmd/build_bootstrap/main.uya -o /tmp/uya-build-bootstrap-portablemir-first-bucket --no-split-c --project-root src/`
    - 关键错误：`std_runtime_saved_envp undeclared`、`std_runtime_saved_argc/std_runtime_saved_argv undeclared`、`typed_program_TYPED_PROGRAM_INVALID_ID undeclared`。
    - 已验证现状：`UYA_ROOT="$PWD/lib/" ../uya/bin/uya build --mir-c99 tests/test_asm_const_output.uya -o /tmp/uya-mir-c99-main-language-portablemir.c` 仍输出 `mir_c99_capability_diagnostic: kind=AST_TEST_STMT reason=test_driver_not_lowered file=tests/test_asm_const_output.uya line=3`，随后落到通用 `错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序`。
    - 重开条件：先恢复固定 `../uya/bin/uya` 能成功重建 current-source `src/cmd/build/main.uya` 或 `src/cmd/build_bootstrap/main.uya` 并同步 sibling `../uya/bin/cmd/build`，再重新推进这个 bucket。
