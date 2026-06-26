#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
import shutil
import shlex
import signal
import socket
import statistics
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
BENCH_DIR = REPO_ROOT / "benchmarks"
DEFAULT_OUTPUT_ROOT = REPO_ROOT / "build" / "uyagin_http_bench"
DEFAULT_UYA_SOURCE = BENCH_DIR / "uyagin_http_bench.uya"
DEFAULT_GIN_DIR = BENCH_DIR / "uyagin_http_bench_gin"

DEFAULT_UYA_PORT = 18876
DEFAULT_GIN_PORT = 18877
DEFAULT_SERVER_THREADS = 4
DEFAULT_WRK_THREADS = 4
DEFAULT_CONNECTIONS = 64
DEFAULT_DURATION = "10s"
DEFAULT_RUNS = 5
DEFAULT_CPU_PROBE_DURATION = "5s"
DEFAULT_CPU_PROBE_CONNECTIONS = 4

TARGET_RPS_RATIO = 1.20
TARGET_P99_RATIO = 0.85
TARGET_HEAP_FALLBACK_DELTA = 0
TARGET_SYSCALL_WRITE_PER_REQ = 1.10
TARGET_SYSCALL_READ_EPOLL_PER_REQ = 1.50
TARGET_CPU_PROBE_RPS_FACTOR = 0.80
TARGET_CPU_PROBE_TOLERANCE = 0.10


@dataclass(frozen=True)
class Scenario:
    name: str
    path: str
    headers: dict[str, str]


SCENARIOS: tuple[Scenario, ...] = (
    Scenario("hello_plaintext", "/plaintext", {}),
    Scenario("json_small", "/json", {}),
    Scenario("path_param", "/users/42", {}),
    Scenario("middleware_x3", "/middleware/ping", {"Authorization": "Bearer bench"}),
    Scenario("large_body", "/blob64k", {}),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run P7 UyaGin vs Gin HTTP benchmarks.")
    parser.add_argument("--runs", type=int, default=DEFAULT_RUNS)
    parser.add_argument("--wrk-threads", type=int, default=DEFAULT_WRK_THREADS)
    parser.add_argument("--connections", type=int, default=DEFAULT_CONNECTIONS)
    parser.add_argument("--duration", default=DEFAULT_DURATION)
    parser.add_argument("--server-threads", type=int, default=DEFAULT_SERVER_THREADS)
    parser.add_argument("--uya-port", type=int, default=DEFAULT_UYA_PORT)
    parser.add_argument("--gin-port", type=int, default=DEFAULT_GIN_PORT)
    parser.add_argument("--out-dir", default="")
    parser.add_argument("--backend", action="append", choices=["uya", "gin"])
    parser.add_argument("--scenario", action="append", choices=[item.name for item in SCENARIOS])
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--skip-syscall-probe", action="store_true")
    parser.add_argument("--skip-cpu-probe", action="store_true")
    parser.add_argument("--cpu-probe-duration", default=DEFAULT_CPU_PROBE_DURATION)
    parser.add_argument("--cpu-probe-rps", type=float, default=0.0)
    parser.add_argument("--cpu-probe-connections", type=int, default=DEFAULT_CPU_PROBE_CONNECTIONS)
    parser.add_argument("--fail-on-target", action="store_true")
    return parser.parse_args()


def require_command(name: str) -> str:
    path = shutil.which(name)
    if path:
        return path
    raise SystemExit(f"missing dependency: {name}")


def resolve_go() -> str:
    env_go = os.environ.get("GO", "")
    if env_go:
        return env_go
    path_go = shutil.which("go")
    if path_go:
        return path_go
    alt_go = "/home/winger/work/go/bin/go"
    if Path(alt_go).exists():
        return alt_go
    raise SystemExit("missing dependency: go")


def run_checked(cmd: list[str], *, cwd: Path | None = None, env: dict[str, str] | None = None, stdout_path: Path | None = None) -> subprocess.CompletedProcess[str]:
    stdout: int | Any
    if stdout_path is None:
        stdout = subprocess.PIPE
        stderr = subprocess.STDOUT
    else:
        stdout_path.parent.mkdir(parents=True, exist_ok=True)
        fp = stdout_path.open("w", encoding="utf-8")
        try:
            completed = subprocess.run(
                cmd,
                cwd=cwd,
                env=env,
                text=True,
                stdout=fp,
                stderr=subprocess.STDOUT,
                check=False,
            )
        finally:
            fp.close()
        if completed.returncode != 0:
            raise RuntimeError(f"command failed ({completed.returncode}): {' '.join(cmd)}; see {stdout_path}")
        return subprocess.CompletedProcess(cmd, completed.returncode, "", "")

    completed = subprocess.run(
        cmd,
        cwd=cwd,
        env=env,
        text=True,
        stdout=stdout,
        stderr=stderr,
        check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(f"command failed ({completed.returncode}): {' '.join(cmd)}\n{completed.stdout}")
    return completed


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip()


def maybe_read_text(path: Path) -> str:
    if path.exists():
        return read_text(path)
    return ""


def now_stamp() -> str:
    return time.strftime("%Y%m%d_%H%M%S")


def choose_output_dir(args: argparse.Namespace) -> Path:
    if args.out_dir:
        return Path(args.out_dir).resolve()
    return (DEFAULT_OUTPUT_ROOT / now_stamp()).resolve()


def clamp_positive(value: int, fallback: int) -> int:
    if value <= 0:
        return fallback
    return value


def parse_latency_us(token: str) -> float:
    text = token.strip()
    if not text:
        return 0.0
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)([a-zA-Z]+)", text)
    if not match:
        raise ValueError(f"unrecognized latency token: {token}")
    value = float(match.group(1))
    unit = match.group(2).lower()
    if unit == "us":
        return value
    if unit == "ms":
        return value * 1000.0
    if unit == "s":
        return value * 1_000_000.0
    if unit == "m":
        return value * 60.0 * 1_000_000.0
    if unit == "ns":
        return value / 1000.0
    raise ValueError(f"unsupported latency unit: {token}")


def parse_duration_seconds(token: str) -> float:
    text = token.strip()
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)([smh]?)", text)
    if not match:
        raise ValueError(f"unrecognized duration token: {token}")
    value = float(match.group(1))
    unit = match.group(2) or "s"
    if unit == "s":
        return value
    if unit == "m":
        return value * 60.0
    if unit == "h":
        return value * 3600.0
    raise ValueError(f"unsupported duration unit: {token}")


