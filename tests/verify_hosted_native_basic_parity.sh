#!/usr/bin/env bash

# Phase 9A：验证 hosted --native 对无外部依赖基础程序能真实生成 executable，
# 并与 C99 oracle 的退出码 / stdout / stderr 一致。

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

run_parity_case() {
    local name="$1"
    local src="$2"
    local c99_bin="$TMP_DIR/$name.c99"
    local native_bin="$TMP_DIR/$name.native"

    (cd "$REPO_ROOT" && ./bin/uya build "$src" -o "$c99_bin" \
        --no-split-c --project-root "$TMP_DIR" \
        >"$TMP_DIR/$name.c99.build.out" 2>"$TMP_DIR/$name.c99.build.err")

    (cd "$REPO_ROOT" && ./bin/uya build "$src" -o "$native_bin" \
        --native --no-split-c --project-root "$TMP_DIR" \
        >"$TMP_DIR/$name.native.build.out" 2>"$TMP_DIR/$name.native.build.err")

    test -s "$native_bin"
    grep -q '后端类型: Native' "$TMP_DIR/$name.native.build.err"
    grep -q 'native_hosted_subset: no_deps_portable_mir_path=1' "$TMP_DIR/$name.native.build.err"
    grep -Eq 'native_hosted_executable_writer_stream: status=ready target=1 code_bytes=[1-9][0-9]* output_bytes=[1-9][0-9]* temp_peak_bytes=[1-9][0-9]*' "$TMP_DIR/$name.native.build.err"
    grep -q 'native_output_bytes:' "$TMP_DIR/$name.native.build.err"
    if grep -q '后端类型: C99' "$TMP_DIR/$name.native.build.err" ||
       grep -q 'native_hosted_portable_mir_lowering_missing' "$TMP_DIR/$name.native.build.err"; then
        echo "error: hosted native basic parity used C99 fallback or reject path for $name" >&2
        cat "$TMP_DIR/$name.native.build.err" >&2
        exit 1
    fi
    if grep -q 'hosted native assembly' "$TMP_DIR/$name.native.build.err"; then
        echo "error: hosted native basic parity still used assembly helper for $name" >&2
        cat "$TMP_DIR/$name.native.build.err" >&2
        exit 1
    fi

    chmod +x "$c99_bin" "$native_bin"
    set +e
    "$c99_bin" >"$TMP_DIR/$name.c99.run.out" 2>"$TMP_DIR/$name.c99.run.err"
    local c99_status=$?
    "$native_bin" >"$TMP_DIR/$name.native.run.out" 2>"$TMP_DIR/$name.native.run.err"
    local native_status=$?
    set -e

    if [[ "$native_status" -ne "$c99_status" ]]; then
        echo "error: hosted native/C99 status differs for $name: c99=$c99_status native=$native_status" >&2
        exit 1
    fi
    if ! cmp -s "$TMP_DIR/$name.c99.run.out" "$TMP_DIR/$name.native.run.out"; then
        echo "error: hosted native/C99 stdout differs for $name" >&2
        exit 1
    fi
    if ! cmp -s "$TMP_DIR/$name.c99.run.err" "$TMP_DIR/$name.native.run.err"; then
        echo "error: hosted native/C99 stderr differs for $name" >&2
        exit 1
    fi
}

run_parity_case exit0 "$TMP_DIR/exit0.uya"
run_parity_case return7 "$TMP_DIR/return7.uya"
run_parity_case call_value "$TMP_DIR/call_value.uya"

echo "OK: hosted native basic parity matches C99"
