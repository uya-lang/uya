.PHONY: build test lint clean run

# Build the compiler
build:
	go build -o uyac ./cmd/uyac

# Run all tests
test:
	go test -v ./...

# Run tests with coverage
test-coverage:
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# Run linter
lint:
	golangci-lint run

# Clean build artifacts
clean:
	rm -f uyac
	rm -f coverage.out coverage.html
	go clean

# Run the compiler (example)
run:
	./uyac input.uya output.c

# Install dependencies
deps:
	go mod download
	go mod tidy

