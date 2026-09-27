# Uya 静态方法实施 TODO

> **归档/核对头（2026-09-27）**：主线语义已完成（本文件头部 2026-04-26 已自述），清单复选框未逐项回填。
>
> - 核对证据：仓库内 9 个 `tests/*static_method*` 用例覆盖 `Type.method(...)` 调用、实例方法显式 receiver、接口不支持静态方法等约束；设计文档见 `static_method_design.md`。
> - 剩余：无已知功能缺口；若需要把清单逐项回填，应按现行语义重新对照测试再勾选，不要直接按旧清单判断进度。

**设计文档**：[static_method_design.md](static_method_design.md)  
**创建日期**：2026-04-25  
**状态**：主线已完成（2026-04-26 回填状态；历史清单未逐项补打全部复选框）

本 TODO 与 [static_method_design.md](static_method_design.md) 配合使用：设计文档负责定义“静态方法是什么、语义边界在哪里”，本文档负责定义“按什么顺序落地、改哪些文件、补哪些测试”。

2026-04-26 更新：

- 已完成统一方法命名空间调用：`Type.method(...)` 可调用静态方法，也可在实例方法场景中显式传入 receiver。
- 已完成实例语法糖约束：`obj.method(...)` 仍只匹配首参为实例 receiver 的方法。
- 已完成调用链收口：结构体字面量、括号表达式、数组下标结果、泛型方法返回值都可继续链式调用。
- 已落地回归：`test_static_method_struct.uya`、`test_static_method_generic_struct.uya`、`test_static_method_generic_method.uya`、`test_static_method_union.uya`、`test_struct_method_chain.uya` 以及多条误用负例均已在主测试集中通过。
- 已完成自举与回归验证：`make b`、`make tests-uya` 通过。

---

## 1. 范围与结论

本轮要落地的静态方法方案是：

- 公开语法使用 `Type.method(...)`
- 不引入双冒号写法
- 不引入 `impl`
- 不引入函数重载
- 静态方法定义在结构体/联合体内部或外部方法块中
- 接口不支持静态方法

---

## 2. 目标验收

全部完成后，应满足：

- `Type.method(...)` 可以调用结构体静态方法
- `Type<T>.method(...)` 可以调用泛型类型静态方法
- 静态泛型方法 `Type.method<U>(...)` 可用
- `@async_fn` 静态方法可用
- `obj.method(...)` 仍只匹配实例方法
- 方法返回值可继续无限制后缀链：`Type.make().next().done()`、`obj.method<T>().next()`
- 同一类型里静态/实例同名会报错
- 接口静态方法签名报错
- 联合体静态方法与变体名冲突报错
- 语法文档与主规范已同步更新
- `make tests` 与 `--uya --c99` 对应回归通过

---

## 3. 分阶段实施

## Phase 0：文档与语义冻结

- [ ] 评审 [static_method_design.md](static_method_design.md) 并冻结 v1 语义
- [ ] 明确 `Type.method(...)` 为唯一公开语法
- [ ] 明确接口不支持静态方法
- [ ] 明确联合体静态方法不得与变体重名
- [ ] 明确同一 owner 类型不允许静态/实例同名

交付标准：

- 设计文档通过评审
- 后续实现不再讨论是否引入双冒号写法

---

## Phase 1：Checker 基础设施

### 目标

给编译器一个稳定的“方法分类”基础，不再在多个调用点靠“默认首参就是 receiver”猜测。

### 文件

- `src/checker/lookup.uya`
- `src/checker/check_stmt.uya`
- `src/checker/check_call.uya`
- `src/checker/check_expr.uya`

### 任务

- [ ] 新增统一 helper：
  - `checker_fn_decl_has_receiver(...)`
  - `checker_fn_decl_is_static_method(...)`
  - 或等价的 receiver 分类函数
- [ ] 统一 receiver 判定规则：
  - `self: &Self`
  - `self: &StructName`
  - `self: &UnionName`
  - `drop(self: T)` 特例
- [ ] 若首参名为 `self` 但类型不是合法 receiver，直接报错
- [ ] 补齐“静态/实例同名冲突”校验
- [ ] 补齐“接口方法必须有 receiver”校验
- [ ] 补齐“联合体静态方法与变体名冲突”校验

交付标准：

- checker 能可靠区分实例方法和静态方法
- 不合法签名在定义期直接报错，而不是拖到调用期

---

## Phase 2：类型命名空间调用解析

### 目标

