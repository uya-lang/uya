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

if [[ "${UYA_FAKE_MAKE_FAIL_TARGET:-}" == "$target" ]]; then
    echo "fake failure for $target" >&2
    exit 17
fi

if [[ "${UYA_FAKE_MAKE_CREATE_ARTIFACTS:-0}" == "1" && "$target" == "uya" ]]; then
    mkdir -p "$repo_root/bin" "$repo_root/src/build" "$repo_root/src/.uyacache"
    printf 'bin-output\n' >"$repo_root/bin/uya"
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

CALL_LOG="$TMP_DIR/calls.ok"
: >"$CALL_LOG"
seed_stale_artifacts
if ! CFLAGS="-std=c99 -O2 -Werror" CC_DRIVER="fake-cc" MAKE="$FAKE_MAKE" UYA_FAKE_MAKE_CALL_LOG="$CALL_LOG" UYA_FAKE_MAKE_ASSERT_CLEAN=1 UYA_FAKE_MAKE_CREATE_ARTIFACTS=1 UYA_BENCH_BASELINE_RSS_KB=100 UYA_BENCH_TMPDIR="$TMP_DIR" bash "$BENCH_SCRIPT" --runs 2 >"$TMP_DIR/bench.tsv" 2>"$TMP_DIR/bench.err"; then
    echo "错误: benchmark smoke 运行失败" >&2
    cat "$TMP_DIR/bench.err" >&2
    exit 1
fi

if ! grep -q $'^run\tmode\tclean_ms\tbuild_ms\ttotal_ms\tpeak_rss_kb\toutput_bytes\tstatus$' "$TMP_DIR/bench.tsv"; then
    echo "错误: benchmark TSV 表头不正确" >&2
    cat "$TMP_DIR/bench.tsv" >&2
    exit 1
fi
if ! awk -F '\t' '
    NR == 2 || NR == 3 {
        if (!($1 ~ /^[12]$/ && $2 == "c99" && NF == 8 && $3 >= 0 && $4 >= 0 && $5 >= 0 && $6 >= 0 && $7 > 0 && $8 == "ok")) exit 1;
    }
    NR == 4 {
        if (!($1 == "median" && $2 == "c99" && NF == 8 && $3 >= 0 && $4 >= 0 && $5 >= 0 && $6 >= 0 && $7 > 0 && $8 == "ok")) exit 1;
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
    $'^metadata\tc99_enabled\t1$'
do
    if ! grep -q "$pattern" "$TMP_DIR/bench.err"; then
        echo "错误: benchmark metadata 缺少字段: $pattern" >&2
        cat "$TMP_DIR/bench.err" >&2
        exit 1
    fi
done
if ! grep -Eq $'^outputs\trun\t1\tc99_single_bytes\t[1-9][0-9]*\tsplit_c_bytes\t[1-9][0-9]*\tnative_bytes\t[1-9][0-9]*\ttemp_bytes\t[1-9][0-9]*\toutput_bytes\t[1-9][0-9]*$' "$TMP_DIR/bench.err"; then
    echo "错误: benchmark 未输出 run 1 生成文件字节明细" >&2
    cat "$TMP_DIR/bench.err" >&2
    exit 1
fi
if ! grep -Eq $'^memory_trend\trun\t1\tcurrent_peak_rss_kb\t[0-9]+\tbaseline_peak_rss_kb\t100\tchange_pct\t-?[0-9]+$' "$TMP_DIR/bench.err"; then
    echo "错误: benchmark 未输出内存趋势" >&2
    cat "$TMP_DIR/bench.err" >&2
    exit 1
fi
if compgen -G "$TMP_DIR/uya-bench-compiler-1s.*" >/dev/null; then
    echo "错误: benchmark 临时日志目录未清理" >&2
    compgen -G "$TMP_DIR/uya-bench-compiler-1s.*" >&2
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
if ! awk -F '\t' 'NR == 2 { exit !($1 == "1" && $2 == "c99" && NF == 8 && $6 == "NA" && $7 >= 0 && $8 == "ok") } END { if (NR != 2) exit 1 }' "$TMP_DIR/noproc.tsv"; then
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
if ! grep -q $'1\tc99\t' "$TMP_DIR/fail.tsv" || ! grep -q "build_failed" "$TMP_DIR/fail.tsv"; then
    echo "错误: build 失败未输出 build_failed TSV 行" >&2
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
