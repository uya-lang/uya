# UPM TODO List（按文件拆分）

> **核对头（2026-09-27）**：本文件是 UPM 的按文件实施清单，未逐条核对；`docs/upm_todolist.md` 与 `docs/todo_package_management.md` 的勾选已全部完成，可作参考。

基于：

- [`docs/upm_evolution_design.md`](./upm_evolution_design.md) 第 12 节“实施优先级与里程碑表”
- [`docs/upm_todolist.md`](./upm_todolist.md)

本文档把 TODO 从“按里程碑”进一步细化为“按文件拆分”，便于直接落地实施。

---

## 1. `src/cmd/upm/upm_lib/main.uya`

**状态**：Phase 1 / Phase 2 主体已完成拆分，当前主要承担 CLI、manifest 编辑与编排层。

### 当前职责

当前文件主要承担：

- CLI 参数解析与命令分发
- manifest 编辑（`init/add/remove`）
- `install/update/build` 的编排层 glue

已不再承担：

- 类型/常量定义
- path 与字符串工具
- manifest 解析
- lockfile 读写
- git 获取
- dependency resolver
- build plan / staging root

### TODO

#### Phase 1
- [x] 移除基础常量、enum、struct 定义，改由 `types.uya` 提供
- [x] 移除 path/string/file 工具函数，改由 `path_utils.uya` 提供
- [x] 移除 manifest parse 相关函数，改由 `manifest.uya` 提供

#### Phase 2
- [x] 移除 lockfile 相关逻辑，改由 `lockfile.uya` 提供
- [x] 移除 git fetch 相关逻辑，改由 `git_fetch.uya` 提供
- [x] 移除 manifest discovery / dependency resolve / conflict detection 逻辑，改由 `resolver.uya` 提供
- [x] 移除 build root 物化与 cleanup 逻辑，改由 `build_plan.uya` 提供
- [x] 保留 glue 层：串联 CLI、manifest 编辑、resolver、build_plan

#### 后续保留职责
- [x] 保留 CLI 参数解析
- [x] 保留 `upm_cli_main(...)`
- [x] 保留 manifest 编辑（如暂不继续拆）
- [x] 保留 `init/add/remove` 的编排层逻辑

### 完成定义
- [x] `main.uya` 不再是“大而全”的实现体
- [x] `main.uya` 主要变为 CLI 与编排层

---

## 2. `src/cmd/upm/upm_lib/types.uya`

**状态**：已创建，Phase 1 已落地；Phase 2 的 resolved graph 结构、Phase 3 的 `UPMPackageContext`、Phase 4 的 identity/checksum 字段已落地。

### 目标职责

统一承载共享常量、enum、struct 与基础 init helper。

### TODO

- [x] 新建文件
- [x] 迁移常量：
  - [x] `UPM_PATH_MAX`
  - [x] `UPM_LINE_MAX`
  - [x] `UPM_CMD_MAX`
  - [x] `UPM_MAX_DEPS`
  - [x] `UPM_MAX_ALIAS_LEN`
  - [x] `UPM_MAX_NAME_LEN`
  - [x] `UPM_MAX_VERSION_LEN`
  - [x] `UYA_UPM_RUNTIME_VERSION`
  - [x] `UPM_MAX_META_LEN`
  - [x] `UPM_MAX_REF_LEN`
  - [x] `UPM_MAX_LOCK_ITEMS`
  - [x] `UPM_MAX_VISITED`
- [x] 迁移 enum：
  - [x] `UPMManifestSection`
  - [x] `UPMDependencyKind`
  - [x] `UPMGitRefKind`
  - [x] `UPMBuildArgValueMode`
- [x] 迁移 struct：
  - [x] `UPMDependency`
  - [x] `UPMManifest`
  - [x] `UPMLockItem`
  - [x] `UPMPackageBuildPlan`
  - [x] `UPMAddArgs`
  - [x] `UPMRemoveArgs`
- [x] 迁移 init helper：
  - [x] `upm_manifest_init()`
  - [x] `upm_build_plan_init()`
- [x] Phase 2 新增：
  - [x] `UPMResolvedDep`
  - [x] `UPMResolvedGraph`
- [x] Phase 3 新增：
  - [x] `UPMPackageContext`
- [x] Phase 4 扩展字段：
  - [x] `UPMManifest.module`
  - [x] `UPMLockItem.module`
  - [x] `UPMLockItem.resolved_version`
  - [x] `UPMLockItem.resolved_commit`
  - [x] `UPMLockItem.content_hash`
  - [x] `UPMResolvedDep.module`
  - [x] `UPMResolvedDep.requested_version`
  - [x] `UPMResolvedDep.resolved_version`
  - [x] `UPMResolvedDep.content_hash`

