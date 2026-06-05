#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
TYPED_FILE="$REPO_ROOT/src/typed/program.uya"
MAIN_FILE="$REPO_ROOT/src/main.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: TypedProgram 定义缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$TABLE_FILE" "$IDS_FILE" "$TYPED_FILE" "$MAIN_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$MAIN_FILE" '^use[[:space:]]+typed;' "src/main.uya 接入 typed 模块"
require_pattern "$TYPED_FILE" '^export[[:space:]]+struct[[:space:]]+TypedProgram' "TypedProgram 结构"
require_pattern "$TYPED_FILE" '^export[[:space:]]+struct[[:space:]]+TypedCallTarget' "TypedCallTarget 结构"
require_pattern "$TYPED_FILE" '^export[[:space:]]+struct[[:space:]]+TypedMethodDispatch' "TypedMethodDispatch 结构"
require_pattern "$TYPED_FILE" '^export[[:space:]]+struct[[:space:]]+TypedProofResult' "TypedProofResult 结构"
require_pattern "$TYPED_FILE" 'expr_types:[[:space:]]*SemanticVector' "expr_types 动态表"
require_pattern "$TYPED_FILE" 'identifier_bindings:[[:space:]]*SemanticVector' "identifier_bindings 动态表"
require_pattern "$TYPED_FILE" 'call_targets:[[:space:]]*SemanticVector' "call_targets 动态表"
require_pattern "$TYPED_FILE" 'method_dispatch:[[:space:]]*SemanticVector' "method_dispatch 动态表"
require_pattern "$TYPED_FILE" 'field_access:[[:space:]]*SemanticVector' "field_access 动态表"
require_pattern "$TYPED_FILE" 'global_init_order:[[:space:]]*SemanticVector' "global_init_order 动态表"
require_pattern "$TYPED_FILE" 'reachable_roots:[[:space:]]*SemanticVector' "reachable_roots 动态表"
require_pattern "$TYPED_FILE" 'proof_results:[[:space:]]*SemanticVector' "proof_results 动态表"
require_pattern "$TYPED_FILE" 'typed_program_reserve_exprs' "reserve API"
require_pattern "$TYPED_FILE" 'typed_program_set_expr_type' "ExprId -> TypeId append/set API"
require_pattern "$TYPED_FILE" 'typed_program_set_identifier_binding' "ExprId -> SymbolId API"
require_pattern "$TYPED_FILE" 'typed_program_set_call_target' "ExprId -> CallTarget API"
require_pattern "$TYPED_FILE" 'typed_program_set_method_dispatch' "ExprId -> MethodDispatch API"
require_pattern "$TYPED_FILE" 'typed_program_set_field_access' "ExprId -> FieldId API"
require_pattern "$TYPED_FILE" 'typed_program_append_global_init' "global_init_order append API"
require_pattern "$TYPED_FILE" 'typed_program_append_reachable_root' "reachable_roots append API"
require_pattern "$TYPED_FILE" 'typed_program_append_proof_result' "proof_results append API"
require_pattern "$TYPED_FILE" 'typed_program_stats' "stats API"
require_pattern "$TYPED_FILE" 'typed_program_estimated_bytes' "estimated bytes API"
require_pattern "$TYPED_FILE" 'resident_peak_bytes:[[:space:]]*usize' "TypedProgram peak resident bytes 字段"
require_pattern "$TYPED_FILE" 'lifecycle_state:[[:space:]]*i32' "TypedProgram lifecycle state 字段"
require_pattern "$TYPED_FILE" 'typed_program_current_bytes' "current bytes API"
require_pattern "$TYPED_FILE" 'typed_program_peak_bytes' "peak bytes API"
require_pattern "$TYPED_FILE" 'typed_program_lifetime_stats' "lifetime stats API"

if grep -Eq 'ASTNode|ast_node|program_decls|LoweredProgram|lowered_program' "$TYPED_FILE"; then
    echo "错误: TypedProgram 不应复制或持有 AST/LoweredProgram 子树引用" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-typed-program.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$TABLE_FILE" >"$tmp_dir/main.uya"
cat "$IDS_FILE" >>"$tmp_dir/main.uya"
cat "$TYPED_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn typed_test_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn typed_test_program() TypedProgram {
    return TypedProgram{
        expr_count: 0,
        global_init_count: 0,
        reachable_root_count: 0,
        proof_result_count: 0,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: TYPED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        expr_types: typed_test_vector(),
        identifier_bindings: typed_test_vector(),
        call_targets: typed_test_vector(),
        method_dispatch: typed_test_vector(),
        field_access: typed_test_vector(),
        global_init_order: typed_test_vector(),
        reachable_roots: typed_test_vector(),
        proof_results: typed_test_vector(),
    };
}

