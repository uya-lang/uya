# Uya 变更日志

## [Unreleased]

### Added
- **`--strict-div` 除零正确性证明（默认关闭）**：整数 `/` 与 `%` 的除数必须能证明非零，
  否则报「除数可能为 0，无法证明 … 安全」。判定复用 `--strict-overflow` 的 i64 宽化区间：
  除数区间不含 0 才算证明成立。常量除数与区间守卫（`if d <= 0 || d >= N { ... }`）可通过；
  常量除零无论开关都会报错。**默认关**：存量库大量依赖「调用方保证非零」的跨函数不变量
  （`align_size(size, align)`、牛顿迭代 `n / guess`、`bytes_read / size` 等），证明器无法表达，
  强制会直接让编译器无法自举 —— 与 `--strict-overflow` 当初的处理路线一致。关闭/开启方式
  `--no-strict-div` / `--strict-div`。回归 `tests/verify_strict_div.sh`（已挂进 `make check`），
  正例 `tests/test_strict_div.uya`，负例夹具 `tests/repros/strict_div_negative.uya`。
- **`--strict-overflow` 静态溢出闸门（**默认开启**）**：整数 `+` `-` `*` 必须能证明不溢出，
  否则编译错误，诊断给出 checked / 区间守卫 / 饱和包装三条修法。证明器基于 i64 宽化区间，
  只采纳可信约束（用户守卫、无回绕增量、常量初始化）。只覆盖有符号整数（无符号是良定义模运算，
  不是 UB）。`src/` 与 `lib/` 存量已全部按语义迁移完毕（饱和 `+|` / 回绕 `+%` / `catch`），
  开启后告警归零，故默认开启；`tests/` 作为对抗性语料由 `tests/run_programs_parallel.sh`
  显式传 `--no-strict-overflow` 豁免。关闭方式 `--no-strict-overflow`。回归 `tests/verify_strict_overflow.sh`。
- **`try`/`catch` 整数溢出检查（规范 0.49.55）**：`try expr` 的 `expr` 现在可以是一个**整数算术表达式**
  （根为 `+` `-` `*` `/` `%` 或一元 `-`），按 checked 求值并产出 `!T`：越界 → `error.Overflow`，
  除数为 0 → `error.DivisionByZero`。整棵算术树共享一次检查，每棵子树只求值一次。
  - 传播：`fn add(a: i32, b: i32) !i32 { return try a + b; }`
  - 就地处理：`(a + b) catch |e| { … }`（`catch` 是 cast 级后缀，整条算术必须加括号）
  - 覆盖 `i8`/`i16`/`i32`/`i64`/`u8`/`u16`/`u32`/`u64`/`usize`/`byte`
- **入口 `main` 可返回错误联合**：`export fn main() !T` / `fn main() !T` 现在能正常链接运行。

### Fixed
- **未安装 zig 的宿主把 `make check` / `make release` 判成失败**：`Makefile` 把 `ZIG` 默认写死成
  某台开发机的绝对路径 `/home/winger/zig/zig`，`tests/verify_std_path_platform_targets.sh` 在
  缺 zig 时又直接 `exit 1`，于是没装 zig 的 CI（ubuntu-ci 跑 `make release`）必然红。
  现改为：`ZIG` 默认从 PATH 解析（解析不到留空），六个脚本里的同类硬编码一并改掉；
  std.path 的 windows 目标在缺 zig 时**保留「生成 C 通过」这一级结论**、交叉编译与运行显示
  `⊘ 跳过`（与既有的 wine 缺省处理一致），并在结尾如实汇报跳过项；
  `TOOLCHAIN=zig` 但找不到 zig 时给出明确错误，而不是拼出空命令。
  文档里同源的 `/home/winger/zig/zig` 示例路径一并改为 `/path/to/zig`。
