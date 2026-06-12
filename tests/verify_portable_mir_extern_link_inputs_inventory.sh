#!/usr/bin/env bash
#
# PortableMIR extern global and C import link input metadata verifier.

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
        echo "error: PortableMIR extern/link input missing evidence: $description" >&2
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
    MirLinkInput \
    MIR_GLOBAL_INIT_EXTERN \
    MIR_GLOBAL_LINKAGE_EXTERN \
    MIR_SYMBOL_VISIBILITY_DEFAULT \
    MIR_SYMBOL_VISIBILITY_HIDDEN \
    MIR_LINK_INPUT_KIND_C_IMPORT_OBJECT \
    MIR_LINK_INPUT_KIND_OBJECT_FILE \
    MIR_LINK_INPUT_KIND_LIBRARY \
    MIR_LINK_INPUT_KIND_SEARCH_PATH \
    portable_mir_append_link_input; do
    require_pattern "$MIR_FILE" "$symbol" "MIR extern/link symbol $symbol"
done

require_pattern "$VERIFIER_FILE" 'portable_mir_verify_link_inputs' \
    "verifier validates link input metadata"
require_pattern "$VERIFIER_FILE" 'MIR_GLOBAL_LINKAGE_EXTERN' \
    "verifier accepts extern global linkage"
require_pattern "$WHITEPAPER_FILE" 'C import object/link inputs' \
    "whitepaper records C import object link inputs"
require_pattern "$TODO_FILE" 'extern globals、C import object/link inputs、symbol visibility 和 target profile metadata' \
    "todo records extern/link input metadata leaf"

echo "OK: PortableMIR extern/link input metadata verified"
