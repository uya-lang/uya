# Uya v0.12.0 发布说明

> **类型**：**里程碑发行**（minor）
> **发布日期**：2026-11-15
> **语言规范**：0.49.57

**v0.12.0** 在 **v0.11.0** 的编译器容量收口之上，完成两件基础设施级的事：一是
**exec 后端（`uya run --vm` / `uya test --vm`）打通自举**——`--vm` 解释执行 `src/main.uya`
能编出可用的原生编译器，解释器自身的内存峰值从 **57 GB 降到 34.7 GB**；二是语言新增
**struct 匿名 union 重叠块**（规范 0.49.57），自举编译器的 `ASTNode` 借此从 **1848 字节
压到 152 字节（12.2×）**。附带密码学域运算提速、std.async / UyaGin / pipeline 的一批
语义级修复，以及 CPU 与内存两条普查门禁。

---

## 核心变更

### 1. exec（`--vm`）后端打通自举

目标只有一条：**C99 后端能编、能跑的程序，exec 后端必须同样能跑，结果一致**。
本轮把这条判据第一次推到了「解释器编译自身」的高度：

```bash
UYA_ROOT=lib ./bin/uya run --vm src/main.uya -- build src/main.uya -o /tmp/uya_vm
/tmp/uya_vm --version                          # v0.12.0
/tmp/uya_vm build /tmp/t2.uya -o /tmp/out_t2   # 自举产物能再编出可运行二进制
```

- **量化基线与门禁**：新增 `tests/verify_exec_vm_census.sh`（全量 `uya test --vm` 通过率与
  失败原因直方图）、`tests/verify_exec_vm_parity.sh`（与 C99 逐用例差分），并接入
  `make exec-census` / `make exec-parity`。对照文档 `docs/exec_vm_c99_parity.md` 记录
  起点 **119 / 910（13.1%）**，现在普查 **912 / 912**。
- **原生内存视图**：结构体 / tuple 字段与 union 字段走 native-agg 影子；`ADDR_INDEX` 按 `imm`
  步长取址；聚合元素支持原生字节视图；超大 raw 数组改从宿主堆分配（编译器根 arena 本身成为
  原生内存）；VM 聚合字节布局补上 C99 自然对齐。
- **静态容量按需增长**：全局表堆化、槽位池（8192 → `1<<17` 起步）、原生聚合旁路表（哈希索引
  + 空闲链 + 按需倍增）、常量池 retain —— 解释器可跑编译器本体，不再撞静态上限。
- **宿主桥**：`uya_call0_i32` 认 `mov eax,imm32; ret` 形态（含 trampoline 跟随）、
  `uya_thread_call_<T>` 非 i32 返回类型不再恒为 0、pthread 家族按名字走宿主拦截、
  `pthread_cancel` 不再用 tkill 打死整个进程、`sigaction` 登记进宿主桥并回填 `oldact`。
- **语义级修复举例**：`catch { … return 非错误联合值 }` 早返回不包 ok/err、`==`/`!=` 对
  结构体恒为「相等」、`as!` 对错误联合源丢错误分支、`.value` 走独立 HIR 节点、
  循环内聚集合字面量丢失、`for arr |&item|` 静默退出、宏生成的 `if` 表达式被无条件套
  `MAKE_ERR`。

### 2. 内存放大：57 GB → 34.7 GB

解释执行编译器本体时峰值 RSS 一度到 57 GB（`-O3` 的内层 gcc 还需要同等量级），本轮按
分配归因逐项收：

- **聚合值引用计数回收默认开启**（整档登记、`CAST` 直通拷贝、覆盖即释放、返回值移动），
  聚合缓冲改**精确分配**，复用前按登记表容量校验；
- 值竞技场**分段串联**，循环内临时聚合提速 45~100 倍；
- 删掉每帧对 `EXEC_MAX_CALL_ARGS`（128）个 varargs 的全量清零（`test_tls_x25519_pure`
  10m59s → 6m55s），`trace` 条件前移到调用点，`exec_value_clone` 加标量快速出口；
- 竞技场每块尾部 **16 字节护栏**，把 1 字节写偏从「读到垃圾 kind」变成明确的分配/越界诊断；
- 诊断设施：分配尺寸直方图、按 opcode 的聚合分配归因、`UYA_PROGRESS` 每 256 MB 累计输出。