- **lexer 遇未知字符静默返回 EOF，整段源码被丢弃**：`#` / `\` / `?` 这类不在词法表里的字符
  会让 parser 把剩余输入当成文件正常结束 —— `uya check` 退出码 0、零输出，`uya build` 则
  整段丢弃后续声明。现改为报「无法识别的字符 '<c>'（ASCII n），位于第 L 行第 C 列」并置
  `lexer.has_error`，错误正确传播为退出码 1。负例 `tests/error_lexer_unknown_char.uya`。
- **`@print` / `@println` / 字符串插值按错误的 printf 转换符输出实参**：`i32` 负值被当无符号打印
  （`-7` → `4294967289`）、`i16` 的 `-300` → `4294966996`、`f64` 的 `-1.5` → 指针值、插值
  `"pi=${pi}"` → `-1963457608`、`*` 动态宽度静默产出 `%426d`。现格式串按实参真实 C 类型选择
  （有符号 `%lld` / 无符号 `%llu` / 浮点 `%g` / 字节指针与切片 `%s`），并显式转换成匹配类型；
  `*` 改为编译期拒绝。回归 `tests/test_println_bytes_ptr_slice.uya`，
  负例 `tests/error_interp_dynamic_width.uya`。
- **大于 INT64_MAX 的整数字面量被 `strtoll` 饱和**：`0xbb67ae8584caa73bu64`（SHA-512 的 IV）与
  `0xFFFFFFFFFFFFFFFF`（P-256 素数 p 的 limb）经 `strtoll` 饱和成 `INT64_MAX`，codegen 按位拆分后
  变成 `0xFFFFFFFF + (0x7FFFFFFF << 32)`，导致 SHA-512 / P-256 / P-384 / RSA / ECDSA 全部算错
  （8 个 crypto/TLS 测试集体失败）。现改为一律 `strtoull` 解析后按二补数转 i64 保存位模式。
- **接口值访问字段、具体结构体赋给接口数组元素静默生成非法 C**：`writer.fd` 与 `arr[i] = concrete`
  都通过 checker 却生成 `has no member named 'fd'` / `incompatible types`。现于 checker 阶段拒绝
  并给出可用写法（接口值自身的 `vtable` / `data` 字段仍放行，`std.async` 的 `Future` 依赖它）。
  负例 `tests/error_interface_field_access.uya`、`tests/error_interface_array_elem_assign.uya`。
- **未证明的有符号溢出不再落入 C UB**：构建（`Makefile` / `src/compile.sh`）、驱动默认 `CFLAGS`
  与生成的 split-C Makefile 统一加 `-fwrapv -fno-strict-overflow`，溢出退化为定义良好的回绕。
  实测 `2147483647 + 1` 由 `-fsanitize=undefined` 报
  `signed integer overflow ... cannot be represented` 转为干净通过。
- **`lib/libc/stdio.uya` 的 `%d` 无法格式化 INT32_MIN**（只输出一个负号）：幅值此前用
  `num = 0 - num` 取反，INT32_MIN 相反数不可表示，回绕后仍为负数导致数字循环一次不进。
  改用 u32 二补数取负。该 bug 被 `-fwrapv` 现形——此前靠 UB 侥幸输出正确。
- `gen_return_error_union` 的「标识符名含 result 即视为错误联合」启发式会误判
  `return result;`（`result: i32`，函数返回 `!i32`）并生成非法 C；改为类型判定优先于名字猜测。

### Compatibility
- 非 `try`/`catch` 上下文的 `a + b` 行为完全不变；`try a + b` 由「编译错误」变为「合法」，
  属纯增量变更。

## v0.10.4 - 编译器容量收口、密码学底座与 Windows 目标

> 发布日期：2026-10-19

### 概要

**v0.10.4** 是 v0.10.x 发行线上的**能力补丁**，四条主线：

1. **编译器容量与速度**：输入文件表 / call edge 表 / reachable 函数表 / 顶层全局类型
   查找全部改成按需增长 —— 大工程不再撞「容量已满」编不过，也不再静默丢函数；
   前端改进程级并行 + 增量指纹，`make uya` 22s → 14s（无改动 0.4s）。
2. **密码学底座**：新增 `std.crypto`（SHA-512/HMAC、4096 位 bigint + Montgomery、
   Curve25519、Ed25519），并修掉三个真缺陷 —— RSA-4096 的 Montgomery 归约丢溢出字、
   Ed25519 验签缺小阶点检查、`x25519` 的 u64 快路径算错。
3. **纯 Uya 的基线 JPEG 编解码**：新增 `std.image`（`Image` + Huffman + 8×8 DCT，
   全整数定点、零 libm / 零 C 依赖）。
4. **Windows 目标**：用 zig cc 打通 Windows 自举（syscall 汇聚点、LLP64 指针截断、
   Winsock、控制台代码页、UBSan 下暴露的区间运算 UB）。

另外：检查器再收口 4 条 UB 漏检并接上切片范围校验；C99 后端默认优化从 `-O0` 提到
`-O2`；补 Benchmarks Game 移植；修 kernel/sim x86 call gate trampoline 的 SysV 栈对齐；
**版本号统一到唯一来源 `src/version.uya`**。

### 新增

#### `std.image`：纯 Uya 的基线 JPEG 编解码

内存位图 + **基线 JPEG 编解码**（Huffman + 8×8 DCT），**零 libm、零 C 依赖**
（全整数定点），编码除调用方给的分配器外不用堆。这是「多模态图片只能接受原图或
拒绝」那条硬约束的收口：此前超预算的图缩不了，因为没有编解码器；现在有了
「解码 → 缩放 → 重编码」的前两半（缩放不在本次范围）。

- **`lib/std/image/image.uya`**：内存位图 `Image`（灰度 / RGB，行优先、无填充）。
  接口：`image_new` / `image_free` / `image_get` / `image_set` / `image_fill` /
  `image_bytes_for` / `image_is_valid`。像素缓冲是 `&u8`（`byte` 在 Uya 里是独立
  类型，热循环里逐像素 `as! u8` 不划算；交接处用 `image_pixels_as_u8/_byte` 重解释）。
- **`lib/std/image/jpeg_tables.uya`**：T.81 Annex K 的量化表（亮度 / 色度）与
  四张标准 Huffman 表（BITS + HUFFVAL）、zigzag 顺序、`jpeg_quality_scale`
  （质量 → 量化表，libjpeg 同款缩放）、`JpegHuffDecoder` 译码表装配
  （快表 + 规范码区间）、`JpegHuffEncoder` 编码表装配。表值用
  `cjpeg -quality 50 -baseline` 的输出**机器提取**（不是手抄），并断言等于 Annex K。
- **`lib/std/image/jpeg_bits.uya`**：熵段位读写。读侧 **逐位、不预读**（`pos` 永远
  指向下一个未读的流字节，撞到标记时停在它上面）；0xFF00 反转义、RSTn 同步；
  写侧按 T.81 补 **1** 收尾。
- **`lib/std/image/jpeg_dct.uya`**：8×8 整数 FDCT / IDCT（矩阵式两趟，矩阵 13 位
  定标 + 趟间 2 位小数，i64 中间量）、`jpeg_quantize` / `jpeg_dequantize`。
  定标口径 = **真值**（不带 libjpeg 的 ×8），实测往返误差 ≤ 1 个灰阶。
- **`lib/std/image/jpeg_marker.uya`**：段解析（SOI/APPn/COM/DQT/DHT/DRI/SOF0-3/SOF9-10/
  DAC/SOS/EOI）。**解析层不拒绝渐进式**（见下面「设计取舍」），只把事实读出来。
- **`lib/std/image/jpeg_decode.uya`**：解码主流程。支持基线顺序 DCT、1/3 分量、
  任意 h/v ∈ 1..4 的矩形采样（块重复上采样）、DRI 重启间隔、8-bit。
  入口：`jpeg_decode`（解进 `Image`）、`jpeg_decode_info`（只读文件头，渐进式也
  能给出宽高）。
- **`lib/std/image/jpeg_encode.uya`**：编码主流程。JFIF + 标准 Annex K 表、
  灰色 / RGB、`JPEG_SUB_444` / `_422` / `_420`、质量 1..100。
  入口：`jpeg_encode`（完整选项）、`jpeg_encode_q`（只调质量）、`jpeg_max_bytes`
  （缓冲上界）、`jpeg_options_default`。
- **测试**：`tests/test_std_jpeg_decode.uya`（12 条断言组：4:2:0+重启 / 灰度 /
  4:4:4 的块均值比对、渐进式与非 JPEG 与截断的拒绝、截断熵段、`jpeg_decode_info`）、
  `tests/test_std_jpeg_encode.uya`（12 个 test / 71 条断言：往返、质量单调性、
  **逐字节断言 DQT 等于 Annex K**、质量两端、缓冲不足、非法输入）。
- **文档**：`docs/std_jpeg.md`（分层、支持矩阵、接口、不变量、测试与证据）；
  `docs/uya.md` 的标准库表补 `std.image` 三行。

#### `std.crypto`：纯 Uya 的密码学底座

为纯 Uya 的 SSH 客户端打底（上游一直缺 SHA-512、Ed25519，以及能做 2048 位以上模幂的
大数）。全部纯 Uya，不引 C / OpenSSL。

- **`lib/std/crypto/sha512.uya`**：SHA-512（FIPS 180-4）+ HMAC-SHA512（RFC 2104），
  带流式上下文。
- **`lib/std/crypto/bigint.uya`**：定长 64 limb（4096 位）大数 + SOS Montgomery 乘法 +
  模幂。上游 `lib/tls/base/mpi.uya` 的 `MPI_MAX_LIMBS = 32` 让 2048 位平方直接返回
  `TlsBadInput`（2048 位平方需要 64 limb），RSA-4096 更无可能；本模块实测 2048 位模幂
  （e=65537）约 13 ms、4096 位模乘 0.27 ms。
- **`lib/std/crypto/curve25519.uya`**：RFC 7748，16×16 位 limb（TweetNaCl 结构，
  不需要 u128）；**`ed25519.uya`**：RFC 8032 签名/验签，复用同一套域运算。
- **`lib/std/crypto/sha256.uya`**：补流式上下文与无长度上限的 HMAC-SHA256
  （原 `std.crypto.hmac_sha256` 的消息上限 256 字节，而 SSH 的 MAC 要覆盖最长 64 KiB 的包）。
- **测试**（期望值均由独立的 Python 参考实现算出，不是从实现反推）：
  `test_crypto_sha512`（13 项，FIPS 180-4 附录 C + RFC 4231 全 7 条 + 流式/边界）、
  `test_crypto_bigint`（11 项）、`test_crypto_bigint_modexp4096`（RSA-4096 向量）、
  `test_crypto_curve25519`（8 项，RFC 7748 §5.2/§6.1）、`test_crypto_ed25519`（7 项，
  RFC 8032 §7.1 TEST 1/2/3 逐字节 + 篡改必须失败 + 9 个小阶点必须被拒）、
  `test_crypto_sha256_stream`（6 项）。

#### Benchmarks Game 移植

`benchmarks/benchmarksgame/` 新增 Uya 版 `n-body` / `spectral-norm` / `binary-trees`，
三者输出与 C 参考实现**逐字节一致**，附构建方法、运行说明与性能对比。

### 修复与收口

#### 编译器容量：四处「表满即静默失效 / 直接编不过」

- **输入文件表（`src/driver/path_list.uya`）**。`main()` 的 `input_file_indices` 是
  `[i32: 64]`（compiler-mini 遗留），而 `parse_args` 的守卫用的是 `MAX_INPUT_FILES`（512）
  ⇒ 第 65 个显式输入的下标写到数组之外，现象是「无法获取输入文件路径（索引 1886221359）」
  这类与真实原因无关的报错。新增 `PathList` / `IntList`（按 2 倍增长、只装指针，
  扩容不打断指针身份），并把同族的 6 张定长表、`ast_merge_programs`、split-C 镜像表
  与 libc 的 128 槽 FILE 池（128 × 64 KiB = 8 MiB BSS）一并改成按需分配；删掉
  `current_size < max_files` 那类**静默停手**的循环。新增
  `tests/verify_input_file_count.sh`（100 个显式输入必须 build+check+依赖表全登记）。
- **reachable 函数表**。`[&ASTNode: 4096]` 且以同一个 4096 当循环上界 ⇒ 第 4097 个可达
  函数被**静默丢掉**（定义不发射、原型不写进 `uya_split_protos.h`），报错点在调用处
  （`implicit declaration` / `invalid initializer`）。改为按 checker 的实际条数分配、
  装满 2 倍扩容，常量降级为初始容量。
- **call edge 表**。`MAX_FN_CALL_EDGES = 16384` 装满就让整个工程编不过，报错点落在标准库
  里。改为按需增长；扩容失败**报错而不静默丢边** —— 静默丢边会让可达集合变小，
  变成「定义不发射、调用点还在」的链接期 `undefined reference`。
- **顶层全局类型查找**。`C99_MAX_GLOBAL_VARS` 是刻意做成的缓存（满了降级是设计），
  但名字查找有 `program_decls` 兜底、类型查找没有 ⇒ 表满后 `&SOME_CONST[0: n]` 退化成
  `struct uya_slice_int32_t`。补上同款降级（只在未命中时触发，表没满时逐字节不变）。

#### 检查器：再收口 4 条 UB 漏检 + 接上切片范围校验

- **区间端点回绕（健全性漏洞）**。`[i32::MIN, i32::MAX]` 相加回绕成反转区间 `[0, -2]`，
  而 `interval_within_bounds` 只比较两个端点 ⇒ `a[w + h]` 被判「已证明安全」而静默放行。
  同一个回绕也解释了「除数是形参加减表达式时编译器自己 SIGFPE（退出码 136）」。四处守卫
  统一改为**保守拒绝**（端点反转直接判「无法证明」），没有采用 i64 饱和运算 ——
  多算一步就多一个静默放行的机会。回归：`error_array_bounds_interval_wrap.uya` +
  正例 `test_bounds_interval_wrap.uya`。
- **常量 `-1` 兼作「非常量」哨兵**。`checker_eval_const_expr` 用 `-1` 同时表示「非常量」，
  于是 `a[0 - 1]` 掉进变量证明分支、静默放行。改为「成功标志 + 值」双返回
  （`checker_eval_const_expr_ex`），下标检查 / for 范围端点 / 区间提取 / codegen 常量折叠
  全部改看成功标志；顺带收口 `2147483647 - (0 - 1)` 这类中间结果为 -1 的减法上溢。
- **嵌套字段移动导致的真 double free**。移动标记原先只落在顶层变量上，
  `const moved: Buf = h.buf` 之后外层结构体的类型级 drop 仍会清理同一份资源。
  checker 侧登记**字段访问路径**（`h.buf`，判定用「前缀 + 恰好停在字段边界」，
  所以 `h.bufx` 不会被误判）且只对「字段类型自带 drop」的形态登记（否则自举爆出
  110 个误报）；codegen 侧在移动点把源字段置零，让类型级 drop 成为空操作。
- **`return` 表达式与元组下标**：`return` 只走类型推断、不深入 cast/实参位置的子表达式，
  元组越界也只在 `checker_check_member_access` 里报 ⇒ 错误被推迟到 C 编译器。给 return
  补一条只递归下标/成员/容器的边界检查（刻意**不**复用 `checker_check_node`，
  否则会对调用实参误做 move 标记，自举当场炸出 84 个「变量已被移动」误报）。
- **切片范围校验接上**：`check_slice_bounds`（`src/checker/proof.uya`）早就实现了，
  但**全树没有调用者**（死代码）。接到切片表达式的类型推断上后，立刻暴露并清掉 13 处
  越界切片（`"..."[0: N]` 的 N 跨过了字符串结尾，切开的是越界读到的内存；逐个按 UTF-8
  字节数核算，语义不变）。全树 984 处字面量切片重新扫描后越界 0 处。
- 测试：新增 21 个负例（`tests/error_*.uya`）+ 40 余个正例（`test_ub_safety_guards` 22 用例、
  `test_bounds_const_negative_index`、`test_return_expr_bounds`、`test_slice_range_bounds`、
  `test_nested_field_move`），正例专门防「证明器收紧到误报」。

#### 密码学：三个真缺陷

- **RSA-4096 签名全错（Montgomery 归约丢溢出字）**。`bigint_mont_mul` 第 3 步只读
  `t[k .. 2k)`，丢掉了 `t[2k]`。模数小或指数短（65537）时它恒为 0，所以既有 11 条测试
  一直绿；RSA-4096 私钥签名几乎每次归约都溢出，错误只在最高字节，症状是服务端稳定回
  `message authentication code incorrect`。修法：读入溢出字，非 0 时必然要减一次 n
  （回绕正好给出 V - n）。`test_crypto_bigint_modexp4096` 修复前红、修复后绿。
- **Ed25519 验签缺小阶点检查（可伪造任意消息的签名）**。8 个小阶点的编码完全合法、
  都能成功解码，缺了 cofactor 检查就能拿它当公钥/A 或 R 构造万能伪造签名；
  而**所有正常的 RFC 8032 向量测试照样全绿**。按 RFC 8032 §5.1.7 增加 `8·P == 单位元`
  判定。过程中还修掉自己那版检查的隐蔽错误：域元素允许**冗余表示**，逐 limb 比较会漏判
  两个 8 阶点，改为比较 `gf_pack` 后的规范字节形式。
- **`x25519` 的 u64 快路径算错**。该路径对 RFC 7748 §5.2/§6.1 全部向量都算错
  （域运算单点都对，ladder 组合起来发散），原测试只调 `x25519_pure_mpi` 所以一直没被
  发现。快路径改为委托 `std.crypto.curve25519`（同批向量逐字节正确，约 3.5 ms/次
  vs MPI 路径 296 ms），并补上快路径的向量断言。

#### Windows 目标

- **编译器可在 Windows 运行并自举自检**：新增 `UYA_TARGET_WINDOWS` 块，
  `uya_windows_syscall` 作为唯一 syscall 汇聚点；syscall ABI 用 `int64_t` 而非 `long`
  （LLP64 下 `long` 仅 32 位，会把指针/长度高位截断成野地址）；目录遍历走
  `FindFirstFileW` bridge；`stat` 用 `BY_HANDLE_FILE_INFORMATION` 补真实
  (卷序列号, 文件索引) —— `_stat64` 的 `st_ino` 恒为 0 会让模块被去重丢弃。
- **Winsock 桥**：socket 描述符加 `0x40000000` 偏移与 CRT fd 区分，`poll` 用 `select`
  实现，`WSAE*` 错误码按语义映射回 Linux errno，`getsockopt`/`setsockopt` 的
  level/optname 做取值翻译，`fcntl` 的 `O_NONBLOCK` 用 `FIONBIO` 实现
  （空实现会让 `tcp_set_nonblocking` 假成功、`connect` 语义全错）。
- **控制台代码页**：`uya_windows_write` 原先一律走 CRT `_write`，中文 Windows（CP936）
  会把 UTF-8 的「用法」渲染成「鐢ㄦ硶」。现在 fd 是控制台时（`GetConsoleMode` 成功）
  单独走 UTF-8 → UTF-16 → `WriteConsoleW`。
- **`clock_gettime` 有符号溢出**：`now.QuadPart * 1e9` 开机一段时间后溢出 int64，
  UBSan 构建直接 panic（实测「SSH 一连就崩」）；改为秒与余数分开计算。
- **区间/哈希运算的 i32 有符号溢出**：`src/checker/interval.uya` 与
  `src/codegen/c99/utils.uya` 里端点加减乘、offset 组合、声明结果缓存哈希等统一改用 u32
  承载（C99 中良定义）再转回 i32，位模式与原语义完全一致（改饱和会改变约束值，
  实测导致 10+ 处边界证明失效）。

#### C99 后端与构建

- **默认 `CFLAGS` 从 `-O0` 提到 `-O2`**。`--opt=N` 只控制 Uya 自己的优化器，不控制宿主 C
  编译器；-O0 让生成代码与手写 C 差一个量级（n-body 22s vs 6.8s）。改为 -O2 后
  n-body 3.9s、spectral-norm 与 binary-trees 追平，可用 `CFLAGS` 覆盖。
  剩余 n-body 差距（sqrt 走 Newton 迭代、`-fno-builtin` 挡住硬件 `sqrtsd`）已记入
  `benchmarks/benchmarksgame/README.md`。
- **async 里 `catch |err| { return err; }` 必须带上 error_id**；**具体 struct → 接口的
  赋值要装箱**（`{vtable, data}`）。
- **`make uya` 22s → 14s**：前端进程级并行 + 增量指纹（`UYA_FORCE_BUILD=1` 可强制重建）。
- **kernel/sim x86 call gate trampoline 改尾跳**：原来的 `call rax; ret` 会多压一层返回
  地址，让 payload 入口的 `rsp % 16` 从 8 变成 0，违反 SysV ABI，下游一用 `movaps`
  就 SIGSEGV（实测 microapp `time` 用例崩在 `syscall_handle_time`）。改为 `jmp rax`，
  并补两条裸函数探针测试覆盖 `uya_call0_i32` 与 `uya_call0_i32_stack`（私有栈）两条路径。
- **版本号统一到唯一来源**：新增 `src/version.uya`（`UYA_VERSION`），`uya --version`、
  usage 首行与 upm 的 `UYA_UPM_RUNTIME_VERSION` 全部引用它；新增
  `tests/verify_version_sources.sh` 校验编译器输出、upm 输出与 readme / CHANGELOG /
  发行说明 / 优化状态报告一致，已挂进 `make check`。

### 设计取舍

- **渐进式 / 算术编码 / 12-bit / 4 分量一律明确拒绝**（`JpegUnsupported`），
  不按基线硬解 —— 按基线解渐进式会得到「上半张对、下半张糊」，比报错糟得多。
  拒绝判定放在**解码侧**而不是解析侧：`jpeg_decode_info` 的用途是「先问尺寸再
  决定收不收」，它要能在渐进式上照样给出宽高。
- **上采样用块重复**（与 `djpeg -nosmooth` 一致）：三角滤波对「缩图 → 重编码」
  收益看不出来，而实现只有几行。
- **编码不做码表优化**：用标准 Huffman 表，实现短、输出可被任何解码器读。

### 外部证据（开发期实测，改 DCT / 量化定标时要重做）

- 我们的编码输出用 `djpeg -dct int` 能解：q90、4:2:0、64×64 渐变，
  平均误差 **1.29/255**、最大 **5/255**。
- 我们的解码器与 `djpeg -nosmooth` 在 4:4:4 / 4:2:2 / 4:2:0 / 4:2:0+重启 四种
  256×256 图上逐样本比对：**最大误差 4/255**（196608 个样本，0 个超过 4）。

### 验证

`make release` 全程通过：clean 重编 + `make b` 自举对比**字节一致**（cmp）+ `make check`
**1153/1153** 单文件测试 + 各闸门（证明优化 / 顶层函数发射 / SIMD / `@syscall` 交叉 /
std.path 三平台含 Windows zig cc + wine 实跑 / UPM 套件 / exec vm / microapp 聚合）
+ backup-all-seed 刷新种子。发布产物 `bin/uya` 为 `-O3 -fno-builtin -DNDEBUG` 静态链接
并 strip，`bin/uya --version` 与 `bin/cmd/upm --version` 均报 v0.10.4。

### 仍在账上（本版未修）

- `buglist.md` 里的「取值路径非线性下标不检查」与「除法正确性证明」仍未做：
  `a[w + h]` 作为**取值**仍不做边界检查（赋值路径已检查），`a / b` 乃至 `a / 0`
  都还不报错；补前者需连带为 13 处 `digits[di - 1 - i]` 型多变量下标补证明。
- 循环体内下标、切片**形参**下标、指针形参解引用这三条 UB 仍未收口（`tests/repros/`
  下仍编译通过并运行期真 UB）；「进循环体前丢掉被改坏的那一侧边界」的尝试实测让自举
  爆出 104 个错误 —— 根因是 `while buf[i] != 0` 这类 C-string 循环只靠循环前 `i == 0`
  那一条过了证明，属独立工作量。
- macOS `kqueue` 后端仍未经真机验收，Windows 的 IOCP 后端仍未落地（沿用 poll 回退）。
- `uya-agent` 的 TUI 自测轮在本机 0.10.3 上整组红，已确认与本版改动无关
  （同机 0.10.1 构建同一份源码全绿），详见 `buglist.md`。

## v0.10.3 - 检查器动态表与 async 缺失项收口

> 发布日期：2026-10-05

### 概要

**v0.10.3** 在 **v0.10.2** 的 `std.process` / typed pipeline 基础上，收口两类问题：

1. **大工程与 C99 split-C 容量/命名收口**：checker 五张定长表改成通用动态哈希表，`uya-agent`
   这类上万声明规模的工程不再撞「函数表容量不足」；split-C 下同名顶层常量定义去重、
   hosted 系统头宏名冲突加护栏。
2. **async 缺失项三条主线**：hosted 下多线程并发 `malloc/free` 必然踩坏堆（P0）、`Waker`
   多 fd/多 interest、HTTP/1 客户端连接池 + keep-alive 复用、TLS 1.2 会话复用、macOS
   `kqueue` 后端。

### 修复

- **checker：五张定长表改成通用动态哈希表 —— 大工程不再报「函数表容量不足」**。
  `symbol_table` / `function_table` / `module_table` / `import_table` / `string_pool` 原先都是
  写死容量的数组（32768 / 8192 / 256 / 512 / 16384）。实测一个 112 文件、约 6800 个声明的
  工程（`uya-agent`）在 `FUNCTION_TABLE_SIZE = 8192` 下**只剩 9 个函数**的余量：再加第 10 个
  函数就报 `函数表容量不足，请增大 FUNCTION_TABLE_SIZE`，而报错点落在**标准库**里
  （`lib/std/http/uyagin_router.uya`，那是被编译到的第 8193 个函数所在的位置），
  使用者完全看不出根因，也没有可用的开关。
  现在新增 `src/checker/dyn_table.uya`：一套「开放寻址 + 线性探测 + 满载 2 倍扩容 + rehash」
  的实现，五张表共用（`string_pool` 是链式桶，单独把桶数组改成动态并支持扩容重挂链）。
  旧常量保留为**初始容量**（不再是上限），小工程的容量、内存画像与性能与改动前一致。
  函数表的插入/查找语义（同名不同模块共存、调用点模块优先、extern 签名一致则不重复插入、
  一 extern 一普通则覆盖）**逐条保持**，`check_stmt.uya` 里那条「函数表容量不足」的
  失败路径删除（只剩「同一模块内签名冲突」与极端情况下的扩容分配失败）。
  表按**指针**元素存储（元素大小 = `@size_of(&X)`），保持编译器的指针身份语义。
  修复过程中踩到并修掉三个实现缺陷，都写进了 `dyn_table.uya` 的注释：
  ① 扩容时只清零键数组、**没清值缓冲** ⇒ 空槽读到 malloc 垃圾指针（编译器自编当场段错误）；
  ② 表按**值拷贝**结构体会切断作用域链表的指针身份（符号查找依赖 `==` 比较）；
  ③ 旧的 `hash & (SIZE - 1)` 掩码**天生非负**，换成 `hash % capacity` 后会得到负下标 ——
  所有调用点都要补一次负数归一。
  新增回归 `tests/test_dyn_table_growth.uya`：500 条插入逼出多次扩容 rehash，逐键回查
  count/id/tag、值指针身份、覆盖语义、不存在的键、以及把容量手工逼到 8192 后旧键仍命中；
  对照实验把 rehash 的「按键重新探测」换成「按下标整段拷贝」当场红 2 条。
  验收：`make b` 自举对比**字节一致**；`make check` 1116/1116 通过（1115 基线 + 本轮新增）；
  用新编译器编译 `uya-agent` 的 49 个源文件，**外加 100 / 8000 / 20000 个空函数全部通过**
  （改动前 +10 个就失败）。

- **C99 split-C 后端：同名顶层常量的「定义」会重复发射（链接期 `multiple definition`）**。
  合并命名空间下两个源文件可以各写一份同名 `export const`（真实例子：`lib/libc` 的
  `CLOCKS_PER_SEC` 曾由 `stdlib.uya` 与 `time.uya` 各定义一次）。`gen_extern_var_decl` 用
  `codegen.global_variables` 注册表判断「这个 C 名是否已经发射过定义」，而该表上限是
  `C99_MAX_GLOBAL_VARS`（512）且**表满后静默丢弃登记**：小程序撑不满、去重生效看不出问题，
  `uya-agent`（1700+ 顶层全局）表早就满了，两份定义一路漏到链接期。
  现在新增一张独立的「已发射定义的全局 C 名」集合（开放寻址 + 线性探测，容量 8192），
  在定义路径上先查再登记；**表满时不再静默降级，而是当场报错退出**，错误信息带
  `文件:(行:列)`、表名与容量、以及本次要登记的全局名，并指明去调哪个常量 ——
  漏登记会静默产出「会链接失败或结果错误」的 C，比直接编译失败更难排查。
  `gen_global_var`（模块内私有非常量全局）刻意不动 —— 那里重名会**大声**报链接错误，
  去重反而会把 loud failure 换成 silent wrong。注意 `global_variables` 本身是**缓存**
  （满了按名查找会退回 `program_decls` 线性扫描），它继续保留「满则降级」的语义。
  新增回归 `tests/verify_split_dup_global.sh`（固定装置 `tests/fixtures/split_dup_global/`），
  已挂进 `make check` / `make check-hosted`；修复前该脚本报
  `multiple definition of 'DUP_SHARED_CONST'`。修复后 `make b` 自举对比字节一致，
  `make check` 1111/1111 通过。

- **C99 hosted 后端：用户顶层全局与系统头宏同名导致编译失败**。hosted 生成会为非 bootstrap 编译单元
  `#include <errno.h>` 等系统头，宏是文本替换，因此用户顶层全局写成裸名时，单文件定义
  （`__attribute__((used)) const int32_t ETIMEDOUT = 110;`）与镜像分 TU 的声明
  （`uya_mirror_globals.h` 里的 `extern const int32_t ETIMEDOUT;`）都会被写成
  `error: expected identifier or '(' before numeric constant`。
  现在在全局声明/定义前按需发射 `#ifdef X / #undef X / #endif` 护栏（判据为"宏形态"标识符——
  纯标识符且含大写字母，外加 `errno`/`stdin`/`stdout`/`stderr`；跳过编译器自身发射的 `uya_`/`UYA_`
  宏前缀），覆盖 `gen_global_var`、`gen_extern_var_decl`、`c99_mirror_emit_extern_global_line`
  三个发射点。新增回归 `tests/test_hosted_macro_name_collision.uya`。
  该缺陷此前被闸门漏检：`tests/run_programs_parallel.sh` 把 `tests/test_pthread_cond.uya` 归入
  nostdlib 名单，于是 `make check` 全绿，但 hosted 直跑同一用例必挂，并连带
  `tests/stress_pthread.sh` 第 1 轮失败、`tests/verify_async_full_dynamic_resources_gate.sh`
  的 `c99-stress` 阶段失败。修复后 `make check` 1111/1111 通过。

