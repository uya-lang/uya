# libc malloc/free 性能优化 TODO

**创建日期**: 2026-06-18
**优先级**: P1（性能基础设施）
**当前状态**: 阶段 1 已完成，阶段 2 进行中
**关联文档**: `docs/libc_malloc_design.md`
**基线说明**: 当前实现以 `lib/libc/heap.uya` 为准：`ChunkHeader` 为 16B，`FreeChunk` 为 32B，尚未引入 footer；阶段 2 引入 footer 时必须同步更新设计文档中的布局和开销说明。

---

## 可勾选执行清单

完成某项后把对应 `- [ ]` 改为 `- [x]`。阶段级 checkbox 只有在该阶段所有任务、测试和性能记录都完成后再勾选。

- [ ] 阶段 2：碎片化根治
  - [ ] 阶段 2 回归测试和新增确定性测试全部通过
  - [ ] 阶段 2 性能收益报告补充实测数据
- [ ] 阶段 3：分配速度优化
  - [ ] Task 3.1：实现 size-segregated free lists
  - [ ] Task 3.2：大块分配走 mmap/munmap 快速路径
  - [ ] 阶段 3 回归测试、bin 覆盖测试和 large-path 测试全部通过
  - [ ] 阶段 3 性能收益报告补充实测数据
- [ ] 阶段 4：多线程扩展
  - [ ] Task 4.1：per-thread allocation cache
  - [ ] 单线程无退化和多线程吞吐目标验证完成
  - [ ] 阶段 4 性能收益报告补充实测数据
- [ ] 收口验证
  - [ ] `make check` 通过
  - [ ] 本文档的任务状态、测试结果和最后更新日期已同步
  - [ ] 需要提交时按仓库规则运行 `make clean && make backup-all`

---

## 概述

本文档基于对 `lib/libc/heap.uya` 完整实现的性能审计，列出了当前 malloc/free/realloc 实现的性能瓶颈与优化任务。当前实现采用 **mmap + 双向自由链表 first-fit + 全局自旋锁** 策略，在单线程场景下可正常工作，但在多线程、长时间运行、或大量小对象场景下存在显著性能问题。

### 当前实现概要

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

本节记录的是基于当前实现结构的**预期收益报告**，不是已完成优化后的实测结论。每个阶段落地后都必须用下文的基准口径补充真实数据，避免只依赖理论复杂度判断。

### 基线瓶颈

当前 allocator 的主要成本来自以下路径：

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


## 阶段 2：碎片化根治（预计 3-5 天）

**目标**：实现空闲块合并和 realloc 原地扩展，解决根本性的内存碎片化问题。

---

### Task 2.1: 实现 free 时相邻块合并 (coalescing)

- **优先级**: P0（最关键缺陷）
- **预计时间**: 2-3 天
- **文件**: `lib/libc/heap.uya`
- **当前问题**: `_free_impl` 仅将 chunk 插入自由链表头部（`add_free`），完全不检查物理相邻 chunk 是否空闲。长期运行导致自由链表中积累大量不相邻的小碎片，即使总空闲内存足够也无法满足大分配请求。
- **方案**: 实现双向 boundary-tag coalescing。

**核心思路**：利用 chunk header 中的 `size` 字段，可以从当前 chunk 找到下一个物理相邻 chunk（`hdr + hdr.size`）。需要同时能从当前 chunk 找到前一个 chunk，所以使用"footer"机制——每个 chunk 尾部额外存储一个 size 副本，使得可以从当前 chunk 地址向前查找前一个 chunk。

**数据结构调整**：
```uya
// 每个 chunk 的尾部添加 footer（仅存储 size，不包含 magic）
// 布局：[header(16B)] [user/free payload...] [footer(8B)]
// header.size 记录整个 chunk 的字节数：header + payload + footer，并包含 LSB free 标记。
// malloc(size) 返回的用户可写空间仍必须 >= size；footer 开销由 allocator 额外计入 chunk 总大小。
// footer 用于向前查找相邻 chunk

struct ChunkFooter {
    size: usize,  // 与 header.size 相同（含 LSB 标记）
}
```

