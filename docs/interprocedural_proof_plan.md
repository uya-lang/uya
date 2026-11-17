# 跨函数内存安全证明：评估与施工图

**状态：方案，未实现。** 本文不改任何代码，只回答四件事：

1. 在**零新语法**（不加标注、不加 `'a`、不改文法）的前提下，跨函数证明能买到什么；
2. 买不到什么（明确清单，防止下一轮高估）；
3. 形式化规则与**健全性边界**（哪里必须降级为 `UNKNOWN`，为什么）；
4. 怎么分段落地、每段的判据与回退点。

**范围之外的近邻文档：**

- 数组/切片/指针**边界**证明的完整施工图在 `docs/array_safety_proof_plan.md`（A 一致性 → B 符号上界 → C 循环不变式 → D 可伸缩性）。本文只与它的 **B 阶段共用一块地基**（差分约束 + `#len(x)` 符号），不复述其内容。
- `docs/uya.md` §14「内存安全」当前明确写着「证明范围仅限当前函数内」「编译器不跨函数进行证明」。本文是**改这条结论的方案**，不是既成事实；`uya.md` 在实现落地前**不应**修改。

行号以函数名为准（会漂移）。所有基线数字见 §12，命令可逐条重跑。

---

## 1 结论摘要

- **可行**：把「函数内凭空要证的事实」换成「编译器推导的契约（summary）」，证明义务沿调用栈上行，最终落在**某个有真实守卫的地方**。人一行标注都不用写。
- **能买 6 类**：悬垂引用（今天 971 个返回指针的函数、1019 个指针字段、289 处 `return &` 一处不查）、非空前提（替代今天「所有指针形参无条件非空」的 blanket 假设）、非零前提（把 `--strict-div` 翻默认为开，111 处 `/` `%` 站点获得保护）、返回值的下标/长度后置事实（下标证明里「事实来自被调方」的那一半）、非逃逸形参解锁移动、以及 shadow 报告本身。
- **买不到**：循环不变式（197 处 `while x < y.len`，buglist ③）、非线性下标、别名/并发数据竞争、use-after-free 与 double free 的失效判定、extern 与 async 的真实语义（逐条见 §8）。
- **代价**：检查器时间 +8%~15%（可实测、可降级），新增约 4k 行，最大风险是误报而非实现难度。
- **最短闭环 14 人日**：P0 度量 → P1 地基 → B3 非零义务（`--strict-div` 翻默认）。这一步就能给出两个确定答案：跨函数消解率、误报绝对数量。全量约 62 人日。

---

## 2 证据基线

测量日期 2026-04-29，工作树基于 `49014a20`。全部为**静态粗测下界**（grep 计数，不是运行期探针），命令见 §12。

| 站点类别 | 数量 | 在本方案里的角色 |
|---|---|---|
| `.uya` 文件（`lib/` + `src/`） | 297 | 扫描规模 |
| `fn` 声明总数 | 5950 | 摘要计算规模 |
| 带指针形参的签名（`lib/`） | 2865 | B2 非空义务的受影响面 |
| **返回指针的函数**：`&T` 842 + `!&T` 102 + 切片 27 | **971** | B1 悬垂检查的受检面（今天零检查） |
| **指针类型的结构体字段** | **1019** | 逃逸的第二通道（字段写），今天零检查 |
| `return &…` | 289 | B1 抽样面（见下方分布） |
| 切片形参签名 / `&arr[i]` / `@len(` | 396 / 3771 / 283 | 下标与长度事实的输入面 |
| `/` 与 `%` 站点 | 58 + 53 = **111** | B3 直接受检面 |
| `while x < y.len` | 197 | **明确不受益**（buglist ③） |
| `>= 0` 守卫 | 891 | B4「事实来自被调方」的需求面代理指标 |
| `extern "libc"` 声明 | 528 | 信任边界 |
| `malloc` / `free` / `fn drop(self` | 44 / 158 / 12 | 所有权面 |
| `interface` 声明 / 函数指针调用 | 1 / 0 | 动态派发面：可直接按 `UNKNOWN` 处理 |
| `getenv(` | 57 | B2 的误报风险面 |
| `test_*` / `error_*` / `repros` | 914 / 211 / 21 | 回归规模 |

**`return &…` 的形态分布**（`grep -rEho "return *&[^;]*"` 后按首标识符分类）：

| 形态 | 数量 | origin 归属 | 收口后是否放行 |
|---|---|---|---|
| `&k.…`（如 `lib/kernel/sim.uya:179` `return &k.host_ctx.pts[0]`） | 144 | `PARAM`（`k` 是形参） | ✅ 放行 |
| `&ctx` | 51 | `PARAM` | ✅ 放行 |
| `&r` / `&out` / `&s` | 32 | 多为 `PARAM`，少数局部 | 视 origin |
| 单标识符（`lib/std/mem/allocator.uya:75 return &g_allocator`、`lib/libc/stdlib.uya:1170 return &readdir_result`） | 7 | `STATIC`（顶层 `var`） | ✅ 必须放行 |
| 其余（`&self.…`、`&scope.…` 等） | 55 | `PARAM` 派生 | ✅ 放行 |

这张表是本方案**第一条硬约束**的来源：`STATIC` 与 `PARAM` 必须判为「可逃逸」，否则自举会被 289 处里的合法形态立刻打穿。`readdir`/`strerror` 这类**故意返回全局缓冲**的 C 风格约定不能被判错——它们是非重入但合法。

---

## 3 为什么零语法可行

Uya 的身份是「无 lifetime 符号 · 无隐式控制 · 本函数内编译期证明 · 单页纸可读完」。跨函数证明有三种做法：

| 做法 | 代表 | 与 Uya 身份的关系 |
|---|---|---|
| 生命周期类型参数 | Rust `'a` | ❌ 直接冲突（身份第一条就是"无 lifetime 符号"），且要和泛型、`Self`、接口方法签名相乘 |
| 人写契约（require/ensure） | SPARK、Dafny、Frama-C ACSL | ❌ 需要谓词表达式文法 + 名字解析 + 类型检查 + 契约漂移维护；单页纸放不下 |
| **编译器推导摘要**（本文） | 思想来自模块化验证的 assume-guarantee，形体接近 Infer 的 summary | ✅ 零语法；证明引擎仍是"本函数内"那一台，摘要只是它的**接口** |

关键洞察：**「跨函数」不等于「跨函数推理」**。推理永远发生在单个函数体内；跨函数传递的只有**已经证过的结论**（warranty）和**尚未证过的前提**（requirement）。所以：

- 证明引擎不用换（沿用 `src/checker/interval.uya` 的约束/区间/线性式那套）；
- 人不用学新东西（错误信息里直接给出规范化谓词）；
- 身份宣言要改的只有一句：「证明范围仅限当前函数内」→「证明范围 = 当前函数体；函数之间的传递只走编译器推导的摘要，人不写任何标注」。

---

## 4 形式化

本节是施工的直接依据。伪代码用 Uya 风格书写，标注为「伪代码」，不是可编译代码。

