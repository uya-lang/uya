# 标准脚本运行时 TODO 完成归档

## 2026-06-29

### Phase 1：运行时基础缺口

#### 1.4 shebang 预研

- [x] 确认 lexer 对首行 `#!` 的现状。
- [x] 设计“仅文件开头位置允许 shebang”的最小语义。

验证记录（归档清理轮）：
- 命令：`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md`
- 结果：`ok: docs/todo_std_script.md has 0 active tasks`
- 命令：`git diff --check -- docs/todo_std_script.md docs/todo_std_script_completed.md`
- 结果：无输出，退出码 0
- 命令：`sed -n '98,104p' docs/todo_std_script.md`
- 结果：`### 1.4 shebang 预研` 下仅保留 `- [ ] 明确 shebang 不阻塞第一批脚本迁移。`

## Phase 5：`uya script` 与 shebang

### 5.2 shebang

- [x] lexer 支持忽略首行 shebang。
- [x] 增加回归：
  - [x] 标准脚本后缀 `.ush` 可通过 `uya run` 运行
  - [x] 带 shebang 的 `.uya` 仍可被兼容解析，但不作为标准脚本后缀
  - [x] 仅文件开头允许 shebang
- [x] 明确 POSIX 当前建议写法：
  - [x] `#!/usr/bin/env -S uya run`
- 验证：
  - `UYA_COMPILER=../uya/bin/uya bash tests/verify_run_shebang_ush.sh`：通过，输出 `verify_run_shebang_ush: ok`

## Phase 0：盘点与基线

- [x] 查看工作树，确认没有未预期改动：`git status --short`。
  - 验证命令：`git status --short`
  - 验证结果：在回写 todo 状态前执行，输出为空，工作树干净，没有未预期改动。

## Phase 0：盘点与基线

- 父级任务：盘点仓库内现有 shell 脚本，按复杂度分三类：
  - [x] A 类：轻量 orchestration，适合第一批迁移
    - 判定口径：以编译器/测试命令编排、退出码断言、文件存在性检查和少量 `grep` 文本匹配为主；不依赖复杂循环、目录遍历或平台矩阵。
    - 当前归入 A 类的首批候选：
      - `tests/verify_check_cli.sh`
      - `tests/verify_exec_vm_compiler_regressions.sh`
      - `tests/verify_split_build_output.sh`
      - `tests/verify_project_root_embedded_uya_resolution.sh`
    - 验证：
      - `sed -n '540,568p' docs/std_script_design.md`：A 类特征与 4 个候选脚本已在设计文档中明确列出。
      - `git ls-files tests/verify_check_cli.sh tests/verify_exec_vm_compiler_regressions.sh tests/verify_split_build_output.sh tests/verify_project_root_embedded_uya_resolution.sh`：4 个候选脚本均为仓库已跟踪文件。
      - `python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md`：`ok: docs/todo_std_script.md has 1 active task`。
      - `git diff --check -- docs/todo_std_script.md`：通过。

## Phase 0：盘点与基线

路径：盘点仓库内现有 shell 脚本，按复杂度分三类

- [x] B 类：中等复杂度，含较多文件系统/文本处理
  - 盘点文档：`docs/std_script_shell_inventory.md`
  - 归类口径：以临时目录/文件生成和 `grep`/`diff`/`find`/`sed`/`sort`/`test -f/-s/-x` 等文本或文件系统断言为主；不承担平台矩阵、benchmark/stress 或完整构建编排。
  - 结果：`rg --files -g '*.sh'` 共发现 183 个脚本，本轮先归入 B 类 132 个，覆盖 `exec_vm`、`async`、`embed/c_import/split`、CLI/package-mode、UPM、microapp、C99/codegen 七组。
  - 验证：
    - `rg --files -g '*.sh' | wc -l` => `183`
    - `python3 - <<'PY' ...` 统计 `docs/std_script_shell_inventory.md` 中的 `tests/` 路径 => `132`
    - `python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md` => `ok: docs/todo_std_script.md has 0 active tasks`
    - `git diff --check` => `OK`

## Phase 0：盘点与基线

- [x] 盘点仓库内现有 shell 脚本，按复杂度分三类：
  - [x] C 类：强平台/强工具链耦合，后期迁移
    - 判定标准：脚本直接按宿主/目标 `OS`、`arch` 分支，或强依赖交叉编译器、对象工具、benchmark 基础设施与外部运行环境。
    - 当前归类：
      - 核心构建/调度：`src/compile.sh`、`tests/run_programs_parallel.sh`、`tests/run_cross_platform_tests.sh`
      - 交叉编译/平台探测：`tests/verify_syscall_c99_cross.sh`、`tests/verify_simd_c99_neon.sh`、`tests/verify_emcc_unknown_runtime.sh`
      - microapp 多平台矩阵：`tests/verify_microapp_profile_example_matrix.sh`、`tests/verify_microapp_aarch64_hosted_runtime.sh`、`tests/verify_microapp_macos_arm64_hosted_runtime.sh`、`tests/verify_microapp_aarch64_object_extract.sh`、`tests/verify_microapp_macos_object_extract.sh`、`tests/verify_microapp_macos_profile_guard.sh`
      - benchmark / stress 基础设施：`benchmarks/run_bench.sh`、`benchmarks/run_uyagin_route_bench.sh`、`tests/verify_http_bench_async_epoll_runtime.sh`、`tests/verify_uyagin_http_bench_runtime.sh`、`tests/stress_http_async_epoll.sh`、`tests/stress_epoll_server.sh`、`tests/stress_pthread.sh`、`tests/run_capability_runtime_benchmark.sh`、`tests/run_malloc_throughput_benchmark.sh`、`tests/run_malloc_phase4_compare.sh`
    - 归因摘记：
      - `src/compile.sh`、`tests/run_cross_platform_tests.sh`、`tests/run_programs_parallel.sh` 都显式处理 `uname` / `TARGET_OS` / `TARGET_ARCH`，并在 `cc` / `zig cc` / `make` / `ulimit` 等工具链分支间切换。
      - `tests/verify_syscall_c99_cross.sh`、`tests/verify_simd_c99_neon.sh`、`tests/verify_emcc_unknown_runtime.sh` 分别依赖 `zig cc`、`emcc`、`node` 等交叉或非通用工具链，迁移时需要先补足 `std.process` 与平台抽象。
      - microapp 与 benchmark 这两组脚本依赖特定 host 架构、`objcopy` / `clang` / `llvm-mc` / `wrk` / `nginx` / `curl` / `go` 等外部环境，不适合作为第一批 `std.script` 迁移对象。
    - 验证：
      - `python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md` -> `ok: docs/todo_std_script.md has 1 active task`
      - `python3` 路径存在性校验脚本 -> `ok: 22 script paths exist`
      - `git diff --check` -> `ok`

