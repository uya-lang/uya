#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/uya-bench-compiler-1s-verify.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT
FIXTURE_REPO="$TMP_DIR/repo"

mkdir -p "$FIXTURE_REPO/scripts" "$FIXTURE_REPO/bin" "$FIXTURE_REPO/src/build" "$FIXTURE_REPO/src/.uyacache"
cp "$REPO_ROOT/scripts/bench_compiler_1s.sh" "$FIXTURE_REPO/scripts/bench_compiler_1s.sh"
chmod +x "$FIXTURE_REPO/scripts/bench_compiler_1s.sh"
BENCH_SCRIPT="$FIXTURE_REPO/scripts/bench_compiler_1s.sh"

seed_stale_artifacts() {
    mkdir -p "$FIXTURE_REPO/bin" "$FIXTURE_REPO/src/build" "$FIXTURE_REPO/src/.uyacache"
    touch "$FIXTURE_REPO/bin/stale"
    touch "$FIXTURE_REPO/src/build/stale"
    touch "$FIXTURE_REPO/src/.uyacache/stale"
}

FAKE_MAKE="$TMP_DIR/fake_make.sh"
cat >"$FAKE_MAKE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CALL_LOG="${UYA_FAKE_MAKE_CALL_LOG:?}"
repo_root=""
target=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -C)
            repo_root="$2"
            shift 2
            ;;
        *)
            target="$1"
            shift
            ;;
    esac
done

if [[ -z "$target" ]]; then
    echo "fake_make: missing target" >&2
    exit 2
fi

if [[ "${UYA_FAKE_MAKE_ASSERT_CLEAN:-0}" == "1" && "$target" == "clean" ]]; then
    for stale in "$repo_root/bin/stale" "$repo_root/src/build/stale" "$repo_root/src/.uyacache/stale"; do
        if [[ -e "$stale" ]]; then
            echo "fake_make: stale artifact was not removed before make clean: $stale" >&2
            exit 23
        fi
    done
fi

printf '%s\n' "$target" >>"$CALL_LOG"
echo "fake make $target"
if [[ "$target" == "uya" ]]; then
    echo "解析耗时: 11 ms"
    echo "合并耗时: 2 ms"
    echo "检查耗时: 13 ms"
    echo "生成耗时: 17 ms"
    echo "arena_peak_bytes: 4096"
    echo "ast_arena_peak_bytes: 3000"
    echo "check_arena_peak_bytes: 800"
    echo "emit_arena_peak_bytes: 296"
    echo "c99_output_buffer_peak_bytes: 65536"
    echo "typed_program_bytes: 2048"
    echo "typed_program_peak_bytes: 8192"
    echo "typed_program_released_bytes: 0"
    if [[ "${UYA_FAKE_TABLE_OVERALLOC:-0}" == "1" ]]; then
        echo "table_count: 1"
        echo "table_capacity: 100"
        echo "table_bytes: 8"
        echo "table_capacity_bytes: 800"
        echo "table_realloc_count: 0"
    else
        echo "table_count: 3"
        echo "table_capacity: 8"
        echo "table_bytes: 96"
        echo "table_capacity_bytes: 256"
        echo "table_realloc_count: 2"
    fi
fi

if [[ "${UYA_FAKE_MAKE_FAIL_TARGET:-}" == "$target" ]]; then
    echo "fake failure for $target" >&2
    exit 17
fi

if [[ "${UYA_FAKE_MAKE_CREATE_ARTIFACTS:-0}" == "1" && "$target" == "uya" ]]; then
    mkdir -p "$repo_root/bin/cmd" "$repo_root/backup" "$repo_root/src/build" "$repo_root/src/.uyacache"
    printf 'bin-output\n' >"$repo_root/bin/uya"
    printf 'cmd-build-bin\n' >"$repo_root/bin/cmd/build"
    printf 'cmd-build-seed-c\n' >"$repo_root/backup/cmd-build.c"
    printf 'object\n' >"$repo_root/bin/fake.o"
    printf 'single-c\n' >"$repo_root/src/build/uya.c"
    printf 'split-c\n' >"$repo_root/src/.uyacache/uya_part1.c"
    touch "$repo_root/bin/stale"
    touch "$repo_root/src/build/stale"
    touch "$repo_root/src/.uyacache/stale"
