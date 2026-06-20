#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"
MODE="${1:-all}"

case "$MODE" in
    all|native|c99|uya-c99)
        ;;
    *)
        echo "usage: $0 [all|native|c99|uya-c99]"
        exit 2
        ;;
esac

if [ ! -x "$COMPILER" ]; then
    echo "missing compiler: $COMPILER"
    echo "hint: run 'make uya' first"
    exit 1
fi

run_uya_test() {
    local rel="$1"
    shift
    local args=("$@")
    local log
    log="$(mktemp)"
    echo "==> uya test ${args[*]} $rel"
    if ! "$COMPILER" test "${args[@]}" "$REPO_ROOT/$rel" >"$log" 2>&1; then
        echo "uya test failed: $rel"
        cat "$log"
        rm -f "$log"
        exit 1
    fi
    rm -f "$log"
}

expect_check_fail() {
    local rel="$1"
    local pattern="$2"
    shift 2
    local args=("$@")
    local log
    log="$(mktemp)"
    if "$COMPILER" check "${args[@]}" "$REPO_ROOT/$rel" >"$log" 2>&1; then
        echo "expected checker failure but succeeded: $rel"
        cat "$log"
        rm -f "$log"
        exit 1
    fi
    if ! grep -Fq "$pattern" "$log"; then
        echo "missing expected diagnostic for $rel: $pattern"
        cat "$log"
        rm -f "$log"
        exit 1
    fi
    rm -f "$log"
}

expect_compile_fail() {
    local rel="$1"
    local pattern="$2"
    local work_dir
    local log
    work_dir="$(mktemp -d)"
    log="$(mktemp)"
    if (cd "$work_dir" && UYA_ROOT="$UYA_ROOT" "$COMPILER" --c99 --safety-proof "$REPO_ROOT/$rel") >"$log" 2>&1; then
        echo "expected compile failure but succeeded: $rel"
        cat "$log"
        rm -rf "$work_dir"
        rm -f "$log"
        exit 1
    fi
    if ! grep -Fq "$pattern" "$log"; then
        echo "missing expected compile diagnostic for $rel: $pattern"
        cat "$log"
        rm -rf "$work_dir"
        rm -f "$log"
        exit 1
    fi
    rm -rf "$work_dir"
    rm -f "$log"
}

run_macro_combo() {
    local args=("$@")
    local macro_log
    macro_log="$(mktemp)"
    if ! (
        cd "$REPO_ROOT"
        UYA_ROOT="$UYA_ROOT" "$COMPILER" run "${args[@]}" "tests/programs/test_ai_prompt_async_macro_combo.uya" >"$macro_log" 2>&1
    ); then
        echo "macro combo build/run failed"
        cat "$macro_log"
        rm -f "$macro_log"
        exit 1
    fi
    rm -f "$macro_log"
}

# 当前已存在、且对 async 语法主链路最有代表性的回归。
# 这组通过只能证明“当前已覆盖的子集仍成立”，不能证明完整语法已完成。
baseline_tests=(
    "tests/test_async_await_parse.uya"
    "tests/test_async_fn_basic.uya"
    "tests/test_async_await.uya"
    "tests/test_async_await_ready.uya"
    "tests/test_async_multiple_await.uya"
    "tests/test_async_state_machine.uya"
    "tests/test_async_large_state_machine_syntax.uya"
    "tests/test_async_if_await.uya"
    "tests/test_async_else_if_await.uya"
    "tests/test_async_for_await.uya"
    "tests/test_async_while_multi_await.uya"
    "tests/test_async_bug_a_two_while.uya"
    "tests/test_async_bug_b_sync_between.uya"
    "tests/test_async_bug_d_nested_block.uya"
    "tests/test_async_await_direct_err_union.uya"
    "tests/test_async_return_error_direct.uya"
    "tests/test_async_compound_try_await.uya"
    "tests/test_async_catch_await.uya"
    "tests/test_async_defer_errdefer.uya"
    "tests/test_async_cleanup_body_coverage.uya"
    "tests/test_async_fn_multi_segment_unwrap.uya"
    "tests/test_async_await_limits_and_segments.uya"
    "tests/test_async_sync_body_matrix.uya"
    "tests/test_async_method_interface.uya"
    "tests/test_async_local_interface_await.uya"
    "tests/test_async_nested.uya"
    "tests/test_async_macro_expand.uya"
    "tests/test_async_frame_inline_temp.uya"
    "tests/test_async_frame_inline_temp2.uya"
    "tests/test_async_fn_local_fixed_array.uya"
    "tests/test_async_codegen_edge_paths.uya"
    "tests/test_std_async_scheduler.uya"
    "tests/test_async_compute_types.uya"
    "tests/test_http1_async_client.uya"
)

