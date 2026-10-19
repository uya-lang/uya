# Uya v0.10.4 发布说明

> **类型**：**v0.10.x 发行线上的能力补丁**（patch）
> **发布日期**：2026-10-19

**v0.10.4** 在 **v0.10.3** 的检查器动态表与 async 网络组合之上，用两周
（2026-10-05 → 2026-10-19）收口四条主线：一是**编译器自身的容量与速度**——四处
「表满即静默失效 / 直接编不过」改成按需增长，前端改进程级并行 + 增量指纹；二是
**密码学底座** `std.crypto`（SHA-512、4096 位 bigint、Curve25519、Ed25519），并修掉
其中三处真缺陷；三是**纯 Uya 的基线 JPEG 编解码** `std.image`；四是 **Windows 目标**
用 zig cc 打通自举与自检。另外把版本号**统一到唯一来源** `src/version.uya`。

---

## 核心变更

### 1. 编译器容量：四处「表满即静默失效」改为按需增长

这一批的共同特征是：表满之后**不报错、而是安静地少做事**，于是症状出现在与真实原因
毫无关系的地方。

- **输入文件表**。`main()` 的 `input_file_indices` 是 `[i32: 64]`（compiler-mini 遗留），
  而 `parse_args` 的守卫用的是 `MAX_INPUT_FILES`（512）——第 65 个显式输入的下标被写到
  数组之外，现场表现为 `错误: 无法获取输入文件路径（索引 1886221359）`，或者把被写坏的
  下标当成路径、报「收集模块依赖失败」。新增 `src/driver/path_list.uya`
  （`PathList` / `IntList`，按 2 倍增长、只装指针，扩容不打断指针身份），并把同族的
  6 张定长表、`ast_merge_programs`、split-C 镜像表与 `lib/libc/stdio.uya` 的 128 槽 FILE 池
  （128 × 64 KiB = 8 MiB BSS）一并改成按需分配；删掉 `current_size < max_files`
  那类**静默停手**的循环。FILE 池刻意**不搬迁 FILE 本体**——调用方长期持有 `&FILE`，
  值数组扩容会让这些指针悬垂。
- **reachable 函数表**。`[&ASTNode: 4096]` 且以同一个 4096 当循环上界 ⇒ 第 4097 个可达
  函数被**静默丢掉**：定义不发射、原型不写进 `uya_split_protos.h`，而调用点照常发射，
  宿主 C 编译器于是报 `implicit declaration` / `invalid initializer`，报错点全在调用处。
  实测 N=4000 通过、N=4090 起红，且恰好只有最后一个函数没被发射。
- **call edge 表**。`MAX_FN_CALL_EDGES = 16384` 装满就让整个工程编不过（报错点还落在
  标准库文件里）。改成按需增长；扩容失败**报错而不静默丢边**——静默丢边会让可达集合
  变小，退化成「定义不发射、调用点还在」的链接期 `undefined reference`，比报错难查得多。
- **顶层全局类型查找**。`C99_MAX_GLOBAL_VARS` 是刻意做成的**缓存**（满了降级是设计），
  但名字查找有 `program_decls` 兜底、类型查找没有 ⇒ 表满后 `&SOME_CONST[0: n]` 会退化成
  `struct uya_slice_int32_t`，宿主 C 报 `has no member named 'ptr'`。补上同款降级
  （只在未命中时触发，表没满时行为逐字节不变）。

配套新增 `tests/verify_input_file_count.sh`（100 个显式输入必须 build + check + 依赖表
全登记），并实测 100 / 400 / 1200 个显式输入文件。

### 2. 密码学底座 `std.crypto`（纯 Uya，不引 C / OpenSSL）

- **`sha512.uya`**：SHA-512（FIPS 180-4）+ HMAC-SHA512（RFC 2104），带流式上下文。
- **`bigint.uya`**：定长 64 limb（4096 位）+ SOS Montgomery 乘法 + 模幂。上游
  `lib/tls/base/mpi.uya` 的 `MPI_MAX_LIMBS = 32` 让 2048 位平方直接返回 `TlsBadInput`，
  RSA-4096 更无可能；本模块实测 2048 位模幂（e=65537）约 13 ms、4096 位模乘 0.27 ms。
- **`curve25519.uya` / `ed25519.uya`**：RFC 7748 与 RFC 8032，16×16 位 limb
  （TweetNaCl 结构，不需要 u128）。
- **`sha256.uya`**：补流式上下文与无长度上限的 HMAC-SHA256（原消息上限 256 字节，
  而 SSH 的 MAC 要覆盖最长 64 KiB 的包）。

**三个真缺陷**（都是在真实用途上暴露的，且都不是新写的代码才有的 bug）：

