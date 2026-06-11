#!/usr/bin/env bash
#
# Phase 9B: HelloWorld parity between hosted --native and C99 oracle.
#
# Contract enforced here:
#   - The C99 oracle for `@println("Hello, World!")` must compile, link, run
#     and emit exactly `Hello, World!\n` on stdout with exit 0. The build
#     stderr must NOT contain the C99 fallback / pre-MIR helper / build-seed
#     helper paths.
#   - Hosted --native must compile, link, run and emit byte-for-byte the same
#     stdout as the C99 oracle for the bare `@println("Hello, World!")` case.
#     A `native_hosted_portable_mir_lowering_missing` reject is no longer
#     accepted for this parity gate.
#   - Hosted --native must NOT mention `后端类型: C99`, hosted native assembly
#     helper fallback, or the build-seed LoweredProgram helper.
#   - Variants covered: bare `@println` literal, `@print + @println("")` two
#     step form, and `@println` used as an i32 expression.
#
# This script is the Phase 9B HelloWorld native-success gate: hw1 must produce
# a real executable and match the C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-hosted-native-helloworld.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "SKIP: hosted native HelloWorld parity currently requires x86_64 host" >&2
    exit 0
fi

UYA_BIN="$REPO_ROOT/bin/uya"
if [[ ! -x "$UYA_BIN" ]]; then
    echo "error: missing or non-executable bin/uya; run \`make uya\` first" >&2
    exit 1
fi

