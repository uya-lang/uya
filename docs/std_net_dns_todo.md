# `std.net.dns` 标准 DNS 客户端 TODO

> **核对头（2026-10-19）**：整份复选框已逐条回到源码与测试核对（上一版核对头只确认了 A/AAAA 并发聚合一项）。本轮结论：
> - **从 `[ ]` 补正为 `[x]` 的项**：Linux UDP + 超时、TCP/53 fallback、`/etc/resolv.conf`、`DnsNoNameserver`、`DnsClient` 注入 resolver、`DnsPlatformUnsupported`、同步/异步同一套错误语义、async future 可被 `block_on_with_event_loop` 驱动、压缩指针 / A / AAAA / UDP / TCP 长度前缀 / 非法域名 / 截断 / 循环压缩指针 8 项单测、async transport 超时与取消与 `TC=1` fallback——均给出 `lib/std/net/dns.uya` 行号或 `tests/test_std_dns*.uya` 用例名。
> - **补正为 `[~]`（实现有、测试/对齐不足）**：域名编解码独立 roundtrip（`dns_encode_name` `:451` 为内部函数）、CNAME 链解析（实现有 `:1396`/`:1443`，无专项测试）、结果顺序与系统解析器对齐（只按 `prefer_family` 分段）。
> - **仍为 `[ ]` 的真缺口**：Darwin / Windows 对应实现（`grep "tos_darwin\|tos_macos\|tos_windows" lib/std/net/dns.uya` 无命中，实现直接调 Linux syscall）；"未来 async HTTPS client 复用 async DNS transport" 与"异步 HTTPS 沿用 nonblocking TCP DNS 路径"（当前没有 async HTTPS client，`lib/tls/https.uya:694` 仍是同步 `dns_client_resolve_host`）；"支持按优先级返回多个地址的更完整排序策略"与"保留可诊断信息便于上层打印"（后者目前只靠错误码区分，未提供可打印的诊断字段）。
> - 当前测试规模：`tests/test_std_dns.uya` 有 34 个 `test` 用例；另有 `test_std_dns_async_transport.uya`（11 例）、`test_std_dns_async_query_aggregate.uya`（3 例）、`test_std_dns_async_composition_shape.uya`（1 例）、`test_async_runtime_shared_dns.uya`。
>
> 总体口径见 `docs/todo_status_index.md`。

本文档用于规划一个最小但可复用的 **标准 DNS 客户端**，目标是把“解析主机名”从各个业务模块里剥离出来，统一收敛到 `std.net.dns`。

这个模块的直接受益方包括：

- `lib/tls/https.uya` 的外站连接路径
- `lib/std/http/http1_async.uya` 的异步主机名连接路径
- 未来的 HTTP client / server
- 未来的异步 HTTPS client
- 其它需要把 hostname 解析为 `A` / `AAAA` 地址的标准库模块

---

## 目标

1. 提供一个可独立测试的 DNS 客户端模块。
2. 支持最小常用解析能力：`A`、`AAAA`、`CNAME`。
3. 允许调用方按需做“只解析 IPv4”或“只解析 IPv6”。
4. 解析失败时返回明确错误，不把 DNS 细节泄漏到上层业务模块。
5. 让 HTTPS/HTTP 客户端不再依赖外部 `curl` 或 shell 桥接。
6. 同一套解析核心同时服务阻塞式和异步 HTTPS。

---

## 设计边界

这个模块只做“客户端递归解析”的最小能力，不做完整权威 DNS 服务器，也不做 zone 文件管理。

### 传输策略

- 标准查询主路径以 **UDP/53** 为主。
- 当响应被截断（`TC=1`）、响应体超过经典 UDP 能力、或调用方明确要求时，切换到 **TCP/53 fallback**。
- 因此这个模块不是“只做 UDP”，而是“**UDP 优先，TCP 补齐**”。
- 同步 HTTPS 与异步 HTTPS 都应共享这套传输策略，只是 I/O 驱动方式不同。

### 要做