### 完成定义
- [x] 所有 upm 共享模型集中在 `types.uya`
- [x] 后续新模块不再在各文件内重复定义共享结构

---

## 3. `src/cmd/upm/upm_lib/path_utils.uya`

### 目标职责

统一承载 path、字符串、文件存在性、安全校验等基础工具。

### TODO

- [x] 新建文件
- [x] 迁移函数：
  - [x] `upm_ascii_is_space`
  - [x] `upm_is_path_sep`
  - [x] `upm_normalize_path`
  - [x] `upm_exit_code_from_system_status`
  - [x] `upm_string_copy`
  - [x] `upm_bytes_copy`
  - [x] `upm_trim_copy`
  - [x] `upm_strip_inline_comment`
  - [x] `upm_is_absolute_path`
  - [x] `upm_path_dirname`
  - [x] `upm_path_parent_dir`
  - [x] `upm_ensure_trailing_slash`
  - [x] `upm_join_path`
  - [x] `upm_make_absolute_path`
  - [x] `upm_realpath_or_copy`
  - [x] `upm_path_exists`
  - [x] `upm_is_directory`
  - [x] `upm_is_file`
  - [x] `upm_source_dir_is_safe`
- [x] 统一处理跨文件 import 依赖
- [x] 让 `manifest.uya` / `resolver.uya` / `build_plan.uya` 复用该文件

### 完成定义
- [x] path 相关工具不再散落于 `main.uya`
- [x] 后续 resolver/build_plan 可稳定复用

---

## 4. `src/cmd/upm/upm_lib/manifest.uya`

### 目标职责

只负责 `uya.toml` 子集解析与 manifest 相关校验。

### TODO

- [x] 新建文件
- [x] 迁移函数：
  - [x] `upm_dep_init`
  - [x] `upm_parse_manifest_string_value`
  - [x] `upm_parse_version_component`
  - [x] `upm_compare_semver_like`
  - [x] `upm_validate_uya_min_version`
  - [x] `upm_parse_dependency_inline_table`
  - [x] `upm_parse_manifest`
- [x] 确保 `[layout]` 兼容逻辑保持不变
- [x] 确保报错文本尽量保持不变
- [x] Phase 4 扩展：
  - [x] 支持 `[package].module`
  - [x] 支持 dependency 中解析 `module + version`
- [x] 继续保持对旧 `path/git` manifest 的兼容
- [x] 纯 `module + version` 依赖解析到真实来源（resolver 已从本地 `~/.uya/pkg/mod/<module>/<version>` 内容缓存解析）

### 完成定义
- [x] manifest 解析不再混入 CLI / build / git 逻辑
- [x] manifest 字段扩展有稳定落点

---

## 5. `src/cmd/upm/upm_lib/lockfile.uya`

**状态**：已创建并投入使用；Phase 4 的扩展字段写回、显式 lockfile `version = 2` 头、完整 lock item 读取入口与旧字段兼容读取已落地。

### 目标职责

只负责 lockfile 的构造、读取、写入、匹配。

### TODO

- [x] 新建文件
- [x] 迁移函数：
  - [x] `upm_lock_item_record`
  - [x] `upm_dependency_exact_ref`
  - [x] `upm_lock_item_matches_source`
  - [x] `upm_write_lockfile(...)`
  - [x] `upm_load_locked_git_commit(...)`
- [x] 保持 install/update 当前 lock 语义不变
- [x] Phase 4 扩展：
  - [x] 写回 `module`
  - [x] 写回 `resolved_version`
  - [x] 写回 `resolved_commit`
  - [x] 写回 `content_hash`
- [x] 提供旧 lockfile `commit` 兼容读取能力
- [x] 明确 lockfile version/v2 头部与完整 lock item 读取策略

### 完成定义
- [x] lockfile 逻辑不再散落在 `main.uya`
- [x] lockfile 成为 resolver/fetch/cache 的稳定边界

---

## 6. `src/cmd/upm/upm_lib/git_fetch.uya`

**状态**：已创建并投入使用；当前 git clone/cache 已接入全局 `~/.uya/pkg/vcs/`，resolver 通过通用 fetch 边界调用 git checkout。

### 目标职责

只负责 git 相关的系统交互与 checkout 准备。

### TODO

- [x] 新建文件
- [x] 迁移函数：
  - [x] `upm_find_git_binary`
  - [x] `upm_exec_argv_wait`
  - [x] `upm_exec_argv_capture_first_line`
  - [x] `upm_git_checkout_ref`
  - [x] `upm_git_rev_parse_head`
  - [x] `upm_git_clone_into`
  - [x] `upm_git_prepare_checkout`
