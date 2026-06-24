# libc malloc/free 性能优化 TODO

**创建日期**: 2026-06-18
**优先级**: P1（性能基础设施）
**当前状态**: 阶段 1-4 已完成；`make check` 已于 2026-06-25 通过并归档，待执行 `make clean && make backup-all`
**测试结果**: 2026-06-25 `make check` 通过；验证记录见 `docs/todo_malloc_perf_completed.md`
**关联文档**: `docs/libc_malloc_design.md`
**基线说明**: 阶段 1 对照基线固定为提交 `bee7df32`：`ChunkHeader` 为 16B、`FreeChunk` 为 32B、未引入 footer。当前实现已完成阶段 2，`ChunkHeader + ChunkFooter` 开销为 24B，阶段 3 起的性能对比以此为新基线。

---

## 可勾选执行清单

完成某项后把对应 `- [ ]` 改为 `- [x]`。阶段级 checkbox 只有在该阶段所有任务、测试和性能记录都完成后再勾选。

## 概述

本文档基于对 `lib/libc/heap.uya` 完整实现的性能审计，列出了当前 malloc/free/realloc 实现的性能瓶颈与优化任务。当前实现采用 **mmap + size-segregated 双向自由链表 + 全局自旋锁** 策略，在单线程场景下可正常工作，但在多线程、长时间运行、或大量小对象场景下仍存在显著性能问题。

### 阶段 1 基线实现概要

| 特性 | 状态 | 文件 |
|------|------|------|
| 空闲链表管理 | ✅ 已实现 | `lib/libc/heap.uya` |
| 块分割 (split) | ✅ 已实现 | `lib/libc/heap.uya:175-195` |
| 相邻块合并 (coalesce) | ❌ 未实现 | — |
| 多线程锁 | ✅ 全局自旋锁 | `lib/libc/heap.uya:14-25` |
| 大小分箱 | ❌ 未实现 | — |
| realloc 原地扩展 | ❌ 未实现（总是 malloc+memcpy+free） | `lib/libc/heap.uya:245-268` |
| per-thread cache | ❌ 未实现 | — |

---

## 性能收益报告

本节先保留阶段 1 基线上的**预期收益分析**，再追加各阶段落地后的实测记录。每个阶段都必须用下文的基准口径补充真实数据，避免只依赖理论复杂度判断。

### 基线瓶颈

阶段 1 基线 allocator 的主要成本来自以下路径：

| 路径 | 当前成本 | 典型触发场景 | 影响 |
|------|----------|--------------|------|
| size/free 标志读写 | 有符号除法/取模 | 每次 find/split/free/realloc | 热路径常数因子偏高 |
| `owns_ptr()` | 遍历所有 HeapRegion，O(region 数) | 每次 free/realloc 校验 | 长运行服务 region 增多后释放延迟上升 |
| `find_chunk()` | 单链表 first-fit，O(free chunk 数) | 大量小块释放后再次分配 | 分配延迟随碎片数量增长 |
| 无 coalescing | 无法合并相邻空闲块 | 交替大小分配、请求峰谷切换 | 总空闲足够但大分配失败，产生假性 OOM |
| realloc 扩容 | malloc + memcpy + free | Vec/缓冲区增长 | 额外拷贝和二次链表操作 |
| 全局锁 | 所有线程串行 malloc/free | 多线程 HTTP/async runtime | 核数增加时吞吐难扩展 |

### 分阶段收益预估

| 阶段 | 主要优化 | 收益类型 | 预期量级 | 必测指标 |
|------|----------|----------|----------|----------|
| 阶段 1 | 位运算、region 命中缓存、减小最小块 | 低风险常数优化 + 小对象内存效率 | 热路径 flag 操作从除法/取模降为单条位运算；`free` 的 region 校验在局部性良好时接近 O(1)；1B 小对象实际占用从 80B 降到 48B | malloc/free 单线程吞吐、region 数增长后的 free 延迟、1B/8B/24B 对象内存占用 |
| 阶段 2 | coalescing + realloc 原地扩展 | 碎片化治理 + 拷贝减少 | 交替分配场景从“可能假性 OOM”变为可复用相邻空闲空间；相邻空闲扩容时 realloc 避免 memcpy | 碎片压力测试最大可持续轮数、峰值 mmap 次数、realloc 原地命中率、复制字节数 |
| 阶段 3 | size-segregated bins + large mmap | 分配延迟稳定化 | 小/中对象查找从扫描单一长链表变为从目标 bin 起跳；大块不污染普通 free list | P50/P95/P99 malloc 延迟、每次分配平均扫描 chunk 数、large 分配后普通 free list/bin 长度变化 |
| 阶段 4 | per-thread cache | 多线程吞吐扩展 | 小对象命中 tcache 时绕过全局锁；4 线程目标吞吐 > 单线程 2.5x | 1/2/4/8 线程吞吐、锁竞争次数、tcache 命中率 |

