#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

COMPILER="${UYA_COMPILER:-$ROOT/bin/uya}"
export UYA_ROOT="${ROOT}/lib/"

assert_no_c_function_definition() {
    local file="$1"
    local symbol="$2"
    local label="$3"

    if grep -Eq "^[[:space:]]*(__attribute__\\(\\([^)]*\\)\\)[[:space:]]*)?[_A-Za-z][^;{}()]*[[:space:]*]${symbol}[[:space:]]*\\([^;{}]*\\)[[:space:]]*\\{" "$file"; then
        echo "error: hosted C unexpectedly emits system libc body for $label: $symbol" >&2
        grep -En "[[:space:]*]${symbol}[[:space:]]*\\(" "$file" >&2 || true
        exit 1
    fi
}

assert_c_function_definition() {
    local file="$1"
    local symbol="$2"
    local label="$3"

    if ! grep -Eq "^[[:space:]]*(__attribute__\\(\\([^)]*\\)\\)[[:space:]]*)?[_A-Za-z][^;{}()]*[[:space:]*]${symbol}[[:space:]]*\\([^;{}]*\\)[[:space:]]*\\{" "$file"; then
        echo "error: expected C body is missing for $label: $symbol" >&2
        exit 1
    fi
}

assert_no_raw_stream_definition() {
    local file="$1"
    local stream="$2"
    local label="$3"

    if grep -Eq "^[[:space:]]*(__attribute__\\(\\([^)]*\\)\\)[[:space:]]*)?struct FILE \\* ${stream}[[:space:]]*=" "$file"; then
        echo "error: hosted C unexpectedly emits raw system stdio stream for $label: $stream" >&2
        exit 1
    fi
}

# 符号级断言必须先 `cc -E` 预处理再匹配。
#
# 原因：生成的 C 里非宿主平台的实现是**关在条件块里**的（平台前导块与各函数体见
# src/codegen/c99/main.uya 的 `#if defined(_WIN32) || defined(UYA_TARGET_WINDOWS)` /
# `#if defined(__APPLE__)` 分支）。grep 逐行匹配、不认识预处理指令，直接扫全文会把
# 「当前宿主上根本不参与编译」的定义当成误报。预处理后只剩宿主真正编译的那一份，
# 断言才判别得了「hosted 到底有没有发射自己的实现体」。
preprocess_c() {
    local src="$1"
    local out="${src}.pp"
    cc -E -std=c99 "$src" -o "$out"
    printf '%s' "$out"
}

hosted_malloc="$TMP/hosted_malloc.c"
hosted_printf="$TMP/hosted_printf.c"
hosted_syscall="$TMP/hosted_syscall.c"
hosted_errno="$TMP/hosted_errno.c"
hosted_stdio_helpers="$TMP/hosted_stdio_helpers.c"
hosted_unistd="$TMP/hosted_unistd.c"
nostdlib_malloc="$TMP/nostdlib_malloc.c"
custom_callback="$TMP/custom_sdk_callback.uya"
custom_hosted="$TMP/custom_hosted_callback.c"
custom_nostdlib="$TMP/custom_nostdlib_callback.c"
custom_memset="$TMP/custom_memset_fixture.uya"
hosted_memset="$TMP/hosted_memset.c"
custom_strtod="$TMP/custom_strtod_fixture.uya"
hosted_strtod="$TMP/hosted_strtod.c"
custom_output_name="$TMP/custom_output_name_fixture.uya"
hosted_output_name_contains_uya="$TMP/http_bench_uya.c"
hosted_async_split_dir="$TMP/hosted_async_split"
hosted_async_split_out="$TMP/hosted_async_split.out"

cat >"$custom_callback" <<'UYA'
export extern "libc" fn hosted_custom_sdk_callback_marker(x: i32) i32 {
    // 夹具只验证符号发射；`x + 1` 在 --strict-overflow 默认开下无法证明无溢出，
    // 这里用饱和加法，语义无关。
    return x +| 1;
}

export fn main() i32 {
    return 0;
}
UYA

cat >"$custom_memset" <<'UYA'
use libc.malloc;
use libc.memset;

export fn main() i32 {
    const buf: &byte = malloc(16usize) as &byte;
    if buf == null {
        return 1;
    }
    _ = memset(buf, 0, 16usize);
    return 0;
}
UYA

cat >"$custom_strtod" <<'UYA'
use libc.strtod;
use libc.strtoll;

export fn main() i32 {
    const parsed_f64: f64 = strtod("12.5", null);
    const parsed_i64: i64 = strtoll("42", null, 10);
    if parsed_f64 > 0.0 && parsed_i64 > 0 {
        return 0;
    }
    return 1;
}
UYA

cat >"$custom_output_name" <<'UYA'
use libc.errno;
use libc.free;
use libc.malloc;
use libc.memset;