def parse_wrk_output(output: str) -> dict[str, float]:
    requests_match = re.search(r"^\s*([0-9]+)\s+requests in\s+", output, re.MULTILINE)
    rps_match = re.search(r"Requests/sec:\s*([0-9]+(?:\.[0-9]+)?)", output)
    avg_match = re.search(r"^\s*Latency\s+([0-9.]+[a-zA-Z]+)\s+", output, re.MULTILINE)
    p99_match = re.search(r"^\s*99(?:\.0+)?%\s+([0-9.]+[a-zA-Z]+)", output, re.MULTILINE)
    if not requests_match or not rps_match or not avg_match or not p99_match:
        raise ValueError(f"failed to parse wrk output:\n{output}")
    return {
        "requests": float(requests_match.group(1)),
        "rps": float(rps_match.group(1)),
        "avg_latency_us": parse_latency_us(avg_match.group(1)),
        "p99_latency_us": parse_latency_us(p99_match.group(1)),
    }


def read_proc_stat(pid: int) -> dict[str, int]:
    stat_path = Path(f"/proc/{pid}/stat")
    raw = stat_path.read_text(encoding="utf-8")
    rparen = raw.rfind(")")
    fields = raw[rparen + 2 :].split()
    return {
        "utime": int(fields[11]),
        "stime": int(fields[12]),
        "rss_pages": int(fields[21]),
    }


def cpu_delta_seconds(before: dict[str, int], after: dict[str, int]) -> float:
    clk_tck = os.sysconf(os.sysconf_names["SC_CLK_TCK"])
    delta_ticks = (after["utime"] + after["stime"]) - (before["utime"] + before["stime"])
    return float(delta_ticks) / float(clk_tck)


def cpu_probe_connection_count(target_rps: float, requested_connections: int) -> int:
    requested = clamp_positive(requested_connections, DEFAULT_CPU_PROBE_CONNECTIONS)
    inferred = max(1, min(requested, int(math.ceil(target_rps / 200.0)) if target_rps > 0 else 1))
    return inferred


def fetch_json(url: str) -> dict[str, Any]:
    with urllib.request.urlopen(url, timeout=2.0) as response:
        return json.loads(response.read().decode("utf-8"))


def wait_http_ready(url: str, *, timeout_s: float = 10.0) -> None:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=1.0) as response:
                if response.status == 200:
                    return
        except (urllib.error.URLError, ConnectionError, TimeoutError, OSError):
            time.sleep(0.05)
    raise RuntimeError(f"server did not become ready: {url}")


def format_server_start_failure(proc: subprocess.Popen[Any], log_path: Path, ready_url: str) -> str:
    lines = [f"server did not become ready: {ready_url}", f"server log: {log_path}"]
    exit_code = proc.poll()
    if exit_code is not None:
        if exit_code < 0:
            lines.append(f"process exited via signal {-exit_code}")
        else:
            lines.append(f"process exited with code {exit_code}")
    if log_path.exists():
        log_text = log_path.read_text(encoding="utf-8", errors="ignore").strip()
        if log_text:
            lines.append("server log tail:")
            lines.extend(log_text.splitlines()[-20:])
    return "\n".join(lines)


def terminate_process(proc: subprocess.Popen[Any]) -> None:
    if proc.poll() is not None:
        return
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        proc.wait(timeout=5.0)
        return
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        return
    proc.wait(timeout=5.0)


def collect_machine_info() -> dict[str, Any]:
    uname = os.uname()
    cpu_model = ""
    cpuinfo_path = Path("/proc/cpuinfo")
    if cpuinfo_path.exists():
        for line in cpuinfo_path.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.lower().startswith("model name"):
                cpu_model = line.split(":", 1)[1].strip()
                break
    governor = maybe_read_text(Path("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"))
    somaxconn = maybe_read_text(Path("/proc/sys/net/core/somaxconn"))
    ulimit_nofile = subprocess.run(["bash", "-lc", "ulimit -n"], text=True, capture_output=True, check=False).stdout.strip()
    ulimit_stack = subprocess.run(["bash", "-lc", "ulimit -s"], text=True, capture_output=True, check=False).stdout.strip()
    return {
        "sysname": uname.sysname,
        "release": uname.release,
        "version": uname.version,
        "machine": uname.machine,
        "cpu_model": cpu_model,
        "cpu_governor": governor or "unknown",
        "somaxconn": somaxconn or "unknown",
        "ulimit_nofile": ulimit_nofile or "unknown",
        "ulimit_stack_kb": ulimit_stack or "unknown",
    }


