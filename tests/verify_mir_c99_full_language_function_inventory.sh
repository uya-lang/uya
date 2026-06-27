#!/usr/bin/env bash
#
# Full-language MIR-C99 CoreBody/function inventory must be grounded in the
# fixed real CLI baseline and the self-build convergence audit, not in legacy
# C99 success evidence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COVERAGE_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing MIR-C99 function inventory evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "error: forbidden MIR-C99 function inventory evidence: $description" >&2
        echo "file: $file" >&2
        grep -En "$pattern" "$file" >&2 || true
        exit 1
    fi
}

bash "$REPO_ROOT/tests/verify_mir_c99_full_language_baseline_truth.sh" >/dev/null
bash "$REPO_ROOT/tests/verify_mir_c99_self_build_convergence_audit.sh" >/dev/null

require_pattern "$COVERAGE_DOC" '^### 2\.2 MIR-C99 full-language CoreBody/function 缺口清单$' \
    "coverage doc has the full-language CoreBody/function inventory section"
require_pattern "$COVERAGE_DOC" '真实 `src/main\.uya --mir-c99` 基线：`usize_from_ptr_requires_target_capability`' \
    "inventory records the current src/main.uya real CLI capability frontier"
require_pattern "$COVERAGE_DOC" 'baseline gate：`bash tests/verify_mir_c99_full_language_baseline_truth\.sh`' \
    "inventory points at the baseline truth gate"
require_pattern "$COVERAGE_DOC" 'audit gate：`bash tests/verify_mir_c99_self_build_convergence_audit\.sh`' \
    "inventory points at the self-build convergence audit gate"
require_pattern "$COVERAGE_DOC" 'CFG：`bash tests/verify_mir_c99_cfg_parity\.sh`' \
    "inventory records the CFG gate"
require_pattern "$COVERAGE_DOC" 'place/memory：`bash tests/verify_mir_c99_place_memory_parity\.sh`' \
    "inventory records the place/memory gate"
require_pattern "$COVERAGE_DOC" 'call ABI：`bash tests/verify_mir_c99_call_parity\.sh`' \
    "inventory records the call ABI gate"
require_pattern "$COVERAGE_DOC" 'runtime helper：`bash tests/verify_mir_c99_memory_string_runtime_parity\.sh`' \
    "inventory records the runtime helper gate"
require_pattern "$COVERAGE_DOC" 'emitter/output：`bash tests/verify_mir_c99_emitter_unit_output\.sh`' \
    "inventory records the emitter/output gate"
require_pattern "$COVERAGE_DOC" 'link/absence：`bash tests/verify_mir_c99_global_import_parity\.sh`' \
    "inventory records the link/absence gate"
require_pattern "$COVERAGE_DOC" 'blocked_category_summary=call_abi=1,runtime_helper=1,emitter_output=1,link_absence=1' \
    "inventory records the current grouped blocker summary"
reject_pattern "$COVERAGE_DOC" 'legacy C99 成功作为 MIR-C99 完成证据|C99 代码由 Uya Mini 编译器生成' \
    "inventory must not cite legacy C99 success as MIR-C99 evidence"

echo "OK: MIR-C99 full-language function inventory is grounded in real CLI and audit gates"
