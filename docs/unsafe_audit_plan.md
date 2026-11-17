# 不安全面审计与冻结计划：让「不安全之处必须显式」可执行

**状态：P0 登记器已落地（统计上报），白名单冻结与 CI 闸门待实现。**
本文只描述**当前真实状态**与**下一步可执行动作**，不描述愿景。

---

## 0 这份文档回答什么

目标是把「审计过的 unsafe 之外零 UB」变成一条**可执行、可 diff、可冻结**的工程线，
而不是靠人工印象判断「我们安全了没有」。要回答三个问题：

1. 编译器眼里，**能绕过证明的构造**到底有多少、分布在哪？
2. 这些构造里，哪些是**不可消除的硬底**（机器码、C 互操作），哪些是**可收窄的债**？
3. 怎么把这份清单变成**会失败的 CI**，而不是一份会腐烂的文档？

---

## 1 已有事实（可复跑）

`--lifetime-report` 现在除了跨函数证明的度量，还打一段 **escapes** 统计。
复跑命令（必须先 `export UYA_ROOT=$PWD/lib`，否则 `use std.*` 解析失败、统计恒为 0）：

```sh
export UYA_ROOT=$PWD/lib
./bin/uya check --lifetime-report src/main.uya 2>&1 | grep -E '^\[(lifetime|escapes)\]'
```

**实测（2026-11-16，`src/main.uya` 依赖闭包）：**

```
[lifetime] req_total=3075 req_resolved=2665 req_unresolved=410
[lifetime] req_param_null=2582
[lifetime] req_div_zero=493
[escapes] extern_fn=511 extern_var=386
[escapes] asm=8
[escapes] union=1 extern_union=0
[escapes] ptr_int=197
[escapes] ptr_cast=35552
[escapes] alloc=66
```

### 1.1 字段含义与判定口径

| 字段 | 判定口径 | 性质 |
|---|---|---|
| `extern_fn` | `fn_decl_is_extern != 0` 的声明数（含 `extern "libc"`） | **硬底**：编译器看不到实现，只能信任 |
| `extern_var` | `AST_EXTERN_VAR_DECL` 声明数 | **硬底**：同上 |
| `asm` | `@asm` 块数 | **硬底**：机器码，无法证明 |
| `union` / `extern_union` | `union` 声明数 / 其中 `extern union` 数 | **硬底**：类型系统不跟踪活跃变体 |
| `ptr_int` | `@ptr_from_usize` + `@usize_from_ptr` + **指针 → `usize`/`isize` 的 cast** | **洞**：整数可以算术，能凭空造地址 |
| `ptr_cast` | 目标类型是指针的 cast（`"fmt" as *byte`、`p as &void`） | **债**：来源没变，只是类型系统看不见 |
| `alloc` | callee 名为 `malloc`/`free`/`calloc`/`realloc` 的调用 | **债**：所有权面 |

**口径的重要取舍（必须写下来，否则后人会误读）：**

- `ptr_int` 第一版把**所有整数宽化 cast**（`x as i64`、`i as usize`）都算了进去，
  得到 37k 条 —— 那是噪声，不是逃逸口。第二版只认「涉及指针的那一侧」，
  但仍是 35785 条。**第三版（2026-11-17）把它拆成两笔**：
  `ptr_int` = 真正的整数↔指针桥（`@ptr_from_usize`、`@usize_from_ptr`、
  指针 → `usize`），`ptr_cast` = 目标是指针的换类型 cast。
  实测 `src` 闭包：**`ptr_int` 197（从 35785 降下来）**、`ptr_cast` 35552。
  也就是说原先那个「35785 条指针转换」里，**真正能把指针变成可运算整数的只有 197 条**，
  其余 99.4% 是 `"fmt" as *byte` 这类 FFI 形参适配 —— 它们依然是审计面（白名单按文件
  冻结，新增即失败），但不该和「能凭空造地址」混为一谈。
- `ptr_cast` 的口径是**目标侧判定**，不区分源是整数还是指针：语法层看不出来，
  判类型要付出全量推断的代价。`(addr as usize) as &T` 这种真正的伪造会落在
  `ptr_cast` 里，靠白名单冻结 + 人工评审兜底 —— 这一点必须明说，不能假装它被机器分了类。
- `alloc` 只认**裸调用形态**（callee 是标识符且在名单里）。方法调用 `x.free()`
  与函数指针别名不在统计内 —— 宁可少数，不要伪造「已覆盖」的假象。
