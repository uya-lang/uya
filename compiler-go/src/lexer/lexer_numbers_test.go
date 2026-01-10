package lexer

import (
	"strings"
	"testing"
)

func TestReadNumber(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		wantType TokenType
		wantVal  string
	}{
		{"integer", "42", TOKEN_NUMBER, "42"},
		{"negative integer", "-42", TOKEN_NUMBER, "-42"},
		{"float", "3.14", TOKEN_NUMBER, "3.14"},
		{"float with zero", "0.5", TOKEN_NUMBER, "0.5"},
		{"float starting with dot", ".5", TOKEN_NUMBER, ".5"},
		{"large integer", "1234567890", TOKEN_NUMBER, "1234567890"},
		{"hex number", "0x1A", TOKEN_NUMBER, "0x1A"},
		{"hex number uppercase", "0XFF", TOKEN_NUMBER, "0XFF"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			l := &Lexer{
				buffer:   tt.input,
				filename: "test.uya",
				line:     1,
				column:   1,
			}
			token, err := l.readNumber()
			if err != nil {
				t.Fatalf("readNumber() error = %v", err)
			}
			if token.Type != tt.wantType {
				t.Errorf("readNumber().Type = %v, want %v", token.Type, tt.wantType)
			}
			if !strings.HasPrefix(token.Value, tt.wantVal) {
				t.Errorf("readNumber().Value = %v, want prefix %v", token.Value, tt.wantVal)
			}
		})
	}
}

