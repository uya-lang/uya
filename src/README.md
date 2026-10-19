# Uya 编译器 `src/` 源码说明

`src/` 是当前主线维护的 **Uya 自举编译器实现**。编译器已经完成自举，`src/` 下源码可编译出当前使用的 `bin/uya`；历史上的 `compiler-c/` 路线已退役，不再作为维护入口。

## 目录结构

主要目录与入口：

- `main.uya` - 编译器入口、CLI 与主编译流程编排
- `arena.uya` - Arena 分配器与基础内存工具
- `ast.uya` - AST 定义
- `driver/` - 宿主工具链、`@c_import` 与模块依赖收集
- `extern_decls.uya` - 外部符号声明
- `fmt.uya` - 格式化与文本输出辅助
- `lexer.uya` - 词法分析器
- `microapp/` - microapp 镜像打包、检查与目标平台处理
- `std_cfg.uya` - 平台 / 构建配置
- `version.uya` - 编译器版本号唯一来源（`UYA_VERSION`，`--version` / usage / upm 共用）
- `str_utils.uya` - 字符串工具
- `parser/` - 语法分析阶段
- `checker/` - 类型检查、可达性、泛型、证明优化等阶段
- `lower/` - 降级 / 转换阶段
- `codegen/c99/` - C99 后端
- `build/` - 单文件 C 与中间产物输出目录
- `.uyacache/`、`.uyacache-*` - 多文件 C / Makefile 中间产物目录

> `build/`、`.uyacache/`、`.uyacache-*` 都是生成目录；日常开发通常不手动提交，提交前以仓库既有 `make backup-*` 流程为准。

## 构建

### 推荐入口

从仓库根目录运行：

```bash
# 构建当前自举编译器
make uya

# 自举验证
make b
```

如果你在 `src/` 目录内调试，也可以直接使用脚本：

```bash
cd src
./compile.sh --c99 -e --safety-proof
```

### `compile.sh` 常用选项

- `-h, --help` - 显示帮助信息
- `-v, --verbose` - 详细输出模式
- `-d, --debug` - 保留中间文件
- `-o, --output DIR` - 指定输出目录
- `-n, --name NAME` - 指定输出文件名
- `-c, --clean` - 清理输出目录后再编译
- `-e, --exec` - 自动链接生成可执行文件
- `--c99` - 使用 C99 后端
- `--line-directives` - 生成 `#line` 指令
- `--nostdlib` - 以 `nostdlib` 模式链接
- `--compiler PATH` - 指定编译器路径（默认使用仓库根目录的 `bin/uya`）

## 手动编译

如果不走 `compile.sh`，可直接从仓库根目录调用当前编译器；`src/main.uya` 会自动收集依赖模块：

```bash
# 生成单文件 C（常用于 seed / 备份流程）
./bin/uya src/main.uya -o src/build/uya.c --c99

# 生成可执行文件（推荐仍通过 compile.sh / make 封装）
cd src
./compile.sh --c99 -e
```

## 依赖关系

高层依赖可概括为：

```text
main.uya
  ├─> arena.uya / ast.uya / fmt.uya / lexer.uya / std_cfg.uya / str_utils.uya / version.uya
  ├─> driver/*
  ├─> microapp/*
  ├─> parser/*
  ├─> checker/*
  ├─> lower/*
  └─> codegen/c99/*
```

实际模块会由 `main.uya` 根据 `use` 自动收集；日常不需要手工维护一长串 `src/*.uya` 顺序列表。

## 编译输出

当前主线以 **C99 后端** 为主：

- 多文件 C 模式通常输出到 `src/.uyacache/`（含 `Makefile` 与分片 `.c`）
- 单文件 C 模式通常输出到 `src/build/uya.c`、`src/build/uya-hosted.c` 等
- 最终编译器可执行文件输出到 `bin/`

日常验证与提交前流程建议使用：

```bash
# 快速自举验证
make b

# 提交前完整验证并刷新备份
make clean
make backup-all
```

## 故障排除

### 编译器不存在

如果提示 `bin/uya` 不存在，可先从 seed 冷启动：

```bash
make from-c
# 或直接完整构建
make uya
```

### 编译错误

如果遇到编译错误，可以：

1. 使用 `-v` 查看详细输出
2. 使用 `-d` 保留中间文件以便调试
3. 确认入口使用 `src/main.uya`，不要再沿用历史的 `src/*.uya` 手写列表

### 类型检查错误

如果遇到类型检查错误，优先检查：

1. 跨文件函数 / 方法签名是否一致
2. 结构体 / 联合体定义是否完整
3. `extern` 声明与调用约定是否匹配

## 当前状态

当前主线状态：

- ✅ 自举已完成
- ✅ 词法分析、语法分析、AST 合并、类型检查、C99 代码生成都在主线使用中
- ✅ `src/` 是唯一维护中的编译器实现
- ✅ 提交前验证以 `make b` / `make backup-all` 为准

更详细的项目状态以仓库根目录 `readme.md` 与 `docs/uya.md` 为准。

## 参考

- [../readme.md](../readme.md) - 项目总览与当前状态
- [../docs/uya.md](../docs/uya.md) - 完整语言规范
- [../docs/DEVELOPMENT.md](../docs/DEVELOPMENT.md) - 开发说明
- [../docs/TESTING.md](../docs/TESTING.md) - 测试与验证流程
