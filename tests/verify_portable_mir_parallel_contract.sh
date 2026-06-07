#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_CONTRACT_FILE="$REPO_ROOT/src/lower/mir_contract.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR parallel contract missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_CONTRACT_FILE" "$PORTABLE_MIR_DOC" "$ARCH_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_PARALLEL_OUTPUT_MIR_FUNCTIONS \
    MIR_PARALLEL_OUTPUT_DIAGNOSTICS \
    MIR_PARALLEL_OUTPUT_DUMP \
    MIR_PARALLEL_OUTPUT_BACKEND_FRAGMENTS \
    MIR_PARALLEL_MERGE_STABLE_FUNCTION_ORDER \
    MIR_PARALLEL_FORBID_SHARED_MODULE_WRITE \
    MIR_PARALLEL_FORBID_HASH_ORDER \
    MIR_PARALLEL_FORBID_CLOSURE_MUTATION \
    PortableMirParallelWorkerInput \
    PortableMirParallelMergeContract \
    portable_mir_parallel_worker_input_is_valid \
    portable_mir_parallel_merge_contract_is_deterministic; do
    require_pattern "$MIR_CONTRACT_FILE" "$symbol" "parallel symbol $symbol"
done

require_pattern "$MIR_CONTRACT_FILE" 'portable_mir_core_input_is_frozen\(&input\.core_input\)' "worker consumes frozen CoreIR input"
require_pattern "$PORTABLE_MIR_DOC" 'worker 输入只能是只读 `LoweredProgram \+ CoreBody' "whitepaper frozen worker input"
require_pattern "$PORTABLE_MIR_DOC" 'stable function order 合并 `MirFunction`、diagnostics、dump 和 backend fragments' "whitepaper stable merge outputs"
require_pattern "$PORTABLE_MIR_DOC" 'worker 不得直接写全局 `MirModule` 动态表' "whitepaper forbids shared module writes"
require_pattern "$PORTABLE_MIR_DOC" 'worker 不得用 hash iteration order' "whitepaper forbids hash-order outputs"
require_pattern "$ARCH_DOC" '支持 per-function 并行 MIR 构造时，按 stable function order 归并 diagnostics、dump 和 backend fragments' "architecture MIR parallel merge"

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-parallel-contract.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat >"$tmp_dir/main.uya" <<'EOF'
export type CoreBodyId = i32;
export type CoreStmtId = i32;
export type CoreExprId = i32;
export type CorePlaceId = i32;
export type CoreCleanupEdgeId = i32;

export const CORE_BODY_INVALID_ID: CoreBodyId = -1;
export const CORE_STMT_KIND_RETURN: i32 = 10;
export const CORE_STMT_KIND_ASM: i32 = 11;
export const CORE_STMT_KIND_DEFER: i32 = 12;
export const CORE_STMT_KIND_ERRDEFER: i32 = 13;
export const CORE_STMT_KIND_DROP: i32 = 14;
export const CORE_STMT_KIND_ERROR_PROPAGATION: i32 = 15;
export const CORE_EXPR_KIND_CALL: i32 = 11;
export const CORE_EXPR_KIND_INDEX: i32 = 12;
export const CORE_EXPR_KIND_SLICE: i32 = 13;
export const CORE_EXPR_KIND_ATOMIC: i32 = 14;
export const CORE_EXPR_KIND_VECTOR: i32 = 15;
export const CORE_EXPR_KIND_MASK: i32 = 16;
export const CORE_PLACE_KIND_FIELD: i32 = 4;
export const CORE_PLACE_KIND_INDEX: i32 = 5;
export const CORE_PLACE_KIND_SLICE: i32 = 6;
export const CORE_CLEANUP_EDGE_KIND_RETURN: i32 = 2;

struct LoweredProgram {
    marker: i32,
}

export struct PortableMirCoreInput {
    program: &LoweredProgram,
    body_id: CoreBodyId,
    target_profile_id: i32,
    flags: i32,
}

