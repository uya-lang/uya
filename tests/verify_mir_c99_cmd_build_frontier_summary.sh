#!/usr/bin/env bash
#
# MIR-C99 cmd/build summary must name the first compiler-source frontier and
# map it to a general MIR-C99 coverage gap.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"
CMD_BUILD_SOURCE="$REPO_ROOT/src/cmd/build/main.uya"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
COVERAGE_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"
TMP_DIR="$(mktemp -d /tmp/uya-mir-c99-cmd-build-frontier.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing MIR-C99 cmd/build frontier evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

output_c="$TMP_DIR/cmd-build-mir.c"
log_file="$TMP_DIR/cmd-build-mir.log"
summary_file="${output_c}.summary"

"$GENERATOR" "$CMD_BUILD_SOURCE" "$output_c" "$log_file" >/dev/null

require_pattern "$log_file" '^frontier_kind=compiler_source$' \
    "log marks the frontier as a real compiler-source frontier"
require_pattern "$log_file" '^frontier_name=native_hosted_handoff_frontier$' \
    "log records the current hosted handoff frontier"
require_pattern "$log_file" '^frontier_reason=pending_core_bodies$' \
    "log records the precise pending-core-body reason"
require_pattern "$log_file" '^frontier_category=mir_instruction_coverage$' \
    "log maps the frontier to a general MIR instruction coverage gap"
require_pattern "$log_file" '^completed_coverage=build_driver_run_output_path_selection$' \
    "log records the migrated build_driver_run output path selection branch"
require_pattern "$log_file" '^completed_body_detail=native_hosted_reachable_body_complete:function=compiler_print_diagnostic_profile,prefix_stmts=4,reason=body_complete$' \
    "log records the completed print diagnostic profile body"
require_pattern "$log_file" '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=26,next_stmt=26,next_kind=AST_VAR_DECL,reason=partial_core_body$' \
    "log records the next build_driver_run source body frontier"
require_pattern "$log_file" '^next_capability=corebody_portable_mir_body_lowering$' \
    "log records the next capability to expand"
require_pattern "$log_file" '^next_coverage=build_driver_run_split_c_arg$' \
    "log records the next coverage slice"

require_pattern "$summary_file" "^MIR_C99_SELF_BUILD_FRONTIER='native_hosted_handoff_frontier'$" \
    "summary sidecar records the current handoff frontier"
require_pattern "$summary_file" "^MIR_C99_FRONTIER_CATEGORY='mir_instruction_coverage'$" \
    "summary sidecar records the general MIR-C99 gap category"
require_pattern "$summary_file" "^MIR_C99_COMPLETED_COVERAGE='build_driver_run_output_path_selection'$" \
    "summary sidecar records the migrated build_driver_run output path selection branch"
require_pattern "$summary_file" "^MIR_C99_COMPLETED_BODY_DETAIL='native_hosted_reachable_body_complete:function=compiler_print_diagnostic_profile,prefix_stmts=4,reason=body_complete'$" \
    "summary sidecar records the completed print diagnostic profile body"
require_pattern "$summary_file" "^MIR_C99_FRONTIER_DETAIL='native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=26,next_stmt=26,next_kind=AST_VAR_DECL,reason=partial_core_body'$" \
    "summary sidecar records the concrete compiler-source body frontier"
require_pattern "$summary_file" "^MIR_C99_NEXT_CAPABILITY='corebody_portable_mir_body_lowering'$" \
    "summary sidecar records the next capability"
require_pattern "$summary_file" "^MIR_C99_NEXT_COVERAGE='build_driver_run_split_c_arg'$" \
    "summary sidecar records the next coverage slice"