- 构造 DNS Query。
- 通过 UDP 向 nameserver 发送请求。
- 在必要时通过 TCP 重发同一查询。
- 解析响应包。
- 处理 CNAME 链的最小展开。
- 提供主机名到地址的查询接口。
- 提供阻塞式与 `Future<!T>` 风格的异步查询接口。

### 暂不做

- DNSSEC。
- DoT / DoH。
- 权威服务器。
- 完整的负缓存策略。
- 复杂的 SRV / NAPTR / TXT 业务解析。

---

## 计划模块

建议模块路径如下：

- `lib/std/net/dns.uya`
- 可选辅助文件：
  - `lib/std/net/dns_message.uya`
  - `lib/std/net/dns_transport.uya`
  - `lib/std/net/dns_async.uya`
  - `lib/std/net/resolv_conf.uya`

建议调用方式：

```uya
use std.net.dns;
```

---

## API 草案

### 基础类型

- `DnsRecordType`
  - `A`
  - `AAAA`
  - `CNAME`
  - `NS`
  - `TXT`
- `DnsClass`
  - 先固定 `IN = 1`
- `DnsError`
  - `InvalidName`
  - `InvalidPacket`
  - `TruncatedPacket`
  - `NoSuchName`
  - `Timeout`
  - `Refused`
  - `ServerFailure`
  - `NoNameserver`
  - `NetworkUnreachable`
  - `WouldBlock`
  - `PlatformUnsupported`
  - `Unsupported`

说明：

- DNS 模块的错误应停留在 `std.net` / `std` 层，不应返回 `Tls*` 命名空间错误。
- `Unsupported` 仅用于调用方明确请求了尚未实现的能力；传输层被截断后应继续 fallback，而不是直接返回 `Unsupported`。

### 解析结果

建议至少提供两个层次：

1. 低层结果：保留原始记录，便于单测和调试。
2. 高层结果：直接返回可连接的地址列表。

可考虑的结构：

- `DnsAddress`
  - `family`
  - `addr_len`
  - `addr[16]`
  - `port` 可选
- `DnsAnswer`
  - `name`
  - `rtype`
  - `ttl`
  - `rdata`

### 核心接口

建议最少实现这些函数：

- `fn dns_client_init(ctx: &DnsClient, resolver: &[byte]) void`
- `fn dns_client_query_a(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) !usize`
- `fn dns_client_query_aaaa(...) !usize`
- `fn dns_client_resolve_host(...) !usize`
- `fn dns_client_resolve_first_ipv4(...) !usize`
- `fn dns_client_resolve_first_ipv6(...) !usize`

为了服务异步 HTTPS，建议同时提供：

- `export @async_fn fn dns_client_query_a_async(...) Future<!usize>`
- `export @async_fn fn dns_client_query_aaaa_async(...) Future<!usize>`
- `export @async_fn fn dns_client_resolve_first_ipv6_async(...) Future<!usize>`
- `export @async_fn fn dns_client_query_all_async(...) Future<!usize>`
- `export @async_fn fn dns_client_lookup_localhost_async(...) Future<!usize>`
- `dns_client_query_a_async` 已有 `localhost` 的最小回归覆盖。
- `dns_client_query_aaaa_async` 已有 `localhost` 的最小回归覆盖。
- `dns_client_resolve_first_ipv6_async` 已有 `localhost` 的最小回归覆盖。
- `dns_client_resolve_first_ipv6_async` 也覆盖了字面量 IPv4 的 AAAA 映射结果。
- `dns_client_query_all_async` 已有 `localhost` 的最小回归覆盖。
- `dns_client_lookup_localhost_async` 已有 `localhost` 的最小回归覆盖。
- `dns_client_query_all_async` 也覆盖了字面量 IPv4 的 `A + AAAA` 拼接结果。
- `dns_client_query_all_async` 的顺序语义是先 `A` 再 `AAAA`，和同步 `dns_client_query_all` 保持一致。
- `dns_client_lookup_localhost_async` 目前仍是同步包装入口，只是把 `dns_client_lookup_localhost` 包成 `Future<!usize>`。
- 如果要继续推进真正的 nonblocking DNS transport，优先从 `dns_client_query_a_udp_future` 这条最小 future 入手，而不是重新把高层解析入口拆成复杂 future。
- `dns_client_query_all` 也已有字面量 IPv4 的 `A + AAAA` 顺序覆盖。
- `dns_client_query_all_async` 的结果布局是 `A` 段在前，`AAAA` 段紧随其后，整体长度由两段有效结果相加决定。
- `dns_client_query_all` / `dns_client_query_all_async` 现在都补了拼接边界断言。

