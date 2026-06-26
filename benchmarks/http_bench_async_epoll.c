// benchmarks/http_bench_async_epoll.c — 纯 C 异步多线程 epoll HTTP 服务器
//
// 手写状态机版本，与 http_bench_async_epoll.uya 行为对齐：
// - 多 reactor（每线程独立 listen + epoll，SO_REUSEPORT）
// - 每个连接用状态机管理（非阻塞读写、Keep-Alive 复用）
// - 固定槽位池，避免 per-connection malloc
//
// 路由：
//   GET /          → "hello"（5 字节）
//   GET /plaintext → "hello"（5 字节，主 benchmark 入口）
//   GET /json      → {"ok":true}（11 字节）
//
// 编译：cc -O3 -Wall -Wextra -pthread -o http_bench_async_epoll http_bench_async_epoll.c
// 运行：./http_bench_async_epoll
//       ./http_bench_async_epoll -t 8

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <sys/socket.h>
#include <sys/epoll.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <signal.h>

#define PORT 8876
#define BACKLOG 8192
#define MAX_EVENTS 4096
#define SLOT_READ_CAP 2048
#define MAX_PATH_LEN 256
#define MAX_CONNS 1024
#define DEFAULT_THREADS 28
#define MAX_THREADS 64
#define BENCH_WORKER_STACK_BYTES (8 * 1024 * 1024)

typedef enum {
    STATE_READ_HEADER,
    STATE_WRITE_RESPONSE,
    STATE_CLOSING
} conn_state_t;

typedef struct {
    int fd;
    conn_state_t state;

    char read_buf[SLOT_READ_CAP];
    size_t read_filled;

    char resp_buf[512];
    size_t resp_len;
    size_t resp_sent;

    int wants_close;
    int http11;
    int http10_session_keep_alive;

    size_t header_end;
    size_t content_len;
    size_t req_consumed;
    int active;
} conn_t;

typedef struct {
    int epoll_fd;
    int listen_fd;
    pthread_t tid;
    int thread_id;
    volatile int shutdown;

    conn_t conns[MAX_CONNS];
    int free_stack[MAX_CONNS];
    int free_top;
} worker_ctx_t;

static int g_threads = DEFAULT_THREADS;
static worker_ctx_t g_workers[MAX_THREADS];

static void set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags == -1) flags = 0;
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

static int create_listen_socket(void) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) {
        perror("socket");
        return -1;
    }

    int opt = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
#ifdef SO_REUSEPORT
    setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));
#endif
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    addr.sin_port = htons(PORT);

    if (bind(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(fd);
        return -1;
    }

    if (listen(fd, BACKLOG) < 0) {
        perror("listen");
        close(fd);
        return -1;
    }

    set_nonblocking(fd);
    return fd;
}

static size_t fmt_usize_dec(char* buf, size_t n) {
    if (n == 0) {
        buf[0] = '0';
        return 1;
    }
    char tmp[24];
    size_t t = 0;
    size_t x = n;
    while (x > 0 && t < 24) {
        tmp[t++] = (char)('0' + (x % 10));
        x /= 10;
    }
    size_t i = 0;
    while (i < t) {
        buf[i] = tmp[t - 1 - i];
        i++;
    }
    return t;
}

static int build_http_ok_response(
    char* hdr_buf, size_t hdr_cap,
    size_t body_len, int close_after,
    size_t* out_hdr_len
) {
    size_t pos = 0;
    const char* line1 = "HTTP/1.1 200 OK\r\n";
    size_t line1_len = 17;
    if (pos + line1_len > hdr_cap) return 0;
    memcpy(hdr_buf + pos, line1, line1_len);
    pos += line1_len;

    const char* conn_hdr = close_after ? "Connection: close\r\n" : "Connection: keep-alive\r\n";
    size_t conn_len = close_after ? 19 : 24;
    if (pos + conn_len > hdr_cap) return 0;
    memcpy(hdr_buf + pos, conn_hdr, conn_len);
    pos += conn_len;

    const char* ct = "Content-Type: text/plain\r\nContent-Length: ";
    size_t ct_len = 42;
    if (pos + ct_len > hdr_cap) return 0;
    memcpy(hdr_buf + pos, ct, ct_len);
    pos += ct_len;

    pos += fmt_usize_dec(hdr_buf + pos, body_len);
    if (pos + 4 > hdr_cap) return 0;
    hdr_buf[pos++] = '\r';
    hdr_buf[pos++] = '\n';
    hdr_buf[pos++] = '\r';
    hdr_buf[pos++] = '\n';

    *out_hdr_len = pos;
    return 1;
}

