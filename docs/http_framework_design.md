# Uya 高性能 HTTP 框架详细设计

**版本**：v0.1  
**状态**：设计阶段  
**参考**：[.cursor/plans/uya_高性能_http_框架_09efdaaa.plan.md](.cursor/plans/uya_高性能_http_框架_09efdaaa.plan.md)、[grammar_formal.md](grammar_formal.md)、[uya.md](uya.md)

> 2026-04-25 注：当前仓库实现已经明显超出本页最初的 blocking-first 设计稿。`std.http.parse/types/server` 已具备 Header 缓存、chunked request 解码与 `writev`/`sendfile` 热路径；更贴近现状的框架层说明请优先参考 [`uyagin_design.md`](./uyagin_design.md) 与 [`uyagin_todo.md`](./uyagin_todo.md)。

> **核对头（2026-10-19）**：本页仍是 v0.1 设计草案，**不要当作实现清单**读。按 `lib/std/http/` 实际文件核对：
> - 1.3 的目录块里 **`middleware.uya` 并不存在**（`ls lib/std/http/middleware.uya` → No such file）；实际 22 个模块为 `types` / `parse` / `router` / `server` / `epoll_server` / `jwt` / `http1_async` / `http2_types` / `http2_frame` / `http2_stream` / `hpack` / `websocket_types` / `websocket_frame` / `websocket_handshake` / `websocket_async` / `websocket_tls` / `websocket_client` / `websocket_json` / `websocket_http2_h3_route` / `uyagin` / `uyagin_router` / `uyagin_websocket`。
> - `ServerMode` 枚举已在 `lib/std/http/types.uya:122` 定义（`ServerConfig.mode` 见 `:247`），但"首版仅实现 Blocking"不再是全部：`lib/std/http/epoll_server.uya` 提供 epoll 服务端（`epoll_server_listen` 等 21 个导出），`lib/std/http/http1_async.uya` 提供 nonblocking async 客户端。
> - 1.2 的"后续：epoll 多路复用、异步 Handler…"已部分落地：epoll 服务端与 async HTTP/1 客户端都在，异步 Handler 由 `lib/std/http/uyagin.uya` 承担；统一 `http.client` 抽象仍未做。

---

## 1. 概述

### 1.1 目标

- 在 Uya 上实现高性能 HTTP/1.1 **服务端框架**，充分利用接口、`!T`、编译期证明、RAII、模块等语言特性。
- **完整支持 RESTful API**：路径参数、查询串、全方法、状态码、请求/响应体。
- **JWT 认证**：解析、验证、可选签发；与框架解耦（jwt 不依赖 get_bearer_token，由用户/中间件组合）。
- **性能可度量**：QPS、延迟、并发、内存指标与 wrk/ab 验证、基线回归 ±5%。

### 1.2 范围

- **本期**：服务端（types、parse、router、server、jwt）；首版 server 为阻塞 accept + 每连接一线程，不依赖 async 模块。
- **补充**：实验性 HTTP/1.1 客户端已在 `lib/std/http/http1_async.uya` 落地，`http1_async_get/post` 通过 nonblocking socket + `epoll` readiness 运行；正式 `http.client` API 仍可继续抽象与收敛。
- **后续**：epoll 多路复用、中间件实现、异步 Handler、统一 `http.client`、与 std.json 集成。

### 1.3 模块与目录

```
lib/std/http/
  types.uya      # 枚举、结构体、错误、Context、Conn、Handler 接口、get_bearer_token
  parse.uya      # HTTP/1.1 请求解析 parse(buf: &[byte]) !Request
  router.uya     # 使用 types 中的 Handler 接口、Router 结构体、路由匹配与 path_params 提取
  server.uya     # ServerConfig、Server、listen/accept 循环、Conn 生命周期
  jwt.uya        # Base64URL、JWT 三段解析、verify/decode/sign、HS256
  middleware.uya # Middleware 接口（首版仅类型），后续实现 logging/CORS/jwt_auth
                 # ⚠️ 2026-10-19 核对：该文件从未创建（仓库无 middleware.uya）；中间件能力目前由 uyagin 的链式 handler 承担
```

模块路径：`lib/std/http/` 为单模块 **std.http**，其下所有 .uya 文件同属该模块。

---

## 2. 类型与常量设计（types.uya）

### 2.1 枚举

- **Method**：GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD（与 HTTP/1.1 方法一致）。
- **Status**：OK=200, Created=201, NoContent=204, BadRequest=400, NotFound=404, MethodNotAllowed=405, Conflict=409, InternalServerError=500 等（常用 REST 状态码）。
- **ServerMode**：Blocking, Epoll, ThreadPool（首版仅实现 Blocking）。枚举字面量使用完整形式 **ServerMode.Blocking**（BNF：`enum_literal = ID '.' ID`）。

