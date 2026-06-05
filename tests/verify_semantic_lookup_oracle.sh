#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOOKUP_FILE="$REPO_ROOT/src/checker/lookup.uya"
CHECKER_ENTRY_FILE="$REPO_ROOT/src/checker/check_expr_extra.uya"
COMPILER="$REPO_ROOT/bin/uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: Semantic lookup oracle 缺少证据: $description" >&2
        return 1
    fi
}

assert_no_oracle_mismatch() {
    local stderr_file="$1"
    if grep -Fq "semantic_lookup_oracle mismatch" "$stderr_file"; then
        echo "错误: Semantic lookup oracle 发现新旧 lookup 不一致" >&2
        cat "$stderr_file" >&2
        return 1
    fi
}

run_oracle_test() {
    local label="$1"
    local test_file="$2"
    local stdout_file="$TMP_DIR/${label}.stdout"
    local stderr_file="$TMP_DIR/${label}.stderr"
    UYA_SEMANTIC_LOOKUP_ORACLE=1 "$COMPILER" test "$test_file" --no-split-c >"$stdout_file" 2>"$stderr_file"
    assert_no_oracle_mismatch "$stderr_file"
}

for file in "$LOOKUP_FILE" "$CHECKER_ENTRY_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOOKUP_FILE" "UYA_SEMANTIC_LOOKUP_ORACLE" "debug 比对环境变量"
require_pattern "$LOOKUP_FILE" "lookup_semantic_oracle_enabled" "debug 比对开关 helper"
require_pattern "$LOOKUP_FILE" "lookup_semantic_oracle_checked" "debug 开关结果缓存"
require_pattern "$LOOKUP_FILE" "lookup_compare_decl_oracle" "声明 lookup oracle 比对 helper"
require_pattern "$LOOKUP_FILE" "lookup_compare_enum_variant_oracle" "枚举变体 lookup oracle 比对 helper"
require_pattern "$LOOKUP_FILE" "semantic_lookup_oracle mismatch" "稳定 mismatch 标记"
require_pattern "$LOOKUP_FILE" "lookup_scan_type_alias_from_program" "type alias 旧扫描 oracle"
require_pattern "$LOOKUP_FILE" "lookup_scan_struct_decl_from_program" "struct 旧扫描 oracle"
require_pattern "$LOOKUP_FILE" "lookup_scan_union_decl_from_program" "union 旧扫描 oracle"
require_pattern "$LOOKUP_FILE" "lookup_scan_interface_decl_from_program" "interface 旧扫描 oracle"
require_pattern "$LOOKUP_FILE" "lookup_scan_enum_decl_from_program" "enum 旧扫描 oracle"
require_pattern "$LOOKUP_FILE" "lookup_scan_is_enum_variant_name_in_program" "enum variant 旧扫描 oracle"
require_pattern "$LOOKUP_FILE" "lookup_compare_decl_oracle\\(\"type_alias\" as &byte, alias_name" "type alias 新旧 AST 节点比对"
require_pattern "$LOOKUP_FILE" "lookup_compare_decl_oracle\\(\"struct\" as &byte, struct_name" "struct 新旧 AST 节点比对"
require_pattern "$LOOKUP_FILE" "lookup_compare_decl_oracle\\(\"union\" as &byte, union_name" "union 新旧 AST 节点比对"
require_pattern "$LOOKUP_FILE" "lookup_compare_decl_oracle\\(\"interface\" as &byte, interface_name" "interface 新旧 AST 节点比对"
require_pattern "$LOOKUP_FILE" "lookup_compare_decl_oracle\\(\"enum\" as &byte, enum_name" "enum 新旧 AST 节点比对"
require_pattern "$LOOKUP_FILE" "lookup_compare_enum_variant_oracle\\(name, semantic_variant, oracle_variant\\)" "enum variant 新旧诊断条件比对"
require_pattern "$CHECKER_ENTRY_FILE" "checker_register_semantic_lookup_db\\(ast_ptr, &checker\\.semantic_db\\)" "SemanticDb 构建完成后注册 lookup 上下文"

TMP_DIR="$(mktemp -d /tmp/uya-semantic-lookup-oracle.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

run_oracle_test "type_alias" "$REPO_ROOT/tests/test_type_alias.uya"
run_oracle_test "static_type_alias" "$REPO_ROOT/tests/test_static_method_type_alias.uya"
run_oracle_test "alias_context" "$REPO_ROOT/tests/test_semantic_lookup_alias_context.uya"
run_oracle_test "struct" "$REPO_ROOT/tests/struct_test.uya"
run_oracle_test "static_struct" "$REPO_ROOT/tests/test_static_method_struct.uya"
run_oracle_test "generic_struct" "$REPO_ROOT/tests/test_generic_multi_instance.uya"
run_oracle_test "enum_basic" "$REPO_ROOT/tests/test_enum_basic.uya"
run_oracle_test "enum_member" "$REPO_ROOT/tests/test_enum_member_access.uya"
run_oracle_test "enum_variant_context" "$REPO_ROOT/tests/test_semantic_lookup_enum_variant.uya"
run_oracle_test "function_family" "$REPO_ROOT/tests/test_semantic_lookup_function_family.uya"
run_oracle_test "union" "$REPO_ROOT/tests/test_union.uya"
run_oracle_test "static_union" "$REPO_ROOT/tests/test_static_method_union.uya"
run_oracle_test "interface" "$REPO_ROOT/tests/test_interface.uya"
run_oracle_test "generic_interface" "$REPO_ROOT/tests/test_generic_interface_impl.uya"
run_oracle_test "interface_compose" "$REPO_ROOT/tests/test_interface_compose.uya"

cat >"$TMP_DIR/bare_enum.uya" <<'EOF'
enum Color {
    RED,
    BLUE,
}

export fn main() i32 {
    const value: Color = RED;
    _ = value;
    return 0;
}
EOF

if UYA_SEMANTIC_LOOKUP_ORACLE=1 "$COMPILER" check "$TMP_DIR/bare_enum.uya" >"$TMP_DIR/bare.stdout" 2>"$TMP_DIR/bare.stderr"; then
    echo "错误: 裸枚举常量应触发诊断" >&2
    exit 1
fi
assert_no_oracle_mismatch "$TMP_DIR/bare.stderr"
if ! grep -Fq "不能使用裸枚举常量" "$TMP_DIR/bare.stderr"; then
    echo "错误: 裸枚举常量诊断文案缺失" >&2
    cat "$TMP_DIR/bare.stderr" >&2
    exit 1
fi

echo "✓ Semantic lookup oracle verified"
