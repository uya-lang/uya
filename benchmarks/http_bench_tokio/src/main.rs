//! 与 `benchmarks/http_bench.go` 对齐：同端口、同路由、同响应体长度（Keep-alive）。
//!
//! 运行（仓库根）：`cargo run --manifest-path benchmarks/http_bench_tokio/Cargo.toml --release`
//! 或在 `benchmarks/http_bench_tokio` 下：`cargo run --release`
//!
//! `--once`：accept 一次连接，处理首个请求后退出。

use bytes::Bytes;
use http_body_util::Full;
use hyper::body::Incoming;
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Request, Response, StatusCode};
use hyper_util::rt::TokioIo;
use std::convert::Infallible;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use tokio::net::TcpListener;

const BENCH_PORT: u16 = 8876;
const ADDR: &str = "127.0.0.1";

fn parse_bench_args() -> (bool, usize) {
    let mut once = false;
    let mut worker_threads = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(1);
    let mut args = std::env::args().skip(1).peekable();

    while let Some(arg) = args.next() {
        if arg == "--once" {
            once = true;
            continue;
        }
        if arg == "--threads" {
            if let Some(n) = args.next().and_then(|s| s.parse::<usize>().ok()) {
                if n > 0 {
                    worker_threads = n.min(64);
                }
            }
            continue;
        }
        if let Some(rest) = arg.strip_prefix("--threads=") {
            if let Ok(n) = rest.parse::<usize>() {
                if n > 0 {
                    worker_threads = n.min(64);
                }
            }
        }
    }

    (once, worker_threads)
}

fn payload_1k() -> &'static [u8] {
    static P: std::sync::OnceLock<Vec<u8>> = std::sync::OnceLock::new();
    P.get_or_init(|| vec![b'a'; 1024])
}

fn payload_10k() -> &'static [u8] {
    static P: std::sync::OnceLock<Vec<u8>> = std::sync::OnceLock::new();
    P.get_or_init(|| vec![b'a'; 10240])
}

fn payload_100k() -> &'static [u8] {
    static P: std::sync::OnceLock<Vec<u8>> = std::sync::OnceLock::new();
    P.get_or_init(|| vec![b'a'; 102400])
}

fn text_response(status: StatusCode, body: &[u8]) -> Response<Full<Bytes>> {
    Response::builder()
        .status(status)
        .header(hyper::header::CONTENT_TYPE, "text/plain")
        .body(Full::new(Bytes::copy_from_slice(body)))
        .unwrap()
}

fn handle_get(path: &str) -> Response<Full<Bytes>> {
    match path {
        "/" => text_response(StatusCode::OK, b"hello"),
        "/plaintext" => text_response(StatusCode::OK, b"hello"),
        "/json" => text_response(StatusCode::OK, br#"{"ok":true}"#),
        "/payload1k" => text_response(StatusCode::OK, payload_1k()),
        "/payload10k" => text_response(StatusCode::OK, payload_10k()),
        "/payload100k" => text_response(StatusCode::OK, payload_100k()),
        _ if path.starts_with("/item/") => {
            let rest = &path["/item/".len()..];
            if rest.is_empty() {
                text_response(StatusCode::BAD_REQUEST, &[])
            } else if rest.contains('/') {
                text_response(StatusCode::NOT_FOUND, &[])
            } else {
                text_response(StatusCode::OK, rest.as_bytes())
            }
        }
        _ => text_response(StatusCode::NOT_FOUND, &[]),
    }
}

async fn dispatch(req: Request<Incoming>) -> Result<Response<Full<Bytes>>, Infallible> {
    if req.method() != hyper::Method::GET {
        return Ok(text_response(StatusCode::METHOD_NOT_ALLOWED, &[]));
    }
    Ok(handle_get(req.uri().path()))
}

async fn run_server(once: bool) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let addr = format!("{}:{}", ADDR, BENCH_PORT);
    let listener = TcpListener::bind(&addr).await?;

    if once {
        let (stream, _) = listener.accept().await?;
        let io = TokioIo::new(stream);
        let counter = Arc::new(AtomicUsize::new(0));
        let service = service_fn(move |req| {
            let c = counter.clone();
            async move {
                let n = c.fetch_add(1, Ordering::SeqCst);
                if n > 0 {
                    return Ok::<_, Infallible>(text_response(StatusCode::BAD_REQUEST, &[]));
                }
                dispatch(req).await
            }
        });
        let conn = http1::Builder::new().keep_alive(false).serve_connection(io, service);
        conn.await?;
        return Ok(());
    }

    eprintln!("benchmark target http://{}/plaintext", addr);

    loop {
        let (stream, _) = listener.accept().await?;
        tokio::task::spawn(async move {
            let io = TokioIo::new(stream);
            let service = service_fn(dispatch);
            if let Err(e) = http1::Builder::new().serve_connection(io, service).await {
                eprintln!("connection error: {}", e);
            }
        });
    }
}

fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let (once, worker_threads) = parse_bench_args();
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(worker_threads)
        .enable_all()
        .build()?;
    if let Err(e) = runtime.block_on(run_server(once)) {
        eprintln!("{}", e);
        std::process::exit(1);
    }
    Ok(())
}