- **`libc.signal`：`signal()` 装的处理器一收到信号就 SIGSEGV（x86_64）**。
  x86-64 的信号交付路径要求 `sa_flags` 带 `SA_RESTORER` 且 `sa_restorer` 指向执行
  `rt_sigreturn` 的垫片，而旧实现用裸 `rt_sigaction` 装处理器（`sa_flags = 0`、
  `sa_restorer = null`），于是处理器体一次都不执行、进程直接以 SIGSEGV(139) 退出。
  回移 0.11 的同名实现：新增 `@naked_fn _signal_restorer()`（x86_64 走
  `movq $15, %rax; syscall`，arm64/arm32 分支同在）；`signal()` 置 `SA_RESTORER` +
  `sa_restorer` 并返回内核回填的旧动作；`SIG_ERR` 改成全 1（64 位 `(void*)-1`）；
  `sigprocmask` 改为把 `sigset_t` 指针交给内核（旧实现传值必然 `EFAULT`）；`raise`
  用 `gettid` 定位调用线程；`atexit`/`on_exit` 改为声明宿主实现。新增回归
  `tests/test_signal.uya` 的 `signal_handler_is_invoked` / `sigprocmask_blocks_delivery`
  两个用例（反向对照：换回未修版本重跑同一用例集报 Segmentation fault、退出码 139）。