fi
EOF
chmod +x "$FAKE_MAKE"

assert_rejects_cache_flag() {
    local var_name="$1"
    local reject_out="$TMP_DIR/reject-${var_name}.out"
    local reject_err="$TMP_DIR/reject-${var_name}.err"
    local reject_calls="$TMP_DIR/reject-${var_name}.calls"
    : >"$reject_calls"

    if env "$var_name=1" MAKE="$FAKE_MAKE" UYA_FAKE_MAKE_CALL_LOG="$reject_calls" UYA_BENCH_TMPDIR="$TMP_DIR" bash "$BENCH_SCRIPT" --runs 1 >"$reject_out" 2>"$reject_err"; then
        echo "错误: $var_name=1 应被 benchmark 拒绝" >&2
        exit 1
    fi
    if ! grep -q "$var_name" "$reject_err" || ! grep -q "禁止" "$reject_err"; then
        echo "错误: $var_name=1 未输出预期拒绝诊断" >&2
        cat "$reject_err" >&2
        exit 1
    fi
    if [[ -s "$reject_calls" ]]; then
        echo "错误: $var_name=1 被拒绝前不应调用 make" >&2
        cat "$reject_calls" >&2
        exit 1
    fi
}

if MAKE="$FAKE_MAKE" UYA_BENCH_TMPDIR="$TMP_DIR" bash "$BENCH_SCRIPT" --runs 0 >"$TMP_DIR/runs0.out" 2>"$TMP_DIR/runs0.err"; then
    echo "错误: --runs 0 应失败" >&2
    exit 1
fi
if ! grep -q -- "--runs 必须是大于等于 1 的整数" "$TMP_DIR/runs0.err"; then
    echo "错误: --runs 0 未输出预期诊断" >&2
    cat "$TMP_DIR/runs0.err" >&2
    exit 1
fi

if MAKE="$FAKE_MAKE" UYA_BENCH_TMPDIR="$TMP_DIR" bash "$BENCH_SCRIPT" --unknown >"$TMP_DIR/unknown.out" 2>"$TMP_DIR/unknown.err"; then
    echo "错误: 未知参数应失败" >&2
    exit 1
fi
if ! grep -q "未知参数" "$TMP_DIR/unknown.err"; then
    echo "错误: 未知参数未输出预期诊断" >&2
    cat "$TMP_DIR/unknown.err" >&2
    exit 1
fi

assert_rejects_cache_flag "UYA_DAEMON"
assert_rejects_cache_flag "UYA_OBJECT_CACHE"
assert_rejects_cache_flag "UYA_IR_CACHE"
assert_rejects_cache_flag "UYA_SKIP_UYA"

CALL_LOG="$TMP_DIR/reject-dump.calls"
: >"$CALL_LOG"
if UYA_DUMP_SEMANTIC_DB=1 MAKE="$FAKE_MAKE" UYA_FAKE_MAKE_CALL_LOG="$CALL_LOG" UYA_BENCH_TMPDIR="$TMP_DIR" bash "$BENCH_SCRIPT" --runs 1 >"$TMP_DIR/reject-dump.out" 2>"$TMP_DIR/reject-dump.err"; then
    echo "错误: UYA_DUMP_SEMANTIC_DB=1 应被硬 KPI benchmark 拒绝" >&2
    exit 1
fi
if ! grep -q "UYA_DUMP_SEMANTIC_DB" "$TMP_DIR/reject-dump.err" || ! grep -q "debug dump" "$TMP_DIR/reject-dump.err"; then
    echo "错误: UYA_DUMP_SEMANTIC_DB=1 未输出预期拒绝诊断" >&2
    cat "$TMP_DIR/reject-dump.err" >&2
    exit 1
fi
if [[ -s "$CALL_LOG" ]]; then
    echo "错误: UYA_DUMP_SEMANTIC_DB=1 被拒绝前不应调用 make" >&2
    cat "$CALL_LOG" >&2
    exit 1
fi