## 2026-06-29 Phase 0：盘点与基线

父级任务路径：`为第一批候选脚本记录 oracle：`

- [x] 退出码
  - 记录结果：四个第一批候选脚本当前成功路径均退出 `0`；脚本整体保持 `set -euo pipefail` 的 fail-fast 语义。
  - oracle：
    - `tests/verify_check_cli.sh`：成功退出 `0`
    - `tests/verify_exec_vm_compiler_regressions.sh`：成功退出 `0`
    - `tests/verify_split_build_output.sh`：成功退出 `0`
    - `tests/verify_project_root_embedded_uya_resolution.sh`：成功退出 `0`
  - 验证命令：
    - `bash tests/verify_check_cli.sh` -> exit `0`
    - `UYA_COMPILER=../uya/bin/uya bash tests/verify_exec_vm_compiler_regressions.sh` -> exit `0`
    - `UYA_COMPILER=../uya/bin/uya bash tests/verify_split_build_output.sh` -> exit `0`
    - `UYA_COMPILER=../uya/bin/uya bash tests/verify_project_root_embedded_uya_resolution.sh` -> exit `0`
  - 验证时间：`2026-06-29 17:10:08 +0800`

## Phase 0：盘点与基线

父级路径：`为第一批候选脚本记录 oracle`

- [x] 关键 stdout/stderr
  - 记录结果（2026-06-29，成功路径）：
    - `tests/verify_check_cli.sh`：stdout 仅 `check cli ok`；stderr 为空。
    - `tests/verify_exec_vm_compiler_regressions.sh`：stdout 为逐项 `验证...` / `... ✓` 进度序列，末行 `✓ exec vm compiler regression checks passed`；stderr 为空。
    - `tests/verify_split_build_output.sh`：stdout 仅 `split build output materialized ok`；stderr 为空。
    - `tests/verify_project_root_embedded_uya_resolution.sh`：stdout 仅 `embedded project-root stdlib resolution ok`；stderr 为空。
  - 验证说明：按本轮硬约束，使用脚本等价执行方式将编译器路径固定为 `../uya/bin/uya`，避免 `bin/uya-hosted` fallback。
  - 验证命令：
    - `sed 's|"$ROOT_DIR/bin/uya"|../uya/bin/uya|g' tests/verify_check_cli.sh | bash`
    - `sed -e 's|^SCRIPT_DIR=.*|SCRIPT_DIR="$(pwd)/tests"|' -e 's|^REPO_ROOT=.*|REPO_ROOT="$(pwd)"|' -e 's|^COMPILER=.*|COMPILER="../uya/bin/uya"|' tests/verify_exec_vm_compiler_regressions.sh | bash`
    - `sed -e 's|^REPO_ROOT=.*|REPO_ROOT="$(pwd)"|' -e '/if \[ -n "${UYA_COMPILER:-}" \]; then/,/^fi$/c\COMPILER="../uya/bin/uya"' tests/verify_split_build_output.sh | bash`
    - `sed -e 's|^REPO_ROOT=.*|REPO_ROOT="$(pwd)"|' -e '/if \[ -n "${UYA_COMPILER:-}" \]; then/,/^fi$/c\COMPILER="../uya/bin/uya"' tests/verify_project_root_embedded_uya_resolution.sh | bash`
  - 验证结果：
    - 上述四条命令均退出 0。
    - `tests/verify_check_cli.sh` stdout：`check cli ok`
    - `tests/verify_exec_vm_compiler_regressions.sh` stdout 末行：`✓ exec vm compiler regression checks passed`
    - `tests/verify_split_build_output.sh` stdout：`split build output materialized ok`
    - `tests/verify_project_root_embedded_uya_resolution.sh` stdout：`embedded project-root stdlib resolution ok`
    - 四条命令 stderr 均为空。

## Phase 0：盘点与基线

父级任务路径：`为第一批候选脚本记录 oracle：`

- [x] 关键产物文件
  - `tests/verify_check_cli.sh`：关键产物仅为 3 个临时日志文件 `OK_LOG`、`BAD_LOG`、`HELP_LOG`（分别承载成功 `check`、失败 `check`、`--help` 输出）；脚本退出时删除，无持久 `-o` 输出文件。
  - `tests/verify_exec_vm_compiler_regressions.sh`：关键产物仅为复用的临时捕获文件 `TMP_STDOUT`、`TMP_STDERR`；用于逐项断言 stdout/stderr，无显式 `-o` 输出文件，脚本退出时删除。
  - `tests/verify_split_build_output.sh`：关键产物为 `OUT_BIN="$(mktemp /tmp/uya-split-build-out.XXXXXX)"`，成功条件是 `test -x "$OUT_BIN"`；辅助日志为 `BUILD_LOG="$(mktemp /tmp/uya-split-build-out.XXXXXX.log)"`；两者退出时删除。
  - `tests/verify_project_root_embedded_uya_resolution.sh`：关键产物为 `OUT_C="$TMP_DIR/out.c"`，成功条件是 `test -s "$OUT_C"`；另有持久编译日志 `/tmp/verify_project_root_embedded_uya_resolution.log` 记录本次 `--c99` 构建输出。
  - 验证：
    - `rg -n 'OK_LOG|BAD_LOG|HELP_LOG|TMP_STDOUT|TMP_STDERR|OUT_BIN|BUILD_LOG|OUT_C|verify_project_root_embedded_uya_resolution\.log|test -x \$OUT_BIN|test -s \$OUT_C' tests/verify_check_cli.sh tests/verify_exec_vm_compiler_regressions.sh tests/verify_split_build_output.sh tests/verify_project_root_embedded_uya_resolution.sh`：确认关键文件变量、固定日志路径和成功断言与记录一致。
    - `bash tests/verify_check_cli.sh`：输出 `check cli ok`。
    - `UYA_COMPILER=../uya/bin/uya bash tests/verify_split_build_output.sh`：输出 `split build output materialized ok`。
    - `UYA_COMPILER=../uya/bin/uya bash tests/verify_project_root_embedded_uya_resolution.sh`：输出 `embedded project-root stdlib resolution ok`。
    - `UYA_COMPILER=../uya/bin/uya bash tests/verify_exec_vm_compiler_regressions.sh`：末行输出 `✓ exec vm compiler regression checks passed`。

