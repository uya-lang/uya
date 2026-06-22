# Uya HTTPS Client 标准库函数级 TDD TODO

> 目标：实现可复用的 Uya 标准库或基础库能力；本文不包含任何具体产品、应用项目或业务 adapter 的接入任务。
>
> 本文是函数定义级 TODO。每个任务都按 TDD 执行：先补测试，确认失败或覆盖缺口，再实现最小代码，最后跑对应验证。
>
> Async 约束：网络主路径必须优先提供 `@async_fn` / `Future<!T>` 接口。同步 wrapper 只能作为测试、兼容或 blocking smoke 辅助；标准库内部不得复制维护同步和异步两套网络主路径。
>
> 路径约定：本文文件路径均相对 `$UYA_ROOT`（当前 Uya 仓库根目录）。外部项目的接入清单不在本文维护。

---

## 0. 仓库边界

### 0.1 必须落在 Uya 仓库

```text
lib/std/net/
  addr.uya
  socket.uya
  poll.uya
  tcp.uya
  dns.uya
  resolver.uya

lib/tls/
  client.uya
  x509/verify.uya
  x509/trust_store.uya
  x509/hostname.uya

lib/std/http/client/
  url.uya
  header.uya
  request.uya
  response.uya
  chunked.uya
  cancel.uya
  pool.uya
  metrics.uya
  client.uya

lib/std/http/
  sse.uya
```

### 0.2 非目标边界

```text
业务 adapter
产品 routing
跨后端切换策略
应用层 stream bridge
业务成本与错误归因
```

具体应用项目的目标文件、测试文件与接入 TODO 由各自项目维护。本文只定义 Uya 标准库中的 DNS/TCP/TLS/HTTP parser/SSE parser 及 HTTP client 能力。

---

## 1. TDD 规则

每个 TODO 项必须遵守：

```text
1. 先写或启用 tests/test_*.uya。
2. 先运行最窄验证，确认测试能暴露缺口。
3. 再实现函数。
4. 再运行对应 test_*.uya 的 --c99 与 --uya --c99 路径。
5. 最后运行 make check 或相关 verify 脚本。
```

推荐命令：

```bash
# 示例执行前先设置 UYA_ROOT=/path/to/uya，或在当前仓库根目录中 export UYA_ROOT="$PWD"。
cd "$UYA_ROOT"
./bin/uya test tests/test_xxx.uya --c99
./tests/run_programs_parallel.sh --c99 test_xxx.uya
./tests/run_programs_parallel.sh --uya --c99 test_xxx.uya
make check
```

`check` 与 `build --c99` 只能作为补充诊断；不能替代 `test` 或 `run_programs_parallel.sh`，因为它们不会执行 `test` 块断言。

验收证据必须写入提交说明或 PR 描述：

```text
- 新增/修改的测试文件
- 首次失败原因
- 最终通过命令
- 是否覆盖 --c99 与 --uya --c99
- 是否触发 realnet gate
```

---

## 2. 阶段 A：地址、socket、poll、TCP

### A1. `std.net.addr`

目标文件：

```text
lib/std/net/addr.uya
tests/test_std_net_addr.uya
```

先写测试：

```text
- [ ] test_socket_addr_port_range
- [ ] test_ipv6_literal_is_explicitly_unsupported_or_parsed
```

函数定义：

```uya
export enum IpFamily {
    IPv4,
    IPv6,
}

export struct IpAddr {
    family: IpFamily,
    bytes: [byte: 16],
    len: usize,
}

export struct SocketAddr {
    ip: IpAddr,
    port: u16,
}

export fn ip_addr_zero() IpAddr;
export fn ip_addr_ipv4(a: byte, b: byte, c: byte, d: byte) IpAddr;
export fn ip_addr_ipv6(bytes: &const byte, len: usize) !IpAddr;
export fn ip_addr_is_ipv4(ip: &IpAddr) bool;
export fn ip_addr_is_ipv6(ip: &IpAddr) bool;
export fn ip_addr_parse_ipv4(input: &[byte]) !IpAddr;
export fn ip_addr_parse_ipv6(input: &[byte]) !IpAddr;
export fn ip_addr_format(ip: &IpAddr, out: &byte, out_max: usize, out_len: &usize) !usize;
export fn socket_addr_new(ip: IpAddr, port: u16) SocketAddr;
export fn socket_addr_format(addr: &SocketAddr, out: &byte, out_max: usize, out_len: &usize) !usize;
```

验收：

```text
- [ ] tests/test_std_net_addr.uya 通过 --c99
- [ ] tests/test_std_net_addr.uya 通过 --uya --c99
```

### A2. `std.net.socket`

目标文件：

```text
lib/std/net/socket.uya
tests/test_std_net_socket.uya
```

先写测试：

```text
- [ ] test_socket_set_nonblocking_on_valid_fd
- [ ] test_socket_set_cloexec_on_valid_fd
- [ ] test_socket_close_ignores_negative_fd
- [ ] test_socket_errno_maps_would_block
```

函数定义：

```uya
export fn net_socket_tcp_ipv4() !i32;
export fn net_socket_udp_ipv4() !i32;
export fn net_socket_set_nonblocking(fd: i32) !void;
export fn net_socket_set_blocking(fd: i32) !void;
export fn net_socket_set_cloexec(fd: i32) !void;
export fn net_socket_close(fd: i32) void;
export fn net_socket_shutdown_read(fd: i32) void;
export fn net_socket_shutdown_write(fd: i32) void;
export fn net_socket_is_would_block_errno(errno_id: i32) bool;
export fn net_socket_errno_to_connect_error(errno_id: i32) !void;
export fn net_socket_errno_to_read_error(errno_id: i32) !usize;
export fn net_socket_errno_to_write_error(errno_id: i32) !usize;
```

### A3. `std.net.poll`

目标文件：

```text
lib/std/net/poll.uya
tests/test_std_net_poll.uya
```

先写测试：

```text
- [ ] test_poll_timeout_returns_timeout
- [ ] test_poll_readable_on_pipe
- [ ] test_poll_writable_on_socketpair
- [ ] test_poll_error_on_closed_peer
```

函数定义：

```uya
export enum PollInterest {
    Read,
    Write,
    ReadWrite,
}

export struct PollResult {
    readable: bool,
    writable: bool,
    error: bool,
    hup: bool,
}

export fn poll_wait_fd(fd: i32, interest: PollInterest, timeout_ms: i32) !PollResult;
export fn poll_wait_readable(fd: i32, timeout_ms: i32) !void;
export fn poll_wait_writable(fd: i32, timeout_ms: i32) !void;
export fn poll_result_has_error(result: &PollResult) bool;
```

