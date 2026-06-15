#!/usr/bin/env bash

# Phase 9A：验证 hosted native preflight 能承载最小 main local-call 初始化和 if-return 骨架。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-hosted-native-main-local-if.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/c_import"
cp "$REPO_ROOT/tests/fixtures/c_import/add_impl.c" "$TMP_DIR/c_import/add_impl.c"

src="$TMP_DIR/main.uya"
c99_bin="$TMP_DIR/c99-main-local-if"
native_bin="$TMP_DIR/native-main-local-if"

cat >"$src" <<'EOF'
@c_import("c_import/add_impl.c");

extern fn add_i32(a: i32, b: i32) i32;

fn value() i32 {
    return 3;
}

export fn main() i32 {
    const v: i32 = value();
    if v != 3 {
        return 1;
    }
    return 0;
}
EOF

c99_build_out="$TMP_DIR/c99.build.out"
c99_build_err="$TMP_DIR/c99.build.err"
if ! (cd "$REPO_ROOT" && ./bin/uya build "$src" -o "$c99_bin" \
    --no-split-c --project-root "$TMP_DIR" >"$c99_build_out" 2>"$c99_build_err"); then
    cat "$c99_build_out" >&2
    cat "$c99_build_err" >&2
    exit 1
fi

set +e
"$c99_bin" >"$TMP_DIR/c99.run.out" 2>"$TMP_DIR/c99.run.err"
c99_status=$?
set -e
if [[ "$c99_status" -ne 0 ]]; then
    echo "error: C99 main local-if smoke exited with $c99_status" >&2
    cat "$TMP_DIR/c99.run.out" >&2
    cat "$TMP_DIR/c99.run.err" >&2
    exit 1
fi

native_build_out="$TMP_DIR/native.build.out"
native_build_err="$TMP_DIR/native.build.err"
set +e
(cd "$REPO_ROOT" && ./bin/uya build "$src" -o "$native_bin" \
    --native --no-split-c --project-root "$TMP_DIR" >"$native_build_out" 2>"$native_build_err")
native_build_status=$?
set -e

if [[ "$native_build_status" -eq 0 ]]; then
    echo "error: main local-if smoke unexpectedly reached hosted native parity" >&2
    exit 1
fi
if [[ -e "$native_bin" ]]; then
    echo "error: native main local-if reject left an output file" >&2
    exit 1
fi
if grep -q '后端类型: C99' "$native_build_err"; then
    echo "error: native main local-if reject fell back to C99" >&2
    cat "$native_build_err" >&2
    exit 1
fi
if ! grep -Eq 'native_hosted_coreir_preflight: status=-1 verifier_error=0 functions=11 core_bodies=3 pending_bodies=4' "$native_build_err"; then
    echo "error: native main local-if reject lacks CoreIR local/if preflight evidence" >&2
    cat "$native_build_err" >&2
    exit 1
fi
if ! grep -Eq 'native_hosted_preflight: status=-1 verifier_error=[1-9][0-9]* mir_extern_functions=7 mir_body_functions=3 mir_types=[1-9][0-9]* extern_symbols=0 c_import_objects=1 hosted_link_objects=0' "$native_build_err"; then
    echo "error: native main local-if reject lacks PortableMIR local/if preflight evidence" >&2
    cat "$native_build_err" >&2
    exit 1
fi
if ! grep -q 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_preflight_failed' "$native_build_err"; then
    echo "error: native main local-if reject lacks hosted lowering gap" >&2
    cat "$native_build_err" >&2
    exit 1
fi

echo "OK: hosted native main local-if preflight covered C99 success and explicit native reject"
