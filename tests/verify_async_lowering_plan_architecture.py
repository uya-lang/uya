#!/usr/bin/env python3

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent.parent
LOWER = ROOT / "src/lower/async.uya"
FUNCTION = ROOT / "src/codegen/c99/function.uya"
TRANSFORM = ROOT / "src/codegen/c99/async_transform.uya"
INTERNAL = ROOT / "src/codegen/c99/internal.uya"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"{label}: missing `{needle}`")


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"{label}: still contains forbidden `{needle}`")


def section(text: str, start: str, end: str, label: str) -> str:
    start_idx = text.find(start)
    if start_idx < 0:
        raise AssertionError(f"{label}: missing section start `{start}`")
    end_idx = text.find(end, start_idx)
    if end_idx < 0:
        raise AssertionError(f"{label}: missing section end `{end}`")
    return text[start_idx:end_idx]


def main() -> int:
    lower_text = LOWER.read_text(encoding="utf-8")
    function_text = FUNCTION.read_text(encoding="utf-8")
    transform_text = TRANSFORM.read_text(encoding="utf-8")
    internal_text = INTERNAL.read_text(encoding="utf-8")
    segment_text = section(
        function_text,
        "fn emit_async_segment(",
        "fn emit_async_continuation(",
        "src/codegen/c99/function.uya",
    )
    continuation_text = section(
        function_text,
        "fn emit_async_continuation(",
        "fn emit_async_no_await_ready_return(",
        "src/codegen/c99/function.uya",
    )

    require(lower_text, "export struct AsyncLowerAwaitPoint", "src/lower/async.uya")
    require(lower_text, "export struct AsyncLowerPlan", "src/lower/async.uya")
    require(lower_text, "export fn async_lower_build_plan", "src/lower/async.uya")
    require(lower_text, "export fn async_lower_stmt_contains_await", "src/lower/async.uya")
    require(lower_text, "export fn async_lower_find_first_try_await_expr", "src/lower/async.uya")
    require(lower_text, "source_stmt: &ASTNode", "src/lower/async.uya")
    require(lower_text, "split_try_expr: &ASTNode", "src/lower/async.uya")
    require(lower_text, "resume_state: i32", "src/lower/async.uya")
    require(lower_text, "terminal_state: i32", "src/lower/async.uya")
    require(lower_text, "prefix_stmt_count: i32", "src/lower/async.uya")

    forbid(function_text, "fn collect_awaits_recursive(", "src/codegen/c99/function.uya")
    forbid(function_text, "fn c99_find_first_try_await_expr(", "src/codegen/c99/function.uya")
    forbid(function_text, "fn c99_async_find_await_by_try_expr(", "src/codegen/c99/function.uya")
    forbid(function_text, "fn c99_async_root_stmt_index_of_first_await(", "src/codegen/c99/function.uya")
    forbid(function_text, "fn c99_async_prefix_stmt_count_before_first_await(", "src/codegen/c99/function.uya")
    require(function_text, "async_lower_build_plan(", "src/codegen/c99/function.uya")
    require(function_text, "async_plan.await_points[plan_i].source_stmt", "src/codegen/c99/function.uya")
    require(function_text, "async_plan.await_points[plan_i].split_try_expr", "src/codegen/c99/function.uya")
    require(function_text, "async_plan.await_points[plan_i].resume_state", "src/codegen/c99/function.uya")
    require(function_text, "async_plan.terminal_state", "src/codegen/c99/function.uya")
    require(function_text, "async_prefix_stmt_count = async_plan.prefix_stmt_count;", "src/codegen/c99/function.uya")
    forbid(function_text, "await_index + 1", "src/codegen/c99/function.uya")
    forbid(function_text, "codegen.async_collect_count + 1", "src/codegen/c99/function.uya")
    forbid(function_text, "await_count + 1", "src/codegen/c99/function.uya")
    forbid(segment_text, "async_lower_find_first_try_await_expr(", "emit_async_segment")
    forbid(continuation_text, "async_lower_find_first_try_await_expr(", "emit_async_continuation")

    require(internal_text, "async_collect_source_stmts: & & ASTNode", "src/codegen/c99/internal.uya")
    require(internal_text, "async_collect_split_try_exprs: & & ASTNode", "src/codegen/c99/internal.uya")
    require(internal_text, "async_collect_state_ids: &i32", "src/codegen/c99/internal.uya")
    require(internal_text, "async_collect_terminal_state: i32", "src/codegen/c99/internal.uya")

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