export fn main() i32 {
    const buf: &byte = malloc(8usize) as &byte;
    if buf == null {
        return errno;
    }
    _ = memset(buf, 0, 8usize);
    free(buf as &void);
    errno = 0;
    return 0;
}
UYA

"$COMPILER" build "$ROOT/tests/test_std_stdlib_malloc_only.uya" --c99 --no-split-c -o "$hosted_malloc" >/dev/null
"$COMPILER" build "$ROOT/tests/test_libc_printf_import.uya" --c99 --no-split-c -o "$hosted_printf" >/dev/null
"$COMPILER" build "$ROOT/tests/test_std_syscall.uya" --c99 --no-split-c -o "$hosted_syscall" >/dev/null
"$COMPILER" build "$ROOT/tests/test_errno.uya" --c99 --no-split-c -o "$hosted_errno" >/dev/null
"$COMPILER" build "$ROOT/tests/test_std_stdio.uya" --c99 --no-split-c -o "$hosted_stdio_helpers" >/dev/null
"$COMPILER" build "$ROOT/tests/test_unistd.uya" --c99 --no-split-c -o "$hosted_unistd" >/dev/null
"$COMPILER" build "$custom_memset" --c99 --no-split-c -o "$hosted_memset" >/dev/null
"$COMPILER" build "$custom_strtod" --c99 --no-split-c -o "$hosted_strtod" >/dev/null
"$COMPILER" build "$custom_output_name" --c99 --no-split-c -o "$hosted_output_name_contains_uya" >/dev/null
"$COMPILER" build --nostdlib "$ROOT/tests/test_std_stdlib_malloc_only.uya" --c99 --no-split-c -o "$nostdlib_malloc" >/dev/null
"$COMPILER" build "$custom_callback" --c99 --no-split-c -o "$custom_hosted" >/dev/null
"$COMPILER" build --nostdlib "$custom_callback" --c99 --no-split-c -o "$custom_nostdlib" >/dev/null
mkdir -p "$hosted_async_split_dir"
"$COMPILER" build "$ROOT/tests/test_async_nested_http1_await_codegen.uya" --split-c-dir "$hosted_async_split_dir" -o "$hosted_async_split_out" --c99 >/dev/null
grep -R -Fq "#include <string.h>" "$hosted_async_split_dir"

# 断言用的预处理版本（见 preprocess_c 的说明）。
hosted_malloc_pp="$(preprocess_c "$hosted_malloc")"
hosted_printf_pp="$(preprocess_c "$hosted_printf")"
hosted_syscall_pp="$(preprocess_c "$hosted_syscall")"
hosted_errno_pp="$(preprocess_c "$hosted_errno")"
hosted_stdio_helpers_pp="$(preprocess_c "$hosted_stdio_helpers")"
hosted_unistd_pp="$(preprocess_c "$hosted_unistd")"
nostdlib_malloc_pp="$(preprocess_c "$nostdlib_malloc")"
custom_hosted_pp="$(preprocess_c "$custom_hosted")"
custom_nostdlib_pp="$(preprocess_c "$custom_nostdlib")"
hosted_memset_pp="$(preprocess_c "$hosted_memset")"
hosted_strtod_pp="$(preprocess_c "$hosted_strtod")"
hosted_output_name_pp="$(preprocess_c "$hosted_output_name_contains_uya")"

# hosted 下 uya heap 是**唯一保留的 uya 分配器**（src/codegen/c99/function.uya 的
# EXPERIMENT-A 分支：hosted 线程堆靠 GS cache + spinlock，而且 calloc 必须与
# malloc/free 用同一套分配器，否则会出现「glibc 指针交给 uya free」的跨分配器错配）。
# 因此 malloc/free/calloc/realloc 在 hosted C 里**应当有函数体** —— 这里改成正向断言，
# 防止有人关掉 EXPERIMENT-A 时静默失配（断言方向在 2026-11-16 修正：原断言写于
# EXPERIMENT-A 之前，之后未同步）。
for symbol in malloc free calloc realloc; do
    assert_c_function_definition "$hosted_malloc" "$symbol" "uya heap kept in hosted"
done
# 环境变量仍然走宿主 libc：不得发射 uya 的 getenv 体。
assert_no_c_function_definition "$hosted_malloc_pp" getenv "malloc fixture"

for symbol in printf fprintf vprintf vfprintf sprintf snprintf vsprintf vsnprintf puts fputs fputc fflush fopen fclose fread fwrite fgetc fgets perror; do
    assert_no_c_function_definition "$hosted_printf_pp" "$symbol" "printf fixture"
done

for symbol in read write close lseek getpid getppid access getcwd; do
    assert_no_c_function_definition "$hosted_unistd_pp" "$symbol" "unistd fixture"
done