**实现步骤**：

- [ ] **添加 footer 辅助函数**：
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

- [ ] **修改 morecore**：创建 chunk 时把 `alloc_size` 设为 `max(chunk_total_for_payload(aligned_payload), HEAP_PAGE_SIZE)`，保持小分配至少映射 4KB region 以复用后续 split/coalesce，并对整个 region chunk 写入 footer。`region.size` 仍记录该 region 内 chunk 区域总字节数。注意 `CHUNK_OVERHEAD = 24B` 时，`aligned_payload + CHUNK_OVERHEAD` 会得到 `8 mod 16` 的 chunk 总长，破坏后续 header 和用户指针的 16 字节对齐；必须对最终 chunk 总长再次执行 `heap_align_up`。

- [ ] **修改 find_chunk**：使用 footer 后，判断空闲块是否足够时必须比较 `chunk_total_for_payload(needed_payload)`，不能继续使用 `needed_payload + @size_of(ChunkHeader)`。否则 first-fit 可能选中一个容得下旧 header 开销、但容不下 footer 后总开销的块。
   ```uya
   fn find_chunk(needed_payload: usize) &FreeChunk {
       const needed_total: usize = chunk_total_for_payload(needed_payload);
       var cur: &FreeChunk = free_list_head;
       while !is_null(cur as &void) {
           var sz: usize = get_size(&cur.header);
           if sz >= needed_total {
               return cur;
           }
           cur = cur.next;
       }
       return null;
   }
   ```

- [ ] **修改 split_chunk**：`alloc_total = chunk_total_for_payload(needed_payload)`；只有 `rem >= chunk_total_for_payload(MIN_CHUNK_SIZE)` 才分割。分割后已分配 chunk 与剩余 free chunk 都必须维护各自 footer。

- [ ] **重写 `_free_impl`**：释放时检查前后邻居并合并：
   ```uya
   fn _free_impl(ptr: &void) void {
       if is_null(ptr) { return; }
       if !owns_ptr(ptr) { return; }

       var hdr: &ChunkHeader = to_header(ptr);
       if hdr.magic != CHUNK_MAGIC { return; }
       var region: &HeapRegion = find_region_for_header(hdr);
       if is_null(region as &void) { return; }

       set_free(hdr, true);
       write_footer(hdr);

       // 尝试合并后一个 chunk
       var next: &ChunkHeader = next_chunk_in_region(region, hdr);
       if !is_null(next as &void) && next.magic == CHUNK_MAGIC && is_free(next) {
           // 合并：扩大当前 chunk，从自由链表移除 next
           remove_free(next as &FreeChunk);
           hdr.size = get_size(hdr) + get_size(next);
           set_free(hdr, true);
           write_footer(hdr);
       }

       // 尝试合并前一个 chunk
       var prev: &ChunkHeader = prev_chunk_in_region(region, hdr);
       if !is_null(prev as &void) && prev.magic == CHUNK_MAGIC && is_free(prev) {
           remove_free(prev as &FreeChunk);
           prev.size = get_size(prev) + get_size(hdr);
           set_free(prev, true);
           write_footer(prev);
           hdr = prev;  // 合并后 hdr 指向前一个
       }

       // 将合并后的 chunk 加入自由链表
       add_free(hdr as &FreeChunk);
   }
   ```

