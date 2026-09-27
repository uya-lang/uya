# @asm 实施检查清单（基准验证）

> **核对头（2026-09-27）**：`@asm` 已完成，本文件属历史过程记录。现状与证据见 `docs/ASM_TODO.md` 的核对头与 `docs/todo_status_index.md`。

**创建日期**：2026-02-23  
**目的**：每个实施步骤都有明确的验收标准，确保可基准实施

---

## ✅ 预实施检查清单

### 环境验证
- [ ] **编译器可用**：`bin/uya --version` 成功
- [ ] **自举验证**：`make check` 全部通过
- [ ] **测试环境**：`make tests` 全部通过
- [ ] **备份存在**：`backup/uya.c` 存在

### 代码状态
- [ ] **工作目录干净**：`git status` 无未提交修改
- [ ] **最新代码**：`git log` 确认最新提交
- [ ] **文档完整**：
  - [ ] `docs/asm_design.md` 已阅读
  - [ ] `docs/asm_implementation_plan.md` 已阅读
  - [ ] `docs/asm_api_reference.md` 已阅读

---

## 📋 第一阶段：基础架构检查清单

### Day 1-2：Lexer 和 AST

#### ✅ Task 1.1：Lexer 支持 @asm

**实施步骤**：
- [ ] 1. 确认 TOKEN_AT_IDENTIFIER 已存在（`src/lexer.uya` 第 48 行）
- [ ] 2. 确认无需修改 TokenType 枚举
- [ ] 3. 在 Parser 中添加 @asm 识别逻辑

**验证命令**：
```bash
# 验证 1：Lexer 能识别 @asm
cat > /tmp/test_lexer_asm.uya << 'EOF'
@asm { "nop" (); }
EOF
bin/uya --lex-only /tmp/test_lexer_asm.uya 2>&1 | grep "TOKEN_AT_IDENTIFIER.*asm"
# 预期输出：包含 "TOKEN_AT_IDENTIFIER" 和 "asm"

# 验证 2：不影响其他内置函数
cat > /tmp/test_lexer_builtins.uya << 'EOF'
const x: i32 = @size_of(i32);
const y: i32 = @align_of(i32);
const z: i32 = @len(arr);
EOF
bin/uya --lex-only /tmp/test_lexer_builtins.uya 2>&1 | grep "TOKEN_AT_IDENTIFIER"
# 预期输出：包含所有内置函数
```

**通过标准**：
- [ ] Lexer 输出包含 `TOKEN_AT_IDENTIFIER "asm"`
- [ ] 无编译错误或警告
- [ ] 其他内置函数识别正常

---

#### ✅ Task 1.2：AST 添加 AST_ASM 节点

**实施步骤**：
- [ ] 1. 在 `src/ast.uya` 第 46-100 行添加 `AST_ASM` 到枚举
- [ ] 2. 在 `src/ast.uya` 第 130-156 行添加 @asm 字段到结构体
- [ ] 3. 运行 `make check` 验证编译器自身能编译

**修改点验证**：
```bash
# 验证 1：ASTNodeType 枚举
grep -n "AST_ASM" src/ast.uya
# 预期输出：显示 AST_ASM 的行号

# 验证 2：ASTNode 字段
grep -n "asm_instructions" src/ast.uya
grep -n "asm_inputs" src/ast.uya
grep -n "asm_outputs" src/ast.uya
# 预期输出：显示所有新增字段的行号
```

**编译验证**：
```bash
# 验证 3：编译器自身能编译
make clean
make uya
# 预期：编译成功，无错误无警告

# 验证 4：自举通过
make check
# 预期：自举验证通过
```

**通过标准**：
- [ ] `AST_ASM` 枚举值已添加
- [ ] 8 个 `asm_*` 字段已添加
- [ ] 编译器自身能成功编译
- [ ] `make check` 通过

---

#### ✅ Task 1.3：Parser 实现基础解析