让 `Type.method(...)` 在 checker 中被识别为“静态方法调用”，而不是模块访问、字段访问或错误的实例方法调用。

### 文件

- `src/checker/check_call.uya`
- `src/checker/check_expr.uya`
- 必要时：`src/checker/symbols.uya`

### 任务

- [ ] 在 `AST_CALL_EXPR` 路径中识别“callee 是 member access，且 object 是类型名”的场景
- [ ] 为结构体静态方法接入参数个数检查
- [ ] 为联合体静态方法接入参数个数检查
- [ ] 为静态泛型方法接入类型参数个数与约束检查
- [ ] 让返回类型推断支持静态方法
- [ ] `Type.method(...)` 调用实例方法时报清晰错误
- [ ] `obj.method(...)` 调用静态方法时报清晰错误

### 判定顺序建议

- [ ] 左侧是值表达式：字段 / 实例方法 / 接口方法
- [ ] 左侧是模块：模块导出项
- [ ] 左侧是类型：联合体变体构造 / 静态方法

交付标准：

- `Type.method(...)` 在 checker 中可稳定通过
- 错误路径有明确诊断

---

## Phase 3：Parser 补口（仅在需要时）

### 目标

尽量不改公开语法，但如果当前 parser 对 `Type<T>.method(...)` 的 AST 保真不足，则做最小修补。

### 文件

- `src/parser/primary.uya`
- 必要时：`src/ast.uya`

### 任务

- [ ] 验证 `Type.method(...)` 是否已能用现有 `AST_MEMBER_ACCESS + AST_CALL_EXPR` 表达
- [ ] 验证 `Type<T>.method(...)` 的类型实参是否会丢失
- [ ] 若类型对象在 member access 中被错误降级，补最小 parser 修复
- [ ] 不新增双冒号 token
- [ ] 不新增公开关键字

交付标准：

- 现有语法即可正确承载静态方法调用
- `Type<T>.method(...)` 的 AST 可被 checker/codegen 使用

---

## Phase 4：C99 Codegen

### 目标

让静态方法沿用“方法降级为普通函数”的现有模型，但调用时不再偷偷插入 receiver。

### 文件

- `src/codegen/c99/expr.uya`
- `src/codegen/c99/function.uya`
- `src/codegen/c99/structs.uya`
- 必要时：`src/codegen/c99/main.uya`

### 任务

- [ ] `gen_call_expr` 支持类型命名空间静态方法调用
- [ ] 结构体静态方法调用生成 `uya_Type_method(...)`
- [ ] 联合体静态方法调用生成 `uya_Type_method(...)`
- [ ] 实例方法调用继续生成 `uya_Type_method(&obj, ...)`
- [ ] 方法原型生成允许“无 receiver 首参”
- [ ] 方法定义生成允许“无 receiver 首参”
- [ ] 泛型 owner + 泛型方法叠加单态继续可达
- [ ] `@async_fn` 静态方法接入 async lowering

### 特别注意

- [ ] 不要破坏现有实例方法 codegen
- [ ] 不要破坏接口方法 vtable
- [ ] 静态方法不进入 vtable 常量生成
- [ ] 不要影响联合体变体构造 `UnionName.variant(...)`

交付标准：

- 生成的 C 名字符合当前方法命名规则
- 静态方法与实例方法都能正确发射

---

## Phase 5：测试

### 新增正例

- [ ] `tests/test_static_method_struct.uya`
  - `Engine.new()`
  - 结构体内部静态方法
  - 外部方法块静态方法
- [ ] `tests/test_static_method_generic_struct.uya`
  - `Vec<i32>.with_capacity(...)`
- [ ] `tests/test_static_method_generic_method.uya`
  - `Cast.to<i64>(...)`
- [ ] `tests/test_static_method_async.uya`
  - `@async_fn` 静态方法
- [ ] `tests/test_static_method_union.uya`
  - 联合体静态方法，且不与变体重名

### 新增反例

- [ ] `tests/error_static_method_called_via_instance.uya`
- [ ] `tests/error_instance_method_called_via_type.uya`
- [ ] `tests/error_static_method_name_conflict.uya`
- [ ] `tests/error_static_method_bad_self_param.uya`
- [ ] `tests/error_interface_static_method.uya`
- [ ] `tests/error_union_static_method_variant_conflict.uya`

### 回归重点

- [ ] 现有结构体方法测试不退化
- [ ] 现有联合体方法测试不退化
- [ ] 现有接口方法测试不退化
- [ ] 现有泛型方法测试不退化
- [ ] 现有 async 方法测试不退化