static size_t find_header_end(const char* buf, size_t len) {
    if (len < 4) return 0;
    for (size_t k = 0; k + 4 <= len; k++) {
        if (buf[k] == '\r' && buf[k+1] == '\n' && buf[k+2] == '\r' && buf[k+3] == '\n') {
            return k + 4;
        }
    }
    return 0;
}

static int is_get_prefix(const char* buf, size_t len) {
    return len >= 4 && buf[0] == 'G' && buf[1] == 'E' && buf[2] == 'T' && buf[3] == ' ';
}

static int parse_request_line_path(const char* buf, size_t len, size_t* path_start, size_t* path_len) {
    if (!is_get_prefix(buf, len)) return 0;
    size_t pe = 4;
    while (pe < len && buf[pe] != ' ') pe++;
    if (pe >= len) return 0;
    size_t pl = pe - 4;
    if (pl == 0 || pl > MAX_PATH_LEN) return 0;
    *path_start = 4;
    *path_len = pl;
    return 1;
}

static size_t scan_content_length(const char* buf, size_t len) {
    for (size_t i = 0; i + 15 < len; i++) {
        if ((buf[i] == 'C' || buf[i] == 'c') && (buf[i+1] == 'O' || buf[i+1] == 'o')) {
            int ok = 1;
            const char* pat = "ontent-Length:";
            for (size_t t = 0; t < 14; t++) {
                char c = buf[i + 2 + t];
                char e = pat[t];
                if (c != e && c != (e - 32) && c != (e + 32)) {
                    ok = 0;
                    break;
                }
            }
            if (ok) {
                size_t vs = i + 16;
                while (vs < len && (buf[vs] == ' ' || buf[vs] == '\t')) vs++;
                size_t cl = 0;
                while (vs < len && buf[vs] >= '0' && buf[vs] <= '9') {
                    cl = cl * 10 + (size_t)(buf[vs] - '0');
                    vs++;
                }
                return cl;
            }
        }
    }
    return 0;
}

static int request_is_http11(const char* buf, size_t len) {
    for (size_t j = 0; j + 8 < len; j++) {
        if (buf[j] == 'H' && buf[j+1] == 'T' && buf[j+2] == 'T' && buf[j+3] == 'P' &&
            buf[j+4] == '/' && buf[j+5] == '1' && buf[j+6] == '.' && buf[j+7] == '1') {
            return 1;
        }
    }
    return 0;
}

static int bench_wants_close_with_session(const char* buf, size_t he, int http10_session_keep_alive) {
    int http11 = request_is_http11(buf, he);
    int wants_close = 1;
    int has_connection = 0;
    for (size_t i = 0; i + 11 < he; i++) {
        if ((buf[i] == 'C' || buf[i] == 'c') &&
            (buf[i+1] == 'O' || buf[i+1] == 'o') &&
            (buf[i+2] == 'N' || buf[i+2] == 'n') &&
            (buf[i+3] == 'N' || buf[i+3] == 'n') &&
            (buf[i+4] == 'E' || buf[i+4] == 'e') &&
            (buf[i+5] == 'C' || buf[i+5] == 'c') &&
            (buf[i+6] == 'T' || buf[i+6] == 't') &&
            (buf[i+7] == 'I' || buf[i+7] == 'i') &&
            (buf[i+8] == 'O' || buf[i+8] == 'o') &&
            (buf[i+9] == 'N' || buf[i+9] == 'n') &&
            buf[i+10] == ':') {
            size_t val_start = i + 11;
            while (val_start < he && (buf[val_start] == ' ' || buf[val_start] == '\t')) val_start++;
            has_connection = 1;
            if (val_start + 9 < he &&
                (buf[val_start] == 'k' || buf[val_start] == 'K') &&
                (buf[val_start+1] == 'e' || buf[val_start+1] == 'E') &&
                (buf[val_start+2] == 'e' || buf[val_start+2] == 'E') &&
                (buf[val_start+3] == 'p' || buf[val_start+3] == 'P') &&
                buf[val_start+4] == '-' &&
                (buf[val_start+5] == 'a' || buf[val_start+5] == 'A') &&
                (buf[val_start+6] == 'l' || buf[val_start+6] == 'L') &&
                (buf[val_start+7] == 'i' || buf[val_start+7] == 'I') &&
                (buf[val_start+8] == 'v' || buf[val_start+8] == 'V') &&
                (buf[val_start+9] == 'e' || buf[val_start+9] == 'E')) {
                wants_close = 0;
            }
            if (val_start + 4 < he &&
                (buf[val_start] == 'c' || buf[val_start] == 'C') &&
                (buf[val_start+1] == 'l' || buf[val_start+1] == 'L') &&
                (buf[val_start+2] == 'o' || buf[val_start+2] == 'O') &&
                (buf[val_start+3] == 's' || buf[val_start+3] == 'S') &&
                (buf[val_start+4] == 'e' || buf[val_start+4] == 'E')) {
                wants_close = 1;
            }
            break;
        }
    }
    if (!has_connection) {
        if (http10_session_keep_alive) {
            wants_close = 0;
        } else {
            wants_close = !http11;
        }
    }
    return wants_close;
}

