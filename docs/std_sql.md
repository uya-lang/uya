# std.sql 模块说明

**更新日期**：2026-10-19

**核对依据**：`lib/std/sql/types.uya`、`lib/std/sql/driver.uya`、`lib/std/sql/db.uya`、`lib/std/sql/sql.uya`（模块入口仅有注释，无导出）与回归测试 `tests/test_std_sql.uya`。

---

## 模块定位

`std.sql` 是 Uya 标准库里的数据库通用抽象层，参考 Go `database/sql` 的分层思路，把业务侧 API 与具体数据库驱动解耦。

当前代码位于：

- `lib/std/sql/sql.uya`
- `lib/std/sql/types.uya`
- `lib/std/sql/driver.uya`
- `lib/std/sql/db.uya`

对应模块路径：

```uya
use std.sql;
use std.sql.types;
use std.sql.driver;
use std.sql.db;
```

---

## 当前能力

首版已落地以下公共抽象（下列签名与现有实现逐条对应）：

### `std.sql.types`（`lib/std/sql/types.uya`）

- `SqlBytesView`（`types.uya:12`）：`{ ptr: &byte, len: usize }`。零拷贝字节视图，同时用于 SQL 文本、列名、字符串值与原始字节值。
- `Value`（`types.uya:18`）：**`export union`**，六个变体：

  | 变体 | 载荷类型 |
  | --- | --- |
  | `Null` | `void` |
  | `Bool` | `bool` |
  | `Int64` | `i64` |
  | `Float64` | `f64` |
  | `Bytes` | `SqlBytesView` |
  | `String` | `SqlBytesView` |

- `NamedArg`（`types.uya:28`）：`{ ordinal: usize, name: SqlBytesView, value: Value }`。位置参数用 `ordinal`，命名参数用 `name`。
- `ColumnInfo`（`types.uya:35`）：`{ name: SqlBytesView, database_type: SqlBytesView, nullable: bool, has_nullable: bool }`。`has_nullable` 用来区分“不可空”与“驱动没提供该信息”。
- 构造/比较辅助：`sql_bytes_view_empty`、`sql_bytes_view_from_ptr`、`sql_bytes_view_from_slice`、`sql_bytes_view_eq`、`sql_value_null`、`sql_value_string`、`sql_value_bytes`、`sql_arg_pos`、`sql_arg_named`。

### `std.sql.driver`（`lib/std/sql/driver.uya`）

- `Result`（`driver.uya:10`）：`{ last_insert_id: i64, rows_affected: i64 }`，是普通结构体，不再套接口。
- 五个 `export interface`，形状固定为“普通返回值 + `out` 参数”：

  ```uya
  export interface Rows {
      fn column_count(self: &Self) usize;
      fn column_info(self: &Self, index: usize) ColumnInfo;
      fn next(self: &Self) bool;
      fn scan(self: &Self, dest: &Value, dest_len: usize) !void;
      fn close(self: &Self) void;
  }

  export interface Stmt {
      fn exec(self: &Self, args: &NamedArg, arg_count: usize) Result;
      fn query(self: &Self, args: &NamedArg, arg_count: usize, out: &Rows) void;
      fn close(self: &Self) void;
  }

  export interface Tx {
      fn prepare(self: &Self, query: &const byte, query_len: usize, out: &Stmt) void;
      fn exec(self: &Self, query: &const byte, query_len: usize, args: &NamedArg, arg_count: usize) Result;
      fn query(self: &Self, query: &const byte, query_len: usize, args: &NamedArg, arg_count: usize, out: &Rows) void;
      fn commit(self: &Self) !void;
      fn rollback(self: &Self) !void;
  }

  export interface Conn {
      fn prepare(self: &Self, query: &const byte, query_len: usize, out: &Stmt) void;
      fn exec(self: &Self, query: &const byte, query_len: usize, args: &NamedArg, arg_count: usize) Result;
      fn query(self: &Self, query: &const byte, query_len: usize, args: &NamedArg, arg_count: usize, out: &Rows) void;
      fn begin(self: &Self, out: &Tx) void;
      fn ping(self: &Self) !void;
      fn close(self: &Self) void;
  }

  export interface Driver {
      fn driver_name(self: &Self) SqlBytesView;
      fn open(self: &Self, dsn: &const byte, dsn_len: usize, out: &Conn) void;
  }
  ```

  注意 `Tx` 与 `Conn` 的 `prepare`/`exec`/`query` 用 `(&const byte, len)` 而不是 `&[byte]`：这是驱动侧接口，高层 `DB` 层负责把 slice 拆成指针+长度。

### `std.sql.db`（`lib/std/sql/db.uya`）

- `DB`（`db.uya:210`）：`{ conn: Conn, driver_name_view: SqlBytesView, closed: bool }`，方法 `driver_name`、`ping`、`prepare`、`exec`、`query`、`query_row`、`begin`、`close`。
- `Row`（`db.uya:33`）：`{ rows: Rows, closed: bool }`，方法 `scan(dest, dest_len) !void`、`close()`。**没有导出的构造函数**，只通过 `DB.query_row` 取得。
- `db_open`（`db.uya:272`）：

  ```uya
  export fn db_open(drv: Driver, dsn: &[byte]) DB
  ```

  返回 `DB` 值本身，**不是** `!DB`，也不返回指针。驱动打开失败在当前签名下只能由后续 `ping()`/调用点暴露。