require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*native_hosted_handoff_frontier' \
    "coverage matrix records the current self-build frontier"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*mir_instruction_coverage' \
    "coverage matrix records the general MIR-C99 gap category"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*compile_stats_record_and_release_typed_program_stmt16_typed_type_records_release.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated typed_type_records_release slice"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*compile_stats_record_and_release_typed_program_stmt17_typed_program_released_bytes.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated released-bytes slice"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*compiler_should_profile_diagnostics_first_slice.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated profile diagnostics first slice"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*compiler_should_profile_diagnostics_null_empty_branch.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated profile diagnostics null/empty branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*compiler_should_profile_diagnostics_false_like_branch.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated profile diagnostics false-like branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*compiler_should_profile_diagnostics_tail_return.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated profile diagnostics tail return"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*compiler_print_diagnostic_profile_guard.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated print diagnostic profile guard"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*compiler_print_diagnostic_profile_count.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated print diagnostic profile count"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*compiler_print_diagnostic_profile_checker_branch.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated print diagnostic profile checker branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*compiler_print_diagnostic_profile_tail_fprintf.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated print diagnostic profile tail fprintf"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_first_slice.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run first slice"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_parse_prefix.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run parse prefix"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_stack_init.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run stack init"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_stack_guard.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run stack guard"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_stack_limit_call.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run stack limit call"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_split_env.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run split env branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_output_path.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run output path branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_user_output_path.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run user output path local"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_explicit_output_path.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run explicit output path branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_llvm_backend_c99_rewrite.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run LLVM backend C99 rewrite branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_split_c_default.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run split-C default branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_output_path_for_compile.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run output path for compile local"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_output_path_selection.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run output path selection branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_split_c_arg' \
    "coverage matrix records the next coverage slice"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_decl_can_materialize_build_driver_run_entry_prefix_body' \
    "build driver recognizes the build_driver_run prefix body"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_coreir_append_build_driver_run_entry_prefix_body' \
    "build driver appends the build_driver_run prefix body as CoreBody"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_mir_append_build_driver_run_entry_prefix_body_function' \
    "build driver lowers the build_driver_run prefix body into PortableMIR"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_parse_prefix_stmt_count' \
    "build driver recognizes the build_driver_run parse prefix"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_mir_append_build_driver_run_parse_call_operands' \
    "build driver appends parse_build_args call operands"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_mir_append_build_driver_run_parse_prefix_control' \
    "build driver lowers the parse prefix control flow"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_stack_init_stmt_supported' \
    "build driver recognizes the build_driver_run stack init statement"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_stack_init_prefix_stmt_count' \
    "build driver exposes the stack init slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_STACK_INIT_PREFIX_STMT_COUNT' \
    "build driver admits the stack init prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_stack_guard_stmt_supported' \
    "build driver recognizes the build_driver_run stack guard statement"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_stack_guard_prefix_stmt_count' \
    "build driver exposes the stack guard slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_STACK_GUARD_PREFIX_STMT_COUNT' \
    "build driver admits the stack guard prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_stack_limit_stmt_supported' \
    "build driver recognizes the build_driver_run stack limit call statement"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_stack_limit_prefix_stmt_count' \
    "build driver exposes the stack limit call slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_STACK_LIMIT_PREFIX_STMT_COUNT' \
    "build driver admits the stack limit call prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_stack_limit_call' \
    "build driver lowers the stack limit call through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'stack_limit_call_inst' \
    "build driver materializes the stack limit call MIR instruction"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_env_stmt_supported' \
    "build driver recognizes the build_driver_run split env statement"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_env_prefix_stmt_count' \
    "build driver exposes the split env slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_SPLIT_ENV_PREFIX_STMT_COUNT' \
    "build driver admits the split env prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_split_env' \
    "build driver lowers the split env branch through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'getenv_call_inst' \
    "build driver materializes the getenv call for split env lowering"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_output_path_stmt_supported' \
    "build driver recognizes the build_driver_run output path statement"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_output_path_prefix_stmt_count' \
    "build driver exposes the output path slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_OUTPUT_PATH_PREFIX_STMT_COUNT' \
    "build driver admits the output path prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_output_path' \
    "build driver lowers the output path branch through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'host_fill_temp_c_compile_path' \
    "build driver materializes the temporary C output path call"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_user_output_path_stmt_supported' \
    "build driver recognizes the build_driver_run user output path local"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_user_output_path_prefix_stmt_count' \
    "build driver exposes the user output path slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_USER_OUTPUT_PATH_PREFIX_STMT_COUNT' \
    "build driver admits the user output path prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_user_output_path' \
    "build driver lowers the user output path local through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'user_output_path_inst' \
    "build driver materializes the user output path null initializer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_explicit_output_path_stmt_supported' \
    "build driver recognizes the build_driver_run explicit output path branch"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_explicit_output_path_prefix_stmt_count' \
    "build driver exposes the explicit output path slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_EXPLICIT_OUTPUT_PREFIX_STMT_COUNT' \
    "build driver admits the explicit output path prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_explicit_output_path' \
    "build driver lowers the explicit output path branch through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'get_argv_call_inst' \
    "build driver materializes the get_argv call for explicit output path lowering"
