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
require_pattern "$log_file" '^completed_coverage=generic_corebody_pointer_param_guard_tail_return_lowering$' \
    "log records the migrated generic pointer-param guard-call tail return"
require_pattern "$log_file" '^completed_body_detail=native_hosted_reachable_body_complete:function=native_build_decl_is_one_i32_ptr_param_fn,prefix_stmts=5,reason=body_complete$' \
    "log records the completed one-i32-pointer helper body"
require_pattern "$log_file" '^frontier_detail=native_hosted_pending_body_frontier:function=native_build_decl_is_two_i32_ptr_param_fn,decl=402,function_id=43,body_stmts=7,reason=pending_core_body$' \
    "log records the next compiler-source pending body frontier"
require_pattern "$log_file" '^next_capability=corebody_portable_mir_body_lowering$' \
    "log records the next capability to expand"
require_pattern "$log_file" '^next_coverage=generic_corebody_two_pointer_param_guard_tail_return_lowering$' \
    "log records the next generic coverage slice"

require_pattern "$summary_file" "^MIR_C99_SELF_BUILD_FRONTIER='native_hosted_handoff_frontier'$" \
    "summary sidecar records the current handoff frontier"
require_pattern "$summary_file" "^MIR_C99_FRONTIER_CATEGORY='mir_instruction_coverage'$" \
    "summary sidecar records the general MIR-C99 gap category"
require_pattern "$summary_file" "^MIR_C99_COMPLETED_COVERAGE='generic_corebody_pointer_param_guard_tail_return_lowering'$" \
    "summary sidecar records the migrated generic pointer-param guard-call tail return"
require_pattern "$summary_file" "^MIR_C99_COMPLETED_BODY_DETAIL='native_hosted_reachable_body_complete:function=native_build_decl_is_one_i32_ptr_param_fn,prefix_stmts=5,reason=body_complete'$" \
    "summary sidecar records the completed one-i32-pointer helper body"
require_pattern "$summary_file" "^MIR_C99_FRONTIER_DETAIL='native_hosted_pending_body_frontier:function=native_build_decl_is_two_i32_ptr_param_fn,decl=402,function_id=43,body_stmts=7,reason=pending_core_body'$" \
    "summary sidecar records the concrete compiler-source pending body frontier"
require_pattern "$summary_file" "^MIR_C99_NEXT_CAPABILITY='corebody_portable_mir_body_lowering'$" \
    "summary sidecar records the next capability"
