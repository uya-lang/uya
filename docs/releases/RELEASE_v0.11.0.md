# Uya v0.11.0 发布说明

> **类型**：**里程碑发行**（minor）
> **发布日期**：2026-10-23

**v0.11.0** 在 **v0.10.4** 的编译器容量收口与密码学底座之上，收口三条主线：
一是**安全证明**——`--strict-overflow` 由默认关翻为**默认开启**，并新增 `--strict-div`
除零正确性证明；二是**一批「静默错误」**——lexer 未知字符、`@print` / 插值格式串、
大于 `INT64_MAX` 的整数字面量、接口字段访问、数组/切片比较，这些缺陷的共同特征是
**不报错但算错**；三是**平台与构建链**——macOS hosted 生成 C 的 7 处 ABI 撞车修复，
自举种子家族恢复可交叉编译，未安装 zig 的宿主不再把 `make check` / `make release`
判成失败。

---

## 核心变更

### 1. `--strict-overflow` 翻为默认开启（破坏性变更）

整数 `+` `-` `*` 必须能证明不溢出，否则编译错误。证明器基于 i64 宽化区间
（`checker_prove_no_overflow` + `src/checker/interval.uya` 的 `wide_*`），只采纳**可信约束**
（用户守卫、无回绕的 `i = i + c`、常量初始化）；由抽象区间计算出的区间内部用 u32 位模式回绕，
一律视为不可信，避免把真实溢出判成安全。只覆盖有符号整数——无符号是良定义模运算，不是 UB。

翻默认的前提是**存量已清零**：`src/` 与 `lib/` 全部按语义迁移完毕（饱和 `+|` / 回绕 `+%` /
`catch`），开启后告警归零。`tests/` 是**对抗性语料库**，由 `tests/run_programs_parallel.sh`
显式传 `--no-strict-overflow` 豁免——否则负例夹具会被「治好」，检测能力本身被销毁。

诊断给出三条修法：checked 算术（`try`/`catch`）、区间守卫前置、饱和包装。

### 2. 新增 `--strict-div` 除零正确性证明（默认关闭）

整数 `/` 与 `%` 的除数必须能证明非零，否则报「除数可能为 0，无法证明 … 安全」。
判定复用 `--strict-overflow` 的 i64 宽化区间：除数区间不含 0 才算证明成立。常量除数与
区间守卫（`if d <= 0 || d >= N { ... }`）可通过；常量除零无论开关都报错。

**为什么默认关**：存量库大量依赖「调用方保证非零」的跨函数不变量——`align_size(size, align)`、
牛顿迭代 `n / guess`、`bytes_read / size`——证明器无法表达，强制开启会直接让编译器无法自举。
这与 `--strict-overflow` 当初的处理路线一致：先默认关，迁移完成后翻默认。

回归 `tests/verify_strict_div.sh`（已挂进 `make check`），正例 `tests/test_strict_div.uya`，
负例夹具 `tests/repros/strict_div_negative.uya`。

### 3. 静默错误收口

这一批缺陷的共同特征是**不报错、只是算错**，症状都出现在离真实原因很远的地方。