### 3. struct 匿名 union 重叠块（规范 0.49.57，新语言特性）

`struct` 体内可写 `union { struct { … } struct { … } }`：块内每个 `struct { … }` 是一组
**互斥使用**的字段，不同组共享同一段存储，字段仍按 `v.field` 直接访问，**不需要** `match`。

```uya
struct Packet {
    kind: i32,
    union {
        struct { seq: i32, ack: i32 }
        struct { code: i64 }
    }
}
```

- 布局按 C99：普通字段顺序排布，重叠块从「块内最大对齐向上取整」处开始，块大小取各组最大值；
  生成的 C 是 `__extension__ union { __extension__ struct { … }; … };`，`-std=c99` 下合法。
- 同一结构体内字段名必须唯一；含重叠块的结构体不能用结构体字面量初始化（按名字逐字段赋值会
  同时写多组）。负例 `tests/error_overlap_duplicate_field.uya`、
  `tests/error_overlap_struct_literal.uya`，正例 `tests/test_overlap_fields.uya`（C99 与 VM 都跑）。
- 收益实绩：`src/ast.uya` 的 `ASTNode` 由 257 字段全内联改成「公共字段 + 变体负载」，
  **1848 B → 152 B**，节点字段访问代码零改动。

### 4. 后端与标准库修复（C99 与 VM 双后端）

共同特征仍是「不报错但算错」，本轮收掉的主要有：

- **C99 后端把 i64 饱和/包装链截断成 32 位**（发版前最后一条，静默错误）：饱和/包装运算选
  C 类型时，复合左操作数（cast、二元表达式）会兜底成 `int32_t`，于是
  `days *% 86400 as i64 +% 3600` 整条链按 32 位发射——期望 `2511824400`，实际 `-1783142896`。
  这直接造成 X.509 侧的 2038 问题：`time_components_to_unix` 正是这种形状，凡 notAfter 晚于
  2038-01-19 的证书都被算成「已过期」。现在按「cast 取目标类型、二元表达式取两侧更宽秩」选类型，
  且只在兜底成 `int32_t` 时提宽（`u8 +| 10` 的钳位语义不变）；
  回归用例 `tests/test_i64_wrapping_chain.uya`。
- **`tests/test_tls_x509.uya` 改用真实证书链**：`b578a7ed` 把链校验重写成「逐级真验签」之后，
  原来那两条用 mock 证书（只有 `rsa_n`/`rsa_e`、没有 TBS 与签名字节）的正例必然失败，
  `make check` 从那时起一直红着。现在正例改用固定 RSA 测试链
  （`tests/fixtures/x509/{root,inter,leaf}.der`，编译期 `@embed` 内嵌），
  过期叶子与信任锚不匹配两条拒绝路径也改为在真实证书上验证。
- **checker / codegen**：数组尺寸表达式求值后**固化回 AST**（局部 `const` 作尺寸被压成 1）；
  `eval_const_expr` 补上当前函数体内的局部 `const` 查找；左操作数是字面量时按右操作数类型
  发射饱和/包装运算（修 i64 被截成 i32）；结构体依赖先恢复后计算（`--vm` 整编自举的关键一环）。
- **std.thread / async**：fd 与槽号撞车；`AsyncWorkerResultFuture` 把 `AsyncThreadSlotWaitFuture`
  的 `slot_idx` 当 fd 交给 `sys_read`（EBADF）；忙等循环每轮 `poll` 装箱中间 future 造成内存爆炸；
  `thread_shared_pop_slot` 只认 `QUEUED` 导致 `DISPATCHED` 槽位取不出任务。
- **UyaGin / DNS**：路由指针改下标取址（结构体数组的裸地址算术在 VM 聚合布局下失效）；
  连接状态提到全局以绕开续体快照对帧内聚合的深拷贝；A/AAAA 与 TCP 长度前缀缓冲改堆分配
  （`@await` 期间地址稳定，DNS 不再 nxdomain）。
- **编译期设施**：新增 `@thread_local` 全局属性（C99 发射 `_Thread_local`）；新增
  `std.backend` 选择器按后端门控原生专用用例；`uya` 运行后自动清理临时 `.c` 与可执行文件，
  `$TMPDIR` 不再无限堆积。

