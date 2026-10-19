# UPM 演进设计文档

> **实现状态（2026-10-19 核对，v0.10.4）**：本文的 MVP 能力已落地于 `src/cmd/upm/`（外置可执行
> `bin/cmd/upm`，`make cmd-upm` / `make cmds`）。当前 CLI：`init` / `install` / `update` / `add`
> （`--path`、`--git` + `--branch|--tag|--commit`、`--dev`）/ `remove`（`--dep`、`--dev`）/ `graph` /
> `why` / `doctor` / `cache dir` / `vendor` / `publish`，`--manifest-path` 可覆盖 manifest 路径。
> 以 `./bin/cmd/upm --help` 为准；回归 `make upm-check`、`tests/test_cmd_upm_direct.sh`。

## 1. 背景

当前仓库中的 `upm` 已实现 Uya 包管理 MVP，具备以下能力：

- `uya.toml` manifest 解析
- `uya.lock` 写回
- `path` / `git` 依赖
- `upm init/install/update/build/add/remove`
- 递归依赖展开
- 基于临时 staging build root 的 `upm build`

当前实现入口与核心代码位于：

- `src/cmd/upm/main.uya:1`
- `src/cmd/upm/upm_lib/main.uya:2452`

当前文档已描述 v1 draft 与 MVP 范围，但尚缺一份面向后续实现的正式“演进设计文档”，用于统一：

- 代码拆分方向
- 编译器接入路径
- 模块身份模型
- 缓存/校验/版本演进
- 生态扩展边界

本文档用于补齐这部分。

---

## 2. 当前实现概述

### 2.1 现有能力

当前 `upm` 已支持：

- `upm init`
- `upm install`
- `upm update`
- `upm build`
- `upm add`
- `upm remove`

参考：

- `src/cmd/upm/upm_lib/main.uya:1554`
- `docs/package_management.md:448`

### 2.2 当前架构特征

当前实现的主要特征是：

1. `upm` 作为独立 CLI 存在
2. 包管理核心逻辑集中在单文件 `src/cmd/upm/upm_lib/main.uya`
3. `upm build` 通过：
   - 解析 manifest
   - 拉取/准备依赖
   - 构造临时 build root
   - 转调 `uya build`
4. 编译器主流程仍主要以 legacy module root 逻辑为中心
5. package mode 主要由 `upm build` 在编译器外部模拟完成

### 2.3 当前核心问题

当前实现虽然可用，但存在以下结构性问题：

1. **核心逻辑集中于单文件**
   - manifest
   - lockfile
   - git fetch
   - resolver
   - build plan
   - CLI
   混杂在一起，不利于维护和复用。

2. **resolver 与 staging 逻辑耦合**
   - 当前依赖解析过程直接伴随临时目录落盘
   - 不利于将 resolver 下沉到编译器

3. **package mode 尚未成为编译器原生能力**
   - `upm build` 是 package-aware
   - `uya build/check/run/test` 尚未统一原生 package-aware

4. **依赖身份已具备 module identity 基础**
   - path/git 依赖可携带 `module + version` 做 identity 与 exact version 校验
   - 纯 `module + version` 依赖可从本地 `~/.uya/pkg/mod/` 内容缓存解析

5. **缓存与校验模型已进入可用状态**
   - 当前 git 获取已接入全局 `~/.uya/pkg/vcs/`
   - `~/.uya/pkg/mod/` 内容层已可写入并复用
   - lockfile 已可写入 `module` / `resolved_version` / `resolved_commit` / `content_hash`
   - checksum 覆盖 path/git 与本地 `pkg/mod` 内容缓存源码树；path/git 均会按旧 lockfile checksum 做校验

---

## 3. 设计目标

本文档定义的演进目标如下：

### 3.1 总目标

将 `upm` 从当前 MVP 演进为：

- 编译器原生支持的 package mode
- 基于稳定模块身份的依赖解析系统
- 具备全局缓存与 checksum 的可重现依赖系统
- 可扩展到 proxy / registry / workspace / publish 的模块生态基础设施

### 3.2 分阶段目标

演进分为五个阶段：

1. 拆出基础层
2. 拆出 resolver / lock / git / build_plan
3. 将 package mode 下沉到编译器
4. 引入 module identity / global cache / checksum / version model
5. 扩展 proxy / registry / workspace / publish

### 3.3 非目标

本文档不要求在当前阶段立即实现：

- 中央 registry 上线
- 多版本并存
- semver range 求解
- 完整 publish 平台
- 完整企业级代理生态

