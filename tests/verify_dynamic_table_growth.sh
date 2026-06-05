#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
INTERN_FILE="$REPO_ROOT/src/semantic/intern.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
TYPED_FILE="$REPO_ROOT/src/typed/program.uya"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
LOWER_CORE_FILE="$REPO_ROOT/src/lower/core.uya"
C99_PLAN_FILE="$REPO_ROOT/src/codegen/c99/plan.uya"
TMP_DIRS=()

cleanup() {
    local dir
    for dir in "${TMP_DIRS[@]}"; do
        if [[ -n "$dir" && "$dir" == /tmp/uya-dynamic-table-growth.* ]]; then
            rm -rf "$dir"
        fi
    done
}

trap cleanup EXIT

make_tmp_dir() {
    local dir
    dir="$(mktemp -d /tmp/uya-dynamic-table-growth.XXXXXX)"
    TMP_DIRS+=("$dir")
    printf '%s\n' "$dir"
}

run_check() {
    local script="$1"
    local path="$SCRIPT_DIR/$script"
    if [[ ! -x "$path" ]]; then
        echo "错误: 缺少可执行验证脚本: $path" >&2
        exit 1
    fi
    echo "== $script =="
    bash "$path"
}

verify_large_legacy_counts() {
    if [[ ! -f "$TABLE_FILE" ]]; then
        echo "错误: 缺少 $TABLE_FILE" >&2
        exit 1
    fi

    local tmp_dir
    tmp_dir="$(make_tmp_dir)"
    cp "$TABLE_FILE" "$tmp_dir/main.uya"
    cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

const OVER_FUNCTION_TABLE_SIZE: i32 = 4097;
const OVER_C99_LOCAL_VARS: i32 = 1025;
const OVER_EXEC_LOCALS: i32 = 257;
const OVER_MONO_INSTANCES: i32 = 513;

fn dynamic_growth_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn dynamic_growth_append_i32(vec: &SemanticVector, count: i32) !void {
    var i: i32 = 0;
    while i < count {
        var value: i32 = i;
        try assert_eq_i32(semantic_vector_append(vec, &value as &const void), 0);
        i = i + 1;
    }
}

fn dynamic_growth_verify_count(vec: &SemanticVector, expected: i32) !void {
    try assert_eq_i32(vec.count as i32, expected);
    try expect(vec.capacity >= expected as usize);
    try expect(vec.realloc_count > 0);
}

test "dynamic vectors exceed legacy compiler table capacities" {
    var decls: SemanticVector = dynamic_growth_vector();
    var functions: SemanticVector = dynamic_growth_vector();
    var c99_locals: SemanticVector = dynamic_growth_vector();
    var exec_locals: SemanticVector = dynamic_growth_vector();
    var mono_instances: SemanticVector = dynamic_growth_vector();

    semantic_vector_init(&decls, @size_of(i32));
    semantic_vector_init(&functions, @size_of(i32));
    semantic_vector_init(&c99_locals, @size_of(i32));
    semantic_vector_init(&exec_locals, @size_of(i32));
    semantic_vector_init(&mono_instances, @size_of(i32));

    try dynamic_growth_append_i32(&decls, OVER_FUNCTION_TABLE_SIZE);
    try dynamic_growth_append_i32(&functions, OVER_FUNCTION_TABLE_SIZE);
    try dynamic_growth_append_i32(&c99_locals, OVER_C99_LOCAL_VARS);
    try dynamic_growth_append_i32(&exec_locals, OVER_EXEC_LOCALS);
    try dynamic_growth_append_i32(&mono_instances, OVER_MONO_INSTANCES);

    try dynamic_growth_verify_count(&decls, OVER_FUNCTION_TABLE_SIZE);
    try dynamic_growth_verify_count(&functions, OVER_FUNCTION_TABLE_SIZE);
    try dynamic_growth_verify_count(&c99_locals, OVER_C99_LOCAL_VARS);
    try dynamic_growth_verify_count(&exec_locals, OVER_EXEC_LOCALS);
    try dynamic_growth_verify_count(&mono_instances, OVER_MONO_INSTANCES);

    semantic_vector_release(&decls);
    semantic_vector_release(&functions);
    semantic_vector_release(&c99_locals);
    semantic_vector_release(&exec_locals);
    semantic_vector_release(&mono_instances);
}
EOF

    (cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)
    echo "✓ dynamic vectors exceed legacy declaration/function/local/mono capacities"
}

