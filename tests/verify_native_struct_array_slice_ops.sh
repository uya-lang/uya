#!/usr/bin/env bash

# Native build-seed 边界：验证 native build compiler 子集所需 struct/array/slice 基础内存操作。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MEMORY_FILE="$REPO_ROOT/src/codegen/native/memory.uya"
X86_FILE="$REPO_ROOT/src/codegen/native/x86_64.uya"
TEST_FILE="$REPO_ROOT/tests/test_native_struct_array_slice_ops.uya"

require_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "错误: 缺少 $path" >&2
        exit 1
    fi
}

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 缺少 native struct/array/slice 证据: $description" >&2
        exit 1
    fi
}

require_file "$MEMORY_FILE"
require_file "$X86_FILE"
require_file "$TEST_FILE"

require_pattern "$MEMORY_FILE" '^export[[:space:]]+struct[[:space:]]+NativeMemorySlot' "memory slot 结构"
require_pattern "$MEMORY_FILE" '^export[[:space:]]+struct[[:space:]]+NativeIndexedAddress' "indexed address 结构"
require_pattern "$MEMORY_FILE" '^export[[:space:]]+struct[[:space:]]+NativeSliceLayout' "slice layout 结构"
require_pattern "$MEMORY_FILE" 'native_memory_struct_field_slot' "struct field slot helper"
require_pattern "$MEMORY_FILE" 'native_memory_array_element_slot' "array element slot helper"
require_pattern "$MEMORY_FILE" 'native_memory_array_indexed_address' "array indexed address helper"
require_pattern "$MEMORY_FILE" 'native_memory_slice_layout' "slice layout helper"

require_pattern "$X86_FILE" 'x86_64_emit_load_r64_base_index_scale_disp32' "indexed load"
require_pattern "$X86_FILE" 'x86_64_emit_store_r64_base_index_scale_disp32' "indexed store"
require_pattern "$X86_FILE" 'x86_64_emit_lea_r64_base_index_scale_disp32' "indexed lea"

(cd "$REPO_ROOT" && ./bin/uya test tests/test_native_struct_array_slice_ops.uya --no-split-c --project-root src/)

echo "verify_native_struct_array_slice_ops: ok"
