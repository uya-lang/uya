# Uya v0.2.17 版本说明

**发布日期**：2026-02-01

本版本完成 **联合体方法（union methods）** 在自举编译器（uya-src）中的完整支持。联合体方法在 C 版编译器中已于此前实现，本次将方法块解析、类型检查与代码生成同步至 uya-src，使外部方法块与内部方法在 `--uya --c99` 下均可用。全量 220 个测试在 `--uya` 下通过。

---

## 核心亮点

### 1. 联合体方法自举同步完成

- **外部方法块**：`UnionName { fn method(self: &Self) Ret { ... } }`，方法块对应联合体时正确识别并生成 `struct uya_tagged_UnionName *` 签名
- **内部方法**：`union U { v: T, fn method(self: &Self) Ret { ... } }`，联合体内部方法的前向声明与定义由 codegen 正确输出
- **Self 类型**：联合体方法的 `self` 参数与 `*self` 类型为 `struct uya_tagged_UnionName *` / `struct uya_tagged_UnionName`，与 C 版一致

### 2. uya-src 模块变更

| 模块 | 变更 |
|------|------|
| codegen/c99/main.uya | 方法块类型名取 struct/union 二者其一；联合体内部方法原型与定义生成 |
| codegen/c99/types.uya | c99_type_to_c_with_self_opt 联合体用 uya_tagged_ 前缀；get_c_type_of_expr 支持 AST_UNARY_EXPR、AST_CAST_EXPR |

### 3. 测试验证

- **test_union_method.uya**：外部方法块 `IntOrFloat { fn as_f64, fn is_int }`，通过 `--c99` 与 `--uya --c99`
- **test_union_inner_method.uya**：联合体内部方法，通过 `--c99` 与 `--uya --c99`
- **全量**：220 个测试在 `--uya` 下全部通过

---

## 技术细节

### 方法块与联合体类型名（main.uya）

- 生成方法块原型与定义时，类型名取 `method_block_struct_name != null ? method_block_struct_name : method_block_union_name`，联合体方法块在 checker 中已置为 `union_name`，故能正确生成 `uya_UnionName_method` 系列函数
- 联合体声明分支：在「前向声明」循环中为 `AST_UNION_DECL` 生成内部方法原型；在「定义」循环中为联合体内部方法调用 `gen_method_function`

### Self 与表达式类型（types.uya）

- **c99_type_to_c_with_self_opt**：通过 `find_union_decl_c99(codegen, self_struct_name)` 判断是否为联合体；联合体时 Self 生成为 `struct uya_tagged_%s *` / `const struct uya_tagged_%s *`，避免 C 端「wrong kind of tag」错误
- **get_c_type_of_expr**：
  - **AST_UNARY_EXPR**（如 `*self`）：op 为 `TOKEN_ASTERISK` 时，从操作数类型字符串去掉 `*` 得到被指类型，使 match 临时变量 `_uya_m` 为 `struct uya_tagged_IntOrFloat` 而非 `int32_t`
  - **AST_CAST_EXPR**（如 `x as f64`）：返回 `c99_type_to_c(codegen, target_type)`，保证 match 结果类型正确

---

## 测试验证

- **C 版编译器（`--c99`）**：test_union.uya、test_union_method.uya、test_union_inner_method.uya 通过
- **自举版编译器（`--uya --c99`）**：上述三个联合体相关测试通过
- **全量**：`./tests/run_programs.sh --uya` 共 220 个测试，通过 220，失败 0
- **自举构建**：`./compile.sh --c99 -e` 成功

---

## 文件变更统计（自 v0.2.16 以来）

**自举实现（uya-src）**：

- `compiler-mini/uya-src/codegen/c99/main.uya` — 方法块 type_name 取 struct/union；联合体内部方法原型与定义
- `compiler-mini/uya-src/codegen/c99/types.uya` — 联合体 Self → uya_tagged_；get_c_type_of_expr 支持 UNARY_EXPR、CAST_EXPR

**测试**（已存在，本版确保自举通过）：

- `compiler-mini/tests/programs/test_union_method.uya`
- `compiler-mini/tests/programs/test_union_inner_method.uya`

---

## 版本对比

### v0.2.16 → v0.2.17 变更

- **新增/完成**：
  - ✅ 联合体方法自举同步：外部方法块与内部方法在 uya-src 中完整支持
  - ✅ 联合体方法 Self 与 `*self` 类型正确生成（uya_tagged_ 前缀）
  - ✅ match 中 `*self` 及 `x as f64` 等表达式类型推断修复，消除错误临时变量类型与链接错误
  - ✅ 全量 220 个测试在 `--uya` 下通过

- **非破坏性**：纯自举同步与类型/代码生成修复，无 API 或规范变更

---

## 使用示例

### 联合体外部方法块

```uya
union IntOrFloat {
    i: i32,
    f: f64,
}

IntOrFloat {
    fn as_f64(self: &Self) f64 {
        return match *self {
            .i(x) => x as f64,
            .f(x) => x,
        };
    }
    fn is_int(self: &Self) bool {
        return match *self {
            .i(_) => true,
            .f(_) => false,
        };
    }
}

fn main() i32 {
    const vi: IntOrFloat = IntOrFloat.i(42);
    const as_float: f64 = vi.as_f64();
    return 0;
}
```

### 联合体内部方法

```uya
union IntOrFloat {
    i: i32,
    f: f64,
    fn as_f64(self: &Self) f64 {
        return match *self {
            .i(x) => x as f64,
            .f(x) => x,
        };
    }
}
```

---

## 下一步计划

- **联合体扩展**：extern union、更多方法/接口能力
- **模块系统**：目录即模块、export/use 语法
- **原子类型**：atomic T、&atomic T

---

## 相关资源

- **语言规范**：`uya.md`（§4.5 联合体、联合体方法）
- **语法规范**：`grammar_formal.md`
- **实现文档**：`compiler-mini/spec/UYA_MINI_SPEC.md`
- **测试用例**：`compiler-mini/tests/programs/test_union*.uya`

---

**本版本完成联合体方法在自举编译器中的完整支持，C 版与 uya-src 行为一致，全量测试通过。**
