# 数组安全访问证明：施工图

范围：`docs/uya.md` §14 强制表要求的**数组/切片/指针边界证明**，从「只覆盖保守子集」
推进到完整支持。本文只给施工方案，不改代码。行号以函数名为准（会漂移）。

## 1. 结论摘要

- 4 个阶段（A 一致性 → B 符号上界 → C 循环不变式 → D 可伸缩性），**合计约 36 人日**。
- **最先动手**：`src/checker/check_expr.uya:4101` —— `infer_array_access` 里
  `if linear_expr.is_valid != 0 { … }` 后面**没有 else**，非线性下标在这条路径上零检查，
  补一句 `verify_expr_bounds_interval` 兜底即可（A 阶段最小、最独立的一刀）。
  `buglist.md:1187` 记「非线性无兜底」未修，而 `check_expr_extra.uya:113` 明明有兜底 ——
  差别就在这一行；同类「两条路径覆盖不一致」已被 ④ 记录（`buglist.md:511-513`）。
- **最大风险**：B 阶段给切片接上证明会撞上现存写法 —— 全树 `343` 处
  `while X < Y.len`（`grep -rEn 'while +[a-zA-Z_][a-zA-Z0-9_]* +< +\S+\.len' --include=*.uya .`），
  ③ 已记录收紧一次就炸出 **104 个**错误（`buglist.md:491`）。必须按 §4.B 的迁移顺序做。

## 2. 目标与完成判据

**判据（一条命令可验证）**：`make check` 全绿（`Makefile:635`，当前基线 **1147/1147**，
见 `buglist.md:459`），且下列四条同时成立：

| # | 判据 | 验证方式 |
|---|---|---|
| 1 | `buglist.md:429` 的 P0 条目里 ③⑤⑥ 转成 `[x]` | `sed -n '429p' buglist.md` 看勾选 |
| 2 | `buglist.md:1187` 两条宽松点（非线性无兜底、非 i32 下标放行）消失 | 同上 |
| 3 | `tests/repros/` 里 3 个复现文件升级为 `tests/error_*.uya` 负例后仍失败（即报错） | `tests/run_programs_parallel.sh`：`error_` 前缀 = 预期编译失败（`tests/run_programs_parallel.sh:712`） |
| 4 | **不**把 `while i < X.len` 变成新错误 | 见下 |

**判据 4 是硬约束**。做法：先落一版「按文件白名单」的基线快照，在收紧前后各跑一次
`./bin/uya build` 全树，**按文件统计**新增的「数组索引安全证明失败」，必须为 0 差异；
白名单之外的任何新增报错都算回归。（直接靠在 A/B 阶段「先给 `X.len` 建符号约束」，
让这 343 处天然可证，而不是靠豁免。）

## 3. 证明链现状