# L396：所有 UYA_DUMP_* dump 开关（含未来新增的）都必须被硬 KPI 拒绝、不计入性能达标。
for DUMP_VAR in UYA_DUMP_FUNCTION_SCOPE UYA_DUMP_LOWERED_PROGRAM UYA_DUMP_COREIR UYA_DUMP_FUTURE_FEATURE; do
    CALL_LOG="$TMP_DIR/reject-$DUMP_VAR.calls"
    : >"$CALL_LOG"
    if env "$DUMP_VAR=1" MAKE="$FAKE_MAKE" UYA_FAKE_MAKE_CALL_LOG="$CALL_LOG" UYA_BENCH_TMPDIR="$TMP_DIR" \
            bash "$BENCH_SCRIPT" --runs 1 >"$TMP_DIR/reject-$DUMP_VAR.out" 2>"$TMP_DIR/reject-$DUMP_VAR.err"; then
        echo "错误: $DUMP_VAR=1 应被硬 KPI benchmark 拒绝" >&2
        exit 1
    fi
    if ! grep -q "$DUMP_VAR" "$TMP_DIR/reject-$DUMP_VAR.err" || ! grep -q "debug dump" "$TMP_DIR/reject-$DUMP_VAR.err"; then
        echo "错误: $DUMP_VAR=1 未输出预期拒绝诊断" >&2
        cat "$TMP_DIR/reject-$DUMP_VAR.err" >&2
        exit 1
    fi
    if [[ -s "$CALL_LOG" ]]; then
        echo "错误: $DUMP_VAR=1 被拒绝前不应调用 make" >&2
        exit 1
    fi
done

CALL_LOG="$TMP_DIR/calls.ok"
: >"$CALL_LOG"
seed_stale_artifacts
if ! CFLAGS="-std=c99 -O2 -Werror" CC_DRIVER="fake-cc" MAKE="$FAKE_MAKE" UYA_FAKE_MAKE_CALL_LOG="$CALL_LOG" UYA_FAKE_MAKE_ASSERT_CLEAN=1 UYA_FAKE_MAKE_CREATE_ARTIFACTS=1 UYA_BENCH_BASELINE_RSS_KB=100 UYA_BENCH_TMPDIR="$TMP_DIR" bash "$BENCH_SCRIPT" --runs 2 >"$TMP_DIR/bench.tsv" 2>"$TMP_DIR/bench.err"; then
    echo "错误: benchmark smoke 运行失败" >&2
    cat "$TMP_DIR/bench.err" >&2
    exit 1
fi

if ! grep -q $'^run\tmode\tseed_ms\tparse_ms\tbind_ms\tcheck_ms\tlower_ms\temit_ms\tlink_ms\ttotal_ms\tpeak_rss_kb\tarena_peak_bytes\toutput_bytes\tc99_output_buffer_peak_bytes\ttable_count\ttable_capacity\ttable_bytes\ttable_capacity_bytes\ttable_realloc_count$' "$TMP_DIR/bench.tsv"; then
    echo "错误: benchmark TSV 表头不正确" >&2
    cat "$TMP_DIR/bench.tsv" >&2
    exit 1
fi
if ! awk -F '\t' '
    NR == 2 || NR == 3 {
        if (!($1 ~ /^[12]$/ && $2 == "c99" && NF == 19 && $3 == "NA" && $4 == 11 && $5 == 2 && $6 == 13 && $7 == "NA" && $8 == 17 && $9 == "NA" && $10 >= 0 && $11 >= 0 && $12 == 4096 && $13 > 0 && $14 == 65536 && $15 == 3 && $16 == 8 && $17 == 96 && $18 == 256 && $19 == 2)) exit 1;
    }
    NR == 4 {
        if (!($1 == "median" && $2 == "c99" && NF == 19 && $3 == "NA" && $4 == 11 && $5 == 2 && $6 == 13 && $7 == "NA" && $8 == 17 && $9 == "NA" && $10 >= 0 && $11 >= 0 && $12 == 4096 && $13 > 0 && $14 == 65536 && $15 == 3 && $16 == 8 && $17 == 96 && $18 == 256 && $19 == 2)) exit 1;
    }
    END { if (NR != 4) exit 1 }
' "$TMP_DIR/bench.tsv"; then
    echo "错误: benchmark TSV 数据行不正确" >&2
    cat "$TMP_DIR/bench.tsv" >&2
    exit 1