- **`libc.stdlib` / `libc.time`：`CLOCKS_PER_SEC` 重复定义导致 split-C 链接失败**。
  合并后的 libc 命名空间里两份 `export const CLOCKS_PER_SEC` 是同一个名字，单 TU 只 emit
  一份所以 `make check` 看不到问题，但 split-C 下每个模块各出一个 `.o`、两个都带外部定义，
  链接期报 `multiple definition of 'CLOCKS_PER_SEC'`（`uya-agent` 那类 33+ 文件工程必然
  复现）。按 C 标准（`CLOCKS_PER_SEC` 属于 `<time.h>`），常量只由 `libc.time` 提供，
  `libc.stdlib` 不再定义第二份；名字仍留在合并后的 libc 命名空间里，`use libc.CLOCKS_PER_SEC`
  用法不变。

### 新特性

- **async：hosted 多线程并发 `malloc/free` 堆损坏修复（P0）**。根因是
  `lib/libc/pthread.uya` 的 `clone` 不含 `CLONE_SETTLS`，子线程只用
  `arch_prctl(ARCH_SET_GS)` 设了 GS、从不建立 FS/TLS，而 hosted 模式把 `malloc/free`
  让给了宿主 glibc（per-thread tcache/arena 挂在 FS 上），于是所有 uya 线程共用父线程的
  glibc TLS。修法是 hosted 下保留 uya 自己的线程安全堆（`lib/libc/heap.uya`），
  `libc.stdlib` 的 `calloc` 一并留在 uya 侧避免跨分配器错配。新增回归
  `tests/test_pthread_heap_concurrency.uya`（8 线程 × 800 轮 `malloc/free`）。
