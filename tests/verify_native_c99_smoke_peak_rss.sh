#!/usr/bin/env bash

# Phase 9 KPI：native executable smoke 的 peak RSS 不高于 C99 smoke。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NATIVE_DIR="$REPO_ROOT/src/codegen/native"

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "错误: native peak RSS smoke 当前只支持 x86_64 host" >&2
    exit 1
fi
if ! command -v cc >/dev/null 2>&1; then
    echo "错误: 缺少 cc，无法构建 RSS 测量器" >&2
    exit 1
fi

tmp_dir="$(mktemp -d /tmp/uya-native-c99-rss.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/codegen/native"
cp "$NATIVE_DIR/elf64.uya" "$tmp_dir/codegen/native/elf64.uya"
cp "$NATIVE_DIR/x86_64.uya" "$tmp_dir/codegen/native/x86_64.uya"
cp "$NATIVE_DIR/main.uya" "$tmp_dir/codegen/native/main.uya"

c99_src="$tmp_dir/c99_smoke.uya"
c99_bin="$tmp_dir/c99-smoke"
native_src="$tmp_dir/native_generate.uya"
native_bin="$tmp_dir/native-smoke"
rss_tool="$tmp_dir/rss_measure"

cat >"$c99_src" <<'EOF'
export fn main() i32 {
    return 0;
}
EOF

cat >"$native_src" <<EOF
use std.testing.assert_eq_i32;
use std.testing.expect;
use libc.FILE;
use libc.fopen;
use libc.fclose;
use codegen.native;

test "generate native exit0 smoke executable for rss" {
    const fp: &FILE = fopen("$native_bin" as &const byte, "wb" as &const byte);
    try expect(fp != null);
    const result: NativeEmitResult = native_emit_linux_x86_64_exit0_stream(fp);
    _ = fclose(fp);
    try assert_eq_i32(result.status, NATIVE_EMIT_STATUS_OK);
    try assert_eq_i32(result.target, NATIVE_TARGET_LINUX_X86_64);
    try expect(result.code_bytes == X86_64_LINUX_EXIT0_SIZE as usize);
    try expect(result.output_bytes == (ELF64_MIN_EXEC_HEADERS + X86_64_LINUX_EXIT0_SIZE) as usize);
}
EOF

(cd "$REPO_ROOT" && ./bin/uya build "$c99_src" -o "$c99_bin" --no-split-c --project-root "$tmp_dir/") >"$tmp_dir/c99_build.log" 2>&1
(cd "$REPO_ROOT" && ./bin/uya test "$native_src" --no-split-c --project-root "$tmp_dir/") >"$tmp_dir/native_generate.log" 2>&1

if [[ ! -x "$c99_bin" ]]; then
    echo "错误: C99 smoke executable 未生成: $c99_bin" >&2
    cat "$tmp_dir/c99_build.log" >&2
    exit 1
fi
if [[ ! -s "$native_bin" ]]; then
    echo "错误: native smoke executable 未生成: $native_bin" >&2
    cat "$tmp_dir/native_generate.log" >&2
    exit 1
fi
chmod +x "$native_bin"

cat >"$tmp_dir/rss_measure.c" <<'EOF'
#include <sys/resource.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: rss_measure <executable>\n");
        return 2;
    }
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        return 3;
    }
    if (pid == 0) {
        execl(argv[1], argv[1], (char *)0);
        _exit(127);
    }

    int status = 0;
    struct rusage usage;
    if (wait4(pid, &status, 0, &usage) < 0) {
        perror("wait4");
        return 4;
    }

    int code = 0;
    if (WIFEXITED(status)) {
        code = WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        code = 128 + WTERMSIG(status);
    } else {
        code = 255;
    }
    printf("%d %ld\n", code, usage.ru_maxrss);
    return 0;
}
EOF
cc "$tmp_dir/rss_measure.c" -o "$rss_tool"

measure_rss_kb() {
    local name="$1"
    local bin="$2"
    local result_file="$tmp_dir/$name.rss"
    "$rss_tool" "$bin" >"$result_file"
    local status
    local rss
    read -r status rss <"$result_file"
    if [[ "$status" -ne 0 ]]; then
        echo "错误: $name smoke 退出码非 0: $status" >&2
        exit 1
    fi
    echo "$rss"
}

c99_rss_kb="$(measure_rss_kb c99 "$c99_bin")"
native_rss_kb="$(measure_rss_kb native "$native_bin")"

if [[ "$native_rss_kb" -gt "$c99_rss_kb" ]]; then
    echo "错误: native smoke peak RSS 高于 C99 smoke: native=${native_rss_kb}KB c99=${c99_rss_kb}KB" >&2
    exit 1
fi

echo "verify_native_c99_smoke_peak_rss: ok (native_peak_rss_kb=$native_rss_kb c99_peak_rss_kb=$c99_rss_kb)"
