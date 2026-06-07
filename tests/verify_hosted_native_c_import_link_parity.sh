#!/usr/bin/env bash

# Phase 9A: hosted native must link a minimal @c_import sidecar object
# through the host ABI/linker and match the C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-hosted-native-c-import-link.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "SKIP: hosted native c_import link parity currently requires x86_64 host" >&2
    exit 0
fi
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "SKIP: hosted native c_import link parity currently requires Linux host" >&2
    exit 0
fi

mkdir -p "$TMP_DIR/c_import"
cp "$REPO_ROOT/tests/fixtures/c_import/add_impl.c" "$TMP_DIR/c_import/add_impl.c"

src="$TMP_DIR/main.uya"
c99_bin="$TMP_DIR/c99-c-import-link"
native_bin="$TMP_DIR/native-c-import-link"

cat >"$src" <<'EOF'
@c_import("c_import/add_impl.c");

extern fn add_i32(a: i32, b: i32) i32;

export fn main() i32 {
    return add_i32(20, 22);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya build "$src" -o "$c99_bin" \
    --no-split-c --project-root "$TMP_DIR" \
    >"$TMP_DIR/c99.build.out" 2>"$TMP_DIR/c99.build.err")

(cd "$REPO_ROOT" && ./bin/uya build "$src" -o "$native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" \
    >"$TMP_DIR/native.build.out" 2>"$TMP_DIR/native.build.err")

test -s "$native_bin"
grep -q '后端类型: Native' "$TMP_DIR/native.build.err"
grep -Eq 'native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=[1-9][0-9]* mir_body_functions=[0-9]+ mir_types=[1-9][0-9]* extern_symbols=[1-9][0-9]* c_import_objects=1 hosted_link_objects=1' "$TMP_DIR/native.build.err"
grep -q 'native_hosted_linker_handoff: extern=add_i32 c_import_objects=1 linked_objects=2' "$TMP_DIR/native.build.err"
grep -q 'native_hosted_subset: c_import_extern_link_path=1' "$TMP_DIR/native.build.err"
grep -q 'native_output_bytes:' "$TMP_DIR/native.build.err"
if grep -q '后端类型: C99' "$TMP_DIR/native.build.err" ||
   grep -q 'native_hosted_portable_mir_lowering_missing' "$TMP_DIR/native.build.err"; then
    echo "error: hosted native c_import link parity used C99 fallback or reject path" >&2
    cat "$TMP_DIR/native.build.err" >&2
    exit 1
fi

chmod +x "$c99_bin" "$native_bin"
set +e
"$c99_bin" >"$TMP_DIR/c99.run.out" 2>"$TMP_DIR/c99.run.err"
c99_status=$?
"$native_bin" >"$TMP_DIR/native.run.out" 2>"$TMP_DIR/native.run.err"
native_status=$?
set -e

if [[ "$native_status" -ne "$c99_status" ]]; then
    echo "error: hosted native/C99 status differs: c99=$c99_status native=$native_status" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/c99.run.out" "$TMP_DIR/native.run.out"; then
    echo "error: hosted native/C99 stdout differs" >&2
    exit 1
fi
if ! cmp -s "$TMP_DIR/c99.run.err" "$TMP_DIR/native.run.err"; then
    echo "error: hosted native/C99 stderr differs" >&2
    exit 1
fi

echo "OK: hosted native c_import linker handoff matches C99"