异步接口约束：

- 结果缓冲区由调用方提供，避免 future 内部持有堆分配结果。
- 同步与异步接口共享同一套报文编解码与记录解析逻辑。
- 异步 transport 应能接入 `std.async.Waker.wait_readable` / `wait_writable`。

可选但推荐补充的 transport 接口：

- `fn dns_client_query_udp(...) !usize`
- `fn dns_client_query_tcp(...) !usize`
- `export @async_fn fn dns_client_query_udp_async(...) Future<!usize>`
- `export @async_fn fn dns_client_query_tcp_async(...) Future<!usize>`

可选接口：

- [x] `fn dns_client_query_all(...) !usize`
- `fn dns_client_lookup_localhost(...) !usize`
- [x] `fn dns_client_set_timeout_ms(...) void`
- [x] `fn dns_client_get_timeout_ms(...) u32`

---

## 实现阶段

### 1. 模块骨架

- [x] 新建 `lib/std/net/dns.uya`。
- [x] 定义错误码、记录类型、查询类型、结果结构体。
- [x] 统一公共常量，例如：
  - `DNS_PORT = 53`
  - `DNS_MAX_NAME = 253`
  - `DNS_MAX_LABEL = 63`
  - `DNS_MAX_PACKET = 512`（先做最小 UDP 版）
- [x] 为后续解析器预留游标型读取函数。

### 2. DNS 报文编码

- [x] 实现 DNS Header 编码与解析。
- [x] 实现 Question 区编码。
- [x] 实现域名 label 编码。
- [x] 实现基本的域名压缩指针解析。
- [x] 支持请求 ID、flags、QDCOUNT、ANCOUNT、NSCOUNT、ARCOUNT。
- [x] 先只支持 `IN` class。

### 3. DNS 报文解析

- [x] 解析 `A` 记录。
- [x] 解析 `AAAA` 记录。
- [x] 解析 `CNAME` 记录并支持最小链式展开。
- [x] 解析 TTL。
- [x] 忽略暂不支持的记录类型，但要正确跳过 RDATA 长度。
- [x] 对压缩指针循环做保护，避免死循环。

### 4. 传输层

- [x] 使用 UDP socket 向 nameserver 发包。
- [x] 明确首版的“正常路径”为 UDP/53。
- [x] 支持读取 `/etc/resolv.conf` 中的 `nameserver`。
- [x] 如果解析器配置为空，返回明确错误。
- [x] 支持最小超时重试：
  - [x] 实现 `dns_socket_set_recv_timeout` / `dns_socket_set_send_timeout` 辅助函数
  - [x] UDP 查询带 3 次重试机制
  - [x] TCP 查询带 2 次重试机制
  - [x] 超时时间可通过 `dns_client_set_timeout_ms` 配置（默认 2000ms，范围 100ms-60s）
  - [x] 新增 `dns_client_get_timeout_ms` 获取当前超时
- [x] MVP 即支持 `TC` 截断位处理。
- [x] UDP 首包至少支持经典 512 字节响应；若要服务真实 HTTPS，需补 EDNS0 或直接在 `TC=1` 时走 TCP fallback。
- [x] `TC=1` 不能直接映射为 `Unsupported`；应改走 TCP 或返回明确的可恢复错误。
- [x] TCP fallback 复用同一套 DNS message 编码，只替换 transport 和长度前缀处理。
- [x] TCP 模式遵循 DNS over TCP 的两字节长度前缀收发格式。
- [x] 为异步 HTTPS 提供 nonblocking UDP/TCP transport：套接字置 `O_NONBLOCK`，在 `EAGAIN` 时返回 `Pending` 并注册 `Waker`。
- [x] 已有最小 `DnsUdpFuture` 形状，`A` 查询的 async 入口已经统一到这条 future 上。
- [x] `DnsUdpFuture` 已经在发送前设置 `O_NONBLOCK`，并在 `EAGAIN` / `EWOULDBLOCK` 时返回 `Pending`。
- [x] `DnsTcpFuture` 已实现，支持完整的 nonblocking TCP DNS 查询流程。
- [x] `dns_client_query_tcp_async` 接口已提供，支持 `A` 和 `AAAA` 查询。

