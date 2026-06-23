#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for return/local/binary/branch/loop.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

bash "$REPO_ROOT/tests/verify_mir_c99_statement_cfg_shard_cli_harness.sh"
bash "$REPO_ROOT/tests/verify_mir_c99_cfg_parity.sh"
bash "$REPO_ROOT/tests/verify_mir_c99_integer_value_parity.sh"

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked partial in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_status "AST_RETURN_STMT"
require_matrix_status "AST_IF_STMT"
require_matrix_status "AST_WHILE_STMT"
require_matrix_status "AST_ASSIGN"
require_matrix_status "AST_BINARY_EXPR"
require_matrix_status "CORE_STMT_KIND_RETURN"
require_matrix_status "CORE_STMT_KIND_LOCAL_DECL"
require_matrix_status "CORE_STMT_KIND_IF"
require_matrix_status "CORE_STMT_KIND_ASSIGN"
require_matrix_status "CORE_STMT_KIND_WHILE"

echo "OK: MIR-C99 full-language return/local/binary/branch/loop parity matched C99 oracle"
