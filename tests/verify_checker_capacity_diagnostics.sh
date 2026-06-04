#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK_CALL="$REPO_ROOT/src/checker/check_call.uya"
CHECK_INTERVAL="$REPO_ROOT/src/checker/interval.uya"
CHECK_MODULES="$REPO_ROOT/src/checker/modules.uya"
CHECK_GENERICS="$REPO_ROOT/src/checker/generics.uya"

require_pattern() {
    local pattern="$1"
    local file="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 缺少 checker 固定表容量 diagnostic 证据: $description" >&2
        return 1
    fi
}

reject_pattern() {
    local pattern="$1"
    local file="$2"
    local description="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "错误: 仍存在静默 checker 固定表上限路径: $description" >&2
        return 1
    fi
}

require_pattern "checker async call graph" "$CHECK_CALL" "async call graph 边表上限 diagnostic"
require_pattern "checker async call visited" "$CHECK_CALL" "async call DFS visited 上限 diagnostic"
require_pattern "checker pointer nonnull table" "$CHECK_INTERVAL" "pointer nonnull proof 表上限 diagnostic"
require_pattern "checker pointer nullable table" "$CHECK_INTERVAL" "pointer nullable proof 表上限 diagnostic"
require_pattern "checker constraint table" "$CHECK_INTERVAL" "constraint proof 表上限 diagnostic"
require_pattern "checker module table" "$CHECK_MODULES" "module hash table 上限 diagnostic"
require_pattern "checker import table" "$CHECK_MODULES" "import table 上限 diagnostic"
require_pattern "checker module cycle table" "$CHECK_MODULES" "module cycle visit/path 上限 diagnostic"
require_pattern "checker mono instance table" "$CHECK_GENERICS" "mono instance 表上限 diagnostic"

reject_pattern "async_call_edge_count[[:space:]]*>=[[:space:]]*@len\\(checker\\.async_call_edge_from\\)[[:space:]]*\\{[[:space:]]*return[[:space:]]+0;" "$CHECK_CALL" "async call graph 满后直接 return 0"
reject_pattern "visited_count[[:space:]]*>=[[:space:]]*MAX_ASYNC_CALL_VISITED[[:space:]]*\\{[[:space:]]*return[[:space:]]+0;" "$CHECK_CALL" "async call DFS visited 满后直接 return 0"
reject_pattern "pointer_nonnull_count[[:space:]]*>=[[:space:]]*MAX_POINTER_NAMES[[:space:]]*\\{[[:space:]]*return;" "$CHECK_INTERVAL" "pointer nonnull 满后直接 return"
reject_pattern "pointer_nullable_count[[:space:]]*>=[[:space:]]*MAX_POINTER_NAMES[[:space:]]*\\{[[:space:]]*return;" "$CHECK_INTERVAL" "pointer nullable 满后直接 return"
reject_pattern "constraint_count[[:space:]]*>=[[:space:]]*MAX_CONSTRAINTS[[:space:]]*\\{[[:space:]]*return;" "$CHECK_INTERVAL" "constraint 满后直接 return"
reject_pattern "return[[:space:]]+null;[[:space:]]*//[[:space:]]*哈希表已满" "$CHECK_MODULES" "module table 满后直接 return null"
reject_pattern "if[[:space:]]+visit_count[[:space:]]*<[[:space:]]*MAX_MODULES[[:space:]]*\\{" "$CHECK_MODULES" "module cycle visit table 满后静默跳过模块"
reject_pattern "checker[.]mono_instance_count[[:space:]]*>=[[:space:]]*MAX_MONO_INSTANCES[[:space:]]*\\{[[:space:]]*return[[:space:]]+-1;" "$CHECK_GENERICS" "mono instance 满后直接 return -1"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
probe="$tmpdir/many_functions.uya"
log="$tmpdir/many_functions.log"
{
    for i in $(seq 0 4097); do
        printf 'fn checker_capacity_probe_%04d() i32 { return %d; }\n' "$i" "$i"
    done
    echo "export fn main() i32 { return 0; }"
} > "$probe"

set +e
output="$(cd "$REPO_ROOT" && ./bin/uya check "$probe" 2>&1)"
status=$?
set -e
printf '%s\n' "$output" > "$log"
if [[ $status -eq 0 ]]; then
    echo "错误: 超过 FUNCTION_TABLE_SIZE 的程序仍然 check 成功，疑似静默跳过函数登记" >&2
    cat "$log" >&2
    exit 1
fi
if ! grep -Eq "函数表容量不足|FUNCTION_TABLE_SIZE" "$log"; then
    echo "错误: 超过 FUNCTION_TABLE_SIZE 的程序未输出函数表容量 diagnostic" >&2
    cat "$log" >&2
    exit 1
fi

echo "✓ checker 固定表上限路径均有明确 diagnostic"
