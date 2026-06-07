#!/usr/bin/env bash

# Phase 6：验证 C99Plan / C99UnitPlan 计划结构定义、动态增长与 split-C 依赖追踪。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
AST_FILE="$REPO_ROOT/src/ast.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
PLAN_FILE="$REPO_ROOT/src/codegen/c99/plan.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: C99 plan stability 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$AST_FILE" "$TABLE_FILE" "$IDS_FILE" "$PLAN_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99Plan' "C99Plan 结构"
require_pattern "$PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99UnitPlan' "C99UnitPlan 结构"
require_pattern "$PLAN_FILE" 'units:[[:space:]]*SemanticVector' "split-C unit 列表为动态 vector"
require_pattern "$PLAN_FILE" 'prototypes:[[:space:]]*SemanticVector' "prototypes 动态表"
require_pattern "$PLAN_FILE" 'helpers:[[:space:]]*SemanticVector' "helpers 动态表"
require_pattern "$PLAN_FILE" 'deps:[[:space:]]*SemanticVector' "deps 动态表"
require_pattern "$PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99PreludePlan' "include/header/prelude 计划结构"
require_pattern "$PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99PreludePlanInput' "prelude 计划构建输入"
require_pattern "$PLAN_FILE" 'c99_prelude_plan_build' "include/header/prelude planner 入口"
require_pattern "$REPO_ROOT/src/codegen/c99/main.uya" 'c99_prelude_plan_build' "C99 emitter 消费 prelude plan"
require_pattern "$PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99PrototypePlan' "function prototype 计划结构"
require_pattern "$PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99PrototypePlanEntry' "prototype 计划事件结构"
require_pattern "$PLAN_FILE" 'c99_prototype_plan_build' "function prototype planner 入口"
require_pattern "$REPO_ROOT/src/codegen/c99/main.uya" 'c99_emit_prototype_plan' "C99 emitter 消费 prototype plan"
require_pattern "$PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99TypeDefinitionPlan' "type definition 计划结构"
require_pattern "$PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99TypeDefinitionPlanEntry' "type definition 计划事件结构"
require_pattern "$PLAN_FILE" 'c99_type_definition_plan_build' "type definition planner 入口"
require_pattern "$REPO_ROOT/src/codegen/c99/main.uya" 'c99_emit_type_definition_layouts' "C99 emitter 消费 type definition plan"
require_pattern "$PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99HelperPlan' "helper emission 计划结构"
require_pattern "$PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99HelperPlanInput' "helper emission 计划输入"
require_pattern "$PLAN_FILE" 'c99_helper_plan_build' "helper emission planner 入口"
require_pattern "$REPO_ROOT/src/codegen/c99/main.uya" 'c99_build_helper_plan' "C99 emitter 消费 helper plan"
require_pattern "$PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99SplitUnitPlanInput' "split-C unit 计划输入"
require_pattern "$PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99SplitSourceAssignment' "split-C source assignment 结构"
require_pattern "$PLAN_FILE" 'c99_split_unit_plan_build' "split-C unit planner 入口"
require_pattern "$REPO_ROOT/src/codegen/c99/main.uya" 'c99_split_unit_plan_build' "C99 emitter 构建 split-C unit plan"
require_pattern "$REPO_ROOT/src/codegen/c99/utils.uya" 'c99_split_mirror_prepare\(codegen:[^)]*split_plan:[^)]*C99Plan' "split-C prepare 消费 planner"
require_pattern "$REPO_ROOT/src/codegen/c99/main.uya" '^fn[[:space:]]+c99_plan_build' "c99_codegen_generate 使用独立 plan build"
require_pattern "$REPO_ROOT/src/codegen/c99/main.uya" '^fn[[:space:]]+c99_emit_plan' "c99_codegen_generate 使用独立 plan emit"
require_pattern "$REPO_ROOT/src/codegen/c99/main.uya" 'c99_emit_plan\(codegen,[[:space:]]*ast,[[:space:]]*output_file,[[:space:]]*&plan\)' "c99_codegen_generate 调用 c99_emit_plan(plan)"
require_pattern "$REPO_ROOT/src/codegen/c99/main.uya" 'c99_write_split_makefile\(codegen,[[:space:]]*&plan\)' "c99_codegen_generate 在 plan 后写 split Makefile"
require_pattern "$PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99DeclPlanEntry' "C99 顶层声明计划事件结构"
require_pattern "$PLAN_FILE" 'decls:[[:space:]]*SemanticVector' "顶层声明事件表为动态 vector"
require_pattern "$PLAN_FILE" 'c99_plan_build_decls' "顶层 AST 声明枚举迁入 planner"
require_pattern "$PLAN_FILE" 'c99_plan_decl_at' "C99 emitter 从 planner 读取声明事件"
require_pattern "$PLAN_FILE" 'c99_prototype_plan_build_from_c99_plan' "prototype planner 消费声明计划"
require_pattern "$PLAN_FILE" 'c99_type_definition_plan_build_from_c99_plan' "type definition planner 消费声明计划"
require_pattern "$REPO_ROOT/src/codegen/c99/main.uya" 'c99_emit_diag_suppress_begin' "C99 emit plan 不直接写 checker 诊断开关"
require_pattern "$REPO_ROOT/src/codegen/c99/main.uya" 'c99_prepare_from_json_reflect_body_for_emit' "C99 emit plan 不直接调用 from_json 反射构造"
require_pattern "$REPO_ROOT/src/codegen/c99/main.uya" 'c99_prepare_mono_body_for_emit' "C99 emit plan 不直接调用 mono 宏展开"
require_pattern "$PLAN_FILE" 'c99_plan_add_unit' "动态追加 unit 入口"
require_pattern "$PLAN_FILE" 'c99_plan_unit_add_dep' "unit 依赖追加入口"

