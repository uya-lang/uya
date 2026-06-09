#!/usr/bin/env bash

# Phase 10：固定 parse_build_args(...) 收尾输出路径检查合同。
# 该合同只冻结无输入、显式输出路径、.c 推断和 native .c 拒绝的源码 surface
# 与当前 frontier；不要求本叶子改生产 lowering 实现。

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

require_pattern "$TODO_DOC" '为收尾输出路径检查补 CoreBody/PortableMIR 合同' \
    "todo 缺少 parse_build_args 收尾合同任务"
require_pattern "$TODO_DOC" '迁入未指定输入文件分支' \
    "todo 缺少未指定输入文件实现任务"
require_pattern "$TODO_DOC" '迁入显式输出路径读取分支' \
    "todo 缺少显式输出路径读取实现任务"
require_pattern "$TODO_DOC" '迁入 `\.c` 输出推断 C99 分支' \
    "todo 缺少 .c 输出推断 C99 实现任务"
require_pattern "$TODO_DOC" '迁入 `--native` 输出 `\.c` 拒绝分支' \
    "todo 缺少 native .c 拒绝实现任务"

require_pattern "$SUBSET_DOC" 'Tail Output Contract' \
    "subset doc 缺少 parse_build_args tail 合同章节"
require_pattern "$SUBSET_DOC" '无输入文件分支：`input_file_count\[0\] == 0`' \
    "subset doc 缺少无输入文件 surface"
require_pattern "$SUBSET_DOC" '`program_name != null`、`print_usage\(program_name as &byte\)`' \
    "subset doc 缺少 print_usage surface"
require_pattern "$SUBSET_DOC" '显式输出路径读取：`const out_idx: i32 = output_file_index\[0\]`' \
    "subset doc 缺少 out_idx surface"
require_pattern "$SUBSET_DOC" '`get_argv\(out_idx\)`、null 输出路径 diagnostic' \
    "subset doc 缺少 out path null diagnostic surface"
require_pattern "$SUBSET_DOC" '`backend_type\[0\] == BackendType\.BACKEND_LLVM`、`strrchr\(out_path, 46\)`' \
    "subset doc 缺少 .c 推断入口 surface"
require_pattern "$SUBSET_DOC" '`backend_type\[0\] = BackendType\.BACKEND_C99`' \
    "subset doc 缺少 C99 backend 写入 surface"
require_pattern "$SUBSET_DOC" '`is_c_output\(out_path as &byte\) != 0`' \
    "subset doc 缺少 native .c 拒绝 surface"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_frontier: function=parse_build_args prefix_stmts=25 next_stmt=25 next_kind=AST_VAR_DECL reason=partial_core_body' \
    "subset doc 缺少 parse_build_args tail out_idx frontier"
require_pattern "$SUBSET_DOC" 'covered_branch=positional-input next_branch=parse-tail-input-count next_kind=AST_IF_STMT' \
    "subset doc 缺少 parse tail loop-body frontier"

require_pattern "$BUILD_DRIVER_SRC" 'if input_file_count\[0\] == 0' \
    "parse_build_args 源码缺少无输入文件分支"
require_pattern "$BUILD_DRIVER_SRC" 'fprintf\(libc\.stderr, "错误: 未指定输入文件\\n" as \*byte\);' \
    "parse_build_args 源码缺少未指定输入 diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'if program_name != null' \
    "parse_build_args 源码缺少 program_name guard"
require_pattern "$BUILD_DRIVER_SRC" 'print_usage\(program_name as &byte\);' \
    "parse_build_args 源码缺少 print_usage 调用"
require_pattern "$BUILD_DRIVER_SRC" 'const out_idx: i32 = output_file_index\[0\];' \
    "parse_build_args 源码缺少 out_idx 声明"
require_pattern "$BUILD_DRIVER_SRC" 'if out_idx >= 0' \
    "parse_build_args 源码缺少 out_idx >= 0 分支"
require_pattern "$BUILD_DRIVER_SRC" 'const out_path: \*byte = get_argv\(out_idx\);' \
    "parse_build_args 源码缺少 get_argv(out_idx)"
require_pattern "$BUILD_DRIVER_SRC" 'if out_path == null' \
    "parse_build_args 源码缺少 out_path null guard"
require_pattern "$BUILD_DRIVER_SRC" '错误: 无法获取输出文件路径（索引 %d）' \
    "parse_build_args 源码缺少 out_path null diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'if backend_type\[0\] == BackendType\.BACKEND_LLVM' \
    "parse_build_args 源码缺少 backend LLVM/C99 推断分支"
require_pattern "$BUILD_DRIVER_SRC" 'const ext: \*byte = strrchr\(out_path, 46\);' \
    "parse_build_args 源码缺少 strrchr(out_path, '.')"
require_pattern "$BUILD_DRIVER_SRC" 'if ext != null && strcmp\(ext, "\.c" as \*byte\) == 0' \
    "parse_build_args 源码缺少 .c 后缀比较"
require_pattern "$BUILD_DRIVER_SRC" 'backend_type\[0\] = BackendType\.BACKEND_C99;' \
    "parse_build_args 源码缺少 .c 输出推断 C99 写入"
require_pattern "$BUILD_DRIVER_SRC" 'if backend_type\[0\] == BackendType\.BACKEND_NATIVE && is_c_output\(out_path as &byte\) != 0' \
    "parse_build_args 源码缺少 native .c 拒绝分支"
require_pattern "$BUILD_DRIVER_SRC" '错误: --native 不能输出 \.c 文件；C 输出请使用 --c99' \
    "parse_build_args 源码缺少 native .c 拒绝 diagnostic"
require_pattern "$BUILD_DRIVER_SRC" 'return 0;' \
    "parse_build_args 源码缺少收尾 return 0"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_tail_no_input_if_supported' \
    "生产代码缺少 tail 无输入文件 recognizer"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_parse_build_args_tail_no_input_body' \
    "生产代码缺少 tail 无输入文件 body/frontier 判定"

require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_frontier: function=parse_build_args prefix_stmts=25 next_stmt=25 next_kind=AST_VAR_DECL reason=partial_core_body' \
    "no-silent-C99 测试缺少 parse_build_args tail out_idx frontier"
require_pattern "$NO_SILENT_TEST" 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' \
    "no-silent-C99 测试缺少 lowering-missing 明确拒绝"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_tail_contract\.sh' \
    "stage1 未纳入 parse_build_args 收尾合同"

echo "verify_native_parse_build_args_tail_contract: ok"