static int path_is_slash(const char* buf, size_t path_start, size_t path_len) {
    return path_len == 1 && buf[path_start] == '/';
}

static int path_is_plaintext(const char* buf, size_t path_start, size_t path_len) {
    if (path_len != 10) return 0;
    return memcmp(buf + path_start, "/plaintext", 10) == 0;
}

static int path_is_json(const char* buf, size_t path_start, size_t path_len) {
    if (path_len != 5) return 0;
    const char* p = buf + path_start;
    return p[0] == '/' && p[1] == 'j' && p[2] == 's' && p[3] == 'o' && p[4] == 'n';
}

static int prepare_response(conn_t* conn, size_t he) {
    size_t content_len = scan_content_length(conn->read_buf, he);
    conn->content_len = content_len;
    conn->req_consumed = he + content_len;

    size_t ps = 0, pl = 0;
    if (!parse_request_line_path(conn->read_buf, he, &ps, &pl)) {
        return 0;
    }

    conn->http11 = request_is_http11(conn->read_buf, he);
    conn->wants_close = bench_wants_close_with_session(conn->read_buf, he, conn->http10_session_keep_alive);

    size_t body_len = 5;
    const char* body = "hello";
    if (path_is_json(conn->read_buf, ps, pl)) {
        body_len = 11;
        body = "{\"ok\":true}";
    } else if (!path_is_slash(conn->read_buf, ps, pl) && !path_is_plaintext(conn->read_buf, ps, pl)) {
        return 0;
    }

    size_t hdr_len = 0;
    if (!build_http_ok_response(conn->resp_buf, sizeof(conn->resp_buf), body_len, conn->wants_close, &hdr_len)) {
        return 0;
    }

    if (hdr_len + body_len > sizeof(conn->resp_buf)) {
        return 0;
    }
    memcpy(conn->resp_buf + hdr_len, body, body_len);
    conn->resp_len = hdr_len + body_len;
    conn->resp_sent = 0;
    return 1;
}

static void close_client_fd_quiet(int fd) {
    if (fd < 0) return;
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags != -1 && (flags & O_NONBLOCK) == 0) {
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }
    char junk[4096];
    while (1) {
        ssize_t n = read(fd, junk, sizeof(junk));
        if (n <= 0) break;
    }
    close(fd);
}

static conn_t* alloc_conn(worker_ctx_t* ctx) {
    if (ctx->free_top > 0) {
        int idx = ctx->free_stack[--ctx->free_top];
        conn_t* c = &ctx->conns[idx];
        memset(c, 0, sizeof(conn_t));
        c->fd = -1;
        c->active = 1;
        return c;
    }
    for (int i = 0; i < MAX_CONNS; i++) {
        if (!ctx->conns[i].active) {
            conn_t* c = &ctx->conns[i];
            memset(c, 0, sizeof(conn_t));
            c->fd = -1;
            c->active = 1;
            return c;
        }
    }
    return NULL;
}

static void free_conn(worker_ctx_t* ctx, conn_t* conn) {
    if (!conn || !conn->active) return;
    if (conn->fd >= 0) {
        struct epoll_event ev;
        epoll_ctl(ctx->epoll_fd, EPOLL_CTL_DEL, conn->fd, &ev);
        close_client_fd_quiet(conn->fd);
    }
    int idx = (int)(conn - ctx->conns);
    if (idx >= 0 && idx < MAX_CONNS) {
        conn->active = 0;
        conn->fd = -1;
        ctx->free_stack[ctx->free_top++] = idx;
    }
}

