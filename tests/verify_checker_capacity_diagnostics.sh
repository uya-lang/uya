#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_ROOT="$REPO_ROOT/src"
CHECK_CALL="$REPO_ROOT/src/checker/check_call.uya"
CHECK_INTERVAL="$REPO_ROOT/src/checker/interval.uya"
CHECK_BUILD_INTERVAL="$REPO_ROOT/src/checker_build/interval.uya"
CHECK_MODULES="$REPO_ROOT/src/checker/modules.uya"
CHECK_GENERICS="$REPO_ROOT/src/checker/generics.uya"
CHECK_TYPES="$REPO_ROOT/src/checker/types.uya"
CHECK_BUILD_TYPES="$REPO_ROOT/src/checker_build/types.uya"
CHECK_EXPR="$REPO_ROOT/src/checker/check_expr.uya"

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

reject_source_pattern() {
    local pattern="$1"
    local description="$2"
    if grep -RInE --include='*.uya' "$pattern" "$SRC_ROOT"; then
        echo "错误: 仍存在静默 checker 固定表上限路径: $description" >&2
        return 1
    fi
}

require_pattern "checker async call graph" "$CHECK_CALL" "async call graph 边表上限 diagnostic"
require_pattern "checker async call visited" "$CHECK_CALL" "async call DFS visited 上限 diagnostic"
require_pattern "checker pointer nonnull table" "$CHECK_INTERVAL" "pointer nonnull proof 表上限 diagnostic"
require_pattern "checker pointer nullable table" "$CHECK_INTERVAL" "pointer nullable proof 表上限 diagnostic"
require_pattern "checker constraint table" "$CHECK_INTERVAL" "constraint proof 表上限 diagnostic"
require_pattern "checker union variant coverage table" "$CHECK_EXPR" "union variant coverage 动态表分配失败 diagnostic"
require_pattern "checker module table" "$CHECK_MODULES" "module 动态表分配失败 diagnostic"
require_pattern "checker import table" "$CHECK_MODULES" "import 动态表分配失败 diagnostic"
require_pattern "checker module cycle table" "$CHECK_MODULES" "module cycle visit/path 上限 diagnostic"
require_pattern "checker mono instance table" "$CHECK_GENERICS" "mono instance 动态表分配失败 diagnostic"
require_pattern "entries:[[:space:]]*SemanticVector" "$CHECK_TYPES" "checker 核心表使用 SemanticVector"
require_pattern "index:[[:space:]]*SemanticHash" "$CHECK_TYPES" "checker 核心表使用 SemanticHash"
require_pattern "entries:[[:space:]]*SemanticVector" "$CHECK_BUILD_TYPES" "cmd/build checker 核心表使用 SemanticVector"
require_pattern "index:[[:space:]]*SemanticHash" "$CHECK_BUILD_TYPES" "cmd/build checker 核心表使用 SemanticHash"
require_pattern "error_names:[[:space:]]*SemanticVector" "$CHECK_TYPES" "checker error name 表使用 SemanticVector"
require_pattern "moved_names:[[:space:]]*SemanticVector" "$CHECK_TYPES" "checker moved name 表使用 SemanticVector"
require_pattern "mono_instances:[[:space:]]*SemanticVector" "$CHECK_TYPES" "checker mono instance 表使用 SemanticVector"
require_pattern "async_call_edges:[[:space:]]*SemanticVector" "$CHECK_TYPES" "checker async call graph 使用 SemanticVector"
require_pattern "fn_call_edges:[[:space:]]*SemanticVector" "$CHECK_TYPES" "checker function call graph 使用 SemanticVector"
require_pattern "reachable_fn_decls:[[:space:]]*SemanticVector" "$CHECK_TYPES" "checker reachable function 集合使用 SemanticVector"
require_pattern "reachability_visit_index:[[:space:]]*SemanticHash" "$CHECK_TYPES" "checker reachability visit 使用 SemanticHash"

