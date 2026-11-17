#!/usr/bin/env bash
# verify_strict_loop_bounds.sh - `--strict-loop-bounds` 的判定矩阵
#
# 背景（buglist P0「数组边界证明对循环里被改写的变量完全不生效」）：
# 默认模式下 `var i = 0; while i < 5 { items[i] }`（items: [i32: 4]）会编译通过，
# 因为循环体只按**进入循环前的约束**检查一遍（`i == 0` 恰好安全），
# 真正越界的第 5 次迭代从来没被检查。
#
# `--strict-loop-bounds` 把循环体里被赋值的变量的上界作废（下界在「只会往上加」时
# 保留），于是同一段代码会正确报错。本脚本把这张判定矩阵钉住：
#
#   用例                         默认    严格
#   while i < 3 (size 4)         通过    通过    # 真安全的循环不能被误杀
#   while i < 4 (size 4)         通过    通过
#   while i < 5 (size 4)         通过    **报错**  # 就是这个洞
#   while i < 10 (size 4)        通过    **报错**
#   while i < 100 之后再用 i      通过    **报错**
#   初值 -5 的循环               报错    报错
#
# 只断言「编译过 / 没编译过」，不校验文案（文案会变，判定不该跟着变）。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UYA_BIN="${UYA_BIN:-$ROOT_DIR/bin/uya}"
export UYA_ROOT="${UYA_ROOT:-$ROOT_DIR/lib}"

[[ -x "$UYA_BIN" ]] || { echo "缺少编译器: $UYA_BIN（先 make uya）" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail=0

# make_case <文件名> <循环上界> [初值]
make_case() {
    local file="$1" bound="$2"
    {
        echo 'export fn main() i32 {'
        echo '    var items: [i32: 4] = [0, 0, 0, 0];'
        echo '    var i: i32 = 0;'
        echo "    while i < $bound {"
        echo '        items[i] = i;'
        echo '        i = i + 1;'
        echo '    }'
        echo '    return 0;'
        echo '}'
    } > "$file"
}

# make_after_case <文件名> <循环上界>：循环之后再用 i 索引
make_after_case() {
    local file="$1" bound="$2"
    {
        echo 'export fn main() i32 {'
        echo '    var items: [i32: 4] = [0, 0, 0, 0];'
        echo '    var i: i32 = 0;'
        echo "    while i < $bound {"
        echo '        i = i + 1;'
        echo '    }'
        echo '    items[i] = 1;'
        echo '    return 0;'
        echo '}'
    } > "$file"
}

# expect <标签> <期望: pass|fail> <文件> [额外参数...]
expect() {
    local label="$1" want="$2" file="$3"
    shift 3
    local got=pass
    if ! "$UYA_BIN" check --safety-proof "$@" "$file" >/dev/null 2>&1; then
        got=fail
    fi
    if [[ "$got" != "$want" ]]; then
        printf '[strict-loop-bounds] FAIL: %s —— 期望 %s，实际 %s\n' "$label" "$want" "$got" >&2
        fail=$((fail + 1))
        return 0
    fi
    printf '[strict-loop-bounds] ✓ %s (%s)\n' "$label" "$got"
}

for bound in 3 4; do
    make_case "$WORK/ok_$bound.uya" "$bound"
    expect "默认 i<$bound（真安全）" pass "$WORK/ok_$bound.uya"
    expect "严格 i<$bound（真安全，不得误杀）" pass "$WORK/ok_$bound.uya" --strict-loop-bounds
done

for bound in 5 10; do
    make_case "$WORK/bad_$bound.uya" "$bound"
    expect "默认 i<$bound（已知缺口：默认放行）" pass "$WORK/bad_$bound.uya"
    expect "严格 i<$bound（越界必须报错）" fail "$WORK/bad_$bound.uya" --strict-loop-bounds
done

make_after_case "$WORK/after_loop.uya" 100
expect "默认循环后用 i（已知缺口）" pass "$WORK/after_loop.uya"
expect "严格循环后用 i（必须报错）" fail "$WORK/after_loop.uya" --strict-loop-bounds

if [[ "$fail" -ne 0 ]]; then
    printf '[strict-loop-bounds] %d 项不符合预期\n' "$fail" >&2
    exit 1
fi
echo '[strict-loop-bounds] 判定矩阵全部符合预期 ✓'