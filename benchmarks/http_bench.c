// benchmarks/http_bench.c — 纯 C 多线程 epoll HTTP 服务器（与 http_bench.go 功能对齐）
//
// 路由与体大小（与 Go/Uya 版一致）：
//   GET /              → "hello"（5 字节）
//   GET /plaintext     → "hello"（5 字节，主 benchmark 入口）
//   GET /json          → {"ok":true}（11 字节）
//   GET /item/:id      → 体为路径参数 id（单段）
//   GET /payload1k     → 1024 字节 'a'
//   GET /payload10k    → 10240 字节 'a'
//   GET /payload100k   → 102400 字节 'a'
//
// 默认 127.0.0.1:8876；`--once`：accept 一次连接，处理首个请求后退出。
//
// 编译：
//   cc -O3 -Wall -Wextra -pthread -o http_bench_c http_bench.c
// 运行：
//   ./http_bench_c
//   ./http_bench_c -t 8  # 指定 8 线程
// 压测：
//   wrk -t4 -c64 -d10s http://127.0.0.1:8876/plaintext

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <sys/socket.h>
#include <sys/epoll.h>
#include <sys/mman.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <sys/uio.h>
#include <signal.h>

#define PORT 8876
#define BACKLOG 128
#define MAX_EVENTS 4096
#define BUF_SIZE 8192
#define MAX_PATH 256
#define DEFAULT_THREADS 44

// 预定义的 payload
static const char payload_1k[1024] = {[0 ... 1023] = 'a'};
static const char payload_10k[10240] = {[0 ... 10239] = 'a'};
static const char payload_100k[102400] = {[0 ... 102399] = 'a'};

// 线程本地数据
typedef struct {
    int epoll_fd;
    int listen_fd;
    pthread_t tid;
    int thread_id;
    volatile int shutdown;
} worker_ctx_t;

static int g_threads = DEFAULT_THREADS;
static worker_ctx_t* g_workers = NULL;

static void set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags == -1) flags = 0;
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

static const char* get_status_text(int code) {
    switch (code) {
        case 200: return "OK";
        case 400: return "Bad Request";
        case 404: return "Not Found";
        case 405: return "Method Not Allowed";
        default:  return "Unknown";
    }
}

static void make_response(int fd, int status, const char* body, size_t body_len) {
    const char* status_text = get_status_text(status);
    char header[BUF_SIZE];
    int header_len = snprintf(header, BUF_SIZE,
        "HTTP/1.1 %d %s\r\n"
        "Content-Length: %zu\r\n"
        "Content-Type: text/plain\r\n"
        "Connection: close\r\n"
        "\r\n",
        status, status_text, body_len);

    struct iovec iov[2];
    iov[0].iov_base = header;
    iov[0].iov_len = header_len;
    iov[1].iov_base = (void*)body;
    iov[1].iov_len = body_len;

    writev(fd, iov, 2);
}

static void make_error_response(int fd, int status) {
    make_response(fd, status, "", 0);
}

static int parse_path(const char* path) {
    if (strcmp(path, "/") == 0) return 0;
    if (strcmp(path, "/json") == 0) return 1;
    if (strncmp(path, "/item/", 6) == 0) return 2;
    if (strcmp(path, "/payload1k") == 0) return 3;
    if (strcmp(path, "/payload10k") == 0) return 4;
    if (strcmp(path, "/payload100k") == 0) return 5;
    if (strcmp(path, "/plaintext") == 0) return 6;
    return -1;
}

static void handle_request(int fd, const char* method, const char* path) {
    if (strcmp(method, "GET") != 0) {
        make_error_response(fd, 405);
        return;
    }

    int route = parse_path(path);
    switch (route) {
        case 0:
            make_response(fd, 200, "hello", 5);
            break;
        case 1:
            make_response(fd, 200, "{\"ok\":true}", 11);
            break;
        case 2: {
            const char* id = path + 6;
            size_t id_len = strlen(id);
            if (id_len == 0 || strchr(id, '/') != NULL) {
                make_error_response(fd, id_len == 0 ? 400 : 404);
            } else {
                make_response(fd, 200, id, id_len);
            }
            break;
        }
        case 3:
            make_response(fd, 200, payload_1k, 1024);
            break;
        case 4:
            make_response(fd, 200, payload_10k, 10240);
            break;
        case 5:
            make_response(fd, 200, payload_100k, 102400);
            break;
        case 6:
            make_response(fd, 200, "hello", 5);
            break;
        default:
            make_error_response(fd, 404);
            break;
    }
}

