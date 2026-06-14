#!/usr/bin/env bash
#
# MIR-C99 self-build must expose an explicit host compiler binary attempt gate.
# Until the compiler candidate is real, the gate must still compile the emitted
# C with the host compiler and report the next compiler-source frontier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"
CMD_BUILD_SOURCE="$REPO_ROOT/src/cmd/build/main.uya"
TMP_DIR="$(mktemp -d /tmp/uya-mir-c99-cmd-build-host-binary.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing MIR-C99 cmd/build host binary attempt evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

output_c="$TMP_DIR/cmd-build-mir.c"
log_file="$TMP_DIR/cmd-build-mir.log"
summary_file="${output_c}.summary"
candidate_bin="$TMP_DIR/cmd-build-mir-candidate"
candidate_stdout="$TMP_DIR/candidate.out"
candidate_stderr="$TMP_DIR/candidate.err"

"$GENERATOR" "$CMD_BUILD_SOURCE" "$output_c" "$log_file" >/dev/null

cc -std=c99 -Wall -Wextra -pedantic "$output_c" -o "$candidate_bin"

set +e
"$candidate_bin" --help >"$candidate_stdout" 2>"$candidate_stderr"
run_status=$?
set -e

if [[ "$run_status" -ne 70 ]]; then
    echo "error: summary-only compiler candidate should report not-yet-generated with exit 70, got $run_status" >&2
    cat "$candidate_stdout" >&2
    cat "$candidate_stderr" >&2
    exit 1
fi

require_pattern "$log_file" '^host_compiler_binary_attempt=1$' \
    "diagnostic log records the host compiler binary attempt gate"
require_pattern "$log_file" '^host_compiler_binary_status=not_yet_generated$' \
    "diagnostic log records the current non-compiler status"
require_pattern "$log_file" '^host_compiler_binary_candidate_role=summary_executable$' \
    "diagnostic log distinguishes summary executable from compiler binary"
require_pattern "$log_file" '^completed_body_detail=native_hosted_reachable_body_complete:function=native_build_reachability_init,prefix_stmts=12,reason=body_complete$' \
    "diagnostic log records the completed reachability_init helper body"
require_pattern "$log_file" '^completed_coverage=generic_corebody_reachability_init_body_lowering$' \
    "diagnostic log records the migrated reachability_init body lowering"
require_pattern "$log_file" '^frontier_detail=native_hosted_pending_body_frontier:function=native_build_type_is_i32,decl=[0-9]+,function_id=[0-9]+,body_stmts=3,reason=pending_core_body$' \
    "diagnostic log preserves the next compiler-source frontier"
require_pattern "$log_file" '^next_coverage=generic_corebody_type_is_i32_body_lowering$' \
    "diagnostic log records the next generic type_is_i32 slice"
require_pattern "$summary_file" '^MIR_C99_HOST_COMPILER_BINARY_ATTEMPT=1$' \
    "summary sidecar records host compiler binary attempt"
require_pattern "$summary_file" '^MIR_C99_HOST_COMPILER_BINARY_STATUS='\''not_yet_generated'\''' \
    "summary sidecar records non-compiler candidate status"
require_pattern "$summary_file" '^MIR_C99_HOST_COMPILER_BINARY_CANDIDATE_ROLE='\''summary_executable'\''' \
    "summary sidecar records summary executable candidate role"
require_pattern "$candidate_stderr" '^compiler_binary_status=not_yet_generated$' \
    "candidate executable reports that it is not a compiler binary"
require_pattern "$candidate_stderr" '^frontier_name=native_hosted_handoff_frontier$' \
    "candidate executable reports the current self-build frontier"

