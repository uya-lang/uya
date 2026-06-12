#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for float/double values and call ABI.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

bash "$REPO_ROOT/tests/verify_mir_c99_float_value_parity.sh"
bash "$REPO_ROOT/tests/verify_mir_c99_float_call_parity.sh"

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked partial in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_status "AST_FLOAT"
require_matrix_status "AST_CAST_EXPR"
require_matrix_status "AST_CALL_EXPR"
require_matrix_status "CORE_EXPR_KIND_CALL"

echo "OK: MIR-C99 full-language float/double value and call ABI parity matched C99 oracle"
