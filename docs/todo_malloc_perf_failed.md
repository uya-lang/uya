# libc malloc/free 性能优化 TODO 失败归档

## 2026-06-25 阶段 4：多线程扩展

上下文：
- 父级任务：`阶段 4：多线程扩展`

  - [f] 单线程无退化和多线程吞吐目标验证完成
    - 失败原因：`tests/build/bench_malloc_phase3_current` 同口径 30 次结果为 `avg_ns_mean=8475.3`、`elapsed_ns_mean=84757719.8`，相对主 todo 中阶段 3 记录的 `avg_ns_mean=1211.7` 出现明显单线程回退；`tests/build/bench_malloc_phase4` 热路径结果里 `threads=4 throughput_ops_per_sec=1014285`，仅为 `threads=1` 的 `1.23x`，未达到 `4 线程 > 单线程 2.5x` 目标。
    - 验证命令：`../uya/bin/uya test tests/test_std_stdlib_malloc.uya`
    - 验证命令：`../uya/bin/uya test tests/test_libc_heap_bins.uya`
    - 验证命令：`../uya/bin/uya test tests/test_libc_heap_large_path.uya`
    - 验证命令：`../uya/bin/uya test tests/test_libc_heap_tcache.uya`
    - 验证命令：`../uya/bin/uya test tests/test_libc_heap_tcache_metrics.uya`
    - 阻塞命令：`./tests/build/bench_malloc_phase4`
    - 关键结果：`malloc_phase4 threads=1 total_ops=448000 elapsed_ns=545180870 throughput_ops_per_sec=821745 lock_acquires=256051 lock_contentions=0 tcache_hits=191952 tcache_misses=32048 tcache_hit_rate_bp=8569 checksum=158684160`
    - 关键结果：`malloc_phase4 threads=2 total_ops=896000 elapsed_ns=735689676 throughput_ops_per_sec=1217904 lock_acquires=513620 lock_contentions=99628 tcache_hits=382386 tcache_misses=65614 tcache_hit_rate_bp=8535 checksum=317377280`
    - 关键结果：`malloc_phase4 threads=4 total_ops=1792000 elapsed_ns=1766760362 throughput_ops_per_sec=1014285 lock_acquires=1050881 lock_contentions=129361 tcache_hits=741131 tcache_misses=154869 tcache_hit_rate_bp=8271 checksum=634790400`
    - 关键结果：`malloc_phase4 threads=8 total_ops=3584000 elapsed_ns=5427651240 throughput_ops_per_sec=660322 lock_acquires=2230528 lock_contentions=455810 tcache_hits=1353496 tcache_misses=438504 tcache_hit_rate_bp=7552 checksum=1269724160`
    - 阻塞命令：`python3 - <<'PY' ... ./tests/build/bench_malloc_phase3_current ... PY`
    - 关键结果：`phase3_current_runs=30`
    - 关键结果：`avg_ns_mean=8475.3 avg_ns_p50=8477 avg_ns_p95=8595 avg_ns_p99=8597`
    - 关键结果：`elapsed_ns_mean=84757719.8 elapsed_ns_p50=84773949 elapsed_ns_p95=85954675 elapsed_ns_p99=85970721`
    - 后续重开条件：降低 `free`/tcache 热路径的全局锁争用、恢复 phase3 单线程基线后，使用同一组 `tests/build/bench_malloc_phase3_current` 与 `tests/build/bench_malloc_phase4` 命令重新验证。
