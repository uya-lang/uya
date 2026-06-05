#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_FILE="$REPO_ROOT/tests/test_generic_template_multi_instance_var_types.uya"
COMPILER="$REPO_ROOT/bin/uya"

for file in "$TEST_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

tmp_dir="$(mktemp -d /tmp/uya-c99-generic-var-types.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

"$COMPILER" test "$TEST_FILE" --no-split-c >/dev/null
"$COMPILER" build "$TEST_FILE" --c99 --no-split-c -O0 -o "$tmp_dir/main.c" >/dev/null

if ! grep -Eq "uya_alignof\\(uint8_t\\)" "$tmp_dir/main.c"; then
    echo "错误: 泛型 u8 实例未在 C99 中保留 uint8_t 局部类型查询" >&2
    exit 1
fi

if ! grep -Eq "uya_alignof\\(int64_t\\)" "$tmp_dir/main.c"; then
    echo "错误: 泛型 i64 实例未在 C99 中保留 int64_t 局部类型查询" >&2
    exit 1
fi

echo "✓ C99 generic template multi-instance local variable types stay distinct"