- **async：`Waker` 多 fd / 多 interest**。原先单 fd / 单 interest 会让「同时等两个 fd」
  退化成只等最后一个；现扩为有界槽表（`WAKER_IO_SLOT_MAX = 4`，同 fd 的 RD|WR 合并成
  `READWRITE`，不同 fd 各占一槽），`_io_fd`/`_io_interest` 保留为「最后一次声明」的主槽镜像，
  单 fd 调用点行为不变；`async_scheduler` 新增 `SchedulerFdRegs` 记录每个已注册 fd，遍历全槽
  注册并对陈旧注册做差集注销。新增回归 `tests/test_async_waker_multi_interest.uya`。
- **async：HTTP/1 客户端连接池 + keep-alive 复用**。修复前每个请求都发
  `Connection: close`、用完即关（N 个请求 = N 次 TCP，HTTPS 还要 N 次握手）。新增进程内单例
  `Http1AsyncPool`（有界 8 个空闲槽，按 host 字节 + port 精确匹配，池满或 host 超长时关 fd
  而不是截断误配）；`Http1AsyncRequest.persist`（默认 0 = 旧行为）控制是否走 keep-alive；
  响应头解析新增 `Connection: close` 识别，`http1_async_finish_connection` 只在
  「调用方要求 persist + 响应非 `read_until_eof` + 未声明 close」时回池。新增
  `http1_async_pool_stats` / `_close_all` / `_put_raw` / `_take_raw` 观测入口与
  `tests/test_http1_async_client.uya` 三个用例。
- **TLS 1.2 会话复用（会话 ID 路径）**。新增 `TlsSessionCache` 按 host 缓存会话，同 host 的
  后续连接可在 ClientHello 里带会话 ID 请求复用；服务器认同后把缓存的 `master_secret`
  装回上下文。新增回归 `tests/test_tls_session_resumption.uya`。
- **async：macOS `kqueue` 后端**。导出 `sys_kqueue()` / `sys_kevent()`（非 macOS 目标返回
  `error.NotSupported`），macOS 分支走 kqueue、失败回退 poll，Linux 路径不变。新增回归
  `tests/test_async_event_kqueue_transition.uya`；运行时行为尚待真机验收（本机无 macOS）。
- **HTTP/1 响应头块上限可配置**。新增 `http1_async_response_header_max_cap()`
  （默认 65536，`UYA_HTTP1_RESPONSE_HEADER_MAX_CAP` 可覆盖，非法值回退默认），
  与 `LinuxEpoll` / `AsyncFramePool` / `Scheduler` 的既有口径一致。

## v0.10.2 - std.process 进程流水线、typed pipeline 落地与偶发红定位

> 发布日期：2026-09-27

### 概要

**v0.10.2** 在 **v0.10.1** 的 async runtime 动态资源与 UPM/package 工作流基础上，把两条新主线推到端到端可发布口径，并把"偶发红"逐个定位到具体机制：

1. **`std.process` 进程与流水线运行时收口**：stage stream 抽象、owned erased stage 生命周期、exec worker stage、child broker 隔离与信号/终端作业控制、capture 策略与取消、spawn 失败分类与结构化诊断。
2. **typed pipeline 端到端**：checker 诊断（首个形参非 `Pipeline`、非 `Pipeline` 左值、sink-after-chain 等）、lowering 所有权转移与错误路径清理、C99 codegen，以及 `std.script` process facade。
3. **`std.path` 与检查器/编译器修复**：平台条件与目录模块别名统一（含交叉目标验证）；边界证明器 `as usize` 范围事实、有符号下标下界与约束名悬垂指针修复；hosted stdio、模块作用域同名函数查找、macOS 交叉宿主绑定与微应用发射修复。
4. **偶发红与发布闸门**：pthread join 早释放线程栈导致的偶发 SIGSEGV（`clear_child_tid` + 共享 `FUTEX_WAIT` 退出确认）；自举种子陈旧导致的 `make release` 冷启动链接失败；`RLIMIT_NOFILE` 软上限 1024 环境把 fd 密集用例的环境限制报成回归。

详见 [docs/releases/RELEASE_v0.10.2.md](./docs/releases/RELEASE_v0.10.2.md)。

### `std.process` / 流水线运行时

- 新增 stage stream 抽象与 owned erased stage 计划，明确 stage 间所有权与析构顺序；新增 exec worker 上的 Uya stage 执行与实验性 fork-backed stage 闸门。
- child broker 隔离、信号 disposition 保留、子进程信号状态清理；覆盖中断信号路由、停止作业取消与终端作业控制（前台所有权）。
- capture 策略与取消语义收敛，stdio remap 加固并让内部 fd 保持在 stdio 之上；spawn 失败分类与结构化启动诊断补齐回归。

### typed pipeline / `std.path`

- checker 诊断补全并归档：首个形参不是 `Pipeline`、非 `Pipeline` 左值参与管道、sink-after-chain、实例方法接收者与合成左值冲突。
- lowering 收口：成功路径转移所有权、错误路径清理输入计划、`try` 前向传播；新增 lowering dump / 诊断验证脚本。
- `std.path` 平台条件（Linux / macOS / Windows）与目录模块别名统一，新增 `tests/verify_std_path_platform_targets.sh` 交叉目标验证。

### 检查器 / 编译器 / 运行时

- 边界证明器：范围事实跨 `as usize` 传递、有符号源 `as usize` 下标下界判定、成员访问约束名悬垂指针（负哈希跳过池化导致结果随变量名变化）修复；配套正向回归 `tests/test_bounds_prover_as_usize_cast.uya` 与负例 `tests/error_array_bounds_signed_cast_lower_bound.uya`。
- 编译器：hosted stdio 符号统一到模块前缀、模块作用域同名函数查找、macOS 交叉目标宿主绑定、微应用 payload 与宿主辅助符号泄漏修复；split-C 缓存锁验证补齐。
- 运行时：pthread join 早释放线程栈导致的 use-after-unmap（偶发 SIGSEGV，#139）修复，新增 `tests/test_pthread_join_stack_reuse.uya`。

### 发布流程

- 刷新自举种子（`backup/*.c`）并修复由此暴露的冷启动链接失败（`uya_pipeline_worker_dispatch` 未定义）。
- 测试脚本把 `RLIMIT_NOFILE` 软上限提升到硬上限；`test_async_event_dynamic_growth` 自身也会先抬够 fd 预算，环境确实不足时明确报 `skip:` 而不是失败。
- UPM 运行时版本号对齐到 `0.10.2`（此前停在 `0.10.0`，影响 `upm --version` 与 `uya_min_version` 门控）；min_version 失败用例改用当前发行线达不到的版本号断言，不再与发布版本号耦合。
- 全量单文件测试 1110/1110 通过；`bin/uya` 以 `-O3 -fno-builtin -DNDEBUG` 构建并 strip。

## v0.10.0 - fmt CLI 收口、if expression 与 C99 主线稳定性

> 发布日期：2026-06-04

### 概要

**v0.10.0** 在 **v0.9.9** 的 WebSocket / HTTP/2 / exec VM 稳定性基础上，把开发工具链与 C99 后端继续推到可发布口径：

1. **`fmt` CLI / API 收口**：完成 phase4 命令行集成，保留注释与 doc comment，稳定 import sort、simplify、rewrite 与 idempotent 行为。
2. **语言与 C99 路径增强**：新增 if expression 的 parser / checker / C99 codegen 路径，并补齐 bare `catch` statement、const pointer 与若干 codegen 回归。
3. **发布种子与 split-C 稳定性**：刷新 backup seeds，修复 split-C cache 清理、Makefile 依赖与私有函数命名冲突，继续保持自举输出与 C99 种子一致。

详见 [docs/releases/RELEASE_v0.10.0.md](./docs/releases/RELEASE_v0.10.0.md)。

### fmt 工具链

- `lib/std/fmt/*.uya` 与 `tools/fmt.uya` 完成 CLI/API 收口，覆盖 tokenization、parser、printer、comments、import sort、simplify 与 rewrite。
- 新增 / 扩展 `tests/test_fmt_*.uya` 与 `tests/verify_fmt_cli.sh`，锁定注释保真、doc comment 附着、语句注释附着、导入排序与幂等格式化。

### 语言 / 编译器

- `src/parser/primary.uya`、`src/checker/check_expr.uya` 与 C99 codegen 支持 if expression。
- C99 后端修复 monomorphized method、typed route generic method、struct array field member copy、async frame descriptor、empty slice zero-init、private function name collision 与 VP8 short payload codegen 回归。
- `src/compile.sh` 与 Makefile 补齐 split-C cache cleanup、Makefile dependency 与 release seed 刷新路径。

## v0.9.6 - microapp 结果面 / 能力契约收口与 CLI 设计同步

> 发布日期：2026-05-12

### 概要

**v0.9.6** 在 **v0.9.5** 的 microapp hosted 多平台闭环基础上，继续做补丁线收口：

1. **runtime / trap 结果面统一**：hosted loader、native fallback 与 unwired 路径统一到单一 bridge ABI 与 `payload result=` 输出口径。
2. **`.uapp required_caps` 正式生效**：镜像声明的能力位图现在会映射为 `SYS_IO` 设备与操作白名单，宿主桩对未知 capability bit 明确拒绝。
3. **发布契约继续锁定**：Linux toolchain / payload symbol 合约与 microapp 文档继续收口，同时同步 `cmd` 子命令拆分设计文档，给后续 CLI 重构提供稳定基线。

