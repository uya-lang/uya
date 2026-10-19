# `std.mqtt.async` 使用文档

> 模块路径：`use std.mqtt.async`  
> 适用范围：纯 UYA、MQTT 3.1 / 3.1.1、明文 TCP、栈上工作缓冲区优先

## 概览

`std.mqtt.async` 现在提供四层能力：

1. 协议层：`MqttConnectOptions`、`MqttSubscribeRequest`、`MqttPublishRequest` 的编包，以及 `mqtt_parse_packet*` / `mqtt_packet_parse_*` 的解包。
2. transport 层：`MqttFdTransport` 实现了 `AsyncReader` / `AsyncWriter`，可直接接入 `epoll` 驱动的异步 Future。
3. 接口层：`AsyncMqttClient` 把 CONNECT / SUBSCRIBE / PUBLISH / read_packet 提升成 `@async_fn` MQTT 语义方法。
4. client 实现层：`MqttFdClient` 是一个基于 `MqttFdTransport` 的现成实现，直接以结构体 `@async_fn` 方法提供能力；同时保留 `mqtt_client_*_fd` 这组直接函数。

这套 API 默认不做协议层堆分配。发送缓冲区 `tx`、接收缓冲区 `rx` 都由调用方提供，推荐直接用局部固定数组。

## 最短可用路径

下面这个例子演示：

1. 连接 broker
2. 发送 CONNECT
3. 发送 SUBSCRIBE
4. 发送 QoS0 PUBLISH

```uya
use std.runtime.entry;
use std.mqtt.async;
use std.async_event.linux_epoll_create;
use std.async_event.LinuxEpoll;
use std.async_scheduler.block_on_with_event_loop;

use std.string.strlen;

const CLIENT_ID: &const byte = "xy-demo";
const USERNAME: &const byte = "xy-demo";
const PASSWORD: &const byte = "secret";
const TOPIC_DOWN: &const byte = "glasses/demo/down";
const TOPIC_UP: &const byte = "glasses/demo/up";
const PAYLOAD: &const byte = "{\"status\":\"ping\"}";

fn run_one_session() !void {
    const endpoint: MqttIpv4Endpoint = MqttIpv4Endpoint{
        a: 43,
        b: 136,
        c: 82,
        d: 108,
        port: 1883 as u16,
    };

    var tx: [byte: 256] = [0: 256];
    var rx: [byte: 512] = [0: 512];
    var loop: LinuxEpoll = try linux_epoll_create(0);

    const opts: MqttConnectOptions = MqttConnectOptions{
        client_id: CLIENT_ID,
        client_id_len: strlen(CLIENT_ID),
        username: USERNAME,
        username_len: strlen(USERNAME),
        password: PASSWORD,
        password_len: strlen(PASSWORD),
        keepalive: 60 as u16,
        protocol_level: MQTT_PROTOCOL_V311,
    };

    {
        var client: MqttFdClient = try mqtt_fd_client_dial(&endpoint, &opts);

        const connack: MqttConnAck = try block_on_with_event_loop<MqttConnAck>(
            &loop,
            client.connect(&tx[0], 256, &rx[0], 512),
            1000
        );
        if !connack.accepted() {
            return error.MqttUnexpectedPacket;
        }

        const suback: MqttSubAck = try block_on_with_event_loop<MqttSubAck>(
            &loop,
            client.subscribe(TOPIC_DOWN, strlen(TOPIC_DOWN), &tx[0], 256, &rx[0], 512),
            1000
        );
        if !suback.accepted() {
            return error.MqttUnexpectedPacket;
        }

        _ = try block_on_with_event_loop<usize>(
            &loop,
            client.publish_qos0(TOPIC_UP, strlen(TOPIC_UP), PAYLOAD, strlen(PAYLOAD), &tx[0], 256),
            1000
        );
    }
}

export fn main() i32 {
    _ = run_one_session() catch {
        return 1;
    };
    return 0;
}
```

### 这段代码里的几个关键点

