# libc malloc/free 性能优化完成归档

## 2026-06-24 归档：阶段 1：低风险热修复

原始位置：`docs/todo_malloc_perf.md`

- [x] 阶段 1：低风险热修复
  - [x] Task 1.1：位运算替代有符号除法
  - [x] Task 1.2：`owns_ptr` 添加最近命中缓存
  - [x] Task 1.3：`MIN_CHUNK_SIZE` 从 64 调整为 32
  - [x] 阶段 1 回归测试全部通过
  - [x] 阶段 1 性能收益报告补充实测数据

### 阶段 1 实测记录

```text
日期：2026-06-24
提交：c6ccc8b0
平台：Linux x86_64
编译命令：`/media/winger/_dde_data/winger/uya/uya/bin/uya build /tmp/malloc_perf_bench.uya -o /tmp/malloc_perf_bench_baseline` 和 `..._current`
测试命令：`./bin/uya test tests/test_std_stdlib_malloc.uya`；`./tests/run_programs_parallel.sh tests/programs/test_heap.uya`；`./tests/run_programs_parallel.sh malloc_test.uya`；`./bin/uya test tests/test_mem_heap.uya`
样本规模：`BLOCK_COUNT=131072`，`ROUNDS=4`，`5` 次重复
基线结果：`0.995 s`
优化后结果：`0.969 s`
变化：约 `2.6%` 更快
结论：阶段 1 的位运算和 region 命中缓存在 ordered free microbench 上带来小幅吞吐提升；现有 malloc 相关回归全部通过。
```

## 阶段 1：低风险热修复（预计 2-3 天）

**目标**：以最小改动消除最直接的常数因子损耗和正确性隐患，不改变整体架构。

---

### Task 1.1: 位运算替代有符号除法 — get_size / is_free / set_free

- **优先级**: P0
- **预计时间**: 30 分钟
- **文件**: `lib/libc/heap.uya`
- **当前问题**:
  ```uya
  // heap.uya:93-105 — 使用 i64 有符号除法和取模来操作 LSB 标记
  fn is_free(hdr: &ChunkHeader) bool {
      return ((hdr.size as i64) % (2 as i64)) != 0;  // 有符号取模，慢
  }
  fn get_size(hdr: &ChunkHeader) usize {
      return ((hdr.size as i64) / (2 as i64)) as usize * 2;  // 有符号除法，更慢
  }
  fn set_free(hdr: &ChunkHeader, free: bool) void {
      var base: usize = ((hdr.size as i64) / (2 as i64)) as usize * 2;  // 同上
      if free { hdr.size = base + 1; }
      else { hdr.size = base; }
  }
  ```
- **改为**:
  ```uya
  fn is_free(hdr: &ChunkHeader) bool {
      return (hdr.size & 1) != 0;
  }
  fn get_size(hdr: &ChunkHeader) usize {
      return hdr.size & ~(1 as usize);  // 清除 LSB free 标记
  }
  fn set_free(hdr: &ChunkHeader, free: bool) void {
      var base: usize = hdr.size & ~(1 as usize);
      if free { hdr.size = base | 1; }
      else { hdr.size = base; }
  }
  ```
- **影响**：这三个函数在 find_chunk、split_chunk、add_free 的热路径上被频繁调用，位运算比有符号除法快 10-50x。
- **验收标准**:
  - [x] `./bin/uya test tests/test_std_stdlib_malloc.uya` 通过
  - [x] `./tests/run_programs_parallel.sh tests/programs/test_heap.uya` 通过
  - [x] 现有 malloc 相关全部测试无回归

---

### Task 1.2: owns_ptr 添加最近命中缓存

