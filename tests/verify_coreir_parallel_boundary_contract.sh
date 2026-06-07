#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COREIR_DOC="$REPO_ROOT/docs/coreir_lowered_program_whitepaper.md"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"
LOWER_CORE="$REPO_ROOT/src/lower/core.uya"
STABLE_SORT_TEST="$REPO_ROOT/tests/verify_lowered_program_stable_sort.sh"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: CoreLower parallel boundary contract missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$COREIR_DOC" "$ARCH_DOC" "$LOWER_CORE" "$STABLE_SORT_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

require_pattern "$COREIR_DOC" '### 21\.1 并行 CoreLower 归并规则' "CoreLower parallel section"
require_pattern "$COREIR_DOC" 'discovery 阶段可以并行收集.*request buffer' "pre-freeze discovery local requests"
require_pattern "$COREIR_DOC" '不得分配' "worker must not allocate stable IDs before merge"
require_pattern "$COREIR_DOC" 'CoreBodyId' "CoreBodyId participates in stable ID boundary"
require_pattern "$COREIR_DOC" 'stable merge barrier' "stable merge barrier"
require_pattern "$COREIR_DOC" '按 stable key 排序、去重、追加 worklist' "stable-key merge and worklist append"
require_pattern "$COREIR_DOC" 'worklist closure 冻结后，per-function CoreBody materialization 才允许并行' "post-freeze per-function materialization boundary"
require_pattern "$COREIR_DOC" 'stable function order 归并' "stable function order merge"
require_pattern "$COREIR_DOC" 'ID、dump 文本和' "parallel output preserves IDs and dump"
require_pattern "$COREIR_DOC" 'diagnostic 顺序一致' "parallel output preserves diagnostics"
require_pattern "$COREIR_DOC" '不得写共享 `LoweredProgram` 表' "worker cannot write shared LoweredProgram tables"
require_pattern "$COREIR_DOC" '禁止模式' "forbidden parallel modes"
require_pattern "$COREIR_DOC" 'hash iteration 顺序分配 stable ID' "no hash-iteration ID allocation"
require_pattern "$COREIR_DOC" '并行开关改变 CoreIR dump、verifier diagnostic' "no dump or diagnostic drift"

require_pattern "$ARCH_DOC" 'CoreLower 的并行合同' "architecture parallel contract"
require_pattern "$ARCH_DOC" '冻结前的 discovery worker 只能产出本地 request buffer' "architecture pre-freeze request buffer"
require_pattern "$ARCH_DOC" '冻结后的 per-function CoreBody materialization 只能消费 frozen' "architecture post-freeze materialization"
require_pattern "$ARCH_DOC" '不得改变 CoreIR IDs、CoreBody ranges、dump 文本或' "architecture deterministic IDs/ranges/dump"
require_pattern "$ARCH_DOC" 'diagnostic 顺序' "architecture deterministic diagnostics"
require_pattern "$ARCH_DOC" 'per-function CoreBody materialization 也必须按 stable function order 归并' "phase checklist stable function order"

require_pattern "$LOWER_CORE" 'lowered_program_sort_stable' "stable table sort API"
require_pattern "$LOWER_CORE" 'lowered_program_sort_functions' "stable function ordering API"
require_pattern "$LOWER_CORE" 'lowered_program_sort_helpers' "stable helper ordering API"
require_pattern "$STABLE_SORT_TEST" 'stable output sort' "stable output sort regression"

echo "OK: CoreLower parallel boundary contract verified"
