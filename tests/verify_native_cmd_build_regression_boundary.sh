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
CMD_BUILD_REGRESSION_TEST="$REPO_ROOT/tests/verify_native_cmd_build_compiler_regressions.sh"
CMD_BUILD_C99_PARITY_TEST="$REPO_ROOT/tests/verify_native_cmd_build_c99_output_parity.sh"
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
require_pattern "$SUBSET_DOC" 'native_hosted_emitter_handoff: status=rejected reason=pending_core_bodies request_verified=1 backend=machine link_plan=complete' \
    "cmd/build subset doc 缺少真实 emitter handoff 首个拒绝文案"
require_pattern "$SUBSET_DOC" '不能生成伪 native 输出，也不能静默回落 C99' \
    "cmd/build subset doc 缺少失败语义"
require_pattern "$SUBSET_DOC" '^## Hosted Native Handoff First Slice Contract' \
    "cmd/build subset doc 缺少 hosted native handoff 首切片合同"
require_pattern "$SUBSET_DOC" '首个真实 handoff 切片只接受 verifier-clean `CoreBody` / `PortableMIR` body' \
    "cmd/build subset doc 缺少首切片 verifier-clean 输入边界"
require_pattern "$SUBSET_DOC" '不得调用历史 `LoweredProgram -> MachineModule` build-seed helper' \
    "cmd/build subset doc 缺少首切片 pre-MIR helper 禁止规则"
require_pattern "$SUBSET_DOC" '未实现真实 emitter 前必须继续返回 `native_hosted_portable_mir_lowering_missing`' \
    "cmd/build subset doc 缺少首切片 explicit reject 语义"
require_pattern "$SUBSET_DOC" '`NativeHostedLinkPlan` / `MirTargetBackendRequest` handoff' \
    "cmd/build subset doc 缺少 hosted link plan handoff 边界"
require_pattern "$SUBSET_DOC" '^## `parse_build_args\(\.\.\.\)` PortableMIR Surface Audit' \
    "cmd/build subset doc 缺少 parse_build_args surface audit"
require_pattern "$SUBSET_DOC" '当前 reachable body frontier 是 `build_compiler_driver_run` 第 12 条语句调用到的' \
    "cmd/build subset doc 缺少 parse_build_args 当前 frontier"
require_pattern "$SUBSET_DOC" '入口 argv/argc 和 early return' \
    "cmd/build subset doc 缺少 parse_build_args argv/argc early return 审计"
require_pattern "$SUBSET_DOC" '默认 out-param 写入和全局状态初始化' \
    "cmd/build subset doc 缺少 parse_build_args out-param/global 审计"
require_pattern "$SUBSET_DOC" '`strcmp` 的 `--help` / `-h`' \
    "cmd/build subset doc 缺少 parse_build_args first-arg strcmp 审计"
require_pattern "$SUBSET_DOC" '主 option loop 骨架' \
    "cmd/build subset doc 缺少 parse_build_args option loop 审计"
require_pattern "$SUBSET_DOC" '`--project-root`' \
    "cmd/build subset doc 缺少 parse_build_args project-root 审计"
require_pattern "$SUBSET_DOC" 'build-seed 明确拒绝选项' \
    "cmd/build subset doc 缺少 parse_build_args build-seed reject 审计"
require_pattern "$SUBSET_DOC" '`--stack-size` 数字扫描' \
    "cmd/build subset doc 缺少 parse_build_args stack-size 审计"
require_pattern "$SUBSET_DOC" '`arg \+ 14` pointer arithmetic' \
    "cmd/build subset doc 缺少 parse_build_args pointer arithmetic 审计"
require_pattern "$SUBSET_DOC" '位置输入文件收集' \
    "cmd/build subset doc 缺少 parse_build_args input collection 审计"
require_pattern "$SUBSET_DOC" '收尾输出路径检查' \
    "cmd/build subset doc 缺少 parse_build_args output path 审计"
require_pattern "$SUBSET_DOC" 'no-output、no-silent-C99' \
    "cmd/build subset doc 缺少 parse_build_args no-silent-C99 迁移要求"
require_pattern "$SUBSET_DOC" '^## `parse_build_args\(\.\.\.\)` Scalar Option Frontier Contract' \
    "cmd/build subset doc 缺少 scalar option frontier 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_loop_body_frontier: function=parse_build_args parent_stmt=23' \
    "cmd/build subset doc 缺少 scalar option loop-body child frontier 诊断形状"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=2 covered_branch=-o next_branch=--c99 next_kind=AST_IF_STMT reason=partial_else_if_chain' \
    "cmd/build subset doc 缺少 -o branch frontier 诊断形状"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=3 covered_branch=backend next_branch=--no-line-directives next_kind=AST_IF_STMT reason=partial_else_if_chain' \
    "cmd/build subset doc 缺少 backend branch frontier 诊断形状"

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
require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_body_frontier: function=parse_build_args prefix_stmts=24 next_stmt=24 next_kind=AST_IF_STMT reason=partial_core_body' \
    "no-silent-C99 测试缺少 cmd/build reachable body frontier"
require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_loop_body_branch_frontier' \
    "no-silent-C99 测试缺少 scalar option loop-body branch frontier 合同锚点"
require_pattern "$NO_SILENT_TEST" 'native_hosted_reachable_loop_body_branch_frontier: function=parse_build_args parent_stmt=23 loop_stmt=3 covered_branch=backend next_branch=--no-line-directives next_kind=AST_IF_STMT reason=partial_else_if_chain' \
    "no-silent-C99 测试缺少 backend 后的 line-directives frontier"