详见 [docs/releases/RELEASE_v0.9.6.md](./docs/releases/RELEASE_v0.9.6.md)。

### microapp / 运行时契约

- `lib/kernel/sim.uya`、`lib/std/runtime/microapp/loader.uya` 统一 trap runtime bridge ABI 与 loader 结果输出；hosted loader / native fallback / unwired 路径统一使用单行 `payload result=` 结果面。
- 新增 / 扩展 `tests/verify_microapp_result_surface.sh`、`tests/verify_microapp_trap_runtime.sh`、`tests/verify_microapp_trap_bridge_result.sh`、`tests/verify_microapp_loader_unwired_profile.sh`，锁定 `ok / exit / fault / validated / unwired` 结果口径。
- 新增 `tests/verify_microapp_payload_symbols.sh`，继续拒绝 payload 直接泄漏宿主 libc 普通符号，并锁定 Linux microapp runtime P0 合约。

### 能力模型 / SYS_IO

- 新增 `lib/kernel/capability.uya`，定义 `KERNEL_CAP_IO_*` 与已知能力位校验。
- `lib/kernel/dispatch.uya` 根据 `.uapp` 头部 `required_caps` 建立 `SYS_IO` 设备与操作白名单，未知能力位直接拒绝。
- 新增 `tests/test_kernel_dispatch.uya`，扩展 `tests/test_kernel_sim.uya`，覆盖 capability validate、device/op 授权与宿主桩行为。

### 文档与后续 CLI 收口

- `docs/microcontainer/README.md`、`docs/microcontainer/microapp_profiles.md`、`docs/microcontainer/portable_native_design.md`、`docs/microcontainer/syscall_abi.md` 同步当前 bridge / result / capability 契约。
- `docs/cmd_subcommand_split_design.md` 与 `docs/todo_cmd_subcommand_split.md` 对齐当前 CLI 拆分设计与待办，作为下一阶段 `build/run/test` / image 子命令收口基线。

## v0.9.5 - microapp hosted 多平台真执行闭环

> 发布日期：2026-05-02

### 概要

**v0.9.5** 将 **v0.9.0 - v0.9.4** 已经铺开的 microapp / 微容器链路推进到 hosted 多平台真执行闭环，同时收口同期落地的 HTTP / UyaGin 与编译器修复：

1. **Portable MicroApp ABI / `.uapp v2` / Profile / bridge / result model 规格冻结**：微容器镜像、profile 与结果面不再继续频繁改名或改字段。
2. **发布闸门与 CI 口径统一**：`make microapp-check`、`make microapp-hosted-smoke` 与平台专属 runtime 检查形成稳定组合，`linux_x86_64_hardvm` 真执行链路成立，`linux_aarch64_hardvm` 与 `macos_arm64_hardvm` 具备 host-gated 回归入口。
3. **同期功能面并入发行线**：纳入 UyaGin P5、最小 HTTPS -> UyaGin 桥接，以及 direct err-union await bind 的 async lowering 修复。

详见 [docs/releases/RELEASE_v0.9.5.md](./docs/releases/RELEASE_v0.9.5.md)。

### HTTP / UyaGin / 编译器 async lowering（2026-04-25）

- `std.http.parse/types/server` 与 `std.http.uyagin` 完成 UyaGin P5 主链路：Header 小写/哈希缓存、8-byte word-at-a-time 扫描、chunked request 原地解码、显式 chunked response、`writev` 聚合写，以及 Linux x86_64 `sendfile` 优先文件发送。
- `tls.https` 新增最小 `https_server_serve_uyagin_once` 桥接，可将 TLS 握手后的 HTTP 请求交给 `std.http.uyagin.Engine`。
- C99 async lowering 修复 direct err-union await bind：`const r: !T = @await fut;` 现在能正确切段、恢复并在后续 `catch` / 表达式中保留错误联合类型。
- 回归新增 / 扩展：`tests/test_async_await_direct_err_union.uya`、`tests/test_http_parse.uya`、`tests/test_http_server.uya`、`tests/test_http_uyagin.uya`、`tests/test_https_loopback.uya`。

## v0.9.4 - microapp 运行时收口、`@embed` / `@c_import` 与标准库扩展

> 发布日期：2026-04-22

### 概要

**v0.9.4** 在 **v0.9.x** 发行线上继续推进 “可发布、可验证、可移植” 这条主线：

1. **microapp / 微容器运行时链路继续收口**：补齐 mapped payload、reloc / bss / fault / exit-code / recovery 路径，新增 `inspect-image` / `verify-image` / profile-first 默认解析，并用聚合脚本覆盖样例源码、镜像、运行时与恢复流程。
2. **语言与构建能力补齐**：新增 `@embed` / `@embed_dir`，完成 `@c_import` 构建集成；同时修复 macro 展开后的切片表达式 codegen 崩溃，并改进 codegen 输出缓冲与 release / zig / gcc 构建路径。
3. **标准库继续扩展**：新增 `std.sql` 抽象、`std.mqtt.async`，并为 `std.crypto` 补上 BLAKE2b / BLAKE2s / MD5 / CRC32。

`./tests/run_programs_parallel.sh --uya --c99` **828** 项测试通过，`make b` 自举验证通过，`make release-clean` 通过。详见 [docs/releases/RELEASE_v0.9.4.md](./docs/releases/RELEASE_v0.9.4.md)。

### microapp / 工具链

- `src/main.uya`：新增 / 完善 `pack-image`、`inspect-image`、`verify-image`、microapp profile 默认推导与诊断输出。
- `lib/std/runtime/microapp/loader.uya`、`lib/kernel/image.uya`、`lib/kernel/sim.uya`、`lib/kernel/recovery.uya`：收口 mapped payload、relocation、BSS、fault / trap、recovery / update 与 host API 诊断路径。
- `Makefile`、`src/compile.sh`：修复 release / release-clean、zig / gcc、`run` / `test` 与 hosted cross-build 工作流问题；补充 host-specific seeds 与 macOS hosted 交叉构建支持。

### 语言 / 编译器

- `src/parser/primary.uya`、`src/main.uya`：新增 `@embed` / `@embed_dir` 内建能力与配套 CLI / codegen 路径。
- `src/compile.sh`、`tests/link_cimports_posix.sh`：完成 `@c_import` 的 sidecar / split-C 构建集成。
- `src/main.uya`：补齐 `-v` / `--version`，使 CLI 版本查询与文档保持一致。
- `src/codegen/c99/expr.uya`、`src/codegen/c99/function.uya`、`lib/std/io/file.uya`：修复 macro 展开切片表达式 codegen SIGSEGV，并改进 codegen 输出缓冲与 async / split-build 稳定性。

### 标准库

- `lib/std/sql/*.uya`：新增 `std.sql` 抽象层与文档。
- `lib/std/mqtt/async.uya`：新增 async MQTT 客户端基础模块。
- `lib/std/crypto/*.uya`：新增 BLAKE2b / BLAKE2s / MD5 / CRC32 实现。

### 测试与文档

- 新增 / 扩展 `tests/test_embed_builtin.uya`、`tests/test_c_import_file.uya`、`tests/test_c_import_dir.uya`、`tests/test_std_sql.uya`、`tests/test_std_mqtt_async.uya`、`tests/test_macro_slice_expr_codegen.uya` 及多组 microapp 验证脚本。
- 更新 `readme.md`、`docs/TESTING.md`、`docs/UYA_BUILD_RUN.md`、`docs/c_import_design.md`、`docs/embed_design.md`、`docs/std_sql.md`、`docs/std_mqtt_async.md` 等文档。
- 新增 `docs/releases/RELEASE_v0.9.4.md`

---

## v0.9.3 - `@frame(foo)` 类型构造器与 pinned 语义

> 发布日期：2026-04-14

### 概要

**v0.9.3** 在异步帧分配基础设施之上，引入 `@frame(foo)` 类型构造器及其完整的 checker 语义：

1. **`@frame(foo)` 类型构造器**：解析器支持 `@frame(fn_name[<T>])` 语法，类型检查器将其解析为对应 async 函数的状态机结构体类型 `uya_async_<fn>`。
2. **无初始化声明**：`@frame` 类型变量允许无显式初始化（`var f: @frame(foo);`），由声明点负责分配/零初始化。
3. **Pinned 语义检查**：async frame 类型被视为 pinned，禁止按值移动、整体赋值、按值传参和按值返回。
4. **C99 前向声明**：codegen 在函数原型中自动为 `@frame` 参数/返回类型生成 `struct uya_async_xxx;` 前向声明，避免跨 TU 编译失败。

`make check` **785** 项测试通过（新增 5 项），`make b` 自举验证通过。评审后修复：补全方法调用路径的 pinned 参数检查，修复 export async 函数 frame struct 命名不一致。详见 [docs/releases/RELEASE_v0.9.3.md](./docs/releases/RELEASE_v0.9.3.md)。

### 语言特性

- `src/lexer.uya`：将 `@frame` 加入内置函数白名单。
- `src/parser/types.uya`：解析 `@frame(fn_name[<T>])` 为 `AST_TYPE_FRAME`。
- `src/parser/statements.uya`：`@frame(...)` 类型变量允许无初始化声明。
- `src/checker/type_from_ast.uya`：`AST_TYPE_FRAME` 解析为 `TYPE_STRUCT("uya_async_<fn>")`；校验目标为 `@async_fn`、泛型实参数量匹配、实参 concrete。
- `src/checker/check_node_extra.uya`：赋值语句中禁止对 pinned 类型整体赋值和按值移动。
- `src/checker/check_stmt.uya`：变量声明禁止用 pinned 类型按值初始化。
- `src/checker/check_call.uya`：函数调用禁止按值传递 pinned 类型参数。
- `src/checker/main.uya`：return 语句禁止按值返回 pinned 类型。

