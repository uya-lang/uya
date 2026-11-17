#!/usr/bin/env bash
# verify_unsafe_audit.sh - 逃逸口白名单闸门（docs/unsafe_audit_plan.md §3）
#
# 目的：把「不安全之处必须显式」变成一条会失败的检查。编译器用
# `--escape-list` 逐站点列出所有能绕过证明的构造（extern / @asm / union /
# 指针↔整数 / 分配器调用），本脚本把它聚合成 `kind<TAB>file<TAB>count`
# 并与冻结基线 docs/unsafe_baseline.txt 对比。
#
# 判定（**刻意非对称**）：
#   1. 实际出现、基线里没有的 (kind,file) → **失败**（新增逃逸口必须评审）；
#   2. 实际数量 **大于** 基线 → **失败**（同一文件里悄悄多开逃逸口）；
#   3. 实际数量 **小于** 基线、或 (kind,file) 消失 → 只提示「可收紧基线」，**不失败**。
#
# 为什么 3 不失败：基线偏松只是「白名单留了余量」（报告数字偏大，不是安全漏洞），
# 而基线偏紧（规则 1/2）才是真正被挡住的东西。若把「可收紧」也算失败，日常重构
# 会让 make check 常年红灯，最后所有人都会无脑重生成基线 —— 闸门就废了。
# 反过来说：任何**新增**都过不去，这正是我们要守住的那条线。
#
# 用法：
#   ./tests/verify_unsafe_audit.sh              # 闸门（CI / make check 用）
#   ./tests/verify_unsafe_audit.sh --update     # 重新冻结基线（需在评审里解释 diff）
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UYA_BIN="${UYA_BIN:-$ROOT_DIR/bin/uya}"
BASELINE="$ROOT_DIR/docs/unsafe_baseline.txt"
AUDIT_ROOT="src/main.uya"

fail() { printf '[unsafe-audit] FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[unsafe-audit] %s\n' "$*"; }

[[ -x "$UYA_BIN" ]] || fail "缺少编译器: $UYA_BIN"
[[ -f "$ROOT_DIR/$AUDIT_ROOT" ]] || fail "缺少审计根: $AUDIT_ROOT"

cd "$ROOT_DIR"
export UYA_ROOT="${UYA_ROOT:-$ROOT_DIR/lib}"

RAW="$(mktemp)"
ACTUAL="$(mktemp)"
trap 'rm -f "$RAW" "$ACTUAL"' EXIT

# 1) 逐站点明细 → 按 (kind, file) 聚合。行号剥掉：白名单按文件冻结，
#    否则每次插入一行注释都会让整份基线失效。
"$UYA_BIN" check --escape-list "$AUDIT_ROOT" >/dev/null 2>"$RAW" \
    || fail "编译器在 --escape-list 模式下失败（先修编译错误再谈审计）"

# 路径归一化：文件名由 parser 按调用方式决定，可能是 `src/x.uya`、`./src/x.uya`
# 或绝对路径（取决于 UYA_ROOT 怎么给）。基线必须与调用方式无关，否则换一台机器
# 或换一个 UYA_ROOT 就整份 diff 爆炸。这里统一剥成「相对仓库根」的形式。
UYA_ROOT_ABS="$(cd "$UYA_ROOT" 2>/dev/null && pwd || echo "$UYA_ROOT")"
ROOT_ABS="$(cd "$ROOT_DIR" && pwd)"

grep '^\[escape\]' "$RAW" \
    | awk -v root="$ROOT_ABS" -v uroot="$UYA_ROOT_ABS" '{
        p = $3
        sub(/:[0-9]+$/, "", p)                       # 去掉行号
        sub(/^\.\//, "", p)                          # 去掉 ./ 前缀
        if (index(p, root "/") == 1) p = substr(p, length(root) + 2)
        else if (index(p, uroot "/") == 1) p = "lib/" substr(p, length(uroot) + 2)
        print $2 "\t" p
    }' \
    | sort | uniq -c | awk '{print $2"\t"$3"\t"$1}' > "$ACTUAL" \
    || fail "未能从 --escape-list 输出聚合出明细（输出格式变了？）"

