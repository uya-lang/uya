# Uya 微容器通用共享库机制 TODO

**版本**: v0.1  
**日期**: 2026-04-28  
**对应设计**: `docs/microcontainer/shared_library_design.md`

---

## 1. 目标

本待办只服务一个目标：

- 建立微容器自己的通用共享库机制
- 让多个 `uapp` 复用同一份共享代码
- 保持 `microapp` 既有安全边界、profile 约束和 loader 语义
- 先以无状态函数库为第一阶段正式能力

本待办不追求：

- 兼容宿主 `.so`
- 容器内 `dlopen()`
- 第一阶段就支持共享库可写全局状态
- 第一阶段就覆盖完整 `libc`

---

## 2. 里程碑

### M1：规格冻结

- 共享库 ABI、镜像种类、import/export/dependency 元数据冻结
- `shared_lib` 与 `exec` 的边界固定
- loader-time linking 规则固定

### M2：v1 无状态共享函数库

- 可构建 `.ulib`
- `uapp` 可声明共享导入
- loader 可完成依赖解析与 import slot 绑定
- 至少 2 个 `uapp` 共享 1 个官方函数库

### M3：多 profile 与运行时共享页

- hosted hard-vm 共享页正式可用
- soft-vm 共享物理代码页正式可用
- 引用计数、registry 和管理命令补齐

### M4：有状态共享库扩展

- 每容器 library instance
- init/fini / ctx 管理
- 更复杂的 `libc` 子集进入共享库

---

## 3. 当前前置条件

以下能力已经是共享库机制的可复用前提：

- [x] `.uapp v2` 已有 `code/rodata/data/bss/reloc/profile/bridge` 基础段模型
- [x] `PayloadObj` 已能表达段与 relocation 元数据
- [x] hosted loader 已有真实映射和权限页语义
- [x] 页表已有共享位 `PTE_S`
- [x] `microapp` 已有较严格的源码约束与 bridge 边界
- [ ] 镜像种类 `shared_lib` 尚未正式定义
- [ ] import/export/dependency section 尚未存在
- [ ] loader 尚无 library registry
- [ ] codegen 尚无 import slot 降级路径

---

## 4. 阶段 0：规格冻结

### 4.1 术语与边界

- [ ] 冻结：
  - `image_kind`
  - `shared_lib`
  - `library_id`
  - `abi_major/minor`
  - `symbol_id`
  - `import slot`
  - `library registry`
- [ ] 冻结 v1 仅支持“函数导出、无状态共享库”
- [ ] 冻结“不支持容器内 `dlopen()`”为正式约束

### 4.2 二进制 ABI

- [ ] 冻结 `format_version = 3` 的扩展方向
- [ ] 冻结 section directory 结构
- [ ] 冻结 `ImportEntry`
- [ ] 冻结 `ExportEntry`
- [ ] 冻结 `DependencyEntry`

验收标准：

- [ ] 设计文档中的字段名、匹配规则、版本规则不再频繁改名
- [ ] 后续实现不再重新讨论“导入是按字符串还是按 ID”

---

## 5. 阶段 1：镜像格式与打包器

### 5.1 `ImageHeader v3`

- [ ] 在 [image.uya](../../lib/kernel/image.uya) 增加：
  - `image_kind`
  - `link_abi_version`
  - `section_table_offset`
  - `section_count`
  - `module_id`
  - `abi_major`
  - `abi_minor`
- [ ] 保持 v1/v2/v3 兼容读取策略

### 5.2 section directory

- [ ] 定义 section kind：
  - `imports`
  - `exports`
  - `dependencies`
  - `strings`
  - `link_aux`
- [ ] 为 v3 镜像补 section 解析器
- [ ] 为 v3 镜像补 section 越界校验

### 5.3 `PayloadObj`

- [ ] 在 [payload.uya](../../lib/kernel/payload.uya) 增加：
  - `image_kind`
  - `module_id`
  - `abi_major`
  - `abi_minor`
  - `imports`
  - `exports`
  - `dependencies`
  - `string_table`
- [ ] 支持打包 `.ulib`
- [ ] 支持打包 `exec + imports`

### 5.4 校验