- **注意**: 引入 footer 后，`morecore` 分配的 chunk 和 `split_chunk` 产生的新 chunk 都需要正确写入 footer。footer 会增加 allocator 内部开销，但不能减少 `malloc(size)` 承诺给用户的可写字节数。所有 `get_size(hdr) - @size_of(ChunkHeader)` 的可用空间计算都要改为 `get_size(hdr) - CHUNK_OVERHEAD`。所有存入 `hdr.size` 的 chunk 总长必须保持 `MALLOC_ALIGN` 对齐，不能只对齐 payload。
- **验收标准**:
  - [ ] `./bin/uya test tests/test_std_stdlib_malloc.uya` 全部通过
  - [ ] `./tests/run_programs_parallel.sh tests/programs/test_heap.uya` 通过
  - [ ] 新增确定性测试：构造相邻 A/B chunk，并用 guard/fill chunk 避免页尾剩余块干扰；释放 B 再释放 A 后，申请 A+B 可容纳的大块必须返回 A 的原地址，证明发生相邻合并而不是从非相邻空闲块或新 mmap 获取
  - [ ] 新增确定性测试：分别覆盖向后合并、向前合并、同时合并前后两个空闲邻居，合并后再次分配/释放不破坏自由链表
  - [ ] 长时间运行稳定性（无内存泄漏、无碎片假性 OOM）

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
- **验收标准**:
  - [ ] `./bin/uya test tests/test_std_stdlib_malloc.uya` 全部通过
  - [ ] 新增确定性测试：分配 A/B/guard，写入 A 的哨兵数据，释放 B 后 `realloc(A, bigger)` 必须返回 A 的原地址并保留原数据，同时 guard 内容不变
  - [ ] 新增确定性测试：原地扩展吞并 next chunk 后，后续 malloc/free 仍能正确使用扩展后剩余拆分块，证明 next 已从自由链表移除

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

**实现要点**：

- [ ] **定义 bin 数组**：
   ```uya
   const NUM_BINS: usize = 8;
   // 每个 bin 是一个双向链表的头
   var bins: [&FreeChunk: NUM_BINS] = [];
   ```

- [ ] **统一 size class 转换函数**：
   ```uya
   fn normalize_payload_size(size: usize) usize {
       var aligned: usize = heap_align_up(size);
       if aligned < MIN_CHUNK_SIZE {
           return MIN_CHUNK_SIZE;
       }
       return aligned;
   }

   fn chunk_payload_capacity(hdr: &ChunkHeader) usize {
       // 阶段 2 后使用 CHUNK_OVERHEAD；若 Task 3.1 独立先做，
       // 则临时等价为 get_size(hdr) - @size_of(ChunkHeader)。
       return get_size(hdr) - CHUNK_OVERHEAD;
   }

   fn bin_index_for_payload(payload_size: usize) usize {
       const size: usize = normalize_payload_size(payload_size);
       if size < 64 { return 0; }
       if size < 128 { return 1; }
       if size < 256 { return 2; }
       if size < 512 { return 3; }
       if size < 1024 { return 4; }
       if size < 2048 { return 5; }
       if size < 4096 { return 6; }
       return 7;
   }

   fn bin_index_for_request(requested_payload: usize) usize {
       return bin_index_for_payload(requested_payload);
   }

   fn bin_index_for_chunk(hdr: &ChunkHeader) usize {
       return bin_index_for_payload(chunk_payload_capacity(hdr));
   }
   ```

- [ ] **修改 find_chunk**：`find_chunk(requested_payload)` 使用 `bin_index_for_request(requested_payload)` 起跳，bin 为空或当前 bin 无合适块时向更大 bin 逐级查找；比较容量时仍用 `chunk_total_for_payload(normalize_payload_size(requested_payload))` 验证真实 chunk total 足够，避免只按 payload class 命中但实际容不下 footer。

- [ ] **修改 add_free/remove_free**：用 `bin_index_for_chunk(&chunk.header)` 维护 bin 链表，不允许直接把 `get_size(hdr)` 传给 bin 函数。

- [ ] **修改 split_chunk**：分割前用 `normalize_payload_size(needed_payload)` 计算分配 payload，用 `chunk_total_for_payload` 计算真实 chunk total；剩余块写完 footer 后再用 `bin_index_for_chunk` 加回对应 bin。

