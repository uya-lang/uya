#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FMT_BIN="${UYA_FMT_BIN:-$REPO_ROOT/bin/uyafmt}"
TMP_DIR="$REPO_ROOT/tests/build/fmt_cli"
mkdir -p "$TMP_DIR"

build_fmt() {
    mkdir -p "$REPO_ROOT/bin"
    "$REPO_ROOT/bin/uya" build --c99 "$REPO_ROOT/tools/fmt.uya" -o "$TMP_DIR/uyafmt.c" >/tmp/verify_fmt_build.out 2>/tmp/verify_fmt_build.err
    cc -O0 -g "$TMP_DIR/uyafmt.c" -o "$FMT_BIN"
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    if ! printf '%s' "$haystack" | grep -Fq -- "$needle"; then
        echo "expected output to contain: $needle"
        echo "actual output:"
        printf '%s\n' "$haystack"
        exit 1
    fi
}

assert_equals() {
    local actual="$1"
    local expected="$2"
    if [ "$actual" != "$expected" ]; then
        echo "expected: $expected"
        echo "actual:   $actual"
        exit 1
    fi
}

build_fmt

INPUT1="$TMP_DIR/input_stdout.uya"
printf 'fn main(){return 0;}' > "$INPUT1"
OUT1="$($FMT_BIN "$INPUT1")"
assert_contains "$OUT1" 'fn main() {'
assert_contains "$OUT1" $'\treturn 0;'
assert_contains "$OUT1" '}'

INPUT2="$TMP_DIR/input_write.uya"
printf 'fn add(a,b){return a+b;}' > "$INPUT2"
"$FMT_BIN" -w "$INPUT2"
OUT2="$(cat "$INPUT2")"
assert_contains "$OUT2" 'fn add(a, b) {'
assert_contains "$OUT2" $'\treturn a + b;'

INPUT3="$TMP_DIR/input_diff.uya"
printf 'fn diff(a,b){return a+b;}' > "$INPUT3"
DIFF_OUT="$($FMT_BIN -d "$INPUT3")"
assert_contains "$DIFF_OUT" '--- '
assert_contains "$DIFF_OUT" '+++ '
assert_contains "$DIFF_OUT" 'fn diff(a, b) {'
assert_contains "$DIFF_OUT" "$INPUT3"

INPUT4="$TMP_DIR/input_simplify.uya"
printf 'fn sum(){return (1);}' > "$INPUT4"
SIMPLIFY_OUT="$($FMT_BIN -s "$INPUT4")"
assert_contains "$SIMPLIFY_OUT" $'\treturn 1;'

INPUT5="$TMP_DIR/input_rewrite.uya"
printf 'fn sample(){foo();foobar();}' > "$INPUT5"
REWRITE_OUT="$($FMT_BIN -r 'foo -> bar' "$INPUT5")"
assert_contains "$REWRITE_OUT" 'bar();'
assert_contains "$REWRITE_OUT" 'foobar();'

DIR1="$TMP_DIR/dir_case"
rm -rf "$DIR1"
mkdir -p "$DIR1/sub"
printf 'fn one(){return 1;}' > "$DIR1/a.uya"
printf 'fn two(){return 2;}' > "$DIR1/sub/b.uya"
printf 'not uya' > "$DIR1/ignore.txt"
LIST_OUT="$($FMT_BIN -l "$DIR1")"
assert_contains "$LIST_OUT" "$DIR1/a.uya"
assert_contains "$LIST_OUT" "$DIR1/sub/b.uya"
"$FMT_BIN" -w "$DIR1"
OUT3="$(cat "$DIR1/a.uya")"
OUT4="$(cat "$DIR1/sub/b.uya")"
assert_contains "$OUT3" 'fn one() {'
assert_contains "$OUT4" 'fn two() {'

LIST_AFTER="$($FMT_BIN -l "$DIR1")"
assert_equals "$LIST_AFTER" ''

MULTI1="$TMP_DIR/multi1.uya"
MULTI2="$TMP_DIR/multi2.uya"
printf 'fn multi1(){return 1;}' > "$MULTI1"
printf 'fn multi2(){return 2;}' > "$MULTI2"
MULTI_OUT="$($FMT_BIN -l "$MULTI1" "$MULTI2")"
assert_contains "$MULTI_OUT" "$MULTI1"
assert_contains "$MULTI_OUT" "$MULTI2"

STDIN_OUT="$(printf 'fn stdin_case(){return 3;}' | $FMT_BIN)"
assert_contains "$STDIN_OUT" 'fn stdin_case() {'
assert_contains "$STDIN_OUT" $'\treturn 3;'

printf 'verify_fmt_cli: ok\n'