SITES=$(grep '^\[escape\]' "$RAW" | wc -l)
GROUP_N=$(wc -l < "$ACTUAL")
log "站点 $SITES 个，聚合为 $GROUP_N 个 (kind,file) 组"

if [[ "${1:-}" == "--update" ]]; then
    {
        printf '# Uya 逃逸口冻结基线（docs/unsafe_audit_plan.md §3）\n'
        printf '# 格式: kind<TAB>file<TAB>count；由 tests/verify_unsafe_audit.sh --update 生成。\n'
        printf '# 新增或增加 -> 闸门失败；减少 -> 提示收紧，不失败。\n'
        cat "$ACTUAL"
    } > "$BASELINE"
    log "已更新 $BASELINE（$GROUP_N 组）。请把这份 diff 放进评审说明。"
    exit 0
fi

[[ -f "$BASELINE" ]] || fail "缺少基线 $BASELINE（先运行 ./tests/verify_unsafe_audit.sh --update）"

# 2) 对比。awk 一次读两份表，输出三类差异。
#    每条记录固定 5 段：动作<TAB>kind<TAB>file<TAB>实际<TAB>基线
#    （早期版本把 kind 和 file 拼成一个字段，read 按 TAB 切分时顺序错位，
#      打出 "alloc 4 2 -> src/arena.uya" 这种读不懂的行 —— 段数必须钉死。）
REPORT=$(awk -F'\t' '
    function emit(tag, k, a, b,   p) { split(k, p, "\t"); printf "%s\t%s\t%s\t%d\t%d\n", tag, p[1], p[2], a, b }
    FNR==NR { if ($0 !~ /^#/ && NF==3) base[$1"\t"$2] = $3 + 0; next }
    $0 !~ /^#/ && NF==3 { seen[$1"\t"$2] = 1; act[$1"\t"$2] = $3 + 0 }
    END {
        for (k in act) {
            if (!(k in base)) { emit("NEW", k, act[k], 0); continue }
            if (act[k] > base[k]) { emit("UP", k, act[k], base[k]); continue }
            if (act[k] < base[k]) emit("DOWN", k, act[k], base[k]);
        }
        for (k in base) if (!(k in seen)) emit("GONE", k, 0, base[k]);
    }
' "$BASELINE" "$ACTUAL" | sort)

NEW_COUNT=$(printf '%s\n' "$REPORT" | grep -c '^NEW' || true)
UP_COUNT=$(printf '%s\n' "$REPORT" | grep -c '^UP' || true)
SLACK_COUNT=$(printf '%s\n' "$REPORT" | grep -cE '^(DOWN|GONE)' || true)

if [[ "$SLACK_COUNT" -gt 0 ]]; then
    log "可收紧（不失败）：$SLACK_COUNT 组少于基线 —— 运行 --update 让基线跟上"
fi

if [[ "$NEW_COUNT" -gt 0 || "$UP_COUNT" -gt 0 ]]; then
    printf '%s\n' "$REPORT" | grep -E '^(NEW|UP)' | while IFS=$'\t' read -r tag kind file actual base_n; do
        case "$tag" in
            NEW) printf '[unsafe-audit] 新增逃逸口: %s %s（%s 处）\n' "$kind" "$file" "$actual" >&2 ;;
            UP)  printf '[unsafe-audit] 逃逸口增加: %s %s  %s -> %s\n' "$kind" "$file" "$base_n" "$actual" >&2 ;;
        esac
    done
    fail "检测到 $NEW_COUNT 组新增、$UP_COUNT 组增加；新增不安全面必须在评审中显式确认，确属必要时运行 --update 并解释 diff"
fi

log "基线一致：未新增任何逃逸口 ✓"