emit_body="$(awk '/^fn c99_emit_plan\(/ {inside=1} /^fn c99_plan_build\(/ {inside=0} inside {print}' "$REPO_ROOT/src/codegen/c99/main.uya")"
if printf '%s\n' "$emit_body" | grep -Eq 'ast[.]program_decls|ast[.]program_decl_count|c99_build_helper_plan\(codegen,[[:space:]]*ast|c99_type_definition_plan_build\([^)]*ast|c99_prototype_plan_build\([^)]*ast|prepare_codegen_tests_and_emit_flags\(codegen,[[:space:]]*ast|c99_emit_all_async_frame_forwards\(codegen,[[:space:]]*ast|c99_preregister_async_frame_metadata\(codegen,[[:space:]]*ast|c99_mirror_emit_extern_const_fwd\(codegen,[[:space:]]*ast'; then
    echo "错误: c99_emit_plan 仍直接枚举或转交 AST program declarations" >&2
    exit 1
fi
if printf '%s\n' "$emit_body" | grep -Eq 'codegen[.]checker|type_from_ast[[:space:]]*[(]|build_from_json_reflect_body[[:space:]]*[(]|prepare_mono_body_expand_macros[[:space:]]*[(]'; then
    echo "错误: c99_emit_plan 仍直接调用 checker 或 checker-backed 准备函数" >&2
    exit 1
fi
if grep -R -E 'LoweredProgram|lowered_program_' "$REPO_ROOT/src/codegen/c99" >/dev/null; then
    echo "错误: C99 emitter/codegen 不应写入或依赖 LoweredProgram" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-c99-plan-stability.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$AST_FILE" "$TABLE_FILE" "$IDS_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use libc;

const C99_MAX_MONO_INSTANCES: i32 = 16;
const C99_MAX_REACHABLE_FUNCTIONS: i32 = 16;

struct MonoInstanceCodegen {
    generic_name: &byte,
    type_args: & & ASTNode,
    type_arg_count: i32,
    is_function: i32,
}

struct C99CodeGenerator {
    arena: &CompilerArena,
    program_node: &ASTNode,
    mono_instances: [MonoInstanceCodegen: C99_MAX_MONO_INSTANCES],
    mono_instance_count: i32,
    reachable_mono_instances: [i32: C99_MAX_MONO_INSTANCES],
    reachable_function_decls: [&ASTNode: C99_MAX_REACHABLE_FUNCTIONS],
    reachable_function_decl_count: i32,
}

fn is_generic_function_c99(fn_decl: &ASTNode) i32 {
    if fn_decl != null && fn_decl.type == ASTNodeType.AST_FN_DECL && fn_decl.fn_decl_type_param_count > 0 {
        return 1;
    }
    return 0;
}

fn is_generic_struct_c99(struct_decl: &ASTNode) i32 {
    if struct_decl != null && struct_decl.type == ASTNodeType.AST_STRUCT_DECL && struct_decl.struct_decl_type_param_count > 0 {
        return 1;
    }
    return 0;
}

fn is_generic_union_c99(union_decl: &ASTNode) i32 {
    if union_decl != null && union_decl.type == ASTNodeType.AST_UNION_DECL && union_decl.union_decl_type_param_count > 0 {
        return 1;
    }
    return 0;
}

fn has_unresolved_mono_type_args(generic_decl: &ASTNode, type_args: & & ASTNode, type_arg_count: i32) i32 {
    return 0;
}

fn get_export_function_c_name(codegen: &C99CodeGenerator, name: &byte, filename: &byte) &byte {
    return name;
}

fn get_mono_struct_name(codegen: &C99CodeGenerator, generic_name: &byte, type_args: & & ASTNode, type_arg_count: i32) &byte {
    if generic_name != null && strcmp(generic_name as *byte, "Box" as *byte) == 0 {
        return "Box_i32" as &byte;
    }
    return generic_name;
}
EOF

cat "$PLAN_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

const OVER_PLAN_UNITS: i32 = 1025;
const OVER_PLAN_PROTOTYPES: i32 = 4097;
const OVER_PLAN_DEPS: i32 = 1025;
const MANY_SPLIT_SOURCES: i32 = 130;

fn plan_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn plan_program() C99Plan {
    return C99Plan{
        arena: null,
        unit_count: 0usize,
        decl_count: 0,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: C99_PLAN_LIFECYCLE_UNINITIALIZED,
        split_enabled: 0,
        split_mirror: 0,
        split_lcp: 0,
        split_part1_unit_id: -1,
        split_part2_unit_id: -1,
        split_common_unit_id: -1,
        split_source_count: 0usize,
        includes: plan_vec(),
        typedefs: plan_vec(),
        prototypes: plan_vec(),
        globals: plan_vec(),
        functions: plan_vec(),
        helpers: plan_vec(),
        deps: plan_vec(),
        decls: plan_vec(),
        units: plan_vec(),
        split_sources: plan_vec(),
    };
}

