#!/usr/bin/env bash
#
# MIR-C99 heap/env/file runtime helper plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_FILE="$REPO_ROOT/src/codegen/mir_c99/runtime_helpers.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 heap/env/file runtime helper plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$HELPER_FILE" "$DRIVER_FILE" "$MIR_FILE" "$VERIFIER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_RUNTIME_HELPER_MALLOC \
    MIR_RUNTIME_HELPER_FREE \
    MIR_RUNTIME_HELPER_ENV \
    MIR_RUNTIME_HELPER_FILE_IO \
    MIR_RUNTIME_CAP_HEAP_HELPERS \
    MIR_RUNTIME_CAP_ENV_FILE_IO \
    mir_c99_runtime_helper_is_heap_allocator \
    mir_c99_runtime_helper_is_env_file_io \
    mir_c99_runtime_helper_plan_build; do
    require_pattern "$HELPER_FILE" "$symbol" "heap/env/file helper symbol $symbol"
done

require_pattern "$HELPER_FILE" 'module\.capability_reqs\.count' \
    "helper plan scans MIR capability requirements"
require_pattern "$HELPER_FILE" 'MIR_RUNTIME_HELPER_MALLOC \|\|' \
    "malloc helper id accepted"
require_pattern "$HELPER_FILE" 'MIR_RUNTIME_HELPER_FREE' \
    "free helper id accepted"
require_pattern "$HELPER_FILE" 'MIR_RUNTIME_HELPER_ENV \|\|' \
    "env helper id accepted"
require_pattern "$HELPER_FILE" 'MIR_RUNTIME_HELPER_FILE_IO' \
    "file IO helper id accepted"
require_pattern "$HELPER_FILE" 'portable_mir_target_profile_supports_runtime_capability' \
    "helper checks target runtime capability"
require_pattern "$DRIVER_FILE" 'mir_c99_runtime_helper_plan_build' \
    "driver builds runtime helper plan"
require_pattern "$MIR_FILE" 'MIR_RUNTIME_CAP_HEAP_HELPERS' \
    "PortableMIR exposes heap helper capability"
require_pattern "$MIR_FILE" 'MIR_RUNTIME_CAP_ENV_FILE_IO' \
    "PortableMIR exposes env/file helper capability"
require_pattern "$VERIFIER_FILE" 'MIR_RUNTIME_HELPER_FILE_IO' \
    "PortableMIR verifier recognizes file IO helper"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$HELPER_FILE"; then
    echo "error: MIR-C99 runtime helpers must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_runtime_heap_env_file_helper_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/cfg.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/values.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/place_memory.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/calls.uya" \
    "$HELPER_FILE" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 heap/env/file runtime helper plan verified"