### 错误集（`lib/std/sql/types.uya:4-9`）

`ErrNoRows`、`ErrDBClosed`、`ErrTxDone`、`ErrColumnOutOfRange`、`ErrScanDestTooSmall`、`ErrScanWithoutRow`。

其中 `ErrColumnOutOfRange`（列下标越界）与 `ErrScanDestTooSmall`（`dest_len` 小于列数）目前只声明、未在本层抛出，约定留给驱动实现使用；`ErrScanWithoutRow` 由 `db.uya` 内置的 `ClosedRows` 兜底返回。

---

## 回归测试覆盖

相关回归测试：`tests/test_std_sql.uya`（459 行，用 `FakeDriver`/`FakeRows`/`FakeStmt`/`FakeTx` 桩驱动跑通全链路）。

当前覆盖（`tests/test_std_sql.uya:451-458`）：

| 用例 | 覆盖内容 |
| --- | --- |
| `db open ping close` | `db_open`、`driver_name()`、`ping()`、`close()` 后 `ping` 返回 `ErrDBClosed` |
| `exec prepare result` | `DB.exec` 返回 `Result`、`DB.prepare` + `Stmt.exec` + `Stmt.close`、命名参数 `sql_arg_named` |
| `query and query_row` | `Rows.column_count` / `column_info` / `next` / `scan`、`DB.query_row` + `Row.scan` |
| `query_row no rows` | `Row.scan` 在无行时返回 `ErrNoRows` |
| `tx commit and done` | `DB.begin`、`Tx.exec`、`Tx.commit`，重复 `rollback` 返回 `ErrTxDone` |

`ErrColumnOutOfRange` / `ErrScanDestTooSmall` 尚无测试（无驱动会抛），`ErrScanWithoutRow` 由 `db.uya:88` 的 `ClosedRows.scan` 兜底。

---

## 设计取舍

为兼容当前 Uya C99 backend，`std.sql` 首版没有完全照搬 Go `database/sql` 的所有返回形式，而是做了几处有意收敛：

- 接口方法里，优先使用“普通返回值 + `out` 参数”的稳定组合
- `Stmt` / `Rows` / `Tx` / `Conn` 等接口值通过 `out: &Interface` 传出
- `Rows.next()` 当前返回 `bool`，扫描阶段的错误通过 `scan(...) !void` 传播
- `Result` 当前为普通结构体，不再额外套一层接口

这几处取舍是为了避开当前 codegen 在“接口方法返回接口”与部分复杂 `!T` 组合上的不稳定路径。后续如果编译器相关能力进一步收口，可以再把接口形状向更直观的 Go 风格回调。

---

## 最小使用方式

业务代码一般不直接依赖数据库厂商 API，而是拿到一个实现了 `driver.Driver` 的驱动，再通过 `db_open` 得到 `DB`：

```uya
// 【伪代码】本段只示意调用顺序与类型形状，不是可直接编译的代码：
// 下方 `<由驱动实现提供>` 标记的位置必须替换为该驱动导出的构造器，
// `std.sql` 自身不导出 Stmt/Rows 的兜底构造（`db.uya` 里的 ClosedStmt/ClosedRows
// 是私有 struct，仅供本层内部兜底）。
use std.sql.types.NamedArg;
use std.sql.types.Value;
use std.sql.driver.Driver;
use std.sql.driver.Stmt;
use std.sql.driver.Rows;
use std.sql.db.DB;
use std.sql.db.db_open;

fn use_db(drv: Driver) !void {
    // db_open 直接返回 DB（不是 !DB）
    const dbi: DB = db_open(drv, &"file:demo.db"[0: 12]);
    try dbi.ping();

    // <由驱动实现提供>：驱动侧导出的“空 Stmt”构造器，例如 native_stmt_new()
    var stmt: Stmt = <由驱动实现提供>;
    try dbi.prepare(&"select 1"[0: 8], &stmt);

    // <由驱动实现提供>：驱动侧导出的“空 Rows”构造器，例如 native_rows_new()
    var rows: Rows = <由驱动实现提供>;
    var args_buf: [NamedArg: 1] = [];
    const args: &[NamedArg] = args_buf[0: 0];
    try dbi.query(&"select 1"[0: 8], args, &rows);

    // next() 返回 bool，扫描错误由 scan(...) !void 传播
    var scanned: [Value: 2] = [];
    while rows.next() {
        try rows.scan(&scanned[0], 2);
    }
    rows.close();

    // 单行场景用 query_row：无行时 Row.scan 返回 error.ErrNoRows
    var one: [Value: 2] = [];
    const row: Row = try dbi.query_row(&"select 1"[0: 8], args);
    try row.scan(&one[0], 2);
}
```

`Row` 也需一并 `use std.sql.db.Row;`。`DB` 的每个方法在 `closed == true` 后都返回 `error.ErrDBClosed`（`db.uya:219-269`）。

