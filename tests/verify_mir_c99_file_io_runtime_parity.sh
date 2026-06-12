#!/usr/bin/env bash
#
# File IO runtime helpers must match the C99 oracle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-file-io.XXXXXX)"
trap 'rm -rf "$tmp_dir"; rm -f /tmp/uya_mir_c99_file_runtime_parity' EXIT

case_file="$tmp_dir/file_io.uya"
cat >"$case_file" <<'UYA'
use libc.sys_open;
use libc.sys_write;
use libc.sys_close;
use libc.sys_unlink;
use libc.O_WRONLY;
use libc.O_CREAT;
use libc.O_TRUNC;

export fn main() i32 {
    const path: *const byte = "/tmp/uya_mir_c99_file_runtime_parity\0";
    const msg: *const byte = "file!\0";
    const fd: i32 = sys_open(path, (O_WRONLY | O_CREAT | O_TRUNC) as i32, 0o644) catch {
        return 10;
    };
    const written: isize = sys_write(fd, msg, 5usize) catch {
        _ = sys_close(fd) catch { -1; };
        return 11;
    };
    _ = sys_close(fd) catch {
        return 12;
    };
    _ = sys_unlink(path) catch {
        return 13;
    };
    return written as i32;
}
UYA

MIR_C99_GENERATE_CMD='./tests/mir_c99_generate.sh {input} {output} {log}' \
C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null

echo "OK: MIR-C99 file IO runtime parity matched C99 oracle"
