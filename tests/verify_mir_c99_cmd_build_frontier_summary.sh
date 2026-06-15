#!/usr/bin/env bash
#
# MIR-C99 cmd/build summary must describe the current real compiler candidate
# frontier without turning frozen helper samples into the next active task.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"
CMD_BUILD_SOURCE="$REPO_ROOT/src/cmd/build/main.uya"
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

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eiq "$pattern" "$file"; then
        echo "error: stale MIR-C99 cmd/build frontier evidence remains: $description" >&2
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

require_pattern "$log_file" '^subset=cmd_build_real_candidate$' \
    "log identifies the cmd/build real compiler candidate subset"
require_pattern "$log_file" '^frontier_kind=compiler_source$' \
    "log marks the frontier as a real compiler-source frontier"
require_pattern "$log_file" '^self_build_convergence_status=real_compiler_candidate$' \
    "log records real compiler candidate convergence status"
require_pattern "$log_file" '^host_compiler_binary_attempt=1$' \
    "log records the host compiler binary attempt"
require_pattern "$log_file" '^host_compiler_binary_status=generated$' \
    "log records generated host compiler binary status"
require_pattern "$log_file" '^host_compiler_binary_candidate_role=compiler_binary$' \
    "log records compiler binary candidate role"
require_pattern "$log_file" '^compiler_source_backend=mir_c99_unit_output$' \
    "log records the MIR-C99 unit output source backend"
require_pattern "$log_file" '^frontier_name=native_hosted_handoff_frontier$' \
    "log records the hosted handoff frontier"
require_pattern "$log_file" '^frontier_reason=pending_core_bodies$' \
    "log records the pending-core-body reason"
require_pattern "$log_file" '^frontier_category=mir_instruction_coverage$' \
    "log maps the frontier to a general MIR instruction coverage gap"
require_pattern "$log_file" '^pending_core_bodies=[1-9][0-9]*$' \
    "log records the current pending_core_bodies count"
require_pattern "$log_file" '^blocked_category_count=4$' \
    "log records the current blocked category count"
require_pattern "$log_file" '^blocked_category_summary=call_abi=1,runtime_helper=1,emitter_output=1,link_absence=1$' \
    "log records grouped blocked categories"
require_pattern "$log_file" '^full_language_backend_parity_status=branch_loop_array_slice_struct_tuple_enum_union_generic_gfunction_method_interface_icomposition_ginterface_float_error_binding_defer_errdefer_try_pointer_multifile_smoke$' \
    "log records the current full-language parity smoke frontier"
reject_pattern "$log_file" '^self_build_convergence_status=summary_only$' \
    "log still claims summary-only convergence"

require_pattern "$summary_file" "^MIR_C99_OUTPUT_ROLE='cmd_build_real_candidate'$" \
    "summary sidecar records real candidate output role"
require_pattern "$summary_file" "^MIR_C99_SELF_BUILD_CONVERGENCE_STATUS='real_compiler_candidate'$" \
    "summary sidecar records real compiler candidate convergence status"
require_pattern "$summary_file" '^MIR_C99_HOST_COMPILER_BINARY_ATTEMPT=1$' \
    "summary sidecar records host compiler binary attempt"
require_pattern "$summary_file" "^MIR_C99_HOST_COMPILER_BINARY_STATUS='generated'$" \
    "summary sidecar records generated host compiler binary status"
require_pattern "$summary_file" "^MIR_C99_HOST_COMPILER_BINARY_CANDIDATE_ROLE='compiler_binary'$" \
    "summary sidecar records compiler binary candidate role"
require_pattern "$summary_file" "^MIR_C99_COMPILER_SOURCE_BACKEND='mir_c99_unit_output'$" \
    "summary sidecar records MIR-C99 unit output backend"
require_pattern "$summary_file" "^MIR_C99_SELF_BUILD_FRONTIER='native_hosted_handoff_frontier'$" \
    "summary sidecar records the hosted handoff frontier"
require_pattern "$summary_file" "^MIR_C99_FRONTIER_CATEGORY='mir_instruction_coverage'$" \
    "summary sidecar records the general MIR-C99 gap category"
require_pattern "$summary_file" '^MIR_C99_PENDING_CORE_BODIES=[1-9][0-9]*$' \
    "summary sidecar records pending_core_bodies count"
require_pattern "$summary_file" '^MIR_C99_BLOCKED_CATEGORY_COUNT=4$' \
    "summary sidecar records blocked category count"
require_pattern "$summary_file" "^MIR_C99_BLOCKED_CATEGORY_SUMMARY='call_abi=1,runtime_helper=1,emitter_output=1,link_absence=1'$" \
    "summary sidecar records grouped blocked categories"
require_pattern "$summary_file" "^MIR_C99_FULL_LANGUAGE_BACKEND_PARITY_STATUS='branch_loop_array_slice_struct_tuple_enum_union_generic_gfunction_method_interface_icomposition_ginterface_float_error_binding_defer_errdefer_try_pointer_multifile_smoke'$" \
    "summary sidecar records the current full-language parity smoke frontier"
reject_pattern "$summary_file" "summary_only|summary_executable" \
    "summary sidecar still describes the obsolete summary-only candidate"

cc -std=c99 -Wall -Wextra -pedantic "$output_c" -o "$candidate_bin" -lm
"$candidate_bin" --help >"$candidate_stdout" 2>"$candidate_stderr"
if ! grep -Eq 'Uya build compiler' "$candidate_stdout" "$candidate_stderr"; then
    echo "error: missing MIR-C99 cmd/build frontier evidence: candidate identifies as Uya build compiler" >&2
    exit 1
fi
if ! grep -Eq '用法:' "$candidate_stdout" "$candidate_stderr"; then
    echo "error: missing MIR-C99 cmd/build frontier evidence: candidate prints usage" >&2
    exit 1
fi

require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*real compiler candidate' \
    "coverage matrix records the real compiler candidate state"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*convergence audit 现固定输出 `status=real_compiler_candidate`' \
    "coverage matrix records real-candidate convergence audit status"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*blocked categories（call ABI、runtime helper、emitter/output、link/absence）' \
    "coverage matrix records grouped blocked categories"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*stage gate 固定只认三类收敛指标' \
    "coverage matrix records metric-based stage gate"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*helper 名、frontier 样本名、statement count、`completed_body_detail` 和 `next_coverage` 只保留为诊断上下文' \
    "coverage matrix keeps helper samples diagnostic-only"
require_pattern "$COVERAGE_DOC" 'MIR-C99 self-build.*经 host C compiler 编译后可通过 `cmd/build --help` smoke' \
    "coverage matrix records host compiler smoke"

echo "OK: MIR-C99 cmd/build frontier summary records real compiler candidate metrics"