- **RSA-4096 签名全错**：`bigint_mont_mul` 的第 3 步只读 `t[k .. 2k)`，丢掉了溢出字
  `t[2k]`。模数小或指数短（65537）时它恒为 0，所以既有 11 条测试一直绿；RSA-4096 私钥
  签名几乎每次归约都溢出，错误只在最高字节，症状是服务端稳定回
  `message authentication code incorrect`。
- **Ed25519 验签缺小阶点检查**：8 个小阶点的编码完全合法、都能成功解码，缺了 cofactor
  检查就能拿它当公钥 / A / R 构造对任意消息都通过的伪造签名——而**所有正常的 RFC 8032
  向量测试照样全绿**。按 RFC 8032 §5.1.7 增加 `8·P == 单位元` 判定，并改为比较
  `gf_pack` 后的规范字节形式（域元素允许冗余表示，逐 limb 比较会漏判两个 8 阶点）。
- **`x25519` 的 u64 快路径算错**：对 RFC 7748 §5.2/§6.1 全部向量都算错（域运算单点都对，
  ladder 组合起来发散），而原测试只调 `x25519_pure_mpi`，所以一直没被发现。快路径改为
  委托 `std.crypto.curve25519`（同一批向量逐字节正确，约 3.5 ms/次 vs MPI 路径 296 ms），
  并补上快路径的向量断言。

### 3. `std.image`：纯 Uya 的基线 JPEG 编解码

内存位图 + 基线 JPEG 解码与编码（Huffman + 8×8 DCT），**零 libm、零 C 依赖**
（全整数定点），编码除调用方给的分配器外不用堆。这是「多模态图片只能接受原图或拒绝」
那条硬约束的收口：此前超预算的图缩不了，因为没有编解码器；现在有了
「解码 → 缩放 → 重编码」的前两半（缩放不在本次范围）。

分层判据是「能不能单独测」：`image`（位图）/ `jpeg_tables`（Annex K 量化表 + 标准
Huffman 表 + 质量缩放 + 码表装配，表值由 `cjpeg` 输出**机器提取**并断言等于 Annex K）/
`jpeg_bits`（熵段位读写，读侧**逐位不预读**）/ `jpeg_dct`（8×8 整数 FDCT/IDCT，
13 位定标 + 趟间 2 位小数）/ `jpeg_marker`（段解析，**解析层不拒绝渐进式**，
因为 `jpeg_decode_info` 要能在渐进式上给出宽高）/ `jpeg_decode` / `jpeg_encode`。

渐进式、算术编码、12-bit、4 分量一律明确拒绝（`JpegUnsupported`）——按基线硬解渐进式
会得到「上半张对、下半张糊」，比报错糟得多。

### 4. Windows 目标：从「只能生成 C」到「可自举自检」

- **syscall 汇聚点**：新增 `UYA_TARGET_WINDOWS` 块，`uya_windows_syscall` 按号分发到
  MinGW CRT / Win32。ABI 用 `int64_t` 而非 `long`——LLP64 下 `long` 只有 32 位，会把
  指针和长度的高位截断成野地址。
- **目录与 stat**：目录遍历走 `FindFirstFileW` bridge；`stat` 用
  `BY_HANDLE_FILE_INFORMATION` 补真实 (卷序列号, 文件索引)，因为 `_stat64` 的 `st_ino`
  恒为 0 会让任意两文件被判成同一个，进而把子目录/同目录模块去重丢弃。
- **Winsock 桥**：socket 描述符加 `0x40000000` 偏移与 CRT fd 区分，`poll` 用 `select`
  实现，`WSAE*` 错误码按语义映射回 Linux errno，`getsockopt`/`setsockopt` 的
  level/optname 做取值翻译，`fcntl` 的 `O_NONBLOCK` 用 `FIONBIO` 实现（空实现会让
  `tcp_set_nonblocking` 假成功、`connect` 语义全错）。
- **控制台代码页**：`uya_windows_write` 原先一律走 CRT `_write`，中文 Windows（CP936）
  会把 UTF-8 的「用法」渲染成「鐢ㄦ硶」。现在 fd 是控制台时单独走
  UTF-8 → UTF-16 → `WriteConsoleW`。
- **UBSan 逼出来的 UB**：`clock_gettime` 的 `now.QuadPart * 1e9` 在开机一段时间后溢出
  int64（症状是「SSH 一连就崩」），改为秒与余数分开算；`src/checker/interval.uya` 与
  `src/codegen/c99/utils.uya` 的区间端点加减乘、offset 组合、声明结果缓存哈希改用 u32
  承载（C99 中良定义）再转回 i32，位模式与原语义完全一致（改饱和会改变约束值，
  实测导致 10+ 处边界证明失效）。