require_pattern "$NO_SILENT_TEST" 'native_hosted_handoff_frontier: reason=pending_core_bodies' \
    "no-silent-C99 测试缺少 cmd/build self-build handoff frontier"
require_pattern "$NO_SILENT_TEST" 'entry_child_coverage=complete' \
    "no-silent-C99 测试缺少 cmd/build nested child complete handoff 证据"
require_pattern "$NO_SILENT_TEST" 'native_hosted_emitter_handoff: status=rejected reason=pending_core_bodies request_verified=1 backend=machine link_plan=complete' \
    "no-silent-C99 测试缺少 cmd/build 真实 emitter handoff 首个拒绝证据"
require_pattern "$NO_SILENT_TEST" 'native_hosted_emitter_import_preflight: status=ready imported_functions=' \
    "no-silent-C99 测试缺少 cmd/build NativeMirEmitter import preflight 证据"
require_pattern "$NO_SILENT_TEST" 'native_hosted_emitter_output_preflight: status=ready output_matches_request=1 output_kind=machine_module' \
    "no-silent-C99 测试缺少 cmd/build NativeMirEmitter output payload preflight 证据"
require_pattern "$NO_SILENT_TEST" 'entry_callee_coverage=complete' \
    "no-silent-C99 测试缺少 cmd/build run entry complete 覆盖证据"
require_pattern "$NO_SILENT_TEST" 'native_unsupported_hosted_path: reason=native_hosted_portable_mir_lowering_missing' \
    "no-silent-C99 测试缺少 cmd/build self-build lowering frontier"
require_pattern "$NO_SILENT_TEST" '后端类型: C99' \
    "no-silent-C99 测试缺少 C99 fallback 反向检查"
require_pattern "$CMD_BUILD_REGRESSION_TEST" 'bin/cmd/build' \
    "cmd/build compiler regression 测试没有使用 native cmd/build"
require_pattern "$CMD_BUILD_REGRESSION_TEST" 'generic_identity' \
    "cmd/build compiler regression 测试缺少 generic identity 形状"
require_pattern "$CMD_BUILD_REGRESSION_TEST" 'local_array_outparam' \
    "cmd/build compiler regression 测试缺少 local array out-param 形状"
require_pattern "$CMD_BUILD_REGRESSION_TEST" 'parse_like_outparam' \
    "cmd/build compiler regression 测试缺少 compiler-like parse out-param 形状"
require_pattern "$CMD_BUILD_REGRESSION_TEST" 'native_hosted_portable_mir_lowering_missing' \
    "cmd/build compiler regression 测试缺少 hosted reject 反向检查"
require_pattern "$CMD_BUILD_C99_PARITY_TEST" 'bin/cmd/build' \
    "cmd/build C99 output parity 测试没有使用 native cmd/build"
require_pattern "$CMD_BUILD_C99_PARITY_TEST" 'bin/uya' \
    "cmd/build C99 output parity 测试没有使用 C99-built compiler oracle"
require_pattern "$CMD_BUILD_C99_PARITY_TEST" 'cmp -s' \
    "cmd/build C99 output parity 测试缺少结构化 C99 输出比对"
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
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_scalar_options_contract\.sh' \
    "stage1 native cmd/build 验证未纳入 parse_build_args scalar option 合同"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_o_option_contract\.sh' \
    "stage1 native cmd/build 验证未纳入 parse_build_args -o 合同"
require_pattern "$STAGE1_TEST" 'verify_native_parse_build_args_backend_options_contract\.sh' \
    "stage1 native cmd/build 验证未纳入 parse_build_args backend options 合同"
require_pattern "$STAGE1_TEST" 'verify_native_cmd_build_compiler_regressions\.sh' \
    "stage1 native cmd/build 验证未纳入 compiler regression 组"
require_pattern "$STAGE1_TEST" 'verify_native_cmd_build_c99_output_parity\.sh' \
    "stage1 native cmd/build 验证未纳入 C99 output parity"
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
require_pattern "$BUILD_DRIVER_SRC" 'native_hosted_emitter_handoff' \
    "build compiler driver 缺少 hosted native emitter handoff frontier 诊断"
require_pattern "$BUILD_DRIVER_SRC" 'emitter_handoff_request_verified' \
    "build compiler driver 缺少 verified backend request handoff 状态"
require_pattern "$BUILD_DRIVER_SRC" 'use[[:space:]]+codegen\.native\.mir_emitter;' \
    "build compiler driver 缺少 NativeMirEmitter 主路径导入"
require_pattern "$BUILD_DRIVER_SRC" 'native_mir_emitter_read_portable_mir' \
    "build compiler driver 缺少 NativeMirEmitter import preflight 接线"
require_pattern "$BUILD_DRIVER_SRC" 'native_hosted_emitter_import_preflight' \
    "build compiler driver 缺少 NativeMirEmitter import preflight 诊断"
require_pattern "$BUILD_DRIVER_SRC" 'native_mir_emitter_finish_output' \
    "build compiler driver 缺少 NativeMirEmitter output payload preflight 接线"
require_pattern "$BUILD_DRIVER_SRC" 'native_hosted_emitter_output_preflight' \
    "build compiler driver 缺少 NativeMirEmitter output payload preflight 诊断"
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