verify_high_load_and_collision_growth() {
    if [[ ! -f "$TABLE_FILE" || ! -f "$INTERN_FILE" ]]; then
        echo "错误: 缺少 dynamic table/intern 源文件" >&2
        exit 1
    fi

    local tmp_dir
    tmp_dir="$(make_tmp_dir)"
    cat "$TABLE_FILE" "$INTERN_FILE" >"$tmp_dir/main.uya"
    cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

test "semantic hash grows under high collision load" {
    var hash: SemanticHash = SemanticHash{
        entries: null,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
    semantic_hash_init(&hash);

    var i: i32 = 0;
    while i < 128 {
        const key: i64 = (0 - i - 1) as i64;
        try assert_eq_i32(semantic_hash_insert(&hash, key, i), 0);
        i = i + 1;
    }

    try assert_eq_i32(hash.count as i32, 128);
    try expect(hash.capacity >= 128usize);
    try expect(hash.realloc_count > 1);

    i = 0;
    while i < 128 {
        const key2: i64 = (0 - i - 1) as i64;
        var value: i32 = -1;
        try assert_eq_i32(semantic_hash_get(&hash, key2, &value), 1);
        try assert_eq_i32(value, i);
        i = i + 1;
    }
    semantic_hash_release(&hash);
}

test "semantic intern grows under high load" {
    var table: SemanticInternTable = SemanticInternTable{
        entries: null,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
        string_bytes: 0usize,
    };
    semantic_intern_init(&table);
EOF

    local i
    for i in $(seq 0 127); do
        printf '    try expect(semantic_intern_get_or_put(&table, "load_%03d") >= 0);\n' "$i" >>"$tmp_dir/main.uya"
    done

    cat >>"$tmp_dir/main.uya" <<'EOF'
    try assert_eq_i32(table.count as i32, 128);
    try expect(table.capacity >= 128usize);
    try expect(table.realloc_count > 1);
    try expect(semantic_intern_find(&table, "load_000") >= 0);
    try expect(semantic_intern_find(&table, "load_064") >= 0);
    try expect(semantic_intern_find(&table, "load_127") >= 0);
    semantic_intern_free(&table);
}
EOF

    (cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)
    echo "✓ dynamic hash collision and intern high-load growth checks passed"
}

verify_typed_program_dynamic_growth() {
    if [[ ! -f "$TABLE_FILE" || ! -f "$IDS_FILE" || ! -f "$TYPED_FILE" ]]; then
        echo "错误: 缺少 TypedProgram 动态增长源文件" >&2
        exit 1
    fi

    local tmp_dir
    tmp_dir="$(make_tmp_dir)"
    cat "$TABLE_FILE" "$IDS_FILE" "$TYPED_FILE" >"$tmp_dir/main.uya"
    cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

const OVER_TYPED_EXPR_COUNT: i32 = 4097;
const OVER_TYPED_PROOF_RESULTS: i32 = 1025;

fn typed_growth_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn typed_growth_program() TypedProgram {
    return TypedProgram{
        expr_count: 0,
        global_init_count: 0,
        reachable_root_count: 0,
        proof_result_count: 0,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: TYPED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        expr_types: typed_growth_vector(),
        identifier_bindings: typed_growth_vector(),
        call_targets: typed_growth_vector(),
        method_dispatch: typed_growth_vector(),
        field_access: typed_growth_vector(),
        global_init_order: typed_growth_vector(),
        reachable_roots: typed_growth_vector(),
        proof_results: typed_growth_vector(),
    };
}

test "typed program grows expression call target and proof result tables" {
    var program: TypedProgram = typed_growth_program();
    typed_program_init(&program);

    var i: i32 = 0;
    while i < OVER_TYPED_EXPR_COUNT {
        try assert_eq_i32(typed_program_set_expr_type(&program, i, i + 1), 0);
        var target: TypedCallTarget = TypedCallTarget{
            kind: TYPED_CALL_TARGET_FUNCTION,
            function_id: i,
            decl_id: i,
            symbol_id: i,
            mono_instance_id: i,
        };
        try assert_eq_i32(typed_program_set_call_target(&program, i, &target), 0);
        i = i + 1;
    }

    i = 0;
    while i < OVER_TYPED_PROOF_RESULTS {
        var proof: TypedProofResult = TypedProofResult{
            expr_id: i,
            status: TYPED_PROOF_OK,
            error_id: 0,
        };
        try assert_eq_i32(typed_program_append_proof_result(&program, &proof), 0);
        i = i + 1;
    }

    try assert_eq_i32(program.expr_count, OVER_TYPED_EXPR_COUNT);
    try assert_eq_i32(program.expr_types.count as i32, OVER_TYPED_EXPR_COUNT);
    try assert_eq_i32(program.call_targets.count as i32, OVER_TYPED_EXPR_COUNT);
    try assert_eq_i32(program.proof_result_count, OVER_TYPED_PROOF_RESULTS);
    try assert_eq_i32(program.proof_results.count as i32, OVER_TYPED_PROOF_RESULTS);
    try expect(program.expr_types.capacity >= OVER_TYPED_EXPR_COUNT as usize);
    try expect(program.call_targets.capacity >= OVER_TYPED_EXPR_COUNT as usize);
    try expect(program.proof_results.capacity >= OVER_TYPED_PROOF_RESULTS as usize);
    try expect(program.expr_types.realloc_count > 1);
    try expect(program.call_targets.realloc_count > 1);
    try expect(program.proof_results.realloc_count > 1);

    var out_type: TypeId = -1;
    var out_target: TypedCallTarget = typed_program_default_call_target();
    try assert_eq_i32(typed_program_get_expr_type(&program, OVER_TYPED_EXPR_COUNT - 1, &out_type), 1);
    try assert_eq_i32(out_type, OVER_TYPED_EXPR_COUNT);
    try assert_eq_i32(typed_program_get_call_target(&program, OVER_TYPED_EXPR_COUNT - 1, &out_target), 1);
    try assert_eq_i32(out_target.function_id, OVER_TYPED_EXPR_COUNT - 1);

    const stats: TypedProgramStats = typed_program_stats(&program);
    try assert_eq_i32(stats.table_count, 8);
    try expect(stats.table_capacity >= (OVER_TYPED_EXPR_COUNT as usize * 2usize));
    try expect(typed_program_estimated_bytes(&program) > @size_of(TypedProgram));
    try expect(typed_program_peak_bytes(&program) >= typed_program_current_bytes(&program));

    typed_program_release(&program);
    try assert_eq_i32(typed_program_lifecycle_state(&program), TYPED_PROGRAM_LIFECYCLE_RELEASED);
    try expect(typed_program_current_bytes(&program) == 0usize);
    try expect(typed_program_peak_bytes(&program) > @size_of(TypedProgram));
}
EOF

    (cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)
    echo "✓ TypedProgram dynamic expression/call/proof growth checks passed"
}

verify_lowered_program_dynamic_growth() {
    if [[ ! -f "$ARENA_FILE" || ! -f "$TABLE_FILE" || ! -f "$IDS_FILE" || ! -f "$TYPED_FILE" || ! -f "$LOWER_CORE_FILE" ]]; then
        echo "错误: 缺少 LoweredProgram 动态增长源文件" >&2
        exit 1
    fi

    local tmp_dir
    tmp_dir="$(make_tmp_dir)"
    cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"
    cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

const OVER_LOWERED_MONO_INSTANCES: i32 = 4097;
const OVER_LOWERED_ERR_UNIONS: i32 = 1025;
const OVER_LOWERED_ASYNC_FRAMES: i32 = 1025;
const OVER_LOWERED_HELPERS: i32 = 1025;

fn lower_growth_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn lower_growth_program() LoweredProgram {
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
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        functions: lower_growth_vector(),
        globals: lower_growth_vector(),
        types: lower_growth_vector(),
        interfaces: lower_growth_vector(),
        err_unions: lower_growth_vector(),
        async_frames: lower_growth_vector(),
        drop_defer_plans: lower_growth_vector(),
        helpers: lower_growth_vector(),
        worklist: lower_growth_vector(),
    };
}

fn lower_growth_typed() TypedProgram {
    return TypedProgram{
        expr_count: 0,
        global_init_count: 0,
        reachable_root_count: 0,
        proof_result_count: 0,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: TYPED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        expr_types: lower_growth_vector(),
        identifier_bindings: lower_growth_vector(),
        call_targets: lower_growth_vector(),
        method_dispatch: lower_growth_vector(),
        field_access: lower_growth_vector(),
        global_init_order: lower_growth_vector(),
        reachable_roots: lower_growth_vector(),
        proof_results: lower_growth_vector(),
    };
}

test "lowered program closure tables grow past legacy capacities" {
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

    var typed: TypedProgram = lower_growth_typed();
    typed_program_init(&typed);
    var i: i32 = 0;
    while i < OVER_LOWERED_MONO_INSTANCES {
        var target: TypedCallTarget = TypedCallTarget{
            kind: TYPED_CALL_TARGET_FUNCTION,
            function_id: i,
            decl_id: i,
            symbol_id: i,
            mono_instance_id: i,
        };
        try assert_eq_i32(typed_program_set_call_target(&typed, i, &target), 0);
        i = i + 1;
    }

    var lowered: LoweredProgram = lower_growth_program();
    lowered_program_init(&lowered, &arena);
    try assert_eq_i32(lowered_program_close_generic_function_instances(&lowered, &typed), 0);
    try assert_eq_i32(lowered.function_count as i32, OVER_LOWERED_MONO_INSTANCES);
    try expect(lowered.functions.capacity >= OVER_LOWERED_MONO_INSTANCES as usize);
    try expect(lowered.functions.realloc_count > 1);

    i = 0;
    while i < OVER_LOWERED_ERR_UNIONS {
        var layout: ErrorUnionLayout = ErrorUnionLayout{
            type_id: 1000000 + i,
            payload_type_id: i,
            error_type_id: i + 1,
        };
        try assert_eq_i32(lowered_program_close_err_union_type(&lowered, &layout), 0);
        i = i + 1;
    }
    try assert_eq_i32(lowered.err_union_count as i32, OVER_LOWERED_ERR_UNIONS);
    try expect(lowered.err_unions.realloc_count > 1);

    i = 0;
    while i < OVER_LOWERED_ASYNC_FRAMES {
        var frame: AsyncFramePlan = AsyncFramePlan{
            function_id: 2000000 + i,
            frame_type_id: i,
            slot_start: 0,
            slot_count: 1,
        };
        try assert_eq_i32(lowered_program_close_async_frame_metadata(&lowered, &frame), 0);
        i = i + 1;
    }
    try assert_eq_i32(lowered.async_frame_count as i32, OVER_LOWERED_ASYNC_FRAMES);
    try expect(lowered.async_frames.realloc_count > 1);

    i = 0;
    while i < OVER_LOWERED_HELPERS {
        var helper: RuntimeHelper = RuntimeHelper{
            helper_id: 3000000 + i,
            kind: LOWERED_RUNTIME_HELPER_UNKNOWN,
            name_id: i,
        };
        try assert_eq_i32(lowered_program_close_runtime_helper_requirement(&lowered, &helper), 0);
        i = i + 1;
    }
    try assert_eq_i32(lowered.helper_count as i32, OVER_LOWERED_HELPERS);
    try expect(lowered.helpers.realloc_count > 1);

    try assert_eq_i32(lowered_program_sort_stable(&lowered), 0);

    lowered_program_release(&lowered);
    typed_program_release(&typed);
    compiler_arena_free_all(&arena);
}
EOF

    (cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)
    echo "✓ LoweredProgram dynamic mono/err_union/async/helper growth checks passed"
}