- `mqtt_fd_client_dial()` 会同步建立 TCP 连接，并返回持有 `MqttFdTransport` 的 `MqttFdClient`。
- `MqttFdClient` 内部持有 owned transport，离开作用域时会通过 transport 的 `drop` 自动关闭 fd。
- `mqtt_fd_client_new()` 现在显式接收 `&MqttFdTransport`，并从传入 transport 上偷走 fd 所有权，避免按值传递时被源变量的 `drop` 提前关闭。
- `tx` / `rx` 都是 caller-owned buffer，可以重复复用。
- `MqttClient` 负责维护 packet id，`subscribe_request()` / `publish_request()` 会复用它的状态。

## `AsyncMqttClient` 接口

如果你想把 MQTT 会话对象继续往上抽象，可以直接依赖接口，而不是绑死在 fd 封装上。

`AsyncMqttClient` 现在统一了这四个入口：

- `connect(...) Future<!MqttConnAck>`
- `subscribe(...) Future<!MqttSubAck>`
- `publish_qos0(...) Future<!usize>`
- `read_packet(...) Future<!MqttPacketView>`

示例：

```uya
fn bootstrap_client<C: AsyncMqttClient>(client: &C, tx: &byte, tx_cap: usize, rx: &byte, rx_cap: usize) !void {
    const loop: LinuxEpoll = try linux_epoll_create(0);

    const connack: MqttConnAck = try block_on_with_event_loop<MqttConnAck>(
        &loop,
        client.connect(tx, tx_cap, rx, rx_cap),
        1000
    );
    if !connack.accepted() {
        return error.MqttUnexpectedPacket;
    }
}
```

当前标准库内置的实现是 `MqttFdClient`。如果你后面要接 TLS、串口 AT 代理、内存环回测试桩，也可以自己实现这个接口。

接口定义本身就是这种风格：

```uya
export interface AsyncMqttClient {
    @async_fn
    fn connect(self: &Self, tx: &byte, tx_cap: usize, rx: &byte, rx_cap: usize) Future<!MqttConnAck>;
    @async_fn
    fn subscribe(self: &Self, topic: &const byte, topic_len: usize, tx: &byte, tx_cap: usize, rx: &byte, rx_cap: usize) Future<!MqttSubAck>;
    @async_fn
    fn publish_qos0(self: &Self, topic: &const byte, topic_len: usize, payload: &const byte, payload_len: usize, tx: &byte, tx_cap: usize) Future<!usize>;
    @async_fn
    fn read_packet(self: &Self, rx: &byte, rx_cap: usize) Future<!MqttPacketView>;
}
```

## 收包与解析

如果你想自己控制收包循环，可以直接使用：

- `client.read_packet(...)`
- `mqtt_read_packet`
- `mqtt_parse_packet`
- `mqtt_packet_parse_connack`
- `mqtt_packet_parse_suback`
- `mqtt_packet_parse_publish`

示例：

```uya
fn read_one_publish(client: &MqttFdClient, rx: &byte, rx_cap: usize) !void {
    const loop: LinuxEpoll = try linux_epoll_create(0);
    const packet: MqttPacketView = try block_on_with_event_loop<MqttPacketView>(
        &loop,
        client.read_packet(rx, rx_cap),
        1000
    );

    if packet.packet_type != MQTT_PACKET_TYPE_PUBLISH {
        return error.MqttUnexpectedPacket;
    }

    const publish: MqttPublishView = try mqtt_packet_parse_publish(&packet);
    if publish.topic_eq("glasses/demo/down" as &const byte, 17) {
        if publish.payload_contains("\"pong\"" as &const byte, 6) {
        }
    }
}
```

如果你手里拿的是原始 transport，而不是 `MqttFdClient`，也可以继续直接调用：

- `mqtt_read_packet<MqttFdTransport>(io, rx, rx_cap)`
- `mqtt_read_packet_fd(io, rx, rx_cap)`

## `@frame` 手动驱动

如果你不想马上接 event loop，而是要手动持有异步帧，也可以直接用 `@frame`。

仓库里有一个最小 smoke：

- [uya/tests/test_std_mqtt_async.uya](/media/winger/_dde_home/winger/wingo/work/rk/builder/rv1103b_linux_ipc_sdk/project/app/xyglasses/uya/tests/test_std_mqtt_async.uya:1)