### 5. 本地优先顺序

- [x] 先识别字面量 IPv4 / IPv6。
- [x] 再查 `/etc/hosts`。
- [x] 再走 DNS 查询。
- [x] 允许调用方指定只要 IPv4 或只要 IPv6：
  - [x] 定义 `DNS_PREFER_ANY` / `DNS_PREFER_IPV4` / `DNS_PREFER_IPV6` 常量
  - [x] `DnsClient` 添加 `prefer_family` 字段
  - [x] 提供 `dns_client_set_prefer_family()` / `dns_client_get_prefer_family()` 接口
  - [x] `dns_client_resolve_host()` 根据偏好选择解析策略
  - [x] `dns_client_query_all()` 根据偏好返回结果

### 6. 高层解析策略

- [x] 返回第一个可用地址。
- [ ] 支持按优先级返回多个地址的更完整排序策略。
- [x] 对 `CNAME` 结果做最小展开后再找地址记录：
  - [x] 添加 `dns_find_cname_target_address()` 函数，在同一个响应中查找 CNAME 目标对应的地址
  - [x] 修改 `dns_query_follow_cname_with_ttl()`，优先在同一个响应中查找地址，避免额外查询
- [~] 保持结果顺序尽量与系统解析器一致。（2026-10-19 核对：`dns_client_query_all()` `:1798` 按 `prefer_family` 决定 A/AAAA 段顺序，**未与系统解析器逐例对齐**；回归仅覆盖 `dns_query_all_prefer_ipv4` / `dns_query_all_prefer_ipv6`）

当前实现的优先级是：

- `dns_client_resolve_host` 先尝试 `A`，再回退到 `AAAA`
- `dns_client_query_all` 先拼接 `A`，再拼接 `AAAA`
- `dns_client_resolve_host` 现在会先查 `/etc/hosts` 的最小 IPv4 记录，再回落到 DNS
- `TC=1` 的 fallback 回归现在用固定 DNS packet 数据构造，稳定覆盖 UDP 截断 + TCP 重查逻辑
- `DnsUdpFuture` 目前先覆盖 `A` 查询，并保留 `localhost` / 字面量 IPv4 快路径

### 7. 错误模型

- [x] 把 DNS 状态码映射为 `std` 错误集合。
- [x] 区分“查询失败”和“解析失败”。
- [x] 区分“无记录”和“网络不可达”。
- [ ] 保留可诊断信息，便于 HTTPS / HTTP 上层打印。
- [x] 同步与异步接口返回同一套错误语义；异步接口额外允许 `WouldBlock` / `Pending` 路径。（2026-10-19 核对：async 变体 `dns_client_query_a_async()` `:2040`、`dns_client_query_aaaa_async()` `:2044`、`dns_client_query_all_async()` `:1826` 均为薄包装，错误集与同步路径同源；would-block 收敛为 `Poll.Pending` 由 `dns_client_query_a_udp_future()` `:1848` / `dns_client_query_a_tcp_future()` `:2020` 承担）

---

## 平台与依赖

### Linux

