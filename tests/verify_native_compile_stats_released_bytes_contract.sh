#!/usr/bin/env bash

# Phase 10：固定 compile_stats_record_and_release_typed_program(...)
# typed_program_released_bytes 写回的 CoreBody/PortableMIR 切片合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
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

for file in "$SUBSET_DOC" "$TODO_DOC" "$BUILD_DRIVER_SRC" "$NO_SILENT_TEST" "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TODO_DOC" 'stats\.typed_program_released_bytes = typed_program_current_bytes\(&checker\.typed_program\)' \
    "todo 缺少 compile_stats released-bytes 写回任务"
require_pattern "$SUBSET_DOC" '^## `compile_stats_record_and_release_typed_program\(\.\.\.\)` Released Bytes Writeback Slice Contract' \
    "subset doc 缺少 compile_stats released-bytes 合同"
require_pattern "$SUBSET_DOC" 'stats\.typed_program_released_bytes = typed_program_current_bytes\(&checker\.typed_program\);' \
    "subset doc 缺少 released-bytes 写回 surface"
require_pattern "$SUBSET_DOC" 'prefix_stmts=17 next_stmt=17 next_kind=AST_ASSIGN reason=partial_core_body' \
    "subset doc 缺少 released-bytes 写回前 frontier"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=compile_stats_record_and_release_typed_program prefix_stmts=18 reason=body_complete' \
    "subset doc 缺少 released-bytes 写回后的 complete frontier"

require_pattern "$BUILD_DRIVER_SRC" 'stats\.typed_program_released_bytes = typed_program_current_bytes\(&checker\.typed_program\);' \
    "compile_stats 源码缺少 released-bytes 写回"
require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_frontier: function=compile_stats_record_and_release_typed_program prefix_stmts=17 next_stmt=17 next_kind=AST_ASSIGN reason=partial_core_body' \
    "no-silent-C99 测试缺少 compile_stats released-bytes 当前 frontier"
require_pattern "$NO_SILENT_TEST" '不应在 compile_stats typed_type_records release 迁入后继续报告 prefix_stmts=16' \
    "no-silent-C99 测试缺少旧 compile_stats prefix=16 反向检查"
require_pattern "$STAGE1_TEST" 'verify_native_compile_stats_released_bytes_contract\.sh' \
    "stage1 未纳入 compile_stats released-bytes 合同"

echo "verify_native_compile_stats_released_bytes_contract: ok"
