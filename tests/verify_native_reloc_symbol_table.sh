#!/usr/bin/env bash

# Phase 9：验证 native reloc / symbol table 最小语义集合。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
MACHINE_FILE="$REPO_ROOT/src/codegen/native/machine.uya"

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$MACHINE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$MACHINE_FILE"; then
        echo "错误: native reloc/symbol table 缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'MACHINE_SYMBOL_KIND_FUNC' "function symbol kind"
require_pattern 'MACHINE_SYMBOL_KIND_OBJECT' "object symbol kind"
require_pattern 'MACHINE_RELOC_KIND_X86_64_PC32' "PC32 reloc kind"
require_pattern 'MACHINE_RELOC_KIND_X86_64_64' "absolute reloc kind"
require_pattern 'machine_symbol_make' "symbol 构造 helper"
require_pattern 'machine_reloc_make' "reloc 构造 helper"
require_pattern 'machine_module_find_symbol' "symbol 查找 helper"

tmp_dir="$(mktemp -d /tmp/uya-native-reloc-symbol.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$MACHINE_FILE" >"$tmp_dir/main.uya"
cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn reloc_symbol_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn reloc_symbol_module() MachineModule {
    return MachineModule{
        arena: null,
        function_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: MACHINE_LIFECYCLE_UNINITIALIZED,
        functions: reloc_symbol_vec(),
        relocs: reloc_symbol_vec(),
        symbols: reloc_symbol_vec(),
        strings: reloc_symbol_vec(),
        sections: reloc_symbol_vec(),
    };
}

test "native symbol and reloc minimal tables store and find entries" {
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

    var module: MachineModule = reloc_symbol_module();
    machine_module_init(&module, &arena);

    var entry_sym: MachineSymbol = machine_symbol_make(101, 1, 4096i64, 32i64,
        MACHINE_SYMBOL_KIND_FUNC, MACHINE_SYMBOL_BIND_GLOBAL);
    var data_sym: MachineSymbol = machine_symbol_make(202, 2, 64i64, 8i64,
        MACHINE_SYMBOL_KIND_OBJECT, MACHINE_SYMBOL_BIND_LOCAL);
    try assert_eq_i32(machine_module_add_symbol(&module, &entry_sym), 0);
    try assert_eq_i32(machine_module_add_symbol(&module, &data_sym), 1);
    try assert_eq_i32(machine_module_find_symbol(&module, 101), 0);
    try assert_eq_i32(machine_module_find_symbol(&module, 202), 1);
    try assert_eq_i32(machine_module_find_symbol(&module, 303), -1);

    const stored0: &MachineSymbol = semantic_vector_item_ptr(&module.symbols, 0usize) as &MachineSymbol;
    try expect(stored0 != null);
    try assert_eq_i32(stored0.kind, MACHINE_SYMBOL_KIND_FUNC);
    try assert_eq_i32(stored0.binding, MACHINE_SYMBOL_BIND_GLOBAL);

    var r0: MachineReloc = machine_reloc_make(12i64, 0, MACHINE_RELOC_KIND_X86_64_PC32, -4i64);
    var r1: MachineReloc = machine_reloc_make(24i64, 1, MACHINE_RELOC_KIND_X86_64_64, 0i64);
    try assert_eq_i32(machine_module_add_reloc(&module, &r0), 0);
    try assert_eq_i32(machine_module_add_reloc(&module, &r1), 0);
    try assert_eq_i32(module.relocs.count as i32, 2);

    const stored_r0: &MachineReloc = semantic_vector_item_ptr(&module.relocs, 0usize) as &MachineReloc;
    try expect(stored_r0 != null);
    try assert_eq_i32(stored_r0.kind, MACHINE_RELOC_KIND_X86_64_PC32);
    try assert_eq_i32(stored_r0.symbol_id, 0);
    try expect(stored_r0.addend == -4i64);

    machine_module_release(&module);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native reloc/symbol table verified"
