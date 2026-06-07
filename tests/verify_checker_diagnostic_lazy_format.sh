#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPILER="${UYA_COMPILER:-$ROOT/bin/uya}"
TMP="$(mktemp -d /tmp/uya-diag-lazy.XXXXXX)"
OK_LOG="$TMP/ok.log"
ERR_LOG="$TMP/error.log"

cleanup() {
    rm -rf "$TMP"
}
trap cleanup EXIT

fail() {
    echo "verify_checker_diagnostic_lazy_format: $*" >&2
    exit 1
}

extract_count() {
    local log="$1"
    sed -n 's/^diagnostic_format_count: \([0-9][0-9]*\)$/\1/p' "$log" | tail -n 1
}

if ! (cd "$ROOT" && UYA_PROFILE_DIAGNOSTICS=1 "$COMPILER" check examples/HelloWorld.uya >"$OK_LOG" 2>&1); then
    cat "$OK_LOG" >&2
    fail "successful checker run failed"
fi

ok_count="$(extract_count "$OK_LOG")"
if [[ -z "$ok_count" ]]; then
    cat "$OK_LOG" >&2
    fail "successful checker run did not print diagnostic_format_count"
fi
if [[ "$ok_count" != "0" ]]; then
    cat "$OK_LOG" >&2
    fail "successful checker run formatted diagnostics ($ok_count)"
fi

set +e
(cd "$ROOT" && UYA_PROFILE_DIAGNOSTICS=1 "$COMPILER" check tests/error_bounds_need_proof.uya >"$ERR_LOG" 2>&1)
status=$?
set -e
if [[ $status -eq 0 ]]; then
    cat "$ERR_LOG" >&2
    fail "error fixture unexpectedly passed"
fi

err_count="$(extract_count "$ERR_LOG")"
if [[ -z "$err_count" ]]; then
    cat "$ERR_LOG" >&2
    fail "error checker run did not print diagnostic_format_count"
fi
if [[ "$err_count" -le 0 ]]; then
    cat "$ERR_LOG" >&2
    fail "error checker run did not record formatted diagnostics"
fi

echo "verify_checker_diagnostic_lazy_format: ok"
