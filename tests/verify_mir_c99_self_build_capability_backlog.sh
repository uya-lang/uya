#!/usr/bin/env bash
#
# MIR-C99 self-build capability backlog must stay grouped by capability class,
# not regress back to helper-frontier tasks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

if [[ ! -f "$TODO_FILE" ]]; then
    echo "error: missing MIR-C99 TODO file" >&2
    exit 1
fi

require_fixed_line() {
    local needle="$1"
    local description="$2"
    if ! grep -Fqx "$needle" "$TODO_FILE"; then
        echo "error: missing MIR-C99 self-build capability backlog evidence: $description" >&2
        echo "expected line: $needle" >&2
        exit 1
    fi
}

line_no() {
    local needle="$1"
    local line
    line="$(grep -Fnx "$needle" "$TODO_FILE" | head -n 1 | cut -d: -f1 || true)"
    if [[ -z "$line" ]]; then
        echo "error: cannot locate backlog line: $needle" >&2
        exit 1
    fi
    printf '%s\n' "$line"
}

parent_line='  - [ ] 根据 audit 重建 capability backlog：CFG、place/memory、call ABI、aggregate/layout、cleanup/error、runtime helper、emitter/output、link/absence；每个 backlog 叶子必须有失败优先的 parity/reject gate 和 host C 编译运行证据。'
cfg_line='    - [ ] CFG：audit=`frontier_sample_1=native_hosted_handoff_frontier` 只保留为 diagnostic-only handoff 样本；gate=`bash tests/verify_mir_c99_cfg_parity.sh` + `bash tests/verify_mir_c99_full_language_return_local_branch_loop_parity.sh`；host C 证据=两者都经 `tests/verify_mir_c99_oracle_parity_harness.sh` 编译并运行 MIR-C99/C99 产物。'
place_line='    - [ ] place/memory：audit=当前未进入 `blocked_category_summary`，但后续 self-build 不得再回退到 pointer/out-param/helper-shape frontier；gate=`bash tests/verify_mir_c99_place_memory_parity.sh` + `bash tests/verify_mir_c99_full_language_pointer_parity.sh`；host C 证据=两者都经 oracle parity harness 编译并运行。'
call_line='    - [ ] call ABI：audit=`blocked_category_call_abi=candidate_call_abi_smoke_missing`；gate=`bash tests/verify_mir_c99_call_parity.sh` + `bash tests/verify_mir_c99_full_language_float_call_abi_parity.sh`；host C 证据=两者都经 oracle parity harness 编译并运行，并继续受 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 约束。'
aggregate_line='    - [ ] aggregate/layout：audit=当前未进入 `blocked_category_summary`，但 aggregate/global/layout 变更必须先过通用 parity 再允许触碰 self-build frontier；gate=`bash tests/verify_mir_c99_layout_parity.sh` + `bash tests/verify_mir_c99_full_language_struct_parity.sh` + `bash tests/verify_mir_c99_global_import_parity.sh`；host C 证据=上述 gate 都编译并运行生成 C 产物。'
cleanup_line='    - [ ] cleanup/error：audit=当前未进入 `blocked_category_summary`，但 break/continue/drop/error path 仍可能重新暴露 candidate frontier；gate=`bash tests/verify_mir_c99_lexical_drop_parity.sh` + `bash tests/verify_mir_c99_dynamic_catch_parity.sh` + `bash tests/verify_mir_c99_full_language_errdefer_parity.sh`；host C 证据=上述 gate 都经 oracle parity harness 编译并运行。'
runtime_line='    - [ ] runtime helper：audit=`blocked_category_runtime_helper=candidate_runtime_capability_missing`；gate=`bash tests/verify_mir_c99_memory_string_runtime_parity.sh` + `bash tests/verify_mir_c99_helloworld_runtime_parity.sh` + `bash tests/verify_mir_c99_file_io_runtime_parity.sh`；host C 证据=上述 gate 编译并运行，且 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 继续记录 runtime helper blocker。'
emitter_line='    - [ ] emitter/output：audit=`blocked_category_emitter_output=native_hosted_emitter_handoff:status=rejected,reason=pending_core_bodies,backend=machine,link_plan=complete`；gate=`bash tests/verify_mir_c99_emitter_unit_output.sh` + `bash tests/verify_mir_c99_split_build_parity.sh`；host C 证据=`bash tests/verify_mir_c99_split_build_parity.sh` 的 multi-file case 与 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 的 candidate 编译运行。'
link_line='    - [ ] link/absence：audit=`blocked_category_link_absence=native_hosted_executable_writer_preflight:status=blocked,reason=pending_core_bodies,output_kind=machine_module,link_plan=complete`；gate=`bash tests/verify_mir_c99_global_import_parity.sh` + `bash tests/verify_mir_c99_independent_boundary.sh`；host C 证据=`bash tests/verify_mir_c99_global_import_parity.sh` 与 `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh`，并要求 absence 边界始终无 legacy C99 引用。'

require_fixed_line "$parent_line" "backlog parent item"
require_fixed_line "$cfg_line" "CFG backlog leaf"
require_fixed_line "$place_line" "place/memory backlog leaf"
require_fixed_line "$call_line" "call ABI backlog leaf"
require_fixed_line "$aggregate_line" "aggregate/layout backlog leaf"
require_fixed_line "$cleanup_line" "cleanup/error backlog leaf"
require_fixed_line "$runtime_line" "runtime helper backlog leaf"
require_fixed_line "$emitter_line" "emitter/output backlog leaf"
require_fixed_line "$link_line" "link/absence backlog leaf"

prev_line="$(line_no "$parent_line")"
for needle in \
    "$cfg_line" \
    "$place_line" \
    "$call_line" \
    "$aggregate_line" \
    "$cleanup_line" \
    "$runtime_line" \
    "$emitter_line" \
    "$link_line"; do
    current_line="$(line_no "$needle")"
    if (( current_line <= prev_line )); then
        echo "error: MIR-C99 self-build capability backlog order regressed near: $needle" >&2
        exit 1
    fi
    prev_line="$current_line"
done

echo "OK: MIR-C99 self-build capability backlog is grouped by capability class with gate/evidence lines"