- **优先级**: P0
- **预计时间**: 1 小时
- **文件**: `lib/libc/heap.uya`
- **当前问题**: `owns_ptr()` 每次 free 都遍历全部 HeapRegion 链表（O(n)），长时间运行的服务可能积累数十上百个 region。
- **方案**: 添加一个 `last_hit_region: &HeapRegion` 缓存变量，记录最近一次命中的 region。先检查缓存，命中则直接返回；未命中再遍历全链表，并更新缓存。
  ```uya
  var _last_region_hit: &HeapRegion = null;

  fn owns_ptr(ptr: &void) bool {
      const addr: usize = (ptr as usize);
      // 快速路径：检查最近命中的 region
      if !is_null(_last_region_hit as &void) {
          const base: usize = _last_region_hit.base as usize;
          const size: usize = _last_region_hit.size;
          const start: usize = base + @size_of(ChunkHeader);
          const end: usize = base + size;
          if addr >= start && addr < end {
              return true;
          }
      }
      // 慢速路径：遍历全部 region
      var region: &HeapRegion = heap_regions;
      while !is_null(region as &void) {
          const base: usize = region.base as usize;
          const size: usize = region.size;
          const start: usize = base + @size_of(ChunkHeader);
          const end: usize = base + size;
          if addr >= start && addr < end {
              _last_region_hit = region;
              return true;
          }
          region = region.next;
      }
      return false;
  }
  ```
- **影响**: 当分配/释放具有时间局部性时（绝大多数场景），free 的 owns_ptr 检查从 O(n) 变为 O(1)。
- **验收标准**:
  - [x] `./bin/uya test tests/test_std_stdlib_malloc.uya` 通过
  - [x] `./tests/run_programs_parallel.sh tests/programs/test_heap.uya` 通过
  - [x] 所有 malloc 测试无回归

---

### Task 1.3: MIN_CHUNK_SIZE 从 64 调整为 32

- **优先级**: P1
- **预计时间**: 15 分钟
- **文件**: `lib/libc/heap.uya`
- **当前问题**: `MIN_CHUNK_SIZE: usize = 64` 意味着申请 1 字节实际消耗 80 字节（64+16 header），对于大量小对象场景（AST 节点、链表节点等）浪费严重。
- **方案**: 将 `MIN_CHUNK_SIZE` 降为 32。加上 16 字节 header = 48 字节最小分配单元。
  ```uya
  const MIN_CHUNK_SIZE: usize = 32;
  ```
- **注意**: 需要同步检查 `split_chunk` 中的剩余空间判断：
  ```uya
  // heap.uya:181 — 确保剩余空间 >= MIN_CHUNK_SIZE + header 才分割
  if rem >= MIN_CHUNK_SIZE + @size_of(ChunkHeader) { ... }
  ```
  此判断逻辑不变，只是阈值变小，分割会更积极（减少内部碎片）。
- **验收标准**:
  - [x] `./bin/uya test tests/test_std_stdlib_malloc.uya` 通过
  - [x] `./tests/run_programs_parallel.sh tests/programs/test_heap.uya` 通过
  - [x] `./tests/run_programs_parallel.sh malloc_test.uya` 通过
  - [x] 无新增分配失败、free-list 复用或 split/free 路径无回归

---

## 2026-06-24 Task 2.1 完成归档

父级任务路径：阶段 2：碎片化根治

  - [x] Task 2.1：实现 free 时相邻块合并
    - 完成内容：`lib/libc/heap.uya` 引入 `ChunkFooter` boundary tag，chunk 总长改为 header + payload + footer 后再对齐；`free` 时通过 footer 找前块、通过 header size 找后块，仅在同一 `HeapRegion` 内合并相邻空闲块；同步调整 `malloc`/`split`/`find_chunk`/`realloc` 的容量计算并避免重复释放重新入链。
    - 新增回归：`tests/test_std_stdlib_malloc.uya` 覆盖两个相邻块释放后可满足单块无法满足的大分配，并断言复用第一个块地址。
    - 验证命令：`../uya/bin/uya test tests/test_std_stdlib_malloc.uya`：通过。
    - 验证命令：`../uya/bin/uya test tests/test_stdlib.uya`：通过。
    - 验证命令：`../uya/bin/uya test tests/test_std_stdlib.uya`：通过。
    - 验证命令：`../uya/bin/uya test tests/test_std_stdlib_malloc_only.uya`：通过。
    - 验证命令：`git diff --check`：通过。

### 2026-06-24
阶段路径：阶段 2：碎片化根治
  - [x] Task 2.2：`realloc` 原地扩展优化
    - 验证：`../uya/bin/uya test tests/test_std_stdlib_malloc.uya` 通过（显式编入 `../uya/lib/libc/heap.uya`，新增 `realloc` 原地扩展用例通过）
    - 验证：`../uya/bin/uya test tests/test_std_stdlib.uya` 通过
    - 验证：`../uya/bin/uya test tests/programs/test_heap.uya` 通过

