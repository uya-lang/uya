#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
TYPED_PROGRAM_FILE="$REPO_ROOT/src/typed/program.uya"
LOWER_CORE_FILE="$REPO_ROOT/src/lower/core.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: CoreIR dump 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'UYA_DUMP_COREIR' "CoreIR dump 环境变量"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_maybe_dump_coreir' "CoreIR dump 调度函数"
require_pattern "$LOWER_CORE_FILE" '=== coreir ===' "CoreIR dump 起始标记"
require_pattern "$LOWER_CORE_FILE" 'core_bodies=%zu core_stmts=%zu core_exprs=%zu' "CoreIR dump 表摘要"

tmp_dir="$(mktemp -d /tmp/uya-coreir-dump.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn coreir_dump_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn coreir_dump_program() LoweredProgram {
    return LoweredProgram{
        arena: null,
        function_count: 0usize,
        global_count: 0usize,
        type_count: 0usize,
        interface_count: 0usize,
        err_union_count: 0usize,
        async_frame_count: 0usize,
        drop_defer_count: 0usize,
        helper_count: 0usize,
        work_item_count: 0usize,
        body_op_count: 0usize,
        core_body_count: 0usize,
        core_stmt_count: 0usize,
        core_expr_count: 0usize,
        core_place_count: 0usize,
        core_cleanup_edge_count: 0usize,
        core_semantic_fact_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        functions: coreir_dump_vec(),
        body_ops: coreir_dump_vec(),
        core_bodies: coreir_dump_vec(),
        core_stmts: coreir_dump_vec(),
        core_exprs: coreir_dump_vec(),
        core_places: coreir_dump_vec(),
        core_cleanup_edges: coreir_dump_vec(),
        core_semantic_facts: coreir_dump_vec(),
        globals: coreir_dump_vec(),
        types: coreir_dump_vec(),
        interfaces: coreir_dump_vec(),
        err_unions: coreir_dump_vec(),
        async_frames: coreir_dump_vec(),
        drop_defer_plans: coreir_dump_vec(),
        helpers: coreir_dump_vec(),
        worklist: coreir_dump_vec(),
    };
}

fn append_coreir_dump_fixture(lowered: &LoweredProgram) !void {
    var body: CoreBody = CoreBody{
        body_id: 0,
        function_id: 11,
        decl_id: 12,
        root_stmt_start: 0,
        root_stmt_count: 1,
        expr_start: 0,
        expr_count: 1,
        place_start: 0,
        place_count: 1,
        cleanup_edge_start: 0,
        cleanup_edge_count: 1,
        semantic_fact_start: 0,
        semantic_fact_count: 1,
        source_span_id: 500,
        flags: CORE_BODY_FLAG_SOURCE_BODY,
    };
    var stmt: CoreStmt = CoreStmt{
        stmt_id: 0,
        kind: CORE_STMT_KIND_RETURN,
        body_id: 0,
        parent_stmt_id: CORE_STMT_INVALID_ID,
        first_child_stmt: CORE_STMT_INVALID_ID,
        child_stmt_count: 0,
        expr_id: 0,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_start: 0,
        cleanup_edge_count: 1,
        source_span_id: 501,
        cleanup_scope_id: 601,
        flags: 0,
    };
    var expr: CoreExpr = CoreExpr{
        expr_id: 0,
        kind: CORE_EXPR_KIND_CALL,
        body_id: 0,
        source_expr_id: 7,
        type_id: 77,
        lhs_expr_id: CORE_EXPR_INVALID_ID,
        rhs_expr_id: CORE_EXPR_INVALID_ID,
        callee_expr_id: CORE_EXPR_INVALID_ID,
        place_id: 0,
        target_function_id: 101,
        target_decl_id: 102,
        field_id: 301,
        proof_result_id: 0,
        capability_id: 801,
        source_span_id: 701,
        flags: 0,
    };
    var place: CorePlace = CorePlace{
        place_id: 0,
        kind: CORE_PLACE_KIND_FIELD,
        body_id: 0,
        source_expr_id: 7,
        type_id: 77,
        base_place_id: CORE_PLACE_INVALID_ID,
        index_expr_id: CORE_EXPR_INVALID_ID,
        field_id: 301,
        symbol_id: 302,
        source_span_id: 702,
        flags: 0,
    };
    var edge: CoreCleanupEdge = CoreCleanupEdge{
        edge_id: 0,
        kind: CORE_CLEANUP_EDGE_KIND_RETURN,
        body_id: 0,
        from_stmt_id: 0,
        to_stmt_id: CORE_STMT_INVALID_ID,
        cleanup_scope_id: 601,
        drop_defer_plan_id: 901,
        payload_expr_id: 0,
        source_span_id: 703,
        flags: 5,
    };
    var fact: CoreSemanticFact = CoreSemanticFact{
        fact_id: 0,
        kind: CORE_SEMANTIC_FACT_RESOLVED_CALL,
        body_id: 0,
        stmt_id: CORE_STMT_INVALID_ID,
        expr_id: 0,
        source_expr_id: 7,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_id: CORE_CLEANUP_EDGE_INVALID_ID,
        call_target_kind: TYPED_CALL_TARGET_FUNCTION,
        target_function_id: 101,
        target_decl_id: 102,
        target_symbol_id: 103,
        mono_instance_id: 104,
        arg_count: 0,
        receiver_type_id: TYPED_PROGRAM_INVALID_ID,
        method_symbol_id: TYPED_PROGRAM_INVALID_ID,
        interface_symbol_id: TYPED_PROGRAM_INVALID_ID,
        vtable_slot: TYPED_PROGRAM_INVALID_ID,
        field_id: 301,
        type_id: 77,
        proof_result_id: 0,
        proof_status: TYPED_PROOF_OK,
        proof_error_id: TYPED_PROGRAM_INVALID_ID,
        source_span_id: 701,
        drop_defer_plan_id: TYPED_PROGRAM_INVALID_ID,
        cleanup_scope_id: TYPED_PROGRAM_INVALID_ID,
        capability_id: 801,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_append_core_body(lowered, &body), 0);
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &stmt), 0);
    try assert_eq_i32(lowered_program_append_core_expr(lowered, &expr), 0);
    try assert_eq_i32(lowered_program_append_core_place(lowered, &place), 0);
    try assert_eq_i32(lowered_program_append_core_cleanup_edge(lowered, &edge), 0);
    try assert_eq_i32(lowered_program_append_core_semantic_fact(lowered, &fact), 0);
}