require_pattern "$BUILD_DRIVER_SRC" 'out_path_cond_inst' \
    "build driver materializes the out_path null guard for explicit output path lowering"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_llvm_fallback_stmt_supported' \
    "build driver recognizes the build_driver_run LLVM backend C99 rewrite branch"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_llvm_fallback_prefix_stmt_count' \
    "build driver exposes the LLVM backend C99 rewrite slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_LLVM_FALLBACK_PREFIX_STMT_COUNT' \
    "build driver admits the LLVM backend C99 rewrite prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_backend_fallback' \
    "build driver lowers the LLVM backend C99 rewrite branch through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'backend_fallback_assign_inst' \
    "build driver materializes the backend C99 rewrite assignment"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_c_default_stmt_supported' \
    "build driver recognizes the build_driver_run split-C default branch"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_c_default_prefix_stmt_count' \
    "build driver exposes the split-C default slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_SPLIT_C_DEFAULT_PREFIX_STMT_COUNT' \
    "build driver admits the split-C default prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_split_c_default' \
    "build driver lowers the split-C default branch through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'split_c_default_cond_inst' \
    "build driver materializes the split-C default condition"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_output_path_for_compile_stmt_supported' \
    "build driver recognizes the build_driver_run output path for compile local"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_output_path_for_compile_prefix_stmt_count' \
    "build driver exposes the output path for compile slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_OUTPUT_PATH_FOR_COMPILE_PREFIX_STMT_COUNT' \
    "build driver admits the output path for compile prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_output_path_for_compile' \
    "build driver lowers the output path for compile local through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'output_path_for_compile_inst' \
    "build driver materializes the output path for compile null initializer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_output_selection_stmt_supported' \
    "build driver recognizes the build_driver_run output path selection branch"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_output_selection_prefix_stmt_count' \
    "build driver exposes the output path selection slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_OUTPUT_PATH_SELECTION_PREFIX_STMT_COUNT' \
    "build driver admits the output path selection prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_output_path_selection' \
    "build driver lowers the output path selection branch through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'output_path_selection_get_argv_inst' \
    "build driver materializes the output path selection get_argv call"

tail_mir_body="$(
    awk '
        /^fn native_build_hosted_mir_append_print_diagnostic_profile_tail_body_function/ {
            in_fn = 1
            depth = 0
            seen_open = 0
        }
        in_fn {
            print
            opens = gsub(/\{/, "{")
            closes = gsub(/\}/, "}")
            if (opens > 0) {
                seen_open = 1
            }
            depth += opens - closes
        }
        in_fn && seen_open == 1 && depth == 0 {
            exit
        }
    ' "$BUILD_DRIVER_SRC"
)"
if grep -Eq 'return[[:space:]]+native_build_hosted_mir_append_print_diagnostic_profile_(guard|count|checker)_body_function' <<<"$tail_mir_body"; then
    echo "error: print diagnostic profile tail MIR lowering still delegates to an earlier MIR body" >&2
    exit 1
fi
if grep -q 'MIR_FUNCTION_FLAG_PARTIAL_BODY' <<<"$tail_mir_body"; then
    echo "error: print diagnostic profile tail MIR lowering still marks a completed body as partial" >&2
    exit 1
fi
if ! grep -q 'native_build_hosted_mir_append_print_diagnostic_profile_checker_body_function' <<<"$tail_mir_body" ||
   ! grep -q 'function.block_count != 5' <<<"$tail_mir_body" ||
   ! grep -q 'fprintf_call.expr_id' <<<"$tail_mir_body" ||
   ! grep -q 'MIR_INST_OP_CALL' <<<"$tail_mir_body" ||
   ! grep -q 'operand_count: 4' <<<"$tail_mir_body" ||
   ! grep -q 'MIR_TERMINATOR_KIND_RETURN' <<<"$tail_mir_body"; then
    echo "error: print diagnostic profile tail MIR lowering does not materialize the tail fprintf call" >&2
    exit 1
fi

