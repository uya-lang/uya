#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GLOBAL_FILE="$REPO_ROOT/src/codegen/c99/global.uya"
TYPES_FILE="$REPO_ROOT/src/codegen/c99/types.uya"
COMPILER="$REPO_ROOT/bin/uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: C99 安全热点缓存 key 缺少证据: $description" >&2
        exit 1
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "错误: C99 安全热点缓存 key 仍包含旧风险: $description" >&2
        exit 1
    fi
}

for file in "$GLOBAL_FILE" "$TYPES_FILE" "$COMPILER"; do
    if [[ ! -e "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TYPES_FILE" "fn c99_identifier_cache_template_decl" "template 声明 key helper"
require_pattern "$TYPES_FILE" "fn c99_identifier_cache_mono_signature_id" "mono signature key helper"
require_pattern "$TYPES_FILE" "function_scope_index_current_generation\\(&codegen\\.checker\\.function_scope_index" "local generation key helper"
require_pattern "$TYPES_FILE" "fn c99_identifier_cache_async_frame_id" "async frame key helper"

require_pattern "$GLOBAL_FILE" "g_c99_ident_ref_template_decls" "identifier-ref cache 存储 template key"
require_pattern "$GLOBAL_FILE" "g_c99_ident_ref_mono_signature_ids" "identifier-ref cache 存储 mono signature key"
require_pattern "$GLOBAL_FILE" "g_c99_ident_ref_local_generations" "identifier-ref cache 存储 local generation key"
require_pattern "$GLOBAL_FILE" "g_c99_ident_ref_async_frame_ids" "identifier-ref cache 存储 async frame key"
require_pattern "$TYPES_FILE" "g_c99_identifier_type_template_decls" "identifier-type cache 存储 template key"
require_pattern "$TYPES_FILE" "g_c99_identifier_type_mono_signature_ids" "identifier-type cache 存储 mono signature key"
require_pattern "$TYPES_FILE" "g_c99_identifier_type_local_generations" "identifier-type cache 存储 local generation key"
require_pattern "$TYPES_FILE" "g_c99_identifier_type_async_frame_ids" "identifier-type cache 存储 async frame key"

require_pattern "$GLOBAL_FILE" "c99_identifier_cache_key_matches\\(codegen" "identifier-ref cache 命中校验完整 key"
require_pattern "$TYPES_FILE" "c99_identifier_cache_key_matches\\(codegen" "identifier-type cache 命中校验完整 key"
require_pattern "$GLOBAL_FILE" "c99_identifier_cache_slot\\(codegen, name" "identifier-ref cache slot 使用安全 key helper"
require_pattern "$TYPES_FILE" "c99_identifier_cache_slot\\(codegen, name" "identifier-type cache slot 使用安全 key helper"

reject_pattern "$GLOBAL_FILE" "g_c99_ident_ref_local_counts|local_variable_count[[:space:]]*\\*" "identifier-ref cache 回退到 local_variable_count"
reject_pattern "$TYPES_FILE" "g_c99_identifier_type_local_counts|local_variable_count[[:space:]]*\\*" "identifier-type cache 回退到 local_variable_count"

tmp_dir="$(mktemp -d /tmp/uya-c99-safe-hot-cache-key.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

"$COMPILER" test "$REPO_ROOT/tests/test_generic_multi_instance.uya" --no-split-c >/dev/null
"$COMPILER" test "$REPO_ROOT/tests/test_generic_template_multi_instance_var_types.uya" --no-split-c >/dev/null
"$COMPILER" build "$REPO_ROOT/tests/test_async_await_direct_err_union.uya" --c99 --no-split-c -O0 -o "$tmp_dir/async.c" >/dev/null
"$COMPILER" build "$REPO_ROOT/tests/test_async_loop_var_generic.uya" --c99 --no-split-c -O0 -o "$tmp_dir/async_generic.c" >/dev/null

echo "✓ C99 generic/async hot caches use template/mono/generation/async-frame keys"
