#!/usr/bin/env bash

# Phase 9：验证 NativeEmitter 读取 LoweredProgram 并导入 MachineModule。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARENA_FILE="$REPO_ROOT/src/arena.uya"
TABLE_FILE="$REPO_ROOT/src/semantic/table.uya"
IDS_FILE="$REPO_ROOT/src/semantic/ids.uya"
TYPED_PROGRAM_FILE="$REPO_ROOT/src/typed/program.uya"
LOWER_CORE_FILE="$REPO_ROOT/src/lower/core.uya"
MACHINE_FILE="$REPO_ROOT/src/codegen/native/machine.uya"
ELF64_FILE="$REPO_ROOT/src/codegen/native/elf64.uya"
EMITTER_FILE="$REPO_ROOT/src/codegen/native/emitter.uya"

for file in "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" "$MACHINE_FILE" "$ELF64_FILE" "$EMITTER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$EMITTER_FILE"; then
        echo "错误: NativeEmitter LoweredProgram 接线缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern '^export[[:space:]]+struct[[:space:]]+NativeEmitter' "NativeEmitter 结构"
require_pattern 'lowered_program:[[:space:]]*&LoweredProgram' "LoweredProgram 输入指针"
require_pattern 'machine_module:[[:space:]]*&MachineModule' "MachineModule 输出指针"
require_pattern 'native_emitter_begin' "emitter 初始化入口"
require_pattern 'native_emitter_read_lowered_program' "读取 LoweredProgram 入口"
require_pattern 'lowered_program_stats' "读取 LoweredProgram 动态表统计"
require_pattern 'lowered_program\.body_ops' "读取 LoweredProgram body op 表"
require_pattern 'semantic_vector_item_ptr\(&emitter\.lowered_program\.functions' "枚举 lowered functions"
require_pattern 'machine_function_add_block' "为 lowered function 导入 machine block"
require_pattern 'machine_block_add_inst' "导入 lowered body op 到 machine inst"
require_pattern 'machine_module_add_function' "导入 machine functions"
require_pattern 'machine_module_add_symbol' "导入 global symbols"

tmp_dir="$(mktemp -d /tmp/uya-native-emitter-lowered.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" "$MACHINE_FILE" "$ELF64_FILE" "$EMITTER_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

fn emitter_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn emitter_lowered_value() LoweredProgram {
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
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: LOWERED_PROGRAM_LIFECYCLE_UNINITIALIZED,
        functions: emitter_vec(),
        body_ops: emitter_vec(),
        core_bodies: emitter_vec(),
        globals: emitter_vec(),
        types: emitter_vec(),
        interfaces: emitter_vec(),
        err_unions: emitter_vec(),
        async_frames: emitter_vec(),
        drop_defer_plans: emitter_vec(),
        helpers: emitter_vec(),
        worklist: emitter_vec(),
    };
}

fn emitter_machine_value() MachineModule {
    return MachineModule{
        arena: null,
        function_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: MACHINE_LIFECYCLE_UNINITIALIZED,
        functions: emitter_vec(),
        relocs: emitter_vec(),
        symbols: emitter_vec(),
        strings: emitter_vec(),
        sections: emitter_vec(),
    };
}