### 2026-06-24
阶段路径：`阶段 2：碎片化根治`
  - [x] 同步 `docs/libc_malloc_design.md` 中的 footer 布局和开销说明
    - 验证：`git diff --check -- docs/libc_malloc_design.md docs/todo_malloc_perf.md`（通过）
    - 验证：`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_malloc_perf.md`（通过，输出 `ok: docs/todo_malloc_perf.md has 1 active task`）
    - 验证：`rg -n "ChunkFooter|chunk_overhead|最小 chunk 总大小|boundary tag footer|合并相邻空闲块" docs/libc_malloc_design.md`（命中 footer 结构、24B 开销、64B 最小 chunk 和合并说明）

### 2026-06-24
阶段路径：`阶段 2：碎片化根治`
  - [x] 阶段 2 回归测试和新增确定性测试全部通过
    - 完成内容：确认阶段 2 已新增的确定性覆盖全部通过，包括 `tests/test_std_stdlib_malloc.uya` 中“释放相邻块后合并复用首块地址”和“`realloc` 借用 next free chunk 原地扩展且保留旧数据”两条关键路径。
    - 验证：`../uya/bin/uya test tests/test_std_stdlib_malloc.uya` 通过
    - 验证：`../uya/bin/uya test tests/test_std_stdlib_malloc_only.uya` 通过
    - 验证：`../uya/bin/uya test tests/programs/test_heap.uya` 通过
    - 验证：`../uya/bin/uya test tests/test_std_stdlib.uya` 通过
    - 验证：`../uya/bin/uya test tests/malloc_test.uya` 通过
    - 验证：`../uya/bin/uya test tests/test_mem_heap.uya` 通过
    - 验证：`../uya/bin/uya test tests/test_stdlib.uya` 通过

## 2026-06-24

原始位置：`docs/todo_malloc_perf.md`
阶段路径：`阶段 2：碎片化根治`

- [x] 阶段 2：碎片化根治
  - [x] 阶段 2 性能收益报告补充实测数据
    - 完成内容：新增 `tests/bench_malloc_phase2.uya`，用同一组 workload 对比阶段 1 基线提交 `bee7df32` 与当前提交 `4fffff4a` 的碎片复用和 `realloc` 行为，并把实测结果写回本文“性能收益报告”。
    - 验证：`../uya/bin/uya build tests/bench_malloc_phase2.uya -o tests/build/bench_malloc_phase2_current`，随后执行 `./tests/build/bench_malloc_phase2_current`；输出 `budget8_rounds=64`、`peak_mmap_count=1`、`inplace_hit_rate_pct=100`、`copy_bytes=0`。
    - 验证：先执行 `git worktree add --detach ../uya_stage1_bench bee7df32`，再执行 `env UYA_ROOT=../uya_stage1_bench/lib ../uya/bin/uya build tests/bench_malloc_phase2.uya -o tests/build/bench_malloc_phase2_baseline`，随后执行 `./tests/build/bench_malloc_phase2_baseline`；输出 `budget8_rounds=7`、`peak_mmap_count=65`、`inplace_hit_rate_pct=0`、`copy_bytes=4032000`。
    - 验证：`../uya/bin/uya test tests/test_std_stdlib_malloc.uya` 通过（当前实现 1/1 通过）。

## 阶段 3：分配速度优化
- [x] Task 3.1：实现 size-segregated free lists
  - 验证：`../uya/bin/uya test tests/test_libc_heap_bins.uya` 通过（4 个 bin 行为/large-path 测试）。
  - 验证：`../uya/bin/uya test tests/test_std_stdlib_malloc.uya` 通过。
  - 验证：`../uya/bin/uya test tests/programs/test_heap.uya` 通过。
  - 验证：`../uya/bin/uya test tests/test_std_stdlib.uya` 通过。
  - 验证：`../uya/bin/uya test tests/test_std_stdlib_malloc_only.uya` 通过。
  - 验证：`../uya/bin/uya test tests/malloc_test.uya` 通过（12 个 malloc 综合用例）。
  - 验证：`../uya/bin/uya test tests/test_mem_allocator.uya` 通过（8 个 allocator 用例）。
  - 验证：`../uya/bin/uya test tests/test_stdlib.uya` 通过。
  - 验证：`../uya/bin/uya build tests/bench_malloc_phase3.uya -o tests/build/bench_malloc_phase3_current` 成功；随后执行 `./tests/build/bench_malloc_phase3_current`，输出 `malloc_phase3_random ops=10000 allocs=5120 frees=4880 peak_active=255 elapsed_ns=8444787 avg_ns=844 checksum=5856720`。

