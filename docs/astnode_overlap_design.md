# ASTNode 结构体重构设计（匿名 union 重叠组）

**状态**：设计 + 首次落地（分组踩字根因已定位并修复，全量验证进行中）
**更新日期**：2026-11-15
**配套 TODO**：`docs/todo_astnode_overlap.md`
**相关历史**：第 681 / 683 / 684 轮（`docs/todo_exec_vm_parity.md`）、提交 `e4b5cfb1`（落地）、`7e30f13a`（回滚）

---

## 1. 问题

`ASTNode` 是编译器唯一的 AST 载体，当前是**全内联扁平结构体**：

| 指标 | 数值 | 来源 |
|---|---|---|
| 字段数 | 259 | `src/ast.uya` |
| `sizeof(ASTNode)` | **1856 B**，align 8 | `gcc` 探针读 `src/.uyacache/uya_part1_types.h` |
| 单节点实际使用宽度 | 4 个公共字段（`type`/`line`/`column`/`filename` = 24 B）+ 某一种 kind 的载荷（≤ 100 B） | 按 kind 逐组统计 |
| 浪费比例 | ≈ **90%+** | 上面的差值 |

代价有两个，都是实测过的：

1. **arena 占用**：本仓库自举（8.7 MB 源码）parse 期 arena ≈ 1.4 GB，即 **~165 字节 arena / 字节源码**（`src/parse_parallel.uya:49` 的经验系数即由此测得）。
2. **cache 局部性**：遍历兄弟节点时每个节点跨 1856 B，等于每次跳 29 个 64 B cache line。parse/check/codegen 全是 tree walk，这是纯损失。

> 与 `--vm` 的关系先划清（**重要，避免把两件事混在一起**）：
> `--vm` 的内存放大主要**不是** ASTNode 造成的。VM 里结构体的「值」表示成 `ExecValue` 数组（**每字段一个槽，`sizeof(ExecValue)` = 56 B**），按值语义深拷贝，且编译器自己的 arena 是**原生内存**（`ARRAY_BUFFER_SIZE` 64 MB 的 raw array → 宿主 malloc），AST 节点走原生字段通道、每节点就是 `sizeof(ASTNode)`。
> 实测：解释执行编译器 check 一个 13.6 KB 的源文件，VM 值竞技场累计 **768 MB**，而同一份文件的 AST arena 只有 ~2 MB 量级；`--vm` 自举 25.9 GB 的竞技场里没有 `count=259` 的聚合（`[agg-recycle]` 计数最大 256/128/26）。
> 结论：**压缩 ASTNode 收益是「arena 与 cache」这条线，不是「VM 值竞技场」那条线**；两条线要分开记账。

---

## 2. 方案比较

| 方案 | 体积 | 改动面 | 判定 |
|---|---|---|---|
| **A. 扁平结构体（现状）** | 1856 B | — | 基线 |
| **B. 位域/字段瘦身**（把 96 个 i32 标志位压成 bitfield） | 约 1600 B | 小 | 收益太小，放弃 |
| **C. 按 kind 拆 payload + 指针**（`payload: &void`） | 24 + 8 + payload | **3986 处访问点 / 82 文件** | 改动面不可接受 |
| **D. 匿名 union 重叠组（本方案）** | **152 B**（12.2×） | **0 处访问点**（字段仍写 `node.field`） | ✅ 采用 |

方案 D 的关键性质：**字段名访问不变**，只有布局变。它是语言特性（第 683 轮落地，规范 0.49.57），语法：

```uya
struct ASTNode {
    type: ASTNodeType,          // 公共字段，所有 kind 共用（在 union 之外）
    line: i32,
    column: i32,
    filename: &byte,
    union {
        struct { /* struct_decl 载荷 */ }
        struct { /* fn_decl 载荷 */ }
        ...
    }
    is_optimized: i32,          // 跨 kind 使用的字段必须留在 union 之外
    ...
}
```

同一 union 块内各 `struct` 组**从块首开始、共享同一段存储**；块大小 = max(组大小)，块偏移按块内最大对齐向上取整。

---

