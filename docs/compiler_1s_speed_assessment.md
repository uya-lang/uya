# Uya 编译器 1 秒编译目标评估

**日期**: 2026-06-04
**目标**: 评估将 `uya` 编译器自身编译时间压入 1 秒的可行路径。
**当前结论**: 以当前 Linux x86_64 本机、`bin/uya` 默认 `-O2` 产物为准，直接生成 C99 的前端路径仍约 20 秒；`make uya` 真实落地约 30 秒。进入 1 秒不能靠单点微优化，需要同时做 codegen 查找索引化、编译器入口裁剪、增量 C 落地和常驻/增量前端。后续目标还必须纳入内存压降，避免用更大的常驻表、IR 或输出缓冲换取表面 wall time；所有程序规模相关表必须动态增长，不能靠写死容量达标。
**配套设计**: [`compiler_1s_architecture_design.md`](compiler_1s_architecture_design.md)
**配套 TODO**: [`todo_compiler_1s.md`](todo_compiler_1s.md)

## 当前实测

工作树干净，测试口径如下：

- 直接编译器口径：`UYA_ROOT="$PWD/lib/" UYA_PROFILE_CODEGEN=1 ./bin/uya src/main.uya -o /tmp/uya-direct-profile.c --c99 --nostdlib --safety-proof`
- Makefile 口径：`make uya`
- 源文件规模：自动依赖共 86 个文件，AST 合并后约 3828 个声明。

| 口径 | wall | parse | check | opt | codegen | total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 直接生成 C99 | 20.45s | 674ms | 4683ms | 390ms | 14002ms | 19751ms |
| `--no-safety-proof` | 19.06s | 794ms | 4233ms | 360ms | 12883ms | 18272ms |
| `--opt=0` | 19.25s | 804ms | 4531ms | n/a | 13088ms | 18433ms |
| `make uya` | 29.98s | 未展开 | 未展开 | 未展开 | 未展开 | 真实落地 |

`UYA_PROFILE_CODEGEN=1` 子计时：

| codegen 子段 | 时间 |
| --- | ---: |
| precollect | 1679ms |
| header | 0ms |
| step1_typedef | 2ms |
| step6_mid | 418ms |
| step6e_tail | 233ms |
| prelude | 2334ms |
| body | 11666ms |
| total | 14000ms |

`body_ms` 占 codegen 约 83%，是第一主战场。

### Phase 0 冷构建时间 baseline

2026-06-04 使用当前 `bench-compiler-1s` 硬 KPI 口径复测：

```bash
bash scripts/bench_compiler_1s.sh --runs 3 --keep-logs
```

运行环境：commit `15216ade5671`，branch `1.0`，Linux x86_64，28 CPU，`cc`，C99 backend，未设置 `CFLAGS`，未启用 native。该脚本每轮主动清理 `bin/`、`src/build/`、`src/.uyacache/`，因此结果比上方旧 `make uya` 约 30 秒口径更接近 1 秒硬目标的冷构建定义。

| run | total_ms | total_s |
| --- | ---: | ---: |
| 1 | 74676 | 74.676 |
| 2 | 74278 | 74.278 |
| 3 | 74337 | 74.337 |
| median | 74337 | 74.337 |

结论：当前硬口径冷构建时间 baseline 为 74.337s median，距离 1s 目标约 74.3x；后续性能阶段必须同时报告该口径前后对比。

### Phase 0 冷构建内存 baseline

同一次三轮 `bench-compiler-1s` 运行得到的内存和输出基线：

| run | peak_rss_kb | peak_rss_mib | output_bytes | output_mib | arena_peak_bytes | table_stats |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | 2103824 | 2054.5 | 15236271 | 14.53 | NA | unavailable |
| 2 | 2104400 | 2055.1 | 15236271 | 14.53 | NA | unavailable |
| 3 | 2102676 | 2053.4 | 15236271 | 14.53 | NA | unavailable |
| median | 2103824 | 2054.5 | 15236271 | 14.53 | NA | unavailable |

结论：当前硬口径 peak RSS baseline 为 2,103,824 KiB median，约 2.01 GiB；输出产物 baseline 为 15,236,271 bytes。`make uya` 日志当前未暴露 compiler 内部 `arena_peak_bytes` 和动态表统计，所以这些字段仍为 `NA`，不能用于内部内存达标判断。

### Phase 5A 更新：arena / 动态表内存字段已落地（2026-06-06）

Phase 5A 把 parser AST、checker 工作内存、C99 emitter 拆为独立 arena（详见
[`compiler_1s_architecture_design.md`](compiler_1s_architecture_design.md) 12.5），并让
`compile.sh` 在普通模式透出编译统计的内存字段，因此 `make uya` 日志与
`make bench-compiler-1s` 不再为 `NA`。单轮真实冷构建（`make clean && make uya`，直接 C99）实测：

| 字段 | 值 |
| --- | ---: |
| peak_rss_kb | 2,141,652 |
| arena_peak_bytes（driver+ast+check+emit 合计） | 1,395,852,048 |
| ast_arena_peak_bytes | 1,207,713,896 |
| check_arena_peak_bytes | 77,056,144 |
| emit_arena_peak_bytes | 10,018,544 |
| table_count（动态表项数） | 683,234 |
| table_capacity | 3,219,324 |
| table_bytes（实占） | 3,469,475 |
| table_capacity_bytes | 31,566,927 |
| table_realloc_count | 229 |

说明：peak RSS 相比 Phase 0 baseline 略升约 1.8%（动态 arena chunk 改为零初始化 + 堆分配），
属预期；arena 拆分本身不降 RSS，只是把 AST（约 1.2 GB）单独可见、可在后续按阶段释放。
旧全量 C99 入口下真正的 25% RSS 下降（L382）与“AST/TypedProgram/LoweredProgram 不再无界同时常驻”（L416）
仍需在 Phase 5A 后续做按阶段释放，本表为其提供可量化基线。动态表 `capacity/count≈4.7`，
低于 benchmark 告警阈值 8，且 `realloc_count=229>0`，由 `tests/verify_dynamic_table_budget.sh`
门禁确认容量是按需增长而非启动超大预分配。

### Phase 7 更新：launcher 硬口径 peak RSS 已低于 Phase 0 25% 阈值（2026-06-07）

入口瘦身后，`make uya` 只重建 `src/main.uya` launcher，完整编译器业务外置到
`bin/cmd/*`。按 `bench-compiler-1s` 硬 KPI 口径复测：

```bash
bash scripts/bench_compiler_1s.sh --runs 1 --baseline-rss-kb 2103824 --keep-logs
```

| 字段 | 值 |
| --- | ---: |
| baseline_peak_rss_kb | 2,103,824 |
| current_peak_rss_kb | 370,824 |
| change_pct | -82 |
| arena_peak_bytes | 130,279,816 |
| ast_arena_peak_bytes | 84,553,048 |
| check_arena_peak_bytes | 22,311,088 |
| emit_arena_peak_bytes | 2,360,760 |
| total_ms | 27,944 |

结论：当前硬口径 peak RSS 已远低于 Phase 0 baseline 的 75% 阈值，因此
`docs/todo_compiler_1s.md` L382 达标。注意这并不表示旧全量 C99 编译器输入的 AST 常驻问题已经
结构性消失；它表示 1s 目标的主入口已通过 launcher split 避开全量业务常驻。

同一工作树下，用 build 子命令直接走 C99 编译 launcher：

```bash
UYA_ROOT="$PWD" bin/cmd/build src/main.uya -o /tmp/uya-direct-c99-total-kpi --no-split-c --project-root src/
```

实测 `总耗时: 852 ms`（parse 413ms、check 332ms、emit 84ms），低于 Phase 6 L470 的
`<8000ms` 目标。

### Phase 5A 更新：native 输出策略收口（2026-06-07）

`src/codegen/native/elf64.uya` 新增 production-oriented streaming writer：

- `elf64_write_executable_stream(FILE*, code, code_len, ...)` 只在栈上保留
  `ELF64_MIN_EXEC_HEADERS`（120 bytes）header 缓冲，先 `fwrite` header，再直接 `fwrite`
  机器码输入，不构造 `headers + code` 的完整 ELF 镜像副本。
- `elf64_native_debug_section_count()` 固定返回 `0`，v1 native ELF 输出不生成 `.debug_*`/DWARF
  section。
- 原 `elf64_write_executable(buf, ...)` 继续作为字节编码测试/小缓冲 helper 保留；native 输出主路径
  应接入 streaming writer。

新增验证：

```bash
bash tests/verify_native_output_policy.sh
bash tests/verify_native_elf64_encoding.sh
```

其中 `verify_native_output_policy.sh` 同时做源码合同检查和 Uya runtime 测试：实际 streaming 写出
`120 + 4` 字节 ELF，确认 `e_shnum=0`、`e_shstrndx=0`、机器码紧随 header，且
`elf64_stream_peak_temp_bytes(4096)` 仍为 `120`。

### Phase 5A/6 更新：C99 发射阶段已是"收口的流式写"（2026-06-06）