fn prototype_codegen_stub(arena: &CompilerArena, program: &ASTNode) C99CodeGenerator {
    return C99CodeGenerator{
        arena: arena,
        program_node: program,
        mono_instances: [MonoInstanceCodegen{
            generic_name: null,
            type_args: null,
            type_arg_count: 0,
            is_function: 0,
        }: C99_MAX_MONO_INSTANCES],
        mono_instance_count: 0,
        reachable_mono_instances: [0: C99_MAX_MONO_INSTANCES],
        reachable_function_decls: [null: C99_MAX_REACHABLE_FUNCTIONS],
        reachable_function_decl_count: 0,
    };
}

test "c99 plan defines stable units and dynamic tables" {
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

    var plan: C99Plan = plan_program();
    c99_plan_init(&plan, &arena);
    try assert_eq_i32(c99_plan_lifecycle_state(&plan), C99_PLAN_LIFECYCLE_ACTIVE);

    // program 级表追加
    try assert_eq_i32(c99_plan_add_include(&plan, 10), 0);
    try assert_eq_i32(c99_plan_add_typedef(&plan, 20), 0);
    try assert_eq_i32(c99_plan_add_prototype(&plan, 30), 0);
    try assert_eq_i32(c99_plan_add_global(&plan, 40), 0);
    try assert_eq_i32(c99_plan_add_function(&plan, 50), 0);
    try assert_eq_i32(c99_plan_add_helper(&plan, 60), 0);
    try assert_eq_i32(c99_plan_includes_is_one(&plan), 1);

    // 三个 unit + 依赖追踪（unit2 依赖 unit0 与 unit1）
    const u0: i32 = c99_plan_add_unit(&plan, 100);
    const u1: i32 = c99_plan_add_unit(&plan, 101);
    const u2: i32 = c99_plan_add_unit(&plan, 102);
    try assert_eq_i32(u0, 0);
    try assert_eq_i32(u1, 1);
    try assert_eq_i32(u2, 2);
    try assert_eq_i32(c99_plan_unit_count(&plan) as i32, 3);

    try assert_eq_i32(c99_plan_unit_add_prototype(&plan, u0, 1000), 0);
    try assert_eq_i32(c99_plan_unit_add_function(&plan, u0, 1001), 0);
    try assert_eq_i32(c99_plan_unit_add_dep(&plan, u2, u0), 0);
    try assert_eq_i32(c99_plan_unit_add_dep(&plan, u2, u1), 0);

    const unit2: &C99UnitPlan = c99_plan_unit_ptr(&plan, u2);
    try expect(unit2 != null);
    try assert_eq_i32(unit2.deps.count as i32, 2);
    const dep0: &i32 = semantic_vector_item_ptr(&unit2.deps, 0usize) as &i32;
    const dep1: &i32 = semantic_vector_item_ptr(&unit2.deps, 1usize) as &i32;
    try expect(dep0 != null);
    try expect(dep1 != null);
    try assert_eq_i32(dep0[0], 0);
    try assert_eq_i32(dep1[0], 1);

    const unit0: &C99UnitPlan = c99_plan_unit_ptr(&plan, u0);
    try expect(unit0 != null);
    try assert_eq_i32(unit0.prototypes.count as i32, 1);
    try assert_eq_i32(unit0.functions.count as i32, 1);
    try assert_eq_i32(unit0.unit_id, 0);
    try assert_eq_i32(unit0.name_id, 100);

    try expect(c99_plan_estimated_bytes(&plan) > @size_of(C99Plan));
    try expect(c99_plan_peak_bytes(&plan) >= c99_plan_estimated_bytes(&plan));

    c99_plan_release(&plan);
    try assert_eq_i32(c99_plan_lifecycle_state(&plan), C99_PLAN_LIFECYCLE_RELEASED);
    compiler_arena_free_all(&arena);
}

test "c99 plan records top level declarations for emitter" {
    var arena_buf: [byte: 8192] = [];
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

    const program: &ASTNode = ast_new_node(ASTNodeType.AST_PROGRAM, 1, 1, &arena, "decl_plan.uya");
    const use_decl: &ASTNode = ast_new_node(ASTNodeType.AST_USE_STMT, 1, 1, &arena, "decl_plan.uya");
    const fn_decl: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 2, 1, &arena, "decl_plan.uya");
    const var_decl: &ASTNode = ast_new_node(ASTNodeType.AST_VAR_DECL, 3, 1, &arena, "decl_plan.uya");
    fn_decl.fn_decl_name = "main" as *byte;
    var_decl.var_decl_name = "answer" as *byte;
    var decls: [&ASTNode: 3] = [];
    decls[0] = use_decl;
    decls[1] = fn_decl;
    decls[2] = var_decl;
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 3;

    var plan: C99Plan = plan_program();
    c99_plan_init(&plan, &arena);
    try assert_eq_i32(c99_plan_build_decls(&plan, program), 0);
    try assert_eq_i32(plan.decl_count, 3);
    try assert_eq_i32(plan.decls.count as i32, 3);
    try expect(c99_plan_decl_at(&plan, 0) == use_decl);
    try expect(c99_plan_decl_at(&plan, 1) == fn_decl);
    try expect(c99_plan_decl_at(&plan, 2) == var_decl);
    try expect(c99_plan_decl_at(&plan, 3) == null);

    c99_plan_release(&plan);
    compiler_arena_free_all(&arena);
}