- `functions`：2026-11-17 起在逃逸口登记器（唯一遍历全部函数体的入口）里计数，
  `src` 闭包实测 3229。此前该字段恒为 0（字段声明了却从未累加）。

---

## 2 哪些是硬底、哪些是债

| 类别 | 实测规模 | 能否消除 | 处置 |
|---|---|---|---|
| `extern_fn` + `extern_var` | 897 | ❌ 不能（libc/syscall 是语言的宿主） | **冻结 + 审计**：每条 extern 声明必须在白名单里 |
| `@asm` | 8 | ❌ 不能 | **冻结 + 人工审**：仅内核/启动/原子原语 |
| `union` | 1 + 0 extern | ❌ 不能（C 互操作与 tag 分派的基础） | **冻结**：新增 union 需理由 |
| `ptr_int` | **197**（原 35785） | ⚠️ 部分能收窄 | **逐个收**：每条都是整数↔指针，能造地址；量级已小到可以逐个看 |
| `ptr_cast` | 35552 | ⚠️ 大部分必要（FFI 形参适配） | **冻结增量**：`"fmt" as *byte` 属于写法噪声，改不动也不该改 |
| `alloc` | 66 | ⚠️ 部分能收窄（走 arena 分配器） | **迁移到 arena**：编译器自有代码不应直接 malloc |

**`ptr_int` 那 197 条分布（2026-11-17 实测，按文件）**：`src/exec/vm.uya` 121、
`src/codegen/c99/function.uya` 20、`src/exec/value.uya` 14、`lib/std/string/string.uya` 8，
其余零散在 libc/stdlib/checker。本轮已清掉 40 条：20 处
「指针身份比较」原来写成 `@usize_from_ptr(a as &void) == @usize_from_ptr(b as &void)`，
现在直接用 `a == b`（Uya 本来就支持指针相等比较）—— 既少了两条整数↔指针桥，
也不再依赖「地址转成整数后仍相等」这个隐含假设。
抽查 vm.uya 的形态：`@usize_from_ptr(vm.slot_pool as &void)` 存基址、
`@ptr_from_usize(aligned) as &ExecValue` 取槽位、`@ptr_from_usize(waker_addr)` 取 await 单元 ——
**这些是解释器把地址当整数值保存的设计后果**，不是随手写的转换：VM 的值表示、
运行期缓冲对齐、await 唤醒单元都以 `usize` 承载地址。
要把这 197 降下去，方向是「给 VM 一个地址类型并让它参与证明」，
不是逐个改写法 —— 所以本计划的降债目标定在**消失即提示收紧、不再增加**，
而不是追求归零。

**结论：硬底部分（extern + asm + union）合计约 900 条声明级站点，是人工可审计的量级。
债分两层：`ptr_int` 197 条（真能造地址，值得逐个收）、`ptr_cast` 35552 条
（FFI 形参适配，冻结增量即可）。2026-11-17 之前这两个数是混在一起报的
（35785），把「能凭空造地址」和「换个类型名」混为一谈，导致既无法排优先级、
也无法衡量降债进度。**

---

## 3 白名单冻结与 CI 闸门（**已落地**）

### 3.1 组成

| 部件 | 位置 | 作用 |
|---|---|---|
| 逐站点清单 | `./bin/uya check --escape-list <root>` | 打 `[escape] <kind> <file>:<line>`，只列不报 |
| 审计根清单 | `docs/unsafe_audit_roots.txt` | 41 个根，逐个跑再按 `(kind,file)` **取最大值**合并 |
| 闸门脚本 | `tests/verify_unsafe_audit.sh` | 聚合成 `kind<TAB>file<TAB>count` 与基线对比 + 覆盖闸门 |
| 冻结基线 | `docs/unsafe_baseline.txt` | 314 个 `(kind,file)` 组，可 diff |
| CI 挂钩 | `make unsafe-audit`（也在 `make check` 里） | 新增/增加即失败 |
| 重冻结 | `make unsafe-baseline-update` | 更新基线，diff 需在评审里解释 |

### 3.1b 为什么要多个审计根（2026-11-17 补）

只用 `src/main.uya` 一个根时，审计面 = **编译器自己的依赖闭包**。标准库里
http / websocket / tls / jpeg / kernel / tflm 这些模块编译器根本不导入，
它们的逃逸口一个都没进白名单 —— 「审计过的 unsafe 之外零 UB」这句话当时对
这 40 个文件根本不成立，只是没人报出来。

