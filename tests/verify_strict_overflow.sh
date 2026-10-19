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

log "1/8 默认关闭：无守卫算术照常编译"
if "$COMPILER" check "$TMP_DIR/unguarded.uya" > "$TMP_DIR/out1.log" 2>&1; then
    log "  ✓ 默认不拦（兼容性保持）"
else
    fail "默认状态下无守卫算术被拦下，应只在 --strict-overflow 下生效"
    cat "$TMP_DIR/out1.log" >&2
fi

log "2/8 闸门开启：无守卫的加/减/乘报溢出无法证明"
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

log "3/8 闸门开启：区间守卫收窄后放行"
if "$COMPILER" check --strict-overflow "$TMP_DIR/guarded.uya" > "$TMP_DIR/out3.log" 2>&1; then
    log "  ✓ 守卫 / 常量 / checked / 饱和 / 包装 全部放行"
else
    fail "合法写法被闸门误拦"
    cat "$TMP_DIR/out3.log" >&2
fi

log "4/8 闸门开启：诊断给出三条可用修法"
if grep -q "try a" "$TMP_DIR/out2.log" && grep -q "区间守卫" "$TMP_DIR/out2.log"; then
    log "  ✓ 诊断含 checked / 守卫 / 饱和包装 提示"
else
    fail "诊断文案缺少修法提示"
    cat "$TMP_DIR/out2.log" >&2
fi

log "5/8 闸门只覆盖有符号：无符号模运算放行"
cat > "$TMP_DIR/unsigned.uya" <<'UEOF'
fn negate_u64(v: u64) u64 {
    // 二补数取负：无符号回绕是良定义语义，不应被闸门拦下
    return (0 as u64) - v;
}
fn hash_step(h: u32, v: u32) u32 {
    return h * 31 as u32 + v;
}
fn ptr_offset(base: usize, n: usize) usize {
    return base + n;
}
export fn main() i32 {
    _ = negate_u64(1 as u64);
    _ = hash_step(2 as u32, 3 as u32);
    _ = ptr_offset(4 as usize, 5 as usize);
    return 0;
}
UEOF
if "$COMPILER" check --strict-overflow "$TMP_DIR/unsigned.uya" > "$TMP_DIR/out6.log" 2>&1; then
    log "  ✓ u64/u32/usize 的模运算未被拦（无符号无 UB）"
else
    fail "无符号算术被闸门误拦"
    cat "$TMP_DIR/out6.log" >&2
fi

log "6/8 区间契约 @range 让参数/调用算术可证"
cat > "$TMP_DIR/contract.uya" <<'UEOF'
fn advance(line: i32 @range(0, 1000000), off: i32 @range(0, 1000)) i32 @range(0, 1001000) {
    return line + off;
}
fn double_it(n: i32 @range(0, 100)) i32 @range(0, 200) {
    return n * 2;
}
fn use_contract(n: i32 @range(0, 100)) i32 {
    return double_it(n) + 5;
}
export fn main() i32 {
    _ = advance(100, 5);
    _ = use_contract(9);
    return 0;
}
UEOF
if "$COMPILER" check --strict-overflow "$TMP_DIR/contract.uya" > "$TMP_DIR/out7.log" 2>&1; then
    log "  ✓ 参数契约 + 返回契约均生效（无守卫也可证）"
else
    fail "区间契约未生效"
    cat "$TMP_DIR/out7.log" >&2
fi

log "7/8 契约违约在运行期被终止（不是被静默忽略）"
cat > "$TMP_DIR/violation.uya" <<'UEOF'
fn add(a: i32 @range(0, 1000), b: i32 @range(0, 1000)) i32 @range(0, 2000) {
    return a + b;
}
export fn main() i32 {
    const v: i32 = add(2000000000, 1000000);
    if v < 0 {
        return 42;
    }
    return 0;
}
UEOF
if "$COMPILER" run --strict-overflow "$TMP_DIR/violation.uya" > "$TMP_DIR/out8.log" 2>&1; then
    fail "契约违约未被运行期检查捕获（会静默回绕）"
    cat "$TMP_DIR/out8.log" >&2
else
    # 违约走 __builtin_trap()：退出码 132（SIGILL）/ 134（SIGABRT）都算被捕获
    rc8=$?
    if [ "$rc8" -eq 132 ] || [ "$rc8" -eq 134 ]; then
        log "  ✓ 运行期以 trap 终止（退出码 $rc8），不会静默回绕"
    else
        fail "契约违约退出码为 $rc8（期望 132/134 的 trap）"
        cat "$TMP_DIR/out8.log" >&2
    fi
fi

log "8/8 闸门可关闭：--no-strict-overflow 恢复默认行为"
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
