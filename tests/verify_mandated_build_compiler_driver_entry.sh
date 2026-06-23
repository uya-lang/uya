#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANDATED_COMPILER="$REPO_ROOT/../uya/bin/uya"
BOOTSTRAP_ENTRY="$REPO_ROOT/src/cmd/build_bootstrap/main.uya"
CMD_BUILD_ENTRY="$REPO_ROOT/src/cmd/build/main.uya"
TMP_DIR="$(mktemp -d /tmp/uya-mandated-build-entry.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

BOOTSTRAP_BIN="$TMP_DIR/build-bootstrap"
CMD_BUILD_BIN="$TMP_DIR/cmd-build"
BOOTSTRAP_STDOUT="$TMP_DIR/bootstrap.out"
BOOTSTRAP_STDERR="$TMP_DIR/bootstrap.err"
CMD_BUILD_STDOUT="$TMP_DIR/cmd-build.out"
CMD_BUILD_STDERR="$TMP_DIR/cmd-build.err"
HELP_STDOUT="$TMP_DIR/help.out"
HELP_STDERR="$TMP_DIR/help.err"

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "error: unexpected ${description}: $file" >&2
        cat "$file" >&2
        exit 1
    fi
}

if [[ ! -x "$MANDATED_COMPILER" ]]; then
    echo "error: missing mandated compiler: $MANDATED_COMPILER" >&2
    exit 1
fi

UYA_ROOT="$REPO_ROOT" "$MANDATED_COMPILER" build "$BOOTSTRAP_ENTRY" \
    -o "$BOOTSTRAP_BIN" --project-root "$REPO_ROOT/src/" --no-split-c \
    >"$BOOTSTRAP_STDOUT" 2>"$BOOTSTRAP_STDERR"
test -x "$BOOTSTRAP_BIN"
reject_pattern "$BOOTSTRAP_STDERR" "error:.*\\bO_RDONLY\\b" \
    "bootstrap host C compile still references bare O_RDONLY"
reject_pattern "$BOOTSTRAP_STDERR" "error:.*\\bSYS_[A-Za-z0-9_]+\\b" \
    "bootstrap host C compile still references bare SYS_* constants"
reject_pattern "$BOOTSTRAP_STDERR" "error:.*\\bEPOLL_[A-Za-z0-9_]+\\b" \
    "bootstrap host C compile still references bare EPOLL_* constants"

UYA_ROOT="$REPO_ROOT" "$BOOTSTRAP_BIN" build "$CMD_BUILD_ENTRY" \
    -o "$CMD_BUILD_BIN" --project-root "$REPO_ROOT/src/" --no-split-c \
    >"$CMD_BUILD_STDOUT" 2>"$CMD_BUILD_STDERR"
test -x "$CMD_BUILD_BIN"
reject_pattern "$CMD_BUILD_STDERR" "error:.*\\bO_RDONLY\\b" \
    "cmd/build host C compile still references bare O_RDONLY"
reject_pattern "$CMD_BUILD_STDERR" "error:.*\\bSYS_[A-Za-z0-9_]+\\b" \
    "cmd/build host C compile still references bare SYS_* constants"
reject_pattern "$CMD_BUILD_STDERR" "error:.*\\bEPOLL_[A-Za-z0-9_]+\\b" \
    "cmd/build host C compile still references bare EPOLL_* constants"
reject_pattern "$CMD_BUILD_STDERR" "error:.*\\bMIR_INST_OP_I32_EQ\\b" \
    "cmd/build host C compile still references missing MIR_INST_OP_I32_EQ contract"

set +e
UYA_ROOT="$REPO_ROOT" "$CMD_BUILD_BIN" --help >"$HELP_STDOUT" 2>"$HELP_STDERR"
help_status=$?
set -e
if [[ "$help_status" -ne 0 ]]; then
    echo "error: temporary cmd/build bootstrap binary should pass --help" >&2
    cat "$HELP_STDOUT" >&2
    cat "$HELP_STDERR" >&2
    exit 1
fi
if ! grep -Eq 'Uya build compiler|用法:' "$HELP_STDOUT" "$HELP_STDERR"; then
    echo "error: temporary cmd/build bootstrap binary did not print build help" >&2
    cat "$HELP_STDOUT" >&2
    cat "$HELP_STDERR" >&2
    exit 1
fi

echo "OK: mandated compiler can bootstrap a current-source build CLI entry and build cmd/build"