现在 `docs/unsafe_audit_roots.txt` 列出 41 个根（编译器 + 40 个补漏模块），
脚本逐个跑 `--escape-list` 后**按 `(kind,file)` 取最大值**合并：

- 求和会虚高 —— 同一文件会出现在多个根的闭包里；
- 按行去重会漏数 —— 一行里写两次 `@usize_from_ptr`（指针身份比较常见形态）
  会被并成一处。

`--update` 全量重冻结：站点 36721 → **38166**，组数 163 → **314**，
耗时 12.9 s（41 个根，std 模块都很小）。

**覆盖闸门（新增，§3.4 有复跑命令）**：分母取「源码文本里含有逃逸构造的文件」
（剥掉注释、不算方法调用形态），分子取「本次审计实际见到的文件」，
差集非空即失败。它挡的是**漏审计**而不是逃逸口变多：新写一个带 `extern fn`
的模块，只要没有根导入它，上面所有对比都不会察觉 —— 白名单永远是
「我看过的那些文件」，看不见的文件等于不存在。

写这条闸门踩过的两个坑（都写进脚本注释了）：

- 分母用 `grep -q` 配 `set -o pipefail` 会因 SIGPIPE 把「匹配位置靠前的文件」
  静默丢掉（42 个漏成 10 个）；
- 分母不剥注释会把文档注释里提到的 `extern "libc" fn exp(...)` 当成真逃逸口
  （`src/exec/hir.uya` 就是这么被误报的）。

### 3.2 为什么按 `(kind, file, count)` 而不是 `file:line`

行号在每次插入注释时都会漂移 —— 按行号冻结会让基线在正常开发中天天失效，
最后所有人都会无脑重生成它，闸门退化成仪式。按 `(kind,file)` 计数冻结：

- 对**行漂移免疫**，对**新增同类构造敏感**（计数变化即差异）；
- 代价是「同文件内删 1 加 1」察觉不到 —— 这条已知盲区在 §5 里列明，
  缓解手段是「文件级新增」仍然会被抓（新文件/新类别一定失败）。

路径也做了归一化（剥 `./` 前缀、剥 `$UYA_ROOT` 前缀），使基线不依赖
调用者把 `UYA_ROOT` 给成相对还是绝对路径。

### 3.3 判定：刻意非对称

| 情况 | 结果 | 理由 |
|---|---|---|
| 出现基线里没有的 `(kind,file)` | **失败** | 新增不安全面，必须评审 |
| 某组计数 > 基线 | **失败** | 同文件里多开了逃逸口 |
| 某组计数 < 基线 / 某组消失 | 通过 + 提示「可收紧」 | 基线偏松只是报表偏差，不是漏洞 |

**为什么「可收紧」不失败**：它不构成安全回归，而把它做成红灯会让日常重构
常年红着，最终导致基线被无脑重生成 —— 那才是真正的失效模式。
反过来，「任何新增都过不去」正是这条线要守住的性质。

### 3.4 判据（可复跑）

```sh
./bin/uya check --escape-list src/main.uya 2>&1 | grep -c '^\[escape\]'   # 单根 36721
./tests/verify_unsafe_audit.sh      # 41 个根取并集，38166 站点 / 314 组；基线一致 ✓
./tests/verify_unsafe_audit.sh --update                                 # 重新冻结
```

已验证的五个方向：

| 方向 | 构造 | 结果 |
|---|---|---|
| 基线调低 | 手改 `src/arena.uya` 的 `alloc` 计数 | 失败并打出 `逃逸口增加: alloc src/arena.uya 2 -> 4` |
| 基线少一行 | 删掉某组 | 失败（NEW） |
| 基线调高 | 某组 +2 | 通过 + 提示可收紧 |
| 新逃逸口 | 在 `lib/std/env.uya` 加 `extern fn audit_probe_new_escape() i32;` | 失败：`新增逃逸口: extern_fn lib/std/env.uya（1 处）` |
| 漏审计 | 新建 `lib/std/audit_probe_hidden.uya` 带 `extern fn`，无根导入 | 失败：`未被审计的逃逸文件: lib/std/audit_probe_hidden.uya` |

后两条是 2026-11-17 补的（前三条 2026-11-16），探针用完即删，
`git diff` 干净 —— 闸门的有效性不能只靠「它现在绿」。

---

## 4 与跨函数证明（B1–B5）的关系

两条线**互补，不重叠**：