**实施步骤**：
- [ ] 1. 在 `src/parser/primary.uya` 中添加 `parser_parse_asm_block` 函数
- [ ] 2. 在 `parser_parse_primary_expr` 中添加 @asm 识别分支
- [ ] 3. 实现指令字符串解析
- [ ] 4. 实现输入输出列表解析
- [ ] 5. 测试解析功能

**验证命令**：
```bash
# 验证 1：解析简单 @asm 块
cat > /tmp/test_parse_simple.uya << 'EOF'
fn test() void {
    @asm { "nop" (); }
}
EOF
bin/uya --parse-only /tmp/test_parse_simple.uya
# 预期：解析成功，无错误

# 验证 2：解析带参数的 @asm 块
cat > /tmp/test_parse_params.uya << 'EOF'
fn test() void {
    var x: i32 = 10;
    var y: i32 = 20;
    @asm { "add {x}, {y}" (x, y, -> x); }
}
EOF
bin/uya --parse-only /tmp/test_parse_params.uya
# 预期：解析成功，无错误

# 验证 3：解析多条指令
cat > /tmp/test_parse_multi.uya << 'EOF'
fn test() void {
    var x: i32 = 0;
    @asm {
        "mov {x}, 10" (-> x);
        "add {x}, 5" (x, -> x);
    }
}
EOF
bin/uya --parse-only /tmp/test_parse_multi.uya
# 预期：解析成功，无错误

# 验证 4：错误处理
cat > /tmp/test_parse_error.uya << 'EOF'
fn test() void {
    @asm { "nop" (;  // 缺少右括号
}
EOF
bin/uya --parse-only /tmp/test_parse_error.uya 2>&1 | grep "错误"
# 预期：显示错误信息
```

**通过标准**：
- [ ] 简单 @asm 块解析成功
- [ ] 带参数的 @asm 块解析成功
- [ ] 多条指令解析成功
- [ ] 错误情况有清晰提示
- [ ] `make check` 通过

---

### Day 3-4：类型检查

#### ✅ Task 1.4：Checker 基础类型检查

**实施步骤**：
- [ ] 1. 在 `src/checker/check_expr.uya` 中添加 `check_asm_block` 函数
- [ ] 2. 实现 `is_valid_asm_input_type` 辅助函数
- [ ] 3. 实现 `is_valid_asm_output_type` 辅助函数
- [ ] 4. 实现 `is_lvalue` 辅助函数
- [ ] 5. 在 `check_expression` 中添加 AST_ASM 分支
- [ ] 6. 测试类型检查

**验证命令**：
```bash
# 验证 1：有效类型通过
cat > /tmp/test_check_valid.uya << 'EOF'
fn test() void {
    var x: i32 = 10;
    var y: i64 = 20;
    var z: u32 = 30;
    @asm { "nop" (); }
    @asm { "add" (x, -> x); }
    @asm { "add" (y, -> y); }
    @asm { "add" (z, -> z); }
}
EOF
bin/uya --check-only /tmp/test_check_valid.uya
# 预期：类型检查通过，无错误

# 验证 2：无效类型被拒绝
cat > /tmp/test_check_invalid.uya << 'EOF'
fn test() void {
    var x: f32 = 3.14;
    @asm { "add" (x, -> x); }  // 错误：浮点数
}
EOF
bin/uya --check-only /tmp/test_check_invalid.uya 2>&1 | grep "类型无效"
# 预期：显示类型错误

# 验证 3：左值检查
cat > /tmp/test_check_lvalue.uya << 'EOF'
fn test() void {
    var x: i32 = 10;
    @asm { "mov" (-> x + 1); }  // 错误：x + 1 不是左值
}
EOF
bin/uya --check-only /tmp/test_check_lvalue.uya 2>&1 | grep "左值"
# 预期：显示左值错误
```

**通过标准**：
- [ ] 有效类型（i32, i64, u32, u64）通过检查
- [ ] 无效类型（f32, f64）被拒绝
- [ ] 左值检查正确
- [ ] 错误提示清晰
- [ ] `make check` 通过

---