verify_c99_plan_dynamic_growth() {
    if [[ ! -f "$ARENA_FILE" || ! -f "$TABLE_FILE" || ! -f "$IDS_FILE" || ! -f "$C99_PLAN_FILE" ]]; then
        echo "错误: 缺少 C99Plan 动态增长源文件" >&2
        exit 1
    fi

    local tmp_dir
    tmp_dir="$(make_tmp_dir)"
    cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$C99_PLAN_FILE" >"$tmp_dir/main.uya"
    cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

const OVER_C99_PLAN_UNITS: i32 = 1025;
const OVER_C99_PLAN_PROTOTYPES: i32 = 4097;
const OVER_C99_PLAN_HELPERS: i32 = 1025;
const OVER_C99_PLAN_DEPS: i32 = 1025;

fn c99_plan_growth_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn c99_plan_growth_program() C99Plan {
    return C99Plan{
        arena: null,
        unit_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: C99_PLAN_LIFECYCLE_UNINITIALIZED,
        includes: c99_plan_growth_vec(),
        typedefs: c99_plan_growth_vec(),
        prototypes: c99_plan_growth_vec(),
        globals: c99_plan_growth_vec(),
        functions: c99_plan_growth_vec(),
        helpers: c99_plan_growth_vec(),
        deps: c99_plan_growth_vec(),
        units: c99_plan_growth_vec(),
    };
}

test "c99 plan units prototypes helpers deps grow past legacy capacities" {
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

    var plan: C99Plan = c99_plan_growth_program();
    c99_plan_init(&plan, &arena);

    var i: i32 = 0;
    while i < OVER_C99_PLAN_UNITS {
        const uid: i32 = c99_plan_add_unit(&plan, i);
        try assert_eq_i32(uid, i);
        i = i + 1;
    }
    try assert_eq_i32(c99_plan_unit_count(&plan) as i32, OVER_C99_PLAN_UNITS);
    try expect(plan.units.realloc_count > 1);

    i = 0;
    while i < OVER_C99_PLAN_PROTOTYPES {
        try assert_eq_i32(c99_plan_unit_add_prototype(&plan, 0, i), 0);
        i = i + 1;
    }
    i = 0;
    while i < OVER_C99_PLAN_HELPERS {
        try assert_eq_i32(c99_plan_unit_add_helper(&plan, 0, i), 0);
        i = i + 1;
    }
    i = 0;
    while i < OVER_C99_PLAN_DEPS {
        try assert_eq_i32(c99_plan_add_dep(&plan, i), 0);
        i = i + 1;
    }

    const unit0: &C99UnitPlan = c99_plan_unit_ptr(&plan, 0);
    try expect(unit0 != null);
    try assert_eq_i32(unit0.prototypes.count as i32, OVER_C99_PLAN_PROTOTYPES);
    try assert_eq_i32(unit0.helpers.count as i32, OVER_C99_PLAN_HELPERS);
    try assert_eq_i32(plan.deps.count as i32, OVER_C99_PLAN_DEPS);
    try expect(unit0.prototypes.realloc_count > 1);
    try expect(unit0.helpers.realloc_count > 1);
    try expect(plan.deps.realloc_count > 1);

    c99_plan_release(&plan);
    compiler_arena_free_all(&arena);
}
EOF

    (cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)
    echo "✓ C99Plan dynamic units/prototypes/helpers/deps growth checks passed"
}