- 跨函数证明（`docs/interprocedural_proof_plan.md`）：**缩小需要证明的面积** ——
  让原本证不出的事实（非空、非零、下标上界、悬垂）变成可证的。
- 本文的审计线：**让证明不了的地方现形并冻结** —— 不追求把它们证出来，
  追求「一条都不许悄悄新增」。

上游若只做前者，会永远面对「剩下的 20% 怎么办」；只做后者，则安全等级不会提高。
两者合起来才有「审计过的 unsafe 之外零 UB」这个可交付的结论。

---

## 5 已知缺口（诚实清单）

- **文件内对冲盲区**：基线按 `(kind,file)` 计数，同一文件里「删 1 加 1」察觉不到。
  能抓到的是「新文件 / 新类别 / 计数净增」。要消灭这个盲区需要按行冻结，
  而按行冻结的维护成本会让基线腐烂（见 §3.2 的取舍），暂不做。
- ~~`functions=0`~~：2026-11-17 已接线（在逃逸口登记器里计数），`src` 闭包实测 3229。
- ~~`ptr_int` 未区分必要与可消除~~：2026-11-17 已拆成 `ptr_int`（197，整数↔指针）
  与 `ptr_cast`（35552，指针换类型）。仍然存在的盲区：`ptr_cast` 按**目标侧**判定，
  `(addr as usize) as &T` 这类伪造会落在 `ptr_cast` 里，靠白名单冻结兜底而非机器分类。
- `alloc` 只认裸调用（`free(p)`），不覆盖方法调用与函数指针别名。
- ~~没有 ASan/UBSan 交叉验证~~：2026-11-17 补上了 **UBSan 交叉验证**（见 §5.1），
  并且它立刻抓到一个真实的读越界 + 一个证明系统缺口。
- **ASan 在本项目不可用**（不是没做，是做不了）：编译器自己用裸 syscall 做
  `mmap`/`setrlimit`，ASan 靠拦截 libc 管理影子内存，两者一撞就是启动即段错误
  （实测 `ASAN_OPTIONS=verbosity=1` 连 `--version` 都走不完）。UBSan 不需要影子内存，
  所以可用。
- UBSan 版二进制只能跑 `check`，跑 `build`/`run` 会在 fork/exec 工具链那段段错误
  （已确认非断言、非本次改动导致：同一份 C 用普通方式编译就正常）。所以
  **代码生成/运行期路径的 UBSan 证据仍缺**，目前只覆盖类型检查与逃生口登记。
- 逃逸口登记只在 `--lifetime-report` / `--escape-list` 下运行，
  **默认编译不做任何登记**（零成本，但也意味着它不是一个默认强制的检查）。

### 5.1 UBSan 交叉验证（2026-11-17）

做法：把编译器源码生成成 hosted 单文件 C（`src/build/uya-hosted.c`），用

```sh
gcc -std=c99 -O1 -g -fno-builtin -fwrapv -fno-strict-overflow \
    -fsanitize=undefined -fno-sanitize-recover=undefined \
    -o /tmp/uya-ub src/build/uya-hosted.c -lm -lpthread
```

编译（`-fno-sanitize-recover` 让任何 UB 直接中止，而不是打一行继续跑），再

```sh
ulimit -s 32768
/tmp/uya-ub check --lifetime-report src/main.uya
UYA_COMPILER=/tmp/uya-ub ./tests/run_programs_parallel.sh
```

结果：

| 跑法 | 结果 |
|---|---|
| `check --lifetime-report src/main.uya` | **零 UB 报告**（报告各字段与普通二进制一致） |
| 全量 1212 例 | 1211 通过，1 例报 `index 64 out of bounds for type 'uint8_t *[64]'` |

那 1 例（`tests/test_async_param_capacity_dynamic.uya`，实参数正好 65）暴露了
`c99_generate_call_expr` 读 `interp_arg_temp_names[i]` 越界 —— 已修（见 buglist），
修完该用例通过、`make b` 自举字节一致。

**边界必须说清楚**：UBSan 只覆盖「跑到的那些路径」（本次是编译器自身的 check + codegen），
而且 UBSan 版二进制只能跑 `check`，`build`/`run` 会在 fork/exec 工具链那段段错误
（同一份 C 普通编译就正常，非本次改动导致）。真正把静态清单和运行期对上的做法是
给**生成的程序**也加 UBSan/ASan（需要 `CC=clang -fsanitize=...` 的工具链支持），
目前没做 —— 这是本计划剩下的最大未验证假设。
