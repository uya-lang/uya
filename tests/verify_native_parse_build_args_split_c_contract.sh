#!/usr/bin/env bash

# Phase 10：固定 parse_build_args(...) split-C / async-frame CLI 合同。
# 该叶子只冻结 async-frame、--no-split-c、inline/separate --split-c-dir
# 的源码 surface、warning/default-dir 调用和 source-order frontier。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
NO_SILENT_TEST="$REPO_ROOT/tests/verify_native_cmd_build_no_silent_c99.sh"
STAGE1_TEST="$REPO_ROOT/tests/verify_native_cmd_build_stage1.sh"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: $description" >&2
        echo "文件: $file" >&2
        exit 1
    fi
}

require_pattern "$TODO_DOC" '为 split-C / async-frame CLI 补 CoreBody/PortableMIR 合同' \
    "todo 缺少 split-C / async-frame 合同任务"
require_pattern "$TODO_DOC" '迁入 `--async-frame-heap=on` 分支' \
    "todo 缺少 async-frame 实现任务"
require_pattern "$TODO_DOC" '迁入 `--no-split-c` 分支' \
    "todo 缺少 --no-split-c 实现任务"
require_pattern "$TODO_DOC" '迁入 inline `--split-c-dir=<dir>` disabled 分支' \
    "todo 缺少 inline --split-c-dir disabled 实现任务"
require_pattern "$TODO_DOC" '迁入 inline `--split-c-dir=<dir>` 成功/default 分支' \
    "todo 缺少 inline --split-c-dir 成功/default 实现任务"
require_pattern "$TODO_DOC" '迁入 separate `--split-c-dir <dir>` disabled-skip 分支' \
    "todo 缺少 separate --split-c-dir disabled-skip 实现任务"
require_pattern "$TODO_DOC" '迁入 separate `--split-c-dir <dir>` 成功/default 分支' \
    "todo 缺少 separate --split-c-dir 成功/default 实现任务"

require_pattern "$SUBSET_DOC" 'split-C CLI' \
    "subset doc 缺少 split-C CLI 合同"
require_pattern "$SUBSET_DOC" '`--async-frame-heap=on`' \
    "subset doc 缺少 async-frame surface"
require_pattern "$SUBSET_DOC" '`--no-split-c`' \
    "subset doc 缺少 --no-split-c surface"
require_pattern "$SUBSET_DOC" '`strncmp\("--split-c-dir=", 14\)`' \
    "subset doc 缺少 inline --split-c-dir strncmp surface"
require_pattern "$SUBSET_DOC" '`arg \+ 14` pointer arithmetic' \
    "subset doc 缺少 inline --split-c-dir pointer arithmetic surface"
require_pattern "$SUBSET_DOC" '`PATH_MAX - 1`' \
    "subset doc 缺少 split-C PATH_MAX surface"
require_pattern "$SUBSET_DOC" '`--split-c-dir <dir>` 的可选参数跳过' \
    "subset doc 缺少 separate --split-c-dir skip surface"
require_pattern "$SUBSET_DOC" '`split_c_set_default_dir\(\)` 调用' \
    "subset doc 缺少 split_c_set_default_dir 调用 surface"
require_pattern "$SUBSET_DOC" 'covered_branch=--async-frame-heap=on next_branch=--no-split-c' \
    "subset doc 缺少 async-frame 后 frontier"
require_pattern "$SUBSET_DOC" 'covered_branch=--no-split-c next_branch=--split-c-dir-inline-disabled' \
    "subset doc 缺少 --no-split-c 后 frontier"
require_pattern "$SUBSET_DOC" 'covered_branch=--split-c-dir-inline-disabled next_branch=--split-c-dir-inline-success' \
    "subset doc 缺少 inline split-c disabled 后 frontier"
require_pattern "$SUBSET_DOC" 'covered_branch=--split-c-dir-inline next_branch=--split-c-dir-separate-disabled' \
    "subset doc 缺少 inline split-c 完成后 frontier"
require_pattern "$SUBSET_DOC" 'covered_branch=--split-c-dir-separate-disabled next_branch=--split-c-dir-separate-success' \
    "subset doc 缺少 separate split-c disabled 后 frontier"
require_pattern "$SUBSET_DOC" 'covered_branch=--split-c-dir next_branch=positional-input' \
    "subset doc 缺少 separate split-c 完成后 positional frontier"

require_pattern "$BUILD_DRIVER_SRC" 'else if strcmp\(arg, "--async-frame-heap=on" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --async-frame-heap=on 分支"
require_pattern "$BUILD_DRIVER_SRC" 'async_frame_heap_fallback\[0\] = 1;' \
    "parse_build_args 源码缺少 async frame out-param 写入"
require_pattern "$BUILD_DRIVER_SRC" 'else if strcmp\(arg, "--no-split-c" as \*byte\) == 0' \
    "parse_build_args 源码缺少 --no-split-c 分支"
require_pattern "$BUILD_DRIVER_SRC" 'g_split_c_disabled_cli = 1;' \
    "parse_build_args 源码缺少 --no-split-c disabled 写入"
