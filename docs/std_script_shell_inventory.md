# 标准脚本运行时盘点

**更新日期**：2026-06-29
**范围**：Phase 0 第一轮，仅记录 B 类 shell 脚本。

## B 类判定标准

满足以下特征的脚本先归入 B 类：

- 核心工作是创建临时目录、拷贝/链接/生成测试输入文件。
- 主要断言手段是 `grep`、`diff`、`find`、`sed`、`sort`、`test -f/-s/-x` 等文本或文件系统检查。
- 会调用 `bin/uya`、`bin/cmd/upm` 或相关产物，但 shell 本身不承担跨平台矩阵、benchmark/stress 调度或完整构建管线编排。
- 迁移到 `std.path`、`std.fs`、`std.env`、`std.process` 后，预计不需要额外的 shell 兼容层。

不纳入本轮 B 类的脚本包括：`src/compile.sh`、`tests/run_programs_parallel.sh`、`tests/run_cross_platform_tests.sh`、`tests/stress_*.sh`、`benchmarks/*.sh`，以及明显偏 hosted/跨架构/benchmark 的验证脚本；这些留给 C 类再细分。

## 扫描摘要

- `rg --files -g '*.sh'` 共发现 183 个 shell 脚本。
- 按上面的 B 类标准，当前先归入 B 类 132 个，主要集中在 `tests/` 下的文件系统/文本 oracle 脚本。

## B 类清单

### exec_vm 与 exec backend（14）

```text
tests/verify_exec_backend_progress.sh
tests/verify_exec_vm_aggregates.sh
tests/verify_exec_vm_builtin_bridge.sh
tests/verify_exec_vm_compiler_regressions.sh
tests/verify_exec_vm_compiler_stage_smoke.sh
tests/verify_exec_vm_defer.sh
tests/verify_exec_vm_drop_local.sh
tests/verify_exec_vm_error_builtin.sh
tests/verify_exec_vm_extern_bridge.sh
tests/verify_exec_vm_globals.sh
tests/verify_exec_vm_hir_scope.sh
tests/verify_exec_vm_smoke.sh
tests/verify_exec_vm_stdio_no_varargs.sh
tests/verify_exec_vm_stdio_varargs.sh
```

### async/并发回归（14）

```text
tests/async_shared_runtime_mix.sh
tests/verify_async_await_capacity.sh
tests/verify_async_cancel_cleanup.sh
tests/verify_async_dynamic_resources.sh
tests/verify_async_full_dynamic_resources_gate.sh
tests/verify_async_large_state_machine.sh
tests/verify_async_nested_future_boundary.sh
tests/verify_async_nested_split_codegen.sh
tests/verify_async_production_smoke.sh
tests/verify_async_resource_diagnostics.sh
tests/verify_async_runtime_shared_semantics.sh
tests/verify_async_smoke_gate_separation.sh
tests/verify_async_websocket_client_reconnect_boundary.sh
tests/verify_async_websocket_regressions.sh
```

### embed/c_import/split 构建产物（20）

```text
tests/link_cimports_posix.sh
tests/split_c_smoke.sh
tests/verify_c_import_split_sidecar.sh
tests/verify_c_import_symlink_dedupe.sh
tests/verify_compile_sh_split_cache_cleanup.sh
tests/verify_dependency_dedupe.sh
tests/verify_embed_dedupe.sh
tests/verify_embed_dir_multifile_reuse.sh
tests/verify_embed_empty_dir.sh
tests/verify_embed_multifile_reuse.sh
tests/verify_embed_nostdlib.sh
tests/verify_embed_split_c.sh
tests/verify_embed_symlink_rejected.sh
tests/verify_embed_too_large.sh
tests/verify_embed_type_only.sh
tests/verify_project_root_embedded_uya_resolution.sh
tests/verify_split_build_output.sh
tests/verify_split_c_cache_lock.sh
tests/verify_split_c_cache_stale_lock.sh
tests/verify_split_c_makefile_dependencies.sh
```

### CLI / package-mode / shebang（9）