test "c99 plan tables grow past legacy capacities" {
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

    var plan: C99Plan = plan_program();
    c99_plan_init(&plan, &arena);

    // 大量 unit，超过任何固定上限
    var i: i32 = 0;
    while i < OVER_PLAN_UNITS {
        const uid: i32 = c99_plan_add_unit(&plan, i);
        try assert_eq_i32(uid, i);
        i = i + 1;
    }
    try assert_eq_i32(c99_plan_unit_count(&plan) as i32, OVER_PLAN_UNITS);
    try expect(plan.units.capacity >= 1025usize);
    try expect(plan.units.realloc_count > 1);

    // 大量 prototypes 写入 unit0
    i = 0;
    while i < OVER_PLAN_PROTOTYPES {
        try assert_eq_i32(c99_plan_unit_add_prototype(&plan, 0, i), 0);
        i = i + 1;
    }
    const unit0: &C99UnitPlan = c99_plan_unit_ptr(&plan, 0);
    try expect(unit0 != null);
    try assert_eq_i32(unit0.prototypes.count as i32, OVER_PLAN_PROTOTYPES);
    try expect(unit0.prototypes.realloc_count > 1);

    // 大量 program 级 deps
    i = 0;
    while i < OVER_PLAN_DEPS {
        try assert_eq_i32(c99_plan_add_dep(&plan, i), 0);
        i = i + 1;
    }
    try assert_eq_i32(plan.deps.count as i32, OVER_PLAN_DEPS);
    try expect(plan.deps.realloc_count > 1);

    const stats: C99PlanStats = c99_plan_stats(&plan);
    try expect(stats.table_count > 8);
    try expect(stats.table_items >= 5122usize);

    c99_plan_release(&plan);
    compiler_arena_free_all(&arena);
}

fn c99_test_split_decl(arena: &CompilerArena, filename: &byte, name: &byte) &ASTNode {
    const decl: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, arena, filename);
    if decl != null {
        decl.fn_decl_name = name;
    }
    return decl;
}

fn c99_test_make_split_path(arena: &CompilerArena, idx: i32) &byte {
    const path: &byte = compiler_arena_alloc(arena, 96) as &byte;
    if path == null {
        return null;
    }
    snprintf(path as *byte, 96, "/repo/pkg/file_%d.uya" as *byte, idx);
    return path;
}

test "c99 split unit planner assigns mirror and common units" {
    var arena_buf: [byte: 131072] = [];
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

    const program: &ASTNode = ast_new_node(ASTNodeType.AST_PROGRAM, 1, 1, &arena, "/repo/src/main.uya" as &byte);
    const main_decl: &ASTNode = c99_test_split_decl(&arena, "/repo/src/main.uya" as &byte, "main_decl" as &byte);
    const duplicate_main: &ASTNode = c99_test_split_decl(&arena, "/repo/src/main.uya" as &byte, "duplicate_main" as &byte);
    const thread_decl: &ASTNode = c99_test_split_decl(&arena, "/repo/lib/std/thread.uya" as &byte, "thread_decl" as &byte);
    const entry_decl: &ASTNode = c99_test_split_decl(&arena, "/repo/lib/runtime/entry/entry.uya" as &byte, "entry_decl" as &byte);
    const test_decl: &ASTNode = c99_test_split_decl(&arena, "/repo/tests/test_one.uya" as &byte, "test_decl" as &byte);
    const bar_decl: &ASTNode = c99_test_split_decl(&arena, "/repo/lib/foo/bar.uya" as &byte, "bar_decl" as &byte);
    var decls: [&ASTNode: 6] = [];
    decls[0] = main_decl;
    decls[1] = duplicate_main;
    decls[2] = thread_decl;
    decls[3] = entry_decl;
    decls[4] = test_decl;
    decls[5] = bar_decl;
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 6;

    var plan: C99Plan = plan_program();
    c99_plan_init(&plan, &arena);
    const input: C99SplitUnitPlanInput = C99SplitUnitPlanInput{
        ast: program,
        decl_count: 6,
        split_enabled: 1,
        split_mirror: 1,
    };
    try assert_eq_i32(c99_split_unit_plan_build(&plan, input), 0);
    try assert_eq_i32(plan.split_enabled, 1);
    try assert_eq_i32(plan.split_mirror, 1);
    try assert_eq_i32(plan.split_part1_unit_id, 0);
    try assert_eq_i32(plan.split_common_unit_id, 1);
    try assert_eq_i32(c99_plan_unit_count(&plan) as i32, 4);
    try assert_eq_i32(plan.split_sources.count as i32, 5);

    const main_unit: &C99UnitPlan = c99_plan_split_unit_for_source(&plan, "/repo/src/main.uya" as &byte);
    const bar_unit: &C99UnitPlan = c99_plan_split_unit_for_source(&plan, "/repo/lib/foo/bar.uya" as &byte);
    const thread_unit: &C99UnitPlan = c99_plan_split_unit_for_source(&plan, "/repo/lib/std/thread.uya" as &byte);
    const entry_unit: &C99UnitPlan = c99_plan_split_unit_for_source(&plan, "/repo/lib/runtime/entry/entry.uya" as &byte);
    const tests_unit: &C99UnitPlan = c99_plan_split_unit_for_source(&plan, "/repo/tests/test_one.uya" as &byte);
    try expect(main_unit != null);
    try expect(bar_unit != null);
    try expect(thread_unit != null);
    try expect(entry_unit != null);
    try expect(tests_unit != null);
    try assert_eq_i32(main_unit.kind, C99_SPLIT_UNIT_KIND_MIRROR_SOURCE);
    try assert_eq_i32(strcmp(main_unit.c_path as *byte, "src/main.c" as *byte), 0);
    try assert_eq_i32(strcmp(main_unit.object_path as *byte, "src/main.o" as *byte), 0);
    try assert_eq_i32(bar_unit.kind, C99_SPLIT_UNIT_KIND_MIRROR_SOURCE);
    try assert_eq_i32(strcmp(bar_unit.c_path as *byte, "lib/foo/bar.c" as *byte), 0);
    try assert_eq_i32(thread_unit.unit_id, plan.split_common_unit_id);
    try assert_eq_i32(entry_unit.unit_id, plan.split_common_unit_id);
    try assert_eq_i32(tests_unit.unit_id, plan.split_common_unit_id);

    c99_plan_release(&plan);

    var part_plan: C99Plan = plan_program();
    c99_plan_init(&part_plan, &arena);
    const part_input: C99SplitUnitPlanInput = C99SplitUnitPlanInput{
        ast: program,
        decl_count: 6,
        split_enabled: 1,
        split_mirror: 0,
    };
    try assert_eq_i32(c99_split_unit_plan_build(&part_plan, part_input), 0);
    try assert_eq_i32(c99_plan_unit_count(&part_plan) as i32, 2);
    try assert_eq_i32(part_plan.split_part1_unit_id, 0);
    try assert_eq_i32(part_plan.split_part2_unit_id, 1);
    try assert_eq_i32(part_plan.split_sources.count as i32, 5);
    const part2_unit: &C99UnitPlan = c99_plan_split_unit_for_source(&part_plan, "/repo/lib/foo/bar.uya" as &byte);
    try expect(part2_unit != null);
    try assert_eq_i32(part2_unit.unit_id, part_plan.split_part2_unit_id);
    c99_plan_release(&part_plan);

    compiler_arena_free_all(&arena);
}

