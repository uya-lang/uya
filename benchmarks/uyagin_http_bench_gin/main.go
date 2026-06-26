package main

import (
	"bytes"
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"runtime"

	"github.com/gin-gonic/gin"
)

const (
	defaultPort    = 18877
	defaultThreads = 4
)

var (
	plaintextBody    = []byte("hello")
	jsonSmallBody    = []byte(`{"ok":true,"msg":"uyagin-bench","lang":"uya","ver":1,"pad":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}`)
	middlewareBody   = []byte("authorized")
	unauthorizedBody = []byte("unauthorized")
	largeBody        = bytes.Repeat([]byte{'a'}, 64*1024)
)

func disabledLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()
	}
}

func authStub() gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.GetHeader("Authorization") == "" {
			c.Data(http.StatusUnauthorized, "text/plain", unauthorizedBody)
			c.Abort()
			return
		}
		c.Next()
	}
}

func buildEngine() *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	engine := gin.New()
	engine.Use(gin.Recovery())

	engine.GET("/plaintext", func(c *gin.Context) {
		c.Data(http.StatusOK, "text/plain", plaintextBody)
	})
	engine.GET("/json", func(c *gin.Context) {
		c.Data(http.StatusOK, "application/json", jsonSmallBody)
	})
	engine.GET("/users/:id", func(c *gin.Context) {
		c.Header("Content-Type", "text/plain")
		c.Status(http.StatusOK)
		_, _ = c.Writer.WriteString(c.Param("id"))
	})
	engine.GET("/blob64k", func(c *gin.Context) {
		c.Data(http.StatusOK, "application/octet-stream", largeBody)
	})

	mw := engine.Group("/middleware")
	mw.Use(disabledLogger(), authStub())
	mw.GET("/ping", func(c *gin.Context) {
		c.Data(http.StatusOK, "text/plain", middlewareBody)
	})

	return engine
}

func parseArgs() (int, int) {
	port := flag.Int("port", defaultPort, "listen port")
	threads := flag.Int("threads", defaultThreads, "gomaxprocs")
	flag.Parse()
	if *threads <= 0 {
		*threads = defaultThreads
	}
	return *port, *threads
}

func main() {
	port, threads := parseArgs()
	runtime.GOMAXPROCS(threads)

	addr := fmt.Sprintf("127.0.0.1:%d", port)
	listener, err := net.Listen("tcp4", addr)
	if err != nil {
		fmt.Fprintf(os.Stderr, "uyagin_http_bench_gin: listen failed: %v\n", err)
		os.Exit(1)
	}
	defer listener.Close()

	server := &http.Server{
		Addr:    addr,
		Handler: buildEngine(),
	}

	fmt.Fprintf(os.Stderr, "uyagin_http_bench_gin: listening on http://%s threads=%d\n", addr, threads)
	if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
		fmt.Fprintf(os.Stderr, "uyagin_http_bench_gin: serve failed: %v\n", err)
		os.Exit(2)
	}
}