## Phase 0：盘点与基线

- [x] 为第一批候选脚本记录 oracle：
  - `stdout/stderr` oracle（2026-06-29，成功路径）：
    - `tests/verify_check_cli.sh`：stdout 仅 `check cli ok`；stderr 为空。
    - `tests/verify_exec_vm_compiler_regressions.sh`：stdout 为逐项 `验证...` / `... ✓` 进度序列，末行 `✓ exec vm compiler regression checks passed`；stderr 为空。
    - `tests/verify_split_build_output.sh`：stdout 仅 `split build output materialized ok`；stderr 为空。
    - `tests/verify_project_root_embedded_uya_resolution.sh`：stdout 仅 `embedded project-root stdlib resolution ok`；stderr 为空。
  - [x] 关键临时目录副作用
    - `tests/verify_check_cli.sh`：创建 `/tmp/verify_check_cli_{ok,bad,help}.XXXXXX.log` 临时文件；`trap cleanup EXIT` 清理，`find /tmp -maxdepth 1 -type f -name 'verify_check_cli_*.log' | wc -l` 运行前后均为 `0`。
    - `tests/verify_exec_vm_compiler_regressions.sh`：仅通过 `mktemp` 创建 stdout/stderr 捕获文件；在专用 `TMPDIR=$(mktemp -d /tmp/std-script-exec-regression.XXXXXX)` 下运行后，临时目录残留项为 `0`。
    - `tests/verify_split_build_output.sh`：创建 `/tmp/uya-split-build-out.XXXXXX` 与 `/tmp/uya-split-build-out.XXXXXX.log`；`trap cleanup EXIT` 清理，`find /tmp -maxdepth 1 \( -type f -o -type l \) -name 'uya-split-build-out.*' | wc -l` 运行前后均为 `0`。
    - `tests/verify_project_root_embedded_uya_resolution.sh`：创建 `/tmp/uya-embedded-root.XXXXXX/`，内部含 `uya/lib -> <repo>/lib` 符号链接、`root_async_import.uya` 与 `out.c`；`trap cleanup EXIT` 会删除该目录，`find /tmp -maxdepth 1 -type d -name 'uya-embedded-root.*' | wc -l` 运行前后均为 `0`，但 `/tmp/verify_project_root_embedded_uya_resolution.log` 会保留并被覆盖更新。
    - 验证命令：`bash tests/verify_check_cli.sh`、`TMPDIR=$(mktemp -d /tmp/std-script-exec-regression.XXXXXX) UYA_COMPILER=../uya/bin/uya bash tests/verify_exec_vm_compiler_regressions.sh`、`UYA_COMPILER=../uya/bin/uya bash tests/verify_split_build_output.sh`、`UYA_COMPILER=../uya/bin/uya bash tests/verify_project_root_embedded_uya_resolution.sh`
    - 验证结果：4 个脚本均成功；前三类临时路径运行后无残留，`verify_project_root_embedded_uya_resolution.sh` 额外保留并覆盖 `/tmp/verify_project_root_embedded_uya_resolution.log`。

## Phase 0：盘点与基线

- 任务路径：记录第一批推荐迁移对象
  - [x] `tests/verify_check_cli.sh`
    - 记录位置：`docs/std_script_design.md` 的 “A 类：优先迁移” 已补充迁移理由、行为 oracle 与最小能力需求。
    - 验证命令：`../uya/bin/uya check tests/check_cli_no_main.uya`；结果：输出包含 `类型检查通过` 与 `检查完成：checker 通过（未执行代码生成）`，且未进入代码生成。
    - 验证命令：`../uya/bin/uya check tests/error_check_missing_brace.uya`；结果：命令失败并输出 `语法分析失败`。
    - 验证命令：`../uya/bin/uya --help`；结果：帮助文本包含 `check <文件>`。
    - 验证命令：`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md`；结果：`ok: docs/todo_std_script.md has 1 active task`。
    - 验证命令：`git diff --check -- docs/todo_std_script.md docs/std_script_design.md`；结果：通过。

## Phase 0：盘点与基线

路径：记录第一批推荐迁移对象

- [x] `tests/verify_exec_vm_compiler_regressions.sh`
  - 理由：脚本主体是线性编排的编译器调用、stdout/stderr 文本断言和少量 fallback 守卫，没有循环、目录遍历或复杂 shell 展开，适合作为第一批 `.sh -> .ush` 迁移样板。
  - 行为 oracle：保持 `--vm` / `--exec` 下的 EXEC 后端命中、关键 stderr 诊断匹配，以及“不回退 C99 / 不打印陈旧误诊断”的失败语义。
  - 迁移所需最小能力：`std.process` 的 argv 执行与 stdout/stderr 捕获，`std.script` 的包含/不包含断言，以及临时文件创建清理帮助函数。
  - 验证：`rg -n -A3 -B1 "verify_exec_vm_compiler_regressions\\.sh" docs/todo_std_script.md`（确认记录条目已写入）
  - 验证：`git diff --check -- docs/todo_std_script.md`（通过）

## Phase 0：盘点与基线

父级任务路径：记录第一批推荐迁移对象

- [x] `tests/verify_split_build_output.sh`
  - 推荐理由：脚本仅 24 行，主体是一次编译调用加一次 `test -x` 断言，没有循环、管道、并行或复杂参数展开，适合作为第一批 `.sh -> .ush` 迁移样本。
  - 迁移所需能力：仓库根目录解析、环境变量读取与 fallback、临时文件创建/删除、child process stdout/stderr 重定向、文件可执行位检查。
  - 预期迁移阶段：待 `std.env` / `std.path` / `std.fs` / `std.process` MVP 齐备后优先替换，保留当前成功输出 `split build output materialized ok` 作为行为 oracle。
  - 验证：`UYA_COMPILER=../uya/bin/uya bash tests/verify_split_build_output.sh` -> `split build output materialized ok`

