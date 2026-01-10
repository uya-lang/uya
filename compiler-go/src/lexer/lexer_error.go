package lexer

import "fmt"

// LexerError represents an error encountered during lexing
type LexerError struct {
	Message  string
	Line     int
	Column   int
	Filename string
}

// Error implements the error interface
func (e *LexerError) Error() string {
	return fmt.Sprintf("%s:%d:%d: %s", e.Filename, e.Line, e.Column, e.Message)
}

