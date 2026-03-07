# Uya AST 格式化器详细设计

## 1. 目标

实现类似 `gofmt` 的 AST 格式化器，满足：
- **幂等性**：格式化多次结果相同
- **注释保留**：所有注释保留在正确位置
- **风格统一**：输出符合 Uya 编码规范
- **可验证**：已格式化文件再次格式化无变化

## 2. gofmt 架构分析

### 2.1 核心流程

```
源码 → Lexer (token.FileSet) → AST (带位置) → Printer → 格式化代码
         ↓                           ↓
    保留位置信息               注释挂载到节点
```

### 2.2 关键数据结构

```go
// go/token - 位置信息
type Position struct {
    Filename string
    Offset   int
    Line     int
    Column   int
}

// go/ast - 注释挂载
type CommentGroup struct {
    List []*Comment
}

type File struct {
    Comments []*CommentGroup  // 文件级注释
}

type Expr interface {
    // 节点位置由 Pos() 返回
    Pos() token.Pos
}
```

### 2.3 格式化规则

| 元素 | gofmt 规则 |
|------|-----------|
| 缩进 | Tab（宽度 8） |
| 运算符 | 前后空格 |
| 逗号 | 后面空格 |
| 大括号 | 前面空格，独占一行或同行（短块） |
| 行宽 | 无限制（依赖编辑器） |

## 3. Uya 格式化器架构

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                     uya-fmt (命令行工具)                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    src/codegen/uya/                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  main.uya   │→ │ internal.uya│→ │ printer.uya │          │
│  │  (入口)     │  │  (结构体)   │  │  (输出逻辑) │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│         │                │                │                  │
│         ▼                ▼                ▼                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  decl.uya   │  │  expr.uya   │  │  stmt.uya   │          │
│  │  (声明)     │  │  (表达式)   │  │  (语句)     │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│         │                │                │                  │
│         └────────────────┼────────────────┘                  │
│                          ▼                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                    type.uya                          │    │
│  │              (类型输出，复用 C99)                    │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 修改点

#### 3.2.1 Lexer 增强 (src/lexer.uya)

**新增字段**：
```uya
struct Lexer {
    // 现有字段...
    
    // 新增：注释收集
    comments: [&Comment: MAX_COMMENTS],
    comment_count: i32,
    current_line_comments: &Comment,  // 当前行注释链表
}

struct Comment {
    text: &byte,           // 注释内容（含 // 或 /* */）
    start_line: i32,
    start_col: i32,
    end_line: i32,
    end_col: i32,
    kind: CommentKind,     // LINE(//) 或 BLOCK(/* */)
    next: &Comment,        // 链表下一个
}
```

**修改函数**：
- `lexer_next_token()`: 解析到注释时，存入 comments 数组

#### 3.2.2 AST 增强 (src/ast.uya)

**新增字段**：
```uya
struct ASTNode {
    // 现有字段...
    
    // 新增：注释挂载
    leading_comments: &Comment,   // 节点前注释
    trailing_comments: &Comment,  // 节点后注释
    line: i32,                    // 已有，保留
    column: i32,                  // 已有，保留
}
```

#### 3.2.3 新增 Uya 后端

**目录结构**：
```
src/codegen/uya/
├── main.uya       # 入口函数
├── internal.uya   # UyaCodeGenerator 结构体
├── printer.uya    # 输出缓冲区和工具函数
├── decl.uya       # 生成声明（fn, struct, enum, use, const, var）
├── expr.uya       # 生成表达式
├── stmt.uya       # 生成语句
└── type.uya       # 生成类型（简化版）
```

## 4. 数据结构设计

### 4.1 UyaCodeGenerator

```uya
struct UyaCodeGenerator {
    // 输出缓冲区
    output: &byte,
    output_size: usize,
    output_pos: usize,
    
    // 格式化状态
    indent_level: i32,
    indent_str: &byte,        // 默认 "    " (4空格)
    at_line_start: i32,
    current_line: i32,
    
    // 注释管理
    comments: &Comment,       // 注释数组
    comment_count: i32,
    next_comment_idx: i32,    // 下一个待输出注释索引
    
    // 配置
    config: &FmtConfig,
}

struct FmtConfig {
    indent_size: i32,         // 默认 4
    max_blank_lines: i32,     // 默认 1
    use_tabs: i32,            // 默认 0（用空格）
}
```

### 4.2 输出工具函数

