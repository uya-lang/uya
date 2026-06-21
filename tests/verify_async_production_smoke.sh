#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"
export UYA_ROOT="${UYA_ROOT:-$REPO_ROOT/lib/}"

if [ ! -x "$COMPILER" ]; then
    echo "missing compiler: $COMPILER"
    echo "hint: run 'make uya' first"
    exit 1
fi

run_step() {
    local label="$1"
    shift

    echo "==> $label"
    "$@"
}

run_step "async full-language and boundary matrix" \
    bash "$SCRIPT_DIR/verify_async_full_language_matrix.sh"

run_step "shared runtime semantic matrix" \
    bash "$SCRIPT_DIR/verify_async_shared_runtime_matrix.sh"

run_step "nested future boundary matrix" \
    bash "$SCRIPT_DIR/verify_async_nested_future_boundary.sh"

run_step "async cancel cleanup smoke" \
    bash "$SCRIPT_DIR/verify_async_cancel_cleanup.sh"

echo "verify_async_production_smoke: full-language, shared runtime, nested future, and cancel cleanup smoke matrix passed"