### A4. `std.net.tcp`

目标文件：

```text
lib/std/net/tcp.uya
tests/test_std_net_tcp.uya
```

先写测试：

```text
- [ ] test_tcp_connect_loopback
- [ ] test_tcp_connect_refused
- [ ] test_tcp_connect_timeout_gated
- [ ] test_tcp_read_timeout
- [ ] test_tcp_write_all_handles_short_write
- [ ] test_tcp_close_on_drop
- [ ] test_tcp_connect_async_loopback
- [ ] test_tcp_read_write_async_with_event_loop
- [ ] test_tcp_async_timeout_or_cancel
```

函数定义：

```uya
export struct TcpStream {
    fd: i32,
    peer: SocketAddr,
    nonblocking: bool,
    closed: bool,
}

export fn tcp_stream_empty() TcpStream;
export fn tcp_connect(addr: &SocketAddr, timeout_ms: u32) !TcpStream;
export fn tcp_connect_ipv4(ip: &IpAddr, port: u16, timeout_ms: u32) !TcpStream;
export fn tcp_stream_read(stream: &TcpStream, out: &byte, out_max: usize, timeout_ms: u32) !usize;
export fn tcp_stream_write(stream: &TcpStream, src: &const byte, src_len: usize, timeout_ms: u32) !usize;
export fn tcp_stream_write_all(stream: &TcpStream, src: &const byte, src_len: usize, timeout_ms: u32) !void;
export @async_fn fn tcp_connect_async(addr: &SocketAddr, timeout_ms: u32) Future<!TcpStream>;
export @async_fn fn tcp_connect_ipv4_async(ip: &IpAddr, port: u16, timeout_ms: u32) Future<!TcpStream>;
export @async_fn fn tcp_stream_read_async(stream: &TcpStream, out: &byte, out_max: usize, timeout_ms: u32) Future<!usize>;
export @async_fn fn tcp_stream_write_async(stream: &TcpStream, src: &const byte, src_len: usize, timeout_ms: u32) Future<!usize>;
export @async_fn fn tcp_stream_write_all_async(stream: &TcpStream, src: &const byte, src_len: usize, timeout_ms: u32) Future<!void>;
export fn tcp_stream_shutdown(stream: &TcpStream) void;
export fn tcp_stream_close(stream: &TcpStream) void;
export fn tcp_stream_take_fd(stream: &TcpStream) !i32;
export fn tcp_stream_drop(stream: TcpStream) void;
```

约束：

```text
- [ ] HTTP client 主链路必须调用 `tcp_*_async`；同步 `tcp_connect` / read / write wrapper 只能作为 blocking compatibility 或 smoke test 辅助。
- [ ] 同步 wrapper 不能复制维护另一套 socket 状态机；应复用 async transport leaf 或共享的底层非阻塞 helper。
```

---

## 3. 阶段 B：DNS resolver 收敛

现状：`lib/std/net/dns.uya` 已有较多实现。这里不重写，也不隐式改公开结构体字段；先用 TDD 把标准库 DNS 行为钉牢，再清理 API。若后续要把 DNS 地址迁移到 `std.net.addr` 的 `IpFamily` / `IpAddr` 风格，必须单独列 API 迁移任务和兼容测试。

目标文件：

```text
lib/std/net/dns.uya
lib/std/net/resolver.uya
tests/test_std_dns.uya
tests/test_std_dns_packet.uya
tests/test_std_dns_hosts.uya
tests/test_std_dns_loopback.uya
```

先写/补强测试：

```text
- [ ] test_dns_encode_query_example_com_a
- [ ] test_dns_decode_a_answer_fixture
- [ ] test_dns_decode_cname_then_a_fixture
- [ ] test_dns_rejects_compression_loop
- [ ] test_dns_rejects_name_too_long
- [ ] test_dns_hosts_parses_comments_and_aliases
- [ ] test_dns_resolv_conf_parses_multiple_nameservers
- [ ] test_dns_nameserver_fallback_after_timeout
- [ ] test_dns_udp_loopback_mock
- [ ] test_dns_timeout_is_bounded
- [ ] test_dns_a_only_v01_contract
- [ ] test_dns_public_struct_fields_match_current_api
```

已存在公开契约：

```uya
export const DNS_PREFER_ANY: u8;
export const DNS_PREFER_IPV4: u8;
export const DNS_PREFER_IPV6: u8;

export struct DnsAddress {
    family: i32,
    addr_len: usize,
    addr: [byte: 16],
    port: u16,
}

export struct DnsClient {
    nameserver: [byte: 16],
    nameserver_len: usize,
    nameserver_port: u16,
    timeout_ms: u32,
    query_id: u16,
    prefer_family: u8,
}

export fn dns_client_init(ctx: &DnsClient, resolver: &[byte]) void;
export fn dns_client_set_timeout_ms(ctx: &DnsClient, timeout_ms: u32) void;
export fn dns_client_get_timeout_ms(ctx: &DnsClient) u32;
export fn dns_client_set_prefer_family(ctx: &DnsClient, prefer: u8) void;
export fn dns_client_get_prefer_family(ctx: &DnsClient) u8;
export fn dns_client_query_a(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) !usize;
export fn dns_client_query_a_with_ttl(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize, ttl_out: &usize) !usize;
export fn dns_client_query_aaaa(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) !usize;
export fn dns_client_query_aaaa_with_ttl(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize, ttl_out: &usize) !usize;
export fn dns_client_resolve_host(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) !usize;
export fn dns_client_resolve_first_ipv4(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) !usize;
export fn dns_client_resolve_first_ipv6(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) !usize;
export fn dns_client_lookup_localhost(ctx: &DnsClient, out: &byte, out_max: usize, out_len: &usize) !usize;
export fn dns_client_query_all(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) !usize;
export fn dns_client_query_a_with_tcp_fallback_packets(udp_packet: &const byte, udp_len: usize, tcp_packet: &const byte, tcp_len: usize, out: &byte, out_max: usize, out_len: &usize, ttl_out: &usize) !usize;
```

已存在异步公开契约：

