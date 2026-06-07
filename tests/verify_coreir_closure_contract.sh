#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_check() {
    local script="$1"
    if [[ ! -x "$script" && ! -f "$script" ]]; then
        echo "error: missing CoreIR closure gate: $script" >&2
        exit 1
    fi
    bash "$script"
}

run_check "$SCRIPT_DIR/verify_coreir_dump_env.sh"
run_check "$SCRIPT_DIR/verify_coreir_dump_golden.sh"
run_check "$SCRIPT_DIR/verify_coreir_verifier.sh"
run_check "$SCRIPT_DIR/verify_coreir_capability_boundary_contract.sh"
run_check "$SCRIPT_DIR/verify_coreir_naked_fn_contract.sh"
run_check "$SCRIPT_DIR/verify_coreir_parallel_boundary_contract.sh"
run_check "$SCRIPT_DIR/verify_coreir_c99_oracle_boundary.sh"

echo "OK: CoreIR closure contract verified"
