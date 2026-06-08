#!/usr/bin/env bash

# Phase 9A/10：固定 freestanding native cmd/build 只是 build-seed 回归边界，
# hosted native 完整语言 parity 不依赖该子集继续扩张。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"
COREIR_DOC="$REPO_ROOT/docs/coreir_lowered_program_whitepaper.md"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"
NO_SILENT_TEST="$REPO_ROOT/tests/verify_native_cmd_build_no_silent_c99.sh"
LOWERED_BODY_CONTRACT_TEST="$REPO_ROOT/tests/verify_lowered_body_op_transition_contract.sh"
STAGE1_TEST="$REPO_ROOT/tests/verify_native_cmd_build_stage1.sh"
DRIVER_SRC="$REPO_ROOT/src/compiler_driver.uya"
NATIVE_BUILD_SRC="$REPO_ROOT/src/codegen/native_build/main.uya"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"

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

require_pattern "$SUBSET_DOC" 'Phase 10 的 native 子集只面向 freestanding `cmd/build` seed，不定义完整' \
    "cmd/build subset doc 缺少 freestanding seed 范围"
require_pattern "$SUBSET_DOC" '完整语言 native parity 转由 `PortableMIR` \+ hosted native 路线承接' \
    "cmd/build subset doc 缺少 hosted native 主线路径"
require_pattern "$SUBSET_DOC" '^## Regression Boundary Contract' \
    "cmd/build subset doc 缺少回归边界合同章节"
require_pattern "$SUBSET_DOC" 'freestanding native `cmd/build` seed 只记录 build-seed 回归边界' \
    "cmd/build subset doc 缺少 build-seed 回归边界说明"
require_pattern "$SUBSET_DOC" '不能成为 hosted native 完整语言 parity 的前置条件' \
    "cmd/build subset doc 缺少不阻塞 hosted parity 说明"
require_pattern "$SUBSET_DOC" '已经通过 `CoreBody` / `PortableMIR` lowering、MIR verifier 和 hosted native / C99' \
    "cmd/build subset doc 缺少 MIR 通过后再下沉规则"
require_pattern "$SUBSET_DOC" '不再为 `compile_files\(\.\.\.\)`' \
    "cmd/build subset doc 缺少 compile_files one-off 禁止规则"
require_pattern "$SUBSET_DOC" '`compile_files\(\.\.\.\)` 16 参数' \
    "cmd/build subset doc 缺少 compile_files 16 参数验收输入"
require_pattern "$SUBSET_DOC" 'call ABI 和 target capability verifier' \
    "cmd/build subset doc 缺少 hosted native call ABI 验收边界"
require_pattern "$SUBSET_DOC" 'tests/verify_native_cmd_build_no_silent_c99\.sh' \
    "cmd/build subset doc 缺少 no-silent-C99 门禁引用"
require_pattern "$SUBSET_DOC" '不能生成伪 native 输出，也不能静默回落 C99' \
    "cmd/build subset doc 缺少失败语义"

require_pattern "$ARCH_DOC" 'hosted native 完整语言 parity：第一阶段以 C99 为 oracle' \
    "architecture doc 缺少 hosted native C99 oracle 范围"
require_pattern "$ARCH_DOC" '已迁 MIR 的 shard 真实运行一致，未迁 MIR 的复杂' \
    "architecture doc 缺少已迁 MIR shard 的真实运行范围"
require_pattern "$ARCH_DOC" 'shard 先保持 explicit reject' \
    "architecture doc 缺少未迁 MIR shard 明确拒绝规则"
require_pattern "$ARCH_DOC" 'freestanding native build-seed：保留 Phase 10 `cmd/build` 子集，后续从已通过 MIR 的能力逐步下沉' \
    "architecture doc 缺少 freestanding build-seed 下沉规则"
require_pattern "$ARCH_DOC" 'freestanding native build-seed 失败只能阻塞 build-seed 里程碑，不能阻塞 hosted native 完整语言 parity' \
    "architecture doc 缺少 freestanding 不阻塞 hosted parity 规则"
require_pattern "$ARCH_DOC" 'helper 只作为 Phase 10 freestanding 回归边界保留，不能作为 hosted native 完整语言主路径' \
    "architecture doc 缺少 LoweredProgram helper 边界"

require_pattern "$COREIR_DOC" '`compile_files\(\.\.\.\)` 16 参数缺口必须通过 CoreBody \+ PortableMIR 解决' \
    "CoreIR whitepaper 缺少 compile_files 16 参数 CoreBody/PortableMIR 验收规则"