- [x] 保持 git 错误码与失败文本稳定
- [x] Phase 4 扩展：
  - [x] 与全局 cache 集成
  - [x] cache hit 优先
  - [x] cache miss 再 fetch
- [x] Phase 5 扩展：
  - [x] 为 fetcher 抽象保留边界

### 完成定义
- [x] git 获取逻辑有独立边界
- [x] cache 改造不再影响 CLI/manifest 解析
- [x] 后续 proxy 改造不再影响 CLI/manifest 解析

---

## 7. `src/cmd/upm/upm_lib/resolver.uya`

**状态**：已创建并投入使用；当前已具备 resolved graph 初始化、记录、plan-oriented 与 graph-oriented 双入口，graph-only resolve 已不再物化 `.uya/deps` / staging root。

### 目标职责

负责 manifest discovery、依赖图解析、冲突检测、resolved graph 构建。

### TODO

- [x] 新建文件
- [x] 迁移函数：
  - [x] `upm_find_manifest_upwards`
  - [x] `upm_resolve_manifest_path`
  - [x] `upm_check_dependency_conflicts`
- [x] 拆分当前递归逻辑，避免“解析依赖图”和“直接落盘 staging root”继续耦合
- [x] 将 recursive dependency resolve 收口到 resolver
- [x] 输出 `UPMResolvedGraph`
- [x] Phase 3 扩展：
  - [x] 提供 package discovery 给 `src/main.uya`
  - [x] 支持构造 `UPMPackageContext`
- [x] Phase 4 扩展：
  - [x] path/git 依赖携带 `module identity` 时校验目标包 identity
  - [x] path/git 依赖携带 `version` 时执行 exact version 校验
  - [x] 结合 global git cache 与 checksum 记录/校验进行 graph resolve
- [x] Phase 4 剩余：
  - [x] 支持纯 `module + version`（无 path/git 来源）解析到真实来源
  - [x] 将 `content_hash` 写入 `UPMResolvedGraph` 的 dep 条目
  - [x] 彻底拆分递归解析与 staging 物化
- [x] Phase 5 扩展：
  - [x] 支持 proxy/registry/workspace 场景下的 graph resolve

### 完成定义
- [x] resolver 可独立表达依赖图
- [x] resolver 不再只是 `upm build` 的私有辅助逻辑
- [x] resolver 可被编译器主流程复用

---

## 8. `src/cmd/upm/upm_lib/build_plan.uya`

**状态**：已创建并投入使用；当前仍是 package mode 的主要过渡期物化层。

### 目标职责

负责构建时的 staging build root 物化，而不是承担依赖图解析职责。

### TODO

- [x] 新建文件
- [x] 迁移 shell 物化相关函数：
  - [x] `upm_shell_quote`
  - [x] `upm_shell_run`
  - [x] `upm_shell_remove_tree`
  - [x] `upm_shell_mkdir_p`
  - [x] `upm_shell_copy_tree`
- [x] 迁移函数：
  - [x] `upm_build_plan_cleanup`
  - [x] `upm_prepare_build_plan`
  - [x] `upm_prepare_build_plan_ex`
- [x] 将 `upm_build_root_contains_alias` 从 `resolver.uya` 移到更合适的物化/路径边界，或明确保留在 resolver 的理由
- [x] 保持 `/tmp/uya-upm-build-<pid>/root` 方案兼容
- [x] Phase 3：作为 package mode 过渡期物化层继续存在
- [x] 后续逐步降低其对 package 语义的承载程度

### 完成定义
- [x] build_plan 主要负责物化构建输入
- [x] 不再承担依赖图主语义
- [x] resolver 与 staging 物化彻底解耦

---

## 9. `src/cmd/upm/upm_lib/cache.uya`

### 目标职责

承载全局缓存目录布局与 cache hit/miss 逻辑。

### TODO

- [x] 新建文件
- [x] 设计 `~/.uya/pkg/vcs/` 布局
- [x] 设计 `~/.uya/pkg/mod/` 布局
- [x] 提供 VCS cache lookup/key API
- [x] 让 `git_fetch.uya` 复用 VCS cache API
- [x] 提供并接入 `~/.uya/pkg/mod/` 内容层 write API
- [x] 让 `resolver.uya` 直接复用 module cache 内容层

### 完成定义
- [x] 全局缓存有明确模块边界
- [x] 不再把缓存逻辑塞回 git_fetch/main
- [x] `pkg/mod` 内容层可实际复用

