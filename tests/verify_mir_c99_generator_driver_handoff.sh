#!/usr/bin/env bash
#
# MIR-C99 generator handoff verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DRIVER="$REPO_ROOT/src/build_compiler_driver.uya"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 generator handoff missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eiq "$pattern" "$file"; then
        echo "error: MIR-C99 generator handoff found forbidden dependency: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$BUILD_DRIVER" "$GENERATOR"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    native_build_hosted_mir_c99_preflight \
    MIR_TARGET_BACKEND_C99 \
    mir_c99_driver_run \
    MirC99Plan \
    MirC99TypePlan \
    MirC99NamePlan \
    MirC99CfgPlan \
    MirC99ValuePlan \
    MirC99PlaceMemoryPlan \
    MirC99CallPlan \
    MirC99RuntimeHelperPlan \
    MirC99Emitter \
    MirC99DriverResult; do
    require_pattern "$BUILD_DRIVER" "$symbol" "build driver MIR-C99 handoff symbol $symbol"
done

require_pattern "$BUILD_DRIVER" 'portable_mir_backend_request_init\(&request,[^;]+MIR_TARGET_BACKEND_C99' \
    "MIR-C99 handoff creates a C99 backend request"
require_pattern "$BUILD_DRIVER" 'portable_mir_backend_request_is_verified\(&request\)' \
    "MIR-C99 handoff verifies request before driver run"
require_pattern "$BUILD_DRIVER" 'native_build_hosted_mir_append_program_safe_bodies' \
    "MIR-C99 handoff consumes source-to-PortableMIR body lowering"
require_pattern "$BUILD_DRIVER" 'mir_c99_driver_run\(&request,' \
    "MIR-C99 handoff calls the independent MIR-C99 driver"
require_pattern "$BUILD_DRIVER" 'MIR_C99_DRIVER_STATUS_DONE' \
    "MIR-C99 handoff checks driver completion"
require_pattern "$BUILD_DRIVER" 'MIR_BACKEND_OUTPUT_MIR_C99_PLAN' \
    "MIR-C99 handoff records MirC99Plan output kind"
require_pattern "$GENERATOR" 'verify_mir_c99_generator_driver_handoff\.sh' \
    "default generator runs handoff verifier before reporting not-ready"
require_pattern "$GENERATOR" 'handoff_status=verified' \
    "default generator log records verified handoff"
require_pattern "$GENERATOR" 'writer_status=pending' \
    "default generator keeps C writer pending until output leaf"

reject_pattern "$GENERATOR" 'C99CodeGenerator|c99_codegen_generate|codegen/c99|legacy C99' \
    "default MIR-C99 generator must not invoke legacy C99 backend"

echo "OK: MIR-C99 generator reaches source-to-PortableMIR and mir_c99_driver_run handoff"
