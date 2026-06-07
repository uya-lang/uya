#!/usr/bin/env bash

# Phase 9：验证 native 字符串常量写入全局数据段。

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
        echo "错误: native 字符串常量缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'export struct NativeStringConstant' "字符串常量摘要"
require_pattern 'native_data_segment_append_string_bytes' "按长度追加字符串"
require_pattern 'native_data_segment_append_c_string' "C string 追加入口"
require_pattern 'nul_terminated' "NUL 结尾状态"

tmp_dir="$(mktemp -d /tmp/uya-native-string-constants.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cat "$ARENA_FILE" "$TABLE_FILE" "$IDS_FILE" "$MACHINE_FILE" >"$tmp_dir/main.uya"
cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

test "native string constants append bytes and c strings" {
    var seg: NativeDataSegment = native_data_segment_empty();
    native_data_segment_init(&seg, 1);

    var raw: [byte: 4] = [];
    raw[0] = 65 as byte;
    raw[1] = 0 as byte;
    raw[2] = 66 as byte;
    raw[3] = 67 as byte;
    const s0: NativeStringConstant = native_data_segment_append_string_bytes(&seg, &raw[0] as &const byte, 4usize, 0);
    try assert_eq_i32(s0.offset, 0);
    try expect(s0.byte_len == 4usize);
    try expect(s0.storage_len == 4usize);
    try assert_eq_i32(s0.nul_terminated, 0);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 0usize), 65);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 1usize), 0);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 2usize), 66);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 3usize), 67);

    const s1: NativeStringConstant = native_data_segment_append_c_string(&seg, "hi" as &const byte);
    try assert_eq_i32(s1.offset, 4);
    try expect(s1.byte_len == 2usize);
    try expect(s1.storage_len == 3usize);
    try assert_eq_i32(s1.nul_terminated, 1);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 4usize), 104);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 5usize), 105);
    try assert_eq_i32(native_data_segment_byte_at(&seg, 6usize), 0);
    try assert_eq_i32(native_data_segment_size(&seg) as i32, 7);

    native_data_segment_release(&seg);
}

test "native string constants reject invalid inputs" {
    var seg: NativeDataSegment = native_data_segment_empty();
    native_data_segment_init(&seg, 1);
    const bad0: NativeStringConstant = native_data_segment_append_c_string(&seg, null);
    try assert_eq_i32(bad0.offset, -1);
    const bad1: NativeStringConstant = native_data_segment_append_string_bytes(&seg, null, 1usize, 1);
    try assert_eq_i32(bad1.offset, -1);
    try assert_eq_i32(native_data_segment_size(&seg) as i32, 0);
    native_data_segment_release(&seg);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native string constants verified"
