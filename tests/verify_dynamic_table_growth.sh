#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_check() {
    local script="$1"
    local path="$SCRIPT_DIR/$script"
    if [[ ! -x "$path" ]]; then
        echo "错误: 缺少可执行验证脚本: $path" >&2
        exit 1
    fi
    echo "== $script =="
    bash "$path"
}

run_check "verify_semantic_table_growth_failures.sh"
run_check "verify_semantic_intern_growth.sh"
run_check "verify_semantic_db_dynamic_growth.sh"

echo "✓ dynamic table growth aggregate checks passed"
