#!/usr/bin/env bash
# 验证「白名单冻结闸门」自身的双向语义（docs/unsafe_audit_plan.md §3 / 目标 (1)）：
#   * 实际 > 基线（同一 kind,file）           → 失败
#   * 实际出现基线没有的 (kind,file)          → 失败
#   * 实际 < 基线，或基线里的 (kind,file) 消失 → 只提示可收紧，**不失败**
# 用真编译器扫出的当前实际值做输入，只在**临时文件**上做加减/删除，
# 绝不碰 docs/unsafe_baseline.txt。
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$ROOT_DIR/tests/verify_unsafe_audit.sh"
export UYA_ROOT="${UYA_ROOT:-$ROOT_DIR/lib}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 一次真实扫描得到当前实际值（--update 写到临时文件）。
UYA_AUDIT_BASELINE="$TMP/current.tsv" "$GATE" --update >/dev/null
REC="$(awk -F'\t' '!/^#/ && $3 >= 2 {print; exit}' "$TMP/current.tsv")"
[[ -n "$REC" ]] || { echo '[audit-gate-test] FAIL: 实际审计面里没有 count>=2 的组' >&2; exit 1; }
KIND="$(printf '%s' "$REC" | cut -f1)"
FILE="$(printf '%s' "$REC" | cut -f2)"
N="$(printf '%s' "$REC" | cut -f3)"
echo "[audit-gate-test] 选中真实组: $KIND $FILE $N"

AWK_MUTATE='
BEGIN { OFS="\t" }
!/^#/ && $1==k && $2==f {
    if (mode=="act_down") { $3=n-1; print; next }
    if (mode=="base_down") { $3=n-1; print; next }
    if (mode=="remove") { next }
}
{ print }
'

make_inputs() {
    case "$1" in
        same|baseline_less)
            cp "$TMP/current.tsv" "$TMP/act.tsv" ;;
        actual_less)
            awk -F'\t' -v k="$KIND" -v f="$FILE" -v n="$N" -v mode=act_down \
                "$AWK_MUTATE" "$TMP/current.tsv" > "$TMP/act.tsv" ;;
        gone)
            awk -F'\t' -v k="$KIND" -v f="$FILE" -v mode=remove \
                "$AWK_MUTATE" "$TMP/current.tsv" > "$TMP/act.tsv" ;;
        new)
            { cat "$TMP/current.tsv"; printf 'ptr_cast\t__uya_gate_semantics_fixture__.uya\t1\n'; } > "$TMP/act.tsv" ;;
        *) echo "unknown case $1" >&2; exit 1 ;;
    esac
    if [[ "$1" == "baseline_less" ]]; then
        awk -F'\t' -v k="$KIND" -v f="$FILE" -v n="$N" -v mode=base_down \
            "$AWK_MUTATE" "$TMP/current.tsv" > "$TMP/base.tsv"
    else
        cp "$TMP/current.tsv" "$TMP/base.tsv"
    fi
}

run_case() {
    local mode="$1" expected_rc="$2" needle="$3"
    make_inputs "$mode"
    set +e
    OUT="$(UYA_AUDIT_BASELINE="$TMP/base.tsv" UYA_AUDIT_ACTUAL="$TMP/act.tsv" "$GATE" 2>&1)"
    local rc=$?
    set -e
    if [[ "$rc" != "$expected_rc" ]]; then
        echo "[audit-gate-test] FAIL: $mode 期望 rc=$expected_rc，实得 rc=$rc" >&2
        printf '%s\n' "$OUT" | tail -5 >&2
        exit 1
    fi
    if ! printf '%s' "$OUT" | grep -F "$needle" >/dev/null; then
        echo "[audit-gate-test] FAIL: $mode 输出里缺少 '$needle'" >&2
        printf '%s\n' "$OUT" | tail -5 >&2
        exit 1
    fi
    echo "[audit-gate-test] ✓ $mode: rc=$rc，命中 '$needle'"
}

run_case same           0 '基线一致'
run_case actual_less    0 '可收紧'
run_case gone           0 '可收紧'
run_case baseline_less  1 '逃逸口增加'
run_case new            1 '新增逃逸口'
