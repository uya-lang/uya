---
name: Uya 包管理规范完善
overview: 设计并完善 Uya 语言的包管理系统规范，包括包配置文件格式、版本管理、依赖解析、包仓库规范和构建流程等完整规范文档。
todos: []
---

# Uya

包管理规范完善

## 目标

为 Uya 语言设计完整的包管理系统规范，包括包配置文件、版本管理、依赖解析、包仓库和构建流程等，使 Uya 项目能够管理外部依赖包。

## 当前状态

Uya 已实现基础模块系统：

- ✅ 目录即模块（`std/io/` → `std.io`）
- ✅ `export`/`use` 语句
- ✅ 模块路径解析（项目根目录 → UYA_ROOT → 编译器目录）
- ✅ 自动依赖收集
- ✅ 循环依赖检测

**缺失**：

- ❌ 包配置文件格式
- ❌ 包版本管理
- ❌ 外部包依赖声明
- ❌ 包仓库/注册表规范
- ❌ 包安装和构建流程

## 实现计划

### 1. 包配置文件规范（`uya.toml`）

在项目根目录创建 `uya.toml` 文件，定义项目元数据和依赖：**文件位置**：`uya.toml`（项目根目录，与包含 `main` 的目录同级或在其父目录）**基本结构**：

```toml
[package]
name = "my_project"
version = "0.1.0"
authors = ["Author Name <author@example.com>"]
description = "项目描述"
license = "MIT"
repository = "https://github.com/user/repo"

[dependencies]
# Git 依赖（主要方式，去中心化）
http = { git = "https://github.com/user/http.git", tag = "v1.2.3" }
json = { git = "https://github.com/user/json.git", tag = "v1.0.0" }
math = { git = "https://gitlab.com/user/math.git", branch = "main" }
parser = { git = "https://github.com/user/parser.git", commit = "abc123" }  # 精确 commit

# 本地路径依赖（开发时使用）
test_utils = { path = "../test_utils" }

[dev-dependencies]
# 开发依赖（仅用于测试、构建工具等）
test_framework = "1.0.0"

[build]
# 构建配置
target = "x86_64-unknown-linux-gnu"  # 目标平台（可选）
```

**规范要点**：

- 使用 TOML 格式（简洁、易读）
- `[package]` 节：项目元数据
- `[dependencies]` 节：运行时依赖
- `[dev-dependencies]` 节：开发依赖（不包含在最终构建中）
- 版本约束通过 Git 标签、分支或 commit 指定
- 主要使用 Git 仓库作为包源（去中心化）
- 支持本地路径依赖（开发时使用）

### 2. 包版本管理规范（基于 Git）

**去中心化版本管理**：

- 不依赖中央注册表，直接从 Git 仓库获取
- 版本通过 Git 标签（tag）、分支（branch）或 commit 指定
- 语义化版本通过 Git 标签体现（如 `v1.2.3`）

**版本指定方式**：

- `tag = "v1.2.3"`：使用 Git 标签（推荐，稳定版本）
- `branch = "main"`：使用分支（开发版本，会跟踪最新提交）
- `commit = "abc123..."`：使用精确 commit（最稳定，但不利于更新）

**版本解析规则**：

- Git 标签优先：如果指定了 tag，使用该标签的代码
- 分支跟踪：如果指定了 branch，使用该分支的最新 commit
- Commit 锁定：如果指定了 commit，使用该精确 commit
- 版本冲突：不同依赖要求同一包的不同版本时，报告错误
- 支持版本锁定文件（`uya.lock`）记录精确 commit

### 3. 依赖解析规则

**模块查找顺序扩展**（在现有基础上）：

1. 项目根目录（本地模块）
2. `deps/` 目录（已安装的外部包）
3. `UYA_ROOT` 环境变量指定的标准库位置
4. 编译器目录（内置标准库）

**依赖解析流程**：

1. 读取 `uya.toml`，解析 `[dependencies]` 节
2. 对于每个依赖：

- 检查 `deps/` 目录是否已安装
- 如果未安装，从 Git 仓库克隆/下载
- 如果指定了 tag，检出对应标签
- 如果指定了 branch，使用分支最新 commit
- 如果指定了 commit，检出该 commit
- 解析传递依赖（依赖的依赖）
- 检测版本冲突（同一包的不同版本要求）

3. 生成依赖图，检测循环依赖
4. 生成 `uya.lock` 锁定文件（精确版本）

**传递依赖处理**：

- 自动解析传递依赖
- 版本冲突时报告错误，要求用户明确指定版本
- 如果无法满足所有约束，报告错误

### 4. 包源规范（去中心化）

**Git 仓库作为包源**：

- 任何公开的 Git 仓库都可以作为包源
- 支持 GitHub、GitLab、Bitbucket、Gitee 等平台
- 支持自托管 Git 服务器
- 支持 SSH 和 HTTPS 协议