### 2.2 错误类型（顶层预定义）

```uya
error InvalidRequest;
error MethodNotAllowed;
error URITooLong;
error HeaderTooLarge;
error PayloadTooLarge;
error TooManyParams;
error ValueTooLong;
error InvalidToken;
error InvalidBoundary;
error TooManyParts;
```

引用形式：`return error.InvalidRequest;`（error_type = `error '.' ID`；勿与 Status.NotFound 等枚举字面量混淆）。

### 2.3 结构体与所有权

- **Request**  
  - 字段：method: Method, path: &[byte], path_params, query, headers, body: &[byte]（均为借用或固定容量结构）。  
  - **所有权**：Request 仅持有 **&[byte]**（借用），实际 buffer 由 **Server/Conn** 拥有（每连接栈或 buffer），Handler 不得逃逸引用。  
  - 方法：`fn get_header(self: &Self, name: &[byte]) !&[byte]`（name 为 header 名切片，如 "Authorization" 的 &[byte]；语法规范 slice_type = `&[' type ']'`）。

- **path_params / query**  
  - 固定容量线性数组（key/value 对），常量 P=8（path_params 条数）、Q=16（query 条数）、L=256（单 key/value 最大字节）。  
- **路由表容量**：使用常量（如 `MAX_ROUTES`）限定路由条数上限，在 types 或 router 中定义，不在代码中使用字面常数。  
  - 查找：线性扫描，不做哈希。超限返回 error.TooManyParams / error.ValueTooLong。

- **Multipart form（multipart/form-data）**  
  - 当请求头 `Content-Type: multipart/form-data; boundary=...` 时，body 按 boundary 切分为多个 part。  
  - **Part** 结构体（或等价类型）：name: &[byte]（必选）、filename: &[byte]（可选，文件上传时有）、content_type: &[byte]（可选）、body: &[byte]；均为借用，生命周期与 Request.body 一致。  
  - part 数量由常量限定（如 `MAX_MULTIPART_PARTS`），超限返回 error.TooManyParts；boundary 解析失败返回 error.InvalidBoundary。  
  - 提供 `fn parse_multipart(body: &[byte], boundary: &[byte]) !MultipartView` 或 Request 方法 `fn multipart(self: &Self) !MultipartView`（method_sig 形式：`fn ID '(' param_list ')' type ';'`），MultipartView 为固定容量 part 数组或迭代访问，便于 Handler 按 name 查找字段/文件。

- **Response**  
  - 字段：status: Status, headers, body（可写缓冲区或切片），由 Handler 填充。

- **Context**  
  - 字段：request: Request, response: Response, conn: Conn。供 Handler 与中间件访问。

- **Conn**  
  - 字段：fd: i32（或等效）。  
  - **drop**：`fn drop(self: Conn) void`（按值，仅一参），内部 close(fd)。RAII 保证连接关闭。

### 2.4 接口

- **Handler**：`interface Handler { fn serve(self: &Self, ctx: &Context) !void; }`
- **Middleware**（首版仅类型）：`interface Middleware { fn process(self: &Self, ctx: &Context, next: Handler) !void; }`

### 2.5 辅助函数

- **get_bearer_token(req: &Request) !&[byte]**  
  - 放在 types.uya 或同模块。实现：调用 `req.get_header(auth_header_name)`，其中 auth_header_name 为 "Authorization" 的 &[byte] 切片，解析 `Bearer ` 前缀后返回 token 切片。  
  - 避免 jwt.uya 依赖 http 的 Request，从而避免循环依赖。

### 2.6 ServerConfig

- **ServerConfig**：mode: ServerMode, max_connections: i32（约束线程数；线程栈约 8MB，max_connections=1000 时虚拟内存约 8GB，需在文档中注明）。

---

## 3. 解析设计（parse.uya）

### 3.1 API

- **parse(buf: &[byte]) !Request** 或 **parse(buf: &[byte]) !ParseResult**  
  - 优先使用切片入参，保留边界信息，便于编译期证明（证明范围仅限当前函数）。  
  - **Keep-alive 支持**：须向调用方提供「本请求在 buf 中消耗的字节数」或「剩余切片」，以便下一轮 parse 使用剩余数据。可选形式：（1）`ParseResult` 含 `request: Request` 与 `consumed: usize`，调用方用 `buf[consumed..]` 或等价方式作为下一轮输入；（2）或 parse 仅返回 Request，由 Request 或外部约定提供 `consumed` 字段/访问方式。

### 3.2 请求边界与 Keep-alive

