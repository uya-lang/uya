# ASTNode 重叠组重构 TODO

**状态**：executable TODO，首次落地进行中
**更新日期**：2026-11-15
**配套设计**：`docs/astnode_overlap_design.md`
**基线口径**：`sizeof(ASTNode)` = 1856 B（扁平）/ **152 B**（重叠组），gcc 探针读 `src/.uyacache/uya_part1_types.h`

---

## A. 已完成（本轮）

- [x] **A1 基线**：`make uya` 通过；探针 `sizeof(ASTNode)=1856 align=8`；`test_overlap_fields`（C99+`--vm`）、`test_json_from_json_slice` / `test_json_struct_collections`（C99+`--vm`）全绿。
- [x] **A2 探针工具**：gcc `sizeof`/`offsetof` 探针（见设计文档 §5.1、§5.3）成为体积与重叠关系的唯一口径。
- [x] **A3 换成重叠组**：`src/ast.uya` 的 `ASTNode` 改为「4 公共字段 + 1 个匿名 union 块（80 组）+ 8 个公共尾字段」，`sizeof` 1856 → **152**，字段集 259 个与扁平版完全一致（脚本比对无差异）。
- [x] **A4 复现回归**：`lib/std/json/encoder.uya:177` 报 `向量比较要求左右操作数都是 @vector(T, N)`（15 条）。
- [x] **A5 最小复现**：缩到 9 行——右侧为内联 `@vector.splat(...)` 时必现，两侧都声明成局部变量时不复现。
- [x] **A6 根因**：`simd_splat_target_type` 单独成组（块 offset 0），却只写在 `AST_CALL_EXPR` 上；写入时把同 offset 的 `call_expr_callee` 抹掉 → `simd_get_vector_builtin_method()` 认不出 splat → 对侧绑定失效。
- [x] **A7 修复**：`simd_splat_target_type` 并入 `call_expr` 组（`src/ast.uya`，附「为什么必须同组」注释）。`sizeof` 仍 152；9 行复现、`encoder.uya`、两个 JSON 用例、`test_overlap_fields` 全绿。
- [x] **A8 永久守卫**：`tests/test_vector_splat_peer_bind.uya`（8 个断言点：内联 splat 参与比较 / 左右互换 / 算术 / 掩码比较 / 多次复用），C99 与 `--vm` 均 rc=0。
- [x] **A9 守卫有效性 A/B**：把 `simd_splat_target_type` 移出 `call_expr` 组重建 → 该用例 13 条报错、`encoder.uya` 15 条报错；恢复后双后端 rc=0、`sizeof` 仍 152。
- [x] **A10 分组不变量评审**：26 个单字段组 × ~200 处写入点按函数归并，8 个「附近无对应 kind」的疑似站点逐一手查，结论全部合规（详见设计文档 §4.4）；`print_expr` 属 `AST_PRINT`/`AST_PRINTLN` 共享的 kind family 组，安全。
- [x] **A11 C99 全量门禁**：`make check` **1196/1197**，唯一失败 `test_tls_x509`（rc=4，ASN.1 整数解析）已用 main 树的平坦版编译器 `bin/uya` 复现 → **既有失败，与本次改动无关**。

## B. `--vm` 专属回归（本轮已定位并修复）

- [x] **B1 `--vm` 全量门禁首跑**：`make exec-census` **907/913**（总数 913、跳过 5）。失败 6 条里
  `test_https_debug/production/real_site` 是 rc=137（环境类超时）、`test_tls_x509` rc=4 是既有失败，
  剩 `test_json_from_json_slice`（rc=4）与 `test_json_struct_collections`（rc=73）是**真回归**：C99 过、
  `--vm` 挂、main 平坦版编译器 `--vm` 也过。
- [x] **B2 字节码/HIR diff**：两版 `--dump-exec-hir` **完全一致**；`--dump-bytecode` 只差 **3 条指令**
  ——多一次「往某结构体字段写零」（`BC_LOAD_CONST(zero)/BC_ADDR_LOCAL/BC_STORE_FIELD`）。
- [x] **B3 组级二分**：写「把 union 里指定组摊平回公共区」的脚本（摊平 = 该组不再与任何组共享存储），
  用例当 oracle。摊平全部 80 组 → 通过（确认是重叠导致）；二分 → 最小必须摊平的是组 17 = `var_decl`。
- [x] **B4 配对搜索**：对 51 个与 `var_decl` 有同 offset 字段的候选组做「union 里只留 17+X」→
  只有 **X=52（`for_stmt`）** 复现，其余 50 个全 PASS。
- [x] **B5 字段级收窄**：`for_stmt` 组只保留前 k 个字段（其余摊平，偏移不变）→ k=6 FAIL、k=5 PASS
  → 撞车字段是 **`for_stmt_range_end`（offset 56）** ↔ **`var_decl_moved_field_src`（offset 56）**。