| 环节 | 文件:函数名 | 现状一句话 |
|---|---|---|
| 约束表存储 | `types.uya` 字段 `constraint_var_names/ops/values`（:339-342） | 定长 64 槽，**只存 `&byte` 名 + i32 常量**，装不下符号上界 |
| 约束写入 | `interval.uya:constraint_add`（:251） | 满了**静默 return**，不报警、不扩容 |
| 约束写入（返回值） | 同上 | `void` 返回：调用方**无法**知道这次约束没进表 |
| 约束可信度 | `interval.uya:g_constraint_sound`（:21） | 与约束同下标的定长 64 槽，`constraint_add` 时置 1 |
| 约束提取 | `interval.uya:constraint_extract_from_binary`（:522） | 左必须是**线性式**；右是常量或退回**类型全域**（:686-694） |
| 线性式提取 | `interval.uya:extract_linear_expr`（:1522） | 只认 `var ± const`、成员访问、cast 透传；乘/移/模**一律 `is_valid=0`** |
| 区间求值 | `interval.uya:eval_expr_interval`（:1753） | 覆盖 `+ - * / % & << >>`，饱和/包装算子在 :1900-1910 与普通算术同传播 |
| 区间判定 | `interval.uya:interval_within_bounds`（:1004） | `min > max`（端点反转）**直接拒**，是已修的健全性漏洞（⑤ 记录、`buglist.md:1187` 邻近） |
| 线性证明 | `interval.uya:verify_linear_expr_bounds`（:2016）/ `_ex`（:2098） | 查区间 + 64 槽约束；`_ex` 额外允许无符号下标下界为 0 |
| span 上界 | `interval.uya:verify_linear_expr_upper_from_span_len`（:1969） | 从 `x = n - i` 的**声明初始化式**反推 `i < n`，只认这一种形状 |
| 数组访问（主） | `check_expr.uya:infer_array_access`（:4080） | 常量越界查；变量只走**线性式**，`is_valid==0` 时**无 else**（:4101-4114） |
| 数组访问（辅） | `check_expr_extra.uya:checker_check_array_access`（:48） | 线性失败后有区间兜底（:113-119）；但**非 i32 下标提前返回**（:65-69、:76-79） |
| 切片访问 | `checker_check_array_access` 的 `TYPE_SLICE` 分支（:62） | 只推元素类型，**整段不设防**（⑤ 缺口 1） |
| 指针下标 | `checker_check_array_access` 的 `TYPE_POINTER` 分支 | 有 `pointer_index_has_user_bounds_proof`（:6）兜底；`byte` 指针 `index==0` 直接放行 |
| 指针可空性 | `interval.uya:pointer_is_nullable`（:143） | 只看**局部变量**的 `null` 初始化登记（`check_stmt.uya:333`），形参从不入表（⑥） |
| 分支快照 | `main.uya:529-724` | then/else 各存一份 `[&byte: 64]`/`[i32: 64]` 栈副本（:532-535、:557-560、:599-602、:630-633） |
| 循环体 | `main.uya:743-780` | 只在**进体前**调一次 `constraint_extract_from_binary`（:764），体内对 `i` 的写**不回传**（③ 的直接根因） |
| `for` 约束 | `check_node_extra.uya:488-507` | 只收**常量**端点（:497、:504），`for 0..s.len` 两侧都不进约束表 |
| 证明步数 | `proof.uya:checker_proof_step`（:1014） | `proof_step_limit` 熔断，超限报「证明超时」 |

> 与本计划**无关，排除**：`int_limit_resolved_kind` / `resolve_int_limit_node` /
> `checker_resolve_int_limit_args` —— 那是 `@max` 常量发射的修复路径，不参与边界证明。

## 4. 分阶段实施计划

### A. 一致性收敛（不依赖大改造，风险最低）— 约 8 人日

**改哪里**：`check_expr.uya:infer_array_access`、`check_expr_extra.uya:checker_check_array_access`、
`interval.uya`（新增除零证明）。

1. **非线性下标兜底**：`infer_array_access` 的 `if linear_expr.is_valid != 0` 补 else，
   走 `verify_expr_bounds_interval`，失败按现成文案报错（与 `check_expr_extra.uya:113` 一致）。
2. **非 i32 下标不再无条件放行**：把 `:65-69`、`:76-79` 两处 `return element_type[0]`
   改成「按 `is_unsigned_type` 走 `_ex` 证明」，即 `_ex` 已经支持的无符号下界。
   发放前先跑判据 4 的快照，这条会动到存量（`buglist.md:1187` 已预警「会拒绝大量写法」）。
3. **除数非零证明**：`check_expr.uya` 的算术检查点，对 `/`、`%` 要求
   `constraint` 里存在该变量的 `!= 0` 或区间不含 0；`interval.uya:1461` 已有
   「除数必须是确定的非零单点」的雏形，复用即可。**注意** `interval.uya:922` 记录过
   编译期除零会让**编译器自己** SIGFPE(136)，新路径不得引入无守卫的常量除法。

**判据**：判据 4 快照差异为 0；`tests/test_nonlinear_bounds.uya`（66 行，正例）仍通过。
**回退**：三项各自独立，都是单函数级改动，`git revert` 单个 commit 即可；无数据结构变化。

