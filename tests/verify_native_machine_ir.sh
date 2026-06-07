#!/usr/bin/env bash

# Phase 9：验证 native 机器 IR 数据结构定义、嵌套动态增长与统计。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
MACHINE_FILE="$REPO_ROOT/src/codegen/native/machine.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: native machine IR 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$MACHINE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$MACHINE_FILE" '^export[[:space:]]+struct[[:space:]]+MachineFunction' "MachineFunction 结构"
require_pattern "$MACHINE_FILE" '^export[[:space:]]+struct[[:space:]]+MachineBlock' "MachineBlock 结构"
require_pattern "$MACHINE_FILE" '^export[[:space:]]+struct[[:space:]]+MachineInst' "MachineInst 结构"
require_pattern "$MACHINE_FILE" 'relocs:[[:space:]]*SemanticVector' "reloc 动态表"
require_pattern "$MACHINE_FILE" 'symbols:[[:space:]]*SemanticVector' "symbol 动态表"
require_pattern "$MACHINE_FILE" 'strings:[[:space:]]*SemanticVector' "string 动态表"
require_pattern "$MACHINE_FILE" 'sections:[[:space:]]*SemanticVector' "section 动态表"
require_pattern "$MACHINE_FILE" 'machine_module_add_function' "动态追加函数入口"
require_pattern "$MACHINE_FILE" 'machine_block_add_inst' "动态追加指令入口"

tmp_dir="$(mktemp -d /tmp/uya-native-machine.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$MACHINE_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

const OVER_MACHINE_FUNCS: i32 = 1025;
const OVER_MACHINE_INSTS: i32 = 4097;
const OVER_MACHINE_RELOCS: i32 = 1025;
const OVER_MACHINE_SYMBOLS: i32 = 1025;
const OVER_MACHINE_SECTIONS: i32 = 257;

fn machine_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn machine_module_value() MachineModule {
    return MachineModule{
        arena: null,
        function_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: MACHINE_LIFECYCLE_UNINITIALIZED,
        functions: machine_vec(),
        relocs: machine_vec(),
        symbols: machine_vec(),
        strings: machine_vec(),
        sections: machine_vec(),
    };
}

fn make_inst(op: i32, imm: i64) MachineInst {
    return MachineInst{
        opcode: op,
        dst: 0,
        src0: 0,
        src1: 0,
        target_id: 0,
        imm: imm,
        flags: 0,
    };
}

test "native machine module defines nested IR and dynamic tables" {
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

    var module: MachineModule = machine_module_value();
    machine_module_init(&module, &arena);
    try assert_eq_i32(machine_module_lifecycle_state(&module), MACHINE_LIFECYCLE_ACTIVE);

    const f0: i32 = machine_module_add_function(&module, 7, 100);
    try assert_eq_i32(f0, 0);
    const b0: i32 = machine_function_add_block(&module, f0, 200);
    const b1: i32 = machine_function_add_block(&module, f0, 201);
    try assert_eq_i32(b0, 0);
    try assert_eq_i32(b1, 1);

    var inst0: MachineInst = make_inst(1, 42);
    var inst1: MachineInst = make_inst(2, 7);
    try assert_eq_i32(machine_block_add_inst(&module, f0, b0, &inst0), 0);
    try assert_eq_i32(machine_block_add_inst(&module, f0, b0, &inst1), 0);

    const fn0: &MachineFunction = machine_module_function_ptr(&module, f0);
    try expect(fn0 != null);
    try assert_eq_i32(fn0.function_id, 7);
    try assert_eq_i32(fn0.name_id, 100);
    try assert_eq_i32(fn0.blocks.count as i32, 2);

    const blk0: &MachineBlock = machine_function_block_ptr(&module, f0, b0);
    try expect(blk0 != null);
    try assert_eq_i32(blk0.label_name_id, 200);
    try assert_eq_i32(blk0.insts.count as i32, 2);
    const got0: &MachineInst = semantic_vector_item_ptr(&blk0.insts, 0usize) as &MachineInst;
    try expect(got0 != null);
    try assert_eq_i32(got0.opcode, 1);

    var reloc: MachineReloc = MachineReloc{ offset: 16, symbol_id: 3, kind: 1, addend: 0 };
    try assert_eq_i32(machine_module_add_reloc(&module, &reloc), 0);
    var sym: MachineSymbol = MachineSymbol{ name_id: 100, section_id: 1, value: 0, size: 32, kind: 2, binding: 1 };
    try assert_eq_i32(machine_module_add_symbol(&module, &sym), 0);
    var sec: MachineSection = MachineSection{ name_id: 300, kind: 1, size: 64, align: 16 };
    try assert_eq_i32(machine_module_add_section(&module, &sec), 0);
    try assert_eq_i32(machine_module_add_string(&module, 99), 0);

    try expect(machine_module_estimated_bytes(&module) > @size_of(MachineModule));
    try expect(machine_module_peak_bytes(&module) >= machine_module_estimated_bytes(&module));

    machine_module_release(&module);
    try assert_eq_i32(machine_module_lifecycle_state(&module), MACHINE_LIFECYCLE_RELEASED);
    compiler_arena_free_all(&arena);
}

