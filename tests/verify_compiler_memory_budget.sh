#!/usr/bin/env bash

# Phase 5A 内存回归脚本：验证 1 秒冷构建 benchmark 的内存预算契约。
# - benchmark TSV 必须包含内存字段（peak_rss_kb / arena / 动态表）。
# - 缺少 RSS 采样时不能误报内存达标。
# - arena 字段存在且为非负整数。
# - 动态表字段存在且为非负整数。
#
# 使用 fake make 驱动真实 scripts/bench_compiler_1s.sh，避免触发真实冷构建。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-compiler-memory-budget.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ ! -f "$REPO_ROOT/scripts/bench_compiler_1s.sh" ]]; then
    echo "错误: 缺少 $REPO_ROOT/scripts/bench_compiler_1s.sh" >&2
    exit 1
fi

# 在隔离的 fixture repo 中运行 benchmark：benchmark 以自身脚本位置推导 REPO_ROOT，
# fake make 的 `make -C <repo>` 因此只会写入 fixture，绝不触碰真实仓库产物。
FIXTURE_REPO="$TMP_DIR/repo"
mkdir -p "$FIXTURE_REPO/scripts" "$FIXTURE_REPO/bin" "$FIXTURE_REPO/src/build" "$FIXTURE_REPO/src/.uyacache"
cp "$REPO_ROOT/scripts/bench_compiler_1s.sh" "$FIXTURE_REPO/scripts/bench_compiler_1s.sh"
chmod +x "$FIXTURE_REPO/scripts/bench_compiler_1s.sh"
BENCH_SCRIPT="$FIXTURE_REPO/scripts/bench_compiler_1s.sh"

EXPECTED_HEADER=$'run\tmode\tseed_ms\tparse_ms\tbind_ms\tcheck_ms\tlower_ms\temit_ms\tlink_ms\ttotal_ms\tpeak_rss_kb\tarena_peak_bytes\toutput_bytes\tc99_output_buffer_peak_bytes\ttable_count\ttable_capacity\ttable_bytes\ttable_capacity_bytes\ttable_realloc_count'

# fake make：输出与真实编译器一致的 arena / 动态表统计字段，并按需生成产物。
FAKE_MAKE="$TMP_DIR/fake_make.sh"
cat >"$FAKE_MAKE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
repo_root=""
target=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -C) repo_root="$2"; shift 2 ;;
        *) target="$1"; shift ;;
    esac
done
if [[ -z "$target" ]]; then
    echo "fake_make: missing target" >&2
    exit 2
fi
echo "fake make $target"
if [[ "$target" == "uya" ]]; then
    echo "解析耗时: 11 ms"
    echo "合并耗时: 2 ms"
    echo "检查耗时: 13 ms"
    echo "生成耗时: 17 ms"
    echo "arena_peak_bytes: 4096"
    echo "c99_output_buffer_peak_bytes: 65536"
    echo "typed_program_bytes: 2048"
    echo "typed_program_peak_bytes: 8192"
    echo "typed_program_released_bytes: 0"
    echo "table_count: 3"
    echo "table_capacity: 8"
    echo "table_bytes: 96"
    echo "table_capacity_bytes: 256"
    echo "table_realloc_count: 2"
    mkdir -p "$repo_root/bin" "$repo_root/src/build" "$repo_root/src/.uyacache"
    printf 'bin-output\n' >"$repo_root/bin/uya"
    printf 'single-c\n' >"$repo_root/src/build/uya.c"
    printf 'split-c\n' >"$repo_root/src/.uyacache/uya_part1.c"
fi
EOF
chmod +x "$FAKE_MAKE"

run_bench() {
    # 用法: run_bench <out.tsv> <err.log> [extra env assignments...]
    local out="$1"; shift
    local err="$1"; shift
    env MAKE="$FAKE_MAKE" UYA_BENCH_TMPDIR="$TMP_DIR" "$@" \
        bash "$BENCH_SCRIPT" --runs 1 >"$out" 2>"$err"
}

# 内存达标判定：仅当 peak_rss_kb 为数值且较 baseline 下降 >= 25% 时认定 "certified"。
# RSS 缺失（NA）一律 "uncertified"，确保不会误报达标。
certify_rss() {
    local tsv="$1"
    local baseline="$2"
    awk -F '\t' -v baseline="$baseline" '
        NR == 2 {
            rss = $11
            if (rss !~ /^[0-9]+$/) { print "uncertified"; exit }
            if (baseline !~ /^[0-9]+$/ || baseline + 0 <= 0) { print "uncertified"; exit }
            if (rss * 100 <= baseline * 75) { print "certified" } else { print "uncertified" }
            exit
        }
        END { if (NR < 2) print "uncertified" }
    ' "$tsv"
}

# ---- 检查 1：benchmark TSV 含内存字段 ----
BUDGET_TSV="$TMP_DIR/budget.tsv"
BUDGET_ERR="$TMP_DIR/budget.err"
if ! run_bench "$BUDGET_TSV" "$BUDGET_ERR" UYA_BENCH_BASELINE_RSS_KB=100000; then
    echo "错误: benchmark 内存预算 smoke 运行失败" >&2
    cat "$BUDGET_ERR" >&2
    exit 1
