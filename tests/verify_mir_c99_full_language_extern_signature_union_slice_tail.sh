#!/usr/bin/env bash
#
# Focused real-CLI gate for the last extern-signature tail cases: extern union
# and extern slice parameters.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPILER="$REPO_ROOT/../uya/bin/uya"

if [[ ! -x "$COMPILER" ]]; then
    echo "error: fixed MIR-C99 compiler is missing or not executable: $COMPILER" >&2
    exit 69
fi

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-extern-union-slice-tail.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

run_case() {
    local rel="$1"
    local basename
    basename="$(basename "$rel" .uya)"
    local log_file="$tmp_dir/$basename.log"
    local output_file="$tmp_dir/$basename.c"
    local status=0

    set +e
    (
        cd "$REPO_ROOT"
        UYA_ROOT="$REPO_ROOT/lib/" "$COMPILER" build --mir-c99 \
            "$rel" -o "$output_file"
    ) >"$log_file" 2>&1
    status=$?
    set -e

    grep -q '\[MIR-C99\]' "$log_file" || {
        cat "$log_file" >&2
        echo "error: missing [MIR-C99] routing evidence for $rel" >&2
        exit 1
    }

    if grep -Fq 'extern_signature_requires_i32_scalars' "$log_file"; then
        cat "$log_file" >&2
        echo "error: $rel still stops at extern_signature_requires_i32_scalars" >&2
        exit 1
    fi

    if grep -Fq '错误: MIR-C99 extern lowering 失败' "$log_file"; then
        cat "$log_file" >&2
        echo "error: $rel regressed to generic extern lowering failure" >&2
        exit 1
    fi

    if [[ "$status" -eq 0 ]]; then
        if [[ ! -s "$output_file" ]]; then
            cat "$log_file" >&2
            echo "error: $rel succeeded but did not produce MIR-C99 output" >&2
            exit 1
        fi
        return 0
    fi

    if ! grep -Eq 'mir_c99_capability_diagnostic:|错误: MIR-C99 |PortableMIR verifier 失败' "$log_file"; then
        cat "$log_file" >&2
        echo "error: $rel failed without a useful MIR-C99 diagnostic" >&2
        exit 1
    fi
}

run_case tests/test_extern_union.uya
run_case tests/test_slice_param_c99_emit.uya

echo "OK: MIR-C99 extern union and slice signature tail no longer stop at extern_signature_requires_i32_scalars"
