#!/usr/bin/env bash
#
# MIR-C99 split-C build shard must cover multi-file parity and build manifest
# scheduling policy without falling back to the legacy C99 split writer.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST_FILE="$REPO_ROOT/src/codegen/mir_c99/build_manifest.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing MIR-C99 split build evidence: $description" >&2
        exit 1
    fi
}

run_case() {
    local case_file="$1"
    MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
    C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
    bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null
}

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-split-build.XXXXXX)"
tmp_check=""
trap 'rm -rf "$tmp_dir" "$tmp_check"' EXIT

mkdir -p "$tmp_dir/c_import"
cat >"$tmp_dir/c_import/split_helper.c" <<'C_EOF'
int split_helper_bias(void) {
    return 21;
}
C_EOF

multi_file_case="$tmp_dir/multi_file_split_build.uya"
cat >"$multi_file_case" <<'UYA'
@c_import("c_import/split_helper.c");

extern fn split_helper_bias() i32;

export fn main() i32 {
    return split_helper_bias();
}
UYA

run_case "$multi_file_case"

require_pattern "$MANIFEST_FILE" 'MIR_C99_BUILD_MANIFEST_ENTRY_PARALLEL_GROUP' \
    "parallel build group manifest entry"
require_pattern "$MANIFEST_FILE" 'MIR_C99_BUILD_MANIFEST_ENTRY_CACHE_LOCK' \
    "cache lock manifest entry"
require_pattern "$MANIFEST_FILE" 'MIR_C99_BUILD_MANIFEST_ENTRY_STALE_LOCK_CHECK' \
    "stale lock check manifest entry"
require_pattern "$MANIFEST_FILE" 'parallel_job_count' \
    "parallel job count summary"
require_pattern "$MANIFEST_FILE" 'cache_lock_count' \
    "cache lock count summary"
require_pattern "$MANIFEST_FILE" 'stale_lock_check_count' \
    "stale lock check count summary"
require_pattern "$MANIFEST_FILE" 'mir_c99_build_manifest_append_build_policy' \
    "build policy append API"
require_pattern "$DRIVER_FILE" 'build_manifest_parallel_job_count' \
    "driver exposes parallel job count"
require_pattern "$DRIVER_FILE" 'build_manifest_cache_lock_count' \
    "driver exposes cache lock count"
require_pattern "$DRIVER_FILE" 'build_manifest_stale_lock_check_count' \
    "driver exposes stale lock check count"

if grep -Eq 'c99_write_split_makefile|split_makefile|codegen\.c99|C99CodeGenerator' "$MANIFEST_FILE"; then
    echo "error: MIR-C99 split build policy must not call legacy C99 split writer" >&2
    exit 1
fi

tmp_check="$(mktemp /tmp/mir_c99_split_build_manifest.XXXXXX.uya)"
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$MANIFEST_FILE" >"$tmp_check"
"$REPO_ROOT/bin/uya" check "$tmp_check" >/dev/null

bash "$REPO_ROOT/tests/verify_mir_c99_todo_no_legacy_test_evidence.sh"
python3 "$REPO_ROOT/.agents/skills/goal-task-runner/scripts/check_todo.py" "$TODO_FILE" >/dev/null

echo "OK: MIR-C99 split-C build parity and manifest policy verified"
