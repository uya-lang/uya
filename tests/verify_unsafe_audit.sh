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
# 允许测试用临时基线验证闸门语义（新增即失败 / 减少只提示），CI 默认仍用冻结基线。
BASELINE="${UYA_AUDIT_BASELINE:-$ROOT_DIR/docs/unsafe_baseline.txt}"
# 审计根：一行一个（# 开头为注释）。跨多个根取**并集**，因为编译器自己只会
# 导入它用到的模块 —— 只用 src/main.uya 一个根，标准库里 http / websocket /
# jpeg / kernel 那些模块根本不会被解析，它们的逃逸口就完全没进审计面。
ROOTS_FILE="$ROOT_DIR/docs/unsafe_audit_roots.txt"

fail() { printf '[unsafe-audit] FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[unsafe-audit] %s\n' "$*"; }

[[ -x "$UYA_BIN" ]] || fail "缺少编译器: $UYA_BIN"
[[ -f "$ROOTS_FILE" ]] || fail "缺少审计根清单: $ROOTS_FILE"

cd "$ROOT_DIR"
export UYA_ROOT="${UYA_ROOT:-$ROOT_DIR/lib}"

WORK_DIR="$(mktemp -d)"
ACTUAL="$WORK_DIR/actual.tsv"
trap 'rm -rf "$WORK_DIR"' EXIT

# 路径归一化：文件名由 parser 按调用方式决定，可能是 `src/x.uya`、`./lib/x.uya`
# 或绝对路径（取决于 UYA_ROOT 怎么给）。基线必须与调用方式无关，否则换一台机器
# 或换一个 UYA_ROOT 就整份 diff 爆炸。这里统一剥成「相对仓库根」的形式。
UYA_ROOT_ABS="$(cd "$UYA_ROOT" 2>/dev/null && pwd || echo "$UYA_ROOT")"
ROOT_ABS="$(cd "$ROOT_DIR" && pwd)"

# 把一个根的 --escape-list 原始输出归一化成 `kind<TAB>file<TAB>count`。
normalize() {
    grep '^\[escape\]' "$1" \
        | awk -v root="$ROOT_ABS" -v uroot="$UYA_ROOT_ABS" '{
            p = $3
            sub(/:[0-9]+$/, "", p)
            sub(/^\.\//, "", p)
            if (index(p, root "/") == 1) p = substr(p, length(root) + 2)
            else if (index(p, uroot "/") == 1) p = "lib/" substr(p, length(uroot) + 2)
            print $2 "\t" p
        }' \
        | sort | uniq -c | awk '{print $2"\t"$3"\t"$1}'
}