assert_no_c_function_definition "$hosted_memset_pp" memset "memset fixture"
grep -Fq "#include <string.h>" "$hosted_memset"
assert_no_c_function_definition "$hosted_strtod_pp" strtod "strtod fixture"
assert_no_c_function_definition "$hosted_strtod_pp" strtoll "strtod fixture"
grep -Fq "#include <stdlib.h>" "$hosted_strtod"
grep -Fq "#include <errno.h>" "$hosted_output_name_contains_uya"
grep -Fq "#include <string.h>" "$hosted_output_name_contains_uya"
grep -Fq "#include <stdlib.h>" "$hosted_output_name_contains_uya"

for stream in stdin stdout stderr; do
    assert_no_raw_stream_definition "$hosted_printf_pp" "$stream" "printf fixture"
    assert_no_raw_stream_definition "$hosted_unistd_pp" "$stream" "unistd fixture"
done

if grep -Eq "^[[:space:]]*(__attribute__\\(\\([^)]*\\)\\)[[:space:]]*)?int32_t[[:space:]]+libc_errno[[:space:]]*=" "$hosted_errno_pp"; then
    echo "error: hosted C unexpectedly emits Uya-owned libc_errno" >&2
    exit 1
fi
grep -Fq "#include <errno.h>" "$hosted_errno"
if grep -Rqw "libc_errno" "$hosted_async_split_dir"; then
    echo "error: hosted split-C output still references Uya-owned libc_errno" >&2
    grep -Rnw "libc_errno" "$hosted_async_split_dir" >&2 || true
    exit 1
fi

assert_c_function_definition "$hosted_syscall_pp" sys_write "syscall wrapper fixture"
assert_c_function_definition "$hosted_syscall_pp" sys_open "syscall wrapper fixture"
assert_c_function_definition "$hosted_syscall_pp" sys_close "syscall wrapper fixture"
assert_c_function_definition "$hosted_syscall_pp" sys_getpid "syscall wrapper fixture"
# hosted 下 stdio 整体保留 uya 实现，且发射名带 `libc_` 前缀（避免把 Uya 的
# struct FILE 当成 glibc FILE 传出去，见 c99_should_skip_hosted_libc_function_body
# 的 stdio.uya 分支）。所以这里断言的是实际发射名 libc_*，不是裸名。
assert_c_function_definition "$hosted_stdio_helpers_pp" libc_write_stdout_bytes "stdio helper fixture"
assert_c_function_definition "$hosted_stdio_helpers_pp" libc_i32_to_str "stdio helper fixture"
assert_c_function_definition "$hosted_stdio_helpers_pp" libc_put_char "stdio helper fixture"

assert_c_function_definition "$nostdlib_malloc_pp" malloc "nostdlib malloc fixture"
assert_c_function_definition "$nostdlib_malloc_pp" free "nostdlib malloc fixture"
assert_c_function_definition "$custom_hosted_pp" hosted_custom_sdk_callback_marker "custom callback fixture"
assert_c_function_definition "$custom_nostdlib_pp" hosted_custom_sdk_callback_marker "custom callback fixture"

cc -std=c99 -Werror "$hosted_malloc" -o "$TMP/hosted_malloc"
cc -std=c99 -Werror "$hosted_printf" -o "$TMP/hosted_printf"
cc -std=c99 -Werror "$hosted_syscall" -o "$TMP/hosted_syscall"
cc -std=c99 -Werror "$hosted_errno" -o "$TMP/hosted_errno"
cc -std=c99 -Werror "$hosted_stdio_helpers" -o "$TMP/hosted_stdio_helpers"
cc -std=c99 -Werror "$hosted_unistd" -o "$TMP/hosted_unistd"
cc -std=c99 -Werror "$hosted_memset" -o "$TMP/hosted_memset"
cc -std=c99 -Werror "$hosted_strtod" -o "$TMP/hosted_strtod"
cc -std=c99 -Werror "$hosted_output_name_contains_uya" -o "$TMP/hosted_output_name_contains_uya"
cc -std=c99 -Werror "$custom_hosted" -o "$TMP/custom_hosted"

"$TMP/hosted_malloc"
"$TMP/hosted_printf" >"$TMP/hosted_printf.out"
grep -Fxq "hello" "$TMP/hosted_printf.out"
"$TMP/hosted_syscall" >"$TMP/hosted_syscall.out"
"$TMP/hosted_errno" >"$TMP/hosted_errno.out"
"$TMP/hosted_stdio_helpers" >"$TMP/hosted_stdio_helpers.out"
"$TMP/hosted_unistd" >"$TMP/hosted_unistd.out"
"$TMP/hosted_memset" >/dev/null
"$TMP/hosted_strtod" >/dev/null
"$TMP/hosted_output_name_contains_uya" >/dev/null
"$hosted_async_split_out" >/dev/null

echo "verify_c99_hosted_libc_uses_system_symbols: ok"