### 场景化收益

| 场景 | 当前表现 | 优化后目标 |
|------|----------|------------|
| 编译器 AST/IR 节点密集分配 | 大量小对象浪费最小块空间，free list 容易积累小碎片 | 阶段 1 降低小对象占用，阶段 2 合并回收相邻碎片，阶段 3 缩短小对象查找链路 |
| HTTP/async runtime 短生命周期请求对象 | 请求峰值后释放大量对象，后续请求可能扫描长链表 | 阶段 2 恢复连续空闲块，阶段 3 按 size class 复用，阶段 4 降低多线程锁竞争 |
| Vec/缓冲区增长 | 扩容总是分配新块并复制旧内容 | 阶段 2 在 next chunk 空闲且容量足够时原地增长，减少 memcpy 和额外 free |
| 大 buffer / 文件 / 网络 payload | 大块进入普通堆，split/free 可能影响小对象链表 | 阶段 3.2 独立 mmap/munmap，大块生命周期不污染普通 allocator 状态 |

### 建议的报告数据口径

每完成一个阶段后，在本节追加一小段实测记录，至少包含：

```text
日期：
提交：
平台：
编译命令：
测试命令：
样本规模：
基线结果：
优化后结果：
变化：
结论：
```

建议保留以下核心指标，便于跨阶段比较：

| 指标 | 含义 | 目标方向 |
|------|------|----------|
| ops/sec | 固定大小 malloc/free 吞吐 | 越高越好 |
| avg/p95/p99 latency | 单次 malloc/free 延迟 | 越低越好 |
| average scanned chunks | 每次 find_chunk 扫描节点数 | 越低越好 |
| mmap count / peak mapped bytes | mmap 次数与峰值映射量 | 在同负载下越低越稳定越好 |
| fragmentation survival rounds | 碎片压力测试可持续轮数 | 越高越好 |
| realloc in-place hit rate | realloc 原地扩展比例 | 越高越好 |
| copy bytes during realloc | realloc 扩容复制字节数 | 越低越好 |
| lock acquisitions / contention | 多线程锁获取和竞争次数 | 越低越好 |

### 阶段 2 实测记录（2026-06-24）

日期：2026-06-24
提交：基线 `bee7df32`；当前 `4fffff4a`
平台：Linux 6.12.65-amd64-desktop-rolling x86_64 GNU/Linux，page size 4096B
编译命令：`../uya/bin/uya build tests/bench_malloc_phase2.uya -o tests/build/bench_malloc_phase2_current`；`git worktree add --detach ../uya_stage1_bench bee7df32` 后执行 `env UYA_ROOT=../uya_stage1_bench/lib ../uya/bin/uya build tests/bench_malloc_phase2.uya -o tests/build/bench_malloc_phase2_baseline`
测试命令：`./tests/build/bench_malloc_phase2_current`；`./tests/build/bench_malloc_phase2_baseline`；`../uya/bin/uya test tests/test_std_stdlib_malloc.uya`
样本规模：碎片压力 64 轮 `malloc(1000) -> malloc(2800) -> free -> free -> malloc(3600) -> free`；`realloc` 压力 4000 轮 `malloc(1000) + malloc(1000) + free(next) + realloc(1800)`
基线结果：`budget8_rounds=7`；`peak_mmap_count=65`；`peak_mapped_bytes=532480`；`big_page_reuse_hits=1`；`inplace_hit_rate_pct=0`；`copy_bytes=4032000`
优化后结果：`budget8_rounds=64`；`peak_mmap_count=1`；`peak_mapped_bytes=8192`；`big_page_reuse_hits=64`；`inplace_hit_rate_pct=100`；`copy_bytes=0`
变化：8-region 预算下碎片压力可持续轮数 `7 -> 64`（+57，约 9.1x）；峰值 `mmap` 次数 `65 -> 1`（-98.5%）；峰值 mapped bytes `532480B -> 8192B`（-524288B，-98.5%）；`realloc` 原地命中率 `0% -> 100%`，复制字节 `4032000B -> 0B`
结论：阶段 2 已把该 workload 从“几乎每轮新增 region”收敛到“单 region 循环复用”，并把相邻空闲块扩容场景的复制成本降到 0；后续阶段可以把关注点收敛到查找延迟和多线程锁竞争。

### 阶段 3 实测记录（2026-06-25）

