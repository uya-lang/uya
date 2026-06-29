# 标准脚本运行时 TODO 失败归档

## 2026-06-29

### Phase 2：`std.path` / `std.env` / `std.fs` MVP

#### 2.1 `std.path`

- [f] 补 Linux / macOS / Windows 语义测试（至少先写平台条件测试）。
  - 失败原因：当前仓库缺少 `../uya/bin/uya`，无法按本轮硬约束执行平台条件验证脚本。
  - 阻塞命令：`bash tests/verify_std_path_platform_targets.sh`
  - 关键错误：`✗ 未找到 ../uya/bin/uya（请先构建编译器）`
  - 补充检查：`ls -l ../uya/bin/uya`
  - 补充结果：`ls: cannot access '../uya/bin/uya': No such file or directory`
  - 重开条件：先在当前仓库构建出 `../uya/bin/uya`，再重新运行 `bash tests/verify_std_path_platform_targets.sh`。
