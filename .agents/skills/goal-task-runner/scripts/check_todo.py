#!/usr/bin/env python3
"""Check todo checkbox status hygiene for goal-task-runner."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


CHECKBOX_RE = re.compile(r"^(?P<prefix>\s*[-*]\s*)\[(?P<state>[^\]])\](?P<rest>.*)$")
VALID_STATES = {" ", "x", "~", "f"}


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate todo checkbox statuses.")
    parser.add_argument("todo", type=Path, help="Path to the todo markdown file")
    parser.add_argument(
        "--allow-multiple-active",
        action="store_true",
        help="Allow more than one [~] item",
    )
    args = parser.parse_args()

    if not args.todo.exists():
        print(f"error: todo file not found: {args.todo}", file=sys.stderr)
        return 2

    active = []
    invalid = []
    uppercase_done = []

    for lineno, line in enumerate(args.todo.read_text(encoding="utf-8").splitlines(), 1):
        match = CHECKBOX_RE.match(line)
        if not match:
            continue
        state = match.group("state")
        if state == "X":
            uppercase_done.append(lineno)
        normalized = state.lower()
        if normalized not in VALID_STATES:
            invalid.append((lineno, state))
        if normalized == "~":
            active.append(lineno)

    errors = []
    if invalid:
        errors.append(
            "invalid checkbox states: "
            + ", ".join(f"line {lineno} [{state}]" for lineno, state in invalid)
        )
    if uppercase_done:
        errors.append("[X] should be normalized to [x]: " + ", ".join(map(str, uppercase_done)))
    if len(active) > 1 and not args.allow_multiple_active:
        errors.append("multiple active [~] tasks: " + ", ".join(map(str, active)))

    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1

    print(
        f"ok: {args.todo} has {len(active)} active task"
        + ("s" if len(active) != 1 else "")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
