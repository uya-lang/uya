#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
C99_MAIN="$REPO_ROOT/src/codegen/c99/main.uya"
C99_UTILS="$REPO_ROOT/src/codegen/c99/utils.uya"
C99_STRUCTS="$REPO_ROOT/src/codegen/c99/structs.uya"
C99_ENUMS="$REPO_ROOT/src/codegen/c99/enums.uya"
C99_TYPES="$REPO_ROOT/src/codegen/c99/types.uya"

require_pattern() {
    local pattern="$1"
    local file="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: 缺少 C99 registry/emitted metadata 容量 diagnostic 证据: $description" >&2
        return 1
    fi
}

reject_pattern() {
    local pattern="$1"
    local file="$2"
    local description="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "错误: 仍存在静默 C99 registry/emitted metadata 上限路径: $description" >&2
        return 1
    fi
}

require_pattern "error id registry" "$C99_UTILS" "error id registry 上限 diagnostic"
require_pattern "string constant registry" "$C99_UTILS" "string constant registry 上限 diagnostic"
require_pattern "embedded constant registry" "$C99_UTILS" "embedded constant registry 上限 diagnostic"
require_pattern "embedded dir table registry" "$C99_UTILS" "embedded dir table registry 上限 diagnostic"
require_pattern "slice struct registry" "$C99_UTILS" "embed builtin slice struct registry 上限 diagnostic"
require_pattern "struct definition registry" "$C99_STRUCTS" "struct definition registry 上限 diagnostic"
require_pattern "enum definition registry" "$C99_ENUMS" "enum definition registry 上限 diagnostic"
require_pattern "simd struct registry" "$C99_TYPES" "SIMD struct registry 上限 diagnostic"
require_pattern "err union struct registry" "$C99_TYPES" "error union struct registry 上限 diagnostic"
require_pattern "async frame descriptor metadata" "$C99_MAIN" "async frame descriptor clamp diagnostic"
require_pattern "g_c99_codegen_has_error[[:space:]]*!=[[:space:]]*0" "$C99_MAIN" "生成结束前传播 registry diagnostic"

reject_pattern "if[[:space:]]+codegen\\.error_count[[:space:]]*>=[[:space:]]*C99_MAX_ERROR_IDS[[:space:]]*\\{[[:space:]]*return[[:space:]]+0;" "$C99_UTILS" "error id registry 满后直接 return 0"
reject_pattern "if[[:space:]]+codegen\\.string_constant_count[[:space:]]*>=[[:space:]]*C99_MAX_STRING_CONSTANTS[[:space:]]*\\{[[:space:]]*return[[:space:]]+null;" "$C99_UTILS" "string constant registry 满后直接 return null"
reject_pattern "if[[:space:]]+codegen\\.embedded_constant_count[[:space:]]*< 0 \\|\\| codegen\\.embedded_constant_count[[:space:]]*>=[[:space:]]*C99_MAX_EMBEDDED_CONSTANTS[[:space:]]*\\{[[:space:]]*return[[:space:]]+null;" "$C99_UTILS" "embedded constant registry 满后直接 return null"
reject_pattern "if[[:space:]]+codegen\\.embedded_dir_table_count[[:space:]]*< 0 \\|\\| codegen\\.embedded_dir_table_count[[:space:]]*>=[[:space:]]*C99_MAX_EMBED_DIR_TABLES[[:space:]]*\\{[[:space:]]*return[[:space:]]+null;" "$C99_UTILS" "embedded dir table registry 满后直接 return null"
reject_pattern "count[[:space:]]*>[[:space:]]*MAX_ASYNC_FRAME_METAS[[:space:]]*\\{[[:space:]]*count[[:space:]]*=[[:space:]]*MAX_ASYNC_FRAME_METAS;" "$C99_MAIN" "async frame descriptor count clamp"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
probe="$tmpdir/many_strings.uya"
out="$tmpdir/many_strings.out"
{
    echo "export fn main() i32 {"
    for i in $(seq 0 4096); do
        printf '    @println("registry_probe_%04d");\n' "$i"
    done
    echo "    return 0;"
    echo "}"
} > "$probe"

set +e
output="$(cd "$REPO_ROOT" && ./bin/uya build "$probe" -o "$out" --no-split-c 2>&1)"
status=$?
set -e
if [[ $status -eq 0 ]]; then
    echo "错误: 超过 C99_MAX_STRING_CONSTANTS 的程序仍然编译成功，疑似静默截断" >&2
    exit 1
fi
if ! grep -Fq "string constant registry" <<<"$output"; then
    echo "错误: 超过 C99_MAX_STRING_CONSTANTS 的程序未输出 string constant registry diagnostic" >&2
    echo "$output" >&2
    exit 1
fi

echo "✓ C99 registry/emitted metadata 上限路径均有明确 diagnostic"