## Phase 0：盘点与基线

- [x] 记录第一批推荐迁移对象：
  - [x] `tests/verify_project_root_embedded_uya_resolution.sh`
    - 记录位置：`docs/std_script_design.md` 的 “A 类：优先迁移” 已补充推荐理由、行为 oracle 与最小能力需求。
    - 验证命令：`UYA_COMPILER=../uya/bin/uya bash tests/verify_project_root_embedded_uya_resolution.sh`；结果：输出 `embedded project-root stdlib resolution ok`。
    - 验证命令：`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md`；结果：`ok: docs/todo_std_script.md has 0 active tasks`。
    - 验证命令：`git diff --check -- docs/todo_std_script.md docs/std_script_design.md docs/todo_std_script_completed.md`；结果：通过。
## 2026-06-29 Phase 0：盘点与基线

父级任务路径：`将复杂脚本标记为后续阶段处理：`

- [x] `tests/run_programs_parallel.sh`
  - 结论：保持为后续阶段脚本；实际迁移落点保留在 `docs/todo_std_script.md` 的 Phase 7.1 `迁移 tests/run_programs_parallel.sh`。
  - 归因：脚本同时承担并行调度、`TARGET_OS` / `TARGET_ARCH` 归一化、`TOOLCHAIN` / `CC_DRIVER` 切换，以及 `RUNTIME_MODE` / `LINK_MODE` / `UYA_TEST_NOSTDLIB_MODE` 分支，不属于第一批 `std.script` 基础能力即可覆盖的简单脚本。
  - 验证：
    - `python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md` -> `ok: docs/todo_std_script.md has 1 active task`
    - `rg -n "PARALLEL_JOBS|TARGET_OS|TARGET_ARCH|TOOLCHAIN|CC_DRIVER|UYA_TEST_NOSTDLIB_MODE|RUNTIME_MODE|LINK_MODE" tests/run_programs_parallel.sh` -> 命中并行调度、目标平台、工具链与运行模式分支
    - `rg -n "tests/run_programs_parallel\\.sh" docs/std_script_shell_inventory.md docs/std_script_design.md docs/todo_std_script.md` -> 盘点文档已排除第一批迁移，设计与主 todo 均保留后续阶段迁移落点

## Phase 0：盘点与基线

- [x] 将复杂脚本标记为后续阶段处理：
  - [x] `tests/run_cross_platform_tests.sh`
    - 验证命令：`rg -n "tests/run_cross_platform_tests\\.sh" docs/std_script_shell_inventory.md docs/std_script_design.md docs/todo_std_script.md`
    - 验证结果：`docs/std_script_shell_inventory.md` 将其列为“不纳入本轮 B 类”的脚本之一；`docs/std_script_design.md` 将其列为 “C 类：后期迁移” 候选；主 todo 已将后续细化留给 `Phase 7 / 7.2 高复杂度脚本评估`。
    - 验证命令：`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md`
    - 验证命令：`git diff --check`
    - 验证结果：`check_todo.py` 返回 `ok: docs/todo_std_script.md has 0 active tasks`。
    - 验证结果：`git diff --check` 无输出。

## Phase 0：盘点与基线

- [x] 将复杂脚本标记为后续阶段处理：
  - [x] `src/compile.sh`
    - 复杂度依据：当前脚本 `1269` 行，已承载平台/架构归一化、toolchain 选择、split-C 链接、缓存清理、自举对比和 CLI 分发，不属于首批 `std.script` 简单迁移对象。
    - 后续阶段：待 `std.process` / `std.script` facade / Windows hosted backend 收口后，再评估是否拆分迁移。
    - 验证：`wc -l src/compile.sh` => `1269 src/compile.sh`
    - 验证：`grep -nE '^(normalize_os|normalize_arch|run_uya_split_make_link|cleanup_uya_split_cache_dir|uya_bootstrap_cmp_exe_normalized)\\(\\)|^while \\[\\[ \\$# -gt 0 \\]\\]|^if \\[ \"\\$BOOTSTRAP_COMPARE\" = true \\]; then|^if \\[ \"\\$USE_NOSTDLIB\" = true \\] && \\[ \"\\$GENERATE_EXEC\" != true \\]; then' src/compile.sh` => 命中 `normalize_os`/`normalize_arch`/`run_uya_split_make_link`/`cleanup_uya_split_cache_dir`/`uya_bootstrap_cmp_exe_normalized`/CLI 参数循环/自举对比与 `--nostdlib` 约束分支。
    - 验证：`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md` => `ok: docs/todo_std_script.md has 0 active tasks`
    - 验证：`git diff --check -- docs/todo_std_script.md docs/todo_std_script_completed.md` => 无输出
## Phase 1：运行时基础缺口

### 1.1 环境变量

- 明确脚本运行时优先语义：
  - [x] child-local env overlay
    - 结果：在 `docs/std_script_design.md` 明确 child env 以当前进程只读快照为 base，overlay/remove 仅作用于 child `execve` env block，按调用顺序决议，同 key 最多出现一次，不回写 `saved_envp`，且禁止通过全局 `setenv` / `unsetenv` + 回滚来模拟。
    - 验证：`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md`（`ok: docs/todo_std_script.md has 1 active task`）
    - 验证：`git diff --check -- docs/std_script_design.md docs/todo_std_script.md`（无输出）
    - 验证：`rg -n "child-local env overlay|只读快照|saved_envp|execve|env_set_current|command\\.env_set" docs/std_script_design.md`（命中新增语义条目）

