#!/usr/bin/env python3
"""Run Codex with an embedded default workflow until a todo file is done."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


CHECKBOX_RE = re.compile(r"^(?P<prefix>\s*[-*]\s*)\[(?P<state>[^\]])\](?P<rest>.*)$")
HEADING_RE = re.compile(r"^(?P<marks>#{1,6})\s+(?P<title>.*)$")
VALID_STATES = {" ", "x", "~", "f"}
DEFAULT_SKILL_NAME = "goal-task-runner"
DEFAULT_SKILL_SOURCE = ".agents/skills/goal-task-runner/SKILL.md"
DEFAULT_GOAL_TASK_RUNNER_SKILL = r"""---
name: goal-task-runner
description: 按顺序执行目标导向的长任务 todo，使用 TDD、诚实进度跟踪、任务拆分、性能优先实现、git 提交和推送。适用于 Codex 被要求接收 todo 文件或 todo 列表并依次完成任务的场景。
---

# 目标任务执行器

使用此 skill 时，必须用中文与用户沟通，包括过程更新、失败说明、验证结果和最终回复。代码、命令、错误日志、提交信息和项目内既有英文术语可以保留原文。

此 skill 用于把 todo 当作一个有纪律的长任务执行：一次只做一个任务，能 TDD 就先写测试，诚实更新状态，不用占位实现糊弄完成，并保持干净的 git 交接。loop.py 会在每轮 prompt 的“本轮硬约束”里提供具体 todo 状态流转、归档路径、单轮停止和日志裁剪规则；这些硬约束优先级高于本 skill 的概括性描述。

如果任务过大、含糊，或暗含多个交付物，先把它拆成有顺序的小型 `[ ]` 叶子子任务，再开始实现。父级只作为分组保持 `[ ]`，每个子任务必须有单一交付物和可运行的验证方式。若接手时父级已经是 `[~]`，先把父级改回 `[ ]`，只把第一个可执行叶子子任务标成 `[~]`；不要留下父子同时 `[~]`。

## 执行原则

1. 先阅读 todo、仓库状态、相关文档和邻近代码，确认本轮目标和最小验证方式。
2. 当任务影响代码行为时，遵循 TDD：
   - 新增或更新一个会失败的测试，用来证明缺失行为或 bug。
   - 运行聚焦测试，并确认它因为预期原因失败。
   - 实现生产代码改动。
   - 运行聚焦测试，直到通过。
   - 标记完成前，运行更广泛的相关测试。
3. 对非代码任务，使用最接近真实的验证方式，例如生成产物、lint、人工检查或命令输出。
4. 优先考虑性能：避免不必要的重复工作、无边界扫描、可避免的分配、慢轮询、可自然并行却串行的工作，以及笨重依赖。当性能是核心风险时，进行测量或基准测试。

## 诚实规则

不要把 stub、只为测试硬编码、隐藏在跳过测试后面的代码，或占位实现标记为 `[x]`。不要为了让测试通过而削弱测试；如果测试本身错误，需要说明修正原因。

不要声称运行过没有运行的验证。如果测试无法运行，先保持任务为进行中状态并尝试修复；如果确实阻塞，记录确切命令、失败原因和后续重开条件。

不要静默丢弃用户改动。编辑前和提交前都检查 `git status`。如果存在无关脏文件，保持原样。如果任务所需文件已有用户改动，在这些改动基础上工作，避免回滚。

## 失败处理

任务失败时：