核心模式如下：

```uya
var frame: @frame(mqtt_connect_frame_smoke);
defer { frame.stop(); }

frame.start(&reader, &rx[0], 8);

const w: Waker = Waker{};
const p: Poll<!usize> = frame.poll(&w);
match p {
    .Ready(ok_val) => {
        const rc: usize = ok_val catch { 127 as usize; };
        if rc != 0 {
        }
    },
    .Pending(_) => {
    },
};
```

适合这类场景：

- 你要把 Future 存成局部状态，分多轮 `poll`
- 你要验证某个异步函数的 lowering 是否符合预期
- 你要把帧对象放进更上层状态机，但仍坚持 caller-owned / stack-owned 生命周期

## 包构造 API

### CONNECT

```uya
const opts: MqttConnectOptions = MqttConnectOptions{
    client_id: CLIENT_ID,
    client_id_len: strlen(CLIENT_ID),
    username: USERNAME,
    username_len: strlen(USERNAME),
    password: PASSWORD,
    password_len: strlen(PASSWORD),
    keepalive: 60 as u16,
    protocol_level: MQTT_PROTOCOL_V311,
};

const n: usize = try mqtt_connect_options_build_packet(&opts, &tx[0], 256);
```

也可以用方法风格：

```uya
const n: usize = try opts.build_packet(&tx[0], 256);
```

### SUBSCRIBE

```uya
const req: MqttSubscribeRequest = MqttSubscribeRequest{
    packet_id: 1 as u16,
    topic: TOPIC_DOWN,
    topic_len: strlen(TOPIC_DOWN),
    qos: 0 as byte,
};
const n: usize = try mqtt_subscribe_request_build_packet(&req, &tx[0], 256);
```

### PUBLISH

```uya
const req: MqttPublishRequest = MqttPublishRequest{
    topic: TOPIC_UP,
    topic_len: strlen(TOPIC_UP),
    payload: PAYLOAD,
    payload_len: strlen(PAYLOAD),
    qos: 0 as byte,
    retain: false,
};
const n: usize = try mqtt_publish_request_build_packet(&req, &tx[0], 256);
```

## 生命周期与缓冲区约束

这部分很重要：

- `MqttPacketView.payload` 借用的是传给 `mqtt_read_packet` / `mqtt_parse_packet` 的原始缓冲区。
- `MqttPublishView.topic_ptr` / `payload_ptr` 也是借用 `rx` 的视图，不做拷贝。
- 一旦你复用了 `rx`，之前解出来的 `MqttPacketView` / `MqttPublishView` 就不应该再继续使用。

推荐做法：

- 解析完立即消费，不长期保存 view。
- 如果业务层确实要跨轮保存，自己拷贝到调用方的存储区。
- `tx` / `rx` 用局部固定数组即可，典型大小是 `tx: 256~512`，`rx: 512~2048`。

## RAII / `drop` / `defer` 约定

### `MqttFdTransport`

- `mqtt_fd_transport_owned(fd)`：作用域结束时 `drop` 会自动关闭 fd。
- `mqtt_fd_transport_borrowed(fd)`：只借用，不负责关闭。
- `take_fd()`：转移所有权，之后 `drop` 不再关闭这个 fd。
- `mqtt_fd_client_new(&opts, &io)`：把 `io` 里的 fd 所有权转移给 `MqttFdClient`；调用后原 `io` 会进入空状态。
- `close()`：提前关闭，适合想在作用域结束前主动释放资源的场景。

### 推荐写法

如果整个函数都持有同一个连接，直接让 RAII 接管就够了：

```uya
{
    var client: MqttFdClient = try mqtt_fd_client_dial(&endpoint, &opts);
    // ...
}
```

如果你想提前结束连接，可以：

```uya
defer { client.close(); }
```

如果连接建立后后续步骤可能失败，`MqttIpv4Endpoint.connect()` 内部已经用 `errdefer` 保证了建连失败路径会关闭 fd，不需要调用方重复清理半成品。