test "native machine tables grow past legacy capacities" {
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

    var module: MachineModule = machine_module_value();
    machine_module_init(&module, &arena);

    // 大量函数
    var i: i32 = 0;
    while i < OVER_MACHINE_FUNCS {
        const fid: i32 = machine_module_add_function(&module, i, i);
        try assert_eq_i32(fid, i);
        i = i + 1;
    }
    try assert_eq_i32(machine_module_function_count(&module) as i32, OVER_MACHINE_FUNCS);
    try expect(module.functions.realloc_count > 1);

    // 函数0 内一个 block 写入大量指令
    const blk: i32 = machine_function_add_block(&module, 0, 0);
    try assert_eq_i32(blk, 0);
    i = 0;
    while i < OVER_MACHINE_INSTS {
        var inst: MachineInst = make_inst(i, i as i64);
        try assert_eq_i32(machine_block_add_inst(&module, 0, blk, &inst), 0);
        i = i + 1;
    }
    const blk0: &MachineBlock = machine_function_block_ptr(&module, 0, blk);
    try expect(blk0 != null);
    try assert_eq_i32(blk0.insts.count as i32, OVER_MACHINE_INSTS);
    try expect(blk0.insts.realloc_count > 1);

    // 大量 reloc / symbol / section
    i = 0;
    while i < OVER_MACHINE_RELOCS {
        var r: MachineReloc = MachineReloc{ offset: i as i64, symbol_id: i, kind: 1, addend: 0 };
        try assert_eq_i32(machine_module_add_reloc(&module, &r), 0);
        i = i + 1;
    }
    try assert_eq_i32(module.relocs.count as i32, OVER_MACHINE_RELOCS);
    try expect(module.relocs.realloc_count > 1);

    i = 0;
    while i < OVER_MACHINE_SYMBOLS {
        var s: MachineSymbol = MachineSymbol{ name_id: i, section_id: 1, value: 0, size: 0, kind: 1, binding: 1 };
        try expect(machine_module_add_symbol(&module, &s) >= 0);
        i = i + 1;
    }
    try assert_eq_i32(module.symbols.count as i32, OVER_MACHINE_SYMBOLS);
    try expect(module.symbols.realloc_count > 1);

    i = 0;
    while i < OVER_MACHINE_SECTIONS {
        var sec: MachineSection = MachineSection{ name_id: i, kind: 1, size: 0, align: 1 };
        try expect(machine_module_add_section(&module, &sec) >= 0);
        i = i + 1;
    }
    try assert_eq_i32(module.sections.count as i32, OVER_MACHINE_SECTIONS);
    try expect(module.sections.realloc_count > 1);

    const stats: MachineModuleStats = machine_module_stats(&module);
    try expect(stats.table_count > 5);
    try expect(stats.table_items >= 5122usize);

    machine_module_release(&module);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native machine IR definition + nested dynamic growth verified"