reject_pattern "async_call_edge_count[[:space:]]*>=[[:space:]]*@len\\(checker\\.async_call_edge_from\\)[[:space:]]*\\{[[:space:]]*return[[:space:]]+0;" "$CHECK_CALL" "async call graph 满后直接 return 0"
reject_pattern "visited_count[[:space:]]*>=[[:space:]]*MAX_ASYNC_CALL_VISITED[[:space:]]*\\{[[:space:]]*return[[:space:]]+0;" "$CHECK_CALL" "async call DFS visited 满后直接 return 0"
reject_pattern "pointer_nonnull_count[[:space:]]*>=[[:space:]]*MAX_POINTER_NAMES[[:space:]]*\\{[[:space:]]*return;" "$CHECK_INTERVAL" "pointer nonnull 满后直接 return"
reject_pattern "pointer_nullable_count[[:space:]]*>=[[:space:]]*MAX_POINTER_NAMES[[:space:]]*\\{[[:space:]]*return;" "$CHECK_INTERVAL" "pointer nullable 满后直接 return"
reject_pattern "min_needed[[:space:]]*>[[:space:]]*MAX_POINTER_NAMES" "$CHECK_INTERVAL" "pointer proof 表超过 MAX_POINTER_NAMES 后直接失败"
reject_pattern "const[[:space:]]+next_capacity:[[:space:]]*i32[[:space:]]*=[[:space:]]*MAX_POINTER_NAMES" "$CHECK_INTERVAL" "pointer proof 表扩容仍固定到 MAX_POINTER_NAMES"
reject_pattern "min_needed[[:space:]]*>[[:space:]]*MAX_POINTER_NAMES" "$CHECK_BUILD_INTERVAL" "cmd/build pointer proof 表超过 MAX_POINTER_NAMES 后直接失败"
reject_pattern "const[[:space:]]+next_capacity:[[:space:]]*i32[[:space:]]*=[[:space:]]*MAX_POINTER_NAMES" "$CHECK_BUILD_INTERVAL" "cmd/build pointer proof 表扩容仍固定到 MAX_POINTER_NAMES"
reject_pattern "constraint_count[[:space:]]*>=[[:space:]]*MAX_CONSTRAINTS[[:space:]]*\\{[[:space:]]*return;" "$CHECK_INTERVAL" "constraint 满后直接 return"
reject_pattern "return[[:space:]]+null;[[:space:]]*//[[:space:]]*哈希表已满" "$CHECK_MODULES" "module table 满后直接 return null"
reject_pattern "if[[:space:]]+visit_count[[:space:]]*<[[:space:]]*MAX_MODULES[[:space:]]*\\{" "$CHECK_MODULES" "module cycle visit table 满后静默跳过模块"
reject_pattern "checker[.]mono_instance_count[[:space:]]*>=[[:space:]]*MAX_MONO_INSTANCES[[:space:]]*\\{[[:space:]]*return[[:space:]]+-1;" "$CHECK_GENERICS" "mono instance 满后直接 return -1"
reject_pattern "const[[:space:]]+(SYMBOL_TABLE_SIZE|FUNCTION_TABLE_SIZE|MODULE_TABLE_SIZE|IMPORT_TABLE_SIZE)" "$CHECK_TYPES" "checker 仍定义核心固定表容量常量"
reject_pattern "const[[:space:]]+(SYMBOL_TABLE_SIZE|FUNCTION_TABLE_SIZE|MODULE_TABLE_SIZE|IMPORT_TABLE_SIZE)" "$CHECK_BUILD_TYPES" "cmd/build checker 仍定义核心固定表容量常量"
reject_pattern "const[[:space:]]+(MAX_ERROR_NAMES|MAX_MOVED_NAMES|MAX_MONO_INSTANCES|MAX_UNION_VARIANTS|MAX_INTERFACE_METHODS|MAX_MONO_NAME_LEN|MAX_MONO_NAME_LIMIT|MAX_POINTER_NAMES|MAX_CONSTRAINTS|MAX_PROOF_TABLE_CAPACITY|MAX_ASYNC_CALL_EDGES|MAX_FN_CALL_EDGES|MAX_FN_ROOTS|MAX_REACHABLE_FN_DECLS|MAX_REACHABILITY_VISIT_SLOTS|MAX_REACHABILITY_VISIT_MASK)" "$CHECK_TYPES" "checker 仍定义已动态化表容量常量"
reject_pattern "const[[:space:]]+(MAX_ERROR_NAMES|MAX_MOVED_NAMES|MAX_MONO_INSTANCES|MAX_UNION_VARIANTS|MAX_INTERFACE_METHODS|MAX_MONO_NAME_LEN|MAX_MONO_NAME_LIMIT|MAX_POINTER_NAMES|MAX_CONSTRAINTS|MAX_PROOF_TABLE_CAPACITY|MAX_ASYNC_CALL_EDGES|MAX_FN_CALL_EDGES|MAX_FN_ROOTS|MAX_REACHABLE_FN_DECLS|MAX_REACHABILITY_VISIT_SLOTS|MAX_REACHABILITY_VISIT_MASK)" "$CHECK_BUILD_TYPES" "cmd/build checker 仍定义已动态化表容量常量"
reject_pattern "slots:[[:space:]]*\\[&[^]]*:[[:space:]]*(SYMBOL_TABLE_SIZE|FUNCTION_TABLE_SIZE|MODULE_TABLE_SIZE|IMPORT_TABLE_SIZE)\\]" "$CHECK_TYPES" "checker 核心表仍使用固定 slots 数组"
reject_pattern "slots:[[:space:]]*\\[&[^]]*:[[:space:]]*(SYMBOL_TABLE_SIZE|FUNCTION_TABLE_SIZE|MODULE_TABLE_SIZE|IMPORT_TABLE_SIZE)\\]" "$CHECK_BUILD_TYPES" "cmd/build checker 核心表仍使用固定 slots 数组"
reject_source_pattern "SYMBOL_TABLE_SIZE|FUNCTION_TABLE_SIZE|MODULE_TABLE_SIZE|IMPORT_TABLE_SIZE|symbol_table[.]slots|function_table[.]slots|module_table[.]slots|import_table[.]slots" "src 中仍直接引用旧 checker 核心固定表"
reject_source_pattern "(^|[^[:alnum:]_])(MAX_ERROR_NAMES|MAX_MOVED_NAMES|MAX_MONO_INSTANCES|MAX_UNION_VARIANTS|MAX_INTERFACE_METHODS|MAX_MONO_NAME_LEN|MAX_MONO_NAME_LIMIT|MAX_POINTER_NAMES|MAX_CONSTRAINTS|MAX_PROOF_TABLE_CAPACITY|MAX_ASYNC_CALL_EDGES|MAX_FN_CALL_EDGES|MAX_FN_ROOTS|MAX_REACHABLE_FN_DECLS|MAX_REACHABILITY_VISIT_SLOTS|MAX_REACHABILITY_VISIT_MASK)([^[:alnum:]_]|$)" "src 中仍直接引用已动态化 checker 表容量常量"
reject_source_pattern "checker[.](error_hashes|async_call_edge_from|async_call_edge_to|fn_call_edge_from|fn_call_edge_to|reachability_visit_cache)" "src 中仍直接引用已移除的 checker 固定数组字段"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
probe="$tmpdir/many_functions.uya"
log="$tmpdir/many_functions.log"
old_function_table_size=8192
function_count=$((old_function_table_size + 8))
{
    for i in $(seq 0 "$function_count"); do
        printf 'fn checker_capacity_probe_%04d() i32 { return %d; }\n' "$i" "$i"
    done
    echo "export fn main() i32 { return 0; }"
} > "$probe"

set +e
output="$(cd "$REPO_ROOT" && UYA_ROOT="$REPO_ROOT/lib/" ./bin/uya check "$probe" 2>&1)"
status=$?
set -e
printf '%s\n' "$output" > "$log"
if [[ $status -ne 0 ]]; then
    echo "错误: 超过旧 FUNCTION_TABLE_SIZE 的程序未能 check 成功，函数表可能仍有固定上限" >&2
    cat "$log" >&2
    exit 1
fi
if grep -Eq "函数表容量不足|FUNCTION_TABLE_SIZE" "$log"; then
    echo "错误: 超过旧 FUNCTION_TABLE_SIZE 后仍输出函数表容量 diagnostic" >&2
    cat "$log" >&2
    exit 1
fi

echo "✓ checker 固定上限路径有诊断，核心表已改为动态存储"