## 3. 分组不变量（本设计的核心，踩坑全出在这里）

字段按「**写在哪种 kind 的节点上**」归组。三条硬约束：

1. **I1 同 kind 同组**：某种 kind 使用的所有载荷字段必须在**同一个组**里。违反 → 该 kind 的两个字段互相覆盖。
2. **I2 跨组写禁止**：某字段只能写在「拥有它的组对应的那个 kind」的节点上。跨组写（例如把 `simd_splat_target_type` 写在 `AST_CALL_EXPR` 上，而它单独成组）会**抹掉该组 offset 上的字段**——这就是三次「踩字」的真身。
3. **I3 多 kind 共用 → 提到公共区**：被 ≥2 种 kind 使用的字段（例如优化器标记 `is_optimized`/`inlined_body`/`is_dead_code`）**不能进 union**，必须留在块外，否则必然违反 I2。

推论（评审时必须逐条问）：
- 每个组必须**只服务一种 kind**（或一组结构上互斥、语义上永不共存的 kind）；
- 「helper / 派生字段」最危险：它常按名称自成一类，却写在别人的节点上。**本轮的真凶就是这个**（见 §4）。

---

## 4. 事故档案与本轮根因

### 4.1 第 683 轮：落地 1848 → 152，随后回滚

`e4b5cfb1` 把 ASTNode 改成重叠组（1848 → 152 B，「src/ 下 3986 处字段访问一行没改」），但 `census` 抓到两例回归：

```
test_json_from_json_slice     VM 返回码 4  （out.ids.len != 3）
test_json_struct_collections  VM 返回码 73 （slice_out.points.len != 2）
```

定位到「有代码在 `var_decl` 组 offset 8 写了一个指针，而 `block` 组的 `block_stmt_count` 正好也在 offset 8」，但**没能揪出具体写入点**；为正确性回滚成扁平布局（`7e30f13a`），语言特性保留。

### 4.2 本轮（2026-11-15）：根因定位

把 ASTNode 重新换成重叠组后，回归以另一种面貌出现：

```
lib/std/json/encoder.uya:(177:41): 错误: 向量比较要求左右操作数都是 @vector(T, N)   ×5，×3 遍 = 15
```

最小复现（9 行，`tests/test_vector_splat_peer_bind.uya` 即由此固化）：

```uya
export fn main() i32 {
    const c: @vector(u8, 16) = @vector.splat(7u8);
    const m: @mask(16) = c != @vector.splat(34u8);   // ← 这里报错
    ...
}
```

二分结论：两侧都声明成局部变量（`c != d`）**不报错**；只有右侧是内联 `@vector.splat(...)` 时才报错 → 说明「从对侧向量绑定 splat 目标类型」这条路径失效。

根因在**分组表**上：

```
group31: call_expr_callee:&ASTNode, call_expr_args, call_expr_arg_count, ...   // offset 0 = call_expr_callee
group77: simd_splat_target_type:&ASTNode                                      // offset 0 = 同一个字
```

而 `simd_splat_target_type` **只写在 `AST_CALL_EXPR` 节点上**：

- `src/checker/check_expr.uya:2404 / 2439 / 2494 / 2522`：`expr.simd_splat_target_type = target_ast;`（同一函数里紧邻 `expr.call_expr_args[...]` 的读写）
- `src/checker/check_call.uya:1514 / 1538 / 1561 / 1584`：`node.simd_splat_target_type = ...`（`node` 是 call 节点）
- 读取点 `check_expr.uya:2570 checker_expr_is_unbound_vector_splat()` 先走 `simd_get_vector_builtin_method(expr)` → 它要读 `call_expr_callee`

于是写 `simd_splat_target_type`（offset 0）**把被调方指针 `call_expr_callee` 抹成裸类型节点**，`simd_get_vector_builtin_method()` 认不出这是 `@vector.splat`，绑定路径被跳过，splat 的类型停在 void → 「向量比较要求左右操作数都是 @vector」。

