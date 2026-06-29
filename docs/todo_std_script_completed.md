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