- [x] 先支持 Linux 上的 UDP socket 与读写超时。（2026-10-19 核对：`dns_client_set_timeout_ms()` `lib/std/net/dns.uya:770` / `dns_client_get_timeout_ms()` `:781`；超时行为回归 `tests/test_std_dns.uya` 的 `dns_query_a_udp_future_times_out_with_silent_nameserver`、`dns_query_a_tcp_future_times_out_with_silent_nameserver`）
- [x] 同时预留 TCP/53 fallback 的 Linux 实现，避免 MVP 只能解析小响应。（2026-10-19 核对：`dns_client_query_a_with_tcp_fallback_packets()` `:1836`、`dns_client_query_tcp_async()` `:2028`；回归 `dns_tcp_fallback_on_truncated_udp`、`dns_query_a_with_ttl_from_tcp_fallback`）
- [x] nameserver 读取先按 `/etc/resolv.conf`。（2026-10-19 核对：`dns_parse_resolv_conf_first_nameserver()` `:586`，`sys_open("/etc/resolv.conf", ...)` `:587`；回归 `dns_init_parses_nameserver_port`）
- [x] 如果 `resolv.conf` 不存在或为空，且调用方未显式配置 resolver，则返回 `NoNameserver`。（2026-10-19 核对：实际错误名为 `export error DnsNoNameserver` `:21`，`dns_parse_resolv_conf_first_nameserver()` 在 `open`/读失败/空内容三条路径均返回它，`:587/:593/:597`）
- [x] 测试环境如需固定 resolver，应通过 `DnsClient` 配置注入，而不是偷偷回退到编译期常量。（2026-10-19 核对：`dns_client_init(ctx, resolver)` `:727` 是唯一 resolver 入口，无编译期常量回退）

### 其他平台

- [x] 平台不可用时返回 `error.PlatformUnsupported` 或 `error.DnsPlatformUnsupported` 这一类 `std.net` 错误。（2026-10-19 核对：`export error DnsPlatformUnsupported` `:24`，在 `:222/:238/:305/:839/:859` 等处返回）
- [ ] 后续再补 Darwin / Windows 对应实现。（2026-10-19 复核：仍未做——`lib/std/net/dns.uya` 中 `grep "tos_darwin\|tos_macos\|tos_windows"` 无命中，实现直接走 Linux syscall 封装）

---

## HTTPS 接入点

DNS 客户端完成后，HTTPS 侧应做这些改造：

- [x] `https_client_connect` 不再依赖 `curl` 或 shell 命令。
- [x] `https_get` 先解析 hostname，再使用解析结果建立 TCP 连接。
- [x] TLS SNI 仍然使用原始 hostname，而不是解析后的 IP。
- [x] 证书校验仍然基于 hostname，而不是 IP。
- [x] `tests/test_https_real_site.uya` 改为直接验证 `std.net.dns` + TLS 连接链路。

### 异步 HTTPS 接入点

- [x] `std.http.http1_async` 的 connect 路径改为先走 `std.net.dns`，同时保留 `localhost` / 字面量 IPv4 快路径。
- [ ] 未来的 async HTTPS client 复用同一套 async DNS transport，避免在事件循环里阻塞等待解析。
- [x] async DNS 的 future 在 `epoll` 事件循环里可被 `block_on_with_event_loop` 驱动。（2026-10-19 核对：回归 `tests/test_std_dns.uya` 的 `dns_query_all_async_with_event_loop_localhost`（`:260`）、`test_std_dns_async_transport.uya` 的 `dns_query_a_udp_future_loopback_success` / `dns_query_a_tcp_future_loopback_success`）
- [ ] 若 DNS 需要 TCP fallback，异步 HTTPS 也必须沿用 nonblocking TCP DNS 路径，而不是退回同步阻塞实现。

---

## 测试计划

### 1. 单元测试

建议新建：

- `tests/test_std_dns.uya`

覆盖点：

