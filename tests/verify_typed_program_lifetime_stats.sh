#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
AST_FILE="$REPO_ROOT/src/ast.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
TYPED_PROGRAM_FILE="$REPO_ROOT/src/typed/program.uya"
TYPED_ASSIGN_FILE="$REPO_ROOT/src/typed/assign.uya"
MAIN_FILE="$REPO_ROOT/src/main.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: TypedProgram lifetime 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$AST_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$TYPED_ASSIGN_FILE" "$MAIN_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TYPED_PROGRAM_FILE" 'resident_peak_bytes:[[:space:]]*usize' "常驻峰值字段"
require_pattern "$TYPED_PROGRAM_FILE" 'lifecycle_state:[[:space:]]*i32' "生命周期状态字段"
require_pattern "$TYPED_PROGRAM_FILE" 'typed_program_current_bytes' "当前常驻 bytes API"
require_pattern "$TYPED_PROGRAM_FILE" 'typed_program_peak_bytes' "峰值 bytes API"
require_pattern "$TYPED_PROGRAM_FILE" 'typed_program_lifetime_stats' "生命周期统计 API"

if grep -Eq 'ASTNode|ast_node|program_decls|LoweredProgram|lowered_program' "$TYPED_PROGRAM_FILE"; then
    echo "错误: TypedProgram 统计合同不应持有 AST/LoweredProgram 引用" >&2
    exit 1
fi

typed_release_calls="$(grep -n '^[[:space:]]*compile_stats_record_and_release_typed_program(&stats, checker);' "$MAIN_FILE" || true)"
typed_release_count="$(printf '%s\n' "$typed_release_calls" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
if [[ "$typed_release_count" != "2" ]]; then
    echo "错误: driver 应仅在 exec lowering 前和 C99 codegen 后释放 TypedProgram" >&2
    printf '%s\n' "$typed_release_calls" >&2
    exit 1
fi

first_typed_release_line="$(printf '%s\n' "$typed_release_calls" | head -n 1 | cut -d: -f1)"
exec_build_line="$(grep -n 'const exec_result: i32 = exec_build_program' "$MAIN_FILE" | head -n 1 | cut -d: -f1)"
if [[ -z "$first_typed_release_line" || -z "$exec_build_line" || "$first_typed_release_line" -ge "$exec_build_line" ]]; then
    echo "错误: exec lowering 前必须先记录并释放 TypedProgram，避免 AST/TypedProgram/HIR 同时常驻" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-typed-lifetime.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$AST_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$TYPED_ASSIGN_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn typed_lifetime_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn typed_lifetime_program() TypedProgram {
    return TypedProgram{
        expr_count: 0,
        global_init_count: 0,
        reachable_root_count: 0,
        proof_result_count: 0,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: TYPED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        expr_types: typed_lifetime_vector(),
        identifier_bindings: typed_lifetime_vector(),
        call_targets: typed_lifetime_vector(),
        method_dispatch: typed_lifetime_vector(),
        field_access: typed_lifetime_vector(),
        global_init_order: typed_lifetime_vector(),
        reachable_roots: typed_lifetime_vector(),
        proof_results: typed_lifetime_vector(),
    };
}

test "typed program peak survives parsed tree arena release" {
    var typed: TypedProgram = typed_lifetime_program();
    typed_program_init(&typed);
    try assert_eq_i32(typed_program_lifecycle_state(&typed), TYPED_PROGRAM_LIFECYCLE_ACTIVE);
    const initial_current: usize = typed_program_current_bytes(&typed);
    try expect(initial_current >= @size_of(TypedProgram));

    var buffer: [byte: 4096] = [];
    var arena: CompilerArena = CompilerArena{
        buffer: null,
        size: 0usize,
        offset: 0usize,
        first_chunk: null,
        current_chunk: null,
        total_allocated: 0usize,
        peak_allocated: 0usize,
    };
    compiler_arena_init(&arena, &buffer[0], @len(buffer) as usize);

    const program_node: &ASTNode = ast_new_node(ASTNodeType.AST_PROGRAM, 1, 1, &arena, "typed_lifetime.uya");
    const fn_node: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, &arena, "typed_lifetime.uya");
    const number_node: &ASTNode = ast_new_node(ASTNodeType.AST_NUMBER, 1, 10, &arena, "typed_lifetime.uya");
    var decls: [&ASTNode: 2] = [];
    decls[0] = fn_node;
    decls[1] = number_node;
    program_node.program_decls = &decls[0] as & & ASTNode;
    program_node.program_decl_count = 2;

    try assert_eq_i32(typed_program_assign_expr_ids(&typed, program_node), 0);
    try assert_eq_i32(typed.expr_count, 3);
    try expect(typed_program_current_bytes(&typed) >= initial_current);
    try expect(typed_program_peak_bytes(&typed) >= typed_program_current_bytes(&typed));

    compiler_arena_free_all(&arena);

    const after_ast_release: TypedProgramLifetimeStats = typed_program_lifetime_stats(&typed);
    try assert_eq_i32(after_ast_release.lifecycle_state, TYPED_PROGRAM_LIFECYCLE_ACTIVE);
    try expect(after_ast_release.current_bytes > 0usize);
    try expect(after_ast_release.peak_bytes >= after_ast_release.current_bytes);

    try assert_eq_i32(typed_program_set_expr_type(&typed, 0, 123), 0);
    var out_type: TypeId = TYPED_PROGRAM_INVALID_ID;
    try assert_eq_i32(typed_program_get_expr_type(&typed, 0, &out_type), 1);
    try assert_eq_i32(out_type, 123);

    const peak_before_release: usize = typed_program_peak_bytes(&typed);
    typed_program_release(&typed);
    const after_typed_release: TypedProgramLifetimeStats = typed_program_lifetime_stats(&typed);
    try assert_eq_i32(after_typed_release.lifecycle_state, TYPED_PROGRAM_LIFECYCLE_RELEASED);
    try expect(after_typed_release.current_bytes == 0usize);
    try expect(after_typed_release.peak_bytes >= peak_before_release);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ TypedProgram lifetime peak/current stats verified"