test "c99 split unit planner grows past legacy mirror unit capacity" {
    var arena_buf: [byte: 262144] = [];
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

    const program: &ASTNode = ast_new_node(ASTNodeType.AST_PROGRAM, 1, 1, &arena, "/repo/pkg/root.uya" as &byte);
    var decls: [&ASTNode: MANY_SPLIT_SOURCES] = [];
    var i: i32 = 0;
    while i < MANY_SPLIT_SOURCES {
        const path: &byte = c99_test_make_split_path(&arena, i);
        decls[i] = c99_test_split_decl(&arena, path, "many" as &byte);
        i = i + 1;
    }
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = MANY_SPLIT_SOURCES;

    var plan: C99Plan = plan_program();
    c99_plan_init(&plan, &arena);
    const input: C99SplitUnitPlanInput = C99SplitUnitPlanInput{
        ast: program,
        decl_count: MANY_SPLIT_SOURCES,
        split_enabled: 1,
        split_mirror: 1,
    };
    try assert_eq_i32(c99_split_unit_plan_build(&plan, input), 0);
    try assert_eq_i32(c99_plan_unit_count(&plan) as i32, MANY_SPLIT_SOURCES + 2);
    try assert_eq_i32(plan.split_sources.count as i32, MANY_SPLIT_SOURCES);
    try expect(plan.units.capacity > 128usize);
    try expect(plan.units.realloc_count > 1);

    c99_plan_release(&plan);
    compiler_arena_free_all(&arena);
}