- 单请求边界：请求行 + 头部 + 根据 Content-Length 的 body。  
- 同一连接上多请求：解析完一个 Request（或 ParseResult）后，**调用方根据 consumed 或 remaining 将 buf 中未消费部分作为下一轮 parse 的输入**，直至无完整请求或连接关闭。

### 3.3 编译期证明

- 所有 `buf[i]` 访问在当前函数内满足 `i >= 0 && i < @len(buf)`。  
- 示例：`while i < len && buf[i] != ' ' { i += 1; }`，循环条件保证下标安全。  
- 错误情况统一返回 error.XXX（InvalidRequest、URITooLong、HeaderTooLarge、PayloadTooLarge 等）。

### 3.4 支持范围

- 请求行：METHOD SP URI SP VERSION（URI 含 path + query）。  
- 头部：逐行解析，支持 Content-Type、Content-Length 等；单 header 长度与总 header 大小受 L/常量限制。  
- Body：按 Content-Length 读取，首版 body 总长不超过约定上限（如 64KB），超限返回 413 或 error。  
- **Multipart form**：当 `Content-Type` 为 `multipart/form-data; boundary=...` 时，从头部解析 boundary 字符串；body 按 `--<boundary>` 与 `--<boundary>--` 切分，每个 part 内解析可选头（Content-Disposition 取 name/filename、Content-Type）与 part body 切片；part 数量与单 part 头长度受常量限制，解析失败返回 error.InvalidBoundary / error.TooManyParts。

---

## 4. 路由设计（router.uya）

### 4.1 Router 结构体

- 使用 **types 中定义的 Handler 接口**；路由表：(method, path_pattern) -> Handler（接口 fat pointer）；**容量**由编译期常量限定（如 `MAX_ROUTES`），超限注册返回错误或断言；不使用字面常数。
- path_pattern 支持**路径参数**，如 `/users/:id`、`/posts/:postId/comments/:commentId`；匹配时提取 segment 写入 Request.path_params（线性数组，key 为占位符名，value 为 segment 切片）。

### 4.2 匹配语义

- 按 method + path 精确匹配；未匹配返回 **404**；method 不匹配（路径存在但方法不对）返回 **405**。
- 匹配顺序：可约定最长路径优先或按注册顺序，文档中明确即可。

### 4.3 资源组 API（可选）

- 使用结构体字面量承载多 Handler：`router.resource("/users", ResourceHandlers{ get: h1, post: h2, get_by_id: h3, put: h4, delete: h5 })`，ResourceHandlers 为含 get/post/… 字段的结构体（Uya 无命名实参）。

---

## 5. 服务端设计（server.uya）

### 5.1 首版并发模型

- **阻塞 accept + 每连接一线程**。每个连接：读入 buffer -> parse -> router.serve(ctx) -> 写回 Response；Conn 用 RAII（drop 关闭 fd），defer/errdefer 保证异常路径也释放资源。

### 5.2 连接生命周期

1. accept 得到 fd  
2. 包装为 Conn（栈或 per-connection 结构）  
3. 读入到固定大小 buffer（如 64KB）  
4. parse(buf) 得到 Request 与 consumed（或 ParseResult）；Request 持有 &[byte] 借用  
5. 构建 Context(request, response, conn)  
6. router.serve(&ctx)；若返回 !T 错误，写入 5xx 响应  
7. 写回 Response（status、headers、body）  
8. 若 Keep-alive，用 buf[consumed..]（或 remaining）作为下一轮 parse 输入，回到步骤 3；否则 Conn 离开作用域触发 drop

### 5.3 错误路径

- parse 失败 -> 4xx/5xx 响应 -> Send  
- 路由 404/405 -> 对应响应 -> Send  
- Handler 返回 !T 错误 -> 5xx -> Send  

### 5.4 epoll 预留

- ServerConfig.mode 含 ServerMode.Epoll；首版仅实现 ServerMode.Blocking，epoll 路径在 server.uya 中预留接口（如 run_epoll_loop 空实现或条件编译），便于后续扩展。

---

## 6. JWT 设计（jwt.uya）

### 6.1 职责边界

- jwt 模块**仅提供**：verify、decode（不验签）、sign、decode_base64url（payload 段 Base64URL 解码）。  
- **不依赖** get_bearer_token；get_bearer_token 在 types/同模块，由用户或中间件先取 token 再调用 `jwt.verify(token, secret)`。

### 6.2 API