L393 关心的是"C99 输出从全局状态 + 边生成边补发收口为 unit 流式写"。实测结论：

- C99 输出本就是 `FILE*` 流式写（`emit_stream` 直接 `fputs/fprintf`，split-C 模式按 part1/part2
  与镜像 .c 动态切换写入目标），不存在"先在内存攒全量再 flush"。
- "边生成边补发"对应六张待输出表（string/slice/simd/embed/embed_dir，外加既有
  mono/err_union/async_frame）。原 emitter-start 稳定性快照只覆盖 mono/err_union/async_frame
  （Phase 5 KPI L379-381）。本次把快照扩展到全部六张待输出表，并新增统一开关
  `UYA_STRICT_C99_EMITTER=1`：发射阶段（原型 + 函数体，快照点 → 校验点）任一待输出表增长即报
  漂移；strict 时直接令 codegen 失败。
- 在自举编译器本体 `src/main.uya`（1 秒硬目标输入）实测，emitter 启动快照为
  `string=6199 slice=3 simd=0 embed=0 embed_dir=0`，发射全程**零漂移**——末尾
  `emit_pending_*` 补发对该输入是空操作，即发射已是无新发现的稳定流式写。覆盖插值、@embed、
  JSON 反射、async 等代表性输入同样零漂移。
- 新增回归 `tests/verify_c99_emitter_streaming.sh`：A) strict 下代表性输入零漂移；
  B) 用 `UYA_C99_EMITTER_SELFTEST_DRIFT=1` 在快照后注入真实漂移，证明门禁会失败（非空转）；
  C) 不开 strict 时漂移仅告警、编译成功（显式 opt-in）。`make check` 全绿（无回归）。

说明：本次确立并门禁化了发射阶段的**行为收敛**（emitter 不再发现新类型/字符串/embed）。
仍残留的是**结构收口**——`C99Plan`/`C99UnitPlan` 合同已定义但尚未接入 `c99_codegen_generate`，
末尾 `emit_pending_*` 补发机制仍作为防御性代码存在；将其改为 plan 驱动的逐 unit 发射属 Phase 6
（L428-L433、L441-L444）。

### Phase 5A/6 更新：两条 1s 杠杆的可行性结论（2026-06-06）

实测后对两条剩余 1s 杠杆给出明确结论，供后续不再重复试错：

**旧全量 C99 入口下的 L382/L417（−25% peak RSS）不可由"按阶段释放"达成。** `ast_merge_programs` 是指针
拼接而非深拷贝（`src/ast.uya:796`），故 `ast_arena≈1.2GB` 是 C99 emitter 全程遍历的**活** AST
（非合并前死副本），无法在 codegen 前释放；AST 占 2.05GB peak 的主体。`check_arena`(77MB)/
`emit_arena`(10MB)/TypedProgram(30MB) 即便提前释放也远不够 25%（≈512MB）。真正的 25% 需要：
缩小 `ASTNode` mega-struct，或让 C99 改为消费紧凑 IR（LoweredProgram）而非 AST（设计文档第 3-7 节
的整体重构），或走 native 路径（本 TODO L33 把 50% RSS 下降定位在 Phase 9-10）。均非可控小增量。

**L467（body_ms<4000）naive 查找迁移不奏效。** 把 `find_struct/union/enum/interface_decl_c99`
加 SemanticDb 类型索引精确名快路径后，实测 body_ms 无变化（迁移前中位 6604ms、迁移后 6653ms，
落在抖动内），已回退。原因：这些 `find_*_c99` 的成本由**否定/试探性查找**（"X 是不是 union？"→否）
主导，否定时 SemanticDb 命中失败后仍回退全程序线性扫描，正向快路径帮不上，反而多一次探测。
真正要降 body_ms 需要：(1) 否定查找短路——SemanticDb miss 即返回 null、跳过回退扫描，前提是用
完整性 oracle（同 Phase 2 做法）证明索引覆盖全部真实声明；(2) 迁移上下文敏感的
`c99_find_enum_decl_in_context`（perf 第一热点，3 次线性扫描）。属需谨慎验证的较大改造，且仅靠
查找迁移也填不平 6.6s→4s 的差距。

结论：两条 KPI 都不是收口式小改能达成的；1s 目标的现实路径是设计文档主张的 IR 化重构与 native
后端（Phase 9-12），而非在当前 AST-直出-C99 架构上做局部优化。这与设计文档"当前架构自然极限是
几秒级全量 + 1 秒热路径"的判断一致。

### 前端剖析：codegen 声明查询埋点（2026-06-06）

实测确认前端瓶颈是共享的逐节点语义重复查询：`--vm` 字节码路径 `exec lowering 7201ms` ≈
直接 C99 `codegen 7516ms`，而 `exec bytecode 构建耗时: 0ms`——输出格式不是成本，lowering 才是。
故 native 后端会继承同样的 ~7s lowering，只省去 host `cc`（make uya 30s 里约 10s），碰不到前端。

新增 `UYA_PROFILE_QUERIES=1` 埋点（`src/codegen/c99/utils.uya` 的 `c99_qprof_*`，对 5 个
`find_*_c99` 做薄包装记 calls/hits，默认关、零 KPI 影响）。`src/main.uya` 一轮实测：

| 查询 | calls | hits | 命中率 |
| --- | ---: | ---: | ---: |
| `c99_find_enum_decl_in_context` | 73,978 | 14,411 | 19% |
| `find_struct_decl_c99` | 149,620 | 135,908 | 91% |
| `find_union_decl_c99` | 36,729 | 30 | **0.08%** |
| `find_enum_decl_c99` | 47,912 | 10,470 | 22% |
| `find_interface_decl_c99` | 100,128 | 0 | **0%** |

合计 **408,367 次**声明查询。关键发现：**`find_interface_decl_c99` 100% 否定、`find_union_decl_c99`
99.9% 否定**——codegen 在某热路径反复问"X 是不是接口/联合体？"，答案几乎永远是否，但每次都
全程序线性扫描（~3828 decl 各 strcmp）确认。这两项 ≈ perf self-time 的 15.7%
（iface 8.9% + union 6.8%），是纯浪费的全表扫描。

由此得出下一步优化（数据驱动，优先级从高到低）：

1. **否定查找短路**：用 SemanticDb 的名字集合 O(1) 判定"X 是否是某 interface/union 名"，不在集合
   即立即返回 null、跳过全表扫描，消除约 13.7 万次全程序扫描。需用完整性 oracle（同 Phase 2）证明
   SemanticDb 覆盖全部真实声明后才能信任否定。
2. **调用点否定缓存**：iface 100% 否定说明调用点逻辑可能本可避免该查询；查清 100,128 次 iface
   查询从哪来，可能直接消除而非加速。
3. `c99_find_enum_decl_in_context`（73,978 次、3 轮线性扫描）迁到 SemanticDb 的 (FileId,NameId) 索引。

另记一个我在 Phase 5A 引入的回归点：`arena.uya:122` 的动态 chunk 零初始化 `memset` 占 perf 5.3%
（AST ~1.2GB / 1MB chunk ≈ 1200 次 1MB memset），可改 `calloc`（大块走 mmap 零页，近乎免费）。

#### 已落地：interface 否定查找短路（2026-06-06）

按上面第 1 步实现了 `find_interface_decl_c99` 的否定短路：interface 查找是纯精确匹配（无泛型 mono
回退），故用 `c99_semantic_find_type_decl_by_kind`（SemanticDb intern→type range→按 kind）O(1)
完全替代原全程序线性扫描，否定即真否定直接返回 null。`UYA_C99_LOOKUP_ORACLE=1` 下与原扫描逐次
对照：`src/main.uya` **0 处不一致**，证明 SemanticDb 对 interface 完整、短路正确性无损。

实测 `body_ms` 中位 **6604ms → 5378ms（−18.5%）**，`total_ms` ~7600 → ~6300；`make check` 全绿。
降幅大于 perf 的 iface 8.9%，因为连带消除了大量 `str_equals`/`strcmp`（每次否定原本要扫 ~3828 decl）。
验证了"埋点定位否定查找 → SemanticDb 否定短路"这条数据驱动路径。下一步对 `find_union_decl_c99`
（99.9% 否定，但有 mono 回退，只能短路第一轮 exact 扫描、保留 mono fallback）和
`c99_find_enum_decl_in_context` 同法推进。

#### 已落地：union/enum exact + enum_ctx 否定查找短路（2026-06-06，续）

沿 interface 短路线继续：先对 `find_union_decl_c99` / `find_enum_decl_c99` 的 exact 扫描做否定短路
（commit `a41f3d8f`，保留 mono fallback），再对 perf #1 的上下文敏感查找
`c99_find_enum_decl_in_context`（原 3 轮全程序扫描：alias-in-file / enum-in-file / use-in-file）做否定短路。
新增 `c99_enum_ctx_name_present_in_file`（`src/codegen/c99/utils.uya`）：用 SemanticDb (FileId,NameId)
的 alias/use 存在性（保守超集）+ enum decl-range × file_id 精确判定，三处都判否（`present_ctx==0`）即跳过
3 轮上下文扫描，直接走 fallback。

