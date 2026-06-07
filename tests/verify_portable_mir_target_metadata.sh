#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_CONTRACT_FILE="$REPO_ROOT/src/lower/mir_contract.uya"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR target metadata missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$MIR_CONTRACT_FILE" "$PORTABLE_MIR_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

for constant in \
    MIR_ADDRESS_SPACE_GLOBAL \
    MIR_ADDRESS_SPACE_SHARED \
    MIR_ADDRESS_SPACE_LOCAL \
    MIR_ADDRESS_SPACE_CONSTANT \
    MIR_ADDRESS_SPACE_DEVICE \
    MIR_CALL_CONV_UYA \
    MIR_CALL_CONV_C \
    MIR_CALL_CONV_SYSCALL \
    MIR_CALL_CONV_RUNTIME_HELPER \
    MIR_CALL_CONV_TARGET_INTRINSIC \
    MIR_RUNTIME_CAP_HOSTED_LIBC \
    MIR_RUNTIME_CAP_FREESTANDING \
    MIR_RUNTIME_CAP_C_EXTERN \
    MIR_ABI_CLASS_DIRECT \
    MIR_ABI_CLASS_MEMORY \
    MIR_MASK_REPR_BITSET; do
    require_pattern "$MIR_CONTRACT_FILE" "export const ${constant}" "constant $constant"
done

require_pattern "$MIR_FILE" 'supported_address_spaces:[[:space:]]*i32' "target profile address-space mask"
require_pattern "$MIR_FILE" 'supported_calling_conventions:[[:space:]]*i32' "target profile calling convention mask"
require_pattern "$MIR_FILE" 'runtime_capability_mask:[[:space:]]*i32' "runtime capability mask"
require_pattern "$MIR_FILE" 'layout_id:[[:space:]]*i32' "MirType target-neutral layout ID"
require_pattern "$MIR_FILE" 'tag_offset_bytes:[[:space:]]*usize' "MirType tag offset metadata"
require_pattern "$MIR_FILE" 'payload_offset_bytes:[[:space:]]*usize' "MirType payload offset metadata"
require_pattern "$MIR_FILE" 'atomic_align_bytes:[[:space:]]*usize' "MirType atomic alignment metadata"
require_pattern "$MIR_FILE" 'lane_stride_bytes:[[:space:]]*usize' "MirType vector lane stride metadata"
require_pattern "$MIR_FILE" 'mask_representation:[[:space:]]*i32' "MirType mask representation metadata"
require_pattern "$MIR_FILE" 'abi_class:[[:space:]]*i32' "MirType ABI class metadata"
require_pattern "$MIR_FILE" 'calling_convention:[[:space:]]*i32' "function/instruction calling convention"
require_pattern "$MIR_FILE" 'required_address_space_mask:[[:space:]]*i32' "function address-space requirement mask"
require_pattern "$PORTABLE_MIR_DOC" 'target-neutral layout metadata' "whitepaper target-neutral layout metadata"
require_pattern "$PORTABLE_MIR_DOC" 'calling convention' "whitepaper calling convention requirement"
require_pattern "$PORTABLE_MIR_DOC" 'hosted/freestanding runtime capability' "whitepaper runtime capability requirement"
require_pattern "$PORTABLE_MIR_DOC" 'address space' "whitepaper address-space requirement"

bash "$REPO_ROOT/tests/verify_portable_mir_structs.sh"

echo "OK: PortableMIR target metadata contract verified"
