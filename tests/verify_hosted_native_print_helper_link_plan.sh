#!/usr/bin/env bash

# Phase 9B / L994.E: hosted native link plan pulls in the print helper
# runtime object when PortableMIR contains uya_write* helper calls.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-hosted-native-print-link.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOSTED_LINK_FILE="$REPO_ROOT/src/codegen/native/hosted_link.uya"
BUILD_DRIVER_FILE="$REPO_ROOT/src/build_compiler_driver.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing print helper link-plan evidence: $description" >&2
        exit 1
    fi
}

require_pattern "$HOSTED_LINK_FILE" 'NATIVE_HOSTED_LINK_FLAG_PRINT_HELPER_OBJECT' \
    "print helper object flag"
require_pattern "$HOSTED_LINK_FILE" 'native_hosted_link_plan_add_print_helper_object' \
    "print helper link object registration API"
require_pattern "$BUILD_DRIVER_FILE" 'native_build_hosted_mir_module_needs_print_helper_object' \
    "PortableMIR print-helper call scanner"
require_pattern "$BUILD_DRIVER_FILE" 'native_hosted_print_helper_link_object: status=planned' \
    "print helper link object diagnostic"

bash "$REPO_ROOT/tests/verify_native_hosted_link_contract.sh"

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "SKIP: hosted native print helper link plan test currently requires x86_64 host" >&2
    exit 0
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
(cd "$REPO_ROOT" && "$REPO_ROOT/bin/uya" build "$HW_SRC" -o "$HW_NATIVE_BIN" \
    --native --no-split-c --project-root "$TMP_DIR" \
    >"$TMP_DIR/hw.native.build.out" 2>"$HW_NATIVE_ERR")
status=$?
set -e

if [[ "$status" -ne 0 ]]; then
    echo "error: HelloWorld native build should now reach the L994.F writer path" >&2
    cat "$HW_NATIVE_ERR" >&2
    exit 1
fi
if [[ ! -s "$HW_NATIVE_BIN" ]]; then
    echo "error: HelloWorld native build reported success without executable" >&2
    cat "$HW_NATIVE_ERR" >&2
    exit 1
fi

if ! grep -q 'native_hosted_print_mir_body: calls=2 write_str=1 newline=1 operands=7 insts=2' "$HW_NATIVE_ERR"; then
    echo "error: print MIR body evidence missing" >&2
    cat "$HW_NATIVE_ERR" >&2
    exit 1
fi
if ! grep -q 'native_hosted_print_helper_link_object: status=planned objects=1' "$HW_NATIVE_ERR"; then
    echo "error: print helper object was not added to hosted link plan" >&2
    cat "$HW_NATIVE_ERR" >&2
    exit 1
fi
if ! grep -Eq 'native_hosted_preflight: status=0 verifier_error=0 .* hosted_link_objects=1' "$HW_NATIVE_ERR"; then
    echo "error: hosted preflight summary did not count the print helper link object" >&2
    cat "$HW_NATIVE_ERR" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: print_helloworld_path=1' "$HW_NATIVE_ERR"; then
    echo "error: L994.F print writer path did not run after link planning" >&2
    cat "$HW_NATIVE_ERR" >&2
    exit 1
fi
chmod +x "$HW_NATIVE_BIN"
"$HW_NATIVE_BIN" >"$TMP_DIR/hw.native.run.out" 2>"$TMP_DIR/hw.native.run.err"
if ! cmp -s "$TMP_DIR/hw.native.run.out" <(printf "Hello, World!\n"); then
    echo "error: L994.F print writer output mismatch" >&2
    cat "$TMP_DIR/hw.native.run.out" >&2
    cat "$TMP_DIR/hw.native.run.err" >&2
    exit 1
fi

echo "OK: hosted native print helper link object is planned and handed to the L994.F writer"
