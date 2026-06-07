#!/usr/bin/env bash

# Phase 9：验证 native x86_64 函数调用基础指令编码。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
X86_FILE="$REPO_ROOT/src/codegen/native/x86_64.uya"

if [[ ! -f "$X86_FILE" ]]; then
    echo "错误: 缺少 $X86_FILE" >&2
    exit 1
fi

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$X86_FILE"; then
        echo "错误: x86_64 call 编码缺少证据: $description" >&2
        exit 1
    fi
}

require_pattern 'X86_64_OP_CALL_REL32' "direct call opcode"
require_pattern 'X86_64_OP_GROUP5_RM64' "indirect call opcode group"
require_pattern 'x86_64_emit_call_rel32' "direct rel32 call helper"
require_pattern 'x86_64_emit_call_r64' "indirect register call helper"

tmp_dir="$(mktemp -d /tmp/uya-native-x86-call.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

{
    cat <<'EOF'
use std.testing.assert_eq_i32;
use std.testing.expect;

EOF
    cat "$X86_FILE"
    cat <<'EOF'

fn call_bval(buf: &byte, i: usize) i32 {
    return buf[i] as i32;
}

test "x86_64 direct call rel32 encodes exact bytes" {
    var buf: [byte: 16] = [];
    var pos: usize = 0usize;
    try assert_eq_i32(x86_64_emit_call_rel32(&buf[0], 16usize, &pos, 5), 0);
    try expect(pos == 5usize);
    try assert_eq_i32(call_bval(&buf[0], 0usize), 232);
    try assert_eq_i32(call_bval(&buf[0], 1usize), 5);
    try assert_eq_i32(call_bval(&buf[0], 2usize), 0);
    try assert_eq_i32(call_bval(&buf[0], 3usize), 0);
    try assert_eq_i32(call_bval(&buf[0], 4usize), 0);

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_call_rel32(&buf[0], 16usize, &pos, -4), 0);
    try assert_eq_i32(call_bval(&buf[0], 0usize), 232);
    try assert_eq_i32(call_bval(&buf[0], 1usize), 252);
    try assert_eq_i32(call_bval(&buf[0], 2usize), 255);
    try assert_eq_i32(call_bval(&buf[0], 3usize), 255);
    try assert_eq_i32(call_bval(&buf[0], 4usize), 255);
}

test "x86_64 indirect register call encodes exact bytes" {
    var buf: [byte: 16] = [];
    var pos: usize = 0usize;
    try assert_eq_i32(x86_64_emit_call_r64(&buf[0], 16usize, &pos, X86_64_REG_RAX), 0);
    try expect(pos == 2usize);
    try assert_eq_i32(call_bval(&buf[0], 0usize), 255);
    try assert_eq_i32(call_bval(&buf[0], 1usize), 208);

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_call_r64(&buf[0], 16usize, &pos, X86_64_REG_R11), 0);
    try expect(pos == 3usize);
    try assert_eq_i32(call_bval(&buf[0], 0usize), 65);
    try assert_eq_i32(call_bval(&buf[0], 1usize), 255);
    try assert_eq_i32(call_bval(&buf[0], 2usize), 211);

    pos = 0usize;
    try assert_eq_i32(x86_64_emit_call_r64(&buf[0], 1usize, &pos, X86_64_REG_RAX), -1);
    try expect(pos == 0usize);
    try assert_eq_i32(x86_64_emit_call_r64(&buf[0], 16usize, &pos, 99), -1);
    try expect(pos == 0usize);
}
EOF
} >"$tmp_dir/main.uya"

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "✓ native x86_64 call instruction encoding verified"
