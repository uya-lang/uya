# 阶段10：将 C99 编译器翻译成 Uya（未来）

## 10.0 规范扩展准备

在进行自举重构之前，需要扩展 Uya Mini 规范以支持编译器实现所需的功能。

**参考文档**：`TODO_uya_mini_extension.md` - 详细的规范扩展任务清单

**关键扩展特性**（P0 优先级）：
- [ ] 指针类型 (`&T` 和 `*T`)
- [ ] 固定大小数组 (`[T: N]`)
- [ ] `sizeof` 内置函数
- [ ] `extern` 函数指针参数支持

## 10.1 分析 C99 代码

- [ ] 识别需要转换的 C 特性
- [ ] 规划 Uya 语法表达方式
- [ ] 参考 `TODO_uya_mini_extension.md` 确认所需语言特性

## 10.2 逐步翻译

- [ ] Arena 分配器 → Uya
- [ ] Lexer → Uya
- [ ] Parser → Uya
- [ ] Checker → Uya
- [ ] CodeGen → Uya（调用 LLVM C API）
- [ ] Main → Uya

## 10.3 自举测试

- [ ] 使用 Uya 编译器编译自身
- [ ] 验证自举成功