1. 只有在有新的具体假设或修复方案时才重试。
2. 如果失败改变了后续工作要求，把说明写入主 todo 的后续待办或失败归档。
3. 只有遇到真实阻塞、重复且不可恢复的失败、缺失依赖、不可能满足的要求，或必须由用户决策的问题时，才按本轮硬约束标记失败并移动到失败归档。
4. 不要提交损坏的生产代码。只有当用户要求持久记录进度时，才提交有价值的诊断性 todo 更新；否则保留未提交改动并清楚报告。
"""


@dataclass(frozen=True)
class TodoStatus:
    pending: int
    active: int
    done: int
    failed: int
    invalid: tuple[tuple[int, str], ...]
    uppercase_done: tuple[int, ...]

    @property
    def unfinished(self) -> int:
        return self.pending + self.active + self.failed

    @property
    def runnable(self) -> int:
        return self.pending + self.active


@dataclass(frozen=True)
class TodoItem:
    lineno: int
    indent: int
    state: str
    text: str
    is_leaf: bool


@dataclass(frozen=True)
class TodoContext:
    item: TodoItem | None
    headings: tuple[str, ...]
    ancestors: tuple[TodoItem, ...]
    excerpt: tuple[str, ...]
    excerpt_start: int
    excerpt_end: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Use `codex exec` to repeatedly execute one todo round, then stop "
            "when no unfinished checkbox remains. By default, the "
            "goal-task-runner workflow is embedded in the prompt."
        )
    )
    parser.add_argument(
        "todo",
        nargs="?",
        default="docs/todo.md",
        help="Todo markdown file to execute. Default: docs/todo.md",
    )
    parser.add_argument(
        "--skill",
        default="",
        help=(
            "Optional Codex skill name to request, with or without a leading "
            "'$'. If omitted, use the embedded goal-task-runner workflow so "
            "loop.py works as a single file."
        ),
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Repository root passed to `codex exec -C`. Default: current directory.",
    )
    parser.add_argument(
        "--codex-cmd",
        default=os.environ.get("CODEX_CMD", "codex"),
        help="Codex executable. Default: CODEX_CMD or `codex`.",
    )
    parser.add_argument(
        "--model",
        default=os.environ.get("CODEX_MODEL", "gpt-5.5"),
        help="Optional model passed to `codex exec --model`.",
    )
    parser.add_argument(
        "--reasoning-effort",
        default=os.environ.get("CODEX_REASONING_EFFORT", "low"),
        choices=("", "minimal", "low", "medium", "high", "xhigh"),
        help=(
            "Optional reasoning effort passed to Codex via "
            "`model_reasoning_effort`."
        ),
    )
    parser.add_argument(
        "--sandbox",
        default=os.environ.get("CODEX_SANDBOX", "danger-full-access"),
        choices=("read-only", "workspace-write", "danger-full-access"),
        help="Sandbox passed to `codex exec --sandbox`.",
    )
    parser.add_argument(
        "--max-rounds",
        type=int,
        default=0,
        help="Maximum Codex rounds. 0 means no limit.",
    )
    parser.add_argument(
        "--continue-after-failed",
        action="store_true",
        help="Continue while [f] tasks exist if there are still [ ] or [~] tasks.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the first Codex command and prompt without running it.",
    )
    parser.add_argument(
        "--context-lines",
        type=int,
        default=12,
        help="Number of todo lines around the selected task included in the prompt.",
    )
    parser.add_argument(
        "--max-excerpt-line-chars",
        type=int,
        default=240,
        help="Maximum characters per numbered todo excerpt line.",
    )
    return parser.parse_args()


def read_todo_lines(todo_path: Path) -> list[str]:
    if not todo_path.exists():
        raise FileNotFoundError(f"todo file not found: {todo_path}")
    return todo_path.read_text(encoding="utf-8").splitlines()


def read_todo_status_from_lines(lines: list[str]) -> TodoStatus:
    pending = active = done = failed = 0
    invalid: list[tuple[int, str]] = []
    uppercase_done: list[int] = []

    for lineno, line in enumerate(lines, 1):
        match = CHECKBOX_RE.match(line)
        if not match:
            continue

        state = match.group("state")
        if state == "X":
            uppercase_done.append(lineno)

        normalized = state.lower()
        if normalized not in VALID_STATES:
            invalid.append((lineno, state))
            continue

        if normalized == " ":
            pending += 1
        elif normalized == "~":
            active += 1
        elif normalized == "x":
            done += 1
        elif normalized == "f":
            failed += 1

    return TodoStatus(
        pending=pending,
        active=active,
        done=done,
        failed=failed,
        invalid=tuple(invalid),
        uppercase_done=tuple(uppercase_done),
    )


def read_todo_status(todo_path: Path) -> TodoStatus:
    return read_todo_status_from_lines(read_todo_lines(todo_path))


def todo_indent(prefix: str) -> int:
    return len(prefix) - len(prefix.lstrip(" "))


def parse_todo_items(lines: list[str]) -> tuple[TodoItem, ...]:
    raw_items: list[TodoItem] = []
    for lineno, line in enumerate(lines, 1):
        match = CHECKBOX_RE.match(line)
        if not match:
            continue

        raw_items.append(
            TodoItem(
                lineno=lineno,
                indent=todo_indent(match.group("prefix")),
                state=match.group("state").lower(),
                text=match.group("rest").strip(),
                is_leaf=True,
            )
        )

    items: list[TodoItem] = []
    for index, item in enumerate(raw_items):
        has_child = False
        for later in raw_items[index + 1 :]:
            if later.indent <= item.indent:
                break
            has_child = True
            break
        items.append(
            TodoItem(
                lineno=item.lineno,
                indent=item.indent,
                state=item.state,
                text=item.text,
                is_leaf=not has_child,
            )
        )
    return tuple(items)


def iter_descendants(items: tuple[TodoItem, ...], parent_index: int):
    parent = items[parent_index]
    for item in items[parent_index + 1 :]:
        if item.indent <= parent.indent:
            break
        yield item


def first_descendant(
    items: tuple[TodoItem, ...],
    parent_index: int,
    state: str,
    leaf_only: bool,
) -> TodoItem | None:
    for item in iter_descendants(items, parent_index):
        if item.state != state:
            continue
        if leaf_only and not item.is_leaf:
            continue
        return item
    return None


def select_next_item(items: tuple[TodoItem, ...]) -> TodoItem | None:
    for item in items:
        if item.state == "~" and item.is_leaf:
            return item

    for index, item in enumerate(items):
        if item.state != "~":
            continue

        pending_leaf = first_descendant(items, index, " ", True)
        if pending_leaf is not None:
            return pending_leaf

        pending_any = first_descendant(items, index, " ", False)
        if pending_any is not None:
            return pending_any

        return item

    for item in items:
        if item.state == " " and item.is_leaf:
            return item

    for item in items:
        if item.state == " ":
            return item

    return None


def collect_headings(lines: list[str], target_lineno: int) -> tuple[str, ...]:
    stack: list[tuple[int, str]] = []
    for line in lines[: max(0, target_lineno - 1)]:
        match = HEADING_RE.match(line)
        if not match:
            continue

        level = len(match.group("marks"))
        title = match.group("title").strip()
        while stack and stack[-1][0] >= level:
            stack.pop()
        stack.append((level, title))

    return tuple("{} {}".format("#" * level, title) for level, title in stack)


def collect_ancestors(items: tuple[TodoItem, ...], target: TodoItem) -> tuple[TodoItem, ...]:
    stack: list[TodoItem] = []
    for item in items:
        if item.lineno >= target.lineno:
            break
        if item.indent >= target.indent:
            continue

        while stack and stack[-1].indent >= item.indent:
            stack.pop()
        stack.append(item)

    return tuple(stack)


def trim_excerpt_line(line: str, max_chars: int) -> str:
    if max_chars <= 0 or len(line) <= max_chars:
        return line
    suffix = " ... [truncated]"
    if max_chars <= len(suffix):
        return line[:max_chars]
    return line[: max_chars - len(suffix)] + suffix


def build_numbered_excerpt(
    lines: list[str],
    target: TodoItem,
    context_lines: int,
    max_line_chars: int,
) -> tuple[tuple[str, ...], int, int]:
    safe_context_lines = max(0, context_lines)
    start = max(1, target.lineno - safe_context_lines)
    end = min(len(lines), target.lineno + safe_context_lines)
    excerpt = []
    for lineno in range(start, end + 1):
        text = trim_excerpt_line(lines[lineno - 1], max_line_chars)
        excerpt.append(f"{lineno}: {text}")
    return tuple(excerpt), start, end


def build_todo_context(
    lines: list[str],
    context_lines: int,
    max_line_chars: int,
) -> TodoContext:
    items = parse_todo_items(lines)
    item = select_next_item(items)
    if item is None:
        return TodoContext(
            item=None,
            headings=(),
            ancestors=(),
            excerpt=(),
            excerpt_start=0,
            excerpt_end=0,
        )

    excerpt, start, end = build_numbered_excerpt(
        lines,
        item,
        context_lines,
        max_line_chars,
    )
    return TodoContext(
        item=item,
        headings=collect_headings(lines, item.lineno),
        ancestors=collect_ancestors(items, item),
        excerpt=excerpt,
        excerpt_start=start,
        excerpt_end=end,
    )


def skill_mention(skill: str) -> str:
    stripped = skill.strip()
    if not stripped:
        raise ValueError("skill name must not be empty")
    if stripped.startswith("$"):
        return stripped
    return f"${stripped}"


def build_prompt_opening(skill: str) -> str:
    if skill.strip():
        mention = skill_mention(skill)
        return f"请使用 `{mention}` skill 执行指定 todo 文件的下一轮任务。"

    return (
        f"请按以下内置 `{DEFAULT_SKILL_NAME}` skill 规则执行指定 todo "
        "文件的下一轮任务。"
    )


def build_rule_source_block(skill: str) -> str:
    if skill.strip():
        mention = skill_mention(skill)
        return f"""规则来源：