test "coreir dump is controlled by env" {
    var arena_buf: [byte: 4096] = [];
    var arena: CompilerArena = CompilerArena{
        buffer: null,
        size: 0usize,
        offset: 0usize,
        first_chunk: null,
        current_chunk: null,
        total_allocated: 0usize,
        peak_allocated: 0usize,
    };
    compiler_arena_init(&arena, &arena_buf[0], @len(arena_buf) as usize);

    var lowered: LoweredProgram = coreir_dump_program();
    lowered_program_init(&lowered, &arena);
    try append_coreir_dump_fixture(&lowered);
    lowered_program_maybe_dump_coreir(&lowered);

    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

default_stderr="$tmp_dir/default.stderr"
dump_stderr="$tmp_dir/dump.stderr"

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c >"$tmp_dir/default.stdout" 2>"$default_stderr")
if grep -Fq "=== coreir ===" "$default_stderr"; then
    echo "错误: 未设置 UYA_DUMP_COREIR 时不应输出 CoreIR dump" >&2
    exit 1
fi

(cd "$REPO_ROOT" && UYA_DUMP_COREIR=1 ./bin/uya test "$tmp_dir/main.uya" --no-split-c >"$tmp_dir/dump.stdout" 2>"$dump_stderr")
if ! grep -Fq "=== coreir ===" "$dump_stderr"; then
    echo "错误: UYA_DUMP_COREIR=1 时缺少 CoreIR dump 起始标记" >&2
    exit 1
fi
if ! grep -Fq "core_bodies=1 core_stmts=1 core_exprs=1 core_places=1 core_cleanup_edges=1 core_semantic_facts=1" "$dump_stderr"; then
    echo "错误: CoreIR dump 缺少表摘要" >&2
    exit 1
fi
if ! grep -Fq "body #0 function=11 decl=12 roots=0+1 exprs=0+1 places=0+1 cleanups=0+1 facts=0+1 source=500 flags=1" "$dump_stderr"; then
    echo "错误: CoreIR dump 缺少稳定 CoreBody 摘要" >&2
    exit 1
fi
if ! grep -Fq "stmt #0 body=0 kind=10 parent=-1 children=-1+0 expr=0 place=-1 cleanup=0+1 source=501 scope=601 flags=0" "$dump_stderr"; then
    echo "错误: CoreIR dump 缺少稳定 CoreStmt 摘要" >&2
    exit 1
fi
if ! grep -Fq "expr #0 body=0 kind=11 source_expr=7 type=77" "$dump_stderr"; then
    echo "错误: CoreIR dump 缺少稳定 CoreExpr 摘要" >&2
    exit 1
fi
if ! grep -Fq "place #0 body=0 kind=4 source_expr=7 type=77 base=-1 index=-1 field=301 symbol=302 source=702 flags=0" "$dump_stderr"; then
    echo "错误: CoreIR dump 缺少稳定 CorePlace 摘要" >&2
    exit 1
fi
if ! grep -Fq "cleanup #0 body=0 kind=2 from=0 to=-1 scope=601 drop_defer=901 payload=0 source=703 flags=5" "$dump_stderr"; then
    echo "错误: CoreIR dump 缺少稳定 cleanup 摘要" >&2
    exit 1
fi
if ! grep -Fq "fact #0 kind=1 body=0 stmt=-1 expr=0 source_expr=7 place=-1 cleanup=-1" "$dump_stderr"; then
    echo "错误: CoreIR dump 缺少稳定 semantic fact 摘要" >&2
    exit 1
fi
if ! grep -Fq "  call kind=1 target_fn=101 target_decl=102 target_symbol=103 mono=104" "$dump_stderr"; then
    echo "错误: CoreIR dump 缺少 resolved call fact 详情" >&2
    exit 1
fi
if ! grep -Fq "=== coreir end ===" "$dump_stderr"; then
    echo "错误: UYA_DUMP_COREIR=1 时缺少 CoreIR dump 结束标记" >&2
    exit 1
fi

echo "✓ CoreIR dump env switch verified"
