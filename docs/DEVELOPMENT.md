# Uya 开发指导说明

**版本**：v0.3.4+  
**更新日期**：2026-05-20

本文档定义 Uya 编译器的开发流程。自 v0.3.4 起，**C 编译器（compiler-c/）已退役**，仅维护自举编译器。

---

## 开发模式

### 自举编译架构

```
bin/uya.c (已提交的 C99 代码)
    ↓ gcc -std=c99
bin/uya (可执行编译器)
    ↓ 编译 src/*.uya
bin/uya.c (新生成的 C99 代码)
    ↓ 自举验证 (make b)
提交新版本
```

### 关键原则

1. **单一编译器源**：`src/` 目录是唯一的编译器源代码
2. **C99 代码作为引导**：`bin/uya.c` 是自举编译器输出的 C99 代码，作为仓库的"种子"
3. **自举验证必须通过**：每次修改后必须运行 `make b` 验证自举一致性

---

## TDD 开发流程

新功能开发推荐使用测试驱动开发（Test-Driven Development）：

### 红绿重构循环

```
┌─────────────────────────────────────────────────────┐
│                    TDD 循环                          │
│                                                     │
│   1. 🔴 红：写失败的测试                              │
│      └─ 明确需求，先写测试文件                        │
│                                                     │
│   2. 🟢 绿：写最小代码使测试通过                       │
│      └─ 不追求完美，只求通过                          │
│                                                     │
│   3. 🔵 重构：优化代码，确保测试仍通过                  │
│      └─ 消除重复，改善设计                            │
│                                                     │
│   重复...                                           │
└─────────────────────────────────────────────────────┘
```

### TDD 工作流

```bash
# 1. 创建测试文件（测试先行）
vim tests/programs/test_new_feature.uya

# 2. 运行测试，确认失败（红）
make tests-uya
# 输出: test_new_feature ... FAILED (预期行为)

# 3. 实现功能代码
vim src/related_module.uya

# 4. 运行测试，确认通过（绿）
make uya && make tests-uya

# 4.1 若改动涉及 unknown/web target、libc/syscall bridge 或 Web 运行时，再补跑独立 smoke
make tests-emcc  # 需要本机安装 emcc 与 node

# 5. 重构代码
# ... 改善代码结构 ...

# 6. 确保重构后测试仍通过
make tests-uya

# 7. 最终验证：自举
make b
```

### 测试编写规范

测试文件命名和结构遵循 `docs/testing_guide.md`：

```uya
// tests/programs/test_feature.uya
use std.testing.*;

fn test_feature_case() !void {
    const result: i32 = my_function(input);
    try assert_eq_i32(result, expected, "description");
}

fn main() i32 {
    test_suite_begin("Feature Tests");
    run_test("feature case", test_feature_case);
    return test_suite_end();
}
```

### TDD 核心原则

| 原则 | 说明 |
|------|------|
| 测试先行 | 任何新功能必须有对应测试 |
| 小步迭代 | 每次只添加一个小功能点 |
| 快速反馈 | 测试应该快速执行 |
| 覆盖边界 | 测试边界条件和异常情况 |

---

## 开发前准备

### 学习开发技能

每次开发前，应阅读技能文档了解开发经验：

```bash
# 阅读 Uya 开发技能文档
cat .codebuddy/skills/uya-development.md
```

技能文档包含：
- Uya 语法规则和常见陷阱
- 编译器架构理解
- 开发最佳实践
- 常见问题解决方案

### 遵循 Uya 语法规则

开发时**必须符合 Uya 语法规则**，不要瞎编乱造：

| 规则 | 说明 |
|------|------|
| `str_equals(a, b) != 0` | 字符串相等（返回 1 表示相等） |
| Union 变体限制 | 不能包含引用 `&T` 或切片 `&[T]` |
| 参考现有代码 | 查看 `tests/programs/` 学习语法 |

---

## 从零开始构建

### 首次克隆仓库

```bash
git clone https://github.com/uya-lang/uya.git
cd uya

# 方式一：从 C99 代码构建（推荐，零依赖）
gcc -std=c99 -O2 bin/uya.c -o bin/uya -lm
make tests-uya  # 验证构建

# 方式二：使用 Makefile
make from-c     # 从 bin/uya.c 构建
```

### 开发流程

```bash
# 1. 修改编译器源代码
vim src/checker.uya

# 2. 使用当前编译器编译新版本
make uya        # bin/uya 编译 src/*.uya → bin/uya.c

# 3. 验证自举一致性
make b          # 新编译器编译自身，输出与 bin/uya.c 对比

# 4. 运行测试
make tests-uya  # 348 个测试

# 5. 提交
git add -A && git commit -m "fix: 描述修复内容"
```

---

## Makefile 目标

