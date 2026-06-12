#!/usr/bin/env bash
#
# MIR-C99 single-C host compile plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN_FILE="$REPO_ROOT/src/codegen/mir_c99/host_compile.uya"

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$PLAN_FILE"; then
        echo "error: MIR-C99 host compile plan missing evidence: $description" >&2
        exit 1
    fi
}

if [[ ! -f "$PLAN_FILE" ]]; then
    echo "error: missing MIR-C99 host compile source: $PLAN_FILE" >&2
    exit 1
fi

require_pattern 'export struct MirC99HostCompilePlan' "host compile plan struct"
require_pattern 'source_c_path:[[:space:]]*&byte' "single C input path"
require_pattern 'temp_object_path:[[:space:]]*&byte' "temporary object path"
require_pattern 'output_executable_path:[[:space:]]*&byte' "executable output path"
require_pattern 'MIR_C99_HOST_STD_C99' "C99 standard marker"
require_pattern 'command_arg_count = 8' "fixed host cc command shape"
require_pattern 'cleanup_pending_count' "temp cleanup lifecycle counter"
require_pattern 'mir_c99_host_compile_mark_c_written' "C written lifecycle transition"
require_pattern 'mir_c99_host_compile_mark_object_ready' "object lifecycle transition"
require_pattern 'mir_c99_host_compile_mark_executable_ready' "executable lifecycle transition"
require_pattern 'mir_c99_host_compile_mark_cleaned' "cleanup lifecycle transition"

if grep -Eq 'c99_write_split_makefile|split_makefile|split-C makefile|codegen\.c99|C99CodeGenerator' "$PLAN_FILE"; then
    echo "error: MIR-C99 host compile plan must not call legacy C99 split-C writer" >&2
    exit 1
fi

"$REPO_ROOT/bin/uya" check "$PLAN_FILE" >/dev/null

echo "OK: MIR-C99 host compile plan and temp lifecycle verified"