fi
if ! grep -qF "$EXPECTED_HEADER" "$BUDGET_TSV"; then
    echo "错误: benchmark TSV 缺少内存字段表头" >&2
    cat "$BUDGET_TSV" >&2
    exit 1
fi

# ---- 检查 3 + 4：arena 字段与动态表字段存在且为非负整数 ----
# 列序：11 peak_rss_kb，12 arena_peak_bytes，13 output_bytes，14 c99_output_buffer_peak_bytes，
#       15 table_count，16 table_capacity，17 table_bytes，18 table_capacity_bytes，19 table_realloc_count
if ! awk -F '\t' '
    NR == 2 {
        ok = 1
        if (NF != 19) ok = 0
        # arena_peak_bytes 必须为非负整数
        if ($12 !~ /^[0-9]+$/) ok = 0
        # output_bytes 必须为非负整数
        if ($13 !~ /^[0-9]+$/) ok = 0
        # C99 输出缓冲峰值必须为非负整数
        if ($14 !~ /^[0-9]+$/) ok = 0
        # 动态表字段必须为非负整数
        if ($15 !~ /^[0-9]+$/) ok = 0
        if ($16 !~ /^[0-9]+$/) ok = 0
        if ($17 !~ /^[0-9]+$/) ok = 0
        if ($18 !~ /^[0-9]+$/) ok = 0
        if ($19 !~ /^[0-9]+$/) ok = 0
        exit !ok
    }
    END { if (NR < 2) exit 1 }
' "$BUDGET_TSV"; then
    echo "错误: benchmark TSV arena/动态表字段缺失或非非负整数" >&2
    cat "$BUDGET_TSV" >&2
    exit 1
fi

# phase_stats 行须含 arena_peak_bytes，table_stats 行须含动态表 count/capacity/realloc/bytes
if ! grep -Eq $'^phase_stats\trun\t1\t.*\tarena_peak_bytes\t[0-9]+\t' "$BUDGET_ERR"; then
    echo "错误: benchmark 未输出 arena_peak_bytes phase 统计" >&2
    cat "$BUDGET_ERR" >&2
    exit 1
fi
if ! grep -Eq $'^phase_stats\trun\t1\t.*\tc99_output_buffer_peak_bytes\t[0-9]+\t' "$BUDGET_ERR"; then
    echo "错误: benchmark 未输出 C99 输出缓冲峰值统计" >&2
    cat "$BUDGET_ERR" >&2
    exit 1
fi
if ! grep -Eq $'^table_stats\trun\t1\ttable_count\t[0-9]+\ttable_capacity\t[0-9]+\ttable_bytes\t[0-9]+\ttable_capacity_bytes\t[0-9]+\ttable_realloc_count\t[0-9]+\t' "$BUDGET_ERR"; then
    echo "错误: benchmark 未输出动态表 count/capacity/realloc/bytes 统计" >&2
    cat "$BUDGET_ERR" >&2
    exit 1
fi

# 正向对照：RSS 为数值且 baseline 远高于实测时，应判定 certified（确保判定函数能给出达标）。
if [[ "$(certify_rss "$BUDGET_TSV" 100000)" != "certified" ]]; then
    echo "错误: 数值 RSS 且大幅下降时应判定内存达标（正向对照失败）" >&2
    cat "$BUDGET_TSV" >&2
    exit 1
fi

# ---- 检查 2：缺少 RSS 采样时不会误报达标 ----
NOPROC_TSV="$TMP_DIR/noproc.tsv"
NOPROC_ERR="$TMP_DIR/noproc.err"
if ! run_bench "$NOPROC_TSV" "$NOPROC_ERR" UYA_BENCH_BASELINE_RSS_KB=100000 UYA_BENCH_PROC_ROOT="$TMP_DIR/no-proc"; then
    echo "错误: 缺少 /proc 时 benchmark 仍应完成时间测量" >&2
    cat "$NOPROC_ERR" >&2
    exit 1
fi
if ! grep -q "RSS 未测量" "$NOPROC_ERR"; then
    echo "错误: 缺少 /proc 时未输出 RSS 未测量诊断" >&2
    cat "$NOPROC_ERR" >&2
    exit 1
fi
if ! awk -F '\t' 'NR == 2 { exit !($11 == "NA") } END { if (NR < 2) exit 1 }' "$NOPROC_TSV"; then
    echo "错误: 缺少 /proc 时 peak_rss_kb 应为 NA" >&2
    cat "$NOPROC_TSV" >&2
    exit 1
fi
if [[ "$(certify_rss "$NOPROC_TSV" 100000)" != "uncertified" ]]; then
    echo "错误: RSS 未测量却被判定内存达标（误报）" >&2
    cat "$NOPROC_TSV" >&2
    exit 1
fi

echo "✓ compiler memory budget: TSV 内存字段、arena/动态表非负、RSS 缺失不误报达标 验证通过"
