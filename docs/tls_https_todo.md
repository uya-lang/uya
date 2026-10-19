# TLS/HTTPS 落地 TODO

> **核对头（2026-10-19）**：阶段 1–5 的条目已按 `lib/tls/`（28 个 `.uya`）与 `tests/test_tls_*.uya` / `tests/test_https_*.uya` / `tests/test_raw_tls.uya` 复核，勾选状态与代码一致。本次修正：把 11 处指向旧绝对路径 `/media/winger/_dde_home/winger/uya/...` 的链接改为仓库相对路径；并补充「仍未清理项」的具体位置（`lib/tls/crypto/chacha20_poly1305.uya` 占位、`lib/tls/crypto/x25519.uya:7` 残留的 `extern fn x25519_ref_impl` 声明与 `:2` 的过期注释）。
> 2026-04 → 2026-10 新增能力：TLS 1.2 **会话复用**（`9bb39dee`，`lib/tls/ssl/handshake.uya` 会话 ID 缓存 + ClientHello 携带 + 服务端白名单认同；测试 `tests/test_tls_session_resumption.uya`），未在本文件的阶段清单里，见 `docs/tls_todo.md` §4.6。

本文档聚焦一个具体问题：**把当前 `lib/tls/` 这套纯 Uya TLS 零件，补成可以真正支撑 HTTPS 的实现**。

当前仓库已经具备很多基础能力，包括：

- 哈希、HMAC、HKDF、AES、GCM、RSA、X25519
- X.509 证书解析、链验证、主机名匹配
- TLS 记录层、握手骨架、SslContext 封装
- 若干 TLS/DTLS 单元测试

但要真正支持 HTTPS，仍然缺少：

- 可互操作的 TLS 1.2/1.3 握手
- 真正的 AEAD 记录层加密
- 证书链验证与握手流程的联动
- SNI / hostname 绑定
- 最小 HTTP 客户端或服务器

这个 TODO 以“能安全发起一次 HTTPS 连接并收发 HTTP 报文”为终点。

---

## 目标

1. 支持最小可用的 HTTPS 客户端。
2. 支持最小可用的 HTTPS 服务器。
3. 保持纯 Uya 实现为主，必要时允许参考实现或临时桥接。
4. 所有 TLS 相关新增测试都应通过 `make b`。

---

## 当前状态

| 子系统 | 状态 | 备注 |
|------|------|------|
| 密码学基础 | 已有 | SHA/HMAC/HKDF/AES/GCM/RSA/X25519 等已具备 |
| X.509 解析 | 已有 | 证书解析、链验证、hostname 匹配已实现 |
| TLS 记录层 | 部分完成 | TLS 1.2/1.3 已走 AEAD 记录流，TLS 1.2 现已与 `openssl`/`curl` 完成最小本地互操作，仍缺更完整互操作与分片覆盖 |
| TLS 1.2 握手 | 部分完成 | 已能和真实 `openssl s_client` / `curl` 完成本地 TLS 1.2 最小握手与应用数据往返；仍缺更完整消息覆盖与外站互操作 |
| TLS 1.3 握手 | 部分完成 | 1-RTT、Finished、application traffic secret 已接通，仍缺更完整互操作 |
| SNI / hostname 绑定 | 已完成 | `ssl_set_hostname`、hostname 校验与 ClientHello SNI 已接通 |
| HTTP 层 | 部分完成 | 已有最小 `https_get`、本地 HTTPS loopback、可被 `curl` 访问的本地 HTTPS server，以及 `https_server_serve_uyagin_once` 形式的 TLS -> UyaGin 最小桥接 |

---

## 阶段 1: 把 TLS 1.2/1.3 握手补成“真的能用”

### 1.1 TLS 1.2 最小互操作握手

- [x] 在 [lib/tls/ssl/handshake.uya](./lib/tls/ssl/handshake.uya) 中补齐真实消息流。
- [x] 支持 `ClientHello -> ServerHello -> Certificate -> ServerKeyExchange -> ServerHelloDone -> ClientKeyExchange -> ChangeCipherSpec -> Finished` 的最小子集。
- [x] 客户端和服务端都能推进到 `DONE`，并在状态机里记录已协商参数。
- [x] 至少支持一个可测试的密码套件组合，例如 RSA + AES-GCM 或 ECDHE + AES-GCM。

