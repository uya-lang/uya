#!/usr/bin/env bash

# Phase 9B / L994.D: NativeMirEmitter lowers hosted print helper calls
# to SysV x86_64 extern-call machine IR.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_EMITTER_FILE="$REPO_ROOT/src/codegen/native/mir_emitter.uya"
MACHINE_FILE="$REPO_ROOT/src/codegen/native/machine.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing native print emitter evidence: $description" >&2
        exit 1
    fi
}

require_pattern "$MIR_EMITTER_FILE" 'native_mir_emitter_import_print_helper_call' \
    "print helper call lowering hook"
require_pattern "$MIR_EMITTER_FILE" 'MIR_EXTERN_HOSTED_HELPER_UYA_WRITE_STR' \
    "uya_write_str helper dispatch"
require_pattern "$MIR_EMITTER_FILE" 'native_abi_sysv_gpr_arg_reg\(arg_index\)' \
    "SysV GPR argument mapper"
require_pattern "$MIR_EMITTER_FILE" 'X86_64_OP_CALL_REL32' \
    "x86_64 direct extern call opcode"
require_pattern "$MIR_EMITTER_FILE" 'machine_module_add_reloc' \
    "PC32 call relocation registration"
require_pattern "$MACHINE_FILE" 'MACHINE_RELOC_KIND_X86_64_PC32' \
    "machine reloc kind for x86_64 extern call"

bash "$REPO_ROOT/tests/verify_native_mir_emitter.sh"

echo "OK: hosted native print helper call lowers to SysV x86_64 MachineModule call"