## 2026-06-25

任务路径：阶段 3：分配速度优化

### Task 3.2: 大块分配走 mmap/munmap 快速路径

- [x] Task 3.2：大块分配走 mmap/munmap 快速路径
- **优先级**: P1
- **预计时间**: 1 天（可独立于 Task 3.1；直接 mmap/munmap 行为只在本任务验收）
- **文件**: `lib/libc/heap.uya`
- **方案**: 请求大小 ≥ 4096 字节时，直接从 mmap 分配独立映射，free 时直接 munmap。不经过自由链表，不参与 split/coalesce。大块不能只写 `ChunkHeader` 后返回：现有 `free/realloc` 会先通过 `owns_ptr()` 验证，小块 `heap_regions` 不包含独立大块映射，因此必须维护独立的大块映射表或把大块安全登记到可验证的 region 表中。`_free_impl/_realloc_impl` 的入口顺序必须先查 large-region metadata，命中后直接走 large 路径；未命中才继续走普通 `owns_ptr()` 验证。
- **large 布局约束**: large path 使用独立的 header-only 布局，不写 footer，也不使用 `CHUNK_OVERHEAD`、`chunk_total_for_payload`、`to_footer/write_footer`、`split_chunk` 或 `coalesce` helper。`ChunkHeader` 只作为 `to_user_ptr/to_header` 兼容层和 magic 校验哨兵；真实映射大小、用户 payload 大小、free/realloc/copy 长度都以 `LargeRegion` 元数据为准。
- **完成说明**:
  - [x] 新增 `LargeRegion` 链表和 `heap_debug_large_region_count/mmap_count/munmap_count`，让 large-path 具备最小可观测性。
  - [x] `malloc` 对 `>=4096` 请求直接走独立 `mmap`，不进入普通 bins，也不参与 split/coalesce。
  - [x] `_free_impl` 先查 large-region，再执行 `munmap`，避免被普通 `owns_ptr()` 提前过滤。
  - [x] `_realloc_impl` 对 large 指针统一走“重新分配 + 复制前缀 + 释放旧映射”，并支持 large-to-large 与 large-to-small。
  - [x] bin 回归测试已更新到阶段 3 语义；`docs/libc_malloc_design.md` 已同步 large-path 当前实现。
- **验收标准**:
  - [x] 新增最小 debug/test 观测能力（例如 large region 数量、普通自由链表/bin 计数，或 mmap/munmap 计数），large-path 验收不能只依赖现有 malloc 测试是否通过
  - [x] 分配/释放 1MB 块不污染自由链表，不触发无意义的 split/coalesce
  - [x] large 指针的 `free` 会实际 `munmap`，不会被 `owns_ptr()` 提前过滤
  - [x] large 指针的 `realloc` 支持复制到新块并释放旧映射
  - [x] 新增确定性测试：large malloc 后 large-region 计数增加，free 后计数减少且普通自由链表/bin 状态不变
  - [x] 新增确定性测试：large realloc 到更大块会保留旧内容前缀、登记新映射、释放旧映射；large realloc 到小块时行为与设计一致并有明确断言
- **验证**:
  - `../uya/bin/uya test tests/test_libc_heap_large_path.uya` -> 3 tests passed, 41 assertions
  - `../uya/bin/uya test tests/test_libc_heap_bins.uya` -> 3 tests passed, 75 assertions
  - `../uya/bin/uya test tests/test_std_stdlib_malloc.uya` -> 1 test passed
  - `../uya/bin/uya test tests/malloc_test.uya` -> 12 subtests passed
  - `git diff --check` -> 通过