日期：2026-06-25
提交：基线 `13b6d9ce`（阶段 2 完成态）；当前 `df801ee9`
平台：Linux 6.12.65-amd64-desktop-rolling #25.01.01.11 SMP PREEMPT_DYNAMIC Wed Jan 14 15:36:12 CST 2026 x86_64 GNU/Linux
编译命令：`../uya/bin/uya build tests/bench_malloc_phase3.uya -o tests/build/bench_malloc_phase3_current`；`git worktree add --detach ../uya_malloc_phase2_baseline 13b6d9ce` 后执行 `env UYA_ROOT=../uya_malloc_phase2_baseline/lib ../uya/bin/uya build tests/bench_malloc_phase3.uya -o tests/build/bench_malloc_phase3_baseline`
测试命令：`./tests/build/bench_malloc_phase3_current` 与 `./tests/build/bench_malloc_phase3_baseline` 各运行 30 次；`../uya/bin/uya test tests/test_std_stdlib_malloc.uya`；`../uya/bin/uya test tests/test_libc_heap_bins.uya`；`../uya/bin/uya test tests/test_libc_heap_large_path.uya`
样本规模：固定随机种子、256 活跃槽位、10000 次随机 alloc/free 操作；size class 为 `32/64/128/256/512/1024/2048/4096`；统计 30 次进程级重复运行的 `elapsed_ns` 与 `avg_ns`
基线结果：`avg_ns mean/p50/p95/p99 = 778.6/781/820/823`；`elapsed_ns mean/p50/p95/p99 = 7790909/7818635/8208053/8233051`
优化后结果：`avg_ns mean/p50/p95/p99 = 1211.7/1200/1281/1316`；`elapsed_ns mean/p50/p95/p99 = 12122754/12009376/12813573/13162317`
变化：`avg_ns` mean `778.6 -> 1211.7`（+55.6%，等价吞吐约 `1284357 -> 825287 ops/sec`）；P50 `781 -> 1200`（+53.6%）；P95 `820 -> 1281`（+56.2%）；P99 `823 -> 1316`（+59.9%）；`elapsed_ns` mean `7.79ms -> 12.12ms`（+55.6%）
当前实现诊断：`tests/test_libc_heap_bins.uya` 覆盖的跨 bin 复用场景中 `heap_debug_last_find_start_bin() == 6` 且 `heap_debug_last_find_steps() == 1`；split 后 remainder 会回到 bin 6。`tests/test_libc_heap_large_path.uya` 验证 1MiB malloc/free 与 large realloc 前后 8 个普通 bin 长度保持不变，large `mmap/munmap` 计数按预期变化。
结论：阶段 3 已验证结构性目标，目标 bin 起跳查找和 large path 隔离都正确生效；但在包含 `4096` size class 的当前混合 workload 上，large 直连 `mmap/munmap` 成本超过了 bins 带来的查找收益，整体分配延迟较阶段 2 回退约 54%-60%。后续进入阶段 4 前，应把“小中对象 bins”与“临界大块阈值”拆成独立基准口径，避免把两类效应混成单一吞吐结论。

### 阶段 4 实测记录（2026-06-25）