- [x] 明确脚本运行时优先语义：
  - [x] 当前进程全局 env mutation
    - 结果：在 `docs/std_script_design.md` 新增“2.4 当前进程全局 env mutation 语义约束”，明确该能力不是 Phase 1 MVP 前置条件，必须使用显式 current-mutation API，与 child-local overlay 保持独立语义；成功后会影响后续 `std.env.get/has/iter` 与 `inherit_current()/Command` 的 base-env 快照，但不会回溯修改已生成 env block 或已启动 child；同时脚本层不允许继续沿用当前 libc stub 的 silent no-op 行为。
    - 验证：`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md`（`ok: docs/todo_std_script.md has 0 active tasks`）
    - 验证：`git diff --check -- docs/std_script_design.md docs/todo_std_script.md docs/todo_std_script_completed.md`（无输出）
    - 验证：`rg -n "### 2\\.4 当前进程全局 env mutation 语义约束|env_set_current|silent no-op|canonical env view|child-only 语义" docs/std_script_design.md`（命中新增语义条目）

## Phase 1：运行时基础缺口

### 1.1 环境变量

- [x] 补齐真实环境变量写接口，或至少补齐供 child process 使用的 env block builder。
- [x] 为 env 读取/覆盖/删除补单元测试。

验证：
`../uya/bin/uya test tests/test_std_env.uya`
结果：通过；6 tests passed，0 failed，59 assertions passed。

## Phase 1：运行时基础缺口
### 1.2 管道与重定向基础
- [x] 在 `osal` 或脚本运行时内部抽象 `pipe`/`pipe2`，避免上层直接碰 raw syscall。
  - 结果：`lib/osal/osal.uya` 新增 `os_pipe` / `os_pipe2` 两个包装；`tests/test_osal.uya` 新增黑盒回归覆盖 `pipe` 与 `pipe2` 的创建和读写；`docs/std_script_design.md` 同步把当前 `osal` 能力说明更新为包含 `pipe/pipe2`。
  - 验证：`../uya/bin/uya test tests/test_osal.uya`（通过，19 tests passed）
  - 验证：`../uya/bin/uya test tests/test_syscall_dir.uya`（通过，7 tests passed）
  - 验证：`../uya/bin/uya test tests/test_unistd.uya`（通过，libc.unistd tests PASS）
  - 验证：`git diff --check`（通过）

## Phase 1：运行时基础缺口
### 1.2 管道与重定向基础
- [x] 补 `stdin/stdout/stderr` 重定向用例。
  - 结果：`tests/test_osal.uya` 新增 `os_redirect_stdin_stdout_with_execve` 与 `os_redirect_stderr_with_execve` 两个黑盒回归，分别用真实 `fork + dup2 + execve` 验证 `stdin/stdout` 文件重定向与 `stderr` 文件重定向，不引入新的运行时实现。
  - 验证：`../uya/bin/uya test tests/test_osal.uya`（通过，21 tests passed）
  - 验证：`../uya/bin/uya test tests/test_unistd.uya`（通过，`libc.unistd tests` PASS）
  - 验证：`../uya/bin/uya test tests/test_syscall_file.uya`（通过，5 tests passed）
  - 补充：`../uya/bin/uya test tests/test_syscall_process.uya` 仍因既有 `WNOHANG` 宏名冲突导致宿主 `cc` 编译失败，与本轮改动无关。
  - 验证：`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md`（通过，`ok: docs/todo_std_script.md has 0 active tasks`）
  - 验证：`git diff --check -- docs/todo_std_script.md docs/todo_std_script_completed.md tests/test_osal.uya`（通过）

## Phase 1：运行时基础缺口
### 1.2 管道与重定向基础
- [x] 补父进程捕获子进程输出的最小回归。
  - 验证：`../uya/bin/uya test tests/test_osal.uya`（通过；新增 `os_parent_captures_child_stdout_via_pipe`，22 tests passed）
  - 验证：`../uya/bin/uya test tests/test_unistd.uya`（通过）

## Phase 1：运行时基础缺口

### 1.3 hosted backend 缺口

- [x] 盘点 Darwin hosted 下脚本运行时仍缺的 bridge。
  - 结果：`docs/std_script_design.md` 已补 Darwin 差集说明；现有下层已覆盖 `chdir/getcwd`、`stat/fstat/lstat`、`readlink`、`dup2`、`pipe2`、`fork/waitpid`、`opendir/readdir/closedir`、`poll`、`clock_gettime/nanosleep`。
  - 结果：当前仍缺的 Darwin 脚本运行时 bridge/底层能力主要有 3 类：`sys_execve` 没有 `uya_macos_*` host bridge；`setenv` / `unsetenv` / `clearenv` 仍是占位；若要兑现 A 类脚本候选里的目录 symlink helper，还缺 `symlink` / `os_symlink` / `sys_symlink` 原语。
  - 结果：第一批脚本迁移可继续依赖 child-local `EnvBlockBuilder`；Darwin 当前最需要单独收口的是 child process launch 这条显式 bridge 或 macOS 真机 smoke 证明。
  - 验证命令：`rg -n "Darwin hosted 的脚本运行时仍有少量 bridge 差集|sys_execve|setenv|symlink helper" docs/std_script_design.md lib/libc/syscall.uya lib/libc/stdlib.uya`
  - 验证结果：命中 `docs/std_script_design.md:108-112`、`lib/libc/syscall.uya:1621`、`lib/libc/stdlib.uya:1040-1056`。
### Phase 1：运行时基础缺口

1.3 hosted backend 缺口

- [x] process spawn/wait
  - 结论：
    - 当前 `lib/osal/osal.uya` 的 `os_spawn` 仍建立在 `sys_fork() + sys_execve()` 上，`os_waitpid` 直接透传 `sys_waitpid()`，属于 POSIX-only 模型，不能直接作为 Windows hosted 的公共实现。
    - `lib/libc/syscall.uya` 的 unknown-host 分支里，`sys_waitpid`、`sys_fork`、`sys_execve` 目前都直接 `return -1`，说明 Windows 不能先复用现有 unknown-host syscall stub，再在上层勉强包装。
    - Windows hosted 的最小 `spawn/wait` bridge 应收敛为：`spawn` 继续接受 UTF-8 `path/argv/env/cwd/stdio` 结构化输入，bridge 内部转宽字符并调用 `CreateProcessW`；`wait` 持有子进程句柄，调用 `WaitForSingleObject`、`GetExitCodeProcess` 并在回收路径关闭句柄。
    - `cwd`、`env`、`pipe/stdio redirection` 虽拆成后续独立叶子，但 `spawn` bridge 的 ABI 从第一版起就应预留这些可选输入，避免后续为 Windows 再做一次公开 API 改版。
  - 文档落点：`docs/std_script_design.md`
  - 验证：
    - `sed -n '527,552p' docs/std_script_design.md`：命中 `CreateProcessW`、`WaitForSingleObject`、`GetExitCodeProcess`，确认设计文档已明确 Windows `spawn/wait` bridge 边界。
    - `rg -n "export fn os_waitpid|export fn os_spawn|sys_fork\\(|sys_execve\\(|sys_waitpid\\(" lib/osal/osal.uya lib/libc/syscall.uya`：命中 `lib/osal/osal.uya` 的 `os_spawn/os_waitpid`，确认当前实现仍绑定 `fork/execve/waitpid`。
    - `sed -n '1018,1155p' lib/libc/syscall.uya`：unknown-host 分支里 `sys_waitpid/sys_fork/sys_execve` 全部直接失败，确认 Windows 不能复用现有 stub。

