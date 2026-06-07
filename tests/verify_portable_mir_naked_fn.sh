#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR naked function contract missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$PORTABLE_MIR_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

for constant in \
    MIR_FUNCTION_FLAG_NAKED \
    MIR_FUNCTION_BODY_KIND_ASM_ONLY_NAKED \
    MIR_NAKED_FORBID_PROLOGUE_EPILOGUE \
    MIR_NAKED_FORBID_STACK_SLOT \
    MIR_NAKED_FORBID_CLEANUP \
    MIR_NAKED_FORBID_DROP \
    MIR_NAKED_FORBID_ASYNC \
    MIR_NAKED_FORBID_IMPLICIT_RETURN; do
    require_pattern "$MIR_FILE" "export const ${constant}" "constant $constant"
done

require_pattern "$MIR_FILE" 'body_kind:[[:space:]]*i32' "MirFunction body kind"
require_pattern "$MIR_FILE" 'naked_asm_inst_start:[[:space:]]*i32' "naked asm start"
require_pattern "$MIR_FILE" 'naked_asm_inst_count:[[:space:]]*i32' "naked asm count"
require_pattern "$MIR_FILE" 'naked_forbidden_lowering_mask:[[:space:]]*i32' "forbidden lowering mask"
require_pattern "$MIR_FILE" 'portable_mir_naked_forbidden_lowering_mask' "naked forbidden lowering helper"
require_pattern "$MIR_FILE" 'portable_mir_function_has_naked_flag' "naked flag helper"
require_pattern "$MIR_FILE" 'portable_mir_function_rejects_naked_lowering' "naked lowering rejection helper"
require_pattern "$MIR_FILE" 'portable_mir_function_has_asm_only_naked_body' "asm-only naked body helper"
require_pattern "$PORTABLE_MIR_DOC" 'MirFunction\.flags\.naked' "documented naked flag"
require_pattern "$PORTABLE_MIR_DOC" 'body_kind = asm_only_naked' "documented asm-only naked body kind"
require_pattern "$PORTABLE_MIR_DOC" 'naked_forbidden_lowering_mask' "documented forbidden lowering mask"
require_pattern "$PORTABLE_MIR_DOC" 'prologue/epilogue' "documented prologue/epilogue ban"
require_pattern "$PORTABLE_MIR_DOC" 'stack slot' "documented stack slot ban"
require_pattern "$PORTABLE_MIR_DOC" 'cleanup' "documented cleanup ban"
require_pattern "$PORTABLE_MIR_DOC" 'drop' "documented drop ban"
require_pattern "$PORTABLE_MIR_DOC" 'async' "documented async ban"
require_pattern "$PORTABLE_MIR_DOC" 'implicit return' "documented implicit return ban"

tmp_dir="$(mktemp -d /tmp/uya-portable-mir-naked.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cat >"$tmp_dir/main.uya" <<'EOF'
export type FileId = i32;
export type DeclId = i32;
export type SymbolId = i32;
export type TypeId = i32;
export type ExprId = i32;
export type FunctionId = i32;
export type CoreBodyId = i32;

export struct CompilerArena {
    marker: i32,
}

export struct SemanticVector {
    data: &byte,
    item_size: usize,
    count: usize,
    capacity: usize,
    bytes: usize,
    realloc_count: i32,
}

export fn semantic_vector_init(vec: &SemanticVector, item_size: usize) void {
    if vec == null {
        return;
    }
    vec.data = null;
    vec.item_size = item_size;
    vec.count = 0usize;
    vec.capacity = 0usize;
    vec.bytes = 0usize;
    vec.realloc_count = 0;
}

export fn semantic_vector_append(vec: &SemanticVector, item: &const void) i32 {
    if vec == null || item == null {
        return -1;
    }
    vec.count = vec.count + 1usize;
    return 0;
}

export fn semantic_vector_free(vec: &SemanticVector) void {
    if vec == null {
        return;
    }
    vec.data = null;
    vec.count = 0usize;
    vec.capacity = 0usize;
    vec.bytes = 0usize;
}

export fn semantic_vector_release(vec: &SemanticVector) void {
    semantic_vector_free(vec);
}
EOF

cat "$MIR_FILE" >>"$tmp_dir/main.uya"

cat >>"$tmp_dir/main.uya" <<'EOF'
use std.testing.assert_eq_i32;

