#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_check() {
    local script="$1"
    if [[ ! -x "$script" && ! -f "$script" ]]; then
        echo "错误: 缺少 LoweredProgram closure 验证脚本: $script" >&2
        exit 1
    fi
    bash "$script"
}

run_check "$SCRIPT_DIR/verify_lowered_program_core_definition.sh"
run_check "$SCRIPT_DIR/verify_lowered_body_op_transition_contract.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_core_semantics_freeze.sh"
run_check "$SCRIPT_DIR/verify_coreir_verifier.sh"
run_check "$SCRIPT_DIR/verify_coreir_capability_boundary_contract.sh"
run_check "$SCRIPT_DIR/verify_coreir_naked_fn_contract.sh"
run_check "$SCRIPT_DIR/verify_coreir_parallel_boundary_contract.sh"
run_check "$SCRIPT_DIR/verify_coreir_c99_oracle_boundary.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_worklist_roots.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_generic_function_closure.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_nested_generic_call.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_generic_method_closure.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_generic_struct_closure.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_interface_method_closure.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_err_union_closure.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_nested_err_union_closure.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_async_frame_closure.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_drop_defer_closure.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_runtime_helper_closure.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_stable_sort.sh"
run_check "$SCRIPT_DIR/verify_lowered_program_debug_dump.sh"
run_check "$SCRIPT_DIR/verify_coreir_dump_env.sh"
run_check "$SCRIPT_DIR/verify_coreir_dump_golden.sh"

echo "✓ LoweredProgram closure aggregate verified"
