#!/usr/bin/env bash

# Phase 10：固定 compile_stats_record_and_release_typed_program(...)
# 首个最小切片的 CoreBody/PortableMIR golden/verifier 合同输入面。
# 该脚本不声明函数体已经迁入；它保证下一步实现必须从真实
# stats/checker early-return 与 field-address call surface 开始。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
CORE_FILE="$REPO_ROOT/src/lower/core.uya"
MIR_CONTRACT_FILE="$REPO_ROOT/src/lower/mir_contract.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_VERIFIER_SRC="$REPO_ROOT/src/lower/mir_verifier.uya"
COREIR_GOLDEN_TEST="$REPO_ROOT/tests/verify_coreir_dump_golden.sh"
MIR_GOLDEN_TEST="$REPO_ROOT/tests/verify_portable_mir_golden.sh"
MIR_VERIFIER_TEST="$REPO_ROOT/tests/verify_portable_mir_verifier.sh"
NO_SILENT_TEST="$REPO_ROOT/tests/verify_native_cmd_build_no_silent_c99.sh"
STAGE1_TEST="$REPO_ROOT/tests/verify_native_cmd_build_stage1.sh"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: $description" >&2
        echo "文件: $file" >&2
        exit 1
    fi
}

for file in "$SUBSET_DOC" "$TODO_DOC" "$BUILD_DRIVER_SRC" "$CORE_FILE" \
    "$MIR_CONTRACT_FILE" "$MIR_FILE" "$MIR_VERIFIER_SRC" "$COREIR_GOLDEN_TEST" \
    "$MIR_GOLDEN_TEST" "$MIR_VERIFIER_TEST" "$NO_SILENT_TEST" "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TODO_DOC" '为 `compile_stats_record_and_release_typed_program\(\.\.\.\)` 的首个最小切片补[[:space:]]*$' \
    "todo 缺少 compile_stats 首切片合同任务"
require_pattern "$TODO_DOC" 'typed_program_current_bytes\(&checker\.typed_program\)` field-address call surface' \
    "todo 缺少 field-address call surface 范围"

require_pattern "$SUBSET_DOC" '^## `compile_stats_record_and_release_typed_program\(\.\.\.\)` PortableMIR Surface Audit' \
    "subset doc 缺少 compile_stats surface audit"
require_pattern "$SUBSET_DOC" '^## `compile_stats_record_and_release_typed_program\(\.\.\.\)` First Slice Contract' \
    "subset doc 缺少 compile_stats first slice contract"
require_pattern "$SUBSET_DOC" '`stats == null` return' \
    "subset doc 缺少 stats null return 合同"
require_pattern "$SUBSET_DOC" '`typed_program_bytes = 0usize`' \
    "subset doc 缺少 typed_program_bytes 清零合同"
require_pattern "$SUBSET_DOC" '`typed_program_peak_bytes = 0usize`' \
    "subset doc 缺少 typed_program_peak_bytes 清零合同"
require_pattern "$SUBSET_DOC" '`typed_program_released_bytes = 0usize`' \
    "subset doc 缺少 typed_program_released_bytes 清零合同"
require_pattern "$SUBSET_DOC" '`checker == null` return' \
    "subset doc 缺少 checker null return 合同"
require_pattern "$SUBSET_DOC" '`typed_program_current_bytes\(&checker\.typed_program\)`' \
    "subset doc 缺少 field-address current-bytes call 合同"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_RETURN' \
    "subset doc 缺少 CoreIR return 合同"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_ASSIGN' \
    "subset doc 缺少 CoreIR stats field store 合同"
require_pattern "$SUBSET_DOC" 'CORE_PLACE_KIND_FIELD' \
    "subset doc 缺少 CoreIR field place 合同"
require_pattern "$SUBSET_DOC" 'CORE_SEMANTIC_FACT_FIELD_ID' \
    "subset doc 缺少 CoreIR frozen field fact 合同"
require_pattern "$SUBSET_DOC" 'MIR_INST_OP_FIELD_ADDR' \
    "subset doc 缺少 PortableMIR field address 合同"
require_pattern "$SUBSET_DOC" 'MIR_INST_OP_STORE' \
    "subset doc 缺少 PortableMIR store 合同"
require_pattern "$SUBSET_DOC" 'MIR_INST_OP_CALL' \
    "subset doc 缺少 PortableMIR call 合同"
require_pattern "$SUBSET_DOC" 'MIR_TERMINATOR_KIND_RETURN' \
    "subset doc 缺少 PortableMIR return terminator 合同"

require_pattern "$BUILD_DRIVER_SRC" 'fn compile_stats_record_and_release_typed_program\(stats: &CompileStats, checker: &TypeChecker\) void' \
    "build driver 缺少 compile_stats helper 签名"
require_pattern "$BUILD_DRIVER_SRC" 'if stats == null' \
    "compile_stats 源码缺少 stats null guard"
require_pattern "$BUILD_DRIVER_SRC" 'stats\.typed_program_bytes = 0usize;' \
    "compile_stats 源码缺少 typed_program_bytes 清零"
require_pattern "$BUILD_DRIVER_SRC" 'stats\.typed_program_peak_bytes = 0usize;' \
    "compile_stats 源码缺少 typed_program_peak_bytes 清零"
