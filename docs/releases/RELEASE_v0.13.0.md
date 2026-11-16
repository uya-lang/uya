# Uya v0.13.0 发布说明

> **类型**：**性能与构建链发行**（minor）
> **发布日期**：2026-11-16
> **语言规范**：0.49.57

**v0.13.0** 没有语言语义变更（规范仍是 0.49.57），全部改动集中在「编译这件事本身有多快」。
三条主线：把检查器里三处「数据量一涨就从 O(1) 变成 O(N)」的结构问题修掉；给 C 阶段的调度与
增量指纹做调优；把每个候选优化的实测结论——**包括被否决的**——写进 `docs/build_speed.md`。

背靠背实测（44 核，同一台机器、old/new 交替，load ≈ 5–7）：

| 场景 | v0.12.0 | v0.13.0 | 差分 |
|---|---:|---:|---:|
| `make uya` 全量强制 | 14.44 / 14.46 s | **12.00 / 12.07 s** | **−17%** |
| `make b` 自举验证 | 27.4 s | **22.2 s** | **−19%** |
| `uya check src/main.uya` | 7.10 s | **3.20 s** | **−55%** |

产物不变：`make b` 自举比对**字节相同**，`make check` **1199/1199** 通过。

---

## 核心变更

### 1. 检查器：三处 O(N) 退化

#### 1.1 顶层可达性 visited 集写死容量（`src/checker/symbols.uya`）

原实现是 262144 个槽位的定长开放寻址表。表满之后
`checker_mark_reachability_node_visited` 直接 `return 1` —— 把「已访问」静默判成「首次访问」，
可达性传播因此退化成指数级重复展开，而且**没有任何报错**（只是越来越慢）。
负载趋近 1 时开放寻址的成功查找平均探测长度本身就按 `1/(1-α)` 发散，实测 `uya check`
有 39% 的时间耗在这个探测回边上。

改成 arena 拥有的**可增长**表：负载因子超过 3/4 时容量翻倍并整表 rehash
（`checker_reachability_visit_grow` / `checker_reachability_visit_ensure`）。初始容量沿用历史值，
小工程不发生扩容，行为与改动前逐字节一致。

#### 1.2 作用域符号查找扫整条链（`src/checker/symbols.uya`）

`symbol_table_lookup` 从最内层作用域逐层扫 `Symbol.next_in_scope` 链表，链上每一跳都要读一个
散落在 400 MB arena 里的 `Symbol`（几乎必然 L1 miss），而直接映射的查找缓存又被「每次插入
自增的 generation」立刻打掉。两处改动：

- `Symbol.name_hash`：插入时算一次 `hash_string` 落盘，查找先比整数、相等才去碰名字的字节；
  去重扫描（`symbol_table_insert`）与退出作用域（`checker_exit_scope`）复用同一份缓存哈希。
- `TypeChecker.scope_buckets`：每层 512 个名字哈希桶（下标 `scope*512 + (hash&511)`，
  链用 `Symbol.next_in_bucket` 串），查找一层只扫一个桶（通常 1~2 个符号）；
  退出作用域时整层桶头清零（`checker_scope_buckets_clear`），保证同层兄弟块看不到上一轮的符号。

> 反向验证过：把哈希桶之外再**删掉**那个直接映射缓存，`uya check` 反而从 3.34 s 涨到
> 4.24~4.48 s —— 缓存本身是有效结构，哈希桶只是把它失配时的代价从「扫整层」降到「扫一个桶」。

#### 1.3 程序级声明线性扫描（`src/checker/lookup.uya`、`macro_expand.uya`）

`checker_fn_decl_owner_type_name`、`checker_fn_decl_is_owned_method` 各自扫「全部 program_decls
× 每个类型的方法表」，`find_macro_decl_from_program` 扫整张声明表，三处合计约 12% 采样。
现在前两者共用一张 **fn_decl →（所属类型名, 是否 union）** 的开放寻址索引
（`ensure_owner_method_index`：首次查询时一遍扫描建好，16384 槽、负载 3/4 记溢出，
溢出即退回线性扫描；插入「先到先得」，与旧实现「decl 顺序里首个匹配胜出」一致），
宏查找改走已有的程序级声明索引（`progdecl_index_find_typed`）。

### 2. C 阶段与增量编译

