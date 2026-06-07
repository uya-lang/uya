#!/usr/bin/env bash

# Phase 9 KPI：native executable smoke 与 C99 smoke 的输出/退出码一致。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NATIVE_DIR="$REPO_ROOT/src/codegen/native"

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "错误: native parity smoke 当前只支持 x86_64 host" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-native-c99-parity.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/codegen/native"
cp "$NATIVE_DIR/elf64.uya" "$tmp_dir/codegen/native/elf64.uya"
cp "$NATIVE_DIR/x86_64.uya" "$tmp_dir/codegen/native/x86_64.uya"
cp "$NATIVE_DIR/main.uya" "$tmp_dir/codegen/native/main.uya"

c99_src="$tmp_dir/c99_smoke.uya"
c99_bin="$tmp_dir/c99-smoke"
native_src="$tmp_dir/native_generate.uya"
native_bin="$tmp_dir/native-smoke"

cat >"$c99_src" <<'EOF'
export fn main() i32 {
    return 0;
}
EOF

cat >"$native_src" <<EOF
use std.testing.assert_eq_i32;
use std.testing.expect;
use libc.FILE;
use libc.fopen;
use libc.fclose;
use codegen.native;

test "generate native exit0 smoke executable" {
    const fp: &FILE = fopen("$native_bin" as &const byte, "wb" as &const byte);
    try expect(fp != null);
    const result: NativeEmitResult = native_emit_linux_x86_64_exit0_stream(fp);
    _ = fclose(fp);
    try assert_eq_i32(result.status, NATIVE_EMIT_STATUS_OK);
    try assert_eq_i32(result.target, NATIVE_TARGET_LINUX_X86_64);
    try expect(result.code_bytes == X86_64_LINUX_EXIT0_SIZE as usize);
    try expect(result.output_bytes == (ELF64_MIN_EXEC_HEADERS + X86_64_LINUX_EXIT0_SIZE) as usize);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya build "$c99_src" -o "$c99_bin" --no-split-c --project-root "$tmp_dir/") >"$tmp_dir/c99_build.log" 2>&1
(cd "$REPO_ROOT" && ./bin/uya test "$native_src" --no-split-c --project-root "$tmp_dir/") >"$tmp_dir/native_generate.log" 2>&1

if [[ ! -x "$c99_bin" ]]; then
    echo "错误: C99 smoke executable 未生成: $c99_bin" >&2
    cat "$tmp_dir/c99_build.log" >&2
    exit 1
fi
if [[ ! -s "$native_bin" ]]; then
    echo "错误: native smoke executable 未生成: $native_bin" >&2
    cat "$tmp_dir/native_generate.log" >&2
    exit 1
fi
chmod +x "$native_bin"

set +e
"$c99_bin" >"$tmp_dir/c99.stdout" 2>"$tmp_dir/c99.stderr"
c99_status=$?
"$native_bin" >"$tmp_dir/native.stdout" 2>"$tmp_dir/native.stderr"
native_status=$?
set -e

if [[ "$c99_status" -ne "$native_status" ]]; then
    echo "错误: native/C99 smoke 退出码不一致: c99=$c99_status native=$native_status" >&2
    exit 1
fi
if ! cmp -s "$tmp_dir/c99.stdout" "$tmp_dir/native.stdout"; then
    echo "错误: native/C99 smoke stdout 不一致" >&2
    exit 1
fi
if ! cmp -s "$tmp_dir/c99.stderr" "$tmp_dir/native.stderr"; then
    echo "错误: native/C99 smoke stderr 不一致" >&2
    exit 1
fi

echo "verify_native_c99_smoke_parity: ok (exit=$native_status stdout_bytes=$(wc -c <"$tmp_dir/native.stdout") stderr_bytes=$(wc -c <"$tmp_dir/native.stderr"))"
