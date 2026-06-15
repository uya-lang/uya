#!/usr/bin/env bash
# Verify make check/check-hosted wire MIR-C99 release gates with staged toggle semantics.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MAKEFILE="$REPO_ROOT/Makefile"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing MIR-C99 release gate evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

require_pattern "$MAKEFILE" 'UYA_MIR_C99_RELEASE_GATE' \
    'Makefile defines MIR-C99 release gate stage variable'
require_pattern "$MAKEFILE" 'UYA_MIR_C99_RELEASE_GATE=off' \
    'Makefile documents default disabled MIR-C99 release gate stage'
require_pattern "$MAKEFILE" 'UYA_MIR_C99_RELEASE_GATE=optional' \
    'Makefile documents optional MIR-C99 release gate stage'
require_pattern "$MAKEFILE" 'UYA_MIR_C99_RELEASE_GATE=required' \
    'Makefile documents required MIR-C99 release gate stage'
require_pattern "$MAKEFILE" 'verify_mir_c99_self_build_convergence_audit\.sh' \
    'Makefile wires convergence audit gate into check flow'
require_pattern "$MAKEFILE" 'verify_mir_c99_cmd_build_host_binary_attempt_gate\.sh' \
    'Makefile wires host compiler candidate gate into check flow'
require_pattern "$MAKEFILE" '跳过 MIR-C99 release gate（设 UYA_MIR_C99_RELEASE_GATE=optional 或 required 启用；默认 UYA_MIR_C99_RELEASE_GATE=off）' \
    'Makefile explains disabled release gate stage'
require_pattern "$MAKEFILE" '执行 MIR-C99 release gate（optional）\.\.\.' \
    'Makefile exposes optional release gate stage message'
require_pattern "$MAKEFILE" '执行 MIR-C99 release gate（required）\.\.\.' \
    'Makefile exposes required release gate stage message'
require_pattern "$MAKEFILE" 'UYA_MIR_C99_RELEASE_GATE=.*make check' \
    'make check success summary mentions MIR-C99 release gate stage'
require_pattern "$MAKEFILE" 'UYA_MIR_C99_RELEASE_GATE=.*make check-hosted' \
    'make check-hosted success summary mentions MIR-C99 release gate stage'
require_pattern "$TODO_FILE" 'make check` / `make check-hosted` 增加 MIR-C99 可选或必选门禁，按阶段切换' \
    'todo keeps current release gate leaf wording'

echo 'OK: MIR-C99 release gate contract is wired for off/optional/required stages'