- [ ] **大块快速路径不在本任务实现**：Task 3.1 只负责把仍由普通堆管理的 chunk 放入正确 bin；`>=4096` 的 chunk 在 Task 3.2 完成前继续走普通堆顶层 bin/现有 `morecore` 路径，不能在这里绕过 `owns_ptr()` 直接 mmap/munmap。

- **验收标准**:
  - [ ] `./bin/uya test tests/test_std_stdlib_malloc.uya` 全部通过
  - [ ] 新增基准测试：连续 10000 次随机大小分配/释放，对比优化前后耗时
  - [ ] 覆盖每个 bin 的分配/释放/跨 bin 查找：小 bin 为空时能向更大 bin 查找，split 后剩余 chunk 进入正确 bin
  - [ ] 在 Task 3.2 未完成时，`>=4096` 的普通堆 chunk 仍能正常 `free/realloc`，不会被错误地当作独立 mmap 块处理

---

### Task 3.2: 大块分配走 mmap/munmap 快速路径

- **优先级**: P1
- **预计时间**: 1 天（可独立于 Task 3.1；直接 mmap/munmap 行为只在本任务验收）
- **文件**: `lib/libc/heap.uya`
- **方案**: 请求大小 ≥ 4096 字节时，直接从 mmap 分配独立映射，free 时直接 munmap。不经过自由链表，不参与 split/coalesce。大块不能只写 `ChunkHeader` 后返回：现有 `free/realloc` 会先通过 `owns_ptr()` 验证，小块 `heap_regions` 不包含独立大块映射，因此必须维护独立的大块映射表或把大块安全登记到可验证的 region 表中。`_free_impl/_realloc_impl` 的入口顺序必须先查 large-region metadata，命中后直接走 large 路径；未命中才继续走普通 `owns_ptr()` 验证。
- **large 布局约束**: large path 刻意使用独立的 header-only 布局，不写 footer，也不使用 `CHUNK_OVERHEAD`、`chunk_total_for_payload`、`to_footer/write_footer`、`split_chunk` 或 `coalesce` helper。`ChunkHeader` 只作为 `to_user_ptr/to_header` 兼容层和 magic 校验哨兵；真实映射大小、用户 payload 大小、free/realloc/copy 长度都必须以 `LargeRegion` 元数据为准。
  ```uya
  struct LargeRegion {
      next: &LargeRegion,
      map_base: *void,
      map_size: usize,
      user_size: usize,
      hdr: &ChunkHeader,
  }

  var large_regions: &LargeRegion = null;

  fn _malloc_impl(size: usize) &void {
      // ... 已有的 size==0 检查、对齐 ...

      // 大块快速路径
      if aligned >= HEAP_PAGE_SIZE {
          return _malloc_large(aligned);
      }

      // 小块走正常流程
      // ...
  }

  fn _malloc_large(size: usize) &void {
      // mmap 独立映射；映射头部保存 LargeRegion，后面才是 header-only ChunkHeader。
      const meta_size: usize = heap_align_up(@size_of(LargeRegion));
      const total: usize = meta_size + size + @size_of(ChunkHeader);
      const result: !*void = sys_mmap(null as *void, total, ...);
      const mapped: *void = result catch { return null; };
      if mapped == null { return null; }

      var region: &LargeRegion = mapped as &LargeRegion;
      var hdr: &ChunkHeader = ((mapped as &byte) + meta_size) as &ChunkHeader;
      hdr.magic = CHUNK_MAGIC;
      hdr.size = size + @size_of(ChunkHeader);
      set_free(hdr, false);
      region.map_base = mapped;
      region.map_size = total;
      region.user_size = size;
      region.hdr = hdr;
      region.next = large_regions;
      large_regions = region;
      return to_user_ptr(hdr);
  }

  fn find_large_region(ptr: &void) &LargeRegion {
      var region: &LargeRegion = large_regions;
      while !is_null(region as &void) {
          if to_user_ptr(region.hdr) == ptr {
              return region;
          }
          region = region.next;
      }
      return null;
  }

  // _free_impl/_realloc_impl 入口先查 find_large_region(ptr)；
  // 命中后从 large_regions 链表移除，再 munmap(region.map_base, region.map_size)。
  // realloc 复制长度使用 min(region.user_size, new_size)，不能读取 footer 或
  // 用 get_size(hdr) - CHUNK_OVERHEAD 推导 large payload。
  ```
