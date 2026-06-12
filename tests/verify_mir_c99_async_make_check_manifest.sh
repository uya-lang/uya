#!/usr/bin/env bash
#
# Guard the MIR-C99 async parity shard inventory against silently missing
# tests/test_async_*.uya files covered by the Linux make check program matrix.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$REPO_ROOT/tests/mir_c99_async_make_check_manifest.txt"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"
RUNNER_FILE="$REPO_ROOT/tests/run_programs_parallel.sh"

if [[ ! -f "$MANIFEST" || ! -f "$TODO_FILE" || ! -f "$RUNNER_FILE" ]]; then
    echo "error: missing MIR-C99 async manifest inputs" >&2
    exit 1
fi

tmp_actual="$(mktemp /tmp/uya-mir-c99-async-actual.XXXXXX)"
tmp_expected="$(mktemp /tmp/uya-mir-c99-async-expected.XXXXXX)"
trap 'rm -f "$tmp_actual" "$tmp_expected"' EXIT

(
    cd "$REPO_ROOT"
    find tests -maxdepth 1 -type f -name 'test_async_*.uya' | sort
) >"$tmp_actual"

grep -Ev '^[[:space:]]*(#|$)' "$MANIFEST" | sort >"$tmp_expected"

if ! diff -u "$tmp_expected" "$tmp_actual"; then
    echo "error: MIR-C99 async make-check manifest is out of date" >&2
    exit 1
fi

count="$(wc -l <"$tmp_expected" | tr -d '[:space:]')"
if [[ "$count" -lt 1 ]]; then
    echo "error: MIR-C99 async manifest is empty" >&2
    exit 1
fi

if ! grep -q 'tests/test_async_\*.uya' "$TODO_FILE"; then
    echo "error: TODO no longer tracks tests/test_async_*.uya parity shard" >&2
    exit 1
fi

if ! grep -q 'test_async_\*' "$RUNNER_FILE"; then
    echo "error: run_programs_parallel skip policy no longer mentions test_async_*" >&2
    exit 1
fi

echo "OK: MIR-C99 async make-check manifest covers $count test_async_*.uya files"