if grep -Eq 'native_hosted_reachable_body_frontier:function=compiler_print_diagnostic_profile|^completed_coverage=compiler_print_diagnostic_profile_checker_branch$|^next_coverage=compiler_print_diagnostic_profile_tail_fprintf$|^MIR_C99_COMPLETED_COVERAGE='\''compiler_print_diagnostic_profile_checker_branch'\''$|^MIR_C99_NEXT_COVERAGE='\''compiler_print_diagnostic_profile_tail_fprintf'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old print diagnostic profile tail frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq 'native_hosted_pending_body_frontier:function=build_driver_run|^completed_coverage=compiler_print_diagnostic_profile_tail_fprintf$|^next_coverage=build_driver_run_first_slice$|^MIR_C99_COMPLETED_COVERAGE='\''compiler_print_diagnostic_profile_tail_fprintf'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_first_slice'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run pending frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=12,next_stmt=12,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_first_slice$|^next_coverage=build_driver_run_parse_prefix$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=12,next_stmt=12,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_first_slice'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_parse_prefix'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run first-slice frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=15,next_stmt=15,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_parse_prefix$|^next_coverage=build_driver_run_stack_init$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=15,next_stmt=15,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_parse_prefix'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_stack_init'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run parse-prefix frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=16,next_stmt=16,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_stack_init$|^next_coverage=build_driver_run_stack_guard$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=16,next_stmt=16,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_stack_init'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_stack_guard'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run stack-init frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=17,next_stmt=17,next_kind=AST_CALL_EXPR,reason=partial_core_body$|^completed_coverage=build_driver_run_stack_guard$|^next_coverage=build_driver_run_stack_limit_call$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=17,next_stmt=17,next_kind=AST_CALL_EXPR,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_stack_guard'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_stack_limit_call'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run stack-limit-call frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=18,next_stmt=18,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_stack_limit_call$|^next_coverage=build_driver_run_split_env$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=18,next_stmt=18,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_stack_limit_call'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_env'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run split-env frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=19,next_stmt=19,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_split_env$|^next_coverage=build_driver_run_output_path$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=19,next_stmt=19,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_env'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_output_path'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run output-path frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=20,next_stmt=20,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_output_path$|^next_coverage=build_driver_run_user_output_path$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=20,next_stmt=20,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_output_path'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_user_output_path'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run user-output-path frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=21,next_stmt=21,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_user_output_path$|^next_coverage=build_driver_run_explicit_output_path$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=21,next_stmt=21,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_user_output_path'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_explicit_output_path'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run explicit-output-path frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=22,next_stmt=22,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_explicit_output_path$|^next_coverage=build_driver_run_llvm_backend_c99_rewrite$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=22,next_stmt=22,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_explicit_output_path'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_llvm_backend_c99_rewrite'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run LLVM backend rewrite frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=23,next_stmt=23,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_llvm_backend_c99_rewrite$|^next_coverage=build_driver_run_split_c_default$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=23,next_stmt=23,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_llvm_backend_c99_rewrite'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_c_default'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run split-C default frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=24,next_stmt=24,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_split_c_default$|^next_coverage=build_driver_run_output_path_for_compile$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=24,next_stmt=24,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_c_default'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_output_path_for_compile'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run output-path-for-compile frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=25,next_stmt=25,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_output_path_for_compile$|^next_coverage=build_driver_run_output_path_selection$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=25,next_stmt=25,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_output_path_for_compile'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_output_path_selection'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run output-path-selection frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

pending_body_function="$(
    awk '
        /^fn native_build_hosted_decl_has_pending_core_body/ {
            in_fn = 1
            depth = 0
            seen_open = 0
        }
        in_fn {
            print
            opens = gsub(/\{/, "{")
            closes = gsub(/\}/, "}")
            if (opens > 0) {
                seen_open = 1
            }
            depth += opens - closes
        }
        in_fn && seen_open == 1 && depth == 0 {
            exit
        }
    ' "$BUILD_DRIVER_SRC"
)"
if ! grep -q 'native_build_hosted_decl_can_materialize_build_driver_run_entry_prefix_body' <<<"$pending_body_function"; then
    echo "error: build_driver_run first slice is still classified as a pending core body" >&2
    exit 1
fi

if grep -Eiq 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' \
    "$log_file" "$summary_file" "$output_c"; then
    echo "error: MIR-C99 cmd/build frontier summary mentioned legacy C99 fallback" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

echo "OK: MIR-C99 cmd/build summary records the first self-build frontier"
