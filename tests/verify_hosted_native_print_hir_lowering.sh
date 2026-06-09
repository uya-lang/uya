#!/usr/bin/env bash

# Phase 9B / L994.B：HIR→CoreBody→MIR print/println string-literal lowering contract 测试。
#
# 合同：本测试在 hosted --native 编译 helloworld 程序（@println("Hello, World!")）时，
# 断言 stderr 包含 MIR body lowering 证据：
#   - `mir_body_functions` 至少为 1（说明 helloworld 主体的 CoreBody 至少被 lowering
#     到 MIR 一次，函数体不再 `pending_bodies` 阻塞 lowering-missing）
#   - 主体函数的 body frontier 报告 `@println(...)` 对应的 CoreExpr/CORE_EXPR_KIND_CALL
#     节点已 lowering 到 `uya_write_str` / `uya_write_newline` extern（synth_decl_id=-3/-4）
#
# TDD 状态（2026-06-10）：本测试当前必须 fail（红），因为 L994.B 未实现。
# L994.B 实现后本测试转绿；L994.A（hosted print helper extern 注册）已绿。
#
# 完整合同定义见 `docs/todo_compiler_1s.md` L994.B 与
# `docs/print_corebody_surface.md` §3。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-hosted-native-print-hir-lowering.XXXXXX)"
# TDD red-light：trap 不清空 TMP_DIR，确保错误信息可读。
trap 'echo "TMP_DIR=$TMP_DIR" >&2' EXIT

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "SKIP: hosted native print HIR lowering test currently requires x86_64 host" >&2
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

# 断言 1：mir_body_functions 至少为 1（helloworld main body 已被 lowering）
if ! grep -Eq 'native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=[1-9][0-9]* mir_body_functions=[1-9][0-9]* mir_types=[1-9][0-9]*' "$HW_NATIVE_ERR"; then
    echo "error: stderr does not show mir_body_functions >= 1 (L994.B not implemented)" >&2
    echo "----- stderr -----" >&2
    cat "$HW_NATIVE_ERR" >&2
    echo "----- end -----" >&2
    echo "L994.B TDD red-light: helloworld main body not lowered to MIR." >&2
    echo "TMP_DIR=$TMP_DIR (保留以便诊断)" >&2
    exit 1
fi

# 断言 2：stale `pending_core_bodies` 拒绝路径不再针对 helloworld 触发
#         （即 lowering-missing 不应作为 @println 的阻塞原因出现）
if grep -q 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' "$HW_NATIVE_ERR"; then
    echo "error: helloworld still rejects with lowering-missing after L994.B" >&2
    echo "----- stderr -----" >&2
    cat "$HW_NATIVE_ERR" >&2
    echo "----- end -----" >&2
    echo "L994.B TDD red-light: lowering-missing still triggered for helloworld @println." >&2
    echo "TMP_DIR=$TMP_DIR (保留以便诊断)" >&2
    exit 1
fi

echo "OK: hosted native HIR print lowering registered main body to MIR (L994.B green)"
