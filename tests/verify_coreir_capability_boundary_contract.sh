#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COREIR_DOC="$REPO_ROOT/docs/coreir_lowered_program_whitepaper.md"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"
LOWER_CORE="$REPO_ROOT/src/lower/core.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: CoreIR capability boundary 缺少证据: $description" >&2
        exit 1
    fi
}

for file in "$COREIR_DOC" "$ARCH_DOC" "$LOWER_CORE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$COREIR_DOC" '## 20\. 语言语义和 Target Capability' "CoreIR capability 章节"
require_pattern "$COREIR_DOC" 'Capability 边界合同' "capability 边界合同小节"
require_pattern "$COREIR_DOC" 'diagnostic 至少携带 capability 名称、触发源构造和目标 profile' "diagnostic 必含信息"
require_pattern "$COREIR_DOC" '不能静默回落 C99' "禁止静默 C99 fallback"
require_pattern "$COREIR_DOC" '不能跳过 safety proof' "禁止跳过 proof"
require_pattern "$COREIR_DOC" '不能创建方言' "禁止 target 方言"
require_pattern "$COREIR_DOC" '`@c_import`.*顶层 build graph capability' "@c_import 能力边界"
require_pattern "$COREIR_DOC" 'filesystem.*文件系统访问' "filesystem 能力边界"
require_pattern "$COREIR_DOC" 'pthread / threading.*线程' "pthread/threading 能力边界"
require_pattern "$COREIR_DOC" 'syscall.*裸 syscall' "syscall 能力边界"
require_pattern "$COREIR_DOC" '`@asm`.*inline asm' "@asm 能力边界"
require_pattern "$COREIR_DOC" 'future PTX device subset.*device/kernel' "future PTX device subset 能力边界"
require_pattern "$COREIR_DOC" 'capability fact 只能描述能力需求和 source attachment' "capability metadata 只描述能力需求"
require_pattern "$COREIR_DOC" 'cleanup 等会改变语言语义的事实' "capability metadata 不携带语言语义事实"

require_pattern "$ARCH_DOC" '完整 Uya 语言语义只由 parser、checker、TypedProgram 和 CoreIR 定义' "架构语言语义归属"
require_pattern "$ARCH_DOC" '@c_import' "架构 @c_import 能力"
require_pattern "$ARCH_DOC" 'filesystem' "架构 filesystem 能力"
require_pattern "$ARCH_DOC" 'pthread' "架构 pthread 能力"
require_pattern "$ARCH_DOC" 'syscall' "架构 syscall 能力"
require_pattern "$ARCH_DOC" '`@asm`' "架构 @asm 能力"
require_pattern "$ARCH_DOC" 'future PTX device subset' "架构 future PTX device subset 能力"
require_pattern "$ARCH_DOC" 'target 可以拒绝能力，不能把拒绝实现成 Uya 方言' "架构禁止方言"
require_pattern "$ARCH_DOC" 'CoreIR capability metadata 只能描述能力需求和 source attachment' "架构 metadata 边界"
require_pattern "$ARCH_DOC" 'CoreIR verifier 先于 MIR lowering 检查' "verifier 检查时序"

require_pattern "$LOWER_CORE" 'COREIR_VERIFY_ERR_CAPABILITY_SEMANTICS' "CoreIR verifier capability 语义污染错误码"
require_pattern "$LOWER_CORE" 'lowered_program_coreir_capability_is_requirement_only' "CoreIR verifier capability-only 检查"
require_pattern "$LOWER_CORE" 'fact\.type_id != TYPED_PROGRAM_INVALID_ID' "capability fact 禁止携带 type 语义"
require_pattern "$LOWER_CORE" 'fact\.call_target_kind != TYPED_CALL_TARGET_UNKNOWN' "capability fact 禁止携带 call 语义"
require_pattern "$LOWER_CORE" 'fact\.drop_defer_plan_id != TYPED_PROGRAM_INVALID_ID' "capability fact 禁止携带 cleanup 语义"

echo "✓ CoreIR capability boundary contract verified"