fi
if ! diff -u <(printf 'clean\nuya\nclean\nuya\n') "$CALL_LOG" >"$TMP_DIR/calls.diff"; then
    echo "错误: make clean && make uya 调用顺序不正确" >&2
    cat "$TMP_DIR/calls.diff" >&2
    exit 1
fi
for pattern in \
    $'^metadata\tcommit\t' \
    $'^metadata\tbranch\t' \
    $'^metadata\tos\t' \
    $'^metadata\tarch\t' \
    $'^metadata\tcpu_count\t' \
    $'^metadata\tcflags\t-std=c99 -O2 -Werror$' \
    $'^metadata\tcc_driver\tfake-cc$' \
    $'^metadata\tbackend\tc99$' \
    $'^metadata\tnative_enabled\t0$' \
    $'^metadata\tc99_enabled\t1$' \
    $'^metadata\tsemantic_db_dump_enabled\t0$' \
    $'^metadata\tdump_enabled\t0$'
do
    if ! grep -q "$pattern" "$TMP_DIR/bench.err"; then
        echo "错误: benchmark metadata 缺少字段: $pattern" >&2
        cat "$TMP_DIR/bench.err" >&2
        exit 1
    fi
done
if ! grep -Eq $'^outputs\trun\t1\tc99_single_bytes\t[1-9][0-9]*\tsplit_c_bytes\t[1-9][0-9]*\tnative_bytes\t[1-9][0-9]*\tbuild_seed_bytes\t[1-9][0-9]*\ttemp_bytes\t[1-9][0-9]*\toutput_bytes\t[1-9][0-9]*$' "$TMP_DIR/bench.err"; then
    echo "错误: benchmark 未输出 run 1 生成文件字节明细" >&2
    cat "$TMP_DIR/bench.err" >&2
    exit 1
fi
if ! grep -Eq $'^memory_trend\trun\t1\tcurrent_peak_rss_kb\t[0-9]+\tbaseline_peak_rss_kb\t100\tchange_pct\t-?[0-9]+$' "$TMP_DIR/bench.err"; then
    echo "错误: benchmark 未输出内存趋势" >&2
    cat "$TMP_DIR/bench.err" >&2
    exit 1
fi
if ! grep -Eq $'^table_stats\trun\t1\ttable_count\t3\ttable_capacity\t8\ttable_bytes\t96\ttable_capacity_bytes\t256\ttable_realloc_count\t2\tstatus\tok$' "$TMP_DIR/bench.err"; then
    echo "错误: benchmark 未输出动态表统计摘要" >&2
    cat "$TMP_DIR/bench.err" >&2
    exit 1
fi
if ! grep -Eq $'^phase_stats\trun\t1\tseed_ms\tNA\tparse_ms\t11\tbind_ms\t2\tcheck_ms\t13\tlower_ms\tNA\temit_ms\t17\tlink_ms\tNA\tarena_peak_bytes\t4096\tast_arena_peak_bytes\t3000\tcheck_arena_peak_bytes\t800\temit_arena_peak_bytes\t296\tc99_output_buffer_peak_bytes\t65536\ttyped_program_bytes\t2048\ttyped_program_peak_bytes\t8192\ttyped_program_released_bytes\t0$' "$TMP_DIR/bench.err"; then
    echo "错误: benchmark 未输出编译阶段和 arena 统计摘要" >&2
    cat "$TMP_DIR/bench.err" >&2
    exit 1
fi
if compgen -G "$TMP_DIR/uya-bench-compiler-1s.*" >/dev/null; then
    echo "错误: benchmark 临时日志目录未清理" >&2
    compgen -G "$TMP_DIR/uya-bench-compiler-1s.*" >&2
    exit 1
fi

CALL_LOG="$TMP_DIR/calls.overalloc"
: >"$CALL_LOG"
if ! MAKE="$FAKE_MAKE" UYA_FAKE_MAKE_CALL_LOG="$CALL_LOG" UYA_FAKE_TABLE_OVERALLOC=1 UYA_BENCH_TMPDIR="$TMP_DIR" bash "$BENCH_SCRIPT" --runs 1 >"$TMP_DIR/overalloc.tsv" 2>"$TMP_DIR/overalloc.err"; then
    echo "错误: 过度预分配场景 benchmark 应完成并报告 warning" >&2
    cat "$TMP_DIR/overalloc.err" >&2
    exit 1