### 4.1 Origin 格

值的「来源」是一个有限格：

```
Origin ::= UNKNOWN            // 不可判定：extern 返回值、cast、@asm、union 变体、函数指针
         | LOCAL(scope_id)    // 局部栈对象（数组、结构体、变量）
         | PARAM(i)           // 第 i 个形参所指向的存储（由调用点实例化）
         | HEAP               // malloc / arena 分配（寿命由 free 显式结束）
         | STATIC             // 顶层 var/const、字符串字面量、static 缓冲

偏序：  UNKNOWN ⊑ LOCAL(s) ⊑ PARAM(i) ⊑ HEAP ≡ STATIC
        （⊑ 读作"更不确定"；HEAP 与 STATIC 同层：都不随栈帧结束而失效）

join(o1, o2) =
    o1 == o2                     → o1
    {LOCAL(a), LOCAL(b)}, a≠b    → LOCAL(min(a,b))       // 取更外层，保守
    {PARAM(i), PARAM(j)}, i≠j    → UNKNOWN
    任何含 UNKNOWN               → UNKNOWN
    HEAP 与 STATIC               → HEAP                  // 两者的"∞"等价，取更宽的
```

性质：格高度有限（4 层 + 作用域嵌套有限），配合 §4.6 的单调 transfer，不动点必收敛。

**为什么不做字段敏感**：指针类型结构体字段有 1019 个，字段敏感会让状态数按字段路径乘积爆炸；而且 drop 侧已经用访问路径字符串解决了「字段被移走后谁负责清理」（`src/checker/symbols.uya:1565 moved_access_path_contains`，见 buglist 条目②的修复）。origin 只记**是否派生自同一底层存储**，不记偏移：

```
派生：derive(o) = o          // &arr[i]、&s.f、s[0:4]、p.f 都只是派生，不改变"谁的存储"
```

代价：`&a.x` 与 `&a.y` 被视为同源（可能漏报"字段 x 被 free 后 y 仍用"这种罕见场景）；收益：状态数不爆、误报可控。这条取舍必须写进实现注释，避免后人以为漏了。

### 4.2 transfer 函数表

摘要与检查都建立在「表达式 → origin」的传播上。逐节点定义：

| 表达式形态 | 结果 origin | 备注 |
|---|---|---|
| `&x` | `origin(x)` | 局部数组/结构体 → `LOCAL(当前 scope)` |
| `&arr[i]` | `origin(arr)` | 3771 处，仓库里最常见的取址形态 |
| `&s.f` / `&s.f.g` | `origin(s)` | 一层或多层字段都等价 |
| `x[start:len]`（`AST_SLICE_EXPR`） | `origin(x)` | 切片是视图，不拥有存储 |
| `s[i]`（读到指针元素） | `derive(origin(s))` | 存的是指针值时，来源跟随容器 |
| `p.f`（指针自动解引用后取字段） | `derive(origin(p))` | 不改变底层存储归属 |
| `f(args)` | 实例化 `callee.ret_origin` | 见 §4.5 |
| `try f(args)` / `f(...) catch` | 同上（错误联合解包不改变 origin） | |
| `x as &T` / `as *void` / `as usize` 往返 | `UNKNOWN` | 不做同一指针的无损识别（可后置优化，不进第一版） |
| union 变体字段读 | `UNKNOWN` | 活跃变体不可静态确定 |
| `@asm` 输出操作数 | `UNKNOWN` | |
| 字符串字面量 | `STATIC` | |
| `null` | `STATIC`（空指针不指向任何存储；非空性另由 §4.5 处理） | |
| 其余（算术、比较、`@len` 等） | 非指针，无 origin | |

### 4.3 生命周期比较

```
lifetime(STATIC)   = ∞
lifetime(HEAP)     = ∞        // 由 free 显式结束；free 之后的判定见 §5.6
lifetime(PARAM(i)) = 由调用点把实参 origin 代入后得到
lifetime(LOCAL(s)) = s 的 scope 层级

outlives(o1, o2) ⇔ lifetime(o1) ⊇ lifetime(o2)
作用域比较用现成的 scope 层级：checker.scope_level
（`src/checker/symbols.uya:1147 checker_enter_scope` / `:1156 checker_exit_scope`）
```

**注意**：今天 `Symbol` 里只有 `scope_level`，没有能区分"同一层级的两次进入"的稳定 id（循环体的同一 scope 每轮复用）。所以要新增 `scope_id`（单调递增，enter 时压栈），并把 `Symbol.scope_id` 一并记下。这是 P1 的第一件事，改动小、收益贯穿全篇。

### 4.4 三处判定点

只有三种语法位置需要判「寿命不足」：

1. **`return`**（`src/checker/main.uya` 的 `AST_RETURN_STMT` 分支）：
   `origin(return_expr)` 若为 `LOCAL(当前函数任意 scope)` 且返回类型含指针/切片/接口 → 报「返回指向局部存储的引用」。
   - 放行：`STATIC`、`HEAP`、`PARAM(i)`（`PARAM` 的合法性由**调用点**负责，见 §4.5）。
   - 这正好收口 buglist P1 的三条复现（返回局部数组、返回局部数组的切片、返回装箱的局部结构体）。
2. **写入更长寿命的容器**：
   - 写结构体字段 `s.p = e`：要求 `outlives(origin(e), origin(s))`；
   - 写全局 `g_p = e`：要求 `origin(e) ∈ {STATIC, HEAP, UNKNOWN}`；
   - 写堆上对象 `h->p = e`（经指针写字段）：要求 `origin(e) ∈ {STATIC, HEAP, UNKNOWN}`；
   - 写切片元素 `arr[i] = e`：`outlives(origin(e), origin(arr))`。
3. **传参**：仅当 callee 摘要声明「该形参逃逸」时才判（否则指针形参只是借用，调用结束即失效）。

### 4.5 义务（requirement）与保证（warranty）

**四种谓词**（刻意只四种，与 `interval.uya` 现有表达力对齐）：

```
p != null              // 解引用 / 下标 / 调用成员方法前
d != 0                 // `/` 与 `%` 的除数
x >= c                 // 常量下界（含 usize 天然 >= 0）
x <  @len(arg)         // 上界来自某个切片/数组形参的符号长度
```

**证据三级**（必须写死，否则整套系统的健全性无从谈起）：

```
PROVED              在函数体内由常量折叠 / 区间 / 差分约束 / 守卫独立证得
ASSUMED_BY_REQUIRE  由本函数自己声明（推导出）的 requirement 支撑
UNKNOWN             无从判定
```

**铁律：warranty 只能由 `PROVED` 产生。** `ASSUMED_BY_REQUIRE` 的事实可以在**本函数体内**用于后续推理（这就是 assume-guarantee），但**绝不能**升级成 warrant 供调用方使用。违反这条，跨函数证明就退化成"把假设当结论"，等于没有证明——这是最容易犯、最难发现的错，实现时必须用类型或断言把它钉死。

**调用点实例化**（以 `const q = f(a0, a1)` 为例）：

