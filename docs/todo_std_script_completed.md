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
