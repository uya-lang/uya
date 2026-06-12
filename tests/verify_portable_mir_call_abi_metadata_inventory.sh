#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: PortableMIR call ABI metadata 缺少证据: $description" >&2
        echo "文件: $file" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$MIR_VERIFIER_FILE" "$PORTABLE_MIR_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_ABI_CLASS_VOID \
    MIR_ABI_CLASS_INTEGER \
    MIR_ABI_CLASS_POINTER \
    MIR_ABI_CLASS_AGGREGATE \
    MIR_ABI_CLASS_FUNCTION \
    MIR_ABI_CLASS_FLOAT \
    MIR_ABI_CLASS_DOUBLE \
    MIR_ABI_CLASS_ERROR_UNION \
    MIR_ABI_CLASS_OUT_PARAM_POINTER; do
    require_pattern "$MIR_FILE" "$symbol" "ABI class 常量 $symbol"
done

for symbol in \
    MIR_CALL_FLAG_MULTI_PARAM \
    MIR_CALL_FLAG_AGGREGATE_RETURN \
    MIR_CALL_FLAG_OUT_PARAM_WRITEBACK \
    MIR_CALL_FLAG_ERROR_UNION_RETURN \
    MIR_CALL_FLAG_FLOAT_ABI; do
    require_pattern "$MIR_FILE" "$symbol" "call ABI flag $symbol"
done

require_pattern "$MIR_FILE" 'portable_mir_abi_class_for_type_kind' "type kind 到 ABI class helper"
require_pattern "$MIR_FILE" 'portable_mir_call_flag_for_return_type' "return type 到 call ABI flag helper"
require_pattern "$MIR_FILE" 'portable_mir_call_flag_for_param_count' "multi-param call flag helper"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_call_abi_metadata' "verifier call ABI metadata hook"
require_pattern "$MIR_VERIFIER_FILE" 'MIR_CALL_FLAG_OUT_PARAM_WRITEBACK' "verifier checks out-param writeback flag"
require_pattern "$MIR_VERIFIER_FILE" 'MIR_ABI_CLASS_FLOAT' "verifier accepts explicit f32 ABI class"
require_pattern "$MIR_VERIFIER_FILE" 'MIR_ABI_CLASS_DOUBLE' "verifier accepts explicit f64 ABI class"
require_pattern "$PORTABLE_MIR_DOC" 'aggregate return / out-param writeback / error union return / float ABI' "whitepaper documents call ABI metadata split"

echo "PortableMIR call ABI metadata inventory ok"
