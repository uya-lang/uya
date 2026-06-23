#!/usr/bin/env bash
#
# MIR-C99 extern unit output contract verifier.
#
# This shard guards the exact current-source gap behind tests/extern_function.uya:
# build-only MIR-C99 must preserve extern symbol names, write extern prototypes,
# and emit the minimal extern-call + i32-eq function body surface without
# falling back to legacy AST/C99 structures inside src/codegen/mir_c99/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CFG_FILE="$REPO_ROOT/src/codegen/mir_c99/cfg.uya"
UNIT_OUTPUT_FILE="$REPO_ROOT/src/codegen/mir_c99/unit_output.uya"
BUILD_DRIVER="$REPO_ROOT/src/build_compiler_driver.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 extern unit output missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$CFG_FILE" "$UNIT_OUTPUT_FILE" "$BUILD_DRIVER"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

require_pattern "$CFG_FILE" 'extern_symbol_name:[[:space:]]*&byte' \
    "function plan stores extern symbol text"
require_pattern "$CFG_FILE" 'extern_symbol_name:[[:space:]]*null' \
    "function plan initializes extern symbol text to null"
require_pattern "$CFG_FILE" 'export[[:space:]]+fn[[:space:]]+mir_c99_cfg_bind_extern_symbol_name\(' \
    "cfg plan exposes extern symbol binding hook"

require_pattern "$UNIT_OUTPUT_FILE" 'fn[[:space:]]+mir_c99_unit_output_write_extern_function_prototype\(' \
    "unit output has dedicated extern prototype writer"
require_pattern "$UNIT_OUTPUT_FILE" 'function[.]extern_symbol_name == null' \
    "extern prototype writer rejects missing bound symbol names"
require_pattern "$UNIT_OUTPUT_FILE" 'extern[[:space:]]+' \
    "extern prototype writer emits C extern keyword"
require_pattern "$UNIT_OUTPUT_FILE" 'writer[.]unit[.]functions[.]count' \
    "extern prototype section scans unit function refs"
require_pattern "$UNIT_OUTPUT_FILE" 'fn[[:space:]]+mir_c99_unit_output_write_extern_call\(' \
    "unit output has dedicated extern call writer"
require_pattern "$UNIT_OUTPUT_FILE" 'target[.]kind == MIR_OPERAND_KIND_CALL_TARGET_EXTERN' \
    "extern call writer recognizes extern call target kind"
require_pattern "$UNIT_OUTPUT_FILE" 'callee_function[.]extern_symbol_name == null' \
    "extern call writer requires bound extern symbol names"
require_pattern "$UNIT_OUTPUT_FILE" 'inst[.]op == MIR_INST_OP_I32_EQ' \
    "unit output handles i32 eq needed by tests/extern_function.uya"
require_pattern "$UNIT_OUTPUT_FILE" 'mir_c99_unit_output_write_extern_call\(writer, stream, inst\)' \
    "block writer lowers generic extern call expressions"

require_pattern "$BUILD_DRIVER" 'fn[[:space:]]+native_build_mir_c99_bind_extern_symbol_names\(' \
    "build driver bridges extern symbol names from current-source AST"
require_pattern "$BUILD_DRIVER" 'mir_c99_cfg_bind_extern_symbol_name\(cfg_plan,' \
    "build driver binds extern names into cfg plan"
require_pattern "$BUILD_DRIVER" 'decl[.]fn_decl_name' \
    "build driver sources extern symbol names from fn_decl_name"
require_pattern "$BUILD_DRIVER" 'native_build_mir_c99_bind_extern_symbol_names\(&module,[[:space:]]*&cfg_plan,' \
    "MIR-C99 emit path binds extern names before unit output"

echo "OK: MIR-C99 extern unit output contract verified"
