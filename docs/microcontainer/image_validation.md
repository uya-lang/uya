# Uya 微容器镜像与加载验证规范

**版本**: v1.3  
**日期**: 2026-04-02  
**关联文档**: `docs/microcontainer/requirements_v1.3.md`

---

## 1. 目标

加载期验证是编译期安全约束的冗余防线，目标是：

- 防篡改
- 防越权指令
- 防非法符号绑定
- 防热更新半写入状态

---

## 2. 镜像格式（最小集合）

容器镜像由头部、代码段、只读数据段、重定位段组成。头部必须包含：

- `magic` 固定标识
- `format_version`
- `container_api_version`
- `image_size`
- `entry_offset`
- `code_size`
- `rodata_size`
- `reloc_count`
- `sha256`
- `required_caps_bitmap`
- `build_mode`（当前内部仍使用容器镜像位；对外可理解为 app 的镜像模式）
- `target_arch`（如 `rv32` / `x86_64` / `aarch64` / `xtensa`）

---

## 3. 三重验证流程

### 3.1 第一步：完整性验证

- 对除 `sha256` 字段外的整镜像做 SHA-256 计算。
- 若哈希不一致，拒绝加载并记录 `E_IMG_HASH_MISMATCH`。

### 3.2 第二步：结构与重定位验证

验证点：

- 所有段边界位于镜像范围内。
- `entry_offset` 必须落在代码段。
- 重定位目标仅允许容器可重定位白名单节。
- 禁止重定位到物理地址常量区域。
- 禁止引用未导出或内核私有符号。

失败返回：

- `E_IMG_LAYOUT_INVALID`
- `E_IMG_RELOC_INVALID`
- `E_IMG_SYMBOL_DENIED`

### 3.3 第三步：指令策略验证

采用“解码后策略判定”，不使用仅匹配 `LUI+ADDI` 的窄规则。

必须执行：

- 全代码段顺序解码（支持压缩指令时需先展开判定）。
- 对每条指令应用策略规则。

禁止类别：

- 特权返回与陷入控制（如 `mret/sret/wfi`）
- CSR 访问指令（`csrr* / csrw*`）
- 代码自修改相关路径（`fence.i`）
- 非法未定义指令

允许 `ecall`，但仅作为 syscall 入口，不允许自定义 trap 向量操作。

失败返回：

- `E_IMG_INSN_DENIED`

---

## 4. 链接约束联动

加载器必须校验链接期产物标签：

- 目标文件类型必须为 `payload_obj`
- 拒绝链接到 `kernel_only` 符号域
- 拒绝未声明 capability 的设备接口桩

---

## 5. 加载状态机

状态机顺序固定：

- `EMPTY -> LOADING -> VERIFIED -> READY`

任一步失败：

- 回滚到 `EMPTY`
- 回收暂存页
- 写入审计日志

---

## 6. 热更新一致性规则

### 6.1 双槽写入

- 新版本仅写入非活跃槽位。
- 写入完成后重复执行三重验证。

### 6.2 原子切换

- 短暂禁中断。
- 先写新版本号与激活位，再执行内存屏障。
- 最后更新活动槽指针。

### 6.3 失败回滚

- 任一阶段失败都保持旧槽可运行。
- 标记新槽为 `INVALID` 并等待清理任务回收。

---

## 7. 审计日志字段

加载与更新失败日志必须记录：

- 时间戳
- container_id
- image_version
- stage（hash/reloc/instruction/activate）
- error_code
- fault_offset
- rollback_result

---

## 8. 测试要求

至少覆盖以下测试集：

- 哈希篡改镜像拒绝加载
- 非法重定位拒绝加载
- CSR 指令注入拒绝加载
- 非法符号引用拒绝加载
- 热更新中断注入后自动回滚

所有测试均需在 `uya microapp build` 产物上执行。

---

## 9. 验收标准

- 任何未通过三重验证的镜像都无法进入 `READY`。
- 审计日志可准确指示失败阶段与故障偏移。
- 热更新失败不影响旧版本持续运行。
