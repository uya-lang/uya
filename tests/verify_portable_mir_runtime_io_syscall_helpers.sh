#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_CONTRACT_FILE="$REPO_ROOT/src/lower/mir_contract.uya"
MIR_VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: PortableMIR runtime IO/syscall helper 缺少证据: $description" >&2
        echo "文件: $file" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$MIR_CONTRACT_FILE" "$MIR_VERIFIER_FILE" "$PORTABLE_MIR_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_RUNTIME_CAP_PRINT_HELPERS \
    MIR_RUNTIME_CAP_HEAP_HELPERS \
    MIR_RUNTIME_CAP_ENV_FILE_IO \
    MIR_RUNTIME_CAP_SYSCALL \
    MIR_RUNTIME_HELPER_PRINT \
    MIR_RUNTIME_HELPER_PRINTLN \
    MIR_RUNTIME_HELPER_MALLOC \
    MIR_RUNTIME_HELPER_FREE \
    MIR_RUNTIME_HELPER_ENV \
    MIR_RUNTIME_HELPER_FILE_IO \
    MIR_RUNTIME_HELPER_SYSCALL; do
    require_pattern "$MIR_CONTRACT_FILE" "$symbol" "runtime helper/capability symbol $symbol"
done

for symbol in \
    MIR_RUNTIME_CAP_PRINT_HELPERS \
    MIR_RUNTIME_CAP_HEAP_HELPERS \
    MIR_RUNTIME_CAP_ENV_FILE_IO; do
    require_pattern "$MIR_FILE" "$symbol" "hosted profile includes $symbol"
done
require_pattern "$MIR_FILE" 'MIR_PROFILE_RUNTIME_CAP_FREESTANDING_NATIVE' \
    "freestanding profile runtime capability mask"
require_pattern "$MIR_FILE" 'MIR_RUNTIME_CAP_SYSCALL' \
    "freestanding profile includes syscall capability"

for symbol in \
    MIR_RUNTIME_HELPER_PRINT \
    MIR_RUNTIME_HELPER_PRINTLN \
    MIR_RUNTIME_HELPER_MALLOC \
    MIR_RUNTIME_HELPER_FREE \
    MIR_RUNTIME_HELPER_ENV \
    MIR_RUNTIME_HELPER_FILE_IO \
    MIR_RUNTIME_HELPER_SYSCALL; do
    require_pattern "$MIR_VERIFIER_FILE" "$symbol" "verifier recognizes helper $symbol"
done

require_pattern "$PORTABLE_MIR_DOC" 'print/println / malloc/free / env/file IO / syscall helper refs' \
    "whitepaper documents IO/syscall helper refs"

echo "PortableMIR runtime IO/syscall helper inventory ok"