- **正确性**：`UYA_C99_LOOKUP_ORACLE=1` 下 `present_ctx==0` 仍执行原扫描对照，命中即报 "短路漏判"。
  `src/main.uya` 实测 **0 处漏判**，证明短路是真否定、无遗漏。
- **性能**（`UYA_PROFILE_CODEGEN=1`，`src/main.uya`，3 轮中位）：`body_ms` 6604 → … →
  **2709ms**（本步 ~4600 → 2709），codegen `total_ms` **3331ms**；端到端 wall 中位 **9218ms**。
  `make check` 全绿（无回归）。
- **KPI**：L469（`UYA_PROFILE_CODEGEN body_ms < 4000`）**达标**（2709，已勾）。
  L470（直接 C99 total `< 8000`）以**端到端**口径仍**未达标**（9218 > 8000）：codegen 已非瓶颈（3331），
  剩余 ~5.9s 主体是 **check 阶段（Phase 0 = 4683ms，尚未优化）** + parse + overhead。
  下一个 1s 杠杆从 codegen 转向 **checker 查询 / 字符串比较**。

### Phase 8 Build Seed Restore Checkpoint（2026-06-07）

`make clean && time -p make restore-cmd-build-seed` 实测：

```text
real 17.18
user 16.89
sys 0.30
```

对同一 `backup/cmd-build-linux-x86_64.c` 直接试编译：

```text
cc -std=c99 -O0 -fno-builtin -w      real 7.17
cc -std=c99 -O0 -fno-builtin -Werror real 7.28
cc -std=c99 -O1 -fno-builtin -w      real 17.51
```

结论：直接从普通 `backup/cmd-build*.c` C seed 恢复当前**未达标**。单独把 restore CFLAGS
从 `-O1` 降到 `-O0` 只能把恢复时间降到约 7.2s，仍超过 3s；主因是
`backup/cmd-build*.c` 仍有约 7.8MB。

为满足 L554，同时保留普通 C99 fallback seed，Phase 8 增加精确 host/arch 的文本 blob seed：

```text
backup/cmd-build-linux-x86_64-blob.c
```

该文件是 C99 小 extractor + base64 文本 blob，只在 host/arch 完全匹配时由
`restore-cmd-build-seed` 优先使用；缺失或平台不匹配时仍回退到普通 `backup/cmd-build*.c`。
`bash tests/verify_build_seed_restore_time.sh` 实测：

```text
elapsed_ms=226
threshold_ms=3000
```

结论：L554（build seed 恢复 `< 3000ms`）在 host/arch blob 快速路径下**达标**；
普通 C seed 仍作为可审计 fallback 保留。

`bash tests/verify_build_seed_restore_memory.sh` 对 `make restore-cmd-build-seed` 及其子进程采样
`/proc/*/status`：

```text
peak_rss_kb=344152
baseline_rss_kb=2103824
threshold_kb=1051912
```

结论：L556（seed restore peak RSS 低于 Phase 0 baseline 50%）**达标**；当前 restore 峰值约
336MiB，低于 Phase 0 冷构建 RSS baseline 一半阈值。

#### 发现：checker proof 表在自编译时溢出（待迁移，硬约束 L35）

编译 `src/main.uya` 时 `checker constraint table` / `pointer nonnull table` 即溢出
（`src/checker/interval.uya:28/185` "容量已满" 警告）：`MAX_CONSTRAINTS=64` / `MAX_POINTER_NAMES=32`
（`src/checker/types.uya:25-26`）固定容量，满后**警告并 return 截断**。截断方向偏保守（约束/非空记录变少
→ 证明更保守、要求显式检查，而非放行不安全代码；`src/main.uya` 仍编译通过即证明），故**非安全漏洞**，
但 (a) 违反"所有编译器表动态扩容"硬约束 L35；(b) 削弱大函数的证明能力。完整修复需把 5 个 proof 字段
+ `if` 路径敏感分析的 ~16 个栈快照数组（`src/checker/main.uya` 的 save/restore/merge）全部动态化，
触及**安全证明核心 + 递归热路径**，属需专门测试基础设施 + 分步验证的高风险重构（本文上方 Phase 0A 清单
已将其列为"诊断失败或迁为动态 bitset/vector"的待迁移项）。

## 当前内存缺口

本文已经有 `bench-compiler-1s` 硬口径 `peak_rss_kb` / `output_bytes` baseline；下一步仍必须补齐 compiler 内部内存字段，并确保后续阶段持续报告：

- `peak_rss_kb`：编译器进程峰值常驻内存。
- `arena_peak_bytes`：compiler arena 峰值。
- `semantic_db_bytes` / `typed_program_bytes` / `lowered_bytes`：新增语义和 IR 表占用。
- `c99_output_buffer_peak_bytes`：C99 输出 FILE 缓冲峰值。
- `output_bytes`：C99 / split-C / native / build seed 产物总字节数。
- `table_count` / `table_capacity` / `table_realloc_count`：所有编译器动态表的实际项数、容量和增长次数，可按表类别输出明细。

当前环境只确认 shell 内置 `time` 可用，未确认 GNU `/usr/bin/time -v`。因此 1 秒 benchmark 不应依赖外部 `time -v`，应优先通过 `/proc/<pid>/status` 或 `/proc/<pid>/smaps_rollup` 采样 RSS。没有 RSS 采样的运行只能记录时间，不能计入内存达标。

## perf 热点

`perf record -F 99 -g -- ./bin/uya src/main.uya -o /tmp/uya-perf.c --c99 --nostdlib --safety-proof` 的 self time 前列：

| 函数 | self |
| --- | ---: |
| `find_type_alias_from_program` | 11.04% |
| `c99_find_enum_decl_in_context` | 9.84% |
| `std_string_strcmp` | 7.37% |
| `str_equals` | 7.33% |
| `c99_find_identifier_type_node` | 6.58% |
| `find_interface_decl_c99` | 5.37% |
| `is_enum_variant_name_in_program` | 4.31% |
| `find_union_decl_c99` | 3.63% |
| `find_enum_decl_c99` | 3.44% |
| `find_function_decl_c99` / unqualified call lookup | 4.67% 合计 |

判断：当前 codegen body 的主要成本是“反复在全程序声明数组和局部/全局变量表里线性查找，再做大量字符串比较”。已有 4096 槽直接映射缓存能缓解简单命中，但冲突、同名/同族优先级、上下文敏感查找仍频繁回退全表扫描。

### Phase 3 perf checkpoint（2026-06-05）

Phase 3 函数与局部作用域索引落地后，使用当前 `bin/uya` 重建后复测同一直接 C99 口径：

```bash
make uya
UYA_ROOT="$PWD/lib/" perf record -F 99 -g -o /tmp/uya-phase3-perf.data -- \
  ./bin/uya src/main.uya -o /tmp/uya-phase3-perf.c --c99 --nostdlib --safety-proof
perf report -i /tmp/uya-phase3-perf.data --stdio --no-children --sort symbol --no-call-graph
```

self time 前 20：

| 排名 | 函数 | self |
| ---: | --- | ---: |
| 1 | `c99_find_enum_decl_in_context` | 15.65% |
| 2 | `std_string_strcmp` | 10.35% |
| 3 | `str_equals` | 9.03% |
| 4 | `find_interface_decl_c99` | 7.09% |
| 5 | `find_union_decl_c99` | 5.39% |
| 6 | `find_enum_decl_c99` | 4.49% |
| 7 | `c99_find_function_decl_for_unqualified_call` | 3.63% |
| 8 | `c99_private_function_needs_file_scope_name` | 3.08% |
| 9 | `find_function_decl_c99` | 2.93% |
| 10 | `checker_fn_decl_is_owned_method` | 2.82% |
| 11 | `find_struct_decl_c99` | 2.34% |
| 12 | `symbol_table_lookup` | 2.23% |
| 13 | `find_macro_decl_from_program` | 2.10% |
| 14 | `memset` | 2.10% |
| 15 | `checker_canonicalize_fn_decl` | 1.85% |
| 16 | `find_method_block_for_union_c99` | 1.48% |
| 17 | `lookup_scan_interface_decl_from_program` | 1.31% |
| 18 | `checker_eval_const_expr` | 1.19% |
| 19 | `checker_find_reachable_fn_decl_by_name` | 1.15% |
| 20 | `semantic_intern_semantic_intern_name` | 1.09% |

结论：`c99_find_identifier_type_node` 未出现在 self time 前 20；`perf report` 直接检索同名符号也无命中。本阶段局部/async 名称查找热点已从前 20 移出，后续主战场转向枚举/接口/函数声明索引和字符串比较。

同一轮重建后的 `UYA_PROFILE_CODEGEN=1` 直接 C99 复测：

