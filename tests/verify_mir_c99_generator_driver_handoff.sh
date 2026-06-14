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
    "default generator runs handoff verifier before reporting output"
require_pattern "$GENERATOR" 'handoff_status=verified' \
    "default generator log records verified handoff"

reject_pattern "$GENERATOR" 'C99CodeGenerator|c99_codegen_generate|codegen/c99|legacy C99' \
    "default MIR-C99 generator must not invoke legacy C99 backend"

# The cmd/build root must now produce a real candidate with writer_status=done.
tmp_dir="$(mktemp -d /tmp/uya-mir-c99-generator-handoff.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
cmd_build_log="$tmp_dir/cmd_build.log"
cmd_build_c="$tmp_dir/cmd_build.c"
MIR_C99_SKIP_HANDOFF_VERIFY=1 \
    "$GENERATOR" "$REPO_ROOT/src/cmd/build/main.uya" "$cmd_build_c" "$cmd_build_log" >/dev/null
if ! grep -Eq '^writer_status=done$' "$cmd_build_log"; then
    echo "error: default generator should report writer_status=done for cmd/build root" >&2
    cat "$cmd_build_log" >&2
    exit 1
fi
if [[ ! -s "$cmd_build_c" ]]; then
    echo "error: default generator should leave real C output for cmd/build root" >&2
    exit 1
fi

# Unsupported inputs must still fail closed with writer_status=pending and no C output.
unsupported_log="$tmp_dir/unsupported.log"
unsupported_c="$tmp_dir/unsupported.c"
set +e
printf 'fn helper() i32 { return 1; }\nexport fn main() i32 { return helper(); }\n' >"$tmp_dir/unsupported.uya"
MIR_C99_SKIP_HANDOFF_VERIFY=1 \
    "$GENERATOR" "$tmp_dir/unsupported.uya" "$unsupported_c" "$unsupported_log" >/dev/null 2>&1
unsupported_status=$?
set -e
if [[ "$unsupported_status" -eq 0 ]]; then
    echo "error: default generator should fail closed on unsupported input" >&2
    exit 1
fi
if [[ -s "$unsupported_c" ]]; then
    echo "error: default generator should not leave C output on unsupported input" >&2
    exit 1
fi
if ! grep -Eq '^writer_status=pending$' "$unsupported_log"; then
    echo "error: default generator should report writer_status=pending on unsupported input" >&2
    cat "$unsupported_log" >&2
    exit 1
fi

echo "OK: MIR-C99 generator reaches source-to-PortableMIR and mir_c99_driver_run handoff"
