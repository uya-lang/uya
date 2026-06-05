#!/usr/bin/env bash

# Phase 6：验证 C99Plan / C99UnitPlan 计划结构定义、动态增长与 split-C 依赖追踪。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
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

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$PLAN_FILE"; do
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
require_pattern "$PLAN_FILE" 'c99_plan_add_unit' "动态追加 unit 入口"
require_pattern "$PLAN_FILE" 'c99_plan_unit_add_dep' "unit 依赖追加入口"

tmp_dir="$(mktemp -d /tmp/uya-c99-plan-stability.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$PLAN_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

const OVER_PLAN_UNITS: i32 = 1025;
const OVER_PLAN_PROTOTYPES: i32 = 4097;
const OVER_PLAN_DEPS: i32 = 1025;

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
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: C99_PLAN_LIFECYCLE_UNINITIALIZED,
        includes: plan_vec(),
        typedefs: plan_vec(),
        prototypes: plan_vec(),
        globals: plan_vec(),
        functions: plan_vec(),
        helpers: plan_vec(),
        deps: plan_vec(),
        units: plan_vec(),
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