require_pattern "$COREIR_DOC" '用 `compile_files\(\.\.\.\)` 作为第一个大型 CoreIR \+ MIR 验收样本' \
    "CoreIR whitepaper 缺少 compile_files 大型验收样本"
require_pattern "$PORTABLE_MIR_DOC" '`compile_files\(\.\.\.\)` 缺口应成为 MIR \+ ABI 验收样本' \
    "PortableMIR whitepaper 缺少 MIR + ABI 验收样本边界"
require_pattern "$PORTABLE_MIR_DOC" '增加 call ABI metadata 和 hosted extern calls' \
    "PortableMIR whitepaper 缺少 call ABI lowering slice"
require_pattern "$PORTABLE_MIR_DOC" '使用 `compile_files\(\.\.\.\)` 作为第一个大型真实 MIR 验收样本' \
    "PortableMIR whitepaper 缺少 compile_files 真实 MIR 验收样本"
require_pattern "$PORTABLE_MIR_DOC" '`compile_files\(\.\.\.\)` 16 参数调用通过 CoreBody \+ MIR lower 到达' \
    "PortableMIR whitepaper 缺少 compile_files 16 参数 MIR 到达标准"

require_pattern "$NO_SILENT_TEST" 'run_hosted_reject_check' \
    "no-silent-C99 测试缺少 hosted native handoff reject"
require_pattern "$NO_SILENT_TEST" 'native_hosted_coreir_preflight: status=0 verifier_error=0 functions=' \
    "no-silent-C99 测试缺少 hosted CoreIR function inventory preflight 证据"
require_pattern "$NO_SILENT_TEST" 'native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=' \
    "no-silent-C99 测试缺少 hosted PortableMIR preflight 证据"
require_pattern "$NO_SILENT_TEST" 'mir_body_functions=' \
    "no-silent-C99 测试缺少 hosted PortableMIR body function lowering 证据"
require_pattern "$NO_SILENT_TEST" 'native_hosted_portable_mir_lowering_missing' \
    "no-silent-C99 测试缺少 hosted 函数体 MIR lowering 缺口"
require_pattern "$NO_SILENT_TEST" 'build-seed LoweredProgram helper 仅限 --nostdlib freestanding 子集' \
    "no-silent-C99 测试缺少 hosted/build-seed 分界"
require_pattern "$NO_SILENT_TEST" 'run_cmd_build_self_preflight_check' \
    "no-silent-C99 测试缺少 hosted cmd/build self-build preflight"
require_pattern "$NO_SILENT_TEST" '[[:space:]]--native --no-split-c' \
    "no-silent-C99 测试缺少 hosted cmd/build self-build 命令"
require_pattern "$NO_SILENT_TEST" 'native_hosted_coreir_preflight: status=0 verifier_error=0 functions=' \
    "no-silent-C99 测试缺少 cmd/build self-build verifier-clean CoreIR preflight"
require_pattern "$NO_SILENT_TEST" 'native_hosted_entry_frontier: wrapper_covered=1 first_pending_callee=build_compiler_driver_run first_pending_callee_prefix=1 first_pending_callee_prefix_stmts=39 first_pending_callee_next_stmt=-1 first_pending_callee_next_kind=<none>' \
    "no-silent-C99 测试缺少 cmd/build entry wrapper 覆盖证据"
require_pattern "$NO_SILENT_TEST" 'native_hosted_entry_child_frontier: first_pending_callee=build_compiler_driver_run parent_stmt=37 child_prefix=1 child_prefix_stmts=7 child_next_stmt=-1 child_next_kind=<none>' \
    "no-silent-C99 测试缺少 cmd/build link-output child frontier 覆盖证据"
require_pattern "$NO_SILENT_TEST" 'native_hosted_handoff_frontier: reason=pending_core_bodies' \
    "no-silent-C99 测试缺少 cmd/build self-build handoff frontier"
require_pattern "$NO_SILENT_TEST" 'entry_callee_coverage=partial_prefix' \
    "no-silent-C99 测试缺少 cmd/build run entry prefix 覆盖证据"
require_pattern "$NO_SILENT_TEST" 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' \
    "no-silent-C99 测试缺少 cmd/build self-build lowering frontier"
require_pattern "$NO_SILENT_TEST" '后端类型: C99' \
    "no-silent-C99 测试缺少 C99 fallback 反向检查"
if grep -q 'native_unsupported_call_expr: name=compile_files' "$NO_SILENT_TEST"; then
    echo "错误: no-silent-C99 测试不应再固定 pre-MIR compile_files one-off 缺口" >&2
    exit 1