验证：Windows 目标 check `src/main.uya`（含安全证明）通过，build 产物经 zig cc 编译后
在 wine 下运行输出正确；`tests/verify_std_path_platform_targets.sh` 的 windows 目标改为
zig cc 交叉 + wine 实跑，缺 zig/wine 时明确提示而不是假装通过。

### 5. 检查器：再收口 4 条 UB 漏检 + 接上切片范围校验

- **区间端点回绕（健全性漏洞）**。`[i32::MIN, i32::MAX]` 相加回绕成反转区间 `[0, -2]`，
  而 `interval_within_bounds` 只比较两个端点 ⇒ `a[w + h]` 被判「已证明安全」而静默放行、
  运行期越界。同一个回绕也解释了「除数是函数形参的加减表达式时编译器自己 SIGFPE
  （退出码 136）」。四处守卫统一改为**保守拒绝**，没有采用 i64 饱和运算——多算一步就多
  一个静默放行的机会。
- **常量 `-1` 兼作「非常量」哨兵**：`a[0 - 1]` 掉进变量证明分支并被放行。改为
  「成功标志 + 值」双返回，下标检查 / for 范围端点 / 区间提取 / 常量折叠全部改看成功标志。
- **嵌套字段移动导致的真 double free**：移动标记原先只落在顶层变量上，
  `const moved: Buf = h.buf` 之后外层结构体的类型级 drop 仍会清理同一份资源。checker 侧
  登记字段访问路径（判定用「前缀 + 恰好停在字段边界」，所以 `h.bufx` 不会被误判），
  且只对「字段类型自带 drop」的形态登记；codegen 侧在移动点把源字段置零。
- **`return` 表达式与元组下标**：`return` 只走类型推断、不深入 cast / 实参位置的子表达式，
  元组越界也只在成员访问检查里报 ⇒ 错误被推迟到 C 编译器。给 return 补一条只递归
  下标/成员/容器的边界检查（刻意**不**复用完整结点检查——那会对调用实参误做 move 标记，
  自举当场炸出 84 个「变量已被移动」误报）。
- **切片范围校验**：`check_slice_bounds` 早就实现了，但**全树没有调用者**（死代码）。
  接到切片表达式的类型推断上后，立刻暴露并清掉 13 处越界切片（`"..."[0: N]` 的 N 跨过了
  字符串结尾，切开的是越界读到的内存；逐个按 UTF-8 字节数核算，语义不变）。全树 984 处
  字面量切片重新扫描后越界 0 处。

新增回归：21 个负例（常量越界 / 证明失败 / 常量算错 / 空指针 / 移动语义）+ 40 余个正例
（`test_ub_safety_guards` 22 用例、`test_bounds_const_negative_index`、
`test_return_expr_bounds`、`test_slice_range_bounds`、`test_nested_field_move`），
正例专门防「证明器收紧到误报」。

### 6. 版本号统一到唯一来源

版本号此前散落在 `src/main.uya` 的两处 `fprintf` 与
`src/cmd/upm/upm_lib/types.uya` 的一个常量里，发版靠人工逐个改，漏一处就会出现
「`bin/uya --version` 报新版本、upm 还在按旧版本比 manifest」这类漂移。现在新增
**`src/version.uya`**（`UYA_VERSION`）作为唯一来源，`uya --version`、usage 首行与 upm 的
`UYA_UPM_RUNTIME_VERSION` 全部引用它；并新增 `tests/verify_version_sources.sh` 校验编译器
输出、upm 输出与 `readme.md` / `CHANGELOG.md` / 本发行说明 /
`docs/compile_time_optimization_status.md` 一致，已挂进 `make check`。

### 7. 其它收口

- **C99 后端默认 `CFLAGS` 从 `-O0` 提到 `-O2`**：`--opt=N` 只控制 Uya 自己的优化器，
  不控制宿主 C 编译器；-O0 让生成代码与手写 C 差一个量级（n-body 22s vs 6.8s），
  改 -O2 后 n-body 3.9s、spectral-norm 与 binary-trees 追平，可用 `CFLAGS` 覆盖。
- **`make uya` 22s → 14s**（无改动 0.4s）：前端进程级并行 + 增量指纹。
- **async**：`catch |err| { return err; }` 必须带上 error_id；具体 struct → 接口的赋值
  要装箱（`{vtable, data}`）。
- **kernel/sim**：x86 call gate trampoline 从 `call rax; ret` 改为 `jmp rax` 尾跳。
  原写法多压一层返回地址，让 payload 入口的 `rsp % 16` 从 8 变成 0，违反 SysV ABI，
  下游一用 `movaps` 就 SIGSEGV（实测 microapp `time` 用例崩在 `syscall_handle_time`）。