这些能力只在后续阶段作为扩展目标定义。

---

## 4. 设计原则

### 4.1 兼容优先

必须始终保持以下工作流可用：

- `uya build file.uya`
- `uya build dir/`
- `uya run/test/check ...`

即：**无 manifest 的 legacy mode 不能回归**。

参考：

- `docs/package_management.md:530`

### 4.2 先重构边界，再增加能力

优先顺序必须是：

1. 拆清模块边界
2. 让 resolver 可复用
3. 让编译器理解 package mode
4. 再引入更高级的 identity / cache / checksum / version

### 4.3 解析图与物化分离

必须明确区分：

- **resolved graph**：依赖解析结果
- **build plan / staging root**：为一次构建准备的物化结果

这两个层级不能长期混为一谈。

### 4.4 alias 不是长期全局身份

alias 只应是当前项目中的局部导入名，不应作为未来生态级模块身份。

### 4.5 工具链原生优先

长期目标应是：

- `uya build`
- `uya check`
- `uya run`
- `uya test`

原生理解 package mode，而不是长期依赖 `upm build` 作为外部包装器。

---

## 5. 目标架构

目标架构分为五层。

### 5.1 类型与公共模型层

负责定义：

- manifest 数据结构
- dependency 数据结构
- lock item 数据结构
- resolved graph 数据结构
- package context 数据结构

建议模块：

- `types.uya`

### 5.2 解析与状态层

负责：

- manifest 解析
- lockfile 读写
- dependency graph 解析
- conflict detection
- source/ref/version 归一化

建议模块：

- `manifest.uya`
- `lockfile.uya`
- `resolver.uya`

### 5.3 获取与缓存层

负责：

- path/git/proxy/registry 获取
- 全局缓存
- checkout / archive / cache hit
- checksum 生成与校验

建议模块：

- `git_fetch.uya`
- `cache.uya`
- `checksum.uya`
- 后续 `fetch_proxy.uya`

### 5.4 编译器集成层

负责：

- package discovery
- package mode / legacy mode 切换
- module root / dependency root 映射
- build/check/run/test package-aware

建议模块：

- 编译器主入口
- 模块解析器
- `build_plan.uya`（过渡期）

### 5.5 生态扩展层

负责：

- proxy
- registry
- workspace
- publish
- diagnostics

建议模块：

- `workspace.uya`
- `registry.uya`
- `publish.uya`
- `diagnostics.uya`

---

## 6. 分阶段演进方案

## Phase 1：拆出基础层

### 目标

将当前大文件中的“纯定义”和“纯工具/纯解析”拆出。

### 输出

新增：

- `src/cmd/upm/upm_lib/types.uya`
- `src/cmd/upm/upm_lib/path_utils.uya`
- `src/cmd/upm/upm_lib/manifest.uya`

### 迁移内容

#### `types.uya`
迁移：

- 所有 UPM 常量
- `UPMManifestSection`
- `UPMDependencyKind`
- `UPMGitRefKind`
- `UPMBuildArgValueMode`
- `UPMDependency`
- `UPMManifest`
- `UPMLockItem`
- `UPMPackageBuildPlan`
- `UPMAddArgs`
- `UPMRemoveArgs`
- `upm_manifest_init`
- `upm_build_plan_init`

#### `path_utils.uya`
迁移：

- path normalize / dirname / parent / join
- trim/copy
- file/dir exists
- source-dir 安全校验

#### `manifest.uya`
迁移：

- manifest string value parse
- dependency inline table parse
- version compare
- `uya_min_version` 校验
- `upm_parse_manifest`

### 约束

- 不改 CLI 行为
- 不改 lockfile 格式
- 不改 build/staging 语义

### 验收标准

- `tests/verify_upm_suite.sh` 全绿
- `main.uya` 中 manifest 逻辑显著减少
- 无行为变化

---

## Phase 2：拆出 lock / git / resolver / build_plan

### 目标

将依赖解析、git 获取、lockfile 状态与构建物化拆层。

### 输出

新增：

- `src/cmd/upm/upm_lib/lockfile.uya`
- `src/cmd/upm/upm_lib/git_fetch.uya`
- `src/cmd/upm/upm_lib/resolver.uya`
- `src/cmd/upm/upm_lib/build_plan.uya`

### 核心动作

#### 6.2.1 拆 lockfile 层
负责：

- lock item record
- lock write/read
- locked git commit 查找
- source/ref exact match