test "c99 prototype plan records function prototype events" {
    var arena_buf: [byte: 65536] = [];
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

    const program: &ASTNode = ast_new_node(ASTNodeType.AST_PROGRAM, 1, 1, &arena, "c99_proto.uya");
    const body: &ASTNode = ast_new_node(ASTNodeType.AST_NUMBER, 1, 1, &arena, "c99_proto.uya");
    const arg_i32: &ASTNode = ast_new_node(ASTNodeType.AST_TYPE_NAMED, 1, 1, &arena, "c99_proto.uya");
    arg_i32.type_named_name = "i32" as *byte;
    var type_args: [&ASTNode: 1] = [];
    type_args[0] = arg_i32;

    const foo: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, &arena, "c99_proto.uya");
    const hidden: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, &arena, "c99_proto.uya");
    const ext: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, &arena, "c99_proto.uya");
    const id_fn: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, &arena, "c99_proto.uya");
    foo.fn_decl_name = "foo" as *byte;
    foo.fn_decl_body = body;
    hidden.fn_decl_name = "hidden" as *byte;
    hidden.fn_decl_body = body;
    ext.fn_decl_name = "host_read" as *byte;
    id_fn.fn_decl_name = "id" as *byte;
    id_fn.fn_decl_body = body;
    id_fn.fn_decl_type_param_count = 1;

    const method_block: &ASTNode = ast_new_node(ASTNodeType.AST_METHOD_BLOCK, 1, 1, &arena, "c99_proto.uya");
    const map_method: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, &arena, "c99_proto.uya");
    map_method.fn_decl_name = "map" as *byte;
    map_method.fn_decl_type_param_count = 1;
    var block_methods: [&ASTNode: 1] = [];
    block_methods[0] = map_method;
    method_block.method_block_struct_name = "Thing" as *byte;
    method_block.method_block_methods = &block_methods[0] as & & ASTNode;
    method_block.method_block_method_count = 1;

    const box_decl: &ASTNode = ast_new_node(ASTNodeType.AST_STRUCT_DECL, 1, 1, &arena, "c99_proto.uya");
    const get_method: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, &arena, "c99_proto.uya");
    box_decl.struct_decl_name = "Box" as *byte;
    box_decl.struct_decl_type_param_count = 1;
    get_method.fn_decl_name = "get" as *byte;
    var struct_methods: [&ASTNode: 1] = [];
    struct_methods[0] = get_method;
    box_decl.struct_decl_methods = &struct_methods[0] as & & ASTNode;
    box_decl.struct_decl_method_count = 1;

    var decls: [&ASTNode: 6] = [];
    decls[0] = foo;
    decls[1] = hidden;
    decls[2] = ext;
    decls[3] = id_fn;
    decls[4] = method_block;
    decls[5] = box_decl;
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 6;

    var codegen: C99CodeGenerator = prototype_codegen_stub(&arena, program);
    codegen.reachable_function_decls[0] = foo;
    codegen.reachable_function_decls[1] = id_fn;
    codegen.reachable_function_decl_count = 2;
    codegen.mono_instances[0] = MonoInstanceCodegen{
        generic_name: "id" as *byte,
        type_args: &type_args[0] as & & ASTNode,
        type_arg_count: 1,
        is_function: 1,
    };
    codegen.reachable_mono_instances[0] = 1;
    codegen.mono_instances[1] = MonoInstanceCodegen{
        generic_name: "Thing_map_i32" as *byte,
        type_args: &type_args[0] as & & ASTNode,
        type_arg_count: 1,
        is_function: 1,
    };
    codegen.mono_instances[2] = MonoInstanceCodegen{
        generic_name: "Box" as *byte,
        type_args: &type_args[0] as & & ASTNode,
        type_arg_count: 1,
        is_function: 0,
    };
    codegen.mono_instance_count = 3;

    var proto_plan: C99PrototypePlan = c99_prototype_plan_empty();
    c99_prototype_plan_init(&proto_plan);
    try assert_eq_i32(c99_prototype_plan_build(&proto_plan, &codegen, program, 6), 0);
    try assert_eq_i32(proto_plan.count, 5);

    const e0: &C99PrototypePlanEntry = c99_prototype_plan_entry_at(&proto_plan, 0);
    const e1: &C99PrototypePlanEntry = c99_prototype_plan_entry_at(&proto_plan, 1);
    const e2: &C99PrototypePlanEntry = c99_prototype_plan_entry_at(&proto_plan, 2);
    const e3: &C99PrototypePlanEntry = c99_prototype_plan_entry_at(&proto_plan, 3);
    const e4: &C99PrototypePlanEntry = c99_prototype_plan_entry_at(&proto_plan, 4);
    try expect(e0 != null);
    try expect(e1 != null);
    try expect(e2 != null);
    try expect(e3 != null);
    try expect(e4 != null);
    try assert_eq_i32(e0.kind, C99_PROTOTYPE_KIND_FUNCTION);
    try expect(e0.decl == foo);
    try assert_eq_i32(e1.kind, C99_PROTOTYPE_KIND_FUNCTION);
    try expect(e1.decl == ext);
    try assert_eq_i32(e2.kind, C99_PROTOTYPE_KIND_MONO_FUNCTION);
    try assert_eq_i32(e2.type_arg_count, 1);
    try assert_eq_i32(e3.kind, C99_PROTOTYPE_KIND_MONO_METHOD);
    try assert_eq_i32(strcmp(e3.owner_name as *byte, "Thing" as *byte), 0);
    try assert_eq_i32(e4.kind, C99_PROTOTYPE_KIND_METHOD);
    try assert_eq_i32(strcmp(e4.owner_name as *byte, "Box_i32" as *byte), 0);
    try expect(e4.owner_decl == box_decl);
    try assert_eq_i32(e4.owner_type_arg_count, 1);

    c99_prototype_plan_release(&proto_plan);
    compiler_arena_free_all(&arena);
}