- [ ] 扩展 `image_validate()`：
  - `shared_lib` 是否非法携带可执行主入口
  - v1 共享库是否非法携带 `data/bss`
  - import/export/dependency section 是否自洽
  - 同一 `symbol_id` 是否重复

验收标准：

- [ ] `microapp inspect` 能看见共享库元数据
- [ ] `microapp verify` 能报告链接级结构错误
- [ ] `.ulib` roundtrip 用例通过

---

## 6. 阶段 2：构建链与源码绑定

### 6.1 共享库构建入口

- [ ] 在 `src/cmd/microapp/main.uya` 增加 CLI：
  - `--emit-shared-lib`
  - 或等价 `microapp build --kind shared_lib`
- [ ] 定义输出扩展名建议 `.ulib`
- [ ] 区分 `exec` 与 `shared_lib` 构建路径

### 6.2 共享库 manifest

- [ ] 定义共享库清单格式：
  - `library_id`
  - `abi_major/minor`
  - exported `symbol_id`
  - signature
- [ ] 冻结 manifest 与镜像字段映射关系
- [ ] 允许由 manifest 生成绑定代码

### 6.3 codegen：import slot 降级

- [ ] 在 [src/codegen/c99](../../src/codegen/c99) 增加共享导入识别
- [ ] 为共享导入分配 `slot_va`
- [ ] 调用点改为“从 slot 读取函数指针后间接调用”
- [ ] 拒绝回退生成宿主 `extern` 调用

### 6.4 checker / 语义

- [ ] 定义“共享导入声明”的编译期识别方式
- [ ] 保证它不破坏当前 `microapp` 对 `extern` 的禁令
- [ ] 对不支持的共享导入用法给出明确诊断

验收标准：

- [ ] 能从共享库 manifest 生成绑定代码
- [ ] 应用源码可像普通函数一样调用绑定 API
- [ ] 生成产物中不再静态内联共享库代码

---

## 7. 阶段 3：Library Registry 与 Loader

### 7.1 registry 数据结构

- [ ] 在 `lib/std/runtime/microapp` 或 `lib/kernel` 层新增 `LibraryRegistry`
- [ ] 记录：
  - `library_id`
  - `abi_major/minor`
  - `profile_id`
  - `target_arch`
  - `bridge_kind`
  - `image_hash`
  - `ref_count`
  - `mapping_handle`
  - export 索引

### 7.2 安装与移除

- [ ] 新增共享库安装路径
- [ ] 新增共享库卸载路径
- [ ] 先支持“安装后常驻”
- [ ] 明确未使用库的卸载策略

### 7.3 依赖解析

- [ ] loader 解析 `DependencyEntry`
- [ ] 构建依赖拓扑
- [ ] 检测循环依赖
- [ ] 按 `library_id + abi_major + min_abi_minor` 解析 provider
- [ ] 校验 `signature_hash`

### 7.4 capability / profile 约束

- [ ] 计算依赖闭包 `required_caps`
- [ ] 校验调用方 capability 声明可覆盖整个依赖闭包
- [ ] 拒绝：
  - `profile_id` 不一致
  - `target_arch` 不一致
  - `bridge_kind` 不一致

验收标准：

- [ ] loader 能给出稳定的解析错误
- [ ] 依赖闭包可以被 `inspect-link` 或调试日志输出

---

## 8. 阶段 4：运行时共享页映射

### 8.1 hard-vm

- [ ] 在 [loader.uya](../../lib/std/runtime/microapp/loader.uya) 接入共享库映射
- [ ] 共享库 `code` 页映射为 `RX`
- [ ] 共享库 `rodata` 页映射为 `R`
- [ ] 多个容器复用同一宿主 backing
- [ ] 页表项标记 `PTE_S`

### 8.2 soft-vm

- [ ] 在 `sim` / `paging` 路径接入共享物理代码页
- [ ] 多个容器页表映射同一 `PPN`
- [ ] 保证共享页不可写

### 8.3 import slot 绑定

- [ ] 装载期把 `slot_va` 写成目标函数地址
- [ ] 校验 `slot_va` 落在合法可写区域
- [ ] 完成最终页权限收口

验收标准：

- [ ] 两个容器能共享同一代码页
- [ ] import slot 绑定后调用正确
- [ ] `ref_count` 随容器生命周期变化

