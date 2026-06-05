#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TYPES_FILE="$REPO_ROOT/src/checker/types.uya"
SYMBOLS_FILE="$REPO_ROOT/src/checker/symbols.uya"
CHECK_STMT_FILE="$REPO_ROOT/src/checker/check_stmt.uya"
COMPILER="$REPO_ROOT/bin/uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: FunctionScopeIndex 参数登记缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$TYPES_FILE" "$SYMBOLS_FILE" "$CHECK_STMT_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TYPES_FILE" "function_scope_index:[[:space:]]+FunctionScopeIndex" "TypeChecker 持有 FunctionScopeIndex"
require_pattern "$SYMBOLS_FILE" "function_scope_index_init\\(&checker\\.function_scope_index\\)" "checker_init 初始化 FunctionScopeIndex"
require_pattern "$CHECK_STMT_FILE" "checker_function_scope_register_params" "函数入口参数登记 helper"
require_pattern "$CHECK_STMT_FILE" "function_scope_index_add_param\\(&checker\\.function_scope_index" "函数入口批量写入 params"
require_pattern "$CHECK_STMT_FILE" "UYA_DUMP_FUNCTION_SCOPE" "参数登记 dump 验证开关"

tmp_dir="$(mktemp -d /tmp/uya-function-scope-params.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

{
    printf 'fn many_params(\n'
    for i in $(seq 0 95); do
        if [[ "$i" -lt 95 ]]; then
            printf '    p%03d: i32,\n' "$i"
        else
            printf '    p%03d: i32\n' "$i"
        fi
    done
    printf ') i32 {\n'
    printf '    return p000 + p095;\n'
    printf '}\n\n'
    printf 'export fn main() i32 {\n'
    printf '    return 0;\n'
    printf '}\n'
} >"$tmp_dir/main.uya"

log_file="$tmp_dir/check.log"
(cd "$REPO_ROOT" && UYA_DUMP_FUNCTION_SCOPE=1 "$COMPILER" check "$tmp_dir/main.uya" >"$log_file" 2>&1)

line="$(grep 'function_scope fn=many_params ' "$log_file" | tail -n 1 || true)"
if [[ -z "$line" ]]; then
    echo "错误: 未在 checker dump 中看到 many_params 的 FunctionScopeIndex 参数登记" >&2
    cat "$log_file" >&2
    exit 1
fi

if [[ ! "$line" =~ params=([0-9]+)[[:space:]]+param_capacity=([0-9]+)[[:space:]]+param_reallocs=([0-9]+)[[:space:]]+bindings=([0-9]+) ]]; then
    echo "错误: FunctionScopeIndex dump 格式不可解析: $line" >&2
    exit 1
fi

params="${BASH_REMATCH[1]}"
capacity="${BASH_REMATCH[2]}"
reallocs="${BASH_REMATCH[3]}"
bindings="${BASH_REMATCH[4]}"

if [[ "$params" -ne 96 || "$bindings" -ne 96 ]]; then
    echo "错误: 参数登记数量不正确: params=$params bindings=$bindings" >&2
    exit 1
fi
if [[ "$capacity" -lt "$params" ]]; then
    echo "错误: 参数动态数组容量小于数量: capacity=$capacity params=$params" >&2
    exit 1
fi
if [[ "$reallocs" -le 1 ]]; then
    echo "错误: 参数动态数组没有发生可解释扩容: reallocs=$reallocs" >&2
    exit 1
fi

echo "✓ FunctionScopeIndex registers all function params at function entry"