#### 6.2.2 拆 git fetch 层
负责：

- 找 git
- fork/exec git
- clone
- checkout
- rev-parse
- prepare checkout

#### 6.2.3 定义 resolved graph
新增中间模型：

- `UPMResolvedDep`
- `UPMResolvedGraph`

用于表达：

- 某个依赖是谁
- 来源是什么
- 解析后的 package root/source root 是什么
- 最终 commit/ref 是什么

这一步用于替代“直接拿 build plan 表达依赖图”的设计。

#### 6.2.4 拆 resolver 层
负责：

- manifest discovery
- manifest path resolve
- recursive dependency resolve
- conflict detection
- visited 去重
- resolved graph 生成

#### 6.2.5 拆 build plan 层
负责：

- staging tmp root
- remove/copy/mkdir
- compile_input 计算
- module_root 计算
- cleanup

### 核心原则

必须开始分离：

- **依赖解析**
- **构建物化**

### 验收标准

- resolver 已能形成 resolved graph
- build plan 不再承担依赖身份语义
- 现有 install/update/build 测试全部通过

---

## Phase 3：将 package mode 下沉到编译器

### 目标

让 package mode 从 `upm build` 的外部行为变成编译器主流程的一部分。

### 核心新增模型

新增：

- `UPMPackageContext`

建议字段：

- `active`
- `manifest_path`
- `package_root`
- `source_root`
- `module_root`
- `resolved_graph`
- `lockfile_path`
- `materialized_root`（过渡期可选）

### 关键实现步骤

#### 6.3.1 编译器入口加入 package discovery
当输入文件或目录时：

1. 向上查找 `uya.toml`
2. 若找到，则进入 package mode
3. 若未找到，则继续 legacy mode

#### 6.3.2 `uya build` 原生 package-aware
在 manifest 项目中：

- `uya build` 直接复用 resolver / package context
- 过渡期可继续依赖 build plan/staging

#### 6.3.3 `uya check/run/test` 接入 package context
逐步统一：

- build
- check
- run
- test

的 package discovery 与依赖准备逻辑。

#### 6.3.4 模块解析器支持 dependency alias roots
package mode 下：

1. 先查 root source root
2. 若 import 首段命中 dependency alias，则跳转到对应 dependency source root
3. 标准库查找仍保留 `UYA_ROOT`

### 阶段目标

使 `upm build` 不再是唯一 package-aware 入口。

### 验收标准

- `uya build` 在 manifest 项目中可直接工作
- legacy mode 完全不回归
- 模块解析器开始直接理解 dependency alias -> source root 映射

---

## Phase 4：引入 module identity / global cache / checksum / version model

### 目标

将 `upm` 从“能拉依赖”升级为“能稳定标识、缓存、验证依赖”的模块系统。

### 关键能力

#### 6.4.1 Module Identity

在 manifest 中新增：

```toml
[package]
name = "http"
module = "uya.io/net/http"
version = "0.1.0"
```

依赖声明逐步支持：

```toml
foo = { module = "uya.io/foo", version = "1.2.3" }
```

其中：

- `name`：本地包名/展示名
- `module`：稳定全局身份
- `version`：模块版本

#### 6.4.2 Global Cache

从早期/历史项目内：

- `.uya/git-cache/`

演进为全局缓存：

- `~/.uya/pkg/vcs/`
- `~/.uya/pkg/mod/`

当前代码已接入 `~/.uya/pkg/vcs/` 作为 git clone/cache；`~/.uya/pkg/mod/` 仍仅有目录布局 API，尚未作为模块内容层实际写入与复用。

分层建议：

- `vcs/`：原始获取层
- `mod/`：解析后的模块内容层

#### 6.4.3 Checksum

lockfile 增加：

- `content_hash`

用于：

- install 时记录
- build 时校验
- cache 命中时校验

#### 6.4.4 版本模型

先支持：

- exact version

例如：

```toml
foo = { module = "uya.io/foo", version = "1.2.3" }
```

暂不引入：

- semver range
- SAT solver
- 多版本共存

### 数据模型演进

#### `UPMManifest`
新增：
- `module`

#### `UPMLockItem`
新增：
- `module`
- `resolved_version`
- `resolved_commit`
- `content_hash`

#### `UPMResolvedDep`
新增：
- `module`
- `requested_version`
- `resolved_version`
- `content_hash`

### 验收标准

