#!/usr/bin/env bash

# Phase 9：聚合 native backend v1 的首批 smoke 回归。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

run_step() {
    echo "==> $*"
    (cd "$REPO_ROOT" && "$@")
}

run_uya_test() {
    local test_file="$1"
    run_step ./bin/uya test "$test_file" --no-split-c --project-root src/
}

run_uya_test tests/test_native_main_only.uya
run_uya_test tests/test_native_int_ops.uya
run_uya_test tests/test_native_function_call.uya
run_uya_test tests/test_native_struct_field.uya
run_uya_test tests/test_native_error_union.uya
run_uya_test tests/test_native_error_defer_control.uya
run_uya_test tests/test_native_global_init.uya
run_uya_test tests/test_native_struct_array_slice_ops.uya
run_uya_test tests/test_native_memory_string_primitives.uya
run_uya_test tests/test_native_hash_intern_memory_ops.uya
run_uya_test tests/test_native_dynamic_table_ops.uya
run_uya_test tests/test_native_diagnostic_output.uya
run_uya_test tests/test_native_file_io.uya
run_uya_test tests/test_native_format_minimal.uya
run_uya_test tests/test_native_malloc_arena.uya
run_uya_test tests/test_native_arena_peak_stats.uya
run_uya_test tests/test_native_generic_instances.uya

run_step bash tests/verify_native_abi_contract.sh
run_step bash tests/verify_native_sysv_calling_convention.sh
run_step bash tests/verify_native_stack_frame_layout.sh
run_step bash tests/verify_native_conservative_regalloc.sh
run_step bash tests/verify_native_x86_64_encoding.sh
run_step bash tests/verify_native_x86_64_int_ptr_instructions.sh
run_step bash tests/verify_native_x86_64_call_instructions.sh
run_step bash tests/verify_native_error_defer_control.sh
run_step bash tests/verify_native_elf64_encoding.sh
run_step bash tests/verify_native_main_facade.sh
run_step bash tests/verify_native_nostdlib_start.sh
run_step bash tests/verify_native_syscall_bridge.sh
run_step bash tests/verify_native_global_data_segment.sh
run_step bash tests/verify_native_string_constants.sh
run_step bash tests/verify_native_struct_array_slice_ops.sh
run_step bash tests/verify_native_memory_string_primitives.sh
run_step bash tests/verify_native_hash_intern_memory_ops.sh
run_step bash tests/verify_native_dynamic_table_ops.sh
run_step bash tests/verify_native_diagnostic_output.sh
run_step bash tests/verify_native_file_io.sh
run_step bash tests/verify_native_format_minimal.sh
run_step bash tests/verify_native_malloc_arena.sh
run_step bash tests/verify_native_arena_peak_stats.sh
run_step bash tests/verify_native_generic_instances.sh
run_step bash tests/verify_native_reloc_symbol_table.sh
run_step bash tests/verify_native_machine_ir.sh
run_step bash tests/verify_native_output_policy.sh
run_step bash tests/verify_native_emitter_lowered_program.sh
run_step bash tests/verify_native_emitter_streaming_output.sh
run_step bash tests/verify_native_mir_emitter.sh
run_step bash tests/verify_native_build_minimal_program.sh

echo "✓ native backend smoke verified"
