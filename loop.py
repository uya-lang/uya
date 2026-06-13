#!/usr/bin/env python3
"""Run Codex with a selected skill until a todo file has no unfinished tasks."""

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
            "Use `codex exec` with a specified skill to repeatedly execute one "
            "todo round, then stop when no unfinished checkbox remains."
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
        default="goal-task-runner",
        help="Codex skill name to request, with or without a leading '$'.",
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
        default=os.environ.get("CODEX_MODEL", ""),
        help="Optional model passed to `codex exec --model`.",
    )
    parser.add_argument(
        "--reasoning-effort",
        default=os.environ.get("CODEX_REASONING_EFFORT", ""),
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


def select_next_item(items: tuple[TodoItem, ...]) -> TodoItem | None:
    for item in items:
        if item.state == "~":
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
    mention = skill_mention(skill)
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
    return f"""请使用 `{mention}` skill 执行指定 todo 文件的下一轮任务。

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

执行要求：
- 严格遵守仓库 `AGENTS.md` 和 `{mention}` 的规则。
- 本轮只推进一个任务：优先继续已有 `[~]`，否则选择文档顺序中的第一个可执行 `[ ]` 叶子任务。
- 优先围绕上面的目标行工作；读取 todo 时使用小范围命令，例如 `sed -n '{range_hint}p' {todo_display}`，避免打印整份 todo 历史。
- 不要读取 `loop.log`；如确需排错，只读取短尾部，例如 `tail -n 200 loop.log`。
- 如果任务过大或含糊，先在 todo 中拆成可执行的小任务，并只启动第一个小任务。
- 完成后写入真实验证命令和结果，再把任务标成 `[x]`；随后将本轮完成的 `[x]` 任务及其验证记录移动到完成归档 `{archive_display}`。
- 无法恢复时写入失败原因、阻塞命令、关键错误和后续重开条件，再把任务标成 `[f]`；随后将本轮失败的 `[f]` 任务及其失败记录移动到失败归档 `{failed_archive_display}`。
- 如果某个父级 checkbox 的全部子任务都已完成，就把这个完整完成子树一起移入 `{archive_display}`；如果全部子任务都已失败或不可继续，就把这个失败子树一起移入 `{failed_archive_display}`。不要在主 todo 留下空的 `[ ]` 父项；主 todo 只保留 `[ ]`、`[~]` 和必要上下文。
- 验证记录保持简短，长日志只摘关键错误或路径。
- 按 skill 要求提交相关改动并尝试推送；不要暂存或回滚无关用户改动。
- 本轮结束后直接停止，不要自己启动下一轮循环；外层 `loop.py` 会重新检查 todo 状态。
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
