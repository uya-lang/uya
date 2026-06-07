#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
TYPED_PROGRAM_FILE="$REPO_ROOT/src/typed/program.uya"
LOWER_CORE_FILE="$REPO_ROOT/src/lower/core.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"
COREIR_DOC="$REPO_ROOT/docs/coreir_lowered_program_whitepaper.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR Core input contract missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" "$PORTABLE_MIR_DOC" "$COREIR_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'export[[:space:]]+struct[[:space:]]+PortableMirCoreInput' "PortableMIR Core-only input struct"
require_pattern "$LOWER_CORE_FILE" 'portable_mir_core_input_is_frozen' "PortableMIR frozen Core input check"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_verify_coreir\(input\.program\)' "PortableMIR input is gated by CoreIR verifier"
require_pattern "$PORTABLE_MIR_DOC" 'PortableMIR lowering 默认接收' "PortableMIR input contract section"
require_pattern "$PORTABLE_MIR_DOC" '默认不查询 `TypedProgram`' "PortableMIR does not query TypedProgram"
require_pattern "$COREIR_DOC" 'PortableMIR 不允许发现新的泛型实例' "CoreIR owns semantic closure"

if grep -En 'portable_mir_[[:alnum:]_]+[[:space:]]*\([^)]*(TypeChecker|TypedProgram)' "$LOWER_CORE_FILE"; then
    echo "error: PortableMIR Core input function accepts checker/TypedProgram bypass state" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-core-input.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn portable_mir_contract_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn portable_mir_contract_arena() CompilerArena {
    return CompilerArena{
        buffer: null,
        size: 0usize,
        offset: 0usize,
        first_chunk: null,
        current_chunk: null,
        total_allocated: 0usize,
        peak_allocated: 0usize,
    };
}

fn portable_mir_contract_program() LoweredProgram {
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
        functions: portable_mir_contract_vec(),
        body_ops: portable_mir_contract_vec(),
        core_bodies: portable_mir_contract_vec(),
        core_stmts: portable_mir_contract_vec(),
        core_exprs: portable_mir_contract_vec(),
        core_places: portable_mir_contract_vec(),
        core_cleanup_edges: portable_mir_contract_vec(),
        core_semantic_facts: portable_mir_contract_vec(),
        globals: portable_mir_contract_vec(),
        types: portable_mir_contract_vec(),
        interfaces: portable_mir_contract_vec(),
        err_unions: portable_mir_contract_vec(),
        async_frames: portable_mir_contract_vec(),
        drop_defer_plans: portable_mir_contract_vec(),
        helpers: portable_mir_contract_vec(),
        worklist: portable_mir_contract_vec(),
    };
}

fn append_portable_mir_contract_corebody(lowered: &LoweredProgram) !void {
    var func: ConcreteFunction = ConcreteFunction{
        function_id: 11,
        decl_id: 12,
        mono_instance_id: TYPED_PROGRAM_INVALID_ID,
        body_start: 0,
        body_count: 1,
        flags: 0,
    };
    var body: CoreBody = CoreBody{
        body_id: 0,
        function_id: 11,
        decl_id: 12,
        root_stmt_start: 0,
        root_stmt_count: 1,
        expr_start: 0,
        expr_count: 0,
        place_start: 0,
        place_count: 0,
        cleanup_edge_start: 0,
        cleanup_edge_count: 0,
        semantic_fact_start: 0,
        semantic_fact_count: 0,
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
        expr_id: CORE_EXPR_INVALID_ID,
        place_id: CORE_PLACE_INVALID_ID,
        cleanup_edge_start: 0,
        cleanup_edge_count: 0,
        source_span_id: 501,
        cleanup_scope_id: TYPED_PROGRAM_INVALID_ID,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_append_function(lowered, &func), 0);
    try assert_eq_i32(lowered_program_append_core_body(lowered, &body), 0);
    try assert_eq_i32(lowered_program_append_core_stmt(lowered, &stmt), 0);
}

test "PortableMIR input accepts only verifier-clean LoweredProgram and CoreBody" {
    var arena_buf: [byte: 4096] = [];
    var arena: CompilerArena = portable_mir_contract_arena();
    compiler_arena_init(&arena, &arena_buf[0], @len(arena_buf) as usize);

    var lowered: LoweredProgram = portable_mir_contract_program();
    lowered_program_init(&lowered, &arena);
    var missing: PortableMirCoreInput = PortableMirCoreInput{
        program: &lowered,
        body_id: 0,
        target_profile_id: 1,
        flags: 0,
    };
    try assert_eq_i32(portable_mir_core_input_is_frozen(&missing), 0);

    try append_portable_mir_contract_corebody(&lowered);
    var input: PortableMirCoreInput = PortableMirCoreInput{
        program: &lowered,
        body_id: 0,
        target_profile_id: 1,
        flags: 0,
    };
    try assert_eq_i32(portable_mir_core_input_is_frozen(&input), 1);

    var wrong_body: PortableMirCoreInput = PortableMirCoreInput{
        program: &lowered,
        body_id: 99,
        target_profile_id: 1,
        flags: 0,
    };
    try assert_eq_i32(portable_mir_core_input_is_frozen(&wrong_body), 0);

    const body0: &CoreBody = semantic_vector_item_ptr(&lowered.core_bodies, 0usize) as &CoreBody;
    try expect(body0 != null);
    body0.root_stmt_start = -1;
    try assert_eq_i32(portable_mir_core_input_is_frozen(&input), 0);

    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "OK: PortableMIR Core input contract verified"
