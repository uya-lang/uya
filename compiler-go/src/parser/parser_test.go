package parser

import (
	"os"
	"testing"

	"github.com/uya/compiler-go/src/lexer"
)

func createTestLexer(t *testing.T, content string) *lexer.Lexer {
	// Create a temporary file for testing
	tmpfile, err := os.CreateTemp("", "test_*.uya")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	defer os.Remove(tmpfile.Name()) // Clean up

	if _, err := tmpfile.WriteString(content); err != nil {
		tmpfile.Close()
		t.Fatalf("Failed to write to temp file: %v", err)
	}
	tmpfile.Close()

	l, err := lexer.NewLexer(tmpfile.Name())
	if err != nil {
		t.Fatalf("NewLexer failed: %v", err)
	}
	return l
}

func TestNewParser(t *testing.T) {
	// Create a lexer for testing
	l := createTestLexer(t, "fn main() {}")

	parser := NewParser(l)
	if parser == nil {
		t.Fatal("NewParser returned nil")
	}

	if parser.lexer == nil {
		t.Fatal("Parser.lexer is nil")
	}

	if parser.currentToken == nil {
		t.Fatal("Parser.currentToken is nil after initialization")
	}
}

func TestParser_Peek(t *testing.T) {
	// Create a simple test
	l := createTestLexer(t, "fn main() {}")

	parser := NewParser(l)
	if parser == nil {
		t.Fatal("NewParser returned nil")
	}

	token := parser.peek()
	if token == nil {
		t.Fatal("peek returned nil")
	}

	// peek should not advance the token
	token2 := parser.peek()
	if token != token2 {
		t.Fatal("peek should not advance the token")
	}
}

func TestParser_Consume(t *testing.T) {
	l := createTestLexer(t, "fn main() {}")

	parser := NewParser(l)
	if parser == nil {
		t.Fatal("NewParser returned nil")
	}

	firstToken := parser.peek()
	consumed := parser.consume()
	if consumed != firstToken {
		t.Fatal("consume should return the current token")
	}

	// After consume, current token should be different
	newToken := parser.peek()
	if newToken == firstToken {
		t.Fatal("consume should advance to next token")
	}
}

func TestParser_Match(t *testing.T) {
	l := createTestLexer(t, "fn main() {}")

	parser := NewParser(l)
	if parser == nil {
		t.Fatal("NewParser returned nil")
	}

	currentType := parser.peek().Type
	if !parser.match(currentType) {
		t.Fatalf("match should return true for current token type %v", currentType)
	}

	// Match a different type should return false
	if parser.match(lexer.TOKEN_STRUCT) && currentType != lexer.TOKEN_STRUCT {
		t.Fatal("match should return false for different token type")
	}
}

func TestParser_Expect(t *testing.T) {
	l := createTestLexer(t, "fn main() {}")

	parser := NewParser(l)
	if parser == nil {
		t.Fatal("NewParser returned nil")
	}

	currentType := parser.peek().Type
	token, err := parser.expect(currentType)
	if err != nil {
		t.Fatalf("expect should succeed for current token type: %v", err)
	}
	if token == nil {
		t.Fatal("expect should return the token")
	}
	if token.Type != currentType {
		t.Fatal("expect should return the correct token")
	}

	// Expect a different type should fail
	_, err = parser.expect(lexer.TOKEN_STRUCT)
	if err == nil && parser.peek().Type != lexer.TOKEN_STRUCT {
		t.Fatal("expect should return error for different token type")
	}
}

func TestParser_Parse_EmptyFile(t *testing.T) {
	// Test parsing an empty file (just EOF)
	// We'll need to create a mock lexer or use a test file
	t.Skip("Need to implement test with mock lexer or test file")
}

