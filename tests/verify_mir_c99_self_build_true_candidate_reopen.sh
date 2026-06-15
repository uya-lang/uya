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
COMPLETED_FILE="$REPO_ROOT/docs/todo_mir_c99_backend_completed.md"
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

for file in "$TODO_FILE" "$FAILED_FILE" "$COMPLETED_FILE" "$GENERATOR" "$CMD_BUILD_SOURCE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing MIR-C99 true candidate reopen input: $file" >&2
        exit 1
    fi
done

if ! grep -Eq '去除 `tracked_cmd_build_seed` 过渡源' "$TODO_FILE" "$COMPLETED_FILE"; then
    echo "error: missing MIR-C99 true candidate reopen evidence: de-seeding leaf is neither active nor completed" >&2
    exit 1
fi
if ! grep -Eq 'source-to-PortableMIR \+ `mir_c99_driver_run` \+ `MirC99Emitter` 生成 candidate C|mir_c99_unit_output' \
    "$TODO_FILE" "$COMPLETED_FILE"; then
    echo "error: missing MIR-C99 true candidate reopen evidence: independent MIR-C99 generation path" >&2
    exit 1
fi

require_pattern "$COMPLETED_FILE" '将已修复的 `MIR-C99-built compiler 复跑 compiler regression、C99 output parity 和 full-language backend parity` 历史失败块从失败归档移入完成归档' \
    "completed archive records the repaired historical failure migration"
require_pattern "$COMPLETED_FILE" '重开位置：`docs/todo_mir_c99_backend.md` 4\.16 `去除 tracked_cmd_build_seed 过渡源`。' \
    "completed archive points to the reopened executable leaf"
reject_pattern "$FAILED_FILE" '^\s*[-*]\s*\[f\].*MIR-C99-built compiler 复跑 `cmd/build` self-build' \
    "failed archive must not retain the reopened self-build item as [f]"

output_c="$TMP_DIR/cmd-build-mir.c"
log_file="$TMP_DIR/cmd-build-mir.log"
summary_file="${output_c}.summary"
MIR_C99_SKIP_HANDOFF_VERIFY=1 "$GENERATOR" "$CMD_BUILD_SOURCE" "$output_c" "$log_file" >/dev/null

require_pattern "$log_file" '^compiler_source_backend=mir_c99_unit_output$' \
    "generator log records the de-seeded MIR-C99 unit output backend"
require_pattern "$summary_file" "^MIR_C99_COMPILER_SOURCE_BACKEND='mir_c99_unit_output'$" \
    "summary sidecar records the de-seeded MIR-C99 unit output backend"
require_pattern "$log_file" '^status=ok$' \
    "de-seeded candidate smoke remains available as blocker context"

echo "OK: MIR-C99 cmd/build self-build failure reopened as a true-candidate de-seeding leaf"