require_native_no_fallback() {
    local err_file="$1"
    local label="$2"
    # "后端类型: C99" appearing inside a --native build is the C99 fallback
    # contract violation we are guarding against. C99-only builds (the oracle)
    # are allowed to print it; callers of this helper must filter the err
    # stream first.
    if grep -q '后端类型: C99' "$err_file"; then
        echo "error: $label build stderr mentions C99 fallback" >&2
        cat "$err_file" >&2
        exit 1
    fi
    if grep -q 'hosted native assembly' "$err_file"; then
        echo "error: $label build stderr mentions hosted native assembly helper" >&2
        cat "$err_file" >&2
        exit 1
    fi
    if grep -q 'build-seed LoweredProgram helper' "$err_file"; then
        echo "error: $label build stderr mentions build-seed helper fallback" >&2
        cat "$err_file" >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Variant 1: bare @println("Hello, World!")
# ---------------------------------------------------------------------------
HW1_SRC="$TMP_DIR/hw1.uya"
cat >"$HW1_SRC" <<'EOF'
export fn main() i32 {
    @println("Hello, World!");
    return 0;
}
EOF

HW1_C99_BIN="$TMP_DIR/hw1.c99"
HW1_C99_ERR="$TMP_DIR/hw1.c99.err"
(cd "$REPO_ROOT" && "$UYA_BIN" build "$HW1_SRC" -o "$HW1_C99_BIN" \
    --no-split-c --project-root "$TMP_DIR" \
    >"$TMP_DIR/hw1.c99.out" 2>"$HW1_C99_ERR")
# C99 oracle build is allowed to print "后端类型: C99"
chmod +x "$HW1_C99_BIN"
set +e
"$HW1_C99_BIN" >"$TMP_DIR/hw1.c99.run.out" 2>"$TMP_DIR/hw1.c99.run.err"
HW1_C99_STATUS=$?
set -e
if [[ "$HW1_C99_STATUS" -ne 0 ]]; then
    echo "error: C99 hw1 exited with $HW1_C99_STATUS" >&2
    cat "$TMP_DIR/hw1.c99.run.out" >&2
    cat "$TMP_DIR/hw1.c99.run.err" >&2
    exit 1
fi
HW1_C99_STDOUT="$(cat "$TMP_DIR/hw1.c99.run.out")"
if [[ "$HW1_C99_STDOUT" != $'Hello, World!\n' && "$HW1_C99_STDOUT" != "Hello, World!" ]]; then
    echo "error: C99 hw1 stdout mismatch: got [$HW1_C99_STDOUT]" >&2
    exit 1
fi

# Hosted native: Phase 9B L994.F requires real success for bare HelloWorld.
HW1_NATIVE_BIN="$TMP_DIR/hw1.native"
HW1_NATIVE_OUT="$TMP_DIR/hw1.native.out"
HW1_NATIVE_ERR="$TMP_DIR/hw1.native.err"
set +e
(cd "$REPO_ROOT" && "$UYA_BIN" build "$HW1_SRC" -o "$HW1_NATIVE_BIN" \
    --native --no-split-c --project-root "$TMP_DIR" \
    >"$HW1_NATIVE_OUT" 2>"$HW1_NATIVE_ERR")
HW1_NATIVE_STATUS=$?
set -e
if [[ "$HW1_NATIVE_STATUS" -ne 0 ]]; then
    echo "error: hw1 native build must succeed for HelloWorld parity" >&2
    cat "$HW1_NATIVE_ERR" >&2
    exit 1
fi
if [[ ! -s "$HW1_NATIVE_BIN" ]]; then
    echo "error: hw1 native build reported success without output" >&2
    cat "$HW1_NATIVE_ERR" >&2
    exit 1
fi
require_native_no_fallback "$HW1_NATIVE_ERR" "hw1-native"
if grep -q 'native_hosted_portable_mir_lowering_missing' "$HW1_NATIVE_ERR"; then
    echo "error: hw1 native parity still reports MIR lowering missing" >&2
    cat "$HW1_NATIVE_ERR" >&2
    exit 1
fi
if ! grep -Eq 'native_hosted_coreir_preflight: status=0 verifier_error=0 functions=[1-9][0-9]* core_bodies=[1-9][0-9]* pending_bodies=[0-9]+' "$HW1_NATIVE_ERR"; then
    echo "error: hw1 native build lacks CoreIR body evidence" >&2
    cat "$HW1_NATIVE_ERR" >&2
    exit 1
fi
if ! grep -Eq 'native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=[1-9][0-9]* mir_body_functions=[1-9][0-9]* mir_types=[1-9][0-9]*' "$HW1_NATIVE_ERR"; then
    echo "error: hw1 native build lacks PortableMIR body evidence" >&2
    cat "$HW1_NATIVE_ERR" >&2
    exit 1
fi
if ! grep -q 'native_hosted_subset: print_helloworld_path=1' "$HW1_NATIVE_ERR"; then
    echo "error: hw1 native build did not report the hosted print HelloWorld writer path" >&2
    cat "$HW1_NATIVE_ERR" >&2
    exit 1
fi
chmod +x "$HW1_NATIVE_BIN"
set +e
"$HW1_NATIVE_BIN" >"$TMP_DIR/hw1.native.run.out" 2>"$TMP_DIR/hw1.native.run.err"
HW1_NATIVE_RUN_STATUS=$?
set -e
if [[ "$HW1_NATIVE_RUN_STATUS" -ne 0 ]]; then
    echo "error: hw1 native executable exited with $HW1_NATIVE_RUN_STATUS" >&2
    cat "$TMP_DIR/hw1.native.run.out" >&2
    cat "$TMP_DIR/hw1.native.run.err" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/hw1.c99.run.out" "$TMP_DIR/hw1.native.run.out"; then
    echo "error: hw1 native/C99 stdout differ" >&2
    diff "$TMP_DIR/hw1.c99.run.out" "$TMP_DIR/hw1.native.run.out" >&2 || true
    exit 1
fi
echo "OK: hw1 native/C99 parity verified"

# ---------------------------------------------------------------------------
# Variant 2: @print + @println("") must produce the same output
# ---------------------------------------------------------------------------
HW2_SRC="$TMP_DIR/hw2.uya"
cat >"$HW2_SRC" <<'EOF'
export fn main() i32 {
    @print("Hello, World!");
    @println("");
    return 0;
}
EOF

HW2_C99_BIN="$TMP_DIR/hw2.c99"
HW2_C99_ERR="$TMP_DIR/hw2.c99.err"
(cd "$REPO_ROOT" && "$UYA_BIN" build "$HW2_SRC" -o "$HW2_C99_BIN" \
    --no-split-c --project-root "$TMP_DIR" \
    >"$TMP_DIR/hw2.c99.out" 2>"$HW2_C99_ERR")
# C99 oracle build is allowed to print "后端类型: C99"
chmod +x "$HW2_C99_BIN"
set +e
"$HW2_C99_BIN" >"$TMP_DIR/hw2.c99.run.out" 2>"$TMP_DIR/hw2.c99.run.err"
HW2_C99_STATUS=$?
set -e
if [[ "$HW2_C99_STATUS" -ne 0 ]]; then
    echo "error: C99 hw2 exited with $HW2_C99_STATUS" >&2
    cat "$TMP_DIR/hw2.c99.run.out" >&2
    cat "$TMP_DIR/hw2.c99.run.err" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/hw1.c99.run.out" "$TMP_DIR/hw2.c99.run.out"; then
    echo "error: hw2 stdout differs from hw1" >&2
    diff "$TMP_DIR/hw1.c99.run.out" "$TMP_DIR/hw2.c99.run.out" >&2 || true
    exit 1
fi

# ---------------------------------------------------------------------------
# Variant 3: @println return value usable as i32 expression
# ---------------------------------------------------------------------------
HW3_SRC="$TMP_DIR/hw3.uya"
cat >"$HW3_SRC" <<'EOF'
export fn main() i32 {
    const printed: i32 = @println("Hello, World!");
    if printed <= 0 { return 1; }
    return 0;
}
EOF

HW3_C99_BIN="$TMP_DIR/hw3.c99"
HW3_C99_ERR="$TMP_DIR/hw3.c99.err"
(cd "$REPO_ROOT" && "$UYA_BIN" build "$HW3_SRC" -o "$HW3_C99_BIN" \
    --no-split-c --project-root "$TMP_DIR" \
    >"$TMP_DIR/hw3.c99.out" 2>"$HW3_C99_ERR")
# C99 oracle build is allowed to print "后端类型: C99"
chmod +x "$HW3_C99_BIN"
set +e
"$HW3_C99_BIN" >"$TMP_DIR/hw3.c99.run.out" 2>"$TMP_DIR/hw3.c99.run.err"
HW3_C99_STATUS=$?
set -e
if [[ "$HW3_C99_STATUS" -ne 0 ]]; then
    echo "error: C99 hw3 exited with $HW3_C99_STATUS" >&2
    cat "$TMP_DIR/hw3.c99.run.out" >&2
    cat "$TMP_DIR/hw3.c99.run.err" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/hw1.c99.run.out" "$TMP_DIR/hw3.c99.run.out"; then
    echo "error: hw3 stdout differs from hw1" >&2
    diff "$TMP_DIR/hw1.c99.run.out" "$TMP_DIR/hw3.c99.run.out" >&2 || true
    exit 1
fi

echo "OK: hosted native HelloWorld parity shell verified (hw1 native/C99 parity)"