- 严格遵守当前 `--root` 仓库内的 `AGENTS.md`。
- 严格遵守 `{mention}` skill 的规则。"""

    return f"""规则来源：
- 严格遵守当前 `--root` 仓库内的 `AGENTS.md`。
- 严格遵守下方内置 `{DEFAULT_SKILL_NAME}` skill 规则。
- 内置 skill 内容来自 `{DEFAULT_SKILL_SOURCE}`，本 prompt 已完整携带；即使目标仓库没有安装该 skill，也必须按这些规则执行。

内置 skill 全文：
~~~markdown
{DEFAULT_GOAL_TASK_RUNNER_SKILL}
~~~"""


def build_runner_contract_block(
    todo_display: str,
    archive_display: str,
    failed_archive_display: str,
    range_hint: str,
) -> str:
    return f"""本轮硬约束（不依赖 skill，若与 skill 冲突以这里为准）：
- 只读取并遵守当前 `--root` 仓库内的 `AGENTS.md`；不要向上级目录查找或应用 `AGENTS.md`。
- Checkbox 状态只使用 `[ ]` 待执行、`[~]` 正在执行、`[x]` 已完成并已验证、`[f]` 已失败且写明原因。
- 本轮只推进一个叶子任务：优先继续已有 `[~]` 叶子；如果已有 `[~]` 是父级/过大任务，先把父级改回 `[ ]`，拆成有顺序的小型 `[ ]` 叶子子任务，并只把第一个可执行叶子标成 `[~]`。
- 如果发现多个 `[~]`，先用中文报告异常；若是父子同时 `[~]`，保留文档顺序中第一个可执行叶子 `[~]` 并把父级改回 `[ ]`，否则按文档顺序只处理第一个 `[~]`；不要重排或吞掉其他任务。
- 开始实现前，先按归档规则移动主 todo 中遗留的 `[x]` / `[f]` 可归档任务块。
- 如果任务过大或含糊，先在 todo 中拆成可执行的叶子子任务；父级保持 `[ ]` 作为分组，子任务写清单一交付物、最小验证命令和完成条件，只启动第一个子任务。
- 优先围绕上面的目标行工作；读取 todo 时使用小范围命令，例如 `sed -n '{range_hint}p' {todo_display}`，避免打印整份 todo 历史。
- 不要读取 `loop.log`；如确需排错，只读取短尾部，例如 `tail -n 200 loop.log`。
- 完成后写入真实验证命令和结果，再把任务标成 `[x]`，并将本轮完成的 `[x]` 任务及其验证记录移动到完成归档 `{archive_display}`。
- 无法恢复时写入失败原因、阻塞命令、关键错误和后续重开条件，再把任务标成 `[f]`，并将本轮失败的 `[f]` 任务及其失败记录移动到失败归档 `{failed_archive_display}`。
- 如果某个父级 checkbox 的全部子任务都已完成，就把这个完整完成子树一起移入 `{archive_display}`；如果全部子任务都已失败或不可继续，就把这个失败子树一起移入 `{failed_archive_display}`。
- 主 todo 只保留 `[ ]`、`[~]` 和必要上下文；不要留下空的 `[ ]` 父项或同一任务的 `[x]` / `[f]` 复本。
- 可归档任务块是一个 checkbox 条目及其所有从属缩进内容；只移动嵌套叶子或子树时，追加内容中保留最近标题和必要的父级任务路径作为普通文本上下文。
- 归档追加内容必须保留原始任务文本、验证命令、失败原因和缩进层级。
- 归档时不要读取归档文件内容、搜索去重或寻找匹配章节；归档文件存在就直接追加，不存在才创建最小头部。
- 验证记录保持简短，长日志只摘关键错误或路径。
- 提交相关改动并尝试推送；只暂存相关文件、todo 主文件和相关归档文件，不要暂存或回滚无关用户改动；推送失败时如实报告。
- 本轮结束后直接停止，不要自己启动下一轮循环；外层 `loop.py` 会重新检查 todo 状态。"""


def format_item_for_prompt(item: TodoItem) -> str:
    return f"L{item.lineno} [{item.state}] {item.text}"


def format_prompt_lines(lines: tuple[str, ...], fallback: str) -> str:
    if not lines:
        return fallback
    return "\n".join(lines)


def todo_archive_path(todo_display: str, suffix: str) -> str:
    path = Path(todo_display)
    if path.suffix:
        return str(path.with_name(f"{path.stem}_{suffix}{path.suffix}"))
    return f"{todo_display}_{suffix}"


def completed_archive_path(todo_display: str) -> str:
    return todo_archive_path(todo_display, "completed")


def failed_archive_path(todo_display: str) -> str:
    return todo_archive_path(todo_display, "failed")


def build_prompt(
    todo_display: str,
    skill: str,
    status: TodoStatus,
    context: TodoContext,
) -> str:
    archive_display = completed_archive_path(todo_display)
    failed_archive_display = failed_archive_path(todo_display)
    if context.item is None:
        target = "未找到可执行 `[~]` 或 `[ ]` 项。"
        leaf = "unknown"
        range_hint = "无"
    else:
        target = format_item_for_prompt(context.item)
        leaf = "yes" if context.item.is_leaf else "no"
        range_hint = f"{context.excerpt_start},{context.excerpt_end}"

    ancestors = tuple(format_item_for_prompt(item) for item in context.ancestors)
    return f"""{build_prompt_opening(skill)}