### 1.2 TLS 1.3 最小互操作握手

- [x] 在 [lib/tls/ssl/handshake13.uya](./lib/tls/ssl/handshake13.uya) 中补齐真正的 1-RTT 流程。
- [x] 完成 key schedule：early secret、handshake secret、master secret。
- [x] 补齐 Finished 验证。
- [x] 将 `handshake13_client_start` / `handshake13_server_step` 从占位消息改成规范化消息编码。

### 1.3 会话状态

- [x] 给 [lib/tls/ssl/context.uya](./lib/tls/ssl/context.uya) 增加协商结果字段。
- [x] 记录协议版本、密码套件、握手完成状态、应用数据是否可读写。
- [x] 让 `ssl_is_handshake_done` 与记录层状态一致。

### 验收

- [x] `tests/test_tls_handshake.uya` 覆盖真实握手路径。
- [x] 新增一个最小的互操作测试，验证 client/server 能互相完成协商。

---

## 阶段 2: 把记录层改成真正的加密记录层

### 2.1 TLS 1.2 记录加密

- [x] 在 [lib/tls/ssl/record.uya](./lib/tls/ssl/record.uya) 中加入 AEAD 或 CBC 模式的真实加密实现。
- [x] 明确每条记录的 nonce / explicit IV / tag 生成方式。
- [x] `record_encrypt` 和 `record_decrypt` 能处理长度检查、认证失败；当前最小实现未覆盖大报文分片。

### 2.2 TLS 1.3 记录加密

- [x] 使用握手派生出的 traffic secret 生成应用数据 key。
- [x] 支持 `TLS_AES_128_GCM_SHA256` 作为最小可用套件。
- [x] 记录层支持 sequence number 与 nonce 拼接。

### 2.3 错误映射

- [x] 将认证失败、解密失败、长度错误映射到 TLS 错误码。
- [x] 区分 `TlsDecodeError`、`TlsInvalidMac`、`TlsHandshakeFailure`。

### 验收

- [x] `tests/test_tls_record.uya` 变成真正的加密往返测试。
- [x] 至少有一个固定向量测试，确保加密结果稳定。

---

## 阶段 3: 证书链、主机名和 SNI 打通

### 3.1 证书验证接入握手

- [x] 在握手完成联动中调用 [lib/tls/x509/verify.uya](./lib/tls/x509/verify.uya)。
- [x] 将服务器证书链、信任锚、用途校验和主机名校验串起来。
- [x] 证书校验失败时会阻止握手进入可读写状态。

### 3.2 主机名

- [x] 为 [lib/tls/ssl/context.uya](./lib/tls/ssl/context.uya) 的 `ssl_set_hostname` 填充真实实现。
- [x] 主机名参与客户端握手参数，并在 client 侧握手完成时进入 hostname 校验。
- [x] 支持精确匹配和单层 wildcard。

### 3.3 SNI

- [x] 在 ClientHello 里加入 SNI 扩展。
- [x] 服务端上下文应能基于 SNI 选择证书或虚拟主机配置。

### 验收

- [x] 新增测试：主机名匹配成功、失败、wildcard 命中、wildcard 拒绝。
- [x] 新增测试：证书链不可信时握手失败。

---

## 阶段 4: 最小 HTTPS 客户端

### 4.1 连接层封装

- [x] 封装一个最小 socket/TCP 连接模块，负责 connect/read/write/close。
- [x] 为 TLS 上下文提供最小阻塞式流 I/O 适配层。
- [x] 明确阻塞和非阻塞行为的错误映射。

### 4.2 HTTPS client

- [x] 实现最小 `https_get(host, port, path)`。
- [x] 连接成功后输出状态码、响应头、响应体。
- [x] 支持 GET 即可，不要求复杂 chunked 编码以外的高级特性。

### 4.3 证书存储

- [x] 增加最小 CA/信任锚装载方式。
- [x] 允许从内置 DER 数组或文件读取信任锚。

### 验收

- [x] 能对一个真实 HTTPS 站点完成握手并读取响应头（当前通过 `curl` 桥接验证）。
- [x] 至少有一个本地 TLS 测试服务器与客户端的回环测试。

