#!/usr/bin/env bash
#
# Full-language MIR-C99 parity shard for defer normal-scope and return order.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

bash "$REPO_ROOT/tests/verify_mir_c99_defer_local_assign_parity.sh" >/dev/null

require_matrix_status() {
    local kind="$1"
    if ! grep -Eq "\\| \`$kind\` \\| [^|]+ \\| partial \\|" "$MATRIX_DOC"; then
        echo "error: $kind must be marked partial in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_note() {
    local kind="$1"
    local needle="$2"
    if ! grep -E "\\| \`$kind\` \\|" "$MATRIX_DOC" | grep -Fq "$needle"; then
        echo "error: $kind must record $needle in the MIR-C99 coverage matrix" >&2
        exit 1
    fi
}

require_matrix_status "CORE_STMT_KIND_DEFER"
require_matrix_note "CORE_STMT_KIND_DEFER" "defer normal-scope return-order parity shard"

echo "OK: MIR-C99 full-language defer parity matched C99 oracle"
