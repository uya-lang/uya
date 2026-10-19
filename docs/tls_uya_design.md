# TLS 纯 Uya 实现详细设计文档

> **核对头（2026-10-19）**：本文是设计与接口约定；实现现状请对照 [tls_todo.md](tls_todo.md)（已按代码复核）。已按 `lib/tls/` 的实际文件清单修正 §2.2 目录树（补 `https.uya`、`crypto/ec_p256.uya`、`crypto/ec_p384.uya`、`x509/store.uya`、`x509/trust_store.uya`），并在 §4.3、§6.5 标注「仍是占位」与「已落地」的差别。

本文档描述在 Uya 中从零实现与 mbedTLS 功能对等的 TLS/DTLS 库的架构、模块接口、数据流与实现约束。与 [tls_todo.md](tls_todo.md) 配合使用：设计文档定「做什么、长什么样」，待办文档定「按什么顺序做、做到什么算完成」。

---

## 1. 目标与约束

### 1.1 目标

- 在 Uya 中实现一套 **纯 Uya** 的 TLS/DTLS 库，无 C 库依赖（除通过 FFI 使用系统熵源如 `/dev/urandom`）。
- 功能对等 mbedTLS 的常用子集：TLS 1.2/1.3 客户端与服务端、常用密码套件、X.509 证书解析与链验证；可选 DTLS 1.2。
- 库根目录：`lib/tls/`；测试位于 `tests/` 根目录，命名 `test_tls_*.uya`；开发在独立分支（如 `feature/tls-pure-uya`）进行。

### 1.2 约束

- **内存**：无 GC，调用方提供缓冲区或库内使用固定大小栈数组/Arena；禁止隐式堆分配。
- **错误**：统一使用 Uya 错误联合类型 `!T`，错误码在 `lib/tls/common.uya` 中集中定义并与 mbedTLS 错误码可映射。
- **线程**：首版单线程；若后续多线程，需明确与 Uya 并发安全（Send/Sync）的配合方式。
- **侧信道**：大数比较、条件分支等关键路径需常量时间实现，在接口与实现中标注。

---

## 2. 总体架构

### 2.1 层次与依赖

```
应用层         TLS Client/Server（调用方）
    |
SSL/TLS 层     记录层（加解密/分片）、握手状态机
    |
X.509 层       证书解析（DER/ASN.1）、链验证
    |
密码学层       哈希、HMAC/HKDF、AES-GCM、RSA/ECDSA/X25519
    |
基础层         大数（MPI）、熵、DRBG
```

- 实现顺序：**基础层 → 密码学层 → X.509 层 → SSL/TLS 层**。
- 上层仅依赖下层公开接口，不跨层调用。

### 2.2 目录与模块

```
lib/tls/
├── common.uya          # 错误码、常量、公共类型
├── https.uya           # 面向 HTTPS 的封装：https_get / https_server_* / https_*_async（2026-10-19 补录，
│                       #   原设计稿未列；46450 字节 / 1262 行）
├── base/
│   ├── mpi.uya         # 多精度整数
│   ├── entropy.uya     # 熵源（如 /dev/urandom）
│   └── drbg.uya        # 确定性随机数（HMAC-DRBG，SP 800-90A）
├── crypto/
│   ├── sha256.uya      # SHA-256
│   ├── sha384.uya      # SHA-384
│   ├── hmac.uya        # HMAC-SHA256/384
│   ├── hkdf.uya        # HKDF（RFC 5869）
│   ├── aes.uya         # AES-128/256 ECB/CBC
│   ├── gcm.uya         # AES-GCM AEAD
│   ├── chacha20_poly1305.uya  # ⚠️ 仍是占位实现（恒返回非 0，无实际 AEAD 运算）
│   ├── rsa.uya         # RSA 签名/验签、加密/解密
│   ├── ec.uya          # ECDH/ECDSA 通用入口
│   ├── ec_p256.uya     # P-256 有限域/标量/点运算（Fe256、Sc256）
│   ├── ec_p384.uya     # P-384（原设计稿只写"ec.uya"，实际拆出独立文件）
│   └── x25519.uya      # X25519 密钥交换
├── x509/
│   ├── asn1.uya        # DER 解析（最小子集）
│   ├── cert.uya        # X.509 证书解析
│   ├── verify.uya      # 证书链验证、主机名验证
│   ├── store.uya       # 证书存储（原设计稿未列）
│   └── trust_store.uya # 信任锚列表（原设计稿未列）
└── ssl/
    ├── record.uya      # TLS 记录层
    ├── handshake.uya   # TLS 1.2 握手 + 会话 ID 缓存/复用
    ├── handshake13.uya # TLS 1.3 握手（HKDF 密钥调度）
    ├── context.uya     # 配置、会话、收发抽象
    ├── dtls_record.uya # DTLS 记录（仅最小实现）
    └── dtls_handshake.uya # DTLS 握手（最小实现，无重传/超时/cookie）
```

