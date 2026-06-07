#!/usr/bin/env bash

# Phase 9A/10：固定 freestanding native cmd/build 只是 build-seed 回归边界，
# hosted native 完整语言 parity 不依赖该子集继续扩张。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"
NO_SILENT_TEST="$REPO_ROOT/tests/verify_native_cmd_build_no_silent_c99.sh"
STAGE1_TEST="$REPO_ROOT/tests/verify_native_cmd_build_stage1.sh"
NATIVE_BUILD_SRC="$REPO_ROOT/src/codegen/native_build/main.uya"

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
require_pattern "$SUBSET_DOC" 'tests/verify_native_cmd_build_no_silent_c99\.sh' \
    "cmd/build subset doc 缺少 no-silent-C99 门禁引用"
require_pattern "$SUBSET_DOC" '不能生成伪 native 输出，也不能静默回落 C99' \
    "cmd/build subset doc 缺少失败语义"

require_pattern "$ARCH_DOC" 'hosted native 完整语言 parity：第一阶段完整实现当前 Uya 语言，并以 C99 为 oracle' \
    "architecture doc 缺少 hosted native 完整语言范围"
require_pattern "$ARCH_DOC" 'freestanding native build-seed：保留 Phase 10 `cmd/build` 子集，后续从已通过 MIR 的能力逐步下沉' \
    "architecture doc 缺少 freestanding build-seed 下沉规则"
require_pattern "$ARCH_DOC" 'freestanding native build-seed 失败只能阻塞 build-seed 里程碑，不能阻塞 hosted native 完整语言 parity' \
    "architecture doc 缺少 freestanding 不阻塞 hosted parity 规则"
require_pattern "$ARCH_DOC" 'helper 只作为 Phase 10 freestanding 回归边界保留，不能作为 hosted native 完整语言主路径' \
    "architecture doc 缺少 LoweredProgram helper 边界"

require_pattern "$NO_SILENT_TEST" 'run_cmd_build_self_reject_check' \
    "no-silent-C99 测试缺少 cmd/build self reject"
require_pattern "$NO_SILENT_TEST" 'native_unsupported_call_expr: name=compile_files\.\*args=16' \
    "no-silent-C99 测试缺少 compile_files 16 参数缺口"
require_pattern "$NO_SILENT_TEST" '后端类型: C99' \
    "no-silent-C99 测试缺少 C99 fallback 反向检查"
require_pattern "$STAGE1_TEST" 'verify_native_cmd_build_regression_boundary\.sh' \
    "stage1 native cmd/build 验证未纳入回归边界合同"
require_pattern "$NATIVE_BUILD_SRC" 'intentionally smaller than codegen\.native\.\*' \
    "native build seed writer 缺少窄子集说明"
require_pattern "$NATIVE_BUILD_SRC" 'for a narrow' \
    "native build seed writer 缺少窄范围说明"
require_pattern "$NATIVE_BUILD_SRC" 'no-arg i32 function subset' \
    "native build seed writer 缺少窄函数子集说明"

echo "verify_native_cmd_build_regression_boundary: ok"
