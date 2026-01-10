package lexer

import (
	"testing"
)

func TestTokenType(t *testing.T) {
	// Test that token types are properly defined
	tests := []struct {
		name     string
		tokenType TokenType
		want     string
	}{
		{"EOF", TOKEN_EOF, "TOKEN_EOF"},
		{"Identifier", TOKEN_IDENTIFIER, "TOKEN_IDENTIFIER"},
		{"Number", TOKEN_NUMBER, "TOKEN_NUMBER"},
		{"String", TOKEN_STRING, "TOKEN_STRING"},
		{"Struct", TOKEN_STRUCT, "TOKEN_STRUCT"},
		{"Fn", TOKEN_FN, "TOKEN_FN"},
		{"Return", TOKEN_RETURN, "TOKEN_RETURN"},
		{"If", TOKEN_IF, "TOKEN_IF"},
		{"Plus", TOKEN_PLUS, "TOKEN_PLUS"},
		{"Equal", TOKEN_EQUAL, "TOKEN_EQUAL"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.tokenType.String() != tt.want {
				t.Errorf("TokenType.String() = %v, want %v", tt.tokenType.String(), tt.want)
			}
		})
	}
}

func TestToken(t *testing.T) {
	tests := []struct {
		name     string
		token    *Token
		wantType TokenType
		wantVal  string
		wantLine int
		wantCol  int
	}{
		{
			name:     "EOF token",
			token:    NewToken(TOKEN_EOF, "", 1, 1, "test.uya"),
			wantType: TOKEN_EOF,
			wantVal:  "",
			wantLine: 1,
			wantCol:  1,
		},
		{
			name:     "Identifier token",
			token:    NewToken(TOKEN_IDENTIFIER, "foo", 5, 10, "test.uya"),
			wantType: TOKEN_IDENTIFIER,
			wantVal:  "foo",
			wantLine: 5,
			wantCol:  10,
		},
		{
			name:     "Number token",
			token:    NewToken(TOKEN_NUMBER, "42", 2, 3, "test.uya"),
			wantType: TOKEN_NUMBER,
			wantVal:  "42",
			wantLine: 2,
			wantCol:  3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.token.Type != tt.wantType {
				t.Errorf("Token.Type = %v, want %v", tt.token.Type, tt.wantType)
			}
			if tt.token.Value != tt.wantVal {
				t.Errorf("Token.Value = %v, want %v", tt.token.Value, tt.wantVal)
			}
			if tt.token.Line != tt.wantLine {
				t.Errorf("Token.Line = %v, want %v", tt.token.Line, tt.wantLine)
			}
			if tt.token.Column != tt.wantCol {
				t.Errorf("Token.Column = %v, want %v", tt.token.Column, tt.wantCol)
			}
			if tt.token.Filename != "test.uya" {
				t.Errorf("Token.Filename = %v, want test.uya", tt.token.Filename)
			}
		})
	}
}

func TestNewToken(t *testing.T) {
	token := NewToken(TOKEN_IDENTIFIER, "test", 1, 1, "file.uya")
	
	if token == nil {
		t.Fatal("NewToken returned nil")
	}
	
	if token.Type != TOKEN_IDENTIFIER {
		t.Errorf("NewToken().Type = %v, want TOKEN_IDENTIFIER", token.Type)
	}
	
	if token.Value != "test" {
		t.Errorf("NewToken().Value = %v, want test", token.Value)
	}
}

