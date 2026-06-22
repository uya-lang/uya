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