```
s = summary(resolve_reachable_callee_fn_decl(check_call.uya:617, f))
若 s.unknown：结果 origin = UNKNOWN，且不做任何逃逸检查（保守放行，不是报错）
否则：
  result.origin = 把 s.ret_origin 里的 PARAM(i) 替换为 origin(ai)
  若 result.origin 含 LOCAL(scope)，登记到符号表（供 §4.3 比较）
  s.ret_maybe_null != 0        → result 登记为 nullable
  s.ret_index_of_param = i     → 登记约束  -1 <= result <= #len(ai) - 1
  s.ret_len_of_param = i       → 登记约束  result.len <= #len(ai)
  s.escape_mask[i] 含 INTO_OUT(j) → 判 outlives(origin(ai), origin(*aj))
  s.escape_mask[i] 含 INTO_GLOBAL / INTO_HEAP → 要求 origin(ai) ∈ {STATIC, HEAP, UNKNOWN}
  s.requires[i] 是 `ai != null` → 就地证或上行
  s.requires[i] 是 `ai != 0`    → 就地证或上行
  s.requires 是 `aj < #len(ai)` → 用差分区​间证或上行
```

**义务上行（Pass B）**：调用点证不出的 requirement，**登记进当前函数的 requirement 集合**（而不是立刻报错），继续分析后面的语句。函数分析结束时该集合就是它的 `requires`。入口（`main`、`test` 块、`export` 根）的 requires 非空 → 报错（`main` 没有调用者可以付账）。

**为什么这能大幅降低误报**：今天的策略是"证不出就报错"，所以为了自举只能把闸门默认关掉（`--strict-div`）或者把假设开成恒真（形参恒非空）。义务上行把"立刻报错"换成"往上找有没有人付账"，付账的人通常就在调用点上（`&x` 天然非空、`8` 天然非零、`if i >= n` 就在附近）。

### 4.6 assume-guarantee 与 SCC 不动点

```
Pass A（自底向上）：对调用图做 SCC 缩点，按拓扑序处理
    初值：所有 summary = UNKNOWN（最保守）
    对每个函数体走一遍 transfer，得到 ret_origin / escape_mask / requires / warranty
    若该函数在某个 SCC 内，重复直到不动点，上限 4 轮；超限 → unknown = 1
    Pass A 全程不增加 error_count（这是自举不炸的关键）

Pass B（自顶向下）：从 main / test 块 / export 根出发
    每个调用点按 §4.5 实例化并消解；消不掉的进当前函数的 requires