---

## 阶段 5: 最小 HTTPS 服务器

### 5.1 监听与 accept

- [x] 封装最小 TCP listener。
- [x] 能 accept 一个连接并进入 TLS server 模式。

### 5.2 服务器证书

- [x] 支持加载服务器证书和私钥。
- [x] 支持 RSA 或 ECDSA 至少一种服务端身份。

### 5.3 HTTP 响应

- [x] 实现最小 HTTP/1.1 `200 OK` 响应。
- [x] 支持固定页面或简单动态响应。
- [x] 支持将 TLS 握手后的最小 HTTP 请求桥接到 `std.http.uyagin.Engine`，用于复用现有异步框架 handler。

### 验收

- [x] `curl https://127.0.0.1:<port>/` 能返回预期内容。
- [x] 客户端和服务器都能跑在仓库的测试环境里。

---

## 阶段 6: 稳定性与兼容性

- [x] 补全更多 RFC 向量测试。
- [x] 覆盖 TLS 1.2 和 TLS 1.3 的失败路径。
- [x] 检查大文件、长证书链、坏 tag、坏长度、坏序列号。
- [x] 检查 `make b`、`--c99`、`--uya --c99` 全部通过。
- [ ] 清理所有临时占位实现和只为测试引入的兼容分支。
  - 2026-10-19 复核后仍存在的具体残留：
    - `lib/tls/crypto/chacha20_poly1305.uya`：仍是占位（`encrypt`/`decrypt` 恒返回非 0，不做 ChaCha20/Poly1305 运算），文件头 `:1`、`:33`、`:57` 均有标注
    - `lib/tls/crypto/x25519.uya:7`：`extern fn x25519_ref_impl(...)` 声明**已无任何调用点**（`x25519()` 走 `x25519_pure_mpi_impl`，`x25519.uya:363`），提供它的 `x25519_ref.c` 已删除；`:2` 的「默认通过 x25519_ref_impl（OpenSSL）提供参考实现」注释也已过期
    - `lib/tls/ssl/dtls_handshake.uya`：只有最小往返，未实现重传/超时/HelloVerifyRequest cookie

### 6.1 收回 EC/X25519 参考桥

- [x] 将 `lib/tls/crypto/ec_ref.c` 的能力逐步迁回纯 Uya 实现。（2026-10-19 核对：该 `.c` 文件已不存在，`ls lib/tls/crypto/*.c` 无匹配）
- [x] 优先完成 P-256 ECDH 的纯 Uya 稳定实现，并补独立回归测试。
- [x] 优先完成 P-256 公钥生成的纯 Uya 稳定实现，并以 [tests/test_tls_ecdsa.uya](./tests/test_tls_ecdsa.uya) / [tests/test_tls_rsa.uya](./tests/test_tls_rsa.uya) 已知向量回归覆盖。
- [x] 补齐 P-384 公钥生成与 ECDH 的纯 Uya 路径，并补独立回归测试。
- [x] 再补齐 P-384 的签名/验签纯 Uya 路径，最后移除 `ec_ref.c` 的测试链接依赖。
- [x] **移除 X25519 OpenSSL 参考实现** `lib/tls/crypto/x25519_ref.c`，纯 Uya 实现已通过 RFC 7748 全部向量。（2026-10-19 核对：`.c` 已不存在，`x25519()` 走 `x25519_pure_mpi_impl`；但 `x25519.uya:7` 的 `extern fn x25519_ref_impl` 声明与 `:2` 的注释仍是残留，见阶段 6 清理项）

---

## 推荐实现顺序

1. 先把 TLS 1.2 或 TLS 1.3 其中一条握手链打通。
2. 再把记录层从明文改成真实加密。
3. 接上证书链、hostname 和 SNI。
4. 最后再做 HTTP client / server。

如果目标是“尽快跑出一个 HTTPS demo”，建议优先做：

1. TLS 1.3 最小互操作握手
2. AES-GCM 记录层
3. SNI + 证书链验证
4. 最小 HTTP client

---

## 参考文档

- [docs/tls_uya_design.md](./tls_uya_design.md)
- [docs/tls_todo.md](./tls_todo.md)
- [docs/tls_uya_plan.md](./tls_uya_plan.md)