```uya
export fn dns_client_query_a_udp_future(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) Future<!usize>;
export fn dns_client_query_aaaa_udp_future(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) Future<!usize>;
export fn dns_client_query_a_tcp_future(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) Future<!usize>;
export fn dns_client_query_aaaa_tcp_future(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) Future<!usize>;
export fn dns_client_query_tcp_async(ctx: &DnsClient, host: &const byte, host_len: usize, qtype: u16, out: &byte, out_max: usize, out_len: &usize) Future<!usize>;
export fn dns_client_query_a_async(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) Future<!usize>;
export fn dns_client_query_aaaa_async(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) Future<!usize>;
export fn dns_client_query_all_async(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) Future<!usize>;
export @async_fn fn dns_client_lookup_localhost_async(ctx: &DnsClient, out: &byte, out_max: usize, out_len: &usize) Future<!usize>;
export fn dns_client_resolve_first_ipv6_async(ctx: &DnsClient, host: &const byte, host_len: usize, out: &byte, out_max: usize, out_len: &usize) Future<!usize>;
```

新增 API 只允许放在兼容层之后，并且必须先写 `test_dns_public_struct_fields_match_current_api` 一类回归，证明没有重复定义或误改上述稳定签名。

内部函数需要有测试覆盖：

```uya
fn dns_encode_name(out: &byte, pos: usize, host: &[byte]) !usize;
fn dns_read_name(cur: &DnsCursor, out: &byte, out_max: usize, out_len: &usize) !usize;
fn dns_parse_resolv_conf_first_nameserver() !DnsAddress;
fn dns_parse_hosts_first_ipv4(host: &[byte]) !DnsAddress;
fn dns_query_follow_cname_with_ttl(ctx: &DnsClient, host: &[byte], depth: usize, qtype: u16, out: &byte, out_max: usize, out_len: &usize, ttl_out: &usize) !usize;
```

初始范围约束：

```text
- [ ] 初始 HTTPS client 路径只要求 A 记录可用。
- [ ] AAAA / Happy Eyeballs 留在后续，不作为初始 HTTPS client 验收 gate；但已有 AAAA / IPv6 查询 API 和测试不得回归。
- [ ] CNAME limited chain 必须支持，因为公网域名常见 CNAME。
```

---

## 4. 阶段 C：TLS client 与 X.509

现状：`lib/tls/` 已有 TLS 基础、record、handshake、x509、https bridge。这里的目标是收敛成标准库可复用的 TLS client API。

### C1. TLS client API

目标文件：

```text
lib/tls/client.uya
tests/test_tls_client_loopback.uya
tests/test_tls_client_realnet.uya
```

先写测试：

```text
- [ ] test_tls_client_config_default_is_secure
- [ ] test_tls_client_loopback_handshake
- [ ] test_tls_client_sni_is_sent
- [ ] test_tls_client_rejects_bad_finished
- [ ] test_tls_client_timeout
- [ ] test_tls_client_close_notify
- [ ] test_tls_client_connect_async_loopback
- [ ] test_tls_stream_async_read_write
- [ ] test_tls_client_realnet_gated_public_hosts
```

函数定义：

```uya
export enum TlsClientVerifyMode {
    VerifyPeer,
    InsecureSkipVerify,
}

export struct TlsClientConfig {
    server_name: &[byte],
    verify_mode: TlsClientVerifyMode,
    ca_bundle_path: &[byte],
    allocator: IAllocator,
    min_version: u16,
    max_version: u16,
    handshake_timeout_ms: u32,
    read_timeout_ms: u32,
    write_timeout_ms: u32,
}

export struct TlsInfo {
    version: u16,
    cipher_suite: u16,
    server_name: [byte: 256],
    server_name_len: usize,
    verified: bool,
    reused_session: bool,
}

export enum TlsRuntimeVersion {
    Tls12,
    Tls13,
}

export struct TlsClientState {
    hs12: HandshakeCtx,
    hs13: Handshake13Ctx,
    rec: RecordCtx,
    ctx12: SslContext,
    ctx13: SslContext13,
}

export struct TlsStream {
    tcp: TcpStream,
    active_version: TlsRuntimeVersion,
    state: &TlsClientState,
    allocator: IAllocator,
    info: TlsInfo,
    closed: bool,
}

export fn tls_client_config_default(server_name: &[byte]) TlsClientConfig;
export fn tls_client_config_insecure_for_test(server_name: &[byte]) TlsClientConfig;
export fn tls_client_connect(tcp: TcpStream, cfg: &TlsClientConfig) !TlsStream;
export fn tls_stream_read(stream: &TlsStream, out: &byte, out_max: usize, timeout_ms: u32) !usize;
export fn tls_stream_write(stream: &TlsStream, src: &const byte, src_len: usize, timeout_ms: u32) !usize;
export fn tls_stream_write_all(stream: &TlsStream, src: &const byte, src_len: usize, timeout_ms: u32) !void;
export @async_fn fn tls_client_connect_async(tcp: TcpStream, cfg: &TlsClientConfig) Future<!TlsStream>;
export @async_fn fn tls_stream_read_async(stream: &TlsStream, out: &byte, out_max: usize, timeout_ms: u32) Future<!usize>;
export @async_fn fn tls_stream_write_async(stream: &TlsStream, src: &const byte, src_len: usize, timeout_ms: u32) Future<!usize>;
export @async_fn fn tls_stream_write_all_async(stream: &TlsStream, src: &const byte, src_len: usize, timeout_ms: u32) Future<!void>;
export fn tls_stream_close_notify(stream: &TlsStream) void;
export fn tls_stream_close(stream: &TlsStream) void;
export fn tls_stream_info(stream: &TlsStream) TlsInfo;
```

约束：

```text
- [ ] `TlsStream.state` 必须由 `TlsStream` 拥有，不能引用 `tls_client_connect` 内部局部变量。
- [ ] `tls_client_config_default` 必须使用 `std.mem.allocator.get_allocator()` 或等价默认 allocator；显式配置中的 `allocator` 不得为空。
- [ ] `SslContext` / `SslContext13` 中的 `hs`、`hs13`、`rec` 指针必须指向同一个 `TlsClientState` 内的稳定存储。
- [ ] `TlsInfo.server_name` 必须复制自 config/server_name，而不是保存调用方传入切片。
- [ ] `tls_stream_close` 必须关闭底层 TCP、发送 best-effort close_notify，并释放 `TlsClientState`；重复 close 必须 no-op。
- [ ] HTTP client 主链路必须调用 `tls_*_async`；同步 TLS wrapper 只能作为 blocking compatibility 或 smoke test 辅助。
- [ ] 同步 wrapper 不能复制维护另一套 handshake/read/write 状态机；应复用 async transport leaf 或共享的底层状态推进 helper。
- [ ] 若初始只落地 TLS 1.2，`max_version` / `min_version` 必须显式拒绝 TLS 1.3，不能把 1.3 配置静默降级到 1.2。
```

### C2. X.509 parser, trust store, hostname verify

目标文件：