def build_uya(args: argparse.Namespace, out_dir: Path) -> dict[str, Any]:
    compiler = os.environ.get("UYA_COMPILER", str(REPO_ROOT / "bin" / "uya"))
    if not Path(compiler).exists():
        raise RuntimeError(f"Uya compiler not found: {compiler}")
    cc = os.environ.get("CC", "cc")
    build_mode = os.environ.get("UYA_BENCH_MODE", "nostdlib").strip() or "nostdlib"
    if build_mode == "nostdlib":
        cflags = os.environ.get(
            "UYA_BENCH_NOSTDLIB_CFLAGS",
            f"-std=c99 -O3 -fno-builtin -fno-stack-protector -I{REPO_ROOT}",
        )
    else:
        cflags = os.environ.get("UYA_BENCH_CFLAGS", f"-std=c99 -O3 -fno-builtin -pthread -I{REPO_ROOT}")
    cfile = out_dir / "uyagin_http_bench.c"
    exe = out_dir / "uyagin_http_bench"
    if not args.skip_build:
        compiler_cmd = [compiler, "--c99", str(DEFAULT_UYA_SOURCE), "-o", str(cfile)]
        if build_mode == "nostdlib":
            compiler_cmd.insert(2, "--nostdlib")
        run_checked(compiler_cmd, cwd=REPO_ROOT, stdout_path=out_dir / "build_uya.log")

        if build_mode == "nostdlib":
            cc_cmd = [cc, *shlex.split(cflags), "-no-pie", "-nostdlib", "-static", str(cfile), "-o", str(exe), "-lgcc"]
        else:
            cc_cmd = [cc, *shlex.split(cflags), "-no-pie", str(cfile), "-o", str(exe), "-lm"]
        run_checked(cc_cmd, cwd=REPO_ROOT, stdout_path=out_dir / "build_uya_cc.log")
    return {
        "compiler": compiler,
        "cc": cc,
        "build_mode": build_mode,
        "cflags": cflags,
        "exe": str(exe),
        "port": args.uya_port,
    }


def build_gin(args: argparse.Namespace, out_dir: Path) -> dict[str, Any]:
    go = resolve_go()
    exe = out_dir / "uyagin_http_bench_gin"
    ldflags = os.environ.get("GIN_BENCH_LDFLAGS", "-s -w")
    goproxy_override = os.environ.get("GIN_BENCH_GOPROXY", "").strip()
    used_goproxy = goproxy_override or "default"
    if not args.skip_build:
        attempts: list[tuple[str, str | None]] = []
        if goproxy_override:
            attempts.append((f"override:{goproxy_override}", goproxy_override))
        else:
            attempts.append(("goproxy.cn", "https://goproxy.cn,direct"))
            attempts.append(("default", None))
            attempts.append(("direct", "direct"))

        build_cmd = [go, "build", "-ldflags", ldflags, "-o", str(exe), "./uyagin_http_bench_gin"]
        build_log = out_dir / "build_gin.log"
        failure_logs: list[tuple[str, Path, str]] = []
        for idx, (label, goproxy_value) in enumerate(attempts, start=1):
            env = os.environ.copy()
            if goproxy_value is not None:
                env["GOPROXY"] = goproxy_value
            attempt_log = build_log if len(attempts) == 1 else out_dir / f"build_gin_attempt{idx}.log"
            try:
                run_checked(build_cmd, cwd=BENCH_DIR, env=env, stdout_path=attempt_log)
                used_goproxy = goproxy_value or "default"
                if attempt_log != build_log:
                    attempt_text = attempt_log.read_text(encoding="utf-8", errors="ignore")
                    build_log.write_text(
                        f"# gin build attempt: {label}\n# GOPROXY={used_goproxy}\n\n{attempt_text}",
                        encoding="utf-8",
                    )
                break
            except RuntimeError as exc:
                failure_logs.append((label, attempt_log, str(exc)))
        else:
            lines = []
            for label, attempt_log, message in failure_logs:
                lines.append(f"## attempt: {label}")
                lines.append(message)
                if attempt_log.exists():
                    lines.append(attempt_log.read_text(encoding="utf-8", errors="ignore"))
                lines.append("")
            build_log.write_text("\n".join(lines), encoding="utf-8")
            raise RuntimeError(f"gin benchmark build failed after {len(attempts)} attempts; see {build_log}")
    return {
        "go": go,
        "ldflags": ldflags,
        "goproxy": goproxy_override or used_goproxy,
        "exe": str(exe),
        "port": args.gin_port,
    }


