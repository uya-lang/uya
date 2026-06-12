#!/usr/bin/env bash
#
# FD/IO async MIR-C99 parity shard: AsyncFd write/read plus write_all/read_exact
# on nonblocking file descriptors.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-async-fd-io.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

run_case() {
    local name="$1"
    local body="$2"
    local case_file="$tmp_dir/${name}.uya"
    printf '%s\n' "$body" >"$case_file"
    MIR_C99_GENERATE_CMD='bash ./tests/mir_c99_generate.sh {input} {output} {log}' \
    C99_ORACLE_GENERATE_CMD='bash ./tests/c99_oracle_generate.sh {input} {output} {log}' \
    bash "$REPO_ROOT/tests/verify_mir_c99_oracle_parity_harness.sh" --case "$case_file" >/dev/null
}

run_case "async_fd_io" '// mir_c99_async_fd_io_case
use std.async;
use libc.syscall;

error AsyncFdFailed;
error PipeCreateFailed;
error PipeReadFailed;
error PipeWriteFailed;
error UnexpectedReady;
error UnexpectedPending;

const TEST_SYS_WRITE: i64 = 1;
const TEST_SYS_PIPE2: i64 = 293;
const TEST_O_NONBLOCK: i32 = 0x800;

fn test_sys_write(fd: i32, buf: &const byte, count: usize) !isize {
    return @syscall(TEST_SYS_WRITE, fd as i64, buf as i64, count as i64) as! isize;
}

fn test_sys_pipe2(pipefd: &i32, flags: i32) !i32 {
    return @syscall(TEST_SYS_PIPE2, pipefd as i64, flags as i64) as! i32;
}

export fn main() i32 {
    var fds: [i32: 2] = [];
    _ = test_sys_pipe2(&fds[0], TEST_O_NONBLOCK) catch {
        return 1;
    };
    const read_fd: i32 = fds[0];
    const write_fd: i32 = fds[1];
    const wk: Waker = Waker{};

    var writer: AsyncFd = async_fd_new(write_fd);
    var src: [byte: 4] = [ 65, 66, 67, 68 ];
    const write_f: Future<!usize> = writer.write(&src[0] as &const byte, 2);
    const write_p: Poll<!usize> = write_f.poll(&wk);
    var wrote_once: usize = 0;
    match write_p {
        .Ready(n) => { wrote_once = n catch { return 3; }; },
        .Pending(_) => { return 3; },
    };
    if wrote_once != 2usize {
        return 3;
    }
    var out: [byte: 8] = [];
    const read_written: isize = sys_read(read_fd, &out[0] as *byte, 2) catch {
        return 4;
    };
    if read_written != 2 || out[0] != 65 || out[1] != 66 {
        return 4;
    }

    const write_all_f: Future<!usize> = writer.write_all(&src[2] as &const byte, 2);
    const wrote_all: usize = block_on<usize>(write_all_f) catch {
        return 5;
    };
    if wrote_all != 2usize {
        return 5;
    }
    const read_all_written: isize = sys_read(read_fd, &out[0] as *byte, 2) catch {
        return 6;
    };
    if read_all_written != 2 || out[0] != 67 || out[1] != 68 {
        return 6;
    }

    var reader: AsyncFd = async_fd_new(read_fd);
    var read_buf: [byte: 8] = [];
    const read_f: Future<!usize> = reader.read(&read_buf[0], 4);
    const first_read_p: Poll<!usize> = read_f.poll(&wk);
    match first_read_p {
        .Ready(_) => { return 7; },
        .Pending(_) => { },
    };
    var pending_src: [byte: 4] = [ 10, 20, 30, 40 ];
    const pending_write: isize = test_sys_write(write_fd, &pending_src[0] as &const byte, 4) catch {
        return 8;
    };
    if pending_write != 4 {
        return 8;
    }
    const second_read_p: Poll<!usize> = read_f.poll(&wk);
    var read_once: usize = 0;
    match second_read_p {
        .Ready(n) => { read_once = n catch { return 9; }; },
        .Pending(_) => { return 9; },
    };
    if read_once != 4usize || read_buf[0] != 10 || read_buf[1] != 20 || read_buf[2] != 30 || read_buf[3] != 40 {
        return 9;
    }

    var exact_buf: [byte: 8] = [];
    const exact_f: Future<!usize> = reader.read_exact(&exact_buf[0], 4);
    const first_exact_p: Poll<!usize> = exact_f.poll(&wk);
    match first_exact_p {
        .Ready(_) => { return 10; },
        .Pending(_) => { },
    };
    var exact_src: [byte: 4] = [ 1, 2, 3, 4 ];
    const exact_write: isize = test_sys_write(write_fd, &exact_src[0] as &const byte, 4) catch {
        return 11;
    };
    if exact_write != 4 {
        return 11;
    }
    const exact_n: usize = block_on<usize>(exact_f) catch {
        return 12;
    };
    if exact_n != 4usize || exact_buf[0] != 1 || exact_buf[1] != 2 || exact_buf[2] != 3 || exact_buf[3] != 4 {
        return 12;
    }

    _ = sys_close(read_fd) catch {};
    _ = sys_close(write_fd) catch {};
    return 23;
}'

echo "OK: MIR-C99 async fd/io parity matched C99 oracle"
