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
        echo "错误: LoweredProgram debug dump 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$LOWER_CORE_FILE" 'UYA_DUMP_LOWERED_PROGRAM' "debug dump 环境变量"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_maybe_dump_summary' "debug dump 调度函数"
require_pattern "$LOWER_CORE_FILE" '=== lowered program ===' "debug dump 起始标记"
require_pattern "$LOWER_CORE_FILE" 'lowered_program_stats' "debug dump 输出动态表摘要"

tmp_dir="$(mktemp -d /tmp/uya-lowered-dump.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn lower_dump_vector() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn lower_dump_program() LoweredProgram {
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
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        functions: lower_dump_vector(),
        body_ops: lower_dump_vector(),
        globals: lower_dump_vector(),
        types: lower_dump_vector(),
        interfaces: lower_dump_vector(),
        err_unions: lower_dump_vector(),
        async_frames: lower_dump_vector(),
        drop_defer_plans: lower_dump_vector(),
        helpers: lower_dump_vector(),
        worklist: lower_dump_vector(),
    };
}

test "lowered program dump is controlled by env" {
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

    var lowered: LoweredProgram = lower_dump_program();
    lowered_program_init(&lowered, &arena);

    var fn_item: ConcreteFunction = ConcreteFunction{
        function_id: 1,
        decl_id: 1,
        mono_instance_id: 1,
        body_start: 0,
        body_count: 0,
    };
    var helper_item: RuntimeHelper = RuntimeHelper{
        helper_id: 2,
        kind: LOWERED_RUNTIME_HELPER_UNKNOWN,
        name_id: 20,
    };
    try assert_eq_i32(lowered_program_append_function(&lowered, &fn_item), 0);
    try assert_eq_i32(lowered_program_close_runtime_helper_requirement(&lowered, &helper_item), 0);
    lowered_program_maybe_dump_summary(&lowered);

    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

default_stderr="$tmp_dir/default.stderr"
dump_stderr="$tmp_dir/dump.stderr"

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c >"$tmp_dir/default.stdout" 2>"$default_stderr")
if grep -Fq "=== lowered program ===" "$default_stderr"; then
    echo "错误: 未设置 UYA_DUMP_LOWERED_PROGRAM 时不应输出 LoweredProgram dump" >&2
    exit 1
fi

(cd "$REPO_ROOT" && UYA_DUMP_LOWERED_PROGRAM=1 ./bin/uya test "$tmp_dir/main.uya" --no-split-c >"$tmp_dir/dump.stdout" 2>"$dump_stderr")
if ! grep -Fq "=== lowered program ===" "$dump_stderr"; then
    echo "错误: UYA_DUMP_LOWERED_PROGRAM=1 时缺少 LoweredProgram dump 起始标记" >&2
    exit 1
fi
if ! grep -Fq "functions=1" "$dump_stderr" || ! grep -Fq "helpers=1" "$dump_stderr" || ! grep -Fq "work_items=1" "$dump_stderr"; then
    echo "错误: LoweredProgram dump 缺少核心摘要字段" >&2
    exit 1
fi
if ! grep -Eq "tables=[0-9]+ table_items=[0-9]+ table_capacity=[0-9]+ table_bytes=[0-9]+ table_reallocs=[0-9]+" "$dump_stderr"; then
    echo "错误: LoweredProgram dump 缺少动态表摘要" >&2
    exit 1
fi
if ! grep -Fq "=== lowered program end ===" "$dump_stderr"; then
    echo "错误: UYA_DUMP_LOWERED_PROGRAM=1 时缺少 LoweredProgram dump 结束标记" >&2
    exit 1
fi

echo "✓ LoweredProgram debug dump env switch verified"