```text
lib/tls/x509/cert.uya
lib/tls/x509/verify.uya
lib/tls/x509/trust_store.uya
lib/tls/x509/hostname.uya
tests/test_tls_x509.uya
tests/test_tls_hostname.uya
tests/test_tls_store.uya
```

先写测试：

```text
- [ ] test_x509_parse_leaf_der_fixture
- [ ] test_x509_parse_pem_bundle
- [ ] test_x509_validity_not_before_after
- [ ] test_x509_san_dns_preferred_over_cn
- [ ] test_x509_wildcard_one_label_only
- [ ] test_x509_wildcard_rejects_public_suffix_shape
- [ ] test_x509_unknown_ca_fails_closed
- [ ] test_x509_incomplete_chain_fails_closed
- [ ] test_x509_eku_server_auth_required
- [ ] test_x509_basic_constraints_ca_required_for_issuer
```

函数定义（`TrustStore` 使用 `lib/tls/x509/trust_store.uya` 已导出的现有类型）：

```uya
export struct X509Name {
    common_name: &[byte],
}

export struct X509SanList {
    dns_names: [X509SanDnsName: 32],
    dns_len: usize,
}

export struct X509Cert {
    subject: X509Name,
    issuer: X509Name,
    san: X509SanList,
    not_before_unix: i64,
    not_after_unix: i64,
    is_ca: bool,
    key_usage: u32,
    ext_key_usage: u32,
    raw_der: &[byte],
}

export struct X509Chain {
    certs: [X509Cert: 8],
    len: usize,
}

export fn x509_cert_parse_der(input: &const byte, input_len: usize, out: &X509Cert) !void;
export fn x509_cert_parse_pem(input: &const byte, input_len: usize, out: &X509Cert) !void;
export fn x509_chain_parse_der_list(input: &const byte, input_len: usize, out: &X509Chain) !void;
export fn x509_pem_bundle_parse(input: &const byte, input_len: usize, out: &TrustStore) !usize;
export fn x509_trust_store_init(store: &TrustStore) void;
export fn x509_trust_store_load_default(store: &TrustStore) !usize;
export fn x509_verify_chain(chain: &X509Chain, store: &TrustStore, now_unix: i64) !void;
export fn x509_verify_hostname(cert: &X509Cert, host: &[byte]) !void;
export fn x509_hostname_match_dns_name(pattern: &[byte], host: &[byte]) bool;
export fn x509_cert_has_server_auth(cert: &X509Cert) bool;
export fn x509_cert_is_valid_at(cert: &X509Cert, now_unix: i64) bool;
```

约束：

```text
- [ ] 仓库已有 `lib/tls/x509/trust_store.uya` 导出的 `TrustStore`，当前布局为 `certs: [Cert: TRUST_STORE_MAX_CERTS]`、`der_storage`、`count`。
- [ ] 本阶段不得另起一个不兼容的同名公开类型；应迁移现有 `TrustStore` 到这里需要的语义，或新增 adapter/helper 函数把现有 `TrustStore` 接到 `x509_verify_chain`。
- [ ] 若 `X509Cert` 与现有 `Cert` 需要同时存在，必须先定义单向 adapter 或迁移计划；不得在 TODO 示例中重新声明 `TrustStore`。
```

验收：

```text
- [ ] 默认 verify peer。
- [ ] 证书错误 fail closed。
- [ ] insecure config 只能在测试或显式 opt-in 使用。
```

---

## 5. 阶段 D：HTTP client 数据模型与 parser

### D1. URL parser

目标文件：

```text
lib/std/http/client/url.uya
tests/test_http_client_url.uya
```

先写测试：

```text
- [ ] test_url_parse_https_default_port
- [ ] test_url_parse_explicit_port
- [ ] test_url_parse_query_preserved
- [ ] test_url_parse_default_path
- [ ] test_url_rejects_empty_host
- [ ] test_url_rejects_unsupported_scheme
- [ ] test_url_ipv6_literal_is_explicitly_unsupported_or_parsed
```

函数定义：

```uya
export enum HttpScheme {
    Http,
    Https,
}

export struct HttpUrl {
    scheme: HttpScheme,
    host: &[byte],
    port: u16,
    path: &[byte],
    query: &[byte],
}

export fn http_url_parse(input: &[byte]) !HttpUrl;
export fn http_url_default_port(scheme: HttpScheme) u16;
export fn http_url_path_and_query(url: &HttpUrl, out: &byte, out_max: usize, out_len: &usize) !usize;
export fn http_url_is_default_port(url: &HttpUrl) bool;
```

### D2. Header map

目标文件：

```text
lib/std/http/client/header.uya
tests/test_http_client_header.uya
```

先写测试：

```text
- [ ] test_header_get_case_insensitive
- [ ] test_header_set_replaces_existing
- [ ] test_header_add_allows_multi_value_except_content_length
- [ ] test_header_rejects_crlf_in_name
- [ ] test_header_rejects_crlf_in_value
- [ ] test_header_total_size_limit
- [ ] test_duplicate_content_length_rejected
- [ ] test_transfer_encoding_content_length_conflict_rejected
```

函数定义：

```uya
export const HTTP_MAX_HEADERS: usize;
export const HTTP_MAX_HEADER_BYTES: usize;

export struct HttpHeader {
    name: &[byte],
    value: &[byte],
}

export struct HeaderMap {
    items: [HttpHeader: HTTP_MAX_HEADERS],
    len: usize,
    total_bytes: usize,
}

export fn header_map_init(map: &HeaderMap) void;
export fn header_map_len(map: &HeaderMap) usize;
export fn header_map_get(map: &HeaderMap, name: &[byte]) !&[byte];
export fn header_map_has(map: &HeaderMap, name: &[byte]) bool;
export fn header_map_set(map: &HeaderMap, name: &[byte], value: &[byte]) !void;
export fn header_map_add(map: &HeaderMap, name: &[byte], value: &[byte]) !void;
export fn header_map_remove(map: &HeaderMap, name: &[byte]) void;
export fn header_name_valid(name: &[byte]) bool;
export fn header_value_valid(value: &[byte]) bool;
export fn header_name_eq_ignore_case(a: &[byte], b: &[byte]) bool;
export fn header_map_validate_total_size(map: &HeaderMap, max_bytes: usize) !void;
export fn header_map_validate_message_framing(map: &HeaderMap) !void;
```

约束：

```text
- [ ] `HeaderMap` 只拥有 header slot，不拥有 name/value 字节；调用方必须保证切片背后的 storage 生命周期覆盖 map 使用期。
- [ ] `HTTP_MAX_HEADER_BYTES` 只能作为默认值；HTTP client 必须使用 `ClientConfig.max_response_header_bytes` 调用 `header_map_validate_total_size`，不能硬写全局上限。
```