# 1) 逐个审计根跑 --escape-list，各自归一化，再按 (kind,file) 取**最大值**合并。
#
#    为什么是 max 而不是求和：同一个文件会出现在多个根的依赖闭包里，
#    而某个文件的逃逸口数量是该文件自身的属性 —— 不论从哪个根进去都一样。
#    求和会让计数成倍虚高；按行去重又会把「同一行里两个 `@usize_from_ptr`」
#    错误地并成一个（这些比较本来就爱写成一行）。取 max 两个坑都避开。
#
#    也**不能**在合并前剥行号：白名单按文件冻结，插一行注释就会让整份基线失效。
ROOT_N=0
FAILED_ROOTS=0
while IFS= read -r root; do
    [[ -z "$root" || "$root" == \#* ]] && continue
    [[ -f "$ROOT_DIR/$root" ]] || fail "审计根清单里的文件不存在: $root"
    ROOT_N=$((ROOT_N + 1))
    raw="$WORK_DIR/raw.$ROOT_N"
    if ! "$UYA_BIN" check --escape-list "$root" >/dev/null 2>"$raw"; then
        printf '[unsafe-audit] 审计根编译失败（无法审计）: %s\n' "$root" >&2
        FAILED_ROOTS=$((FAILED_ROOTS + 1))
        continue
    fi
    normalize "$raw" > "$WORK_DIR/cnt.$ROOT_N"
done < "$ROOTS_FILE"
[[ "$FAILED_ROOTS" -eq 0 ]] || fail "$FAILED_ROOTS 个审计根无法编译 —— 有模块是「从没被编译过」的状态，先修它"

awk -F'\t' '
    { k = $1 "\t" $2; if ($3 + 0 > m[k]) m[k] = $3 + 0 }
    END { for (k in m) { split(k, p, "\t"); print p[1] "\t" p[2] "\t" m[k] } }
' "$WORK_DIR"/cnt.* | sort > "$ACTUAL" \
    || fail "未能从 --escape-list 输出聚合出明细（输出格式变了？）"

SITES=$(awk -F'\t' '{ s += $3 } END { print s + 0 }' "$ACTUAL")
GROUP_N=$(wc -l < "$ACTUAL")
log "审计根 $ROOT_N 个，站点 $SITES 个，聚合为 $GROUP_N 个 (kind,file) 组"

# 1b) 覆盖闸门：源码里**含有**逃逸构造的文件，必须出现在本次审计结果里。
#
#     这一条挡的是「漏审计」而不是「逃逸口变多」：新写一个 lib/std/xxx.uya
#     带 extern fn，只要它没被任何审计根导入，上面的对比全都不会察觉 ——
#     白名单永远是「我看过的那些文件」，看不见的文件等于不存在。
#     所以分母用源码文本（不看编译器输出），差集非空就失败。
#
#     匹配前先剥掉注释：注释里写「`extern "libc" fn exp(...)` 这类没有实现体的
#     声明」不该被算成逃逸口（实测 `src/exec/hir.uya` 就是这么被误报的）。
#     剥注释的 awk 会跳过字符串字面量里的 `//`（`"http://"` 不会被截断）。
#     方法调用形态（`x.free()`）也不计入 —— 术语统计里 `alloc` 只认裸调用，
#     分母必须同一口径，否则「调用了带 free 方法的类型」会被当成逃逸文件。
strip_comments() {
    awk '{
        out = ""; q = 0; i = 1; n = length($0)
        while (i <= n) {
            c = substr($0, i, 1)
            if (c == "\\") { out = out c substr($0, i + 1, 1); i += 2; continue }
            if (c == "\"") { q = 1 - q; out = out c; i += 1; continue }
            if (q == 0 && c == "/" && substr($0, i + 1, 1) == "/") break
            out = out c; i += 1
        }
        print out
    }' "$1"
}

SRC_WITH_ESCAPES=$(
    for f in $(find "$ROOT_DIR/src" "$ROOT_DIR/lib" -name '*.uya' -not -path '*uyacache*' | sort); do
        # 这里**不能**用 `grep -q`：`set -o pipefail` 下 grep 命中后立刻退出会让
        # 上游 awk 吃到 SIGPIPE（退出码 141），整个管道被判成「没命中」——
        # 症状是「匹配位置靠前的文件凭空从分母里消失」（实测 42 个漏成 10 个）。
        if strip_comments "$f" | grep -E 'extern fn|extern var|extern "libc"|@asm|@ptr_from_usize|@usize_from_ptr|[^._a-zA-Z]malloc\(|[^._a-zA-Z]free\(' > /dev/null; then
            printf '%s\n' "${f#$ROOT_DIR/}"
        fi
    done | sort -u
)
AUDITED_FILES=$(awk -F'\t' '{ print $2 }' "$ACTUAL" | sort -u)
UNCOVERED=$(comm -23 <(printf '%s\n' "$SRC_WITH_ESCAPES") <(printf '%s\n' "$AUDITED_FILES") \
    | grep -v '^$' || true)
if [[ -n "$UNCOVERED" ]]; then
    printf '%s\n' "$UNCOVERED" | while IFS= read -r f; do
        printf '[unsafe-audit] 未被审计的逃逸文件: %s\n' "$f" >&2
    done
    fail "有 $(printf '%s\n' "$UNCOVERED" | wc -l) 个含逃逸构造的文件不在任何审计根的闭包里 —— 把它们加进 docs/unsafe_audit_roots.txt，或在白名单里显式豁免"
fi

# 测试专用：可把「实际」换成改过的一份，用于验证闸门双向语义（正常 CI 不设此变量）。
# 真实扫描与覆盖检查已经完成，这里只影响最后的对比。
if [[ -n "${UYA_AUDIT_ACTUAL:-}" ]]; then
    ACTUAL="$UYA_AUDIT_ACTUAL"
fi

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