### B. 符号上界进约束表（③⑤ 的共同前置）— 约 12 人日

**核心数据结构变化**（照 `types.uya:300` 现有字段写法；这是**表结构**改动，不是 `DynTable`）：

```uya
// types.uya —— TypeChecker 内，紧跟现有 constraint_* 三张表
// 上界来源：0 = 常量（values 就是界），1 = 符号（extra_name 是 &length 曲线）
const CONSTRAINT_BOUND_CONST: i32 = 0;
const CONSTRAINT_BOUND_SYMBOL: i32 = 1;
// 符号界的「比较基准」：len(x) / len(x)-1 / 原样
const CONSTRAINT_SYMBOL_LEN: i32 = 0;
const CONSTRAINT_SYMBOL_LEN_MINUS_1: i32 = 1;
const CONSTRAINT_SYMBOL_SELF: i32 = 2;
```

```uya
// interval.uya —— 参照 struct DynTable（dyn_table.uya:79）的字段风格
// constraint_add 现在返回 void 且满槽静默丢；改为三返回并由调用方判失败。
// 一行注释：不拆 —— 表装配与三个并行数组同下标写入，拆开只会增加漏写风险。
struct ConstraintRef {
    bound_kind: i32,        // CONSTRAINT_BOUND_CONST / _SYMBOL
    symbol_name: &byte,     // bound_kind == _SYMBOL 时的符号名
    symbol_shape: i32,      // CONSTRAINT_SYMBOL_*
    interval: Interval,     // symbol_shape == _SYMBOL_LEN 时，右操作数的区间
}
```

**关键约束**：`symbol_name` 名字的**存储生命周期**必须走
`constraint_expr_name`（`interval.uya:342`，已改用 `compiler_arena_alloc`）。
`buglist.md` P2 条记录过：早先用栈缓冲导致「换变量名结果就变」，别退回去。

**语义**：`interval_within_bounds`（:1004）**不变** —— 符号约束只允许出现在
「比较两个界」的路径上，**不得**被当成有界区间塞回 `Interval`。
理由：`Interval` 是 i32 端点，把「未知的 `s.len`」编码成一个假常量会重演端点反转那条漏洞。
新增独立函数 `verify_symbolic_upper_bound`，与 `verify_linear_expr_upper_from_span_len`
（:1969）同层、同写法。

**怎么不误报（迁移策略，必须照做）**：
1. 先只**注册**符号约束（`i < s.len` 进表），**不动**任何放行/拒绝判定；
   此时判据 4 快照必须**零差异**（纯增量，纯记录）。
2. 再让 `verify_linear_expr_bounds_ex` 在「上界找不到」时额外问一次符号表；
   跑快照，只看 `lib/` 与 `src/` 的差异。
3. 最后才打开切片的 `TYPE_SLICE` 分支（`check_expr_extra.uya:62`）。
   这一步单独一个 commit —— 它才是真正会让 343 处开始被判定的那一下。

**判据**：三步每步都跑判据 4；第 3 步允许差异 > 0 但必须**逐文件清零**并记入 buglist。
**回退**：符号表是纯增量的旁路结构，关掉「第 3 步」这一个开关即回到 B 阶段起点；
A 阶段的收益不受影响。

### C. 循环不变式（③）+ 指针形参空检查（⑥）— 约 10 人日

**改哪里**：`main.uya:743-780`（while）、`check_node_extra.uya:488-507`（for）、
`check_stmt.uya` 的形参处理、`interval.uya:pointer_is_nullable`（:143）。

1. **③ 循环不变式**：现状是「进体前提取一次（`main.uya:764`），出体整段恢复
   （`main.uya:777`）」。最小可行版：体内每次遇到 `i = i + k`（k 为常量正数）就**重算**
   该变量的上下界，而不是丢掉；即把 `constraint_update_for_increment`
   （`interval.uya:299`）真正接到循环体的赋值检查上。**不要**做「收紧被改坏的那一侧」
   —— `buglist.md:489-497` 记录的那版正是这个思路，炸了 104 个错误。
