# 微容器文档索引

本文档用于集中整理当前仓库中的微容器相关文档，并说明它们之间的关系。

---

## 核心文档

- [requirements_v1.3.md](../../docs/microcontainer/requirements_v1.3.md)
- [runtime-architecture.md](../../docs/microcontainer/runtime-architecture.md)
- [capability_api_schema.md](../../docs/microcontainer/capability_api_schema.md)
- [backend_adapter_contract.md](../../docs/microcontainer/backend_adapter_contract.md)
- [native_mock_semantics.md](../../docs/microcontainer/native_mock_semantics.md)
- [image_validation.md](../../docs/microcontainer/image_validation.md)
- [syscall_abi.md](../../docs/microcontainer/syscall_abi.md)
- [update_recovery.md](../../docs/microcontainer/update_recovery.md)
- [platform_impl.md](../../docs/microcontainer/platform_impl.md)
- [benchmark_plan.md](../../docs/microcontainer/benchmark_plan.md)
- [source_to_uapp_pipeline.md](../../docs/microcontainer/source_to_uapp_pipeline.md)
- [migration_guide.md](../../docs/microcontainer/migration_guide.md)
- [microapp_source_template.md](../../docs/microcontainer/microapp_source_template.md)
- [microapp_profiles.md](../../docs/microcontainer/microapp_profiles.md)
- [portable_native_design.md](../../docs/microcontainer/portable_native_design.md)
- [portable_native_todo.md](../../docs/microcontainer/portable_native_todo.md)

---

## 术语边界

- `microapp.uya`：微应用源码文件（开发入口）
- `payload_obj`：编译器与打包器之间的中间产物，当前会保留源文件路径等 provenance 信息
- `payload code`：`target_arch` 指定的目标架构载荷码
- `.uapp`：最终加载器消费的镜像文件
- 目标 CLI 是 `uya microapp build|pack|inspect|verify|run`；调试时也可直接运行
  `bin/cmd/microapp ...` 验证与 launcher 分发等价
- 目标态 `.uapp` 可以由 `uya microapp build ... -o xxx.uapp` 直接生成，也可以先产 `.pobj`
  再用 `uya microapp pack` 打包；宿主示例仍保留用于对照和调试
- 示例 loader 现在可通过命令行参数接收任意 `.uapp` 路径，默认仍回退到示例镜像
- 热更新槽容量与示例 loader 读取缓冲已经拆成两个独立上限，便于后续分别调优
- `examples/microapp/microcontainer_hello_source.uya` 是当前推荐的可移植 microapp 源码样例
- 当前 portable source 示例集包括：
  - `examples/microapp/microcontainer_hello_source.uya`
  - `examples/microapp/microcontainer_alloc_yield_source.uya`
  - `examples/microapp/microcontainer_time_source.uya`
  - `examples/microapp/microcontainer_bss_source.uya`
  - `examples/microapp/microcontainer_reloc_source.uya`
  - `examples/microapp/microcontainer_reloc_data_source.uya`
