#!/usr/bin/env bash
#
# The broad cmd/build self-build failure must be reopened as an executable
# de-seeding leaf instead of being treated as completed by the transitional
# tracked cmd/build seed smoke.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"
FAILED_FILE="$REPO_ROOT/docs/todo_mir_c99_backend_failed.md"
GENERATOR="$REPO_ROOT/tests/mir_c99_generate.sh"
CMD_BUILD_SOURCE="$REPO_ROOT/src/cmd/build/main.uya"
TMP_DIR="$(mktemp -d /tmp/uya-mir-c99-true-candidate-reopen.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing MIR-C99 true candidate reopen evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -En "$pattern" "$file" >&2; then
        echo "error: MIR-C99 true candidate reopen found stale failed item: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$TODO_FILE" "$FAILED_FILE" "$GENERATOR" "$CMD_BUILD_SOURCE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing MIR-C99 true candidate reopen input: $file" >&2
        exit 1
    fi
done

require_pattern "$TODO_FILE" '去除 `tracked_cmd_build_seed` 过渡源' \
    "main TODO reopens the true candidate de-seeding leaf"
require_pattern "$TODO_FILE" 'source-to-PortableMIR \+ `mir_c99_driver_run` \+ `MirC99Emitter` 生成 candidate C' \
    "main TODO requires the independent MIR-C99 generation path"
require_pattern "$TODO_FILE" 'MIR_C99_COMPILER_SOURCE_BACKEND=tracked_cmd_build_seed` 只作为阻塞证据' \
    "main TODO keeps the tracked seed as blocker evidence only"
require_pattern "$TODO_FILE" 'seed smoke 不得作为本叶完成' \
    "main TODO forbids completing the leaf from the transitional seed smoke"

require_pattern "$FAILED_FILE" '已重开历史项：MIR-C99-built compiler 复跑 `cmd/build` self-build。' \
    "failed archive records the reopened historical failure"
require_pattern "$FAILED_FILE" '重开位置：`docs/todo_mir_c99_backend.md` 4.16 `去除 tracked_cmd_build_seed 过渡源`。' \
    "failed archive points to the reopened executable leaf"
reject_pattern "$FAILED_FILE" '^\s*[-*]\s*\[f\].*MIR-C99-built compiler 复跑 `cmd/build` self-build' \
    "failed archive must not retain the reopened self-build item as [f]"

output_c="$TMP_DIR/cmd-build-mir.c"
log_file="$TMP_DIR/cmd-build-mir.log"
summary_file="${output_c}.summary"
MIR_C99_SKIP_HANDOFF_VERIFY=1 "$GENERATOR" "$CMD_BUILD_SOURCE" "$output_c" "$log_file" >/dev/null

require_pattern "$log_file" '^compiler_source_backend=tracked_cmd_build_seed$' \
    "generator log still exposes the transitional tracked seed backend"
require_pattern "$summary_file" "^MIR_C99_COMPILER_SOURCE_BACKEND='tracked_cmd_build_seed'$" \
    "summary sidecar still exposes the transitional tracked seed backend"
require_pattern "$log_file" '^status=ok$' \
    "transitional candidate smoke remains available as blocker context"

echo "OK: MIR-C99 cmd/build self-build failure reopened as a true-candidate de-seeding leaf"
