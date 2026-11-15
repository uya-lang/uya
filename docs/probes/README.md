# 复现件索引（VM 行为差异定位用）

这些是定位 `docs/todo_exec_vm_parity.md` 里各项失败时用的最小复现程序，
原本放在 `/tmp`，这里固化以便后续直接使用。

用法（在仓库根目录）：

```sh
export UYA_ROOT=$PWD/lib/
./bin/uya run --vm --no-strict-overflow docs/probes/<名字>.uya
```

| 文件 | 复现什么 | 期望 |
|---|---|---|
| `tls_test.uya` | `@thread_local` 全局属性可用性 | 打印 `OK tls` |
| `thr_probe.uya` | 最小两线程（create → 打印 → join） | 默认与 `UYA_EXEC_REAL_THREADS=1` 都打印 `W`/`OK thr` |
| `thr_alloc_probe.uya` | 两线程各 2000 次 malloc/free | 默认 rc=0；真线程模式下**不稳定**（多数超时/段错误） |
| `ws_plain22_probe.uya` | 22 字节 websocket 帧：写 + 读 + 解码 | 打印 `OK full` |
| `ws_json_probe.uya` | `websocket_conn_write_json<JsonUser>` | **当前打印 `E5 write json`**（宏生成编码块误报 overflow） |
| `ws_full_probe.uya` | 同上 + 服务端读消息 | 停在 `OK write_json`（读挂死，配合上一个一起看） |
| `agg_slice_probe.uya` | 结构体数组经切片写入后读字段 | 打印 `OK agg` |
| `iface_field_probe.uya` | 结构体字段里的接口值调方法 | 打印 `OK field iface` |
| `json_parse_probe.uya` | JSON 解析 | 打印 `OK parse` |