- **verify(token: &[byte], secret: &[byte]) !&[byte]**（或返回含 payload 切片的简单结构体）：校验签名（HS256），返回 raw payload 切片；首版不依赖 std.json。  
- **decode(token: &[byte]) !&[byte]**：不验签，仅解码 payload 段。  
- **decode_base64url(payload_slice: &[byte]) !&[byte]**：Base64URL 解码，供 payload 解析使用。  
- **sign(payload: &[byte], secret: &[byte]) !&[byte]**（或写入调用方提供的 buffer）：签发 JWT（HS256）。  
- **has_expired(payload: &[byte]) bool**（可选）：解析 payload 中的 exp 与当前时间比较；首版可不实现，文档注明「仅验签，不校验过期」。

### 6.3 依赖

- HMAC-SHA256：若 Uya 无加密标准库，通过 FFI 调用 libc/OpenSSL 或自带最小实现；FFI 时注意 `*const byte` 与 `&[byte]` 的转换（见语法规范指针规则）。

---

## 7. 中间件设计（middleware.uya）

### 7.1 首版

- 仅定义 **Middleware** 接口类型（见 §2.4），不实现具体中间件。

### 7.2 后续

- 实现为「包装 Handler」：如 `fn logging(next: Handler) Handler`、`fn jwt_auth(next: Handler, secret: &[byte]) Handler`；jwt_auth 从 ctx 取 Bearer、调用 jwt.verify、失败返回 **401**；**403** 由业务 Handler 返回。

---

## 8. RESTful 与 JWT 行为汇总

- **HTTP 方法**：Method 枚举覆盖 GET/POST/PUT/PATCH/DELETE/OPTIONS/HEAD；路由按 (method, path) 匹配；405 表示方法不允许。  
- **路径参数**：path_pattern 如 `/users/:id`，提取后写入 Request.path_params，Handler 通过 path_params 按 key 取 value。  
- **查询串**：Request.query 线性数组，get_query(ctx, key) 或等价访问。  
- **状态码**：Response.status = Status.Created 等。  
- **请求/响应体**：Request.body / Response  body 为切片或缓冲区；Content-Type 由头部解析或设置。  
- **Multipart form**：Content-Type 为 multipart/form-data 时，通过 parse_multipart 或 Request.multipart() 得到 Part 列表（name、filename、content_type、body），用于表单提交与文件上传。  
- **JWT**：get_bearer_token(req) -> jwt.verify(token, secret) -> payload；无/无效 token 返回 401；权限不足由 Handler 返回 403。

---

## 9. 性能指标与验证

- **指标**：QPS/RPS、延迟（p50/p95/p99）、并发连接数、内存（RSS、每连接增量）、解析吞吐（可选）。  
- **场景**：plaintext、简单 JSON、带 path 参数；body 档位 small/medium/large（如 1KB/10KB/100KB）；首版基线不含 JWT。  
- **环境**：记录 CPU、内存、OS、编译器；CPU 亲和性（是否绑核）在文档中注明。  
- **工具**：wrk 时明确 keep-alive（如 `-H "Connection: keep-alive"`）；脚本解析 wrk 输出；基线存入 benchmarks/baseline.json；回归允许 ±5%。

---

## 10. 语法规范约束

- **接口方法**：`self: &Self`，符合 BNF method_sig（`fn ID '(' param_list ')' type ';'`）；接口类型作参数时按接口引用传递（如 next: Handler）。  
- **drop**：`fn drop(self: T) void`，按值、仅一参；只能在结构体内部或方法块中定义（禁止顶层），见 uya.md §12。  
- **错误**：预定义 `error_decl = 'error' ID ';'`，引用 `error_type = 'error' '.' ID`，返回类型 `!T`（error_union_type）。  
- **枚举字面量**：`enum_literal = ID '.' ID`（如 Status.OK、ServerMode.Blocking）。  
- **切片与数组**：切片 `slice_type = '&[' type ']' | '&[' type ';' NUM ']'`（即 &[byte]、&[byte; N]）；数组 `array_type = '[' type ':' NUM ']'`（即 [T: N]）。  
- **常量**：`const_decl = 'const' ID ':' type '=' expr ';'`；P、Q、L、MAX_ROUTES、MAX_MULTIPART_PARTS 等均用 const 声明。  
- **结构体字面量**：`struct_literal = ID '{' field_init_list '}'`，field_init = ID ':' expr；无命名实参，多参数用结构体字面量。

---

## 11. 参考

- 计划：[.cursor/plans/uya_高性能_http_框架_09efdaaa.plan.md](.cursor/plans/uya_高性能_http_框架_09efdaaa.plan.md)  
- 实现待办：[todo_http.md](todo_http.md)  
- 语法：[grammar_formal.md](grammar_formal.md)、[grammar_quick.md](grammar_quick.md)  
- 语言规范：[uya.md](uya.md)（§2 类型、§4 结构体、§5 函数、§6 接口、§12 内存与 RAII、§14 内存安全）
