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
        echo "错误: PortableMIR runtime memory helper 缺少证据: $description" >&2
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
    MIR_RUNTIME_CAP_MEMORY_HELPERS \
    MIR_RUNTIME_CAP_STRING_PRIMITIVES \
    MIR_RUNTIME_HELPER_MEMCPY \
    MIR_RUNTIME_HELPER_MEMSET \
    MIR_RUNTIME_HELPER_MEMCMP \
    MIR_RUNTIME_HELPER_STRING_PRIMITIVE; do
    require_pattern "$MIR_CONTRACT_FILE" "$symbol" "runtime helper/capability symbol $symbol"
done

require_pattern "$MIR_FILE" 'MIR_PROFILE_RUNTIME_CAP_HOSTED_NATIVE' \
    "hosted profile runtime capability mask"
require_pattern "$MIR_FILE" 'MIR_RUNTIME_CAP_MEMORY_HELPERS' \
    "hosted profile includes memory helper capability"
require_pattern "$MIR_FILE" 'MIR_RUNTIME_CAP_STRING_PRIMITIVES' \
    "hosted profile includes string primitive capability"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_runtime_helper_capability_id' \
    "verifier validates runtime helper capability ids"
require_pattern "$MIR_VERIFIER_FILE" 'MIR_RUNTIME_HELPER_MEMCPY' \
    "verifier recognizes memcpy helper"
require_pattern "$MIR_VERIFIER_FILE" 'MIR_RUNTIME_HELPER_MEMSET' \
    "verifier recognizes memset helper"
require_pattern "$MIR_VERIFIER_FILE" 'MIR_RUNTIME_HELPER_MEMCMP' \
    "verifier recognizes memcmp helper"
require_pattern "$PORTABLE_MIR_DOC" 'memcpy / memset / memcmp / string primitive helper refs' \
    "whitepaper documents memory/string helper refs"

echo "PortableMIR runtime memory helper inventory ok"