### 1.3 hosted backend 缺口

明确 Windows hosted 所需最小 bridge 列表：

- [x] cwd
  - 结论：
    - `cwd` 需要拆成当前进程 `os_getcwd` / `os_chdir` 与 child-only `Command.cwd` override 两类能力，不能用“先 `chdir` 再回滚”的方式混做。
    - 当前仓库的 hosted C99 codegen 已声明 `_chdir` / `_getcwd` alias，说明 Windows hosted 确实存在最小 `cwd` bridge 入口；但公共 API 既然承诺 UTF-8 byte string，最终实现不能停留在窄字符 CRT 语义上。
    - 最终 Windows bridge 应统一走 UTF-8 ↔ UTF-16 转换，并把 child `cwd` 直接落到 `CreateProcessW` 的 `lpCurrentDirectory`，避免父进程 cwd 被临时污染。
  - 文档落点：`docs/std_script_design.md`
  - 验证：
    - `sed -n '539,558p' docs/std_script_design.md`：命中新增 `cwd` 语义边界、UTF-16 收敛与 `lpCurrentDirectory` 约束。
    - `rg -n "_chdir|_getcwd|_wchdir|_wgetcwd|Command\\.cwd|lpCurrentDirectory|UTF-8 byte string" docs/std_script_design.md src/codegen/c99/main.uya`：命中设计文档新增条目与 `src/codegen/c99/main.uya` 的 `_chdir` / `_getcwd` alias 证据。

## Phase 1：运行时基础缺口

### 1.3 hosted backend 缺口

父级任务路径：明确 Windows hosted 所需最小 bridge 列表

- [x] env
  - 结论：Windows hosted 的 `env` 最小 bridge 已收敛为两层：启动阶段从宽字符宿主环境构造 UTF-8 canonical env view，child-only overlay 继续复用 `EnvBlockBuilder`，并在 `CreateProcessW(..., lpEnvironment=...)` 处转换为 UTF-16 env block；当前进程 env mutation 不是 Phase 1 前置，也不能复用现有 `setenv` / `unsetenv` / `clearenv` stub。
  - 验证命令：`rg -n "saved_envp|GetEnvironmentStringsW|CreateProcessW|lpEnvironment|silent success|EnvBlockBuilder" docs/std_script_design.md lib/std/env.uya lib/std/runtime/entry/entry.uya lib/libc/stdlib.uya`
  - 结果：命中文档与实现边界，确认结论与 `saved_envp`、`EnvBlockBuilder`、`CreateProcessW(..., lpEnvironment=...)` 和当前 env mutation stub 一致。
  - 验证命令：`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md`
  - 结果：ok: docs/todo_std_script.md has 0 active tasks

### 1.3 hosted backend 缺口

父级任务路径：明确 Windows hosted 所需最小 bridge 列表

- [x] stat/remove/rename
  - 结论：Windows hosted 的 `stat/remove/rename` 最小 bridge 已收敛为一组共用 UTF-8 → UTF-16 路径转换的文件桥：`stat` 负责存在性/目录/大小/时间等基础元数据，`remove` 负责文件/目录删除分发，`rename` 负责保持 replace 语义的重命名。
  - 验证命令：`sed -n '555,562p' docs/std_script_design.md`
  - 结果：设计文档已明确 `GetFileAttributesExW` / `GetFileInformationByHandleEx`、`DeleteFileW` / `RemoveDirectoryW`、`MoveFileExW(..., MOVEFILE_REPLACE_EXISTING)` 与统一 UTF-8 → UTF-16 路径转换约束。
  - 验证命令：`sed -n '1386,1595p' lib/libc/syscall.uya`
  - 结果：`sys_stat` / `sys_rename` 当前只有 macOS hosted 分支，其余仍走 syscall 路径，证明 Windows hosted 还缺对应 bridge。
  - 验证命令：`sed -n '2011,2057p' lib/libc/stdio.uya`
  - 结果：`remove()` 依赖 `sys_stat` + `sys_rmdir` / `sys_unlink` 分发，`rename()` 直接透传 `sys_rename()`，证明三项应成组补齐。
  - 验证命令：`git diff --check -- docs/std_script_design.md docs/todo_std_script.md`
  - 结果：通过。
  - 验证命令：`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md`
  - 结果：`ok: docs/todo_std_script.md has 0 active tasks`
### 1.3 hosted backend 缺口

父级任务路径：明确 Windows hosted 所需最小 bridge 列表