- 旧 path/git 项目继续可用
- 新项目可在 path/git 依赖上携带 `module + version` 进行 identity 与 exact version 校验
- 纯 `module + version`（无 path/git 来源）依赖解析完成
- 同依赖跨项目可复用缓存
- lockfile 可记录 identity + checksum

---

## Phase 5：生态层扩展

### 目标

将单机可用的模块系统扩展为可持续生态系统。

### 关键能力

#### 6.5.1 Proxy
优先于 registry 实现。

原因：

- 降低对公网 git 的依赖
- 企业可部署
- 加速与留存
- 更适合 Uya 早期生态

#### 6.5.2 Registry
定位为：

- metadata / discovery 层

而非一开始就变成唯一真实 source。

主要承担：

- module -> source metadata
- version list
- README/license 等元数据

#### 6.5.3 Workspace
建议比 Go 更早系统设计。

最小能力：

- 多 package root 本地联调
- workspace 内模块优先走本地
- 统一 build/check/test 视图

#### 6.5.4 Publish
最小目标：

- version 唯一性检查
- checksum 固化
- metadata 校验
- 源码可获取性验证

#### 6.5.5 Diagnostics
建议增加：

- `upm graph`
- `upm why`
- `upm doctor`
- `upm cache dir`
- `upm vendor`

### 验收标准

- resolver 能支持多 fetch backend
- 支持 proxy/registry 扩展
- workspace 语义清晰
- publish 形成最小闭环
- 提供 graph/doctor/cache 可观察能力

---

## 7. 数据模型建议

后续建议保留以下核心结构。

### 7.1 `UPMResolvedDep`
用于表示单个解析后的依赖。

建议字段：

- alias
- package_name
- module
- kind
- package_root
- source_root
- path_raw
- git_url
- requested_ref
- requested_version
- resolved_commit
- resolved_version
- content_hash

### 7.2 `UPMResolvedGraph`
用于表示 root package 的完整依赖图。

建议字段：

- root_manifest_path
- package_root
- source_root
- resolved_dep_count
- resolved_deps[]

### 7.3 `UPMPackageContext`
用于一次编译/运行/测试的 package 语义上下文。

建议字段：

- active
- manifest_path
- package_root
- source_root
- module_root
- resolved_graph
- lockfile_path
- materialized_root（过渡期）

---

## 8. 风险与约束

### 8.1 legacy mode 回归风险
必须始终保证：

- 无 manifest 的 build/check/run/test 不回归

### 8.2 resolver 与 build_plan 混淆风险
若继续让 build plan 表达依赖图，会阻碍后续编译器接入。

### 8.3 alias 与模块身份混淆风险
必须避免 alias 成为未来生态级身份。

### 8.4 过早引入复杂版本求解
在 identity/cache/checksum 尚未稳定前，不应引入复杂版本范围与多版本策略。

### 8.5 过早做中心化 registry
应优先实现 proxy / cache / identity，再考虑 registry 服务。

---

## 9. 推荐实施顺序

建议优先按以下顺序执行：

### 第一阶段
- Phase 1：拆基础层

### 第二阶段
- Phase 2：拆 lock/git/resolver/build_plan

### 第三阶段
- Phase 3：编译器 package mode

### 第四阶段
- Phase 4：identity/cache/checksum/version

### 第五阶段
- Phase 5：proxy/registry/workspace/publish

---

## 11. 与当前代码文件的映射

本节用于把本文档中的演进阶段，与当前仓库中的真实实现位置对应起来，方便后续拆分任务落地。

### 11.1 当前核心入口

- `src/cmd/upm/main.uya`
  - `cmd/upm` 独立可执行入口
  - 当前仅做 `upm_cli_main(...)` 转发
- `src/cmd/upm/upm_lib/main.uya`
  - 当前 `upm` 的主要实现集中在此

### 11.2 当前已存在但尚未拆层的职责

`src/cmd/upm/upm_lib/main.uya` 当前同时承担：

- 类型/常量定义
- path 与字符串工具
- manifest 解析
- lockfile 读写
- git 获取与 checkout
- dependency resolver
- build plan / staging root 物化
- manifest 编辑（`init/add/remove`）
- CLI 参数解析与命令分发

这也是本文档把 Phase 1 / Phase 2 的首要目标定义为“拆层”的原因。

### 11.3 建议拆分后的模块映射

#### Phase 1 对应

建议新增并承接以下职责：

- `src/cmd/upm/upm_lib/types.uya`
  - 常量
  - enum
  - struct
  - 基础 init helper