---

## 9. 阶段 5：CLI、inspect 与运维工具

### 9.1 命令入口

- [ ] 增加：
  - `microapp install-shared-lib`
  - `microapp list-shared-lib`
  - `microapp remove-shared-lib`
  - `microapp inspect-link`
- [ ] `microapp inspect` 支持 `.ulib`
- [ ] `microapp verify` 支持 `.ulib`

### 9.2 可观测性

- [ ] 输出：
  - resolved provider
  - ABI 版本
  - dependency closure
  - ref_count
  - 共享页信息

验收标准：

- [ ] 开发者能从 CLI 看见“为什么解析成功/失败”
- [ ] 不需要读原始二进制也能定位常见链接问题

---

## 10. 阶段 6：测试与 benchmark

### 10.1 单元测试

- [ ] `ImportEntry/ExportEntry/DependencyEntry` 解析测试
- [ ] ABI 版本匹配测试
- [ ] `signature_hash` 匹配测试
- [ ] 循环依赖检测测试

### 10.2 镜像回归

- [ ] `.ulib` pack/unpack roundtrip
- [ ] `microapp inspect` 输出回归
- [ ] `microapp verify` 错误回归

### 10.3 运行时回归

- [ ] 两个 `uapp` 共享同一 `memcpy` 库
- [ ] 库缺失时报稳定错误
- [ ] ABI 不匹配时报稳定错误
- [ ] profile / bridge 不匹配时报稳定错误

### 10.4 体积与性能

- [ ] 增加共享库前后体积对照
- [ ] 增加 cold load 对照
- [ ] 增加调用开销对照
- [ ] 记录系统总 ROM 占用是否真的下降

验收标准：

- [ ] 至少证明 1 个真实共享库场景确实能减小 `uapp` 体积
- [ ] 调用开销在可接受范围内

---

## 11. 阶段 7：v2 有状态共享库

### 11.1 实例化模型

- [ ] 定义 `LibraryInstance`
- [ ] 每容器为有状态库分配私有 `ctx`
- [ ] 定义 `init/fini`

### 11.2 ABI 扩展

- [ ] 定义 ctx 绑定方式
- [ ] 定义 thunk / hidden context 调用形式
- [ ] 定义有状态库如何声明自身状态需求

### 11.3 迁移更复杂库

- [ ] 评估：
  - allocator
  - stdio
  - `errno`
  - signal 状态
- [ ] 只有在 v2 ABI 稳定后再进入共享库

---

## 12. 建议的首批实现顺序

为避免同时改动过大，建议严格按以下顺序推进：

1. 先冻结设计文档与二进制 ABI
2. 再做 `Image v3 + PayloadObj + inspect/verify`
3. 再做共享库 manifest 与绑定代码生成
4. 再做 codegen 的 import slot 降级
5. 再做 loader 的 registry / resolve / bind
6. 先让 `memcpy/memset/strlen` 这一类无状态函数跑通
7. 最后再考虑有状态库和更复杂 `libc`

---

## 13. 首批官方共享库候选

### 优先级 A：最适合 v1

- [ ] `memcpy`
- [ ] `memmove`
- [ ] `memset`
- [ ] `memcmp`
- [ ] `strlen`
- [ ] `strcmp`
- [ ] `strncpy`
- [ ] `ctype` 子集

### 优先级 B：需要更多 ABI 讨论

- [ ] `math` 纯函数子集
- [ ] 编码/校验类纯函数

### 优先级 C：推迟到 v2 或更晚

- [ ] allocator
- [ ] stdio
- [ ] signal 全局状态
- [ ] pthread / TLS
- [ ] 依赖宿主进程隐式状态的封装

---

## 14. 完成定义

共享库机制第一阶段完成，需要同时满足：

- [ ] 能构建合法 `.ulib`
- [ ] 能把应用中的共享调用降成 import slot
- [ ] loader 能完成依赖解析与绑定
- [ ] 至少 2 个 `uapp` 共享 1 个官方函数库
- [ ] `microapp inspect` / `microapp verify` / 调试日志足够可用
- [ ] 至少有一组体积收益数据证明该机制值得保留

只有同时满足这些条件，才应宣布 v1 共享库机制可用。
