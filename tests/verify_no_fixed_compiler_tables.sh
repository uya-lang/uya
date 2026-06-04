#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_REF="${UYA_FIXED_TABLE_BASE_REF:-HEAD}"
DIFF_FILE="${UYA_FIXED_TABLE_DIFF_FILE:-}"

read_diff() {
    if [[ -n "$DIFF_FILE" ]]; then
        if [[ "$DIFF_FILE" == "-" ]]; then
            cat
        else
            cat "$DIFF_FILE"
        fi
        return
    fi

    git -C "$REPO_ROOT" diff --no-ext-diff --unified=0 "$BASE_REF" -- \
        src/main.uya \
        src/checker \
        src/codegen/c99 \
        src/exec
}

is_fixed_capacity_shape() {
    local line="$1"
    if [[ "$line" =~ \[[^][]+:[[:space:]]*([A-Z][A-Z0-9_]*|[0-9][0-9]*)\] ]]; then
        return 0
    fi
    if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?const[[:space:]]+[A-Z][A-Z0-9_]*[[:space:]]*:.*=[[:space:]]*[0-9] ]]; then
        return 0
    fi
    if [[ "$line" =~ count[[:space:]]*\>\=[[:space:]]*([A-Z][A-Z0-9_]*|[0-9][0-9]*) ]]; then
        return 0
    fi
    if [[ "$line" =~ \>\=[[:space:]]*(C99_MAX_|MAX_|EXEC_MAX_|CHECKER_[A-Z0-9_]*SIZE|FUNCTION_TABLE_SIZE|SYMBOL_TABLE_SIZE|IMPORT_TABLE_SIZE|MODULE_TABLE_SIZE|STRING_POOL_SIZE) ]]; then
        return 0
    fi
    return 1
}

has_table_role_name() {
    local lower="$1"
    [[ "$lower" =~ (table|tables|cache|caches|index|indices|idx|slot|slots|bucket|buckets|queue|stack|worklist|list|lists|map|mapping|local|locals|global|globals|decl|decls|symbol|symbols|function|functions|module|modules|import|imports|mono|reachable|edge|edges|frame|frames|bytecode|instr|instrs|const_pool|host_call|scope|scopes|defer|defers|errdefer|drop|drops|error_names|moved_names|string_constants|string_pool|resolved|processed|program|programs|files|paths|bindings|args|fields) ]]
}

is_allowed_small_buffer() {
    local lower="$1"
    if has_table_role_name "$lower"; then
        return 1
    fi
    [[ "$lower" =~ (buf|buffer|path|filename|file_name|name|message|msg|fmt|format|num|digit|suffix|prefix|cmd|command|tmp|temp|line|cwd) ]]
}

is_forbidden_added_line() {
    local line="$1"
    local lower
    lower="$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')"

    if [[ "$lower" =~ ^[[:space:]]*(//|$) ]]; then
        return 1
    fi
    if ! is_fixed_capacity_shape "$line"; then
        return 1
    fi
    if is_allowed_small_buffer "$lower"; then
        return 1
    fi
    if has_table_role_name "$lower"; then
        return 0
    fi
    return 1
}

current_file=""
current_line=0
violations=0

while IFS= read -r diff_line; do
    if [[ "$diff_line" =~ ^diff[[:space:]]--git[[:space:]]a/(.*)[[:space:]]b/(.*)$ ]]; then
        current_file="${BASH_REMATCH[2]}"
        current_line=0
        continue
    fi
    if [[ "$diff_line" =~ ^@@[[:space:]]-[0-9]+(,[0-9]+)?[[:space:]]\+([0-9]+)(,[0-9]+)?[[:space:]]@@ ]]; then
        current_line="${BASH_REMATCH[2]}"
        continue
    fi
    if [[ "$diff_line" == "+++"* || "$diff_line" == "---"* ]]; then
        continue
    fi
    if [[ "$diff_line" == "+"* ]]; then
        added="${diff_line:1}"
        if is_forbidden_added_line "$added"; then
            printf '%s:%s: 新增编译器表/缓存/list 不得使用固定容量: %s\n' \
                "${current_file:-unknown}" "${current_line:-0}" "$added" >&2
            violations=$((violations + 1))
        fi
        if [[ "$current_line" =~ ^[0-9]+$ ]]; then
            current_line=$((current_line + 1))
        fi
        continue
    fi
    if [[ "$diff_line" == "-"* ]]; then
        continue
    fi
    if [[ "$current_line" =~ ^[0-9]+$ && "$current_line" -gt 0 ]]; then
        current_line=$((current_line + 1))
    fi
done < <(read_diff)

if [[ "$violations" -gt 0 ]]; then
    echo "错误: 检测到新增固定容量 compiler table/index/cache/list/mapping；请改为动态表或明确小缓冲例外。" >&2
    exit 1
fi

echo "✓ 未检测到新增固定容量 compiler table/index/cache/list/mapping"