### D3. Request encoder

目标文件：

```text
lib/std/http/client/cancel.uya
lib/std/http/client/request.uya
tests/test_http_client_request_encode.uya
```

先写测试：

```text
- [ ] test_request_encode_get_no_body
- [ ] test_request_encode_post_content_length
- [ ] test_request_encode_host_added
- [ ] test_request_encode_host_with_non_default_port
- [ ] test_request_encode_query_preserved
- [ ] test_request_encode_user_agent_default
- [ ] test_request_encode_rejects_invalid_header
```

函数定义：

```uya
export enum HttpMethod {
    GET,
    POST,
    PUT,
    PATCH,
    DELETE,
    HEAD,
}

export enum BodyKind {
    Empty,
    Bytes,
}

export struct HttpBody {
    kind: BodyKind,
    bytes: &[byte],
}

export struct CancelToken {
    cancelled: atomic i32,
}

export struct HttpRequest {
    method: HttpMethod,
    url: HttpUrl,
    headers: HeaderMap,
    body: HttpBody,
    timeout_ms: u32,
    cancel_token: &CancelToken,
}

export fn cancel_token_init(token: &CancelToken) void;
export fn cancel_token_cancel(token: &CancelToken) void;
export fn cancel_token_is_cancelled(token: &CancelToken) bool;
export fn cancel_token_never() &CancelToken;
export fn http_body_empty() HttpBody;
export fn http_body_bytes(bytes: &[byte]) HttpBody;
export fn http_request_init(req: &HttpRequest, method: HttpMethod, url: HttpUrl) void;
export fn http_request_set_body(req: &HttpRequest, body: HttpBody) void;
export fn http_request_header_capacity(req: &HttpRequest) usize;
export fn http_request_encode_headers(req: &HttpRequest, out: &byte, out_max: usize, out_len: &usize) !usize;
```

约束：

```text
- [ ] `CancelToken` 与 `cancel_token_*` helper 放在 `cancel.uya`；`request.uya` 只引用它们。
- [ ] `cancelled` 使用 `0/1` 表示 false/true；Uya 当前只允许整数原子类型，不能使用 `atomic bool`。`cancel_token_is_cancelled` 对外仍返回 `bool`。
- [ ] 初始请求体只支持 `Empty` 与 `Bytes`。后续若增加 streaming upload，必须先定义 `HttpBodyReader` / async 读接口，再新增 `BodyKind.Reader`，不得留下无 payload 的 enum 分支。
```

### D4. Response parser

目标文件：

```text
lib/std/http/client/response.uya
tests/test_http_client_response_parse.uya
```

先写测试：

```text
- [ ] test_response_parse_status_line
- [ ] test_response_parse_content_length
- [ ] test_response_parse_404_body
- [ ] test_response_parse_head_no_body
- [ ] test_response_parse_204_no_body
- [ ] test_response_rejects_bad_status_code
- [ ] test_response_header_too_large
- [ ] test_response_body_too_large
```

函数定义：

```uya
export enum ResponseBodyMode {
    NoBody,
    ContentLength,
    Chunked,
    UntilClose,
}

export struct HttpResponseMeta {
    status: i32,
    reason: &[byte],
    headers: HeaderMap,
    body_mode: ResponseBodyMode,
    content_length: usize,
    keep_alive: bool,
}

export struct HttpResponse {
    status: i32,
    reason: &[byte],
    headers: HeaderMap,
    header_storage: &byte,
    header_len: usize,
    header_capacity: usize,
    header_owned: bool,
    header_allocator: &IAllocator,
    body: &[byte],
    body_storage: &byte,
    body_len: usize,
    body_capacity: usize,
    body_owned: bool,
    body_allocator: &IAllocator,
    complete: bool,
    reused_conn: bool,
    remote_addr: SocketAddr,
    tls_info: TlsInfo,
}

export fn http_response_parse_status_line(line: &[byte], status_out: &i32, reason_out: &&[byte]) !void;
export fn http_response_parse_headers(buf: &[byte], out: &HttpResponseMeta, consumed: &usize) !void;
export fn http_response_body_mode(method: HttpMethod, status: i32, headers: &HeaderMap) !ResponseBodyMode;
export fn http_response_should_keep_alive(headers: &HeaderMap) bool;
export fn http_response_free(resp: &HttpResponse) void;
```

约束：

```text
- [ ] `body` 只是视图；当 `body_owned == true` 时，`http_response_free` 必须通过 `body_allocator.dealloc(body_storage)` 释放底层存储。
- [ ] `headers` 与 `reason` 只是视图；当 response 跨出 parser/read 函数返回给调用者时，必须指向 `header_storage` 中的稳定副本。
- [ ] 当 `header_owned == true` 时，`http_response_free` 必须通过 `header_allocator.dealloc(header_storage)` 释放底层存储。
- [ ] `header_allocator` / `body_allocator` 使用 `std.mem.allocator.IAllocator`；当对应 `*_owned == false` 时允许为空，`http_response_free` 必须 no-op。
- [ ] `header_storage`、`header_capacity`、`header_owned`、`body_storage`、`body_capacity`、`body_owned` 必须在所有成功和错误路径初始化，避免泄漏、悬垂切片或误释放。
- [ ] `complete == true` 只表示响应头和按 `body_mode` 要求的 body 都已完整读取；连接池复用必须同时检查 `complete` 与 keep-alive。
```

---

## 6. 阶段 E：chunked、SSE、streaming

### E1. Chunked decoder

目标文件：

```text
lib/std/http/client/chunked.uya
tests/test_http_client_chunked.uya
```

先写测试：

```text
- [ ] test_chunked_decode_wikipedia_fixture
- [ ] test_chunked_ignores_extension
- [ ] test_chunked_rejects_bad_size
- [ ] test_chunked_rejects_missing_crlf
- [ ] test_chunked_enforces_single_chunk_limit
- [ ] test_chunked_enforces_total_limit
- [ ] test_chunked_skips_or_parses_trailers
```

函数定义：

```uya
export enum ChunkedState {
    ReadChunkSizeLine,
    ReadChunkData,
    ReadChunkCrlf,
    ReadTrailers,
    Done,
    Error,
}

export struct ChunkedDecoder {
    state: ChunkedState,
    current_chunk_size: usize,
    current_chunk_read: usize,
    total_read: usize,
    max_chunk_size: usize,
    max_total_size: usize,
}

export fn chunked_decoder_init(dec: &ChunkedDecoder, max_chunk_size: usize, max_total_size: usize) void;
export fn chunked_parse_size_line(line: &[byte]) !usize;
export fn chunked_decoder_feed(dec: &ChunkedDecoder, input: &[byte], out: &byte, out_max: usize, out_len: &usize, consumed: &usize) !void;
export fn chunked_decoder_is_done(dec: &ChunkedDecoder) bool;
export fn chunked_decoder_finish(dec: &ChunkedDecoder) !void;
```

