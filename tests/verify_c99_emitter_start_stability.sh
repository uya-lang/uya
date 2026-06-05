#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
C99_INTERNAL="$REPO_ROOT/src/codegen/c99/internal.uya"
C99_MAIN="$REPO_ROOT/src/codegen/c99/main.uya"
C99_FUNCTION="$REPO_ROOT/src/codegen/c99/function.uya"
OUT_C="$(mktemp /tmp/uya-c99-emitter-start.XXXXXX.c)"
OUT_BIN="$(mktemp /tmp/uya-c99-emitter-start.XXXXXX)"
STDERR_LOG="$(mktemp /tmp/uya-c99-emitter-start.XXXXXX.stderr)"

cleanup() {
    rm -f "$OUT_C" "$OUT_BIN" "$STDERR_LOG"
}
trap cleanup EXIT

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: C99 emitter start stability 缺少证据: $description" >&2
        exit 1
    fi
}

require_order() {
    local before_pattern="$1"
    local after_pattern="$2"
    local description="$3"
    local before_line
    local after_line
    before_line="$(grep -nE "$before_pattern" "$C99_MAIN" | head -n 1 | cut -d: -f1)"
    after_line="$(grep -nE "$after_pattern" "$C99_MAIN" | head -n 1 | cut -d: -f1)"
    if [[ -z "$before_line" || -z "$after_line" || "$before_line" -ge "$after_line" ]]; then
        echo "错误: C99 emitter start stability 顺序错误: $description" >&2
        exit 1
    fi
}

for file in "$C99_INTERNAL" "$C99_MAIN" "$C99_FUNCTION"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$C99_INTERNAL" 'emitter_start_mono_instance_count' "记录 emitter start mono 数量"
require_pattern "$C99_INTERNAL" 'emitter_start_err_union_struct_count' "记录 emitter start err_union 数量"
require_pattern "$C99_INTERNAL" 'emitter_start_async_frame_meta_count' "记录 emitter start async frame 数量"
require_pattern "$C99_FUNCTION" 'c99_codegen_preregister_async_frame_meta' "async frame descriptor 预注册 helper"
require_pattern "$C99_MAIN" 'c99_preregister_async_frame_metadata' "C99 emitter 前 async frame 预注册入口"
require_pattern "$C99_MAIN" 'c99_codegen_capture_emitter_start_stability' "C99 emitter start 快照入口"
require_pattern "$C99_MAIN" 'c99_codegen_verify_emitter_start_stability' "C99 emitter start 快照校验入口"
require_order 'c99_preregister_async_frame_metadata\(codegen, ast\);' \
    'if c99_codegen_capture_emitter_start_stability\(codegen\) != 0' \
    "async frame 预注册必须早于 emitter start 快照"
require_order 'if c99_codegen_capture_emitter_start_stability\(codegen\) != 0' \
    '第七步：生成所有函数的前向声明' \
    "emitter start 快照必须早于函数原型/函数体输出阶段"

export UYA_ROOT="$REPO_ROOT/lib/"
export UYA_DUMP_C99_EMITTER_START=1
"$COMPILER" --c99 "$SCRIPT_DIR/test_c99_async_frame_descriptors.uya" -o "$OUT_C" >/dev/null 2>"$STDERR_LOG"

if ! grep -q '\[UYA_C99_EMITTER_START\]' "$STDERR_LOG"; then
    echo "错误: 未输出 C99 emitter start 稳定快照" >&2
    exit 1
fi

async_count="$(sed -n 's/.*async_frame=\([0-9][0-9]*\).*/\1/p' "$STDERR_LOG" | tail -n 1)"
if [[ -z "$async_count" || "$async_count" -le 0 ]]; then
    echo "错误: async frame 数量未在 C99 emitter start 前稳定为正数" >&2
    exit 1
fi

if ! grep -q "int32_t _uya_async_frame_descriptor_count" "$OUT_C"; then
    echo "错误: 缺少 async frame descriptor count 输出" >&2
    exit 1
fi

cc -std=c99 -O0 -g -fno-builtin "$OUT_C" -o "$OUT_BIN" -lm
"$OUT_BIN" >/dev/null

echo "✓ C99 emitter start mono/err_union/async frame stability verified"