require_pattern "$BUILD_DRIVER_SRC" 'g_split_c_dir_active = 0;' \
    "parse_build_args 源码缺少 --no-split-c active 清零"
require_pattern "$BUILD_DRIVER_SRC" 'g_split_c_dir\[0\] = 0 as byte;' \
    "parse_build_args 源码缺少 --no-split-c dir 清零"
require_pattern "$BUILD_DRIVER_SRC" 'strncmp\(arg as &const byte, "--split-c-dir=" as &const byte, 14\) == 0' \
    "parse_build_args 源码缺少 inline --split-c-dir strncmp"
require_pattern "$BUILD_DRIVER_SRC" '警告: 已指定 --no-split-c，忽略 --split-c-dir' \
    "parse_build_args 源码缺少 split-C disabled warning"
require_pattern "$BUILD_DRIVER_SRC" 'const split_dir_inline: \*byte = arg \+ 14;' \
    "parse_build_args 源码缺少 inline --split-c-dir arg + 14"
require_pattern "$BUILD_DRIVER_SRC" 'const sl: usize = strlen\(split_dir_inline\);' \
    "parse_build_args 源码缺少 inline --split-c-dir strlen"
require_pattern "$BUILD_DRIVER_SRC" 'sl < PATH_MAX - 1' \
    "parse_build_args 源码缺少 split-C PATH_MAX - 1 检查"
require_pattern "$BUILD_DRIVER_SRC" 'strcpy\(&g_split_c_dir\[0\] as \*byte, split_dir_inline\);' \
    "parse_build_args 源码缺少 inline --split-c-dir strcpy"
require_pattern "$BUILD_DRIVER_SRC" 'g_split_c_dir_active = 1;' \
    "parse_build_args 源码缺少 split-C active 写入"
require_pattern "$BUILD_DRIVER_SRC" 'split_c_set_default_dir\(\);' \
    "parse_build_args 源码缺少 split-C default-dir 调用"
require_pattern "$BUILD_DRIVER_SRC" 'else if strcmp\(arg, "--split-c-dir" as \*byte\) == 0' \
    "parse_build_args 源码缺少 separate --split-c-dir 分支"
require_pattern "$BUILD_DRIVER_SRC" 'const sd_skip: \*byte = get_argv\(i \+ 1\);' \
    "parse_build_args 源码缺少 separate --split-c-dir disabled skip get_argv"
require_pattern "$BUILD_DRIVER_SRC" 'sd_skip != null && sd_skip\[0\] != 45 as byte' \
    "parse_build_args 源码缺少 separate --split-c-dir disabled skip 判定"
require_pattern "$BUILD_DRIVER_SRC" 'const sd: \*byte = get_argv\(i \+ 1\);' \
    "parse_build_args 源码缺少 separate --split-c-dir get_argv"
require_pattern "$BUILD_DRIVER_SRC" 'const sl: usize = strlen\(sd\);' \
    "parse_build_args 源码缺少 separate --split-c-dir strlen"
require_pattern "$BUILD_DRIVER_SRC" 'strcpy\(&g_split_c_dir\[0\] as \*byte, sd\);' \
    "parse_build_args 源码缺少 separate --split-c-dir strcpy"

require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_async_frame_if_supported' \
    "生产代码缺少 async-frame branch shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_async_frame_body' \
    "生产代码缺少 async-frame body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_no_split_c_if_supported' \
    "生产代码缺少 --no-split-c branch shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_no_split_c_body' \
    "生产代码缺少 --no-split-c body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_split_c_inline_disabled_if_supported' \
    "生产代码缺少 inline --split-c-dir disabled branch shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_split_c_inline_disabled_body' \
    "生产代码缺少 inline --split-c-dir disabled body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_split_c_inline_success_if_supported' \
    "生产代码缺少 inline --split-c-dir success/default branch shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_split_c_inline_success_body' \
    "生产代码缺少 inline --split-c-dir success/default body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_split_c_separate_disabled_if_supported' \
    "生产代码缺少 separate --split-c-dir disabled branch shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_split_c_separate_disabled_body' \
    "生产代码缺少 separate --split-c-dir disabled body/frontier 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_split_c_separate_success_if_supported' \
    "生产代码缺少 separate --split-c-dir success/default branch shape recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_split_c_separate_success_body' \
    "生产代码缺少 separate --split-c-dir success/default body/frontier 判定"
require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=18 covered_branch=positional-input-capacity next_branch=positional-input-store next_kind=AST_VAR_DECL reason=partial_else_if_chain' \
    "no-silent-C99 测试必须固定位置输入容量检查后的 store frontier"
require_pattern "$NO_SILENT_TEST" 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' \
    "no-silent-C99 测试缺少 lowering-missing 明确拒绝"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_split_c_contract\.sh' \
    "stage1 未纳入 parse_build_args split-C / async-frame 合同"

echo "verify_native_parse_build_args_split_c_contract: ok"