2. **`for 0..s.len`**：`check_node_extra.uya:497-507` 目前只认常量端点
   （`checker_eval_const_expr_ex` 失败就不加约束）。改为常量失败时走 B 的符号路径。
3. **⑥ 形参空检查**：`pointer_is_nullable` 只看登记集合，而形参从不进集合
   （`check_stmt.uya:333` 只处理 `var` 声明）。加「`&T` 形参默认可空」+ 调用点
   `bad(null)` 告警。风险：全树所有解引用裸 `&T` 形参的函数会同时报错，**先做**
   `pointer_nonnull_add` 的形参版迁移（同 B 的三步法）。

**判据**：`tests/repros/bounds_loop_body_not_proved.uya` 与
`null_param_deref_not_checked.uya` 转为 `tests/error_*.uya` 后能被 `make check` 判为「预期失败」。
**回退**：③ 与 ⑥ 是两个独立 commit；循环不变式回退 = 恢复「出体丢弃」的旧语义，
只丢精度、不引入不健全。
**人日**：③ 4 + ⑥ 4 + 迁移 2。

### D. 可伸缩性（定长表改可增长）— 约 6 人日

**参考实现**：`dyn_table.uya`（290 行）。它给出的是「**非泛型字节缓冲 + elem_size 运行时给**」
的现成范式 —— 文件头 :12-30 明确说明为什么不能用 `DynTable<T>`：
**uya 0.10 的 checker 在字段访问处不落实泛型实参 T**，表能写不能读。

**要动的地方（按耦合度排序）**：
1. `types.uya:26` `MAX_CONSTRAINTS = 64` + `types.uya:36-42` 那段「初始容量 vs 上限」注释。
2. `interval.uya:21` `g_constraint_sound: [i32: 64]`（**全局**，与约束表**靠下标对齐**，
   是最难改的一处：任何 rehash 都必须同步搬它）。
3. `main.uya:531-535/557-560/599-602/630-633` 六组 `[&byte: 64]`/`[i32: 64]` 栈快照，
   `check_expr_extra.uya:1267-1270` 一组。
4. `MAX_POINTER_NAMES = 32`（`types.uya:25`）及 `pointer_nullable_add`
   （`interval.uya:114`，满槽同样静默丢）。

**判据**：构造一个 >64 条约束的函数（嵌套 if 守卫），当前**静默失败**、改后能证明通过；
加进 `tests/test_*.uya` 作正例。
**回退**：按 `types.uya:36-42` 的既有约定，**初值保持 64**，扩容才增长 ——
这样小工程的容量/性能与改动前逐字节一致，出问题只需把初值调回并禁用增长。
**人日**：表结构 3 + 快照点 2 + 验证 1。

## 5. 测试矩阵

命名约定（`tests/run_programs_parallel.sh:710-714`）：`error_*` = 预期编译失败，
`test_*` = 正例由脚本强制跑通。

| 已覆盖 | 覆盖的环节 |
|---|---|
| `tests/test_bounds_prover_as_usize_cast.uya` | `_ex` 的无符号下界 + 成员访问下标 |
| `tests/test_bounds_interval_wrap.uya` / `error_array_bounds_interval_wrap.uya` | 端点反转「证明不成立就不放行」 |
| `tests/test_nonlinear_bounds.uya` | `*`、`<<` 的区间传播（正例，66 行） |
| `tests/test_ub_safety_guards.uya` | 各类守卫的正确写法 + drop 只一次（22 例） |
| `tests/error_array_bounds_guard_off_by_one.uya` 等 17 个 `error_array_bounds_*` | 常量/证明失败的负例面 |
| `tests/test_slice_range_bounds.uya` / `error_slice_range_oob.uya` | ⑤ 缺口 2（已修） |
| `tests/test_return_expr_bounds.uya` / `error_array_bounds_oob_in_return.uya` | ④（已修） |
| `tests/test_bounds_const_negative_index.uya` / `error_..._negative_index.uya` | ① 常量 -1（已修） |

