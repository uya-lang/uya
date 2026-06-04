#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
GUARD="$REPO_ROOT/tests/verify_no_fixed_compiler_tables.sh"

require_pattern() {
    local pattern="$1"
    local file="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 固定表新增冻结门禁缺少证据: $description" >&2
        return 1
    fi
}

dynamic_table_incomplete() {
    grep -Eq '^- \[[ ~f]\] 新建 `src/semantic/table\.uya`' "$TODO_DOC" && return 0
    grep -Eq '^- \[[ ~f]\] 动态表 API 必须包含' "$TODO_DOC" && return 0
    grep -Eq '^- \[[ ~f]\] 动态表必须记录' "$TODO_DOC" && return 0
    grep -Eq '^- \[[ ~f]\] 动态表增长必须检查' "$TODO_DOC" && return 0
    grep -Eq '^- \[[ ~f]\] intern 表按负载因子动态扩容' "$TODO_DOC" && return 0
    grep -Eq '^- \[[ ~f]\] `SemanticDb` 所有数组.*动态扩容' "$TODO_DOC" && return 0
    return 1
}

run_bad_diff_probe() {
    local tmp_dir bad_diff bad_out bad_err symbol
    tmp_dir="$(mktemp -d /tmp/uya-fixed-table-freeze.XXXXXX)"
    trap 'rm -rf "$tmp_dir"' RETURN
    bad_diff="$tmp_dir/bad-fixed-table.diff"
    bad_out="$tmp_dir/bad.out"
    bad_err="$tmp_dir/bad.err"

    cat >"$bad_diff" <<'EOF'
diff --git a/src/main.uya b/src/main.uya
--- a/src/main.uya
+++ b/src/main.uya
@@ -0,0 +1,2 @@
+const INPUT_FILE_TABLE_SIZE: i32 = 128;
+var input_file_table: [&byte: INPUT_FILE_TABLE_SIZE] = [];
diff --git a/src/codegen/c99/new_tables.uya b/src/codegen/c99/new_tables.uya
--- a/src/codegen/c99/new_tables.uya
+++ b/src/codegen/c99/new_tables.uya
@@ -0,0 +1,2 @@
+const C99_NEW_WORKLIST_SIZE: i32 = 64;
+var c99_new_worklist: [&ASTNode: C99_NEW_WORKLIST_SIZE] = [];
diff --git a/src/checker/new_tables.uya b/src/checker/new_tables.uya
--- a/src/checker/new_tables.uya
+++ b/src/checker/new_tables.uya
@@ -0,0 +1,2 @@
+const CHECKER_NEW_CACHE_SIZE: i32 = 256;
+var checker_new_cache: [&ASTNode: CHECKER_NEW_CACHE_SIZE] = [];
diff --git a/src/exec/new_tables.uya b/src/exec/new_tables.uya
--- a/src/exec/new_tables.uya
+++ b/src/exec/new_tables.uya
@@ -0,0 +1,2 @@
+const EXEC_NEW_FRAME_TABLE_SIZE: i32 = 512;
+var exec_new_frame_table: [i32: EXEC_NEW_FRAME_TABLE_SIZE] = [];
EOF

    if UYA_FIXED_TABLE_DIFF_FILE="$bad_diff" bash "$GUARD" >"$bad_out" 2>"$bad_err"; then
        echo "错误: 新增固定容量 compiler table 样例应被冻结门禁拒绝" >&2
        cat "$bad_out" >&2
        return 1
    fi

    for symbol in INPUT_FILE_TABLE_SIZE C99_NEW_WORKLIST_SIZE CHECKER_NEW_CACHE_SIZE EXEC_NEW_FRAME_TABLE_SIZE; do
        if ! grep -q "$symbol" "$bad_err"; then
            echo "错误: 冻结门禁拒绝诊断缺少 $symbol" >&2
            cat "$bad_err" >&2
            return 1
        fi
    done
}

if dynamic_table_incomplete; then
    require_pattern "固定表新增冻结门禁" "$ARCH_DOC" "架构文档必须声明冻结期门禁"
    require_pattern "动态表基础设施完成前.*不得新增.*固定容量" "$ARCH_DOC" "动态表完成前必须禁止新增固定容量 compiler table"
else
    echo "info: 动态表基础设施 TODO 看起来已完成，仍保留新增固定表 no-regression 门禁"
fi

require_pattern "tests/verify_fixed_table_freeze_policy\\.sh" "$TODO_DOC" "TODO 验证块必须包含冻结策略门禁"
require_pattern "tests/verify_no_fixed_compiler_tables\\.sh" "$TODO_DOC" "TODO 验证块必须包含新增固定表 diff 门禁"
require_pattern "旧固定表.*oracle/fallback" "$ARCH_DOC" "旧固定表只能作为 oracle/fallback"

bash "$GUARD" --self-test
run_bad_diff_probe

echo "✓ 动态表基础设施完成前的新增固定表冻结门禁有效"