- 模块路径：当前约定 **`UYA_ROOT=lib/`**（与 `tests/run_programs_parallel.sh` 一致），故 `lib/tls/common.uya` 对应 `use tls.common`，`lib/tls/base/mpi.uya` 对应 `use tls.base.mpi`；目录下每文件为一子模块（与现有 `std.io`、`std.mem` 解析方式一致）。
- 测试：`tests/test_tls_mpi.uya`、`tests/test_tls_sha256.uya`、…、`tests/test_tls_handshake.uya`，均位于 **`tests/` 根目录**（与 `run_programs_parallel.sh` 默认 `find tests/ -maxdepth 1 -name "*.uya"` 收集范围一致），需通过 `--c99` 与 `--uya --c99`。

---

## 3. 基础层设计

### 3.1 公共类型与错误（common.uya）

- **错误码**：使用 Uya 的 `error` 定义，例如：
  - `error.TlsBadInput`、`error.TlsInvalidMac`、`error.TlsDecodeError`、`error.TlsNoMemory`、`error.TlsCryptoFailure` 等；
  - 与 mbedTLS 的 `MBEDTLS_ERR_SSL_*`、`MBEDTLS_ERR_X509_*` 可建立映射表（文档或注释）。
- **常量**：TLS 版本号（0x0303 = 1.2, 0x0304 = 1.3）、记录类型（handshake, alert, application_data）、密码套件 ID 等，以 `const` 或 `enum` 定义。
- **依赖**：仅依赖 Uya 内置类型与 `std.mem`（若可用），不依赖其他 `lib/tls` 模块。

### 3.2 大数（base/mpi.uya）

- **用途**：RSA、ECDSA、DH 等所需的多精度整数运算。
- **数据结构**：
  - `struct Mpi`：内部为 limb 数组（如 `[u64]` 或固定最大 limb 数），符号位、有效 limb 数；
  - 不暴露内部布局，提供 init/clear（或 drop）、from_bytes_be/from_bytes_le、to_bytes_be/to_bytes_le（调用方提供 `&byte` 缓冲区）。
- **运算**：add、sub、mul、div、mod、exp_mod、compare（返回 -1/0/1）；比较需常量时间（用于密钥材料时）。
- **接口示例**（示意）：
  - `fn init(self: &Mpi) void`
  - `fn from_bytes_be(self: &Mpi, data: &const byte, len: usize) !void`
  - `fn to_bytes_be(self: &const Mpi, out: &byte, out_len: usize) !usize`
  - `fn exp_mod(self: &Mpi, result: &Mpi, exp: &const Mpi, mod: &const Mpi) !void`
- **参考**：mbedTLS `bignum.c`/`bignum.h`；首版可不做汇编优化。

### 3.3 熵（base/entropy.uya）

- **用途**：为 DRBG 提供种子。
- **接口**：`fn fill_entropy(buf: &byte, len: usize) !void`；实现通过 `std.syscall` 或 FFI 读 `/dev/urandom`（Linux）或等价系统接口。
- **平台**：首版可仅实现 Linux；其他平台返回 `error.TlsPlatformUnsupported` 或后续扩展。

### 3.4 确定性随机数（base/drbg.uya）

