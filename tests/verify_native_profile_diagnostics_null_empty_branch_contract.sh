#!/usr/bin/env bash

# Native build-seed 边界：固定 compiler_should_profile_diagnostics(...)
# null/empty early-return branch 的 CoreBody/PortableMIR 合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
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

for file in "$SUBSET_DOC" "$TODO_DOC" "$BUILD_DRIVER_SRC" "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done
require_pattern "$SUBSET_DOC" '^## `compiler_should_profile_diagnostics\(\.\.\.\)` Null/Empty Branch Contract' \
    "subset doc 缺少 compiler_should_profile_diagnostics null/empty branch 合同"
require_pattern "$SUBSET_DOC" 'if value == null \|\| value\[0\] == 0 as byte' \
    "subset doc 缺少 null/empty branch 源码"
require_pattern "$SUBSET_DOC" 'CORE_EXPR_KIND_I32_NE' \
    "subset doc 缺少 null/empty branch compare CoreIR 合同"
require_pattern "$SUBSET_DOC" 'CORE_PLACE_KIND_INDEX' \
    "subset doc 缺少 value[0] byte index place 合同"
require_pattern "$SUBSET_DOC" 'MIR_TERMINATOR_KIND_COND_BR' \
    "subset doc 缺少 null/empty branch PortableMIR 条件分支合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_frontier: function=compiler_should_profile_diagnostics prefix_stmts=2 next_stmt=2 next_kind=AST_IF_STMT reason=partial_core_body' \
    "subset doc 缺少 null/empty branch 迁入后的 next frontier"

require_pattern "$SUBSET_DOC" '实现叶子应新增 `NATIVE_PROFILE_DIAGNOSTICS_NULL_EMPTY_BRANCH_PREFIX_STMT_COUNT = 2`' \
    "subset doc 缺少后续实现叶子的 prefix 常量要求"
require_pattern "$SUBSET_DOC" '实现叶子应同步 `tests/verify_native_cmd_build_no_silent_c99.sh`' \
    "subset doc 缺少后续实现叶子的 no-silent-C99 同步要求"
script_name="${0##*/}"
if grep -Eq "$script_name" "$STAGE1_TEST"; then
    echo "错误: stage1 不应重新聚合已归档 helper 合同" >&2
    echo "文件: $STAGE1_TEST" >&2
    exit 1
fi

echo "verify_native_profile_diagnostics_null_empty_branch_contract: ok"
