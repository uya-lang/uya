#!/usr/bin/env bash

# Phase 9A：验证 C99 第一阶段继续作为独立 oracle，
# 不被 PortableMIR 迁移提前绑死。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PORTABLE_MIR_DOC="$REPO_ROOT/docs/portable_mir_whitepaper.md"
COREIR_DOC="$REPO_ROOT/docs/coreir_lowered_program_whitepaper.md"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"
MIR_BACKEND_FILE="$REPO_ROOT/src/lower/mir_backend.uya"
C99_PLAN_FILE="$REPO_ROOT/src/codegen/c99/plan.uya"
COREIR_GATE="$REPO_ROOT/tests/verify_coreir_closure_contract.sh"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: C99 oracle boundary 缺少证据: $description" >&2
        echo "文件: $file" >&2
        exit 1
    fi
}

for file in "$PORTABLE_MIR_DOC" "$COREIR_DOC" "$ARCH_DOC" "$MIR_BACKEND_FILE" "$C99_PLAN_FILE" "$COREIR_GATE"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$PORTABLE_MIR_DOC" '^## 20\. C99 后端关系' "PortableMIR C99 关系章节"
require_pattern "$PORTABLE_MIR_DOC" 'C99 第一阶段继续作为独立 oracle' "PortableMIR 白皮书独立 oracle 规则"
require_pattern "$PORTABLE_MIR_DOC" '现有 C99 路径在第一阶段不要求导入 PortableMIR' "PortableMIR 白皮书未强制迁移规则"
require_pattern "$PORTABLE_MIR_DOC" 'hosted native parity 稳定后，可实验性新增 `PortableMIR -> C99Plan`' \
    "PortableMIR 白皮书实验性 MIR->C99Plan 规则"
require_pattern "$COREIR_DOC" '第一阶段 C99 可以继续直接消费 `LoweredProgram` 作为 oracle' \
    "CoreIR 白皮书 C99 可继续消费 LoweredProgram"
require_pattern "$COREIR_DOC" '在 parity 证明前不能删除现有 C99 oracle' \
    "CoreIR 白皮书禁止提前删除 C99 oracle"
require_pattern "$ARCH_DOC" 'C99 迁移到 MIR 是后续选项，不是第一阶段强制要求' \
    "架构文档未声明 C99 迁移不是第一阶段强制项"
require_pattern "$ARCH_DOC" '第一阶段 C99 oracle 不要求依赖 PortableMIR' \
    "架构文档未声明 C99 oracle 独立于 PortableMIR"
require_pattern "$MIR_BACKEND_FILE" 'MIR_TARGET_BACKEND_C99' "MIR backend 缺少 C99 backend kind"
require_pattern "$MIR_BACKEND_FILE" 'MIR_BACKEND_OUTPUT_C99_PLAN' "MIR backend 缺少 C99Plan 输出 kind"
require_pattern "$C99_PLAN_FILE" '^export[[:space:]]+struct[[:space:]]+C99Plan' "C99Plan 合同结构"
require_pattern "$COREIR_GATE" 'verify_coreir_c99_oracle_boundary\.sh' "CoreIR 聚合门禁未纳入 C99 oracle 边界"

if grep -R -E '(^use[[:space:]]+lower\.mir|PortableMir|MirTargetBackend|MIR_TARGET_BACKEND_|MIR_BACKEND_OUTPUT_)' \
    "$REPO_ROOT/src/codegen/c99" "$REPO_ROOT/src/codegen/c99_build" >/tmp/uya-c99-mir-deps.$$; then
    echo "错误: C99 第一阶段不应强制依赖 PortableMIR/MIR backend" >&2
    cat /tmp/uya-c99-mir-deps.$$ >&2
    rm -f /tmp/uya-c99-mir-deps.$$
    exit 1
fi
rm -f /tmp/uya-c99-mir-deps.$$

echo "verify_portable_mir_c99_oracle_boundary: ok"