Pass C（收口）：带不出去的 requires → 报错，附调用链
```

单调性：`join` 只会让 origin 更不确定，`warranty` 只会变少，`requires` 只会变多 —— 三者都是单调的，格高度有限，所以收敛；4 轮上限是为了编译时间可控，超限即降级 `unknown`（保守，不是不健全）。

### 4.7 与现有「移动语义」的接缝

现有的移动检查是**扁平名字集合**：`moved_names: [&byte: 128]`（`src/checker/types.uya:17/326`）、`moved_count` 在函数入口（`src/checker/check_stmt.uya:809`）和每个 `test` 块（`src/checker/main.uya` 的 `AST_TEST_STMT` 分支）清零；`has_active_pointer_to`（`src/checker/symbols.uya:1449`）用 `Symbol.pointee_of` 扫全部作用域的符号来判「有活跃指针 → 不许移动」。

两处必须接上，但**不在第一版混做**：

1. `has_active_pointer_to` 的本质是「有指针指向我 → 不许移动」。有了 origin，这个判定可以精确到「有 origin 指向我的指针仍可能被使用」，从而放开 B5 的移动解锁。**但这是放宽规则**，风险与 B1/B2/B3 相反（放宽会引入新的 double free），所以放最后。
2. 分支快照：今天 `moved_count` 没有分支快照，`if c { const b = a; }` 之后 `a` 被判已移动（假阳性），`match` 各分支同理。这是现有实现的已知粗糙点，修它属于「同一条流水线的必要补课」，但要单独提交、单独回归，不和摘要混在一起。

---

## 5 健全性角落（逐条给边界规则）

这一节是本文档最重要的部分：**跨函数证明最容易坏在边界上，而不是坏在主干**。

### 5.1 指针算术

`p + n`、`p - n`、`(p as usize + 8) as &T`：一律 `UNKNOWN`。

理由：Uya 的指针算术在 C 后端就是裸地址运算，编译期无法约束目标存储的寿命；对 `&arr[i]` 之外的算术做 any 推断都会产生假保证。`UNKNOWN` 不产生任何 warranty，只产生 requirement（因此不会误报"安全"）。

### 5.2 cast 往返

`as &void` → `as *T`、`as usize` → `as &T`：`UNKNOWN`。仓库里 `as *void` 大量出现在 libc 桥接（`lib/libc/stdlib.uya:1166` 的 `&readdir_result as *void`），若尝试做"无损 cast 识别"会牵出别名与 ABI 大小的整条栈，第一版不做。

### 5.3 union

union 的活跃变体不可静态确定 → 读写变体字段一律 `UNKNOWN`。这也意味着 union 里的指针字段不参与逃逸检查；`uya.md` §4.5.10 的联合体 drop 递归清理仍然由 codegen 负责，与本方案无关。

### 5.4 全局可变状态

`STATIC` 寿命 = ∞，所以「`return &global`」合法（§2 的 7 处即为此类）。但**写全局**是永久逃逸：只允许 `STATIC`/`HEAP`/`UNKNOWN` 写进全局。这条规则会让 `g_p = &local` 立即报错——这正是 `test_pthread_join_stack_reuse` 那类 use-after-unmap 的编译期形态。

### 5.5 extern：信任边界

对 `extern "libc" fn`（528 个声明）无法做摘要，默认规则：

```
形参：假定不逃逸（借用语义）——与今天的实际行为一致，因此不引入新误报
返回值：origin = UNKNOWN，且 may_be_null = 1（malloc/getenv 一族）
```

这两条都是**信任假设**，必须在文档与代码里显式标注。仓库里已知的**真逃逸** extern（默认规则会漏掉，需要人工清单）：

| API | 逃逸形态 | 后果 |
|---|---|---|
| `epoll_ctl` | `epoll_event.data.ptr` 被内核长期保存 | 指针在 `epoll_ctl` 返回后仍需有效 |
| `pthread_create` / `clone` | `arg` 传给新线程 | 线程存活期间必须有效（`test_pthread_join_stack_reuse` 的根因） |
| `atexit` / `on_exit` | 保存函数指针 + arg | 进程生命周期 |
| `dirfd`/`readdir` 一族 | 返回全局缓冲（`readdir_result`） | 非重入，但合法 |

处置：默认规则 + **逃逸 extern 审计清单**（单列一节，随库演进维护）。**不引入 `@escapes` 属性**——按本文的零语法前提，宁可维护一份 20 行的清单，也不开属性口子。如果将来清单超过 ~50 条或出现跨项目复用需求，再重新评估。

### 5.6 HEAP 与 free

`HEAP` 当前按「∞ 寿命」处理（不做 free 后的失效判定）。这意味着：

- **不检测** use-after-free 与 double free（buglist ② 那一类）；
- 但也不产生假保证（`HEAP` 不参与寿命比较，只参与"能否写全局"这类宽判定）。

要做 free 后的失效判定，需要「所有权 + 消费」模型（`free` 消费 origin，并把该 origin 标 dead），那是**第二个子课题**，与本文的寿命传递正交。写入 §8 不买清单，避免与 B1/B2/B3 混成一锅。

### 5.7 线程与 async

- **线程**：`LOCAL` 不得跨线程（线程入口实参必须是 `STATIC`/`HEAP`/`UNKNOWN`）。这条规则正好覆盖 pthread arg 的真实规则，且不依赖 extern 摘要。
- **async**：`@frame` 是 pinned 生命周期（`docs/goal_v1_lockdown.md` 已把它列为"事实上是 lifetime 系统"）。第一版把 async 函数整体视为 `unknown`（不产生 warranty、不做逃逸检查），**不承诺**任何 async 相关结论。

### 5.8 接口与函数指针

仓库里只有 1 个 `interface` 声明、0 处函数指针调用 → 动态派发面极小。规则：目标集合并集（任一实现逃逸则算逃逸），且集合不可静态确定时整体 `unknown`。由于实际为 0，**P5 这一阶段可以砍掉**，省 8 人日。

### 5.9 装箱接口值（B1 的第三个缺口，2026-11-17 查明：不能只加判定）

现象：`fn make() IWriter { const s: Console = Console{ fd: 42 }; return s; }` 这类
「把具体结构体隐式装箱成接口值返回」的写法，在记录里一直列为「静默通过的悬垂」。
实测查清后，真实情况是**两个独立的缺陷**，都不是「判定点没接」：

1. **不链 `std.async` 就链接失败。** C 后端把隐式装箱生成成
   `_uya_box = (struct Console *)std_async_box_alloc_current(sizeof ...)`
   （`src/codegen/c99/stmt.uya:1698`，赋值/参数位置另有两处同形），
   而 `std_async_box_alloc_current` 由 `lib/std/async.uya:117` 的
   `export fn async_box_alloc_current` 提供。用户程序不 `use std.async` 时该符号不存在
   → `undefined reference to 'std_async_box_alloc_current'`，**链接期报错**（实测
   `/tmp` 最小复现，进程 rc=1）。也就是说这条路径不是静默 UB，而是硬失败。
2. **链上了反而真悬垂。** `async_box_alloc_current` 从
   `get_async_frame_allocator()`（线程级 async frame allocator）取内存
   （`lib/std/async.uya:117-137`），而 `async_frame_pool_reset`
   （`lib/std/async_frame.uya:889`）会把 bucket 里的内存全部释放（generation 递增）。
   把这样装出来的接口值 `return` 出当前帧，调用方拿到的 `data` 指针指向已回收的池内存。

因此这条缺口**不能用「B1 多接一处判定」收掉**：真正的修法是给接口装箱一个寿命与返回类型
匹配的所有权规则（例如返回位置的装箱改走 `malloc`/调用方显式 `box` API，或引入
「装箱结果不可越过帧边界」的检查，同时改 `scheduler_pool_to_allocator`
（`lib/std/async_scheduler.uya:708`，全树唯一的接口返回函数）与它的调用点）。
在没定下这条所有权规则前加判定，只会让 `return *pool;` 这类合法转发一起变红。

**收口（2026-11-18）：先用「进程寿命分配」把 UB 消掉，所有权规则留作后续优化。**
最小且安全的取舍：只改 `return` 位置的**两个**隐式装箱点
（`src/codegen/c99/stmt.uya` 的普通返回与错误联合载荷返回），生成的分配由
`std_async_box_alloc_current` 改为 `__builtin_malloc(sizeof(T) + 16)`，
并手写与 `async_box_free_current` 兼容的 16 字节头
（`header[0]=0` ⇒ 释放走 libc free，`header[1]=sizeof(T)`）。头是必需的：
只发裸 malloc 会让 54 个 async 测试在释放时读野指针而 SIGSEGV（已实测并修正）。

- 缺陷 1 消失：不再引用 `std.async` 符号，用户程序不导入它也能链接；
- 缺陷 2 消失：返回出去的接口 `data` 指针不再指向会被帧池回收的 bucket；
- async **future** 的装箱（`stmt.uya:1394`、`function.uya:6186/6190`）保持原路径 ——
  它们有配对的 `async_box_free_current`，依赖帧池回收；
- 代价：返回的接口 box **没有 free 路径**（受控泄漏）。在零 GC 且没有接口所有权跟踪
  的前提下，这是「泄漏」与「悬垂 UB」之间唯一安全的选择；把它升格为带 refcount /
  调用方显式 `box` 的正式所有权规则，是后续工作，不阻塞当前的 UB 收口。

因此 B1 的「装箱局部接口值返回」缺口现在是**已修**，不再是「防回归」清单里的洞。
回归 `tests/test_interface_box_return.uya` 修复前链接失败（rc=1），
修复后 64 次跨函数返回 + 虚方法调用全部正确（rc=0）。
注意 exec（VM）后端对该表达式形态仍报 `无法为表达式构造地址`，与本次修复无关，
属于 VM 的 boxing 支持缺口。

---

## 6 可证性与量化方法

### 6.1 五个消解来源

任一 requirement 的消解只能来自这五个桶之一：

| 桶 | 来源 | 典型形态 | 可静态预估 |
|---|---|---|---|
| ① | 地址取用 | `f(&x)` 对 `p != null` | 高（`&x` 天然非空） |
| ② | 常量 | `f(buf, 8)` 对 `d != 0`；`[i32: 4]` 对 `x < @len(arr)` | 高 |
| ③ | 本地守卫 | `if p == null { return ... }`、`if i >= n { ... }` | 中 |
| ④ | 上游 require | Pass B 已入作用域的同类谓词 | 仅运行期可知 |
| ⑤ | callee warranty | `find` 的 `ret ∈ [-1, #len(s))` | 仅运行期可知 |

### 6.2 唯一有意义的指标

```
跨函数消解率 = (④ + ⑤) / 全部 requirement
误报率      = Pass C 报错数 / 全部 requirement
```

两者**只能**由 `--lifetime-report`（P0 的产物）按文件统计出来，不能靠本文档估算。报告字段：

```
file:line  fn  requirement  bucket  evidence(PROVED/ASSUMED/UNKNOWN)  resolved_at(caller:line | unresolved)
```

**预判**（写下来是为了将来对账，不是结论）：非空义务 ① 应占 >90%（`&x` 是主流调用形态）；非零义务 ② 占比可观（`align` 常传字面量）；下标义务主要靠 ③（守卫在调用方，这正是 B4 的收益来源）。若实测偏离，按实测修方案。

**实测（2026-11-17，`src/main.uya` 依赖闭包，`--lifetime-report`）**：

```
[lifetime] functions=3229
[lifetime] req_total=3078 req_resolved=2668 req_unresolved=410     # B2/B3 义务消解率 86.7%
[lifetime] req_param_null=2582
[lifetime] req_div_zero=496
[lifetime] returns_local=0
[lifetime] summary_unknown=2948
[lifetime] call_sites=35764 call_resolved=5148                     # 调用点摘要消解率 14.4%
```

这三个数字此前**是假的**，本轮一并修好：

- `functions=0`：`lifetime_fn_count` 字段声明了、报告也打印了，但没有任何地方累加。
  现在在逃逸口登记器（唯一遍历全部函数体的入口）里计数。
- `summary_unknown` / `call_sites=0`：摘要只在 `lifetime_origin_of_expr(调用)` 里才会被求，
  而正常 check 路径没有任何地方对调用表达式求 origin —— 也就是说
  `summary_unknown=0` 的真实含义是「这套机制一次都没被调用过」。现在登记器在
  `--lifetime-report` 下对每个调用点求一次 origin，得到真实分母。
- `call_resolved` 一度是 **0**，查明是 `lifetime_collect_return_origins` 的**首条 return
  分支写反了**：注释写「先把 acc 置成 UNKNOWN 再 join，结果就等于 o 本身」，但
  `origin_join` 的规则是「任何一侧 UNKNOWN 就 UNKNOWN」，于是
  join(UNKNOWN, o) ≡ UNKNOWN —— 只要函数有 return，摘要就永远是 UNKNOWN，
  整套跨函数摘要机制静默失效。修成「首条直接作为初值」后，
  调用点消解率 0 → 5148/35764 = **14.4%**；同时给摘要加了按节点指纹的记忆化
  （`g_lifetime_summary_keys`），否则逐调用点求摘要会指数级放大
  （实测 10 分钟不返回）。

**对账结论**：跨函数消解率当前只有 14.4%，B2/B3 的义务消解率 86.7% —— 前者才是
「跨函数证明」的真实进度条，不能拿后者的数字冒充。要抬 14.4%，靠的是
§4.5 的 `escape_mask` / `requires` 摘要（本轮只做了 `ret_origin`）与 B4 的
`ret_len_of_param`，不是加判定点。

### 6.2b 已查明的两个证明缺口（2026-11-17）

跨函数这条线之外，B4 依赖的**数组下标证明**有两个洞，都是由 UBSan 交叉验证反推出来的
（详见 `docs/unsafe_audit_plan.md` §5.1 与 buglist）：

1. **循环里被改写的变量，下标证明完全不生效**（P0，未修）。
   `while i < 5 { items[i] = i; i = i + 1; }`（`items: [i32: 4]`）在 `--safety-proof`
   下编译通过；循环之后再写 `items[i]` 也通过，`while i < 100` 同样通过。
   换成形参 `items[k]` 或 `if c { i = 9; } items[i]` 就会正确报错。
   根因是 `constraint_update_for_increment` 用「约束整体 +1」近似一次迭代，
   而循环体只检查一遍、没有不动点：body 里看到的是初值（`i == 0`，安全），
   真正越界的那次迭代从来没被检查。`while i < n { arr[i] }` 是遍历的主流写法，
   所以这条缺口覆盖了绝大多数下标访问 —— 它比 B1 的残留判定点严重得多。
2. **`verify_linear_expr_upper_from_span_len` 的启发式已确认可误放行（2026-11-18 修复）**。
   它允许「某个变量的上界 ≤ 数组大小」替代「下标变量自己的上界」，匹配的是
   `len = end - start` / `p = base + i` 这类惯用法的反向约束。**构造出了单独误放行的负例**：
   ```uya
   var p: i32 = 0;
   const end: i32 = 4;
   const len: i32 = end - p;
   p = 3;
   if len > 1 { return g_arr[p + 1]; }   // g_arr 长度 4，实际访问下标 4
   ```
   修复前 `--safety-proof` 编译通过；对照组把 `len` 改成常量 4 就会正确报
   「数组索引安全证明失败」。根因：`len = end - start` 只是**声明时刻**的快照，
   约束表里的 `len > offset` 不会随 `start` 的后续赋值失效，启发式却拿它当持久等式用。
   修法（`src/checker/interval.uya`）：只有 `len` 与 `start` 都是不可变符号（`is_const`）
   时才启用这条启发式，保证声明时的等式在整个作用域成立。
   负例固化在 `tests/error_span_len_stale_start.uya`，修复后按预期原因失败。
   这条与 ① 是**独立**的两个洞：① 的原因是「循环体只检查一遍、无不动的约束 +1」。

**① 的修法已实现一半（2026-11-17）**：新增 `--strict-loop-bounds`，
规则是「进入循环时作废体内被赋值变量的上界；只有当体内每次赋值都是
`x = x + 非负常量`（含 `+|`）时才保留下界」。实测判定矩阵：

| 用例（`items: [i32: 4]`） | 默认 | `--strict-loop-bounds` |
|---|---|---|
| `while i < 3 { items[i] }` | 通过 | 通过（真安全，不误杀） |
| `while i < 4 { items[i] }` | 通过 | 通过（真安全，不误杀） |
| `while i < 5 { items[i] }` | 通过（**洞**） | **报错** |
| `while i < 10 { items[i] }` | 通过（**洞**） | **报错** |
| `while i < 100 { i = i + 1 } items[i]` | 通过（**洞**） | **报错** |

矩阵钉在 `tests/verify_strict_loop_bounds.sh`（挂进 `make check`）。
**为什么默认不开**：在 `src/main.uya` 闭包上打开会报 939 个错误
（279 数组索引、606 i32 溢出、42 `DEBUG_BYTE_PTR_SUBSCRIPT_ERROR`、3 索引需要证明、1 除零），
全是真实的「靠初值蒙过去」的站点。逐个补真守卫是独立工作项，修完再设默认。

**结论**：在 ① 修好之前，「审计过的 unsafe 之外零 UB」这句话对循环遍历不成立，
§6.2 的 86.7% / 14.4% 也不能读成「安全覆盖率」。修法写在 buglist 里：
进入 `while` 体前把体内被赋值变量的约束清空（或置无界），循环结束后再清一次，
然后按 `check --safety-proof src/main.uya` 的真实报错逐个补守卫 —— 这会是一批
真实越界修复，不允许用放宽判定消掉。

### 6.3 与 `361/908` 实验的对账

buglist ⑥ 记录：取消「形参恒非空」后，908 个测试里 361 个报「指针可能为空」。那是**把假设换成默认报错**的结果。本方案把假设换成**调用点义务**，而调用点最常见的形态是 `&x`（①，天然可证），所以 361 这个数字**不应**原样出现；真实数字必须由 P0 报告给出。若实测仍在数百量级，说明 ① 的预估错了，应停止后续阶段并重估（这是本方案的**熔断条件**）。

---

## 7 收益六类 × 量化

| # | 收益 | 受检站点 | 收益性质 | 误报风险 | 判据 |
|---|---|---|---|---|---|
| B1 | 悬垂引用（返回局部地址 / 局部切片 / 装箱局部接口值 / 写入更长寿命容器） | 971 返回指针函数 + 1019 指针字段 + 289 `return &` + 21 repros 中的 3 个逃逸复现 | **防回归**（UB 不崩只错值，最难查） | 低（`STATIC`/`PARAM` 放行规则清楚） | buglist P1 → `[x]`；3 个 repro 升级为 `error_*` 后按预期原因失败 |
| B2 | 非空前提（替代 blanket 假设） | 2865 指针形参签名 + 57 处 `getenv` | 精度提升，无需 `?&T` 语法 | 中（nullable 实参直传面；实测直传 **0 处**） | ⑥ → `[x]`；shadow 报告误报数 ≤ 白名单 |
| B3 | 非零前提 | 111 处 `/` `%` | **从无保护到默认保护** | 中（需逐点加守卫） | `--strict-div` 翻默认；`make check` 零回归 |
| ↳ 实测 | `check --strict-div src/main.uya` 于 P0/P1/B1 落地后重测 | 实命中 **93 处**（`vm` 31、`modules` 15、`stdlib` 7、`function` 6、`value` 6、`interval` 5，其余零散） | 分两类：①同函数可证（动态表容量恒正等，补 `if cap <= 0` 守卫即可；已在 `check_call.uya` 补 3 处，93→87）②跨函数不变量（`align_size` 的 `align`、牛顿迭代 `guess`、`interval` 的 `a.min / b.min`） | ②类正是「由调用点付账」的需求，但付账方是 **B2（非空/非零义务）与 B4（后置事实）**，两者未落地 | **按 §6.3 维持默认关闭**；翻默认推迟到 B2/B4 落地后重测，届时用 `--lifetime-report` 的 `req_div_zero` 读跨函数消解率 |
| B4 | 后置事实（返回下标范围 / 返回切片长度） | 27 返回切片 + 891 处 `>= 0` | 打通"事实来自被调方"的下标证明 | 中 | `find/chr` 类正例通过；`tests/test_bounds_*` 不回归 |
| B5 | 非逃逸形参 → 解锁移动 | 2865 形参签名里绝大多数为纯读函数 | 易用性 + drop 正确性 | 中高（放宽会引入新的 double free） | `tests/test_drop_after_move.uya` + 嵌套字段 move 正负例 |
| B6 | shadow 报告 | 全树 | **可执行的工作清单 + 可 diff 的基线** | 近零 | 报告两次运行 diff = 0 |

---

## 8 不买清单

| 项 | 结论 | 归属 |
|---|---|---|
| 循环不变式（197 处 `while x < y.len`，buglist ③） | ❌ 完全正交 | `docs/array_safety_proof_plan.md` B/C |
| 非线性下标（`a[i*j]`） | ❌ 仍需单独兜底 | 同上 A 阶段 |
| 切片形参 `s[i]` 的 `len` 符号化 | ⚠️ 共用 §4.5 的 `#len(x)`，但主体在 array plan B | array plan B |
| 别名分析 / 并发数据竞争 | ❌ 不做（flow-sensitive 单线程语义） | 无计划 |
| use-after-free / double free（`free` 后失效） | ❌ 第二个子课题（所有权+消费模型） | 未来 |
| `@asm`、`as` 往返、union | ❌ 一律 `UNKNOWN` | 本文 §5 |
| extern 真实行为 | ❌ 信任边界 + 审计清单 | 本文 §5.5 |
| async / `@frame` pinned | ❌ 整体 `unknown` | 独立议题（`goal_v1_lockdown` T5/T6） |
| 接口派发 / 函数指针 | ❌ 实测量级为 0，直接 `unknown` | 本文 §5.8 |

**这条清单的作用**：下一轮再讨论"跨函数证明"时，先看这张表，避免把 ③ 和不买项混进验收指标，导致"方案做了但没效果"的误判。

---

## 9 成本模型

| 项 | 估计 | 依据 |
|---|---|---|
| 检查器时间 | **+8%~15%** | 每个函数体已走 1 次 `checker_check_node` + 较重的 `checker_walk_reachability_expr`；摘要只多扫五类结点（赋值/返回/取址/字段写/调用），并对 SCC 内函数重算 ≤ 4 轮。P0 起把 summary 耗时打进报告，超 15% 降级为"只算叶子函数，其余 `unknown`" |
| 新增代码 | 约 4k 行 | `lifetime.uya` 1.2k（origin/传播/判定）+ `summary.uya` 1.5k（摘要结构与不动点）+ 接线 0.6k（`check_call`/`check_stmt`/`main`）+ 诊断 0.8k（调用链、规范化谓词） |
| 新增数据结构 | `Symbol` 3 字段、`TypeChecker` 5 字段、`FnSummary`（键 = fn 声明节点，`check_call.uya:617` 已有解析器） | 不新增 `ASTNode` 字段（节点数量大，加字段代价高） |
| 迁移成本 | 集中在 B2 的 nullable 实参面 | 实测直传 nullable 返回值 **0 处**；`getenv` 57 处基本先落变量再判空 |
| 误报治理 | shadow → 基线快照 → 白名单 → strict flag → 默认，五级 | 每级都能靠翻默认值回退 |

---

## 10 为什么不是别的方案

| 方案 | 不可行的硬理由 |
|---|---|
| Rust 式生命周期参数 | 与「无 lifetime 符号」身份直接冲突；还要与泛型、`Self`、接口方法签名、`@frame` 相乘；单页纸放不下 |
| SPARK / Dafny / ACSL 式人写契约 | 需要谓词表达式文法 + 名字解析 + 类型检查 + 契约漂移维护；且「写就必须对」的校验本身又是一套推断（等于还是要做本文的东西，只是多了一层语法） |
| Infer 式全程序 biabduction | 不可解释（说不出"为什么这里安全"），误报高，与「一行报错 + 修改建议」的现有 UX 冲突 |
| ASan / Valgrind 运行期检测 | 太晚（测试期才暴露）；nostdlib / microapp 目标里根本不存在这些运行时 |
| 只做单函数、放弃跨函数 | 就是现状：971 个返回指针函数零检查、111 处除法默认无保护、⑥ 只能靠 blanket 假设 |

结论：**推断式 assume-guarantee 是唯一同时满足「零语法 + 一行报错可解释 + 跨函数可组合」的路线**；代价是必须把 §5 的边界规则和 §8 的不买清单写死。

---

## 11 施工图

| 阶段 | 内容 | 人日 | 出口判据 |
|---|---|---|---|
| **P0 度量** | `--lifetime-report`（只算不报）：origin 传播 + 摘要计算 + 按文件导出 §6.2 字段 | 4 | 两次运行报告 diff = 0；`make check` 一字不变 |
| **P1 地基** | `scope_id` + Origin 格 + transfer 表 + `Symbol` 三字段；`#len(x)` 符号与差分约束（与 array plan B 共用） | 8 | 单函数逃逸可判：`fn mk() &[i32] { var b: [i32: 4] = [1,2,3,4]; return &b[0:4]; }` 报错 |
| **B1** | 三处判定点接上（`return` / 写更长寿命容器 / 传参）；`STATIC`/`PARAM` 放行 | 6 | buglist P1 → `[x]`；3 个 repro 升级为负例 |
| ↳ 实测（return） | 2026-11-16 **return 判定点落地（收窄版）**：`lifetime_check_return_escape` 认三种形态 —— ①`return &x` / `&arr[i]` / `&s.f`；②对局部数组开窗的切片 `return buf[a:b]`；③按值返回**元素含指针**的局部数组 | 负例 `error_return_local_addr`、`error_return_local_array_elem_addr`、`error_return_local_slice`、`error_return_local_ptr_array` 均按预期原因失败 | 放行面：形参来源（`fn f(s: &[i32: 4]) &[i32] { return s[1:3]; }`）、纯标量数组按值返回、局部指针变量转存后返回 | §6.3 熔断记录在案：把「局部指针变量的值」纳入判定时自举爆 231 处误报，故 origin 表对指针符号一律 `UNKNOWN` | 未做：传参判定点；写更长寿命容器见下行（可证一侧已接）；装箱局部接口值返回**已修**（§5.9 收口，走进程寿命分配，不再是判定点缺口） |
| ↳ 实测（store） | 2026-11-17 **写更长寿命容器判定点落地（可证的一侧）**：`lifetime_check_store_escape` 挂进赋值，只在「来源 origin = `LOCAL` **且** 容器是全局变量 / 全局对象字段」时报错 | 负例 `tests/error_store_local_addr_to_global.uya`（`g_slot = &x`）按预期原因失败；正例 `tests/test_store_escape_positive.uya` 四形态（局部→局部、内层→外层局部字段、`STATIC`→全局、纯值赋值）全过 | 全树零误报：`uya check src/main.uya` 错误 0、**3.47 s**（接判定前 4.0 s 量级）；`make b` 自举**字节一致** | 本轮抓出两个真 bug：①`lifetime_origin_of_value` 与 `lifetime_origin_of_expr` 对「读字段/读元素」**互相递归**（没记忆化 → `check src/main.uya` 不返回、随后栈溢出 rc=139），改为非标识符一律 `UNKNOWN` + 摘要加深度闸门（8 层）；②字段分支判定**方向反了**（`origin_outlives(container, src) == 0` 才报 = 专报安全的那一侧），改为只认「容器 `STATIC`」 | 明确**放行**（= 洞还在，见 §5）：`PARAM → 全局`（编译器自身 4 处主流写法：`g_compiler_arena_failure_key = key` 等）、`LOCAL → 局部容器字段`（需字段级逃逸分析）、`arr[i] = e`（切片 origin 拿不到）、来源为调用表达式（会把函数摘要拖进互相递归，且被调方 return 判定点已判过） |
| **B3** | 非零义务 → `--strict-div` 翻默认 | 10 | `make check` 零回归；111 处逐点处理；`tests/verify_strict_div.sh` 扩成四断言 |
| ↳ 实测 | 2026-11-16 **已落地并翻默认** | `src/` 87 → 0（七类清账：容量取模走 `dyn_table_slot_of` 32 处、证明器消费 `CONSTRAINT_NE`、非零证明改为只需单侧端点、判零落到局部名、链式对齐走 `c99_layout_align_up_i32`、`@size_of` 按形态直接认、6 处单点） | `lib/` 12 → 0（jpeg/async/thread 一律「落局部 + 正分支包裹」） | `g_strict_div` 默认 1，`--no-strict-div` 保留；测试语料按 `--strict-overflow` 同一约定显式豁免 | `tests/verify_strict_div.sh` 扩成四断言；默认模式 `check src/main.uya` 错误 0；`make uya` 自举通过；`error_const_*_zero` 负例仍失败 | §6.3 未触发：全程零误报，全部清账都是「让判定看得见」，没有放宽规则 |
| **B2** | 非空义务替代 blanket 假设（`check_stmt.uya:770` 那条 `pointer_nonnull_add(param)` 改成"产生 requirement"） | 10 | ⑥ → `[x]`；误报 ≤ 白名单 |
| ↳ 实测 | 上半（删 blanket 假定）2026-11-16 落地；下半（调用点付账）同日落地 | 上半：`req_total=3165`、`req_resolved=2552`、消解率 80.6%；下半：被调方摘要只认「指针形参 + 无条件解引用 + 无 null 守卫」，调用点字面量 `null` 报错 | **误报数 0**（全树逐文件扫描 B2 诊断命中 0 条）；负例 `tests/error_pass_null_to_deref_param.uya` 按预期失败 | §6.3 熔断 1 次：第一版把 if/while 体内的解引用也算，`lib/tls/base/drbg.uya` 的 `_update(ctx, null, 0)` 误报 2 条（`provided_data[i]` 由 `provided_len` 守着），已收紧为「只认无条件解引用」 | 2026-11-18 扩展：`lifetime_expr_is_known_null` 认初值为 null 的全局 const；`lifetime_scan_param_calls` 沿具名调用链传播 requirement（深度上限 3 防环）；`lifetime_find_param_alias` 认 `var q = p` / `q = p` 的直接别名。负例分别见 `tests/error_param_null_global_const.uya`、`tests/error_param_null_transitive.uya`、`tests/error_param_null_local_alias.uya`。**剩余缺口**：可变全局、多级别名/复杂表达式、方法调用、函数指针调用不付账（依赖 B4/B5 的指针指向传播） |
| **B4** | 后置事实（`ret_index_of_param` / `ret_len_of_param`）接进 `infer_array_access`、`checker_check_array_access` | 12 | `find/chr` 类正例通过；与 array plan B 合流 |
| ↳ 实测 | 2026-11-16 **已落地**（`ret_index_of_param` 的下标上界部分） | 摘要 `lifetime_fn_ret_index_upper`：返回类型 `i32` + 顶层 `while v < N`，循环内 return 只能是「未改写 v 前的 `return v`」或负整数哨兵，多循环 N 必须一致，否则放弃 | 事实记在 `Symbol.post_index_upper`（`lifetime_record_post_index_upper`），**分支内**才变成约束（`lifetime_apply_post_index_bound` 只在 `if v >= 0` 的 then 里注入 `v < N`，随分支回滚） | 正例 `tests/test_bounds_index_from_callee.uya` 通过；负例 `tests/error_bounds_index_from_callee_unguarded.uya` 按预期失败；健全性对照（上界 8 vs 数组 4）仍报错 | 零回归：`src/main.uya` 错误 0，全树逐文件 **502**（基线 506，无新增） | 未做：`ret_len_of_param`、形参名→实参名映射、非 `i32` 返回 |
| **B5** | 非逃逸形参 → 移动解锁（改 `has_active_pointer_to` 的判定源） | 8 | move 正负例全绿；无新增 double free |
| ↳ 评估 | 2026-11-16 只做可行性评估，**未实施** | 方向与 B1/B2/B3 **相反**：这是放宽规则，出错引入新的 double free | 依赖把 B2 的 requirement 摘要扩成「形参用途摘要」（不逃逸 = 不存字段/不返回/不传入可能逃逸的调用），再把判定源从「有没有指针指向我」换成「有没有 origin 指向我的指针仍可能被使用」 | origin 格四档与 `lifetime_origin_of_value` 已有，但**指针指向传播**缺 | 排到下一轮 |
| ↳ 实作 | 2026-11-16 **已落地**（`has_active_pointer_to` 换判定源） | 新增 `lifetime_pointer_is_dead`：指针不阻止移动 ⟺ 每次使用都是「实参 → 非逃逸形参」且早于移动点；配套 `lifetime_fn_param_escapes`（形参逃逸摘要：存字段/元素/全局、return、再外传即逃逸） | 遍历器对认不出的节点形态**fail-closed**（指向活跃 / 按逃逸处理），因此没扩到的语法只会退回旧行为 | `error_move_active_pointer`（零使用）、`error_move_active_pointer_after_borrow`（先移后借）、新增 `error_move_escaping_borrow`（传给会逃逸的形参）三者仍报错；正例 `tests/test_move_non_escaping_borrow.uya` check+run 通过 | 只放宽、不收紧：不可能新增误报；健全性靠「①调用返回后被调方不持有 ②移动后本函数不再碰」两条 |
| **P6** | 迁移收口、默认开、文档同步（`uya.md` §6.5/§7/§12.5.5/§14.1/§14.3、`grammar_*` 若涉及、buglist 三条勾选） | 4 | `make check` + `make b` 字节一致 + `make check-hosted` |

**最短闭环 = P0 + P1 + B3（14 人日）**：判据是 `--strict-div` 翻默认后全量零回归、`make b` 自举字节一致、111 处除法站点处理完毕，并且拿到 §6.2 的跨函数消解率与误报数。**是否继续 B1/B2/B4/B5，用这两个数字决定**；若误报按 §6.3 的熔断条件超预期，停止并重估。

每个阶段独立提交、独立回退（回退 = 翻默认值或撤单个 commit）。

---

## 12 复算附录

测量日期 2026-04-29，基线提交 `49014a20`。全部在本仓库根目录执行。

```bash
# 规模
find lib src -name '*.uya' | wc -l                                   # 297
grep -rho "^\s*\(export \)\?fn [a-zA-Z_]" lib src --include=*.uya | wc -l    # 5950
grep -rho "fn [a-zA-Z_0-9]*(\([^)]*\))" lib --include=*.uya | grep -c "&[a-zA-Z_]"  # 2865

# 返回指针的函数
grep -rEho "\) *&[a-zA-Z_(]"  lib src --include=*.uya | wc -l         # 842  (&T)
grep -rEho "\) *&\["          lib src --include=*.uya | wc -l         # 27   (&[T])
grep -rEho "! *&[a-zA-Z_(\[]" lib src --include=*.uya | wc -l         # 102  (!&T)

# 逃逸通道与取址形态
grep -rEho "^ *(export )?[a-zA-Z_0-9]+: *&[a-zA-Z_(\[]" lib src --include=*.uya | wc -l  # 1019
grep -rEn "return *&" lib src --include=*.uya | wc -l                 # 289
grep -rEho "&[a-zA-Z_0-9]+\[[^]]*\]" lib src --include=*.uya | wc -l  # 3771 (&arr[i])

# 边界与证明面
grep -rEho "\([^)]*&\[[^)]*\)" lib src --include=*.uya | wc -l        # 396 切片形参签名
grep -rEho "@len\(" lib src --include=*.uya | wc -l                   # 283
grep -rEho "[a-zA-Z_0-9\)\]] */ *[a-zA-Z_0-9\(]" lib src --include=*.uya | wc -l  # 58 除
grep -rEho "[a-zA-Z_0-9\)\]] *% *[a-zA-Z_0-9\(]" lib src --include=*.uya | wc -l  # 53 模
grep -rEho ">= *0" lib src --include=*.uya | wc -l                    # 891
grep -rEn 'while +[a-zA-Z_][a-zA-Z_0-9]* +< +\S+\.len' --include=*.uya lib src | wc -l  # 197

# 信任边界与所有权
grep -rEho 'extern "libc" fn [a-zA-Z_0-9]*' lib --include=*.uya | wc -l   # 528
grep -rEho "\bmalloc\(" lib --include=*.uya | wc -l                   # 44
grep -rEho "\bfree\("   lib --include=*.uya | wc -l                   # 158
grep -rEho "fn drop\(self" lib src --include=*.uya | wc -l            # 12
grep -rEho "^interface [a-zA-Z_]" lib src --include=*.uya | wc -l     # 1
grep -rEho "\(fn *\(" lib --include=*.uya | wc -l                     # 0（函数指针调用）
grep -rEho "getenv\(" lib src --include=*.uya | wc -l                 # 57

# 回归规模
ls tests/test_*.uya | wc -l      # 914
ls tests/error_*.uya | wc -l     # 211
ls tests/repros/*.uya | wc -l    # 21
```

**代码引用锚点**（以函数名为准，行号会漂移）：

| 位置 | 用途 |
|---|---|
| `src/checker/types.uya:17` `MAX_MOVED_NAMES`、`:326` `moved_names` | 现有移动集合是扁平名字表 |
| `src/checker/symbols.uya:1147` / `:1156` | `checker_enter_scope` / `checker_exit_scope`（`scope_id` 的挂载点） |
| `src/checker/symbols.uya:1449` `has_active_pointer_to` | B5 要改的判定源 |
| `src/checker/symbols.uya:1471` `checker_mark_moved`、`:1565` `moved_access_path_contains` | 整变量/字段移动的现有实现 |
| `src/checker/check_stmt.uya:770` | 形参无条件登记为「非空」（B2 要替换的那行） |
| `src/checker/check_stmt.uya:809` | 函数入口清空 moved 集合 |
| `src/checker/main.uya:743` | `AST_WHILE_STMT` 约束快照（③ 相关，本文不修） |
| `src/checker/interval.uya:26/114/143` | `pointer_nonnull_add` / `pointer_nullable_add` / `pointer_is_nullable` |
| `src/checker/interval.uya:251` `constraint_add` | 差分约束的改造点 |
| `src/checker/check_expr.uya:4139` `infer_array_access` | 数组下标证明主路径 |
| `src/checker/check_expr_extra.uya:48` `checker_check_array_access`、`:139` | 切片/指针分支与空指针检查 |
| `src/checker/check_call.uya:617` `resolve_reachable_callee_fn_decl` | 摘要的键解析（已有，无需新增） |
| `src/checker/check_call.uya:1435` `checker_check_call_expr` | 调用点实例化的挂载点 |
| `src/codegen/c99/stmt.uya:306` `emit_drop_cleanup_at_scope_for_return_expr` | drop 与 `return` 的现有交互（所有权面参考） |
| `src/parser/main.uya:776` | 现有属性族（`@async_fn`/`@naked_fn`）——本文**不新增**属性 |