```uya
// 写入字符
fn write_char(gen: &UyaCodeGenerator, c: byte) void;

// 写入字符串
fn write_str(gen: &UyaCodeGenerator, s: &byte) void;

// 写入换行
fn write_newline(gen: &UyaCodeGenerator) void;

// 写入缩进
fn write_indent(gen: &UyaCodeGenerator) void;

// 确保空格（非行首时）
fn ensure_space(gen: &UyaCodeGenerator) void;

// 输出注释（在指定位置之前）
fn emit_comments_before(gen: &UyaCodeGenerator, line: i32) void;
```

## 5. 格式化规则

**详细规范见 [`UYA_STYLE_GUIDE.md`](./UYA_STYLE_GUIDE.md)**，本节仅摘要关键规则。

### 5.1 缩进

| 场景 | 规则 |
|------|------|
| 顶层声明 | 无缩进 |
| 函数体/块内 | +1 级缩进 |
| 结构体字段 | +1 级缩进 |
| 链式调用换行 | +1 级缩进 |
| match 臂 | +1 级缩进 |

### 5.2 空格

| 场景 | 规则 |
|------|------|
| 二元运算符 | 前后空格：`a + b` |
| 一元运算符 | 无空格：`-a`, `!b`, `&c` |
| 逗号后 | 空格：`foo(a, b)` |
| 冒号后 | 空格：`x: i32` |
| 分号前 | 无空格 |
| 大括号前 | 空格：`fn foo() {` |
| 小括号内 | 无空格：`foo(a)` 不写作 `foo( a )` |
| 中括号内 | 无空格：`arr[i]` |
| `.` 前后 | 无空格：`obj.field` |
| `::` 前后 | 无空格：`mod::item` |
| `->` / `=>` 前后 | 空格：`a => b` |

### 5.3 换行

| 场景 | 规则 |
|------|------|
| 声明之间 | 1 空行 |
| 函数体 `{` 后 | 换行 |
| `}` 前 | 换行 |
| 分号后 | 换行 |
| 注释后 | 换行（单行注释） |
| 长行 | 暂不自动换行（Phase 2） |

### 5.4 注释处理

```
源码位置:       1         2         3
                |---------|---------|
输入:    // comment1      // comment2
         const x = 1;     // trailing
         
AST:
  VarDecl {
    line: 2
    leading_comments: [Comment{text: "// comment1", line: 1}]
    trailing_comments: [Comment{text: "// trailing", line: 2}]
  }
  Comment {text: "// comment2", line: 2, standalone: true}

输出:
  // comment1
  const x: i32 = 1;  // trailing
  
  // comment2
```

## 6. 实现步骤

### Phase 1: Lexer 增强（注释收集）

**修改文件**: `src/lexer.uya`

1. 添加 `Comment` 结构体
2. 添加 `Lexer.comments` 数组
3. 修改 `lexer_next_token()` 识别注释并存储

**工作量**: ~100 行

### Phase 2: AST 增强（注释挂载）

**修改文件**: `src/ast.uya`, `src/parser/main.uya`

1. ASTNode 添加 `leading_comments`, `trailing_comments`
2. Parser 在创建节点时挂载注释

**工作量**: ~150 行

### Phase 3: Uya 后端实现

**新建目录**: `src/codegen/uya/`

1. `internal.uya`: 结构体定义 (~50 行)
2. `printer.uya`: 输出工具函数 (~100 行)
3. `type.uya`: 类型输出 (~80 行)
4. `decl.uya`: 声明输出 (~200 行)
5. `expr.uya`: 表达式输出 (~150 行)
6. `stmt.uya`: 语句输出 (~100 行)
7. `main.uya`: 入口 (~50 行)

**工作量**: ~730 行

### Phase 4: 集成测试

1. 修改 `src/main.uya` 添加 `--uya` 后端选项
2. 编写测试用例
3. 验证幂等性

**工作量**: ~100 行

## 7. 总工作量

| 阶段 | 工作量 | 风险 |
|------|--------|------|
| Phase 1 | ~100 行 | 低 |
| Phase 2 | ~150 行 | 中（需改核心） |
| Phase 3 | ~730 行 | 低 |
| Phase 4 | ~100 行 | 低 |
| **总计** | **~1080 行** | - |

## 8. 验收标准

### 8.1 功能测试

```uya
// 输入
export fn main( )i32{
// comment
const x:i32=1+2;
return x;}

// 输出
export fn main() i32 {
    // comment
    const x: i32 = 1 + 2;
    return x;
}
```

