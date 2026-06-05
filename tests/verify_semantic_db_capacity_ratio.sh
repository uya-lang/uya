#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/bin/uya"
MAX_RATIO="${UYA_SEMANTIC_INDEX_MAX_RATIO:-8}"

if [[ ! -x "$COMPILER" ]]; then
    echo "错误: 缺少可执行编译器: $COMPILER" >&2
    exit 1
fi

if ! [[ "$MAX_RATIO" =~ ^[0-9]+$ ]] || [[ "$MAX_RATIO" -lt 1 ]]; then
    echo "错误: UYA_SEMANTIC_INDEX_MAX_RATIO 必须是大于等于 1 的整数" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-semantic-db-ratio.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

dump_stderr="$tmp_dir/dump.stderr"
(cd "$REPO_ROOT" && UYA_DUMP_SEMANTIC_DB=1 "$COMPILER" check src/main.uya >"$tmp_dir/dump.stdout" 2>"$dump_stderr")

expected_indexes=(
    decls_by_name
    functions_by_name
    types_by_name
    global_vars_by_name
    enum_variants_by_name
    exports_by_module_name
    aliases_by_file_name
    use_items_by_file_name
)

for index_name in "${expected_indexes[@]}"; do
    line="$(grep -E "^phase2_index name=${index_name} " "$dump_stderr" || true)"
    if [[ -z "$line" ]]; then
        echo "错误: 缺少 SemanticDb Phase 2 索引统计: $index_name" >&2
        exit 1
    fi
    count="$(sed -n 's/.* count=\([0-9][0-9]*\) .*/\1/p' <<<"$line")"
    capacity="$(sed -n 's/.* capacity=\([0-9][0-9]*\) .*/\1/p' <<<"$line")"
    load_ppm="$(sed -n 's/.* load_ppm=\([0-9][0-9]*\) .*/\1/p' <<<"$line")"
    reallocs="$(sed -n 's/.* reallocs=\([0-9][0-9]*\) .*/\1/p' <<<"$line")"
    if [[ -z "$count" || -z "$capacity" || -z "$load_ppm" || -z "$reallocs" ]]; then
        echo "错误: SemanticDb Phase 2 索引统计字段不完整: $line" >&2
        exit 1
    fi
    if [[ "$count" -le 0 ]]; then
        echo "错误: SemanticDb Phase 2 主索引为空: $index_name count=$count" >&2
        exit 1
    fi
    if [[ "$capacity" -lt "$count" ]]; then
        echo "错误: SemanticDb Phase 2 索引容量小于 count: $index_name count=$count capacity=$capacity" >&2
        exit 1
    fi
    if [[ "$capacity" -gt $((count * MAX_RATIO)) ]]; then
        echo "错误: SemanticDb Phase 2 索引容量比过高: $index_name count=$count capacity=$capacity threshold=$MAX_RATIO" >&2
        exit 1
    fi
    if [[ "$load_ppm" -le 0 || "$load_ppm" -gt 1000000 ]]; then
        echo "错误: SemanticDb Phase 2 索引 load_ppm 不可解释: $index_name load_ppm=$load_ppm" >&2
        exit 1
    fi
    if [[ "$reallocs" -le 0 ]]; then
        echo "错误: SemanticDb Phase 2 索引未记录动态增长: $index_name reallocs=$reallocs" >&2
        exit 1
    fi
done

echo "✓ SemanticDb Phase 2 capacity/count ratios are explainable on src/main.uya"
