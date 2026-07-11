#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_COMPILER:-$REPO_ROOT/bin/uya}"
TMP_STDOUT="$(mktemp)"
TMP_STDERR="$(mktemp)"
trap 'rm -f "$TMP_STDOUT" "$TMP_STDERR"' EXIT

"$COMPILER" run --vm "$SCRIPT_DIR/test_exec_vm_opaque_struct.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
grep -q '^1$' "$TMP_STDOUT"

"$COMPILER" run --exec --verbose "$SCRIPT_DIR/test_exec_vm_opaque_struct.uya" >"$TMP_STDOUT" 2>"$TMP_STDERR"
if grep -q '回退 C99' "$TMP_STDERR"; then
    echo 'opaque struct unexpectedly fell back from exec backend' >&2
    cat "$TMP_STDERR" >&2
    exit 1
fi
grep -q '^1$' "$TMP_STDOUT"

echo 'exec vm opaque struct verification passed'