**修复**：把 `simd_splat_target_type` 并入 `call_expr` 组（`src/ast.uya`，附注释说明为什么必须同组）。修完 9 行复现、`encoder.uya`、两个 JSON 用例、`test_overlap_fields` 全绿，`sizeof` 仍为 152。

> 与第 683 轮那次的关系：同一类错误（违反 I1/I2），上次卡在没有定位手段。本轮的定位手法可复用：
> **①最小复现**（把库文件缩到 9 行）→ **②按「两侧都声明 vs 内联」二分**（区分「类型推断路径」还是「数据本身」）→ **③按代码路径回读字段**（`checker_expr_is_unbound_vector_splat` → `simd_get_vector_builtin_method` → `call_expr_callee`）→ **④回到分组表验证 offset 是否撞车**。

### 4.3 已知残余风险（尚未出事故，但结构上同类）

| 风险点 | 说明 | 处置 |
|---|---|---|
| 整节点按值拷贝后改 kind | `src/exec/lower.uya:565` `named_target_node[0] = target[0]; named_target_node.type = AST_TYPE_NAMED;` 把别组字节一并拷进来 | 拷完必须覆盖本组全部字段；本组字段都要写 |
| 合成的节点 | `exec/lower.uya` 里多处 `compiler_arena_alloc(@size_of(ASTNode))` + `memset(0)` + 手写 kind，**不走 `ast_new_node`** | 必须 `memset` 后再逐字段写（已如此），新增处需同规矩 |
| 单字段组 | 26 个组只有一个字段（`identifier_name`、`string_literal_value`、`print_expr` …），offset 0 直接撞别的组 | 每组逐一登记「哪些 kind 写它」，见 §4.5 |
| **缺 kind 守卫的组字段读取** | 拿着一个「可能是别的 kind」的节点指针直接读变体字段（`stmt.ast_node.var_decl_*`），平坦结构里读到的是「该字段真没被写过 = 0」，重叠后读到的是**邻组同 offset 字段的真实值** | 读变体字段前一律校验 `node.type`，见 §4.4 |

### 4.4 事故 2（本轮）：`--vm` 专属回归 —— `var_decl_moved_field_src` 与 `for_stmt_range_end` 同处 offset 56

**现象**：`sizeof` 已经是 152、`make check`（C99）只剩一个既有失败，但 `make exec-census` 掉两条：

```
test_json_from_json_slice.uya    --vm rc=4    （out.ids.len != 3）
test_json_struct_collections.uya --vm rc=73   （slice_out.points.len != 2）
```

两条都是「C99 过、`--vm` 挂」，且用 main 树的平坦版编译器 `bin/uya` 跑 `--vm` 同样的用例**通过** → 真回归，不是 VM 既有 bug。

**定位链（这套手法建议固化成流程）**：

1. **字节码 diff**：`./bin/uya run --vm <用例> --dump-bytecode`，两版只差 **3 条指令**（多出 `BC_LOAD_CONST(zero) / BC_ADDR_LOCAL / BC_STORE_FIELD`，即凭空多一次「往某结构体字段写零」）。跳转目标位移是它的副作用，忽略。
2. **HIR diff**：`--dump-exec-hir` 两版**完全相同** → 差别不在降级出的树上，而在**发射字节码时读到的数据**。
3. **组级二分**：写一个「把 union 里指定组摊平回公共区」的脚本（摊平 = 该组不再与任何组共享存储），用两个 JSON 用例当 oracle。
   - 摊平全部 80 组 → 用例通过（确认是重叠导致的）；
   - 二分 → 最小必须摊平的组序号 **17 = `var_decl`**；
   - 再对 51 个「与组 17 有同 offset 字段」的候选组做「union 里只留 17+X」→ **只有 X=52（`for_stmt`）复现**。