### Day 5：代码生成

#### ✅ Task 1.5：Codegen 基础生成

**实施步骤**：
- [ ] 1. 在 `src/codegen/c99/expr.uya` 中添加 `gen_asm_block` 函数
- [ ] 2. 实现临时变量生成
- [ ] 3. 实现内联汇编生成
- [ ] 4. 在 `gen_expression` 中添加 AST_ASM 分支
- [ ] 5. 测试代码生成

**验证命令**：
```bash
# 验证 1：生成 C 代码
cat > /tmp/test_codegen_simple.uya << 'EOF'
export fn main() i32 {
    var x: i32 = 10;
    @asm { "add %0, 5" (x, -> x); }
    return x;
}
EOF
bin/uya --c99 /tmp/test_codegen_simple.uya -o /tmp/test_codegen_simple.c
cat /tmp/test_codegen_simple.c | grep "__asm__"
# 预期：生成的 C 代码包含 __asm__ 块

# 验证 2：编译生成的 C 代码
gcc -Wall -Werror /tmp/test_codegen_simple.c -o /tmp/test_codegen_simple
# 预期：GCC 编译成功，无警告

# 验证 3：运行程序
/tmp/test_codegen_simple
echo $?
# 预期：输出 15

# 验证 4：复杂示例
cat > /tmp/test_codegen_complex.uya << 'EOF'
export fn main() i32 {
    var x: i32 = 10;
    var y: i32 = 20;
    @asm {
        "add %0, %1" (x, y, -> x);
    }
    return x;
}
EOF
bin/uya --c99 /tmp/test_codegen_complex.uya -o /tmp/test_codegen_complex.c
gcc /tmp/test_codegen_complex.c -o /tmp/test_codegen_complex
/tmp/test_codegen_complex
echo $?
# 预期：输出 30
```

**代码审查**：
```bash
# 检查生成的 C 代码格式
cat /tmp/test_codegen_simple.c | head -30

# 检查临时变量命名
grep "_uya_asm_" /tmp/test_codegen_simple.c
# 预期：所有临时变量都有 _uya_asm_ 前缀

# 检查注释
grep "@asm 块" /tmp/test_codegen_simple.c
# 预期：有清晰的注释标记
```

**通过标准**：
- [ ] 生成的 C 代码包含正确的 __asm__ 块
- [ ] GCC 编译成功，无警告
- [ ] 程序运行结果正确
- [ ] 临时变量命名规范
- [ ] 代码有清晰注释
- [ ] `make check` 通过

---

## 🎯 第一阶段完整验收

### 功能验收测试

**测试脚本**：
```bash
#!/bin/bash
# stage1_acceptance_test.sh

echo "=== 第一阶段验收测试 ==="

# 测试 1：编译器自举
echo "测试 1: 编译器自举"
make clean && make check
if [ $? -ne 0 ]; then
    echo "❌ 自举失败"
    exit 1
fi
echo "✅ 自举通过"

# 测试 2：简单 @asm 功能
echo "测试 2: 简单 @asm 功能"
cat > /tmp/test_stage1.uya << 'EOF'
export fn main() i32 {
    var x: i32 = 10;
    @asm { "add %0, 5" (x, -> x); }
    return x;
}
EOF
bin/uya --c99 /tmp/test_stage1.uya -o /tmp/test_stage1.c
gcc /tmp/test_stage1.c -o /tmp/test_stage1
result=$(/tmp/test_stage1; echo $?)
if [ "$result" -eq 15 ]; then
    echo "✅ 简单 @asm 功能正常"
else
    echo "❌ 简单 @asm 功能异常：期望 15，实际 $result"
    exit 1
fi

# 测试 3：多条指令
echo "测试 3: 多条指令"
cat > /tmp/test_stage1_multi.uya << 'EOF'
export fn main() i32 {
    var x: i32 = 0;
    @asm {
        "mov %0, 10" (-> x);
        "add %0, 5" (x, -> x);
    }
    return x;
}
EOF
bin/uya --c99 /tmp/test_stage1_multi.uya -o /tmp/test_stage1_multi.c
gcc /tmp/test_stage1_multi.c -o /tmp/test_stage1_multi
result=$(/tmp/test_stage1_multi; echo $?)
if [ "$result" -eq 15 ]; then
    echo "✅ 多条指令功能正常"
else
    echo "❌ 多条指令功能异常：期望 15，实际 $result"
    exit 1
fi

# 测试 4：类型检查
echo "测试 4: 类型检查"
cat > /tmp/test_stage1_type.uya << 'EOF'
fn test() void {
    var x: f32 = 3.14;
    @asm { "add" (x, -> x); }
}
EOF
bin/uya --check-only /tmp/test_stage1_type.uya 2>&1 | grep -q "类型无效"
if [ $? -eq 0 ]; then
    echo "✅ 类型检查正常"
else
    echo "❌ 类型检查异常：应该拒绝浮点数"
    exit 1
fi

echo "=== 第一阶段验收测试通过 ✅ ==="
```