- **实现阶段**：DRBG 依赖 AES（CTR-DRBG）或 HMAC（HMAC-DRBG），因此 **在阶段 2 实现**（在 AES 与 HMAC 之后）；阶段 1 仅交付 MPI 与 entropy。
- **算法**：CTR-DRBG（NIST SP 800-90A）或 HMAC-DRBG；若采用 HMAC-DRBG，则本模块依赖 `tls.crypto.hmac`。
- **状态**：`struct DrbgCtx` 含内部状态（key、counter 等），不暴露。
- **接口**：
  - `fn init(ctx: &DrbgCtx, entropy: &const byte, entropy_len: usize, nonce: &const byte, nonce_len: usize) !void`
  - `fn fill_random(ctx: &DrbgCtx, buf: &byte, len: usize) !void`
  - `fn reseed(ctx: &DrbgCtx, entropy: &const byte, entropy_len: usize) !void`
- **测试**：固定 seed + nonce，验证输出与已知向量一致。

---

## 4. 密码学层设计

### 4.1 哈希（crypto/sha256.uya, sha384.uya）

- **接口**：一次性：`fn sha256(data: &const byte, len: usize, out: &byte) void`（out 至少 32 字节）；或带状态：`struct Sha256`，`fn update(self: &Sha256, data: &const byte, len: usize) void`，`fn finish(self: &Sha256, out: &byte) void`。
- **输出**：SHA-256 32 字节，SHA-384 48 字节；大端。
- **测试**：NIST 或 RFC 测试向量。

### 4.2 HMAC 与 HKDF（crypto/hmac.uya, hkdf.uya）

- **HMAC**：`fn hmac_sha256(key: &const byte, key_len: usize, msg: &const byte, msg_len: usize, out: &byte) void`；同理 HMAC-SHA384。
- **HKDF**：`fn hkdf_extract(hash_id: ..., salt: &const byte, salt_len: usize, ikm: &const byte, ikm_len: usize, prk_out: &byte) void`；`fn hkdf_expand(...) !void`；按 RFC 5869。
- **用途**：TLS PRF、密钥推导、DRBG（若用 HMAC-DRBG）。

### 4.3 对称加密（crypto/aes.uya, gcm.uya）

- **AES**：块加密 128/256 位密钥；ECB/CBC 模式（用于兼容或早期）；接口 `fn aes_encrypt_block(...)`、`fn aes_cbc_encrypt(...)` 等，调用方提供 key/iv 缓冲区。
- **AES-GCM**：AEAD；接口 `fn aes_gcm_encrypt(key: &const byte, key_len: usize, nonce: &const byte, nonce_len: usize, aad: &const byte, aad_len: usize, plain: &const byte, plain_len: usize, cipher_out: &byte, tag_out: &byte) !void`；解密同理，验 tag 失败返回错误。
- **ChaCha20-Poly1305**（可选）：同上，接口风格一致，nonce 12 字节，tag 16 字节。
  - **实现状态（2026-10-19）**：`lib/tls/crypto/chacha20_poly1305.uya` **只是占位**——文件头写明「占位实现」，`encrypt`/`decrypt` 恒返回非 0，不做 ChaCha20 流加密与 Poly1305 MAC。RFC 8439 向量与真实实现仍待补；TLS 侧因此不能协商 `TLS_CHACHA20_POLY1305_SHA256`。
- **测试**：NIST GCM 向量、RFC 7539 向量。

### 4.4 公钥（crypto/rsa.uya, ec.uya, x25519.uya）

- **RSA**：密钥表示（n, e, d 等）由 Mpi 组成；`fn rsa_verify_pkcs1_v15(...) !void`、`fn rsa_sign_pkcs1_v15(...) !void`；加密/解密按 TLS 需要选 RSAES-OAEP 或 PKCS#1 v1.5；密钥解析可从字节或后续从 X.509 取得。
- **EC**：P-256/P-384 的 ECDH 与 ECDSA；点乘、标量乘法等基于 Mpi；接口 `fn ecdh_compute_shared(...) !void`、`fn ecdsa_verify(...) !void`、`fn ecdsa_sign(...) !void`。
- **X25519**：标量乘 32 字节；`fn x25519(out: &byte, scalar: &const byte, point: &const byte) !void`；TLS 1.3 常用。
- **侧信道**：大数比较、分支在密钥材料路径上使用常量时间实现。

---

## 5. X.509 层设计

### 5.1 ASN.1/DER（x509/asn1.uya）

