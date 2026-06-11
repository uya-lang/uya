#!/usr/bin/env bash

# Phase 9B / L994.B：HIR→CoreBody→MIR print/println string-literal lowering contract 测试。
#
# 合同：本测试在 hosted --native 编译 helloworld 程序（@println("Hello, World!")）时，
# 断言 stderr 包含 print lowering 证据：
#   - HIR 模式识别到 `@println(string)`。
#   - CoreIR body 生成 `uya_write_str` + `uya_write_newline` call。
#   - PortableMIR body 生成对应两个 `MIR_INST_OP_CALL`。
#   - `mir_body_functions` 至少为 1。
#
# 本测试只验证 L994.B 的 print lowering 接线。后续非 print runtime entry body
# 仍可能触发 `native_hosted_portable_mir_lowering_missing`，但 frontier 必须明确
# 指向非 print 的 pending body（例如 `get_argc`），不能是 print main body。
#
# TDD 状态（2026-06-11）：L994.B.1/B.2/B.3 分片已分别有窄脚本；
# B.4 完成后本脚本作为聚合门禁转绿。
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

# 断言 0（L994.B.1）：println helloworld 模式已被 CoreBody 模式识别前端检测到
if ! grep -q 'native_hosted_print_hir_pattern: declared' "$HW_NATIVE_ERR"; then
    echo "error: println helloworld pattern not recognized (L994.B.1 not implemented)" >&2
    echo "----- stderr -----" >&2
    cat "$HW_NATIVE_ERR" >&2
    echo "----- end -----" >&2
    exit 1
fi
echo "L994.B.1 OK: println helloworld pattern recognized by CoreBody frontend"

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

# 断言 2（L994.B.2）：CoreIR body 已经生成两个 print helper call
if ! grep -q 'native_hosted_print_coreir_body: calls=2 write_str=1 newline=1' "$HW_NATIVE_ERR"; then
    echo "error: stderr does not show print CoreIR write_str + newline body (L994.B.2 not wired)" >&2
    echo "----- stderr -----" >&2
    cat "$HW_NATIVE_ERR" >&2
    echo "----- end -----" >&2
    exit 1
fi
echo "L994.B.2 OK: print CoreIR body emitted write_str + write_newline calls"

# 断言 3（L994.B.3/B.4）：MIR body 已经进入主路由并生成两个 helper call inst
if ! grep -q 'native_hosted_print_mir_body: calls=2 write_str=1 newline=1 operands=7 insts=2' "$HW_NATIVE_ERR"; then
    echo "error: stderr does not show print MIR write_str + newline body (L994.B.3/B.4 not wired)" >&2
    echo "----- stderr -----" >&2
    cat "$HW_NATIVE_ERR" >&2
    echo "----- end -----" >&2
    exit 1
fi
echo "L994.B.3/B.4 OK: print MIR body wired through hosted native preflight"

# 断言 4：如果后续仍因 lowering-missing reject，frontier 必须是非 print body。
if grep -q 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' "$HW_NATIVE_ERR"; then
    if ! grep -Eq 'native_hosted_pending_body_frontier: function=(get_argc|get_argv|platform_|runtime_)' "$HW_NATIVE_ERR"; then
        echo "error: lowering-missing remains but frontier is not a known non-print pending body" >&2
        echo "----- stderr -----" >&2
        cat "$HW_NATIVE_ERR" >&2
        echo "----- end -----" >&2
        exit 1
    fi
    echo "L994.B OK: print lowering is complete; later non-print pending body still blocks native executable writer"
    exit 0
fi

echo "OK: hosted native HIR print lowering registered main body to MIR (L994.B green)"
