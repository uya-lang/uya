// benchmarks/http_bench.go — 纯 Go 裸 socket HTTP 服务端（与 http_bench.uya 对齐）
//
// 路由与体大小（与 Uya 版一致）：
//   GET /              → "hello"（5 字节）
//   GET /plaintext     → "hello"（5 字节，主 benchmark 入口）
//   GET /json          → {"ok":true}（11 字节）
//   GET /item/:id      → 体为路径参数 id（单段）
//   GET /payload1k     → 1024 字节 'a'
//   GET /payload10k    → 10240 字节 'a'
//   GET /payload100k   → 102400 字节 'a'
//
// 默认 127.0.0.1:8876；`--once`：accept 一次连接，处理首个请求后退出。
// `--threads N`：指定 accept worker 与 GOMAXPROCS。
//
// 运行：
//   cd benchmarks && go run .
// 压测（与 Uya 相同 URL）：
//   wrk -t4 -c64 -d10s http://127.0.0.1:8876/plaintext

package main

import (
	"bufio"
	"bytes"
	"fmt"
	"net"
	"os"
	"runtime"
	"strconv"
	"strings"
)

const benchPort = "8876"

var (
	helloBody   = []byte("hello")
	jsonBody    = []byte(`{"ok":true}`)
	payload1k   = bytes.Repeat([]byte{'a'}, 1024)
	payload10k  = bytes.Repeat([]byte{'a'}, 10240)
	payload100k = bytes.Repeat([]byte{'a'}, 102400)

	rootPath        = []byte("/")
	plaintextPath   = []byte("/plaintext")
	jsonPath        = []byte("/json")
	itemPrefix      = []byte("/item/")
	payload1kPath   = []byte("/payload1k")
	payload10kPath  = []byte("/payload10k")
	payload100kPath = []byte("/payload100k")
	getMethod       = []byte("GET")
	http11Version   = []byte("HTTP/1.1")
)

func statusText(code int) string {
	switch code {
	case 200:
		return "OK"
	case 400:
		return "Bad Request"
	case 404:
		return "Not Found"
	case 405:
		return "Method Not Allowed"
	default:
		return "Unknown"
	}
}

func trimCRLF(b []byte) []byte {
	if len(b) > 0 && b[len(b)-1] == '\n' {
		b = b[:len(b)-1]
	}
	if len(b) > 0 && b[len(b)-1] == '\r' {
		b = b[:len(b)-1]
	}
	return b
}

func equalFoldASCII(b []byte, s string) bool {
	if len(b) != len(s) {
		return false
	}
	for i := 0; i < len(b); i++ {
		c := b[i]
		d := s[i]
		if c == d {
			continue
		}
		if 'A' <= c && c <= 'Z' {
			c += 'a' - 'A'
		}
		if 'A' <= d && d <= 'Z' {
			d += 'a' - 'A'
		}
		if c != d {
			return false
		}
	}
	return true
}

func containsTokenCI(b []byte, token string) bool {
	if len(token) == 0 || len(b) < len(token) {
		return false
	}
	for i := 0; i+len(token) <= len(b); i++ {
		if equalFoldASCII(b[i:i+len(token)], token) {
			return true
		}
	}
	return false
}

func parseRequestLine(line []byte) (method []byte, path []byte, version []byte, ok bool) {
	line = trimCRLF(line)
	sp1 := bytes.IndexByte(line, ' ')
	if sp1 < 0 {
		return nil, nil, nil, false
	}
	rest := line[sp1+1:]
	sp2 := bytes.IndexByte(rest, ' ')
	if sp2 < 0 {
		return nil, nil, nil, false
	}
	method = line[:sp1]
	path = rest[:sp2]
	version = bytes.TrimSpace(rest[sp2+1:])
	if len(method) == 0 || len(path) == 0 || len(version) == 0 {
		return nil, nil, nil, false
	}
	if q := bytes.IndexByte(path, '?'); q >= 0 {
		path = path[:q]
	}
	return method, path, version, true
}

func parseConnectionHeader(line []byte) (found bool, wantsClose bool, wantsKeepAlive bool) {
	line = trimCRLF(line)
	if len(line) < 11 {
		return false, false, false
	}
	if !equalFoldASCII(line[:10], "Connection") || line[10] != ':' {
		return false, false, false
	}
	val := bytes.TrimSpace(line[11:])
	if containsTokenCI(val, "close") {
		return true, true, false
	}
	if containsTokenCI(val, "keep-alive") {
		return true, false, true
	}
	return true, false, false
}