test "c99 type definition plan records type emission events" {
    var arena_buf: [byte: 65536] = [];
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

    const program: &ASTNode = ast_new_node(ASTNodeType.AST_PROGRAM, 1, 1, &arena, "c99_types.uya");
    const enum_decl: &ASTNode = ast_new_node(ASTNodeType.AST_ENUM_DECL, 1, 1, &arena, "c99_types.uya");
    const alias_decl: &ASTNode = ast_new_node(ASTNodeType.AST_TYPE_ALIAS, 1, 1, &arena, "c99_types.uya");
    const result_union: &ASTNode = ast_new_node(ASTNodeType.AST_UNION_DECL, 1, 1, &arena, "c99_types.uya");
    const box_struct: &ASTNode = ast_new_node(ASTNodeType.AST_STRUCT_DECL, 1, 1, &arena, "c99_types.uya");
    const pair_struct: &ASTNode = ast_new_node(ASTNodeType.AST_STRUCT_DECL, 1, 1, &arena, "c99_types.uya");
    const i32_type: &ASTNode = ast_new_node(ASTNodeType.AST_TYPE_NAMED, 1, 1, &arena, "c99_types.uya");
    i32_type.type_named_name = "i32" as *byte;

    enum_decl.enum_decl_name = "Color" as *byte;
    alias_decl.type_alias_name = "MyInt" as *byte;
    alias_decl.type_alias_target_type = i32_type;
    result_union.union_decl_name = "Result" as *byte;
    result_union.union_decl_type_param_count = 1;
    box_struct.struct_decl_name = "Box" as *byte;
    box_struct.struct_decl_type_param_count = 1;
    pair_struct.struct_decl_name = "Pair" as *byte;

    var decls: [&ASTNode: 5] = [];
    decls[0] = enum_decl;
    decls[1] = alias_decl;
    decls[2] = result_union;
    decls[3] = box_struct;
    decls[4] = pair_struct;
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 5;

    var type_args: [&ASTNode: 1] = [];
    type_args[0] = i32_type;
    var codegen: C99CodeGenerator = prototype_codegen_stub(&arena, program);
    codegen.mono_instances[0] = MonoInstanceCodegen{
        generic_name: "Result" as *byte,
        type_args: &type_args[0] as & & ASTNode,
        type_arg_count: 1,
        is_function: 0,
    };
    codegen.mono_instances[1] = MonoInstanceCodegen{
        generic_name: "Box" as *byte,
        type_args: &type_args[0] as & & ASTNode,
        type_arg_count: 1,
        is_function: 0,
    };
    codegen.mono_instance_count = 2;

    var type_plan: C99TypeDefinitionPlan = c99_type_definition_plan_empty();
    c99_type_definition_plan_init(&type_plan);
    try assert_eq_i32(c99_type_definition_plan_build(&type_plan, &codegen, program, 5), 0);
    try assert_eq_i32(type_plan.registration_count, 3);
    try assert_eq_i32(type_plan.early_definition_count, 2);
    try assert_eq_i32(type_plan.layout_definition_count, 4);

    const r0: &C99TypeDefinitionPlanEntry = c99_type_definition_plan_registration_at(&type_plan, 0);
    const r1: &C99TypeDefinitionPlanEntry = c99_type_definition_plan_registration_at(&type_plan, 1);
    const r2: &C99TypeDefinitionPlanEntry = c99_type_definition_plan_registration_at(&type_plan, 2);
    try expect(r0 != null);
    try expect(r1 != null);
    try expect(r2 != null);
    try assert_eq_i32(r0.kind, C99_TYPEDEF_KIND_REGISTER_ENUM);
    try expect(r0.decl == enum_decl);
    try assert_eq_i32(r1.kind, C99_TYPEDEF_KIND_REGISTER_MONO_STRUCT);
    try expect(r1.decl == box_struct);
    try assert_eq_i32(r1.type_arg_count, 1);
    try assert_eq_i32(r2.kind, C99_TYPEDEF_KIND_REGISTER_STRUCT);
    try expect(r2.decl == pair_struct);

    const e0: &C99TypeDefinitionPlanEntry = c99_type_definition_plan_early_at(&type_plan, 0);
    const e1: &C99TypeDefinitionPlanEntry = c99_type_definition_plan_early_at(&type_plan, 1);
    try expect(e0 != null);
    try expect(e1 != null);
    try assert_eq_i32(e0.kind, C99_TYPEDEF_KIND_ENUM);
    try assert_eq_i32(e1.kind, C99_TYPEDEF_KIND_ALIAS);

    const l0: &C99TypeDefinitionPlanEntry = c99_type_definition_plan_layout_at(&type_plan, 0);
    const l1: &C99TypeDefinitionPlanEntry = c99_type_definition_plan_layout_at(&type_plan, 1);
    const l2: &C99TypeDefinitionPlanEntry = c99_type_definition_plan_layout_at(&type_plan, 2);
    const l3: &C99TypeDefinitionPlanEntry = c99_type_definition_plan_layout_at(&type_plan, 3);
    try expect(l0 != null);
    try expect(l1 != null);
    try expect(l2 != null);
    try expect(l3 != null);
    try assert_eq_i32(l0.kind, C99_TYPEDEF_KIND_MONO_UNION);
    try expect(l0.decl == result_union);
    try assert_eq_i32(l0.type_arg_count, 1);
    try assert_eq_i32(l1.kind, C99_TYPEDEF_KIND_BUILTIN_TYPEINFO);
    try assert_eq_i32(l2.kind, C99_TYPEDEF_KIND_MONO_STRUCT);
    try expect(l2.decl == box_struct);
    try assert_eq_i32(l3.kind, C99_TYPEDEF_KIND_STRUCT);
    try expect(l3.decl == pair_struct);

    c99_type_definition_plan_release(&type_plan);
    compiler_arena_free_all(&arena);
}

test "c99 helper plan records helper emission needs" {
    var arena_buf: [byte: 32768] = [];
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

    const program: &ASTNode = ast_new_node(ASTNodeType.AST_PROGRAM, 1, 1, &arena, "helper_plan.uya");
    const async_decl: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, &arena, "lib/std/async_frame.uya");
    async_decl.fn_decl_name = "async_frame_runtime_marker" as *byte;
    var decls: [&ASTNode: 1] = [];
    decls[0] = async_decl;
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 1;

    const input: C99HelperPlanInput = C99HelperPlanInput{
        ast: program,
        decl_plan: null,
        decl_count: 1,
        container_mode: 1,
        microapp_softvm_mode: 1,
        needs_syscall_helpers: 1,
        simd_struct_count: 2,
        async_frame_meta_count: 3,
    };
    const plan: C99HelperPlan = c99_helper_plan_build(input);
    try assert_eq_i32(plan.emit_error_name_helper, 1);
    try assert_eq_i32(plan.emit_microapp_mmu_helpers, 1);
    try assert_eq_i32(plan.emit_simd_runtime_helpers, 1);
    try assert_eq_i32(plan.emit_syscall_helpers, 1);
    try assert_eq_i32(plan.emit_microapp_syscall_helpers, 1);
    try assert_eq_i32(plan.emit_async_frame_descriptors, 1);
    try assert_eq_i32(plan.async_frame_descriptor_count, 3);
    try assert_eq_i32(plan.async_frame_runtime_used, 1);

    const quiet_input: C99HelperPlanInput = C99HelperPlanInput{
        ast: program,
        decl_plan: null,
        decl_count: 0,
        container_mode: 0,
        microapp_softvm_mode: 1,
        needs_syscall_helpers: 0,
        simd_struct_count: 0,
        async_frame_meta_count: -7,
    };
    const quiet: C99HelperPlan = c99_helper_plan_build(quiet_input);
    try assert_eq_i32(quiet.emit_error_name_helper, 1);
    try assert_eq_i32(quiet.emit_microapp_mmu_helpers, 0);
    try assert_eq_i32(quiet.emit_simd_runtime_helpers, 0);
    try assert_eq_i32(quiet.emit_syscall_helpers, 0);
    try assert_eq_i32(quiet.emit_microapp_syscall_helpers, 0);
    try assert_eq_i32(quiet.emit_async_frame_descriptors, 1);
    try assert_eq_i32(quiet.async_frame_descriptor_count, 0);
    try assert_eq_i32(quiet.async_frame_runtime_used, 0);

    compiler_arena_free_all(&arena);
}

