#!/usr/bin/env bash

# Phase 10：固定 set_process_stack_limit_bytes(...) 首个 Linux x86_64
# CoreBody/PortableMIR 合同切片，并验证生产 preflight lowering 已接线。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
ENTRY_SRC="$REPO_ROOT/lib/std/runtime/entry/entry.uya"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
CORE_FILE="$REPO_ROOT/src/lower/core.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
MIR_VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
COREIR_GOLDEN_TEST="$REPO_ROOT/tests/verify_coreir_dump_golden.sh"
MIR_GOLDEN_TEST="$REPO_ROOT/tests/verify_portable_mir_golden.sh"
MIR_VERIFIER_TEST="$REPO_ROOT/tests/verify_portable_mir_verifier.sh"
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

for file in "$TODO_DOC" "$SUBSET_DOC" "$ENTRY_SRC" "$BUILD_DRIVER_SRC" "$CORE_FILE" "$MIR_FILE" \
    "$MIR_VERIFIER_FILE" "$COREIR_GOLDEN_TEST" "$MIR_GOLDEN_TEST" \
    "$MIR_VERIFIER_TEST" "$NO_SILENT_TEST" "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TODO_DOC" '为 `set_process_stack_limit_bytes\(\.\.\.\)` 的首个最小切片补 CoreBody/PortableMIR' \
    "todo 缺少 stack-limit 首切片合同任务"
require_pattern "$TODO_DOC" 'SYS_setrlimit_x86_64 = 160' \
    "todo 缺少 x86_64 setrlimit syscall 号"
require_pattern "$TODO_DOC" '@syscall\(\.\.\. ENTRY_RLIMIT_STACK \.\.\. &rlim \.\.\.\)' \
    "todo 缺少 syscall/rlim 首切片说明"

require_pattern "$SUBSET_DOC" '^## `set_process_stack_limit_bytes\(\.\.\.\)` PortableMIR Surface Audit' \
    "subset doc 缺少 stack-limit surface audit"
require_pattern "$SUBSET_DOC" '^## `set_process_stack_limit_bytes\(\.\.\.\)` First Slice Contract' \
    "subset doc 缺少 stack-limit first slice contract"
require_pattern "$SUBSET_DOC" 'Linux x86_64 首切片' \
    "subset doc 缺少 Linux x86_64 首切片范围"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_LOCAL_DECL' \
    "subset doc 缺少 EntryRLimit local decl CoreIR 合同"
require_pattern "$SUBSET_DOC" 'CORE_EXPR_KIND_CALL' \
    "subset doc 缺少 syscall CoreIR call 合同"
require_pattern "$SUBSET_DOC" 'CORE_SEMANTIC_FACT_CAPABILITY' \
    "subset doc 缺少 syscall capability fact 合同"
require_pattern "$SUBSET_DOC" 'MIR_INST_OP_CALL' \
    "subset doc 缺少 PortableMIR call inst 合同"
require_pattern "$SUBSET_DOC" 'MIR_CALL_ABI_PROFILE_FREESTANDING_SYSCALL' \
    "subset doc 缺少 freestanding syscall ABI 合同"
require_pattern "$SUBSET_DOC" 'MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY' \
    "subset doc 缺少 capability verifier 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_callee_frontier: parent=build_compiler_driver_run stmt=17 first_unresolved_callee=set_process_stack_limit_bytes reason=pending_core_body' \
    "subset doc 缺少当前 stack-limit frontier"

require_pattern "$ENTRY_SRC" 'export fn set_process_stack_limit_bytes\(limit_bytes: u64\) void' \
    "entry runtime 缺少 stack-limit helper 签名"
require_pattern "$ENTRY_SRC" 'struct EntryRLimit' \
    "entry runtime 缺少 EntryRLimit 结构体"
require_pattern "$ENTRY_SRC" 'rlim_cur: limit_bytes' \
    "entry runtime 缺少 rlim_cur 初始化"
require_pattern "$ENTRY_SRC" 'rlim_max: limit_bytes' \
    "entry runtime 缺少 rlim_max 初始化"
require_pattern "$ENTRY_SRC" 'const ENTRY_RLIMIT_STACK: i32 = 3;' \
    "entry runtime 缺少 RLIMIT_STACK 常量"
require_pattern "$ENTRY_SRC" 'std\.cfg\(std\.target_os == \.tos_linux' \
    "entry runtime 缺少 Linux target gate"
