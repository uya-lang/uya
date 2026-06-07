#!/usr/bin/env bash

# Phase 9：验证 NativeEmitter 输出使用 streaming writer，不构造完整 ELF 镜像副本。

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
        echo "错误: NativeEmitter streaming 输出缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern '^export[[:space:]]+struct[[:space:]]+NativeEmitterOutputResult' "streaming 输出摘要结构"
require_pattern 'native_emitter_stream_temp_peak_bytes' "emitter streaming 临时缓冲上界"
require_pattern 'native_emitter_write_executable_stream' "emitter streaming 输出入口"
require_pattern 'elf64_write_executable_stream' "调用 ELF64 streaming writer"
require_pattern 'elf64_stream_peak_temp_bytes' "复用固定 header 临时缓冲上界"

if grep -Eq 'elf64_write_executable\(' "$EMITTER_FILE"; then
    echo "错误: NativeEmitter 不应调用完整 ELF 镜像 helper" >&2
    exit 1
fi

if grep -Eq '\bmalloc\b|ELF.*image|full.*image' "$EMITTER_FILE"; then
    echo "错误: NativeEmitter streaming 输出不应保留完整 ELF 镜像副本" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-native-emitter-stream.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
output_path="$tmp_dir/native-emitter-stream.bin"
cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$TYPED_PROGRAM_FILE" "$LOWER_CORE_FILE" "$MACHINE_FILE" "$ELF64_FILE" "$EMITTER_FILE" >"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<EOF
use std.testing.assert_eq_i32;
use std.testing.expect;
use libc.FILE;
use libc.fclose;
use libc.fopen;
use libc.fread;
use libc.rewind;

fn stream_vec() SemanticVector {
    return SemanticVector{
        data: null,
        item_size: 0usize,
        count: 0usize,
        capacity: 0usize,
        bytes: 0usize,
        realloc_count: 0,
    };
}

fn stream_lowered_value() LoweredProgram {
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
        functions: stream_vec(),
        body_ops: stream_vec(),
        core_bodies: stream_vec(),
        core_stmts: stream_vec(),
        core_exprs: stream_vec(),
        core_places: stream_vec(),
        core_cleanup_edges: stream_vec(),
        core_semantic_facts: stream_vec(),
        globals: stream_vec(),
        types: stream_vec(),
        interfaces: stream_vec(),
        err_unions: stream_vec(),
        async_frames: stream_vec(),
        drop_defer_plans: stream_vec(),
        helpers: stream_vec(),
        worklist: stream_vec(),
    };
}

fn stream_machine_value() MachineModule {
    return MachineModule{
        arena: null,
        function_count: 0usize,
        estimated_bytes: 0usize,
        resident_peak_bytes: 0usize,
        lifecycle_state: MACHINE_LIFECYCLE_UNINITIALIZED,
        functions: stream_vec(),
        relocs: stream_vec(),
        symbols: stream_vec(),
        strings: stream_vec(),
        sections: stream_vec(),
    };
}

fn stream_bval(buf: &byte, i: usize) i32 {
    return buf[i] as i32;
}

test "native emitter writes executable through streaming writer" {
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

    var lowered: LoweredProgram = stream_lowered_value();
    lowered_program_init(&lowered, &arena);
    var module: MachineModule = stream_machine_value();
    machine_module_init(&module, &arena);
    var emitter: NativeEmitter = native_emitter_empty();
    try assert_eq_i32(native_emitter_begin(&emitter, &lowered, &module, 1), 0);

    var code: [byte: 4] = [];
    code[0] = 195 as byte; // ret, only used as payload bytes for this writer test
    code[1] = 144 as byte;
    code[2] = 144 as byte;
    code[3] = 144 as byte;

    const fp: &FILE = fopen("$output_path" as &const byte, "w+b" as &const byte);
    try expect(fp != null);
    const result: NativeEmitterOutputResult = native_emitter_write_executable_stream(&emitter,
        fp, &code[0] as &const byte, 4usize);
    try assert_eq_i32(result.status, NATIVE_EMITTER_STATUS_DONE);
    try assert_eq_i32(result.output_bytes as i32, ELF64_MIN_EXEC_HEADERS + 4);
    try assert_eq_i32(result.code_bytes as i32, 4);
    try expect(result.temp_peak_bytes == ELF64_MIN_EXEC_HEADERS as usize);
    try expect(native_emitter_stream_temp_peak_bytes(4096usize) == ELF64_MIN_EXEC_HEADERS as usize);

    rewind(fp);
    var out: [byte: 128] = [];
    const nread: usize = fread(&out[0], 1usize, result.output_bytes, fp);
    try expect(nread == result.output_bytes);
    try assert_eq_i32(stream_bval(&out[0], 0usize), 127);
    try assert_eq_i32(stream_bval(&out[0], 1usize), 69);
    try assert_eq_i32(stream_bval(&out[0], 2usize), 76);
    try assert_eq_i32(stream_bval(&out[0], 3usize), 70);
    try assert_eq_i32(stream_bval(&out[0], 60usize), 0);
    try assert_eq_i32(stream_bval(&out[0], 62usize), 0);
    try assert_eq_i32(stream_bval(&out[0], ELF64_MIN_EXEC_HEADERS as usize), 195);
    try assert_eq_i32(stream_bval(&out[0], (ELF64_MIN_EXEC_HEADERS + 1) as usize), 144);

    _ = fclose(fp);
    machine_module_release(&module);
    lowered_program_release(&lowered);
    compiler_arena_free_all(&arena);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native emitter streaming output verified"