### 8.2 幂等性测试

```bash
./bin/uya build input.uya --uya -o /tmp/fmt1.uya
./bin/uya build /tmp/fmt1.uya --uya -o /tmp/fmt2.uya
diff /tmp/fmt1.uya /tmp/fmt2.uya  # 应该相同
```

### 8.3 注释保留测试

```uya
// 输入
// 文件头注释
const a: i32 = 1;  // 行尾注释
/* 块
   注释 */
const b: i32 = 2;

// 输出（注释位置保留）
// 文件头注释
const a: i32 = 1;  // 行尾注释

/* 块
   注释 */
const b: i32 = 2;
```

### 8.4 完整性验证（MD5 幂等测试）

**验证方法**：格式化 `src/` 目录所有文件，验证二次格式化后 MD5 一致。

```bash
#!/bin/bash
# scripts/verify_fmt.sh

set -e

SRC_DIR="src"
TMP_DIR="/tmp/uya-fmt-verify"
PASS=0
FAIL=0

echo "=== Uya FMT 幂等性验证 ==="
echo "源目录: $SRC_DIR"
echo "临时目录: $TMP_DIR"
echo ""

# 清理临时目录
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/pass1"
mkdir -p "$TMP_DIR/pass2"

# Pass 1: 格式化所有文件
echo "Pass 1: 格式化所有文件..."
for file in $(find "$SRC_DIR" -name "*.uya"); do
    rel_path="${file#$SRC_DIR/}"
    out_file="$TMP_DIR/pass1/$rel_path"
    mkdir -p "$(dirname "$out_file")"
    ./bin/uya build "$file" --uya -o "$out_file"
done

# Pass 2: 再次格式化 Pass 1 的输出
echo "Pass 2: 再次格式化..."
for file in $(find "$TMP_DIR/pass1" -name "*.uya"); do
    rel_path="${file#$TMP_DIR/pass1/}"
    out_file="$TMP_DIR/pass2/$rel_path"
    mkdir -p "$(dirname "$out_file")"
    ./bin/uya build "$file" --uya -o "$out_file"
done

# 对比 MD5
echo ""
echo "验证 MD5 一致性..."
for file in $(find "$TMP_DIR/pass1" -name "*.uya"); do
    rel_path="${file#$TMP_DIR/pass1/}"
    file2="$TMP_DIR/pass2/$rel_path"
    
    if [ -f "$file2" ]; then
        md5_1=$(md5sum "$file" | cut -d' ' -f1)
        md5_2=$(md5sum "$file2" | cut -d' ' -f1)
        
        if [ "$md5_1" = "$md5_2" ]; then
            PASS=$((PASS + 1))
            echo "  ✓ $rel_path"
        else
            FAIL=$((FAIL + 1))
            echo "  ✗ $rel_path (MD5 不一致)"
            echo "    Pass 1: $md5_1"
            echo "    Pass 2: $md5_2"
        fi
    else
        FAIL=$((FAIL + 1))
        echo "  ✗ $rel_path (文件缺失)"
    fi
done

echo ""
echo "=== 验证结果 ==="
echo "通过: $PASS"
echo "失败: $FAIL"

if [ $FAIL -eq 0 ]; then
    echo "✓ 所有文件格式化幂等性验证通过"
    exit 0
else
    echo "✗ 存在格式化幂等性问题"
    exit 1
fi
```

**预期结果**：
```
=== 验证结果 ===
通过: 48
失败: 0
✓ 所有文件格式化幂等性验证通过
```

**验证文件范围**：
- `src/*.uya` - 编译器核心模块
- `src/checker/*.uya` - 类型检查器
- `src/codegen/c99/*.uya` - C99 后端
- `src/parser/*.uya` - 解析器
- `src/core/*.uya` - 核心配置
- `lib/*.uya` - 标准库（可选）

## 9. 风险和缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Lexer 改动影响编译器 | 高 | 增量开发，保持兼容 |
| 注释挂载位置不准确 | 中 | 参考 go/ast 的 CommentMap |
| 复杂表达式格式化 | 中 | 参考 C99 后端实现 |
| 性能问题 | 低 | 使用缓冲区，避免频繁 IO |

## 10. 后续优化

- Phase 2: 长行自动换行
- Phase 3: 函数参数对齐
- Phase 4: import 分组排序