**运行验收测试**：
```bash
chmod +x stage1_acceptance_test.sh
./stage1_acceptance_test.sh
```

### 交付物检查清单

- [ ] **代码修改**：
  - [ ] `src/ast.uya` 已修改并提交
  - [ ] `src/parser/primary.uya` 已修改并提交
  - [ ] `src/checker/check_expr.uya` 已修改并提交
  - [ ] `src/codegen/c99/expr.uya` 已修改并提交

- [ ] **测试用例**：
  - [ ] `tests/programs/test_asm_basic.uya` 已创建
  - [ ] 所有测试通过

- [ ] **文档更新**：
  - [ ] `docs/asm_api_reference.md` 已更新
  - [ ] `CHANGELOG.md` 已更新

- [ ] **验收通过**：
  - [ ] 自举验证通过（`make check`）
  - [ ] 所有测试通过（`make tests`）
  - [ ] 验收测试脚本通过
  - [ ] 代码审查通过

- [ ] **备份**：
  - [ ] `make backup` 成功执行
  - [ ] `backup/uya.c` 已更新

---

## 📊 进度追踪表

### 每日进度记录

| 日期 | 任务 | 状态 | 问题 | 解决方案 |
|------|------|------|------|----------|
| Day 1 | Lexer + AST | [ ] | | |
| Day 2 | Lexer + AST | [ ] | | |
| Day 3 | Parser | [ ] | | |
| Day 4 | Checker | [ ] | | |
| Day 5 | Codegen | [ ] | | |

### 问题追踪表

| 问题编号 | 问题描述 | 严重程度 | 状态 | 解决日期 |
|----------|----------|----------|------|----------|
| | | | | |

---

## 🎯 验收标准总结

### 必须满足（P0）
- [x] 编译器自身能成功自举（`make check`）
- [x] 所有现有测试通过（`make tests`）
- [x] 简单 @asm 块能正确解析、编译、运行
- [x] 类型检查能拒绝无效类型
- [x] 生成的 C 代码无 GCC 警告

### 应该满足（P1）
- [x] 错误提示清晰易懂
- [x] 代码有详细注释
- [x] 测试覆盖率 > 80%

### 可以满足（P2）
- [ ] 支持复杂的嵌套表达式
- [ ] 支持指令字符串转义
- [ ] 优化代码生成性能

---

## 📝 回滚计划

### 如果实施失败

**步骤 1**：停止所有修改
```bash
git status  # 查看当前修改
```

**步骤 2**：回滚到上一个稳定版本
```bash
git checkout .
git clean -fd
```

**步骤 3**：恢复备份
```bash
make restore
make check
```

**步骤 4**：分析失败原因
- 检查错误日志
- 回顾修改点
- 识别风险点

**步骤 5**：重新规划
- 调整实施方案
- 降低风险
- 重新开始

---

**最后更新**：2026-02-23  
**下次审查**：每完成一个主要任务后  
**维护者**：Uya 开发团队
