#!/usr/bin/env bash
#
# Full-language scheduler/channel/IO/compute async MIR-C99 parity shard:
# channel, scheduler event-loop, fd/io, multi-fd, and async_compute paths.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing full-language async scheduler/compute evidence: $description" >&2
        exit 1
    fi
}

bash "$REPO_ROOT/tests/verify_mir_c99_async_channel_scheduler_parity.sh" >/dev/null
bash "$REPO_ROOT/tests/verify_mir_c99_async_fd_io_parity.sh" >/dev/null
bash "$REPO_ROOT/tests/verify_mir_c99_async_multi_fd_scheduler_parity.sh" >/dev/null
bash "$REPO_ROOT/tests/verify_mir_c99_async_compute_parity.sh" >/dev/null

require_pattern "$MATRIX_DOC" \
    '\| async runtime / Future / Waker \| partial \| partial \| .*scheduler/channel/IO/compute async full-language parity shard 覆盖 channel、scheduler event、fd/io、multi-fd 与 async_compute' \
    "async runtime full-language scheduler/compute coverage"
require_pattern "$MATRIX_DOC" \
    '\| async channel / scheduler / event loop / async_compute \| partial \| partial \| .*scheduler/channel/IO/compute async full-language parity shard 覆盖 channel、scheduler event、fd/io、multi-fd 与 async_compute' \
    "async channel/scheduler/event-loop/compute runtime coverage"
require_pattern "$MATRIX_DOC" \
    '\| file IO \| done \| partial \| .*scheduler/channel/IO/compute async full-language parity shard 覆盖 AsyncFd read/write/read_exact/write_all 与 multi-fd scheduler' \
    "async fd/io runtime coverage"
require_pattern "$TODO_FILE" \
    'scheduler/channel/IO/compute async full-language parity' \
    "todo tracks scheduler/channel/IO/compute async full-language shard"

echo "OK: MIR-C99 full-language async scheduler/channel/IO/compute parity matched C99 oracle"