- 当前 x86_64 真执行回归还额外覆盖了 relocation 和非零 exit code 透传
- 当前 hosted `call-gate` 装载路径已经把最小 `RELATIVE relocation` 应用扩到 `x86_64 + aarch64`，并开始规范化 x86_64 的内部 `R_X86_64_64`
- 当前还额外补上了最小 `aarch64 call-gate trampoline` helper；在 arm64 宿主上，compiler helper 也已支持切到私有栈后再调用 payload
- 仓库里现在还带有一个 arm64-host-gated 的 `linux_aarch64_hardvm` runtime 脚本；非 arm64 宿主会自动跳过；在 macOS arm64 CI 上会优先用 `xcrun clang + llvm-objcopy`
- microapp 生成 C 里的 bridge helper 现在已经从过渡的 `uya_microapp_syscall*` 收成 `uya_microapp_bridge_dispatch*`
- x86_64/aarch64 hosted call-gate payload 现在已通过 runtime bridge ABI slot 进入宿主 runtime，不再直接内嵌 `UYA_HOST_SYS_*` shim；aarch64 真执行回归仍按宿主架构 gate
- x86_64 的 hosted `call-gate` 构建链现在已改成编译器直接从 `gcc -c` 产出的 `.o` 提取 section/symbol/rela，不再需要先链接中间 `.elf`
- aarch64 的 hosted `call-gate` 构建链现在也已改成编译器直接从 `gcc -c` 产出的 `.o` 提取 section/symbol/rela，不再需要先链接中间 `.elf`
- trap bridge 除了 `validated` 结果面之外，现在还补了一条手工 RV32 `.uapp` 的最小真执行链路（`print/yield/exit`），ECALL 会通过 `sim_microapp_bridge_dispatch2` 进入同一 runtime bridge ABI
- 当前 x86_64 真执行回归也已经覆盖 fault/error 路径（通过子进程隔离把崩溃收口为可观测信号退出状态）
- 当前统一 fault/result 模型已经在 Linux hosted loader 与 sim/recovery 链路落地；每次 payload 运行只输出一行稳定的 `[microapp loader] payload result=...`，fault 统一携带 `fault_class / fault_code / fault_signal`
- trap bridge 的极小/不可执行 smoke 仍保留显式 `payload result=validated bridge=trap target=...` 结果面；RV32 runtime 路径不再停在 validated-only
- 尚未接线的 hosted profile 现在也会显式输出 `payload result=unwired bridge=... target=...`，不再只靠单独错误文案表达
- `examples/microapp/microcontainer_hello_build.uya` / `examples/microapp/microcontainer_hello_load.uya` 是宿主侧构建/加载工具，不属于 portable source 子集
- 用户 portable microapp 源码现在会在编译期拒绝直接 `use/call libc.*` 与 `std.time`，并提示改用 `std.microapp.*`
- `std.microapp.io` 现在提供 UART/GPIO/TIMER 的最小 `SYS_IO` wrapper；编译器会从这些 wrapper 的源码使用推导 `.uapp required_caps`，并由 runtime 在加载期映射成设备白名单
- 当前 microapp 路径里，目标选择已经切到 `profile-first`
- 推荐本地用 `make microapp-check` 运行当前 microapp 回归集
- `make microapp-check` 现在包含 Linux x86_64 profile/toolchain 契约审计：默认 profile 必须解析为 `linux_x86_64_hardvm`，`.uapp` 构建必须在 `READELF/OBJDUMP/NM/OBJCOPY=false` 下成功，不回退中间 ELF 链路，并通过 payload object 符号白名单与 runtime result surface 回归
- 在 hosted 平台上做轻量 smoke test 时，可用 `make microapp-hosted-smoke`
- 若只想单独触发 arm64-host-gated 的 aarch64 runtime 回归，可用 `make microapp-aarch64-runtime-check`
- 若只想单独触发 macOS arm64-host-gated 的 runtime 回归，可用 `make microapp-macos-runtime-check`
- 若只想检查 `.uapp v1/v2` 兼容链路，可用 `make microapp-compat-check`
- 若只想检查 crash/recovery/update 链路，可用 `make microapp-recovery-check`
- `make microapp-recovery-check` 当前会覆盖 `test_kernel_update.uya` 与 `test_kernel_sim.uya`，并检查 crash log 的 structured fault 字段
- `make microapp-check` 现在同时包含手工 `.uapp` 的 trap bridge validated smoke 和 RV32 trap runtime bridge 回归
- `make microapp-check` 现在还包含 native fallback / unwired / mapped fault 的单一 result surface 回归，防止重新出现旧的 `payload fault class=...` 诊断面
- 默认 profile 推导优先级是：`--microapp-profile` > `MICROAPP_TARGET_PROFILE` > `MICROAPP_TARGET_ARCH(+TARGET_OS)` > `TARGET_OS/TARGET_ARCH` > `HOST_OS/HOST_ARCH` > `linux_x86_64_hardvm`
- `MICROAPP_TARGET_GCC` 和 `TARGET_GCC` 都可以显式覆盖具体 gcc，前者优先级更高；若未覆盖，则走当前 profile 自带的默认 gcc
- `MICROAPP_TARGET_CFLAGS` / `MICROAPP_TARGET_LDFLAGS` 现在也是按 profile 给默认值：
  - `call_gate` profile 默认 `-fpie/-pie`
  - `trap` profile 默认 `-fno-pie/-no-pie`
- 当前 `microapp` 目标选择已逐步从 `arch-first` 迁移到 `profile-first`：
  - 可用 `--microapp-profile <name>` 显式指定
  - 也可用 `MICROAPP_TARGET_PROFILE`
  - CLI 优先级高于环境变量
  - 详细说明见 [microapp_profiles.md](../../docs/microcontainer/microapp_profiles.md)
  - 同一份 portable source 的多 profile 编译矩阵也见 [microapp_profiles.md](../../docs/microcontainer/microapp_profiles.md)

默认 profile 三元组映射：

- `linux_x86_64_hardvm` -> `x86_64-linux-gnu`
- `linux_aarch64_hardvm` -> `aarch64-linux-gnu`
- `macos_arm64_hardvm` -> `arm64-apple-darwin`
- `rv32_baremetal_softvm` -> `riscv32-unknown-elf`
- `xtensa_baremetal_softvm` -> `xtensa-unknown-elf`

---

## 阅读顺序

建议先看：

1. [requirements_v1.3.md](../../docs/microcontainer/requirements_v1.3.md)
2. [runtime-architecture.md](../../docs/microcontainer/runtime-architecture.md)
3. [capability_api_schema.md](../../docs/microcontainer/capability_api_schema.md)
4. [backend_adapter_contract.md](../../docs/microcontainer/backend_adapter_contract.md)
5. [native_mock_semantics.md](../../docs/microcontainer/native_mock_semantics.md)
6. [image_validation.md](../../docs/microcontainer/image_validation.md)
7. [source_to_uapp_pipeline.md](../../docs/microcontainer/source_to_uapp_pipeline.md)
8. [microapp_profiles.md](../../docs/microcontainer/microapp_profiles.md)
9. [migration_guide.md](../../docs/microcontainer/migration_guide.md)
10. [portable_native_design.md](../../docs/microcontainer/portable_native_design.md)
11. [portable_native_todo.md](../../docs/microcontainer/portable_native_todo.md)
