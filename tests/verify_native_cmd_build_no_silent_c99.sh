#!/usr/bin/env bash

# Phase 10：防止 --native 未接入时静默回落到 C99，并让 cmd/build self-build
# 从 hosted CoreBody/PortableMIR preflight 开始，而不是回到 freestanding LoweredProgram 特例。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-native-cmd-build-no-silent-c99.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

run_hosted_reject_check() {
    local compiler="$1"
    local label="$2"
    local out="$TMP_DIR/${label}.bin"
    local stdout="$TMP_DIR/${label}.out"
    local stderr="$TMP_DIR/${label}.err"

    set +e
    "$compiler" build "$REPO_ROOT/tests/test_native_main_only.uya" \
        -o "$out" --native --no-split-c --project-root "$REPO_ROOT/src/" \
        >"$stdout" 2>"$stderr"
    local status=$?
    set -e

    if [[ "$status" -eq 0 ]]; then
        echo "错误: $label --native 不应静默成功" >&2
        exit 1
    fi
    if [[ -e "$out" ]]; then
        echo "错误: $label --native 未接入时不应生成输出文件: $out" >&2
        exit 1
    fi
    if ! grep -q '后端类型: Native' "$stderr"; then
        echo "错误: $label --native 未进入 native BackendType" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if ! grep -Eq 'native_hosted_coreir_preflight: status=0 verifier_error=0 functions=[1-9][0-9]* core_bodies=[0-9]+ pending_bodies=[1-9][0-9]*' "$stderr"; then
        echo "错误: $label --native 缺少 hosted CoreIR function inventory preflight 证据" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if ! grep -Eq 'native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=[1-9][0-9]* mir_body_functions=[0-9]+ mir_types=[1-9][0-9]* extern_symbols=[1-9][0-9]* c_import_objects=0 hosted_link_objects=0' "$stderr"; then
        echo "错误: $label --native 缺少 hosted PortableMIR preflight 证据" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if ! grep -q 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' "$stderr"; then
        echo "错误: $label --native 缺少函数体 MIR lowering 缺口诊断" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if ! grep -q 'build-seed LoweredProgram helper 仅限 --nostdlib freestanding 子集' "$stderr"; then
        echo "错误: $label --native 未排除 build-seed helper" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q '后端类型: C99' "$stderr"; then
        echo "错误: $label --native 被静默回落到了 C99" >&2
        exit 1
    fi
}

