# Uya 语言 libc 内存分配器实现说明

## 概述

本文档记录了 Uya 语言 libc 内存分配器的 musl 风格实现方案。

## 当前实现（与 `lib/libc/heap.uya` 同步，截至 2026-06-25）- 小块 bins + large mmap 直连

### 核心特性

**数据结构：**
```uya
// 内存块头部（16 字节）
struct ChunkHeader {
    magic: u64,    // 魔数 0xDEADBEEF
    size: usize,   // 块大小，低 1 位=空闲标志
}

// 边界标记 footer（8 字节，镜像 header.size）
struct ChunkFooter {
    size: usize,
}

// 空闲块前缀（32 字节，第一个字段必须是 header）
struct FreeChunk {
    header: ChunkHeader,  // 偏移 0-15
    prev: &FreeChunk,     // 偏移 16
    next: &FreeChunk,     // 偏移 24
}
```

当前实现已经引入 footer。`hdr.size` 记录整个 chunk 的总字节数，覆盖 `ChunkHeader + 用户可写区域/空闲链表覆盖区 + ChunkFooter`，并继续使用最低位标记 free 状态。`chunk_overhead()` 固定为 `16B header + 8B footer = 24B`，`chunk_total_for_payload()` 对 `payload + 24B` 再做 16 字节对齐，因此当前最小 chunk 总大小是 `heap_align_up(32 + 24) = 64B`。这意味着最小分配块虽然请求/归一化 payload 为 32B，但实际可写空间为 `64 - 24 = 40B`；空闲时其中前 16B 被 `prev/next` 链表指针复用。

**malloc:**
- 使用 8 个按 payload size class 分箱的空闲链表管理已释放的内存块
- 从目标 bin 起跳，按 bin 从小到大执行首次适配
- 块分割：大块使用时分割剩余部分回到空闲链表
- 小于 4096B 的请求在没有合适块时使用 mmap 扩展普通堆 region
- 大于等于 4096B 的请求直接走独立 mmap 映射，不进入普通 bins

**free:**
- 先写入当前块 footer
- 通过 footer 边界标记向前/向后查找相邻 chunk
- 合并相邻空闲块后再加入空闲链表头部
- large 直连映射不写 footer，不参与 split/coalesce，直接从 large-region 表中删除并 munmap

**calloc:**
- 调用 malloc 分配内存
- 使用 memset 清零

**realloc:**
- 原地优化：新大小≤旧大小时直接返回
- 否则分配新内存 → 复制旧数据 → 释放旧内存
- 若旧指针来自 large 直连映射，则按新大小重新走 malloc 路径，复制 `min(old_user_size, new_size)` 后释放旧映射

### 关键技术

#### 1. 使用 `as` 进行类型转换

```uya
// 从 mmap 返回的指针转换为 ChunkHeader
var hdr: &ChunkHeader = (ptr as &ChunkHeader);

// 同一指针转换为 FreeChunk（因为 header 是第一个字段）
var chunk: &FreeChunk = (ptr as &FreeChunk);

// 从 ChunkHeader 转换为 FreeChunk
var hdr: &ChunkHeader = ...;
var chunk: &FreeChunk = (hdr as &FreeChunk);
```

#### 2. 使用 `((ptr as &byte) as usize) == 0` 检查 null

```uya
fn is_null(ptr: &void) bool {
    return (((ptr as &byte) as usize) == 0);
}

// 使用示例
if is_null(chunk as &void) { return null; }
if !is_null(chunk.prev as &void) { ... }
```

#### 3. 当前低位标记与 footer 实现

```uya
const CHUNK_FLAG_FREE: usize = 1;

fn is_free(hdr: &ChunkHeader) bool {
    return (hdr.size & CHUNK_FLAG_FREE) != 0;
}

fn get_size(hdr: &ChunkHeader) usize {
    return hdr.size - (hdr.size & CHUNK_FLAG_FREE);
}

fn chunk_overhead() usize {
    return @size_of(ChunkHeader) + @size_of(ChunkFooter);
}

fn to_footer(hdr: &ChunkHeader) &ChunkFooter {
    const sz: usize = get_size(hdr);
    return (((hdr as &byte) + sz - @size_of(ChunkFooter)) as &ChunkFooter);
}
```

### 内存布局

```
分配态 chunk（总大小 = header + payload + footer，再按 16B 对齐）：
[0          16                             sz-8      sz]
+-----------+------------------------------+----------+
| Header16B | user payload / free overlay  | Footer8B |
+-----------+------------------------------+----------+

空闲态 chunk（`FreeChunk` 只覆盖 chunk 起始的 32B 前缀）：
[0          16        24      32                   sz-8      sz]
+-----------+---------+-------+--------------------+----------+
| Header16B | prev8B  | next8B| remaining payload  | Footer8B |
+-----------+---------+-------+--------------------+----------+

`ChunkFooter.size` 镜像保存 `hdr.size`，因此 `prev_chunk_in_region()` 可以先读取前一个 chunk 的 footer，再常数时间回退到前一个 header。

`FreeChunk` 与 `ChunkHeader` 仍然共用同一起始地址，因此可以安全转换 `(chunk as &ChunkHeader)` 和 `(hdr as &FreeChunk)`。

```

large 直连映射（独立元数据 + header-only chunk，无 footer）：
[0                meta_size          meta_size+16         map_size]
+-----------------+------------------+--------------------+
| LargeRegion     | ChunkHeader 16B  | user payload       |
+-----------------+------------------+--------------------+

large path 只保留 `ChunkHeader` 作为 `to_header/to_user_ptr` 兼容层与 magic 哨兵；真实映射长度、
用户请求大小、munmap 长度都存放在 `LargeRegion` 元数据中。
```

### malloc 流程

```
1. 对齐大小到 16 字节
2. 若对齐后的 payload 大小 ≥ 4096B：
   - 直接 mmap 独立映射
   - 在映射头部写入 `LargeRegion` 元数据
   - 返回 header 之后的用户指针
3. 否则计算目标 size class，从对应 bin 起跳查找空闲链表（首次适配）
4. 如果没有合适块：
   - 调用 mmap 扩展普通堆 region
   - 添加到空闲链表
   - 重新查找
5. 从空闲链表移除
6. 清除空闲标志并写入 footer
7. 分割块（如果剩余空间达到最小 chunk 总大小）
8. 返回用户指针
```

### free 流程

```
1. 空指针检查
2. owns_ptr(ptr) 所属 region 校验
3. 获取块头部
4. 验证魔数
5. 写入当前块 footer 并执行相邻空闲块合并
6. 转换为合并后的 FreeChunk
7. 添加到空闲链表头部
```

## 改进建议

### 短期
1. ✅ **空闲链表管理**：已实现
2. ✅ **块分割**：已实现
3. ✅ **boundary tag footer + 块合并**：已实现

### 长期
1. **最佳适配算法**：在 bin 内进一步减少碎片和扫描成本
2. **per-thread cache**：降低多线程场景的全局锁竞争

## 测试验证

```bash
./bin/uya test tests/test_std_stdlib_malloc.uya
./bin/uya test tests/test_libc_heap_bins.uya
./bin/uya test tests/test_libc_heap_large_path.uya
```

## 参考资料

- [musl libc malloc 实现](https://git.musl-libc.org/cgit/musl/tree/src/malloc/mallocng)
- [dlmalloc (Doug Lea's malloc)](http://gee.cs.oswego.edu/dl/html/malloc.html)
