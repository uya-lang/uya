#!/usr/bin/env bash

# Phase 9B / L994.C: print helper MIR verifier ABI gate.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"

require_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$MIR_VERIFIER_FILE"; then
        echo "error: missing print MIR verifier ABI evidence: $description" >&2
        exit 1
    fi
}

require_pattern 'portable_mir_verify_print_helper_call_abi' "print helper ABI verifier hook"
require_pattern 'MIR_EXTERN_HOSTED_HELPER_UYA_WRITE_STR' "uya_write_str helper id"
require_pattern 'MIR_EXTERN_HOSTED_HELPER_UYA_WRITE_NEWLINE' "uya_write_newline helper id"
require_pattern 'MIR_TYPE_KIND_POINTER' "pointer-sized string operand check"
require_pattern 'MIR_CALL_CONV_C' "C ABI calling convention check"

"$REPO_ROOT/tests/verify_hosted_native_print_mir_body.sh"

echo "OK: hosted native print helper MIR verifier ABI gate present"