### 5. 性能

| 项 | 改善 |
|---|---|
| P-384 域乘（`fe384_mul` 6×6 学校簿 + 伪梅森快速归约） | VM 下 p384 39m29s → **2m36s（15×）**；`test_tls_ecdsa` 全量 >45min 未完成 → **4m01s 通过** |
| P-256 域乘（`fe256_mul` 全标量展开、只最后一次条件减） | 标量乘 **298s → 7s** |
| `paths_equal` 先比文件名再 `stat` | `stat` 调用 **-93%** |
| 文件级全局收集去重、模块导出表容量倍增、`ExecLowerContext` 数组按需分配 | lowering/builder 巨型栈帧清零开销消除 |

### 6. 测试与 CI

- **两条普查门禁**：CPU 侧 `tests/exec_vm_census_skip.txt` 与内存侧
  `tests/exec_vm_census_mems.txt` 两张登记表，每行「文件名 + 原因」，只允许登记「C99 侧同样
  不适用/同样失败」的用例；并行度按物理内存预算自动压低，不再因转 OOM 杀掉整轮会话。
- **超时纪律**：超时改成按进程组 `SIGKILL`，看门狗放独立会话，挂死用例不再留孤儿、不再拖满整轮；
  阻塞型用例超时收窄到 60 s，纯算法大数用例单独放宽。
- **macOS CI**：pty 自检握手超时与进度点、`waitpid` `WCONTINUED`、errno 链接、arm64 屏障测试、
  macOS 管道 worker exec 路径、失败用例详情注解 —— macOS hosted 链路重新可验收。

---

## 升级指南

- **代码无需改动**：v0.12.0 没有破坏性语法变更，`--strict-overflow` 默认开启的口径与 v0.11.0 相同。
- **可选新特性**：需要「同一时刻只有一种变体有效」的大结构体（AST、协议报文、指令解码）可以
  改用匿名 union 重叠块，注意不能再用结构体字面量初始化。
- **`--vm` 仍是可选后端**：默认仍是 C99；`uya run --vm` / `uya test --vm` 用于验证与调试。
- **种子**：本版已随发行刷新单文件 C 种子（`backup/uya.c` 与 hosted 种子家族），冷启动
  `make from-c`（Linux）/ `make from-c-native`（macOS）可直接用当前种子。

---

## 统计与验证

- `make check`：**1197 / 1197**，失败 0。
- `uya test --vm` 普查（`make exec-census`）：**912 / 912**。
- 自举：`make b` 前后端一致，`--vm` 自举产物可再编出可运行原生二进制。
- 版本一致性：`tests/verify_version_sources.sh` 通过，`bin/uya --version` 报 `v0.12.0`。
- 自 v0.11.0 以来共 **1085** 个提交（其中 597 个是 exec VM 攻坚期的逐轮定位记录）。

---

## 已知限制

- **exec 后端覆盖边界**：hosted `run` / `test` 已对齐；microapp / softvm / baremetal 是另一条
  产物路径，`--vm` 不适用。inline asm 仍报 `EXEC_UNSUPPORTED_ASM`，SIMD 只覆盖部分形态。
- **`--vm` 的性能不是目标**：解释执行比 C99 慢 1~2 个数量级，大数运算用例靠超时表兜底。
- **`--strict-div` 默认关**：证明器仍无法表达「调用方保证非零」的跨函数不变量，与 v0.11.0 一致。
- **macOS / Windows 验证范围**：macOS 已回到「生成 C + 交叉编译 + 链接 + CI 自检」闭环，
  kqueue 真机全量回归仍未做；Windows 仍是「交叉编译 + wine 运行」，IOCP 后端未落地。
- **重叠块的构造限制**：不能用结构体字面量初始化，也不能嵌套 `union` 之外的变体标签；
  这些都是刻意的最小面，避免引入 `match` 才能安全访问的语法。

---

## 致谢

感谢在 exec 后端自举、内存放大归因、匿名 union 重叠块与测试门禁上逐轮定位与复验的参与者。

---

**标签**：`v0.12.0`
**下载 / 发行页**：[GitHub Releases](https://github.com/uya-lang/uya/releases/tag/v0.12.0)
**完整变更日志**：[CHANGELOG.md](../../CHANGELOG.md)