**包发布规范**：

- 包必须包含 `uya.toml` 文件（在仓库根目录）
- 包名在 `uya.toml` 中定义，不需要全局唯一（通过 Git URL 区分）
- 版本通过 Git 标签管理（推荐使用语义化版本标签，如 `v1.2.3`）
- 包必须包含至少一个导出模块

**包命名规范**：

- 包名在 `uya.toml` 的 `[package]` 节中定义
- 包名用于模块路径（如 `use http.client;`）
- 不同 Git 仓库可以有相同的包名（通过 Git URL 区分）

**私有仓库支持**：

- 支持私有 Git 仓库（通过 SSH 密钥或 HTTPS 认证）
- 支持企业内网 Git 服务器
- 认证信息通过 Git 配置或环境变量管理

### 5. 包安装和构建流程

**包安装流程**：

1. 读取 `uya.toml` 依赖声明
2. 对于每个 Git 依赖：

- 克隆或更新 Git 仓库到临时目录
- 根据 tag/branch/commit 检出对应版本
- 复制到 `deps/{package_name}/` 目录（或使用 Git submodule）

3. 对于本地路径依赖：

- 创建符号链接或复制到 `deps/` 目录

4. 递归处理传递依赖（读取每个依赖的 `uya.toml`）
5. 检测版本冲突
6. 生成 `uya.lock` 锁定文件（记录所有依赖的精确 commit）

**包构建流程**：

1. 读取 `uya.lock`（如果存在）或 `uya.toml`
2. 收集所有依赖包的文件
3. 按照模块查找顺序解析模块路径
4. 编译主项目和所有依赖

**包锁定文件（`uya.lock`）**：

- 记录所有依赖的精确 Git commit hash
- 确保可重现构建（即使分支更新，也使用锁定的 commit）
- 自动生成，不应手动编辑
- 格式：TOML，包含完整依赖树和每个包的 commit hash
- 示例：
  ```toml
        [[dependencies]]
        name = "http"
        git = "https://github.com/user/http.git"
        commit = "abc123def456..."
        
        [[dependencies.http.dependencies]]
        name = "utils"
        git = "https://github.com/user/utils.git"
        commit = "789ghi012jkl..."
  ```




### 6. 包目录结构规范

**标准包结构**：

```javascript
package_name/
├── uya.toml          # 包配置文件
├── src/              # 源代码目录
│   ├── main.uya      # 主模块（如果是可执行包）
│   └── lib.uya       # 库模块（如果是库包）
├── README.md         # 说明文档
├── LICENSE           # 许可证
└── examples/         # 示例代码（可选）
```

**安装后的目录结构**：

```javascript
project_root/
├── uya.toml
├── uya.lock
├── src/
│   └── main.uya
└── deps/              # 外部依赖包
    ├── http/
    │   ├── uya.toml
    │   └── src/
    └── json/
        ├── uya.toml
        └── src/
```



### 7. 模块路径解析扩展

**外部包的模块路径**：

- 包名作为模块路径的第一段
- 例如：`use http.client;` → `deps/http/src/client.uya`
- 支持子模块：`use http.client.request;` → `deps/http/src/client/request.uya`

**模块路径解析优先级**（更新）：

1. 项目根目录（`src/` 或根目录）
2. `deps/{package_name}/src/`（外部包）
3. `UYA_ROOT/std/`（标准库）
4. 编译器内置目录

### 8. 工具命令规范

**包管理器命令**（`uyapm` CLI）：

- `uyapm init`：初始化新项目，创建 `uya.toml`
- `uyapm add <git-url> [tag/branch]`：添加 Git 依赖
- `uyapm remove <package>`：移除依赖
- `uyapm install`：安装所有依赖（根据 `uya.toml` 或 `uya.lock`）
- `uyapm update`：更新依赖（如果使用 branch，更新到最新 commit）
- `uyapm build`：构建项目
- `uyapm publish`：无需发布（Git 仓库即发布）

## 文档输出

创建以下规范文档：

1. **`docs/package_management.md`**：完整的包管理规范文档

- 包配置文件格式
- 版本管理规范
- 依赖解析规则
- 包源规范（去中心化 Git 仓库）
- 构建和安装流程

2. **更新 `uya.md`**：在模块系统章节添加包管理相关内容

- 扩展模块路径解析规则
- 添加外部包使用说明

3. **示例文件**：

- `examples/package_example/uya.toml`：示例配置文件
- `examples/package_example/README.md`：包管理使用示例

## 实现优先级

1. **阶段 1（规范文档）**：完成所有规范文档编写
2. **阶段 2（基础支持）**：实现 `uya.toml` 解析和本地路径依赖
3. **阶段 3（完整实现）**：实现包管理器工具和 Git 依赖支持