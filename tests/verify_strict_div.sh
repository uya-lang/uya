#!/usr/bin/env bash
# verify_strict_div.sh - 验证 `--strict-div` 除零正确性证明（规范 §14.2）
#
# 断言三件事：
#   1. 默认（--strict-div 关闭）下，依赖「调用方保证非零」的除法仍然编译通过
#      —— 否则存量代码会被这条闸门砸坏；
#   2. --strict-div 下，无法证明非零的除数必须编译失败；
#   3. --strict-div 下，有区间守卫的除数与常量除数必须仍然编译通过
#      —— 防止把证明器收紧到误报。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UYA_BIN="${UYA_BIN:-$ROOT_DIR/bin/uya}"
NEG_FIXTURE="tests/repros/strict_div_negative.uya"
POS_FIXTURE="tests/test_strict_div.uya"

fail() {
    printf '[strict-div] FAIL: %s\n' "$*" >&2
    exit 1
}

log() {
    printf '[strict-div] %s\n' "$*"
}

[[ -x "$UYA_BIN" ]] || fail "缺少编译器: $UYA_BIN"
[[ -f "$ROOT_DIR/$NEG_FIXTURE" ]] || fail "缺少负例夹具: $NEG_FIXTURE"
[[ -f "$ROOT_DIR/$POS_FIXTURE" ]] || fail "缺少正例夹具: $POS_FIXTURE"

cd "$ROOT_DIR"
export UYA_ROOT="${UYA_ROOT:-$ROOT_DIR/lib}"

# 1) 默认模式：负例夹具应当编译通过（证明该闸门默认是关闭的）
if "$UYA_BIN" check "$NEG_FIXTURE" >/dev/null 2>&1; then
    log "默认模式放行（--strict-div 默认关闭）✓"
else
    fail "默认模式下 $NEG_FIXTURE 就报错了 —— 除零闸门不该默认开启（会砸坏存量库）"
fi

# 2) --strict-div：负例必须编译失败
if "$UYA_BIN" check --strict-div "$NEG_FIXTURE" >/dev/null 2>&1; then
    fail "--strict-div 下 $NEG_FIXTURE 仍然编译通过 —— 除零证明没有生效"
fi
log "--strict-div 拒绝无证明的除数 ✓"

# 3) --strict-div：正例（常量除数 / 区间守卫 / try 路径）必须通过
if "$UYA_BIN" check --strict-div "$POS_FIXTURE" >/dev/null 2>&1; then
    log "--strict-div 放行常量与区间守卫 ✓"
else
    fail "--strict-div 下 $POS_FIXTURE 被误报 —— 证明器收紧过度"
fi

# 4) 常量除零无论开关都必须报错（常量折叠路径，与 --strict-div 无关）
const_zero_tmp="$(mktemp "${TMPDIR:-/tmp}/uya-strict-div-const.XXXXXX.uya")"
trap 'rm -f "$const_zero_tmp"' EXIT
cat >"$const_zero_tmp" <<'UYA'
export fn main() i32 {
    const a: i32 = 100 / 0;
    return a;
}
UYA
if "$UYA_BIN" check "$const_zero_tmp" >/dev/null 2>&1; then
    fail "常量表达式除零没有报错 —— 常量折叠路径出错"
fi
log "常量除零始终报错 ✓"

log "全部通过"
