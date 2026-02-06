---
name: DSL自定义指南
overview: 创建一份完整的DSL自定义指南，包含教程、API参考、示例集合和设计模式库，帮助用户使用Uya宏系统创建自定义DSL。
todos:
  - id: create_doc_structure
    content: 创建文档目录结构和主文档框架
    status: pending
  - id: tutorial_quick_start
    content: 编写教程快速开始部分（DSL简介、第一个示例）
    status: pending
    dependencies:
      - create_doc_structure
  - id: tutorial_basics
    content: 编写基础概念章节（宏系统、AST、代码生成）
    status: pending
    dependencies:
      - tutorial_quick_start
  - id: tutorial_step_by_step
    content: 编写创建简单DSL的完整步骤教程
    status: pending
    dependencies:
      - tutorial_basics
  - id: api_reference
    content: 编写API参考文档（所有宏系统功能）
    status: pending
    dependencies:
      - create_doc_structure
  - id: example_sql
    content: 实现SQL DSL示例（完整可运行代码）
    status: pending
    dependencies:
      - tutorial_step_by_step
  - id: example_config
    content: 实现配置DSL示例
    status: pending
    dependencies:
      - tutorial_step_by_step
  - id: example_test
    content: 实现测试框架DSL示例
    status: pending
    dependencies:
      - tutorial_step_by_step
  - id: pattern_library
    content: 整理设计模式库（构建器、模板、组合等）
    status: pending
    dependencies:
      - example_sql
      - example_config
  - id: practice_sql
    content: 完善SQL DSL实践项目（完整实现+文档）
    status: pending
    dependencies:
      - example_sql
  - id: practice_config
    content: 完善配置DSL实践项目
    status: pending
    dependencies:
      - example_config
  - id: test_examples
    content: 为所有示例编写测试用例
    status: pending
    dependencies:
      - example_sql
      - example_config
      - example_test
---

# DSL 自定义指南实现计划

## 概述

创建一份完整的DSL自定义指南文档，帮助用户使用Uya宏系统创建自定义领域特定语言（DSL）。指南包含教程、API参考、实际示例和设计模式库。

## 文档结构

### 1. 教程部分（Tutorial）

**文件**：`docs/dsl_guide_tutorial.md`

#### 1.1 快速开始

- DSL是什么
- 为什么使用宏系统创建DSL
- 第一个DSL示例（5分钟上手）

#### 1.2 基础概念

- 宏系统基础
- AST操作
- 代码生成流程
- 编译时 vs 运行时

#### 1.3 创建简单DSL

- 步骤1：定义DSL语法
- 步骤2：设计数据结构
- 步骤3：实现宏
- 步骤4：测试和验证

#### 1.4 进阶技巧

- 参数验证
- 错误处理
- 条件编译
- 代码组合

#### 1.5 最佳实践

- 命名约定
- 文档编写
- 性能考虑
- 调试技巧

### 2. API参考（API Reference）

**文件**：`docs/dsl_guide_api_reference.md`

#### 2.1 宏定义语法

- `mc` 关键字
- 参数类型（`expr`, `stmt`, `type`）
- **注意**：`pattern` 参数类型在规范中提及，但当前实现中尚未支持，请使用 `expr` 替代
- 返回标签（`expr`, `stmt`, `struct`, `type`）
- `export` 关键字

#### 2.2 编译时内置函数

- `@mc_eval(expr)` - 编译时求值
- `@mc_type(expr)` - 类型反射
- `@mc_ast(expr)` - 代码转AST
- `@mc_code(ast)` - AST转代码
- `@mc_error(msg)` - 编译错误
- `@mc_get_env(name)` - 环境变量

#### 2.3 宏调用语法

- 基本调用
- 参数传递
- 返回值使用
- 语法糖规则

#### 2.4 插值语法

- `${}` 插值
- 嵌套插值
- AST节点引用

#### 2.5 限制和安全

- 递归深度限制
- 展开次数限制
- 环境变量访问限制

### 3. 示例集合（Examples）

**文件**：`docs/dsl_guide_examples/`

#### 3.1 SQL查询构建器

**文件**：`docs/dsl_guide_examples/sql_dsl.md`

- 表定义
- SELECT查询
- WHERE条件
- JOIN操作

#### 3.2 配置DSL

**文件**：`docs/dsl_guide_examples/config_dsl.md`

- 键值对配置
- 嵌套配置
- 类型验证
- 默认值

#### 3.3 测试框架DSL

**文件**：`docs/dsl_guide_examples/test_dsl.md`

- 测试用例定义
- 断言宏
- 测试套件组织
- Mock支持

