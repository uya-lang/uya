#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_REF="${UYA_FIXED_TABLE_BASE_REF:-HEAD}"
DIFF_FILE="${UYA_FIXED_TABLE_DIFF_FILE:-}"
SELF_TEST=0
PRINT_SCOPE=0
SCAN_PATHS=(
    "src/main.uya"
    "src/checker"
    "src/codegen/c99"
    "src/exec"
)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --self-test)
            SELF_TEST=1
            shift
            ;;
        --print-scope)
            PRINT_SCOPE=1
            shift
            ;;
        -h|--help)
            echo "用法: bash tests/verify_no_fixed_compiler_tables.sh [--self-test] [--print-scope]" >&2
            exit 0
            ;;
        *)
            echo "错误: 未知参数: $1" >&2
            exit 1
            ;;
    esac
done

read_diff() {
    if [[ -n "$DIFF_FILE" ]]; then
        if [[ "$DIFF_FILE" == "-" ]]; then
            cat
        else
            cat "$DIFF_FILE"
        fi
        return
    fi

    git -C "$REPO_ROOT" diff --no-ext-diff --unified=0 "$BASE_REF" -- "${SCAN_PATHS[@]}"
}

print_scope() {
    local path
    for path in "${SCAN_PATHS[@]}"; do
        printf '%s\n' "$path"
    done
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

run_guard() {
    local current_file=""
    local current_line=0
    local violations=0
    local diff_line added

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
        return 1
    fi

    echo "✓ 未检测到新增固定容量 compiler table/index/cache/list/mapping"
}

run_self_test() {
    local tmp_dir small_diff bad_diff small_out small_err bad_out bad_err scope_out
    tmp_dir="$(mktemp -d /tmp/uya-fixed-table-guard.XXXXXX)"
    trap 'rm -rf "$tmp_dir"' RETURN
    small_diff="$tmp_dir/small-buffer.diff"
    bad_diff="$tmp_dir/fixed-table.diff"
    small_out="$tmp_dir/small.out"
    small_err="$tmp_dir/small.err"
    bad_out="$tmp_dir/bad.out"
    bad_err="$tmp_dir/bad.err"
    scope_out="$tmp_dir/scope.out"

    cat >"$small_diff" <<'EOF'
diff --git a/src/checker/example.uya b/src/checker/example.uya
--- a/src/checker/example.uya
+++ b/src/checker/example.uya
@@ -0,0 +1,4 @@
+const NAME_BUF_SIZE: i32 = 256;
+const PATH_BUF_SIZE: i32 = 1024;
+var msg_buf: [byte: 256] = [];
+var temp_path_buf: [byte: PATH_BUF_SIZE] = [];
EOF

    cat >"$bad_diff" <<'EOF'
diff --git a/src/checker/example.uya b/src/checker/example.uya
--- a/src/checker/example.uya
+++ b/src/checker/example.uya
@@ -0,0 +1,4 @@
+const NEW_CACHE_SIZE: i32 = 128;
+var new_cache: [&ASTNode: NEW_CACHE_SIZE] = [];
+var pending_worklist: [&ASTNode: 64] = [];
+if pending_count >= NEW_CACHE_SIZE { return -1; }
EOF

    if ! UYA_FIXED_TABLE_DIFF_FILE="$small_diff" bash "$0" >"$small_out" 2>"$small_err"; then
        echo "错误: 小缓冲样例应被允许" >&2
        cat "$small_err" >&2
        return 1
    fi
    if UYA_FIXED_TABLE_DIFF_FILE="$bad_diff" bash "$0" >"$bad_out" 2>"$bad_err"; then
        echo "错误: table/cache/list 样例应被拒绝" >&2
        cat "$bad_out" >&2
        return 1
    fi
    if ! grep -q "NEW_CACHE_SIZE" "$bad_err" || ! grep -q "new_cache" "$bad_err" || ! grep -q "pending_worklist" "$bad_err"; then
        echo "错误: table/cache/list 拒绝诊断缺少预期证据" >&2
        cat "$bad_err" >&2
        return 1
    fi
    if ! bash "$0" --print-scope >"$scope_out"; then
        echo "错误: 扫描范围输出失败" >&2
        return 1
    fi
    for required_path in src/main.uya src/checker src/codegen/c99 src/exec; do
        if ! grep -qx "$required_path" "$scope_out"; then
            echo "错误: 扫描范围缺少 $required_path" >&2
            cat "$scope_out" >&2
            return 1
        fi
    done

    echo "✓ fixed compiler table guard 小缓冲/表缓存区分自测通过"
}

if [[ "$PRINT_SCOPE" -ne 0 ]]; then
    print_scope
    exit 0
fi

if [[ "$SELF_TEST" -ne 0 ]]; then
    run_self_test
    exit 0
fi

run_guard