fn portable_mir_naked_test_function(mode: i32) MirFunction {
    const forbidden: i32 = portable_mir_naked_forbidden_lowering_mask();
    var func: MirFunction = MirFunction{
        function_id: 0,
        lowered_function_id: 11,
        decl_id: 12,
        source_core_body_id: 0,
        symbol_id: 13,
        signature_type_id: 0,
        param_start: 0,
        param_count: 0,
        local_start: 0,
        local_count: 0,
        block_start: 0,
        block_count: 0,
        entry_block_id: MIR_BLOCK_INVALID_ID,
        cleanup_model: 0,
        capability_req_start: 0,
        capability_req_count: 0,
        calling_convention: 1,
        runtime_capability_mask: 1,
        required_address_space_mask: MIR_ADDRESS_SPACE_GENERIC,
        body_kind: MIR_FUNCTION_BODY_KIND_ASM_ONLY_NAKED,
        naked_asm_inst_start: 0,
        naked_asm_inst_count: 1,
        naked_forbidden_lowering_mask: forbidden,
        debug_loc_id: 0,
        flags: MIR_FUNCTION_FLAG_NAKED,
    };
    if mode == 1 {
        func.flags = 0;
        func.body_kind = MIR_FUNCTION_BODY_KIND_NORMAL;
        func.naked_forbidden_lowering_mask = 0;
    }
    if mode == 2 {
        func.body_kind = MIR_FUNCTION_BODY_KIND_NORMAL;
    }
    if mode == 3 {
        func.local_count = 1;
    }
    if mode == 4 {
        func.block_count = 1;
        func.entry_block_id = 0;
    }
    if mode == 5 {
        func.cleanup_model = 1;
    }
    if mode == 6 {
        func.naked_forbidden_lowering_mask = MIR_NAKED_FORBID_PROLOGUE_EPILOGUE;
    }
    if mode == 7 {
        func.naked_asm_inst_count = 0;
    }
    return func;
}

test "PortableMIR records asm-only naked body and forbidden lowering mask" {
    const forbidden: i32 = portable_mir_naked_forbidden_lowering_mask();
    try assert_eq_i32(forbidden, MIR_NAKED_FORBID_PROLOGUE_EPILOGUE + MIR_NAKED_FORBID_STACK_SLOT +
        MIR_NAKED_FORBID_CLEANUP + MIR_NAKED_FORBID_DROP + MIR_NAKED_FORBID_ASYNC +
        MIR_NAKED_FORBID_IMPLICIT_RETURN);

    var valid: MirFunction = portable_mir_naked_test_function(0);
    try assert_eq_i32(portable_mir_function_has_naked_flag(&valid), 1);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&valid), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, MIR_NAKED_FORBID_PROLOGUE_EPILOGUE), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, MIR_NAKED_FORBID_STACK_SLOT), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, MIR_NAKED_FORBID_CLEANUP), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, MIR_NAKED_FORBID_DROP), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, MIR_NAKED_FORBID_ASYNC), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, MIR_NAKED_FORBID_IMPLICIT_RETURN), 1);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&valid, forbidden), 1);

    var ordinary: MirFunction = portable_mir_naked_test_function(1);
    try assert_eq_i32(portable_mir_function_has_naked_flag(&ordinary), 0);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&ordinary), 0);
    try assert_eq_i32(portable_mir_function_rejects_naked_lowering(&ordinary, forbidden), 0);
}

test "PortableMIR rejects ordinary lowering shape for naked functions" {
    var normal_body: MirFunction = portable_mir_naked_test_function(2);
    var local_stack: MirFunction = portable_mir_naked_test_function(3);
    var ordinary_block: MirFunction = portable_mir_naked_test_function(4);
    var cleanup_body: MirFunction = portable_mir_naked_test_function(5);
    var partial_forbidden: MirFunction = portable_mir_naked_test_function(6);
    var empty_asm_body: MirFunction = portable_mir_naked_test_function(7);

    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&normal_body), 0);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&local_stack), 0);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&ordinary_block), 0);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&cleanup_body), 0);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&partial_forbidden), 0);
    try assert_eq_i32(portable_mir_function_has_asm_only_naked_body(&empty_asm_body), 0);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya test "$tmp_dir/main.uya" --no-split-c)

echo "OK: PortableMIR naked function contract verified"
