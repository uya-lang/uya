#!/usr/bin/env bash
#
# MIR-C99 TODO evidence must not claim bare `./bin/uya test` runs as MIR-C99
# validation. That command still uses the legacy C99 backend by default.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

if [[ ! -f "$TODO_FILE" ]]; then
    echo "error: missing MIR-C99 TODO file" >&2
    exit 1
fi

if grep -nE '验证：.*`(\./)?bin/uya test' "$TODO_FILE" >&2; then
    echo "error: MIR-C99 TODO verification evidence contains bare bin/uya test" >&2
    echo "hint: use a verify_mir_c99_* parity gate or the oracle parity harness for MIR-C99 evidence" >&2
    exit 1
fi

if ! grep -q '`./bin/uya test` 默认仍走现有 AST/LoweredProgram C99 后端' "$TODO_FILE"; then
    echo "error: MIR-C99 TODO is missing the legacy-test evidence rule" >&2
    exit 1
fi

echo "OK: MIR-C99 TODO does not use legacy bin/uya test as MIR-C99 evidence"