## 2026-06-25

来源标题：可勾选执行清单
任务路径：阶段 3：分配速度优化

  - [x] 阶段 3 回归测试、bin 覆盖测试和 large-path 测试全部通过
    - 验证：`../uya/bin/uya test tests/test_std_stdlib_malloc.uya` 通过（总计 1 个测试，通过 1，失败 0）。
    - 验证：`../uya/bin/uya test tests/test_libc_heap_bins.uya` 通过（3 个子测试全部通过，75 个断言通过）。
    - 验证：`../uya/bin/uya test tests/test_libc_heap_large_path.uya` 通过（3 个子测试全部通过，41 个断言通过）。


任务路径：阶段 3：分配速度优化
- [x] 阶段 3：分配速度优化
  - [x] 阶段 3 性能收益报告补充实测数据
    - 编译命令：`../uya/bin/uya build tests/bench_malloc_phase3.uya -o tests/build/bench_malloc_phase3_current`；`git worktree add --detach ../uya_malloc_phase2_baseline 13b6d9ce` 后执行 `env UYA_ROOT=../uya_malloc_phase2_baseline/lib ../uya/bin/uya build tests/bench_malloc_phase3.uya -o tests/build/bench_malloc_phase3_baseline`
    - 验证命令：`./tests/build/bench_malloc_phase3_current` 与 `./tests/build/bench_malloc_phase3_baseline` 各运行 30 次；`../uya/bin/uya test tests/test_std_stdlib_malloc.uya`；`../uya/bin/uya test tests/test_libc_heap_bins.uya`；`../uya/bin/uya test tests/test_libc_heap_large_path.uya`
    - 验证结果：`avg_ns mean 778.6 -> 1211.7`，`elapsed_ns mean 7790909 -> 12122754`；`test_std_stdlib_malloc` 通过（总计 1，失败 0）；`test_libc_heap_bins` 通过（3 tests，75 assertions）；`test_libc_heap_large_path` 通过（3 tests，41 assertions）
    - 文档同步：`docs/todo_malloc_perf.md` 已补充阶段 3 实测记录，顶层状态更新为“阶段 1-3 已完成，阶段 4 待开始”，最后更新日期改为 `2026-06-25`

## 2026-06-25
路径：阶段 4：多线程扩展

### Task 4.1: per-thread allocation cache（线程本地缓存）

- [x] Task 4.1：per-thread allocation cache
  - **优先级**: P2（仅多线程场景受益）
  - **文件**: `lib/libc/heap.uya`、`lib/libc/pthread.uya`
  - **完成说明**: 在线程描述符上挂接 per-thread small-object cache；`malloc` 小块命中当前线程 cache 时无锁返回；`free` 小块优先进入当前线程 cache；线程退出时回刷当前线程 cache，避免缓存块随线程描述符释放而泄漏。
  - **验证**:
    - `../uya/bin/uya tests/test_libc_heap_tcache.uya && ./a.out`：通过（新增线程退出回刷场景；修复前失败 `EXIT:61`，修复后 `EXIT:0`）
    - `../uya/bin/uya test tests/test_std_stdlib_malloc.uya`：通过（总计 1，失败 0）
    - `../uya/bin/uya test tests/test_libc_heap_bins.uya`：通过（3 tests，75 assertions）
    - `../uya/bin/uya test tests/test_libc_heap_large_path.uya`：通过（3 tests，41 assertions）
    - `../uya/bin/uya test tests/test_pthread_create_join.uya`：通过
    - `../uya/bin/uya test tests/test_pthread_api_create_join.uya`：通过
  - **后续说明**:
    - `单线程无退化和多线程吞吐目标验证完成` 继续在主 todo 的阶段 4 清单中跟踪。
    - `阶段 4 性能收益报告补充实测数据` 继续在主 todo 的阶段 4 清单中跟踪。
## 2026-06-25 阶段 4：多线程扩展

任务路径：`阶段 4：多线程扩展`