---

## 10. `src/cmd/upm/upm_lib/checksum.uya`

### 目标职责

承载源码树 hash 规则与 checksum 校验逻辑。

### TODO

- [x] 新建文件
- [x] 定义源码树 hash 规则
- [x] 定义忽略文件/目录规则
- [x] 提供 checksum generate API
- [x] 提供 checksum verify API
- [x] 让 lockfile/install/build 复用
- [x] path 依赖按旧 lockfile checksum 做强校验

### 完成定义
- [x] checksum 生成/校验不再散落于 resolver/build/install 路径中

---

## 11. `src/main.uya`

**状态**：M3 已完成；已通过 helper 收口 package discovery，并引入 `UPMPackageContext`；`build/check/run/test` 已共享 package 准备入口。

### 目标职责

作为编译器主入口，负责 package discovery 与 package mode/legacy mode 分流。

### TODO

#### Phase 3
- [x] 在 build 流程中加入 manifest discovery
- [x] 找到 `uya.toml` 时进入 package mode
- [x] 找不到时保持 legacy mode
- [x] 让 `uya build` 复用 `resolver.uya`
- [x] 让 `uya check` 复用 `resolver.uya`
- [x] 让 `uya run/test` 至少共享 package discovery 与依赖准备逻辑
- [x] 初始化并传递 `UPMPackageContext`

### 完成定义
- [x] `uya build/check/run/test` 可进入原生 package mode
- [x] 不再需要把 package-aware 语义长期限定在 `upm build`

---

## 12. `src/driver/modules.uya`

**状态**：M3 已完成；已接入 package mode 下的 alias-root 优先级，冲突策略已落地，并已有 package mode 专项测试覆盖。

### 目标职责

作为模块解析核心，负责在 package mode 下支持 dependency alias roots。

### TODO

#### Phase 3
- [x] 保持 legacy mode 下现有 `project_root -> UYA_ROOT` 查找顺序
- [x] 在 package mode 下支持 root source root 查找
- [x] 在 package mode 下支持 dependency alias -> dependency source root 映射
- [x] 明确 alias 与本地顶层模块冲突策略
- [x] 为 package mode 增加回归测试

### 完成定义
- [x] 模块解析器可直接理解 package graph 的根映射
- [x] 包感知模块查找不再完全依赖 staging 目录结构

---

## 13. `src/cmd/upm/upm_lib/fetch_proxy.uya`（Phase 5 建议新增）

### TODO

- [x] 新建文件
- [x] 提供 proxy backend
- [x] 支持配置 proxy 地址
- [x] 支持 resolver 优先走 proxy

---

## 14. `src/cmd/upm/upm_lib/registry.uya`（Phase 5 建议新增）

### TODO

- [x] 新建文件
- [x] 支持 module -> source metadata 查询
- [x] 支持版本列表查询
- [x] 为后续 discover/search 保留接口

---

## 15. `src/cmd/upm/upm_lib/workspace.uya`（Phase 5 建议新增）

### TODO

- [x] 新建文件
- [x] 承载 workspace 语义
- [x] 支持多个 package root 组合
- [x] 支持 workspace 内本地模块优先

---

## 16. `src/cmd/upm/upm_lib/publish.uya`（Phase 5 建议新增）

### TODO

- [x] 新建文件
- [x] 设计 publish 最小协议
- [x] 支持 version 唯一性检查
- [x] 支持 metadata 校验
- [x] 支持 checksum 固化

---

## 17. `src/cmd/upm/upm_lib/diagnostics.uya`（Phase 5 建议新增）

### TODO

- [x] 新建文件
- [x] 提供 `upm graph`
- [x] 提供 `upm why`
- [x] 提供 `upm doctor`
- [x] 提供 `upm cache dir`
- [x] 提供 `upm vendor`

---

## 18. 测试与文档文件

### `tests/verify_upm_suite.sh` 及相关测试
- [x] 每个里程碑结束后执行完整回归
- [x] 增加 package mode 下 `uya build/check/run/test` 测试
- [x] 增加 module identity / cache / checksum / exact version 测试
- [x] 增加 proxy / workspace / diagnostics 测试

### `docs/package_management.md`
- [x] 随实现推进同步“当前实现状态”
- [x] 保持 v1 draft 与长期演进设计边界清晰

### `docs/upm_evolution_design.md`
- [x] 随里程碑推进更新阶段状态
- [x] 同步文件映射和优先级变化

### `docs/upm_todolist.md`
- [x] 保持按里程碑 TODO 的总览视图
- [x] 与本文件保持一致