### 代码生成

- `src/codegen/c99/types.uya`：新增 `c99_emit_async_frame_forward_for_type`，递归扫描类型中的 `@frame` 并生成 C 前向声明；`AST_TYPE_FRAME` 生成 `struct uya_async_<cname>`。
- `src/codegen/c99/function.uya`：`gen_function_prototype`、`gen_method_prototype`、`gen_mono_method_prototype` 在原型发射前调用前向声明 helper；修复 `c99_async_collect_locals_recursive` 使无初始化的 `@frame` 局部变量也能被提升到状态机字段。

### 测试

- 新增 `tests/test_async_frame_type.uya`（3 项正向测试）
- 新增 `tests/error_async_frame_pinned_move.uya`
- 新增 `tests/error_async_frame_pinned_arg.uya`
- 新增 `tests/error_async_frame_pinned_return.uya`

### 文档

- 更新 `docs/async_frame_allocation_design.md`、`docs/todo_async_frame_allocation.md`
- 新增 `docs/releases/RELEASE_v0.9.3.md`

---

## v0.9.2 - 测试基础设施：并行测试独立目录与实时输出

> 发布日期：2026-04-12

### 概要

**v0.9.x** 补丁：改进并行测试脚本与 `make tests` 体验。

1. **独立输出目录避免冲突**：基于测试文件相对路径生成唯一 ID，每个单文件/多文件测试用例拥有独立的编译输出目录，彻底消除同名 `.uya` 文件在并行运行时的产物覆盖问题。
2. **实时结果输出**：后台测试每完成一个立即输出 `✓` / `❌`，不再等全部跑完才汇总；通过 `stdbuf -oL` 自动处理非 TTY 环境（如 `make`/`CI`）的行缓冲，解决 `make tests` 看不到实时进度的问题。
3. **`make tests` 去掉 `--hide-pass`**：默认模式下通过的测试也会实时显示，与直接运行脚本行为保持一致。

`make check` **779** 项测试通过。详见 [docs/releases/RELEASE_v0.9.2.md](./docs/releases/RELEASE_v0.9.2.md)。

### 测试基础设施

- `tests/run_programs_parallel.sh`：新增 `generate_test_id()`、`process_ready_single_results()`；重构编译产物路径与流水线式结果收集逻辑；顶部增加 `stdbuf -oL` 自举逻辑。
- `Makefile`：`tests:`、`tests-hosted:`、`tests-uya:` 移除 `--hide-pass`。

### 文档与版本字符串

- 新增 `docs/releases/RELEASE_v0.9.2.md`
- 编译器帮助中的版本字符串更新为 **v0.9.2**

---

## v0.9.1 - 修复 `@async_fn` 变量提升与嵌套块初始化 bug

> 发布日期：2026-04-12

### 概要

**v0.8.x** 补丁：修复编译器在 `@async_fn` 状态机 lowering 中的两类关键 bug：

1. **变量提升容量不足**：`async_local_*` 数组硬编码为 16 条目，导致像 `http1_request_async` 这种拥有大量局部变量的函数在 lowering 时丢失后续局部，生成未定义局部引用的 C 代码。
2. **嵌套块内 hoisted 变量未初始化**：`while`/`if` 等不含 `@await` 的嵌套控制流中的 `const` 指针被 hoist 到状态机字段后，`gen_var_decl_stmt` 仍将其生成为普通局部变量，而后续引用已映射为 `s->_uya_loc_xxx`，导致该字段在 resume 路径上为未初始化（null），运行时 SIGSEGV。

同时修复了 `@async_fn` 中 `return error.X` 与 `as!` 强制类型转换在泛型上下文下的 payload 类型单态化问题。所有 HTTP/HTTPS 测试（14 项）全部通过，`make check` **779** 项测试通过。详见 [docs/releases/RELEASE_v0.9.1.md](./docs/releases/RELEASE_v0.9.1.md)。

### 编译器

- `src/codegen/c99/internal.uya`：`async_local_names` / `async_local_types` / `async_local_inits` / `async_local_root_stmt` / `async_param_names` 从 16 扩至 32。
- `src/codegen/c99/function.uya`、`global.uya`、`types.uya`、`utils.uya`：将所有硬编码 `16` 改为 `@len(...)` 动态检查。
- `src/codegen/c99/stmt.uya`：`gen_var_decl_stmt` 在 async poll 上下文中，若变量已被 hoist 到 `async_local_names`，直接生成状态机字段初始化（`s->_uya_loc_xxx = init`）；数组类型额外处理 `memset`/`memcpy`。
- `src/codegen/c99/stmt.uya` / `expr.uya`：`return error.X` 与 `as!` 的 payload C 类型通过 `c99_mono_type_to_c` 正确单态化泛型参数。

### 标准库

- `lib/std/http/http1_async.uya`：移除 `catch` 块内多余分号；重新启用此前被 TODO 绕过的 `http_check_deadline(deadline_ms)` 超时检查。
- `lib/tls/https.uya`：修复 `catch` 块语法与 `as!` 溢出使用方式（先提取 `.value` 再运算）。

### 文档与版本字符串

- 新增 `docs/releases/RELEASE_v0.9.1.md`
- 编译器帮助中的版本字符串更新为 **v0.9.1**

---

## v0.8.2 - 主线程栈上限改为应用显式设置

> 发布日期：2026-03-31

### 概要

**v0.8.x** 补丁：`std.runtime.entry` 不再在 C `main` 中固定提高 `RLIMIT_STACK`；新增 **`set_process_stack_limit_bytes`**，应用按需调用；编译器在 **`main_main`** 内根据 **`--stack-size`** 调用该函数；`make check` **698** 项测试通过。详见 [docs/releases/RELEASE_v0.8.2.md](./docs/releases/RELEASE_v0.8.2.md)。

### 文档与版本字符串

- 新增 `docs/releases/RELEASE_v0.8.2.md`
- 编译器帮助中的版本字符串更新为 **v0.8.2**

---

## v0.8.1 - v0.8.0 发行线补丁：TFLM、epoll HTTP、压测与稳定性

> 发布日期：2026-03-30

### 概要

自 **v0.8.0** 起的**补丁版本**，在同一发行线下合并 TFLM 标准库与多后端（含 CMSIS-NN）、`std.http` 非阻塞与 epoll 路径、`http_bench_async` 与基准脚本、全局数组字符串字面量初始化、编译器与 pthread / nostdlib / 自举对比等修复；`make check` **697** 项测试通过。详见 [docs/releases/RELEASE_v0.8.1.md](./docs/releases/RELEASE_v0.8.1.md)。

### 文档与版本字符串

- 新增 `docs/releases/RELEASE_v0.8.1.md`
- 编译器帮助中的版本字符串更新为 **v0.8.1**

---

## v0.8.0 - 里程碑：异步运行时、std.http、多文件 C99 与工具链

> 发布日期：2026-03-25

### 概要

自 **v0.7.4** 起的里程碑版本（**~379** 次提交），`make check` **658** 项测试通过。

### 新特性与重大改进

- **异步运行时**：`@async_fn` 状态机大小与转换验证、多 fd 调度、`MpscChannel` / `RingQueue`、`ThreadPool` 扩展；泛型异步与 C99 单态修复。
- **std.http**：TCP、解析、路由、阻塞服务器、Keep-alive / 流水线、multipart、JWT（HS256 + `exp`）与 SHA-256（无 OpenSSL）；压测程序与 Go 对照基准。
- **C99 后端**：默认多文件输出与镜像 TU、`--no-split-c`；切片形参按值；vtable 与自举对比修复；codegen/SIMD 性能与缓存。
- **工具链**：`--nostdlib` 与 Makefile/种子流程；`build` / `run` / `test` 子命令；默认更大堆栈、默认 `--safety-proof`；字符串 `\xHH` / `\uXXXX` 转义。
- **标准库**：`IAllocator` / `Arena`、`Vec` / `HashMap` 等与分配器协同；`std.json` 编码写路径优化。

### 文档与发布

- 新增 `docs/releases/RELEASE_v0.8.0.md`
- 编译器 `--version` / 帮助中的版本字符串更新为 **v0.8.0**

---

## v0.7.4 - P1/P2 可选任务实现

> 发布日期：2026-02-24

### 新特性

#### P1 任务

- **越界访问检测（bounds_check_pass）**
  - 在 `checker/proof.uya` 中实现编译期静态分析
  - 检测数组访问越界风险
  - 检测指针算术越界风险
  - 检测切片边界越界风险
  - 支持 `BoundsCheckRisk` 枚举（SAFE/WARNING/ERROR）

#### P2 任务

- **指令融合优化（instruction_fusion_pass）**
  - 在 `checker/optimizer.uya` 中实现指令融合框架
  - 检测可融合的连续算术指令
  - 检测乘加融合（MAC）模式
  - 为后续优化提供分析基础

- **冗余指令消除（redundant_instruction_elimination_pass）**
  - 在 `checker/optimizer.uya` 中实现冗余指令检测
  - 检测 nop 等无副作用指令
  - 检测自移动指令（如 mov r0, r0）
  - 寄存器生命周期分析框架

- **RISC-V 平台扩展支持**
  - 新增 `TYPE_ASM_REG_RISCV_V` 类型（向量扩展）
  - 新增 `TYPE_ASM_REG_RISCV_F` 类型（单精度浮点）
  - 新增 `TYPE_ASM_REG_RISCV_D` 类型（双精度浮点）
  - 更新 `is_riscv_reg_type()` 函数支持新类型
  - 更新 `asm_reg_type_name()` 函数支持新类型

