# macOS 平台移植分析与实施边界

> **状态（2026-10-19 核对，v0.10.4）**：本文记录的阻塞点（`make uya-hosted` 报
> 「'/.../src/main.uya' 既不是文件也不是目录」）**已解决**。当前 macOS 支持面：
> `make from-c-native` 冷启动、`backup/uya-hosted-macos{.c,-arm64.c,-x86_64.c}` 种子家族、
> `.github/workflows/macos-ci.yml`、C99 `@syscall` 的 Darwin 分支与 libc host bridge、
> `lib/std/async_event.uya` 的 kqueue 后端（失败回退 `poll`）、`make microapp-macos-runtime-check`。
> 本文作为当时的问题分析保留；剩余项（macOS 上 async/pthread 用例默认跳过、真机全量闭环）
> 见 `docs/todo_status_index.md` 与 `docs/todo_multiplatform_migration.md`。

## 背景

当前项目已经在 macOS 上完成了第一阶段验证：

- 可以使用 `backup/uya-hosted-macos.c` 在 macOS 本机通过 `make from-c-native` 生成 `bin/uya`
- 生成的 `bin/uya` 可以在 macOS 上启动
- 当前阻塞点不再是构建脚本，而是源码本体在 macOS 上的文件系统/路径判型

已知失败现象：

- `make uya-hosted` 时，编译器报错：
  - `错误: '/.../src/main.uya' 既不是文件也不是目录`

这说明：

- `Makefile` 与 `compile.sh` 已基本具备 macOS 主线能力
- 当前主问题已经进入源码深水区，重点应转向：
  - Darwin host bridge
  - `stat/fstat/lstat`
  - `readdir/dirent`
  - 统一 `Stat` 抽象与 Darwin 原生 ABI 的映射

---

## 当前平台边界

### Linux

当前 Linux 仍然是项目的已验证主线：

- `nostdlib` 路线完整
- syscall/runtime/codegen/验证路径以 Linux 为主
- 内部统一 `Stat` 抽象本身按 Linux 风格设计

### macOS

当前 macOS 已具备的能力：

- 宿主平台识别
- hosted 构建链
- 本机 seed 冷启动（`from-c-native`）
- Darwin 编译器路径获取（`_NSGetExecutablePath + realpath`）
- Darwin `opendir/readdir/closedir` host bridge
- C99 codegen 中的 Darwin 平台枚举

当前 macOS 的明确边界：

- 主线应走 **hosted**
- 不应走 Linux `nostdlib` 路线
- 文件系统/路径判型虽然上层逻辑共享，但底层依赖 Darwin host bridge 正确性

---

## 当前最强怀疑点

当前最强怀疑点已经收敛到：

- `stat -> sys_stat -> uya_macos_stat -> uya_macos_copy_stat -> unified Stat.st_mode`

### 关键事实

1. `src/main.uya` 中的 `is_directory` / `is_file` 逻辑本身很简单：
   - 依赖 `stat()` 成功
   - 依赖 `st_mode`
   - 依赖 `S_IFMT/S_IFDIR/S_IFREG`

2. 项目内部统一 `Stat` 明确是 Linux 风格抽象：
   - 位于 `lib/libc/syscall.uya`
   - 注释明确说明与 Linux x86_64 stat 布局一致

3. macOS 下并不直接走 Linux syscall，而是走：
   - `uya_macos_stat`
   - `uya_macos_fstat`
   - `uya_macos_lstat`

4. 当前 Darwin bridge 使用的是：
   - 手写 `uya_macos_native_stat`
   - 手写 `uya_macos_copy_stat`

这意味着：

> 当前最大风险并不是上层逻辑，而是 Darwin native `struct stat` 到统一 `Stat` 的 ABI/字段映射。

---

## 已知差异点

### 1. 宿主路径获取

- Linux：`/proc/self/exe`
- macOS：`_NSGetExecutablePath + realpath`

结论：
- 这层已明确分平台，不是当前主要问题点。

### 2. 目录读取

- Linux：`getdents64`
- macOS：`uya_macos_host_opendir/readdir_fill/closedir`

结论：
- 目录读取已经平台化
- 后续可能仍有 `dirent` / `d_type` / `d_name` 风险
- 但不是当前第一阻塞点

### 3. 文件状态获取

- Linux：syscall 路线天然匹配统一 `Stat`
- macOS：需通过 Darwin native bridge 转换到统一 `Stat`

结论：
- 这是当前第一优先级差异点

### 4. 统一 `Stat`

- 项目内部统一 `Stat` 是 Linux 风格抽象，不是 Darwin 原生布局
- 这本身不是错误
- 但要求 Darwin bridge 必须正确完成 native -> unified 的映射