4. **字段级收窄**：让 `for_stmt` 组只保留前 k 个字段（其余单独摊平，偏移不变），k=7 → FAIL、k=6 → FAIL、k=5 → PASS → 撞车字段是**第 6 个字段 `for_stmt_range_end`（offset 56）**，与 `var_decl_moved_field_src` 同 offset。
5. **回到代码**：`src/exec/builder.uya:exec_builder_emit_moved_field_clear()` 读 `stmt.ast_node.var_decl_moved_field_src` 决定要不要「把移动源字段清零」，**没有校验 `stmt.ast_node` 的 kind**。而 `HIR_STMT_VAR_INIT` 的 `ast_node` 在 `for x in a..b` 降级出来的迭代变量初始化处，指的就是那个 **`AST_FOR_STMT`** 节点 —— 平坦结构下 `var_decl_moved_field_src` 是独立字段、值为 0（跳过）；重叠后读到的是 `for_stmt_range_end`（非空 AST 指针）→ 误判成「有被移动的字段」→ 多发射一条字段清零。

**修复**：给 `exec_builder_emit_moved_field_clear()` 加 `stmt.ast_node.type != ASTNodeType.AST_VAR_DECL → return 0` 守卫（与相邻的 `exec_builder_stmt_drop_decl()` 已有的守卫保持一致）。修完两个 JSON 用例双后端全绿，`sizeof` 仍 152。

> 为什么 C99 后端不中：`src/codegen/c99/stmt.uya:2741` 读的是 `stmt.var_decl_moved_field_src`，那里的 `stmt` 本来就是类型的 **`VarDecl *`**，不可能是 `for` 节点；出问题的是 VM 侧 `HIRStmt.ast_node` 这个「复用字段」——同一个字段在不同语句 kind 下指向不同的 AST 节点。

> 教训：**平坦结构会「掩盖」所有缺失的 kind 守卫**——因为每个变体字段都是独立存储，读错 kind 的字段只会读到 0（或垃圾，通常为 0）。
> 一旦换成重叠组，「读错 kind 的字段」立刻变成「读到邻组的真实指针」。所以**每个变体字段读取点都必须证明 kind**（对应 §3 的 I2）。

### 4.5 26 个单字段组的写入审计（本轮已完成）

方法：把每个单字段字段的全部 `.<field> =` 站点按所在函数归并（26 组共 ~200 处写入），再挑出「所在函数附近看不到对应 kind」的 8 个站点逐个手查，最后用 `offsetof` 探针确认「谁和谁共享同一个 offset」。

| 组 | 字段 | 写入点 | 结论 |
|---|---|---|---|
| 10–16 | `mc_{eval,code,ast,error,interp,type,source}_operand` | parser + `deep_copy_ast_internal` | ✅ 只写在 `AST_MC_*` 节点上 |
| 27 | `await_expr_operand` | parser / deep_copy / `c99_async_await_result_ast` | ✅ 只写在 `AST_AWAIT_EXPR` 上 |
| 38 | `len_expr_array` | parser + deep_copy | ✅ `AST_LEN` |
| 41 | `identifier_name` | 45 处 / 38 函数（含 `exec/lower.uya:5118` 合成 ident、`parser/primary.uya:1064` 的 `null`） | ✅ 手查两处疑似点：节点分别由 `AST_IDENTIFIER` 创建，合规 |
| 44 | `bool_literal_value` | `create_bool_literal` + parser + deep_copy | ✅ `AST_BOOL` |
| 46 | `string_literal_value` | 9 处；手查 `primary.uya:774` | ✅ 节点由 `AST_STRING` 创建 |
| 48 | `char_literal_value` | parser + deep_copy | ✅ `AST_CHAR` |
| 53 | `return_stmt_expr` | 13 处；手查 `lower.uya:8722` 的 `rewritten.return_stmt_expr = catch_expr` | ✅ 该处 `stmt` 只可能是 `VAR_DECL`/`RETURN_STMT`（`exec_lower_pipeline_stmt_operand()` 只在这两种 kind 上返回非空），else 分支穷尽 |
| 54/55 | `defer_stmt_body` / `errdefer_stmt_body` | 仅 `parser_parse_statement` | ✅ |
| 64 | `type_error_union_payload_type` | 32 处 / 21 函数 | ✅ 全部作用在 `AST_TYPE_ERROR_UNION` 上（`type_to_ast` / `substitute_type_ast_for_mono` 先造该 kind 再填） |
| 66/67 | `ptr_from_usize_value` / `usize_from_ptr_ptr` | parser + `gen_expr` + deep_copy | ✅ |
| 68/69 | `error_id_operand` / `error_name_operand` | parser + deep_copy | ✅ |
| 71 | `va_end_ap` | parser + deep_copy | ✅ |
| 75 | `print_expr` | 6 处 / 3 函数 | ✅ **kind family 共享组**：只有 `AST_PRINT` 和 `AST_PRINTLN` 用它，且两者都只用这一个字段（`AST_PRINTLN` 没有别的载荷字段），重叠是安全的 |
| 76 | `type_atomic_inner_type` | parser / deep_copy / `substitute_type_ast_for_mono` | ✅ `AST_TYPE_ATOMIC` |
| 78 | `type_mask_size_expr` | 6 处 / 5 函数（`c99_gen_simd_builtin_call`、`c99_resolve_simd_type_ast_from_expr`、`type_to_ast`） | ✅ 全部作用在 `AST_TYPE_MASK` 上 |