```text
[UYA_PROFILE_CODEGEN] simd_ms=0 precollect_ms=472 header_ms=1 step1_typedef_ms=3 step6_mid_ms=419 step6e_tail_ms=141 prelude_ms=1037 body_ms=7653 total_ms=8690
```

Phase 0 `body_ms=11666ms`，当前 `body_ms=7653ms`，下降约 34.4%，满足 Phase 3 “较 Phase 0 降低至少 20%” KPI。

## 动态表要求

当前已有的 4096 槽直接映射缓存只能算临时缓解，不能作为最终索引结构。后续 `SemanticDb`、`TypedProgram`、`LoweredProgram`、C99 planner 和 native backend 中所有表都必须按需动态扩容；凡是承担 table/index/cache/list/mapping 角色的结构，都不能写死容量。

具体要求：

- 不新增 `C99_MAX_*`、`CHECKER_*_SIZE` 或魔法容量作为程序规模相关表的语义上限。
- 表必须记录 `count`、`capacity`、`bytes`、`realloc_count`，并进入 benchmark 摘要或按表明细。
- 动态增长必须检查整数溢出和 allocation failure，失败时给出明确 diagnostic。
- hash/intern/scope 表必须按负载因子增长，高冲突场景不能回退到全程序线性扫描。
- 静态数组仅允许用于语言或 ABI 已证明有界的非 table 小缓冲，且必须在实现旁写清楚界限来源。

### Phase 0 固定容量扫描清单

扫描命令：

```bash
rg -n "^const (C99_MAX|C99_.*CACHE|C99_.*SIZE|C99_ASYNC|C99_DECL|C99_TYPE|MAX_|SYMBOL_TABLE_SIZE|FUNCTION_TABLE_SIZE|MODULE_TABLE_SIZE|IMPORT_TABLE_SIZE|STRING_POOL_SIZE|CHECKER_LOOKUP|MONO_INSTANCE_INDEX|EXEC_MAX)" src/codegen/c99 src/checker src/exec src/main.uya
rg -n "\\[[^\\]\\n]+:\\s*(MAX_|C99_MAX_|EXEC_MAX_|[0-9]{2,})" src/main.uya src/checker src/codegen/c99 src/exec
rg -n "count >=|>= C99_MAX|>= MAX_|>= EXEC_MAX|>= FUNCTION_TABLE_SIZE|>= SYMBOL_TABLE_SIZE|>= IMPORT_TABLE_SIZE|>= MODULE_TABLE_SIZE|>= STRING_POOL_SIZE" src/codegen/c99 src/checker src/exec src/main.uya
```

需要迁移或明确诊断的固定表、索引、缓存、worklist：

- `src/main.uya`：`MAX_INPUT_FILES=128` 驱动 `main_file_paths_global`、`resolved_files_global`、`all_files_global`、`processed_files_global`、`main_files_global`、`programs`、`input_paths_override`；`input_file_indices: [i32: 64]` 也是输入列表硬上限。迁移目标：`FileId`/path dynamic vector、dependency worklist、program range。
- `src/codegen/c99/internal.uya`：`C99_MAX_STRING_CONSTANTS=4096`、`C99_MAX_EMBEDDED_CONSTANTS=4096`、`C99_MAX_EMBED_DIR_TABLES=512`、`C99_MAX_STRUCT_DEFINITIONS=1024`、`C99_MAX_ENUM_DEFINITIONS=512`、`C99_MAX_FUNCTION_DECLS=512`、`C99_MAX_REACHABLE_FUNCTIONS=4096`、`C99_MAX_GLOBAL_VARS=512`、`C99_MAX_LOCAL_VARS=1024`、`C99_MAX_LOOP_STACK=64`、`C99_MAX_CALL_ARGS=64`、`C99_MAX_DEFER_STACK=64`、`C99_MAX_DEFERS_PER_BLOCK=128`、`C99_MAX_DROP_VARS_PER_BLOCK=128`、`C99_MAX_SLICE_STRUCTS=128`、`C99_MAX_ERR_UNION_STRUCTS=256`、`C99_MAX_SIMD_STRUCTS=128`、`C99_MAX_MONO_INSTANCES=1024`、`C99_MAX_ERROR_IDS=1024`、`C99_ASYNC_MAX_AWAITS=4096`、`C99_MAX_INTERFACE_METHODS=128` 都落在 `C99CodeGenerator` 的表/栈/列表字段上。迁移目标：codegen state dynamic vector、range builder、scoped stack、async worklist。
- `src/codegen/c99/internal.uya` 声明缓存：`C99_DECL_CACHE_SIZE=4096` / `C99_DECL_CACHE_MASK=4095` 直接映射 `fn_decl_cache`、`struct_decl_cache`、`enum_decl_cache`、`type_alias_cache`、`union_decl_cache`、`macro_decl_cache`、`interface_decl_cache`。迁移目标：按名字 intern id 的动态 hash + collision range。
- `src/codegen/c99/global.uya`：`C99_IDENT_REF_CACHE_SIZE=4096` / mask 直接映射 identifier ref cache。迁移目标：上下文 key dynamic hash。
- `src/codegen/c99/types.uya`：`C99_TYPE_TO_C_CACHE_SIZE=4096`、`C99_IDENTIFIER_TYPE_CACHE_SIZE=4096` 直接映射类型和 identifier type cache；`dims: [i32: 10]`、interface signature scratch arrays、local variable scans 仍依赖固定上限。迁移目标：type key dynamic hash、per-function local index、small-array builder。
- `src/codegen/c99/utils.uya`：`C99_SAFE_IDENT_CACHE_SIZE=2048`、`C99_STRING_CONST_CACHE_SIZE=4096` 直接映射缓存；mirror/split-C 路径去重有 `uniq: [[byte: 512]: 128]` 等固定列表。迁移目标：dynamic hash/set、path vector。
- `src/codegen/c99/main.uya` / `structs.uya` / `function.uya` / `expr.uya`：`MAX_TESTS=1000`、interface method scratch arrays `C99_MAX_INTERFACE_METHODS` / `128`、async saved-local arrays `32`、async param arrays `16`、`C99_ASYNC_MAX_AWAITS` 相关 await 数组仍是固定 worklist；生成端还写出 `AsyncFrameDescriptor entries[512]`、`FieldInfo fields[64]`、async pool cap `4096`，需要明确是 runtime 有界结构还是迁到动态输出表。
- `src/checker/types.uya`：`SYMBOL_TABLE_SIZE=32768`、`FUNCTION_TABLE_SIZE=4096`、`MODULE_TABLE_SIZE=256`、`IMPORT_TABLE_SIZE=512`、`STRING_POOL_SIZE=16384` 是核心 checker hash/table 上限；`MAX_ERROR_NAMES=1024`、`MAX_MOVED_NAMES=128`、`MAX_MONO_INSTANCES=512`、`MAX_UNION_VARIANTS=32`、`MAX_INTERFACE_METHODS=128`、`MAX_INTERFACE_STACK=64`、`MAX_POINTER_NAMES=32`、`MAX_CONSTRAINTS=64`、`MAX_ASYNC_CALL_EDGES=512`、`MAX_FN_CALL_EDGES=16384`、`MAX_FN_ROOTS=4096`、`MAX_REACHABLE_FN_DECLS=4096`、`MAX_REACHABILITY_VISIT_SLOTS=262144`、`MAX_ASYNC_FRAME_METAS=512` 都进入 `TypeChecker` 表/缓存/worklist。迁移目标：SemanticDb dynamic table、dynamic hash、queue/worklist、scoped proof state vector。
- `src/checker/lookup.uya`：`CHECKER_LOOKUP_CACHE_SIZE=2048` 直接映射 enum/struct/type alias/union/interface/function/method block lookup cache。迁移目标：program decl index dynamic hash。
- `src/checker/generics.uya`：`MONO_INSTANCE_INDEX_SIZE=1024`、`g_mono_index_next: [i32: MAX_MONO_INSTANCES]` 与 checker `mono_instances` 共用固定 mono 容量。迁移目标：mono instance dynamic vector + hash buckets。
- `src/checker/symbols.uya` / `interval.uya` / `check_stmt.uya` / `check_expr*.uya`：`count >= MAX_*` 路径覆盖 error/moved names、function roots/call edges/reachable queue、pointer nonnull/nullable、constraints、interface stack/methods、union variant coverage；其中 `MAX_UNION_VARIANTS` 相关代码会截断覆盖数组。迁移目标：明确 diagnostic 或动态 bitset/vector。
- `src/checker/modules.uya`：`MAX_MODULES=64` 控制循环检测 path/visit_state，`path_len >= MAX_MODULES` 当前会跳过循环检测。迁移目标：module graph dynamic DFS stack。
- `src/checker/macro_expand.uya`：macro scope arrays `scope_names: [&byte: 256]`、`scope_renamed_names: [&byte: 256]`、`scope_starts: [i32: 64]`、`local_bindings: [MacroParamBinding: 64]`、局部 `MAX_FIELDS=64` / `MAX_LOCAL_BINDINGS=64` 是宏展开表/worklist。迁移目标：macro expansion context dynamic vector。
- `src/exec/lower.uya`：`EXEC_MAX_LOCALS=256`、`EXEC_MAX_GLOBALS=1024`、`EXEC_MAX_SCOPE_DEPTH=512`、`EXEC_MAX_INTERFACE_METHODS=64`、`EXEC_MAX_MODULE_GLOBAL_REQUESTS=256` 固定 lowering locals/globals/scope/request 表。迁移目标：HIR local/global dynamic vector、scope stack、request set。
- `src/exec/builder.uya` / `frame.uya` / `hir.uya`：`EXEC_MAX_BYTECODE_INSTRS=16384`、`EXEC_MAX_CONST_POOL_VALUES=8192`、`EXEC_MAX_HOST_CALL_SITES=64`、`EXEC_MAX_CLEANUP_SCOPE_DEPTH=512`、`EXEC_MAX_FRAME_SLOTS=8192`、`EXEC_MAX_CALL_ARGS=32`，加上 `break_jumps/continue_jumps: [i32:128]`、`defers/errdefers/drop_locals: [&HIRStmt:64]`、`loop_stack: [ExecLoopPatch:32]`，仍是 bytecode/frame/cleanup 固定表。迁移目标：bytecode builder dynamic vector、frame slot vector、cleanup/defer stack。

