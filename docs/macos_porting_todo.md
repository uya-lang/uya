# macOS 平台移植 TODO 清单（按优先级顺序）

> **实现状态（2026-10-19 核对）**：本清单的复选框**未回填**，但下列能力已落地——
> `make from-c-native` 冷启动、`backup/uya-hosted-macos.c` / `-arm64.c` / `-x86_64.c` 种子家族、
> `.github/workflows/macos-ci.yml`、C99 `@syscall` 的 Darwin 分支与 libc bridge、
> `lib/std/async_event.uya` 的 kqueue 后端（失败回退 `poll`）、`make microapp-macos-runtime-check`。
> 与本清单原设想不同的是：`stat/fstat/lstat` bridge 仍走 `uya_macos_native_stat_call` mirror
> （`src/codegen/c99/main.uya:2945-3136`），并未改成直接使用系统 `struct stat`。
> 引用本文件时请以代码与 `docs/todo_status_index.md` 为准，不要按未勾复选框判断进度。

> 本清单严格按当前已确认的实施边界生成。
> 目标是：
> - 优先修复 macOS `stat` bridge
> - 不扩散到主逻辑
> - 不碰 Linux 已验证主线
> - 每一步都有明确验证目标

---

## P0：当前阻塞点修复（必须先完成）

### [ ] 1. 定位并修改 Darwin `stat` bridge 的生成源头
- 目标文件：`src/codegen/c99/main.uya`（及相关 bridge 生成片段）
- 目标：找到当前生成以下代码的模板来源：
  - `uya_macos_stat`
  - `uya_macos_fstat`
  - `uya_macos_lstat`
  - `uya_macos_copy_stat`
  - `uya_macos_native_stat`
- 结果要求：确认真正修改点，不直接长期依赖手工改 seed

### [ ] 2. 将 Darwin `stat/fstat/lstat` bridge 改为直接使用系统原生 `struct stat`
- 目标：
  - 不再手写 mirror `uya_macos_native_stat` 作为 native ABI 载体
  - 改为在 bridge 中直接使用 Darwin 原生 `struct stat`
  - 再逐字段复制到统一 `Stat`
- 约束：
  - 保留统一 `Stat`
  - 不改 Linux 路线
  - 不改上层 `is_file/is_directory`

### [ ] 3. 重写 `uya_macos_copy_stat` 的输入侧
- 目标：
  - 从 `const struct uya_macos_native_stat *src`
  - 改为 `const struct stat *src`
- 要求：
  - 保持输出侧仍是统一 `Stat`
  - 明确检查 `st_mode`、`st_dev`、`st_ino`、`st_nlink`、时间字段映射

### [ ] 4. 清理/退出 `uya_macos_native_stat` 主链角色
- 目标：
  - 移除或废弃其作为 Darwin ABI mirror 的职责
- 注意：
  - 若短期内不能彻底删除，也必须确保 `uya_macos_stat/fstat/lstat` 不再依赖它

### [ ] 5. 处理 Darwin bridge 需要的系统头/声明整合
- 目标：
  - 为原生 `struct stat` 的使用提供稳定声明来源
- 注意：
  - 只限 Darwin bridge 局部
  - 不要把系统头依赖扩散到整个 seed/整个 codegen 主体

---

## P1：最小闭环验证（P0 完成后立即执行）

### [ ] 6. 重新生成 macOS seed 家族
- 目标文件：
  - `backup/uya-hosted-macos.c`
  - `backup/uya-hosted-macos-x86_64.c`
  - `backup/uya-hosted-macos-arm64.c`
- 目标：
  - 让新的 Darwin `stat` bridge 进入 seed
- 注意：
  - `backup/uya-hosted-macos-arm64.c` 与 `backup/uya-hosted-macos-x86_64.c` 永久保留
  - 不删除历史对照 seed

### [ ] 7. 验证 `make from-c-native`
- 目标：
  - 确认新的 bridge 没有破坏 macOS 本机 cold start
- 成功标准：
  - `bin/uya` 可重新生成

### [ ] 8. 验证 `make uya-hosted`
- 目标：
  - 检查当前阻塞点是否消失
- 重点观察：
  - 不再出现：
    - `错误: '/.../src/main.uya' 既不是文件也不是目录`

---

## P2：第二梯队排查（只有在 P1 越过当前卡点后才进行）

### [ ] 9. 复查 `paths_equal` 是否在 macOS 下仍可靠
- 位置：`src/main.uya:681-689`
- 目标：
  - 确认 `st_dev/st_ino` 在新的 Darwin bridge 下语义正确
- 触发条件：
  - 若后续出现文件去重、模块去重异常再进入此项

### [ ] 10. 复查 Darwin `readdir/dirent` bridge
- 目标：
  - 检查目录扫描、模块发现、自动依赖收集是否仍有 Darwin 专属问题
- 重点对象：
  - `uya_macos_host_readdir_fill`
  - `d_name` 清洗
  - `d_type` / regular-file 判定
- 触发条件：
  - 仅当 `stat` bridge 修复后，hosted 主线继续在目录/模块阶段失败时进入

### [ ] 11. 复查 regular-file 判定与模块收集一致性
- 目标：
  - 检查 `is_file/is_directory` 恢复后，依赖收集是否仍存在 macOS 特殊偏差
- 注意：
  - 先观察，不要先改主流程

---

## P3：一致性与稳定性收口

### [ ] 12. 确认 `uya-safety` / `uya-hosted` / `tests-hosted` 在新 bridge 下保持一致行为
- 目标：
  - 确认当前 macOS hosted/native bootstrap 语义未被新的 bridge 改动破坏

### [ ] 13. 更新 `docs/macos_porting_analysis.md`
- 目标：
  - 把 bridge 改动后的真实实施结果、风险消除情况、剩余问题同步回文档

### [ ] 14. 记录 x86_64 / arm64 Darwin 验证差异
- 目标：
  - 明确新 bridge 在两种架构上的验证状态
- 要求：
  - 不删除 arch-specific seed
  - 明确记录两边是否一致通过

---

## 当前明确不要做的事（红线）

### [ ] 不修改 `src/main.uya` 的主流程逻辑
包括但不限于：
- `is_file`
- `is_directory`
- 输入解析主流程
- 项目根目录推导
- 自动依赖收集主流程

### [ ] 不修改统一 `Stat`
- 位置：`lib/libc/syscall.uya`
- 原因：避免波及 Linux 主线与内部统一抽象

### [ ] 不修改 Linux `sys_stat/sys_fstat/sys_lstat`
- 原因：Linux 主线保持不变

### [ ] 不先改 `S_IFMT / S_IFDIR / S_IFREG` 解释逻辑
- 原因：当前没有足够证据表明问题在常量解释层

### [ ] 不把问题扩散到广泛平台化重构
包括但不限于：
- 不在 `src/main.uya` 大量引入 macOS/Linux 分支
- 不拆分内部统一结构为 Darwin/Linux 两套
- 不提前重写 runtime / osal / async / pthread / net 主体

---

## 最终执行原则

1. **先修 bridge，再看主逻辑是否自然恢复**
2. **先解决 `stat`，不要同时动 `readdir`**
3. **只在上一层修通后，再进入下一层**
4. **每一步都要有明确的验证结果**
5. **不要为了修一个 Darwin bridge 问题滑向广泛平台化重构**