### E2. SSE parser

目标文件：

```text
lib/std/http/sse.uya
tests/test_http_sse.uya
```

先写测试：

```text
- [ ] test_sse_single_data_event
- [ ] test_sse_multiline_data_joins_with_newline
- [ ] test_sse_comment_ignored
- [ ] test_sse_event_name
- [ ] test_sse_id_and_retry_preserved
- [ ] test_sse_split_across_tcp_chunks
- [ ] test_sse_done_is_data_not_protocol_magic
- [ ] test_sse_finish_flushes_partial_line_correctly
```

函数定义：

```uya
export struct SseEvent {
    event_name: &[byte],
    data: &[byte],
    id: &[byte],
    retry_ms: i32,
}

export interface SseSink {
    fn on_sse(self: &Self, ev: &SseEvent) !void;
}

export struct SseParser {
    line_buf: [byte: 8192],
    line_len: usize,
    event_name_buf: [byte: 128],
    event_name_len: usize,
    data_buf: [byte: 65536],
    data_len: usize,
    id_buf: [byte: 256],
    id_len: usize,
    retry_ms: i32,
}

export fn sse_parser_init(parser: &SseParser) void;
export fn sse_parser_feed(parser: &SseParser, chunk: &[byte], sink: &SseSink) !void;
export fn sse_parser_finish(parser: &SseParser, sink: &SseSink) !void;
export fn sse_parser_reset_event(parser: &SseParser) void;
export fn sse_parse_line(parser: &SseParser, line: &[byte], sink: &SseSink) !void;
export fn sse_emit_event(parser: &SseParser, sink: &SseSink) !void;
```

初始范围约束：

```text
- [ ] raw pass-through 不等待完整 SSE event。
- [ ] parsed mode 只能旁路统计，不能阻塞转发。
- [ ] [DONE] 只作为普通 data 内容，不写死任何上层协议语义。
```

---

## 7. 阶段 F：HTTP client、pool、metrics

执行顺序约束：F2/F3 的公开签名已经依赖 `ClientMetrics`，因此实现时需先落地 F5 的 `ClientMetrics` / `ClientTiming` 类型与 init helper，再编译 request/stream API。

### F1. Transport abstraction

目标文件：

```text
lib/std/http/client/client.uya
tests/test_http_client_loopback.uya
```

函数定义：

```uya
export union TransportInner {
    PlainTcp: TcpStream,
    Tls: TlsStream,
}

export struct TransportStream {
    inner: TransportInner,
    closed: bool,
}

export fn transport_read(t: &TransportStream, out: &byte, out_max: usize, timeout_ms: u32) !usize;
export fn transport_write_all(t: &TransportStream, src: &const byte, src_len: usize, timeout_ms: u32) !void;
export fn transport_close(t: &TransportStream) void;
export fn transport_is_tls(t: &TransportStream) bool;

export @async_fn fn transport_read_async(t: &TransportStream, out: &byte, out_max: usize, timeout_ms: u32) Future<!usize>;
export @async_fn fn transport_write_all_async(t: &TransportStream, src: &const byte, src_len: usize, timeout_ms: u32) Future<!void>;
```

约束：

```text
- [ ] `TransportStream` 只能拥有一个底层 stream：PlainTcp 分支拥有 `TcpStream`，Tls 分支拥有 `TlsStream`，不得同时按值保存 `TcpStream` 和 `TlsStream`。
- [ ] `transport_read` / `transport_write_all` / `transport_close` 必须 match `inner` 只操作有效分支，并设置 `closed` 防止 double close。
- [ ] `TlsStream` 已拥有握手后的 `TcpStream`；TLS transport 不得再复制保存同一个 fd。
```

### F2. Client config and non-stream request

目标文件：

```text
lib/std/http/client/client.uya
tests/test_http_client_loopback.uya
tests/test_https_client_loopback.uya
```

先写测试：

```text
- [ ] test_http_client_get_loopback_content_length
- [ ] test_http_client_post_loopback_content_length
- [ ] test_http_client_reads_error_status_body
- [ ] test_http_client_tls_loopback_verify_ok
- [ ] test_http_client_tls_loopback_verify_fail
- [ ] test_http_client_first_byte_timeout
- [ ] test_http_client_total_timeout
- [ ] test_http_client_cancel_before_connect
- [ ] test_http_client_cancel_during_read
- [ ] test_http_client_request_async_awaits_dns_connect_tls
- [ ] test_http_client_request_blocking_wraps_async_path
```

函数定义：

```uya
export struct ClientConfig {
    allocator: IAllocator,
    connect_timeout_ms: u32,
    tls_timeout_ms: u32,
    write_timeout_ms: u32,
    read_timeout_ms: u32,
    first_byte_timeout_ms: u32,
    total_timeout_ms: u32,
    max_response_header_bytes: usize,
    max_response_body_bytes: usize,
    max_chunk_size: usize,
    keep_alive: bool,
    max_idle_conns: usize,
    max_idle_per_host: usize,
    idle_timeout_ms: u32,
    verify_tls: bool,
    ca_bundle_path: &[byte],
    server_name_override: &[byte],
    user_agent: &[byte],
}

export struct Client {
    config: ClientConfig,
    pool: ConnPool,
}

export fn client_config_default() ClientConfig;
export fn client_init(client: &Client, config: &ClientConfig) void;
export fn client_close_idle(client: &Client) void;
export fn client_server_name_for_url(client: &Client, url: &HttpUrl) &[byte];

export @async_fn fn client_request_async(client: &Client, req: &HttpRequest, out: &HttpResponse, metrics: &ClientMetrics) Future<!void>;
export @async_fn fn client_resolve_host_async(client: &Client, url: &HttpUrl, out: &byte, out_max: usize, out_len: &usize) Future<!usize>;
export @async_fn fn client_connect_transport_async(client: &Client, url: &HttpUrl, cancel: &CancelToken, out: &TransportStream) Future<!void>;
export @async_fn fn client_write_request_async(client: &Client, stream: &TransportStream, req: &HttpRequest) Future<!void>;
export @async_fn fn client_read_response_headers_async(client: &Client, stream: &TransportStream, req: &HttpRequest, meta: &HttpResponseMeta) Future<!void>;
export @async_fn fn client_read_response_body_async(client: &Client, stream: &TransportStream, req: &HttpRequest, meta: &HttpResponseMeta, out: &HttpResponse) Future<!void>;
export fn client_release_transport(client: &Client, key: &ConnKey, stream: &TransportStream, reusable: bool) void;

export fn client_request_blocking(client: &Client, req: &HttpRequest, out: &HttpResponse, metrics: &ClientMetrics) !void;
```

