#!/usr/bin/env bash
#
# Focused real-CLI gate for std.runtime.entry runtime-bridge convergence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXED_UYA="$REPO_ROOT/../uya/bin/uya"
TMP_DIR="$(mktemp -d /tmp/uya-mir-c99-entry-extern-body.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
    echo "error: $*" >&2
    exit 1
}

if [[ ! -x "$FIXED_UYA" ]]; then
    fail "missing fixed compiler path: $FIXED_UYA"
fi

build_case() {
    local case_file="$1"
    local expect_success="$2"
    local case_name
    case_name="$(basename "$case_file" .uya)"
    local case_log="$TMP_DIR/${case_name}.log"
    local case_out="$TMP_DIR/${case_name}.c"

    set +e
    (
        cd "$REPO_ROOT"
        UYA_ROOT="$REPO_ROOT/lib/" "$FIXED_UYA" build --mir-c99 "$case_file" -o "$case_out"
    ) >"$case_log" 2>&1
    local status=$?
    set -e

    grep -Fq '[MIR-C99]' "$case_log" || {
        cat "$case_log" >&2
        fail "$case_file log is missing [MIR-C99] routing evidence"
    }

    if grep -Fq 'entry_extern_main_requires_runtime_bridge' "$case_log"; then
        cat "$case_log" >&2
        fail "$case_file is still blocked by std.runtime.entry runtime bridge"
    fi

    if [[ "$expect_success" == "success" ]]; then
        if [[ "$status" -ne 0 ]]; then
            cat "$case_log" >&2
            fail "$case_file should now build successfully through real --mir-c99"
        fi
        if [[ ! -s "$case_out" ]]; then
            cat "$case_log" >&2
            fail "$case_file succeeded but did not emit a non-empty MIR-C99 output"
        fi
        return 0
    fi

    if [[ "$status" -eq 0 ]]; then
        if [[ ! -s "$case_out" ]]; then
            cat "$case_log" >&2
            fail "$case_file succeeded but did not emit a non-empty MIR-C99 output"
        fi
        return 0
    fi

    grep -Eq 'mir_c99_capability_diagnostic: kind=|错误: MIR-C99 ' "$case_log" || {
        cat "$case_log" >&2
        fail "$case_file moved past entry bridge but did not report a stable next frontier"
    }
}

build_case "tests/test_outlibc_basic.uya" success
build_case "tests/test_zero_deps.uya" frontier

echo "OK: MIR-C99 real CLI cases now move past the std.runtime.entry runtime-bridge boundary"
