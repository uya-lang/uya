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