## 什么时候用方法，什么时候用顶层包装

这套模块同时保留了：

- 结构体 `@async_fn` 方法：现在已经是一等用法，最适合业务代码直接消费
- 顶层包装函数：更适合做兼容入口、组合测试或保持纯函数式调用风格

例如下面两种语义相同：

```uya
const n: usize = try opts.build_packet(&tx[0], 256);
const n2: usize = try mqtt_connect_options_build_packet(&opts, &tx[0], 256);
```

当前建议：

- 业务代码优先用 `MqttFdClient` / `AsyncMqttClient` 方法
- 顶层包装函数保留给兼容层和不想显式持有 client 对象的场景

## API 速查

### 类型

- `MqttConnectOptions`
- `MqttSubscribeRequest`
- `MqttPublishRequest`
- `MqttConnAck`
- `MqttSubAck`
- `MqttPacketView`
- `MqttPublishView`
- `AsyncMqttClient`
- `MqttFdClient`
- `MqttFdTransport`
- `MqttIpv4Endpoint`
- `MqttClient`

### 顶层函数

- `mqtt_connect_options_build_packet`
- `mqtt_subscribe_request_build_packet`
- `mqtt_publish_request_build_packet`
- `mqtt_parse_packet`
- `mqtt_packet_wire_len`
- `mqtt_packet_parse_connack`
- `mqtt_packet_parse_suback`
- `mqtt_packet_parse_publish`
- `mqtt_fd_transport_owned`
- `mqtt_fd_transport_borrowed`
- `mqtt_client_new`
- `mqtt_fd_client_new`
- `mqtt_fd_client_dial`
- `mqtt_write_all`
- `mqtt_read_exact`
- `mqtt_read_packet`
- `mqtt_read_packet_fd`
- `mqtt_client_connect_fd`
- `mqtt_client_subscribe_fd`
- `mqtt_client_publish_qos0_fd`

## 当前边界

当前这版标准库 MQTT core 的边界是：

- 支持 MQTT 3.1 / 3.1.1
- 高层 API 当前聚焦 fd transport
- 默认只覆盖最常用的 CONNECT / SUBSCRIBE / QoS0 PUBLISH
- 还没内置 DNS、TLS、PING keepalive、QoS1/2、自动重连

如果你后面要往上扩：

- 接 DNS：可在建连前复用 `std.net.dns`
- 接 TLS：可以在 transport 层扩一套新的 `AsyncReader` / `AsyncWriter`
- 接业务状态机：推荐把 view 解析留在 MQTT 层，业务层只吃 topic / payload 判定结果

## 参考

- 模块实现：[lib/std/mqtt/async.uya](../lib/std/mqtt/async.uya)
- smoke 测试：[tests/test_std_mqtt_async.uya](../tests/test_std_mqtt_async.uya)

> **核对头（2026-10-19）**：本文 API 清单已逐个回到 `lib/std/mqtt/async.uya` 核对，**全部存在**，无臆造项。补充定位与两点修正：
> - 泛型 helper 均为 `export @async_fn`：`mqtt_write_all<W: AsyncWriter>`（`:647`）、`mqtt_read_exact<R: AsyncReader>`（`:659`）、`mqtt_read_packet<R: AsyncReader>`（`:671`）。
> - fd 语义包装：`mqtt_client_connect_fd`（`:775`）、`mqtt_client_subscribe_fd`（`:835`）、`mqtt_client_publish_qos0_fd`（`:898`），`MqttFdClient` 的三个方法直接转发到它们（`:927/932/937`）。
> - 原「参考」小节的两个链接指向**另一台机器上的绝对路径**（`/media/winger/_dde_home/.../xyglasses/uya/...`），已改为仓库相对路径。
> - 「当前边界」四条（MVP 3.1/3.1.1、仅 fd transport、仅 CONNECT/SUBSCRIBE/QoS0 PUBLISH、无 DNS/TLS/PING keepalive/QoS1-2/自动重连）经 grep 复核仍成立：`lib/std/mqtt/async.uya` 中无 `PINGREQ`/`QoS1`/`reconnect`/TLS 相关导出。