fi
if ! grep -Eq $'^table_capacity_warning\trun\t1\ttable_count\t1\ttable_capacity\t100\tratio\t100\tthreshold\t[0-9]+$' "$TMP_DIR/overalloc.err"; then
    echo "错误: 过度预分配场景未输出 table capacity warning" >&2
    cat "$TMP_DIR/overalloc.err" >&2
    exit 1
fi

CALL_LOG="$TMP_DIR/calls.noproc"
: >"$CALL_LOG"
if ! MAKE="$FAKE_MAKE" UYA_FAKE_MAKE_CALL_LOG="$CALL_LOG" UYA_BENCH_PROC_ROOT="$TMP_DIR/no-proc" UYA_BENCH_TMPDIR="$TMP_DIR" bash "$BENCH_SCRIPT" --runs 1 >"$TMP_DIR/noproc.tsv" 2>"$TMP_DIR/noproc.err"; then
    echo "错误: 缺少 /proc 时 benchmark 仍应完成时间测量" >&2
    cat "$TMP_DIR/noproc.err" >&2
    exit 1
fi
if ! grep -q "RSS 未测量" "$TMP_DIR/noproc.err"; then
    echo "错误: 缺少 /proc 时未输出 RSS 未测量诊断" >&2
    cat "$TMP_DIR/noproc.err" >&2
    exit 1
fi
if ! awk -F '\t' 'NR == 2 { exit !($1 == "1" && $2 == "c99" && NF == 19 && $11 == "NA" && $12 == 4096 && $13 >= 0 && $14 == 65536 && $15 == 3 && $19 == 2) } END { if (NR != 2) exit 1 }' "$TMP_DIR/noproc.tsv"; then
    echo "错误: 缺少 /proc 时 peak_rss_kb 应为 NA" >&2
    cat "$TMP_DIR/noproc.tsv" >&2
    exit 1
fi
if ! diff -u <(printf 'clean\nuya\n') "$CALL_LOG" >"$TMP_DIR/calls-noproc.diff"; then
    echo "错误: 缺少 /proc 路径调用顺序不正确" >&2
    cat "$TMP_DIR/calls-noproc.diff" >&2
    exit 1
fi

CALL_LOG="$TMP_DIR/calls.fail"
: >"$CALL_LOG"
seed_stale_artifacts
if MAKE="$FAKE_MAKE" UYA_FAKE_MAKE_CALL_LOG="$CALL_LOG" UYA_FAKE_MAKE_ASSERT_CLEAN=1 UYA_FAKE_MAKE_FAIL_TARGET="uya" UYA_BENCH_TMPDIR="$TMP_DIR" bash "$BENCH_SCRIPT" --runs 1 >"$TMP_DIR/fail.tsv" 2>"$TMP_DIR/fail.err"; then
    echo "错误: make uya 失败时 benchmark 应失败" >&2
    exit 1
fi
if ! awk -F '\t' 'NR == 2 { exit !($1 == "1" && $2 == "c99" && NF == 19 && $4 == 11 && $12 == 4096 && $14 == 65536 && $15 == 3) } END { if (NR != 2) exit 1 }' "$TMP_DIR/fail.tsv"; then
    echo "错误: build 失败未输出固定字段 TSV 行" >&2
    cat "$TMP_DIR/fail.tsv" >&2
    exit 1
fi
if ! grep -q "错误: make uya 失败" "$TMP_DIR/fail.err" || ! grep -q "fake failure for uya" "$TMP_DIR/fail.err"; then
    echo "错误: build 失败未输出预期日志" >&2
    cat "$TMP_DIR/fail.err" >&2
    exit 1
fi
if ! diff -u <(printf 'clean\nuya\n') "$CALL_LOG" >"$TMP_DIR/calls-fail.diff"; then
    echo "错误: build 失败路径调用顺序不正确" >&2
    cat "$TMP_DIR/calls-fail.diff" >&2
    exit 1
fi

echo "✓ bench_compiler_1s 参数边界、TSV、调用顺序、失败路径与临时目录清理验证通过"