- **lexer 遇未知字符静默返回 EOF**。`#` / `\` / `?` 这类不在词法表里的字符会让 parser 把
  剩余输入当成文件正常结束：`uya check` 退出码 0、零输出，`uya build` 整段丢弃后续声明。
  现在报「无法识别的字符 '<c>'（ASCII n），位于第 L 行第 C 列」并置 `lexer.has_error`，
  错误正确传播为退出码 1。负例 `tests/error_lexer_unknown_char.uya`。
- **`@print` / `@println` / 字符串插值按错误的 printf 转换符输出实参**。`i32` 负值被当无符号
  打印（`-7` → `4294967289`）、`i16` 的 `-300` → `4294966996`、`f64` 的 `-1.5` → 指针值、
  插值 `"pi=${pi}"` → `-1963457608`、`*` 动态宽度静默产出 `%426d`。现在由 checker 在插值段上
  记录 `format_kind`（1=有符号整型 2=无符号整型 3=浮点 4=字节指针 5=切片），C99 后端据此选
  转换符并发射**与之匹配**的变参实参类型；字节数组 / 字节切片 / 字节指针按 C 字符串 `%s` 输出；
  `*` 改为编译期拒绝。回归 `tests/test_println_bytes_ptr_slice.uya`、
  `tests/test_print_builtin_format.uya`，负例 `tests/error_interp_dynamic_width.uya`。
- **大于 `INT64_MAX` 的整数字面量被 `strtoll` 饱和**。`0xbb67ae8584caa73bu64`（SHA-512 的 IV）
  与 `0xFFFFFFFFFFFFFFFF`（P-256 素数 p 的 limb）被钳成 `INT64_MAX`，codegen 按位拆分后变成
  `0xFFFFFFFF + (0x7FFFFFFF << 32)`，导致 SHA-512 / P-256 / P-384 / RSA / ECDSA 全部算错
  （8 个 crypto/TLS 测试集体失败）。现在一律 `strtoull` 解析后按二补数转 i64 保存位模式。
- **接口类型的两处非法形态改为编译期拒绝**。接口值直接访问字段（须先经类型断言取具体类型）、
  把具体结构体赋给接口数组元素，此前静默生成非法 C（`has no member named 'fd'` /
  `incompatible types`）。接口值自身的 `vtable` / `data` 字段仍放行——`std.async` 的 `Future`
  依赖它。负例 `tests/error_interface_field_access.uya`、
  `tests/error_interface_array_elem_assign.uya`。
- **数组 / 切片的比较运算符静默产生错误结果**。数组在 C 侧退化成首元素指针比较
  （`[1,2,3] == [1,2,3]` 运行期是 false），切片则发射非法的 `struct == struct`。现在
  `==` `!=` `<` `>` `<=` `>=` 遇到数组或切片一律编译期报错，指向 `std.mem.mem_cmp`
  或显式逐元素循环。
- **普通用户程序被 pipeline worker 入口抢先接管**。C99 后端在 `container_mode == 0` 时总会
  发射弱桥接 `uya_pipeline_worker_dispatch()`，它先于 `main_main()` 执行，此前只按 argc/argv
  判断——恰好带一个 `--uya-pipeline-worker` 参数的普通程序会被误判成 worker，随后读未 dup2 过的
  描述符失败并返回退出码 122，用户程序根本没跑。现在入口先用 `fcntl(F_GETFD)` 自检两个保留 fd，
  只有真正由 exec 侧 dup2 过的进程才走 worker 分支。回归
  `tests/verify_pipeline_worker_entry_guard.sh`。
- **未证明的有符号溢出不再落入 C UB**。构建（`Makefile` / `src/compile.sh`）、驱动默认 `CFLAGS`
  与生成的 split-C Makefile 统一加 `-fwrapv -fno-strict-overflow`，溢出退化为定义良好的回绕。
  实测 `2147483647 + 1` 由 `-fsanitize=undefined` 报 `signed integer overflow` 转为干净通过。
- **`lib/libc/stdio.uya` 的 `%d` 无法格式化 `INT32_MIN`**（只输出一个负号）。幅值此前用
  `num = 0 - num` 取反，`INT32_MIN` 的相反数不可表示，回绕后仍为负数，数字循环一次不进。
  改用 u32 二补数取负。该 bug 被 `-fwrapv` 现形——此前靠 UB 侥幸输出正确。
- `gen_return_error_union` 的「标识符名含 result 即视为错误联合」启发式会误判
  `return result;`（`result: i32`，函数返回 `!i32`）并生成非法 C；改为类型判定优先于名字猜测。

### 4. macOS hosted：7 处 ABI 撞车修复，种子家族恢复可交叉编译

`struct timeval` / `struct sigaction` / `signal` / `sa_handler` 与 Darwin 系统头同名撞车；
`__attribute__((weak))` 在 Mach-O 上不成立（可选符号改走 `dlsym`）；`libc.signal` 整族误用
Linux syscall 号与信号编号表。修复后 macOS x86_64 / arm64 两套架构重新可交叉编译并链接，
自举种子家族恢复，Linux 侧行为未变。

### 5. 构建与 CI：zig 变为可选

`Makefile` 曾把 `ZIG` 默认写死成一台开发机的绝对路径，而
`tests/verify_std_path_platform_targets.sh` 在缺 zig 时直接 `exit 1`——没装 zig 的 CI
（ubuntu-ci 跑 `make release`）必然红。现在 `ZIG` 默认从 PATH 解析（解析不到留空），
同源的六处硬编码一并改掉；std.path 的 windows 目标在缺 zig 时**保留「生成 C 通过」**、
交叉编译与运行显示 `⊘ 跳过`（与既有的 wine 缺省处理一致）并在结尾汇总跳过项；
`TOOLCHAIN=zig` 但找不到 zig 时给出明确错误。

---

## 升级指南

1. **先跑一次 `uya check --strict-overflow`**（现已默认开启）：无法证明不溢出的 `+` `-` `*`
   会报错。按诊断修：checked 算术（`try`/`catch`）、区间守卫前置、或饱和 `+|` `+%`。
   存量工程可以 `--no-strict-overflow` 过渡，但建议尽快迁移。
2. **`/` 与 `%` 暂不受影响**：`--strict-div` 默认关闭，无需改动；想要额外保障可显式开启。
3. **检查数组 / 切片的比较**：`a == b`（数组或切片）现在是编译错误，改用
   `std.mem.mem_cmp` 或逐元素循环。
4. **检查 `@print` / 插值输出**：过去的错值已修正，若有测试断言了旧的错误输出（如
   `@println(-7)` 期望 `4294967289`），需要更新。
5. **接口字段访问**：`iface.field` 现在是编译错误，先做类型断言取具体类型；`vtable` / `data`
   仍可直接访问。

---

## 统计与验证

- 自举：`make uya` 通过，`make b` 自举字节一致。
- 测试：`make check` **1185 / 1185** 通过（Linux x86_64）。
- 负例：新增 6 个 `tests/error_*.uya`，均按预期编译失败。
- 验证脚本：`tests/verify_strict_div.sh`、`tests/verify_pipeline_worker_entry_guard.sh`
  已挂进 `make check`。
- CI 条件复验：PATH 中不含 zig 时同样 1185 / 1185，std.path 的 windows 目标按预期 `⊘` 跳过。

---

## 已知限制

- **`--strict-div` 默认关**：证明器无法表达「调用方保证非零」的跨函数不变量，强制开启会破坏
  自举。迁移路径与 `--strict-overflow` 相同：先补齐存量，再翻默认。
- **`--strict-overflow` 覆盖范围**：只覆盖有符号 `+` `-` `*`；`/` `%` 由 `--strict-div` 单独管，
  无符号运算不纳入（良定义模运算）。
- **macOS 验证范围**：本次只做到「生成 C + 交叉编译 + 链接」；`kqueue` 后端仍未在真机验收。
- **Windows 验证范围**：仍是「交叉编译 + wine 运行」，未做真机全量回归；IOCP 后端未落地。
- **`make b` 之外的自举种子**：种子家族已随本版刷新；若手工改动 `src/` 后只跑 `make uya`，
  记得 `make backup-all` 同步种子，否则 `make from-c` 冷启动会用旧种子。

---

## 致谢

感谢所有为本版本安全证明、静默错误收口、macOS 交叉链与构建健壮性贡献的参与者。

---

**标签**：`v0.11.0`
**下载 / 发行页**：[GitHub Releases](https://github.com/uya-lang/uya/releases/tag/v0.11.0)
**完整变更日志**：[CHANGELOG.md](../../CHANGELOG.md)