- [x] 降低 `free`/tcache 热路径全局锁争用后重新验证单线程无退化和多线程吞吐目标
  - 验证命令：`../uya/bin/uya test tests/test_libc_heap_tcache_metrics.uya`
    - 结果：通过；验证 tcache `free` + 同线程复用路径不再增加 `heap_debug_lock_acquire_count()`
  - 验证命令：`../uya/bin/uya test tests/test_libc_heap_tcache.uya`
    - 结果：通过；新增 `malloc(2048)` 阈值边界 tcache 复用场景
  - 验证命令：`../uya/bin/uya test tests/test_std_stdlib_malloc.uya`
    - 结果：通过
  - 验证命令：`../uya/bin/uya test tests/test_libc_heap_large_path.uya`
    - 结果：通过；3/3 测试通过
  - 验证命令：`../uya/bin/uya build tests/bench_malloc_phase4.uya -o tests/build/bench_malloc_phase4_current`
    - 结果：构建成功
  - 验证命令：`./tests/build/bench_malloc_phase4_current`
    - 结果：`threads=1 throughput_ops_per_sec=896069 lock_acquires=58 lock_contentions=0 tcache_hits=223944 tcache_misses=56`
    - 结果：`threads=2 throughput_ops_per_sec=1268075 lock_acquires=75740 lock_contentions=14 tcache_hits=377113 tcache_misses=70887`
    - 结果：`threads=4 throughput_ops_per_sec=2891477 lock_acquires=232 lock_contentions=202 tcache_hits=895776 tcache_misses=224`
    - 结果：`threads=8 throughput_ops_per_sec=4684753 lock_acquires=464 lock_contentions=432 tcache_hits=1791552 tcache_misses=448`
    - 结论：4 线程吞吐为单线程 `3.23x`，满足“4 线程 > 单线程 2.5x”目标；单线程吞吐较本轮修复前基线 `850584 -> 896069`

## 2026-06-25 本轮完成

来源：`docs/todo_malloc_perf.md`

- [x] 阶段 4：多线程扩展
  - [x] 阶段 4 性能收益报告补充实测数据
    - 完成内容：在“性能收益报告”追加阶段 4 的 10 次进程级重复实测，补充 `1/2/4/8` 线程吞吐、锁获取/竞争和 `tcache` 命中率，并注明阶段 3 缺少同口径 benchmark 的对照限制。
    - 验证：`../uya/bin/uya test tests/test_libc_heap_tcache_metrics.uya` 通过（总计 1，失败 0，assertions 16）。
    - 验证：`../uya/bin/uya build tests/test_libc_heap_tcache.uya -o tests/build/test_libc_heap_tcache` 成功；随后执行 `./tests/build/test_libc_heap_tcache` 通过（exit 0）。
    - 验证：`../uya/bin/uya test tests/test_std_stdlib_malloc.uya` 通过（总计 1，失败 0）。
    - 验证：`../uya/bin/uya build tests/bench_malloc_phase4.uya -o tests/build/bench_malloc_phase4_current` 成功；随后执行 `./tests/build/bench_malloc_phase4_current` 连续 10 次，生成 `40` 条 `threads=1/2/4/8` 样本并完成统计。

## 可勾选执行清单
完成日期：2026-06-25
父级任务路径：收口验证
  - [x] `make check` 通过
    - 验证命令：`env UYA_CMD_BOOTSTRAP_COMPILER="../uya/bin/uya" make check`
    - 验证结果：通过。自举、1061 个程序测试、UPM 套件、exec vm 专项回归、microapp 聚合套件，以及 SIMD / @syscall / http_bench C99 专项验证通过；`benchmarks/http_bench_async_epoll.uya C99` 按 Makefile 默认跳过。

路径上下文：## 可勾选执行清单 > 收口验证
  - [x] 本文档的任务状态、测试结果和最后更新日期已同步
    验证命令：`rg -n '当前状态|测试结果|最后更新|收口验证' docs/todo_malloc_perf.md`
    验证结果：第 5-6 行与第 511 行已同步；主 todo 仅保留未完成的 `make clean && make backup-all`。
    验证命令：`python3 ~/.codex/skills/goal-task-runner/scripts/check_todo.py docs/todo_malloc_perf.md`
    验证结果：`ok: docs/todo_malloc_perf.md has 0 active tasks`
    验证命令：`git diff --check`
    验证结果：通过
## 2026-06-25 收口验证

