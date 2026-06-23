#!/usr/bin/env bash
#
# Guard the generic CoreBody lowering migration against new fixed-shape
# materializers. Existing helpers may be deleted as they move to generic
# lowering, but new helper names are not accepted as progress.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DRIVER="$REPO_ROOT/src/build_compiler_driver.uya"
BASELINE="$REPO_ROOT/tests/fixtures/mir_c99_known_one_off_materializers.txt"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

fail() {
    echo "error: $*" >&2
    exit 1
}

if [[ ! -f "$BUILD_DRIVER" ]]; then
    fail "missing build compiler driver: $BUILD_DRIVER"
fi

if [[ ! -f "$BASELINE" ]]; then
    fail "missing MIR-C99 one-off materializer baseline: $BASELINE"
fi

if [[ ! -f "$TODO_FILE" ]]; then
    fail "missing MIR-C99 TODO file: $TODO_FILE"
fi

current="$(mktemp /tmp/uya-mir-c99-materializers-current.XXXXXX)"
extra="$(mktemp /tmp/uya-mir-c99-materializers-extra.XXXXXX)"
trap 'rm -f "$current" "$extra"' EXIT

grep -Eo 'fn native_build_hosted_decl_can_materialize_[A-Za-z0-9_]+_body' "$BUILD_DRIVER" \
    | sed 's/^fn //' \
    | sort -u >"$current"

comm -13 "$BASELINE" "$current" >"$extra"
if [[ -s "$extra" ]]; then
    echo "error: new fixed-shape MIR-C99 materializer helpers are forbidden" >&2
    echo "These must be modeled as generic CoreBody/PortableMIR lowering instead:" >&2
    sed -n '1,80p' "$extra" >&2
    exit 1
fi

if ! grep -q 'one-off materializer' "$TODO_FILE"; then
    fail "todo is missing the generic CoreBody no-new-one-off parent rule"
fi

if ! grep -q '禁止：为了让单个 case 变绿继续新增 helper 名' "$TODO_FILE"; then
    fail "todo does not state that new helper names are forbidden"
fi

echo "OK: MIR-C99 generic CoreBody migration has no new one-off materializer helpers"
