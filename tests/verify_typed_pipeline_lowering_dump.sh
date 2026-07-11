#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UYA_COMPILER="${UYA_COMPILER:-$ROOT_DIR/bin/uya}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/uya-pipeline-lowering.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

compile_dump() {
    local source="$1"
    local output="$2"
    "$UYA_COMPILER" build "$ROOT_DIR/$source" \
        --project-root "$ROOT_DIR" --c99 --no-split-c -o "$output"
}

require_pattern() {
    local pattern="$1"
    local file="$2"
    local label="$3"
    if ! grep -E -q "$pattern" "$file"; then
        echo "typed pipeline lowering dump missing: $label" >&2
        exit 1
    fi
}

compile_dump tests/test_typed_pipeline_lowering.uya "$TMP_DIR/plain.c"
compile_dump tests/test_typed_pipeline_try_forward_lowering.uya "$TMP_DIR/try.c"

# 单个 transformer：一个 Pipeline 临时变量先后进入 transformer 和最终 sink。
require_pattern '__uya_pipe_tmp_[0-9]+ = inc\(__uya_pipe_tmp_[0-9]+\);.*value\(__uya_pipe_tmp_[0-9]+\)' "$TMP_DIR/plain.c" 'single transformer'

# 多个 transformer：整条链复用同一个 Pipeline 临时变量，未构造文本调用再解析。
require_pattern '__uya_pipe_tmp_[0-9]+ = inc\(__uya_pipe_tmp_[0-9]+\);.*__uya_pipe_tmp_[0-9]+ = add\(__uya_pipe_tmp_[0-9]+, 2\);' "$TMP_DIR/plain.c" 'multiple transformers'

# 最终 sink：sink 的非 Pipeline 返回值写入独立结果临时变量。
require_pattern '__uya_pipe_res_[0-9]+ = value\(__uya_pipe_tmp_[0-9]+\)' "$TMP_DIR/plain.c" 'final sink'

# !Pipeline try-forward：先求值错误联合、错误时返回，再提取 value 到 Pipeline 临时变量。
require_pattern 'struct err_union_Pipeline _uya_try_tmp = make_ok_pipeline\(\); if \(_uya_try_tmp.error_id != 0\)' "$TMP_DIR/try.c" '!Pipeline error propagation'
require_pattern 'struct Pipeline __uya_pipe_tmp_[0-9]+ = _uya_try_tmp.value' "$TMP_DIR/try.c" '!Pipeline payload extraction'

echo 'typed pipeline lowering dump verification passed'
