package lexer

import (
	"strings"
	"testing"
)

func TestNewLexer(t *testing.T) {
	// Create a temporary file for testing
	testContent := "fn main() {}"
	lexer := &Lexer{
		buffer:   testContent,
		filename: "test.uya",
		line:     1,
		column:   1,
	}

	if lexer.buffer != testContent {
		t.Errorf("Lexer.buffer = %v, want %v", lexer.buffer, testContent)
	}
}

func TestLexer_NextToken_Basic(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		wantType TokenType
		wantVal  string
	}{
		{"EOF", "", TOKEN_EOF, ""},
		{"identifier", "foo", TOKEN_IDENTIFIER, "foo"},
		{"keyword fn", "fn", TOKEN_FN, "fn"},
		{"keyword struct", "struct", TOKEN_STRUCT, "struct"},
		{"number", "42", TOKEN_NUMBER, "42"},
		{"plus", "+", TOKEN_PLUS, "+"},
		{"minus", "-", TOKEN_MINUS, "-"},
		{"equal", "==", TOKEN_EQUAL, "=="},
		{"assign", "=", TOKEN_ASSIGN, "="},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			l := &Lexer{
				buffer:   tt.input,
				filename: "test.uya",
				line:     1,
				column:   1,
			}
			token, err := l.NextToken()
			if err != nil {
				t.Fatalf("NextToken() error = %v", err)
			}
			if token.Type != tt.wantType {
				t.Errorf("NextToken().Type = %v, want %v", token.Type, tt.wantType)
			}
			if !strings.HasPrefix(token.Value, tt.wantVal) {
				t.Errorf("NextToken().Value = %v, want prefix %v", token.Value, tt.wantVal)
			}
		})
	}
}

func TestLexer_NextToken_Operators(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		wantType TokenType
		wantVal  string
	}{
		{"plus pipe", "+|", TOKEN_PLUS_PIPE, "+|"},
		{"plus percent", "+%", TOKEN_PLUS_PERCENT, "+%"},
		{"arrow", "=>", TOKEN_ARROW, "=>"},
		{"logical and", "&&", TOKEN_LOGICAL_AND, "&&"},
		{"logical or", "||", TOKEN_LOGICAL_OR, "||"},
		{"left shift", "<<", TOKEN_LEFT_SHIFT, "<<"},
		{"right shift", ">>", TOKEN_RIGHT_SHIFT, ">>"},
		{"range", "..", TOKEN_RANGE, ".."},
		{"ellipsis", "...", TOKEN_ELLIPSIS, "..."},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			l := &Lexer{
				buffer:   tt.input,
				filename: "test.uya",
				line:     1,
				column:   1,
			}
			token, err := l.NextToken()
			if err != nil {
				t.Fatalf("NextToken() error = %v", err)
			}
			if token.Type != tt.wantType {
				t.Errorf("NextToken().Type = %v, want %v", token.Type, tt.wantType)
			}
			if token.Value != tt.wantVal {
				t.Errorf("NextToken().Value = %v, want %v", token.Value, tt.wantVal)
			}
		})
	}
}

func TestLexer_NextToken_String(t *testing.T) {
	l := &Lexer{
		buffer:   `"hello"`,
		filename: "test.uya",
		line:     1,
		column:   1,
	}
	token, err := l.NextToken()
	if err != nil {
		t.Fatalf("NextToken() error = %v", err)
	}
	if token.Type != TOKEN_STRING {
		t.Errorf("NextToken().Type = %v, want TOKEN_STRING", token.Type)
	}
	if !strings.Contains(token.Value, "hello") {
		t.Errorf("NextToken().Value = %v, want to contain 'hello'", token.Value)
	}
}

func TestLexer_SkipWhitespace(t *testing.T) {
	l := &Lexer{
		buffer:   "   \n\t  foo",
		filename: "test.uya",
		line:     1,
		column:   1,
	}
	l.skipWhitespace()
	token, err := l.NextToken()
	if err != nil {
		t.Fatalf("NextToken() error = %v", err)
	}
	if token.Type != TOKEN_IDENTIFIER || token.Value != "foo" {
		t.Errorf("NextToken() = %v, want identifier 'foo'", token)
	}
}

func TestLexer_SkipComments(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  TokenType
	}{
		{"single line comment", "// comment\nfoo", TOKEN_IDENTIFIER},
		{"multi line comment", "/* comment */foo", TOKEN_IDENTIFIER},
		{"nested comment", "/* a /* b */ c */foo", TOKEN_IDENTIFIER},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			l := &Lexer{
				buffer:   tt.input,
				filename: "test.uya",
				line:     1,
				column:   1,
			}
			l.skipWhitespace()
			token, err := l.NextToken()
			if err != nil {
				t.Fatalf("NextToken() error = %v", err)
			}
			if token.Type != tt.want {
				t.Errorf("NextToken().Type = %v, want %v", token.Type, tt.want)
			}
		})
	}
}