static void process_request(int fd, char* buf) {
    char* crlf = strstr(buf, "\r\n");
    if (!crlf) return;

    *crlf = '\0';

    char method[16] = {0};
    char path[MAX_PATH] = {0};
    if (sscanf(buf, "%15s %255s", method, path) != 2) {
        make_error_response(fd, 400);
        return;
    }

    handle_request(fd, method, path);
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

    return fd;
}

static void* worker_thread(void* arg) {
    worker_ctx_t* ctx = (worker_ctx_t*)arg;

    struct epoll_event ev = {0};
    ev.events = EPOLLIN;
    ev.data.fd = ctx->listen_fd;
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
            int fd = events[i].data.fd;

            if (fd == ctx->listen_fd) {
                // 接受新连接
                struct sockaddr_in client_addr;
                socklen_t client_len = sizeof(client_addr);
                int conn_fd = accept(ctx->listen_fd, (struct sockaddr*)&client_addr, &client_len);
                if (conn_fd < 0) continue;

                int nodelay = 1;
                setsockopt(conn_fd, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
                set_nonblocking(conn_fd);

                struct epoll_event cev = {0};
                cev.events = EPOLLIN | EPOLLET;
                cev.data.fd = conn_fd;
                epoll_ctl(ctx->epoll_fd, EPOLL_CTL_ADD, conn_fd, &cev);
            } else {
                // 客户端事件
                if (events[i].events & (EPOLLERR | EPOLLHUP | EPOLLIN)) {
                    char buf[BUF_SIZE];
                    ssize_t nread = read(fd, buf, sizeof(buf));

                    if (nread > 0) {
                        buf[nread] = '\0';
                        if (strstr(buf, "\r\n\r\n") != NULL) {
                            process_request(fd, buf);
                        }
                    }

                    // HTTP 响应发送后关闭连接（Connection: close）
                    close(fd);
                    epoll_ctl(ctx->epoll_fd, EPOLL_CTL_DEL, fd, NULL);
                }
            }
        }
    }

    return NULL;
}

static void run_server(void) {
    // 为每个线程创建独立的 listen socket（使用 SO_REUSEPORT）
    g_workers = calloc(g_threads, sizeof(worker_ctx_t));
    if (!g_workers) {
        perror("calloc");
        exit(1);
    }

    for (int i = 0; i < g_threads; i++) {
        int listen_fd = create_listen_socket();
        if (listen_fd < 0) {
            exit(1);
        }

        if (listen(listen_fd, BACKLOG) < 0) {
            perror("listen");
            close(listen_fd);
            exit(1);
        }

        int epoll_fd = epoll_create1(0);
        if (epoll_fd < 0) {
            perror("epoll_create1");
            close(listen_fd);
            exit(1);
        }

        g_workers[i].epoll_fd = epoll_fd;
        g_workers[i].listen_fd = listen_fd;
        g_workers[i].thread_id = i;
        g_workers[i].shutdown = 0;
    }

    fprintf(stderr, "benchmark target http://127.0.0.1:%d/plaintext (threads=%d)\n", PORT, g_threads);

    // 启动 worker 线程
    for (int i = 0; i < g_threads; i++) {
        if (pthread_create(&g_workers[i].tid, NULL, worker_thread, &g_workers[i]) != 0) {
            perror("pthread_create");
            exit(1);
        }
    }

    // 等待所有线程
    for (int i = 0; i < g_threads; i++) {
        pthread_join(g_workers[i].tid, NULL);
    }

    // 清理
    for (int i = 0; i < g_threads; i++) {
        close(g_workers[i].epoll_fd);
        close(g_workers[i].listen_fd);
    }
    free(g_workers);
}

static void run_once(void) {
    int listen_fd = create_listen_socket();
    if (listen_fd < 0) {
        exit(1);
    }

    if (listen(listen_fd, 1) < 0) {
        perror("listen");
        close(listen_fd);
        exit(1);
    }

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

    // 读取请求
    char buf[BUF_SIZE];
    int total = 0;
    while (1) {
        ssize_t n = read(conn_fd, buf + total, BUF_SIZE - total - 1);
        if (n < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (n == 0) break;
        total += n;
        buf[total] = '\0';
        if (strstr(buf, "\r\n\r\n") != NULL) break;
        if (total >= BUF_SIZE - 1) break;
    }

    // 处理请求
    process_request(conn_fd, buf);

    close(conn_fd);
}

static void signal_handler(int sig) {
    (void)sig;
    if (g_workers) {
        for (int i = 0; i < g_threads; i++) {
            g_workers[i].shutdown = 1;
        }
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
            if (g_threads > 64) g_threads = 64;
        }
    }

    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    if (once) {
        run_once();
    } else {
        run_server();
    }

    return 0;
}
