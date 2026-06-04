# C99 热路径 Benchmark 记录

**更新日期**：2026-03-23（默认 `-O2` 链 `bin/uya`、`get_c_name` 标识符缓存、声明缓存 4096、prelude 分段子计时）

> 2026-06-04 说明：本文保留 2026-03 的历史热路径记录。当前 1 秒目标、可信 benchmark 口径和 20s 级复核数据见 [`compiler_1s_speed_assessment.md`](compiler_1s_speed_assessment.md)。现在 `make bench-compile-stats` 默认会先重建当前 `bin/uya`，并使用临时输出名避免覆盖正式编译器；只有显式 `--no-rebuild` / `UYA_BENCH_SKIP_REBUILD=1` 才复用已有二进制。

## 复现入口

- `make bench-compile-stats`
- `make bench-compile-stats ARGS="--runs 3"`

脚本位置：`scripts/bench_compile_stats.sh`

默认基准命令：

```bash
cd src && ./compile.sh --c99 -e -v --nostdlib
```

统计来源为编译器 stderr 中的 `=== 编译统计 ===` 段落，抓取以下字段：

- `文件数`
- `解析耗时`
- `合并耗时`
- `检查耗时`
- `优化耗时`
- `生成耗时`
- `总耗时`

## 复现环境（本轮）

| 项 | 值 |
|----|-----|
| 仓库 commit | `48c66b291469cb16b676213880f679b87e5bc2f5`（示例；以 `git rev-parse HEAD` 为准） |
| 内核 / 架构 | `Linux ... 6.12.65-amd64 ... x86_64 GNU/Linux`（主机名略） |
| 默认构建 | `CFLAGS ?= -std=c99 -O2 -g -fno-builtin -Werror`（见根目录 `Makefile`；调试可用 `CFLAGS='-std=c99 -O0 ...'` 覆盖） |

## 本轮实现（与「生成耗时」相关）

- **SIMD**：`emit_simd_x86_sse_runtime_helpers` 中取消 `simd_vector_struct_reg_count==0 → simd_emit_all=1` 全开；对「仅有 mask、且各 lane 族均为 0」场景由 `c99_simd_mask_only_ensure_lane_flags` 将 i32/u32/f32 族至少标为 4 lane，使 `c99_simd_need_emit_*` 按需发射。
- **标识符 C 名缓存**：`get_c_name_for_identifier_ref`（[`src/codegen/c99/global.uya`](../src/codegen/c99/global.uya)）对「全局表线性扫描 + `get_safe_c_identifier`」路径增加 4096 槽直接映射缓存，键与 `lookup_identifier_type_c_impl` 一致（含 async 相关字段）；在 `c99_identifier_type_cache_reset` 与 `c99_codegen_new` 中一并清空。
- **声明查找缓存**：`C99_DECL_CACHE_*` 由 1024 扩至 **4096**（[`src/codegen/c99/internal.uya`](../src/codegen/c99/internal.uya)），降低 `find_*_decl_c99` 哈希冲突后的全表扫描频率。
- **可选子计时**：设置环境变量 `UYA_PROFILE_CODEGEN` 为非空时，在 **stderr** 打印一行（`clock()`，与主程序「生成耗时」同语义）：  
  `[UYA_PROFILE_CODEGEN] simd_ms=... precollect_ms=... header_ms=... step1_typedef_ms=... step6_mid_ms=... step6e_tail_ms=... prelude_ms=... body_ms=... total_ms=...`  
  - `precollect_ms`：`precollect_codegen_decl` 遍历顶层声明。  
  - `header_ms`：precollect 结束到「第一步」字符串常量前的头文件 / 平台宏 / 内置类型等输出。  
  - `step1_typedef_ms`：第一步～第五步 b（字符串常量、错误注册、结构体表、前向声明、枚举、typedef）。  
  - `step6_mid_ms`：第六步切片/SIMD/接口/err_union/联合体/结构体定义及 syscall 助手等，至第六步 e 之前。  
  - `step6e_tail_ms`：第六步 e / e2 的错误联合收集与补输出等，至第七步前。  
  - `prelude_ms`：进入 `c99_codegen_generate` 至第七步前（上列子段之和应接近 `prelude_ms`，受 `clock()` 粒度影响可能差 1ms）。  
  - `body_ms` = `total_ms - prelude_ms`（前向声明、函数体、测试、`emit_pending_string_constants` 等）。
