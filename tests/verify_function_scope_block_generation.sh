#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCOPE_FILE="$REPO_ROOT/src/checker/function_scope.uya"
CHECKER_MAIN_FILE="$REPO_ROOT/src/checker/main.uya"
CHECK_STMT_FILE="$REPO_ROOT/src/checker/check_stmt.uya"
COMPILER="$REPO_ROOT/bin/uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: FunctionScopeIndex block generation 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$SCOPE_FILE" "$CHECKER_MAIN_FILE" "$CHECK_STMT_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$SCOPE_FILE" "function_scope_index_current_generation" "generation 查询 API"
require_pattern "$CHECKER_MAIN_FILE" "checker_function_scope_enter_block" "AST_BLOCK 进入时同步 FunctionScopeIndex"
require_pattern "$CHECKER_MAIN_FILE" "checker_function_scope_exit_block" "AST_BLOCK 退出时同步 FunctionScopeIndex"
require_pattern "$CHECK_STMT_FILE" "function_scope_index_add_local" "局部变量登记到 FunctionScopeIndex"

tmp_dir="$(mktemp -d /tmp/uya-function-scope-blocks.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.uya" <<'EOF'
fn local_blocks(seed: i32) i32 {
    var x0: i32 = seed;
    {
        var x1: i32 = x0 + 1;
        {
            var x2: i32 = x1 + 1;
            return x2;
        }
    }
    return x0;
}

export fn main() i32 {
    return local_blocks(1);
}
EOF

log_file="$tmp_dir/check.log"
(cd "$REPO_ROOT" && UYA_DUMP_FUNCTION_SCOPE=1 "$COMPILER" check "$tmp_dir/main.uya" >"$log_file" 2>&1)

require_log() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$log_file"; then
        echo "错误: FunctionScopeIndex block generation dump 缺少: $description" >&2
        cat "$log_file" >&2
        exit 1
    fi
}

require_log "function_scope block_enter fn=local_blocks depth=1 generation=1 scopes=2" "函数体 block generation"
require_log "function_scope local fn=local_blocks name=x0 locals=1 depth=1 generation=1 binding=[0-9]+" "函数体 local generation"
require_log "function_scope block_enter fn=local_blocks depth=2 generation=2 scopes=3" "内层 block generation"
require_log "function_scope local fn=local_blocks name=x1 locals=2 depth=2 generation=2 binding=[0-9]+" "内层 local generation"
require_log "function_scope block_enter fn=local_blocks depth=3 generation=3 scopes=4" "深层 block generation"
require_log "function_scope local fn=local_blocks name=x2 locals=3 depth=3 generation=3 binding=[0-9]+" "深层 local generation"
require_log "function_scope block_exit fn=local_blocks depth=0 generation=[1-9][0-9]* scopes=1" "函数体 block 退出后恢复根深度"

echo "✓ FunctionScopeIndex maintains local generation across block enter/exit"
