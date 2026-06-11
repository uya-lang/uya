#!/usr/bin/env bash

# Phase 9B / L994.B.2: verify @println(string) materializes a CoreIR body
# with write_str + write_newline call nodes before later MIR/native gates.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-hosted-native-print-coreir.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "SKIP: hosted native print CoreIR body test currently requires x86_64 host" >&2
    exit 0
fi

UYA_BIN="$REPO_ROOT/bin/uya"
if [[ ! -x "$UYA_BIN" ]]; then
    echo "error: missing or non-executable bin/uya; run \`make uya\` first" >&2
    exit 1
fi

HW_SRC="$TMP_DIR/hw.uya"
cat >"$HW_SRC" <<'EOF'
export fn main() i32 {
    @println("Hello, World!");
    return 0;
}
EOF

HW_NATIVE_BIN="$TMP_DIR/hw.native"
HW_NATIVE_ERR="$TMP_DIR/hw.native.build.err"
set +e
(cd "$REPO_ROOT" && "$UYA_BIN" build "$HW_SRC" -o "$HW_NATIVE_BIN" \
    --native --no-split-c --project-root "$TMP_DIR" \
    >"$TMP_DIR/hw.native.build.out" 2>"$HW_NATIVE_ERR")
HW_NATIVE_STATUS=$?
set -e

if ! grep -q 'native_hosted_print_hir_pattern: declared' "$HW_NATIVE_ERR"; then
    echo "error: print HIR pattern was not recognized before CoreIR body emission" >&2
    cat "$HW_NATIVE_ERR" >&2
    exit 1
fi

if ! grep -q 'native_hosted_print_coreir_body: calls=2 write_str=1 newline=1' "$HW_NATIVE_ERR"; then
    echo "error: print CoreIR body did not emit write_str + write_newline calls" >&2
    cat "$HW_NATIVE_ERR" >&2
    exit 1
fi

if [[ "$HW_NATIVE_STATUS" -eq 0 ]]; then
    echo "OK: hosted native print CoreIR body emitted write_str + write_newline calls"
else
    echo "OK: hosted native print CoreIR body emitted write_str + write_newline calls before later MIR/native rejection"
fi
