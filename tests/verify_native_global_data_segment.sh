#!/usr/bin/env bash

# Phase 9：验证 native 全局数据段动态字节缓冲。

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
        echo "错误: native 全局数据段缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'export struct NativeDataSegment' "全局数据段结构"
require_pattern 'native_data_segment_init' "数据段初始化"
require_pattern 'native_data_segment_append_byte' "追加单字节"
require_pattern 'native_data_segment_append_bytes' "追加字节切片"
require_pattern 'native_data_segment_append_zeros' "追加零填充"
require_pattern 'native_data_segment_align_to' "对齐填充"
require_pattern 'semantic_vector_append' "动态增长字节表"

tmp_dir="$(mktemp -d /tmp/uya-native-global-data.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$MACHINE_FILE" >"$tmp_dir/main.uya"
cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

test "native global data segment appends bytes zeros and alignment padding" {
    var seg: NativeDataSegment = native_data_segment_empty();
    native_data_segment_init(&seg, 8);
    try assert_eq_i32(seg.lifecycle_state, MACHINE_LIFECYCLE_ACTIVE);
    try assert_eq_i32(seg.align, 8);

    try assert_eq_i32(native_data_segment_append_byte(&seg, 17 as byte), 0);
    var data: [byte: 3] = [];
    data[0] = 170 as byte;
    data[1] = 187 as byte;
    data[2] = 204 as byte;
    try assert_eq_i32(native_data_segment_append_bytes(&seg, &data[0] as &const byte, 3usize), 1);
    try assert_eq_i32(native_data_segment_size(&seg) as i32, 4);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 0usize), 17);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 1usize), 170);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 2usize), 187);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 3usize), 204);

    try assert_eq_i32(native_data_segment_align_to(&seg, 8), 8);
    try assert_eq_i32(native_data_segment_size(&seg) as i32, 8);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 4usize), 0);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 7usize), 0);

    try assert_eq_i32(native_data_segment_append_zeros(&seg, 2usize), 8);
    try assert_eq_i32(native_data_segment_size(&seg) as i32, 10);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 10usize), -1);

    native_data_segment_release(&seg);
    try assert_eq_i32(seg.lifecycle_state, MACHINE_LIFECYCLE_RELEASED);
}

test "native global data segment grows dynamically past small capacities" {
    var seg: NativeDataSegment = native_data_segment_empty();
    native_data_segment_init(&seg, 1);
    var i: i32 = 0;
    while i < 300 {
        try expect(native_data_segment_append_byte(&seg, (i & 255) as byte) >= 0);
        i = i + 1;
    }
    try assert_eq_i32(native_data_segment_size(&seg) as i32, 300);
    try expect(seg.bytes.capacity >= 300usize);
    try expect(seg.bytes.realloc_count > 1);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 0usize), 0);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 255usize), 255);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 256usize), 0);
    try expect(native_data_segment_capacity_bytes(&seg) >= native_data_segment_size(&seg));
    native_data_segment_release(&seg);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native global data segment verified"