- `src/cmd/upm/upm_lib/path_utils.uya`
  - path normalize / join / dirname / exists
  - trim/copy 等基础工具
- `src/cmd/upm/upm_lib/manifest.uya`
  - `uya.toml` 子集解析
  - dependency inline table 解析
  - `uya_min_version` 校验

#### Phase 2 对应

建议新增并承接以下职责：

- `src/cmd/upm/upm_lib/lockfile.uya`
  - lockfile 读写
  - locked ref/commit 查找
  - lock item 匹配
- `src/cmd/upm/upm_lib/git_fetch.uya`
  - git executable 查找
  - clone / checkout / rev-parse
  - git cache 准备
- `src/cmd/upm/upm_lib/resolver.uya`
  - manifest discovery
  - dependency graph resolve
  - conflict detection
  - resolved graph 构建
- `src/cmd/upm/upm_lib/build_plan.uya`
  - staging build root
  - compile_input/module_root 计算
  - cleanup

### 11.4 与编译器主流程的映射

#### 当前相关位置

- `src/main.uya`
  - 编译器主入口
  - 后续 package discovery 与 package mode/legacy mode 分流的主要接入点
- `src/driver/modules.uya`
  - 当前模块解析真实行为来源之一
  - 后续 dependency alias roots / package mode 模块查找的主要接入点

#### Phase 3 对应

建议在以下位置接入：

- `src/main.uya`
  - 增加 manifest discovery
  - 初始化 `UPMPackageContext`
  - 让 `build/check/run/test` 复用 package mode
- `src/driver/modules.uya`
  - 增加 package mode 下的 dependency alias -> source root 映射逻辑
  - 保留 legacy mode 下的现有查找顺序

### 11.5 与后续 identity/cache/checksum 的映射

#### Phase 4 对应的主要修改点

- `src/cmd/upm/upm_lib/types.uya`
  - 新增 `module` / `resolved_version` / `content_hash` 等字段
- `src/cmd/upm/upm_lib/manifest.uya`
  - 解析 `package.module`
  - 解析 `dependency.module + version`
- `src/cmd/upm/upm_lib/lockfile.uya`
  - lockfile v2 字段扩展
- `src/cmd/upm/upm_lib/git_fetch.uya`
  - 与 global cache 集成
- `src/cmd/upm/upm_lib/resolver.uya`
  - 以 module identity 为核心进行 graph resolve
- 后续可新增：
  - `src/cmd/upm/upm_lib/cache.uya`
  - `src/cmd/upm/upm_lib/checksum.uya`

### 11.6 与后续 proxy/registry/workspace 的映射

#### Phase 5 对应的主要新增点

- `src/cmd/upm/upm_lib/fetch_proxy.uya`
- `src/cmd/upm/upm_lib/registry.uya`
- `src/cmd/upm/upm_lib/workspace.uya`
- `src/cmd/upm/upm_lib/publish.uya`
- `src/cmd/upm/upm_lib/diagnostics.uya`

这些模块不应在 MVP 阶段提前混入 `main.uya`，而应建立在前述分层稳定之后再进入主线。

## 12. 实施优先级与里程碑表

**当前状态（2026-06-14）**：

- M1：已完成
- M2：主体已完成（resolved graph 已落结构，resolver 已具备 plan-oriented 与 graph-oriented 双入口；graph-only resolve 已不再物化 staging）
- M3：已完成（主入口接入、alias-root 优先级与 package mode 专项测试已落地）
- M4：已完成（`package.module`、依赖 `module/version` 解析、path/git identity 校验、global git cache、`pkg/mod` 内容层、checksum、lockfile v2 头部、resolved graph hash 与 graph-only/staging 拆分已落地；registry/proxy/workspace 属于 M5）
- M5：未开始

本节用于把前文的阶段性设计压缩成更适合执行和排期的视图。

### 12.1 推荐优先级

#### P0（应最先完成）

- Phase 1：拆出基础层
- Phase 2：拆出 lock / git / resolver / build_plan

原因：

- 这是后续一切演进的结构前提
- 风险相对可控
- 可在不改变外部语义的前提下推进

#### P1（基础稳定后推进）

- Phase 3：将 package mode 下沉到编译器

原因：

- 这是从“外挂式 upm”走向“工具链原生模块系统”的关键分界点
- 只有完成这一步，`uya build/check/run/test` 才能真正统一 package-aware 行为

#### P2（编译器已接入 package mode 后推进）

- Phase 4：引入 module identity / global cache / checksum / version model