允许保留但必须被后续门禁识别为“小缓冲”的候选：`PATH_MAX` 路径缓冲、`NAME_BUF_SIZE` / `TEMP_BUF_SIZE` / `NUM_BUF_SIZE` / `FMT_BUF_SIZE` / message buffer 这类格式化缓冲、`C99_TYPE_CONV_MAX_DEPTH` 递归保护、ABI/语言规范证明有界的 SIMD lane 分支。若这些缓冲承担 table/index/cache/list/mapping 角色，仍必须迁移或补明确 diagnostic。

### Phase 0A 静默上限路径修复清单

2026-06-04 对 `src/main.uya`、`src/codegen/c99/`、`src/checker/`、`src/exec/` 继续扫描 `count >= MAX`、`>= C99_MAX_*`、`>= EXEC_MAX_*`、`>= *_SIZE`、`< MAX_*` 受限循环和固定容量写入保护。本清单只列扫描后仍可能静默截断、静默跳过或继续成功的路径；已经立即调用 `checker_report_error` / `exec_backend_set_error` 的分支不作为本轮修复队列主项，但仍要在动态表迁移时移除固定容量。

| 子系统 | 静默或截断路径 | 后续修复要求 |
| --- | --- | --- |
| `src/main.uya` 输入/文件列表 | `resolved_file_at` / `resolved_file_set` 对 `idx >= MAX_INPUT_FILES` 返回 `null` 或 no-op；`entry.uya` 仅在 `resolved_count < MAX_INPUT_FILES` 时追加，没有溢出诊断；`input_file_indices: [i32: 64]` 小于 `MAX_INPUT_FILES=128`，`parse_args` 仍按 `MAX_INPUT_FILES` 写入。 | 任何 input/resolved/all/processed/program/input override append 超出容量都必须在 CLI 或 compile_files 层报错并失败；`input_file_indices` 容量要和实际上限一致或迁为动态 vector。 |
| C99 mono / reachable / test worklist | `c99_codegen_ensure_mono_struct`、`c99_codegen_ensure_mono_function`、`c99_codegen_ensure_mono_method` 在 `mono_instance_count >= C99_MAX_MONO_INSTANCES` 后直接返回；`mark_top_level_function_reachable` 在 `reachable_function_decl_count >= C99_MAX_REACHABLE_FUNCTIONS` 后返回；`append_collected_test` / `collect_tests_from_node` 在 `MAX_TESTS` 后返回 0。 | 生成端必须报告表名、当前 count 和上限，并让 C99 codegen 失败；不得让缺失 mono/reachable/test 项继续生成不完整 C。 |
| C99 registry / emitted metadata | `c99_get_or_add_error_id` 满 `C99_MAX_ERROR_IDS` 返回 0；`get_string_constant_name` 满 `C99_MAX_STRING_CONSTANTS` 返回 `null`；embed constant、embed dir table、slice struct registry 满后返回 `null`/return；`emit_async_frame_descriptors` 将 `checker.async_frame_meta_count` 截到 `MAX_ASYNC_FRAME_METAS`。 | registry 失败必须变成明确 diagnostic；descriptor 输出不能静默 clamp，必须迁为动态输出表或显式失败。 |
| C99 locals / cleanup stacks | `c99_push_local_variable` 只在 `local_idx < C99_MAX_LOCAL_VARS` 时写入，调用点普遍用 `local_variable_count < C99_MAX_LOCAL_VARS` 保护后跳过登记；local lookup 循环以 `li < C99_MAX_LOCAL_VARS` 截止；defer/drop accessors 对 `C99_MAX_DEFER_STACK`、`C99_MAX_DEFERS_PER_BLOCK`、`C99_MAX_DROP_VARS_PER_BLOCK` 越界返回 `null`/no-op。 | 局部变量登记、defer、errdefer 和 drop cleanup 超上限必须报错并失败，不能继续生成缺少类型/cleanup 信息的 C。 |
| checker reachability / async graph | `checker_mark_reachability_node_visited` 在 `MAX_REACHABILITY_VISIT_SLOTS` 满后返回 1，等价于“已访问”；`checker_register_async_call_edge` 满 `MAX_ASYNC_CALL_EDGES` 返回 0；`async_call_path_exists` 满 `MAX_ASYNC_CALL_VISITED` 返回 0；`checker_register_async_frame_meta` 满 `MAX_ASYNC_FRAME_METAS` 返回 -1。 | reachability/async 图容量不足必须用 checker diagnostic 失败，不能把未访问节点当作已完成，也不能丢失 async call/frame 信息。 |
| checker proof / union / module DFS | `pointer_nonnull_add`、`pointer_nullable_add`、`constraint_add` 满 `MAX_POINTER_NAMES` / `MAX_CONSTRAINTS` 后返回；`checker_add_moved_name` 和 `checker_add_error_name` 满 `MAX_MOVED_NAMES` / `MAX_ERROR_NAMES` 后返回；`MAX_UNION_VARIANTS` 会截断 match 覆盖检查；interface visited stack 满后不再追加；`dfs_visit_module` 在 `path_len >= MAX_MODULES` 后返回 0，循环检测被跳过，`visit_state` 也只初始化前 `MAX_MODULES` 个模块。 | proof 状态、error/moved 名称、union coverage、interface stack 和 module DFS 达上限必须诊断失败，或者迁为动态 bitset/vector/DFS stack。 |
| checker mono index | `register_mono_instance` 在 `MAX_MONO_INSTANCES` 后返回 -1；`mono_index_head_set` / `mono_index_next_set` 对 `MONO_INSTANCE_INDEX_SIZE` / `MAX_MONO_INSTANCES` 越界 no-op。 | 单态化容量不足必须带源码位置报错；mono index 后续迁为 dynamic vector + hash bucket 后才能计入 1 秒硬路径。 |
| exec lowering | `exec_lower_append_local` 在 `EXEC_MAX_LOCALS` / `next_slot` 满后返回 -1 但不直接设置 diagnostic；`exec_lower_collect_interface_method` 满 `EXEC_MAX_INTERFACE_METHODS` 返回 -1；`exec_lower_add_module_global_request` 满 `EXEC_MAX_MODULE_GLOBAL_REQUESTS` 返回；部分 HIR reachable 收集只在 `out_count < MAX_REACHABLE_FN_DECLS` 时追加，超限分支没有统一报错。 | lowering 层所有 `-1` / return 型容量失败必须设置 exec diagnostic 并向调用者传播失败；module global request 和 reachable 收集不得静默丢项。 |
| exec builder / VM 边界 | builder 的 host call、const pool、bytecode、frame slot、cleanup scope 多数已有 `exec_backend_set_error`；仍存在 `EXEC_MAX_CALL_ARGS` / `EXEC_MAX_FRAME_SLOTS` 受限循环和验证数组，VM/bytecode 路径需要确认不会静默截断实参、slot 或 cleanup 数据。 | 已有 diagnostic 的固定表后续迁动态；仍然只靠受限循环保护的路径要补诊断或证明为 ABI/runtime 有界小缓冲。 |

## 1 秒预算

若目标是“直接生成 C99”，1 秒预算建议：

| 阶段 | 当前 | 目标 |
| --- | ---: | ---: |
| parse | 0.7s | 0.10s |
| check | 4.6s | 0.25s |
| opt | 0.4s | 0.03s |
| codegen | 14.0s | 0.45s |
| overhead | 0.7s | 0.17s |

若目标是“`make uya` 产出可运行 `bin/uya`”，还要给 C 编译/链接留预算。传统 `cc` 全量编译 9MB C 文件或清空 split cache 后重编，无法进入 1 秒；必须是热增量缓存或常驻构建。

## 优化路线

### P0: 基准可信化

