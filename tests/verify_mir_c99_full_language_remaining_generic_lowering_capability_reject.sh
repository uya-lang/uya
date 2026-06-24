#!/usr/bin/env bash
#
# Focused real-CLI gate for the remaining generic PortableMIR-lowering bucket.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"

if [[ ! -x "$COMPILER" ]]; then
    echo "error: fixed MIR-C99 compiler is missing or not executable: $COMPILER" >&2
    exit 69
fi

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-remaining-generic.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cases=(
    "tests/test_cfg_target.uya|mir_c99_capability_diagnostic: kind=AST_BINARY_EXPR reason=binary_expr_requires_general_expr_lowering file=(.*/)?tests/test_cfg_target\\.uya line=66"
    "tests/test_exec_vm_const_pool.uya|mir_c99_capability_diagnostic: kind=AST_BINARY_EXPR reason=binary_expr_requires_general_expr_lowering file=(.*/)?tests/test_exec_vm_const_pool\\.uya line=4"
    "tests/test_exec_vm_defer.uya|mir_c99_capability_diagnostic: kind=AST_CALL_EXPR reason=call_expr_requires_call_lowering file=(.*/)?tests/test_exec_vm_defer\\.uya line=43"
    "tests/test_exec_vm_drop_local.uya|mir_c99_capability_diagnostic: kind=AST_ASSIGN reason=assign_dest_requires_local_i32_binding file=(.*/)?tests/test_exec_vm_drop_local\\.uya line=28"
    "tests/test_exec_vm_hir_scope.uya|mir_c99_capability_diagnostic: kind=AST_CALL_EXPR reason=call_expr_requires_call_lowering file=(.*/)?tests/test_exec_vm_hir_scope\\.uya line=11"
    "tests/test_exec_vm_local_load_store.uya|mir_c99_capability_diagnostic: kind=AST_CALL_EXPR reason=call_expr_requires_call_lowering file=(.*/)?tests/test_exec_vm_local_load_store\\.uya line=8"
    "tests/test_struct_array_field_typed_empty_init.uya|mir_c99_capability_diagnostic: kind=AST_VAR_DECL reason=local_decl_requires_i32_scalar_storage file=(.*/)?tests/test_struct_array_field_typed_empty_init\\.uya line=11"
)

for entry in "${cases[@]}"; do
    src="${entry%%|*}"
    pattern="${entry#*|}"
    base="$(basename "$src" .uya)"
    log_file="$tmp_dir/$base.log"
    output_file="$tmp_dir/$base.c"

    set +e
    (
        cd "$REPO_ROOT"
        UYA_ROOT="$REPO_ROOT/lib/" "$COMPILER" build --mir-c99 "$src" -o "$output_file"
    ) >"$log_file" 2>&1
    status=$?
    set -e

    if [[ "$status" -eq 0 ]]; then
        echo "error: expected $src to fail closed under real --mir-c99" >&2
        exit 1
    fi

    grep -q '\[MIR-C99\]' "$log_file" || {
        cat "$log_file" >&2
        echo "error: missing [MIR-C99] routing evidence for $src" >&2
        exit 1
    }

    if grep -Fq '错误: MIR-C99 PortableMIR lowering 尚未覆盖当前程序' "$log_file"; then
        cat "$log_file" >&2
        echo "error: $src still falls through to the generic PortableMIR lowering failure" >&2
        exit 1
    fi

    grep -Eq "$pattern" "$log_file" || {
        cat "$log_file" >&2
        echo "error: missing explicit capability diagnostic for $src" >&2
        exit 1
    }

    if [[ -e "$output_file" && -s "$output_file" ]]; then
        cat "$log_file" >&2
        echo "error: reject left a non-empty MIR-C99 output: $output_file" >&2
        exit 1
    fi
done

echo "OK: remaining generic MIR-C99 lowering bucket now fails closed with explicit capability diagnostics"