static int conn_epoll_mod(worker_ctx_t* ctx, conn_t* conn, uint32_t events) {
    struct epoll_event ev;
    ev.events = events;
    ev.data.ptr = conn;
    return epoll_ctl(ctx->epoll_fd, EPOLL_CTL_MOD, conn->fd, &ev);
}

static int conn_epoll_add(worker_ctx_t* ctx, conn_t* conn, uint32_t events) {
    struct epoll_event ev;
    ev.events = events;
    ev.data.ptr = conn;
    return epoll_ctl(ctx->epoll_fd, EPOLL_CTL_ADD, conn->fd, &ev);
}

static void on_conn_readable(worker_ctx_t* ctx, conn_t* conn) {
    while (1) {
        if (conn->state != STATE_READ_HEADER) return;

        if (conn->read_filled >= SLOT_READ_CAP) {
            free_conn(ctx, conn);
            return;
        }

        size_t he = find_header_end(conn->read_buf, conn->read_filled);
        if (he == 0) {
            ssize_t n = read(conn->fd, conn->read_buf + conn->read_filled, SLOT_READ_CAP - conn->read_filled);
            if (n < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    conn_epoll_mod(ctx, conn, EPOLLIN);
                    return;
                }
                free_conn(ctx, conn);
                return;
            }
            if (n == 0) {
                free_conn(ctx, conn);
                return;
            }
            conn->read_filled += (size_t)n;
            he = find_header_end(conn->read_buf, conn->read_filled);
            if (he == 0) {
                if (conn->read_filled >= SLOT_READ_CAP) {
                    free_conn(ctx, conn);
                    return;
                }
                continue;
            }
        }

        if (!prepare_response(conn, he)) {
            free_conn(ctx, conn);
            return;
        }

        conn->state = STATE_WRITE_RESPONSE;
        if (conn_epoll_mod(ctx, conn, EPOLLOUT) < 0) {
            free_conn(ctx, conn);
        }
        return;
    }
}

static void on_conn_writable(worker_ctx_t* ctx, conn_t* conn) {
    while (1) {
        if (conn->state != STATE_WRITE_RESPONSE) return;

        if (conn->resp_sent >= conn->resp_len) {
            if (conn->wants_close) {
                free_conn(ctx, conn);
                return;
            }
            if (!conn->http11) {
                conn->http10_session_keep_alive = 1;
            }
            size_t consumed = conn->req_consumed;
            if (consumed < conn->read_filled) {
                memmove(conn->read_buf, conn->read_buf + consumed, conn->read_filled - consumed);
                conn->read_filled -= consumed;
            } else {
                conn->read_filled = 0;
            }
            conn->header_end = 0;
            conn->content_len = 0;
            conn->wants_close = 0;
            conn->req_consumed = 0;
            conn->http11 = 0;
            conn->resp_len = 0;
            conn->resp_sent = 0;
            conn->state = STATE_READ_HEADER;
            if (conn_epoll_mod(ctx, conn, EPOLLIN) < 0) {
                free_conn(ctx, conn);
            }
            return;
        }

        ssize_t n = write(conn->fd, conn->resp_buf + conn->resp_sent, conn->resp_len - conn->resp_sent);
        if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                conn_epoll_mod(ctx, conn, EPOLLOUT);
                return;
            }
            free_conn(ctx, conn);
            return;
        }
        if (n == 0) {
            free_conn(ctx, conn);
            return;
        }
        conn->resp_sent += (size_t)n;
    }
}

static void accept_connections(worker_ctx_t* ctx) {
    while (1) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        int conn_fd = accept(ctx->listen_fd, (struct sockaddr*)&client_addr, &client_len);
        if (conn_fd < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) break;
            break;
        }

        int nodelay = 1;
        setsockopt(conn_fd, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
        set_nonblocking(conn_fd);

        conn_t* conn = alloc_conn(ctx);
        if (!conn) {
            close_client_fd_quiet(conn_fd);
            continue;
        }
        conn->fd = conn_fd;
        conn->state = STATE_READ_HEADER;
        if (conn_epoll_add(ctx, conn, EPOLLIN) < 0) {
            close(conn_fd);
            conn->active = 0;
        }
    }
}