路径：`## 可勾选执行清单`

- [x] 收口验证
  已归档：`make check` 已于 2026-06-25 通过，验证记录见 `docs/todo_malloc_perf_completed.md`
  - [x] 需要提交时按仓库规则运行 `make clean && make backup-all`
    验证命令：`make clean`；`make backup-all`
    验证结果：两者均退出码 `0`。`make backup-all` 完成自举、全量验证、`backup/uyacache` 备份，以及 `backup/uya.c`、`backup/uya-linux-x86_64.c`、`backup/uya-hosted.c`、`backup/uya-hosted-linux-x86_64.c`、`backup/uya-hosted-macos-arm64.c`、`backup/uya-hosted-macos-x86_64.c`、`backup/uya-hosted-macos.c` 刷新。
    关键摘要：`UPM`、`exec vm`、`microapp`、`@syscall C99`、`SIMD C99 NEON`、`http_bench C99` 通过；`benchmarks/http_bench_async_epoll.uya` 按脚本提示未启用检查而跳过。

## 阶段 2：碎片化根治（预计 3-5 天）
### Task 2.1: 实现 free 时相邻块合并 (coalescing)

- [x] **添加 footer 辅助函数**：
   ```uya
   const CHUNK_FLAG_FREE: usize = 1;
   // 当前 ABI 下为 24B；它不是 16 的倍数，不能直接作为 chunk 总长公式的最终结果。
   const CHUNK_OVERHEAD: usize = @size_of(ChunkHeader) + @size_of(ChunkFooter);

   fn raw_chunk_size(raw: usize) usize {
       return raw & ~CHUNK_FLAG_FREE;
   }

   fn chunk_total_for_payload(payload: usize) usize {
       return heap_align_up(payload + CHUNK_OVERHEAD);
   }

   fn to_footer(hdr: &ChunkHeader) &ChunkFooter {
       const sz: usize = get_size(hdr);
       return (((hdr as &byte) + sz - @size_of(ChunkFooter)) as &ChunkFooter);
   }

   fn write_footer(hdr: &ChunkHeader) void {
       var footer: &ChunkFooter = to_footer(hdr);
       footer.size = hdr.size;
   }

   fn find_region_for_header(hdr: &ChunkHeader) &HeapRegion {
       const addr: usize = hdr as usize;
       var region: &HeapRegion = heap_regions;
       while !is_null(region as &void) {
           const base: usize = region.base as usize;
           const end: usize = base + region.size;
           if addr >= base && addr < end {
               return region;
           }
           region = region.next;
       }
       return null;
   }

   fn next_chunk_in_region(region: &HeapRegion, hdr: &ChunkHeader) &ChunkHeader {
       const sz: usize = get_size(hdr);
       const next_addr: usize = (hdr as usize) + sz;
       const end: usize = (region.base as usize) + region.size;
       if next_addr >= end { return null; }
       return next_addr as &ChunkHeader;
   }

   fn prev_chunk_in_region(region: &HeapRegion, hdr: &ChunkHeader) &ChunkHeader {
       const base: usize = region.base as usize;
       const addr: usize = hdr as usize;
       if addr == base { return null; }
       // 从前一个 footer 读取 size，计算出前一个 chunk 的起始地址
       const footer_addr: &ChunkFooter = ((hdr as &byte) - @size_of(ChunkFooter)) as &ChunkFooter;
       const prev_sz: usize = raw_chunk_size(footer_addr.size);
       if prev_sz < chunk_total_for_payload(MIN_CHUNK_SIZE) || addr < base + prev_sz { return null; }
       return ((hdr as &byte) - prev_sz) as &ChunkHeader;
   }
   ```
   验证：
   - `../uya/bin/uya test tests/test_std_stdlib_malloc.uya`（通过）
   - `../uya/bin/uya build tests/bench_malloc_phase2.uya -o tests/build/bench_malloc_phase2_round && ./tests/build/bench_malloc_phase2_round`（通过；`malloc_phase2_frag rounds=64 budget8_rounds=64 unique_regions=1 peak_mmap_count=1 peak_mapped_bytes=8192 big_page_reuse_hits=64`；`malloc_phase2_realloc iterations=4000 inplace_hits=4000 inplace_hit_rate_pct=100 copy_bytes=0`）