func readRequest(br *bufio.Reader, http10SessionKeepAlive bool) (method []byte, path []byte, wantsClose bool, http11 bool, err error) {
	line, err := br.ReadSlice('\n')
	if err != nil {
		return nil, nil, true, false, err
	}

	method, path, version, ok := parseRequestLine(line)
	if !ok {
		return nil, nil, true, false, fmt.Errorf("bad request line")
	}
	http11 = bytes.Equal(version, http11Version)

	hasConnection := false
	wantsClose = true
	for {
		line, err = br.ReadSlice('\n')
		if err != nil {
			return nil, nil, true, http11, err
		}
		line = trimCRLF(line)
		if len(line) == 0 {
			break
		}
		found, closeToken, keepAliveToken := parseConnectionHeader(line)
		if !found {
			continue
		}
		hasConnection = true
		if closeToken {
			wantsClose = true
		}
		if keepAliveToken {
			wantsClose = false
		}
	}

	if !hasConnection {
		if http10SessionKeepAlive {
			wantsClose = false
		} else {
			wantsClose = !http11
		}
	}
	return method, path, wantsClose, http11, nil
}

func dispatch(method, path []byte) (int, []byte) {
	if !bytes.Equal(method, getMethod) {
		return 405, nil
	}
	switch {
	case bytes.Equal(path, rootPath):
		return 200, helloBody
	case bytes.Equal(path, plaintextPath):
		return 200, helloBody
	case bytes.Equal(path, jsonPath):
		return 200, jsonBody
	case bytes.HasPrefix(path, itemPrefix):
		id := path[len(itemPrefix):]
		if len(id) == 0 {
			return 400, nil
		}
		if bytes.IndexByte(id, '/') >= 0 {
			return 404, nil
		}
		return 200, id
	case bytes.Equal(path, payload1kPath):
		return 200, payload1k
	case bytes.Equal(path, payload10kPath):
		return 200, payload10k
	case bytes.Equal(path, payload100kPath):
		return 200, payload100k
	default:
		return 404, nil
	}
}

func writeResponse(conn *net.TCPConn, status int, body []byte, keepAlive bool) error {
	var header [256]byte
	h := header[:0]
	h = append(h, "HTTP/1.1 "...)
	h = strconv.AppendInt(h, int64(status), 10)
	h = append(h, ' ')
	h = append(h, statusText(status)...)
	h = append(h, "\r\nContent-Length: "...)
	h = strconv.AppendInt(h, int64(len(body)), 10)
	h = append(h, "\r\nContent-Type: text/plain\r\nConnection: "...)
	if keepAlive {
		h = append(h, "keep-alive"...)
	} else {
		h = append(h, "close"...)
	}
	h = append(h, "\r\n\r\n"...)

	bufs := net.Buffers{h, body}
	_, err := (&bufs).WriteTo(conn)
	return err
}

func handleConn(conn *net.TCPConn, once bool) {
	defer conn.Close()
	_ = conn.SetNoDelay(true)

	reader := bufio.NewReaderSize(conn, 8192)
	http10SessionKeepAlive := false

	for {
		method, path, wantsClose, http11, err := readRequest(reader, http10SessionKeepAlive)
		if err != nil {
			return
		}

		status, body := dispatch(method, path)
		if err := writeResponse(conn, status, body, !wantsClose); err != nil {
			return
		}

		if once || wantsClose {
			return
		}
		if !http11 {
			http10SessionKeepAlive = true
		}
	}
}

func runOnce() error {
	ln, err := net.Listen("tcp4", "127.0.0.1:"+benchPort)
	if err != nil {
		return err
	}
	defer ln.Close()

	tcpLn, ok := ln.(*net.TCPListener)
	if !ok {
		return fmt.Errorf("unexpected listener type")
	}
	conn, err := tcpLn.AcceptTCP()
	if err != nil {
		return err
	}
	handleConn(conn, true)
	return nil
}

func acceptLoop(tcpLn *net.TCPListener) {
	for {
		conn, err := tcpLn.AcceptTCP()
		if err != nil {
			if ne, ok := err.(net.Error); ok && ne.Temporary() {
				continue
			}
			return
		}
		go handleConn(conn, false)
	}
}

func runServer(workerCount int) error {
	addr := "127.0.0.1:" + benchPort
	ln, err := net.Listen("tcp4", addr)
	if err != nil {
		return err
	}

	tcpLn, ok := ln.(*net.TCPListener)
	if !ok {
		return fmt.Errorf("unexpected listener type")
	}

	if workerCount < 1 {
		workerCount = 1
	}
	for i := 0; i < workerCount; i++ {
		go acceptLoop(tcpLn)
	}

	fmt.Fprintf(os.Stderr, "benchmark target http://%s/plaintext\n", addr)
	select {}
}

func parseArgs(args []string) (bool, int) {
	once := false
	threads := runtime.NumCPU()

	for i := 0; i < len(args); i++ {
		a := args[i]
		switch {
		case a == "--once":
			once = true
		case a == "--threads" && i+1 < len(args):
			if n, err := strconv.Atoi(args[i+1]); err == nil && n > 0 {
				threads = n
			}
			i++
		case strings.HasPrefix(a, "--threads="):
			value := strings.TrimPrefix(a, "--threads=")
			if n, err := strconv.Atoi(value); err == nil && n > 0 {
				threads = n
			}
		}
	}

	if threads < 1 {
		threads = 1
	}
	return once, threads
}

func main() {
	once, threads := parseArgs(os.Args[1:])
	runtime.GOMAXPROCS(threads)

	if once {
		if err := runOnce(); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}

	if err := runServer(threads); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