| 目标 | 说明 |
|------|------|
| `make from-c` | 从 `bin/uya.c` 构建 `bin/uya`；若缺失则优先挑选 `backup/uya-hosted-<host_os>-<host_arch>.c` / `backup/uya-<host_os>-<host_arch>.c`，再回退到通用备份；Linux x86_64 的 nostdlib `_start` 仍走 `crti.o`+`.o`+`crtn.o` 链接 |
| `make uya-c` | 构建 C 编译器 bin/uya-c（用于编译 src/*.uya） |
| `make uya` | 使用 bin/uya-c 编译 src/*.uya → bin/uya.c，然后构建 bin/uya |
| `make b` | 自举验证：编译器编译自身，验证输出一致性 |
| `make tests-uya` | 运行自举编译器测试 |
| `make tests-emcc` | 运行独立 emcc/unknown target smoke（需本机安装 emcc 与 node；不默认包含在 `make check` / `make release-dirty`） |
| `make release` | 最终 release 验证：要求工作树干净，执行 clean + 平台对应自举/测试 + seed 刷新 + 发布构建 |
| `make release-dirty` | 本地调试用的完整 release 流程；会先 clean，再执行平台对应 release 步骤，但不要求工作树干净 |
| `make release-clean` | 在 Git HEAD 干净快照中执行 `make release`，忽略未提交修改，适合作为 CI 对照 |
| `make tests-c` | （已废弃）运行 C 编译器测试 |
| `make clean` | 清理构建产物 |

---

## 代码结构

```
uya/
├── bin/
│   ├── uya          # 可执行编译器
│   └── uya.c        # 自举编译器输出的 C99 代码（已提交）
├── src/             # 编译器源代码（唯一维护源）
│   ├── main.uya     # 入口
│   ├── lexer.uya    # 词法分析
│   ├── parser.uya   # 语法分析
│   ├── checker.uya  # 类型检查 + 宏展开
│   ├── codegen/     # 代码生成
│   │   └── c99/     # C99 后端
│   └── ...
├── lib/             # 标准库
│   ├── std/         # 核心库
│   └── libc/        # C 库绑定
├── tests/           # 测试文件
│   └── programs/    # 348 个测试程序
├── docs/            # 文档
└── compiler-c/      # （已退役）C 编译器，仅供参考
```

---

## 自举验证详解

### `make b` 流程

```bash
# 1. 当前编译器编译自身 → bin/uya_bootstrap.c
bin/uya --c99 src/*.uya -o bin/uya_bootstrap.c

# 2. 对比新旧 C99 代码
diff bin/uya.c bin/uya_bootstrap.c

# 3. 一致则通过（验证自举能力）
```

### 验证失败处理

如果 `make b` 失败：

1. 检查是否有未提交的改动
2. 确认修改是否影响代码生成顺序
3. 排序相关的输出必须稳定（如 err_union 按名称排序）

---

## 发布流程

```bash
# 1. 确保测试通过
make tests-uya && make b

# 2. 更新版本号（如 v0.3.5）
# 编辑相关文档

# 3. 创建版本说明
vim docs/releases/RELEASE_v0.3.5.md

# 4. 提交并打标签
git add -A
git commit -m "release: v0.3.5"
git tag -a v0.3.5 -m "v0.3.5: 版本描述"

# 5. 推送
git push origin main --tags
```

---

## 注意事项

### 已退役组件

- **compiler-c/**：C 语言实现的编译器，自 v0.3.4 起不再维护
- **make tests-c**：已废弃，仅保留 `make tests-uya`

### 禁止操作

- ❌ 不要修改 `compiler-c/` 目录（已退役）
- ❌ 不要跳过自举验证（`make b`）
- ❌ 不要在测试失败时提交代码
- ❌ 不要删除有意义的测试（测试是回归保护）
- ❌ 不要瞎编乱造语法（参考现有代码和测试）

### 开发经验积累

每次开发获得的有用经验，应更新到技能文档 `.codebuddy/skills/uya-development.md`，包括：
- 新发现的语法规则
- 常见陷阱和解决方案
- 代码模式最佳实践

### bin/uya.c 必须提交

- 这是仓库的"种子"，新克隆者从此开始
- 每次 `make uya` 后，如自举验证通过，应提交新的 bin/uya.c
- 确保提交的 bin/uya.c 能通过 `make tests-uya`

### uya.c 备份机制

`bin/uya.c` 是自举编译器的种子文件，会被 `make clean` 删除。备份机制确保安全：

```bash
# 自动备份（make uya 完成后）
make uya        # 自动备份 bin/uya.c → backup/uya.c.zip

# 自动恢复（make from-c 时 bin/uya.c 不存在）
make from-c     # 自动从 backup/uya.c.zip 恢复

# 手动操作
make backup     # 手动备份
make restore    # 手动恢复
```

| 操作 | 说明 |
|------|------|
| `make backup` | 备份 `bin/uya.c` 到 `backup/uya.c.zip` |
| `make restore` | 从备份恢复 `bin/uya.c` |
| `make clean && make from-c` | 清理后从备份恢复构建 |

---

## 相关文档

- **回归测试说明**：[TESTING.md](./TESTING.md)
- **版本历史**：[RELEASE_*.md](./releases/)
- **语言规范**：[uya.md](./uya.md)
- **变更日志**：[changelog.md](./changelog.md)
