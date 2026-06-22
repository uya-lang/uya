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