原因：

- identity、cache、checksum 的价值需要建立在 package mode 主流程稳定之后
- 若编译器仍不原生理解 package graph，则这些能力只能继续挂在外层 wrapper 上

#### P3（长期扩展）

- Phase 5：proxy / registry / workspace / publish

原因：

- 这是生态层能力，不应早于核心模块系统稳定
- 需要前面的 identity / cache / checksum 打底

### 12.2 里程碑摘要表

| 里程碑 | 目标 | 主要输出 | 风险级别 | 建议时机 |
|---|---|---|---|---|
| M1 | 拆出基础层 | `types.uya`、`path_utils.uya`、`manifest.uya` | 低 | 立即开始 |
| M2 | 拆出核心子模块 | `lockfile.uya`、`git_fetch.uya`、`resolver.uya`、`build_plan.uya`、resolved graph | 中 | M1 后 |
| M3 | 编译器 package mode | `UPMPackageContext`、`uya build/check/run/test` package-aware、模块解析器支持 dependency alias roots | 高 | M2 后 |
| M4 | 身份/缓存/校验/版本 | `package.module`、global cache、lockfile v2、checksum、exact version | 中高 | M3 稳定后 |
| M5 | 生态扩展 | proxy、registry、workspace、publish、diagnostics | 高 | M4 后 |

### 12.3 每个里程碑的完成定义

#### M1 完成定义

- `src/cmd/upm/upm_lib/main.uya` 不再承载基础类型和 manifest 解析
- `tests/verify_upm_suite.sh` 全绿
- 对外 CLI 行为无变化

#### M2 完成定义

- resolver 已能形成独立的 resolved graph
- build plan 不再兼任依赖图语义承载层
- git / lockfile / build root 逻辑已形成清晰边界

#### M3 完成定义

- `uya build` 在 manifest 项目中原生可用
- `uya check` 进入 package mode
- `uya run/test` 至少共享 package discovery 与依赖准备链路
- legacy mode 无回归

#### M4 完成定义

- manifest 可表达稳定 module identity
- lockfile 可表达 resolved identity + checksum
- git 依赖可跨项目复用 `~/.uya/pkg/vcs/` 缓存
- path/git 依赖携带 `module + version` 时，exact version 校验稳定可用
- 纯 `module + version` 依赖可解析到真实来源
- `~/.uya/pkg/mod/` 模块内容层可被实际写入与复用

#### M5 完成定义

- fetch backend 可扩展
- proxy / registry 具备最小闭环
- workspace 可支持本地多包联调
- publish/diagnostics 有最小可用入口

### 12.4 建议执行策略

建议按以下策略推进：

1. **先文档与边界，后能力扩展**
   - 每个阶段先收口模块边界与职责
   - 再增加新字段、新协议或新命令
2. **每个里程碑结束都跑完整 upm 回归测试**
   - 尤其是 M1、M2、M3
3. **M3 前不引入大规模协议变化**
   - 例如 lockfile v2、global cache、module identity 不应早于 package mode 接入编译器
4. **生态层能力严格后置**
   - proxy / registry / workspace / publish 都不应抢在 resolver 与编译器集成之前

### 12.5 配套 TODO 文档

为便于实施与跟踪，本文档对应的 TODO 已拆分为以下两份：

- [UPM TODO List（按里程碑）](./upm_todolist.md)
- [UPM TODO List（按文件拆分）](./upm_todolist_by_file.md)

建议使用方式：

- 规划阶段：优先阅读本文档与 `docs/package_management.md`
- 排期阶段：优先使用 `upm_todolist.md`
- 落地实施阶段：优先使用 `upm_todolist_by_file.md`

## 13. 结论

当前 `upm` 已具备 MVP 闭环，M1/M2/M3 已完成，M4 中的 module identity、global git cache、`pkg/mod` 内容层、checksum 与 lockfile v2 扩展已部分落地，但其长期价值不应停留在：

- 改写 `uya.toml`
- 拉取 git/path 依赖
- 通过 staging root 包装 `uya build`

它应沿以下路线持续演进：

1. 从单文件 CLI 实现拆出可复用核心
2. 将 package mode 下沉为编译器原生能力
3. 引入稳定的 module identity
4. 建立全局缓存与 checksum 机制
5. 扩展到 proxy / registry / workspace / publish

最终目标是将 `upm` 演进为：

> 一个被 Uya 工具链原生理解、具备稳定模块身份、可缓存、可校验、可扩展的模块系统。