---

## 如何接 SQLite

`SQLite` 是最推荐的第一个真实驱动，原因是 API 平坦、句柄简单、依赖轻。

建议做法：

1. 新建 `lib/std/sql/sqlite.uya`
2. 使用 `extern fn` 声明 `sqlite3_*` C API
3. 句柄先统一使用 `*void` 或外部 C 句柄指针，不直接搬运 `sqlite3` 内部结构体布局
4. 实现 `SQLiteDriver : Driver`
5. 实现 `SQLiteConn : Conn`
6. 实现 `SQLiteStmt : Stmt`
7. 实现 `SQLiteRows : Rows`
8. 实现 `SQLiteTx : Tx`

最常用的绑定点通常包括：

- `sqlite3_open_v2`
- `sqlite3_close`
- `sqlite3_prepare_v2`
- `sqlite3_finalize`
- `sqlite3_step`
- `sqlite3_reset`
- `sqlite3_bind_null`
- `sqlite3_bind_int64`
- `sqlite3_bind_double`
- `sqlite3_bind_text`
- `sqlite3_bind_blob`
- `sqlite3_column_count`
- `sqlite3_column_name`
- `sqlite3_column_type`
- `sqlite3_column_int64`
- `sqlite3_column_double`
- `sqlite3_column_text`
- `sqlite3_column_blob`
- `sqlite3_column_bytes`

构建时建议使用 hosted 路径：

```bash
bin/uya build your_sqlite_demo.uya -o /tmp/app --c99
```

如果你使用 SQLite amalgamation，也可以直接把 `sqlite3.c` 写进源码构建图：

```uya
@c_import(
    "third_party/sqlite/sqlite3.c",
    "-Ithird_party/sqlite -DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_LOAD_EXTENSION=1",
    "-ldl -lpthread"
);
```

若只想输出 C：

```bash
bin/uya build your_sqlite_demo.uya -o /tmp/app.c --c99 --no-split-c
# 额外生成：/tmp/app.cimports.sh
```

---

## 如何接 MySQL

`MySQL` 建议优先走 `libmysqlclient` 或 MariaDB Connector/C 的薄适配层。

和 SQLite 不同，MySQL 原生 C API 的结构体与 prepared statement 绑定结构更复杂，因此更推荐“C shim + Uya 驱动”的双层设计：

1. 新建 `lib/std/sql/mysql.uya`
2. 额外写一个很薄的 `mysql_shim.c`
3. shim 对外暴露平坦函数，例如 `uya_mysql_open`、`uya_mysql_prepare`、`uya_mysql_exec`、`uya_mysql_fetch`
4. Uya 侧只处理 `*void` 句柄、整数状态码、字节指针和长度

这样可以显著降低以下复杂度：

- `MYSQL`
- `MYSQL_STMT`
- `MYSQL_RES`
- `MYSQL_BIND`
- 不同发行版 MySQL / MariaDB 头文件差异

构建方式通常类似：

```bash
bin/uya build your_mysql_demo.uya -o /tmp/app --c99
```

如果你已经把 shim 写成一个目录，也可以直接递归导入：

```uya
@c_import("mysql_shim/");
@c_import("mysql_shim/", "", "-lmysqlclient");
```

更常见的单文件 shim 写法：

```uya
@c_import("mysql_shim.c", "", "-lmysqlclient");
```

---

## 生命周期与内存注意事项

当前 `std.sql` 的值类型里，`String` 和 `Bytes` 都是 `SqlBytesView`，属于零拷贝视图。

这意味着驱动实现者需要明确约束返回值生命周期：

- 最保守的约定：字符串/字节值只在当前行有效
- 如果底层数据库缓冲区会在下一次 `next()` 后失效，驱动应在 `scan()` 时复制到调用方可持有的缓冲区或 arena
- 纯零拷贝与长期持有通常不能同时保证，需要驱动文档明确说明

SQLite 通常比较容易在 `scan()` 阶段按需复制。
MySQL 如果直接复用结果缓冲，也要谨慎处理 `fetch` 后的数据失效边界。

---

## 后续规划

`std.sql` 当前处于“核心抽象已落地，真实驱动待补”的阶段。

截至 2026-10-19 核对：`lib/std/sql/` 只有 `types.uya` / `driver.uya` / `db.uya` / `sql.uya` 四个文件，仓库内没有任何真实驱动实现（`grep -rln "std.sql" lib tests examples` 仅命中这四个文件与 `tests/test_std_sql.uya`），因此本文档提到的 SQLite/MySQL/Postgres 驱动均**尚未存在**。

后续推荐顺序：

1. `std.sql.sqlite`
2. `std.sql.mysql`
3. `std.sql.postgres` 或 PostgreSQL 协议/`libpq` 适配
4. 连接池、超时、上下文取消等更高层能力

---

## 相关文件

- `lib/std/sql/types.uya`
- `lib/std/sql/driver.uya`
- `lib/std/sql/db.uya`
- `tests/test_std_sql.uya`
- `readme.md`
- `docs/uya.md`
- `docs/TESTING.md`
- `docs/changelog.md`