run_cmd_build_self_preflight_check() {
    local compiler="$1"
    local label="$2"
    local out="$TMP_DIR/${label}.bin"
    local stdout="$TMP_DIR/${label}.out"
    local stderr="$TMP_DIR/${label}.err"

    set +e
    "$compiler" build "$REPO_ROOT/src/cmd/build/main.uya" \
        -o "$out" --native --no-split-c --project-root "$REPO_ROOT/src/" \
        >"$stdout" 2>"$stderr"
    local status=$?
    set -e

    if [[ "$status" -eq 0 ]]; then
        echo "错误: $label --native 当前不应伪报告 native cmd/build self-build 完成" >&2
        exit 1
    fi
    if [[ -e "$out" ]]; then
        echo "错误: $label --native self-build preflight 失败时不应留下输出文件: $out" >&2
        exit 1
    fi
    grep -Eq '输入文件数量: [1-9][0-9]*' "$stderr"
    grep -q 'src/cmd/build/main.uya' "$stderr"
    grep -q '后端类型: Native' "$stderr"
    grep -q '类型检查通过' "$stderr"
    grep -q '=== 代码生成阶段 ===' "$stderr"
    grep -Eq 'native_hosted_coreir_preflight: status=0 verifier_error=0 functions=[1-9][0-9]* core_bodies=28 pending_bodies=[1-9][0-9]*' "$stderr"
    grep -Eq 'native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=[1-9][0-9]* mir_body_functions=27 mir_types=[1-9][0-9]* extern_symbols=[1-9][0-9]* c_import_objects=0 hosted_link_objects=0' "$stderr"
    grep -q 'native_hosted_entry_frontier: wrapper_covered=1 first_pending_callee=build_compiler_driver_run first_pending_callee_prefix=1 first_pending_callee_prefix_stmts=39 first_pending_callee_next_stmt=-1 first_pending_callee_next_kind=<none>' "$stderr"
    grep -q 'native_hosted_entry_child_frontier: first_pending_callee=build_compiler_driver_run parent_stmt=37 child_prefix=1 child_prefix_stmts=7 child_next_stmt=-1 child_next_kind=<none>' "$stderr"
    grep -q 'native_hosted_reachable_body_complete: function=parse_build_args prefix_stmts=28 reason=body_complete' "$stderr"
    if grep -q 'native_hosted_reachable_callee_frontier: parent=build_compiler_driver_run stmt=17 first_unresolved_callee=set_process_stack_limit_bytes reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 stack-limit helper 首切片迁入后继续报告 set_process_stack_limit_bytes pending callee" >&2
        cat "$stderr" >&2
        exit 1
    fi
    grep -Eq 'native_hosted_pending_body_frontier: function=native_build_type_is_usize .*reason=pending_core_body' "$stderr"
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_type_is_i32 .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_type_is_i32 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_reachability_init .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_reachability_init 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_local_table_init .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_local_table_init 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_simd_vector_mask_shape_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_simd_vector_mask_shape_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_atomic_i32_shape_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_atomic_i32_shape_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_struct_union_enum_shape_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_struct_union_enum_shape_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_direct_method_shape_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_direct_method_shape_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_interface_method_shape_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_interface_method_shape_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_lexical_drop_shape_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_lexical_drop_shape_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_defer_local_assign_shape_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_defer_local_assign_shape_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_dynamic_catch_shape_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_dynamic_catch_shape_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_pointer_deref_shape_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_pointer_deref_shape_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_const_slice_len_index_shape_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_const_slice_len_index_shape_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_const_slice_sum_shape_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_const_slice_sum_shape_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_local_table_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_local_table_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_reachability_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_reachability_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_lowered_plan_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_lowered_plan_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_empty_vector .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_empty_vector struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=native_build_ast_plan_empty .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 native_build_ast_plan_empty struct literal return 迁入后继续报告 pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=3 next_stmt=3 next_kind=AST_CALL_EXPR reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 diagnostic profile tail fprintf 迁入后继续报告 prefix_stmts=3" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 diagnostic profile checker branch 迁入后继续报告 prefix_stmts=2" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compiler_print_diagnostic_profile prefix_stmts=1 next_stmt=1 next_kind=AST_VAR_DECL reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 diagnostic profile count local 迁入后继续报告 prefix_stmts=1" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_hosted_pending_body_frontier: function=compiler_print_diagnostic_profile .*reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 diagnostic profile print guard 迁入后继续报告整个 helper pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=3 next_stmt=3 next_kind=return reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 profile diagnostics tail return 迁入后继续报告 prefix_stmts=3" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 profile diagnostics false-like branch 迁入后继续报告 prefix_stmts=2" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=1 next_stmt=1 next_kind=AST_IF_STMT reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 profile diagnostics null/empty branch 迁入后继续报告 prefix_stmts=1" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_pending_body_frontier: function=compiler_should_profile_diagnostics' "$stderr"; then
        echo "错误: $label self-build 不应在 profile diagnostics 首切片迁入后继续报告整个 helper pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=17 next_stmt=17 next_kind=AST_ASSIGN reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 compile_stats released-bytes 迁入后继续报告 prefix_stmts=17" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=16 next_stmt=16 next_kind=AST_CALL_EXPR reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 compile_stats typed_type_records release 迁入后继续报告 prefix_stmts=16" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=15 next_stmt=15 next_kind=AST_CALL_EXPR reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 compile_stats typed_program_release 迁入后继续报告 prefix_stmts=15" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=14 next_stmt=14 next_kind=AST_ASSIGN reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 compile_stats table_realloc_count 迁入后继续报告 prefix_stmts=14" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=13 next_stmt=13 next_kind=AST_ASSIGN reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 compile_stats table_capacity_bytes 迁入后继续报告 prefix_stmts=13" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=12 next_stmt=12 next_kind=AST_ASSIGN reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 compile_stats table_used_bytes 迁入后继续报告 prefix_stmts=12" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=11 next_stmt=11 next_kind=AST_ASSIGN reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 compile_stats table_capacity 迁入后继续报告 prefix_stmts=11" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=10 next_stmt=10 next_kind=AST_ASSIGN reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 compile_stats table_items 迁入后继续报告 prefix_stmts=10" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=9 next_stmt=9 next_kind=AST_CALL_EXPR reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 compile_stats typed_program aggregate 迁入后继续报告 prefix_stmts=9" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=8 next_stmt=8 next_kind=AST_CALL_EXPR reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 compile_stats semantic_db aggregate 迁入后继续报告 prefix_stmts=8" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=7 next_stmt=7 next_kind=AST_VAR_DECL reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 compile_stats table_agg 迁入后继续报告 prefix_stmts=7" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=6 next_stmt=6 next_kind=AST_ASSIGN reason=partial_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 compile_stats peak-bytes 迁入后继续报告 prefix_stmts=6" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_pending_body_frontier: function=compile_stats_record_and_release_typed_program decl=159 function_id=4 body_stmts=18 reason=pending_core_body' "$stderr"; then
        echo "错误: $label self-build 不应在 compile_stats 首切片迁入后继续报告整个 helper pending" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_callee_frontier: parent=build_compiler_driver_run stmt=12 first_unresolved_callee=parse_build_args' "$stderr"; then
        echo "错误: $label self-build 不应在 parse_build_args complete 后继续报告 parse_build_args pending callee" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'native_hosted_reachable_tail_branch_frontier: function=parse_build_args' "$stderr"; then
        echo "错误: $label self-build 不应在 parse_build_args complete 后继续报告 tail branch frontier" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q 'covered_branch=positional-input next_branch=parse-tail-input-count' "$stderr"; then
        echo "错误: $label self-build 不应停留在位置输入后的 tail 首分支 frontier" >&2
        cat "$stderr" >&2
        exit 1
    fi
    grep -Eq 'native_hosted_handoff_frontier: reason=pending_core_bodies mir_body_functions=[1-9][0-9]* extern_symbols=[1-9][0-9]* pending_bodies=[1-9][0-9]* entry_callee_coverage=complete entry_child_coverage=complete' "$stderr"
    grep -Eq 'native_hosted_emitter_handoff: status=rejected reason=pending_core_bodies request_verified=1 backend=machine link_plan=complete link_objects=0 extern_symbols=[1-9][0-9]* entry_child_coverage=complete' "$stderr"
    grep -Eq 'native_hosted_emitter_import_preflight: status=ready imported_functions=[1-9][0-9]* imported_blocks=[1-9][0-9]* imported_insts=[0-9]+ pending_bodies=[1-9][0-9]*' "$stderr"
    grep -Eq 'native_hosted_emitter_output_preflight: status=ready output_matches_request=1 output_kind=machine_module machine_functions=[1-9][0-9]* pending_bodies=[1-9][0-9]*' "$stderr"
    grep -Eq 'native_hosted_executable_writer_plan: status=blocked can_write=0 output_kind=machine_module machine_module=attached link_plan=complete link_objects=0 c_import_objects=0 pending_bodies=[1-9][0-9]*' "$stderr"
    grep -Eq 'native_hosted_executable_writer_preflight: status=blocked reason=pending_core_bodies output_kind=machine_module machine_functions=[1-9][0-9]* link_plan=complete link_objects=0 c_import_objects=0 pending_bodies=[1-9][0-9]*' "$stderr"
    grep -q 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' "$stderr"
    grep -q 'build-seed LoweredProgram helper 仅限 --nostdlib freestanding 子集' "$stderr"
    if grep -q 'native_hosted_portable_mir_preflight_failed' "$stderr" ||
       grep -q 'COREIR_VERIFY_ERR_INVALID_BODY_RANGE' "$stderr"; then
        echo "错误: $label self-build CoreIR/PortableMIR preflight 应为 verifier-clean" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native_unsupported_(call_expr|fn_body|fn_shape)' "$stderr"; then
        echo "错误: $label self-build 不应再落回 pre-MIR freestanding shape 诊断" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -Eq 'native backend.*LoweredProgram.*机器码' "$stderr"; then
        echo "错误: $label self-build 不应再使用 freestanding LoweredProgram 机器码缺口" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if grep -q '后端类型: C99' "$stderr"; then
        echo "错误: $label --native 生成 cmd/build 时被静默回落到了 C99" >&2
        exit 1
    fi
}

run_hosted_reject_check "$REPO_ROOT/bin/uya" "uya"
run_hosted_reject_check "$REPO_ROOT/bin/cmd/build" "cmd-build"
run_cmd_build_self_preflight_check "$REPO_ROOT/bin/cmd/build" "cmd-build-self"

echo "verify_native_cmd_build_no_silent_c99: ok"