def start_server(cmd: list[str], *, cwd: Path, log_path: Path) -> tuple[subprocess.Popen[Any], Any]:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    fp = log_path.open("wb")
    proc = subprocess.Popen(
        cmd,
        cwd=cwd,
        stdout=fp,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    return proc, fp


def wrk_bin() -> str:
    return shutil.which("wrk") or shutil.which("wrk2") or ""


def build_wrk_command(bin_path: str, args: argparse.Namespace, url: str, headers: dict[str, str]) -> list[str]:
    cmd = [
        bin_path,
        "-t",
        str(clamp_positive(args.wrk_threads, DEFAULT_WRK_THREADS)),
        "-c",
        str(clamp_positive(args.connections, DEFAULT_CONNECTIONS)),
        "-d",
        args.duration,
        "--latency",
    ]
    for key, value in headers.items():
        cmd.extend(["-H", f"{key}: {value}"])
    cmd.append(url)
    return cmd


def median_of(samples: list[dict[str, float]], key: str) -> float:
    return float(statistics.median(item[key] for item in samples))


def safe_ratio(lhs: float, rhs: float) -> float:
    if rhs == 0.0:
        return 0.0
    return lhs / rhs


def run_backend_scenario(
    *,
    backend_name: str,
    backend_info: dict[str, Any],
    scenario: Scenario,
    args: argparse.Namespace,
    out_dir: Path,
    wrk_path: str,
) -> dict[str, Any]:
    samples: list[dict[str, Any]] = []
    port = int(backend_info["port"])
    url = f"http://127.0.0.1:{port}{scenario.path}"
    ready_url = f"http://127.0.0.1:{port}/plaintext"

    for run_idx in range(args.runs):
        run_dir = out_dir / "raw" / backend_name / scenario.name / f"run_{run_idx + 1}"
        run_dir.mkdir(parents=True, exist_ok=True)
        cmd = [backend_info["exe"], "--port", str(port), "--threads", str(clamp_positive(args.server_threads, DEFAULT_SERVER_THREADS))]
        server_log = run_dir / "server.log"
        proc, log_fp = start_server(cmd, cwd=REPO_ROOT, log_path=server_log)
        try:
            try:
                wait_http_ready(ready_url)
            except RuntimeError as exc:
                raise RuntimeError(format_server_start_failure(proc, server_log, ready_url)) from exc
            before_cpu = read_proc_stat(proc.pid)
            before_metrics: dict[str, Any] | None = None
            if backend_name == "uya":
                before_metrics = fetch_json(f"http://127.0.0.1:{port}/__uyagin/metrics")

            wrk_cmd = build_wrk_command(wrk_path, args, url, scenario.headers)
            wrk_result = run_checked(wrk_cmd, cwd=REPO_ROOT)
            (run_dir / "wrk.txt").write_text(wrk_result.stdout, encoding="utf-8")

            after_cpu = read_proc_stat(proc.pid)
            after_metrics: dict[str, Any] | None = None
            if backend_name == "uya":
                after_metrics = fetch_json(f"http://127.0.0.1:{port}/__uyagin/metrics")

            parsed = parse_wrk_output(wrk_result.stdout)
            cpu_seconds = cpu_delta_seconds(before_cpu, after_cpu)
            cpu_per_req_us = 0.0
            if parsed["requests"] > 0:
                cpu_per_req_us = cpu_seconds * 1_000_000.0 / parsed["requests"]

            sample: dict[str, Any] = {
                "backend": backend_name,
                "scenario": scenario.name,
                "run": run_idx + 1,
                "requests": parsed["requests"],
                "rps": parsed["rps"],
                "avg_latency_us": parsed["avg_latency_us"],
                "p99_latency_us": parsed["p99_latency_us"],
                "cpu_seconds": cpu_seconds,
                "cpu_per_req_us": cpu_per_req_us,
                "wrk_cmd": wrk_cmd,
            }
            if before_metrics and after_metrics:
                sample["uya_metrics_before"] = before_metrics
                sample["uya_metrics_after"] = after_metrics
                sample["uya_heap_fallback_delta"] = int(after_metrics["heap_fallback_count"]) - int(before_metrics["heap_fallback_count"])
                sample["uya_frame_alloc_delta"] = int(after_metrics["frame_alloc_count"]) - int(before_metrics["frame_alloc_count"])
                sample["uya_frame_free_delta"] = int(after_metrics["frame_free_count"]) - int(before_metrics["frame_free_count"])
            samples.append(sample)
        finally:
            terminate_process(proc)
            log_fp.close()

    summary: dict[str, Any] = {
        "backend": backend_name,
        "scenario": scenario.name,
        "runs": samples,
        "median_requests": median_of(samples, "requests"),
        "median_rps": median_of(samples, "rps"),
        "median_avg_latency_us": median_of(samples, "avg_latency_us"),
        "median_p99_latency_us": median_of(samples, "p99_latency_us"),
        "median_cpu_seconds": median_of(samples, "cpu_seconds"),
        "median_cpu_per_req_us": median_of(samples, "cpu_per_req_us"),
    }
    if backend_name == "uya":
        summary["median_uya_heap_fallback_delta"] = median_of(samples, "uya_heap_fallback_delta")
        summary["median_uya_frame_alloc_delta"] = median_of(samples, "uya_frame_alloc_delta")
        summary["median_uya_frame_free_delta"] = median_of(samples, "uya_frame_free_delta")
    return summary


def parse_strace_summary(text: str) -> dict[str, dict[str, float]]:
    result: dict[str, dict[str, float]] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("% time") or line.startswith("------") or line.endswith("total"):
            continue
        parts = line.split()
        if len(parts) < 5:
            continue
        syscall = parts[-1]
        try:
            if len(parts) >= 6 and parts[-2].isdigit() and parts[-3].isdigit():
                calls = float(parts[-3])
            else:
                calls = float(parts[-2])
        except ValueError:
            continue
        result[syscall] = {"calls": calls}
    return result


def keepalive_request_bytes(path: str, headers: dict[str, str]) -> bytes:
    lines = [
        f"GET {path} HTTP/1.1",
        "Host: 127.0.0.1",
        "Connection: keep-alive",
        "User-Agent: uyagin-http-cpu-probe",
    ]
    for key, value in headers.items():
        lines.append(f"{key}: {value}")
    return ("\r\n".join(lines) + "\r\n\r\n").encode("ascii")


def read_http_response(sock: socket.socket, recv_buf: bytearray) -> bool:
    header_end = recv_buf.find(b"\r\n\r\n")
    while header_end < 0:
        chunk = sock.recv(4096)
        if not chunk:
            return False
        recv_buf.extend(chunk)
        header_end = recv_buf.find(b"\r\n\r\n")
    header_block = bytes(recv_buf[: header_end + 4])
    header_text = header_block.decode("iso-8859-1")
    content_length = 0
    for line in header_text.split("\r\n"):
        if line.lower().startswith("content-length:"):
            content_length = int(line.split(":", 1)[1].strip())
            break
    total_needed = header_end + 4 + content_length
    while len(recv_buf) < total_needed:
        chunk = sock.recv(4096)
        if not chunk:
            return False
        recv_buf.extend(chunk)
    del recv_buf[:total_needed]
    return True


def run_keepalive_cpu_probe(
    *,
    backend_name: str,
    backend_info: dict[str, Any],
    scenario: Scenario,
    target_rps: float,
    duration_s: float,
    requested_connections: int,
    args: argparse.Namespace,
    out_dir: Path,
) -> dict[str, Any]:
    if target_rps <= 0.0:
        raise ValueError("cpu probe target_rps must be > 0")

    connection_count = cpu_probe_connection_count(target_rps, requested_connections)
    send_interval = float(connection_count) / target_rps
    request_bytes = keepalive_request_bytes(scenario.path, scenario.headers)
    port = int(backend_info["port"])
    ready_url = f"http://127.0.0.1:{port}/plaintext"
    cmd = [backend_info["exe"], "--port", str(port), "--threads", str(clamp_positive(args.server_threads, DEFAULT_SERVER_THREADS))]
    probe_dir = out_dir / "raw" / backend_name / scenario.name / "cpu_probe"
    probe_dir.mkdir(parents=True, exist_ok=True)
    server_log = probe_dir / "server.log"
    proc, log_fp = start_server(cmd, cwd=REPO_ROOT, log_path=server_log)

    counts = [0 for _ in range(connection_count)]
    errors = [0 for _ in range(connection_count)]

    def worker(slot: int, start_ts: float, stop_ts: float) -> None:
        recv_buf = bytearray()
        next_ts = start_ts
        sock_obj: socket.socket | None = None
        try:
            while time.monotonic() < stop_ts:
                if sock_obj is None:
                    sock_obj = socket.create_connection(("127.0.0.1", port), timeout=2.0)
                    sock_obj.settimeout(2.0)
                    recv_buf.clear()
                now = time.monotonic()
                if now < next_ts:
                    time.sleep(next_ts - now)
                try:
                    sock_obj.sendall(request_bytes)
                    if not read_http_response(sock_obj, recv_buf):
                        raise ConnectionError("connection closed while reading response")
                    counts[slot] += 1
                except (socket.timeout, OSError, ConnectionError, ValueError):
                    errors[slot] += 1
                    if sock_obj is not None:
                        try:
                            sock_obj.close()
                        except OSError:
                            pass
                        sock_obj = None
                    continue
                next_ts += send_interval
        finally:
            if sock_obj is not None:
                try:
                    sock_obj.close()
                except OSError:
                    pass

    try:
        try:
            wait_http_ready(ready_url)
        except RuntimeError as exc:
            raise RuntimeError(format_server_start_failure(proc, server_log, ready_url)) from exc
        before_cpu = read_proc_stat(proc.pid)
        start_ts = time.monotonic() + 0.25
        stop_ts = start_ts + duration_s
        threads: list[threading.Thread] = []
        for idx in range(connection_count):
            thread = threading.Thread(target=worker, args=(idx, start_ts, stop_ts), daemon=True)
            thread.start()
            threads.append(thread)
        for thread in threads:
            thread.join()
        end_ts = time.monotonic()
        after_cpu = read_proc_stat(proc.pid)
    finally:
        terminate_process(proc)
        log_fp.close()

    elapsed = max(end_ts - (start_ts + 0.0), 1e-9)
    request_count = sum(counts)
    error_count = sum(errors)
    achieved_rps = request_count / elapsed
    cpu_seconds = cpu_delta_seconds(before_cpu, after_cpu)
    cpu_per_req_us = cpu_seconds * 1_000_000.0 / request_count if request_count > 0 else 0.0
    result = {
        "backend": backend_name,
        "scenario": scenario.name,
        "target_rps": target_rps,
        "duration_s": duration_s,
        "connections": connection_count,
        "request_count": request_count,
        "error_count": error_count,
        "achieved_rps": achieved_rps,
        "cpu_seconds": cpu_seconds,
        "cpu_per_req_us": cpu_per_req_us,
        "within_target_tolerance": abs(achieved_rps - target_rps) <= (target_rps * TARGET_CPU_PROBE_TOLERANCE),
    }
    (probe_dir / "cpu_probe.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def run_syscall_probe(
    *,
    backend_info: dict[str, Any],
    args: argparse.Namespace,
    out_dir: Path,
    wrk_path: str,
) -> dict[str, Any] | None:
    strace = shutil.which("strace")
    if not strace or args.skip_syscall_probe:
        return None

    scenario = next(item for item in SCENARIOS if item.name == "hello_plaintext")
    port = int(backend_info["port"])
    url = f"http://127.0.0.1:{port}{scenario.path}"
    ready_url = f"http://127.0.0.1:{port}/plaintext"
    probe_dir = out_dir / "raw" / "uya" / "hello_plaintext" / "syscall_probe"
    probe_dir.mkdir(parents=True, exist_ok=True)

    summary_path = probe_dir / "strace_summary.txt"
    server_log = probe_dir / "server.log"
    cmd = [
        strace,
        "-f",
        "-qq",
        "-c",
        "-o",
        str(summary_path),
        backend_info["exe"],
        "--port",
        str(port),
        "--threads",
        str(clamp_positive(args.server_threads, DEFAULT_SERVER_THREADS)),
    ]
    proc, log_fp = start_server(cmd, cwd=REPO_ROOT, log_path=server_log)
    try:
        try:
            wait_http_ready(ready_url)
        except RuntimeError as exc:
            raise RuntimeError(format_server_start_failure(proc, server_log, ready_url)) from exc
        wrk_cmd = build_wrk_command(wrk_path, args, url, scenario.headers)
        wrk_result = run_checked(wrk_cmd, cwd=REPO_ROOT)
        (probe_dir / "wrk.txt").write_text(wrk_result.stdout, encoding="utf-8")
        parsed = parse_wrk_output(wrk_result.stdout)
    finally:
        terminate_process(proc)
        log_fp.close()

    summary_text = maybe_read_text(summary_path)
    if not summary_text:
        return None
    syscalls = parse_strace_summary(summary_text)
    requests = parsed["requests"]
    probe: dict[str, Any] = {
        "requests": requests,
        "syscalls": syscalls,
        "write_per_req": (syscalls.get("write", {}).get("calls", 0.0) / requests) if requests else 0.0,
        "read_per_req": (syscalls.get("read", {}).get("calls", 0.0) / requests) if requests else 0.0,
        "epoll_wait_per_req": (syscalls.get("epoll_wait", {}).get("calls", 0.0) / requests) if requests else 0.0,
        "combined_read_epoll_per_req": (
            (syscalls.get("read", {}).get("calls", 0.0) + syscalls.get("epoll_wait", {}).get("calls", 0.0)) / requests
        )
        if requests
        else 0.0,
        "summary_path": str(summary_path),
    }
    probe["syscall_pass_target"] = (
        probe["write_per_req"] <= TARGET_SYSCALL_WRITE_PER_REQ
        and probe["combined_read_epoll_per_req"] <= TARGET_SYSCALL_READ_EPOLL_PER_REQ
    )
    return probe


def collect_selected_scenarios(args: argparse.Namespace) -> list[Scenario]:
    if not args.scenario:
        return list(SCENARIOS)
    selected = set(args.scenario)
    return [item for item in SCENARIOS if item.name in selected]


def collect_selected_backends(args: argparse.Namespace) -> list[str]:
    if not args.backend:
        return ["uya", "gin"]
    ordered: list[str] = []
    for name in ("uya", "gin"):
        if name in args.backend:
            ordered.append(name)
    return ordered


def build_summary_csv(rows: list[dict[str, Any]], path: Path) -> None:
    fields = [
        "scenario",
        "uya_median_rps",
        "gin_median_rps",
        "rps_ratio_vs_gin",
        "uya_median_p99_latency_us",
        "gin_median_p99_latency_us",
        "p99_ratio_vs_gin",
        "uya_median_cpu_per_req_us",
        "gin_median_cpu_per_req_us",
        "uya_median_heap_fallback_delta",
        "syscall_pass_target",
        "cpu_matched_pass_target",
        "rps_pass_target",
        "p99_pass_target",
        "alloc_pass_target",
        "cpu_per_req_pass_estimate",
        "overall_pass_target",
    ]
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.DictWriter(fp, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    args = parse_args()
    args.runs = clamp_positive(args.runs, DEFAULT_RUNS)
    args.wrk_threads = clamp_positive(args.wrk_threads, DEFAULT_WRK_THREADS)
    args.connections = clamp_positive(args.connections, DEFAULT_CONNECTIONS)
    args.server_threads = clamp_positive(args.server_threads, DEFAULT_SERVER_THREADS)
    if args.connections > 64:
        raise SystemExit("connections must be <= 64 to stay within current UyaGin connection slot cap")

    out_dir = choose_output_dir(args)
    out_dir.mkdir(parents=True, exist_ok=True)

    wrk_path = wrk_bin()
    if not wrk_path:
        raise SystemExit("missing dependency: wrk or wrk2")

    selected_scenarios = collect_selected_scenarios(args)
    selected_backends = collect_selected_backends(args)

    build_info: dict[str, Any] = {}
    if "uya" in selected_backends:
        build_info["uya"] = build_uya(args, out_dir)
    if "gin" in selected_backends:
        build_info["gin"] = build_gin(args, out_dir)

    machine = collect_machine_info()
    results: dict[str, dict[str, Any]] = {name: {} for name in selected_backends}

    for scenario in selected_scenarios:
        for backend_name in selected_backends:
            info = build_info[backend_name]
            print(f"uyagin_http_bench: backend={backend_name} scenario={scenario.name} runs={args.runs}")
            summary = run_backend_scenario(
                backend_name=backend_name,
                backend_info=info,
                scenario=scenario,
                args=args,
                out_dir=out_dir,
                wrk_path=wrk_path,
            )
            results[backend_name][scenario.name] = summary

    syscall_probe = None
    if "uya" in selected_backends:
        syscall_probe = run_syscall_probe(
            backend_info=build_info["uya"],
            args=args,
            out_dir=out_dir,
            wrk_path=wrk_path,
        )

    cpu_probe = None
    if (
        not args.skip_cpu_probe
        and "uya" in selected_backends
        and "gin" in selected_backends
        and any(item.name == "hello_plaintext" for item in selected_scenarios)
    ):
        uya_hello = results["uya"].get("hello_plaintext")
        gin_hello = results["gin"].get("hello_plaintext")
        if uya_hello and gin_hello:
            target_rps = args.cpu_probe_rps
            if target_rps <= 0.0:
                target_rps = min(uya_hello["median_rps"], gin_hello["median_rps"]) * TARGET_CPU_PROBE_RPS_FACTOR
            probe_duration = parse_duration_seconds(args.cpu_probe_duration)
            if target_rps > 0.0 and probe_duration > 0.0:
                scenario = next(item for item in SCENARIOS if item.name == "hello_plaintext")
                cpu_probe = {
                    "target_rps": target_rps,
                    "duration_s": probe_duration,
                    "connections": cpu_probe_connection_count(target_rps, args.cpu_probe_connections),
                    "uya": run_keepalive_cpu_probe(
                        backend_name="uya",
                        backend_info=build_info["uya"],
                        scenario=scenario,
                        target_rps=target_rps,
                        duration_s=probe_duration,
                        requested_connections=args.cpu_probe_connections,
                        args=args,
                        out_dir=out_dir,
                    ),
                    "gin": run_keepalive_cpu_probe(
                        backend_name="gin",
                        backend_info=build_info["gin"],
                        scenario=scenario,
                        target_rps=target_rps,
                        duration_s=probe_duration,
                        requested_connections=args.cpu_probe_connections,
                        args=args,
                        out_dir=out_dir,
                    ),
                }
                cpu_probe["pass_target"] = (
                    cpu_probe["uya"]["within_target_tolerance"]
                    and cpu_probe["gin"]["within_target_tolerance"]
                    and cpu_probe["uya"]["cpu_per_req_us"] < cpu_probe["gin"]["cpu_per_req_us"]
                )

    comparison_rows: list[dict[str, Any]] = []
    for scenario in selected_scenarios:
        uya = results.get("uya", {}).get(scenario.name)
        gin = results.get("gin", {}).get(scenario.name)
        row: dict[str, Any] = {"scenario": scenario.name}
        if uya:
            row["uya_median_rps"] = round(uya["median_rps"], 2)
            row["uya_median_p99_latency_us"] = round(uya["median_p99_latency_us"], 2)
            row["uya_median_cpu_per_req_us"] = round(uya["median_cpu_per_req_us"], 4)
            row["uya_median_heap_fallback_delta"] = int(round(uya.get("median_uya_heap_fallback_delta", 0.0)))
        else:
            row["uya_median_rps"] = ""
            row["uya_median_p99_latency_us"] = ""
            row["uya_median_cpu_per_req_us"] = ""
            row["uya_median_heap_fallback_delta"] = ""
        if gin:
            row["gin_median_rps"] = round(gin["median_rps"], 2)
            row["gin_median_p99_latency_us"] = round(gin["median_p99_latency_us"], 2)
            row["gin_median_cpu_per_req_us"] = round(gin["median_cpu_per_req_us"], 4)
        else:
            row["gin_median_rps"] = ""
            row["gin_median_p99_latency_us"] = ""
            row["gin_median_cpu_per_req_us"] = ""

        if uya and gin:
            rps_ratio = safe_ratio(uya["median_rps"], gin["median_rps"])
            p99_ratio = safe_ratio(uya["median_p99_latency_us"], gin["median_p99_latency_us"])
            cpu_ratio = safe_ratio(uya["median_cpu_per_req_us"], gin["median_cpu_per_req_us"])
            row["rps_ratio_vs_gin"] = round(rps_ratio, 4)
            row["p99_ratio_vs_gin"] = round(p99_ratio, 4)
            row["rps_pass_target"] = "1" if rps_ratio >= TARGET_RPS_RATIO else "0"
            row["p99_pass_target"] = "1" if p99_ratio <= TARGET_P99_RATIO else "0"
            row["alloc_pass_target"] = "1" if int(round(uya.get("median_uya_heap_fallback_delta", 0.0))) == TARGET_HEAP_FALLBACK_DELTA else "0"
            row["cpu_per_req_pass_estimate"] = "1" if cpu_ratio <= 1.0 else "0"
        else:
            row["rps_ratio_vs_gin"] = ""
            row["p99_ratio_vs_gin"] = ""
            row["rps_pass_target"] = ""
            row["p99_pass_target"] = ""
            row["alloc_pass_target"] = ""
            row["cpu_per_req_pass_estimate"] = ""
        if scenario.name == "hello_plaintext" and syscall_probe is not None:
            row["syscall_pass_target"] = "1" if syscall_probe["syscall_pass_target"] else "0"
        else:
            row["syscall_pass_target"] = ""
        if scenario.name == "hello_plaintext" and cpu_probe is not None:
            row["cpu_matched_pass_target"] = "1" if cpu_probe["pass_target"] else "0"
        else:
            row["cpu_matched_pass_target"] = ""
        row["overall_pass_target"] = "1"
        for key in ("rps_pass_target", "p99_pass_target", "alloc_pass_target", "syscall_pass_target", "cpu_matched_pass_target"):
            value = row.get(key, "")
            if value == "0":
                row["overall_pass_target"] = "0"
                break
        comparison_rows.append(row)

    overall_pass = all(row["overall_pass_target"] == "1" for row in comparison_rows) if comparison_rows else False
    report = {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "output_dir": str(out_dir),
        "machine": machine,
        "targets": {
            "rps_ratio_min": TARGET_RPS_RATIO,
            "p99_ratio_max": TARGET_P99_RATIO,
            "heap_fallback_delta_max": TARGET_HEAP_FALLBACK_DELTA,
            "syscall_write_per_req_max": TARGET_SYSCALL_WRITE_PER_REQ,
            "syscall_read_epoll_per_req_max": TARGET_SYSCALL_READ_EPOLL_PER_REQ,
            "cpu_probe_rps_factor": TARGET_CPU_PROBE_RPS_FACTOR,
            "cpu_probe_tolerance": TARGET_CPU_PROBE_TOLERANCE,
        },
        "bench_config": {
            "wrk_bin": wrk_path,
            "wrk_threads": args.wrk_threads,
            "connections": args.connections,
            "duration": args.duration,
            "server_threads": args.server_threads,
            "runs": args.runs,
            "cpu_probe_duration": args.cpu_probe_duration,
            "cpu_probe_connections": args.cpu_probe_connections,
        },
        "build": build_info,
        "results": results,
        "comparisons": comparison_rows,
        "syscall_probe_uya_hello_plaintext": syscall_probe,
        "cpu_probe_hello_plaintext": cpu_probe,
        "overall_pass_target": overall_pass,
        "notes": [
            "RPS/p99 target follows docs/uyagin_todo.md P7 thresholds.",
            "alloc_pass_target is derived from UyaGin heap_fallback_count delta and should be 0 on the hot path.",
            "syscall_pass_target is a heuristic bound for the TODO text '接近 1 write + 摊销 read/epoll'.",
            "cpu_probe_hello_plaintext uses an internal keep-alive paced client to compare backend CPU at the same target RPS.",
            "cpu_per_req_pass_estimate remains as a coarse same-work proxy in the regular wrk runs.",
        ],
    }

    json_path = out_dir / "report.json"
    csv_path = out_dir / "summary.csv"
    json_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    build_summary_csv(comparison_rows, csv_path)

    for row in comparison_rows:
        print(
            "uyagin_http_compare: "
            f"scenario={row['scenario']} "
            f"uya_rps={row['uya_median_rps']} "
            f"gin_rps={row['gin_median_rps']} "
            f"rps_ratio={row['rps_ratio_vs_gin']} "
            f"uya_p99_us={row['uya_median_p99_latency_us']} "
            f"gin_p99_us={row['gin_median_p99_latency_us']} "
            f"p99_ratio={row['p99_ratio_vs_gin']} "
            f"alloc_pass={row['alloc_pass_target']} "
            f"syscall_pass={row['syscall_pass_target']} "
            f"cpu_matched_pass={row['cpu_matched_pass_target']} "
            f"cpu_per_req_pass_estimate={row['cpu_per_req_pass_estimate']} "
            f"overall_pass={row['overall_pass_target']}"
        )
    if syscall_probe:
        print(
            "uyagin_http_syscall_probe: "
            f"write_per_req={syscall_probe['write_per_req']:.6f} "
            f"read_per_req={syscall_probe['read_per_req']:.6f} "
            f"epoll_wait_per_req={syscall_probe['epoll_wait_per_req']:.6f} "
            f"combined_read_epoll_per_req={syscall_probe['combined_read_epoll_per_req']:.6f} "
            f"pass_target={int(bool(syscall_probe['syscall_pass_target']))}"
        )
    if cpu_probe:
        print(
            "uyagin_http_cpu_probe: "
            f"target_rps={cpu_probe['target_rps']:.2f} "
            f"uya_achieved_rps={cpu_probe['uya']['achieved_rps']:.2f} "
            f"gin_achieved_rps={cpu_probe['gin']['achieved_rps']:.2f} "
            f"uya_cpu_per_req_us={cpu_probe['uya']['cpu_per_req_us']:.4f} "
            f"gin_cpu_per_req_us={cpu_probe['gin']['cpu_per_req_us']:.4f} "
            f"pass_target={int(bool(cpu_probe['pass_target']))}"
        )
    print(f"uyagin_http_export: json={json_path} csv={csv_path}")
    if args.fail_on_target and not overall_pass:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
