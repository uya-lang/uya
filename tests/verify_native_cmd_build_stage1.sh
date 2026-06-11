#!/usr/bin/env bash

# Phase 10 stage1：统一验证 build-only --native 的真实成功子集，
# 并固定 native cmd/build 尚未自举时不能静默回落 C99。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/verify_native_build_minimal_program.sh"
bash "$SCRIPT_DIR/verify_native_cmd_build_compiler_regressions.sh"
bash "$SCRIPT_DIR/verify_native_cmd_build_c99_output_parity.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_first_slice_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_first_arg_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_option_loop_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_scalar_options_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_o_option_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_backend_options_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_line_directives_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_safety_proof_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_opt_level_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_nostdlib_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_project_root_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_seed_reject_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_stack_size_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_split_c_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_inputs_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_tail_contract.sh"
bash "$SCRIPT_DIR/verify_native_stack_limit_helper_contract.sh"
bash "$SCRIPT_DIR/verify_native_compile_stats_first_slice_contract.sh"
bash "$SCRIPT_DIR/verify_native_compile_stats_peak_bytes_contract.sh"
bash "$SCRIPT_DIR/verify_native_compile_stats_table_agg_contract.sh"
bash "$SCRIPT_DIR/verify_native_compile_stats_semantic_db_agg_contract.sh"
bash "$SCRIPT_DIR/verify_native_compile_stats_typed_program_agg_contract.sh"
bash "$SCRIPT_DIR/verify_native_compile_stats_table_items_contract.sh"
bash "$SCRIPT_DIR/verify_native_compile_stats_table_capacity_contract.sh"
bash "$SCRIPT_DIR/verify_native_compile_stats_table_used_bytes_contract.sh"
bash "$SCRIPT_DIR/verify_native_compile_stats_table_capacity_bytes_contract.sh"
bash "$SCRIPT_DIR/verify_native_compile_stats_table_realloc_count_contract.sh"
bash "$SCRIPT_DIR/verify_native_compile_stats_typed_program_release_contract.sh"
bash "$SCRIPT_DIR/verify_native_compile_stats_typed_type_records_release_contract.sh"
bash "$SCRIPT_DIR/verify_native_compile_stats_released_bytes_contract.sh"
bash "$SCRIPT_DIR/verify_native_profile_diagnostics_first_slice_contract.sh"
bash "$SCRIPT_DIR/verify_native_cmd_build_regression_boundary.sh"
bash "$SCRIPT_DIR/verify_native_cmd_build_no_silent_c99.sh"

echo "verify_native_cmd_build_stage1: ok"