test "c99 prelude plan records hosted header decisions" {
    var arena_buf: [byte: 32768] = [];
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

    const program: &ASTNode = ast_new_node(ASTNodeType.AST_PROGRAM, 1, 1, &arena, "c99_plan.uya");
    const body: &ASTNode = ast_new_node(ASTNodeType.AST_NUMBER, 1, 1, &arena, "c99_plan.uya");
    const malloc_decl: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, &arena, "c99_plan.uya");
    const strlen_impl: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, &arena, "c99_plan.uya");
    const read_decl: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, &arena, "c99_plan.uya");
    const write_impl: &ASTNode = ast_new_node(ASTNodeType.AST_FN_DECL, 1, 1, &arena, "c99_plan.uya");
    malloc_decl.fn_decl_name = "malloc" as *byte;
    strlen_impl.fn_decl_name = "strlen" as *byte;
    strlen_impl.fn_decl_body = body;
    read_decl.fn_decl_name = "read" as *byte;
    write_impl.fn_decl_name = "write" as *byte;
    write_impl.fn_decl_body = body;
    var decls: [&ASTNode: 4] = [];
    decls[0] = malloc_decl;
    decls[1] = strlen_impl;
    decls[2] = read_decl;
    decls[3] = write_impl;
    program.program_decls = &decls[0] as & & ASTNode;
    program.program_decl_count = 4;

    const hosted_input: C99PreludePlanInput = C99PreludePlanInput{
        ast: program,
        decl_plan: null,
        decl_count: 4,
        freestanding: 0,
        needs_string_h: 1,
        needs_stdio_h: 1,
        needs_stdlib_h: 1,
        has_stdio_conflicts: 0,
        is_bootstrap: 0,
        target_os_is_macos: 0,
    };
    const hosted: C99PreludePlan = c99_prelude_plan_build(hosted_input);
    try assert_eq_i32(hosted.include_stddef_h, 1);
    try assert_eq_i32(hosted.include_stdio_base_h, 1);
    try assert_eq_i32(hosted.include_math_h, 1);
    try assert_eq_i32(hosted.include_string_h, 0);
    try assert_eq_i32(hosted.include_stdlib_h, 1);
    try assert_eq_i32(hosted.include_stdio_requested_h, 1);
    try assert_eq_i32(hosted.emit_malloc_decl, 1);
    try assert_eq_i32(hosted.emit_read_decl, 1);
    try assert_eq_i32(hosted.emit_write_decl, 0);
    try assert_eq_i32(hosted.emit_opendir_decl, 1);
    try assert_eq_i32(hosted.emit_exit_decl, 1);

    const free_input: C99PreludePlanInput = C99PreludePlanInput{
        ast: program,
        decl_plan: null,
        decl_count: 4,
        freestanding: 1,
        needs_string_h: 1,
        needs_stdio_h: 1,
        needs_stdlib_h: 1,
        has_stdio_conflicts: 0,
        is_bootstrap: 0,
        target_os_is_macos: 0,
    };
    const free_plan: C99PreludePlan = c99_prelude_plan_build(free_input);
    try assert_eq_i32(free_plan.include_stddef_h, 0);
    try assert_eq_i32(free_plan.emit_malloc_decl, 0);

    const mac_bootstrap_input: C99PreludePlanInput = C99PreludePlanInput{
        ast: program,
        decl_plan: null,
        decl_count: 4,
        freestanding: 0,
        needs_string_h: 0,
        needs_stdio_h: 0,
        needs_stdlib_h: 0,
        has_stdio_conflicts: 0,
        is_bootstrap: 1,
        target_os_is_macos: 1,
    };
    const mac_bootstrap: C99PreludePlan = c99_prelude_plan_build(mac_bootstrap_input);
    try assert_eq_i32(mac_bootstrap.emit_read_decl, 1);
    try assert_eq_i32(mac_bootstrap.emit_write_decl, 0);

    compiler_arena_free_all(&arena);
}
EOF

# 小工具：用纯整数返回值表达 includes 数量是否为 1（避免 usize 直接断言歧义）。
cat >>"$tmp_dir/main.uya" <<'EOF'
fn c99_plan_includes_is_one(plan: &C99Plan) i32 {
    if plan == null {
        return 0;
    }
    if plan.includes.count == 1usize {
        return 1;
    }
    return 0;
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ C99 plan stability + dynamic growth + split-C dependency verified"