- [~] 域名编码 / 解码 roundtrip。（2026-10-19 核对：`dns_encode_name()` `:451` / `dns_name_valid()` `:424` 为内部函数，**无独立 roundtrip 单测**；端到端由 `dns_query_a_async_localhost` 等覆盖）
- [x] 压缩指针解析。（2026-10-19 核对：`dns` 名称解析在 `:526` 处理 `0xC0` 前缀压缩指针；回归 `dns_query_a_with_tcp_fallback_packets_rejects_compression_loop`）
- [x] A 记录解析。（回归 `dns_resolve_ipv4_literal`、`dns_query_a_async_localhost`）
- [x] AAAA 记录解析。（回归 `dns_resolve_localhost_ipv6_literal`、`dns_query_aaaa_async_localhost`）
- [~] CNAME 链解析。（2026-10-19 核对：`dns_extract_cname()` `:1396` / `dns_find_cname_target_address()` `:1443` 已实现，但 **`tests/` 中无 CNAME 专项用例**）
- [x] UDP 响应解析。（回归 `dns_query_all_localhost`、`dns_udp_future_localhost`、`dns_query_a_udp_future_loopback_success`）
- [x] TCP 长度前缀收发与解析。（回归 `dns_query_a_with_ttl_from_tcp_fallback`、`dns_query_a_tcp_future_loopback_success`、`dns_query_all_async_prefer_ipv4_tcp_fallback_accepts_tcp_body_larger_than_udp_limit`）
- [x] 非法域名拒绝。（回归 `dns_query_a_rejects_empty_name`、`dns_query_a_async_rejects_empty_name`）
- [x] 截断包拒绝。（回归 `dns_query_a_with_tcp_fallback_packets_rejects_truncated_udp`）
- [x] 循环压缩指针拒绝。（回归 `dns_query_a_with_tcp_fallback_packets_rejects_compression_loop`）

### 2. 集成测试

- [x] 使用 `localhost` 或本机可控 nameserver 做 UDP 解析集成测试。
- [x] 增加至少一个触发 TCP fallback 的集成测试。
- [x] 如果环境允许网络，再增加一次真实域名 smoke test。
  - **结果**: DNS 解析成功 (example.com → 172.66.147.243)
  - **限制**: TLS 握手失败（简化版 TLS 实现不支持真实服务器）
- [x] 若网络不可用，使用 skip marker 跳过真实外网测试。

### 2.1 异步集成测试

- [x] 已有 `tests/test_std_dns.uya` 包含 async 测试用例，验证 async UDP/TCP 查询能在事件循环中完成。
- [x] 覆盖 nonblocking socket 下的 `EAGAIN -> Pending -> Ready` 路径（UDP 和 TCP）。
- [x] 覆盖 async transport 的超时、取消前 close、以及 `TC=1` 后 TCP fallback。（2026-10-19 核对：`tests/test_std_dns_async_transport.uya` 的 `dns_transport_direct_futures_time_out_on_silent_loopback_nameservers`、`dns_transport_direct_futures_cancel_cleanly_in_shared_queue`、`dns_query_all_async_any_tcp_fallback_and_aaaa`）

### 3. HTTPS 联动测试

- [x] 让 `tests/test_https_real_site.uya` 直接走 `std.net.dns`。
- [x] 确认外站 HTTPS 不再依赖 curl 桥接。
- [x] 保留本地 loopback HTTPS 测试，避免外网不稳定影响回归。
- [x] 为异步 HTTP/HTTPS 新增 hostname 解析用例，覆盖 DNS + nonblocking connect 联动。

---

## 验收标准

1. `std.net.dns` 可以独立编译通过。
2. `test_std_dns.uya` 在 `--c99` 与 `--uya --c99` 下通过。
3. `test_std_dns_async.uya` 能在事件循环里通过。
4. 标准查询走 UDP；截断或大响应能自动切换到 TCP fallback。
5. `https_get` 的外站路径只依赖标准 DNS + 标准 socket，不依赖 curl。
6. 异步 HTTP/HTTPS 的 hostname 解析不阻塞事件循环。
7. 证书校验、SNI、hostname 匹配保持不变。
8. 文档里不再把 DNS 解析逻辑散落在 `tls` 或 `http` 模块中。

---

## 推荐实现顺序

1. 先做域名编码 / 解码和报文头。
2. 再做同步 UDP 查询与 `A` 记录。
3. 然后补 `AAAA`、`CNAME`、错误映射和 `/etc/resolv.conf`。
4. 再做 `TC=1` 的 TCP fallback 与 async transport。
5. 最后接入同步 HTTPS 与异步 HTTP/HTTPS，并把旧的桥接路径删掉。

---

## 备注

- 这个 TODO 的目标不是“做一个全功能 DNS 服务器”，而是“做一个够 HTTPS/HTTP 用的、可测试的标准客户端”。
- 如果后续需要缓存，可以单独拆一个 `std.net.dns_cache`，不要把缓存逻辑塞进解析核心。