{build_rule_source_block(skill)}

本轮输入：
Todo 文件：`{todo_display}`
完成归档：`{archive_display}`
失败归档：`{failed_archive_display}`
当前状态：pending={status.pending} active={status.active} done={status.done} failed={status.failed} unfinished={status.unfinished}

本轮定位：
- 目标：{target}
- 是否叶子：{leaf}
- 所在标题：
{format_prompt_lines(context.headings, "  (无标题上下文)")}
- 父级 checkbox：
{format_prompt_lines(ancestors, "  (无父级 checkbox)")}

任务附近摘录（优先用这些行号定位，必要时只读取这个小范围附近）：
```text
{format_prompt_lines(context.excerpt, "  (无摘录)")}
```

{build_runner_contract_block(todo_display, archive_display, failed_archive_display, range_hint)}
"""


def build_codex_command(args: argparse.Namespace, root: Path) -> list[str]:
    cmd = [
        args.codex_cmd,
        "exec",
        "-C",
        str(root),
        "--sandbox",
        args.sandbox,
    ]
    if args.model.strip():
        cmd.extend(["--model", args.model.strip()])
    if args.reasoning_effort.strip():
        effort = args.reasoning_effort.strip()
        cmd.extend(["--config", f'model_reasoning_effort="{effort}"'])
    cmd.append("-")
    return cmd


def print_status(prefix: str, status: TodoStatus) -> None:
    print(
        "{} pending={} active={} done={} failed={} unfinished={}".format(
            prefix,
            status.pending,
            status.active,
            status.done,
            status.failed,
            status.unfinished,
        ),
        flush=True,
    )


def validate_status(status: TodoStatus) -> int:
    if status.invalid:
        details = ", ".join(f"line {lineno} [{state}]" for lineno, state in status.invalid)
        print(f"error: invalid checkbox states: {details}", file=sys.stderr)
        return 2

    if status.uppercase_done:
        lines = ", ".join(str(lineno) for lineno in status.uppercase_done)
        print(f"error: [X] should be normalized to [x]: {lines}", file=sys.stderr)
        return 2

    return 0


def run_codex_round(cmd: list[str], prompt: str) -> int:
    completed = subprocess.run(cmd, input=prompt, text=True, check=False)
    return completed.returncode


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    todo_path = Path(args.todo)
    if not todo_path.is_absolute():
        todo_path = root / todo_path
    todo_display = os.path.relpath(todo_path, root)

    cmd = build_codex_command(args, root)

    if args.dry_run:
        try:
            lines = read_todo_lines(todo_path)
        except FileNotFoundError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 2

        status = read_todo_status_from_lines(lines)
        status_error = validate_status(status)
        if status_error:
            return status_error

        context = build_todo_context(
            lines,
            args.context_lines,
            args.max_excerpt_line_chars,
        )
        prompt = build_prompt(todo_display, args.skill, status, context)
        print("command:", " ".join(cmd))
        print()
        print(prompt)
        return 0

    rounds = 0
    while True:
        try:
            lines = read_todo_lines(todo_path)
        except FileNotFoundError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 2

        status = read_todo_status_from_lines(lines)
        print_status("todo:", status)
        status_error = validate_status(status)
        if status_error:
            return status_error

        if status.unfinished == 0:
            print("done: no unfinished todo tasks remain")
            return 0

        if status.failed and not args.continue_after_failed:
            print(
                "error: failed [f] tasks remain; fix them or rerun with "
                "--continue-after-failed",
                file=sys.stderr,
            )
            return 2

        if status.runnable == 0:
            print("error: no runnable [ ] or [~] tasks remain", file=sys.stderr)
            return 2

        if args.max_rounds > 0 and rounds >= args.max_rounds:
            print(f"stopped: reached --max-rounds={args.max_rounds}")
            return 3

        context = build_todo_context(
            lines,
            args.context_lines,
            args.max_excerpt_line_chars,
        )
        prompt = build_prompt(todo_display, args.skill, status, context)

        rounds += 1
        print(f"round {rounds}: running {' '.join(cmd)}", flush=True)
        if context.item is not None:
            print(
                "round {}: target L{} [{}] {}".format(
                    rounds,
                    context.item.lineno,
                    context.item.state,
                    context.item.text,
                ),
                flush=True,
            )
        returncode = run_codex_round(cmd, prompt)
        if returncode != 0:
            print(f"error: codex round {rounds} exited with {returncode}", file=sys.stderr)
            return returncode


if __name__ == "__main__":
    raise SystemExit(main())