```text
tests/verify_check_cli.sh
tests/verify_cmd_bins_nostdlib_static.sh
tests/verify_fmt_cli.sh
tests/verify_nostdlib_user.sh
tests/verify_package_alias_source_roots.sh
tests/verify_package_mode_alias_root_conflict.sh
tests/verify_package_mode_build_success.sh
tests/verify_package_mode_legacy_fallback.sh
tests/verify_run_shebang_ush.sh
```

### UPM 工作区与清单（34）

```text
tests/test_cmd_upm_direct.sh
tests/verify_upm_add_git.sh
tests/verify_upm_add_path.sh
tests/verify_upm_add_remove_e2e.sh
tests/verify_upm_alias_conflict.sh
tests/verify_upm_build_flags.sh
tests/verify_upm_checksum_mismatch_git.sh
tests/verify_upm_checksum_mismatch_path.sh
tests/verify_upm_diagnostics.sh
tests/verify_upm_fetch_boundary.sh
tests/verify_upm_git_dep.sh
tests/verify_upm_git_ref_conflict.sh
tests/verify_upm_global_cache_git.sh
tests/verify_upm_graph_plan_no_staging.sh
tests/verify_upm_layout_manifest.sh
tests/verify_upm_legacy_mode.sh
tests/verify_upm_manifest_discovery_file.sh
tests/verify_upm_manifest_flat.sh
tests/verify_upm_manifest_missing.sh
tests/verify_upm_manifest_src.sh
tests/verify_upm_min_version_fail.sh
tests/verify_upm_min_version_ok.sh
tests/verify_upm_missing_dep_manifest.sh
tests/verify_upm_missing_lockfile.sh
tests/verify_upm_module_identity_exact_version_path.sh
tests/verify_upm_module_identity_version_mismatch.sh
tests/verify_upm_module_manifest_parse.sh
tests/verify_upm_path_dep.sh
tests/verify_upm_path_invalid.sh
tests/verify_upm_remove.sh
tests/verify_upm_resolved_graph_hash.sh
tests/verify_upm_temp_cleanup.sh
tests/verify_upm_transitive_conflict.sh
tests/verify_upm_workspace_backend.sh
```

### microapp 本地工程/产物断言（30）

```text
tests/verify_microapp_alloc_yield_runtime.sh
tests/verify_microapp_bss_manifest.sh
tests/verify_microapp_bss_runtime.sh
tests/verify_microapp_build_uapp.sh
tests/verify_microapp_example_boundary.sh
tests/verify_microapp_example_codegen.sh
tests/verify_microapp_example_sources_runtime.sh
tests/verify_microapp_exit_code_runtime.sh
tests/verify_microapp_fault_runtime.sh
tests/verify_microapp_host_api_diagnostics.sh
tests/verify_microapp_image_contracts.sh
tests/verify_microapp_loader_generic.sh
tests/verify_microapp_loader_unwired_profile.sh
tests/verify_microapp_mode_gate.sh
tests/verify_microapp_payload_symbols.sh
tests/verify_microapp_pobj_manifest.sh
tests/verify_microapp_portable_sources.sh
tests/verify_microapp_profile_cli.sh
tests/verify_microapp_profile_default_resolution.sh
tests/verify_microapp_recovery_update.sh
tests/verify_microapp_reloc_data_runtime.sh
tests/verify_microapp_reloc_runtime.sh
tests/verify_microapp_required_caps_runtime.sh
tests/verify_microapp_result_surface.sh
tests/verify_microapp_syscall_codegen.sh
tests/verify_microapp_time_runtime.sh
tests/verify_microapp_trap_bridge_result.sh
tests/verify_microapp_trap_runtime.sh
tests/verify_microapp_uapp_compat.sh
tests/verify_microapp_verify_cli.sh
```

### C99/codegen/诊断文本断言（11）

```text
tests/test_outlibc.sh
tests/verify_c99_async_frame_descriptors.sh
tests/verify_c99_async_frame_empty_descriptors.sh
tests/verify_c99_method_helper_emission_bug.sh
tests/verify_c99_struct_array_and_typed_route_regressions.sh
tests/verify_codegen_emit_buffering.sh
tests/verify_function_reachability_codegen.sh
tests/verify_gui_fixlist_codegen.sh
tests/verify_module_alias_import_table_codegen.sh
tests/verify_simd_select_c_emit.sh
tests/verify_slice_param_c99_emit.sh
```