static void* worker_thread(void* arg) {
    worker_ctx_t* ctx = (worker_ctx_t*)arg;

    struct epoll_event ev;
    ev.events = EPOLLIN;
    ev.data.ptr = NULL;
    if (epoll_ctl(ctx->epoll_fd, EPOLL_CTL_ADD, ctx->listen_fd, &ev) < 0) {
        perror("epoll_ctl add listen");
        return NULL;
    }

    struct epoll_event events[MAX_EVENTS];

    while (!ctx->shutdown) {
        int n = epoll_wait(ctx->epoll_fd, events, MAX_EVENTS, 100);
        if (n < 0) {
            if (errno == EINTR) continue;
            break;
        }

        for (int i = 0; i < n; i++) {
            void* ptr = events[i].data.ptr;
            if (ptr == NULL) {
                accept_connections(ctx);
            } else {
                conn_t* conn = (conn_t*)ptr;
                if (!conn->active) continue;
                if (events[i].events & (EPOLLERR | EPOLLHUP)) {
                    free_conn(ctx, conn);
                    continue;
                }
                if (events[i].events & EPOLLIN) {
                    on_conn_readable(ctx, conn);
                }
                if (events[i].events & EPOLLOUT) {
                    on_conn_writable(ctx, conn);
                }
            }
        }
    }

    for (int i = 0; i < MAX_CONNS; i++) {
        if (ctx->conns[i].active) {
            free_conn(ctx, &ctx->conns[i]);
        }
    }

    return NULL;
}

static void run_server(void) {
    for (int i = 0; i < g_threads; i++) {
        worker_ctx_t* ctx = &g_workers[i];
        ctx->thread_id = i;
        ctx->shutdown = 0;
        ctx->free_top = 0;
        memset(ctx->conns, 0, sizeof(ctx->conns));

        ctx->listen_fd = create_listen_socket();
        if (ctx->listen_fd < 0) {
            exit(1);
        }

        ctx->epoll_fd = epoll_create1(0);
        if (ctx->epoll_fd < 0) {
            perror("epoll_create1");
            close(ctx->listen_fd);
            exit(1);
        }
    }

    fprintf(stderr, "benchmark target http://127.0.0.1:%d/plaintext (threads=%d)\n", PORT, g_threads);

    pthread_attr_t attr;
    pthread_attr_init(&attr);
    size_t stacksize = BENCH_WORKER_STACK_BYTES;
    pthread_attr_setstacksize(&attr, stacksize);

    for (int i = 0; i < g_threads; i++) {
        if (pthread_create(&g_workers[i].tid, &attr, worker_thread, &g_workers[i]) != 0) {
            perror("pthread_create");
            exit(1);
        }
    }

    pthread_attr_destroy(&attr);

    for (int i = 0; i < g_threads; i++) {
        pthread_join(g_workers[i].tid, NULL);
    }

    for (int i = 0; i < g_threads; i++) {
        close(g_workers[i].epoll_fd);
        close(g_workers[i].listen_fd);
    }
}

static void run_once(void) {
    int listen_fd = create_listen_socket();
    if (listen_fd < 0) exit(1);

    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    int conn_fd = accept(listen_fd, (struct sockaddr*)&client_addr, &client_len);
    if (conn_fd < 0) {
        perror("accept");
        close(listen_fd);
        exit(1);
    }
    close(listen_fd);

    int nodelay = 1;
    setsockopt(conn_fd, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));

    char buf[4096];
    int total = 0;
    while (1) {
        int n = (int)read(conn_fd, buf + total, sizeof(buf) - total - 1);
        if (n < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (n == 0) break;
        total += n;
        buf[total] = '\0';
        if (strstr(buf, "\r\n\r\n") != NULL) break;
        if (total >= (int)sizeof(buf) - 1) break;
    }

    size_t he = find_header_end(buf, total);
    if (he != 0) {
        conn_t conn = {0};
        memcpy(conn.read_buf, buf, total);
        conn.read_filled = total;
        if (prepare_response(&conn, he)) {
            write(conn_fd, conn.resp_buf, conn.resp_len);
        }
    }
    close(conn_fd);
}

static void signal_handler(int sig) {
    (void)sig;
    for (int i = 0; i < g_threads; i++) {
        g_workers[i].shutdown = 1;
    }
}

int main(int argc, char* argv[]) {
    int once = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--once") == 0) {
            once = 1;
        } else if (strcmp(argv[i], "-t") == 0 && i + 1 < argc) {
            g_threads = atoi(argv[++i]);
            if (g_threads < 1) g_threads = DEFAULT_THREADS;
            if (g_threads > MAX_THREADS) g_threads = MAX_THREADS;
        }
    }

    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    signal(SIGPIPE, SIG_IGN);

    if (once) {
        run_once();
    } else {
        run_server();
    }

    return 0;
}