- [x] **B6 根因**：`src/exec/builder.uya:exec_builder_emit_moved_field_clear()` 读
  `stmt.ast_node.var_decl_moved_field_src` **没校验 kind**；`HIR_STMT_VAR_INIT` 的 `ast_node` 在
  `for … |v|` 降级出的迭代变量初始化处是那个 `AST_FOR_STMT`。平坦结构下该字段独立存储、值为 0（跳过），
  重叠后读到 `for_stmt_range_end`（非空 AST 指针）→ 误判成「有被移动字段」→ 多发射一条字段清零，
  把 `WithSlice.ids` 一类字段打掉 → `out.ids.len` 不等于 3。
- [x] **B7 修复**：加 `stmt.ast_node.type != ASTNodeType.AST_VAR_DECL → return 0` 守卫（与相邻
  `exec_builder_stmt_drop_decl()` 已有守卫一致）。两个 JSON 用例双后端 rc=0，`sizeof` 仍 152。
- [x] **B8 同类站点复查**：`src/exec/*.uya` 里对 `ast_node` 的变体字段读取共 11 处
  （`var_decl_type`×4、`var_decl_was_moved`×1、`var_decl_moved_field_src`×1、`assign_src/dest`×3、
  `array_literal_repeat_count_expr`×1、`type`×3），除 B7 那一处**其余都已有 kind 校验**。
- [x] **B9 全量复验**（修复后同一个 `bin/uya`）：`make check` **1197/1198**（唯一失败 `test_tls_x509` rc=4 既有）；
  `make exec-census` **909/913**（跳过 5，通过率 99.6%；失败 = `test_tls_x509` rc=4 既有 + `test_https_debug` /
  `test_https_production` / `test_https_real_site` rc=137 环境超时）。修复前 `--vm` 是 907/913，
  缺的两条正是 B1 里那两个 JSON 用例 —— 修完自动转绿。
- [x] **B10 文档回填**：A8–A11、B1–B9 已写进 `docs/todo_exec_vm_parity.md` 第 755 轮纪要（含门禁表与 A/B 数字）。

> 回归覆盖说明：B6/B7 这条路径没有新增专用用例 —— 数组迭代 `for s.ids |v| { }` 在 C99 后端
> 目前编不过（`s.ids` 被当成数组做 `sizeof` 下标，属既有 C99 限制），写成用例会挂在 `make check` 上。
> 现成的两个 oracle 就是 `tests/test_json_from_json_slice.uya` 与 `tests/test_json_struct_collections.uya`
> （`make exec-census` 里每次都跑）。

## C. 待做

- [ ] **C1 `src/ast.uya` 头部注释**：写清 I1/I2/I3（同 kind 同组 / 跨组写禁止 / 多 kind 共用提到公共区）与「新增字段先定 kind 再定组」的规矩。
- [ ] **C2 运行时审计模式（可选）**：`ast_new_node` 登记 (节点, kind)，收尾时检查「非本 kind 组的字节仍为 0」，打印 (kind, 组, 字段)。需要 kind→组 映射表，先按需再定。
- [ ] **C3 残余风险登记**：`src/exec/lower.uya:565` 的「整节点拷贝后改 kind」已确认安全（`named_target_node.type` 改写后本组字段全部覆盖写）；新增此类代码需同规矩，写进 `src/exec/lower.uya` 对应注释。
- [x] **C4 量化收益（宿主侧已测）**：负载 =「编译整个编译器树」（`make uya` 全量），每次冷启动删
  `src/build` + `src/.uyacache`，取两次最好值，峰值 RSS 用 `os.wait4` 的 `rusage`：

  | 变体 | 耗时 | 峰值 RSS |
  |---|---|---|
  | 平坦 `ASTNode`（1856 B） | 16.0 s | 2685.6 MB |
  | 重叠组 `ASTNode`（152 B） | 15.6 s | **707.3 MB** |

  → **峰值 RSS 降至 26%（省 1.93 GB，3.8×）**，耗时持平（−2.6%，噪声量级）。
  - [ ] `--vm` 侧 `UYA_PROGRESS=1` 的 `[mem]` 累计与峰值（对照第 751 轮的 34.0 GB 基线）—— 未测：
    `--vm` 的内存主体是 VM 值竞技场（`ExecValue` 深拷贝），与 ASTNode 体积无关，记账要分开（见设计文档 §5）。
  - [ ] `tests/exec_vm_census_mems.txt` 的单用例内存额度是否可下调 —— 未做：同理，额度瓶颈不在 AST。
- [ ] **C5 种子与提交**：`make b`（自举）通过后 `make clean && make backup-all`；`backup/uya.c` 及 hosted 种子随同一提交更新。
- [ ] **C6 回滚预案**：改动集中在 `src/ast.uya` 一个文件，`git revert` 到扁平版成本可控。

---

## 关键命令

```bash
# 体积 / 重叠关系
make uya && gcc -std=c99 -I. -o /tmp/probe_astnode /tmp/probe_astnode.c && /tmp/probe_astnode

# 已知踩字回归
UYA_ROOT=$PWD/lib/ ./bin/uya test tests/test_vector_splat_peer_bind.uya
UYA_ROOT=$PWD/lib/ ./bin/uya test --vm tests/test_vector_splat_peer_bind.uya
./bin/uya check lib/std/json/encoder.uya

# 全量门禁
make check
make exec-census
```