test "native emitter reads lowered program counts and imports machine skeletons" {
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

    var lowered: LoweredProgram = emitter_lowered_value();
    lowered_program_init(&lowered, &arena);
    var fn0: ConcreteFunction = ConcreteFunction{
        function_id: 10,
        decl_id: 100,
        mono_instance_id: 0,
        body_start: 0,
        body_count: 3,
    };
    var fn1: ConcreteFunction = ConcreteFunction{
        function_id: 11,
        decl_id: 101,
        mono_instance_id: 1,
        body_start: 3,
        body_count: 2,
    };
    var global0: GlobalObject = GlobalObject{
        global_id: 30,
        decl_id: 130,
        type_id: 230,
        init_expr_id: 330,
    };
    var type0: ConcreteType = ConcreteType{
        type_id: 40,
        decl_id: 140,
        layout_id: 240,
        method_range_start: 0,
        method_range_count: 0,
    };
    var helper0: RuntimeHelper = RuntimeHelper{
        helper_id: 50,
        kind: LOWERED_RUNTIME_HELPER_UNKNOWN,
        name_id: 150,
    };
    var body0: LoweredBodyOp = LoweredBodyOp{
        opcode: LOWERED_BODY_OP_RETURN_CONST_I32,
        dst: 0,
        src0: 0,
        src1: 0,
        target_id: 10,
        imm: 7i64,
        flags: 0,
    };
    var body1: LoweredBodyOp = LoweredBodyOp{
        opcode: LOWERED_BODY_OP_RETURN_CALL,
        dst: 1,
        src0: 10,
        src1: 0,
        target_id: 11,
        imm: 0i64,
        flags: 1,
    };
    var body2: LoweredBodyOp = LoweredBodyOp{
        opcode: LOWERED_BODY_OP_ADD_I32,
        dst: 2,
        src0: 0,
        src1: 1,
        target_id: 0,
        imm: 0i64,
        flags: 0,
    };
    var body3: LoweredBodyOp = LoweredBodyOp{
        opcode: LOWERED_BODY_OP_RETURN_CONST_I32,
        dst: 0,
        src0: 0,
        src1: 0,
        target_id: 11,
        imm: 9i64,
        flags: 0,
    };
    var body4: LoweredBodyOp = LoweredBodyOp{
        opcode: LOWERED_BODY_OP_RETURN_CALL,
        dst: 0,
        src0: 11,
        src1: 0,
        target_id: 10,
        imm: 0i64,
        flags: 0,
    };
    try assert_eq_i32(lowered_program_append_body_op(&lowered, &body0), 0);
    try assert_eq_i32(lowered_program_append_body_op(&lowered, &body1), 0);
    try assert_eq_i32(lowered_program_append_body_op(&lowered, &body2), 0);
    try assert_eq_i32(lowered_program_append_body_op(&lowered, &body3), 0);
    try assert_eq_i32(lowered_program_append_body_op(&lowered, &body4), 0);
    try assert_eq_i32(lowered_program_append_function(&lowered, &fn0), 0);
    try assert_eq_i32(lowered_program_append_function(&lowered, &fn1), 0);
    try assert_eq_i32(lowered_program_append_global(&lowered, &global0), 0);
    try assert_eq_i32(lowered_program_append_type(&lowered, &type0), 0);
    try assert_eq_i32(lowered_program_append_helper(&lowered, &helper0), 0);

    var module: MachineModule = emitter_machine_value();
    machine_module_init(&module, &arena);
    var emitter: NativeEmitter = native_emitter_empty();

    try assert_eq_i32(native_emitter_begin(&emitter, &lowered, &module, 1), 0);
    try assert_eq_i32(emitter.status, NATIVE_EMITTER_STATUS_READY);
    try assert_eq_i32(emitter.lowered_function_count as i32, 2);
    try assert_eq_i32(emitter.lowered_body_op_count as i32, 5);
    try assert_eq_i32(emitter.lowered_global_count as i32, 1);
    try assert_eq_i32(emitter.lowered_type_count as i32, 1);
    try assert_eq_i32(emitter.lowered_helper_count as i32, 1);
    try expect(emitter.lowered_table_items >= 5usize);
    try expect(emitter.lowered_table_bytes > 0usize);
    try expect(emitter.lowered_bytes >= @size_of(LoweredProgram));

    try assert_eq_i32(native_emitter_read_lowered_program(&emitter), 0);
    try assert_eq_i32(emitter.status, NATIVE_EMITTER_STATUS_DONE);
    try assert_eq_i32(emitter.imported_function_count as i32, 2);
    try assert_eq_i32(emitter.imported_body_op_count as i32, 5);
    try assert_eq_i32(emitter.imported_global_count as i32, 1);
    try assert_eq_i32(machine_module_function_count(&module) as i32, 2);
    try assert_eq_i32(module.symbols.count as i32, 1);

    const got_fn0: &MachineFunction = machine_module_function_ptr(&module, 0);
    const got_fn1: &MachineFunction = machine_module_function_ptr(&module, 1);
    try expect(got_fn0 != null);
    try expect(got_fn1 != null);
    try assert_eq_i32(got_fn0.function_id, 10);
    try assert_eq_i32(got_fn0.name_id, 10);
    try assert_eq_i32(got_fn0.blocks.count as i32, 1);
    try assert_eq_i32(got_fn1.function_id, 11);
    try assert_eq_i32(got_fn1.blocks.count as i32, 1);
    const got_block0: &MachineBlock = machine_function_block_ptr(&module, 0, 0);
    const got_block1: &MachineBlock = machine_function_block_ptr(&module, 1, 0);
    try expect(got_block0 != null);
    try expect(got_block1 != null);
    try assert_eq_i32(got_block0.insts.count as i32, 3);
    try assert_eq_i32(got_block1.insts.count as i32, 2);
    const got_inst0: &MachineInst = semantic_vector_item_ptr(&got_block0.insts, 0usize) as &MachineInst;
    const got_inst1: &MachineInst = semantic_vector_item_ptr(&got_block0.insts, 1usize) as &MachineInst;
    try expect(got_inst0 != null);
    try expect(got_inst1 != null);
    try assert_eq_i32(got_inst0.opcode, LOWERED_BODY_OP_RETURN_CONST_I32);
    try assert_eq_i32(got_inst0.target_id, 10);
    try assert_eq_i32(got_inst0.imm as i32, 7);
    try assert_eq_i32(got_inst1.opcode, LOWERED_BODY_OP_RETURN_CALL);
    try assert_eq_i32(got_inst1.target_id, 11);
    try assert_eq_i32(got_inst1.flags, 1);

    const got_sym0: &MachineSymbol = semantic_vector_item_ptr(&module.symbols, 0usize) as &MachineSymbol;
    try expect(got_sym0 != null);
    try assert_eq_i32(got_sym0.name_id, 30);
    try assert_eq_i32(got_sym0.kind, MACHINE_SYMBOL_KIND_OBJECT);
    try assert_eq_i32(got_sym0.binding, MACHINE_SYMBOL_BIND_GLOBAL);

    machine_module_release(&module);
    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}

test "native emitter rejects unreadable state" {
    var emitter: NativeEmitter = native_emitter_empty();
    try assert_eq_i32(native_emitter_read_lowered_program(&emitter), -1);
    try assert_eq_i32(emitter.status, NATIVE_EMITTER_STATUS_ERROR);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native emitter LoweredProgram reader verified"