require_pattern "$ENTRY_SRC" 'std\.cfg\(std\.target_arch == \.ta_x86_64' \
    "entry runtime 缺少 x86_64 arch gate"
require_pattern "$ENTRY_SRC" 'const SYS_setrlimit_x86_64: i64 = 160;' \
    "entry runtime 缺少 x86_64 setrlimit syscall 号"
require_pattern "$ENTRY_SRC" '@syscall\(SYS_setrlimit_x86_64, ENTRY_RLIMIT_STACK as i64, &rlim as i64\)' \
    "entry runtime 缺少 x86_64 setrlimit syscall"
require_pattern "$ENTRY_SRC" 'setrlimit_result_x86_64 catch \{ 0i64; \};' \
    "entry runtime 缺少 x86_64 catch-ignore 语义"

require_pattern "$CORE_FILE" 'CORE_STMT_KIND_LOCAL_DECL' \
    "CoreIR 缺少 local decl statement kind"
require_pattern "$CORE_FILE" 'CORE_EXPR_KIND_CALL' \
    "CoreIR 缺少 call expression kind"
require_pattern "$CORE_FILE" 'CORE_SEMANTIC_FACT_CAPABILITY' \
    "CoreIR 缺少 capability semantic fact"
require_pattern "$CORE_FILE" 'CORE_CAPABILITY_SYSCALL' \
    "CoreIR 缺少 syscall capability 常量"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_decl_can_materialize_stack_limit_body' \
    "build driver 缺少 stack-limit CoreBody materialize 判定"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_coreir_append_stack_limit_body' \
    "build driver 缺少 stack-limit CoreIR builder"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_mir_append_stack_limit_body_function' \
    "build driver 缺少 stack-limit PortableMIR builder"
require_pattern "$BUILD_DRIVER_SRC" 'CORE_CAPABILITY_SYSCALL' \
    "build driver stack-limit CoreIR 未记录 syscall capability"
require_pattern "$COREIR_GOLDEN_TEST" 'CORE_SEMANTIC_FACT_CAPABILITY' \
    "CoreIR golden 缺少 capability fact 覆盖"
require_pattern "$COREIR_GOLDEN_TEST" 'CORE_EXPR_KIND_CALL' \
    "CoreIR golden 缺少 call expr 覆盖"

require_pattern "$MIR_FILE" 'MIR_INST_OP_CALL' \
    "PortableMIR 缺少 call inst"
require_pattern "$MIR_FILE" 'MIR_CALL_ABI_PROFILE_FREESTANDING_SYSCALL' \
    "PortableMIR 缺少 syscall ABI profile"
require_pattern "$MIR_FILE" 'runtime_capability_mask' \
    "PortableMIR 缺少 runtime capability mask 字段"
require_pattern "$MIR_FILE" 'MirCapabilityReq' \
    "PortableMIR 缺少 capability requirement 结构"
require_pattern "$MIR_GOLDEN_TEST" 'MIR_INST_OP_CALL' \
    "PortableMIR golden 缺少 call inst 覆盖"
require_pattern "$MIR_VERIFIER_FILE" 'MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY' \
    "PortableMIR verifier 缺少 target capability 错误"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_call_abi_supported' \
    "PortableMIR verifier 缺少 call ABI gate"
require_pattern "$MIR_VERIFIER_FILE" 'portable_mir_verify_runtime_capability_supported' \
    "PortableMIR verifier 缺少 runtime capability gate"
require_pattern "$MIR_VERIFIER_TEST" 'MIR_VERIFY_ERR_UNSUPPORTED_TARGET_CAPABILITY' \
    "PortableMIR verifier 测试缺少 unsupported capability 覆盖"

require_pattern "$NO_SILENT_TEST" 'core_bodies=40' \
    "no-silent-C99 测试缺少 stack-limit 之后的 CoreBody 计数"
require_pattern "$NO_SILENT_TEST" 'mir_body_functions=39' \
    "no-silent-C99 测试缺少 stack-limit 之后的 MIR body 计数"
require_pattern "$NO_SILENT_TEST" '不应在 stack-limit helper 首切片迁入后继续报告 set_process_stack_limit_bytes pending callee' \
    "no-silent-C99 测试缺少旧 stack-limit frontier 反向检查"
require_pattern "$STAGE1_TEST" 'verify_native_stack_limit_helper_contract\.sh' \
    "stage1 未纳入 stack-limit helper 合同"

echo "verify_native_stack_limit_helper_contract: ok"