- **范围**：仅解析 TLS/X.509 所需：INTEGER、OID、BIT STRING、OCTET STRING、SEQUENCE、EXPLICIT tag、UTCTime/GeneralizedTime。
- **接口**：游标式或一次性：给定 `&const byte` 与长度，返回解析出的类型与长度、子片；或提供 `struct Asn1Reader` 逐步读 TLV。
- **不实现**：BER、INDEFINITE length、复杂扩展解析可后期按需加。

### 5.2 证书解析（x509/cert.uya）

- **结构**：证书表示为结构体：版本、序列号、签名算法 OID、颁发者/主体 DN、有效期（notBefore/notAfter）、公钥（RSA 或 EC 参数）、扩展（SAN、keyUsage 等可选）。
- **接口**：`fn cert_parse(der: &const byte, der_len: usize, cert_out: &Cert) !void`；`Cert` 持有必要字段及原始 TBSCertificate 用于验签。
- **依赖**：asn1、crypto（用于解析公钥及后续验签）。

### 5.3 证书验证（x509/verify.uya）

- **链验证**：从叶证书到根；每步验证签名（RSA/ECDSA）、有效期、基本约束、用途；根由调用方提供（信任锚列表）。
- **主机名**：与 TLS 客户端设定的 hostname 比较，支持 SAN dNSName、IP 及 CN 回退（按 RFC 6125 简化）。
- **接口**：`fn verify_chain(certs: &[Cert], hostname: &const byte, hostname_len: usize, trust_anchors: &[Cert]) !void` 或类似；证书链与信任锚由调用方以 **切片 `&[Cert]` 或固定长度 `&[Cert: N]`** 提供，在栈上分配，满足无堆约束。

---

## 6. SSL/TLS 层设计

### 6.1 记录层（ssl/record.uya）

- **输入/输出**：明文/密文缓冲区均由调用方提供；记录头 5 字节（类型、版本、长度），TLS 1.2/1.3 密文格式不同（1.3 为 AEAD，含 nonce + ciphertext + tag）。
- **状态**：每条连接维护写/读序列号、当前密钥（由握手层设置）；加密/解密时按密码套件调用 crypto 层（AES-GCM 或 ChaCha20-Poly1305）。
- **接口**：`fn record_encrypt(ctx: &RecordCtx, type: u8, plain: &const byte, plain_len: usize, cipher_out: &byte, out_len: &usize) !void`；`fn record_decrypt(...) !void`；内部处理分片（> 2^14 分多记录）。

### 6.2 握手（ssl/handshake.uya, handshake13.uya）

- **与传输解耦**：收发字节通过接口或回调，例如：
  - `fn send(ctx: &void, buf: &const byte, len: usize) !void`
  - `fn recv(ctx: &void, buf: &byte, max_len: usize) !usize`
  由调用方绑定到 socket 或内存 mock。
- **TLS 1.2**：客户端：ClientHello → ServerHello、Certificate、ServerKeyExchange（可选）、ServerHelloDone → ClientKeyExchange、ChangeCipherSpec、Finished → ChangeCipherSpec、Finished；服务端对称。密钥计算使用 PRF（基于 HMAC），密钥块写入 RecordCtx。
- **TLS 1.3**：1-RTT：ClientHello（key_share 等）→ ServerHello、EncryptedExtensions、Certificate、CertificateVerify、Finished；密钥 schedule 用 HKDF；可单独 `handshake13.uya` 或与 1.2 共用状态机分支。
- **状态机**：显式状态枚举（ClientHelloSent、ServerHelloReceived、…），按当前状态与收到消息类型迁移；非法消息返回错误。

### 6.3 上下文（ssl/context.uya）

- **SslContext**：持有配置（支持的版本、密码套件、证书/私钥或回调）、RecordCtx、握手状态、收发回调及 opaque 指针。
- **接口**：`fn init(ctx: &SslContext, config: &const SslConfig) void`；`fn set_hostname(ctx: &SslContext, name: &const byte, len: usize) void`（客户端）；`fn handshake(ctx: &SslContext) !void`；`fn read(ctx: &SslContext, buf: &byte, max_len: usize) !usize`；`fn write(ctx: &SslContext, buf: &const byte, len: usize) !void`；`fn close_notify(...) void`。
- **配置**：端点类型（client/server）、TLS 版本、密码套件列表、证书验证模式（required/optional/none）、证书链与私钥（服务端）等。