日期：2026-06-25
提交：当前 `6bfd45bc`
平台：Linux 6.12.65-amd64-desktop-rolling #25.01.01.11 SMP PREEMPT_DYNAMIC Wed Jan 14 15:36:12 CST 2026 x86_64 GNU/Linux
编译命令：`../uya/bin/uya build tests/bench_malloc_phase4.uya -o tests/build/bench_malloc_phase4_current`；`../uya/bin/uya build tests/test_libc_heap_tcache.uya -o tests/build/test_libc_heap_tcache`
测试命令：`../uya/bin/uya test tests/test_libc_heap_tcache_metrics.uya`；`./tests/build/test_libc_heap_tcache`；`../uya/bin/uya test tests/test_std_stdlib_malloc.uya`；`./tests/build/bench_malloc_phase4_current` 连续运行 10 次
样本规模：每次 benchmark 覆盖 `1/2/4/8` 线程；每线程执行 `4000` 轮、每轮对 `32/64/128/256/512/1024/2048` 七个 size class 各做 `8` 次 `malloc + free`；单次进程总操作数分别为 `448000/896000/1792000/3584000`；统计 10 次进程级重复运行的 `throughput_ops_per_sec`、`elapsed_ns`、`lock_acquires`、`lock_contentions`、`tcache_hit_rate_bp`
基线结果：阶段 3 提交 `df801ee9` 尚未提供 `tests/bench_malloc_phase4.uya` 与 `tcache` 指标接口，本阶段按扩展目标使用单线程结果作为对照：`threads=1 throughput_ops_per_sec mean/p50/p95 = 895340.3/892860/903168`；`elapsed_ns mean/p50/p95 = 500391895.7/499741555/506360838`；`lock_acquires = 58`；`lock_contentions = 0`；`tcache_hit_rate = 99.97%`
优化后结果：`threads=2 throughput_ops_per_sec mean/p50/p95 = 1470225.6/1585868/1622179`；`elapsed_ns mean/p50/p95 = 623685488.2/562662469/814806604`；`lock_acquires p50 = 116`；`lock_contentions mean/p50 = 15.3/16`；`tcache_hit_rate mean/p50 = 92.61%/99.97%`。`threads=4 throughput_ops_per_sec mean/p50/p95 = 2682543.8/2738881/2922646`；`elapsed_ns mean/p50/p95 = 673119004.7/639752442/776733531`；`lock_acquires p50 = 232`；`lock_contentions mean/p50 = 206.6/203`；`tcache_hit_rate mean/p50 = 98.35%/99.97%`。`threads=8 throughput_ops_per_sec mean/p50/p95 = 4564436.2/4586196/4922242`；`elapsed_ns mean/p50/p95 = 788061208.4/774960887/925131264`；`lock_acquires p50 = 464`；`lock_contentions mean/p50 = 426.3/424`；`tcache_hit_rate mean/p50 = 99.78%/99.97%`
变化：相对单线程基线，`2/4/8` 线程吞吐均值分别达到 `1.64x/3.00x/5.10x`，P50 达到 `1.78x/3.07x/5.14x`；典型样本的 `lock_acquires` 仅随线程数近线性增长 `58 -> 116 -> 232 -> 464`。在 10 次进程级重复里，`threads=2/4/8` 分别有 `7/10`、`7/10`、`9/10` 样本维持 `99.97%` 的 `tcache` 命中率，其余样本出现额外 refill/miss 长尾并拉低均值。
结论：阶段 4 已实测达到文档目标“4 线程吞吐 > 单线程 2.5x”，并把大多数小对象热路径的全局锁获取压缩到“每线程仅为每个 size class 做一次冷启动 refill”的量级。当前残余风险主要是 fresh-process 样本里偶发的 `tcache` 冷启动长尾；若后续需要更稳定的均值口径，可在 benchmark 中加入预热轮或拉长采样时间。


## 阶段 2：碎片化根治（预计 3-5 天）

**目标**：实现空闲块合并和 realloc 原地扩展，解决根本性的内存碎片化问题。

---

### Task 2.2: realloc 原地扩展优化

- **优先级**: P1
- **预计时间**: 1 天
- **文件**: `lib/libc/heap.uya`
- **当前问题**: `_realloc_impl` 总是 `malloc → memcpy → free`，即使紧邻的下一个 chunk 空闲也不尝试原地扩展。
- **前置依赖**: Task 2.1（coalescing）完成后，可以通过检查 next chunk 是否空闲来决定原地扩展。
- **方案**:
  ```uya
  fn _realloc_impl(ptr: &void, size: usize) &void {
      // ... 已有的 null/size==0/owns_ptr/magic 检查 ...

      var hdr: &ChunkHeader = to_header(ptr);
      var old_sz: usize = get_size(hdr) - CHUNK_OVERHEAD;

      // 缩容：直接返回原指针
      if size <= old_sz { return ptr; }

      var aligned: usize = heap_align_up(size);
      if aligned < MIN_CHUNK_SIZE { aligned = MIN_CHUNK_SIZE; }
      var needed_total: usize = chunk_total_for_payload(aligned);
      var region: &HeapRegion = find_region_for_header(hdr);
      if is_null(region as &void) { return null; }

      // 尝试原地扩展
      var next: &ChunkHeader = next_chunk_in_region(region, hdr);
      if !is_null(next as &void) && next.magic == CHUNK_MAGIC && is_free(next) {
          var next_sz: usize = get_size(next);
          if get_size(hdr) + next_sz >= needed_total {
              // 原地扩展：吞并下一个空闲 chunk
              remove_free(next as &FreeChunk);
              hdr.size = get_size(hdr) + next_sz;
              set_free(hdr, false);
              var footer: &ChunkFooter = to_footer(hdr);
              footer.size = hdr.size;
              // 如果吞并后有剩余，分割出去
              split_chunk(hdr as &FreeChunk, aligned);
              return ptr;
          }
      }

      // 原地扩展失败，走 malloc+memcpy+free
      var new_ptr: &void = _malloc_impl(size);
      if is_null(new_ptr) { return null; }
      _ = memcpy(new_ptr as *byte, ptr as *const byte, old_sz);
      _free_impl(ptr);
      return new_ptr;
  }
  ```
