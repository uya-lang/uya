#!/usr/bin/env bash

# Phase 9B: verify the hosted print helper runtime object that native
# link planning pulls in for print/println helper calls.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_SRC="$REPO_ROOT/lib/std/runtime/hosted_print_helpers.c"
HOSTED_LINK_FILE="$REPO_ROOT/src/codegen/native/hosted_link.uya"
TMP_DIR="$(mktemp -d /tmp/uya-hosted-runtime-print.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: missing hosted runtime print helper evidence: $description" >&2
        exit 1
    fi
}

if [[ ! -f "$HELPER_SRC" ]]; then
    echo "error: missing hosted runtime print helper source: $HELPER_SRC" >&2
    exit 1
fi

require_pattern "$HELPER_SRC" 'int[[:space:]]+__uya_print_i32' "__uya_print_i32"
require_pattern "$HELPER_SRC" 'int[[:space:]]+__uya_print_str' "__uya_print_str"
require_pattern "$HELPER_SRC" 'int[[:space:]]+__uya_write_newline' "__uya_write_newline"
require_pattern "$HELPER_SRC" 'int[[:space:]]+uya_write_str' "uya_write_str bridge"
require_pattern "$HELPER_SRC" 'int[[:space:]]+uya_write_newline' "uya_write_newline bridge"
require_pattern "$HOSTED_LINK_FILE" 'std/runtime/hosted_print_helpers\.c' "hosted link runtime helper source path"

cat >"$TMP_DIR/main.c" <<'EOF'
#include <stddef.h>

int __uya_print_i32(int fd, int value);
int __uya_print_str(int fd, const char *ptr, int len);
int __uya_write_newline(int fd);
int uya_write_str(int fd, const char *ptr, int len);
int uya_write_newline(int fd);

int main(void) {
    int total = 0;
    total += __uya_print_str(1, "A", 1);
    total += __uya_write_newline(1);
    total += __uya_print_i32(1, -42);
    total += __uya_write_newline(1);
    total += uya_write_str(1, "B", 1);
    total += uya_write_newline(1);
    return total == 8 ? 0 : 1;
}
EOF

cc -std=c99 -O0 -g -fno-builtin -c "$HELPER_SRC" -o "$TMP_DIR/hosted_print_helpers.o"
cc -std=c99 -O0 -g -fno-builtin "$TMP_DIR/main.c" \
    "$TMP_DIR/hosted_print_helpers.o" -o "$TMP_DIR/check_helpers"
"$TMP_DIR/check_helpers" >"$TMP_DIR/stdout.txt" 2>"$TMP_DIR/stderr.txt"

if ! cmp -s "$TMP_DIR/stdout.txt" <(printf 'A\n-42\nB\n'); then
    echo "error: hosted runtime print helper output mismatch" >&2
    cat "$TMP_DIR/stdout.txt" >&2
    cat "$TMP_DIR/stderr.txt" >&2
    exit 1
fi

echo "OK: hosted native runtime print helper object compiles links and prints"