- **`OBJS` 按实际 C 体积降序（LPT）**：镜像 Makefile 的 `OBJS` 顺序就是 `make` 的启动顺序，
  最大的 TU 必须第一个开工，否则整段 C 阶段被拖成「最慢 TU + 排队时间」
  （背靠背 6.13 s → 5.84 s）。
- **批量哈希**：增量指纹不再「每个文件两个子进程」，改成一次 `sha256sum` + 一次 `stat`
  处理全部源文件与生成物（160+ 个 `.c/.h`、110+ 个源文件，省掉 300+ 次 fork）。
- **大文件切块开关** `UYA_SPLIT_CHUNK=1` 落地并验证正确性（产物逐字节一致、`make b` 通过），
  但 codegen 的每槽位重复开销未消，**默认仍关闭**。

### 3. 可测性：把否决也写下来

`docs/build_speed.md` 新增 §2.2（本轮三项修复的完整实测）与 §8.1（**试过并否决**的方向）：

| 方向 | 实测 | 结论 |
|---|---|---|
| `UYA_SPLIT_CHUNK=1` 切块 | 12.9/14.0 s → 17.3/17.9 s | 净亏，默认关闭 |
| C 阶段分阶段调度（先 `-j3` 编 3 个大 TU 再 `-j44`） | 5.8 s → 9.9 s | 更差 |
| C 阶段加 `-pipe` | 5.71/6.02 s → 5.59/5.78 s（−3%） | 收益不抵跨工具链风险 |
| 删掉符号查找直接映射缓存 | 3.34 s → 4.24~4.48 s | 更差，缓存保留 |

### 4. CI

- 发布闸门只认「标签当前指向的提交」上的 CI 结论；`macos-ci` 降为**仅参考**，
  手动触发 `release-publish` 可开 `allow_red_ci`，但必须同时填 `reason`。
- gcc 专属告警降级改用探针，Apple clang 下不再加（修 `macos-ci` 的 `from-c-native`）。

---

## 升级指南

**没有破坏性变更，升级不需要改代码。**

- `make uya` / `make from-c` 照旧；本次发行刷新了 `backup/uya*.c` 自举种子。
- 语言规范、`--strict-overflow` 口径、默认后端（C99）均不变。
- 可观测差异：`uya check <file>` 与 `make uya` 明显更快；编译器二进制布局（`TypeChecker` /
  `Symbol` 结构体）有变化，但这属于内部实现，不对外暴露。

---

## 统计与验证

| 项目 | 结果 |
|---|---|
| `make b` | ✓ 主编译器与自举编译器产物**字节相同**（cmp） |
| `make check` | ✓ **1199 / 1199** 通过（含自举、证明优化、SIMD/NEON、C99 交叉目标、upm 套件） |
| `bash tests/verify_version_sources.sh` | ✓ `version sources ok (0.13.0)` |
| `make release` | clean 冷启动 → `uya` → `b` → `check` → 种子刷新 → `-O3 -DNDEBUG` + `strip` 发布构建 |

---

## 已知限制

- **切块仍默认关闭**：正确性已验证，但 164 个槽位时 codegen body 阶段 CPU 从 0.94 s 涨到
  6.55 s（每槽位重复开销），把 C 阶段 −28% 的收益吃光。这是下一轮的最高优先项。
- **codegen 局部变量类型查找**（`lookup_identifier_type_c_impl`）仍是线性扫描：它的缓存键必须
  含 `local_variable_count`（局部表存在「count 不变、槽位被覆写」的写法），安全放宽需要在
  ~20 个 push 点统一维护内容代次；而 body 阶段按镜像 TU 并行后，它对墙钟只有约 0.1 s。
- **C 阶段的 makespan 由单个 TU 决定**：`src/codegen/c99/expr.c` 约 1.13 MB，单独编就要 ~4.5 s，
  再加 `-j` 没有意义（实测 `-j8/-j16/-j44` = 6.80/4.83/4.39 s）。
- **`macos-ci` 仍是仅参考**：macOS hosted 主线的既有问题收口后再升回阻断项（见 `buglist.md`）。

---

## 致谢

感谢所有提交 bug 报告、跑全量回归和帮忙盯 CI 的贡献者。本次发行的每一处提速都附了背靠背
实测数据，测量方法写在 `docs/build_speed.md` 的「复现命令」一节。
