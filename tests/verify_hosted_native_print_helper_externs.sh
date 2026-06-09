#!/usr/bin/env bash

# Phase 9B / L994.A：MIR extern helper 注册 contract 测试。
#
# 合同：本测试在 hosted --native 编译 helloworld 程序（@println("Hello, World!")）时，
# 断言 stderr 包含 MIR extern helper 注册证据：
#   - 至少一个名为 `uya_write` 的 MIR extern function（fd: i32, ptr: *byte, len: i32 -> i32）
#   - 至少一个名为 `uya_write_str` 的 MIR extern function（fd: i32, ptr: *byte, len: i32 -> i32）
#   - 至少一个名为 `uya_write_newline` 的 MIR extern function（fd: i32 -> i32）
#
# 输出格式（建议）：
#   `mir_extern_function_count: name=uya_write symbol_index=...`
#   `mir_extern_function_count: name=uya_write_str symbol_index=...`
#   `mir_extern_function_count: name=uya_write_newline symbol_index=...`
#
# TDD 状态（2026-06-10）：本测试当前必须 fail（红），因为 L994.A 未实现。
# 实现 L994.A 后，本测试转为绿。
#
# 完整合同定义见 `docs/todo_compiler_1s.md` L994.A 与
# `docs/print_corebody_surface.md` §3.3。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-hosted-native-print-helper-externs.XXXXXX)"
# TDD red-light：trap 不清空 TMP_DIR，确保错误信息可读。
trap 'echo "TMP_DIR=$TMP_DIR" >&2' EXIT

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "SKIP: hosted native print helper externs test currently requires x86_64 host" >&2
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

# 当前 L994.A 未实现，--native 必然 reject with lowering-missing。
# 测试在这里只断言 helper 计数（不论 reject 还是 success）。
# 实现 L994.A 后，本测试的 helper 计数断言会变成绿。

assert_helper_registered() {
    local helper_name="$1"
    if ! grep -Eq "mir_extern_function_count:[[:space:]]+name=${helper_name}\b" "$HW_NATIVE_ERR"; then
        echo "error: stderr missing MIR extern helper registration for '${helper_name}'" >&2
        echo "----- stderr -----" >&2
        cat "$HW_NATIVE_ERR" >&2
        echo "----- end -----" >&2
        echo "L994.A TDD red-light: MIR extern helper '${helper_name}' not registered." >&2
        echo "TMP_DIR=$TMP_DIR (保留以便诊断)" >&2
        exit 1
    fi
}

assert_helper_registered "uya_write"
assert_helper_registered "uya_write_str"
assert_helper_registered "uya_write_newline"

echo "OK: hosted native MIR extern print helpers registered (L994.A green)"