- **自举编译器（`src/` → `uya.c`）**：编译器实现**不使用** `@vector` / SIMD 结构体（源码中无相关类型），因此自举时 **`simd_struct_count` 为 0**，**`simd_ms=0` 是预期**，并非 SIMD 优化未生效。`make bench-compile-stats` 的 codegen 瓶颈在 **`body_ms`**（函数体等生成），与 SIMD 辅助块无关；SIMD 按需发射类优化**主要作用于**含 SIMD 的用户程序与测试，**不**指望拉高自举 bench 的 codegen 数字。
- **libc stdio**：`FILE` 内置缓冲由 **4KiB 扩至 64KiB**，减少大块 C 写出时的 `write` 次数；`fflush` 实际调用 `flush_buffer`；`fclose` 在关闭 fd 前刷新缓冲。**未**合并 `fopen` 槽位重置（在自举对比中曾导致生成 C 损坏，已回退）。**未**在 `main` 中调用 `setvbuf`、**未**为 `FILE` 增加独立 1MiB 用户缓冲（曾触发自举不稳定）。

## 对比基线（历史）

本轮热路径收束前的基线样本：

| 阶段 | 基线（ms） |
|------|-----------:|
| parse | 927 |
| check | 2589 |
| codegen | 13766 |
| total | 17476 |

## 当前结果（默认 `-O2` 构建的 `bin/uya`）

**测试硬件**（与下表同次测量，2026-03-23）：Intel Core **i7-14700**（Raptor Lake，1 插槽，**20C / 28T**，x86_64）；系统内存约 **32 GiB**（`free` 报告总计 31Gi）；单 NUMA。未记录固定电源策略与后台负载，**数值会随睿频、温度与其它进程占用波动**。

历史三次平均（`make bench-compile-stats ARGS="--runs 3"`，2026-03-23，**64KiB FILE 缓冲**、当时 `bin/uya` 默认 `-O0`）：

| 阶段 | 当前平均（ms） |
|------|---------------:|
| parse | 525 |
| check | 646 |
| codegen | 3359 |
| total | 4682 |

本轮（默认 `-O2` + 标识符缓存 + 声明缓存 4096）单次示例（`UYA_PROFILE_CODEGEN=1`，`src/main.uya` → 临时 `.c`）：`codegen`（生成耗时）约 **1.7～1.8s** 量级，仍高于 1s KPI，但较旧基线明显下降；请以本机 `make bench-compile-stats` 为准。

**说明**：`codegen` 列对应 stderr「生成耗时」，为 `clock()` 计量的 CPU 时间量级，不是纯磁盘 I/O wall time。

## 可选：`-O0` 编译 `bin/uya`（调试）

```bash
CFLAGS='-std=c99 -O0 -g -fno-builtin -Werror' make from-c
```

## WriteBuf（应用层大块缓冲）

全量用堆缓冲替代 `FILE*` 写出需改动 codegen 内 **两千余处** `fputs`/`fprintf`/`fputc` 调用，维护成本高；历史尝试在 `main` 对输出流 `setvbuf` 超大用户缓冲曾触发自举不稳定，故**未**在本轮实现统一 WriteBuf。当前依赖 **64KiB `FILE` 内置缓冲** + 上述算法侧缓存与 **`-O2`**。

## 结论与 KPI

- 默认 **`-O2`** 与标识符/声明缓存后，**codegen 可降至约 1.7～2.0s**（视机器与负载），**仍可能高于**「同一基准下 codegen &lt; 1000ms」的激进 KPI。
- **bench 自举路径**上 SIMD 块常为 0ms；主要耗时在 **`body_ms`**（前向声明与函数体等）及 **`precollect_ms`**（可据 `UYA_PROFILE_CODEGEN` 分段定位）。
- `UYA_PROFILE_CODEGEN` 可区分 **prelude 子段**、**body** 与 **simd**，便于继续优化。
