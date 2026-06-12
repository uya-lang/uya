#!/usr/bin/env bash
#
# MIR-C99 unit declaration-section output verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN_FILE="$REPO_ROOT/src/codegen/mir_c99/plan.uya"
CFG_FILE="$REPO_ROOT/src/codegen/mir_c99/cfg.uya"
OUTPUT_FILE="$REPO_ROOT/src/codegen/mir_c99/unit_output.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 unit output missing evidence: $description" >&2
        exit 1
    fi
}

if [[ ! -f "$PLAN_FILE" || ! -f "$CFG_FILE" || ! -f "$OUTPUT_FILE" ]]; then
    echo "error: missing MIR-C99 plan, CFG, or unit output source" >&2
    exit 1
fi

for symbol in \
    mir_c99_unit_output_write_include_section \
    mir_c99_unit_output_write_typedef_section \
    mir_c99_unit_output_write_extern_prototype_section \
    mir_c99_unit_output_write_function_prototype_section \
    mir_c99_unit_output_write_global_section \
    mir_c99_unit_output_write_function_body_section \
    mir_c99_unit_output_writer_bind_cfg \
    mir_c99_unit_output_write_declaration_sections; do
    require_pattern "$OUTPUT_FILE" "$symbol" "section writer $symbol"
done

require_pattern "$OUTPUT_FILE" 'mir_c99_unit_output_write_i32\(stream,[[:space:]]*ref\.source_id\)' \
    "section symbols use MirC99Ref.source_id"
require_pattern "$OUTPUT_FILE" '#include <stdint\.h>\\n#include <stddef\.h>\\n#include <stdbool\.h>' \
    "default C99 include bytes"
require_pattern "$OUTPUT_FILE" 'typedef int32_t uya_mir_ty_' "typedef bytes"
require_pattern "$OUTPUT_FILE" 'extern void uya_mir_helper_' "extern helper prototype bytes"
require_pattern "$OUTPUT_FILE" 'static int32_t uya_mir_fn_' "function prototype bytes"
require_pattern "$OUTPUT_FILE" 'static int32_t uya_mir_global_' "global bytes"
require_pattern "$OUTPUT_FILE" 'bb' "function body label bytes"
require_pattern "$OUTPUT_FILE" 'mir_c99_cfg_emit_br_goto' "function body emits BR terminators"
require_pattern "$OUTPUT_FILE" 'mir_c99_cfg_emit_cond_br_goto' "function body emits COND_BR terminators"
require_pattern "$OUTPUT_FILE" 'mir_c99_cfg_emit_return' "function body emits RETURN terminators"
require_pattern "$OUTPUT_FILE" 'cfg_plan:[[:space:]]*&MirC99CfgPlan' "unit output is bound to CFG plan"

if grep -Eq 'return 0;.*uya_mir_fn_|uya_mir_fn_.*return 0;' "$OUTPUT_FILE"; then
    echo "error: MIR-C99 unit output must not emit fixed return-0 function bodies" >&2
    exit 1
fi

line_include="$(grep -n 'mir_c99_unit_output_write_include_section(writer, stream)' "$OUTPUT_FILE" | head -1 | cut -d: -f1)"
line_typedef="$(grep -n 'mir_c99_unit_output_write_typedef_section(writer, stream)' "$OUTPUT_FILE" | head -1 | cut -d: -f1)"
line_extern="$(grep -n 'mir_c99_unit_output_write_extern_prototype_section(writer, stream)' "$OUTPUT_FILE" | head -1 | cut -d: -f1)"
line_fn="$(grep -n 'mir_c99_unit_output_write_function_prototype_section(writer, stream)' "$OUTPUT_FILE" | head -1 | cut -d: -f1)"
line_global="$(grep -n 'mir_c99_unit_output_write_global_section(writer, stream)' "$OUTPUT_FILE" | head -1 | cut -d: -f1)"
line_body="$(grep -n 'mir_c99_unit_output_write_function_body_section(writer, stream)' "$OUTPUT_FILE" | head -1 | cut -d: -f1)"

if [[ -z "$line_include" || -z "$line_typedef" || -z "$line_extern" || -z "$line_fn" ||
      "$line_include" -ge "$line_typedef" || "$line_typedef" -ge "$line_extern" || "$line_extern" -ge "$line_fn" ]]; then
    echo "error: declaration section writer order is not include -> typedef -> extern prototype -> function prototype" >&2
    exit 1
fi
if [[ -z "$line_global" || -z "$line_body" || "$line_global" -ge "$line_body" ]]; then
    echo "error: all-section writer order is not globals -> function bodies" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_unit_output_sections.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' "$PLAN_FILE" "$CFG_FILE" "$OUTPUT_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 unit declaration/global/function-body section output contract verified"
