#!/usr/bin/env bash

# Phase 10：验证 native build compiler 子集所需 error union / defer 控制流清理契约。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTROL_FILE="$REPO_ROOT/src/codegen/native/control.uya"
TEST_FILE="$REPO_ROOT/tests/test_native_error_defer_control.uya"

require_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "错误: 缺少 $path" >&2
        exit 1
    fi
}

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 缺少 native error/defer 控制流证据: $description" >&2
        exit 1
    fi
}

require_file "$CONTROL_FILE"
require_file "$TEST_FILE"

require_pattern "$CONTROL_FILE" '^export[[:space:]]+struct[[:space:]]+NativeCleanupPlan' "NativeCleanupPlan 结构"
require_pattern "$CONTROL_FILE" '^export[[:space:]]+struct[[:space:]]+NativeCleanupAction' "NativeCleanupAction 结构"
require_pattern "$CONTROL_FILE" 'NativeTable' "使用动态 NativeTable 存储 cleanup plan"
require_pattern "$CONTROL_FILE" 'native_cleanup_push_defer' "defer 注册"
require_pattern "$CONTROL_FILE" 'native_cleanup_push_errdefer' "errdefer 注册"
require_pattern "$CONTROL_FILE" 'native_cleanup_emit_exit_order' "退出路径 cleanup order"
require_pattern "$CONTROL_FILE" 'NATIVE_CLEANUP_EXIT_ERROR' "错误路径常量"

(cd "$REPO_ROOT" && ./bin/uya test tests/test_native_error_defer_control.uya --no-split-c --project-root src/)

echo "verify_native_error_defer_control: ok"
