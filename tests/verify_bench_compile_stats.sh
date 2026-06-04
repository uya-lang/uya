#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BENCH_SCRIPT="$REPO_ROOT/scripts/bench_compile_stats.sh"
TMP_DIR="$(mktemp -d /tmp/uya-bench-verify.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if UYA_BENCH_SKIP_REBUILD=1 bash "$BENCH_SCRIPT" --runs 0 >"$TMP_DIR/runs0.out" 2>"$TMP_DIR/runs0.err"; then
    echo "错误: --runs 0 应失败" >&2
    exit 1
fi
if ! grep -q -- "--runs 必须是大于等于 1 的整数" "$TMP_DIR/runs0.err"; then
    echo "错误: --runs 0 未输出预期诊断" >&2
    cat "$TMP_DIR/runs0.err" >&2
    exit 1
fi

if UYA_BENCH_SKIP_REBUILD=1 bash "$BENCH_SCRIPT" --unknown >"$TMP_DIR/unknown.out" 2>"$TMP_DIR/unknown.err"; then
    echo "错误: 未知参数应失败" >&2
    exit 1
fi
if ! grep -q "未知参数" "$TMP_DIR/unknown.err"; then
    echo "错误: 未知参数未输出预期诊断" >&2
    cat "$TMP_DIR/unknown.err" >&2
    exit 1
fi

UYA_BENCH_SKIP_REBUILD=1 UYA_BENCH_TMPDIR="$TMP_DIR" bash "$BENCH_SCRIPT" --runs 1 >"$TMP_DIR/bench.tsv" 2>"$TMP_DIR/bench.err"
if ! grep -q $'^run\tfiles\tparse_ms\tmerge_ms\tcheck_ms\topt_ms\tcodegen_ms\ttotal_ms$' "$TMP_DIR/bench.tsv"; then
    echo "错误: benchmark TSV 表头不正确" >&2
    cat "$TMP_DIR/bench.tsv" >&2
    exit 1
fi
if ! awk -F '\t' 'NR == 2 { exit !($1 == "1" && NF == 8 && $2 > 0 && $5 >= 0 && $7 > 0 && $8 > 0) } END { if (NR < 2) exit 1 }' "$TMP_DIR/bench.tsv"; then
    echo "错误: benchmark TSV 数据行不正确" >&2
    cat "$TMP_DIR/bench.tsv" >&2
    exit 1
fi
if [[ -e "$REPO_ROOT/bin/uya-bench-compile-stats" || -e "$REPO_ROOT/bin/uya-bench-compile-stats.build" ]]; then
    echo "错误: benchmark 临时可执行文件未清理" >&2
    exit 1
fi
if compgen -G "$TMP_DIR/uya-bench-compile-stats.*" >/dev/null; then
    echo "错误: benchmark 临时输出目录未清理" >&2
    compgen -G "$TMP_DIR/uya-bench-compile-stats.*" >&2
    exit 1
fi

echo "✓ bench_compile_stats 参数边界与 smoke/perf 输出验证通过"
