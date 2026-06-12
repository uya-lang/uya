#!/usr/bin/env bash
#
# MIR-C99 self-build preflight for the build-only compiler root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CMD_BUILD_SOURCE="$REPO_ROOT/src/cmd/build/main.uya"
BUILD_DRIVER="$REPO_ROOT/src/build_compiler_driver.uya"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"
TMP_DIR="$(mktemp -d /tmp/uya-mir-c99-cmd-build-preflight.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing cmd/build MIR-C99 self-build evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

if [[ ! -f "$CMD_BUILD_SOURCE" ]]; then
    echo "error: missing cmd/build self-build root: $CMD_BUILD_SOURCE" >&2
    exit 1
fi

require_pattern "$CMD_BUILD_SOURCE" '^use build_compiler_driver;' \
    "cmd/build root imports build-only compiler driver"
require_pattern "$CMD_BUILD_SOURCE" 'export[[:space:]]+fn[[:space:]]+main\(\)[[:space:]]+i32' \
    "cmd/build root exports process main"
require_pattern "$CMD_BUILD_SOURCE" 'return[[:space:]]+build_compiler_driver_main\(\);' \
    "cmd/build root delegates to build_compiler_driver_main"
require_pattern "$BUILD_DRIVER" 'fn[[:space:]]+native_build_hosted_mir_c99_preflight' \
    "build driver exposes hosted MIR-C99 preflight"
require_pattern "$BUILD_DRIVER" 'native_build_hosted_mir_append_program_safe_bodies' \
    "MIR-C99 preflight consumes source-to-PortableMIR body lowering"
require_pattern "$BUILD_DRIVER" 'portable_mir_backend_request_init\(&request,[^;]+MIR_TARGET_BACKEND_C99' \
    "MIR-C99 preflight creates a C99 backend request"
require_pattern "$BUILD_DRIVER" 'mir_c99_driver_run\(&request,' \
    "MIR-C99 preflight reaches MirC99Plan driver"
require_pattern "$BUILD_DRIVER" 'MIR_BACKEND_OUTPUT_MIR_C99_PLAN' \
    "MIR-C99 preflight records MirC99Plan output kind"

stdout_file="$TMP_DIR/generator.out"
stderr_file="$TMP_DIR/generator.err"
output_c="$TMP_DIR/cmd-build-mir.c"
log_file="$TMP_DIR/cmd-build-mir.log"

set +e
"$GENERATOR" "$CMD_BUILD_SOURCE" "$output_c" "$log_file" >"$stdout_file" 2>"$stderr_file"
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
    echo "error: cmd/build MIR-C99 self-build should still stop before minimal C99 output" >&2
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    exit 1
fi
if [[ -s "$output_c" ]]; then
    echo "error: cmd/build MIR-C99 preflight must not leave C output before writer leaf" >&2
    ls -l "$output_c" >&2
    exit 1
fi
if [[ ! -f "$log_file" ]]; then
    echo "error: cmd/build MIR-C99 preflight did not write a diagnostic log" >&2
    exit 1
fi
require_pattern "$log_file" 'handoff_status=verified' \
    "default generator verified source-to-PortableMIR/MirC99Plan handoff"
require_pattern "$log_file" 'writer_status=pending' \
    "default generator remains fail-closed for cmd/build C output"
require_pattern "$log_file" 'status=not-ready' \
    "default generator reports not-ready instead of success"
require_pattern "$log_file" 'input=.*/src/cmd/build/main\.uya' \
    "diagnostic log records cmd/build source root"

if grep -Eiq 'fallback|legacy C99|codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator' \
    "$log_file" "$stdout_file" "$stderr_file"; then
    echo "error: cmd/build MIR-C99 preflight mentioned legacy C99 fallback" >&2
    cat "$log_file" >&2
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    exit 1
fi

echo "OK: cmd/build MIR-C99 self-build root reaches fail-closed preflight"