- `bench-compile-stats` 不应覆盖 `bin/uya`，也不应绕开 Makefile 默认 `-O2` 退回 `compile.sh` 的 `-O0 -g` 默认值。
- profile 口径固定三条：直接 C99、split-C no-link、`make uya`。
- 每次优化记录 `UYA_PROFILE_CODEGEN`、`perf top` 前 20、`peak_rss_kb`、arena 峰值和输出字节数。

### P1: C99 声明索引

目标：把 `find_*_from_program` 和 `find_*_c99` 从高频 O(N) 变成 O(1)/短链。

- 建立多值声明索引，而不是单槽缓存：`name_hash -> list/range`，支持同名 extern/body、libc/std family、context filename。
- `find_function_decl_c99` 当前即使缓存命中仍全表扫描以选择 body/family；应在索引构建时预分类 `best_body`, `best_stub`, `family_body`, `family_stub`。
- 将 `find_type_alias_from_program`、`is_enum_variant_name_in_program` 迁到 checker/codegen 共享索引，避免 codegen 继续调用 checker 的全表扫描版本。
- `c99_find_enum_decl_in_context` 按 `(enum_name, context_module/file)` 建二级缓存，避免枚举/别名解析反复穿透。

预期收益：codegen 14.0s -> 5-7s。

### P2: 标识符/类型上下文缓存

- `c99_find_identifier_type_node` 与 `lookup_identifier_type_c_impl` 仍在局部变量、全局变量、async locals 间反复倒扫；按函数进入时构建局部名称表，按 block depth 做栈式增量。
- `str_equals`/`strcmp` 占比高，说明缓存 key 仍以字符串比较为主。对 AST 声明名、模块名、类型名引入 intern id，热点路径比较整数。
- 泛型/async 禁用缓存是正确性保护，但可用 “template decl ptr + mono args signature id + local generation” 作为安全 key，恢复缓存命中。

预期收益：codegen 5-7s -> 3-4s，checker 小幅下降。

### P3: 入口瘦身

当前编译 `src/main.uya` 会拉入 exec、microapp、kernel image、upm lib、完整 C99 后端等 86 个文件。1 秒目标必须缩小默认 `bin/uya`：

- dispatcher `bin/uya` 只保留命令分发、版本、帮助、兼容提示。
- `bin/cmd/build` 才是真编译器；`check/run/test/fmt/upm` 独立二进制。
- `src/main.uya` 的隐式编译入口仅过渡保留，最终移除。

这与 `docs/cmd_subcommand_split_design.md` 的方向一致，但需要按当前源码重估：现在 `src/main.uya` 已瘦到约 3747 行，真正的大头转移到 `src/codegen/c99/*.uya`、exec 和 microapp。

预期收益：默认 `bin/uya` 编译可接近 1 秒；`cmd/build` 全量仍需要后续 P1/P2/P4。

### P4: 热增量和常驻编译

全量 1 秒不现实，热路径 1 秒可行：

- AST/checker/type/codegen prelude 缓存按文件 mtime + content hash 失效。
- split C 不再默认清空 `.uyacache`；改为只重写发生变化的 module C 和公共头，Makefile 依赖复用 `.o`。
- 常驻 compiler daemon 保留 intern 表、模块 AST、声明索引和类型缓存；CLI 只做轻量 RPC。

预期收益：改动单文件的 `cmd/build` 热编译进入 0.5-1.0s；全量冷编译仍可能 5s+。

## 架构判断

- “当前全量 `make uya` 进入 1 秒”不可由局部修补达成；需要改构建模型。
- “热编译编译器自身进入 1 秒”可达，但依赖增量缓存与 split C 对象复用。
- “默认 `uya --help`/dispatcher 自举进入 1 秒”可通过入口瘦身优先达成。
- 首个工程目标应定为：`UYA_PROFILE_CODEGEN` 下 `body_ms < 4000ms`，再推进 `body_ms < 1000ms`。

## 更深层架构诊断

上面的 P1/P2 仍偏“热点修复”。真正的结构性问题更大：当前编译器没有稳定的“语义层边界”。C99 后端不是单纯把已解析、已类型化、已实例化的 IR 打印成 C，而是在打印 C 的过程中继续做名称解析、类型推断、泛型实例发现、错误联合注册、async frame 补登记、头文件需求收集和 split-C 产物规划。

### 1. `bin/uya` 入口职责仍然过宽

`src/main.uya` 已经从旧设计中的 8k 行降到约 3747 行，但入口仍直接 `use` 编译器核心、C99、exec、microapp、kernel image/payload、upm lib 和 fmt。也就是说，即使用户只是需要 `build/check` 主路径，自举编译器也会把大量非必需子系统带入同一个程序。

这不是“文件大”问题，而是产品边界问题：

- `uya` 应是稳定 launcher/dispatcher。
- `uya build` 应是编译器。
- `uya microapp build/pack/inspect/verify/run` 应是独立工具命名空间。
- exec backend 应是开发/运行后端，不应强制进入默认 C99 自举二进制。
- upm、fmt 应是独立命令，不能被编译器入口静态拉入。

当前架构下，入口瘦身不能只移动代码文件；必须改变二进制构成边界。

### 2. Program AST 被当成全局数据库使用

当前核心数据形态是一个扁平 `AST_PROGRAM.program_decls` 数组。checker、optimizer、codegen 都反复在这个数组上扫描：

- `find_type_alias_from_program`
- `find_struct_decl_from_program`
- `find_union_decl_from_program`
- `find_interface_decl_from_program`
- `find_enum_decl_c99`
- `find_function_decl_c99`
- `c99_find_enum_decl_in_context`
- `is_enum_variant_name_in_program`

`perf` 的前几名基本都是这些查询。这里的问题不是“缓存槽太小”，而是缺一个真正的 semantic database：

- `ModuleId`
- `SymbolId`
- `TypeId`
- `DeclId`
- `ScopeId`
- `FileId`
- `InternedNameId`

没有这些 ID，后端只能拿 `&byte` 名字和 filename 继续推理；于是每次推理都要重新扫 AST、重新比较字符串、重新判断 lib/std family、重新处理同名 extern/body。

### 3. Checker 和 Codegen 互相穿透

C99 后端多处直接调用或模拟 checker 语义：

- `checker_infer_type`
- `type_from_ast`
- 临时写 `checker.current_function_decl`
- 临时写 `checker.current_type_params`
- 临时进入/退出 checker scope
- `checker.suppress_codegen_diagnostics`

这意味着 checker 没有输出足够完整的 typed/bound representation。codegen 为了知道表达式类型、方法接收者、泛型替换、err_union payload，只能重新“问 checker”，甚至在 codegen 中搭临时 checker 上下文。

结构上应改成：

```text
Parse AST
  -> Resolve/Binder: 给每个标识符、成员、调用、类型名绑定 SymbolId/DeclId/TypeId
  -> TypeCheck: 产出 TypedProgram + ExprType table + CallTarget table + MethodDispatch table
  -> Lower: 展开 async/generic/error-union/drop/defer/test/macro
  -> Backend IR: C99/Wasm/exec 共用的已降级 IR
  -> Emit C99
```

codegen 不应再调用 `checker_infer_type`。如果后端还需要推断类型，说明前一阶段没有把合同交清楚。

### 4. C99 后端同时做 lowering、planning 和 emission

`c99_codegen_generate` 是一个综合调度器，职责包含：

- 预收集 hosted header 需求、字符串常量、embed、slice 类型。
- 构建声明缓存。
- 预注册结构体、枚举、接口、union、err_union。
- 处理 generic mono instance 和 mono method。
- 对 async frame 发 forward/descriptor。
- 生成前向声明。
- 生成 vtable、测试函数、全局变量、普通函数、main bridge。
- 最后写 split-C manifest 和 Makefile。

这导致几种问题：

- 生成顺序变成语义正确性的一部分。
- 后期发现的新类型要通过 `emit_pending_*` 补发。
- mono instance 可能在生成函数体时继续增加，迫使多轮扫描。
- split-C mirror 产物组织和语义生成混在一个阶段，难以增量。

应拆成三个对象：

```text
C99Plan
  declarations: 已解析符号与发射顺序
  type_defs: 所有需要的 C 类型定义
  functions: 已实例化函数体列表
  globals: 全局与常量
  runtime_helpers: 按需 runtime helper 列表

C99LoweredUnit
  module/file scoped C fragments
  stable dependency fingerprints

C99Emitter
  只负责把 Plan/Unit 写成 bytes
```

当前 `body_ms` 大，根因就是 body 阶段边生成边问全局 AST，而不是消费一个预先完成的 plan。

### 5. 泛型、async、err_union 是“边生成边发现”

当前 C99 路径里，泛型实例、async frame 类型、err_union 结构体经常在以下阶段被补发现：

- `collect_err_union_from_ast`
- `collect_err_union_from_function_body`
- mono function/method prototype pass
- mono function/method body pass
- `emit_pending_err_union_structs`
- `emit_pending_string_constants`
- `emit_async_frame_descriptors`

