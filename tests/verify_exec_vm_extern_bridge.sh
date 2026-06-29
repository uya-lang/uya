#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
export UYA_ROOT="${REPO_ROOT}/lib/"

TMP_STDOUT="$(mktemp)"
TMP_STDERR="$(mktemp)"
trap 'rm -f "$TMP_STDOUT" "$TMP_STDERR"' EXIT

echo "验证 extern/libc bridge 正向路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_extern_bridge.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q 'test_exec_vm_extern_bridge.uya' "$TMP_STDOUT"
echo "  run --vm extern bridge ✓"

echo "验证 run --exec --verbose extern bridge 不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_extern_bridge.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ extern bridge run --exec --verbose unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
grep -q 'test_exec_vm_extern_bridge.uya' "$TMP_STDOUT"
echo "  run --exec --verbose extern bridge ✓"

echo "验证 direct extern mkdir/rmdir bridge 正向路径..."
"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_extern_mkdir_bridge.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
echo "  run --vm extern mkdir/rmdir bridge ✓"

echo "验证 run --exec --verbose direct extern mkdir/rmdir bridge 不发生 fallback..."
"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_extern_mkdir_bridge.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo "✗ extern mkdir/rmdir bridge run --exec --verbose unexpectedly fell back to C99"
    cat "$TMP_STDERR"
    exit 1
fi
echo "  run --exec --verbose extern mkdir/rmdir bridge ✓"

echo "验证仅有 extern 声明的 varargs 继续稳定拒绝..."
if "$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_extern_decl_varargs_unsupported.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"; then
    echo "✗ extern-decl-only varargs should remain unsupported under --vm"
    cat "$TMP_STDERR"
    exit 1
fi
grep -q 'exec unsupported 原因码: extern_abi' "$TMP_STDERR"
grep -q 'exec: 当前不支持 extern ABI' "$TMP_STDERR"
echo "  extern-decl-only varargs unsupported ✓"

echo "✓ exec vm extern bridge checks passed"
