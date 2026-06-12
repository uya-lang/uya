#!/usr/bin/env bash
#
# PortableMIR split-C cross-unit symbol metadata verifier.

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
        echo "error: PortableMIR cross-unit symbol missing evidence: $description" >&2
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
    MirCrossUnitSymbol \
    MIR_CROSS_UNIT_SYMBOL_EXPORT \
    MIR_CROSS_UNIT_SYMBOL_IMPORT \
    MIR_CROSS_UNIT_SYMBOL_REF \
    MIR_CROSS_UNIT_OWNER_FUNCTION \
    MIR_CROSS_UNIT_OWNER_GLOBAL \
    portable_mir_append_cross_unit_symbol; do
    require_pattern "$MIR_FILE" "$symbol" "MIR cross-unit symbol $symbol"
done

require_pattern "$VERIFIER_FILE" 'portable_mir_verify_cross_unit_symbols' \
    "verifier validates cross-unit symbols"
require_pattern "$WHITEPAPER_FILE" 'cross-unit symbol/export/import/ref metadata' \
    "whitepaper records cross-unit symbol metadata"
require_pattern "$TODO_FILE" 'split-C 多 unit 所需的 cross-unit symbol/export/import/ref metadata' \
    "todo records cross-unit symbol metadata leaf"

echo "OK: PortableMIR cross-unit symbol metadata verified"
