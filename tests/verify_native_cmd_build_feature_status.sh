#!/usr/bin/env bash

# Native build-seed 边界：验证 native cmd/build 子集 feature 状态矩阵覆盖每个 inventory 项。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"

if [[ ! -f "$DOC" ]]; then
    echo "错误: 缺少 $DOC" >&2
    exit 1
fi

grep -q '^## Native Support Status' "$DOC" || {
    echo "错误: native cmd/build feature status 缺少状态章节" >&2
    exit 1
}

for status in done partial missing not_required; do
    grep -q "\`$status\`" "$DOC" || {
        echo "错误: native cmd/build feature status 缺少状态说明: $status" >&2
        exit 1
    }
done

require_status() {
    local feature_id="$1"
    local status_pattern="$2"
    if ! grep -Eq "^\| ${feature_id} \| ${status_pattern} \|" "$DOC"; then
        echo "错误: feature ${feature_id} 缺少预期 native 状态: ${status_pattern}" >&2
        exit 1
    fi
}

require_status F01 partial
require_status F02 partial
require_status F03 missing
require_status F04 missing
require_status F05 missing
require_status F06 partial
require_status F07 partial
require_status F08 partial
require_status F09 partial
require_status F10 partial
require_status F11 partial
require_status F12 partial
require_status F13 partial
require_status F14 missing
require_status F15 partial
require_status F16 done

if grep -Eq '^\| F[0-9][0-9] \| (unknown|todo|tbd|yes|no) \|' "$DOC"; then
    echo "错误: native cmd/build feature status 含有非规范状态" >&2
    exit 1
fi

echo "verify_native_cmd_build_feature_status: ok (done=1 partial=11 missing=4)"