run_baseline_matrix() {
    local label="$1"
    shift
    local args=("$@")

    echo "==> async baseline matrix ($label)"

    for test_file in "${baseline_tests[@]}"; do
        run_uya_test "$test_file" "${args[@]}"
    done

    # 规范明确禁止的 @await 位置，必须继续保持失败。
    expect_check_fail "tests/error_await_outside_async.uya" "@await 只能在 @async_fn 函数内使用" "${args[@]}"
    expect_check_fail "tests/error_await_in_future_returning_non_async.uya" "@await 只能在 @async_fn 函数内使用" "${args[@]}"
    expect_check_fail "tests/error_async_await_in_while_cond.uya" "@async_fn 状态机结构验证失败" "${args[@]}"
    expect_check_fail "tests/error_async_await_in_return.uya" "@async_fn 状态机结构验证失败" "${args[@]}"
    expect_check_fail "tests/error_async_defer_return.uya" "defer/errdefer 块中不能使用 return 语句" "${args[@]}"
    expect_check_fail "tests/error_async_errdefer_break.uya" "defer/errdefer 块中不能使用 break 语句" "${args[@]}"
    expect_check_fail "tests/error_async_defer_continue_nested.uya" "defer/errdefer 块中不能使用 continue 语句" "${args[@]}"
    expect_check_fail "tests/error_async_for_iterator_interface_await.uya" "接口类型变量的 for 迭代目前不支持；请使用具体实现迭代器类型" "${args[@]}"

    # 2026-06-18: struct 迭代器 ref 绑定现已支持，转为正向回归。
    run_uya_test "tests/test_async_for_iterator_ref_await.uya" "${args[@]}"

    # 宏展开 async lowering 程序级回归
    echo "==> test_ai_prompt_async_macro_combo build/run ($label)"
    run_macro_combo "${args[@]}"
}

run_c99_extended_matrix() {
    local label="$1"
    shift
    local driver_args=("$@")

    echo "==> verify_async_await_capacity ($label)"
    UYA_COMPILER="$COMPILER" bash "$SCRIPT_DIR/verify_async_await_capacity.sh" "${driver_args[@]}" >/dev/null

    echo "==> verify_async_nested_future_boundary ($label)"
    UYA_COMPILER="$COMPILER" bash "$SCRIPT_DIR/verify_async_nested_future_boundary.sh" "${driver_args[@]}" >/dev/null

    echo "==> verify_async_shared_runtime_matrix ($label)"
    UYA_COMPILER="$COMPILER" bash "$SCRIPT_DIR/verify_async_shared_runtime_matrix.sh" "${driver_args[@]}" >/dev/null
}

if [ "$MODE" = "all" ] || [ "$MODE" = "native" ]; then
    run_baseline_matrix "native"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "c99" ]; then
    run_baseline_matrix "c99" "--c99"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "uya-c99" ]; then
    run_baseline_matrix "uya-c99" "--uya" "--c99"
fi

if [ "$MODE" = "native" ]; then
    echo "verify_async_full_language_matrix: native baseline passed"
    exit 0
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "c99" ]; then
    run_c99_extended_matrix "c99"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "uya-c99" ]; then
    run_c99_extended_matrix "uya-c99" "--uya"
fi

if [ "$MODE" = "c99" ]; then
    echo "verify_async_full_language_matrix: C99 baseline, iterator for boundaries, forbidden @await positions, nested future boundary, shared runtime matrix, and macro combo passed"
    exit 0
fi

if [ "$MODE" = "uya-c99" ]; then
    echo "verify_async_full_language_matrix: --uya --c99 baseline, iterator for boundaries, forbidden @await positions, nested future boundary, shared runtime matrix, and macro combo passed"
    exit 0
fi

echo "verify_async_full_language_matrix: native baseline, C99 baseline, --uya --c99 baseline, iterator for boundaries, forbidden @await positions, nested future boundary, shared runtime matrix, and macro combo passed"