这说明 lowering 没有收敛点。一个健康结构应该先构建完整闭包：

```text
worklist = entry roots
while worklist not empty:
  resolve call target
  instantiate generic if needed
  lower async body if needed
  register all concrete frame/err_union/drop/helper types
  add newly referenced concrete functions/types
```

闭包稳定后再开始输出。这样 codegen 不需要多轮“边写边补”。

### 6. 类型现在有两套身份：AST/Type 与 C 字符串

热点路径里有大量 `strstr(type_c, "err_union_")`、`strncmp(type_c, "struct ")`、从 C 类型字符串回推 struct 名、从 `safe_name` 判断 async frame 的逻辑。这是后端把“C 文本”反向当语义信息用。

这会造成：

- 缓存 key 很难正确。
- 泛型上下文下不得不禁用缓存。
- 指针/数组/接口/err_union 的判断散落在字符串处理里。
- 性能受字符串长度和字符串比较支配。

应以 `TypeId` / `ConcreteTypeId` / `CTypeId` 表达身份，C 字符串只在最后 emission 生成一次。

### 7. split-C 现在是输出格式，不是构建模型

当前 split-C 能把 C 文件拆开，但 `make uya` 仍默认清理 `.uyacache`，然后全量生成、全量编译。即使不清理，公共头和 mirror manifest 的稳定性也会决定对象缓存是否可复用。

要进入 1 秒，split-C 必须变成真实构建模型：

- 每个 `ModuleId` 或 `C99LoweredUnit` 对应稳定 `.c`。
- 公共头按内容 hash 写入，未变不更新时间戳。
- 每个 unit 记录 semantic fingerprint，不变不重写。
- Makefile/ninja depfile 稳定输出，不随扫描顺序抖动。
- `cmd/build` 热路径只重编受影响 unit。

当前 split-C 更像“把大 C 文件镜像拆成多个文件”，不是增量编译系统。

## 目标架构

建议把“1 秒编译”拆成两个产品目标：

### 目标 A：`uya` launcher 自举 1 秒

这是短期可达目标。`bin/uya` 只保留：

- help/version
- 子命令发现
- execve 原样转发
- 隐式入口兼容提示

它不静态链接 C99 backend、exec backend、microapp、upm、kernel image。真正编译器进入 `bin/cmd/build`。

### 目标 B：`cmd/build` 热编译 1 秒

这是中期目标。需要 compiler database + lowered IR + split-C 增量。

冷编译全量 `cmd/build` 仍可能是 5-10 秒；热编译单模块进入 1 秒。

### 目标 C：`cmd/build` 冷编译接近 1 秒

这是长期目标。除上述架构外，还需要：

- 常驻 compiler daemon。
- 前端 AST/type/index 缓存。
- C99 emission 写缓冲或二进制 IR 后端。
- 或者让自举主线从 C99 全量文本后端迁移到更快的 native/bytecode/VM 后端。

## 重构路线调整

原 P1/P2 可以继续做，但不应把它们误认为最终架构。建议路线改为：

### Phase 0: 先保基准

- 保持 `bench-compile-stats` 不污染 `bin/uya`。
- 新增 profile fixture：直接 C99、split-C、`make uya` 三口径。
- 所有性能 PR 都要给 `UYA_PROFILE_CODEGEN` 和 `perf top` 前后对比。

2026-06-04 评审修复后，`bench-compile-stats` 口径收紧为：

- 默认先执行 `make uya`，确保使用当前源码和 Makefile 默认 `-O2` 构建出的 `bin/uya`；只有显式传 `--no-rebuild` 或 `UYA_BENCH_SKIP_REBUILD=1` 时才复用已有二进制。
- benchmark 输出写入 `UYA_BENCH_TMPDIR` 下的临时目录，最终二进制使用 `bin/uya-bench-compile-stats` 临时名，脚本结束后必须清理临时目录和临时二进制。
- `make bench-compile-stats-check` 覆盖 `--runs 0`、未知参数、单次真实 TSV 输出和临时产物清理，作为该 benchmark 工具的 smoke/boundary/performance 门禁。
- 同机复核 `make bench-compile-stats ARGS='--runs 1'`：`files=86 parse=643ms check=4555ms opt=370ms codegen=14110ms total=19680ms`。这与本文 20s 级直接 C99 结论一致，旧文档里的 3-5s 历史记录不能作为当前口径的达标证据。
- 内存口径尚未收紧；下一步应新增 `bench-compiler-1s`，输出 `peak_rss_kb`、`arena_peak_bytes`、`output_bytes`，并记录当前基线。

## 正确性与性能验收矩阵

1 秒目标相关改动必须按风险分层验证，不能只看单个 wall time：

| 类别 | 必跑门禁 | 覆盖内容 |
| --- | --- | --- |
| benchmark 工具 | `make bench-compile-stats-check` | 参数边界、真实 `CompileStats` TSV、临时产物清理 |
| C99 后端 smoke | C99 相关 `tests/verify_*.sh`，尤其 split-C、async frame、imported main、private name collision | 生成顺序、符号、Makefile 依赖和历史 codegen 回归 |
| 编译器冒烟 | `make tests-uya` 或本次改动相关 `./bin/uya test tests/test_xxx.uya` | 前端/checker/codegen 基础行为 |
| 性能采样 | `make bench-compile-stats ARGS='--runs 3'` 与 `UYA_PROFILE_CODEGEN=1 ...` | parse/check/opt/codegen 与 codegen 子段 |
| 性能热点 | `perf record -F 99 -g -- ./bin/uya ...` | `find_*`、字符串比较、identifier/type 查询热点是否真实下降 |
| 内存采样 | `make bench-compiler-1s ARGS='--runs 3'`，并采样 `/proc/<pid>/status` 或 `/proc/<pid>/smaps_rollup` | peak RSS、arena 峰值、输出字节数、是否用内存换时间 |
| 收口验证 | `make check`；准备提交时 `make clean && make backup-all` | 全量正确性、自举一致性和备份种子同步 |

对架构性重构，新增或改动的阶段至少要有三类测试：最小正向 smoke、边界/负向用例、和同机性能对比。性能优化若改变语义阶段边界，还必须补历史 C99 回归，避免“速度达标但生成错误 C”的假阳性。

### Phase 1: 建 SemanticIndex，不改语义

新增 `SemanticIndex` 或先放在 `TypeChecker` 里：

- name interning。
- module/file table。
- decl id table。
- 按 kind 的 name -> decl list。
- enum variant -> enum decl。
- type alias -> target。
- function name -> body/stub/family candidates。

先只让 checker/codegen 查询它，输出保持不变。目标是把 codegen 14s 压到 5s 内。

### Phase 2: TypedProgram，禁止 codegen 重新推断

checker 给每个表达式/调用/成员/类型名填表：

- `expr_type[NodeId]`
- `call_target[NodeId]`
- `member_target[NodeId]`
- `resolved_type[NodeId]`
- `symbol_ref[NodeId]`

C99 后端用这些表，不再调用 `checker_infer_type`。目标是减少 checker/codegen 互相穿透和重复推断。

### Phase 3: ConcreteProgram lowering

在 codegen 前完成：

- generic monomorphization closure。
- async lowering/frame metadata。
- err_union concrete type closure。
- test runner lowering。
- defer/drop lowering。
- runtime helper dependency closure。

C99 后端只消费 concrete list。

### Phase 4: C99Plan + incremental split

生成稳定 `C99Plan`，按 module/unit 输出：

- 不变 unit 不重写。
- 不变头不更新时间戳。
- depfile/Makefile 稳定。
- 支持热编译跳过 host C 编译。

### Phase 5: Command binary split

把 `bin/uya`、`bin/cmd/build`、`bin/cmd/check`、`bin/cmd/run`、`bin/cmd/test`、`bin/cmd/fmt`、`bin/cmd/upm` 的构成边界固化到 Makefile 和 backup seed。

## 新的判断

现在架构的核心问题是：**后端承担了语义数据库、lowering 调度器和文本 emitter 三个角色**。只修缓存会让数字变好，但仍会把正确性绑定在生成顺序上。1 秒目标需要把“查询/决策/降级/输出”拆开，让每个阶段只做一次，并且让结果可缓存。

## 再深入一层：当前不是“慢编译器”，而是“不可增量架构”

如果目标只是把 20s 降到 8s，热点缓存和索引足够。但如果目标是 1s，现有形态更根本的问题是：它几乎没有可以持久化、复用、并行化或局部失效的边界。

### A. AST 是语法树、语义树、IR、数据库的混合体

`ASTNode` 是一个扁平 mega struct：所有节点变体共享一套字段，语法、类型节点、声明、表达式、内建、macro、async、asm、embed、error union 都放在同一结构里。这个设计对早期自举很友好，但到现在有几个代价：

- 没有 `NodeId`，缓存只能用指针和上下文指针做 key。
- 没有不可变源 AST 与后续 IR 的边界，checker/optimizer/lowering 可以继续改同一棵树。
- AST 字段承载太多阶段含义，新增语言特性会直接扩大所有阶段的可见面。
- 后端看到的是“语法形状”，不是“已解析语义”；所以它会继续解析名字、推断类型、判断调用目标。

