#!/usr/bin/env python3

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent.parent
LOWER = ROOT / "src/lower/async.uya"
FUNCTION = ROOT / "src/codegen/c99/function.uya"
TRANSFORM = ROOT / "src/codegen/c99/async_transform.uya"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"{label}: missing `{needle}`")


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"{label}: still contains forbidden `{needle}`")


def main() -> int:
    lower_text = LOWER.read_text(encoding="utf-8")
    function_text = FUNCTION.read_text(encoding="utf-8")
    transform_text = TRANSFORM.read_text(encoding="utf-8")

    require(lower_text, "export struct AsyncLowerAwaitPoint", "src/lower/async.uya")
    require(lower_text, "export struct AsyncLowerPlan", "src/lower/async.uya")
    require(lower_text, "export fn async_lower_build_plan", "src/lower/async.uya")
    require(lower_text, "export fn async_lower_stmt_contains_await", "src/lower/async.uya")
    require(lower_text, "export fn async_lower_find_first_try_await_expr", "src/lower/async.uya")

    forbid(function_text, "fn collect_awaits_recursive(", "src/codegen/c99/function.uya")
    forbid(function_text, "fn c99_find_first_try_await_expr(", "src/codegen/c99/function.uya")
    require(function_text, "async_lower_build_plan(", "src/codegen/c99/function.uya")

    require(transform_text, "use lower.async;", "src/codegen/c99/async_transform.uya")
    forbid(transform_text, "export struct AwaitPoint", "src/codegen/c99/async_transform.uya")
    forbid(transform_text, "export fn async_collect_all_awaits(", "src/codegen/c99/async_transform.uya")
    forbid(transform_text, "export fn stmt_contains_await(", "src/codegen/c99/async_transform.uya")
    require(transform_text, "export fn async_transform_stmt_contains_await(", "src/codegen/c99/async_transform.uya")
    require(transform_text, "return async_lower_stmt_contains_await(node);", "src/codegen/c99/async_transform.uya")

    print("verify_async_lowering_plan_architecture: centralized async lowering plan confirmed")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"verify_async_lowering_plan_architecture: {exc}", file=sys.stderr)
        raise SystemExit(1)
