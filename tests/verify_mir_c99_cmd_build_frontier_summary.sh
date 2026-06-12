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
require_pattern "$log_file" '^frontier_detail=native_hosted_reachable_body_frontier:function=compile_stats_record_and_release_typed_program,prefix_stmts=13,next_stmt=13,next_kind=AST_ASSIGN,reason=partial_core_body$' \
    "log records the first concrete compiler-source body frontier"
require_pattern "$log_file" '^next_capability=corebody_portable_mir_body_lowering$' \
    "log records the next capability to expand"
require_pattern "$log_file" '^next_coverage=compile_stats_record_and_release_typed_program_stmt13_table_capacity_bytes$' \
    "log records the next coverage slice"

require_pattern "$summary_file" "^MIR_C99_SELF_BUILD_FRONTIER='native_hosted_handoff_frontier'$" \
    "summary sidecar records the current handoff frontier"
require_pattern "$summary_file" "^MIR_C99_FRONTIER_CATEGORY='mir_instruction_coverage'$" \
    "summary sidecar records the general MIR-C99 gap category"
require_pattern "$summary_file" "^MIR_C99_FRONTIER_DETAIL='native_hosted_reachable_body_frontier:function=compile_stats_record_and_release_typed_program,prefix_stmts=13,next_stmt=13,next_kind=AST_ASSIGN,reason=partial_core_body'$" \
    "summary sidecar records the concrete compiler-source body frontier"
require_pattern "$summary_file" "^MIR_C99_NEXT_CAPABILITY='corebody_portable_mir_body_lowering'$" \
    "summary sidecar records the next capability"
require_pattern "$summary_file" "^MIR_C99_NEXT_COVERAGE='compile_stats_record_and_release_typed_program_stmt13_table_capacity_bytes'$" \
    "summary sidecar records the next coverage slice"

require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*native_hosted_handoff_frontier' \
    "coverage matrix records the current self-build frontier"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*mir_instruction_coverage' \
    "coverage matrix records the general MIR-C99 gap category"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*compile_stats_record_and_release_typed_program_stmt13_table_capacity_bytes' \
    "coverage matrix records the next coverage slice"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_compile_stats_table_used_bytes_assign_supported' \
    "build driver recognizes the stmt12 table_used_bytes writeback"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_coreir_append_compile_stats_table_used_bytes_assign' \
    "build driver appends the stmt12 assignment as CoreBody"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_decl_can_lower_compile_stats_table_used_bytes_slice_mir_body' \
    "build driver exposes the stmt12 slice to PortableMIR lowering"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_mir_append_compile_stats_table_used_bytes_slice_body_function' \
    "build driver lowers the stmt12 slice into PortableMIR"

if grep -Eiq 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' \
    "$log_file" "$summary_file" "$output_c"; then
    echo "error: MIR-C99 cmd/build frontier summary mentioned legacy C99 fallback" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

echo "OK: MIR-C99 cmd/build summary records the first self-build frontier"
