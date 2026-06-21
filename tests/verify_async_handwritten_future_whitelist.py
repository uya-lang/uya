#!/usr/bin/env python3

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parent.parent
STD_ROOT = ROOT / "lib/std"
FUTURE_IMPL_RE = re.compile(r"^(?:export\s+)?struct\s+([A-Za-z0-9_]+)[^\n]*:\s+Future<", re.MULTILINE)

EXPECTED_BY_FILE = {
    "lib/std/async.uya": [
        "Future",
        "Task",
        "AsyncWaitFdFuture",
    ],
    "lib/std/thread.uya": [
        "AsyncThreadSlotWaitFuture",
        "AsyncWorkerSubmitFuture",
        "AsyncWorkerResultFuture",
        "AsyncWorkerCancelFuture",
        "AsyncWorkerComputeFuture",
    ],
}


def collect_future_impls(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    return FUTURE_IMPL_RE.findall(text)


def main() -> int:
    actual_by_file: dict[str, list[str]] = {}
    for path in sorted(STD_ROOT.rglob("*.uya")):
        matches = collect_future_impls(path)
        if matches:
            actual_by_file[path.relative_to(ROOT).as_posix()] = matches

    if set(actual_by_file) != set(EXPECTED_BY_FILE):
        unexpected_files = sorted(set(actual_by_file) - set(EXPECTED_BY_FILE))
        missing_files = sorted(set(EXPECTED_BY_FILE) - set(actual_by_file))
        problems: list[str] = []
        if unexpected_files:
            rendered = ", ".join(f"{path}: {actual_by_file[path]}" for path in unexpected_files)
            problems.append(f"unexpected files with hand-written Future impls: {rendered}")
        if missing_files:
            rendered = ", ".join(missing_files)
            problems.append(f"missing expected runtime whitelist files: {rendered}")
        raise AssertionError("; ".join(problems))

    for rel, expected in EXPECTED_BY_FILE.items():
        actual = actual_by_file[rel]
        if actual != expected:
            raise AssertionError(f"{rel}: expected {expected}, got {actual}")

    print("verify_async_handwritten_future_whitelist: runtime shell and substrate whitelist confirmed")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"verify_async_handwritten_future_whitelist: {exc}", file=sys.stderr)
        raise SystemExit(1)