test "typed program stores compact id tables" {
    var program: TypedProgram = typed_test_program();
    typed_program_init(&program);
    try assert_eq_i32(program.expr_count, 0);
    try assert_eq_i32(typed_program_lifecycle_state(&program), TYPED_PROGRAM_LIFECYCLE_ACTIVE);
    try assert_eq_i32(typed_program_current_bytes(&program) >= @size_of(TypedProgram), true);
    try assert_eq_i32(typed_program_peak_bytes(&program) >= typed_program_current_bytes(&program), true);
    try assert_eq_i32(typed_program_reserve_exprs(&program, 16usize), 0);
    try assert_eq_i32(program.expr_types.capacity >= 16usize, true);

    try assert_eq_i32(typed_program_set_expr_type(&program, 3, 42), 0);
    try assert_eq_i32(typed_program_set_identifier_binding(&program, 3, 7), 0);
    var target: TypedCallTarget = TypedCallTarget{
        kind: TYPED_CALL_TARGET_FUNCTION,
        function_id: 5,
        decl_id: 9,
        symbol_id: 7,
        mono_instance_id: 1,
    };
    try assert_eq_i32(typed_program_set_call_target(&program, 3, &target), 0);
    var dispatch: TypedMethodDispatch = TypedMethodDispatch{
        receiver_type_id: 2,
        method_symbol_id: 11,
        interface_symbol_id: 12,
        vtable_slot: 4,
    };
    try assert_eq_i32(typed_program_set_method_dispatch(&program, 4, &dispatch), 0);
    try assert_eq_i32(typed_program_set_field_access(&program, 4, 13), 0);
    try assert_eq_i32(typed_program_append_global_init(&program, 2), 0);
    try assert_eq_i32(typed_program_append_reachable_root(&program, 5), 0);
    var proof: TypedProofResult = TypedProofResult{
        expr_id: 3,
        status: TYPED_PROOF_OK,
        error_id: 0,
    };
    try assert_eq_i32(typed_program_append_proof_result(&program, &proof), 0);

    var out_type: TypeId = -1;
    var out_symbol: SymbolId = -1;
    var out_field: FieldId = -1;
    var out_target: TypedCallTarget = typed_program_default_call_target();
    var out_dispatch: TypedMethodDispatch = typed_program_default_method_dispatch();
    try assert_eq_i32(typed_program_get_expr_type(&program, 3, &out_type), 1);
    try assert_eq_i32(out_type, 42);
    try assert_eq_i32(typed_program_get_identifier_binding(&program, 3, &out_symbol), 1);
    try assert_eq_i32(out_symbol, 7);
    try assert_eq_i32(typed_program_get_call_target(&program, 3, &out_target), 1);
    try assert_eq_i32(out_target.function_id, 5);
    try assert_eq_i32(typed_program_get_method_dispatch(&program, 4, &out_dispatch), 1);
    try assert_eq_i32(out_dispatch.method_symbol_id, 11);
    try assert_eq_i32(typed_program_get_field_access(&program, 4, &out_field), 1);
    try assert_eq_i32(out_field, 13);
    try assert_eq_i32(program.global_init_count, 1);
    try assert_eq_i32(program.reachable_root_count, 1);
    try assert_eq_i32(program.proof_result_count, 1);

    const stats: TypedProgramStats = typed_program_stats(&program);
    try assert_eq_i32(stats.table_count, 8);
    try assert_eq_i32(stats.table_capacity >= 16usize, true);
    try assert_eq_i32(typed_program_estimated_bytes(&program) >= @size_of(TypedProgram), true);
    const lifetime: TypedProgramLifetimeStats = typed_program_lifetime_stats(&program);
    try assert_eq_i32(lifetime.lifecycle_state, TYPED_PROGRAM_LIFECYCLE_ACTIVE);
    try assert_eq_i32(lifetime.current_bytes == typed_program_current_bytes(&program), true);
    try assert_eq_i32(lifetime.peak_bytes >= lifetime.current_bytes, true);
    typed_program_reset(&program);
    try assert_eq_i32(program.expr_count, 0);
    try assert_eq_i32(program.global_init_count, 0);
    typed_program_release(&program);
    try assert_eq_i32(typed_program_estimated_bytes(&program) as i32, 0);
    try assert_eq_i32(typed_program_current_bytes(&program) as i32, 0);
    try assert_eq_i32(typed_program_lifecycle_state(&program), TYPED_PROGRAM_LIFECYCLE_RELEASED);
    try assert_eq_i32(typed_program_peak_bytes(&program) >= @size_of(TypedProgram), true);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ TypedProgram definition and compact dynamic storage verified"
