#!/usr/bin/env bash
# Release gate: backup flow must keep the existing C99 seed until MIR-C99
# self-build is actually stable; no MIR-C99 backup seed may enter the tracked
# backup flow yet.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MAKEFILE="$REPO_ROOT/Makefile"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"
ARCH_DOC="$REPO_ROOT/docs/compiler_1s_architecture_design.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing MIR-C99 backup release gate evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "error: forbidden MIR-C99 backup release gate evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$MAKEFILE" "$TODO_FILE" "$ARCH_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing MIR-C99 backup release gate input: $file" >&2
        exit 1
    fi
done

require_pattern "$MAKEFILE" '^backup-seed:' \
    'Makefile still defines the tracked C99 backup-seed target'
require_pattern "$MAKEFILE" '^backup-all:' \
    'Makefile still defines the tracked backup-all target'
reject_pattern "$MAKEFILE" 'backup/[^[:space:]]*mir[^[:space:]]*\.c|MIR_C99_BACKUP_SEED|mir_c99.*seed' \
    'tracked backup flow must not already introduce MIR-C99 seed artifacts or toggles'

require_pattern "$TODO_FILE" 'backup flow 保留现有 C99 seed，新增 MIR-C99 seed 只在自举稳定后进入。' \
    'todo leaf records the release gate requirement'
require_pattern "$ARCH_DOC" 'release gate：在 MIR-C99 backend 达到稳定 self-build 之前，backup flow 继续保留现有 C99/hosted seed；' \
    'architecture doc records the deferred MIR-C99 seed policy intro'
require_pattern "$ARCH_DOC" 'MIR-C99 seed 只有在 self-build 达到稳定自举后才允许进入 tracked backup 流程。' \
    'architecture doc records the deferred MIR-C99 seed policy body'

echo "OK: MIR-C99 backup release gate keeps current C99 seed flow until stable self-build"
