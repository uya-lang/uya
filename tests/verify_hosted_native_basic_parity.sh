#!/usr/bin/env bash

# Phase 9A：验证 hosted --native 对无外部依赖基础程序在 coverage 未完成时
# fail-closed：不静默回落 C99、不生成伪输出，并保留 CoreBody/PortableMIR
# preflight 诊断。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-hosted-native-basic-parity.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "SKIP: hosted native basic parity currently requires x86_64 host" >&2
    exit 0
fi

cat >"$TMP_DIR/exit0.uya" <<'EOF'
export fn main() i32 {
    return 0;
}
EOF

cat >"$TMP_DIR/return7.uya" <<'EOF'
export fn main() i32 {
    return 7;
}
EOF

cat >"$TMP_DIR/call_value.uya" <<'EOF'
fn value() i32 {
    return 5;
}

export fn main() i32 {
    return value();
}
EOF

run_reject_case() {
    local name="$1"
    local src="$2"
    local c99_bin="$TMP_DIR/$name.c99"
    local native_bin="$TMP_DIR/$name.native"

    (cd "$REPO_ROOT" && ./bin/uya build "$src" -o "$c99_bin" \
        --no-split-c --project-root "$TMP_DIR" \
        >"$TMP_DIR/$name.c99.build.out" 2>"$TMP_DIR/$name.c99.build.err")

    set +e
    (cd "$REPO_ROOT" && ./bin/uya build "$src" -o "$native_bin" \
        --native --no-split-c --project-root "$TMP_DIR" \
        >"$TMP_DIR/$name.native.build.out" 2>"$TMP_DIR/$name.native.build.err")
    local native_build_status=$?
    set -e

    if [[ "$native_build_status" -eq 0 ]]; then
        echo "error: hosted native basic should reject while coverage is incomplete for $name" >&2
        cat "$TMP_DIR/$name.native.build.err" >&2
        exit 1
    fi
    if [[ -e "$native_bin" ]]; then
        echo "error: hosted native basic produced output while rejecting for $name" >&2
        cat "$TMP_DIR/$name.native.build.err" >&2
        exit 1
    fi
    grep -q '后端类型: Native' "$TMP_DIR/$name.native.build.err"
    grep -Eq 'native_hosted_coreir_preflight: status=-1 verifier_error=0 functions=[1-9][0-9]* core_bodies=[1-9][0-9]* pending_bodies=[1-9][0-9]*' "$TMP_DIR/$name.native.build.err"
    grep -Eq 'native_hosted_preflight: status=-1 verifier_error=[1-9][0-9]* mir_extern_functions=[1-9][0-9]* mir_body_functions=[1-9][0-9]*' "$TMP_DIR/$name.native.build.err"
    grep -q 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_preflight_failed' "$TMP_DIR/$name.native.build.err"
    grep -q '不能静默回落 C99，也不能使用 build-seed LoweredProgram helper' "$TMP_DIR/$name.native.build.err"
    if grep -q '后端类型: C99' "$TMP_DIR/$name.native.build.err" ||
       grep -q 'native_hosted_subset: no_deps_portable_mir_path=1' "$TMP_DIR/$name.native.build.err" ||
       grep -q 'native_output_bytes:' "$TMP_DIR/$name.native.build.err"; then
        echo "error: hosted native basic parity used C99 fallback or reject path for $name" >&2
        cat "$TMP_DIR/$name.native.build.err" >&2
        exit 1
    fi
    if grep -q 'hosted native assembly' "$TMP_DIR/$name.native.build.err"; then
        echo "error: hosted native basic parity still used assembly helper for $name" >&2
        cat "$TMP_DIR/$name.native.build.err" >&2
        exit 1
    fi

    chmod +x "$c99_bin"
    set +e
    "$c99_bin" >"$TMP_DIR/$name.c99.run.out" 2>"$TMP_DIR/$name.c99.run.err"
    local c99_status=$?
    set -e
    if [[ "$c99_status" -lt 0 || "$c99_status" -gt 255 ]]; then
        echo "error: C99 oracle status out of range for $name: $c99_status" >&2
        exit 1
    fi
}

run_reject_case exit0 "$TMP_DIR/exit0.uya"
run_reject_case return7 "$TMP_DIR/return7.uya"
run_reject_case call_value "$TMP_DIR/call_value.uya"

echo "OK: hosted native basic fail-closed boundary keeps C99 oracle separate"