实现形态：

```uya
export @async_fn fn client_request_async(client: &Client, req: &HttpRequest, out: &HttpResponse, metrics: &ClientMetrics) Future<!void> {
    client_metrics_init(metrics);
    var error_stage: ClientErrorKind = ClientErrorKind.Protocol;
    errdefer {
        if metrics.error_kind == ClientErrorKind.None {
            client_metrics_mark_error(metrics, error_stage);
        }
        client_metrics_mark_done(metrics, client_metrics_now_ms_or_zero());
    }

    var key: ConnKey = undefined;
    const server_name: &[byte] = client_server_name_for_url(client, &req.url);
    try conn_key_init(&key, req.url.scheme, req.url.host, req.url.port, server_name);

    var transport: TransportStream = undefined;
    error_stage = ClientErrorKind.Connect;
    try @await client_connect_transport_async(client, &req.url, req.cancel_token, &transport);
    var reusable: bool = false;
    defer { client_release_transport(client, &key, &transport, reusable); }

    error_stage = ClientErrorKind.Protocol;
    try @await client_write_request_async(client, &transport, req);

    var meta: HttpResponseMeta = undefined;
    try @await client_read_response_headers_async(client, &transport, req, &meta);
    try @await client_read_response_body_async(client, &transport, req, &meta, out);

    metrics.reused_conn = out.reused_conn;
    const status_kind: ClientErrorKind = client_error_kind_from_status(meta.status);
    if status_kind != ClientErrorKind.None {
        client_metrics_mark_error(metrics, status_kind);
    }
    reusable = out.complete && meta.keep_alive && client.config.keep_alive;
    client_metrics_mark_done(metrics, client_metrics_now_ms_or_zero());
}
```

约束：

```text
- [ ] `client_request_async` 不得用无条件 `defer transport_close` 结束请求。
- [ ] `client_config_default` 必须使用 `std.mem.allocator.get_allocator()` 或等价默认 allocator；显式配置中的 `allocator` 不得为空。
- [ ] 连接成功后应使用 `defer client_release_transport(..., reusable)`；`reusable` 默认 false，只在完整读取且 keep-alive 后置 true。
- [ ] `client_server_name_for_url` 必须优先返回非空 `client.config.server_name_override`，否则返回 `url.host`。
- [ ] response 完整读取且 `meta.keep_alive && client.config.keep_alive` 时，连接必须归还 pool；否则必须 close。
- [ ] `conn_key_init` 失败必须填充 `metrics.error_kind`，并且不得触碰未初始化的 transport。
- [ ] DNS/connect/TLS/write/read/status 错误路径必须填充 `metrics.error_kind`；实现可以在 helper 内写入更精确分类，或返回可被 `client_error_kind_from_error_id` 稳定映射的错误 ID。
- [ ] 已经获得 transport 的路径必须关闭或标记连接不可复用。
```

### F3. Streaming request

目标文件：

```text
lib/std/http/client/client.uya
tests/test_http_client_stream_loopback.uya
tests/test_http_client_cancel.uya
```

先写测试：

```text
- [ ] test_stream_headers_event_before_data
- [ ] test_stream_raw_data_pass_through
- [ ] test_stream_sse_parsed_events
- [ ] test_stream_downstream_cancel_closes_upstream
- [ ] test_stream_first_packet_marks_retry_boundary
- [ ] test_stream_error_after_first_packet_returns_stream_error
- [ ] test_stream_async_awaits_raw_sink_write
- [ ] test_stream_blocking_helper_wraps_async_path
```

函数定义：

```uya
export enum StreamEventKind {
    Headers,
    Data,
    SseEvent,
    Done,
    Error,
}

export struct StreamEvent {
    kind: StreamEventKind,
    status: i32,
    headers: HeaderMap,
    data: &[byte],
    sse: SseEvent,
}

export interface StreamSink {
    @async_fn fn on_event_async(self: &Self, ev: &StreamEvent) Future<!void>;
    fn is_cancelled(self: &Self) bool;
}

export @async_fn fn client_stream_async(client: &Client, req: &HttpRequest, sink: &StreamSink, metrics: &ClientMetrics) Future<!void>;
export @async_fn fn client_stream_raw_async(client: &Client, req: &HttpRequest, sink: &StreamSink, metrics: &ClientMetrics) Future<!void>;
export @async_fn fn client_stream_sse_async(client: &Client, req: &HttpRequest, sink: &StreamSink, metrics: &ClientMetrics) Future<!void>;

export fn client_stream_blocking(client: &Client, req: &HttpRequest, sink: &StreamSink, metrics: &ClientMetrics) !void;
```

约束：

```text
- [ ] client_stream_raw_async 每收到一段 body bytes 就 @await sink.on_event_async(Data)，不能等完整 SSE event。
- [ ] client_stream_sse_async 可以旁路解析 SSE，但 raw 转发优先。
- [ ] blocking helper 只能调用 async 主路径，不能复制一套读写循环。
- [ ] stream 完成、取消、协议错误和 sink 错误都必须写回 `metrics`，供上层调用者统一处理延迟与错误分类。
```

### F4. Connection pool

目标文件：

```text
lib/std/http/client/pool.uya
tests/test_http_client_pool.uya
```

先写测试：

```text
- [ ] test_pool_reuses_second_request_same_host
- [ ] test_pool_does_not_reuse_different_host
- [ ] test_pool_does_not_reuse_connection_close
- [ ] test_pool_does_not_reuse_unread_body
- [ ] test_pool_idle_timeout_closes
- [ ] test_pool_tls_error_closes
```

函数定义：