### 6.4 DTLS（可选）

- **记录**：在 TLS 记录前增加 DTLS 头（序号、epoch、fragment 等）；`dtls_record.uya` 封装/解析该头并调用现有 record 加解密。
- **握手**：重传、超时、HelloVerifyRequest cookie；状态机扩展；可与 TLS 握手共用大部分逻辑，仅消息边界与重传不同。
- **实现状态（2026-10-19）**：`dtls_record.uya` 已有 13 字节头封装/解析（单条明文 payload）；`dtls_handshake.uya` 只有 ClientHello/ServerHello → Done 的最小往返，**未实现重传、超时与 HelloVerifyRequest cookie**。测试 `tests/test_tls_dtls.uya`。

### 6.5 会话复用（TLS 1.2，2026-10-19 补录，已落地）

`lib/tls/ssl/handshake.uya` 实现了基于会话 ID 的 TLS 1.2 会话复用（提交 `9bb39dee`）：

- **缓存**：`TlsSessionCache` 为进程内单例、有界缓存，常量 `TLS_SESSION_CACHE_MAX = 8`（条）、`TLS_SESSION_ID_LEN = 32`（字节）、host 上限 `TLS_SESSION_HOST_MAX = 128`（`handshake.uya:59-80`）。条目保存 host、会话 ID、`master_secret`（`HS_MASTER_SECRET_LEN`）与密码套件。
- **接口**：`tls_session_cache_store(host, session_id, id_len, master, suite) bool`（`:174`）、`tls_session_cache_lookup(...)`（`:221`）、`tls_session_cache_stats()`（`:160`）、`tls_session_cache_clear()`（`:167`）。
- **客户端**：`handshake_set_resume_session_id(ctx, id, len) !void`（`:360`）让 ClientHello 携带上次的会话 ID；`handshake_session_resumed(&ctx) bool`（`:377`）查询是否命中。
- **服务端**：回显同一会话 ID 即表示接受复用，此时**跳过密钥协商**、直接沿用缓存中的 `master_secret`（`:276` 注释与实现）。
- **上层入口**：`lib/tls/https.uya` 暴露对应封装（`9bb39dee` 新增 37 行）。
- **测试**：`tests/test_tls_session_resumption.uya`（437 行）。

---

## 7. 数据流与调用关系

- **握手阶段**：应用调用 `handshake()` → 握手层通过 send/recv 收发消息 → 解析后更新状态、计算密钥 → 写入 RecordCtx → 继续直到 Finished 校验通过。
- **应用数据**：应用调用 `read()`/`write()` → context 调用 record_decrypt/record_encrypt → 通过 send/recv 与对端交换密文。
- **证书验证**：握手层在收到 Certificate 后调用 x509 cert_parse + verify_chain（及 hostname）；verify 内部使用 crypto 层验签。

---

## 8. 测试策略

- **单元**：每个模块对应 `tests/test_tls_<module>.uya`，使用 NIST/RFC/mbedTLS 已知向量；通过 `tests/run_programs_parallel.sh --c99` 与 `--uya --c99`。
- **集成**：`tests/test_tls_handshake.uya` 用内存 buffer 模拟两端收发，完成 TLS 1.2 握手并交换一条应用数据，验证解密后明文一致。
- **互操作**（可选）：与 OpenSSL 或 mbedTLS 对端跑简单客户端/服务端，需 `std.net` 或临时 FFI socket。

---

## 9. 参考

- [uya.md](uya.md) — 类型、错误、模块、FFI。
- [tls_todo.md](tls_todo.md) — 分阶段待办与验收标准。
- mbedTLS：`library/`、`include/mbedtls/`；实现时以 **mbedTLS 3.x/4.x** 及以下 RFC 为参考，若与最新 mbedTLS 行为有差异，在文档或代码注释中说明。
- RFC 5246（TLS 1.2）、RFC 8446（TLS 1.3）、RFC 6347（DTLS 1.2）、RFC 5280（X.509）、RFC 5869（HKDF）。