- [x] dir traversal
  - 结论：Windows hosted 的 `dir traversal` 最小 bridge 应继续暴露 UTF-8 `path` + 统一 `libc.Dirent` 抽象，内部转 UTF-16 并以 `FindFirstFileW` / `FindNextFileW` / `FindClose` 维护目录句柄；`readdir` 只需稳定填充 `d_type` / `d_name`，其余字段可保零值，并允许 `DT_UNKNOWN` fallback。
  - 验证命令：`sed -n '563,568p' docs/std_script_design.md`
  - 结果：设计文档已明确 Windows `dir traversal` 的 UTF-16 bridge、统一 `Dirent` 抽象、首项缓存与 `DT_UNKNOWN` fallback 约束。
  - 验证命令：`rg -n "uya_macos_host_readdir_fill|sys_open \\+ sys_getdents64 \\+ sys_close|dirent_may_be_regular_file|FindFirstFileW|FindNextFileW|FindClose" docs/std_script_design.md lib/libc/stdlib.uya src/main.uya`
  - 结果：命中现有 macOS hosted `readdir_fill`、Linux `sys_getdents64` 路径，以及 `src/main.uya` 的 `dirent_may_be_regular_file(...)` fallback，证明 Windows 仍缺目录遍历 bridge 且新增边界与现有抽象一致。
  - 验证命令：`python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md`
  - 结果：`ok: docs/todo_std_script.md has 0 active tasks`
  - 验证命令：`git diff --check -- docs/std_script_design.md docs/todo_std_script.md docs/todo_std_script_completed.md`
  - 结果：通过。

## Phase 1：运行时基础缺口

### 1.3 hosted backend 缺口

任务路径：明确 Windows hosted 所需最小 bridge 列表

- [x] 明确 Windows hosted 所需最小 bridge 列表：
  - [x] pipe/stdio redirection
    - 产出：`docs/std_script_design.md` 已补齐 Windows hosted `pipe/stdio` 最小 bridge 语义，明确对齐 `tests/test_osal.uya` 中 `stdin -> child`、`stderr -> file`、`parent capture stdout` 三条现有 POSIX 行为基线。
    - 验证命令：`git diff --check -- docs/todo_std_script.md docs/todo_std_script_completed.md docs/std_script_design.md`
    - 验证结果：通过。
    - 验证命令：`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_std_script.md`
    - 验证结果：`ok: docs/todo_std_script.md has 0 active tasks`。

## Phase 1：运行时基础缺口

### 1.4 shebang 预研

- [x] 明确 shebang 不阻塞第一批脚本迁移。
  - 结论：第一批 `.sh -> .ush` 迁移统一走 `../uya/bin/uya run path/to/script.ush -- ...`；shebang 与未来 `uya script` 只作为后续脚本入口 UX 增强，不是 Phase 1 / Phase 4 的前置条件。
  - 依据：`docs/std_script_design.md` 已将普通 `export fn main() !i32` + `uya run` 定义为 Phase 1 入口，并将 `uya script` / shebang 放在后续阶段；`docs/uya.md` 记录 `#!` 仅作为文件开头首行注释规则，当前 `uya run` 已可直接运行带 shebang 的 `.ush` / `.uya`。
  - 验证：`../uya/bin/uya run <tmp>/hello.ush`，输出 `plain ush ok`。
  - 验证：`UYA_COMPILER=../uya/bin/uya bash ./tests/verify_run_shebang_ush.sh`，输出 `verify_run_shebang_ush: ok`。

## Phase 2：`std.path` / `std.env` / `std.fs` MVP

### 2.1 `std.path`

- [x] 新建 `lib/std/path.uya` 或等价模块。
  - TDD：
    - `../uya/bin/uya test tests/test_std_path_module.uya`：初始失败，报错 `模块中未找到导出项`。
  - 验证：
    - `../uya/bin/uya test tests/test_std_path_module.uya`：通过。
    - `../uya/bin/uya test tests/test_module_use_simple.uya`：通过。
    - `make clean`：通过。
    - `make backup-all`：通过；期间 zig 交叉链接 macOS hosted 可执行文件提示 `timeval` / `sigaction` / `signal` 重定义，但 Makefile 继续保留 C 种子并返回成功。
## Phase 2：`std.path` / `std.env` / `std.fs` MVP

### 2.1 `std.path`

父级任务路径：提供：

  - [x] `join`
    - 验证：`../uya/bin/uya test tests/test_std_path_module.uya`
    - 结果：通过，`std.path` 5 个用例全部通过。
    - 验证：`../uya/bin/uya test tests/test_std_string.uya`
    - 结果：通过。
    - 验证：`git diff --check`
    - 结果：通过，无 diff 格式问题。

## Phase 2：`std.path` / `std.env` / `std.fs` MVP

### 2.1 `std.path`

父级路径：`提供`
- [x] `dirname`
  - 实现：在 `lib/std/path.uya` 新增 `dirname(path, out, out_cap)`，覆盖相对路径、Unix 根目录、Windows 盘符目录与尾部分隔符裁剪。
  - 验证：`../uya/bin/uya test tests/test_std_path_module.uya`
    - 结果：通过，`std.path` 9 个用例全部通过，包含新增 `dirname` 回归。
  - 验证：`git diff --check -- lib/std/path.uya tests/test_std_path_module.uya docs/todo_std_script.md`
    - 结果：通过，无 diff 格式问题。

## Phase 2：`std.path` / `std.env` / `std.fs` MVP

### 2.1 `std.path`

父级路径：`提供：`

- [x] `basename`
  - 实现：在 `lib/std/path.uya` 新增导出 `basename(path, out, out_cap)`，统一处理空串、尾部分隔符裁剪、Unix 根和 Windows 盘符根。
  - 验证：`../uya/bin/uya test tests/test_std_path_module.uya`
    - 结果：首次失败，新增 3 个 `basename` 用例失败并出现宿主 C `basename` 隐式声明警告；实现后通过，`std.path` 12 个用例全部通过。
  - 验证：`git diff --check -- lib/std/path.uya tests/test_std_path_module.uya docs/todo_std_script.md`
    - 结果：通过。

## Phase 2：`std.path` / `std.env` / `std.fs` MVP

### 2.1 `std.path`

- 父级任务：`提供：`
- [x] `stem`
  - 预期失败验证：`../uya/bin/uya test tests/test_std_path_module.uya`
    - 结果：失败，链接阶段报 `undefined reference to 'stem'`。
  - 实现：在 `lib/std/path.uya` 新增 `stem(path, out, out_cap)`，复用 basename/root 逻辑，只剥离最后一个有效扩展名，并保留 dotfile 与根路径行为。
  - 验证：`../uya/bin/uya test tests/test_std_path_module.uya`
    - 结果：通过，`std.path` 14 个用例全部通过，包含新增 `stem` 回归。
  - 验证：`git diff --check -- lib/std/path.uya tests/test_std_path_module.uya docs/todo_std_script.md`
    - 结果：通过。

