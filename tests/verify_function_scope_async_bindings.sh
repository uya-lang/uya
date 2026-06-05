#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK_STMT_FILE="$REPO_ROOT/src/checker/check_stmt.uya"
SCOPE_FILE="$REPO_ROOT/src/checker/function_scope.uya"
COMPILER="$REPO_ROOT/bin/uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: FunctionScopeIndex async binding 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$CHECK_STMT_FILE" "$SCOPE_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$SCOPE_FILE" "function_scope_index_add_async_binding" "async binding 追加 API"
require_pattern "$SCOPE_FILE" "function_scope_index_find_binding" "同一 by-name 查询 API"
require_pattern "$CHECK_STMT_FILE" "checker_var_decl_init_is_await_bind" "checker 识别 @await 绑定"
require_pattern "$CHECK_STMT_FILE" "function_scope_index_add_async_binding\\(&checker\\.function_scope_index" "checker 登记 async bind"
require_pattern "$CHECK_STMT_FILE" "visible_kind" "dump 输出同一查询模型命中类别"

tmp_dir="$(mktemp -d /tmp/uya-function-scope-async.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.uya" <<'EOF'
use std.async;

fn ready_i32(v: i32) Future<!i32> {
    const p: Poll<!i32> = Poll<!i32>.Ready(ok<i32>(v));
    return Future<!i32>{ state: p };
}

@async_fn
fn async_scope(seed: i32) Future<!i32> {
    const ordinary: i32 = seed + 1;
    const awaited: i32 = try @await ready_i32(ordinary);
    const direct: !i32 = @await ready_i32(awaited);
    const direct_val: i32 = direct catch { 0 - 7; };
    {
        var nested: i32 = direct_val + ordinary;
        return nested;
    }
    return ordinary;
}

export fn main() i32 {
    return 0;
}
EOF

log_file="$tmp_dir/check.log"
(cd "$REPO_ROOT" && UYA_DUMP_FUNCTION_SCOPE=1 "$COMPILER" check "$tmp_dir/main.uya" >"$log_file" 2>&1)

require_log() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$log_file"; then
        echo "错误: FunctionScopeIndex async binding dump 缺少: $description" >&2
        cat "$log_file" >&2
        exit 1
    fi
}

require_log "function_scope local fn=async_scope name=ordinary locals=1 depth=1 generation=1 binding=[0-9]+ visible_kind=2 visible_depth=1" "async 函数普通局部进入 LOCAL 查询模型"
require_log "function_scope async_bind fn=async_scope name=awaited asyncs=1 depth=1 generation=1 binding=[0-9]+ visible_kind=4 visible_depth=1" "try @await bind 进入 ASYNC 查询模型"
require_log "function_scope async_bind fn=async_scope name=direct asyncs=2 depth=1 generation=1 binding=[0-9]+ visible_kind=4 visible_depth=1" "直接 @await bind 进入 ASYNC 查询模型"
require_log "function_scope local fn=async_scope name=direct_val locals=2 depth=1 generation=[1-9][0-9]* binding=[0-9]+ visible_kind=2 visible_depth=1" "async bind 后续普通局部仍可查询"
require_log "function_scope local fn=async_scope name=nested locals=3 depth=2 generation=[1-9][0-9]* binding=[0-9]+ visible_kind=2 visible_depth=2" "async 函数内嵌套 block local 进入同一查询模型"

echo "✓ FunctionScopeIndex registers async binds and async locals in the same scope lookup model"
