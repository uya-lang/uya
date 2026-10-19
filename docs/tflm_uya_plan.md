# TFLM 纯 Uya 实现 — 计划索引

> **核对头（2026-10-19）**：`lib/tflm/` 实际共 10 个 `.uya`：9 个符合本文约定的 `<模块>/<模块>.uya`（common / model / arena / tensor / resolver / interpreter / kernels / quant / backend），另加设计与本文都提到的 `backend/arm.uya`；模块路径即「`lib/tflm/<名>/<名>.uya` → `use tflm.<名>`」。下面「与 TFLM 的对应关系」表的左列原先写成 `lib/tflm/model.uya`（缺一层目录），已按实际路径修正。

本页为 TensorFlow Lite Micro 风格嵌入式推理引擎的**纯 Uya 实现**在 Uya 仓库中的计划与文档入口。

---

## 文档

- **[tflm_uya_design.md](tflm_uya_design.md)** — 详细设计：目标与约束、总体架构、模型/内存/算子/解释器各层接口与数据结构、数据流、测试策略、路线图与风险。
- **[tflm_uya_todo.md](tflm_uya_todo.md)** — 待办清单：阶段 1～3 的任务项、验收标准与依赖。

---

## 约定

- **库根目录**：`lib/tflm/`。**模块路径**：`UYA_ROOT=lib/` 时须为 `lib/tflm/<名>/<名>.uya` → `use tflm.<名>`（例：`lib/tflm/common/common.uya` → `use tflm.common`，`lib/tflm/kernels/kernels.uya` → `use tflm.kernels`）。
- **测试位置**：`tests/` 根目录，文件命名 `test_tflm_*.uya`；需通过 `--c99` 与 `--uya --c99`（见 [.cursorrules](../.cursorrules)）。
- **验证**：所有 `test_tflm_*.uya` 需通过 `./tests/run_programs_parallel.sh --c99` 与 `--uya --c99`（`test_tflm_cmsis` 额外链接 `tests/tflm_cmsis_host_stub.c`，脚本与 `tests/Makefile` 已配置）。

---

## 与 TFLM 的对应关系

| 本库模块           | TFLM 对应                    |
|--------------------|-----------------------------|
| `lib/tflm/model/model.uya` | 模型加载、FlatBuffer 解析（**当前为线性 stub `ModelPlan`**） |
| `lib/tflm/arena/arena.uya` | MicroAllocator / 张量 Arena |
| `lib/tflm/tensor/tensor.uya` | TfLiteTensor 视图 |
| `lib/tflm/resolver/resolver.uya` | MicroMutableOpResolver |
| `lib/tflm/interpreter/interpreter.uya` | MicroInterpreter |
| `lib/tflm/kernels/kernels.uya` | 各类 BuiltinOperator 内核（fc / softmax / conv2d / depthwise_conv2d / relu / pool / reshape） |
| `lib/tflm/quant/quant.uya` | 量化辅助（`quant_sat_i32_to_i8`、`quant_mul_i32_shift_sat`） |
| `lib/tflm/backend/backend.uya`、`backend/arm.uya` | 通用后端 / CMSIS-NN extern 占位 |
| `lib/tflm/common/common.uya` | 错误码、`BuiltinOperator`、`Context`、`TFLITE_VERSION` |

---

## 参考

- [uya.md](uya.md) — Uya 语言规范。
- [tflm_uya_design.md](tflm_uya_design.md) — 详细设计与接口说明。
- TensorFlow Lite Micro：<https://github.com/tensorflow/tflite-micro>；FlatBuffer schema：`tflite/schema/schema.fbs`。