更正确的分层应是：

```text
SyntaxNode   只表达源代码形状
BoundNode    所有名字、模块、成员、调用都已绑定 ID
TypedNode    所有表达式/类型节点有 TypeId
LoweredNode  async/defer/drop/macro/test/generic 已降到核心模型
BackendIR    面向 C99/exec/wasm 的稳定发射输入
```

只要 AST 继续同时承担这些角色，1 秒编译就会被“每个阶段重新理解同一棵树”拖住。

### B. 全局可变上下文让编译器难以常驻

当前有多类全局或准全局状态：

- `src/main.uya` 的 `g_split_c_dir`、`g_container_mode`、`g_app_mode_microapp`、`g_module_root_override` 等编译参数全局。
- `main_file_paths_global`、`resolved_files_global`、`all_files_global`、`processed_files_global` 等全局缓冲。
- checker 里 `current_function_decl`、`current_type_params`、`current_self_type_name` 等当前上下文。
- C99 codegen 里 `current_function_decl`、`current_type_params`、`struct_type_args`、`expected_type`、`async_state_var`、`local_variable_count` 等当前上下文。
- 多处 `g_*_cache` 需要显式 reset，历史上已经出现过同进程 EXEC 后 fallback C99 的缓存污染问题。

这说明编译请求不是一个纯 `CompileContext` 对象。它更像“进程级单例编译器”。这会直接阻挡：

- compiler daemon。
- 多项目/多 target 同进程编译。
- 并行模块编译。
- 增量缓存复用。
- 可测试的阶段级 API。

1 秒热编译需要常驻或至少强缓存；常驻需要 request-local state。当前架构在这点上是反向的。

### C. TypeChecker 和 C99CodeGenerator 都是“上帝对象”

`TypeChecker` 包含 symbol/module/import/string pool、当前函数状态、错误集、mono instances、proof 状态、reachability、async frame metas。`C99CodeGenerator` 又包含输出流、声明缓存、全局/局部变量表、defer/drop 栈、slice/err_union/SIMD 待输出表、mono instances、async 状态机、header 需求、split-C 状态等。

这两个结构并不是窄接口对象，而是把多个阶段的全量状态堆在一起：

```text
TypeChecker =
  resolver + type checker + proof engine + mono registry + reachability analyzer + async metadata registry

C99CodeGenerator =
  semantic query layer + lowering state + C type registry + function planner + output writer + split-C build planner
```

只要这些对象不拆，性能优化会继续变成“在上帝对象里加缓存字段”。这可以缓解热点，但不会形成可维护的 1 秒架构。

### D. 没有真正的 Compiler Database

现在编译器需要的核心查询分散在很多线性函数里：

- name -> decl
- name + module/file -> visible decl
- enum variant -> enum
- type alias -> canonical target
- struct/union/interface -> method set
- expression node -> type
- call node -> callee
- concrete generic instance -> lowered body
- Type -> layout
- Type -> C ABI representation

这些都应该是一个 compiler database 的 query：

```text
query module_graph(root_file) -> ModuleGraph
query parse(file_id) -> SyntaxTree
query resolve(module_id) -> BoundModule
query type_of(expr_id) -> TypeId
query decl_by_name(scope_id, name_id, kind) -> DeclId
query instantiate_generic(decl_id, type_args) -> ConcreteDeclId
query lower_function(concrete_fn_id) -> LoweredFunctionId
query c_abi_type(type_id) -> CTypeId
query emit_unit(unit_id) -> ByteBuffer
```

每个 query 有输入 key、输出值、依赖列表和 fingerprint。没有这个层，增量编译只能靠文件 mtime 和临时缓存，很难正确。

### E. C99 是自举产物，但不该是唯一主中间层

当前自举主线是 Uya -> C99 -> host cc -> `bin/uya`。这很稳，但 1 秒目标和 C99 主中间层天然冲突：

- C 文本大，当前单文件约 9MB。
- C 编译器不是 Uya 可控阶段。
- C 的头文件/原型/顺序限制反向污染 Uya lowering。
- split-C 需要维护 C 层依赖稳定性。
- C 字符串一旦成为内部语义载体，就会拖慢所有类型判断。

更稳的路线不是丢掉 C99，而是把它降级为后端之一：

```text
Uya source -> Compiler DB -> Core IR -> backend:
  - C99 backend: portability/bootstrap/release seed
  - Exec/bytecode backend: fast dev/test/run
  - Future native/wasm backend: fast production build
```

短期仍用 C99 做 release seed；日常热编译和测试应尽快走更短路径。

### F. 目前的优化阶段位置不对

现在优化在 checker 后、codegen 前直接遍历 AST。它标记常量折叠、死代码等，但没有改变后续架构问题：

- 它还是 AST pass，不是 typed IR pass。
- 它不能减少 codegen 的语义查询，因为后端仍要重新理解 AST。
- 它对泛型/async/err_union 的 concrete closure 没有形成约束。

真正的优化入口应在 `TypedProgram -> LoweredProgram` 之间，优化对象是有 `TypeId/SymbolId/ControlFlow` 的 IR，而不是语法树。

### G. 当前“模块”只是文件收集，不是编译单元

`collect_module_dependencies` 递归找到文件，随后 `ast_merge_programs` 合成一个 program。这个模型简单，但它把模块边界消掉了：

- 作用域/可见性需要通过 filename/module path 反推。
- 后端 split-C 只能事后根据 source path 镜像输出。
- 增量失效不能表达“这个模块 public API 未变，依赖者不用重查”。
- 并行 checker/codegen 很难做。

1 秒热编译需要模块成为真实编译单元：

```text
ModuleUnit {
  module_id
  source_file_id
  import_ids
  public_api_fingerprint
  private_body_fingerprint
  bound_symbols
  typed_items
  lowered_items
}
```

这样 private 改动可以只重 lower/codegen 当前模块，public API 改动才传播。

## 架构原则重写

后续重构不要以“把现有文件拆小”为目标，而要按这些原则约束：

1. **后端不得发起语义查询**：C99 backend 只能查询已冻结表，不能调用 checker 推断。
2. **所有名字先 intern**：热点路径不得比较长字符串；字符串只在 diagnostics/emission 出现。
3. **所有节点有稳定 ID**：缓存 key 不用裸指针；为 daemon/增量/序列化做准备。
4. **所有全局状态归入 CompileSession**：一次编译请求可并行、可重复、可在同进程多次运行。
5. **先闭包，后发射**：generic/async/err_union/runtime helper 必须在 emission 前固定。
6. **C 类型不是语义信息**：`CTypeId` 到字符串是最后一步，不能从 C 字符串反推 Uya 类型。
7. **模块是编译单元**：merge program 只可作为兼容视图，不能作为内部唯一表示。
8. **C99 是后端，不是中间语义层**：release bootstrap 可以依赖 C99，日常速度目标不能被 C99 全量文本绑死。

## 更激进但更正确的路线

如果目标真的是“编译 Uya 进入 1 秒”，推荐不要先全力优化 C99 emitter，而是并行开两条线：

### 线 1：建立 Compiler DB，仍输出 C99

这是保守线，保证现有 release/bootstrap 稳定：

1. `NameId/FileId/ModuleId/DeclId/TypeId`。
2. `SemanticIndex` 替换 `find_*_from_program`。
3. `TypedProgram` 表替换 codegen re-infer。
4. `ConcreteProgram` 闭包替换边生成边发现。
5. `C99Plan` 替换 `c99_codegen_generate` 巨型调度器。
6. split-C 按 unit fingerprint 增量写入。

目标：全量从 20s 降到 5s 以内，热编译 1s。

### 线 2：让 exec/bytecode 成为开发期主路径

这是速度线，目标是日常 run/test/check：

1. 用同一 `TypedProgram/ConcreteProgram` 喂给 exec lowering。
2. 支持不完整特性 fallback，但 fallback 不能污染 checker/codegen 全局状态。
3. `uya test --exec` 成为默认开发测试路径之一。
4. C99 只在 release/backup/portable 输出时跑。

目标：小程序和 compiler smoke 的开发反馈明显短于 C99。

### 最终形态

```text
bin/uya                launcher, <1s self-build
bin/cmd/build          full compiler, C99/native/bytecode backends
bin/cmd/check          parse+resolve+type only
bin/cmd/run            default fast backend, C99 fallback
bin/cmd/test           default fast backend, C99 fallback
bin/cmd/fmt            syntax-only tool
bin/cmd/upm            package manager

compiler-core/
  session
  source_db
  parser
  resolver
  typeck
  lower
  query_db
  diagnostics

backends/
  c99
  exec
  wasm/native future
```

这才是和 1 秒目标一致的架构。当前架构可以继续优化，但它的自然极限更像“几秒级全量 + 1 秒热路径”，不是“全量 `make uya` 永久 1 秒”。
