#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for struct literals, field access, and
# method-style aggregate calls.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

bash "$REPO_ROOT/tests/verify_mir_c99_place_memory_parity.sh"
bash "$REPO_ROOT/tests/verify_mir_c99_call_parity.sh"

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked partial in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_status "AST_STRUCT_DECL"
require_matrix_status "AST_METHOD_BLOCK"
require_matrix_status "AST_CALL_EXPR"
require_matrix_status "AST_MEMBER_ACCESS"
require_matrix_status "AST_STRUCT_INIT"
require_matrix_status "CORE_EXPR_KIND_CALL"
require_matrix_status "CORE_PLACE_KIND_FIELD"

echo "OK: MIR-C99 full-language struct parity matched C99 oracle"