verify_large_legacy_counts
verify_high_load_and_collision_growth
verify_typed_program_dynamic_growth
verify_lowered_program_dynamic_growth
verify_c99_plan_dynamic_growth
run_check "verify_semantic_table_growth_failures.sh"
run_check "verify_semantic_intern_growth.sh"
run_check "verify_semantic_db_dynamic_growth.sh"
run_check "verify_semantic_phase2_dynamic_indexes.sh"
run_check "verify_semantic_db_global_vars.sh"
run_check "verify_c99_identifier_type_node_scope_table.sh"
run_check "verify_lowered_program_core_definition.sh"
run_check "verify_lowered_program_worklist_roots.sh"
run_check "verify_c99_identifier_type_c_scope_table.sh"
run_check "verify_c99_no_local_count_hot_cache.sh"
run_check "verify_c99_generic_template_multi_instance_var_types.sh"
run_check "verify_c99_safe_hot_cache_key.sh"
run_check "verify_c99_async_bind_name_conflicts.sh"
run_check "verify_semantic_db_capacity_ratio.sh"
run_check "verify_function_scope_local_shadowing.sh"
run_check "verify_function_scope_block_exit_visibility.sh"
run_check "verify_function_scope_dynamic_growth_stress.sh"
run_check "verify_function_scope_index_dynamic_bindings.sh"

echo "✓ dynamic table growth aggregate checks passed"
