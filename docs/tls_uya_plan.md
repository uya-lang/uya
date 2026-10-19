# TLS 纯 Uya 实现 — 计划索引

> **核对头（2026-10-19）**：`lib/tls/` 实际有 28 个 `.uya` 文件（含设计稿未列的 `https.uya`、`crypto/ec_p256.uya`、`crypto/ec_p384.uya`、`x509/store.uya`、`x509/trust_store.uya`）；下方「与 mbedTLS 的对应关系」已补 `https.uya` 一行。测试侧现有 `tests/test_tls_*.uya` 19 个 + `tests/test_raw_tls.uya` + `tests/test_https_*.uya` 8 个。各阶段实际完成状态以 [tls_todo.md](tls_todo.md) 的复核结果为准。

本页为 mbedTLS 风格 TLS/DTLS 库的**纯 Uya 实现**在 Uya 仓库中的计划与文档入口。

---

## 文档

- **[tls_uya_design.md](tls_uya_design.md)** — 详细设计：架构、目录与模块、各层接口与数据结构、数据流、测试策略。
- **[tls_todo.md](tls_todo.md)** — 待办清单：阶段 0～4 的任务项、验收标准、里程碑与依赖。
- **[tls_https_todo.md](tls_https_todo.md)** — 面向 HTTPS 落地的待办清单：从 TLS 握手到最小 HTTP client/server。

---

## 约定

- **库根目录**：`lib/tls/`（方案 A）。**模块路径**：当前约定 `UYA_ROOT=lib/`，故 `lib/tls/common.uya` → `use tls.common`，`lib/tls/base/mpi.uya` → `use tls.base.mpi`（与现有 std 解析一致）。
- **测试位置**：`tests/` 根目录，文件命名 `test_tls_*.uya`（与 `run_programs_parallel.sh` 默认 `find tests/ -maxdepth 1 -name "*.uya"` 一致）。
- **分支**：开发在分支 `feature/tls-pure-uya` 进行。
- **验证**：所有 `test_tls_*.uya` 需通过 `--c99` 与 `--uya --c99`（见 [.cursorrules](../.cursorrules)、[todo_mini_to_full.md](todo_mini_to_full.md)）。

---

## 与 mbedTLS 的对应关系

| 本库模块 | mbedTLS 对应 |
|----------|----------------|
| lib/tls/base/mpi.uya | library/bignum.c |
| lib/tls/base/entropy.uya, drbg.uya | library/entropy.c, ctr_drbg.c |
| lib/tls/crypto/sha256.uya 等 | library/sha256.c |
| lib/tls/crypto/hmac.uya, hkdf.uya | library/hmac_drbg 相关、自实现 HKDF |
| lib/tls/crypto/aes.uya, gcm.uya | library/aes.c, gcm.c |
| lib/tls/crypto/rsa.uya, ec.uya, x25519.uya | library/rsa.c, ecp.c, 等 |
| lib/tls/x509/asn1.uya, cert.uya, verify.uya | library/x509.c, x509_crt.c |
| lib/tls/ssl/record.uya, handshake.uya, context.uya | library/ssl_tls.c, ssl_msg.c, 等 |
| lib/tls/https.uya（`https_get` / `https_server_*` / 异步入口，原设计稿未列） | 无直接对应（mbedTLS 之上的示例/封装层） |

API 风格可与 mbedTLS 的 `mbedtls_*` 命名大致对应，便于对照规范与测试；详见 [tls_uya_design.md](tls_uya_design.md)。

---

## 参考规范与 RFC

- [uya.md](uya.md) — Uya 语言规范。
- mbedTLS 源码：<https://github.com/Mbed-TLS/mbedtls>（library/, include/mbedtls/）；实现时以 **mbedTLS 3.x/4.x** 及以下 RFC 为参考，行为差异在文档或注释中说明。
- RFC 5246（TLS 1.2）、RFC 8446（TLS 1.3）、RFC 6347（DTLS 1.2）、RFC 5280（X.509）、RFC 5869（HKDF）。