结论：**单字段组本身不是缺陷**——它只是「该 kind 只有一个载荷字段」的直写结果；风险全在「是否被写到别的 kind 上」。I2 是唯一需要守的纪律，本轮审计未发现新的违规（`simd_splat_target_type` 是唯一一处，已修）。

---

## 5. 验证方法（可复现，全部无估算）

1. **体积探针**（唯一权威口径，不用手算）：

   ```bash
   make uya                      # 产出 src/.uyacache/uya_part1_types.h
   cat > /tmp/probe_astnode.c <<'EOF'
   #include <stdio.h>
   #include "src/.uyacache/uya_part1_types.h"
   int main(void) { printf("sizeof(ASTNode)=%zu align=%zu\n", sizeof(struct ASTNode), _Alignof(struct ASTNode)); return 0; }
   EOF
   gcc -std=c99 -I. -o /tmp/probe_astnode /tmp/probe_astnode.c && /tmp/probe_astnode
   ```

   基线 1856 / 8；重叠组 152 / 8。

2. **分组审计脚本**（静态，扫 `src/ast.uya` 的分组表）：列出「字段前缀与所在组主流前缀不一致」的字段，以及所有单字段组。本轮用它一次就剩 3 条待核（其中 2 条是公共区误报、1 条是刚修的 `simd_splat_target_type`）。

3. **`offsetof` 探针**（权威的「谁和谁重叠」表）：从 `src/.uyacache/uya_part1_types.h` 里抽出 259 个字段名，生成对每个字段取 `offsetof(struct ASTNode, f)` 的 C 程序，把结果按 offset 排序。拿到「同 offset 字段集合」后再和「写入点所属 kind」对账——这是"跨组写是否真踩字"的判定依据，比读代码可靠。脚本骨架：

   ```python
   # 1) 从生成的头文件里正则抽出 struct ASTNode 内的字段名
   # 2) 生成 printf("%zu <field>\n", offsetof(struct ASTNode, <field>));
   # 3) gcc 编译运行，按 offset 分组
   ```

4. **写入点 kind 审计**：对每个组，把「写该组字段」的所有 `.<field> =` 站点按所在函数归并，检查这些函数创建/操作的是不是该组对应的 kind。命中「函数里看不到该 kind」的站点再逐个手查——本轮的 8 个疑似站点全部手查过，结论见 §4.5。

5. **最小复现用例**：每个已知踩字点固化一个小用例（本轮：`tests/test_vector_splat_peer_bind.uya`）。