---

## 关于 `S_IFMT / S_IFDIR / S_IFREG`

当前分析结果：

- 尚未发现明确证据表明这组常量在 Darwin 与 Linux 之间存在当前问题所需级别的差异
- `lib/libc/stdio.uya` 中 `remove()` 使用的局部常量值：
  - `_S_IFMT = 0170000`
  - `_S_IFDIR = 0040000`
- 这组值符合 Unix/POSIX 常见约定

当前结论：

> 目前更像是 `st_mode` 值来源层有问题，而不是常量解释层有问题。

---

## 推荐方案：Darwin `stat` bridge 改为直接使用系统原生 `struct stat`

### 当前方案（高风险）

当前 Darwin bridge 采用：

- 手写 `uya_macos_native_stat`
- 假设其 ABI 与 Darwin 原生 `struct stat` 一致
- 再将其复制到统一 `Stat`

风险：

- 字段宽度错误
- 字段顺序错误
- padding / 对齐错误
- x86_64 与 arm64 ABI 假设不一致
- SDK/系统版本差异风险

### 推荐方案（方案 2）

改为：

- 在 C host bridge 中直接使用系统原生 `struct stat`
- 调用原生 `fstat` / `fstatat`
- 再逐字段复制到统一 `Stat`

即：

- 保留统一 `Stat`
- 只替换 Darwin native bridge 的实现方式

这样可以避免：

- 自己手写 mirror Darwin ABI
- 因 mirror 结构失真导致 `st_mode` / `st_dev` / `st_ino` 错位

---

## 方案 2 的最小实施边界

### 必须修改的层

1. `uya_macos_stat`
2. `uya_macos_fstat`
3. `uya_macos_lstat`
4. `uya_macos_copy_stat`
5. 生成这些 bridge 的 codegen 模板

### 应废弃/退出主链的内容

1. `uya_macos_native_stat`
2. 依赖 `uya_macos_native_stat` 的 `fstat/fstatat` native ABI mirror 声明

### 当前不要修改的层

1. `src/main.uya` 的 `is_file` / `is_directory`
2. `src/main.uya` 输入解析主流程
3. 统一 `Stat`
4. Linux `sys_stat/sys_fstat/sys_lstat`
5. Linux 主线与 `nostdlib` 路径
6. `S_IF*` 解释逻辑

---

## 防止滑向“广泛平台化重构”的边界

当前问题应限制在：

- Darwin native 文件状态 bridge
- Darwin native ABI 到 unified `Stat` 的字段映射

### 目前不应做的事情

1. 不应在 `src/main.uya` 主流程中大量引入 macOS / Linux 分支
2. 不应修改统一 `Stat` 为平台相关结构
3. 不应因为 `stat` 问题而先改模块系统、依赖收集系统
4. 不应把 `osal` 重构成大规模平台抽象层
5. 不应把 Linux 主线拉入此次修复

### 一旦出现这些征兆，说明已经超出当前问题边界

- 开始频繁修改 `src/main.uya` 主流程
- 开始拆分内部统一结构为 Darwin/Linux 两套
- 开始系统性改 `runtime/syscall/codegen` 主体
- 开始同时处理 `async/pthread/process/net` 平台差异

---

## 推荐实施顺序

### 第 1 步
只改 Darwin `stat/fstat/lstat` bridge 的 native 侧实现方式。

### 第 2 步
重新生成 macOS seed：

- `backup/uya-hosted-macos.c`
- `backup/uya-hosted-macos-x86_64.c`
- `backup/uya-hosted-macos-arm64.c`

### 第 3 步
验证：

- `make from-c-native`

确保冷启动链没有被破坏。

### 第 4 步
验证：

- `make uya-hosted`

关注当前已知阻塞点是否消失：

- `src/main.uya` 不再把真实存在的路径判成“既不是文件也不是目录”

### 第 5 步
如果越过当前卡点，再继续检查第二梯队问题：

- `paths_equal`
- `st_dev/st_ino`
- `readdir/dirent`
- regular-file 判定
- 模块依赖收集

---

## 最终结论

本轮分析的最终收敛是：

1. 当前问题的主战场已经不在 `Makefile` / `compile.sh`
2. 当前问题不应上升为广泛平台化重构
3. 当前最小正确修复边界是：
   - **只修 Darwin `stat` bridge**
4. 推荐方向是：
   - **直接使用系统原生 `struct stat`，再映射到统一 `Stat`**
5. 只有在这一步修完后，若仍有问题，才进入目录桥接和第二梯队问题分析