## 阶段 2：碎片化根治（预计 3-5 天）

### Task 2.1: 实现 free 时相邻块合并 (coalescing)

- [x] **修改 morecore**：创建 chunk 时把 `alloc_size` 设为 `max(chunk_total_for_payload(aligned_payload), HEAP_PAGE_SIZE)`，保持小分配至少映射 4KB region 以复用后续 split/coalesce，并对整个 region chunk 写入 footer。`region.size` 仍记录该 region 内 chunk 区域总字节数。注意 `CHUNK_OVERHEAD = 24B` 时，`aligned_payload + CHUNK_OVERHEAD` 会得到 `8 mod 16` 的 chunk 总长，破坏后续 header 和用户指针的 16 字节对齐；必须对最终 chunk 总长再次执行 `heap_align_up`。
  - 验证（2026-06-25）：
    - `../uya/bin/uya test tests/test_std_stdlib_malloc.uya`：通过（总计 1，通过 1，失败 0）
    - `../uya/bin/uya build tests/bench_malloc_phase2.uya -o tests/build/bench_malloc_phase2_current`：构建成功
    - `./tests/build/bench_malloc_phase2_current`：`malloc_phase2_frag rounds=64 budget8_rounds=64 unique_regions=1 peak_mmap_count=1 peak_mapped_bytes=8192 big_page_reuse_hits=64`；`malloc_phase2_realloc iterations=4000 inplace_hits=4000 inplace_hit_rate_pct=100 copy_bytes=0`

## 阶段 2：碎片化根治（预计 3-5 天）
### Task 2.1: 实现 free 时相邻块合并 (coalescing)
- [x] **修改 find_chunk**：使用 footer 后，判断空闲块是否足够时必须比较 `chunk_total_for_payload(needed_payload)`，不能继续使用 `needed_payload + @size_of(ChunkHeader)`。否则 first-fit 可能选中一个容得下旧 header 开销、但容不下 footer 后总开销的块。
  - 完成内容：核对 `lib/libc/heap.uya` 后确认 `find_chunk` 当前实现已经使用 `chunk_total_for_payload(needed_payload)` 作为空闲块匹配阈值；本轮补上缺失的确定性回归 `tests/test_libc_heap_find_chunk_footer_fit.uya`，覆盖“64B free chunk 只能满足旧 header 开销、不能满足 footer 开销”的场景，并通过 `heap_flush_current_thread_cache()` 强制命中 global bins 路径。
  - 验证：`../uya/bin/uya test tests/test_libc_heap_find_chunk_footer_fit.uya` 通过（1 test，9 assertions）。
  - 验证：`../uya/bin/uya test tests/test_libc_heap_bins.uya` 通过（3 tests，75 assertions）。
  - 验证：`../uya/bin/uya test tests/test_std_stdlib_malloc.uya` 通过（总计 1 个测试，通过 1，失败 0）。

## 阶段 2：碎片化根治（预计 3-5 天）
### Task 2.1: 实现 free 时相邻块合并 (coalescing)
- [x] **修改 split_chunk**：`alloc_total = chunk_total_for_payload(needed_payload)`；只有 `rem >= chunk_total_for_payload(MIN_CHUNK_SIZE)` 才分割。分割后已分配 chunk 与剩余 free chunk 都必须维护各自 footer。
  验证说明：核对 `lib/libc/heap.uya` 中现有 `split_allocated_chunk` 实现，已按 `chunk_total_for_payload(normalize_payload_size(...))` 计算分配总长，仅在 `rem >= chunk_total_for_payload(MIN_CHUNK_SIZE)` 时分割，并分别对已分配 chunk 与剩余 free chunk 写 footer。
  验证命令：`../uya/bin/uya test tests/test_libc_heap_bins.uya`
  验证结果：通过，3 tests / 75 assertions。
  验证命令：`../uya/bin/uya test tests/test_libc_heap_find_chunk_footer_fit.uya`
  验证结果：通过，1 test / 9 assertions。
  验证命令：`../uya/bin/uya test tests/test_std_stdlib_malloc.uya`
  验证结果：通过，1 个测试文件通过，0 失败。
