#!/usr/bin/env bash
#
# PortableMIR global initializer and string constant metadata verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
WHITEPAPER_FILE="$REPO_ROOT/docs/portable_mir_whitepaper.md"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR global initializer missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$VERIFIER_FILE" "$WHITEPAPER_FILE" "$TODO_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MirGlobal \
    MirConst \
    MIR_GLOBAL_INIT_SCALAR \
    MIR_GLOBAL_INIT_AGGREGATE \
    MIR_GLOBAL_INIT_STRING \
    MIR_CONST_KIND_SCALAR \
    MIR_CONST_KIND_AGGREGATE \
    MIR_CONST_KIND_STRING \
    MIR_GLOBAL_SECTION_DATA \
    MIR_GLOBAL_SECTION_RODATA \
    MIR_GLOBAL_LINKAGE_INTERNAL \
    MIR_GLOBAL_LINKAGE_EXPORT \
    portable_mir_append_global \
    portable_mir_append_const; do
    require_pattern "$MIR_FILE" "$symbol" "MIR global/const symbol $symbol"
done

require_pattern "$VERIFIER_FILE" 'portable_mir_verify_global_initializer' \
    "verifier validates global initializer metadata"
require_pattern "$VERIFIER_FILE" 'MIR_GLOBAL_INIT_STRING' \
    "verifier checks string global initializer kind"
require_pattern "$WHITEPAPER_FILE" 'global scalar / aggregate initializer' \
    "whitepaper records global scalar aggregate initializer"
require_pattern "$WHITEPAPER_FILE" 'string constants.*dedupe' \
    "whitepaper records string constant dedupe"
require_pattern "$TODO_FILE" 'global scalar / aggregate initializer、string constants、dedupe id 和 section/linkage metadata' \
    "todo records global initializer metadata leaf"

echo "OK: PortableMIR global initializer metadata verified"
