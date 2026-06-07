#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEGACY_VERIFIER="$SCRIPT_DIR/verify_lowered_program_core_verifier.sh"

if [[ ! -x "$LEGACY_VERIFIER" && ! -f "$LEGACY_VERIFIER" ]]; then
    echo "error: missing CoreIR verifier implementation script: $LEGACY_VERIFIER" >&2
    exit 1
fi

bash "$LEGACY_VERIFIER"

echo "OK: CoreIR verifier gate verified"
