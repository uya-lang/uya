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
