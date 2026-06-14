#!/usr/bin/env bash
#
# MIR-C99 self-build reset metrics must stay anchored to candidate-state
# change, blocked-category reduction, and runnable compiler smoke.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"
TODO_COMPLETED_FILE="$REPO_ROOT/docs/todo_mir_c99_backend_completed.md"
COVERAGE_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

if [[ ! -f "$TODO_FILE" || ! -f "$TODO_COMPLETED_FILE" || ! -f "$COVERAGE_DOC" ]]; then
    echo "error: missing MIR-C99 self-build metrics contract inputs" >&2
    exit 1
fi

count_fragment() {
    local file="$1"
    local fragment="$2"
    grep -F -c "$fragment" "$file" || true
}

require_fragment_once() {
    local fragment="$1"
    local description="$2"
    local todo_count
    local completed_count
    local total_count
    todo_count="$(count_fragment "$TODO_FILE" "$fragment")"
    completed_count="$(count_fragment "$TODO_COMPLETED_FILE" "$fragment")"
    total_count=$((todo_count + completed_count))
    if (( total_count == 0 )); then
        echo "error: missing MIR-C99 self-build reset metric contract: $description" >&2
        echo "expected fragment: $fragment" >&2
        exit 1
    fi
    if (( total_count > 1 )); then
        echo "error: duplicated MIR-C99 self-build reset metric contract: $description" >&2
        echo "fragment: $fragment" >&2
        exit 1
    fi
}

require_doc_fragment() {
    local fragment="$1"
    local description="$2"
    if ! grep -Fq "$fragment" "$COVERAGE_DOC"; then
        echo "error: coverage doc missing MIR-C99 self-build reset metric contract: $description" >&2
        echo "expected fragment: $fragment" >&2
        exit 1
    fi
}

leaf_fragment='收敛指标固定为“summary executable -> real compiler candidate”的状态变化、blocked category 减少和可运行 compiler smoke；不得以单个 helper body-complete 或 frontier 名变化作为完成定义。'
state_fragment='状态变化：只有当 host C compiler 编译出的候选不再以 exit 70 报告 `compiler_binary_status=not_yet_generated`，且 `host_binary_candidate_role` 不再是 `summary_executable`，并能通过 `cmd/build --help` 或等价 compiler smoke 运行时，才算从 summary executable 进入 real compiler candidate。'
blocked_fragment='blocked category：只看 `blocked_category_count` 和各 `blocked_category_*` 是否减少；helper 名、`frontier_sample_*`、`completed_body_detail`、`next_coverage` 和 statement count 只保留为诊断上下文，不能单独定义完成。'
smoke_fragment='compiler smoke：最小 host C 证据必须包含 host C compiler 编译候选，并运行 `cmd/build --help` 或等价 smoke，验证 stdout/stderr/exit code 体现 compiler binary 行为。'
baseline_fragment='当前基线：`bash tests/verify_mir_c99_self_build_convergence_audit.sh` + `bash tests/verify_mir_c99_cmd_build_host_binary_attempt_gate.sh` 固定 `self_build_convergence_status=summary_only`、`host_compiler_binary_candidate_role=summary_executable`、`blocked_category_count=4`；后续只允许围绕这些指标下降或转态推进。'

require_fragment_once "$leaf_fragment" "leaf text"
require_fragment_once "$state_fragment" "candidate-state transition gate"
require_fragment_once "$blocked_fragment" "blocked-category reduction gate"
require_fragment_once "$smoke_fragment" "compiler smoke gate"
require_fragment_once "$baseline_fragment" "summary-only baseline"

require_doc_fragment '4.16 stage gate 固定只认三类收敛指标：候选状态从 summary executable 切换到 real compiler candidate、`blocked_category_count`/`blocked_category_*` 减少、以及 host C compiler 编译出的候选通过 `cmd/build --help` 或等价 compiler smoke。' \
    "coverage doc records the three allowed convergence metrics"
require_doc_fragment 'helper 名、frontier 样本名、statement count、`completed_body_detail` 和 `next_coverage` 只保留为诊断上下文，不再定义完成。' \
    "coverage doc demotes helper/frontier deltas to diagnostics"

echo "OK: MIR-C99 self-build reset metrics stay fixed to state change, blocker reduction, and compiler smoke"
