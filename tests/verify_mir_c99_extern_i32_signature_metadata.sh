#!/usr/bin/env bash
#
# Focused gate for real extern-signature metadata lowering under MIR-C99.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DRIVER="$REPO_ROOT/src/build_compiler_driver.uya"
FIXED_UYA="$REPO_ROOT/../uya/bin/uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 extern signature metadata missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

fail() {
    echo "error: $*" >&2
    exit 1
}

if [[ ! -f "$BUILD_DRIVER" ]]; then
    fail "missing source: $BUILD_DRIVER"
fi

require_pattern "$BUILD_DRIVER" 'fn native_build_hosted_mir_append_extern_signature_type\(' \
    "extern signature helper exists"
require_pattern "$BUILD_DRIVER" 'native_build_extern_signature_type_supported\(decl\.fn_decl_return_type\) == 0' \
    "extern signature helper validates return type support"
require_pattern "$BUILD_DRIVER" 'decl\.fn_decl_param_count > 0 && decl\.fn_decl_params == null' \
    "extern signature helper rejects missing param arrays"
require_pattern "$BUILD_DRIVER" 'decl\.fn_decl_params\[i\]' \
    "extern signature helper iterates declared params"
require_pattern "$BUILD_DRIVER" 'param == null \|\| param\.type != ASTNodeType\.AST_VAR_DECL' \
    "extern signature helper validates param node kind"
require_pattern "$BUILD_DRIVER" 'native_build_extern_signature_type_supported\(param\.var_decl_type\) == 0' \
    "extern signature helper validates param type support"
require_pattern "$BUILD_DRIVER" 'native_build_hosted_mir_append_extern_signature_ast_type\(module,' \
    "extern signature helper lowers AST types into MIR types"
require_pattern "$BUILD_DRIVER" 'module\.function_param_type_count as i32' \
    "extern signature helper captures param metadata start"
require_pattern "$BUILD_DRIVER" 'native_build_hosted_mir_append_function_param_type\(module,' \
    "extern signature helper appends function param metadata"
require_pattern "$BUILD_DRIVER" 'native_build_hosted_mir_function_signature_type\(' \
    "extern signature helper materializes function signature type"
require_pattern "$BUILD_DRIVER" 'param_start,[[:space:]]*decl\.fn_decl_param_count\)' \
    "extern signature helper records declared param count in signature"
require_pattern "$BUILD_DRIVER" 'native_build_hosted_mir_append_extern_signature_type\(module, decl,' \
    "extern function lowering uses real extern signature helper"
require_pattern "$BUILD_DRIVER" 'signature_type_id: signature_type_id' \
    "extern function stores lowered signature type"

extern_body="$(sed -n '/^fn native_build_hosted_mir_append_extern_function(/,/^}/p' "$BUILD_DRIVER")"
if printf '%s\n' "$extern_body" | grep -Eq 'native_build_hosted_mir_ensure_signature_type\('; then
    fail "extern function lowering still uses the zero-param placeholder signature helper"
fi

if [[ ! -x "$FIXED_UYA" ]]; then
    fail "missing fixed compiler path ../uya/bin/uya"
fi

bash "$REPO_ROOT/tests/verify_portable_mir_call_abi_metadata_inventory.sh" >/dev/null
bash "$REPO_ROOT/tests/verify_mir_c99_type_function_signature.sh" >/dev/null

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-extern-signature.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

build_case() {
    local case_file="$1"
    local case_name
    case_name="$(basename "$case_file" .uya)"
    local case_log="$tmp_dir/${case_name}.log"
    local case_out="$tmp_dir/${case_name}.c"

    set +e
    (
        cd "$REPO_ROOT"
        UYA_ROOT="$REPO_ROOT/lib/" "$FIXED_UYA" build --mir-c99 "$case_file" -o "$case_out"
    ) >"$case_log" 2>&1
    local status=$?
    set -e

    if [[ "$status" -eq 0 ]]; then
        cat "$case_log" >&2
        fail "$case_file should still fail closed at the post-extern-signature frontier"
    fi
    grep -Fq '[MIR-C99]' "$case_log" || {
        cat "$case_log" >&2
        fail "$case_file log is missing [MIR-C99] routing evidence"
    }
    if grep -Fq 'extern_signature_requires_i32_scalars' "$case_log"; then
        cat "$case_log" >&2
        fail "$case_file regressed to extern_signature_requires_i32_scalars"
    fi
    if grep -Fq '错误: MIR-C99 extern lowering 失败' "$case_log"; then
        cat "$case_log" >&2
        fail "$case_file regressed to the generic extern lowering failure"
    fi
    grep -Fq '错误: MIR-C99 PortableMIR verifier 失败: code=16' "$case_log" || {
        cat "$case_log" >&2
        fail "$case_file did not reach the current verifier-clean frontier"
    }
    if [[ -e "$case_out" && -s "$case_out" ]]; then
        cat "$case_log" >&2
        fail "$case_file reject left a non-empty MIR-C99 output: $case_out"
    fi
}

build_case "tests/test_ffi_cast.uya"
build_case "tests/extern_ffi_no_struct.uya"

echo "OK: MIR-C99 extern signature metadata lowering now reaches the verifier frontier"
