#!/usr/bin/env bash
#
# Multi-fd scheduler async MIR-C99 parity shard: concurrent read_exact tasks
# sharing one scheduler queue and Linux epoll event loop.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmp_dir="$(mktemp -d /tmp/uya-mir-c99-async-multi-fd.XXXXXX)"
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

run_case "async_multi_fd_scheduler" '// mir_c99_async_multi_fd_scheduler_case
use std.async;
use std.async_event;
use std.async_scheduler;
use libc.syscall;

error ChildSpawnFailed;
error PipeCreateFailed;

const TEST_SYS_PIPE2: i64 = 293;
const TEST_O_NONBLOCK: i32 = 0x800;

fn test_sys_pipe2(pipefd: &i32, flags: i32) !i32 {
    return @syscall(TEST_SYS_PIPE2, pipefd as i64, flags as i64) as! i32;
}

fn spawn_delayed_writer(write_fd: i32, a: byte, b: byte, c: byte, d: byte, delay_ns: i64) !i32 {
    const fork_result: !i64 = sys_fork();
    const child_pid: i64 = fork_result catch {
        return error.ChildSpawnFailed;
    };
    if child_pid == 0 {
        const req: TimeSpec = TimeSpec{ tv_sec: 0, tv_nsec: delay_ns };
        var rem: TimeSpec = TimeSpec{ tv_sec: 0, tv_nsec: 0 };
        _ = sys_nanosleep(&req, &rem) catch {};
        var src: [byte: 4] = [ a, b, c, d ];
        _ = sys_write(write_fd, &src[0] as *const byte, 4) catch {};
        _ = sys_close(write_fd) catch {};
        sys_exit(0);
    }
    return child_pid as i32;
}

fn wait_child(child_pid: i32) void {
    if child_pid > 0 {
        var status: i32 = 0;
        _ = sys_waitpid(child_pid, &status, 0) catch {};
    }
}

struct FdRead4Future : Future<!i32> {
    fd: i32,
    expected_first: byte,
    expected_last: byte,
    total: usize = 0,
    buf: [byte: 4] = [],

    fn poll(self: &Self, waker: &Waker) Poll<!i32> {
        while self.total < 4usize {
            const n_result: !isize = sys_read(self.fd, &self.buf[self.total] as *byte, 4usize - self.total);
            const n: isize = n_result catch |err| {
                const err_id: u32 = @error_id(err);
                if err_id == libc_EAGAIN as u32 || err_id == libc_EWOULDBLOCK as u32 {
                    waker.wait_readable(self.fd);
                    return Poll<!i32>.Pending({});
                }
                return Poll<!i32>.Ready(ok<i32>(0 - 3));
            };
            if n <= 0 {
                return Poll<!i32>.Ready(ok<i32>(0 - 4));
            }
            self.total = self.total + n as usize;
        }
        if self.buf[0] != self.expected_first || self.buf[3] != self.expected_last {
            return Poll<!i32>.Ready(ok<i32>(0 - 2));
        }
        return Poll<!i32>.Ready(ok<i32>(self.buf[0] as i32 + self.buf[3] as i32));
    }

    fn release(self: &Self) void {
        _ = self;
    }
}

fn read_four_sum(fd: i32, expected_first: byte, expected_last: byte) Future<!i32> {
    return FdRead4Future{ fd: fd, expected_first: expected_first, expected_last: expected_last };
}

export fn main() i32 {
    var first_pipe: [i32: 2] = [];
    var second_pipe: [i32: 2] = [];
    _ = test_sys_pipe2(&first_pipe[0], TEST_O_NONBLOCK) catch {
        return 1;
    };
    _ = test_sys_pipe2(&second_pipe[0], TEST_O_NONBLOCK) catch {
        _ = sys_close(first_pipe[0]) catch {};
        _ = sys_close(first_pipe[1]) catch {};
        return 2;
    };

    const first_read_fd: i32 = first_pipe[0];
    const first_write_fd: i32 = first_pipe[1];
    const second_read_fd: i32 = second_pipe[0];
    const second_write_fd: i32 = second_pipe[1];
    const first_child: i32 = spawn_delayed_writer(first_write_fd, 11, 12, 13, 14, 5 * 1000 * 1000) catch {
        return 3;
    };
    const second_child: i32 = spawn_delayed_writer(second_write_fd, 21, 22, 23, 24, 10 * 1000 * 1000) catch {
        wait_child(first_child);
        return 4;
    };

    const first_future: Future<!i32> = read_four_sum(first_read_fd, 11, 14);
    const second_future: Future<!i32> = read_four_sum(second_read_fd, 21, 24);

    var scheduler: Scheduler = scheduler_new();
    var epoll_impl: LinuxEpoll = linux_epoll_create(0) catch {
        return 7;
    };
    const loop: EventLoop = epoll_impl;
    var first_result: i32 = 0;
    var second_result: i32 = 0;
    const completed: i32 = scheduler_run_pair_i32_with_event_loop(&scheduler, loop, first_future, second_future, &first_result, &second_result, 1000) catch {
        return 8;
    };

    wait_child(first_child);
    wait_child(second_child);
    _ = sys_close(first_read_fd) catch {};
    _ = sys_close(first_write_fd) catch {};
    _ = sys_close(second_read_fd) catch {};
    _ = sys_close(second_write_fd) catch {};
    _ = sys_close(epoll_impl.epfd) catch {};

    if completed != 2 {
        return 9;
    }
    if first_result != 25 {
        return 10;
    }
    if second_result != 45 {
        return 11;
    }
    return 24;
}'

echo "OK: MIR-C99 async multi-fd scheduler parity matched C99 oracle"
