#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BENCH_SCRIPT="$REPO_ROOT/scripts/bench_compiler_1s.sh"
TMP_DIR="$(mktemp -d /tmp/uya-bench-compiler-1s-verify.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_MAKE="$TMP_DIR/fake_make.sh"
cat >"$FAKE_MAKE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CALL_LOG="${UYA_FAKE_MAKE_CALL_LOG:?}"
target=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -C)
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

printf '%s\n' "$target" >>"$CALL_LOG"
echo "fake make $target"

if [[ "${UYA_FAKE_MAKE_FAIL_TARGET:-}" == "$target" ]]; then
    echo "fake failure for $target" >&2
    exit 17
fi
EOF
chmod +x "$FAKE_MAKE"

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

CALL_LOG="$TMP_DIR/calls.ok"
: >"$CALL_LOG"
CFLAGS="-std=c99 -O2 -Werror" CC_DRIVER="fake-cc" MAKE="$FAKE_MAKE" UYA_FAKE_MAKE_CALL_LOG="$CALL_LOG" UYA_BENCH_TMPDIR="$TMP_DIR" bash "$BENCH_SCRIPT" --runs 2 >"$TMP_DIR/bench.tsv" 2>"$TMP_DIR/bench.err"

if ! grep -q $'^run\tmode\tclean_ms\tbuild_ms\ttotal_ms\tstatus$' "$TMP_DIR/bench.tsv"; then
    echo "错误: benchmark TSV 表头不正确" >&2
    cat "$TMP_DIR/bench.tsv" >&2
    exit 1
fi
if ! awk -F '\t' '
    NR == 2 || NR == 3 {
        if (!($1 ~ /^[12]$/ && $2 == "c99" && NF == 6 && $3 >= 0 && $4 >= 0 && $5 >= 0 && $6 == "ok")) exit 1;
    }
    NR == 4 {
        if (!($1 == "median" && $2 == "c99" && NF == 6 && $3 >= 0 && $4 >= 0 && $5 >= 0 && $6 == "ok")) exit 1;
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
if compgen -G "$TMP_DIR/uya-bench-compiler-1s.*" >/dev/null; then
    echo "错误: benchmark 临时日志目录未清理" >&2
    compgen -G "$TMP_DIR/uya-bench-compiler-1s.*" >&2
    exit 1
fi

CALL_LOG="$TMP_DIR/calls.fail"
: >"$CALL_LOG"
if MAKE="$FAKE_MAKE" UYA_FAKE_MAKE_CALL_LOG="$CALL_LOG" UYA_FAKE_MAKE_FAIL_TARGET="uya" UYA_BENCH_TMPDIR="$TMP_DIR" bash "$BENCH_SCRIPT" --runs 1 >"$TMP_DIR/fail.tsv" 2>"$TMP_DIR/fail.err"; then
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