## Phase 2：`std.path` / `std.env` / `std.fs` MVP

### 2.1 `std.path`

- 父级任务：`提供：`
- [x] `extension`
  - 预期失败验证：`../uya/bin/uya test tests/test_std_path_module.uya`
    - 结果：失败，链接阶段报 `undefined reference to 'extension'`，并伴随宿主 C `implicit declaration of function 'extension'` 警告。
  - 实现：在 `lib/std/path.uya` 新增 `extension(path, out, out_cap)`，复用现有 `stem` / root 逻辑，返回最后一个扩展名（含前导 `.`），并让 dotfile、根路径与无扩展名路径返回空串。
  - 验证：`../uya/bin/uya test tests/test_std_path_module.uya`
    - 结果：通过，`std.path` 16 个用例全部通过，包含新增 `extension` 回归。
  - 验证：`git diff --check -- lib/std/path.uya tests/test_std_path_module.uya docs/todo_std_script.md docs/todo_std_script_completed.md`
    - 结果：通过。
## Phase 2：`std.path` / `std.env` / `std.fs` MVP

### 2.1 `std.path`

- 父级任务：`提供：`
- [x] `is_abs`
  - 预期失败验证：`../uya/bin/uya test tests/test_std_path_module.uya`
    - 结果：失败，链接阶段报 `undefined reference to 'is_abs'`，并伴随宿主 C `implicit declaration of function 'is_abs'` 警告。
  - 实现：在 `lib/std/path.uya` 新增导出 `is_abs(path)`，复用现有内部 `path_is_absolute`，统一识别 Unix 根路径与 Windows 盘符绝对路径。
  - 验证：`../uya/bin/uya test tests/test_std_path_module.uya`
    - 结果：通过，`std.path` 17 个用例全部通过，包含新增 `is_abs` 回归。
  - 验证：`../uya/bin/uya test tests/test_module_use_simple.uya`
    - 结果：通过。
  - 验证：`make clean`
    - 结果：通过。
  - 验证：`make UYA_BACKUP_MACOS_AUX=0 backup-all`
    - 结果：通过，完成自举、1073 项测试、UPM/exec vm/microapp/SIMD/@syscall/http_bench 验证以及 seed/uyacache 备份。
## Phase 2：`std.path` / `std.env` / `std.fs` MVP

### 2.1 `std.path`

- 父级任务：`提供：`
- [x] `normalize`
  - 预期失败验证：`../uya/bin/uya test tests/test_std_path_module.uya`
    - 结果：失败，链接阶段报 `undefined reference to 'normalize'`，并伴随宿主 C `implicit declaration of function 'normalize'` 警告。
  - 实现：在 `lib/std/path.uya` 新增导出 `normalize(path, out, out_cap)`，消解 `.` / `..`、折叠重复分隔符，并保留根路径、盘符与输入分隔符家族。
  - 验证：`../uya/bin/uya test tests/test_std_path_module.uya`
    - 结果：通过，`std.path` 19 个用例全部通过，包含新增 `normalize` 回归。
  - 验证：`../uya/bin/uya test tests/test_module_use_simple.uya`
    - 结果：通过。
  - 验证：`git diff --check -- lib/std/path.uya tests/test_std_path_module.uya docs/todo_std_script.md`
    - 结果：通过。
  - 验证：`make clean`
    - 结果：通过。
  - 验证：`make backup-all`
    - 结果：首次执行在 `check` 阶段出现瞬时 `test_std_thread` 退出码 `134`；随后单独运行 `../uya/bin/uya test tests/test_std_thread.uya` 通过，第二次 `make backup-all` 通过，完成自举、1073 项测试、UPM/exec vm/microapp/SIMD/@syscall/http_bench 验证并刷新 `backup/uya*.c` 种子。

## Phase 2：`std.path` / `std.env` / `std.fs` MVP

### 2.1 `std.path`

提供：
  - [x] `path_list_separator`
    - 实现：在 `lib/std/path.uya` 新增导出 `path_list_separator()`，用 `std.cfg(std.target_os == .tos_windows)` 返回 `';'`，其他目标返回 `':'`。
    - 验证：`../uya/bin/uya test tests/test_std_path_module.uya`
      结果：通过，20 个 `std.path` 相关测试全部通过。
    - 验证：`git diff --check -- lib/std/path.uya tests/test_std_path_module.uya docs/todo_std_script.md`
      结果：通过，无 diff 格式错误。

## Phase 2：`std.path` / `std.env` / `std.fs` MVP

### 2.1 `std.path`

- [x] 提供：
  - [x] `executable_suffix`
    - 预期失败验证：`../uya/bin/uya test tests/test_std_path_module.uya`
      - 结果：首次失败，链接阶段报 `undefined reference to executable_suffix`。
    - 实现：在 `lib/std/path.uya` 新增导出 `executable_suffix()`，用目标平台常量返回 Windows `.exe` / 其他空串；在 `tests/test_std_path_module.uya` 补平台条件测试。
    - 验证：`../uya/bin/uya test tests/test_std_path_module.uya`
      - 结果：通过，21 个 `std.path` 用例全部通过，79 个断言通过。
    - 验证：`git diff --check -- lib/std/path.uya tests/test_std_path_module.uya docs/todo_std_script.md docs/todo_std_script_completed.md`
      - 结果：通过，无 diff 格式错误。

## Phase 2：`std.path` / `std.env` / `std.fs` MVP

### 2.1 `std.path`

- [x] 补 Linux / macOS / Windows 语义测试（至少先写平台条件测试）。
  - 修复：先用 `make from-c` 从 `backup/uya.c` 冷启动生成缺失的 `../uya/bin/uya`，解除失败归档中的本地编译器阻塞。
  - 覆盖：`tests/verify_std_path_platform_targets.sh` 依次用 `TARGET_OS=linux`、`TARGET_OS=macos`、`TARGET_OS=windows` 生成并运行 `tests/test_std_path_platform_cfg.uya`，验证 `path_list_separator()` 与 `executable_suffix()` 的目标平台条件语义。
  - 验证：`bash tests/verify_std_path_platform_targets.sh`
    - 结果：通过，Linux / macOS / Windows 三个目标的 `std.path` 平台条件验证全部通过。