require_pattern "$summary_file" "^MIR_C99_NEXT_COVERAGE='generic_corebody_two_pointer_param_guard_tail_return_lowering'$" \
    "summary sidecar records the next generic coverage slice"

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
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_split_c_arg.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run split_c_arg local"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_split_c_arg_assign.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run split_c_arg assignment branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_artifacts.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run artifacts local"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_split_c_lock.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run split_c_lock local"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_split_c_lock_defer.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run split_c_lock_defer cleanup"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_split_c_lock_acquire.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run split_c_lock_acquire branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_compile_result.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run compile_result call"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_result_error.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run result_error branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_native_success.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run native_success branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_is_output_c_file.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run is_output_c_file local"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_c_output_check.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run C output check branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*build_driver_run_link_output.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run link output branch"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*generic_corebody_guard_call_tail_return_lowering.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated build_driver_run final return"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*generic_corebody_pointer_param_guard_tail_return_lowering.*已纳入 CoreBody -> PortableMIR lowering' \
    "coverage matrix records the migrated pointer-param helper slice"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*generic_corebody_two_pointer_param_guard_tail_return_lowering' \
    "coverage matrix records the next generic coverage slice"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*不得新增按 helper 名称或固定 7-stmt body shape 命中的 materializer' \
    "coverage matrix rejects helper-specific materializer direction"
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
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_c_arg_stmt_supported' \
    "build driver recognizes the build_driver_run split_c_arg local"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_c_arg_prefix_stmt_count' \
    "build driver exposes the split_c_arg slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_SPLIT_C_ARG_PREFIX_STMT_COUNT' \
    "build driver admits the split_c_arg prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_split_c_arg' \
    "build driver lowers the split_c_arg local through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'split_c_arg_inst' \
    "build driver materializes the split_c_arg null initializer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_c_arg_assign_stmt_supported' \
    "build driver recognizes the build_driver_run split_c_arg assignment branch"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_c_arg_assign_prefix_stmt_count' \
    "build driver exposes the split_c_arg assignment slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_SPLIT_C_ARG_ASSIGN_PREFIX_STMT_COUNT' \
    "build driver admits the split_c_arg assignment prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_split_c_arg_assign' \
    "build driver lowers the split_c_arg assignment branch through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'split_c_arg_assign_inst' \
    "build driver materializes the split_c_arg assignment"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_artifacts_stmt_supported' \
    "build driver recognizes the build_driver_run artifacts local"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_artifacts_prefix_stmt_count' \
    "build driver exposes the artifacts slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_ARTIFACTS_PREFIX_STMT_COUNT' \
    "build driver admits the artifacts prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_artifacts' \
    "build driver lowers the artifacts local through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'artifacts_inst' \
    "build driver materializes the artifacts aggregate initializer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_c_lock_stmt_supported' \
    "build driver recognizes the build_driver_run split_c_lock local"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_c_lock_prefix_stmt_count' \
    "build driver exposes the split_c_lock slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_SPLIT_C_LOCK_PREFIX_STMT_COUNT' \
    "build driver admits the split_c_lock prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_split_c_lock' \
    "build driver lowers the split_c_lock local through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'split_c_lock_inst' \
    "build driver materializes the split_c_lock zero initializer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_c_lock_defer_parts' \
    "build driver recognizes the build_driver_run split_c_lock_defer cleanup shape"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_c_lock_defer_stmt_supported' \
    "build driver validates the split_c_lock_defer cleanup slice"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_c_lock_defer_prefix_stmt_count' \
    "build driver exposes the split_c_lock_defer slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_SPLIT_C_LOCK_DEFER_PREFIX_STMT_COUNT' \
    "build driver admits the split_c_lock_defer prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_split_c_lock_defer' \
    "build driver lowers the split_c_lock_defer cleanup through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'split_c_lock_defer_inst' \
    "build driver materializes the split_c_lock_defer cleanup MIR marker"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_c_lock_acquire_parts' \
    "build driver recognizes the build_driver_run split_c_lock_acquire shape"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_split_c_lock_acquire_prefix_stmt_count' \
    "build driver exposes the split_c_lock_acquire slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_SPLIT_C_LOCK_ACQUIRE_PREFIX_STMT_COUNT' \
    "build driver admits the split_c_lock_acquire prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_split_c_lock_acquire' \
    "build driver lowers the split_c_lock_acquire branch through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'split_c_lock_acquire_inst' \
    "build driver materializes the split_c_lock_acquire MIR marker"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_result_call_expr' \
    "build driver recognizes the build_driver_run compile_result call"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_result_prefix_stmt_count' \
    "build driver exposes the compile_result slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_COMPILE_RESULT_PREFIX_STMT_COUNT' \
    "build driver admits the compile_result prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_compile_result' \
    "build driver lowers the compile_result call through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'compile_result_inst' \
    "build driver materializes the compile_result MIR marker"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_result_error_prefix_stmt_count' \
    "build driver recognizes the build_driver_run result_error branch"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_RESULT_ERROR_PREFIX_STMT_COUNT' \
    "build driver admits the result_error prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_result_error' \
    "build driver lowers the result_error branch through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'result_error_cond_inst' \
    "build driver materializes the result_error condition MIR marker"
require_pattern "$BUILD_DRIVER_SRC" 'result_error_return_inst' \
    "build driver materializes the result_error return MIR marker"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_native_success_fprintf_call' \
    "build driver recognizes the build_driver_run native_success fprintf call"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_native_success_prefix_stmt_count' \
    "build driver exposes the native_success slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_NATIVE_SUCCESS_PREFIX_STMT_COUNT' \
    "build driver admits the native_success prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_native_success' \
    "build driver lowers the native_success branch through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'native_success_fprintf_inst' \
    "build driver materializes the native_success fprintf MIR marker"
require_pattern "$BUILD_DRIVER_SRC" 'native_success_return_inst' \
    "build driver materializes the native_success return MIR marker"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_is_output_c_file_prefix_stmt_count' \
    "build driver exposes the is_output_c_file slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_IS_OUTPUT_C_FILE_PREFIX_STMT_COUNT' \
    "build driver admits the is_output_c_file prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_is_output_c_file' \
    "build driver lowers the is_output_c_file local through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'is_output_c_file_inst' \
    "build driver materializes the is_output_c_file zero initializer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_c_output_check_prefix_stmt_count' \
    "build driver exposes the C output check slice to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_C_OUTPUT_CHECK_PREFIX_STMT_COUNT' \
    "build driver admits the C output check prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_c_output_check' \
    "build driver lowers the C output check branch through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'c_output_check_cond_inst' \
    "build driver materializes the C output check condition"