require_pattern "$BUILD_DRIVER_SRC" 'stats\.typed_program_released_bytes = 0usize;' \
    "compile_stats 源码缺少 typed_program_released_bytes 清零"
require_pattern "$BUILD_DRIVER_SRC" 'if checker == null' \
    "compile_stats 源码缺少 checker null guard"
require_pattern "$BUILD_DRIVER_SRC" 'stats\.typed_program_bytes = typed_program_current_bytes\(&checker\.typed_program\);' \
    "compile_stats 源码缺少 first field-address current-bytes call"
require_pattern "$BUILD_DRIVER_SRC" 'stats\.typed_program_peak_bytes = typed_program_peak_bytes\(&checker\.typed_program\);' \
    "compile_stats 源码缺少 peak-bytes call"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_decl_can_materialize_compile_stats_first_slice_body' \
    "build driver 缺少 compile_stats CoreBody materialize 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_coreir_append_compile_stats_first_slice_body' \
    "build driver 缺少 compile_stats CoreIR builder"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_decl_can_lower_compile_stats_first_slice_mir_body' \
    "build driver 缺少 compile_stats PortableMIR 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_mir_append_compile_stats_first_slice_body_function' \
    "build driver 缺少 compile_stats PortableMIR builder"
require_pattern "$BUILD_DRIVER_SRC" 'CORE_BODY_FLAG_SOURCE_BODY \| CORE_BODY_FLAG_PARTIAL' \
    "build driver compile_stats CoreBody 未标记 partial"

require_pattern "$CORE_FILE" 'CORE_STMT_KIND_RETURN' \
    "CoreIR 缺少 return statement kind"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_ASSIGN' \
    "CoreIR 缺少 assign statement kind"
require_pattern "$CORE_FILE" 'CORE_PLACE_KIND_FIELD' \
    "CoreIR 缺少 field place kind"
require_pattern "$CORE_FILE" 'CORE_SEMANTIC_FACT_FIELD_ID' \
    "CoreIR 缺少 frozen field semantic fact"
require_pattern "$COREIR_GOLDEN_TEST" 'CORE_STMT_KIND_ASSIGN' \
    "CoreIR golden 缺少 assign 覆盖"
require_pattern "$COREIR_GOLDEN_TEST" 'CORE_PLACE_KIND_FIELD' \
    "CoreIR golden 缺少 field place 覆盖"
require_pattern "$COREIR_GOLDEN_TEST" 'CORE_SEMANTIC_FACT_FIELD_ID' \
    "CoreIR golden 缺少 field fact 覆盖"

require_pattern "$MIR_CONTRACT_FILE" 'MIR_INST_OP_FIELD_ADDR' \
    "PortableMIR contract 缺少 field address opcode"
require_pattern "$MIR_CONTRACT_FILE" 'MIR_LOWER_FEATURE_FIELD_INDEX_SLICE_ADDRESS' \
    "PortableMIR contract 缺少 field/index/slice address feature"
require_pattern "$MIR_FILE" 'MIR_INST_OP_STORE' \
    "PortableMIR 缺少 store inst"
require_pattern "$MIR_FILE" 'MIR_INST_OP_CALL' \
    "PortableMIR 缺少 call inst"
require_pattern "$MIR_FILE" 'MIR_TERMINATOR_KIND_RETURN' \
    "PortableMIR 缺少 return terminator"
require_pattern "$MIR_GOLDEN_TEST" 'MIR_INST_OP_FIELD_ADDR' \
    "PortableMIR golden 缺少 field address 覆盖"
require_pattern "$MIR_GOLDEN_TEST" 'MIR_INST_OP_STORE' \
    "PortableMIR golden 缺少 store 覆盖"
require_pattern "$MIR_GOLDEN_TEST" 'MIR_INST_OP_CALL' \
    "PortableMIR golden 缺少 call 覆盖"
require_pattern "$MIR_VERIFIER_SRC" 'MIR_INST_OP_STORE' \
    "PortableMIR verifier 缺少 store 校验"
require_pattern "$MIR_VERIFIER_SRC" 'MIR_INST_OP_CALL' \
    "PortableMIR verifier 缺少 call 校验"
require_pattern "$MIR_VERIFIER_TEST" 'MIR_INST_OP_CALL' \
    "PortableMIR verifier 测试缺少 call 覆盖"

require_pattern "$NO_SILENT_TEST" 'core_bodies=16' \
    "no-silent-C99 测试缺少 compile_stats CoreBody 计数"
require_pattern "$NO_SILENT_TEST" 'mir_body_functions=15' \
    "no-silent-C99 测试缺少 compile_stats MIR body 计数"
require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program' \
    "no-silent-C99 测试缺少 compile_stats partial body frontier"
require_pattern "$NO_SILENT_TEST" '不应在 compile_stats 首切片迁入后继续报告整个 helper pending' \
    "no-silent-C99 测试缺少旧 compile_stats pending 反向检查"
require_pattern "$STAGE1_TEST" 'verify_native_compile_stats_first_slice_contract\.sh' \
    "stage1 未纳入 compile_stats 首切片合同"

echo "verify_native_compile_stats_first_slice_contract: ok"