export fn portable_mir_core_input_is_frozen(input: &PortableMirCoreInput) i32 {
    if input == null || input.program == null {
        return 0;
    }
    if input.body_id != 0 {
        return 0;
    }
    return 1;
}
EOF

cat "$MIR_CONTRACT_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn portable_mir_parallel_test_input(program: &LoweredProgram) PortableMirParallelWorkerInput {
    return PortableMirParallelWorkerInput{
        core_input: PortableMirCoreInput{
            program: program,
            body_id: 0,
            target_profile_id: 1,
            flags: 0,
        },
        stable_function_index: 0,
        worker_id: 0,
        flags: 0,
    };
}

test "PortableMIR parallel worker input is frozen CoreIR only" {
    var lowered: LoweredProgram = LoweredProgram{ marker: 1 };
    var input: PortableMirParallelWorkerInput = portable_mir_parallel_test_input(&lowered);
    try assert_eq_i32(portable_mir_parallel_worker_input_is_valid(&input), 1);

    input.core_input.body_id = 2;
    try assert_eq_i32(portable_mir_parallel_worker_input_is_valid(&input), 0);
    input = portable_mir_parallel_test_input(&lowered);
    input.core_input.program = null;
    try assert_eq_i32(portable_mir_parallel_worker_input_is_valid(&input), 0);
    input = portable_mir_parallel_test_input(&lowered);
    input.stable_function_index = -1;
    try assert_eq_i32(portable_mir_parallel_worker_input_is_valid(&input), 0);
    input = portable_mir_parallel_test_input(&lowered);
    input.worker_id = -1;
    try assert_eq_i32(portable_mir_parallel_worker_input_is_valid(&input), 0);
}

test "PortableMIR parallel merge contract preserves deterministic outputs" {
    var contract: PortableMirParallelMergeContract = PortableMirParallelMergeContract{
        function_count: 0,
        worker_count: 0,
        output_mask: 0,
        merge_order_mask: 0,
        forbidden_mask: 0,
        flags: 0,
    };
    const required_outputs: i32 = portable_mir_parallel_required_output_mask();
    const required_forbidden: i32 = portable_mir_parallel_required_forbidden_mask();
    try assert_eq_i32(portable_mir_parallel_merge_contract_init(&contract, 2, 3), 0);
    try assert_eq_i32(portable_mir_parallel_merge_contract_is_deterministic(&contract), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(required_outputs, MIR_PARALLEL_OUTPUT_MIR_FUNCTIONS), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(required_outputs, MIR_PARALLEL_OUTPUT_DIAGNOSTICS), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(required_outputs, MIR_PARALLEL_OUTPUT_DUMP), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(required_outputs, MIR_PARALLEL_OUTPUT_BACKEND_FRAGMENTS), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(required_forbidden, MIR_PARALLEL_FORBID_SHARED_MODULE_WRITE), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(required_forbidden, MIR_PARALLEL_FORBID_HASH_ORDER), 1);
    try assert_eq_i32(portable_mir_lowering_mask_has(required_forbidden, MIR_PARALLEL_FORBID_CLOSURE_MUTATION), 1);

    contract.output_mask = MIR_PARALLEL_OUTPUT_MIR_FUNCTIONS;
    try assert_eq_i32(portable_mir_parallel_merge_contract_is_deterministic(&contract), 0);
    try assert_eq_i32(portable_mir_parallel_merge_contract_init(&contract, 2, 3), 0);
    contract.merge_order_mask = 0;
    try assert_eq_i32(portable_mir_parallel_merge_contract_is_deterministic(&contract), 0);
    try assert_eq_i32(portable_mir_parallel_merge_contract_init(&contract, 2, 3), 0);
    contract.forbidden_mask = MIR_PARALLEL_FORBID_SHARED_MODULE_WRITE;
    try assert_eq_i32(portable_mir_parallel_merge_contract_is_deterministic(&contract), 0);
    try assert_eq_i32(portable_mir_parallel_merge_contract_init(&contract, 2, 0), -1);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "OK: PortableMIR parallel construction contract verified"
