#!/usr/bin/env bash
#
# MIR-C99 cmd/build self-build convergence audit must report real compiler
# candidate status, host binary candidate role, pending_core_bodies count,
# frozen frontier samples, and grouped blocked categories.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"
CMD_BUILD_SOURCE="$REPO_ROOT/src/cmd/build/main.uya"
COVERAGE_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"
TMP_DIR="$(mktemp -d /tmp/uya-mir-c99-self-build-audit.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing MIR-C99 self-build convergence audit evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

output_c="$TMP_DIR/cmd-build-mir.c"
log_file="$TMP_DIR/cmd-build-mir.log"
summary_file="${output_c}.summary"

"$GENERATOR" "$CMD_BUILD_SOURCE" "$output_c" "$log_file" >/dev/null

require_pattern "$log_file" '^self_build_convergence_status=real_compiler_candidate$' \
    "log records real compiler candidate convergence status"
require_pattern "$log_file" '^compiler_binary_status=generated$' \
    "log records compiler binary generated status"
require_pattern "$log_file" '^host_compiler_binary_candidate_role=compiler_binary$' \
    "log records compiler binary candidate role"
require_pattern "$log_file" '^pending_core_bodies=[1-9][0-9]*$' \
    "log records pending_core_bodies count"
require_pattern "$log_file" '^blocked_category_count=4$' \
    "log records blocked category count"
require_pattern "$log_file" '^blocked_category_summary=call_abi=1,runtime_helper=1,emitter_output=1,link_absence=1$' \
    "log records grouped blocked categories"
require_pattern "$log_file" '^blocked_category_call_abi=candidate_call_abi_smoke_missing$' \
    "log records call ABI blocker"
require_pattern "$log_file" '^blocked_category_runtime_helper=candidate_runtime_capability_missing$' \
    "log records runtime helper blocker"
require_pattern "$log_file" '^blocked_category_emitter_output=native_hosted_emitter_handoff:status=rejected,reason=pending_core_bodies,backend=machine,link_plan=complete$' \
    "log records emitter/output blocker"
require_pattern "$log_file" '^blocked_category_link_absence=native_hosted_executable_writer_preflight:status=blocked,reason=pending_core_bodies,output_kind=machine_module,link_plan=complete$' \
    "log records link/absence blocker"

require_pattern "$summary_file" "^MIR_C99_SELF_BUILD_CONVERGENCE_STATUS='real_compiler_candidate'$" \
    "summary sidecar records real compiler candidate convergence status"
require_pattern "$summary_file" "^MIR_C99_HOST_COMPILER_BINARY_CANDIDATE_ROLE='compiler_binary'$" \
    "summary sidecar records compiler binary candidate role"
require_pattern "$summary_file" '^MIR_C99_PENDING_CORE_BODIES=[1-9][0-9]*$' \
    "summary sidecar records pending_core_bodies count"
require_pattern "$summary_file" '^MIR_C99_BLOCKED_CATEGORY_COUNT=4$' \
    "summary sidecar records blocked category count"
require_pattern "$summary_file" "^MIR_C99_BLOCKED_CATEGORY_SUMMARY='call_abi=1,runtime_helper=1,emitter_output=1,link_absence=1'$" \
    "summary sidecar records grouped blocked categories"
require_pattern "$summary_file" "^MIR_C99_BLOCKED_CATEGORY_CALL_ABI='candidate_call_abi_smoke_missing'$" \
    "summary sidecar records call ABI blocker"
require_pattern "$summary_file" "^MIR_C99_BLOCKED_CATEGORY_RUNTIME_HELPER='candidate_runtime_capability_missing'$" \
    "summary sidecar records runtime helper blocker"
require_pattern "$summary_file" "^MIR_C99_BLOCKED_CATEGORY_EMITTER_OUTPUT='native_hosted_emitter_handoff:status=rejected,reason=pending_core_bodies,backend=machine,link_plan=complete'$" \
    "summary sidecar records emitter/output blocker"
require_pattern "$summary_file" "^MIR_C99_BLOCKED_CATEGORY_LINK_ABSENCE='native_hosted_executable_writer_preflight:status=blocked,reason=pending_core_bodies,output_kind=machine_module,link_plan=complete'$" \
    "summary sidecar records link/absence blocker"
require_pattern "$summary_file" "^MIR_C99_COMPILER_SOURCE_BACKEND='mir_c99_unit_output'$" \
    "summary sidecar records the compiler source backend used for the candidate"

pending_from_log="$(sed -n -E 's/^pending_core_bodies=([0-9]+)$/\1/p' "$log_file")"
pending_from_summary="$(sed -n -E 's/^MIR_C99_PENDING_CORE_BODIES=([0-9]+)$/\1/p' "$summary_file")"
if [[ -z "$pending_from_log" || -z "$pending_from_summary" || "$pending_from_log" != "$pending_from_summary" ]]; then
    echo "error: pending_core_bodies count diverged between log and summary" >&2
    cat "$log_file" >&2
    cat "$summary_file" >&2
    exit 1
fi

require_pattern "$COVERAGE_DOC" 'convergence audit 现固定输出 `status=real_compiler_candidate`、host binary candidate role `compiler_binary`、`pending_core_bodies=3511`' \
    "coverage doc records real compiler candidate audit status"
require_pattern "$COVERAGE_DOC" '`frontier_sample_1=native_hosted_handoff_frontier` 仅作为 diagnostic-only handoff 样本' \
    "coverage doc records handoff frontier sample as diagnostic-only"
require_pattern "$COVERAGE_DOC" 'frontier samples（`native_hosted_handoff_frontier`、`native_build_type_named_equals`、`native_hosted_executable_writer_preflight`）' \
    "coverage doc records frozen frontier samples"
require_pattern "$COVERAGE_DOC" 'blocked categories（call ABI、runtime helper、emitter/output、link/absence）' \
    "coverage doc records grouped blocked categories"
require_pattern "$COVERAGE_DOC" '当前真实 compiler candidate C 由 `mir_c99_unit_output` 提供' \
    "coverage doc records the MIR-C99 unit output source"

echo "OK: MIR-C99 self-build convergence audit records real compiler candidate status and grouped blockers"