### 新增函数

- `check_array_bounds_const()` - 检测数组访问越界（常量索引）
- `check_pointer_arithmetic_bounds()` - 检测指针算术越界
- `check_slice_bounds()` - 检测切片边界越界
- `bounds_check_pass()` - 全程序越界访问检测 Pass
- `can_fuse_arithmetic_instructions()` - 检测指令融合机会
- `instruction_fusion_pass()` - 指令融合优化 Pass
- `detect_redundant_instruction()` - 检测冗余指令
- `analyze_register_lifecycle()` - 寄存器生命周期分析
- `redundant_instruction_elimination_pass()` - 冗余指令消除 Pass
- `optimize_asm_block()` - @asm 块综合优化入口

### 测试

- 新增 `tests/programs/test_bounds_check.uya` 测试文件
- 所有 462 个现有测试通过

---

## v0.7.3 - 编译期优化功能完善

> 发布日期：2026-02-24

### 新特性

- **优化级别命令行选项**
  - `--opt=<0-3>` 设置优化级别
  - `-O0`, `-O1`, `-O2`, `-O3` 简写形式
  - 默认优化级别为 1（常量折叠 + 死代码消除）

### 优化级别说明

| 级别 | 功能 |
|------|------|
| 0 | 禁用优化（调试模式） |
| 1 | 常量折叠 + 死代码消除（默认） |
| 2 | + 证明优化 |
| 3 | + 内联 + 循环展开（未来） |

### 修复

- **修复 Lexer 不支持三元运算符导致的优化器解析问题**
  - 问题：lexer 遇到 `?` 返回 `TOKEN_EOF`，导致 parser 提前终止
  - 影响：`optimizer.uya` 中三元运算符后的函数定义全部丢失
  - 修复：将三元运算符改为 if-else 语句
  - 同时修复了被掩盖的 TokenType 名称错误：
    - `TOKEN_AND_AND` → `TOKEN_LOGICAL_AND`
    - `TOKEN_OR_OR` → `TOKEN_LOGICAL_OR`
    - `TOKEN_EQUAL_EQUAL` → `TOKEN_EQUAL`
    - `TOKEN_BANG_EQUAL` → `TOKEN_NOT_EQUAL`
  - 修复 ASTNodeType 和字段名错误：
    - `AST_INDEX_EXPR` → `AST_ARRAY_ACCESS`
    - `bool_value` → `bool_literal_value`

### 文档更新

- 更新 `docs/compile_time_optimization_status.md` 状态文档

---

## v0.7.2 - @asm 测试覆盖率完善

> 发布日期：2026-02-23

### 测试

- **@asm 功能测试覆盖率 100%**
  - 新增 9 个正向测试文件，覆盖基础功能、类型系统、clobbers、边界情况等
  - 新增 17 个反向测试文件，覆盖语法错误、类型错误、限制检查等
  - 修复了类型检查器中 `AST_ASM` 节点作为语句使用时未进行类型检查的 bug

### 新增测试文件

**正向测试（9 个）：**
- `test_asm_basic.uya` - 基础功能：简单指令、无输入输出、多输入多输出
- `test_asm_types.uya` - 类型系统：i8/i16/i32/i64/u8/u16/u32/u64/usize/指针
- `test_asm_clobbers.uya` - clobbers 声明：单/多寄存器、memory、混合
- `test_asm_edge_cases.uya` - 边界情况：空指令、最大输入/输出、控制流中使用
- `test_asm_codegen.uya` - 代码生成验证
- `test_asm_expressions.uya` - 表达式：变量、常量、数组元素、结构体字段
- `test_asm_duplicate_output.uya` - 多输出变量测试
- `test_asm_const_output.uya` - 输出测试
- `test_asm_void_output.uya` - 无输出测试

**反向测试（17 个）：**
- `error_asm_empty_block.uya` - @asm 块不能为空
- `error_asm_missing_string.uya` - 期望指令字符串
- `error_asm_invalid_input_type.uya` - f32 输入类型错误
- `error_asm_invalid_output_type.uya` - f64 输出类型错误
- `error_asm_output_pointer.uya` - 指针不能作为输出
- `error_asm_f64_input.uya` - f64 输入类型错误
- `error_asm_f64_output.uya` - f64 输出类型错误
- `error_asm_missing_paren.uya` - 语法错误：缺少 '('
- `error_asm_missing_close_paren.uya` - 语法错误：缺少 ')'
- `error_asm_missing_brace.uya` - 语法错误：缺少 '{'
- `error_asm_missing_close_brace.uya` - 语法错误：缺少 '}'
- `error_asm_too_many_inputs.uya` - 输入超过最大限制
- `error_asm_too_many_outputs.uya` - 输出超过最大限制
- `error_asm_void_input.uya` - void 类型输入错误
- `error_asm_struct_input.uya` - 结构体输入错误
- `error_asm_array_input.uya` - 数组输入错误
- `error_asm_slice_input.uya` - 切片输入错误

### 修复

- 修复 `src/checker/main.uya`：`AST_ASM` 节点作为语句使用时未调用类型检查

---

## v0.7.1 - 切片字面量 & 语法增强

> 发布日期：2026-02-21

### 新特性

- **切片字面量**：支持从数组字面量直接创建切片
  - `const slice: &[i32] = &[1, 2, 3];`
  - `const slice: &[i32] = &[0: 10];`
  - 无需先声明数组变量，直接创建切片

- **match 表达式省略分号**
  - 当所有分支都是 block 时可省略分号
  - 提升代码流畅性和可读性

### 改进

- 类型推断增强：变量声明时正确推断切片类型
- 代码生成优化：切片字面量生成高效的 C99 复合字面量

---

## v0.7.0 - 编译器重构 & 性能优化

> 发布日期：2026-02-21

### 重构（阶段一：模块拆分）

**checker.uya 拆分为 16 个文件：**
- `types.uya` - 类型定义 (224 行)
- `symbols.uya` - 符号表操作 (668 行)
- `type_utils.uya` - 类型工具函数 (481 行)
- `lookup.uya` - 查找函数 (452 行)
- `generics.uya` - 泛型单态化 (177 行)
- `proof.uya` - 安全证明 (331 行)
- `type_from_ast.uya` - 类型解析 (335 行)
- `check_expr.uya` - 表达式检查 (1465 行)
- `check_stmt.uya` - 语句检查 (754 行)
- `check_call.uya` - 调用检查 (747 行)
- `interval.uya` - 区间算术 (1027 行)
- `check_expr_extra.uya` - 表达式辅助 (824 行)
- `check_node_extra.uya` - 节点检查 (641 行)
- `modules.uya` - 模块系统 (1197 行)
- `macro_expand.uya` - 宏展开 (1168 行)
- `main.uya` - 检查器入口 (610 行)

**parser.uya 拆分为 6 个文件：**
- `types.uya` - 类型解析 (599 行)
- `primary.uya` - 基础表达式 (2393 行)
- `expressions.uya` - 二元/一元表达式 (925 行)
- `statements.uya` - 语句解析 (616 行)
- `declarations.uya` - 声明解析 (2200 行)
- `main.uya` - 解析器入口 (479 行)

### 内存优化（阶段二）

- **Arena 按需增长**：动态分配新 chunk，避免静态分配浪费
- **静态内存减少 75%**：320MB → 81MB

### 性能优化（阶段三）

- **作用域链表优化**：符号表查找从 O(32768) → O(当前作用域符号数)
- **自举编译时间**：8.2s → 1.8s（提升 4.5 倍）
- **字符串池**：减少字符串比较开销

### 修复

- 修复 `fprintf` 参数类型警告

### 代码统计

| 模块 | 文件数 | 总行数 |
|------|--------|--------|
| checker | 16 | 10,978 |
| parser | 6 | 7,212 |
| codegen/c99 | 10 | ~8,000 |

---

## v0.6.0 - 统一测试框架 & CLI 重构

> 发布日期：2026-02-20

### 新特性

- **统一命令行接口**：`uya build`、`uya run`、`uya test` 子命令
- **统一测试框架**：`test "name" {}` 语法，自动收集和运行测试
- **自动入口检测**：编译器自动检测 `test` 和 `export fn main`
- **--nostdlib 模式**：静态链接，零依赖可执行文件
- **编译阶段计时**：显示各编译阶段耗时

### 修复

- `try` 表达式在 void 函数中正确工作

---

## v0.5.9 - 错误处理增强

### 新特性

- 错误联合类型 `!T` 改进
- 预定义错误集支持

---

## v0.5.8 - 接口系统

### 新特性

- 鸭子类型接口
- 零注册，编译期生成

---

## v0.5.7 - 泛型系统

### 新特性

- 泛型语法 `<T>` 支持
- 泛型约束 `<T: Trait>`
- 泛型单态化

---

## v0.5.5 - 内存安全

### 新特性

- 编译期内存安全证明
- 指针非空追踪
- 移动语义检查

---

## v0.5.4 - Union 类型

### 新特性

- 联合体（union）类型
- 编译期标签跟踪
- C union 100% 互操作

---

## v0.5.3 - 模块系统

### 新特性

- 目录级模块
- 显式导出 `export`
- 路径导入 `use`

---

## v0.5.0 - 初始发布

### 核心特性

- 零 GC
- 默认高级安全
- 单页纸可读完
- 无 lifetime 符号
- 无隐式控制
- 编译期证明