交付标准：

- 新增正反例都稳定通过
- 相关旧回归无新增失败

---

## Phase 6：规范、语法文档与变更日志同步

### 文件

- `docs/uya.md`
- `docs/grammar_quick.md`
- `docs/grammar_formal.md`
- `docs/changelog.md`

### 任务

- [ ] 在 `uya.md` 方法章节增加“静态方法”小节
- [ ] 明确公开写法是 `Type.method(...)`
- [ ] 明确接口不支持静态方法
- [ ] 更新语法速查文档 `docs/grammar_quick.md`，补充静态方法定义与调用示例
- [ ] 更新正式语法文档 `docs/grammar_formal.md`，明确方法签名中“有 receiver / 无 receiver”的区分规则
- [ ] 必要时补 `docs/uya.md` 中与方法语法相关的示例和约束说明，避免主手册与语法文档脱节
- [ ] changelog 记录该能力与限制
- [ ] 检查仓库内是否还有把双冒号写法当公开语法的文档

交付标准：

- 主手册、语法速查、正式语法、变更日志四处一致
- 用户只看语法文档也能理解静态方法的定义与调用方式
- 用户阅读主手册即可理解静态方法

---

## 4. 按文件细分 TODO

## `src/checker/lookup.uya`

- [ ] 增加支持“按名称查找静态方法/实例方法”的过滤 helper
- [ ] 避免现有 `find_method_in_struct` 只按名字返回、导致静态/实例混淆

## `src/checker/check_stmt.uya`

- [ ] 方法定义期做签名合法性校验
- [ ] 方法块 / 结构体内部定义都走同一套校验
- [ ] 接口实现完备性检查忽略静态方法

## `src/checker/check_call.uya`

- [ ] 静态方法实参个数检查
- [ ] 静态泛型方法类型参数检查
- [ ] “类型调用实例方法”报错
- [ ] “实例调用静态方法”报错

## `src/checker/check_expr.uya`

- [ ] 静态方法返回类型推断
- [ ] `Type<T>.method(...)` 推断
- [ ] 联合体变体构造与静态方法分流

## `src/parser/primary.uya`

- [ ] 验证并补齐 `Type<T>.method(...)` AST 保真

## `src/codegen/c99/expr.uya`

- [ ] 静态方法调用发射
- [ ] 不隐式插入 receiver

## `src/codegen/c99/function.uya`

- [ ] 方法原型和定义允许零 receiver
- [ ] 泛型静态方法与 async 静态方法继续可达

## `src/codegen/c99/structs.uya`

- [ ] lookup helper 支持区分静态/实例
- [ ] 不影响现有 vtable / interface 生成

---

## 5. 建议实施顺序

1. 先做 checker 的方法分类与定义期报错  
2. 再做 `Type.method(...)` 的调用解析  
3. 再补 parser 保真问题（如果真的需要）  
4. 再做 C99 codegen  
5. 最后补测试与规范文档

原因：

- 如果没有统一的“方法分类”，后面 checker 和 codegen 很容易各写一套规则
- 定义期报错先落地，最容易收缩语义边界
- parser 很可能只需最小补丁，没必要一开始就大动

---

## 6. 风险清单

- [ ] 现有 `find_method_in_struct` / `find_method_in_union` 只按名字返回，容易误把静态方法当实例方法
- [ ] `Type<T>.method(...)` 的 AST 可能不完整，导致 checker/codegen 拿不到类型实参
- [ ] 联合体静态方法可能与变体构造路径冲突
- [ ] async 静态方法若沿用实例方法假设，可能在 lowering 时错误地期待 receiver
- [ ] 现有文档中少量旧示例可能继续误导用户使用非正式写法

---

## 7. 收尾项

- [ ] `make b`
- [ ] `make tests`
- [ ] 相关 `--uya --c99` 回归单独跑一轮
- [ ] 文档中的示例与测试名一一对应
- [ ] TODO 状态回填

---

## 8. 后续可选迁移

静态方法能力落地后，可选评估以下标准库迁移项：

- [ ] `uyagin_new()` 增加等价 `Engine.new()`
- [ ] `router_new()` 增加等价 `Router.new()`
- [ ] `scheduler_new()` 增加等价 `Scheduler.new()`
- [ ] `async_fd_new(fd)` 评估是否改成 `AsyncFd.from_fd(fd)`

这些迁移不属于本 TODO 的阻塞项。