| 待补 | 对应阶段 |
|---|---|
| `tests/error_array_bounds_nonlinear_no_fallback.uya` | A.1（非线性兜底） |
| `tests/error_array_bounds_non_i32_index.uya` | A.2 |
| `tests/error_div_by_zero_symbolic.uya` | A.3 |
| `tests/test_slice_symbolic_upper_bound.uya` + `error_slice_index_no_proof.uya` | B（⑤ 缺口 1） |
| `tests/test_loop_invariant_increment.uya` + `error_loop_body_stale_bound.uya` | C.1（③） |
| `tests/error_null_param_deref.uya` + `test_null_param_guarded.uya` | C.3（⑥） |
| `tests/test_constraints_over_64.uya` | D |

**现成复现文件**（`ls tests/repros/ | grep bounds`）：
`bounds_loop_body_not_proved.uya`（③）、`bounds_slice_index_not_proved.uya`（⑤）、
`bounds_const_negative_index.uya`、`bounds_const_oob_in_return_cast.uya`、
`bounds_interval_wrap_unsound.uya`、`bounds_prover_as_usize_cast.uya`，以及
`null_param_deref_not_checked.uya`（⑥）。修好后按 ①④⑤ 的先例**升级为 `tests/error_*`**。

## 6. 风险与陷阱

1. **定长表饱和**：`MAX_CONSTRAINTS = 64` 满了 `constraint_add`（`interval.uya:251-255`）
   **静默 return**，不报错 —— 表现为「守卫明明写了却证明失败」，极难定位。
   B 阶段引入符号约束会让表**更快**装满，所以 B 必须与 D 的代价一起算。
   （`types.uya:36-42` 记的正是这条历史教训。）
2. **证明器误报导致自举失败**：编译器要编自己，`lib/` 与 `src/` 一起被检查。
   本仓已有先例：② 的「字段 drop 门」不加会让自举爆 110 个误报（`buglist.md:461`），
   ④ 直接复用 `checker_check_node` 会爆 84 个「变量已被移动」（`buglist.md:515`）。
   **任何收紧都必须先在 `src/` + `lib/` 上跑一遍再合。**
3. **`checker_check_expr_type` 的副作用**：`checker_mark_moved`
   （`symbols.uya:1470`）把名字**追加**进 `moved_names`（`moved_count = idx + 1`，
   :1500），**累加、非幂等**；同一实参被检查两次就必报「变量已被移动」。
   上一轮实测炸出 **24 处**（`buglist.md:380`）。新增的证明路径**只准**读类型，不准复用
   `checker_check_expr_type` 这类会走完整检查的入口。
4. **`-|` / `+|` 与端点回绕**：饱和运算被 `eval_expr_interval` 当成普通算术传播
   （`interval.uya:1900-1910`，注释写的是「单调运算，端点落在同一区间」）。
   但 `interval_add/sub/mul` 内部用 **u32 回绕**消除有符号溢出 UB
   （见 `interval.uya` :1014 上方注释），端点反转已被 `interval_within_bounds`（:1004）
   拦下 —— 这条**已修过一次**，任何改动区间算术的补丁都必须保留
   `min > max ⇒ 拒绝` 这条硬判据，别为了「多证几条」把它放宽。

---

**人日合计**：A 8 + B 12 + C 10 + D 6 = **36 人日**（含迁移与回归，不含评审）。

**新增函数落点与文件行数**（当前 `wc -l`）：`interval.uya` 2371 行（**已超 2000**）、
`check_expr.uya` 4462、`check_expr_extra.uya` 2930、`types.uya` 390、`main.uya` 1244。
→ `verify_symbolic_upper_bound` 放 `interval.uya`（已超线，**不要**再加）；
建议新文件 `src/checker/interval_symbol.uya`（B 阶段新建，从 0 起算），
符号约束的结构体与判定都放那里，`interval.uya` 只保留一个调用点。
