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
    return parser.parse_args()


def read_todo_status(todo_path: Path) -> TodoStatus:
    if not todo_path.exists():
        raise FileNotFoundError(f"todo file not found: {todo_path}")

    pending = active = done = failed = 0
    invalid: list[tuple[int, str]] = []
    uppercase_done: list[int] = []

    for lineno, line in enumerate(todo_path.read_text(encoding="utf-8").splitlines(), 1):
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


def skill_mention(skill: str) -> str:
    stripped = skill.strip()
    if not stripped:
        raise ValueError("skill name must not be empty")
    if stripped.startswith("$"):
        return stripped
    return f"${stripped}"


def build_prompt(todo_display: str, skill: str) -> str:
    mention = skill_mention(skill)
    return f"""请使用 `{mention}` skill 执行指定 todo 文件的下一轮任务。

Todo 文件：`{todo_display}`

执行要求：
- 严格遵守仓库 `AGENTS.md` 和 `{mention}` 的规则。
- 本轮只推进一个任务：优先继续已有 `[~]`，否则选择文档顺序中的第一个可执行 `[ ]` 叶子任务。
- 如果任务过大或含糊，先在 todo 中拆成可执行的小任务，并只启动第一个小任务。
- 完成后写入真实验证命令和结果，再把任务标成 `[x]`；无法恢复时标成 `[f]` 并记录原因。
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
    prompt = build_prompt(todo_display, args.skill)

    if args.dry_run:
        print("command:", " ".join(cmd))
        print()
        print(prompt)
        return 0

    rounds = 0
    while True:
        try:
            status = read_todo_status(todo_path)
        except FileNotFoundError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 2

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

        rounds += 1
        print(f"round {rounds}: running {' '.join(cmd)}", flush=True)
        returncode = run_codex_round(cmd, prompt)
        if returncode != 0:
            print(f"error: codex round {rounds} exited with {returncode}", file=sys.stderr)
            return returncode


if __name__ == "__main__":
    raise SystemExit(main())