- **Benchmarks Game**：新增 `n-body` / `spectral-norm` / `binary-trees` 的 Uya 移植，
  输出与 C 参考实现逐字节一致。

---

## 升级指南

从 `v0.10.3` 升级到 `v0.10.4`：

```bash
git pull
git checkout v0.10.4

make clean && make release
```

- **兼容性**：语言语法与语义无破坏性变更；这一版只放宽了编译器的容量上限、
  收紧了若干漏检的 UB（**新报错说明旧代码里真有 UB**，不是语法变了）。
- **可能新出现的编译错误**（都属于 UB 收口，逐个看诊断即可）：
  常量负数下标、`return` 里的越界、元组越界、切片范围越界、嵌套字段移动后的再次读取。
- **C99 后端默认优化级别变了**：`-O0` → `-O2`。需要调试生成代码时可显式
  `make CFLAGS=...` 覆盖。
- **版本号来源**：若你有脚本解析 `bin/uya --version`，输出形态不变（`vMAJOR.MINOR.PATCH`）；
  生成的 C 里没有新增宏。

---

## 统计与验证

| 项目 | 说明 |
|------|------|
| 相对 `v0.10.3` | 33 个提交（2026-10-05 → 2026-10-19，不含发布收口提交），`src/` 26 文件 +4637/-706、`lib/` 21 文件 +6103/-135、`tests/` 61 文件 +4594/-12、`benchmarks/` 5 文件 +375/-1、`docs/` 8 文件 +620/-5 |
| 新增模块 | `lib/std/crypto/`（sha512 / bigint / curve25519 / ed25519）、`lib/std/image/`（7 文件）、`src/driver/path_list.uya`、`src/version.uya` |
| 新增回归 | 26 个负例 `tests/error_*.uya`、8 个 `tests/repros/*.uya`、`test_ub_safety_guards`（22 用例）、`test_bounds_*` 系列、`test_nested_field_move`、`test_slice_range_bounds`、`test_crypto_*`（6 个）、`test_std_jpeg_decode/encode`、`test_async_catch_reraise`、`test_interface_value_assign`、`verify_input_file_count.sh`、`verify_parallel_frontend.sh`、`verify_compile_incremental.sh`、`verify_version_sources.sh` |
| 自举一致性 | `make b` 自举对比通过（主编译器与自举编译器产物 `cmp` 字节一致） |
| 大工程验证 | `uya-agent`（104 文件、约 780 个顶层全局、4400+ 可达函数、16500+ call edge）从「12 条容量错误编不过」恢复为干净重编通过；显式输入文件实测 100 / 400 / 1200 个 |
| 验证闸门 | `make check` 全绿；`tests/verify_std_path_platform_targets.sh`（含 Windows zig cc + wine 实跑）、UPM 套件、exec vm 专项、microapp 聚合套件全部通过 |
| 发布产物 | `bin/uya` 使用 `-O3 -fno-builtin -DNDEBUG` 构建并 strip；`bin/uya --version` 输出 `v0.10.4` |
| 上一标签 | `v0.10.3` |

---

## 已知限制

- **取值路径的非线性下标仍不检查**：`a[w + h]` 作为**取值**不做边界证明（赋值路径已检查），
  除法正确性证明（除数非零）尚未实现，`a / 0` 仍不报错。补前者需连带为 13 处
  `digits[di - 1 - i]` 型多变量下标补证明。
- **仍有 3 条 UB 漏检未收口**：循环体内下标、切片**形参**下标、指针形参解引用。
  `tests/repros/` 下对应复现仍编译通过并运行期真 UB。「进循环体前丢掉被改坏的那一侧边界」
  的尝试实测让自举爆出 104 个错误——`while buf[i] != 0` 这类 C-string 循环只靠循环前
  `i == 0` 那一条过了证明，属独立工作量。
- **Windows 目标**：验证范围是「编译器在 Windows 自举 + check + 产物在 wine 下运行」，
  未做真机 Windows 全量回归；IOCP 后端仍未落地（沿用 poll/select 回退）。
- **macOS `kqueue` 后端**仍未经真机验收（v0.10.3 遗留）。
- **JPEG**：只解基线顺序 DCT 的 8-bit、1/3 分量；渐进式/算术编码/12-bit/4 分量明确拒绝。
  缩放不在范围内。

---

## 致谢

感谢所有为本版本编译器容量收口、密码学底座、JPEG 编解码、Windows 目标与检查器
UB 收口贡献的参与者。

---

**标签**：`v0.10.4`
**下载 / 发行页**：[GitHub Releases](https://github.com/uya-lang/uya/releases/tag/v0.10.4)
**完整变更日志**：[CHANGELOG.md](../../CHANGELOG.md)
