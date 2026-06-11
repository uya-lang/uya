#!/usr/bin/env bash

# Native build-seed 边界：验证 native cmd/build 子集 feature inventory 文档存在且覆盖关键需求类别。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"

if [[ ! -f "$DOC" ]]; then
    echo "错误: 缺少 $DOC" >&2
    exit 1
fi

require_doc_pattern() {
    local pattern="$1"
    local description="$2"
    if ! grep -Eq "$pattern" "$DOC"; then
        echo "错误: native cmd/build feature inventory 缺少: $description" >&2
        exit 1
    fi
}

require_doc_pattern '^# Native `cmd/build` 子集清单' "标题"
require_doc_pattern '当前实测依赖数:[[:space:]]*83' "当前依赖数"
require_doc_pattern 'src/cmd/build/main\.uya' "build root"
require_doc_pattern 'src/build_compiler_driver\.uya' "build driver"
require_doc_pattern 'src/checker_build/\*\.uya' "checker_build 边界"
require_doc_pattern 'src/codegen/c99_build/\*\.uya' "c99_build 边界"
require_doc_pattern 'F01[[:space:]]*\| CLI / process entry' "CLI/process feature"
require_doc_pattern 'F02[[:space:]]*\| Source / module IO' "source/module IO feature"
require_doc_pattern 'F03[[:space:]]*\| Lexer / parser / AST' "lexer/parser/AST feature"
require_doc_pattern 'F04[[:space:]]*\| Semantic / typed program' "semantic/typed feature"
require_doc_pattern 'F05[[:space:]]*\| Checker / safety proof' "checker/proof feature"
require_doc_pattern 'F06[[:space:]]*\| 复合类型' "复合类型 feature"
require_doc_pattern 'F07[[:space:]]*\| 控制流和错误处理' "控制流/错误处理 feature"
require_doc_pattern 'F08[[:space:]]*\| 泛型 / 方法 / 接口' "泛型/接口 feature"
require_doc_pattern 'F09[[:space:]]*\| 动态表' "动态表 feature"
require_doc_pattern 'F10[[:space:]]*\| intern / hash / string' "intern/hash/string feature"
require_doc_pattern 'F11[[:space:]]*\| 内存管理' "内存管理 feature"
require_doc_pattern 'F12[[:space:]]*\| diagnostics / formatting' "diagnostics/formatting feature"
require_doc_pattern 'F13[[:space:]]*\| C99 build backend' "C99 build backend feature"
require_doc_pattern 'F14[[:space:]]*\| Host toolchain / filesystem' "host toolchain feature"
require_doc_pattern 'F15[[:space:]]*\| Metrics / benchmark' "metrics feature"
require_doc_pattern 'F16[[:space:]]*\| 显式非需求' "显式非需求 feature"

tmp_dir="$(mktemp -d /tmp/uya-native-cmd-build-feature.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

UYA_ROOT="$REPO_ROOT" "$REPO_ROOT/bin/uya" build "$REPO_ROOT/src/cmd/build/main.uya" \
    -o "$tmp_dir/cmd-build" --no-split-c --project-root "$REPO_ROOT/src/" \
    >"$tmp_dir/build.out" 2>"$tmp_dir/build.err"

dep_count="$(awk '/输入文件数量:/ { print $2; exit }' "$tmp_dir/build.err")"
if [[ "$dep_count" != "83" ]]; then
    echo "错误: cmd/build 当前依赖数与 feature inventory 不一致: ${dep_count:-unknown}" >&2
    exit 1
fi

echo "verify_native_cmd_build_feature_inventory: ok (deps=$dep_count features=16)"