fi
require_pattern "$NO_SILENT_TEST" 'self-build CoreIR/PortableMIR preflight 应为 verifier-clean' \
    "no-silent-C99 测试缺少 cmd/build self-build preflight failed 反向检查"
if grep -q -- '--native --nostdlib' "$NO_SILENT_TEST"; then
    echo "错误: no-silent-C99 测试不应再把 cmd/build self-build 退回 freestanding --nostdlib" >&2
    exit 1
fi
require_pattern "$LOWERED_BODY_CONTRACT_TEST" 'opcode 清单已变化' \
    "LoweredBodyOp transition 测试缺少 opcode 冻结门禁"
require_pattern "$LOWERED_BODY_CONTRACT_TEST" 'CoreBody/PortableMIR' \
    "LoweredBodyOp transition 测试缺少 CoreBody/PortableMIR 迁移要求"
require_pattern "$STAGE1_TEST" 'verify_native_cmd_build_regression_boundary\.sh' \
    "stage1 native cmd/build 验证未纳入回归边界合同"
require_pattern "$DRIVER_SRC" 'compile_files\(&input_file_indices\[0\], input_file_count, input_paths_override_ptr, input_paths_override_count, output_file_index, selected_backend, emit_line_directives, enable_safety_proof, opt_level, output_path_for_compile, is_nostdlib, stack_size, split_c_arg, async_frame_heap_fallback, stop_after_checker, &artifacts\)' \
    "compiler driver 缺少真实 compile_files 16 参数调用输入"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_portable_mir_preflight' \
    "build compiler driver 缺少 hosted native PortableMIR preflight"
require_pattern "$BUILD_DRIVER_SRC" 'lowered_program_verify_coreir_result' \
    "build compiler driver 缺少 hosted CoreIR verifier preflight"
require_pattern "$BUILD_DRIVER_SRC" 'lowered_program_append_function' \
    "build compiler driver 缺少 hosted CoreIR function inventory 记录"
require_pattern "$BUILD_DRIVER_SRC" 'lowered_program_append_core_body' \
    "build compiler driver 缺少 hosted safe CoreBody materialization"
require_pattern "$BUILD_DRIVER_SRC" 'CORE_EXPR_KIND_INT_LITERAL' \
    "build compiler driver 缺少 hosted integer literal CoreExpr materialization"
require_pattern "$BUILD_DRIVER_SRC" 'native_hosted_link_plan_add_extern_symbol' \
    "build compiler driver 缺少 extern symbol hosted link plan 记录"
require_pattern "$BUILD_DRIVER_SRC" 'portable_mir_append_function' \
    "build compiler driver 缺少 hosted extern function MIR 记录"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_hosted_mir_append_void_body_function' \
    "build compiler driver 缺少 hosted void CoreBody 到 PortableMIR 函数体 lower"
require_pattern "$BUILD_DRIVER_SRC" 'native_hosted_portable_mir_lowering_missing' \
    "build compiler driver 缺少 hosted native MIR lowering 缺口诊断"
require_pattern "$BUILD_DRIVER_SRC" 'native_hosted_portable_mir_preflight_failed' \
    "build compiler driver 缺少 hosted native self-build preflight 缺口诊断"
require_pattern "$BUILD_DRIVER_SRC" 'native_hosted_handoff_frontier' \
    "build compiler driver 缺少 hosted native self-build handoff frontier 诊断"
require_pattern "$BUILD_DRIVER_SRC" 'native_hosted_entry_frontier' \
    "build compiler driver 缺少 hosted native entry wrapper frontier 诊断"
require_pattern "$BUILD_DRIVER_SRC" 'native_hosted_link_plan_init' \
    "build compiler driver 缺少 NativeHostedLinkPlan 初始化"
require_pattern "$BUILD_DRIVER_SRC" 'is_nostdlib[[:space:]]*==[[:space:]]*0' \
    "build compiler driver 缺少 hosted native 与 freestanding native 分流"
require_pattern "$NATIVE_BUILD_SRC" 'intentionally smaller than codegen\.native\.\*' \
    "native build seed writer 缺少窄子集说明"
require_pattern "$NATIVE_BUILD_SRC" 'for a narrow' \
    "native build seed writer 缺少窄范围说明"
require_pattern "$NATIVE_BUILD_SRC" 'no-arg i32 function subset' \
    "native build seed writer 缺少窄函数子集说明"

echo "verify_native_cmd_build_regression_boundary: ok"
