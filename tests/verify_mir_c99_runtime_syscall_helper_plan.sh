#!/usr/bin/env bash
#
# MIR-C99 syscall runtime helper plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_FILE="$REPO_ROOT/src/codegen/mir_c99/runtime_helpers.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
ABI_PROFILE_TEST="$REPO_ROOT/tests/verify_portable_mir_call_abi_profile.sh"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 syscall runtime helper plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$HELPER_FILE" "$DRIVER_FILE" "$MIR_FILE" "$VERIFIER_FILE" "$ABI_PROFILE_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_RUNTIME_HELPER_SYSCALL \
    MIR_RUNTIME_CAP_SYSCALL \
    mir_c99_runtime_helper_is_syscall \
    mir_c99_runtime_helper_plan_build; do
    require_pattern "$HELPER_FILE" "$symbol" "syscall helper symbol $symbol"
done

require_pattern "$HELPER_FILE" 'module\.capability_reqs\.count' \
    "syscall helper plan scans MIR capability requirements"
require_pattern "$HELPER_FILE" 'MIR_RUNTIME_HELPER_SYSCALL' \
    "syscall helper id accepted"
require_pattern "$HELPER_FILE" 'portable_mir_target_profile_supports_runtime_capability' \
    "syscall helper checks target runtime capability"
require_pattern "$HELPER_FILE" 'mir_c99_plan_append_ref\(mir_plan,[[:space:]]*MIR_C99_REF_KIND_HELPER' \
    "syscall helper refs appended to program plan"
require_pattern "$HELPER_FILE" 'mir_c99_unit_append_ref\(unit,[[:space:]]*MIR_C99_REF_KIND_HELPER' \
    "syscall helper refs appended to unit plan"
require_pattern "$DRIVER_FILE" 'mir_c99_runtime_helper_plan_build' \
    "driver builds runtime helper plan"
require_pattern "$MIR_FILE" 'MIR_RUNTIME_CAP_SYSCALL' \
    "PortableMIR exposes syscall capability"
require_pattern "$VERIFIER_FILE" 'MIR_RUNTIME_HELPER_SYSCALL' \
    "PortableMIR verifier recognizes syscall helper"
require_pattern "$ABI_PROFILE_TEST" 'portable_mir_target_profile_supports_runtime_capability\(&hosted, MIR_RUNTIME_CAP_SYSCALL\), 0' \
    "hosted target does not silently accept syscall capability"
require_pattern "$ABI_PROFILE_TEST" 'portable_mir_target_profile_supports_runtime_capability\(&free, MIR_RUNTIME_CAP_SYSCALL\), 1' \
    "freestanding target explicitly accepts syscall capability"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$HELPER_FILE"; then
    echo "error: MIR-C99 runtime helpers must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_runtime_syscall_helper_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/cfg.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/values.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/place_memory.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/calls.uya" \
    "$HELPER_FILE" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 syscall runtime helper plan verified"