- **影响**: vector 扩容等场景避免了不必要的 memcpy 和重新分配。
---

## 阶段 3：分配速度优化（预计 3-5 天）

**目标**：通过大小分箱消除 find_chunk 的线性扫描，使分配延迟接近 O(1)。

---

### Task 3.1: 实现 size-segregated free lists（大小分箱）

- **优先级**: P1
- **预计时间**: 3-5 天
- **文件**: `lib/libc/heap.uya`
- **当前问题**: `find_chunk` 在单一自由链表上做线性 first-fit 扫描。碎片化时链表中充斥大量太小无法使用的 chunk，每次扫描都要跳过它们。
- **方案**: 按 2 的幂分级，引入分箱自由链表。

```
BIN 0:  [32, 64)    字节
BIN 1:  [64, 128)
BIN 2:  [128, 256)
BIN 3:  [256, 512)
BIN 4:  [512, 1024)
BIN 5:  [1024, 2048)
BIN 6:  [2048, 4096)
BIN 7:  [4096, ∞)    — 顶层普通堆 bin；直接 mmap/munmap 留给 Task 3.2
```

**bin 口径**：上表统一表示“对齐后的用户 payload size class”，不是 `ChunkHeader + payload + footer` 的 chunk total size。阶段 2 引入 footer 后，最小 payload 仍是 32，但最小 chunk total 会变成 `chunk_total_for_payload(32)`；bin 0 不能因为直接传入 chunk total 而空置。所有入口必须先用同一组转换函数归一化，禁止在 `find_chunk`、`add_free/remove_free`、`split_chunk` 中混用 payload size 与 chunk total size。

---

## 阶段 4：多线程扩展（预计 5-10 天）

**目标**：消除全局锁瓶颈，使多线程分配吞吐随核心数扩展。
当前进展：Task 4.1 与热路径锁争用修复/吞吐复测任务已完成并归档到 `docs/todo_malloc_perf_completed.md`；本文件保留阶段 4 剩余的性能收益报告任务。

---

## 优化任务优先级总览

| 阶段 | 任务 | 优先级 | 难度 | 预期收益 |
|------|------|--------|------|----------|
| 1.1 | 位运算替代除法 | P0 | 极低 | 热路径常数加速 10-50x |
| 1.2 | owns_ptr 命中缓存 | P0 | 低 | free 延迟从 O(n)→O(1) |
| 1.3 | MIN_CHUNK_SIZE=32 | P1 | 极低 | 小对象内存利用率 +50% |
| 2.1 | 相邻块合并 | P0 | 中 | 根治碎片化，解决假性 OOM |
| 2.2 | realloc 原地扩展 | P1 | 低 | 避免不必要拷贝 |
| 3.1 | 大小分箱 | P1 | 中 | 分配延迟从 O(n)→O(1) |
| 3.2 | 大块 mmap 快速路径 | P1 | 低 | 大块分配不污染自由链表 |
| 4.1 | per-thread cache | P2 | 高 | 多线程吞吐线性扩展 |

---

## 测试策略

### 回归测试（每次改动后必须运行）

### 新增基准测试

阶段 1-3 完成后需要新增：

- [ ] 吞吐基准：单线程 10000 次 malloc/free 的耗时
- [ ] `realloc` 扩展基准：vector 扩容模式的耗时

---

## 风险与注意事项

| 风险 | 影响 | 应对 |
|------|------|------|
| footer 引入增加内存开销（每块 +8B） | 小块内存利用率下降 | 仅阶段 2+ 需要 footer；可用位图替代 footer 来减少开销 |
| coalescing 引入后 bug 难以定位 | 内存损坏 | 每个阶段完成后运行全量测试 + valgrind |
| 分箱实现错误可能导致 bin 链表损坏 | 分配异常 | 逐步实现，先 4 bin 再扩展到 8 bin |
| per-thread cache 需要 threadlocal 支持 | 编译器可能不支持 | 检查 Uya 是否支持 `threadlocal` 关键字，否则用 pthread_getspecific |

---

## 参考资料

- [dlmalloc (Doug Lea's malloc)](http://gee.cs.oswego.edu/dl/html/malloc.html) — boundary-tag coalescing 经典参考
- [jemalloc](https://jemalloc.net/) — per-thread cache + size class 设计
- [TCMalloc](https://github.com/google/tcmalloc) — Google 的 per-thread caching allocator
- 现有设计文档: `docs/libc_malloc_design.md`

---

**最后更新**: 2026-06-25
**维护者**: Uya 开发团队