#### 3.4 HTTP路由DSL

**文件**：`docs/dsl_guide_examples/http_dsl.md`

- 路由定义
- 中间件
- 参数提取
- 响应生成

#### 3.5 状态机DSL

**文件**：`docs/dsl_guide_examples/state_machine_dsl.md`

- 状态定义
- 转换规则
- 事件处理
- 代码生成

#### 3.6 数据验证DSL

**文件**：`docs/dsl_guide_examples/validation_dsl.md`

- 验证规则
- 组合验证器
- 错误消息
- 类型安全

### 4. 设计模式库（Pattern Library）

**文件**：`docs/dsl_guide_patterns.md`

#### 4.1 构建器模式

- 链式调用
- 状态累积
- 最终构建

#### 4.2 模板模式

- 代码模板
- 参数替换
- 条件生成

#### 4.3 组合模式

- 嵌套结构
- 递归展开
- 树形构建

#### 4.4 验证模式

- 参数检查
- 类型验证
- 约束检查

#### 4.5 代码生成模式

- 结构体生成
- 方法生成
- 接口实现

#### 4.6 条件编译模式

- 特性开关
- 平台特定
- 版本控制

### 5. 实践项目

**文件**：`docs/dsl_guide_practice/`

#### 5.1 完整SQL DSL实现

**目录**：`docs/dsl_guide_practice/sql_dsl/`

- 完整源代码
- 测试用例
- 使用文档

#### 5.2 配置管理DSL

**目录**：`docs/dsl_guide_practice/config_dsl/`

- 完整实现
- 示例配置
- 集成指南

## 实现步骤

### 阶段1：基础文档结构

1. 创建文档目录结构
2. 编写教程快速开始部分
3. 整理API参考基础内容

### 阶段2：教程完善

1. 完成基础概念章节
2. 编写创建简单DSL的完整教程
3. 添加进阶技巧和最佳实践

### 阶段3：示例实现

1. 实现SQL DSL示例（完整可运行）
2. 实现配置DSL示例
3. 实现测试框架DSL示例
4. 实现其他示例

### 阶段4：模式库

1. 整理常见设计模式
2. 为每个模式提供代码示例
3. 说明适用场景

### 阶段5：实践项目

1. 完善SQL DSL实现
2. 添加配置DSL实现
3. 编写使用文档

## 文件组织

```javascript
docs/
├── dsl_guide_tutorial.md           # 教程主文档
├── dsl_guide_api_reference.md      # API参考
├── dsl_guide_patterns.md            # 设计模式库
├── dsl_guide_examples/             # 示例集合
│   ├── sql_dsl.md
│   ├── config_dsl.md
│   ├── test_dsl.md
│   ├── http_dsl.md
│   ├── state_machine_dsl.md
│   └── validation_dsl.md
└── dsl_guide_practice/             # 实践项目
    ├── sql_dsl/
    │   ├── sql_dsl.uya
    │   ├── examples.uya
    │   └── README.md
    └── config_dsl/
        ├── config_dsl.uya
        ├── examples.uya
        └── README.md

compiler-mini/tests/programs/
└── dsl_examples/                   # DSL示例测试
    ├── test_sql_dsl_basic.uya
    ├── test_config_dsl.uya
    └── test_test_dsl.uya
```



## 内容要求

### 教程部分

- 循序渐进，从简单到复杂
- 每个概念都有代码示例
- 包含常见错误和解决方案
- 提供练习题目

### API参考

- 完整的函数签名
- 参数说明
- 返回值说明
- 使用示例
- 注意事项
- **已知限制**：明确标注当前不支持的功能（如 `pattern` 参数类型）

### 示例集合

- 每个示例都是完整可运行的
- 包含详细注释
- 提供使用场景说明
- 包含测试用例

### 模式库

- 模式描述
- 适用场景
- 实现示例
- 优缺点分析
- 变体说明

## 质量保证

1. **准确性**：所有代码示例必须可编译运行
2. **完整性**：覆盖宏系统所有功能
3. **实用性**：示例贴近实际使用场景
4. **可维护性**：文档结构清晰，易于更新

## 已知限制和注意事项

### 当前不支持的功能

1. **`pattern` 参数类型**

- 虽然在语法规范中提及，但当前宏系统实现中尚未支持
- 如果需要处理模式匹配，可以使用 `expr` 参数类型替代
- 未来版本可能会添加对 `pattern` 参数类型的完整支持

### 实现状态说明

- 文档中会明确标注每个功能的实现状态
- 区分"已实现"、"部分实现"、"计划中"三种状态
- 为未实现功能提供替代方案

## 后续扩展

- 视频教程
- 交互式示例