require_pattern "$BUILD_DRIVER_SRC" 'c_output_check_after_block' \
    "build driver materializes the C output check control-flow blocks"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_build_driver_run_link_output_prefix_stmt_count' \
    "build driver exposes the link output branch to prefix lowering"
require_pattern "$BUILD_DRIVER_SRC" 'NATIVE_BUILD_DRIVER_RUN_LINK_OUTPUT_PREFIX_STMT_COUNT' \
    "build driver admits the link output branch prefix count"
require_pattern "$BUILD_DRIVER_SRC" 'include_link_output' \
    "build driver lowers the link output branch through the MIR prefix path"
require_pattern "$BUILD_DRIVER_SRC" 'link_output_cond_inst' \
    "build driver materializes the link output condition"
require_pattern "$BUILD_DRIVER_SRC" 'link_output_after_block' \
    "build driver materializes the link output control-flow blocks"

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

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=26,next_stmt=26,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_output_path_selection$|^next_coverage=build_driver_run_split_c_arg$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=26,next_stmt=26,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_output_path_selection'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_c_arg'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run split_c_arg frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=27,next_stmt=27,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_split_c_arg$|^next_coverage=build_driver_run_split_c_arg_assign$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=27,next_stmt=27,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_c_arg'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_c_arg_assign'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run split_c_arg_assign frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=28,next_stmt=28,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_split_c_arg_assign$|^next_coverage=build_driver_run_artifacts$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=28,next_stmt=28,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_c_arg_assign'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_artifacts'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run artifacts frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=29,next_stmt=29,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_artifacts$|^next_coverage=build_driver_run_split_c_lock$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=29,next_stmt=29,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_artifacts'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_c_lock'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run split_c_lock frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=30,next_stmt=30,next_kind=AST_DEFER_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_split_c_lock$|^next_coverage=build_driver_run_split_c_lock_defer$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=30,next_stmt=30,next_kind=AST_DEFER_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_c_lock'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_c_lock_defer'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run split_c_lock_defer frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=31,next_stmt=31,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_split_c_lock_defer$|^next_coverage=build_driver_run_split_c_lock_acquire$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=31,next_stmt=31,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_c_lock_defer'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_split_c_lock_acquire'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run split_c_lock_acquire frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=32,next_stmt=32,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_split_c_lock_acquire$|^next_coverage=build_driver_run_compile_result$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=32,next_stmt=32,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_split_c_lock_acquire'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_compile_result'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run compile_result frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=33,next_stmt=33,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_compile_result$|^next_coverage=build_driver_run_result_error$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=33,next_stmt=33,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_compile_result'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_result_error'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run result_error frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=34,next_stmt=34,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_result_error$|^next_coverage=build_driver_run_native_success$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=34,next_stmt=34,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_result_error'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_native_success'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run native_success frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=35,next_stmt=35,next_kind=AST_VAR_DECL,reason=partial_core_body$|^completed_coverage=build_driver_run_native_success$|^next_coverage=build_driver_run_is_output_c_file$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=35,next_stmt=35,next_kind=AST_VAR_DECL,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_native_success'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_is_output_c_file'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run is_output_c_file frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=36,next_stmt=36,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_is_output_c_file$|^next_coverage=build_driver_run_c_output_check$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=36,next_stmt=36,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_is_output_c_file'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_c_output_check'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run C output check frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=37,next_stmt=37,next_kind=AST_IF_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_c_output_check$|^next_coverage=build_driver_run_link_output$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=37,next_stmt=37,next_kind=AST_IF_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_c_output_check'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_link_output'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run link output frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^frontier_detail=native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=38,next_stmt=38,next_kind=AST_RETURN_STMT,reason=partial_core_body$|^completed_coverage=build_driver_run_link_output$|^next_coverage=build_driver_run_final_return$|^MIR_C99_FRONTIER_DETAIL='\''native_hosted_reachable_body_frontier:function=build_driver_run,prefix_stmts=38,next_stmt=38,next_kind=AST_RETURN_STMT,reason=partial_core_body'\''$|^MIR_C99_COMPLETED_COVERAGE='\''build_driver_run_link_output'\''$|^MIR_C99_NEXT_COVERAGE='\''build_driver_run_final_return'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still reports the old build_driver_run final return frontier" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

if grep -Eq '^next_coverage=native_build_decl_is_extern_two_i32_param_fn_first_slice$|^MIR_C99_NEXT_COVERAGE='\''native_build_decl_is_extern_two_i32_param_fn_first_slice'\''$' \
    "$log_file" "$summary_file"; then
    echo "error: MIR-C99 cmd/build frontier summary still treats the current helper sample as the next coverage goal" >&2
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
