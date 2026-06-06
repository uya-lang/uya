#!/usr/bin/env bash

# Phase 5A/6 L393/L444：验证 C99 发射阶段为"已收口的 unit 流式写"——
# emitter 启动快照之后，全部"边生成边补发"待输出表（string/slice/simd/embed/embed_dir，
# 以及既有 mono/err_union/async_frame）在整个原型 + 函数体发射期间不再增长。
#
# 断言分三部分：
#   A. 收敛性：对一组代表性输入（含自举编译器 src/main.uya 这一 1 秒硬目标本体，
#      以及覆盖 string/slice/simd/embed/err_union/async 各待输出表的测试）在
#      UYA_STRICT_C99_EMITTER=1 下编译，必须成功（rc=0）——证明发射期间零漂移。
#   B. 非空转：用 UYA_C99_EMITTER_SELFTEST_DRIFT=1 在快照后注入一次真实漂移，
#      strict 模式下编译必须失败（rc!=0）且打印漂移诊断——证明门禁确实会触发。
#   C. 默认不致命：仅注入漂移而不开 strict 时，编译仍成功（rc=0）但打印漂移告警，
#      保证门禁是显式 opt-in、不影响正常构建。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UYA_BIN="$REPO_ROOT/bin/uya"
export UYA_ROOT="$REPO_ROOT/lib/"

if [[ ! -x "$UYA_BIN" ]]; then
    echo "错误: 缺少可执行 $UYA_BIN（先运行 make uya）" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d /tmp/uya-c99-emitter-streaming.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

# 代表性输入："相对路径|额外 flags"。覆盖各待输出表的真实发射路径。
INPUTS=(
    "src/main.uya|--nostdlib --safety-proof"                 # 1 秒硬目标本体；6000+ 字符串、err_union
    "tests/test_embed_builtin.uya|"                          # @embed 二进制常量 + 目录表 + 切片结构体
    "tests/test_json_to_json_reflect.uya|"                   # 反射式 codegen：simd 结构体 + mono
    "tests/test_json_from_json_reflect.uya|"                 # 反射式 codegen：大量 mono/err_union
    "tests/test_string_interp_one.uya|"                      # 字符串插值（内联 fmt，不应污染字符串池）
    "tests/test_async_frame_type.uya|"                       # async frame 元数据
)

fail=0

echo "=== A. 收敛性：strict 模式下代表性输入零漂移 ==="
for entry in "${INPUTS[@]}"; do
    rel="${entry%%|*}"
    flags="${entry#*|}"
    src="$REPO_ROOT/$rel"
    if [[ ! -f "$src" ]]; then
        echo "  跳过（缺失）: $rel"
        continue
    fi
    out="$TMP_DIR/$(echo "$rel" | tr '/.' '__').c"
    # shellcheck disable=SC2086
    if UYA_STRICT_C99_EMITTER=1 "$UYA_BIN" "$src" -o "$out" --c99 $flags \
            >"$TMP_DIR/a.out" 2>"$TMP_DIR/a.err"; then
        echo "  ✓ $rel（strict 收敛）"
    else
        echo "  ✗ $rel：strict 模式编译失败（发射阶段出现待输出表漂移）" >&2
        grep -E "UYA_C99_EMITTER" "$TMP_DIR/a.err" | head -3 >&2 || true
        fail=1
    fi
done

echo "=== B. 非空转：注入漂移后 strict 必须失败 ==="
SELF_SRC="$REPO_ROOT/tests/test_string_interp_one.uya"
if UYA_C99_EMITTER_SELFTEST_DRIFT=1 UYA_STRICT_C99_EMITTER=1 \
        "$UYA_BIN" "$SELF_SRC" -o "$TMP_DIR/selftest_strict.c" --c99 \
        >"$TMP_DIR/b.out" 2>"$TMP_DIR/b.err"; then
    echo "  ✗ 注入漂移后 strict 仍成功——门禁空转，未检出发射阶段漂移" >&2
    fail=1
else
    if grep -Eq "emitter 阶段待输出表漂移" "$TMP_DIR/b.err"; then
        echo "  ✓ 门禁检出注入漂移并失败（非空转）"
    else
        echo "  ✗ strict 失败但缺少预期漂移诊断" >&2
        cat "$TMP_DIR/b.err" >&2
        fail=1
    fi
fi

echo "=== C. 默认不致命：仅注入漂移、不开 strict 时编译成功但告警 ==="
if UYA_C99_EMITTER_SELFTEST_DRIFT=1 \
        "$UYA_BIN" "$SELF_SRC" -o "$TMP_DIR/selftest_warn.c" --c99 \
        >"$TMP_DIR/c.out" 2>"$TMP_DIR/c.err"; then
    if grep -Eq "emitter 阶段待输出表漂移" "$TMP_DIR/c.err"; then
        echo "  ✓ 非 strict 下漂移仅告警、编译成功"
    else
        echo "  ✗ 非 strict 下注入漂移却无告警" >&2
        fail=1
    fi
else
    echo "  ✗ 非 strict 下注入漂移不应导致编译失败" >&2
    fail=1
fi

if [[ "$fail" -ne 0 ]]; then
    echo "✗ C99 emitter streaming 验证失败" >&2
    exit 1
fi

echo "✓ C99 emitter streaming 收口验证通过（代表性输入零漂移 + 门禁非空转 + 默认 opt-in）"