if grep -Eq 'native_hosted_reachable_body_frontier:function=compiler_print_diagnostic_profile|^completed_coverage=compiler_print_diagnostic_profile_checker_branch$|^next_coverage=compiler_print_diagnostic_profile_tail_fprintf$|^MIR_C99_COMPLETED_COVERAGE='\''compiler_print_diagnostic_profile_checker_branch'\''$|^MIR_C99_NEXT_COVERAGE='\''compiler_print_diagnostic_profile_tail_fprintf'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old print diagnostic profile tail frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq 'native_hosted_pending_body_frontier:function=build_driver_run|^completed_coverage=compiler_print_diagnostic_profile_tail_fprintf$|^next_coverage=build_driver_run_first_slice$|^MIR_C99_COMPLETED_COVERAGE='\''compiler_print_diagnostic_profile_tail_fprintf'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_first_slice'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run pending frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=12,next_stmt=12,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_first_slice$|^next_coverage=build_driver_run_parse_prefix$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=12,next_stmt=12,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_first_slice'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_parse_prefix'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run first-slice frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=15,next_stmt=15,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_parse_prefix$|^next_coverage=build_driver_run_stack_init$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=15,next_stmt=15,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_parse_prefix'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_stack_init'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run parse-prefix frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=16,next_stmt=16,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_stack_init$|^next_coverage=build_driver_run_stack_guard$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=16,next_stmt=16,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_stack_init'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_stack_guard'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run stack-init frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=17,next_stmt=17,next_kind=AST_CALL_EXPR,reason=partial_core_body$|^completed_coverage=build_driver_run_stack_guard$|^next_coverage=build_driver_run_stack_limit_call$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=17,next_stmt=17,next_kind=AST_CALL_EXPR,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_stack_guard'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_stack_limit_call'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run stack-limit-call frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=18,next_stmt=18,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_stack_limit_call$|^next_coverage=build_driver_run_split_env$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=18,next_stmt=18,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_stack_limit_call'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_env'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run split-env frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=19,next_stmt=19,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_split_env$|^next_coverage=build_driver_run_output_path$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=19,next_stmt=19,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_env'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_output_path'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run output-path frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=20,next_stmt=20,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_output_path$|^next_coverage=build_driver_run_user_output_path$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=20,next_stmt=20,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_output_path'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_user_output_path'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run user-output-path frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=21,next_stmt=21,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_user_output_path$|^next_coverage=build_driver_run_explicit_output_path$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=21,next_stmt=21,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_user_output_path'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_explicit_output_path'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run explicit-output-path frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=22,next_stmt=22,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_explicit_output_path$|^next_coverage=build_driver_run_llvm_backend_c99_rewrite$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=22,next_stmt=22,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_explicit_output_path'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_llvm_backend_c99_rewrite'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run LLVM backend rewrite frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=23,next_stmt=23,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_llvm_backend_c99_rewrite$|^next_coverage=build_driver_run_split_c_default$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=23,next_stmt=23,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_llvm_backend_c99_rewrite'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_c_default'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run split-C default frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=24,next_stmt=24,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_split_c_default$|^next_coverage=build_driver_run_output_path_for_compile$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=24,next_stmt=24,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_c_default'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_output_path_for_compile'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run output-path-for-compile frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=25,next_stmt=25,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_output_path_for_compile$|^next_coverage=build_driver_run_output_path_selection$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=25,next_stmt=25,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_output_path_for_compile'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_output_path_selection'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run output-path-selection frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=26,next_stmt=26,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_output_path_selection$|^next_coverage=build_driver_run_split_c_arg$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=26,next_stmt=26,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_output_path_selection'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_c_arg'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run split_c_arg frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=27,next_stmt=27,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_split_c_arg$|^next_coverage=build_driver_run_split_c_arg_assign$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=27,next_stmt=27,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_c_arg'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_c_arg_assign'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run split_c_arg_assign frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=28,next_stmt=28,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_split_c_arg_assign$|^next_coverage=build_driver_run_artifacts$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=28,next_stmt=28,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_c_arg_assign'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_artifacts'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run artifacts frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=29,next_stmt=29,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_artifacts$|^next_coverage=build_driver_run_split_c_lock$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=29,next_stmt=29,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_artifacts'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_c_lock'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run split_c_lock frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=30,next_stmt=30,next_kind=AST_DEFER_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_split_c_lock$|^next_coverage=build_driver_run_split_c_lock_defer$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=30,next_stmt=30,next_kind=AST_DEFER_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_c_lock'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_c_lock_defer'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run split_c_lock_defer frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=31,next_stmt=31,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_split_c_lock_defer$|^next_coverage=build_driver_run_split_c_lock_acquire$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=31,next_stmt=31,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_c_lock_defer'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_c_lock_acquire'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run split_c_lock_acquire frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=32,next_stmt=32,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_split_c_lock_acquire$|^next_coverage=build_driver_run_compile_result$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=32,next_stmt=32,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_c_lock_acquire'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_compile_result'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run compile_result frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=33,next_stmt=33,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_compile_result$|^next_coverage=build_driver_run_result_error$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=33,next_stmt=33,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_compile_result'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_result_error'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run result_error frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=34,next_stmt=34,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_result_error$|^next_coverage=build_driver_run_native_success$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=34,next_stmt=34,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_result_error'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_native_success'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run native_success frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eiq 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' \
    "$log_file" "$summary_file" "$output_c" "$candidate_stdout" "$candidate_stderr"; then
    echo "error: MIR-C99 host binary attempt mentioned legacy C99 fallback" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    cat "$output_c" >&2
    cat "$candidate_stdout" >&2
    cat "$candidate_stderr" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=35,next_stmt=35,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_native_success$|^next_coverage=build_driver_run_is_output_c_file$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=35,next_stmt=35,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_native_success'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_is_output_c_file'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run is_output_c_file frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=36,next_stmt=36,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_is_output_c_file$|^next_coverage=build_driver_run_c_output_check$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=36,next_stmt=36,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_is_output_c_file'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_c_output_check'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run C output check frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=38,next_stmt=38,next_kind=AST_RETURN_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_link_output$|^next_coverage=build_driver_run_final_return$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=38,next_stmt=38,next_kind=AST_RETURN_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_link_output'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_final_return'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still reports the old build_driver_run final return frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^next_coverage=native_build_decl_is_extern_two_i32_param_fn_first_slice$|^MIR_C99_NEXT_COVERAGE='\''native_build_decl_is_extern_two_i32_param_fn_first_slice'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 host binary attempt still treats the current helper sample as the next coverage goal" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

echo "OK: MIR-C99 cmd/build host compiler binary attempt gate records summary-only frontier"