6. **「摊平 + 二分 + 配对 + 收窄」四步定位法**（本轮 `--vm` 回归就是这么钉死的，脚本约 80 行、可随时重写）：
   - **摊平**：把 `src/ast.uya` 里 union 块的指定组改写成「块外独立字段」（不动字段名和顺序，所以 `offsetof` 与访问点全不变），
     让这组不再与任何组共享存储。支持 `all` / `none` / `0-39` / `5,9,13` / `all-not:17,52`。
     **校验点**：`all` 时 `sizeof(ASTNode)` 必须回到 1856——回到 1856 就说明「摊平」本身没引入别的变化。
   - **二分**：以失败用例为 oracle（`./bin/uya test --vm <用例>` 的退出码），二分「必须摊平的组序」，得到最小集合。
   - **配对**：`union` 里只保留「主嫌疑组 + X」，对每个候选 X 跑一次构建 + 用例（51 个组 × ~20 s ≈ 17 min，可接受）。
   - **字段收窄**：让某组只把前 k 个字段放进 union（其余摊平，偏移不变），二分到具体字段。
   - **收尾**：拿到 (组A,字段a) ↔ (组B,字段b) 同 offset 后回到代码找「读/写它却没校验 kind」的站点。
   - 经验：这套流程的价值不在「快」，而在**把 259 个字段 × 80 组的组合空间压成 1 个二元问题**，
     oracle 是编译器自己的退出码，不需要人读代码猜。

7. **门禁**：`make check`（C99 全量）与 `make exec-census`（`--vm` 全量），两个后端都不许回归；`test_overlap_fields` 必须 5/5（C99 + `--vm`）。

8. **收益量化**：`/usr/bin/time` 或 python `resource` 取 `ru_maxrss` + 编译耗时；`--vm` 侧看 `UYA_PROGRESS=1` 的 `[mem]` 累计。

---

## 6. 自举与种子

- 现在的 `backup/uya.c` **已经认识**匿名 union 重叠块语法（`grep -c var_decl_overlap_block backup/uya.c` = 11），所以**不需要第 683 轮那套两阶段摊平自举**：直接改 `src/ast.uya` → `make uya` 即可。
- 但如果把种子回退到 11-12 之前的版本，就必须走两阶段（stage1 摊平字段编出懂语法的 `bin/uya`，stage2 恢复 union 版再自举），并且**必须 `make backup-seed`**，否则干净克隆再也冷启动不起来。这条纪律写进 TODO。

---

## 7. 结论与不做的事

- 采用**方案 D**：匿名 union 重叠组，`sizeof(ASTNode)` 1856 → **152 B**，零访问点改动。
- **不做**：按 kind 拆分 payload 指针（3986 处改动）、位域瘦身（收益 <15%）。
- **必须做**：分组不变量评审（I1/I2/I3）、单字段组逐个登记、踩字回归用例、全量门禁、种子刷新。
- 收益口径要分开记账：**arena/cache**（本方案）与 **VM 值竞技场**（另一条线，见 `docs/todo_exec_vm_parity.md` 第 745/751 轮）。

### 7.1 实测收益（2026-11-15，同一台机器、同一份源码）

负载 =「编译整个编译器树」（`make uya` 全量，前端 + C99 生成 + cc），每次冷启动删 `src/build` 与
`src/.uyacache`，两个变体各跑 2 次取最好值，峰值 RSS 用 `os.wait4` 的 `rusage`：

| 变体 | 耗时 | 峰值 RSS |
|---|---|---|
| 平坦 `ASTNode`（sizeof=1856） | 16.0 s | 2685.6 MB |
| 重叠组 `ASTNode`（sizeof=152） | 15.6 s | **707.3 MB** |

**峰值 RSS 降到 26%（省 1.93 GB，3.8×）**，耗时持平（−2.6%，在噪声量级）。
这与「节点体积 12.2×」不完全成正比，是因为编译期间的内存不止 AST arena（还有 checker 表、
模块缓存、生成的 C 文本等固定开销）。

### 7.2 门禁状态

| 门禁 | 结果 |
|---|---|
| `make check`（C99 全量） | 1197 / 1198（唯一失败 `test_tls_x509` rc=4，**既有失败**，main 平坦版同样复现） |
| `make exec-census`（`--vm` 全量） | 909 / 913，跳过 5（失败 = 上述 `test_tls_x509` + 3 条 `--vm` https 用例 rc=137 环境超时） |
| `tests/test_overlap_fields.uya` | C99 + `--vm` 均通过 |
| `tests/test_vector_splat_peer_bind.uya`（本轮新增守卫） | C99 + `--vm` 均通过 |
