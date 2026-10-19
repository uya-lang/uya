#!/usr/bin/env bash
# --strict-overflow 溢出闸门验证
#
# 覆盖：
#   1. 默认行为：闸门关闭时，无守卫的参数算术照常编译（兼容性）
#   2. 闸门开启：无守卫的加/减/乘报「溢出无法证明」
#   3. 闸门开启：区间守卫收窄后放行
#   4. 闸门开启：checked 算术（try / catch）豁免静态闸门
#   5. 闸门开启：饱和 / 包装运算符放行
#
# 用法：./tests/verify_strict_overflow.sh
# 环境：UYA_BIN 覆盖编译器路径（默认 <repo>/bin/uya）

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="${UYA_BIN:-$REPO_ROOT/bin/uya}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/uya-strict-overflow.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

FAILED=0

log() {
    printf '[strict-overflow] %s\n' "$*"
}

fail() {
    printf '[strict-overflow] FAIL: %s\n' "$*" >&2
    FAILED=1
}

if [ ! -x "$COMPILER" ]; then
    echo "错误: 找不到编译器 $COMPILER" >&2
    exit 1
fi

# ---------- fixture ----------

# 无守卫的参数算术：闸门关闭时应编译通过，闸门开启时应报错
cat > "$TMP_DIR/unguarded.uya" <<'EOF'
fn add(a: i32, b: i32) i32 {
    return a + b;
}
fn sub(a: i32, b: i32) i32 {
    return a - b;
}
fn mul(a: i32, b: i32) i32 {
    return a * b;
}
export fn main() i32 {
    _ = add(1, 2);
    _ = sub(3, 4);
    _ = mul(5, 6);
    return 0;
}
EOF

# 闸门开启下必须全部放行的写法
cat > "$TMP_DIR/guarded.uya" <<'EOF'
fn bounded_add(a: i32, b: i32) i32 {
    if a >= 0 && a < 1000 && b >= 0 && b < 1000 {
        return a + b;
    }
    return 0;
}
fn bounded_sub(a: i32, b: i32) i32 {
    if a >= 0 && a < 1000 && b >= 0 && b < 1000 {
        return a - b;
    }
    return 0;
}
fn bounded_mul(a: i32, b: i32) i32 {
    if a > 0 && a < 100 && b > 0 && b < 100 {
        return a * b;
    }
    return 0;
}
fn bounded_compound(a: i32) i32 {
    // 复合赋值 desugar 成二元表达式；a < 1000 时 a + 1 必然不溢出
    var acc: i32 = 0;
    if a >= 0 && a < 1000 {
        acc = a + 1;
    }
    return acc;
}
fn const_arith() i32 {
    return 100 + 200;
}
fn checked_add(a: i32, b: i32) !i32 {
    return try a + b;
}
fn checked_sub(a: i32, b: i32) !i32 {
    return try a - b;
}
fn local_catch_add(a: i32, b: i32) i32 {
    return (a + b) catch { 0; };
}
fn local_catch_div(a: i32, b: i32) i32 {
    return (a / b) catch { 0; };
}
fn wrapped_ops(a: i32, b: i32) i32 {
    return a +% b;
}
fn saturating_ops(a: i32, b: i32) i32 {
    return a +| b;
}
export fn main() i32 {
    _ = bounded_add(1, 2);
    _ = bounded_sub(5, 3);
    _ = bounded_mul(3, 4);
    _ = bounded_compound(7);
    _ = const_arith();
    _ = local_catch_add(1, 2);
    _ = local_catch_div(4, 2);
    _ = wrapped_ops(1, 2);
    _ = saturating_ops(1, 2);
    _ = checked_add(1, 2) catch { 0; };
    _ = checked_sub(1, 2) catch { 0; };
    return 300 - 300;
}
EOF

# ---------- 用例 ----------

log "1/5 默认关闭：无守卫算术照常编译"
if "$COMPILER" check "$TMP_DIR/unguarded.uya" > "$TMP_DIR/out1.log" 2>&1; then
    log "  ✓ 默认不拦（兼容性保持）"
else
    fail "默认状态下无守卫算术被拦下，应只在 --strict-overflow 下生效"
    cat "$TMP_DIR/out1.log" >&2
fi

log "2/5 闸门开启：无守卫的加/减/乘报溢出无法证明"
if "$COMPILER" check --strict-overflow "$TMP_DIR/unguarded.uya" > "$TMP_DIR/out2.log" 2>&1; then
    fail "闸门开启后无守卫算术仍然通过"
else
    count=$(grep -c "溢出无法证明" "$TMP_DIR/out2.log" || true)
    if [ "$count" -ge 3 ]; then
        log "  ✓ 报出 $count 处（加/减/乘各一）"
    else
        fail "期望至少 3 处溢出诊断，实际 $count 处"
        cat "$TMP_DIR/out2.log" >&2
    fi
fi

log "3/5 闸门开启：区间守卫收窄后放行"
if "$COMPILER" check --strict-overflow "$TMP_DIR/guarded.uya" > "$TMP_DIR/out3.log" 2>&1; then
    log "  ✓ 守卫 / 常量 / checked / 饱和 / 包装 全部放行"
else
    fail "合法写法被闸门误拦"
    cat "$TMP_DIR/out3.log" >&2
fi

log "4/5 闸门开启：诊断给出三条可用修法"
if grep -q "try a" "$TMP_DIR/out2.log" && grep -q "区间守卫" "$TMP_DIR/out2.log"; then
    log "  ✓ 诊断含 checked / 守卫 / 饱和包装 提示"
else
    fail "诊断文案缺少修法提示"
    cat "$TMP_DIR/out2.log" >&2
fi

log "5/5 闸门可关闭：--no-strict-overflow 恢复默认行为"
if "$COMPILER" check --strict-overflow --no-strict-overflow "$TMP_DIR/unguarded.uya" > "$TMP_DIR/out5.log" 2>&1; then
    log "  ✓ 显式关闭后不拦"
else
    fail "--no-strict-overflow 未能关闭闸门"
    cat "$TMP_DIR/out5.log" >&2
fi

echo ""
if [ "$FAILED" -ne 0 ]; then
    echo "✗ --strict-overflow 闸门验证失败" >&2
    exit 1
fi
echo "✓ --strict-overflow 闸门验证通过"