```uya
export struct ConnKey {
    scheme: HttpScheme,
    host: [byte: 256],
    host_len: usize,
    port: u16,
    server_name: [byte: 256],
    server_name_len: usize,
}

export struct PooledConn {
    key: ConnKey,
    stream: TransportStream,
    last_used_ms: u64,
    in_use: bool,
    reusable: bool,
}

export struct ConnPool {
    conns: Vec<PooledConn>,
    max_idle_conns: usize,
    max_idle_per_host: usize,
    idle_timeout_ms: u32,
}

export fn conn_key_eq(a: &ConnKey, b: &ConnKey) bool;
export fn conn_pool_init(pool: &ConnPool, allocator: IAllocator, max_idle_conns: usize, max_idle_per_host: usize, idle_timeout_ms: u32) void;
export fn conn_pool_deinit(pool: &ConnPool) void;
export fn conn_pool_get(pool: &ConnPool, key: &ConnKey, now_ms: u64, out: &TransportStream) !bool;
export fn conn_pool_put(pool: &ConnPool, key: &ConnKey, stream: &TransportStream, now_ms: u64, reusable: bool) void;
export fn conn_pool_close_idle(pool: &ConnPool, now_ms: u64) void;
export fn conn_pool_close_all(pool: &ConnPool) void;
export fn conn_pool_mark_unusable(conn: &PooledConn) void;
export fn conn_key_init(key: &ConnKey, scheme: HttpScheme, host: &[byte], port: u16, server_name: &[byte]) !void;
```

约束：

```text
- [ ] `ConnKey` 长期保存在 pool 中，必须拥有 host/server_name 副本；不得保存来自 URL parser 或临时 buffer 的切片。
- [ ] `conn_key_init` 负责长度检查、复制和清零终止；host/server_name 超过容量时返回错误。
- [ ] `conn_pool_put` / `conn_pool_get` 表示所有权转移：放入 pool 后 caller 的 `TransportStream` 必须标记为 closed/empty，取出后 pool slot 不再关闭同一 fd。
- [ ] `ConnPool` 的物理存储必须随 `max_idle_conns` 增长或收缩，不得把 `[PooledConn: 64]` 一类固定数组作为产品容量上限。
- [ ] `conn_pool_put` 如果因分配失败或超过策略上限无法保存连接，必须关闭传入 stream 并把 caller stream 标记为 closed/empty，不能泄漏 fd。
```

### F5. Metrics and error classification

目标文件：

```text
lib/std/http/client/metrics.uya
tests/test_http_client_errors.uya
```

先写测试：

```text
- [ ] test_metrics_init_error_kind_none
- [ ] test_metrics_mark_done_uses_explicit_time
- [ ] test_error_kind_success_status_none
- [ ] test_error_kind_dns
- [ ] test_error_kind_connect
- [ ] test_error_kind_tls
- [ ] test_error_kind_timeout_first_byte
- [ ] test_error_kind_status_429
- [ ] test_error_kind_status_5xx
- [ ] test_error_kind_status_401_not_retryable
```

函数定义：

```uya
export enum ClientErrorKind {
    None,
    Dns,
    Connect,
    Tls,
    Timeout,
    Cancelled,
    Protocol,
    Status4xx,
    Status5xx,
    RateLimited,
    BodyTooLarge,
    Unknown,
}

export struct ClientTiming {
    start_ms: u64,
    dns_done_ms: u64,
    connect_done_ms: u64,
    tls_done_ms: u64,
    first_byte_ms: u64,
    done_ms: u64,
}

export struct ClientMetrics {
    reused_conn: bool,
    bytes_written: usize,
    bytes_read: usize,
    timing: ClientTiming,
    error_kind: ClientErrorKind,
}

export fn client_error_kind_from_status(status: i32) ClientErrorKind;
export fn client_error_kind_from_error_id(err_id: u32, default_kind: ClientErrorKind) ClientErrorKind;
export fn client_error_is_retryable(kind: ClientErrorKind, stream_started: bool) bool;
export fn client_timing_init(t: &ClientTiming, now_ms: u64) void;
export fn client_metrics_now_ms_or_zero() u64;
export fn client_metrics_init(m: &ClientMetrics) void;
export fn client_metrics_mark_error(m: &ClientMetrics, kind: ClientErrorKind) void;
export fn client_metrics_mark_done(m: &ClientMetrics, now_ms: u64) void;
```

约束：

```text
- [ ] `client_metrics_init` 必须把 `error_kind` 初始化为 `ClientErrorKind.None`。
- [ ] `client_error_kind_from_status` 对 2xx/3xx 返回 `ClientErrorKind.None`，对 429 返回 `RateLimited`，对其他 4xx/5xx 返回对应分类。
- [ ] `client_metrics_mark_error` 只写错误分类；完成时间必须由 `client_metrics_mark_done(metrics, now_ms)` 显式写入。
- [ ] 成功、取消、协议错误、状态错误和 transport 错误路径都必须调用 `client_metrics_mark_done`；成功路径不得把 `None` 改成 `Unknown`。
- [ ] `client_error_is_retryable(ClientErrorKind.None, ...)` 必须返回 false。
```

---

## 8. 阶段 G：realnet gate 与标准库验收

目标文件：

```text
tests/test_http_client_realnet.uya
tests/test_tls_client_realnet.uya
tests/verify_http_client_realnet.sh
```

先写测试：

```text
- [ ] test_realnet_example_com_headers
- [ ] test_realnet_iana_org_headers
- [ ] test_realnet_cloudflare_headers
- [ ] test_realnet_public_https_headers
- [ ] test_realnet_skip_without_UYA_NET_TEST
```

函数定义：

```uya
fn realnet_enabled() bool;
fn realnet_head_or_get(host: &[byte], path: &[byte]) !i32;
fn realnet_assert_https_header(host: &[byte]) !void;
```

验收：

```bash
# 示例执行前先设置 UYA_ROOT=/path/to/uya，或在当前仓库根目录中 export UYA_ROOT="$PWD"。
cd "$UYA_ROOT"
UYA_NET_TEST=1 ./tests/verify_http_client_realnet.sh
```

必须证明：

```text
- [ ] DNS resolve
- [ ] TCP connect timeout
- [ ] TLS handshake + SNI
- [ ] certificate verify + hostname verify
- [ ] HTTP request write
- [ ] HTTP response header read
- [ ] no libcurl/OpenSSL/mbedTLS/c-ares runtime dependency
```

---

## 9. 完成定义

标准库完成：

```text
- [ ] 所有可复用网络/TLS/HTTP/SSE 代码位于 Uya 仓库。
- [ ] 每个 public function 有至少一个正向测试或被端到端测试覆盖。
- [ ] 每个 parser 有 malformed 输入测试。
- [ ] request 与 stream 均支持 cancel_token。
- [ ] first_byte_timeout_ms 与 tls_timeout_ms 有独立测试。
- [ ] TLS 默认 verify peer，证书错误 fail closed。
- [ ] realnet gate 可验证公网 HTTPS 域名的 TLS + HTTP header read。
- [ ] make check 通过。
- [ ] 相关测试通过 --c99 与 --uya --c99。
```