- **验收标准**:
  - [ ] 新增最小 debug/test 观测能力（例如 large region 数量、普通自由链表/bin 计数，或 mmap/munmap 计数），large-path 验收不能只依赖现有 malloc 测试是否通过
  - [ ] 分配/释放 1MB 块不污染自由链表，不触发无意义的 split/coalesce
  - [ ] large 指针的 `free` 会实际 `munmap`，不会被 `owns_ptr()` 提前过滤
  - [ ] large 指针的 `realloc` 支持复制到新块并释放旧映射
  - [ ] 新增确定性测试：large malloc 后 large-region 计数增加，free 后计数减少且普通自由链表/bin 状态不变
  - [ ] 新增确定性测试：large realloc 到更大块会保留旧内容前缀、登记新映射、释放旧映射；large realloc 到小块时行为与设计一致并有明确断言

---

## 阶段 4：多线程扩展（预计 5-10 天）

**目标**：消除全局锁瓶颈，使多线程分配吞吐随核心数扩展。

---

### Task 4.1: per-thread allocation cache（线程本地缓存）

- **优先级**: P2（仅多线程场景受益）
- **预计时间**: 5-10 天
- **文件**: `lib/libc/heap.uya`
- **当前问题**: 全局自旋锁使所有线程的 malloc/free 完全串行化。多核下总吞吐难以超过单线程吞吐。
- **方案**: 参考 tcmalloc/jemalloc 的 per-thread cache 模式：

- [ ] **Thread Cache**: 每个线程持有小对象的本地自由链表缓存（无锁访问）。
- [ ] **Central Cache**: 全局共享的中间缓存，thread cache 从 central cache 批量获取/归还。
- [ ] **Page Heap**: 直接与 mmap 交互的底层。

简化实现：仅实现两层：
- [ ] **Per-thread cache**: 线程本地的小块缓存（按 size class），使用 `threadlocal` 存储。malloc 命中缓存时无锁；未命中时加全局锁从 central 批量获取。
- [ ] **Central (现有的 heap 逻辑)**: 全局锁保护，但只在批量转移时加锁，而不是每次分配都加锁。

```uya
// 线程本地缓存简化设计
const TCACHE_MAX_SIZE: usize = 2048;   // 超过此大小走全局路径
const TCACHE_BATCH: usize = 8;         // 批量获取/归还数量
const NUM_TCACHE_BINS: usize = 7;      // 32, 64, 128, 256, 512, 1024, 2048

struct TCacheBin {
    head: &FreeChunk,
    count: usize,
}

// 使用 threadlocal 存储（如果 Uya 支持）
// 否则通过 pthread_getspecific 实现
var tcache_bins: [TCacheBin: NUM_TCACHE_BINS] = [];  // per-thread
```

- **验收标准**:
  - [ ] 单线程性能无退化
  - [ ] 4 线程并发分配吞吐 > 单线程的 2.5x
  - [ ] 所有现有测试通过

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

- [ ] 快速单元测试：`./bin/uya test tests/test_std_stdlib_malloc.uya`
- [ ] 多文件集成测试：`./tests/run_programs_parallel.sh tests/programs/test_heap.uya`
- [ ] malloc 程序回归：`./tests/run_programs_parallel.sh malloc_test.uya`
- [ ] 阶段完成后全量验证：`make check`

### 新增基准测试

阶段 1-3 完成后需要新增：

- [ ] 碎片化压力测试：交替分配/释放不同大小，验证不出现假性 OOM
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

**最后更新**: 2026-06-24
**维护者**: Uya 开发团队
