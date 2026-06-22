# HTTPS Client Stdlib Completed

## 2. 阶段 A：地址、socket、poll、TCP

### A1. `std.net.addr`

- [x] test_ipv4_parse_valid
  - 验证：`../uya/bin/uya test tests/test_std_net_addr.uya --c99` 通过（1 个测试，7 个断言）。
  - 验证：`../uya/bin/uya test tests/test_std_net_addr.uya --uya --c99` 通过（1 个测试，7 个断言）。

## 2. 阶段 A：地址、socket、poll、TCP
### A1. `std.net.addr`

```text
- [x] test_ipv4_parse_rejects_bad_octet
  验证命令：../uya/bin/uya test tests/test_std_net_addr.uya
  验证结果：通过；ipv4_parse_valid 与 ipv4_parse_rejects_bad_octet 均 OK，Assertions Passed: 8。
```
### A1. `std.net.addr`

先写测试：

```text
- [x] test_ipv4_parse_rejects_trailing_bytes
  验证：`../uya/bin/uya test tests/test_std_net_addr.uya`
  结果：通过，3 tests，0 failed；新增 `ipv4_parse_rejects_trailing_bytes` 覆盖 `127.0.0.1x` 尾随字节拒绝路径。
```
## 2. 阶段 A：地址、socket、poll、TCP
### A1. `std.net.addr`
先写测试：
- [x] test_ipv4_display_roundtrip
  - 验证命令：`../uya/bin/uya test tests/test_std_net_addr.uya`
  - 验证结果：通过；`ipv4_display_roundtrip` 在内的 4 个测试全部通过。
  - 验证命令：`git diff --check`
  - 验证结果：通过；未发现空白或补丁格式问题。

### A1. `std.net.addr`

- [x] test_socket_addr_port_range
  - 说明：新增 `socket_addr_new` / `socket_addr_format` 端口边界测试，覆盖 `0` 和 `65535`，无生产代码改动。
  - 验证：`../uya/bin/uya test tests/test_std_net_addr.uya --c99` 通过（5 个测试，75 个断言）。
  - 验证：`../uya/bin/uya test tests/test_std_net_addr.uya --uya --c99` 通过（5 个测试，75 个断言）。

### A1. `std.net.addr`

上下文：## 2. 阶段 A：地址、socket、poll、TCP

目标文件：

```text
lib/std/net/addr.uya
tests/test_std_net_addr.uya
```

已完成任务：

```text
- [x] test_ipv6_literal_is_explicitly_unsupported_or_parsed
  验证：
  - ../uya/bin/uya test tests/test_std_net_addr.uya -> 通过（6 tests passed, 0 failed）
  - python3 /home/winger/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_https_client_stdlib.md -> 通过（1 active task）
  - git diff --check -> 通过
  - make clean -> 通过
  - make backup-all -> 通过
```

## 2. 阶段 A：地址、socket、poll、TCP
### A1. `std.net.addr`
- [x] tests/test_std_net_addr.uya 通过 --c99
  - 验证：`../uya/bin/uya test tests/test_std_net_addr.uya --c99` 通过（6 个测试，76 个断言）。

### A1. `std.net.addr`

- [x] tests/test_std_net_addr.uya 通过 --uya --c99
  - 验证：`../uya/bin/uya test tests/test_std_net_addr.uya --uya --c99` 通过（6 个测试，76 个断言）。
  - 相关验证：`../uya/bin/uya test tests/test_std_net_addr.uya --c99` 通过（6 个测试，76 个断言）。

### A2. `std.net.socket`
上下文：先写测试

```text
- [x] test_socket_set_nonblocking_on_valid_fd
  验证：
  - `../uya/bin/uya test tests/test_std_net_socket.uya`（1 个测试通过，0 个失败）
  - `../uya/bin/uya test tests/test_tcp_basic.uya`（3 个测试通过，0 个失败）
  - `../uya/bin/uya test tests/test_syscall_ioctl.uya`（3 个测试通过，0 个失败）
```

### A2. `std.net.socket`
上下文：先写测试

```text
- [x] test_socket_set_cloexec_on_valid_fd
  验证：
  - `../uya/bin/uya test tests/test_std_net_socket.uya`（2 个测试通过，0 个失败）
  - `../uya/bin/uya test tests/test_tcp_basic.uya`（3 个测试通过，0 个失败）
  - `../uya/bin/uya test tests/test_syscall_ioctl.uya`（3 个测试通过，0 个失败）
```

### A2. `std.net.socket`
上下文：修复 `docs/todo_https_client_stdlib_failed.md`

```text
- [x] test_socket_close_ignores_negative_fd
  - 实现：`lib/std/net/socket.uya` 新增 `net_socket_close(fd)`；`fd < 0` 直接返回，`close(2)` 错误静默忽略。
  - 测试：`tests/test_std_net_socket.uya` 新增 `socket_close_ignores_negative_fd`。
  - 失败归档修复：`make backup-all` 旧阻塞点来自 `test_async_thread_pool_dynamic_growth` 在 worker 已创建、队列已积压、但 slot 尚未标记为 RUNNING 的调度窗口读取 `running_workers`；已在该测试中等待 running worker 可见后再采样 queued metrics。
  - 验证：`export UYA_ROOT="$PWD" && ../uya/bin/uya test tests/test_std_net_socket.uya --c99` 通过（3 tests, 0 failed, 4 assertions passed）。
  - 验证：`export UYA_ROOT="$PWD" && ../uya/bin/uya test tests/test_std_net_socket.uya --uya --c99` 通过（3 tests, 0 failed, 4 assertions passed）。
  - 验证：`export UYA_ROOT="$PWD" && ../uya/bin/uya test tests/test_tcp_basic.uya` 通过（3 tests, 0 failed, 10 assertions passed）。
  - 验证：`export UYA_ROOT="$PWD" && ../uya/bin/uya test tests/test_syscall_ioctl.uya` 通过（3 tests, 0 failed, 3 assertions passed）。
  - 验证：`export UYA_ROOT="$PWD" && for i in 1 2 3; do timeout 90s ../uya/bin/uya test tests/test_async_thread_pool_dynamic_growth.uya || exit $?; done` 通过（每轮 5 tests, 0 failed, 113 assertions passed）。
  - 验证：`export UYA_ROOT="$PWD" && timeout 90s ../uya/bin/uya test tests/test_async_compute_dynamic_resource_pressure.uya` 通过（1 test, 0 failed, 53 assertions passed）。
  - 验证：`./tests/run_programs_parallel.sh --hide-pass` 通过（1054 tests, 0 failed）。
  - 验证：`make clean && make backup-all` 通过。
```
