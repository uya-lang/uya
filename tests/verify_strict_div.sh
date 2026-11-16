#!/usr/bin/env bash
# verify_strict_div.sh - 验证 `--strict-div` 除零正确性证明（规范 §14.2）
#
# B3 收口后该闸门**默认开启**，断言四件事：
#   1. 默认模式下，无法证明非零的除数必须编译失败（闸门是开的）；
#   2. `--no-strict-div` 显式关闭后，同一份夹具必须编译通过（逃生阀有效）；
#   3. 默认模式下，有区间守卫 / 早返回判零 / 常量除数必须编译通过
#      —— 防止把证明器收紧到误报；
#   4. 常量除零无论开关都必须报错（常量折叠路径，与 --strict-div 无关）。
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

# 1) 默认模式：负例夹具必须编译失败（证明该闸门默认是开启的）
if "$UYA_BIN" check "$NEG_FIXTURE" >/dev/null 2>&1; then
    fail "默认模式下 $NEG_FIXTURE 仍然编译通过 —— 除零闸门没有默认开启"
fi
log "默认模式拒绝无证明的除数（--strict-div 默认开启）✓"

# 2) --no-strict-div：同一份负例必须放行（逃生阀）
if "$UYA_BIN" check --no-strict-div "$NEG_FIXTURE" >/dev/null 2>&1; then
    log "--no-strict-div 放行 ✓"
else
    fail "--no-strict-div 未能关闭闸门 —— 逃生阀失效"
fi

# 3) 默认模式：正例（常量除数 / 区间守卫 / try 路径）必须通过
if "$UYA_BIN" check "$POS_FIXTURE" >/dev/null 2>&1; then
    log "默认模式放行常量与区间守卫 ✓"
else
    fail "默认模式下 $POS_FIXTURE 被误报 —— 证明器收紧过度"
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
